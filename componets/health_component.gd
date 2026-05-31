extends Node
class_name HealthComponent

# ─────────────────────────────────────────
##  HEALTH COMPONENT
#  Owns HP state only. No armour, no UI,
#  no FX — those are other components' jobs.
# ─────────────────────────────────────────

# ─────────────────────────────────────────
#Signals
signal hp_changed(new_hp: int, max_hp: int)
signal hp_critical                          # fires once when HP reaches 1
signal player_died

# ─────────────────────────────────────────
#Constants
const MAX_HP: int = 3

# ─────────────────────────────────────────
#State
var hp: int = MAX_HP

# ─────────────────────────────────────────
# Track whether we've already fired hp_critical this life
# so it only fires once per life, not on every hit at HP 1
var _critical_fired: bool = false
# ─────────────────────────────────────────

# ─────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────

# ─────────────────────────────────────────
## Called by hit_receiver_component (positive = damage, negative = healing).
## External code should never set hp directly.
# ─────────────────────────────────────────
func apply_damage(amount: int) -> void:
	if hp <= 0:
		return  # already dead, ignore

	hp = clampi(hp - amount, 0, MAX_HP)
	emit_signal("hp_changed", hp, MAX_HP)

	_check_critical()
	_check_death()

# ─────────────────────────────────────────
## Convenience wrapper used by field_kit_component to restore 1 HP.
# ─────────────────────────────────────────
func restore(amount: int) -> void:
	if hp <= 0:
		return  # dead players can't use field kits

	var was_critical: bool = (hp == 1)

	hp = clampi(hp + amount, 0, MAX_HP)
	emit_signal("hp_changed", hp, MAX_HP)

	# If we healed out of critical, allow hp_critical to fire again next time
	if was_critical and hp > 1:
		_critical_fired = false

# ─────────────────────────────────────────
## Resets HP fully — used by safe house visits and Act 3 checkpoint.
# ─────────────────────────────────────────
func full_restore() -> void:
	hp = MAX_HP
	_critical_fired = false
	emit_signal("hp_changed", hp, MAX_HP)

# ─────────────────────────────────────────
## Returns true if the player is at the critical HP threshold.
# ─────────────────────────────────────────
func is_critical() -> bool:
	return hp == 1

# ─────────────────────────────────────────
## Returns true if the player has no HP remaining.
# ─────────────────────────────────────────
func is_dead() -> bool:
	return hp <= 0


# ─────────────────────────────────────────
##  PRIVATE HELPERS
# ─────────────────────────────────────────

func _check_critical() -> void:
	if hp == 1 and not _critical_fired:
		_critical_fired = true
		emit_signal("hp_critical")


func _check_death() -> void:
	if hp <= 0:
		emit_signal("player_died")
