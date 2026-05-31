extends Node3D
class_name GrapplePoint

enum Type {
	LEDGE,      # player zips to edge and climbs up
	ZIPLINE,    # player travels horizontally and drops off
	HANG        # player just hangs, no auto climb
}

@export var type: Type = Type.LEDGE
@export var climb_destination: Marker3D # assign ClimbDestination in Inspector
@export var surface_normal: Vector3 = Vector3.FORWARD  # which way player faces on arrival

@onready var editor_mesh: MeshInstance3D = $MeshInstance3D

func _ready():
	# hide the editor sphere during the game
	editor_mesh.visible = false

func get_climb_position() -> Vector3:
	if climb_destination:
		return climb_destination.global_position
	# fallback: just go up a bit from the ledge
	return global_position + Vector3.UP * 1.8

func get_surface_normal() -> Vector3:
	return global_transform.basis * surface_normal
