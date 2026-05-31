extends Node
class_name ThreatCeilingComponent

# ─────────────────────────────────────────
#  THREAT CEILING COMPONENT  (on District)
#  Tracks the player's repeated tactics.
#  When a tactic hits its threshold the
#  district telegraphs an adaptation,
#  waits 90 seconds, then deploys it.
#  The city forgets slowly on re-entry.
# ─────────────────────────────────────────

# ── Tactic Types ──────────────────────────
enum TacticType {
	GRAPPLE_ENTRY,    # threshold 3 → anti-grapple nets
	EMP_USE,          # threshold 2 → surge-armoured guards
	AERIAL_TAKEDOWN   # threshold 2 → overhead mesh panels
}

# ── Adaptation States ─────────────────────
enum AdaptationState {
	INACTIVE,     # threshold not yet reached
	TELEGRAPHED,  # threshold crossed — 90s window open
	DEPLOYED      # adaptation is live in the world
}

# ── Constants ─────────────────────────────
const TELEGRAPH_WINDOW:   float = 90.0   # seconds before adaptation deploys
const FREEZE_DURATION:    float = 90.0   # tactician neutralised freeze window
const RE_ENTRY_DECAY:     int   = 1      # tactic counts drop by this on re-entry

# ── Tactic Thresholds ─────────────────────
const THRESHOLDS: Dictionary = {
	TacticType.GRAPPLE_ENTRY:   3,
	TacticType.EMP_USE:         2,
	TacticType.AERIAL_TAKEDOWN: 2
}

# ── Adaptation Labels ─────────────────────
# Human-readable names for signals and debug
const ADAPTATION_NAMES: Dictionary = {
	TacticType.GRAPPLE_ENTRY:   "anti_grapple_nets",
	TacticType.EMP_USE:         "surge_armoured_guards",
	TacticType.AERIAL_TAKEDOWN: "overhead_mesh_panels"
}

# ── Signals ───────────────────────────────
signal tactic_registered(tactic: TacticType, new_count: int, threshold: int)
signal adaptation_telegraphed(tactic: TacticType, adaptation_name: String, window: float)
signal adaptation_deployed(tactic: TacticType, adaptation_name: String)
signal adaptation_cancelled(tactic: TacticType, adaptation_name: String)
signal ceiling_frozen(duration: float)
signal ceiling_unfrozen
signal ceiling_reset(tactic: TacticType, new_count: int)

# ── Exports ───────────────────────────────
@export var district_name: String = "District_01"

# ── State ─────────────────────────────────
# Tactic counts — how many times each tactic has been used this visit
var _counts: Dictionary = {
	TacticType.GRAPPLE_ENTRY:   0,
	TacticType.EMP_USE:         0,
	TacticType.AERIAL_TAKEDOWN: 0
}

# Adaptation states per tactic
var _adaptation_states: Dictionary = {
	TacticType.GRAPPLE_ENTRY:   AdaptationState.INACTIVE,
	TacticType.EMP_USE:         AdaptationState.INACTIVE,
	TacticType.AERIAL_TAKEDOWN: AdaptationState.INACTIVE
}

# Telegraph timers — count down to zero, then adaptation deploys
var _telegraph_timers: Dictionary = {
	TacticType.GRAPPLE_ENTRY:   0.0,
	TacticType.EMP_USE:         0.0,
	TacticType.AERIAL_TAKEDOWN: 0.0
}

var _freeze_timer:      float = 0.0
var _ceiling_frozen:    bool  = false
var _player_in_district: bool = false


# ─────────────────────────────────────────
#  GODOT CALLBACKS
# ─────────────────────────────────────────

func _ready() -> void:
	var parent := get_parent()
	# Expects an Area3D parent to detect player entering/leaving the district
	if parent is Area3D:
		parent.body_entered.connect(_on_body_entered)
		parent.body_exited.connect(_on_body_exited)
	else:
		push_warning("ThreatCeilingComponent: parent is not an Area3D. \
			Re-entry decay will not trigger automatically.")


func _process(delta: float) -> void:
	_tick_freeze(delta)
	_tick_telegraph_timers(delta)


# ─────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────

## Called by player action systems whenever a tracked tactic is used.
## e.g. grapple_component calls register_tactic(TacticType.GRAPPLE_ENTRY)
func register_tactic(tactic: TacticType) -> void:
	if _ceiling_frozen:
		return   # Tactician neutralised — district is not learning right now

	if _adaptation_states[tactic] == AdaptationState.DEPLOYED:
		return   # Already adapted — no point counting further

	_counts[tactic] += 1
	var count:     int = _counts[tactic]
	var threshold: int = THRESHOLDS[tactic]

	emit_signal("tactic_registered", tactic, count, threshold)

	# Check if we just crossed the threshold
	if count >= threshold \
	and _adaptation_states[tactic] == AdaptationState.INACTIVE:
		_begin_telegraph(tactic)


## Called when the player neutralises the district Tactician.
## Freezes the ceiling — no new adaptations can trigger for 90s.
## Telegraphs already in progress are paused.
func neutralise_tactician() -> void:
	_freeze_timer    = FREEZE_DURATION
	_ceiling_frozen  = true
	emit_signal("ceiling_frozen", FREEZE_DURATION)

	# Pause all active telegraph timers by storing them as-is —
	# _tick_telegraph_timers checks _ceiling_frozen and skips ticking


## Returns true if a specific adaptation is currently live.
func is_deployed(tactic: TacticType) -> bool:
	return _adaptation_states[tactic] == AdaptationState.DEPLOYED


## Returns the current tactic count for a given type.
func get_count(tactic: TacticType) -> int:
	return _counts[tactic]


## Returns seconds remaining in the telegraph window for a tactic.
## Returns 0.0 if not currently telegraphed.
func get_telegraph_remaining(tactic: TacticType) -> float:
	if _adaptation_states[tactic] != AdaptationState.TELEGRAPHED:
		return 0.0
	return _telegraph_timers[tactic]


## Returns whether the ceiling is currently frozen.
func is_frozen() -> bool:
	return _ceiling_frozen


# ─────────────────────────────────────────
#  PRIVATE — TELEGRAPH AND DEPLOYMENT
# ─────────────────────────────────────────

func _begin_telegraph(tactic: TacticType) -> void:
	_adaptation_states[tactic] = AdaptationState.TELEGRAPHED
	_telegraph_timers[tactic]  = TELEGRAPH_WINDOW

	# Guards radio aloud — player has 90s to act before adaptation appears
	emit_signal("adaptation_telegraphed",
		tactic,
		ADAPTATION_NAMES[tactic],
		TELEGRAPH_WINDOW
	)


func _deploy_adaptation(tactic: TacticType) -> void:
	_adaptation_states[tactic] = AdaptationState.DEPLOYED
	_telegraph_timers[tactic]  = 0.0

	emit_signal("adaptation_deployed", tactic, ADAPTATION_NAMES[tactic])


func _cancel_telegraph(tactic: TacticType) -> void:
	if _adaptation_states[tactic] != AdaptationState.TELEGRAPHED:
		return
	_adaptation_states[tactic] = AdaptationState.INACTIVE
	_telegraph_timers[tactic]  = 0.0
	emit_signal("adaptation_cancelled", tactic, ADAPTATION_NAMES[tactic])


# ─────────────────────────────────────────
#  PRIVATE — TIMERS
# ─────────────────────────────────────────

func _tick_telegraph_timers(delta: float) -> void:
	if _ceiling_frozen:
		return   # All telegraph timers paused while frozen

	for tactic in _telegraph_timers.keys():
		if _adaptation_states[tactic] != AdaptationState.TELEGRAPHED:
			continue

		_telegraph_timers[tactic] -= delta

		if _telegraph_timers[tactic] <= 0.0:
			_deploy_adaptation(tactic)


func _tick_freeze(delta: float) -> void:
	if not _ceiling_frozen:
		return

	_freeze_timer -= delta

	if _freeze_timer <= 0.0:
		_freeze_timer   = 0.0
		_ceiling_frozen = false
		emit_signal("ceiling_unfrozen")


# ─────────────────────────────────────────
#  PRIVATE — RE-ENTRY DECAY
#  "The city forgets slowly."
#  Each re-entry drops all tactic counts
#  by RE_ENTRY_DECAY (default 1).
#  Deployed adaptations step back to
#  TELEGRAPHED. Telegraphed steps back to
#  INACTIVE if count drops below threshold.
# ─────────────────────────────────────────

func _apply_re_entry_decay() -> void:
	for tactic in _counts.keys():
		var old_count: int = _counts[tactic]
		_counts[tactic] = maxi(old_count - RE_ENTRY_DECAY, 0)
		var new_count: int = _counts[tactic]

		emit_signal("ceiling_reset", tactic, new_count)

		# Step deployed adaptation back to telegraphed
		if _adaptation_states[tactic] == AdaptationState.DEPLOYED:
			_adaptation_states[tactic] = AdaptationState.TELEGRAPHED
			_telegraph_timers[tactic]  = TELEGRAPH_WINDOW
			emit_signal("adaptation_telegraphed",
				tactic,
				ADAPTATION_NAMES[tactic],
				TELEGRAPH_WINDOW
			)

		# Cancel a live telegraph if count dropped below threshold
		elif _adaptation_states[tactic] == AdaptationState.TELEGRAPHED:
			if new_count < THRESHOLDS[tactic]:
				_cancel_telegraph(tactic)


# ─────────────────────────────────────────
#  PRIVATE — DISTRICT ENTRY / EXIT
# ─────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	# Only apply decay on re-entry (not first entry)
	if _player_in_district:
		return

	var was_outside := not _player_in_district
	_player_in_district = true

	if was_outside:
		_apply_re_entry_decay()


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_district = false
