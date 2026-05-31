extends Node
class_name FieldKitComponent

# ─────────────────────────────────────────
#  FIELD KIT COMPONENT
#  Manages kit inventory and the 1.2s
#  exposed-use window. Restores 1 HP +
#  full armour on successful completion.
#  Gets interrupted if the player is hit
#  during the use window.
# ─────────────────────────────────────────

# ─────────────────────────────────────────
## Signals
# ─────────────────────────────────────────
signal kit_use_started
signal kit_use_completed
signal kit_use_interrupted
signal kit_count_changed(new_count: int, max_count: int)

# ─────────────────────────────────────────
## Constants
# ─────────────────────────────────────────
const MAX_KITS:    int   = 3
const USE_TIME:    float = 1.2   # seconds of exposure during application

# ─────────────────────────────────────────
## Component References
# ─────────────────────────────────────────
@export var health_component:       HealthComponent
@export var armour_component:       ArmourComponent
@export var hit_receiver_component: HitReceiverComponent

# ─────────────────────────────────────────
## State
# ─────────────────────────────────────────
var kit_count:   int   = 0       # starts at 0 — player finds these in the world
var _use_timer:  float = 0.0
var _using:      bool  = false


# ─────────────────────────────────────────
#  GODOT CALLBACKS
# ─────────────────────────────────────────

func _ready() -> void:
	# Listen for any hit while we might be mid-use
	# hit_receiver_component is wired via Inspector or Player._ready()
	if hit_receiver_component:
		hit_receiver_component.hit_received.connect(_on_hit_received)


func _process(delta: float) -> void:
	if not _using:
		return

	_use_timer -= delta

	if _use_timer <= 0.0:
		_complete_use()


# ─────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────

# ─────────────────────────────────────────
## Called by Player when the use-kit input fires.
## Returns true if use was started, false if refused.
# ─────────────────────────────────────────
func use_kit() -> bool:
	if not _can_use():
		return false

	kit_count   -= 1
	_use_timer   = USE_TIME
	_using       = true

	emit_signal("kit_use_started")
	emit_signal("kit_count_changed", kit_count, MAX_KITS)
	return true

# ─────────────────────────────────────────
## Called when the player walks over a kit pickup in the world.
# ─────────────────────────────────────────
func pick_up_kit() -> bool:
	if kit_count >= MAX_KITS:
		return false   # already at max — pickup refused

	kit_count += 1
	emit_signal("kit_count_changed", kit_count, MAX_KITS)
	return true


## Called by safe house / checkpoint to refill kits alongside HP.
func refill_kits() -> void:
	kit_count = MAX_KITS
	emit_signal("kit_count_changed", kit_count, MAX_KITS)

# ─────────────────────────────────────────
## Returns the progress of the current use as a 0–1 fraction.
## Useful for driving a use-progress UI bar.
# ─────────────────────────────────────────
func get_use_progress() -> float:
	if not _using:
		return 0.0
	return 1.0 - (_use_timer / USE_TIME)


func is_using() -> bool:
	return _using


# ─────────────────────────────────────────
#  PRIVATE — LOGIC
# ─────────────────────────────────────────

func _can_use() -> bool:
	if _using:
		return false   # already mid-use

	if kit_count <= 0:
		return false   # no kits left

	if health_component.hp >= health_component.MAX_HP:
		return false   # HP already full — don't waste the kit

	if health_component.is_dead():
		return false

	return true


func _complete_use() -> void:
	_using     = false
	_use_timer = 0.0

	health_component.restore(1)
	armour_component.set_full()

	emit_signal("kit_use_completed")


func _interrupt_use() -> void:
	# Kit is consumed (already deducted in use_kit) but does nothing
	_using     = false
	_use_timer = 0.0

	# Give the kit back — interrupted use doesn't consume it
	kit_count += 1
	emit_signal("kit_count_changed", kit_count, MAX_KITS)
	emit_signal("kit_use_interrupted")


# ─────────────────────────────────────────
#  PRIVATE — SIGNAL CALLBACKS
# ─────────────────────────────────────────

func _on_hit_received(_hit_type: HitReceiverComponent.HitType, _damage: int) -> void:
	if _using:
		_interrupt_use()
