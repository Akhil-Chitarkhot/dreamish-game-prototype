extends Node
class_name StealthComponent

# ─────────────────────────────────────────
#  STEALTH COMPONENT  (on Player)
#  Owns the three raw stealth input values.
#  Applies modifiers pushed by whatever
#  stealth zones the player is inside.
#  Enemies never read raw values — they
#  always read the effective (modified) ones.
# ─────────────────────────────────────────

# ── Signals ───────────────────────────────
## Fires whenever any effective value changes.
## awareness_component on each enemy listens to this.
signal stealth_values_changed(light: float, sound: float, motion: float)

# ── Raw Inputs ────────────────────────────
# Set externally by movement, sound, and light systems.
# 0.0 = minimum  |  1.0 = maximum

## Set by the light/shadow detection system or zone entry.
var light_exposure:  float = 1.0

## Set by movement_component (footstep surfaces, crouch state).
var sound_output:    float = 0.0

## Set by movement_component (current speed, normalised 0–1).
var movement_speed:  float = 0.0

# ── Effective Values ──────────────────────
# What enemies actually read. Raw × stacked modifiers.
var effective_light:  float = 1.0
var effective_sound:  float = 0.0
var effective_motion: float = 0.0

# ── Active Zone Modifier Stack ────────────
# Each entry is a Dictionary pushed by a stealth_zone_component.
# Format: { "id": int, "light": float, "sound": float, "motion": float, "ignore_light": bool }
var _active_modifiers: Array[Dictionary] = []
var _next_modifier_id: int = 0


# ─────────────────────────────────────────
#  PUBLIC API — RAW VALUE SETTERS
#  Called by movement_component and the
#  light detection system each frame.
# ─────────────────────────────────────────

func set_light_exposure(value: float) -> void:
	light_exposure = clampf(value, 0.0, 1.0)
	_recalculate()


func set_sound_output(value: float) -> void:
	sound_output = clampf(value, 0.0, 1.0)
	_recalculate()


func set_movement_speed(value: float) -> void:
	movement_speed = clampf(value, 0.0, 1.0)
	_recalculate()


# ─────────────────────────────────────────
#  PUBLIC API — ZONE MODIFIER STACK
#  Called by stealth_zone_component on
#  player enter / exit.
# ─────────────────────────────────────────

## Called when player enters a zone.
## Returns a modifier ID the zone holds onto
## so it can cleanly remove itself on exit.
func add_zone_modifier(
	light_mult:   float,
	sound_mult:   float,
	motion_mult:  float,
	ignore_light: bool = false
) -> int:
	var id := _next_modifier_id
	_next_modifier_id += 1

	_active_modifiers.append({
		"id":           id,
		"light":        light_mult,
		"sound":        sound_mult,
		"motion":       motion_mult,
		"ignore_light": ignore_light
	})

	_recalculate()
	return id


## Called when player exits a zone — pass back
## the ID returned by add_zone_modifier().
func remove_zone_modifier(modifier_id: int) -> void:
	for i in _active_modifiers.size():
		if _active_modifiers[i]["id"] == modifier_id:
			_active_modifiers.remove_at(i)
			_recalculate()
			return


## Returns all three effective values as a Dictionary.
## Convenience getter for awareness_component.
func get_effective_values() -> Dictionary:
	return {
		"light":  effective_light,
		"sound":  effective_sound,
		"motion": effective_motion
	}


# ─────────────────────────────────────────
#  PRIVATE — RECALCULATION
#  Rebuilds effective values from raw inputs
#  and all currently active zone modifiers.
#  Called any time a raw value or modifier changes.
# ─────────────────────────────────────────

func _recalculate() -> void:
	# Start with raw values
	var light  := light_exposure
	var sound  := sound_output
	var motion := movement_speed
	var ignore_light := false

	# Multiply all active zone modifiers together
	# Multiple zones stack — e.g. shadow(×0.1) in rain(×0.6) → sound ×0.6, light ×0.1
	for mod in _active_modifiers:
		light  *= mod["light"]
		sound  *= mod["sound"]
		motion *= mod["motion"]
		if mod["ignore_light"]:
			ignore_light = true

	# Dog patrol zones ignore light entirely
	if ignore_light:
		light = 0.0

	effective_light  = clampf(light,  0.0, 1.0)
	effective_sound  = clampf(sound,  0.0, 1.0)
	effective_motion = clampf(motion, 0.0, 1.0)

	emit_signal("stealth_values_changed", effective_light, effective_sound, effective_motion)
