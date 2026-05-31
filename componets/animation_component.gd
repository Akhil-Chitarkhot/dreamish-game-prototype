extends Node

@export var animation_tree: AnimationTree
@export var stance_component: StanceComponent
@export var movement_component: Node
@export var combat_component: Node

@export var set_locomotion: AnimationSet
@export var set_combat: AnimationSet
@export var set_stealth: AnimationSet

const ROOT_TRANSITION := "parameters/transition_request"

var _active_set: AnimationSet
var _ready_to_animate := false

func _ready() -> void:
	# Guard — dont run until AnimationTree is fully set up
	if not animation_tree or not set_locomotion:
		return

	animation_tree.active = true
	_active_set = set_locomotion
	_ready_to_animate = true

	stance_component.stance_changed.connect(_on_stance_changed)
	movement_component.velocity_changed.connect(_on_velocity_changed)
	movement_component.jumped.connect(_on_jumped)
	movement_component.landed.connect(_on_landed)
	combat_component.light_attacked.connect(_play_action.bind("light_attack"))
	combat_component.heavy_attacked.connect(_play_action.bind("heavy_attack"))
	combat_component.dodged.connect(_play_action.bind("dodge"))

func _on_stance_changed(new_stance) -> void:
	if not _ready_to_animate: return
	match new_stance:
		StanceComponent.Stance.LOCOMOTION: _switch_set(set_locomotion)
		StanceComponent.Stance.COMBAT:     _switch_set(set_combat)
		StanceComponent.Stance.STEALTH:    _switch_set(set_stealth)

func _switch_set(new_set: AnimationSet) -> void:
	if not new_set: return
	_active_set = new_set
	animation_tree.set(ROOT_TRANSITION, new_set.stance_name)

func _on_velocity_changed(velocity: Vector3) -> void:
	if not _ready_to_animate: return
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	animation_tree.set(_active_set.blend_param, flat_speed)

func _on_jumped() -> void:
	if not _ready_to_animate: return
	animation_tree.set(_active_set.transition_param, "jump")

func _on_landed() -> void:
	if not _ready_to_animate: return
	animation_tree.set(_active_set.transition_param, "land")

func _play_action(action_name: String) -> void:
	if not _ready_to_animate: return
	if _active_set.action_map.has(action_name):
		animation_tree.set(_active_set.transition_param, _active_set.action_map[action_name])
