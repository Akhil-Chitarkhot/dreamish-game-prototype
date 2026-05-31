# Stealth Level Setup Guide
## Complete Step-by-Step Reference

---

## Before You Start — One-Time Project Setup

These steps only need to be done once for the entire project, not per level.

---

### 1. Name Your Physics Layers

Go to **Project → Project Settings → Layer Names → 3D Physics** and type these names exactly:

```
Layer 1: world
Layer 2: player
Layer 3: enemy
Layer 4: zones
Layer 5: district
```

---

### 2. Set Up the Input Map

Go to **Project → Project Settings → Input Map**.

For each action below, click **Add Action**, type the name, press Enter, then click the **+** button and press the corresponding key:

```
use_kit        → whatever healing key you want (e.g. E)
ui_page_up     → F1
ui_page_down   → F2
ui_home        → F3
ui_end         → F4
ui_select      → F5
```

---

### 3. Verify Player Has the stealth_component

Open your **Player scene**. Find the `Components` node. It must have a child called
`stealth_component` with `stealth_component.gd` attached.

If it is missing:
- Right-click `Components` → **Add Child Node** → **Node** → name it `stealth_component`
- Drag `stealth_component.gd` onto it in the Inspector

Your player Components folder must look like this:
```
Player (CharacterBody3D)         ← group: "player"
└── Components
    ├── camera_component
    ├── input_component
    ├── movement_component
    └── stealth_component        ← must be here
```

---

### 4. Verify movement_component Feeds stealth_component

Open `movement_component.gd`. Confirm these lines exist at the top:
```gdscript
@onready var stealth_component: StealthComponent = 
    get_parent().get_parent().get_node_or_null("Components/stealth_component")
```

And at the bottom of `_physics_process(delta)`:
```gdscript
var player   := get_parent().get_parent() as CharacterBody3D
var speed    := player.velocity.length()
var speed_fraction: float = speed / move_speed
stealth_component.set_movement_speed(clampf(speed_fraction, 0.0, 1.0))

var sound: float
if speed < 0.1:
    sound = 0.0
elif speed > move_speed * 0.8:
    sound = 1.0
else:
    sound = 0.6
stealth_component.set_sound_output(sound)
```

---

## Part 1 — Create the Level Scene

---

### Step 1 — New Scene

- **Scene → New Scene**
- Set root node type to **Node3D**
- Name it whatever you want (e.g. `District_Warehouse`)
- **Save immediately** as `your_level_name.tscn`

---

### Step 2 — Add Lighting

Right-click the root node and add:

**WorldEnvironment**
- Click it → Inspector → Environment → **New Environment**
- Set Background Mode to `Sky` or `Color` — either is fine for testing

**DirectionalLight3D**
- Set Transform Rotation to `(-45, 45, 0)`
- Energy: `1.2`

Add **OmniLight3D** nodes for distinct lit and dark areas. Suggested positions for a
standard test layout:

```
Light_Courtyard  (OmniLight3D)   position: (-6, 3, -6)   energy: 2.5
Light_Warehouse  (OmniLight3D)   position: (8, 3, 8)     energy: 0.4
```

The bright light defines the lit zone. The dim light defines the shadow zone.

---

### Step 3 — Build the Geometry

Right-click the root → **Add Child Node** → **Node3D** → name it `Geometry`.

Inside `Geometry`, add **CSGBox3D** nodes for each piece. Set the listed size and
position in the Inspector under **Transform**:

```
Floor       CSGBox3D    Size: (40, 1, 40)     Position: (0, -0.5, 0)
Wall_North  CSGBox3D    Size: (40, 4, 1)      Position: (0, 2, -20)
Wall_South  CSGBox3D    Size: (40, 4, 1)      Position: (0, 2, 20)
Wall_East   CSGBox3D    Size: (1, 4, 40)      Position: (20, 2, 0)
Wall_West   CSGBox3D    Size: (1, 4, 40)      Position: (-20, 2, 0)
Cover_Box   CSGBox3D    Size: (3, 2, 3)       Position: (5, 1, 5)
```

**Set collision on all geometry:**
- Select all CSGBox3D nodes
- Inspector → **Use Collision: ON**
- Set their Layer to **1** (world), Mask to **(none)**

---

## Part 2 — Set Up the District

The district is a large Area3D that covers the entire playable area. It tracks tactic
counts via `threat_ceiling_component` and detects when the player enters or exits.

---

### Step 4 — Create the District Node

Right-click the root → **Add Child Node** → **Area3D** → name it `District_01`.

**Add to group:**
- With `District_01` selected → click the **Node** tab (beside Inspector)
- Click **Groups** → type `district` → click **Add**

**Add CollisionShape3D:**
- Right-click `District_01` → **Add Child Node** → **CollisionShape3D**
- Inspector → Shape → **New BoxShape3D**
- Set Size to `(38, 10, 38)`
- Leave Position at `(0, 0, 0)`

**Set collision layers:**
- Select `District_01`
- Inspector → **Collision** section
- Layer: **5** (district)
- Mask: **2** (player)

**Add threat_ceiling_component:**
- Right-click `District_01` → **Add Child Node** → **Node**
- Name it `threat_ceiling_component` (must match exactly)
- Drag `threat_ceiling_component.gd` onto the script slot in Inspector
- Set `district_name` to whatever this district is called

---

## Part 3 — Set Up Stealth Zones

Zones are Area3D nodes inside the district. They push light, sound, and motion
modifiers onto the player when entered.

---

### Step 5 — Create Zone_Lit

Right-click `District_01` → **Add Child Node** → **Area3D** → name it `Zone_Lit`.

**Add CollisionShape3D:**
- Right-click `Zone_Lit` → **Add Child Node** → **CollisionShape3D**
- Shape → **New BoxShape3D**
- Size: `(18, 6, 18)`
- Position: `(-5, 3, -5)`

**Set collision:**
- Layer: **4** (zones)
- Mask: **2** (player)

**Add stealth_zone_component:**
- Right-click `Zone_Lit` → **Add Child Node** → **Node**
- Name it `stealth_zone_component`
- Drag `stealth_zone_component.gd` onto it
- Set in Inspector:
  ```
  zone_type:           LIT
  detection_threshold: 0.25
  ```

---

### Step 6 — Create Zone_Shadow

Right-click `District_01` → **Add Child Node** → **Area3D** → name it `Zone_Shadow`.

**Add CollisionShape3D:**
- Shape → **New BoxShape3D**
- Size: `(14, 6, 14)`
- Position: `(8, 3, 8)`

**Set collision:**
- Layer: **4** (zones)
- Mask: **2** (player)

**Add stealth_zone_component:**
- Right-click `Zone_Shadow` → **Add Child Node** → **Node**
- Name it `stealth_zone_component`
- Drag `stealth_zone_component.gd` onto it
- Set in Inspector:
  ```
  zone_type:           SHADOW
  detection_threshold: 0.65
  ```

---

### Zone Type Quick Reference

Use this when adding more zones later:

| Zone Type    | Light Mult | Sound Mult | Suggested Threshold | Use Case                  |
|--------------|-----------|-----------|---------------------|---------------------------|
| LIT          | ×1.0      | ×1.0      | 0.25                | Floodlit open area        |
| SHADOW       | ×0.1      | ×1.0      | 0.65                | Dark corner or alley      |
| ELEVATED     | ×1.0      | ×0.5      | 0.55                | Rooftop above patrol      |
| RAIN         | ×1.0      | ×0.6      | 0.45                | Outdoor rain area         |
| DOG_PATROL   | ignored   | ×1.0      | 0.40                | Animal patrol zone        |
| CUSTOM       | you set   | you set   | you set             | Any special scenario      |

---

## Part 4 — Set Up Patrol Points

Patrol points are plain Node3D nodes that the guard walks between.

---

### Step 7 — Create the Patrol Route

Right-click the root → **Add Child Node** → **Node3D** → name it `PatrolRoutes`.

Right-click `PatrolRoutes` → **Add Child Node** → **Node3D** → name it `GuardPatrol_01`.

Inside `GuardPatrol_01`, add four **Node3D** nodes:

```
Point_A    Position: (-4, 0, -4)
Point_B    Position: (-8, 0, -4)
Point_C    Position: (-8, 0, -8)
Point_D    Position: (-4, 0, -8)
```

This creates a square loop inside the lit zone. Place them wherever you want
the guard to patrol — just keep them inside the zone you assigned to that guard.

**Tip — visualising patrol points in the editor:**
Add a tiny CSGSphere3D as a child of each Point node (radius 0.2). This shows
their positions as small spheres in the viewport. Disable their collision in the
Inspector so they do not affect gameplay.

---

## Part 5 — Set Up the Guard

---

### Step 8 — Create the Guard Scene

**Scene → New Scene** → root node **CharacterBody3D** → name it `Guard` → save as
`guard.tscn`.

Build this exact structure:

```
Guard  (CharacterBody3D)
├── MeshInstance3D
├── CollisionShape3D
└── Components  (Node)
    ├── awareness_component   (Node)
    └── alert_state_machine_component  (Node)
```

**MeshInstance3D:**
- Mesh → **New CapsuleMesh** → Height: `1.8`, Radius: `0.35`
- Surface Material Override → **New StandardMaterial3D**
- Albedo Colour → red `(1, 0, 0, 1)`

**CollisionShape3D:**
- Shape → **New CapsuleShape3D** → Height: `1.8`, Radius: `0.35`

**awareness_component:**
- Right-click `Components` → Add Child Node → Node → name it `awareness_component`
- Drag `awareness_component.gd` onto the script slot
- Leave `patrol_zone` empty for now (assigned after placing in level)
- Set:
  ```
  default_threshold:  0.65
  detection_range:    18.0
  eye_offset:         Vector3(0, 0.8, 0)
  is_dog:             false
  los_check_interval: 0.1
  ```

**alert_state_machine_component:**
- Right-click `Components` → Add Child Node → Node
- Name it `alert_state_machine_component`
- Drag `alert_state_machine_component.gd` onto the script slot
- Drag the `awareness_component` node into the `awareness_component` export slot
- Leave `patrol_zone` empty for now

**Attach guard.gd:**
- Click the root `Guard` node
- Drag `guard.gd` onto the script slot in the Inspector

**Add to group:**
- Select root `Guard` node → **Node tab → Groups** → add `guard`

**Set guard collision:**
- Select root `Guard` node
- Collision Layer: **3** (enemy)
- Collision Mask: **1** (world)

**Save the scene.**

---

## Part 6 — Place the Guard in the Level

---

### Step 9 — Instance the Guard

Back in your level scene, drag `guard.tscn` from the FileSystem panel onto
`District_01` in the scene tree. The guard should appear as a child of `District_01`.

Position the guard at `(-5, 0, -5)` — inside the lit zone.

---

### Step 10 — Assign Patrol Points

Click the guard instance in the scene tree. In the Inspector find `patrol_points` (Array).

- Click the array field
- Press the **+** button four times to create four slots
- Drag `Point_A` from the scene tree into slot 0
- Drag `Point_B` into slot 1
- Drag `Point_C` into slot 2
- Drag `Point_D` into slot 3

---

### Step 11 — Assign Zones to Guard Components

With the guard selected, expand it in the scene tree to find its components.

**Click awareness_component:**
- Drag `Zone_Lit` from the scene tree into the `patrol_zone` slot

**Click alert_state_machine_component:**
- Drag `Zone_Lit` into the `patrol_zone` slot

---

## Part 7 — Add the Player

---

### Step 12 — Instance the Player

Drag your `player.tscn` into the level scene. Position it at `(0, 0, 0)`.

Confirm the player node is in the `player` group:
- Select Player → **Node tab → Groups** → confirm `player` is listed
- If not: type `player` → click **Add**

---

## Part 8 — Set Up the Debug Overlay

The debug overlay shows all stealth values live so you can verify everything works.

---

### Step 13 — Create the CanvasLayer

Right-click the root node → **Add Child Node** → **CanvasLayer** → name it
`DebugOverlay`.

Drag `stealth_debug_overlay.gd` onto the `DebugOverlay` node's script slot.

---

### Step 14 — Create the Label

Right-click `DebugOverlay` → **Add Child Node** → **Label** → name it `DebugLabel`.

**Configure the label:**
- **Layout Mode** → Anchors
- **Anchors Preset** → Full Rect (the rectangle icon in the 2D toolbar)
- **Position** → `(10, 10)`
- **Size** → `(500, 800)`
- **Theme Overrides → Font Sizes → Font Size** → `13`
- **Theme Overrides → Styles → Normal** → New StyleBoxFlat
  - Bg Color → `(0, 0, 0, 0.6)`
  - Content Margin Left/Right/Top/Bottom → all `8`

---

## Part 9 — Final Scene Tree Check

Before pressing play, your scene tree must look exactly like this:

```
YourLevelName  (Node3D)
├── WorldEnvironment
├── DirectionalLight3D
├── Light_Courtyard   (OmniLight3D)
├── Light_Warehouse   (OmniLight3D)
│
├── Geometry  (Node3D)
│   ├── Floor        (CSGBox3D)
│   ├── Wall_North   (CSGBox3D)
│   ├── Wall_South   (CSGBox3D)
│   ├── Wall_East    (CSGBox3D)
│   ├── Wall_West    (CSGBox3D)
│   └── Cover_Box    (CSGBox3D)
│
├── PatrolRoutes  (Node3D)
│   └── GuardPatrol_01  (Node3D)
│       ├── Point_A  (Node3D)
│       ├── Point_B  (Node3D)
│       ├── Point_C  (Node3D)
│       └── Point_D  (Node3D)
│
├── District_01  (Area3D)   ← group: "district"
│   ├── CollisionShape3D
│   ├── threat_ceiling_component
│   ├── Zone_Lit  (Area3D)
│   │   ├── CollisionShape3D
│   │   └── stealth_zone_component
│   ├── Zone_Shadow  (Area3D)
│   │   ├── CollisionShape3D
│   │   └── stealth_zone_component
│   └── Guard  (CharacterBody3D)   ← group: "guard"
│       ├── MeshInstance3D
│       ├── CollisionShape3D
│       └── Components
│           ├── awareness_component
│           └── alert_state_machine_component
│
├── Player  (CharacterBody3D)   ← group: "player"
│   └── Components
│       ├── camera_component
│       ├── input_component
│       ├── movement_component
│       └── stealth_component
│
└── DebugOverlay  (CanvasLayer)   ← stealth_debug_overlay.gd
    └── DebugLabel  (Label)
```

---

## Part 10 — Collision Layer Master Table

This is the most common cause of things silently not working. Verify every node
matches this table exactly.

| Node                         | Layer | Mask       | Why                                    |
|------------------------------|-------|------------|----------------------------------------|
| Floor / Walls / Cover        | 1     | none       | World geometry, nothing detects it     |
| Player CharacterBody3D       | 2     | 1          | Moves through world                    |
| Guard CharacterBody3D        | 3     | 1          | Moves through world                    |
| Zone_Lit Area3D              | 4     | 2          | Detects player body entering           |
| Zone_Shadow Area3D           | 4     | 2          | Detects player body entering           |
| District_01 Area3D           | 5     | 2          | Detects player entering district       |

**LoS raycast mask** — in `awareness_component.gd` find `_run_los_raycast()` and
confirm this line exists after creating the query:

```gdscript
query.collision_mask = 0b00000011   # hits layers 1 (world) and 2 (player) only
```

This stops the raycast from hitting zone volumes or other guards.

---

## Part 11 — Testing Checklist

Run through this every time you set up a new level to confirm everything works.

---

### Test 1 — Overlay is visible

Press **F5**. The debug panel should appear in the top-left corner immediately.

**If it shows `! stealth_component not found`:**
- Player is not in the `player` group, OR
- `stealth_component` is missing from `Components`, OR
- Path in `stealth_debug_overlay.gd` is wrong (should be `"Components/stealth_component"`)

**If it shows `! awareness_component not found`:**
- Guard is not in the `guard` group

---

### Test 2 — Guard patrols

Guard should immediately start walking between the four patrol points.

**If guard stands still:**
- `patrol_points` array is empty in the Inspector
- Check that Point_A through Point_D are assigned

**If guard falls through the floor:**
- Guard collision mask does not include layer 1 (world)
- Floor UseCollision is OFF

---

### Test 3 — Zone modifiers work

Walk into the shadow zone. Watch the debug overlay:

```
Light effective should DROP from 1.00 to 0.10
Active modifiers should read: 1
```

Walk back out:
```
Light effective should RETURN to 1.00
Active modifiers should read: 0
```

**If modifiers never change:**
- Zone Area3D collision layer is not 4, or mask is not 2
- Player CharacterBody3D mask does not include layer 4
- Player is not in the `player` group

---

### Test 4 — Awareness rises

Walk slowly into the lit zone and approach the guard.

```
In range:       YES
Line of sight:  YES
Awareness:      should climb above 0%
```

**If In range stays NO:**
- `stealth_component` path is wrong in `awareness_component._ready()`
- Should be: `player_node.get_node_or_null("Components/stealth_component")`

**If LoS stays NO:**
- Raycast collision mask is wrong — should hit layer 1 and 2
- The guard and player are on the same layer, causing self-intersection

---

### Test 5 — State transitions

| Action                                   | Expected result                        |
|------------------------------------------|----------------------------------------|
| Walk slowly toward guard in lit zone     | Guard turns yellow (SUSPICIOUS)        |
| Stand still for 6 seconds               | Guard returns to green (UNAWARE)       |
| Run at guard                             | Guard turns orange (ALERTED)           |
| Hide behind Cover_Box for 12 seconds    | Guard returns to yellow, then green    |
| Run directly at guard from close range  | Guard turns white (FULL ALERT)         |
| Leave district, wait 30 seconds         | Guard chains back to green             |

---

### Test 6 — Debug shortcut keys

| Key | Expected result                                           |
|-----|-----------------------------------------------------------|
| F1  | Guard immediately turns orange (body found override)      |
| F2  | Grapple count increases by 1 (shown in overlay)           |
| F2 × 3 | `adaptation_telegraphed` fires, 90s timer starts      |
| F3  | EMP count increases                                       |
| F4  | Aerial count increases                                    |
| F5  | Ceiling frozen line shows `YES — 90.0s left`              |

---

## Part 12 — Adding a Second Guard

---

### Steps

1. Add a second patrol route under `PatrolRoutes`:

```
GuardPatrol_02  (Node3D)
├── Point_A    Position: (6, 0, 6)
├── Point_B    Position: (10, 0, 6)
├── Point_C    Position: (10, 0, 10)
└── Point_D    Position: (6, 0, 10)
```

2. Drag another instance of `guard.tscn` onto `District_01`

3. Position it at `(8, 0, 8)` — inside the shadow zone

4. Assign patrol points to the new guard's `patrol_points` array (GuardPatrol_02 points)

5. On the new guard's `awareness_component`:
   - `patrol_zone` → `Zone_Shadow`

6. On the new guard's `alert_state_machine_component`:
   - `patrol_zone` → `Zone_Shadow`

7. Add this guard to the `guard` group

The debug overlay only shows the first guard it finds via the `guard` group.
To monitor a specific guard, change this line in `stealth_debug_overlay.gd`:

```gdscript
# Change:
var guard := guards[0]

# To target a guard by name:
var guard := get_tree().get_nodes_in_group("guard").filter(
    func(g): return g.name == "Guard2")[0]
```

---

## Common Mistakes Quick Reference

| Symptom                            | Most Likely Cause                                          |
|------------------------------------|------------------------------------------------------------|
| Overlay shows nothing              | Script on wrong node (must be on CanvasLayer, not Label)   |
| Awareness always 0%                | stealth_component path wrong in awareness_component        |
| Zone modifiers never apply         | Collision layer/mask mismatch on zones or player           |
| Guard doesn't patrol               | patrol_points array empty in Inspector                     |
| Guard falls through floor          | Guard collision mask missing layer 1                       |
| District never detected            | District Area3D not in "district" group                    |
| F1-F5 keys do nothing              | Input Map actions not set up in Project Settings           |
| LoS always NO despite facing guard | Raycast mask hitting wrong layers                          |
| State never decays back            | patrol_zone not assigned on alert_state_machine_component  |

---

## Part 13 — Adding More Zone Types

Each new zone follows the exact same four steps as Zone_Lit and Zone_Shadow.
The only thing that changes is the zone_type and detection_threshold values.

---

### Rain Zone

Right-click `District_01` → Add Child Node → Area3D → name it `Zone_Rain`.

```
Zone_Rain  (Area3D)
└── CollisionShape3D    BoxShape3D — cover the rainy outdoor area
    stealth_zone_component
        zone_type:           RAIN
        detection_threshold: 0.45
```

Collision: Layer 4, Mask 2.

Rain zones stack well with shadow zones. If a dark alley is also raining, place
both a `Zone_Shadow` and a `Zone_Rain` Area3D overlapping the same space.
The stealth_component multiplies both modifier sets automatically:
- Sound from shadow: ×1.0
- Sound from rain: ×0.6
- Final sound: ×0.6

---

### Elevated Zone

Used for rooftops, catwalks, or anywhere above the enemy's eye line.

```
Zone_Elevated  (Area3D)
└── CollisionShape3D    BoxShape3D — positioned high up, e.g. Position (0, 6, 0)
    stealth_zone_component
        zone_type:           ELEVATED
        detection_threshold: 0.55
```

The ELEVATED type reduces sound output by ×0.5 — guards below hear the player
less clearly. Light is unmodified, so being elevated but visible is still dangerous.

---

### Dog Patrol Zone

```
Zone_Dog  (Area3D)
└── CollisionShape3D    BoxShape3D — the dog's patrol area
    stealth_zone_component
        zone_type:           DOG_PATROL
        detection_threshold: 0.40
```

When the player is inside a DOG_PATROL zone, light_exposure is completely ignored
regardless of how lit the area is. Only sound and motion matter.
The guard assigned to this zone should have `is_dog: true` on its
`awareness_component`.

---

### Custom Zone Example — Gas Leak Room

A room where a chemical leak muffles sound by 80% but visibility is unaffected.

```
Zone_GasRoom  (Area3D)
└── CollisionShape3D
    stealth_zone_component
        zone_type:              CUSTOM
        detection_threshold:    0.50
        custom_light_mult:      1.0
        custom_sound_mult:      0.2
        custom_motion_mult:     1.0
        custom_ignore_light:    false
```

---

## Part 14 — Adding a Second District

Each distinct patrol area in your game gets its own district. Districts are
independent — a FULL_ALERT in District_01 does not affect District_02.

---

### Steps

1. Right-click the root → Add Child Node → Area3D → name it `District_02`
2. Add it to the `district` group
3. Add a CollisionShape3D covering its area — make sure it does NOT overlap
   `District_01`'s collision shape. Overlapping districts cause both to trigger
   simultaneously when the player stands near the boundary.

```
District_02  (Area3D)   ← group: "district"
├── CollisionShape3D    Size (38, 10, 38), offset so it doesn't overlap District_01
├── threat_ceiling_component
│     district_name: "District_02"
├── Zone_Lit_02   (Area3D)
│   ├── CollisionShape3D
│   └── stealth_zone_component
└── Guard_03  (instance of guard.tscn)
    ├── awareness_component   patrol_zone → Zone_Lit_02
    └── alert_state_machine_component   patrol_zone → Zone_Lit_02
```

**Important:** Each guard must reference a zone from its own district.
A guard in District_02 referencing a zone from District_01 will use the wrong
detection threshold.

---

### Separating Districts in the Scene Tree

For bigger games, organise your scene tree like this to keep it readable:

```
World  (Node3D)
├── SharedGeometry
├── Districts
│   ├── District_01  (Area3D)
│   │   ├── ...zones and guards...
│   └── District_02  (Area3D)
│       ├── ...zones and guards...
├── PatrolRoutes
│   ├── GuardPatrol_01
│   └── GuardPatrol_02
└── Player
```

---

## Part 15 — Connecting Threat Ceiling Adaptations to the World

When a tactic threshold is crossed the `threat_ceiling_component` fires signals.
Those signals need to connect to something physical in the world.
Here is how to wire this up.

---

### Step 1 — Add a District Manager Script

Create a new script called `district_manager.gd` and attach it to the
`District_01` node itself (not the threat_ceiling_component child):

```gdscript
extends Area3D

@onready var ceiling: ThreatCeilingComponent = $threat_ceiling_component

# References to physical world objects that change on adaptation.
# Assign these in the Inspector after creating them.
@export var anti_grapple_nets:    Node3D = null
@export var overhead_mesh_panels: Node3D = null


func _ready() -> void:
    ceiling.adaptation_telegraphed.connect(_on_adaptation_telegraphed)
    ceiling.adaptation_deployed.connect(_on_adaptation_deployed)
    ceiling.ceiling_frozen.connect(_on_ceiling_frozen)
    ceiling.ceiling_unfrozen.connect(_on_ceiling_unfrozen)


func _on_adaptation_telegraphed(
        tactic: ThreatCeilingComponent.TacticType,
        adaptation_name: String,
        _window: float) -> void:
    # Guards radio aloud — player has 90s to act
    print("[District] WARNING: %s incoming in 90s" % adaptation_name)
    # TODO: play guard radio audio here


func _on_adaptation_deployed(
        tactic: ThreatCeilingComponent.TacticType,
        adaptation_name: String) -> void:
    print("[District] DEPLOYED: %s" % adaptation_name)

    match tactic:
        ThreatCeilingComponent.TacticType.GRAPPLE_ENTRY:
            if anti_grapple_nets:
                anti_grapple_nets.show()
                # Enable the net's collision so grapple hooks catch on it
                for child in anti_grapple_nets.get_children():
                    if child is CollisionShape3D:
                        child.disabled = false

        ThreatCeilingComponent.TacticType.AERIAL_TAKEDOWN:
            if overhead_mesh_panels:
                overhead_mesh_panels.show()
                for child in overhead_mesh_panels.get_children():
                    if child is CollisionShape3D:
                        child.disabled = false

        ThreatCeilingComponent.TacticType.EMP_USE:
            # Swap regular guards for surge-armoured variants
            # For now: just change their colour to show the upgrade
            for guard in get_tree().get_nodes_in_group("guard"):
                var mesh := guard.get_node_or_null("MeshInstance3D") as MeshInstance3D
                if mesh:
                    var mat := StandardMaterial3D.new()
                    mat.albedo_color = Color(0.6, 0.0, 0.0)   # darker red = armoured
                    mesh.set_surface_override_material(0, mat)


func _on_ceiling_frozen(duration: float) -> void:
    print("[District] Ceiling frozen for %.0f seconds" % duration)


func _on_ceiling_unfrozen() -> void:
    print("[District] Ceiling unfrozen — adaptations resume")
```

---

### Step 2 — Create the Physical Adaptation Objects

In your level, create placeholder objects for each adaptation. These start hidden.

**Anti-grapple nets:**

```
AntiGrappleNets  (Node3D)   ← starts hidden (visible: OFF in Inspector)
├── MeshInstance3D           ← a flat BoxMesh stretched across grapple anchor spots
└── CollisionShape3D         ← disabled at start, enabled on deployment
      disabled: true
```

Set its position to block your main grapple anchor points.

**Overhead mesh panels:**

```
OverheadMeshPanels  (Node3D)   ← starts hidden
├── MeshInstance3D             ← flat mesh stretched across aerial approach zones
└── CollisionShape3D
      disabled: true
```

---

### Step 3 — Assign Them in the Inspector

Select `District_01`. In the Inspector you should now see the `district_manager.gd`
export slots:

```
anti_grapple_nets:    [drag AntiGrappleNets here]
overhead_mesh_panels: [drag OverheadMeshPanels here]
```

---

### Step 4 — Register Tactics From Player Actions

In whatever script handles grappling, add one line when the grapple lands:

```gdscript
func _on_grapple_landed() -> void:
    _register_tactic(ThreatCeilingComponent.TacticType.GRAPPLE_ENTRY)


func _register_tactic(tactic: ThreatCeilingComponent.TacticType) -> void:
    for district in get_tree().get_nodes_in_group("district"):
        var ceiling := district.get_node_or_null("threat_ceiling_component") \
                       as ThreatCeilingComponent
        if ceiling and ceiling._player_in_district:
            ceiling.register_tactic(tactic)
            return
```

Add the same helper and call it from your EMP and aerial takedown scripts,
passing the relevant TacticType enum value.

---

## Part 16 — Scaling Up to a Real Level

Once testing works, here is how to move from a CSGBox3D blockout to real level
geometry without breaking anything.

---

### Replacing CSGBox3D Geometry

The stealth system does not care what the geometry looks like. You can replace
every CSGBox3D with imported meshes at any time. The only requirement is that
your world geometry stays on **collision Layer 1** so the LoS raycasts hit it.

When you import a mesh:
- Add a **StaticBody3D** as a parent of your MeshInstance3D
- Add a **CollisionShape3D** or use **Trimesh** collision
- Set the StaticBody3D collision Layer to **1**, Mask to **none**

---

### Resizing Zone Volumes

Zone Area3D collision shapes do not need to match the visual geometry exactly.
Think of them as invisible gameplay regions. Resize them freely in the editor
by adjusting the BoxShape3D size until they cover the right area.

A good habit: make zones slightly smaller than the visual space they represent.
This means the player is visually inside a shadow before the modifier kicks in,
which feels more fair than the modifier triggering before the player is visibly
in the dark.

---

### Adding More Patrol Points

Patrol points can be any Node3D placed anywhere in the level.
There is no limit on how many you add per route.
Just expand the `patrol_points` array in the guard's Inspector and add more slots.

For a more interesting patrol, mix positions across different heights. Guards
will walk directly toward each point, so place points along the actual walkable
path to avoid them walking through walls.

---

### Performance — Multiple Guards

Each guard runs a LoS raycast every `los_check_interval` seconds (default 0.1s).
With many guards this adds up. Recommendations:

| Guard count | los_check_interval setting |
|-------------|---------------------------|
| 1–5         | 0.1s  (10 checks/second)  |
| 6–12        | 0.15s (7 checks/second)   |
| 13–20       | 0.2s  (5 checks/second)   |
| 20+         | 0.3s + consider distance culling |

For guards far from the player, increase `los_check_interval` or disable
their `awareness_component._physics_process` entirely until the player
enters their detection range. Add this to `guard.gd`:

```gdscript
func _physics_process(delta: float) -> void:
    # Only run full AI when player is within outer range
    var player_dist := global_position.distance_to(
        get_tree().get_nodes_in_group("player")[0].global_position)

    # Disable awareness processing when very far away
    $Components/awareness_component.set_physics_process(player_dist < 40.0)

    # ... rest of your physics process
```

---

## Part 17 — Script and File Organisation

Keep all stealth-related scripts in one folder so they are easy to find.
Recommended file structure:

```
res://
├── scripts/
│   ├── player/
│   │   ├── player.gd
│   │   ├── health_component.gd
│   │   ├── armour_component.gd
│   │   ├── hit_receiver_component.gd
│   │   ├── field_kit_component.gd
│   │   ├── low_health_fx_component.gd
│   │   └── stealth_component.gd
│   ├── stealth/
│   │   ├── stealth_zone_component.gd
│   │   ├── awareness_component.gd
│   │   ├── alert_state_machine_component.gd
│   │   └── threat_ceiling_component.gd
│   └── enemies/
│       └── guard.gd
├── scenes/
│   ├── player/
│   │   └── player.tscn
│   ├── enemies/
│   │   └── guard.tscn
│   └── levels/
│       └── test_stealth_level.tscn
└── debug/
    └── stealth_debug_overlay.gd
```

---

## Part 18 — Level Setup Summary Card

Cut this out and keep it as a quick reference when building new levels.

```
NEW LEVEL CHECKLIST
────────────────────────────────────────────────

SCENE ROOT
  □ Node3D root
  □ WorldEnvironment
  □ DirectionalLight3D
  □ OmniLight3D nodes for lit/shadow areas

GEOMETRY  (all Layer 1, Mask none, UseCollision ON)
  □ Floor
  □ Walls
  □ Cover objects

DISTRICT  (Area3D)
  □ Added to "district" group
  □ CollisionShape3D  (BoxShape3D covering whole area)
  □ Layer 5, Mask 2
  □ threat_ceiling_component  (district_name set)

PER ZONE  (Area3D inside District)
  □ CollisionShape3D  (positioned and sized)
  □ Layer 4, Mask 2
  □ stealth_zone_component  (zone_type + threshold set)

PATROL ROUTE  (Node3D outside District)
  □ Node3D container
  □ 4+ Point_N Node3D children with positions set

PER GUARD  (instance of guard.tscn inside District)
  □ Added to "guard" group
  □ Layer 3, Mask 1
  □ patrol_points array → Point_A through Point_D assigned
  □ awareness_component → patrol_zone → correct zone
  □ alert_state_machine_component → awareness_component assigned
  □ alert_state_machine_component → patrol_zone → correct zone

PLAYER  (instance of player.tscn)
  □ Added to "player" group
  □ Layer 2, Mask 1
  □ Components/stealth_component exists and has script

DEBUG OVERLAY  (CanvasLayer)
  □ stealth_debug_overlay.gd on the CanvasLayer node
  □ DebugLabel (Label) child — Full Rect anchor, font size 13

────────────────────────────────────────────────
QUICK FAULT GUIDE

Awareness stuck at 0%
  → Check Components/stealth_component path in awareness_component._ready()

Zone modifiers not applying
  → Zone Layer 4 + Mask 2 / Player Mask includes 4

Guard won't patrol
  → patrol_points array empty in Inspector

State won't decay
  → patrol_zone not assigned on alert_state_machine_component

Overlay empty
  → Script on CanvasLayer not Label / check group names

LoS always blocked
  → Raycast mask = 0b00000011 (layers 1 and 2 only)
────────────────────────────────────────────────
```
