# Attach to: Components/grapple_component (Node3D) inside your Player3DTemplate
# Requires:  - GrapplePoint nodes in the level added to the "grapple_points" group
#            - Input action "grapple" defined in Project Settings > Input Map
#            - Camera3D at path: CameraPivot/SpringArm3D/Camera3D (relative to owner)
class_name GrappleComponent
extends Node3D

# ---------------------------------------------------------------------------
## Signals — other components (e.g. movement_component) listen to these
# ---------------------------------------------------------------------------
signal grapple_started(target: GrapplePoint)   # fired when travel begins
signal grapple_completed                        # fired when player arrives at ledge
signal grapple_cancelled                        # fired when climb finishes, resume movement

# ---------------------------------------------------------------------------
## Inspector exports — tune these per your game feel
# ---------------------------------------------------------------------------
# Detection
@export_group("Detection")
@export var max_range: float = 25.0            # max grapple distance in metres
@export var detection_angle: float = 45.0      # degrees from camera centre still valid

# Travel
@export_group("Travel")
@export var travel_duration: float = 0.6       # seconds to reach destination
@export var arc_depth_ratio: float = 0.2       # how deep the arc dips (0 = straight line)

@export_group("Visuals")
@export var highlight_material: Material        # glowing material shown on candidate point

# ---------------------------------------------------------------------------
## Internal state
# ---------------------------------------------------------------------------
# References
var player: CharacterBody3D
var camera: Camera3D

# Detection
var all_grapple_points: Array[GrapplePoint] = []
var current_candidate: GrapplePoint = null

# Travel
var is_grappling: bool = false
var grapple_target: GrapplePoint = null
var travel_t: float = 0.0
var travel_start: Vector3 = Vector3.ZERO
var travel_control: Vector3 = Vector3.ZERO     # bezier middle control point

# Hang / Climb
var is_hanging: bool = false

# ---------------------------------------------------------------------------
## Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	# owner is Player3DTemplate — the CharacterBody3D at the root
	player = owner as CharacterBody3D
	camera = owner.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D

	if not player:
		push_error("GrappleComponent: owner is not a CharacterBody3D")
		return
	if not camera:
		push_error("GrappleComponent: could not find Camera3D at CameraPivot/SpringArm3D/Camera3D")
		return

	_register_all_points()


func _physics_process(delta: float) -> void:
	# Detection runs every frame so the highlight stays responsive
	if not is_grappling and not is_hanging:
		_update_candidate()

	# Travel update moves the player along the arc each frame
	if is_grappling:
		_update_travel(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("grapple"):
		if is_hanging:
			# second press while hanging = climb up
			attempt_climb()
		else:
			# first press = fire hook
			attempt_grapple()


# ---------------------------------------------------------------------------
## SYSTEM 1 — Grapple Point Registration
# All GrapplePoint nodes in the level must be in the "grapple_points" group
# ---------------------------------------------------------------------------
func _register_all_points() -> void:
	all_grapple_points.clear()
	for node in get_tree().get_nodes_in_group("grapple_points"):
		if node is GrapplePoint:
			all_grapple_points.append(node)


# Call this if you dynamically add/remove grapple points at runtime
func refresh_grapple_points() -> void:
	_register_all_points()


# ---------------------------------------------------------------------------
## SYSTEM 2 — Detection: find and highlight the best candidate each frame
# ---------------------------------------------------------------------------
func _update_candidate() -> void:
	var best: GrapplePoint = null
	var best_score: float = -1.0

	for point in all_grapple_points:
		var score = _score_point(point)
		if score > best_score:
			best_score = score
			best = point

	# Only accept the best candidate if nothing blocks line of sight
	if best != null and _has_line_of_sight(best):
		_set_candidate(best)
	else:
		_set_candidate(null)


func _score_point(point: GrapplePoint) -> float:
	var to_point: Vector3 = point.global_position - player.global_position
	var distance: float = to_point.length()

	# Reject if beyond max range
	if distance > max_range:
		return -1.0

	# Reject if behind the camera's forward direction
	var camera_forward: Vector3 = -camera.global_transform.basis.z
	var dot: float = camera_forward.dot(to_point.normalized())
	if dot < 0.0:
		return -1.0

	# angle_score: how centred on screen (dot remapped from -1..1 to 0..1)
	var angle_score: float = (dot + 1.0) / 2.0
	# distance_score: closer = higher score
	var distance_score: float = 1.0 - (distance / max_range)

	# Weight: player intent (angle) matters more than proximity
	return (angle_score * 0.7) + (distance_score * 0.3)


func _has_line_of_sight(point: GrapplePoint) -> bool:
	var space_state = get_world_3d().direct_space_state

	# Cast from chest height so floor geometry doesn't block it
	var origin: Vector3 = player.global_position + Vector3.UP * 1.0
	var target: Vector3 = point.global_position

	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [player]  # don't hit the player's own collider

	var result = space_state.intersect_ray(query)

	# Clear line of sight = nothing was hit, or what was hit IS the grapple point
	return result.is_empty() or result.collider == point


func _set_candidate(point: GrapplePoint) -> void:
	if point == current_candidate:
		return  # no change, skip the work

	# Remove highlight from the previous candidate
	if current_candidate != null:
		_set_highlight(current_candidate, false)

	current_candidate = point

	# Apply highlight to the new candidate
	if current_candidate != null:
		_set_highlight(current_candidate, true)


func _set_highlight(point: GrapplePoint, enabled: bool) -> void:
	# GrapplePoint scene should have a MeshInstance3D child for the editor marker
	var mesh = point.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	mesh.visible = enabled
	if enabled and highlight_material != null:
		mesh.material_override = highlight_material
	else:
		mesh.material_override = null


# ---------------------------------------------------------------------------
## SYSTEM 3 — Travel: move player along a bezier arc to the grapple point
# ---------------------------------------------------------------------------
func attempt_grapple() -> void:
	if current_candidate == null or is_grappling:
		return

	grapple_target = current_candidate
	is_grappling = true
	travel_t = 0.0
	travel_start = player.global_position

	# Control point sits at the midpoint, pulled downward
	# The dip depth is proportional to the total distance so it scales naturally
	var mid: Vector3 = travel_start.lerp(grapple_target.global_position, 0.5)
	var arc_depth: float = travel_start.distance_to(grapple_target.global_position) * arc_depth_ratio
	travel_control = mid + Vector3.DOWN * arc_depth

	emit_signal("grapple_started", grapple_target)


func _update_travel(delta: float) -> void:
	travel_t += delta / travel_duration

	if travel_t >= 1.0:
		travel_t = 1.0
		_arrive_at_destination()
		return

	# Quadratic bezier: (1-t)²·P0 + 2(1-t)t·P1 + t²·P2
	var t: float = _ease_in_out(travel_t)
	var pos: Vector3 = \
		(1.0 - t) * (1.0 - t) * travel_start \
		+ 2.0 * (1.0 - t) * t * travel_control \
		+ t * t * grapple_target.global_position

	# Directly set position — bypasses physics intentionally during travel
	player.global_position = pos


func _ease_in_out(t: float) -> float:
	# Smoothstep: fast start, decelerates on arrival
	# Gives the feel of a rope snapping taut then gently landing
	return t * t * (3.0 - 2.0 * t)


func _arrive_at_destination() -> void:
	is_grappling = false
	# Snap to exact destination to avoid any floating point drift
	player.global_position = grapple_target.global_position
	emit_signal("grapple_completed")
	_start_ledge_hang()


# ---------------------------------------------------------------------------
## SYSTEM 4 — Ledge Hang and Climb
# ---------------------------------------------------------------------------
func _start_ledge_hang() -> void:
	# Only enter hang state for LEDGE type points
	if grapple_target.type != GrapplePoint.Type.LEDGE:
		# For other types (ZIPLINE, HANG) you'd add their logic here
		return

	is_hanging = true

	# Rotate player to face away from the building surface
	var look_target: Vector3 = player.global_position + grapple_target.get_surface_normal()
	player.look_at(look_target, Vector3.UP)


func attempt_climb() -> void:
	if not is_hanging or grapple_target == null:
		return

	var climb_pos: Vector3 = grapple_target.get_climb_position()

	# Tween the player up and onto the roof in two stages:
	# 1. Rise up to roof height
	# 2. Move forward onto the surface
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# Stage 1: lift up
	var lift_pos: Vector3 = Vector3(
		player.global_position.x,
		climb_pos.y,
		player.global_position.z
	)
	tween.tween_property(player, "global_position", lift_pos, 0.2)

	# Stage 2: step forward onto roof
	tween.tween_property(player, "global_position", climb_pos, 0.2)

	# Cleanup once the tween finishes
	tween.tween_callback(_finish_climb)


func _finish_climb() -> void:
	is_hanging = false
	grapple_target = null
	# Signal movement_component to resume normal control
	emit_signal("grapple_cancelled")

# ---------------------------------------------------------------------------
## Stealth grappling
# ---------------------------------------------------------------------------
func _on_grapple_landed() -> void:
	var district := _get_current_district()
	if district:
		district.register_tactic(ThreatCeilingComponent.TacticType.GRAPPLE_ENTRY)

# Helper — finds the district component from the player's current zone
func _get_current_district() -> ThreatCeilingComponent:
	var districts := get_tree().get_nodes_in_group("district")
	for d in districts:
		var ceiling := d.get_node_or_null("threat_ceiling_component")
		if ceiling and ceiling._player_in_district:
			return ceiling
	return null
