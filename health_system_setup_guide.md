# Health System Setup Guide
## Complete Step-by-Step Reference

---

## Overview — What This System Contains

The health system is made of five components that all live on the Player node.
Each owns exactly one job. Nothing reaches into another component directly —
they talk through signals only.

```
health_component         → owns HP (max 3, no passive regen)
armour_component         → owns armour durability + passive regen timer
hit_receiver_component   → single entry point for ALL incoming damage
field_kit_component      → manages kit inventory and the 1.2s use window
low_health_fx_component  → reacts to HP 1 with limp, heartbeat, vignette
```

---

## Before You Start — One-Time Project Setup

---

### 1. Input Map

Go to **Project → Project Settings → Input Map**.

Add this action if it does not already exist:

```
use_kit    → E key  (or whatever healing key you prefer)
```

Click **Add Action** → type `use_kit` → press Enter → click **+** → press the key
→ click OK.

---

### 2. Verify Your Player Has the Right Structure

Open your **Player scene**. The root node must be a **CharacterBody3D** and must
be in the `player` group. Inside it there must be a `Components` node that holds
all the player's components.

If your player does not have a `Components` node yet:
- Right-click the Player root → **Add Child Node** → **Node** → name it `Components`
- Move existing components (camera, input, movement) inside it

---

## Part 1 — Adding Health Components to the Player

---

### Step 1 — Add health_component

Right-click `Components` → **Add Child Node** → **Node** → name it exactly
`health_component`.

Drag `health_component.gd` onto the script slot in the Inspector.

This component has no exports. Everything is defined as constants inside the script.
No Inspector settings needed.

---

### Step 2 — Add armour_component

Right-click `Components` → **Add Child Node** → **Node** → name it
`armour_component`.

Drag `armour_component.gd` onto the script slot.

No Inspector settings needed. All values are defined as constants:
```
MAX_ARMOUR:           1.0   (full durability)
REGEN_CAP:            0.6   (passive regen never exceeds 60%)
REGEN_DELAY:          8.0s  (seconds out of combat before regen starts)
REGEN_DELAY_UPGRADED: 6.0s  (with upgrade unlocked)
REGEN_RATE:           0.15  (durability restored per second)
```

To enable the upgraded regen speed later, set this from any upgrade script:
```gdscript
player.get_node("Components/armour_component").upgraded_regen = true
```

---

### Step 3 — Add hit_receiver_component

Right-click `Components` → **Add Child Node** → **Node** → name it
`hit_receiver_component`.

Drag `hit_receiver_component.gd` onto the script slot.

**Inspector settings:**
```
health_component:  [drag Components/health_component here]
armour_component:  [drag Components/armour_component here]
```

This is the only component that needs its dependencies assigned in the Inspector
(or you can wire them in `player.gd` — see Part 2).

---

### Step 4 — Add field_kit_component

Right-click `Components` → **Add Child Node** → **Node** → name it
`field_kit_component`.

Drag `field_kit_component.gd` onto the script slot.

**Inspector settings:**
```
health_component:       [drag Components/health_component here]
armour_component:       [drag Components/armour_component here]
hit_receiver_component: [drag Components/hit_receiver_component here]
```

Constants defined in script (for reference):
```
MAX_KITS:   3      (maximum kits the player can carry)
USE_TIME:   1.2s   (exposed window during application)
```

---

### Step 5 — Add low_health_fx_component

Right-click `Components` → **Add Child Node** → **Node** → name it
`low_health_fx_component`.

Drag `low_health_fx_component.gd` onto the script slot.

**Inspector settings:**
```
health_component:          [drag Components/health_component here]
animation_tree:            [leave empty for now — set up in Part 4]
heartbeat_audio:           [leave empty for now — set up in Part 4]
vignette_overlay:          [leave empty for now — set up in Part 4]
limp_blend_param:          "parameters/limp_blend/blend_amount"
vignette_intensity_param:  "intensity"
heartbeat_volume_db:       -6.0
```

The three empty slots (animation_tree, heartbeat_audio, vignette_overlay)
are optional for a test setup. The component warns and skips gracefully
when they are not assigned. You can test HP, armour, and damage fully
without them.

---

### Your Player Scene After All Five Components

```
Player  (CharacterBody3D)              ← group: "player"
└── Components  (Node)
    ├── camera_component
    ├── input_component
    ├── movement_component
    ├── stealth_component
    ├── health_component               ← health_component.gd
    ├── armour_component               ← armour_component.gd
    ├── hit_receiver_component         ← hit_receiver_component.gd
    ├── field_kit_component            ← field_kit_component.gd
    └── low_health_fx_component        ← low_health_fx_component.gd
```

---

## Part 2 — Wiring Components in player.gd

Open `player.gd`. In `_ready()` you should have these wiring functions.
If any are missing, add them now.

---

### @onready References

At the top of `player.gd` add these alongside your existing @onready lines:

```gdscript
# Existing components
@onready var camera_component:   Node = $Components/camera_component
@onready var input_component:    Node = $Components/input_component
@onready var movement_component: Node = $Components/movement_component

# Health system components
@onready var health_component:        HealthComponent        = $Components/health_component
@onready var armour_component:        ArmourComponent        = $Components/armour_component
@onready var hit_receiver_component:  HitReceiverComponent   = $Components/hit_receiver_component
@onready var field_kit_component:     FieldKitComponent      = $Components/field_kit_component
@onready var low_health_fx_component: LowHealthFXComponent   = $Components/low_health_fx_component
```

---

### _ready() Wiring Functions

```gdscript
func _ready() -> void:
    _wire_hit_receiver()
    _wire_field_kit()
    _wire_health_signals()
    _wire_low_health_fx()


func _wire_hit_receiver() -> void:
    hit_receiver_component.health_component = health_component
    hit_receiver_component.armour_component = armour_component


func _wire_field_kit() -> void:
    field_kit_component.health_component       = health_component
    field_kit_component.armour_component       = armour_component
    field_kit_component.hit_receiver_component = hit_receiver_component


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
    low_health_fx_component.critical_state_entered.connect(_on_critical_state_entered)
    low_health_fx_component.critical_state_exited.connect(_on_critical_state_exited)
```

---

### _input() — Kit Use

```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("use_kit"):
        field_kit_component.use_kit()
```

---

### Signal Handler Stubs

Add these to `player.gd` if they are missing. They are empty for now — fill them
in as you build the HUD and animation systems.

```gdscript
func _on_hp_changed(new_hp: int, max_hp: int) -> void:
    print("[Player] HP: %d / %d" % [new_hp, max_hp])
    # TODO: update HUD HP display

func _on_hp_critical() -> void:
    print("[Player] HP critical!")
    # low_health_fx_component handles visuals automatically

func _on_player_died() -> void:
    print("[Player] Died.")
    set_process_input(false)
    $Components/movement_component.set_process(false)
    # TODO: trigger death screen / respawn

func _on_armour_changed(_current: float, _max_armour: float) -> void:
    pass
    # TODO: update HUD armour bar

func _on_armour_broken() -> void:
    print("[Player] Armour broken!")
    # TODO: play armour break flash / sound

func _on_kit_use_started() -> void:
    print("[Player] Kit use started — exposed 1.2s")
    # TODO: play use animation, lock dodge input

func _on_kit_use_completed() -> void:
    print("[Player] Kit used — HP and armour restored")
    # TODO: return to idle animation

func _on_kit_use_interrupted() -> void:
    print("[Player] Kit interrupted!")
    # Kit was refunded automatically

func _on_kit_count_changed(new_count: int, max_count: int) -> void:
    print("[Player] Kits: %d / %d" % [new_count, max_count])
    # TODO: update HUD kit counter

func _on_hit_received(hit_type: HitReceiverComponent.HitType, damage: int) -> void:
    print("[Player] Hit — type: %s  damage: %d" % [
        HitReceiverComponent.HitType.keys()[hit_type], damage])
    # TODO: trigger hit animation / camera shake / rumble

func _on_critical_state_entered() -> void:
    print("[Player] Critical state entered")
    # TODO: notify enemy AI to press attack

func _on_critical_state_exited() -> void:
    print("[Player] Critical state exited")
```

---

## Part 3 — How Enemies Deal Damage

Every enemy, trap, and hazard in the game uses exactly one line to deal damage.
They never touch health_component or armour_component directly.

---

### The Four Hit Types

```
HitType.LIGHT          → absorbed by armour. If armour broken → escalates to HEAVY
HitType.HEAVY          → bypasses armour → -1 HP
HitType.GRAB           → bypasses armour → -2 HP, uncounterable
HitType.ENVIRONMENTAL  → bypasses everything → -n HP (you set the amount)
```

---

### In Any Enemy Script

```gdscript
# Get a reference to the player's hit_receiver_component
var player := get_tree().get_nodes_in_group("player")[0]
var hit_receiver := player.get_node("Components/hit_receiver_component") \
                    as HitReceiverComponent

# Deal a light hit (absorbed by armour)
hit_receiver.receive_hit(HitReceiverComponent.HitType.LIGHT)

# Deal a heavy hit (bypasses armour, -1 HP)
hit_receiver.receive_hit(HitReceiverComponent.HitType.HEAVY)

# Deal a grab hit (-2 HP, uncounterable)
hit_receiver.receive_hit(HitReceiverComponent.HitType.GRAB)

# Environmental damage — fall, fire, electricity (-2 HP in this example)
hit_receiver.receive_hit(HitReceiverComponent.HitType.ENVIRONMENTAL, 2)
```

---

### In a Hazard / Trigger Volume

For things like fire, electricity, or fall damage — use an Area3D:

```gdscript
extends Area3D

@export var damage_amount: int = 1
@export var damage_interval: float = 0.5   # how often to deal damage

var _timer: float = 0.0
var _player_inside: bool = false
var _hit_receiver: HitReceiverComponent = null


func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
    if not _player_inside or _hit_receiver == null:
        return
    _timer -= delta
    if _timer <= 0.0:
        _timer = damage_interval
        _hit_receiver.receive_hit(
            HitReceiverComponent.HitType.ENVIRONMENTAL,
            damage_amount
        )


func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    _player_inside = true
    _hit_receiver  = body.get_node_or_null("Components/hit_receiver_component")
    _timer = 0.0   # deal damage immediately on entry


func _on_body_exited(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    _player_inside = false
    _hit_receiver  = null
```

---

## Part 4 — Setting Up the Low Health FX

These three effects all trigger automatically when HP reaches 1. Set them up
when you are ready — the system works without them during early testing.

---

### Effect 1 — Heartbeat Audio

**Create the AudioStreamPlayer:**
- Right-click your Player root → **Add Child Node** → **AudioStreamPlayer**
- Name it `HeartbeatAudio`
- Import a looping heartbeat audio file (.ogg or .mp3) into your project
- Drag it into the AudioStreamPlayer's **Stream** slot in the Inspector
- Set **Autoplay** to OFF
- Set **Loop** to ON (click the stream resource → enable Loop)

**Assign it to low_health_fx_component:**
- Click `low_health_fx_component` in the Inspector
- Drag `HeartbeatAudio` into the `heartbeat_audio` slot

---

### Effect 2 — Vignette Overlay

**Create the vignette shader:**

Create a new file called `vignette.gdshader` and paste this into it:

```gdshader
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv      = UV - vec2(0.5);
    float dist   = length(uv);
    float vignette = smoothstep(0.3, 0.75, dist);
    COLOR = vec4(0.0, 0.0, 0.0, vignette * intensity);
}
```

**Create the CanvasLayer and ColorRect:**

The vignette must sit above the game view. Add it directly to your Player scene
(not inside Components — this is a UI element):

```
Player  (CharacterBody3D)
├── Components
│   └── ...
└── VignetteLayer  (CanvasLayer)
    └── VignetteRect  (ColorRect)
```

- Set `VignetteLayer` **Layer** to `10` (renders on top of everything)
- Select `VignetteRect`
  - **Layout Mode** → Anchors → **Full Rect** preset
  - **Color** → `(0, 0, 0, 0)` (transparent — the shader controls opacity)
  - **Material** → New ShaderMaterial
  - Click the ShaderMaterial → **Shader** → drag `vignette.gdshader` onto the slot
  - Set the shader parameter **intensity** to `0.0`

**Assign it to low_health_fx_component:**
- Click `low_health_fx_component`
- Drag `VignetteRect` (the ColorRect, not the CanvasLayer) into the
  `vignette_overlay` slot

---

### Effect 3 — Limp Animation

This requires an **AnimationTree** on the player with a blend node for the limp.
This is the most complex effect and can be left for later.

**Basic setup when you are ready:**

1. Add an **AnimationTree** node to your player
2. Inside the AnimationTree, create a **BlendSpace1D** or **AnimationNodeBlend2**
3. Name the blend parameter path to match the export in `low_health_fx_component`:
   ```
   limp_blend_param: "parameters/limp_blend/blend_amount"
   ```
4. At value `0.0` → normal walk animation
5. At value `1.0` → limp walk animation

**Assign it:**
- Click `low_health_fx_component`
- Drag your AnimationTree node into the `animation_tree` slot

---

## Part 5 — Field Kit Pickups in the World

Field kits are found in the level, not purchased. Here is how to make a pickup.

---

### Create the Pickup Scene

**Scene → New Scene** → root **Area3D** → name it `FieldKitPickup` → save as
`field_kit_pickup.tscn`.

```
FieldKitPickup  (Area3D)
├── CollisionShape3D   ← SphereShape3D, radius 0.5
├── MeshInstance3D     ← small SphereMesh, bright green colour
└── field_kit_pickup.gd
```

**Collision:**
- Layer: **4** (or a dedicated "pickup" layer)
- Mask: **2** (detects player)

**Script:**

```gdscript
extends Area3D

func _ready() -> void:
    body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return

    var kit_comp := body.get_node_or_null("Components/field_kit_component") \
                    as FieldKitComponent
    if kit_comp == null:
        return

    # Try to give the kit — returns false if player is already at max (3)
    var accepted := kit_comp.pick_up_kit()
    if accepted:
        queue_free()   # pickup disappears only if the player wasn't already full
    # If refused, pickup stays in the world — player can come back for it
```

---

### Place Pickups in the Level

Drag `field_kit_pickup.tscn` into your level scene. Place them:
- In corners that reward exploration
- Near high-risk areas (before a tough encounter)
- Never more than 3 in one area (player can only carry 3)

---

## Part 6 — Safe House Setup

A safe house visit restores full HP + full armour + refills kits.

---

### Create the Safe House Trigger

Add an **Area3D** to your level wherever the safe house is:

```
SafeHouse_Trigger  (Area3D)
├── CollisionShape3D   ← large BoxShape3D covering the safe house interior
└── safe_house_trigger.gd
```

**Script:**

```gdscript
extends Area3D

# Whether this safe house is accessible.
# Set to false when safe houses are burned in Act 2.
@export var is_accessible: bool = true

signal safe_house_entered
signal safe_house_burned

func _ready() -> void:
    body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    if not is_accessible:
        print("[SafeHouse] Access denied — safe house burned")
        return

    # Full restore
    var health := body.get_node_or_null("Components/health_component") \
                  as HealthComponent
    var armour := body.get_node_or_null("Components/armour_component") \
                  as ArmourComponent
    var kits   := body.get_node_or_null("Components/field_kit_component") \
                  as FieldKitComponent

    if health: health.full_restore()
    if armour: armour.set_full()
    if kits:   kits.refill_kits()

    emit_signal("safe_house_entered")
    print("[SafeHouse] Full restore — HP, armour, and kits refilled")


func burn_safe_house() -> void:
    is_accessible = false
    emit_signal("safe_house_burned")
    print("[SafeHouse] Safe house burned — no longer accessible")
```

---

## Part 7 — Act 3 Checkpoint

The only scripted full heal in the game. Fires once before the Voss confrontation.

Add this to whatever script manages the Act 3 checkpoint trigger:

```gdscript
func _trigger_act3_checkpoint() -> void:
    var player := get_tree().get_nodes_in_group("player")[0]

    var health := player.get_node_or_null("Components/health_component") as HealthComponent
    var armour := player.get_node_or_null("Components/armour_component") as ArmourComponent

    if health: health.full_restore()
    if armour: armour.set_full()

    print("[Checkpoint] Act 3 checkpoint — full restore before Voss")
    # TODO: play checkpoint cutscene / dialogue
```

---

## Part 8 — Health Debug Overlay

For testing the health system, add a debug label that shows HP, armour, and kit
count in real time. Create `health_debug_overlay.gd`:

```gdscript
extends CanvasLayer

@onready var _label: Label = $DebugLabel

var _health:  HealthComponent    = null
var _armour:  ArmourComponent    = null
var _kits:    FieldKitComponent  = null


func _ready() -> void:
    var players := get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        var p := players[0]
        _health = p.get_node_or_null("Components/health_component")
        _armour = p.get_node_or_null("Components/armour_component")
        _kits   = p.get_node_or_null("Components/field_kit_component")


func _process(_delta: float) -> void:
    if _label == null:
        return
    _label.text = _build_text()


func _build_text() -> String:
    var lines: PackedStringArray = []
    lines.append("── HEALTH DEBUG ───────────────────")

    # HP
    lines.append("")
    lines.append("[ HP ]")
    if _health:
        var bar := _bar(_health.hp, _health.MAX_HP)
        lines.append("  %s  %d / %d" % [bar, _health.hp, _health.MAX_HP])
        lines.append("  Critical: %s" % ("YES" if _health.is_critical() else "NO"))
        lines.append("  Dead:     %s" % ("YES" if _health.is_dead() else "NO"))
    else:
        lines.append("  ! health_component not found")

    # Armour
    lines.append("")
    lines.append("[ ARMOUR ]")
    if _armour:
        var pct := _armour.armour / _armour.MAX_ARMOUR
        var bar := _bar_float(_armour.armour, _armour.MAX_ARMOUR)
        lines.append("  %s  %.0f%%" % [bar, pct * 100.0])
        lines.append("  Broken:       %s" % ("YES" if _armour.is_broken() else "NO"))
        lines.append("  Regen active: %s" % ("YES" if _armour._regen_active else "NO"))
        if not _armour._regen_active and not _armour.is_broken():
            lines.append("  Regen delay:  %.1fs" % _armour._regen_timer)
        lines.append("  Regen cap:    60%%  (passive max)")
    else:
        lines.append("  ! armour_component not found")

    # Kits
    lines.append("")
    lines.append("[ FIELD KITS ]")
    if _kits:
        var kit_bar := _bar(_kits.kit_count, _kits.MAX_KITS)
        lines.append("  %s  %d / %d" % [kit_bar, _kits.kit_count, _kits.MAX_KITS])
        if _kits.is_using():
            lines.append("  USING — %.0f%% complete" % (_kits.get_use_progress() * 100.0))
        else:
            lines.append("  Press E to use a kit")
    else:
        lines.append("  ! field_kit_component not found")

    # Controls
    lines.append("")
    lines.append("[ DEBUG CONTROLS ]")
    lines.append("  Num1  Light hit")
    lines.append("  Num2  Heavy hit")
    lines.append("  Num3  Grab hit  (-2 HP)")
    lines.append("  Num4  Environmental hit")
    lines.append("  Num5  Pick up field kit")
    lines.append("  Num6  Full restore (safe house)")
    lines.append("")
    lines.append("───────────────────────────────────")

    return "\n".join(lines)


func _input(event: InputEvent) -> void:
    var players := get_tree().get_nodes_in_group("player")
    if players.is_empty():
        return
    var p := players[0]
    var hr := p.get_node_or_null("Components/hit_receiver_component") \
              as HitReceiverComponent

    if event.is_action_pressed("ui_text_indent"):          # Num1
        if hr: hr.receive_hit(HitReceiverComponent.HitType.LIGHT)
    elif event.is_action_pressed("ui_text_dedent"):        # Num2
        if hr: hr.receive_hit(HitReceiverComponent.HitType.HEAVY)
    elif event.is_action_pressed("ui_text_newline"):       # Num3
        if hr: hr.receive_hit(HitReceiverComponent.HitType.GRAB)
    elif event.is_action_pressed("ui_cut"):                # Num4
        if hr: hr.receive_hit(HitReceiverComponent.HitType.ENVIRONMENTAL, 1)
    elif event.is_action_pressed("ui_copy"):               # Num5
        if _kits: _kits.pick_up_kit()
    elif event.is_action_pressed("ui_paste"):              # Num6
        if _health: _health.full_restore()
        if _armour: _armour.set_full()
        if _kits:   _kits.refill_kits()


func _bar(current: int, maximum: int) -> String:
    var filled := int((float(current) / float(maximum)) * 10.0)
    var empty  := 10 - filled
    return "[" + "█".repeat(filled) + "░".repeat(empty) + "]"


func _bar_float(current: float, maximum: float) -> String:
    var filled := int((current / maximum) * 10.0)
    var empty  := 10 - filled
    return "[" + "█".repeat(filled) + "░".repeat(empty) + "]"
```

**Add to your test level:**

```
HealthDebugOverlay  (CanvasLayer)   ← health_debug_overlay.gd
└── DebugLabel  (Label)
      Layout: Full Rect
      Position: (520, 10)    ← offset right so it doesn't overlap stealth overlay
      Size: (380, 500)
      Font size: 13
      StyleBoxFlat background: Color(0, 0, 0, 0.6)
```

**Add these Input Map actions for the debug keys:**

```
ui_text_indent   → Numpad 1
ui_text_dedent   → Numpad 2
ui_text_newline  → Numpad 3
ui_cut           → Numpad 4
ui_copy          → Numpad 5
ui_paste         → Numpad 6
```

---

## Part 9 — Testing Checklist

Run through these in order. Each one isolates one layer of the system.

---

### Test 1 — Overlay is visible

Press **F5**. The health debug panel should appear on the right side of the screen.

```
HP:     [██████████]  3 / 3
Armour: [██████████]  100%
Kits:   [░░░░░░░░░░]  0 / 3
```

If `! health_component not found` appears:
- Components path is wrong — check it is `"Components/health_component"`
- Player is not in the `"player"` group

---

### Test 2 — Light hits degrade armour

Press **Numpad 1** three times. Armour bar should degrade each time.
On the third hit armour should break (bar empty, `Broken: YES`).
A fourth Numpad 1 should now deal 1 HP damage (escalates to heavy).

Wait 8 seconds without pressing anything. Armour should begin regenerating
and stop at 60%.

---

### Test 3 — Heavy and grab hits bypass armour

Press **Numpad 2** (heavy). HP should drop from 3 → 2 immediately regardless
of armour state.

Press **Numpad 3** (grab). HP should drop by 2 immediately (3→1 or 2→0).

---

### Test 4 — Critical state at HP 1

Get HP down to 1 (press Numpad 2 twice from full HP).

If `low_health_fx_component` is wired:
- Heartbeat audio should start
- Vignette should appear on screen edges
- Limp blend should activate in the animation tree

The console should print `[Player] HP critical!`

---

### Test 5 — Field kit pickup and use

Press **Numpad 5** three times — kit count should go from 0 → 1 → 2 → 3.
Pressing a fourth time should do nothing (already at max 3).

Drop HP to 2 (Numpad 2 once). Press **E** to use a kit.
The overlay should show `USING — 0% → 100% complete` over 1.2 seconds.
After 1.2 seconds HP should restore to 3 and armour should be full.

Take a hit during the 1.2s window. The console should print
`[Player] Kit interrupted!` and the kit should be refunded (count unchanged).

---

### Test 6 — Cannot use kit at full HP

With HP at 3 (full), press **E**. Nothing should happen.
`field_kit_component._can_use()` returns false when HP is already full.

---

### Test 7 — Full restore

Press **Numpad 6**. HP, armour, and kits should all return to maximum instantly.

---

### Test 8 — Player death

With HP at 1, press **Numpad 2** (heavy hit). HP should hit 0.
Console prints `[Player] Died.`
Player input and movement should be disabled.
Press Numpad 6 to restore (only works during testing — in real game use safe house).

---

## Part 10 — Hit Routing Quick Reference

This is what happens internally for each hit type. Use this when debugging
unexpected damage values.

```
receive_hit(LIGHT)
  armour intact?
    YES → armour degrades ~0.34,  0 HP lost,   emits LIGHT
    NO  → armour already broken,  -1 HP,        emits HEAVY (escalated)

receive_hit(HEAVY)
  → -1 HP regardless of armour,  emits HEAVY

receive_hit(GRAB)
  → -2 HP regardless of armour,  emits GRAB (uncounterable)

receive_hit(ENVIRONMENTAL, n)
  → -n HP regardless of armour,  emits ENVIRONMENTAL

ALL PATHS → armour.reset_regen_timer()
```

---

## Part 11 — Recovery Methods Quick Reference

```
Field kit (use_kit)
  Restores:  +1 HP + full armour
  Time:      1.2s exposed window
  Limit:     max 3 carried, not purchasable, found in world only
  Interrupt: taking any hit during 1.2s cancels use, kit refunded

Safe house visit
  Restores:  full HP + full armour + full kit resupply
  Time:      3–8 min navigating to safe house
  Limit:     can be burned in Act 2, trust affects access

Act 3 checkpoint
  Restores:  full HP + full armour
  When:      scripted, before Voss confrontation only
  Note:      only scripted full heal in the game

Passive armour regen
  Restores:  armour to ~60% only
  Time:      8s out of combat (6s with upgrade)
  Interrupt: any hit resets the 8s timer
  Cap:       NEVER reaches 100% passively
```

---

## Part 12 — Setup Summary Card

```
HEALTH SYSTEM CHECKLIST
────────────────────────────────────────────────

PLAYER SCENE  (group: "player")
  □ Components/health_component         health_component.gd
  □ Components/armour_component         armour_component.gd
  □ Components/hit_receiver_component   hit_receiver_component.gd
  □ Components/field_kit_component      field_kit_component.gd
  □ Components/low_health_fx_component  low_health_fx_component.gd

INSPECTOR ASSIGNMENTS
  □ hit_receiver_component
      health_component → Components/health_component
      armour_component → Components/armour_component
  □ field_kit_component
      health_component       → Components/health_component
      armour_component       → Components/armour_component
      hit_receiver_component → Components/hit_receiver_component
  □ low_health_fx_component
      health_component → Components/health_component
      (audio/vignette/anim optional for now)

PLAYER.GD
  □ @onready references for all 5 components
  □ _wire_hit_receiver() in _ready()
  □ _wire_field_kit() in _ready()
  □ _wire_health_signals() in _ready()
  □ _wire_low_health_fx() in _ready()
  □ _input() handles use_kit action

INPUT MAP
  □ use_kit action bound to E (or preferred key)
  □ Numpad 1–6 for debug shortcuts

WORLD
  □ FieldKitPickup scenes placed in level
  □ SafeHouse trigger placed if needed

DEBUG OVERLAY
  □ HealthDebugOverlay (CanvasLayer) in level
  □ DebugLabel child — Full Rect, font 13, dark background
  □ health_debug_overlay.gd on the CanvasLayer

────────────────────────────────────────────────
QUICK FAULT GUIDE

HP never changes after hits
  → hit_receiver_component.health_component not assigned

Armour never degrades
  → hit_receiver_component.armour_component not assigned

Kit use does nothing
  → field_kit_component.hit_receiver_component not assigned
  → OR kit_count is 0 (press Numpad 5 to pick up a kit)
  → OR HP is already full

Kit interruption not working
  → field_kit_component._ready() runs before wiring in player._ready()
  → Ensure field_kit is wired before its _ready() calls connect()

Critical FX not triggering
  → low_health_fx_component.health_component not assigned
  → OR audio/vignette/anim nodes not assigned (warnings in output are expected)

Player can't move after death
  → Expected — movement disabled in _on_player_died()
  → Press Numpad 6 to restore during testing

Armour regenerates to 100%
  → Should never happen — check REGEN_CAP constant in armour_component.gd
  → Must be 0.6, not 1.0
────────────────────────────────────────────────
```
