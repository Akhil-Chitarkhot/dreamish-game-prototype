extends Node
class_name AwarenessComponent

# ─────────────────────────────────────────
#  AWARENESS COMPONENT  (on each Enemy)
#  Runs the three-input detection formula:
#  AWARENESS = (light×0.5) + (sound×0.3) + (motion×0.2)
#  Handles line-of-sight, detection range,
#  and dog-variant weighting.
#  Fires signals when thresholds are crossed.
# ─────────────────────────────────────────

# ── Formula Weights ───────────────────────
const LIGHT_WEIGHT:  float = 0.5
const SOUND_WEIGHT:  float = 0.3
const MOTION_WEIGHT: float = 0.2

# Dog variant — light ignored, motion dominant
const DOG_SOUND_WEIGHT:  float = 0.4
const DOG_MOTION_WEIGHT: float = 0.6

# ── Signals ───────────────────────────────
signal awareness_changed(value: float)
signal awareness_threshold_crossed(threshold: float)   # rose above threshold
signal awareness_threshold_cleared(threshold: float)   # dropped below threshold
signal line_of_sight_gained
signal line_of_sight_lost

# ── Exports ───────────────────────────────
## The zone this enemy patrols in.
## Its detection_threshold is used as the trigger point.
## Leave empty to use default_threshold below.
@export var patrol_zone: StealthZoneComponent

## Fallback threshold when no patrol zone is assigned.
@export_range(0.0, 1.0) var default_threshold: float = 0.65

## How far this enemy can detect the player (metres).
@export var detection_range: float = 20.0

## Height offset from the enemy's origin to its eyes.
@export var eye_offset: Vector3 = Vector3(0.0, 1.6, 0.0)

## Dog/animal variant — ignores light, uses motion-dominant weights.
@export var is_dog: bool = false

## How often (seconds) the LoS raycast fires.
## 0.1 = 10 checks per second — good balance of accuracy and performance.
@export var los_check_interval: float = 0.1

# ── Runtime References ────────────────────
## Set by the enemy's main script in _ready().
## The sensor is inert until this is assigned.
var stealth_component: StealthComponent = null
var player_node: Node3D = null

# ── State ─────────────────────────────────
var current_awareness: float  = 0.0
var has_line_of_sight: bool   = false
var player_in_range:   bool   = false

var _above_threshold:  bool   = false
var _los_timer:        float  = 0.0


# ─────────────────────────────────────────
#  GODOT CALLBACKS
# ─────────────────────────────────────────

func _ready() -> void:
	# Try to auto-find player via group if not set manually
	if player_node == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]

	if player_node and stealth_component == null:
		stealth_component = player_node.get_node_or_null("Components/stealth_component")

	# Listen to stealth value changes — recalculate on every update
	if stealth_component:
		stealth_component.stealth_values_changed.connect(_on_stealth_values_changed)


func _physics_process(delta: float) -> void:
	if not _has_valid_references():
		return

	_update_range_check()

	if not player_in_range:
		_decay_awareness_to_zero(delta)
		return

	_tick_los_check(delta)
	_recalculate_awareness()


# ─────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────

## Returns the active detection threshold —
## from the patrol zone if assigned, otherwise the export default.
func get_threshold() -> float:
	if patrol_zone != null:
		return patrol_zone.detection_threshold
	return default_threshold


## Returns current awareness as a 0–1 fraction.
func get_awareness_fraction() -> float:
	return current_awareness


## Allows the alert_state_machine to hard-reset awareness
## e.g. when a guard is knocked out.
func reset_awareness() -> void:
	_set_awareness(0.0)
	has_line_of_sight = false
	_above_threshold  = false


# ─────────────────────────────────────────
#  PRIVATE — RANGE AND LOS
# ─────────────────────────────────────────

func _update_range_check() -> void:
	if player_node == null:
		return
	var dist: float = (get_parent() as Node3D).global_position.distance_to(player_node.global_position)
	player_in_range = dist <= detection_range


func _tick_los_check(delta: float) -> void:
	_los_timer -= delta
	if _los_timer > 0.0:
		return
	_los_timer = los_check_interval
	_run_los_raycast()


func _run_los_raycast() -> void:
	var parent := get_parent() as Node3D
	var space  := parent.get_world_3d().direct_space_state

	if space == null:
		return

	var enemy_eye_pos: Vector3 = parent.global_position + eye_offset
	var player_pos:    Vector3 = player_node.global_position + Vector3(0, 1.0, 0)

	var query := PhysicsRayQueryParameters3D.create(enemy_eye_pos, player_pos)
	query.exclude = [parent.get_rid()]

	var result := space.intersect_ray(query)
	var had_los := has_line_of_sight

	if result.is_empty():
		has_line_of_sight = true
	elif result.collider == player_node:
		has_line_of_sight = true
	else:
		has_line_of_sight = false

	if has_line_of_sight and not had_los:
		emit_signal("line_of_sight_gained")
	elif not has_line_of_sight and had_los:
		emit_signal("line_of_sight_lost")


# ─────────────────────────────────────────
#  PRIVATE — FORMULA
# ─────────────────────────────────────────

func _recalculate_awareness() -> void:
	if stealth_component == null:
		return

	var values   := stealth_component.get_effective_values()
	var light    := values["light"]  as float
	var sound    := values["sound"]  as float
	var motion   := values["motion"] as float

	var awareness: float

	if is_dog:
		# Dog: ignores light entirely, sound and motion only
		awareness = (sound * DOG_SOUND_WEIGHT) + (motion * DOG_MOTION_WEIGHT)
	else:
		# Light only contributes when enemy has line of sight
		var effective_light := light if has_line_of_sight else 0.0
		awareness = (effective_light * LIGHT_WEIGHT) \
				  + (sound            * SOUND_WEIGHT)  \
				  + (motion           * MOTION_WEIGHT)

	_set_awareness(clampf(awareness, 0.0, 1.0))


func _decay_awareness_to_zero(delta: float) -> void:
	# When player leaves detection range, awareness fades passively.
	# The alert_state_machine owns the full decay logic —
	# this just prevents the formula from freezing at its last value.
	if current_awareness > 0.0:
		_set_awareness(maxf(current_awareness - delta * 0.5, 0.0))


func _set_awareness(value: float) -> void:
	var prev      := current_awareness
	current_awareness = value

	if current_awareness != prev:
		emit_signal("awareness_changed", current_awareness)

	var threshold := get_threshold()

	# Crossed above threshold
	if not _above_threshold and current_awareness >= threshold:
		_above_threshold = true
		emit_signal("awareness_threshold_crossed", threshold)

	# Dropped below threshold
	elif _above_threshold and current_awareness < threshold:
		_above_threshold = false
		emit_signal("awareness_threshold_cleared", threshold)


# ─────────────────────────────────────────
#  PRIVATE — SIGNAL CALLBACKS
# ─────────────────────────────────────────

func _on_stealth_values_changed(_light: float, _sound: float, _motion: float) -> void:
	# Stealth values changed — recalculate immediately if in range
	if player_in_range:
		_recalculate_awareness()


# ─────────────────────────────────────────
#  PRIVATE — GUARDS
# ─────────────────────────────────────────

func _has_valid_references() -> bool:
	return player_node != null and stealth_component != null
