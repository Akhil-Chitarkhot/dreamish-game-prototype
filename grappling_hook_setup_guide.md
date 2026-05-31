# Grappling Hook System — Complete Setup Guide
### Godot 4.6 | Composition-Based | Third Person

---

## Overview

This guide walks through setting up a Batman-style grappling hook system from scratch.
The system works as follows:

1. Valid grapple points in the level get highlighted when the player looks at them
2. Player presses the grapple button
3. Player zips along an arc to the ledge edge
4. Player hangs on the ledge
5. Player presses the button again to climb onto the roof

The system is built as a **component** that slots into an existing composition-based
player setup alongside `movement_component`, `input_component`, and `camera_component`.

---

## Files You Will Create

| File | Purpose |
|---|---|
| `grapple_point.gd` | Script for placeable level markers |
| `grapple_point.tscn` | Scene you drag into your levels |
| `grapple_component.gd` | The main system — lives inside the player |
| `grapple_highlight.tres` | Glowing material shown on valid targets |

---

## Prerequisites

Before starting, confirm you have:

- A working **CharacterBody3D** player with composition structure
- `Components` node containing your existing components
- Camera at path: `Player → CameraPivot → SpringArm3D → Camera3D`
- Basic third person movement already working

---

## Part 1: The Scripts

Create these two script files first before building any scenes.

---

### 1.1 — Create `grapple_point.gd`

In the **FileSystem** panel, navigate to your scripts folder.
Right click → **New Script** → name it `grapple_point.gd`.

Paste the following:

```gdscript
# grapple_point.gd
# Attach to the root node of grapple_point.tscn
# Place instances of that scene around your level at ledge edges
class_name GrapplePoint
extends Node3D

enum Type {
    LEDGE,      # player zips to edge and climbs up
    ZIPLINE,    # player travels horizontally and drops off
    HANG        # player just hangs, no auto climb
}

@export var type: Type = Type.LEDGE
@export var climb_destination: Marker3D   # assign ClimbDestination marker in Inspector
@export var surface_normal: Vector3 = Vector3.FORWARD

@onready var editor_mesh = $MeshInstance3D

func _ready():
    # Hide the editor sphere during the game
    editor_mesh.visible = false

func get_climb_position() -> Vector3:
    if climb_destination:
        return climb_destination.global_position
    # Fallback if no destination assigned: go up from ledge
    return global_position + Vector3.UP * 1.8

func get_surface_normal() -> Vector3:
    return global_transform.basis * surface_normal
```

Save the file.

---

### 1.2 — Create `grapple_component.gd`

Right click in your scripts folder → **New Script** → name it `grapple_component.gd`.

Paste the following:

```gdscript
# grapple_component.gd
# Attach to: Components/grapple_component (Node3D) inside your Player
# Requires:  - GrapplePoint nodes in the level added to "grapple_points" group
#            - Input action "grapple" in Project Settings > Input Map
#            - Camera3D at path: CameraPivot/SpringArm3D/Camera3D (relative to owner)
class_name GrappleComponent
extends Node3D

# ---------------------------------------------------------------------------
# Signals — movement_component listens to these to pause/resume control
# ---------------------------------------------------------------------------
signal grapple_started(target: GrapplePoint)
signal grapple_completed
signal grapple_cancelled

# ---------------------------------------------------------------------------
# Inspector exports
# ---------------------------------------------------------------------------
@export_group("Detection")
@export var max_range: float = 25.0
@export var detection_angle: float = 45.0

@export_group("Travel")
@export var travel_duration: float = 0.6
@export var arc_depth_ratio: float = 0.2

@export_group("Visuals")
@export var highlight_material: Material

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var player: CharacterBody3D
var camera: Camera3D

var all_grapple_points: Array[GrapplePoint] = []
var current_candidate: GrapplePoint = null

var is_grappling: bool = false
var grapple_target: GrapplePoint = null
var travel_t: float = 0.0
var travel_start: Vector3 = Vector3.ZERO
var travel_control: Vector3 = Vector3.ZERO

var is_hanging: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
    player = owner as CharacterBody3D
    camera = owner.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D

    if not player:
        push_error("GrappleComponent: owner is not a CharacterBody3D")
        return
    if not camera:
        push_error("GrappleComponent: could not find Camera3D at CameraPivot/SpringArm3D/Camera3D")
        return

    _register_all_points()


func _physics_process(delta: float) -> void:
    if not is_grappling and not is_hanging:
        _update_candidate()
    if is_grappling:
        _update_travel(delta)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("grapple"):
        if is_hanging:
            attempt_climb()
        else:
            attempt_grapple()

# ---------------------------------------------------------------------------
# System 1 — Registration
# ---------------------------------------------------------------------------
func _register_all_points() -> void:
    all_grapple_points.clear()
    for node in get_tree().get_nodes_in_group("grapple_points"):
        if node is GrapplePoint:
            all_grapple_points.append(node)

func refresh_grapple_points() -> void:
    _register_all_points()

# ---------------------------------------------------------------------------
# System 2 — Detection
# ---------------------------------------------------------------------------
func _update_candidate() -> void:
    var best: GrapplePoint = null
    var best_score: float = -1.0

    for point in all_grapple_points:
        var score = _score_point(point)
        if score > best_score:
            best_score = score
            best = point

    if best != null and _has_line_of_sight(best):
        _set_candidate(best)
    else:
        _set_candidate(null)


func _score_point(point: GrapplePoint) -> float:
    var to_point: Vector3 = point.global_position - player.global_position
    var distance: float = to_point.length()

    if distance > max_range:
        return -1.0

    var camera_forward: Vector3 = -camera.global_transform.basis.z
    var dot: float = camera_forward.dot(to_point.normalized())
    if dot < 0.0:
        return -1.0

    var angle_score: float = (dot + 1.0) / 2.0
    var distance_score: float = 1.0 - (distance / max_range)

    return (angle_score * 0.7) + (distance_score * 0.3)


func _has_line_of_sight(point: GrapplePoint) -> bool:
    var space_state = get_world_3d().direct_space_state
    var origin: Vector3 = player.global_position + Vector3.UP * 1.0
    var target: Vector3 = point.global_position

    var query = PhysicsRayQueryParameters3D.create(origin, target)
    query.exclude = [player]

    var result = space_state.intersect_ray(query)
    return result.is_empty() or result.collider == point


func _set_candidate(point: GrapplePoint) -> void:
    if point == current_candidate:
        return

    if current_candidate != null:
        _set_highlight(current_candidate, false)

    current_candidate = point

    if current_candidate != null:
        _set_highlight(current_candidate, true)


func _set_highlight(point: GrapplePoint, enabled: bool) -> void:
    var mesh = point.get_node_or_null("MeshInstance3D") as MeshInstance3D
    if mesh == null:
        return
    mesh.visible = enabled
    if enabled and highlight_material != null:
        mesh.material_override = highlight_material
    else:
        mesh.material_override = null

# ---------------------------------------------------------------------------
# System 3 — Travel
# ---------------------------------------------------------------------------
func attempt_grapple() -> void:
    if current_candidate == null or is_grappling:
        return

    grapple_target = current_candidate
    is_grappling = true
    travel_t = 0.0
    travel_start = player.global_position

    var mid: Vector3 = travel_start.lerp(grapple_target.global_position, 0.5)
    var arc_depth: float = travel_start.distance_to(grapple_target.global_position) * arc_depth_ratio
    travel_control = mid + Vector3.DOWN * arc_depth

    emit_signal("grapple_started", grapple_target)


func _update_travel(delta: float) -> void:
    travel_t += delta / travel_duration

    if travel_t >= 1.0:
        travel_t = 1.0
        _arrive_at_destination()
        return

    var t: float = _ease_in_out(travel_t)
    var pos: Vector3 = \
        (1.0 - t) * (1.0 - t) * travel_start \
        + 2.0 * (1.0 - t) * t * travel_control \
        + t * t * grapple_target.global_position

    player.global_position = pos


func _ease_in_out(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


func _arrive_at_destination() -> void:
    is_grappling = false
    player.global_position = grapple_target.global_position
    emit_signal("grapple_completed")
    _start_ledge_hang()

# ---------------------------------------------------------------------------
# System 4 — Hang and Climb
# ---------------------------------------------------------------------------
func _start_ledge_hang() -> void:
    if grapple_target.type != GrapplePoint.Type.LEDGE:
        return

    is_hanging = true

    var look_target: Vector3 = player.global_position + grapple_target.get_surface_normal()
    player.look_at(look_target, Vector3.UP)


func attempt_climb() -> void:
    if not is_hanging or grapple_target == null:
        return

    var climb_pos: Vector3 = grapple_target.get_climb_position()

    var tween = get_tree().create_tween()
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.set_ease(Tween.EASE_OUT)

    var lift_pos: Vector3 = Vector3(
        player.global_position.x,
        climb_pos.y,
        player.global_position.z
    )
    tween.tween_property(player, "global_position", lift_pos, 0.2)
    tween.tween_property(player, "global_position", climb_pos, 0.2)
    tween.tween_callback(_finish_climb)


func _finish_climb() -> void:
    is_hanging = false
    grapple_target = null
    emit_signal("grapple_cancelled")
```

Save the file.

---

## Part 2: The Grapple Point Scene

This is the marker you will place around your levels at ledge edges.

---

### 2.1 — Create a New Scene

1. Go to **Scene → New Scene**
2. Click **Other Node** for the root type
3. Search for and select **Node3D**
4. Rename the root node to `GrapplePoint`

---

### 2.2 — Add Child Nodes

With `GrapplePoint` selected, add the following children one at a time using **Ctrl+A**:

**Child 1:**
- Type: `MeshInstance3D`
- Keep the default name `MeshInstance3D`
- In the Inspector, find the **Mesh** property and set it to a new **SphereMesh**
- Click the SphereMesh resource and set **Radius** to `0.15` and **Height** to `0.3`
- This sphere is your editor visibility marker — you will see it in the viewport while building levels but it hides at runtime

**Child 2:**
- Type: `Marker3D`
- Rename it `ClimbDestination`
- This marks where the player stands after climbing up — you will position this per-instance later

Your scene tree should look like this:
```
GrapplePoint  (Node3D)
├── MeshInstance3D
└── ClimbDestination  (Marker3D)
```

---

### 2.3 — Attach the Script

1. Select the root `GrapplePoint` node
2. In the Inspector, click the **Script** slot (the scroll icon)
3. Click **Load** and select `grapple_point.gd`

---

### 2.4 — Assign the Climb Destination Export

1. Select the root `GrapplePoint` node
2. In the Inspector you will now see the exported variables from the script
3. Find **Climb Destination** and drag the `ClimbDestination` Marker3D from the scene tree into that slot

---

### 2.5 — Save the Scene

**Ctrl+S** → save as `grapple_point.tscn` in your scenes folder.

---

## Part 3: The Player Scene

Now wire the grapple component into your existing player.

---

### 3.1 — Open Your Player Scene

Open `Player3DTemplate.tscn` (or whatever your player scene is named).

---

### 3.2 — Add the Grapple Component Node

1. Select the **Components** node in your scene tree
2. Press **Ctrl+A** → add a **Node3D**
3. Rename it `grapple_component`
4. With it selected, go to the Inspector → Script slot → Load → select `grapple_component.gd`

Your Components section should now look like:
```
Components
├── camera_component
├── input_component
├── movement_component
└── grapple_component    ← new
```

---

### 3.3 — Add the Rope Origin Marker

1. Select `grapple_component`
2. **Ctrl+A** → add a **Marker3D**
3. Rename it `GrappleOrigin`
4. In the viewport, move it to chest height on your character — approximately **Y: 1.0** depending on your model scale

This is where the visual rope will originate from in the future.

---

### 3.4 — Configure the Inspector Values

Select `grapple_component` and set these values in the Inspector:

| Property | Recommended Value | Notes |
|---|---|---|
| Max Range | `25.0` | Metres. Increase for larger levels |
| Detection Angle | `45.0` | Degrees. How wide the detection cone is |
| Travel Duration | `0.6` | Seconds. Lower = snappier zip |
| Arc Depth Ratio | `0.2` | The dip of the swing arc. 0 = straight line |
| Highlight Material | *(leave empty for now)* | Set up in Part 4 |

---

### 3.5 — Verify the Camera Path

Open `grapple_component.gd` and find this line inside `_ready()`:

```gdscript
camera = owner.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
```

Compare this string to your actual scene tree. The path must go from the **player root** down to your `Camera3D`. If your structure is different, update the string to match.

For example, if your camera is at `Head/Camera3D` the line should be:
```gdscript
camera = owner.get_node("Head/Camera3D") as Camera3D
```

---

## Part 4: The Highlight Material

This material glows on the grapple point when the player looks at it.

---

### 4.1 — Create the Material

1. In the **FileSystem** panel, navigate to your materials folder (create one if needed)
2. Right click → **New Resource**
3. Search for `StandardMaterial3D` and select it
4. Save it as `grapple_highlight.tres`

---

### 4.2 — Configure the Material

Double click `grapple_highlight.tres` to open it in the Inspector:

1. Scroll down to the **Emission** section
2. Check the **Enabled** checkbox
3. Click the colour swatch next to **Emission** and pick a bright colour — white or yellow works well
4. Set **Emission Energy Multiplier** to `2.0` or higher for a strong glow effect

---

### 4.3 — Assign to the Component

1. Go back to your player scene
2. Select `grapple_component`
3. In the Inspector, find **Highlight Material**
4. Drag `grapple_highlight.tres` from the FileSystem into that slot

---

## Part 5: The Input Action

---

### 5.1 — Add the Grapple Action

1. Go to **Project → Project Settings**
2. Click the **Input Map** tab
3. In the **Add Action** field at the top, type `grapple`
4. Click **Add**

---

### 5.2 — Bind a Key

1. Find your new `grapple` action in the list
2. Click the **+** button to the right of it
3. Press the key you want to use — **E** or **Right Mouse Button** are common choices
4. Click **OK**
5. Close Project Settings

---

## Part 6: Update movement_component.gd

Your movement component needs to pause while the player is grappling so it does not fight the arc travel.

---

### 6.1 — Add These to movement_component.gd

Find your `_ready()` function and add the grapple connections inside it:

```gdscript
func _ready() -> void:
    # ... your existing _ready code above this ...

    # Grapple hook — pause movement during travel and hang
    var grapple = owner.get_node("Components/grapple_component")
    grapple.grapple_started.connect(_on_grapple_started)
    grapple.grapple_cancelled.connect(_on_grapple_finished)
```

---

### 6.2 — Add These Variables and Functions

Somewhere in the class body (outside any function), add:

```gdscript
var movement_paused: bool = false
```

Then add these two functions:

```gdscript
func _on_grapple_started(_target) -> void:
    movement_paused = true

func _on_grapple_finished() -> void:
    movement_paused = false
```

---

### 6.3 — Guard Your Physics Process

At the very top of your `_physics_process` function, add the early return:

```gdscript
func _physics_process(delta: float) -> void:
    if movement_paused:
        return

    # ... all your existing movement code below unchanged ...
```

---

## Part 7: Place Grapple Points in Your Level

---

### 7.1 — Add a Point to the Level

1. Open your level scene
2. In the **FileSystem**, find `grapple_point.tscn`
3. Drag it into the scene viewport and drop it near a ledge edge
4. Use the move tool to position it precisely at the **edge of the ledge** — not on top of the roof, not floating in air, right at the rim

---

### 7.2 — Position the Climb Destination

1. Expand the `GrapplePoint` node in the scene tree
2. Select the `ClimbDestination` child Marker3D
3. Move it to where the player should stand **after** climbing up — on top of the roof, a step or two back from the edge

---

### 7.3 — Orient the Surface Normal

The surface normal tells the player which way to face when hanging. The forward direction is the **blue Z axis** arrow in the viewport.

1. Select the root `GrapplePoint` node
2. Rotate it so the **blue arrow points away from the building face**

For example, if the building wall faces north, the blue arrow should point north (away from the wall, toward where the player approaches from).

---

### 7.4 — Add to the Group

This is the step most likely to be forgotten — without it the component cannot find the point.

1. Select the root `GrapplePoint` node
2. In the top right panel, click the **Node** tab (next to Inspector)
3. Click **Groups**
4. Type `grapple_points` exactly (all lowercase, underscore)
5. Click **Add**

You should see `grapple_points` appear in the group list with a checkmark.

Repeat steps 7.1 through 7.4 for every grapple point you place in the level.

---

## Part 8: Testing

---

### 8.1 — First Run Checklist

Before pressing Play, confirm:

- [ ] `grapple_component.gd` is attached to the `grapple_component` Node3D in your player
- [ ] `grapple_point.gd` is attached to the root of every `GrapplePoint` instance
- [ ] Every `GrapplePoint` in the level is in the `grapple_points` group
- [ ] `ClimbDestination` is assigned in every `GrapplePoint`'s Inspector
- [ ] `grapple_highlight.tres` is assigned to `grapple_component`'s Highlight Material slot
- [ ] The `grapple` input action is bound to a key in Project Settings
- [ ] `movement_paused` guard is added to `movement_component._physics_process()`

---

### 8.2 — What to Test

**Test 1 — Highlighting**
Walk toward a grapple point and look at it. The sphere mesh should become visible and glow. Look away and it should disappear. If it does not appear, the node is not in the `grapple_points` group.

**Test 2 — Grapple Travel**
With a point highlighted, press the grapple key. You should arc smoothly toward the ledge edge. If nothing happens, check the Output panel for errors — the script prints specific messages if the player or camera references failed.

**Test 3 — Hang State**
After arriving at the ledge you should stop there, facing away from the building. Your movement input should not move you. If you slide off, the `movement_paused` guard is not working.

**Test 4 — Climb**
While hanging, press the grapple key again. You should lift up and step onto the roof. If the player warps to a wrong position, recheck the `ClimbDestination` marker placement on that point.

---

### 8.3 — Common Problems

| Symptom | Likely Cause | Fix |
|---|---|---|
| Highlight never appears | Node not in group | Re-add to `grapple_points` group |
| Highlight appears but grapple does nothing | Input action name mismatch | Check action is named exactly `grapple` |
| Player flies past the ledge | `movement_paused` not set | Check the `_on_grapple_started` connection |
| Error: cannot find Camera3D | Wrong node path | Update the path string in `grapple_component.gd _ready()` |
| Player falls through floor on arrival | ClimbDestination too low | Move the Marker3D up slightly |
| Hang state but wrong facing direction | Surface normal wrong | Rotate GrapplePoint so blue Z faces away from wall |
| Error: Identifier not declared | Signal callback name mismatch | Ensure connect() name matches the function name exactly |

---

## Part 9: Inspector Tuning Reference

Once everything is working, use these values to adjust the feel:

| Property | Lower Value | Higher Value |
|---|---|---|
| `Max Range` | Requires close approach | Can grapple from far away |
| `Travel Duration` | Snappy, fast zip | Slow, cinematic travel |
| `Arc Depth Ratio` | Nearly straight line | Deep dramatic swing arc |
| `Emission Energy` (material) | Subtle glow | Bright obvious highlight |

---

## File Summary

At the end of this setup you should have created:

```
res://
├── scripts/
│   ├── grapple_point.gd
│   └── grapple_component.gd
├── scenes/
│   └── grapple_point.tscn
└── materials/
    └── grapple_highlight.tres
```

And modified:
- `Player3DTemplate.tscn` — added `grapple_component` node under Components
- `movement_component.gd` — added pause/resume logic

---

*Guide covers Godot 4.6 — GDScript syntax and node names are version specific.*
