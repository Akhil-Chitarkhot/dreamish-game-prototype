extends CharacterBody3D
class_name Guard

# ─────────────────────────────────────────
#  GUARD
#  Red capsule test enemy.
#  Patrols waypoints when unaware.
#  Reacts through all five alert states.
#  Driven entirely by alert_state_machine_component.
# ─────────────────────────────────────────

# ── Component References ──────────────────
@onready var awareness:    AwarenessComponent          = $awareness_component
@onready var alert_sm:     AlertStateMachineComponent  = $alert_state_machine_component
@onready var mesh:         MeshInstance3D              = $MeshInstance3D

# ── Patrol ────────────────────────────────
## Drag Node3D markers from the scene tree into this array in the Inspector.
@export var patrol_points: Array[Node3D] = []

# ── Movement Speeds ───────────────────────
@export var patrol_speed:     float = 2.5
@export var suspicious_speed: float = 1.5
@export var alerted_speed:    float = 5.5
@export var rotation_speed:   float = 8.0
@export var gravity:          float = -30.0

# ── Colours ───────────────────────────────
const COL_UNAWARE:    Color = Color(0.85, 0.1,  0.1 )   # red
const COL_SUSPICIOUS: Color = Color(1.0,  0.85, 0.0 )   # yellow
const COL_ALERTED:    Color = Color(1.0,  0.45, 0.0 )   # orange
const COL_FULL_ALERT: Color = Color(1.0,  1.0,  1.0 )   # white flash
const COL_WRAITH:     Color = Color(0.5,  0.0,  1.0 )   # purple

# ── Internal State ────────────────────────
var _current_state: AlertStateMachineComponent.AlertState = \
	AlertStateMachineComponent.AlertState.UNAWARE

var _patrol_index:         int     = 0
var _patrol_wait_timer:    float   = 0.0
var _patrol_waiting:       bool    = false
var _suspicious_look_timer:float   = 0.0
var _investigation_point:  Vector3 = Vector3.ZERO
var _search_timer:         float   = 0.0


# ─────────────────────────────────────────
#  GODOT CALLBACKS
# ─────────────────────────────────────────

func _ready() -> void:
	add_to_group("guard")
	_set_colour(COL_UNAWARE)

	alert_sm.state_changed.connect(_on_state_changed)
	alert_sm.last_known_position_updated.connect(_on_last_known_position_updated)
	alert_sm.partner_radio_called.connect(_on_partner_radio_called)
	alert_sm.lockdown_triggered.connect(_on_lockdown_triggered)
	alert_sm.body_found.connect(_on_body_found)


func _physics_process(delta: float) -> void:
	# Always apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	match _current_state:
		AlertStateMachineComponent.AlertState.UNAWARE:
			_tick_patrol(delta)
		AlertStateMachineComponent.AlertState.SUSPICIOUS:
			_tick_suspicious(delta)
		AlertStateMachineComponent.AlertState.ALERTED:
			_tick_alerted(delta)
		AlertStateMachineComponent.AlertState.FULL_ALERT:
			_tick_full_alert(delta)
		AlertStateMachineComponent.AlertState.WRAITH_PROTOCOL:
			_tick_wraith(delta)

	move_and_slide()


# ─────────────────────────────────────────
#  PATROL BEHAVIOUR (UNAWARE)
# ─────────────────────────────────────────

func _tick_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity.x = 0
		velocity.z = 0
		return

	# Wait briefly at each waypoint
	if _patrol_waiting:
		_patrol_wait_timer -= delta
		velocity.x = 0
		velocity.z = 0
		if _patrol_wait_timer <= 0.0:
			_patrol_waiting = false
			_advance_patrol_index()
		return

	var target := patrol_points[_patrol_index].global_position
	var dist   := global_position.distance_to(target)

	if dist < 0.4:
		# Reached waypoint — wait 1.5s then move to next
		_patrol_waiting    = true
		_patrol_wait_timer = 1.5
		velocity.x = 0
		velocity.z = 0
	else:
		_move_toward(target, patrol_speed, delta)


func _advance_patrol_index() -> void:
	_patrol_index = (_patrol_index + 1) % patrol_points.size()


# ─────────────────────────────────────────
#  SUSPICIOUS BEHAVIOUR
# ─────────────────────────────────────────

func _tick_suspicious(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

	# Face toward the investigation point
	if _investigation_point != Vector3.ZERO:
		_rotate_toward(_investigation_point, delta)

	# Slowly look left and right to sell the "searching" feel
	_suspicious_look_timer -= delta
	if _suspicious_look_timer <= 0.0:
		_suspicious_look_timer = 1.8
		# Flip investigation point slightly so guard scans
		_investigation_point = global_position + \
			(global_transform.basis.x * (1.0 if randf() > 0.5 else -1.0) * 3.0) + \
			global_transform.basis.z * -4.0


# ─────────────────────────────────────────
#  ALERTED BEHAVIOUR
# ─────────────────────────────────────────

func _tick_alerted(delta: float) -> void:
	var last_pos := alert_sm.last_known_position

	if last_pos == Vector3.ZERO:
		# No known position yet — stand and scan
		velocity.x = 0
		velocity.z = 0
		return

	var dist := global_position.distance_to(last_pos)

	if dist < 1.0:
		# Reached last known position — search nearby for a moment
		velocity.x = 0
		velocity.z = 0
		_search_timer += delta
		if _search_timer > 3.0:
			_search_timer = 0.0
			# Pick a random nearby search point
			var offset := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
			alert_sm.last_known_position = last_pos + offset
	else:
		_search_timer = 0.0
		_move_toward(last_pos, alerted_speed, delta)


# ─────────────────────────────────────────
#  FULL ALERT BEHAVIOUR
# ─────────────────────────────────────────

func _tick_full_alert(delta: float) -> void:
	# Same as alerted but faster — move directly to last known position
	# In a real game this would coordinate with other guards
	var last_pos := alert_sm.last_known_position

	if last_pos == Vector3.ZERO:
		velocity.x = 0
		velocity.z = 0
		return

	_move_toward(last_pos, alerted_speed * 1.3, delta)


# ─────────────────────────────────────────
#  WRAITH PROTOCOL BEHAVIOUR
# ─────────────────────────────────────────

func _tick_wraith(_delta: float) -> void:
	# Stands perfectly still — mirrors the player's counter timing
	# Placeholder for Act 3 elite behaviour
	velocity.x = 0
	velocity.z = 0


# ─────────────────────────────────────────
#  MOVEMENT HELPERS
# ─────────────────────────────────────────

func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var flat_target  := Vector3(target.x, global_position.y, target.z)
	var direction    := (flat_target - global_position).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	_rotate_toward(target, delta)


func _rotate_toward(target: Vector3, delta: float) -> void:
	var flat_target := Vector3(target.x, global_position.y, target.z)
	var direction   := (flat_target - global_position).normalized()

	if direction.length() < 0.1:
		return

	var target_angle := atan2(direction.x, direction.z)
	var current_angle := rotation.y

	rotation.y = lerp_angle(current_angle, target_angle, rotation_speed * delta)


# ─────────────────────────────────────────
#  SIGNAL HANDLERS
# ─────────────────────────────────────────

func _on_state_changed(
		_old: AlertStateMachineComponent.AlertState,
		new:  AlertStateMachineComponent.AlertState) -> void:

	_current_state = new

	match new:
		AlertStateMachineComponent.AlertState.UNAWARE:
			_set_colour(COL_UNAWARE)
			_search_timer = 0.0
			print("[Guard: %s] UNAWARE — resuming patrol" % name)

		AlertStateMachineComponent.AlertState.SUSPICIOUS:
			_set_colour(COL_SUSPICIOUS)
			_suspicious_look_timer = 0.0
			# Use the last known position as the starting look direction
			_investigation_point = alert_sm.last_known_position \
				if alert_sm.last_known_position != Vector3.ZERO \
				else global_position + (-global_transform.basis.z * 3.0)
			print("[Guard: %s] SUSPICIOUS — stopped and scanning" % name)

		AlertStateMachineComponent.AlertState.ALERTED:
			_set_colour(COL_ALERTED)
			_search_timer = 0.0
			print("[Guard: %s] ALERTED — hunting" % name)

		AlertStateMachineComponent.AlertState.FULL_ALERT:
			_set_colour(COL_FULL_ALERT)
			print("[Guard: %s] FULL ALERT — lockdown" % name)

		AlertStateMachineComponent.AlertState.WRAITH_PROTOCOL:
			_set_colour(COL_WRAITH)
			print("[Guard: %s] WRAITH PROTOCOL" % name)


func _on_last_known_position_updated(pos: Vector3) -> void:
	# Reset search timer so guard actively moves to new position
	_search_timer = 0.0
	print("[Guard: %s] Last known position → %s" % [name, str(pos.snapped(Vector3.ONE * 0.1))])


func _on_partner_radio_called(_state: AlertStateMachineComponent.AlertState) -> void:
	print("[Guard: %s] Radioing partner — waiting for convergence" % name)


func _on_lockdown_triggered() -> void:
	print("[Guard: %s] LOCKDOWN triggered" % name)


func _on_body_found() -> void:
	print("[Guard: %s] Body found — jumping to ALERTED" % name)


# ─────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────

func _set_colour(colour: Color) -> void:
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mesh.set_surface_override_material(0, mat)
