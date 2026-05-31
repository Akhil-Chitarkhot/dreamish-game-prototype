extends Node
class_name CameraComponent

# ---------------------------------------------------------------------------
## Camera rotaion limits.
# ---------------------------------------------------------------------------
@export var tilt_upper_limit :=  deg_to_rad(20)
@export var tilt_lower_limit := deg_to_rad(-50)

# ---------------------------------------------------------------------------
## Assign in editor or via player.gd
# ---------------------------------------------------------------------------
@export var camera_pivot: Node3D
@export var camera: Camera3D

var _queued_delta := Vector2.ZERO

func _ready() -> void:
	camera_pivot = %CameraPivot
	camera = %Camera3D

# ---------------------------------------------------------------------------
## Called by InputComponent's look_input_changed signal.
# ---------------------------------------------------------------------------
func on_look_input(raw_delta: Vector2) -> void:
	_queued_delta += raw_delta

func _physics_process(delta: float) -> void:
	camera_pivot.rotation.y += -_queued_delta.x * delta
	camera_pivot.rotation.x += -_queued_delta.y * delta
	camera_pivot.rotation.x  = clamp(
		camera_pivot.rotation.x,
		tilt_lower_limit,
		tilt_upper_limit
	)
	
	_queued_delta = Vector2.ZERO

# ---------------------------------------------------------------------------
## Convenience: other components can ask "which way is the camera facing?"
# ---------------------------------------------------------------------------
func get_camera_basis() -> Basis:
	return camera.global_basis
