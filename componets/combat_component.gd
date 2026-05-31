extends Node

signal light_attacked
signal heavy_attacked
signal dodged

@export var stance: StanceComponent

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("light_attack"):
		stance.enter_combat()
		light_attacked.emit()
	elif event.is_action_pressed("heavy_attack"):
		stance.enter_combat()
		heavy_attacked.emit()
	elif event.is_action_pressed("dodge"):
		dodged.emit()
