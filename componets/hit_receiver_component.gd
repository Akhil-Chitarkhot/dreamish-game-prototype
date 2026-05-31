extends Node
class_name HitReceiverComponent

# ─────────────────────────────────────────
#  HIT RECEIVER COMPONENT
#  The only entry point for all incoming
#  damage. Enemies, traps, and the
#  environment never touch HP or armour
#  directly — they always call receive_hit().
# ─────────────────────────────────────────

# ─────────────────────────────────────────
## Hit Type Enum
# ─────────────────────────────────────────
enum HitType {
	LIGHT,          # Armour only. If armour broken → escalates to HEAVY
	HEAVY,          # Bypasses armour → -1 HP directly
	GRAB,           # Bypasses armour → -2 HP, uncounterable
	ENVIRONMENTAL   # Bypasses everything → -n HP (caller sets amount)
}
# ─────────────────────────────────────────
## Signals
# ─────────────────────────────────────────
signal hit_received(hit_type: HitType, final_damage: int)
# ^^ Listened to by animation, VFX, and audio components

# ─────────────────────────────────────────
## Component References
# Assign these in the Inspector or wire them
# in Player._ready() — see bottom of file
# ─────────────────────────────────────────
@export var health_component: HealthComponent
@export var armour_component: ArmourComponent

# ─────────────────────────────────────────
## State
# Set to true during cutscenes or scripted
# sequences where damage should be ignored
# ─────────────────────────────────────────
var invincible: bool = false


# ─────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────

## Primary entry point. Every source of damage calls this.
## environmental_amount is only read for HitType.ENVIRONMENTAL.
func receive_hit(hit_type: HitType, environmental_amount: int = 1) -> void:
	if invincible:
		return

	if _is_player_dead():
		return

	match hit_type:
		HitType.LIGHT:
			_handle_light_hit()

		HitType.HEAVY:
			_handle_heavy_hit()

		HitType.GRAB:
			_handle_grab_hit()

		HitType.ENVIRONMENTAL:
			_handle_environmental_hit(environmental_amount)

	# Every hit interrupts armour regen — always, regardless of type
	armour_component.reset_regen_timer()


# ─────────────────────────────────────────
#  PRIVATE — HIT HANDLERS
# ─────────────────────────────────────────

func _handle_light_hit() -> void:
	# Ask armour to absorb. Returns 0 (absorbed) or 1 (armour broken, bleed through)
	var bleed: int = armour_component.absorb_light_hit()

	if bleed > 0:
		# Armour was already broken — light hit escalates to heavy
		health_component.apply_damage(1)
		emit_signal("hit_received", HitType.HEAVY, 1)
		# Note: we emit HEAVY so listeners (animations etc.)
		# react to what actually happened, not what was intended
	else:
		emit_signal("hit_received", HitType.LIGHT, 0)


func _handle_heavy_hit() -> void:
	# Heavy always bypasses armour entirely
	health_component.apply_damage(1)
	emit_signal("hit_received", HitType.HEAVY, 1)


func _handle_grab_hit() -> void:
	# Grab bypasses armour and deals 2 HP — uncounterable
	health_component.apply_damage(2)
	emit_signal("hit_received", HitType.GRAB, 2)


func _handle_environmental_hit(amount: int) -> void:
	# Falls, fire, electricity — bypass everything
	health_component.apply_damage(amount)
	emit_signal("hit_received", HitType.ENVIRONMENTAL, amount)


# ─────────────────────────────────────────
#  PRIVATE — GUARDS
# ─────────────────────────────────────────

func _is_player_dead() -> bool:
	return health_component.is_dead()


# ─────────────────────────────────────────
#  WIRING NOTE (for Player._ready())
# ─────────────────────────────────────────
#
# If you prefer code wiring over the Inspector, do this in Player.gd:
#
#   hit_receiver_component.health_component = health_component
#   hit_receiver_component.armour_component = armour_component
#
# Either approach works — Inspector exports are just more visible.
