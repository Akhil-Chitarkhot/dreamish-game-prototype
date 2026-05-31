extends CharacterBody3D

# ─────────────────────────────────────────
#  PLAYER
#  Pure compositor. Owns no game logic.
#  Connects components to each other via
#  signals and routes input actions to the
#  correct component.
# ─────────────────────────────────────────

# ─────────────────────────────────────────
## Input System Components
# ─────────────────────────────────────────
@onready var input:       InputComponent    = $Components/input_component
# ─────────────────────────────────────────
## Camera System Components
# ─────────────────────────────────────────
@onready var camera_comp: CameraComponent   = $Components/camera_component
# ─────────────────────────────────────────
## Movement System Components
# ─────────────────────────────────────────
@onready var movement:    MovementComponent = $Components/movement_component

# ─────────────────────────────────────────
## Health System Components
# ─────────────────────────────────────────
@onready var health_component:         HealthComponent      = $Components/health_component
@onready var armour_component:         ArmourComponent      = $Components/armour_component
@onready var hit_receiver_component:   HitReceiverComponent = $Components/hit_receiver_component
@onready var field_kit_component:      FieldKitComponent    = $Components/field_kit_component
@onready var low_health_fx_component:  LowHealthFXComponent = $Components/low_health_fx_component



# ─────────────────────────────────────────
## CALLBACKS
# ─────────────────────────────────────────


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	input.move_input_changed.connect(movement.set_move_input)
	input.look_input_changed.connect(camera_comp.on_look_input)
	input.jump_pressed.connect(movement.queue_jump)

	movement.get_camera_basis = camera_comp.get_camera_basis
	
	_wire_hit_receiver()
	_wire_field_kit()
	_wire_health_signals()
	_wire_low_health_fx()
	

func _input(event: InputEvent) -> void:
	_handle_kit_input(event)
	
	_handle_kit_input(event)

	if event.is_action_pressed("ui_accept"):      # Space — light hit
		hit_receiver_component.receive_hit(HitReceiverComponent.HitType.LIGHT)

	if event.is_action_pressed("ui_cancel"):      # Escape — pick up a kit
		field_kit_component.pick_up_kit()


# ─────────────────────────────────────────
#  PRIVATE — WIRING
#  One method per component pair.
#  Keeps _ready() scannable at a glance.
# ─────────────────────────────────────────
 
func _wire_hit_receiver() -> void:
	# Give hit_receiver its two dependencies
	hit_receiver_component.health_component = health_component
	hit_receiver_component.armour_component = armour_component
 
 
func _wire_field_kit() -> void:
	# Give field_kit its three dependencies
	field_kit_component.health_component       = health_component
	field_kit_component.armour_component       = armour_component
	field_kit_component.hit_receiver_component = hit_receiver_component
 
	# field_kit connects to hit_receiver internally in its own _ready(),
	# so we must wire these before field_kit_component._ready() runs.
	# @onready guarantees all children are ready before this runs — we're safe.
 
 
func _wire_health_signals() -> void:
	health_component.hp_changed.connect(_on_hp_changed)
	health_component.hp_critical.connect(_on_hp_critical)
	health_component.player_died.connect(_on_player_died)
 
	armour_component.armour_changed.connect(_on_armour_changed)
	armour_component.armour_broken.connect(_on_armour_broken)
 
	field_kit_component.kit_use_started.connect(_on_kit_use_started)
	field_kit_component.kit_use_completed.connect(_on_kit_use_completed)
	field_kit_component.kit_use_interrupted.connect(_on_kit_use_interrupted)
	field_kit_component.kit_count_changed.connect(_on_kit_count_changed)
 
	hit_receiver_component.hit_received.connect(_on_hit_received)
 
 
func _wire_low_health_fx() -> void:
	# low_health_fx only needs health_component — it wires itself in its own _ready()
	# Nothing extra to wire here unless you want Player to react to its signals too
	low_health_fx_component.critical_state_entered.connect(_on_critical_state_entered)
	low_health_fx_component.critical_state_exited.connect(_on_critical_state_exited)
 
 
# ─────────────────────────────────────────
#  PRIVATE — INPUT ROUTING
# ─────────────────────────────────────────
 
func _handle_kit_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_kit"):
		field_kit_component.use_kit()
 
 
# ─────────────────────────────────────────
#  PRIVATE — SIGNAL HANDLERS
#  These are the Player's responses to
#  component events. Keep them thin —
#  forward to UI, animation, or other
#  systems. Never add logic here.
# ─────────────────────────────────────────
 
# ── Health ────────────────────────────────
 
func _on_hp_changed(new_hp: int, max_hp: int) -> void:
	# Forward to HUD / UI system
	# e.g. hud.update_hp(new_hp, max_hp)
	print("[Player] HP: %d / %d" % [new_hp, max_hp])
 
 
func _on_hp_critical() -> void:
	# low_health_fx_component handles visuals/audio automatically.
	# Use this slot for gameplay-level responses, e.g.:
	# - enemy AI mood shift (already covered by low_health_fx signals)
	# - achievement tracking
	print("[Player] HP critical!")
 
 
func _on_player_died() -> void:
	# Freeze input, trigger death animation, load respawn screen, etc.
	print("[Player] Player died.")
	set_process_input(false)
	movement.set_process(false)
 
 
# ── Armour ────────────────────────────────
 
func _on_armour_changed(_current: float, _max_armour: float) -> void:
	# Forward to HUD / UI system
	# e.g. hud.update_armour(current / max_armour)
	pass
 
 
func _on_armour_broken() -> void:
	# Trigger a brief armour-broken animation or VFX
	# e.g. animation_player.play("armour_break_flash")
	print("[Player] Armour broken!")
 
 
# ── Field Kit ─────────────────────────────
 
func _on_kit_use_started() -> void:
	# Play kit-use animation, lock out dodge/attack input
	# e.g. animation_player.play("use_field_kit")
	print("[Player] Kit use started — exposed for 1.2s")
 
 
func _on_kit_use_completed() -> void:
	# Return to idle animation, re-enable full input
	print("[Player] Kit use complete — HP and armour restored")
 
 
func _on_kit_use_interrupted() -> void:
	# Snap animation back, kit was refunded automatically
	print("[Player] Kit use interrupted by hit!")
 
 
func _on_kit_count_changed(new_count: int, max_count: int) -> void:
	# Update kit counter in HUD
	# e.g. hud.update_kits(new_count, max_count)
	print("[Player] Kits: %d / %d" % [new_count, max_count])
 
 
# ── Hit Receiver ──────────────────────────
 
func _on_hit_received(hit_type: HitReceiverComponent.HitType, final_damage: int) -> void:
	# Route to hit-reaction animations, VFX, rumble, etc.
	# hit_type tells you exactly what happened (LIGHT, HEAVY, GRAB, ENVIRONMENTAL)
	print("[Player] Hit received — type: %s | damage: %d" % [
		HitReceiverComponent.HitType.keys()[hit_type], final_damage
	])
 
 
# ── Low Health FX ─────────────────────────
 
func _on_critical_state_entered() -> void:
	# Notify enemy AI to shift dialogue: "He's hurt — press him."
	# e.g. EnemyEventBus.emit_signal("player_critical", true)
	print("[Player] Critical state entered — enemies should press attack")
 
 
func _on_critical_state_exited() -> void:
	# Revert enemy AI dialogue shift
	print("[Player] Critical state exited")
