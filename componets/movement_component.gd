extends Node
class_name MovementComponent


# ---------------------------------------------------------------------------
## Add a reference to the mesh or visual container node
# ---------------------------------------------------------------------------
@export var visual_node: Node3D
@export var rotation_speed := 10.0 # Controls how snappy the turn is
@export var move_speed     := 8.0
@export var acceleration   := 20.0
@export var jump_impulse   := 12.0
@export var stopping_speed := 1.0
@export var gravity        := -30.0
# ---------------------------------------------------------------------------

var get_camera_basis: Callable

var _raw_input   := Vector2.ZERO
var _jump_queued := false

@onready var stealth_component: StealthComponent = get_parent().get_parent().get_node_or_null("Components/stealth_component")

# ---------------------------------------------------------------------------
## Grappling hook
# ---------------------------------------------------------------------------
func _ready() -> void:
	var grapple = owner.get_node("Components/grapple_component")
	grapple.grapple_started.connect(_on_grapple_started)
	grapple.grapple_cancelled.connect(_on_grapple_completed)

var movement_paused: bool = false

func _on_grapple_started(_target):
	movement_paused = true

func _on_grapple_completed():
	movement_paused = false  
	# climb prompt appears here — movement stays paused until climb finishes
# ---------------------------------------------------------------------------

func set_move_input(raw: Vector2) -> void:
	_raw_input = raw

func queue_jump() -> void:
	_jump_queued = true

func _physics_process(delta: float) -> void:
	
	if movement_paused:
		return
	
	var character: CharacterBody3D = owner

	var cam_basis: Basis = get_camera_basis.call()
	var forward := cam_basis.z
	var right   := cam_basis.x
	var move_dir := forward * _raw_input.y + right * _raw_input.x
	move_dir.y = 0.0
	move_dir   = move_dir.normalized()

	var y_vel := character.velocity.y
	character.velocity.y = 0.0
	character.velocity = character.velocity.move_toward(
		move_dir * move_speed, acceleration * delta
	)
	if is_equal_approx(move_dir.length_squared(), 0.0) \
	and character.velocity.length_squared() < stopping_speed:
		character.velocity = Vector3.ZERO

	character.velocity.y = y_vel + gravity * delta

	if _jump_queued and character.is_on_floor():
		character.velocity.y += jump_impulse

	_jump_queued = false
	character.move_and_slide()
	
	# ---------------------------------------------------------------------------
	## Stealth LOGIC
	# ---------------------------------------------------------------------------
	var player := get_parent().get_parent() as CharacterBody3D  # gets the CharacterBody3D that owns this component

	# Normalise current speed against move_speed (0.0–1.0)
	var speed_fraction: float = player.velocity.length() / move_speed
	stealth_component.set_movement_speed(clampf(speed_fraction, 0.0, 1.0))
	
	#use when crouching is built
	#if is_crouching:
	#sound = 0.15
	
	# Sound — default walking, spikes when sprinting
	var speed := (get_parent().get_parent() as CharacterBody3D).velocity.length()
	var sound: float

	if speed < 0.1:
		sound = 0.0          # standing still — silent
	elif speed > move_speed * 0.8:
		sound = 1.0          # sprinting — maximum noise
	else:
		sound = 0.6          # walking

	stealth_component.set_sound_output(sound)
	
# ---------------------------------------------------------------------------
## ROTATION LOGIC
# ---------------------------------------------------------------------------
	# Only rotate if the player is actively trying to move
	if visual_node and move_dir.length_squared() > 0.001:
		# 1. Calculate where the mesh should look. 
		# We look away from move_dir if your mesh natively faces Z-forward.
		# If your mesh faces backward after this, change '-' to '+'
		var target_pos := visual_node.global_position - move_dir
		
		# 2. Get the target transform basis using looking_at
		var target_transform := visual_node.global_transform.looking_at(target_pos, Vector3.UP)
		
		# 3. Smoothly interpolate (Slerp) the current rotation to the target rotation
		visual_node.global_transform.basis = visual_node.global_transform.basis.slerp(
			target_transform.basis, 
			rotation_speed * delta
		).orthonormalized() # Keeps the scale from breaking over time
# ---------------------------------------------------------------------------
	
	
