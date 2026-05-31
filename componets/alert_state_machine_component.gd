extends Node
class_name AlertStateMachineComponent

# ─────────────────────────────────────────
#  ALERT STATE MACHINE COMPONENT  (on Enemy)
#  Owns the five alert states, all decay
#  timers, last known position, and the
#  radio / partner logic.
#  Listens to awareness_component.
#  Broadcasts state to the enemy AI tree.
# ─────────────────────────────────────────

# ── States ────────────────────────────────
enum AlertState {
	UNAWARE,          # < 25%   — fixed patrol, predictable timing
	SUSPICIOUS,       # 25–65%  — leaves patrol, radios partner, waits 8s
	ALERTED,          # 65–89%  — active hunt, last known pos, flanks, calls units
	FULL_ALERT,       # 90%+    — zone lockdown, no stealth possible
	WRAITH_PROTOCOL   # elite   — never investigates, mirrors counter timing
}

# ── Awareness Thresholds ──────────────────
const SUSPICIOUS_THRESHOLD:  float = 0.25
const ALERTED_THRESHOLD:     float = 0.65
const FULL_ALERT_THRESHOLD:  float = 0.90

# ── Decay Timers ──────────────────────────
const SUSPICIOUS_DECAY:      float = 6.0   # → UNAWARE  after 6s no contact
const ALERTED_DECAY:         float = 12.0  # → SUSPICIOUS after 12s contact lost
const FULL_ALERT_CLEAR:      float = 30.0  # → ALERTED  after zone exit + 30s clear

# ── Partner Wait ──────────────────────────
const PARTNER_WAIT_TIME:     float = 8.0   # seconds enemy waits for partner in SUSPICIOUS

# ── Signals ───────────────────────────────
signal state_changed(old_state: AlertState, new_state: AlertState)
signal last_known_position_updated(position: Vector3)
signal partner_radio_called(calling_state: AlertState)
signal units_called                       # ALERTED — spreads and flanks
signal body_found                         # hard override signal
signal lockdown_triggered                 # FULL_ALERT — lights on, zone sealed
signal wraith_protocol_activated

# ── Component References ──────────────────
@export var awareness_component: AwarenessComponent
@export var patrol_zone: StealthZoneComponent   # to track player zone exit

# ── State ─────────────────────────────────
var current_state: AlertState = AlertState.UNAWARE
var last_known_position: Vector3 = Vector3.ZERO

var _decay_timer:          float = 0.0
var _partner_wait_timer:   float = 0.0
var _full_alert_clear_timer: float = 0.0

var _decay_active:         bool  = false
var _player_in_zone:       bool  = false
var _contact_lost:         bool  = false   # true when LoS dropped in ALERTED+


# ─────────────────────────────────────────
#  GODOT CALLBACKS
# ─────────────────────────────────────────

func _ready() -> void:
	assert(awareness_component != null,
		"AlertStateMachineComponent: awareness_component not assigned.")

	awareness_component.awareness_changed.connect(_on_awareness_changed)
	awareness_component.line_of_sight_gained.connect(_on_los_gained)
	awareness_component.line_of_sight_lost.connect(_on_los_lost)

	if patrol_zone:
		patrol_zone.player_entered_zone.connect(_on_player_entered_zone)
		patrol_zone.player_exited_zone.connect(_on_player_exited_zone)


func _process(delta: float) -> void:
	_tick_partner_wait(delta)
	_tick_decay(delta)
	_tick_full_alert_clear(delta)
	_update_last_known_position()


# ─────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────

## Hard override — body discovery jumps straight to ALERTED
## regardless of current awareness value.
func report_body_found() -> void:
	emit_signal("body_found")
	_force_state(AlertState.ALERTED)
	_start_decay(ALERTED_DECAY)


## Called when the player is directly witnessed (confirmed visual).
## Jumps straight to FULL_ALERT.
func report_player_witnessed(at_position: Vector3) -> void:
	last_known_position = at_position
	emit_signal("last_known_position_updated", last_known_position)
	_force_state(AlertState.FULL_ALERT)


## Story trigger for elite enemies — Act 3 only.
func trigger_wraith_protocol() -> void:
	_force_state(AlertState.WRAITH_PROTOCOL)
	emit_signal("wraith_protocol_activated")


## Returns true if enemy is actively hunting the player.
func is_hunting() -> bool:
	return current_state == AlertState.ALERTED \
		or current_state == AlertState.FULL_ALERT \
		or current_state == AlertState.WRAITH_PROTOCOL


## Returns true if stealth is still viable against this enemy.
func is_stealth_possible() -> bool:
	return current_state != AlertState.FULL_ALERT \
		and current_state != AlertState.WRAITH_PROTOCOL


# ─────────────────────────────────────────
#  PRIVATE — STATE TRANSITIONS
# ─────────────────────────────────────────

func _evaluate_state_from_awareness(awareness: float) -> void:
	# Never auto-downgrade FULL_ALERT or WRAITH_PROTOCOL —
	# those have their own dedicated exit paths.
	if current_state == AlertState.FULL_ALERT \
	or current_state == AlertState.WRAITH_PROTOCOL:
		return

	if awareness >= FULL_ALERT_THRESHOLD:
		_try_enter_state(AlertState.FULL_ALERT)

	elif awareness >= ALERTED_THRESHOLD:
		_try_enter_state(AlertState.ALERTED)

	elif awareness >= SUSPICIOUS_THRESHOLD:
		_try_enter_state(AlertState.SUSPICIOUS)

	else:
		# Awareness is low — begin decay rather than snapping to UNAWARE
		if current_state != AlertState.UNAWARE:
			_begin_decay_for_current_state()


func _try_enter_state(new_state: AlertState) -> void:
	# Only escalate — never auto-downgrade via this path
	if new_state <= current_state:
		_reset_decay()   # contact re-established, cancel any active decay
		return
	_force_state(new_state)


func _force_state(new_state: AlertState) -> void:
	if new_state == current_state:
		return

	var old_state := current_state
	current_state  = new_state
	_reset_decay()

	emit_signal("state_changed", old_state, new_state)
	_on_state_entered(new_state, old_state)


func _on_state_entered(new_state: AlertState, _old_state: AlertState) -> void:
	match new_state:
		AlertState.SUSPICIOUS:
			# Leaves patrol, radios partner, waits 8s for convergence
			_partner_wait_timer = PARTNER_WAIT_TIME
			emit_signal("partner_radio_called", AlertState.SUSPICIOUS)

		AlertState.ALERTED:
			# Active hunt — stamps last known position, calls all units
			if awareness_component.has_line_of_sight:
				_stamp_last_known_position()
			emit_signal("units_called")
			_contact_lost = false

		AlertState.FULL_ALERT:
			# Zone lockdown — lights on, no stealth possible
			emit_signal("lockdown_triggered")
			emit_signal("units_called")
			_contact_lost = false

		AlertState.UNAWARE:
			_contact_lost = false


# ─────────────────────────────────────────
#  PRIVATE — DECAY TIMERS
# ─────────────────────────────────────────

func _begin_decay_for_current_state() -> void:
	if _decay_active:
		return   # already counting down

	match current_state:
		AlertState.SUSPICIOUS:
			_start_decay(SUSPICIOUS_DECAY)
		AlertState.ALERTED:
			if _contact_lost:
				_start_decay(ALERTED_DECAY)


func _start_decay(duration: float) -> void:
	_decay_timer  = duration
	_decay_active = true


func _reset_decay() -> void:
	_decay_timer  = 0.0
	_decay_active = false


func _tick_decay(delta: float) -> void:
	if not _decay_active:
		return
	if current_state == AlertState.UNAWARE \
	or current_state == AlertState.FULL_ALERT \
	or current_state == AlertState.WRAITH_PROTOCOL:
		_reset_decay()
		return

	_decay_timer -= delta

	if _decay_timer <= 0.0:
		_reset_decay()
		_decay_expired()


func _decay_expired() -> void:
	match current_state:
		AlertState.SUSPICIOUS:
			_force_state(AlertState.UNAWARE)
		AlertState.ALERTED:
			_force_state(AlertState.SUSPICIOUS)
			_start_decay(SUSPICIOUS_DECAY)   # chain: ALERTED → SUSPICIOUS → UNAWARE


func _tick_full_alert_clear(delta: float) -> void:
	# FULL_ALERT only starts its timer after the player has LEFT the zone
	if current_state != AlertState.FULL_ALERT:
		_full_alert_clear_timer = 0.0
		return
	if _player_in_zone:
		_full_alert_clear_timer = 0.0
		return

	_full_alert_clear_timer += delta

	if _full_alert_clear_timer >= FULL_ALERT_CLEAR:
		_full_alert_clear_timer = 0.0
		# Drop to ALERTED — ALERTED's own decay will finish the chain
		_force_state(AlertState.ALERTED)
		_contact_lost = true
		_start_decay(ALERTED_DECAY)


func _tick_partner_wait(delta: float) -> void:
	if _partner_wait_timer <= 0.0:
		return
	_partner_wait_timer -= delta


# ─────────────────────────────────────────
#  PRIVATE — LAST KNOWN POSITION
# ─────────────────────────────────────────

func _update_last_known_position() -> void:
	# Continuously update last known pos while hunting WITH line of sight
	if not is_hunting():
		return
	if not awareness_component.has_line_of_sight:
		return
	_stamp_last_known_position()


func _stamp_last_known_position() -> void:
	if awareness_component.player_node == null:
		return
	var new_pos := awareness_component.player_node.global_position
	if new_pos.is_equal_approx(last_known_position):
		return
	last_known_position = new_pos
	emit_signal("last_known_position_updated", last_known_position)


# ─────────────────────────────────────────
#  PRIVATE — SIGNAL CALLBACKS
# ─────────────────────────────────────────

func _on_awareness_changed(value: float) -> void:
	_evaluate_state_from_awareness(value)


func _on_los_gained() -> void:
	_contact_lost = false
	_reset_decay()

	if current_state == AlertState.ALERTED \
	or current_state == AlertState.FULL_ALERT:
		_stamp_last_known_position()


func _on_los_lost() -> void:
	# Mark contact lost — decay timers can now begin
	if current_state == AlertState.ALERTED:
		_contact_lost = true
		_begin_decay_for_current_state()


func _on_player_entered_zone(_zone: StealthZoneComponent) -> void:
	_player_in_zone = true
	_full_alert_clear_timer = 0.0   # reset clear timer — player is back


func _on_player_exited_zone(_zone: StealthZoneComponent) -> void:
	_player_in_zone = false
	# Full alert clear timer will begin in _tick_full_alert_clear
