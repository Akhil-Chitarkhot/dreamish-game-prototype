extends Node
class_name LowHealthFXComponent

# ─────────────────────────────────────────
#  LOW HEALTH FX COMPONENT
#  A pure reactor. Owns no game state.
#  Listens to health_component signals and
#  coordinates the three HP-1 feedback
#  layers: limp animation, heartbeat audio,
#  and screen-edge vignette.
#
#  Each FX layer is isolated in its own
#  method — swap or stub any one of them
#  without touching the others.
# ─────────────────────────────────────────

# ─────────────────────────────────────────
## Signals
## Emitted so enemies, dialogue systems, and
## other listeners can react to critical state
## without coupling to health_component directly.
# ─────────────────────────────────────────
signal critical_state_entered
signal critical_state_exited
# ─────────────────────────────────────────
## Component Reference
# ─────────────────────────────────────────
@export var health_component: HealthComponent

# ─────────────────────────────────────────
## FX Node References
## The player's AnimationTree node.
## Assign in Inspector.
# ─────────────────────────────────────────
@export var animation_tree: AnimationTree

# ─────────────────────────────────────────
## Looping heartbeat AudioStreamPlayer.
## Assign in Inspector.
# ─────────────────────────────────────────
@export var heartbeat_audio: AudioStreamPlayer

# ─────────────────────────────────────────
## A CanvasLayer > ColorRect with a vignette
## ShaderMaterial on it. Assign in Inspector.
# ─────────────────────────────────────────
@export var vignette_overlay: ColorRect

# ─────────────────────────────────────────
## Animation Tree Parameters
## The blend parameter path in your AnimationTree
## that drives the limp animation blend.
## Example: "parameters/limp_blend/blend_amount"
# ─────────────────────────────────────────
@export var limp_blend_param: String = "parameters/limp_blend/blend_amount"

# ─────────────────────────────────────────
## Vignette Shader Parameter
## The shader uniform name that controls
## vignette intensity (0.0 = off, 1.0 = full).
# ─────────────────────────────────────────
@export var vignette_intensity_param: String = "intensity"

# ─────────────────────────────────────────
## Audio
## Volume in dB when critical (audible).
# ─────────────────────────────────────────
@export var heartbeat_volume_db: float = -6.0

# ─────────────────────────────────────────
## State
# ─────────────────────────────────────────
var _is_critical: bool = false


# ─────────────────────────────────────────
#  GODOT CALLBACKS
# ─────────────────────────────────────────

func _ready() -> void:
	assert(health_component != null, "LowHealthFXComponent: health_component not assigned.")

	health_component.hp_critical.connect(_on_hp_critical)
	health_component.hp_changed.connect(_on_hp_changed)

	# Ensure all FX start in their off state
	_set_vignette(false)
	_set_heartbeat(false)
	_set_limp(false)


# ─────────────────────────────────────────
#  PRIVATE — SIGNAL CALLBACKS
# ─────────────────────────────────────────

func _on_hp_critical() -> void:
	if _is_critical:
		return   # already in critical state, don't double-fire

	_is_critical = true

	_set_limp(true)
	_set_heartbeat(true)
	_set_vignette(true)

	emit_signal("critical_state_entered")


func _on_hp_changed(new_hp: int, _max_hp: int) -> void:
	# If health recovered above 1, exit the critical state
	if _is_critical and new_hp > 1:
		_is_critical = false

		_set_limp(false)
		_set_heartbeat(false)

		# Vignette fades out rather than snapping off
		_fade_vignette_out()

		emit_signal("critical_state_exited")


# ─────────────────────────────────────────
#  PRIVATE — FX LAYERS
#  Each layer is self-contained.
#  Stub, replace, or extend any one
#  independently of the others.
# ─────────────────────────────────────────

func _set_limp(active: bool) -> void:
	if animation_tree == null:
		push_warning("LowHealthFXComponent: animation_tree not assigned — limp skipped.")
		return

	# Blend to 1.0 for full limp, 0.0 to remove it.
	# Your AnimationTree needs a BlendSpace1D or Blend node
	# mapped to this parameter path.
	var target: float = 1.0 if active else 0.0
	animation_tree.set(limp_blend_param, target)


func _set_heartbeat(active: bool) -> void:
	if heartbeat_audio == null:
		push_warning("LowHealthFXComponent: heartbeat_audio not assigned — audio skipped.")
		return

	if active:
		heartbeat_audio.volume_db = heartbeat_volume_db
		if not heartbeat_audio.playing:
			heartbeat_audio.play()
	else:
		heartbeat_audio.stop()


func _set_vignette(active: bool) -> void:
	if vignette_overlay == null:
		push_warning("LowHealthFXComponent: vignette_overlay not assigned — vignette skipped.")
		return

	var mat := vignette_overlay.material as ShaderMaterial
	if mat == null:
		push_warning("LowHealthFXComponent: vignette_overlay has no ShaderMaterial.")
		return

	# Snap on instantly — the vignette is permanent while critical
	mat.set_shader_parameter(vignette_intensity_param, 1.0 if active else 0.0)
	vignette_overlay.visible = active


func _fade_vignette_out() -> void:
	if vignette_overlay == null:
		return

	var mat := vignette_overlay.material as ShaderMaterial
	if mat == null:
		return

	# Smooth fade over 1.5 seconds using a tween
	var tween := create_tween()
	tween.tween_method(
		func(v: float) -> void:
			mat.set_shader_parameter(vignette_intensity_param, v),
		1.0,   # from
		0.0,   # to
		1.5    # duration in seconds
	)
	tween.tween_callback(func() -> void: vignette_overlay.visible = false)
