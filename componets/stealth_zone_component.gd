extends Node
class_name StealthZoneComponent

# ─────────────────────────────────────────
#  STEALTH ZONE COMPONENT  (child of Area3D)
#  Defines what a region of the world does
#  to the player's stealth values and what
#  detection threshold enemies inside use.
#
#  Scene setup:
#    Area3D  (collision shape defines zone)
#    └── stealth_zone_component  ← this script
# ─────────────────────────────────────────

# ── Zone Types ────────────────────────────
enum ZoneType {
	SHADOW,      # Dark cover          — light ×0.1
	LIT,         # Fully exposed       — light ×1.0 (default, no suppression)
	ELEVATED,    # Above patrol line   — sound ×0.5
	RAIN,        # Noise dampened      — sound ×0.6
	DOG_PATROL,  # Light irrelevant    — light ignored, motion tracked only
	CUSTOM       # Designer-defined values via @export
}

# ── Signals ───────────────────────────────
signal player_entered_zone(zone: StealthZoneComponent)
signal player_exited_zone(zone: StealthZoneComponent)

# ── Exports ───────────────────────────────
@export var zone_type: ZoneType = ZoneType.LIT

## The awareness fraction at which enemies inside
## this zone trigger their state machine.
## 0.25 = suspicious threshold, 0.65 = alerted, etc.
@export_range(0.0, 1.0) var detection_threshold: float = 0.65

## Only used when zone_type is CUSTOM.
@export_group("Custom Modifiers")
@export_range(0.0, 1.0) var custom_light_mult:  float = 1.0
@export_range(0.0, 1.0) var custom_sound_mult:  float = 1.0
@export_range(0.0, 1.0) var custom_motion_mult: float = 1.0
@export var custom_ignore_light: bool = false

# ── State ─────────────────────────────────
## The modifier ID returned by stealth_component
## so we can cleanly remove it on exit.
var _active_modifier_id: int = -1
var _player_inside: bool = false

# Preset modifier tables — indexed by ZoneType
const _PRESETS := {
	ZoneType.SHADOW:     { "light": 0.1, "sound": 1.0, "motion": 1.0, "ignore_light": false },
	ZoneType.LIT:        { "light": 1.0, "sound": 1.0, "motion": 1.0, "ignore_light": false },
	ZoneType.ELEVATED:   { "light": 1.0, "sound": 0.5, "motion": 1.0, "ignore_light": false },
	ZoneType.RAIN:       { "light": 1.0, "sound": 0.6, "motion": 1.0, "ignore_light": false },
	ZoneType.DOG_PATROL: { "light": 1.0, "sound": 1.0, "motion": 1.0, "ignore_light": true  },
}


# ─────────────────────────────────────────
#  GODOT CALLBACKS
# ─────────────────────────────────────────

func _ready() -> void:
	var parent := get_parent()
	assert(parent is Area3D, \
		"StealthZoneComponent must be a child of an Area3D node.")

	parent.body_entered.connect(_on_body_entered)
	parent.body_exited.connect(_on_body_exited)


# ─────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────

## Returns true if the player is currently inside this zone.
func has_player() -> bool:
	return _player_inside


## Returns the resolved modifier dictionary for this zone.
## awareness_component can call this to inspect zone properties.
func get_modifiers() -> Dictionary:
	return _resolve_modifiers()


# ─────────────────────────────────────────
#  PRIVATE — BODY DETECTION
# ─────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var stealth := _find_stealth_component(body)
	if stealth == null:
		return

	_player_inside = true

	var mod := _resolve_modifiers()
	_active_modifier_id = stealth.add_zone_modifier(
		mod["light"],
		mod["sound"],
		mod["motion"],
		mod["ignore_light"]
	)

	emit_signal("player_entered_zone", self)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var stealth := _find_stealth_component(body)
	if stealth == null:
		return

	_player_inside = false

	if _active_modifier_id >= 0:
		stealth.remove_zone_modifier(_active_modifier_id)
		_active_modifier_id = -1

	emit_signal("player_exited_zone", self)


# ─────────────────────────────────────────
#  PRIVATE — HELPERS
# ─────────────────────────────────────────

func _resolve_modifiers() -> Dictionary:
	if zone_type == ZoneType.CUSTOM:
		return {
			"light":        custom_light_mult,
			"sound":        custom_sound_mult,
			"motion":       custom_motion_mult,
			"ignore_light": custom_ignore_light
		}
	return _PRESETS[zone_type]


func _find_stealth_component(body: Node) -> StealthComponent:
	# Works whether stealth_component is a direct child
	# or found anywhere in the player's subtree
	for child in body.get_children():
		if child is StealthComponent:
			return child
	push_warning("StealthZoneComponent: player body has no StealthComponent.")
	return null
