class_name ArmourComponent
extends Node

# ─────────────────────────────────────────
##  ARMOUR COMPONENT
##  Owns armour durability state.
##  Handles passive regen timer logic.
##  Knows nothing about HP, UI, or FX.
# ─────────────────────────────────────────

# ─────────────────────────────────────────
## Signals
# ─────────────────────────────────────────
signal armour_changed(current: float, max_armour: float)
signal armour_broken                  # fires when durability hits 0
signal armour_restored                # fires when regen brings armour back above 0

# ─────────────────────────────────────────
## Constants
# ─────────────────────────────────────────
const MAX_ARMOUR:        float = 1.0
const REGEN_CAP:         float = 0.6   # passive regen never exceeds 60%
const REGEN_DELAY:       float = 8.0   # seconds out of combat before regen starts
const REGEN_DELAY_UPGRADED: float = 6.0
const REGEN_RATE:        float = 0.15  # durability restored per second during regen

# ─────────────────────────────────────────
## State
# ─────────────────────────────────────────
var armour:        float = MAX_ARMOUR
var _regen_timer:  float = 0.0         # counts down to zero, then regen begins
var _regen_active: bool  = false       # true while we are currently regenerating
var _was_broken:   bool  = false       # tracks the broken state across frames

# ─────────────────────────────────────────
## Upgrades
## Set to true when the player unlocks the regen-speed upgrade
# ─────────────────────────────────────────
var upgraded_regen: bool = false


# ─────────────────────────────────────────
#  GODOT CALLBACKS
# ─────────────────────────────────────────

func _process(delta: float) -> void:
	_tick_regen(delta)


# ─────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────

## Absorbs a light hit. Returns the amount of damage that bled through
## (0 if armour absorbed it, >0 if armour was already broken).
func absorb_light_hit() -> int:
	if is_broken():
		# Armour broken → light hit escalates to heavy, bleeds through
		return 1

	# Armour takes the hit — degrade it
	_apply_armour_damage(0.34)   # roughly 3 light hits to break armour
	reset_regen_timer()
	return 0


## Called by hit_receiver_component on ANY incoming hit to interrupt regen.
func reset_regen_timer() -> void:
	var delay := REGEN_DELAY_UPGRADED if upgraded_regen else REGEN_DELAY
	_regen_timer  = delay
	_regen_active = false


## Called by field_kit_component and safe house — restores armour to full.
func set_full() -> void:
	var was_broken := is_broken()
	armour = MAX_ARMOUR
	_was_broken = false
	emit_signal("armour_changed", armour, MAX_ARMOUR)
	if was_broken:
		emit_signal("armour_restored")


## Returns true when armour durability is at zero.
func is_broken() -> bool:
	return armour <= 0.0


## Returns armour as a 0–1 fraction (useful for UI progress bars).
func get_fraction() -> float:
	return armour / MAX_ARMOUR


# ─────────────────────────────────────────
#  PRIVATE HELPERS
# ─────────────────────────────────────────

func _apply_armour_damage(amount: float) -> void:
	var was_broken_before := is_broken()
	armour = clampf(armour - amount, 0.0, MAX_ARMOUR)
	emit_signal("armour_changed", armour, MAX_ARMOUR)

	if not was_broken_before and is_broken():
		_was_broken = true
		emit_signal("armour_broken")


func _tick_regen(delta: float) -> void:
	# Nothing to do if armour is already at or above the regen cap
	if armour >= REGEN_CAP:
		_regen_active = false
		return

	# Count down the out-of-combat delay
	if _regen_timer > 0.0:
		_regen_timer -= delta
		_regen_active = false
		return

	# Delay expired — begin regenerating
	var was_broken := is_broken()
	_regen_active = true
	armour = clampf(armour + REGEN_RATE * delta, 0.0, REGEN_CAP)
	emit_signal("armour_changed", armour, MAX_ARMOUR)

	# If we just recovered from broken, fire the restored signal
	if was_broken and not is_broken():
		_was_broken = false
		emit_signal("armour_restored")
