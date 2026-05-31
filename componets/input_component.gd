extends Node
class_name InputComponent

# ---------------------------------------------------------------------------
## Emitted every frame with the raw WASD/stick vector.
# ---------------------------------------------------------------------------
signal move_input_changed(direction: Vector2)
# ---------------------------------------------------------------------------
## Emitted on mouse motion (only when captured).
# ---------------------------------------------------------------------------
signal look_input_changed(delta: Vector2)
# ---------------------------------------------------------------------------
## Emitted once when jump is pressed.
# ---------------------------------------------------------------------------
signal jump_pressed
# ---------------------------------------------------------------------------
## sensitivities for mouse and joystick.
# ---------------------------------------------------------------------------
@export var mouse_sensitivity := 0.25
@export var joystick_sensitivity := 1.5
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion \
	and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		look_input_changed.emit(event.relative * mouse_sensitivity)
		

# ---------------------------------------------------------------------------
# Grappling hook 
# ---------------------------------------------------------------------------
	if event.is_action_pressed("grapple"):
		# tell whoever is listening
		Input.action_press("grapple")  # or emit a signal
# ---------------------------------------------------------------------------


func _process(_delta: float) -> void:
	var raw := Input.get_vector(
		"move_left", "move_right", "move_up", "move_down", 0.4
	)
	move_input_changed.emit(raw)

# ---------------------------------------------------------------------------
## RIGHT STICK CAMERA LOOK
# ---------------------------------------------------------------------------
	var look_input := Input.get_vector(
		"look_left",
		"look_right",
		"look_up",
		"look_down",
	)
# ---------------------------------------------------------------------------
## Only emit if stick is actually moving
# ---------------------------------------------------------------------------

	if look_input.length() > 0.0:

		look_input_changed.emit(
			look_input * joystick_sensitivity
		)
# ---------------------------------------------------------------------------
## Jump 
# ---------------------------------------------------------------------------
	if Input.is_action_just_pressed("jump"):
		jump_pressed.emit()
