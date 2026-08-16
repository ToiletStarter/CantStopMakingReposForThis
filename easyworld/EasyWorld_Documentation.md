# EasyWorld

Single-file Roblox executor **world-space** visual engine (`EasyWorld.luau`, version `1.0.0`).

Where EasyESP draws 2D overlays anchored to entities on screen, EasyWorld draws **geometry that lives in the world** — rings that lie flat on the ground, spheres that wrap a target, orbit paths that show where a player will walk, boxes that preview a block placement. Every shape is projected per-frame through the camera, so it has real perspective: it grows as you approach, tilts as you turn, and dims when something occludes it.

It is game-agnostic. A shape is a spec table plus a `get` function that returns a position; EasyWorld does the projection, culling, styling and pooling. Ring specs also accept a function for `rad`, allowing bounded effects such as expanding audio reach indicators without rebuilding the shape.

---

## Requirements

| API | Required | Consequence if missing |
|---|---|---|
| `Drawing` | **yes** | Errors on load. |
| `setrenderproperty` | no | Falls back to direct property writes. |
| `getgenv` | no | Falls back to `shared` then `_G` for the `__EASY_STACK` runtime table. |

---

## Install

```lua
local EasyWorld = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyworld/EasyWorld.luau"))()
```

The returned value is the `World` class table (`World.new`, `World.ver`, `World.Shapes`, `World.Presets`, `World.Toolkit`, `World.DestroyAll`).

---

## Quick start

```lua
local world = EasyWorld.new()
world:start()

world:ring("killaura.range", {
    get  = function() return workspace.FloydBandson.HumanoidRootPart.Position - Vector3.new(0, 3, 0) end,
    rad  = 14.4,
    col  = Color3.fromRGB(255, 70, 70),
    sides = 64,
    glow = true,
})
```

Teardown:

```lua
world:stop()      -- disconnect the render loop and hide everything
world:destroy()   -- stop() + destroy every pooled drawing + clear the registry slot
```

`EasyWorld.new` is single-instance by convention: it destroys the instance registered in `getgenv().__EASY_STACK.world` before constructing, so re-running a script never stacks two render loops.

---

## Concepts

### The per-frame pipeline

`world:tick(dt)` is the whole engine; `start()` connects it to `RenderStepped`. Per frame:

1. `pool:begin()` — mark every drawing as dead-until-touched.
2. If the master switch is off, skip straight to step 6.
3. For each shape in priority order: resolve its position, cull it, dispatch to its shape function.
4. Each shape function emits primitives through the pool with **stable keys**.
5. The segment budget aborts the pass if a frame gets too expensive.
6. `pool:finish()` hides untouched drawings, `pool:prune()` destroys long-idle ones.

### Position resolution

Every shape has a `get` field. It may be a value or a function returning one, and these types are accepted:

| Returned | Used as |
|---|---|
| `Vector3` | position |
| `CFrame` | position **and** orientation (box uses the rotation) |
| `BasePart` | `.Position` and `.CFrame` |
| `Model` | `:GetPivot()` |
| `nil` / anything else | shape is skipped this frame, silently |

A `get` that errors is caught — the shape is skipped for that frame, and the rest of the scene still draws.

```lua
world:ring("target", {
    get = function()
        local plr = getTarget()
        return plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    end,
    rad = 8,
})
```

Returning `nil` is the idiomatic way to hide a shape when there is no target — no need to toggle it.

### Orientation: `normal`, `tilt`, `yaw`

Round shapes are built on a plane defined by a normal vector. By default the normal is straight up, so a ring lies flat on the ground.

- `tilt` — degrees away from vertical. `0` = flat on the ground, `90` = standing upright facing you.
- `yaw` — which compass direction the tilt leans toward.
- `normal` — supply a `Vector3` directly and `tilt`/`yaw` are ignored.

```lua
world:ring("flat",  { get = pos, rad = 10, tilt = 0  })   -- on the ground
world:ring("wall",  { get = pos, rad = 10, tilt = 90 })   -- upright
world:ring("lean",  { get = pos, rad = 10, tilt = 35, yaw = 90 })
```

### The drawing pool

Every primitive is a reused `Drawing` addressed by a string key, with shadow-property diffing — a property is only written when its value actually changed. Drawings untouched for `cfg.pruneAge` frames are destroyed.

This means the cost of a static scene is near zero after the first frame, and shape count can change freely without leaking.

---

## Shapes

Every shape shares the [common spec](#common-spec) and adds its own fields.

### `ring`

A circle in the world. The workhorse — range indicators, target markers, radius visualizers.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `rad` | number | `10` | Radius in studs. |
| `sides` | number | `48` | Resolution. Scaled by `cfg.quality`. |
| `tilt` / `yaw` | number | `0` | Orientation, see above. |
| `lift` | number | `0.08` | Nudge along the normal, to stop z-fighting with the floor. |
| `spin` | number | `0` | Radians per second of rotation. |
| `squash` | number | `1` | `<1` squashes into an ellipse. |
| `wiggle` | number | `0` | Radial distortion amplitude in studs. |
| `wiggleFreq` | number | `6` | Lobes around the circumference. |
| `wiggleSpeed` | number | `2` | Animation rate. |
| `wiggleMode` | string | `"sine"` | `"sine"` (smooth lobes) or `"noise"` (organic Perlin). |
| `lanes` | number | `1` | Concentric copies. |
| `laneGap` | number | `0.6` | Stud spacing between lanes. |
| `laneLift` | number | `0` | Vertical stagger per lane. |
| `lanePhase` | number | `0` | Rotational offset per lane. |
| `fill` | boolean | `false` | Fill the disc with triangles. |
| `fillA` | number | `0.06` | Fill alpha. |
| `ticks` | number | `0` | Radial tick marks around the edge. |
| `tickLen` | number | `1.2` | Tick length in studs. |
| `style` | string | `"solid"` | `"solid"` or `"dashed"`. |
| `dashOn` / `dashOff` | number | `2` / `2` | Dash pattern in segments. |
| `dashSpeed` | number | `0` | Dash march rate. |

### `orbit`

A ring plus a live marker showing a position **on** that ring, with a comet trail. Built for orbit/strafe visualizers.

Inherits every `ring` field, and adds:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `angle` | number or function | `nil` | Current angle in radians. A function is called each frame. |
| `markerSize` | number | `5` | Marker dot radius in pixels. |
| `trail` | number | `10` | Trail segment count. `0` disables. |
| `trailArc` | number | `1.1` | Trail length in radians. |
| `dir` | number | `1` | `1` or `-1`; which way the trail lags. |

```lua
local angle = 0
world:orbit("orbit.path", {
    get   = function() return target and target.Position end,
    angle = function() return angle end,
    rad   = 9, lanes = 3, laneGap = 1.5, tilt = 12,
    trail = 14,
})
-- elsewhere, per frame: angle += speed * dt
```

### `sphere`

A wireframe sphere from stacked latitude bands plus meridian circles. Target bubbles, blast radii.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `rad` | number | `3` | Radius. |
| `bands` | number | `3` | Horizontal slices. |
| `meridians` | number | `3` | Vertical great circles. |
| `bandSpread` | number | `0.72` | How far bands reach toward the poles. |
| `gyro` | boolean | `true` | Bands tumble over time instead of staying axis-aligned. |
| `spin` | number | `0.4` | Tumble rate. |
| `meridianSpin` | number | `0` | Independent meridian rotation. |
| `core` | boolean | `false` | Draw a dot at the centre. |
| `coreSize` / `coreA` | number | `3` / `0.9` | Core dot size and alpha. |

### `box`

A 3D wireframe cuboid. Block placement previews, hitbox visualizers.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `size` | Vector3 | `(3,3,3)` | Dimensions in studs. |
| `corner` | number | `0` | `0` = full edges. `0…0.5` = draw only that fraction at each corner (corner-box style). |
| `fill` | boolean | `false` | Fill all six faces. |
| `fillA` | number | `0.07` | Face alpha. |

When `get` returns a `CFrame`, `BasePart` or `Model`, the box inherits its **rotation**. Pass `cframe = false` to force an axis-aligned box.

### `cylinder`

Two or more stacked rings joined by vertical posts. Columns, capture zones, beacons.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `rad` | number | `5` | Radius. |
| `height` | number | `6` | Height along the normal. |
| `rings` | number | `2` | Horizontal rings. |
| `posts` | number | `8` | Vertical connectors. |
| `postA` | number | `0.55` | Post alpha. |
| `taper` | number | `0` | `0…1`, shrinks the top ring into a cone. |

### `disc`

A filled ground disc built from concentric bands, with a bright outer edge. Softer than a ring — good for "area" rather than "boundary".

| Field | Type | Default | Meaning |
|---|---|---|---|
| `rad` | number | `10` | Radius. |
| `bands` | number | `3` | Concentric fill bands. |
| `fillA` | number | `0.07` | Fill alpha at the centre band. |

### `arc`

A partial ring, optionally filled as a wedge. Field-of-view cones, swing arcs.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `from` / `to` | number | `0` / `90` | Start and end angle in **degrees**. |
| `rad` | number | `6` | Radius. |
| `wedge` | boolean | `false` | Fill from the centre. |

### `beam`

A line between two world points.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `get` | any | — | Start point. |
| `get2` / `pos2` | any | — | End point. Same accepted types as `get`. |
| `segments` | number | `1` | Subdivisions. Raise for `sag`. |
| `sag` | number | `0` | Studs of downward droop at the midpoint. |
| `arrow` | boolean | `false` | Arrowhead at the end. |
| `arrowSize` | number | `9` | Arrowhead size in pixels. |

### `path` / `trail`

A polyline through a list of points. Projectile arcs, pathfinding previews, scaffold plans.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `points` | `{Vector3}` or function | — | At least two points. |
| `head` | boolean | `false` | Dot at the last point. |
| `headSize` | number | `4` | Head dot radius. |

### `marker`

A small screen-space glyph pinned to a world position.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `marker` | string | `"diamond"` | `"diamond"`, `"cross"`, `"dot"`. |
| `size2d` | number | `8` | Size in pixels. |

### `text`

A world-anchored label.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `text` | string or function | `""` | Content. A function is called each frame. |
| `labelSize` | number | `12` | Font size. |
| `center` | boolean | `true` | Horizontal centring. |
| `textOffset` | number | `0` | Vertical pixel offset. Distinct from `labelOffset`, which positions the optional `label` attached to *any* shape. |

---

## Common spec

Every shape accepts these.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `true` | Per-shape switch. |
| `get` | any or function | — | Position source. |
| `offset` | Vector3 | `nil` | Added to the resolved position. |
| `col` | Color3 | `(150,190,255)` | Primary colour. |
| `col2` | Color3 | `nil` | Secondary colour. Enables a gradient along polylines, and tints fills, cores and markers. |
| `a` | number | `1` | Base alpha. |
| `w` | number | `2` | Line width. |
| `glow` | boolean | `true` | Draw wider translucent copies underneath each line. |
| `glowLayers` | number | `2` | Glow passes, capped at 4. **Each layer multiplies segment count.** |
| `glowGain` | number | `0.28` | Glow alpha. |
| `glowSpread` | number | `2.5` | Glow width growth. |
| `pulse` | boolean | `false` | Sine-breathe the alpha. |
| `pulseRate` | number | `2` | Pulse speed. |
| `pulseDepth` | number | `0.35` | Pulse amplitude. |
| `depthFade` | boolean | `true` | Fade with distance from camera. |
| `depthFadeGain` | number | `0.55` | Fade strength. |
| `scaleWidth` | boolean | `true` | Lines thicken up close, thin far away. |
| `widthNear` | number | `60` | Depth at which width is unscaled. |
| `widthGain` | number | `1.9` | Maximum width multiplier. |
| `maxDist` | number | `0` | Cull beyond this many studs. `0` = unlimited. |
| `fadeDist` | number | `0` | Fade linearly to nothing at this distance. `0` = off. |
| `occlude` | boolean | `false` | Raycast per segment; dim the hidden parts. |
| `occludeStep` | number | `3` | Raycast every Nth point. Higher is cheaper and blockier. |
| `occludeAlpha` | number | `0.22` | Alpha multiplier for hidden segments. |
| `z` | number | `0` | Draw order within a priority band. |
| `priority` | number | `0` | Higher draws over lower. |
| `label` | string or function | `nil` | Text drawn at the shape's anchor. |
| `labelSize` | number | `12` | Label font size. |
| `labelOffset` | number | `-14` | Label vertical offset. |

---

## API reference

### Lifecycle

| Signature | Returns | Notes |
|---|---|---|
| `EasyWorld.new(opt?)` | instance | `opt.on`, `opt.cfg`. Destroys the previous instance. |
| `world:start()` | `self` | Connects `RenderStepped`. No-op if running. |
| `world:stop()` | `self` | Disconnects and hides everything. Shapes stay registered. |
| `world:destroy()` | `nil` | `stop()` + destroys every drawing + clears the registry slot. Safe to call twice. |
| `EasyWorld.DestroyAll()` | `nil` | Destroys the registered instance. |
| `world:on(v)` | `self` | Master switch. `false` hides everything without unregistering. |
| `world:toggle()` | boolean | Flips the master switch. |

### Shapes

| Signature | Returns | Notes |
|---|---|---|
| `world:add(id, spec)` | spec or `nil` | Generic. `nil` if `spec.kind` is unknown. Replaces an existing id. |
| `world:ring(id, spec)` | spec | Also `:sphere`, `:box`, `:orbit`, `:beam`, `:path`, `:cylinder`, `:disc`, `:marker`, `:arc`, `:label`. |
| `world:remove(id)` | boolean | Unregisters and hides its drawings. |
| `world:clear()` | `self` | Removes every shape. |
| `world:get(id)` | spec or `nil` | The live spec table — mutate it directly if you like. |
| `world:has(id)` | boolean | |
| `world:enable(id, v)` | `self` | Per-shape switch. |
| `world:set(id, patch)` | spec or `nil` | Deep-merge a patch. |
| `world:setPath(id, path, v)` | value | Dot-path write: `world:setPath("r", "col", c)`. |
| `world:getPath(id, path)` | value | Dot-path read. |
| `world:group(prefix, list)` | table | Register several shapes under `prefix.key` ids. |
| `world:removeGroup(prefix)` | number | Remove everything under `prefix.`; returns the count. |

### Presets

`world:preset(id, name)` applies a style bundle. Pass `nil` as the id to apply to every shape.

| Name | Look |
|---|---|
| `clean` | Thin, no glow, slightly transparent. |
| `neon` | Bright, 3 glow layers, wide spread. |
| `pulse` | Breathing alpha, heavy lines. |
| `ghost` | Faint, aggressive distance fade. |
| `heavy` | Very thick, 4 glow layers. |

### Queries

| Signature | Returns |
|---|---|
| `world:project(pos)` | `x, y, depth, onScreen` |
| `world:getStats()` | `{ items, drawn, culled, segments, pool, running, enabled }` |
| `world:setIgnore({Instance})` | `self` — extra instances excluded from occlusion rays (the local character is always excluded) |

### Engine config

`world.cfg`:

| Key | Default | Meaning |
|---|---|---|
| `quality` | `1` | Global multiplier on every shape's `sides`. |
| `pruneAge` | `240` | Frames a drawing may sit idle before being destroyed. |
| `maxSegs` | `12000` | Segment budget per frame. The pass aborts once exceeded. |
| `globalAlpha` | `1` | Master alpha multiplier. |
| `cullBehind` | `true` | Reserved. |

### `EasyWorld.Toolkit`

`version`, `clone`, `merge`, `fill`, `pathGet`, `pathSet`, `basis(normal)`, `normalFromTilt(tilt, yaw)`, `shapeDefaults`, `presets`, and `quick(opt)` which constructs and starts in one call.

---

## Recipes

### Killaura range ring that follows you

```lua
world:ring("aura.range", {
    get = function()
        local c = game.Players.LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        return r and (r.Position - Vector3.new(0, 3, 0))
    end,
    rad = 14.4, sides = 72, col = Color3.fromRGB(255, 60, 60),
    lanes = 2, laneGap = 0.35, glow = true, ticks = 12,
})
```

### Target bubble that vanishes with the target

```lua
world:sphere("aura.bubble", {
    get = function()
        local t = Aura.target
        return t and t.root
    end,
    rad = 3.5, bands = 4, meridians = 4,
    col = Color3.fromRGB(255, 40, 40), col2 = Color3.fromRGB(255, 190, 190),
    pulse = true, core = true,
})
```

### Scaffold placement preview

```lua
world:box("scaffold.next", {
    get = function() return Scaffold.nextBlockPosition end,
    size = Vector3.new(3, 3, 3),
    col = Color3.fromRGB(120, 255, 170),
    fill = true, fillA = 0.1, corner = 0.25,
})
```

### Projectile arc

```lua
world:path("aim.arc", {
    points = function() return Ballistics.solve(origin, target) end,
    col = Color3.fromRGB(255, 220, 120), head = true, w = 2,
})
```

---

## Performance

Segment count is the cost driver. A ring costs `sides` segments, **multiplied by `glowLayers + 1`** and by `lanes`.

```
ring(sides=64, glow=true, glowLayers=2, lanes=3)  ->  64 * 3 * 3 = 576 segments
```

Levers, in order of effectiveness:

1. `glow = false` — an instant 3x cut.
2. Lower `sides`. 32 is smooth at typical distances; 64 is only worth it up close or on big radii.
3. `cfg.quality = 0.6` — scales every shape at once.
4. `maxDist` — cull distant shapes entirely.
5. `occludeStep` — raise it; occlusion raycasts are the other real cost.

`cfg.maxSegs` is a hard stop: once a frame exceeds it the remaining shapes are skipped that frame. Shapes are processed in `priority` order, so give your important visuals a higher priority and they will survive the budget.

---

## Gotchas

**`glow` multiplies your segment count.** `glowLayers = 2` means every line is drawn 3 times. This is the single biggest performance factor and the first thing to turn off when frames drop.

**`get` returning `nil` is not an error — it is the hide mechanism.** No warning is printed, nothing is drawn. If a shape is mysteriously invisible, check what `get` actually returns before suspecting the renderer.

**A shape whose draw function errors is disabled permanently**, with a `warn` naming the id. It will not retry on the next frame. Re-`add` it after fixing the cause.

**`maxDist = 0` and `fadeDist = 0` mean unlimited**, not "cull everything".

**`lift` exists because of z-fighting.** A ring at exactly ground level interleaves with the floor. The default `0.08` nudge is usually enough; raise it on bumpy terrain.

**`tilt` is degrees, `angle` is radians.** `tilt`/`yaw`/`from`/`to` take degrees because they are authored by hand; `orbit.angle` takes radians because it is computed.

**`priority` bands are coarse.** Internally `priority` is multiplied by 100 into the z-bias, so `z` differentiates within a band and `priority` between bands. Two shapes with the same `priority` and `z` have undefined relative order.

**Occlusion is sampled, not exact.** With `occludeStep = 3` only every third point is raycast and the result is reused for the points between. Lower it for accuracy, raise it for speed.

**The pool keys on shape id.** Two shapes with the same id are the same shape — `add` replaces. Use `group`/`removeGroup` for sets.
