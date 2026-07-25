# EasyESP

Single-file Roblox executor ESP library (`EasyESP.luau`, version `4.0.0`). It draws screen-space overlays through the executor `Drawing` API: 2D and 3D boxes, corner boxes, names, distances, health bars, bone skeletons, head dots, gaze lines, tracers, text flags, off-screen arrows, world-space rings, a rotating radar, a player list, a target selector with FOV circle/brackets/snapline/info card, a threat banner, self-HUD (FOV circle, crosshair, watermark, compass), Highlight/material chams, and lighting overrides. It targets script authors who want a configuration table rather than a widget tree: one `ESP.new()` instance owns a config tree, a drawing pool, a per-frame render loop, and optional player/NPC/entity sources.

---

## Requirements

The library hard-errors at load if the executor lacks the three globals it depends on (`EasyESP.luau:1-3`):

```lua
if not Drawing or not setrenderproperty or not cleardrawcache then
    error("EasyESP needs Drawing, setrenderproperty, and cleardrawcache", 2)
end
```

Note: `cleardrawcache` is required by the guard but is never called anywhere else in the file — the guard uses it purely as an executor-capability probe.

Everything else degrades instead of erroring:

| Missing API | Behaviour |
|---|---|
| `Drawing.Fonts` | Falls back to `{}`, then font id `0` if `Plex`/`UI`/`System` are absent. |
| `getfpscap` | Initial `stats.fpsAvg` seed defaults to `60`. |
| `getgenv` | Falls back to `_G` for the `__EASY_STACK` runtime table. |
| `ContextActionService:BindActionAtPriority` | Falls back to `BindAction`; the whole bind is wrapped in `pcall`. |
| `writefile` | `esp:save()` returns `false`. |
| `isfile` / `readfile` | `esp:load()` returns `false`. |
| `isfolder` / `listfiles` | `esp:configs()` returns `{}`. |
| `makefolder` | Skipped; save still attempts the write. |

User callbacks (`npcSrc`, `npcLabel`, `targetSrc`, `targetInfo`, entity `get`/`label`/`draw`, flags, hooks, modules) all run inside `pcall`, so a callback error does not kill the render loop. The loop itself is wrapped: a `tick` error warns once, calls `pool:finish()`, and keeps running (`EasyESP.luau:2907-2916`).

---

## Install

```lua
local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyesp/EasyESP.luau"))()
```

The returned value is the `ESP` class table (`ESP.new`, `ESP.ver`, `ESP.Descriptors`, `ESP.Toolkit`, `ESP.DestroyAll`).

---

## Quick start

```lua
local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyesp/EasyESP.luau"))()

-- create: opt is merged over defaults(), then any gaps refilled from defaults()
local esp = ESP.new({
    box = { on = true, kind = "corner" },
    name = { on = true },
    dist = { on = true },
})

esp:on(true)    -- master switch (cfg.on); alias esp:setEnabled(true)
esp:start()     -- connects RunService.RenderStepped -> esp:tick(dt)
```

Teardown:

```lua
esp:stop()      -- disconnect the loop, hide all drawings, restore lighting, clear chams
esp:destroy()   -- stop() + unbind input, destroy the pool, drop records/entities/mods/flags
```

`ESP.new` is single-instance by convention: it destroys the previously registered instance in `getgenv().__EASY_STACK.esp` before constructing, so re-running a script never stacks two ESPs. `ESP.DestroyAll()` kills every instance the module created. `Start`/`Stop`/`Destroy` exist as capitalised aliases.

Leaving `cfg.on = false` while the loop runs is a valid idle state: `tick` still measures FPS, hides every pooled drawing, restores lighting, and clears chams each frame without doing any work.

---

## Concepts

### The per-frame pipeline

`ESP:tick(dt)` (`EasyESP.luau:2802`) is the whole engine; `start()` only connects it to `RenderStepped`. Order per frame:

1. **FPS accounting** — accumulates frames into a 0.45s window, writes `stats.fps` and an EMA `stats.fpsAvg` (`avg*0.7 + fps*0.3`). This runs before the `cfg.on` check, so the FPS measurement that drives `perf.mode = "auto"` never stops.
2. **Master-off path** — if `cfg.on` is false: `pool:begin()` / `pool:reset()` / `pool:finish()`, restore lighting, clear all chams, return.
3. **Frame skip** — advance `t` and `frame`, then return early if `perf.frameSkip` says this frame is skipped (see [Performance](#performance)).
4. **Snapshot roster** — `_world()` applies lighting overrides, `_snap()` builds `self.snap`: one immutable-per-frame snapshot table per live player, then `_snapNPC` appends NPC snapshots, then the whole array is sorted by distance ascending. `_pick()` chooses `self.target` from the snapshot.
5. **Draw passes** — chams (per snapshot), entities, radar, per-snapshot player/NPC drawing (`_player`), off-screen arrows, target overlay, threat banner, player list, self-HUD. Module hooks fire at `world`, `player` and `screen` stages.
6. **Pool retire** — `pool:finish()` hides every key that was drawn last frame but not this frame; then, every `perf.pruneEvery` frames, `pool:prune(perf.pruneAfter)` destroys drawings idle for that many frames. `stats.pool` is updated last.

A snapshot carries the projected root position (`sx`, `sy`, `depth`, `on`), the cached 2D box (`bx`, `by`, `bw`, `bh`), health, distance, LOD bucket, visibility, team/ally/friend state, and `rec` (the persistent per-entity record). NPC snapshots additionally carry `npc = true`, `name`, and `cfg = self.cfg.npc` — every draw routine reads `s.cfg or self.cfg`, which is how one code path serves both categories.

### The drawing pool

`Pool` (`EasyESP.luau:789-1132`) is a keyed cache of `Drawing` objects with dirty-tracking. Every draw call takes a string key: `"b12345"` for a player box, `"c12345i3"` for a corner segment, `"rad_p4"` for a radar blip, `"ent_b1foo"` for an entity box. Keys embed the record `uid` (positive `UserId` for players, negative counter ids for NPCs), so a given entity reuses the same `Drawing` every frame.

- `get(key, kind)` returns the cached object, or destroys and recreates it if the same key is asked for a different `Drawing` class.
- Each setter (`line`, `box`, `dot`, `tri`, `txt`) writes properties through `setrenderproperty` **only when the shadow value changed**, so a static overlay costs almost no property writes.
- `begin()` clears the `live` set at the start of a frame; every draw call marks its key live.
- `finish()` hides (sets `Visible = false`) every key that was live last frame but not this frame. **A key you do not draw in a frame is hidden, not destroyed.**
- `carry(prefix)` re-marks last frame's keys under a prefix as live, keeping them visible without redrawing — used by the entity pass on skipped frames.
- `prune(n)` destroys drawings that have been idle for more than `n` frames, freeing the object and its shadow entry.
- `reset()` hides everything; `nuke()` destroys everything and zeroes the pool.
- `pool.zbias` is added to every `ZIndex` passed during a pass; `tick` sets it per layer from `cfg.priority`.

### Players vs NPCs

Players are discovered automatically (`Players:GetPlayers()` plus `PlayerAdded`/`PlayerRemoving`), excluding the local player.

NPCs are **not** discovered automatically. `cfg.npc.on = true` does nothing until you supply a source callback:

```lua
esp:setNPCSource(function()
    return workspace.Zombies:GetChildren()   -- any array of Instances
end)
esp:setNPCLabel(function(model) return model:GetAttribute("Kind") or model.Name end)
esp.cfg.npc.on = true
```

The source is called once per frame inside `pcall` and must return a table of Instances. Each entry needs a root (`HumanoidRootPart`, else `PrimaryPart`, else the first `BasePart`); health comes from the `Health` attribute if present, otherwise `Humanoid.Health`; an entry is skipped if the `Dead` attribute is `true` or health is `<= 0`.

> **`cfg.npc` is an independent deep copy of the player config, not a view onto it.** `defaults()` builds `t.npc.box = deep(t.box)`, `t.npc.hp = deep(t.hp)`, and so on (`EasyESP.luau:668-691`). Writing `esp.cfg.box.on = true` affects players only. To change NPC drawing you must write `esp.cfg.npc.box.on = true`. There is no inheritance and no fallback lookup at draw time — `_player`, `_boxDraw`, `_hpDraw`, `_cham`, `_arrow` etc. resolve `s.cfg or self.cfg` once and read every key from that root.

The helpers that *do* write both trees, because they walk them explicitly: `esp:theme()` (mirrors every colour into `cfg.npc`), `esp:pack()` (merges any pack subtable that also exists on `cfg.npc`), `esp:profile()` (merges `perf` into `cfg.npc.perf`). Manual assignment, `merge`, and `ESP.new(opt)` do not.

NPCs are also structurally excluded from the player-only HUD: the radar, the player list, the target selector, and the threat banner all skip `s.npc` snapshots. NPCs get box/name/dist/hp/flags/bones/head/gaze/tracer/rings/chams/arrows only. NPC snapshots always have `ally = false` and `friend = false`, which makes `npc.team`, `npc.friendTint` and the team/friend colour branches inert for them.

### Entities

Entities are a third, snapshot-free category: arbitrary world objects fed by `esp:addEnt(id, spec)` (alias `addEntity`). A spec needs `get()` returning a `Vector3`, a `BasePart`, a `Model`, or an array of those; the pass then draws a 2D bounding box, an optional bottom dot, label, distance, tracer, ring, and calls `spec.draw` if given. `addInst`/`scan`/`scanNPCs`/`scanTools`/`scanPickups` are convenience wrappers that register entity specs. Entities are cut off at `spec.max or cfg.maxRange`, drawn every `perf.entityStep` frames, and z-biased by `spec.priority or cfg.priority.entity`. They read none of the player/NPC config subtables.

---

## Configuration reference

Everything below is derived from `defaults()` (`EasyESP.luau:383-693`) and `ringSpec()` (`EasyESP.luau:363-381`). `ESP.new(opt)` deep-merges `opt` over these defaults, then refills anything missing, so partial tables are safe. `esp:repair()` refills gaps again at runtime.

Named colour defaults come from the `PAL` palette: `accent` = `Color3.fromRGB(190,150,255)`, `good` = `(125,235,165)`, `bad` = `(255,110,130)`, `text` = `(236,238,245)`, `muted` = `(175,180,190)`, `friend` = `(120,190,255)`, `ink` = `(14,14,18)`. Alpha-style keys (`a`, `fillA`, `lineA`, `matA`) are passed straight to `Drawing` `Transparency`.

### Top level

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Master switch. When false, `tick` hides all drawings, restores lighting and clears chams every frame. |
| `maxRange` | number | `3000` | Roster reach for players: an entity beyond `max(maxRange, espRange, radar.range)` is dropped from the snapshot entirely. Also the default distance cap for entities/scans. `0` means unlimited. |
| `espRange` | number | `3000` | Per-snapshot draw cutoff in `_player`, the target selector cutoff, and the divisor for `box.mode = "dist"`. `0` means unlimited. |
| `team` | boolean | `false` | Skip drawing snapshots whose player shares the local player's `Team`. |
| `rainbow` | boolean | `false` | Cycle the accent colour over time instead of using `box.col`. |
| `rainbowRate` | number | `1` | Hue speed multiplier (`t * rate * 0.12`). |
| `friendTint` | boolean | `true` | Override the accent with `friendCol` for marked friends. |
| `friendCol` | Color3 | `friend` | Friend accent, and the fallback colour whenever `box.col` is not a `Color3`. |

### `priority`

Each value is multiplied by `scale` and added to the `ZIndex` of every drawing in that layer's pass (`pool.zbias`). Higher draws over lower.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `scale` | number | `100` | Multiplier applied to every layer number. |
| `player` | number | `5` | Layer for player snapshots. |
| `walker` | number | `4` | Layer for NPC snapshots. |
| `entity` | number | `2` | Default layer for entity groups; overridable per group with `spec.priority`. |
| `hud` | number | `9` | Layer for radar, arrows, target, threat, list and self-HUD. |

### `vis`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `check` | boolean | `false` | Enable the raycast visibility test (makes `s.vis` non-nil for flags, list `[V]`/`[H]`, tinting). Any of `check`/`hide`/`tint`, `target.visOnly`, or `chams.on and chams.tint` is enough to turn the test on. |
| `hide` | boolean | `false` | Skip drawing snapshots whose last visibility test failed. |
| `tint` | boolean | `false` | Recolour the accent to `box.hpFull` when visible, `box.hpLow` when hidden. |
| `points` | number | `3` | How many body parts to raycast against: root and head always, then torso (3), left arm (4), right arm (5). Any clear ray means visible. |

### `perf`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `mode` | string | `"auto"` | `"auto"` scales `visStep`/`boxStep`/`toolStep` from `stats.fpsAvg` and roster size; any other value uses the raw numbers. |
| `frameSkip` | number | `0` | Skip `n` of every `n+1` frames entirely (0 = every frame). |
| `visStep` | number | `2` | Re-run the visibility raycast for a given uid once every N frames. |
| `boxStep` | number | `2` | Recompute the 3D-to-2D bounding box for a given uid once every N frames; the cached box is reused between recomputes. |
| `toolStep` | number | `14` | Re-read the held `Tool` name for a given uid once every N frames. |
| `near` | number | `120` | Upper distance bound of LOD 0. |
| `mid` | number | `320` | Upper distance bound of LOD 1. |
| `far` | number | `760` | Upper distance bound of LOD 2; beyond it, LOD 3. |
| `pruneAfter` | number | `260` | Destroy pooled drawings idle for this many frames. `0` disables pruning. |
| `pruneEvery` | number | `90` | Run the prune sweep every N frames. |
| `fpsMin` | number | `35` | unused — never read. |
| `fpsMax` | number | `144` | unused — never read. |
| `npcFrameSkip` | number | `2` | Read from the **root** `perf` only: run NPC chams once every N frames. |
| `npcBoxStep` | number | `4` | unused at root — the engine reads `cfg.npc.perf.npcBoxStep`. |
| `entityStep` | number | `3` | Run the entity pass every N frames; skipped frames call `pool:carry("ent")` so entity drawings stay visible. |
| `cullMax` | number | `80` | unused at root — the engine reads `cfg.npc.perf.cullMax`. |
| `cullMargin` | number | `80` | unused — never read. |

### `box`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `true` | Draw the box. |
| `kind` | string | `"corner"` | `"corner"` (corner brackets), `"3d"` (12 projected edges), `"3dcorner"` (edge stubs), anything else = full 2D rectangle. |
| `col` | Color3 | `accent` | Base accent colour for the box and everything that falls back to the accent. |
| `w` | number | `1` | Line thickness. |
| `outline` | boolean | `true` | Black backing line/rect one pixel thicker. Ignored by the `3d` kinds. |
| `fill` | boolean | `false` | Draw a filled rectangle behind the box (2D kinds only). |
| `fillCol` | Color3 | `accent` | Fill colour. |
| `fillA` | number | `0.07` | Fill transparency, multiplied by the distance-fade factor. |
| `mode` | string | `"static"` | Accent source: `"static"`, `"team"` (player `TeamColor`), `"hp"` (`hpLow`→`hpFull` by health), `"dist"` (`hpFull`→`hpLow` by `dist/espRange`). |
| `fade` | boolean | `false` | Fade drawing alpha with distance. |
| `fade0` | number | `140` | Distance where fading starts. |
| `fade1` | number | `700` | Distance where fading reaches its floor (alpha bottoms out at 0.15). |
| `hpFull` | Color3 | `good` | "Full health" / "visible" end of the box gradients; also used by the `vis` flag and `vis.tint`. |
| `hpLow` | Color3 | `bad` | "Low health" / "hidden" end of the same gradients. |
| `corner` | number | `0.28` | Corner-bracket length as a fraction of `min(width, height)`. |

### `name`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `true` | Draw the name above the box. |
| `user` | boolean | `false` | `false` = `DisplayName`; `true` = `"DisplayName (Name)"` while `on` is true. NPCs always use the `npcLabel` result or the model name. |
| `size` | number | `13` | Text size; also the vertical offset above the box. |
| `col` | Color3 | `text` | Text colour; falls back to the accent when not a `Color3`. |

### `dist`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw the distance under the box. |
| `size` | number | `11` | Text size. |
| `col` | Color3 | `muted` | Text colour; falls back to the accent when not a `Color3`. |
| `suf` | string | `"m"` | Suffix appended to the rounded distance. |

### `hp`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `true` | Draw the vertical health bar. Requires `maxHp > 0`. |
| `side` | string | `"left"` | `"right"` places the bar right of the box; anything else places it left. |
| `w` | number | `3` | Bar width in pixels. |
| `outline` | boolean | `true` | Black backing rectangle. |
| `text` | boolean | `false` | Numeric health above the bar, shown only while health is below full. |
| `pct` | boolean | `false` | Health percentage centred under the box. |
| `full` | Color3 | `good` | Bar colour at full health. |
| `low` | Color3 | `bad` | Bar colour at zero health. |

### `flags`

Flags are text rows produced by callbacks. Five are registered at construction: `vis` (`VIS`/`HID`), `hp` (`123hp`), `tool` (held tool name), `spd` (rounded root speed, shown above 2), `friend` (`FRIEND`). Add your own with `esp:flag(name, fn)`.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw the flag column. |
| `side` | string | `"right"` | `"left"` puts right-aligned rows left of the box; anything else puts left-aligned rows right of it. |
| `size` | number | `10` | Text size. |
| `gap` | number | `1` | Extra pixels between rows. |
| `col` | Color3 | `text` | Default row colour when a flag callback returns no colour. |

### `bones`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw the skeleton. Suppressed above LOD 1 (i.e. past `perf.mid`). |
| `col` | Color3 | `text` | Bone colour; falls back to the accent when not a `Color3`. |
| `w` | number | `1` | Line thickness. |

R15 (14 segments) is used when `UpperTorso` exists, otherwise the R6 set (5 segments).

### `head`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw a filled circle at the head. |
| `size` | number | `3` | Circle radius. |
| `col` | Color3 | `text` | Circle colour; falls back to the accent. |

### `gaze`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw a line from the head along its `LookVector`. |
| `len` | number | `10` | Line length in studs. |
| `col` | Color3 | `text` | Line colour; falls back to the accent. |

### `tracer`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw a line from a screen anchor to the bottom-centre of the box. |
| `from` | string | `"bottom"` | Anchor: `"bottom"`, `"center"`, `"top"`, or `"mouse"` (current mouse location). |
| `col` | Color3 | `accent` | Line colour; falls back to the accent. |
| `w` | number | `1` | Line thickness. |

### `arrow`

Off-screen indicator. Drawn only when the snapshot's box is fully off-screen or behind the camera; the arrow pass runs when either `cfg.arrow.on` or `cfg.npc.arrow.on` is true, and each snapshot then honours its own tree.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw off-screen arrows. |
| `rad` | number | `190` | Maximum ring radius from screen centre. Effective radius is `min(rad, rad * scale * 500/dist)`. |
| `size` | number | `14` | Arrow length in pixels. |
| `col` | Color3 | `accent` | Arrow colour (overridden by root `rainbow`). |
| `fill` | boolean | `true` | Filled triangle; `false` draws two 2px lines instead. |
| `outline` | boolean | `true` | Black triangle two pixels larger behind a filled arrow. |
| `dist` | boolean | `false` | Distance text under the arrow. |
| `a` | number | `1` | Arrow transparency. |
| `scale` | number | `1` | Distance-scaling factor for the radius formula. |

### `radar`

Players only; NPC snapshots are skipped. Draggable with middle mouse.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw the radar. Requires a local character root. |
| `x` | number | `18` | Left edge in pixels (updated by dragging). |
| `y` | number | `170` | Top edge in pixels (updated by dragging). |
| `r` | number | `74` | Radius; the widget occupies `2r × 2r`. |
| `range` | number | `500` | World radius mapped to the disc. Also counts toward roster reach. |
| `rot` | boolean | `true` | Rotate blips with camera yaw; `false` = world-aligned. |
| `bg` | boolean | `true` | Black filled disc behind the radar. |
| `grid` | boolean | `true` | Crosshair lines through the centre. |
| `border` | boolean | `true` | Outer ring. |
| `ringLabels` | boolean | `true` | Range labels at the outer and half rings. The mid ring is drawn when either `grid` or `ringLabels` is on. |
| `names` | boolean | `false` | Draw display names next to blips. |
| `max` | number | `24` | Maximum blips per frame (nearest first, since the snapshot is distance-sorted). |
| `allies` | boolean | `false` | Include same-team players. |
| `col` | Color3 | `text` | Grid, border, range labels and name text. |
| `enemy` | Color3 | `accent` | Blip colour fallback when the player has no `TeamColor`. |
| `ally` | Color3 | `good` | Blip colour for same-team players. |
| `friend` | Color3 | `friend` | Blip colour for marked friends. |
| `selfCol` | Color3 | white | Centre blip (drawn one pixel larger than `blip`). |
| `blip` | number | `3` | Blip radius. |
| `size` | number | `9` | Name and range-label text size. |
| `a` | number | `0.28` | Background disc transparency. |

### `target`

Players only. Selection is nearest-to-screen-centre within `fov`, unless `esp:setTargetSource(fn)` supplies a snapshot/character/player to lock onto.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Enable selection and drawing. |
| `fov` | number | `240` | Screen-space selection radius in pixels. |
| `showFov` | boolean | `false` | Draw the FOV circle (64 sides, thickness `w`). |
| `visOnly` | boolean | `false` | Only select candidates whose visibility test did not fail. Also forces the visibility test on. |
| `friends` | boolean | `true` | Allow marked friends as candidates. |
| `allies` | boolean | `false` | Allow same-team players as candidates. |
| `col` | Color3 | `accent` | FOV circle, brackets, snapline, label and card colour. |
| `friend` | Color3 | `friend` | Overlay colour when the target is a friend. |
| `ally` | Color3 | `good` | Overlay colour when the target is an ally. |
| `w` | number | `1` | Line thickness for the FOV circle, brackets and snapline. |
| `pad` | number | `4` | Pixels the bracket rectangle is inflated past the box. |
| `outline` | boolean | `true` | Black backing lines behind brackets and snapline. |
| `brackets` | boolean | `true` | Corner brackets around the target. |
| `line` | boolean | `false` | Snapline from screen centre to the target's box centre. |
| `label` | boolean | `true` | Name text above the brackets. |
| `hp` | boolean | `true` | Append the health percentage to the label. |
| `dist` | boolean | `true` | Append the distance to the label. |
| `card` | boolean | `true` | Info card at the top-right (280px wide) with name, `hp/maxHp`, distance, plus the `setTargetInfo` string. The card is drawn even when the target has no on-screen box. |

### `list`

Players only; draggable with middle mouse.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw the list. |
| `x` | number | `18` | Left edge (updated by dragging). |
| `y` | number | `350` | Top edge (updated by dragging). |
| `w` | number | `220` | Panel width. |
| `max` | number | `10` | Maximum rows; also fixes the panel height (`title? 18 + row*max + 8`). |
| `row` | number | `17` | Row height in pixels. |
| `bg` | boolean | `true` | Panel background, border, and per-row strips. |
| `title` | boolean | `true` | Header row: `PLAYERS <roster>` plus the current target name. |
| `allies` | boolean | `false` | Include same-team players. |
| `hp` | boolean | `true` | Thin health bar in each row. |
| `dist` | boolean | `true` | Distance column. |
| `vis` | boolean | `true` | Append `[V]`/`[H]` when a visibility result exists. |
| `idx` | boolean | `true` | Prefix rows with `1.`, `2.`, … |
| `col` | Color3 | `text` | Title and name text. |
| `enemy` | Color3 | `accent` | Panel border and row accent fallback. |
| `ally` | Color3 | `good` | Row accent for same-team players. |
| `friend` | Color3 | `friend` | Row accent for marked friends. |
| `low` | Color3 | `bad` | Row health bar at zero health. |
| `full` | Color3 | `good` | Row health bar at full health. |
| `a` | number | `0.3` | Panel background transparency. |

### `threat`

Banner for the current target. Requires a player target (`s.npc` and NPC targets are excluded).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw the banner. |
| `y` | number | `92` | Vertical position in pixels; horizontally centred. |
| `size` | number | `13` | Text size (drives the banner height). |
| `col` | Color3 | `bad` | Text and border colour. |
| `bg` | boolean | `true` | Black background plus border. |
| `a` | number | `0.3` | Background transparency. |
| `visOnly` | boolean | `false` | Suppress the banner while the target's visibility test failed. |
| `dist` | boolean | `true` | Append the distance. |
| `hp` | boolean | `true` | Append the health percentage. |

### `chams`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Enable chams. When false, any existing highlight/material state is reverted. |
| `mode` | string | `"highlight"` | `"material"` swaps part `Material`/`Color`/`Transparency`; anything else uses a `Highlight` instance named `easyesp`. |
| `depth` | string | `"top"` | `"occluded"` = `HighlightDepthMode.Occluded`; anything else = `AlwaysOnTop`. |
| `team` | boolean | `false` | Skip same-team players (and revert them). |
| `fill` | boolean | `true` | Enable the highlight fill; `false` sets `FillTransparency = 1`. |
| `fillCol` | Color3 | white | Fill / material colour, unless overridden by `tint` or `rainbow`. |
| `fillA` | number | `0.55` | `FillTransparency` when `fill` is on. |
| `line` | boolean | `true` | Enable the highlight outline; `false` sets `OutlineTransparency = 1`. |
| `lineCol` | Color3 | white | Outline colour, unless overridden by `tint` or `rainbow`. |
| `lineA` | number | `0` | `OutlineTransparency` when `line` is on (`0` = fully opaque). |
| `mat` | string | `"ForceField"` | `Enum.Material` name for material mode; invalid names fall back to `ForceField`. |
| `matCol` | Color3 | white | unused — material mode colours parts with `fillCol`/`tint`/`rainbow` instead. |
| `matA` | number | `0.2` | Part `Transparency` in material mode, clamped to `0…0.95`. |
| `matHead` | boolean | `true` | Include the `Head` part in material mode. `HumanoidRootPart` is always excluded. |
| `tint` | boolean | `false` | Colour by visibility using `vis`/`hid`. Also forces the visibility test on. |
| `vis` | Color3 | `good` | Tint colour while visible. |
| `hid` | Color3 | `bad` | Tint colour while hidden. |
| `rainbow` | boolean | `false` | Per-entity hue cycling (offset by uid) when `tint` is not driving the colour. |
| `rate` | number | `1` | Rainbow hue speed (`t * rate * 0.12`). |

Material mode re-applies at most once every 20 frames per record, and switching `mat` reverts the previous material first. Original `Material`/`Color`/`Transparency` are stored in a weak-keyed map and restored on clear, out-of-range, death, disconnect, `stop()` or `destroy()`.

### `world`

Lighting/camera overrides. The originals (`Brightness`, `Ambient`, `OutdoorAmbient`, `ExposureCompensation`, `FogEnd`, camera `FieldOfView`) are snapshotted on first apply and restored when `on` goes false, `cfg.on` goes false, `stop()` or `destroy()` runs.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Apply the overrides. |
| `full` | boolean | `false` | Fullbright: forces `Lighting.Brightness = 3`, ignoring `bright`. |
| `fov` | number | `70` | Camera `FieldOfView`, applied unconditionally while `on` is true. |
| `noFog` | boolean | `false` | Sets `FogEnd = 1e7`; otherwise restores the original `FogEnd`. |
| `bright` | number | `1` | `Lighting.Brightness` when `full` is false. |
| `amb` | Color3 | `(0,0,0)` | `Lighting.Ambient`. |
| `out` | Color3 | `(0,0,0)` | `Lighting.OutdoorAmbient`. |
| `exp` | number | `1` | `Lighting.ExposureCompensation`. |
| `grade` | boolean | `false` | Enable the managed `ColorCorrectionEffect` named `easyesp_cc`. |
| `sat` | number | `0` | Its `Saturation`. |
| `con` | number | `0` | Its `Contrast`. |

### `rings`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Enable per-entity ground rings. |
| `enemies` | boolean | `false` | Required alongside `on`: draw the specs at each drawn snapshot's foot position. |
| `specs` | array | `{ ringSpec() }` | One ring per spec, all drawn per entity. Managed with `addRingSpec`, `dropRingSpec`, `clearRingSpecs`. |

Each spec (from `ringSpec()`; also used by `esp:addRing`, entity `spec.ring`, and `Toolkit.ring`):

| Key | Type | Default | Meaning |
|---|---|---|---|
| `rad` | number | `10` | Ring radius in studs. |
| `col` | Color3 | `accent` | Segment colour. |
| `w` | number | `1` | Segment thickness. |
| `a` | number | `1` | Base transparency. |
| `sides` | number | `32` | Segment count at LOD 0; scaled to 75% / 55% / 40% at LOD 1 / 2 / 3, floor 8. |
| `spin` | number | `0` | Radians per second of rotation. |
| `fill` | boolean | `false` | Fan of triangles from the centre to each segment. |
| `fillA` | number | `0.05` | Fill triangle transparency. |
| `glow` | boolean | `false` | Second pass two pixels thicker at 25% alpha. |
| `pulse` | boolean | `false` | Modulate alpha by `0.6 + 0.4*abs(sin(t*pulseRate))`. |
| `pulseRate` | number | `2` | Pulse speed. |
| `style` | string | `"solid"` | `"dashed"` draws every other segment; anything else draws all. |
| `kind` | string | `"circle"` | unused — never read; rings are always circles. |
| `ticks` | number | `0` | Radial tick marks around the ring; drawn only below LOD 2. |
| `tickLen` | number | `0.8` | Tick length in studs beyond `rad`. |

### `self` — FOV, crosshair, watermark, compass

`self.fov`:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw a circle at screen centre. |
| `rad` | number | `120` | Radius in pixels. |
| `sides` | number | `64` | Circle segment count. |
| `w` | number | `1` | Outline thickness. |
| `a` | number | `1` | Outline transparency. |
| `fill` | boolean | `false` | Also draw a filled circle. |
| `fillA` | number | `0.04` | Fill transparency. |
| `col` | Color3 | `text` | Circle colour. |
| `rainbow` | boolean | `false` | Hue-cycle the colour (`t * 0.2`). |

`self.cross`:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw a four-arm crosshair at screen centre. |
| `gap` | number | `4` | Pixels of empty space around the centre. |
| `len` | number | `8` | Arm length. |
| `w` | number | `1` | Arm thickness. |
| `a` | number | `1` | Transparency. |
| `col` | Color3 | `good` | Arm colour. |
| `rainbow` | boolean | `false` | Hue-cycle the colour (`t * 0.22`). |
| `outline` | boolean | `true` | Black backing lines. |
| `dot` | boolean | `false` | Centre dot. |
| `dotSize` | number | `1` | Centre dot radius. |

`self.wm` (watermark; draggable with middle mouse):

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw the watermark. |
| `x` | number | `8` | Text left edge (updated by dragging). |
| `y` | number | `8` | Text top edge (updated by dragging). |
| `size` | number | `12` | Text size; drives the pill height and hit rect. |
| `col` | Color3 | `text` | Text colour. |
| `accent` | Color3 | `accent` | 2px accent stripe on the left of the background. |
| `bg` | boolean | `true` | Black background pill plus the accent stripe. |
| `stats` | boolean | `true` | Append `FPS`, `Drawn` and `Pool` counters to `"EasyESP <ver>"`. |
| `a` | number | `0.32` | Background transparency. |

`self.compass`:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Draw a horizontal compass strip, centred horizontally. |
| `y` | number | `18` | Vertical position of the baseline. |
| `w` | number | `360` | Strip width in pixels (clipped to `±w/2`). |
| `scale` | number | `2.2` | Pixels per degree of bearing offset. |
| `size` | number | `11` | Label text size. |
| `col` | Color3 | `text` | Baseline and minor ticks. |
| `accent` | Color3 | `accent` | Cardinal ticks, `N/E/S/W` labels and the bearing readout. |
| `a` | number | `1` | Transparency (baseline uses `a * 0.35`). |
| `bearing` | boolean | `true` | Numeric heading in degrees above the strip. |

Ticks are placed every 15°, with cardinals every 90°.

### `npc`

An independent deep copy, not a fallback chain — see [Players vs NPCs](#players-vs-npcs).

Mirrored subtables, identical in shape and defaults to their root counterparts: `vis`, `box`, `hp`, `name`, `dist`, `flags`, `bones`, `head`, `gaze`, `tracer`, `chams`, `arrow`, `perf`. There is no `npc.radar`, `npc.list`, `npc.target`, `npc.threat`, `npc.self`, `npc.world` or `npc.priority` — those features are player-only or global.

Where the NPC tree differs:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Enable the NPC category. Does nothing without `esp:setNPCSource(fn)`. |
| `espRange` | number | `3000` | Per-snapshot draw cutoff for NPCs. `0` means unlimited. |
| `maxRange` | number | `3000` | Contributes to the NPC roster reach. `0` means unlimited. |
| `rainbow` | boolean | `false` | Hue-cycle NPC accents. |
| `rainbowRate` | number | `1` | NPC hue speed. |
| `friendTint` | boolean | `false` | Differs from the root default (`true`); inert regardless, since NPC snapshots are never friends. |
| `friendCol` | Color3 | `friend` | Accent fallback when `npc.box.col` is not a `Color3`. |
| `team` | boolean | `false` | Inert: NPC snapshots always have `ally = false`. |
| `rings.on` | boolean | `false` | Enable NPC ground rings. |
| `rings.enemies` | boolean | `true` | Differs from the root default (`false`), so NPC rings only need `rings.on`. |
| `rings.specs` | array | `{ ringSpec() }` | A separate spec array from `cfg.rings.specs`. |
| `perf.npcBoxStep` | number | `4` | **Read here only.** Recompute an NPC's 2D box, and re-run its visibility test, once every N frames. Not affected by `perf.mode = "auto"`. |
| `perf.cullMax` | number | `80` | **Read here only.** Hard cap on NPC snapshots added per frame; the source array is truncated at this count in iteration order, not by distance. |
| `perf.*` (all other keys) | — | mirrored | unused — the engine reads every other `perf` key from the root table, including `npcFrameSkip` and `entityStep`. |

NPC roster reach has a quirk worth knowing: `reach` becomes unlimited if **either** `npc.maxRange` or `npc.espRange` is `<= 0`, otherwise it is `max(npc.maxRange, npc.espRange)` (`EasyESP.luau:1743`). The per-draw cutoff still uses `npc.espRange` alone.

---

## Performance

Eight independent throttles plus a distance LOD. They are separate mechanisms, and several **compound** — the effective work is the product, not the max.

**`perf.mode = "auto"`** (default). `_plan()` measures `stats.fpsAvg` and roster size and multiplies `visStep`, `boxStep` and `toolStep` before use:

- FPS multiplier: `1` at ≥120, `1.15` at ≥90, `1.35` at ≥70, `1.6` at ≥55, `1.95` at ≥45, `2.4` below.
- Roster load multiplier: `1 + clamp((players - 8) / 18, 0, 1.8)`, applied to `visStep` and `boxStep` only.
- Results are floored at `1`, `1`, and `3` respectively; `toolStep` adds `players * 0.15` instead of the load multiplier.

So at 40 FPS with 30 players, `boxStep = 2` becomes `2 * 2.4 * 2.22 ≈ 11`. Set `perf.mode` to anything else (e.g. `"manual"`) to use the raw numbers verbatim. Note `_plan` scales only these three keys — the LOD thresholds, `frameSkip`, `npcBoxStep`, `npcFrameSkip`, `entityStep` and `cullMax` are never auto-scaled.

**`frameSkip`** — skips whole frames: `frame % (frameSkip + 1) ~= 0` returns from `tick` immediately. This return happens **before `pool:begin()`/`pool:finish()`**, which is deliberate: skipped frames leave the pool's live/prev bookkeeping untouched, so nothing is hidden and the previous frame's drawings simply persist on screen. The cost is staleness, not flicker. It compounds with everything below, since the step counters key off `self.frame`, which only advances on frames that reach the check.

**`boxStep`** — per-uid, phase-offset by uid (`(frame + uid + salt) % step == 0`), so recomputation is spread across frames rather than spiking. Between recomputes the cached 2D box is reused, so boxes lag slightly behind fast movement. A box is always computed on the first frame an entity has none.

**`visStep`** — same per-uid rotation for the visibility raycast (1–5 rays per test, per `vis.points`). The test only runs at all if something needs it: `vis.check`, `vis.hide`, `vis.tint`, `target.visOnly`, or `chams.on and chams.tint`. Leaving all of those off is the single largest saving available.

**`toolStep`** — same rotation for `FindFirstChildOfClass("Tool")`, used by the `tool` flag.

**`npcBoxStep`** (read from `cfg.npc.perf`) — the NPC equivalent of `boxStep` *and* `visStep` combined: it gates both the NPC box recompute and the NPC visibility test. It is not auto-scaled.

**`npcFrameSkip`** (read from root `cfg.perf`) — gates the chams pass for NPC snapshots only: `frame % npcFrameSkip == 0`. Player chams run every frame. This throttles instance mutation (Highlight properties, material swaps), which is the expensive part. NPC *drawing* (`_player`) is intentionally not gated by it — running box/name/tracer drawing at a lower rate than the display would strobe, so the draw pass stays per-frame by design and only the cham state machine is slowed.

**`entityStep`** — the entity pass runs on `frame % entityStep == 0`. On skipped frames it calls `pool:carry("ent")`, which re-marks the previous frame's `ent`-prefixed keys as live so `finish()` does not hide them. Entity overlays therefore hold their last position between passes rather than blinking.

**`cullMax`** (read from `cfg.npc.perf`) — hard cap on NPC snapshots per frame, applied while iterating the source array. It truncates in source order before distance sorting, so with a large source the retained set is arbitrary, not the nearest N. Filter or pre-sort in your source callback if that matters.

**LOD (`near` / `mid` / `far`)** — every snapshot gets a bucket from its distance: 0 ≤ `near`, 1 ≤ `mid`, 2 ≤ `far`, else 3. Effects: bones are skipped above LOD 1; ring segment counts scale to 100/75/55/40% (floor 8); ring ticks are skipped at LOD 2 and above. Nothing else reads the bucket.

**Pool pruning** — `pruneAfter` / `pruneEvery` trade memory for allocation churn: destroying a drawing frees it, but a re-appearing entity must allocate a new one. The defaults (destroy after 260 idle frames, swept every 90) are tuned for a rotating roster; raise `pruneAfter` if entities cycle in and out of range frequently, set it to `0` to never destroy.

Two coarser controls sit above all of this: `maxRange` keeps distant entities out of the snapshot entirely (cheapest possible cull, since nothing downstream sees them), and `espRange` only suppresses drawing while still paying for the snapshot. Prefer lowering `maxRange`.

The built-in `PROFILES` (`low`, `balanced`, `high`, applied with `esp:profile(name)`) set `frameSkip`, `visStep`, `boxStep`, `toolStep`, the LOD thresholds and the prune pair together, and also merge the same `perf` block into `cfg.npc.perf`.

---

## API reference

Every method below lives on the `ESP` metatable, so `esp:method(...)` works for all of them. `ESP.new`, `ESP.DestroyAll`, `ESP.GetDescriptors`, `ESP.GetDescriptorDefaults`, `ESP.GetDescriptor` and `ESP.Validate` are also safe to call dot-style on the class table. Aliases are listed once in [Aliases](#aliases) rather than repeated per entry.

### Lifecycle

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `ESP.new(opt?)` | `opt`: partial config table, any depth | the instance | `deep`-merges `opt` over `defaults()`, then `fill`s any gaps back from `defaults()`. Destroys the previously registered instance in `getgenv().__EASY_STACK.esp` first. |
| `esp:start()` | — | `self` | Connects `RunService.RenderStepped` → `tick`. No-op if already running. |
| `esp:stop()` | — | `self` | Disconnects the loop, `pool:reset()` (hide all), restores lighting, clears every cham. The pool objects survive. |
| `esp:destroy()` | — | `nil` | `stop()` + unbind the MB3 action + `clearBinds()` + disconnect player/humanoid signals + `pool:nuke()` + empty every registry table. |
| `ESP.DestroyAll()` | — | `nil` | Destroys every instance the module has created, newest first. |
| `esp:on(v)` | `v`: any truthy/falsey | `self` | Writes `cfg.on = v and true or false`. |
| `esp:setEnabled(v)` | as `on` | `self` | Wrapper around `on`. |
| `esp:toggle()` | — | `boolean` — the new `cfg.on` | Returns the state, not `self`. |

### Sources

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:setNPCSource(fn)` | `fn() -> {Instance}` | `self` | Called once per frame inside `pcall`. A non-function clears the source. Must return an array table; anything else is ignored for that frame. |
| `esp:npc(v)` | `v`: truthy/falsey | `self` | Writes `cfg.npc.on`. Inert without a source. |
| `esp:setTargetSource(fn)` | `fn() -> snapshot \| Model \| Player` | `self` | Result is matched against `s`, `s.char` and `s.plr` across the roster; a match locks the target and skips FOV selection. No match falls through to normal selection. |
| `esp:setTargetInfo(fn)` | `fn(snapshot) -> string?` | `self` | Extra line on the target info card. |
| `esp:setNPCLabel(fn)` | `fn(Instance) -> string?` | `self` | Per-frame per-NPC label. Falsey result falls back to `model.Name`. |

```lua
esp:setNPCSource(function() return workspace.Walkers:GetChildren() end):npc(true)
```

### Appearance

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:theme(nameOrTbl?)` | theme name (`"pastel"`, `"carbon"`, `"rose"`, `"mint"`, `"mono"`) or a table with any of `accent`/`good`/`bad`/`text`/`muted`/`friend`/`ink` | `true`, or `false` if the name is unknown | `nil` means `"pastel"`. Missing table keys keep the current value. Writes ~35 player keys and their `cfg.npc` counterparts, plus `rings.specs[1].col` on both trees. |
| `esp:applyTheme(nameOrTbl?)` | as `theme` | as `theme` | Wrapper. |
| `esp:themes()` | — | sorted `{string}` | |
| `esp:setAccent(c)` | `c`: `Color3` | the applied `Color3` | Narrower than `theme`: sets `box.col`, `box.fillCol`, `tracer.col`, `arrow.col`, `radar.enemy`, `target.col`, `list.enemy`, `self.wm.accent`, `self.compass.accent`, `rings.specs[1].col`. **Player tree only** — it does not touch `cfg.npc`. A non-`Color3` leaves `box.col` unchanged. |

### Performance

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:profile(name)` | `"low"` / `"balanced"` / `"high"` | `true`, or `false` if unknown | Merges the profile, then merges its `perf` block into `cfg.npc.perf`, then `fill`s from defaults. |
| `esp:applyPerformance(name)` | as `profile` | as `profile` | Wrapper. |
| `esp:performanceProfiles()` | — | sorted `{string}` | |

### Packs and presets

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:pack(name)` | `"clean"` / `"comp"` / `"world"` | `true`, or `false` if unknown | Merges the pack into `cfg`, then merges every pack subtable that also exists on `cfg.npc` into that counterpart (so `box`/`name`/`hp`/`dist`/`flags`/`tracer`/`arrow` propagate; `radar`/`list`/`target` have no NPC counterpart and are skipped). |
| `esp:applyFeaturePack(name)` | as `pack` | as `pack` | Wrapper. |
| `esp:featurePacks()` | — | sorted `{string}` | |
| `esp:preset(name)` | `"lite"` / `"legit"` / `"world"` / `"full"` | `true`, or `false` if unknown | Applies `theme`, then `profile`, then `pack`, then merges the preset's `extra` table. Later steps overwrite earlier ones. |
| `esp:applyPreset(name)` | as `preset` | as `preset` | Wrapper. |
| `esp:presets()` | — | sorted `{string}` | |

### Flags

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:flag(name, fn)` | `name`: string key; `fn(snapshot) -> {text, Color3?} \| nil` | `fn` | Re-registering an existing name replaces the callback and keeps its position in `flagOrder`. A new name is appended and starts enabled. |
| `esp:setFlagEnabled(name, on)` | `name`: string; `on`: truthy/falsey | `self` | Coerced with `not not on`. Works for names that are not registered yet. |
| `esp:dropFlag(name)` | `name`: string | `nil` | Removes the callback, its enabled state and its order entry. |

See [Flag callbacks](#flag-callbacks) for the callback contract.

### Draw hooks

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:hook(name, fn)` | `name`: string key; `fn(esp, snapshot)` | `fn` | Runs once per **drawn** snapshot (players and NPCs), at the end of `_player`, inside `pcall`. Snapshots culled by team/visibility/range/off-screen never reach it. Return value is ignored. |
| `esp:unhook(name)` | `name`: string | `nil` | |

```lua
esp:hook("underline", function(e, s)
    e.pool:line("hk" .. s.uid, s.bx, s.by + s.bh + 1, s.bx + s.bw, s.by + s.bh + 1, s.rec and Color3.new(1,1,1), 1, 1)
end)
```

### Modules

A module is a named bundle of stage callbacks with its own `state` table.

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:mod(spec)` | `spec.name` (required string), `spec.on` (boolean, must be exactly `true` to start enabled), `spec.state` (table, default `{}`), `spec.up(state, esp)`, `spec.down(state, esp)`, `spec.world(state, esp)`, `spec.player(state, esp, snapshot)`, `spec.screen(state, esp)` | the stored module record | Asserts on a missing name. Re-registering a name runs the old module's `down` first. `state.esp` is set to the instance. `up` fires immediately. All stage calls are `pcall`ed. `world` runs after the roster snapshot, `player` per drawn snapshot after hooks, `screen` after the HUD passes. |
| `esp:module(name)` | `name`: string | the record or `nil` | Fields: `name`, `on`, `state`, `up`, `down`, `player`, `world`, `screen`. |
| `esp:toggleMod(name, on?)` | `name`: string; `on`: boolean or `nil` to flip | `nil` | Silently ignores unknown names. Quirk: flipping an enabled module sets `m.on = nil` rather than `false` (falsey either way). |
| `esp:dropMod(name)` | `name`: string | `nil` | Runs `down` before removal. |

### Friends

Friends are keyed by `UserId`, so they only ever affect player snapshots.

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:friend(x)` | `Player` instance, or a numeric `UserId` (or numeric string) | `nil` | Any other `Instance` resolves to no id and is ignored without erroring. |
| `esp:markFriend(x)` | as `friend` | `nil` | Wrapper. |
| `esp:unfriend(x)` | as `friend` | `nil` | |
| `esp:unmarkFriend(x)` | as `friend` | `nil` | Wrapper. |
| `esp:clearFriends()` | — | `nil` | Clears in place; existing references to the table stay valid. |
| `esp:isFriend(x)` | as `friend` | `boolean` | Never returns `nil`. |

### Rings and center

Two independent ring systems: **static rings** (`self.rings`, world anchors, drawn in the self-HUD pass) and **config ring specs** (`cfg.rings.specs` / `cfg.npc.rings.specs`, drawn at every drawn entity's foot position).

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:addRing(id, spec?)` | `id`: any table key; `spec`: ring table, normalised through `ringSpec()` | the normalised spec | Two extra keys beyond the [ring spec](#rings): `at` — anchor, resolved through `center()` each frame (`nil` = local player's feet, `Vector3`, function, `Player`, `BasePart`, `Model`); `y` — stud offset added to the anchor. |
| `esp:dropRing(id)` | `id` | `nil` | |
| `esp:clearRings()` | — | `nil` | Replaces the table; drawings are hidden by `pool:finish()` on the next frame. |
| `esp:addRingSpec(spec?)` | `spec`: ring table | the normalised spec | Appends to `cfg.rings.specs` (player tree only). |
| `esp:dropRingSpec(i?)` | `i`: index, default the last | `nil` | |
| `esp:clearRingSpecs()` | — | `nil` | Leaves `cfg.rings.specs` an empty array, not the default one-spec array. |
| `esp:center(x?)` | `nil`, `Vector3`, `function() -> Vector3`, `Player`, `BasePart`, `Model` | `Vector3` or `nil` | `nil` = local player's feet (`HipHeight + 0.1` below the root, else 2.6). `Player` = that player's feet. `BasePart` = bottom-centre. `Model` = `PrimaryPart` position, else the first `BasePart` position. |

```lua
esp:addRing("home", { at = Vector3.new(0, 5, 0), rad = 40, pulse = true, glow = true })
```

### Entities

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:addEnt(id, spec)` | `id`: any table key; `spec`: see [Entity spec reference](#entity-spec-reference) | the spec | Asserts without `spec.get`. **Mutates and stores the table you pass**, so you can keep the reference and retune `col`/`max` later. Normalises `col`, `box`, `name`, `dist` and `ring`. |
| `esp:addEntity(id, spec)` | as `addEnt` | as `addEnt` | Wrapper. |
| `esp:addInst(id, inst, opt?)` | `id`: key; `inst`: `BasePart` or `Model`; `opt`: `label`, `col`, `box`, `name`, `dist`, `tracer`, `dot`, `ring`, `size`, `max`, `draw` | the built spec | Builds a `get` that returns the instance while it has a `Parent`. If `id` is already taken it appends `_<GetDebugId()>` (or a microsecond stamp) instead of overwriting. |
| `esp:addInstanceEntity(id, inst, opt?)` | as `addInst` | as `addInst` | Wrapper. |
| `esp:dropEnt(id)` | `id` | `nil` | |
| `esp:removeEntity(id)` | `id` | `nil` | Wrapper. |
| `esp:clearEnts(prefix?)` | `prefix`: string; omit to clear all | `number` removed | With a prefix, matches on `tostring(id):sub(1, #prefix)`. |
| `esp:clearEntities(prefix?)` | as `clearEnts` | `number` | Wrapper. |

### Scanning

All scanners register entity specs through `addInst`, clear their own prefix first unless `clear == false`, and return the number registered.

| Signature | Parameters | Returns |
|---|---|---|
| `esp:scan(root?, spec?)` | `root` (default `workspace`); `spec`: `prefix` (`"scan_"`), `limit` (`80`), `clear`, `names` (array of case-insensitive substrings), `classes` (array of class names), `models`, `parts`, plus the `addInst` opts `label` (string or `function(inst)`), `col`, `box`, `name`, `dist`, `tracer`, `dot`, `ring`, `max` | `number` |
| `esp:scanInstances(root?, spec?)` | as `scan` | `number` |
| `esp:scanNPCs(opt?)` | `root`, `prefix` (`"npc_"`), `limit` (`40`), `clear`, `label`, `col` (default `(255,135,135)`), `box`, `name`, `dist`, `tracer`, `dot`, `ring`, `max` | `number` |
| `esp:scanTools(opt?)` | `root`, `prefix` (`"tool_"`), `limit` (`60`), same opts; `col` default `(255,220,110)` | `number` |
| `esp:scanPickups(opt?)` | `root`, `prefix` (`"pickup_"`), `limit` (`80`), `names` (default `ammo/coin/cash/drop/pickup/weapon/med/armor`), same opts; `col` default `(120,255,190)` | `number` |

Filter precedence in `scan` is `names` → `classes` → `models` → `parts` → `Model`; only the first non-nil branch is used, and a match must still be a `Model` or `BasePart`. `scanNPCs` requires a `Humanoid` and excludes player characters, and boxes the model. `scanTools` boxes the tool's `Handle` (or first `BasePart`), not the `Tool`.

### Input

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:bind(key, fn)` | `key`: `Enum.KeyCode`; `fn(esp)` | the `RBXScriptConnection` | Keyboard `InputBegan`, ignores gameProcessed input, calls `fn` inside `pcall`. Connections are tracked and dropped by `clearBinds`/`destroy`. |
| `esp:clearBinds()` | — | `number` disconnected | |

### Queries

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:nearest(maxRange?, allies?)` | `maxRange`: number, default unlimited; `allies`: truthy to include same-team players | `Player` or `nil` | Walks the distance-sorted roster and returns the first entry that has a `plr` (so NPCs are skipped) within range. |
| `esp:project(pos)` | `pos`: `Vector3` | `x, y, depth, onScreen` — four values | `depth <= 0` means behind the camera. Returns `0, 0, -1, false` with no camera. |
| `esp:sees(char, points?)` | `char`: `Model`; `points`: `1`–`5`, default `cfg.vis.points` | `boolean` | Immediate raycast, ignores the per-uid throttle. Rays originate at the camera and exclude the local character and `char`. |
| `esp:statsGet()` | — | table | `fps`, `fpsAvg`, `drawn`, `pool`, `roster` (`#snap`, so players **and** NPCs), `target` (display name / NPC label / `nil`), `ents`, `friends`. Freshly built each call. |
| `esp:getStats()` | — | table | Wrapper. |

### Persistence

Configs are stored as JSON under `EasyESP4/<name>.json`. `Color3` values survive the round trip as `{__easyesp="c", r, g, b}`; `Instance` and function values are stripped.

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `esp:export()` | — | JSON string | `{ ver = "4.0.0", cfg = <packed cfg> }`. |
| `esp:import(str)` | `str`: JSON string | `boolean` | Rejects malformed JSON or a missing `cfg` table. Fills gaps from `defaults()`, then rewrites `self.cfg` **in place** (clear + copy), so any external reference to the config table — including a UI mount — stays valid. |
| `esp:save(name)` | `name`: string, sanitised to `[%w_-]` (empty → `"default"`) | `boolean` | `false` without `writefile`. |
| `esp:load(name)` | `name`: string | `boolean` | `false` without `isfile`/`readfile`, or if the file is missing. |
| `esp:configs()` | — | sorted `{string}` | Names without the `.json` suffix. `{}` without `isfolder`/`listfiles`. |
| `esp:repair()` | — | `self.cfg` | `fill(cfg, defaults())` — adds missing keys, never overwrites existing ones. |
| `esp:repairConfig()` | — | `self.cfg` | Wrapper. |

### Descriptors

65 descriptor entries describe the subset of the config that a UI should expose. See [UI bridge](#ui-bridge) for the entry shape.

| Signature | Parameters | Returns | Notes |
|---|---|---|---|
| `ESP.GetDescriptors(prefix?)` / `esp:GetDescriptors(prefix?)` | `prefix`: string prepended to each `path` as `prefix .. "." .. path` | a deep copy of the descriptor array | Both call styles take the prefix in the first *meaningful* position; the instance is discarded when present. Mutating the result is safe. |
| `ESP.GetDescriptorDefaults(prefix?)` / `esp:GetDescriptorDefaults(prefix?)` | as above | map of `path -> default` | Defaults are the library defaults, not the instance's current values. |
| `ESP.GetDescriptor(path)` / `esp:GetDescriptor(path)` | `path`: string | a deep copy of one entry, or `nil` | |
| `ESP.Validate(...)` | see below | the coerced value | |
| `ESP.Descriptors` | — | the live descriptor array | The real table, not a copy. Treat as read-only. |

Path lookup accepts a prefixed path: if the first dot-segment is **not** a top-level config key, it is stripped and the remainder is looked up. So `"ui.box.on"` resolves to the `box.on` descriptor, while `"npc.box.on"` resolves to nothing, because `npc` *is* a top-level key — NPC paths deliberately have no descriptors.

Coercion by `kind`: `toggle` → `not not value`; `slider`/`number` → `tonumber` (falling back to the descriptor default, then `0`), clamped to `min`/`max`, then snapped to `step` from `min`; `dropdown`/`mode` → `tostring(value)` if it matches an `items` entry, else the default; `color` → the value if it is a `Color3`, else the default; `keybind` → the value if it is an `EnumItem`, else the default. An unknown path returns the value untouched.

**`ESP.Validate` argument positions.** The declaration is `ESP.Validate(selfOrPath, path, value)` and it branches on `type(selfOrPath) == "table"`:

```lua
ESP.Validate("box.w", 3.7)        -- dot-call:    arg1 = path,     arg2 = value      -> 4
esp:Validate("box.w", 3.7)        -- method-call: arg1 = self,     arg2 = path, arg3 = value -> 4
ESP.Validate(esp, "box.w", 3.7)   -- explicit self, same as the method call          -> 4
esp.Validate("box.w", 3.7)        -- dot-call through the instance, still correct    -> 4
```

Both styles work, but the discriminator is purely "is argument 1 a table", so a dot-call must never pass a table as the path. `Toolkit.validate(path, value)` forwards dot-style.

### `ESP.Toolkit`

Stateless helpers on the class table. `Toolkit.quickESP` is an alias of `Toolkit.quick`.

| Member | Signature | Returns | Notes |
|---|---|---|---|
| `version` | field | `"4.0.0"` | Same string as `ESP.ver` / `ESP.version`. |
| `themes` | field | the live `THEMES` table | Keys: `pastel`, `carbon`, `rose`, `mint`, `mono`. |
| `profiles` | field | the live `PROFILES` table | Keys: `low`, `balanced`, `high`. |
| `packs` | field | the live `PACKS` table | Keys: `clean`, `comp`, `world`. |
| `presets` | field | the live `PRESETS` table | Keys: `lite`, `legit`, `world`, `full`. |
| `descriptors` | field | the live `DESCRIPTORS` array | Same table as `ESP.Descriptors`. |
| `clone` | `Toolkit.clone(x)` | deep copy | Recurses tables but copies `Color3`/`Vector2`/`Vector3` by reference. Non-tables pass through. |
| `merge` | `Toolkit.merge(a, b)` | `a` | Recursive overwrite: `b` wins; a `Color3` in `b` always replaces rather than merges. |
| `fill` | `Toolkit.fill(a, b)` | `a` | Only writes keys missing from `a`; recurses where both sides are tables. |
| `color` | `Toolkit.color(r?, g?, b?)` | `Color3` | 0–255 components, each defaulting to `255`. |
| `hsv` | `Toolkit.hsv(h?, s?, v?)` | `Color3` | Defaults `0, 1, 1`. |
| `ring` | `Toolkit.ring(spec?)` | normalised ring spec | Same normaliser used by `addRing` and `spec.ring`. Fills the passed table in place. |
| `flag` | `Toolkit.flag(txt, c?)` | `{tostring(txt), c}` | The row shape a flag callback must return. |
| `pathGet` | `Toolkit.pathGet(t, path)` | value or `nil` | Dot path. Returns `nil` on any non-table segment. |
| `pathSet` | `Toolkit.pathSet(t, path, value)` | `value` | Creates intermediate tables, overwriting non-table segments. |
| `pathToggle` | `Toolkit.pathToggle(t, path)` | the new value | `pathSet(t, path, not pathGet(t, path))`. |
| `findPlayer` | `Toolkit.findPlayer(q)` | `Player` or `nil` | Case-insensitive plain-substring match against `Name` then `DisplayName`; first hit in `GetPlayers()` order. |
| `scan` | `Toolkit.scan(root?, pred, limit?)` | `{Instance}` | `root` default `workspace`, `limit` default `100`. `pred(inst)` runs inside `pcall`; a throwing predicate just excludes the instance. Returns instances — it does **not** register entities. |
| `applyTheme` | `Toolkit.applyTheme(esp, name)` | as `esp:theme` | |
| `applyProfile` | `Toolkit.applyProfile(esp, name)` | as `esp:profile` | |
| `applyPack` | `Toolkit.applyPack(esp, name)` | as `esp:pack` | |
| `applyPreset` | `Toolkit.applyPreset(esp, name)` | as `esp:preset` | |
| `getDescriptors` | `Toolkit.getDescriptors(prefix?)` | descriptor array copy | |
| `getDescriptorDefaults` | `Toolkit.getDescriptorDefaults(prefix?)` | `path -> default` map | |
| `getDescriptor` | `Toolkit.getDescriptor(path)` | entry copy or `nil` | |
| `validate` | `Toolkit.validate(path, value)` | coerced value | |
| `quick` | `Toolkit.quick(opt?)` | a started instance | `theme`, `profile`, `pack`, `preset` and `on` are consumed as control keys; every other key is passed to `ESP.new` as config seed. Applies theme → profile → pack → preset, sets `cfg.on` (`opt.on ~= false`), then `start()`s. |
| `quickESP` | alias of `quick` | | |

```lua
local esp = ESP.Toolkit.quick({ preset = "legit", box = { kind = "3d" } })
```

### Aliases

Two kinds. **Reference** aliases are the same function object (`ESP.Start == ESP.start`); **wrapper** aliases are separate functions that immediately call the canonical one. Behaviour is identical either way.

| Alias | Canonical | Kind |
|---|---|---|
| `Start` | `start` | reference |
| `Stop` | `stop` | reference |
| `Destroy` | `destroy` | reference |
| `addFlag` | `flag` | reference |
| `removeFlag` | `dropFlag` | reference |
| `onDraw` | `hook` | reference |
| `removeDraw` | `unhook` | reference |
| `register` | `mod` | reference |
| `toggleModule` | `toggleMod` | reference |
| `unregister` | `dropMod` | reference |
| `attachRing` | `addRing` | reference |
| `detachRing` | `dropRing` | reference |
| `GetStats` | `getStats` | reference |
| `setEnabled` | `on` | wrapper |
| `applyTheme` | `theme` | wrapper |
| `applyPerformance` | `profile` | wrapper |
| `applyFeaturePack` | `pack` | wrapper |
| `applyPreset` | `preset` | wrapper |
| `markFriend` | `friend` | wrapper |
| `unmarkFriend` | `unfriend` | wrapper |
| `addEntity` | `addEnt` | wrapper |
| `removeEntity` | `dropEnt` | wrapper |
| `addInstanceEntity` | `addInst` | wrapper |
| `clearEntities` | `clearEnts` | wrapper |
| `scanInstances` | `scan` | wrapper |
| `getStats` | `statsGet` | wrapper |
| `repairConfig` | `repair` | wrapper |
| `ESP.version` | `ESP.ver` | field copy |
| `Toolkit.quickESP` | `Toolkit.quick` | reference |

---

## Entity spec reference

The table you hand to `addEnt(id, spec)`. `addEnt` normalises five fields in place and stores the same table, so you may keep the reference and retune it live. Everything else is read fresh every entity pass by `drawOne` (`EasyESP.luau:2573`).

| Field | Type | Default | Meaning |
|---|---|---|---|
| `get` | `function() -> obj` | **required** | Returns a `Vector3`, a `BasePart`, a `Model`, or an array of those. Anything else — including a `nil` return — draws nothing that pass. Array entries are drawn under `id .. "_" .. i`, so a stable ordering keeps pool keys stable. |
| `label` | string or `function(obj) -> string` | `nil` | The name text. Drawn only when `name` is also truthy and the resolved label is a non-empty string. Fixed size 12, centred 16px above the box. |
| `box` | boolean | `true` | 2D bounding box from the object's pivot and size. Normalised as `spec.box ~= false`. |
| `name` | boolean | `true` | Gate for `label`. Normalised as `spec.name ~= false`. |
| `dist` | boolean | `true` | Distance text under the box, size 10. Normalised as `spec.dist ~= false`. |
| `col` | `Color3` | `cfg.box.col` at registration time | Used by every part of the entity overlay. Non-`Color3` values are replaced at registration. |
| `outline` | boolean | `true` | The black backing rectangle behind the box. Only `false` disables it, and only the box has one — label, distance, dot, tracer and ring have no outline pass. |
| `priority` | number | `cfg.priority.entity` (`2`) | Multiplied by `cfg.priority.scale` into `pool.zbias` for this group. |
| `max` | number | `cfg.maxRange` (`3000`) | Distance cull, in studs. Compared directly, so **`0` culls everything** — there is no "unlimited" branch here. |
| `size` | `Vector3` | `Vector3.new(3, 4, 3)` | Box dimensions, used **only** when `get` returns a `Vector3`. `BasePart` uses `Size`, `Model` uses `GetBoundingBox()`. |
| `dot` | boolean | `nil` (off) | Filled 3px 12-sided dot at the bottom-centre of the box. |
| `tracer` | boolean | `nil` (off) | 1px line from the bottom-centre of the screen to the bottom-centre of the box. Not configurable per group — it ignores `cfg.tracer`. |
| `ring` | ring spec table | `nil` | World ring at `pos - Vector3.new(0, size.Y/2, 0)`, always drawn at LOD 0. **Normalised through `ringSpec()` by `addEnt`**, so a partial table is filled with ring defaults. Assigning `spec.ring` *after* registration skips that normalisation — pass it at registration, or run it through `ESP.Toolkit.ring(...)` yourself. |
| `draw` | `function(esp, id, obj, pos, x, y, w, h, dist)` | `nil` | Called last, inside `pcall`, with the drawn id (including the `_i` suffix for arrays), the object, its world position, the box rect and the distance. Use it for custom pooled drawings. |

Two caveats: `get` and `label` are **not** `pcall`-wrapped (only `draw` is), so an error in either aborts the whole frame — `start()` catches it, warns once and keeps the loop alive, but nothing else draws that frame. And any pool key you create inside `draw` should start with `ent` so that `pool:carry("ent")` keeps it visible on frames skipped by `perf.entityStep`.

```lua
local Loot = workspace:WaitForChild("Loot")

esp:addEnt("loot", {
    get   = function() return Loot:GetChildren() end,
    label = function(obj) return obj:GetAttribute("Item") or obj.Name end,
    col   = Color3.fromRGB(120, 255, 190),
    box = true, name = true, dist = true,
    outline  = false,
    dot      = true,
    tracer   = false,
    priority = 3,
    max      = 900,
    size     = Vector3.new(2, 2, 2),
    ring     = { rad = 3, a = 0.6, pulse = true },
    draw = function(e, id, obj, pos, x, y, w, h, dist)
        if dist < 40 then
            e.pool:txt("ent_hint" .. id, "PICK UP", x + w * 0.5, y + h + 15, 10, Color3.new(1, 1, 1), true)
        end
    end,
})
```

---

## Flag callbacks

Flags are the text column beside the box, shared by players and NPCs. Registration and the callback contract:

```lua
esp:flag(name: string, fn: (snapshot) -> ({ string, Color3? } | nil))
```

The callback receives exactly one argument, the snapshot, and runs inside `pcall` once per drawn entity per frame while `flags.on` is set on that entity's config tree.

Return shape:

- `{ text, colour }` — `text` is `tostring`ed; `colour` falls back to `flags.col` when absent. Rows are numbered in registration order and stacked by `flags.size + flags.gap`.
- `nil` or `false` — no row; the numbering closes up, so a flag that appears and disappears does not leave a gap.
- Anything else (a bare string, `true`, a number) is a bug: the engine indexes `out[1]` outside the `pcall`, which either yields `"nil"` text or aborts the frame. Return a table or nothing.

`esp:setFlagEnabled(name, false)` suppresses a row without unregistering it; five flags are registered at construction (`vis`, `hp`, `tool`, `spd`, `friend`), all enabled.

### Snapshot fields

| Field | Type | Meaning |
|---|---|---|
| `plr` | `Player` | The player. **`nil` on NPC snapshots** — the reliable way to tell the categories apart alongside `npc`. |
| `char` | `Model` | Character model for players, the source model for NPCs. |
| `hum` | `Humanoid` | The humanoid. Can be `nil` for NPCs sourced from models that carry a `Health` attribute instead. |
| `root` | `BasePart` | `HumanoidRootPart` for players; for NPCs, `HumanoidRootPart` → `PrimaryPart` → first `BasePart`. Never `nil`. |
| `head` | `BasePart` | The `Head` child, or `nil` if absent. |
| `uid` | number | Positive `UserId` for players, negative counter id for NPCs. Every pool key for this entity embeds it. |
| `npc` | `true` | Present **only** on NPC snapshots; `nil` on player snapshots. |
| `name` | string | The resolved NPC label (`npcLabel` result, else the model name). **NPC only** — `nil` for players, whose text comes from `plr.DisplayName`. |
| `dist` | number | Studs from the camera position to `root.Position`. The roster is sorted ascending on this. |
| `hp` | number | Current health. `Health` attribute for NPCs when present, otherwise `Humanoid.Health`. |
| `maxHp` | number | Max health. NPCs without a humanoid, or with a non-positive max, report `100`. |
| `hpPct` | number | `hp / maxHp` clamped to `0…1`; `0` when `maxHp <= 0`. |
| `vis` | boolean or `nil` | Last visibility raycast result. **`nil` means "never tested"** — the test only runs when something needs it, and only on this uid's turn. Test for `s.vis == false` rather than `not s.vis`. |
| `on` | boolean | `WorldToViewportPoint`'s on-screen flag for the root position. |
| `sx`, `sy` | number | Projected screen position of the root. |
| `depth` | number | Projected depth. `<= 0` means behind the camera; nothing is drawn in that case. |
| `bx`, `by` | number or `nil` | Top-left of the cached 2D box. `nil` while no box has ever been computed for this uid. |
| `bw`, `bh` | number or `nil` | Width and height of the cached 2D box. |
| `lod` | number | `0`–`3` from `perf.near`/`mid`/`far`. Always computed from the **root** `perf` table, including for NPCs. |
| `team` | `Team` or `nil` | `plr.Team`. **Player only** — absent on NPC snapshots. |
| `teamCol` | `Color3` or `nil` | `plr.TeamColor.Color`. **Player only.** Drives `box.mode = "team"`. |
| `ally` | boolean | Same non-nil `Team` as the local player. **Hardcoded `false` for NPCs**, so `cfg.npc.team` and every ally branch are inert for them. |
| `friend` | boolean | Marked through the friends API. **Hardcoded `false` for NPCs**, so `cfg.npc.friendTint` and `cfg.npc.friendCol`'s tint branch are inert for them. |
| `tool` | string | Name of the held `Tool`, `""` when none. Refreshed on the uid's `toolStep` turn. Always `""` for NPCs. |
| `foot` | `Vector3` or `nil` | Ground position under the root (`HipHeight + 0.1`, else 2.6 studs down). Anchor for per-entity rings. |
| `pivot` | `CFrame` | Pivot used for the last 3D→2D box computation. |
| `size` | `Vector3` | Extents used for that computation, and by the `3d` box kinds. Players get a clamped hull of the visible character parts; NPCs get `Model:GetBoundingBox()`. |
| `rec` | table | The persistent per-entity record that survives across frames — the right place to stash your own state. Carries `uid`, `hp`, `maxHp`, `hp0`, `vis`, `pivot`, `size`, `box`, `hitAt`, `hitDmg`, cham state, and `plr` (players) or `model` (NPCs). |
| `cfg` | table | The config root for this entity. Present **only** on NPC snapshots, where it is `cfg.npc`; player snapshots omit it. Read it as `s.cfg or esp.cfg`. |

```lua
esp:flag("armor", function(s)
    if s.npc then return end                     -- players only
    local v = s.char and s.char:GetAttribute("Armor")
    if v and v > 0 then
        return { "ARM " .. math.floor(v), Color3.fromRGB(120, 190, 255) }
    end
end)

esp.cfg.flags.on = true
esp:setFlagEnabled("spd", false)
```

---

## UI bridge

`ESP.Descriptors` is a flat array of 65 entries describing the config keys a settings UI should expose. It is a curated subset — 65 of several hundred keys — and it deliberately contains **no `npc.*` paths**.

### Descriptor entry

| Field | Type | Present on | Meaning |
|---|---|---|---|
| `path` | string | all | Dot path into `cfg`, e.g. `"box.kind"`, `"self.wm.on"`. |
| `label` | string | all | Human-readable control text. |
| `kind` | string | all | One of `toggle`, `slider`, `dropdown`, `color`. (`mode`, `keybind`, `label`, `section` and `note` are handled by `Validate`/`desc` but are not used by any current entry.) |
| `window` | string | all | Top-level grouping: `Combat`, `Visuals`, `Radar`, `World`, `Self`. |
| `tab` | string | all | Tab within the window. |
| `subtab` | string | some | Nested tab; entries without it sit directly on the tab. |
| `section` | string | all | Card within the tab. |
| `order` | number | all | Intended sort key, `10`-spaced across the whole array. |
| `default` | any | all | The library default, read from `defaults()` at load. Not the instance's current value. |
| `desc` | string | two entries | Long-form description (`target.on`, `target.fov` only). |
| `min`, `max`, `step` | number | sliders | Range and quantisation for `Validate`. |
| `decimals` | number | some sliders | Display precision hint (`box.fillA` = 2, `world.bright` = 1). Not used by `Validate`. |
| `items` | `{string}` | dropdowns | Allowed values; `Validate` rejects anything else back to `default`. |
| `bindable` | boolean | all | `true` for real controls; `false` only for the unused `label`/`section`/`note` kinds. A UI reads it as "may be keybound". |
| `resettable` | boolean | all | Always `true` in the current set. |
| `persist` | boolean | all | Always `true` in the current set. |

### `UI:AttachESP(esp, opts)`

The sibling EasyUI library builds its whole ESP panel from that array (`EasyUiTesting.luau:2018`). The handshake:

1. Asserts only that `esp` is a table with a table `cfg`. Every ESP method it touches afterwards is nil-guarded (`esp.Validate and …`, `if esp.on then`, `o.build ~= false and esp.GetDescriptors`, `esp.save and esp:save(name)`, and so on), so a partial or stubbed ESP object degrades instead of erroring.
2. Detaches any previous `_espLink`.
3. `UI:Mount(prefix, esp.cfg)` (`prefix` defaults to `"esp"`) points the flag namespace at the **live** config table, so widget writes land on `esp.cfg` directly and `esp:import()`/`esp:load()` survive because `import` refills that same table in place rather than replacing it.
4. Registers a validator for the namespace that calls `esp:Validate(path, value)` method-style, so every widget write is coerced by the descriptor rules before it reaches the config.
5. `opts.enabled ~= false` → `esp:on(true)`; `opts.start ~= false` → `esp:start()` (recorded as `link.started`).
6. `opts.build ~= false` → iterates `esp:GetDescriptors()` (no prefix) and, per entry, resolves window → tab → subtab → section, then creates one widget with `text = label or path`, `flag = prefix .. "." .. path`, `default = pathGet(esp.cfg, path)` (the instance's current value, not `d.default`), `min`/`max`/`step`/`decimals`, `options = d.items`, `noKeybind = d.bindable == false`. Kind maps to `Toggle`, `Slider`, `Dropdown` (for `dropdown` and `mode`), `Colorpicker`, `Keybind`; an unmapped kind is skipped silently.
7. Returns a `link` with `sync()`, `SetEnabled(bool)`, `applyTheme(name)`, `applySetup(name)` (calls `esp:preset`), `save(name)`, `load(name)` and `detach()`. `detach` destroys the generated tabs, windows, widgets and flags, unmounts the namespace, clears the validator, and then either `esp:destroy()` (when `opts.own`) or `esp:stop()` (when it started the loop and `opts.stopOnDetach` is set).

Relevant options: `prefix`, `own`, `enabled`, `start`, `stopOnDetach`, `build`, `singleWindow`, `width` (430), `height` (390), `open`.

```lua
local link = UI:AttachESP(esp, { prefix = "esp", singleWindow = true, own = true })
```

Two consequences worth planning around. Because there are no `npc.*` descriptors, the generated panel covers players only — NPC settings need hand-built widgets bound to `esp.cfg.npc.*` paths. And `ESP.new` looks for `getgenv().__EASY_STACK.bridge` to detach a live UI link before destroying the previous instance, but this EasyUI build never publishes itself there, so that mutual-detach path does not fire; re-running a script leaves the old panel bound to a destroyed instance unless you call `link:detach()` yourself.

---

## Typical integration

Condensed from a production consumer: create once, force the fastest profile, widen the ranges, flatten the text, register world-object groups, then drive everything from a per-frame mapping function.

```lua
local ESP = loadstring(game:HttpGet(URL))()
local esp = ESP.new()
esp:profile("high")             -- frameSkip 0, boxStep 1, visStep 1; also written to cfg.npc.perf
esp:on(true):start()

local c = esp.cfg
c.maxRange, c.espRange = 7500, 7500
c.target.on, c.self.fov.on = false, false
c.perf.entityStep, c.perf.npcFrameSkip = 2, 2
c.npc.maxRange, c.npc.espRange = 7500, 7500      -- cfg.npc is a separate tree
c.npc.perf.npcBoxStep, c.npc.perf.cullMax = 3, 160

local function noOutline(t, seen)                -- clear every per-config outline flag
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
        if k == "outline" then t[k] = false elseif type(v) == "table" then noOutline(v, seen) end
    end
end
noOutline(c, {})
esp.pool.noOutline = true                        -- and the global text-outline kill-switch

local specs = {}
local function group(id, folder, labeler, gate, priority)
    specs[id] = esp:addEnt(id, {                 -- addEnt returns the stored table
        get = function() return gate() and folder:GetChildren() or {} end,
        label = labeler, box = true, name = true, dist = true,
        col = Color3.new(1, 1, 1), priority = priority, outline = false, max = 7500,
    })
end
group("loot", workspace.Loot, function(o) return o:GetAttribute("Item") or o.Name end, function() return S.lootView end, 1)
group("cars", workspace.Cars, function(o) return o.Name .. " [" .. tostring(o:GetAttribute("Fuel")) .. "]" end, function() return S.carView end, 3)

esp:setNPCSource(function() return S.walkers and workspace.Walkers:GetChildren() or {} end)
esp:setNPCLabel(function(m) return m:GetAttribute("Kind") or m.Name end)
esp:npc(true)

esp:flag("hold", function(s)
    if s.tool ~= "" then return { "HOLD: " .. s.tool } end
end)

RunService.Heartbeat:Connect(function()          -- one mapping pass; cheap, all plain writes
    c.on         = S.on
    c.box.on     = S.playerBox
    c.box.col    = S.boxColour
    c.npc.box.on = S.walkerBox                   -- NPC keys must be written separately
    specs.loot.col = S.lootColour                -- live spec retune, no re-registration
    esp:setFlagEnabled("hold", S.showHeld)
end)
```

---

## Gotchas

**`cfg.npc` is a deep copy, not a view.** Writing `cfg.box.on` never affects NPCs. Only `theme()`, `pack()` and `profile()` walk both trees; `merge`, `ESP.new(opt)`, `setAccent()` and plain assignment do not. See [Players vs NPCs](#players-vs-npcs).

**`pool.noOutline` is the only global outline switch, and it only affects text.** Setting `esp.pool.noOutline = true` forces `Outline = false` on every `Drawing.Text` the pool creates. Line and rectangle outlines are per-feature `outline` booleans (`box.outline`, `hp.outline`, `target.outline`, `arrow.outline`, `self.cross.outline`, entity `spec.outline`) and are unaffected — clear those individually.

**`perf.npcFrameSkip` gates chams only.** It is read from the **root** `cfg.perf` and only decides whether `_cham` runs for an NPC snapshot this frame. NPC box/name/distance/flag drawing runs every frame regardless; throttling it would strobe. The NPC drawing throttle is `cfg.npc.perf.npcBoxStep`, which gates the box recompute and the visibility raycast.

**`0` means unlimited for ranges, but the two roster paths disagree.** The player path computes `reach = max(maxRange, espRange, radar.range)` after mapping each `<= 0` to infinity, so zeroing one still leaves the others in force. The NPC path (`EasyESP.luau:1743`) makes `reach` infinite if **either** `npc.maxRange` or `npc.espRange` is `<= 0`. Zeroing just one NPC range therefore uncaps the whole NPC roster. The per-draw cutoffs still use `espRange`/`npc.espRange` alone, and `0` there disables the cutoff.

**Entity `max` has no unlimited branch.** `drawOne` compares `dist > (spec.max or cfg.maxRange)` directly, so with `cfg.maxRange = 0` and no `spec.max`, every entity is culled. Set `spec.max` explicitly when you zero the global range.

**NPC snapshots hardcode `ally = false` and `friend = false`.** `cfg.npc.team`, `cfg.npc.friendTint`, and every ally/friend colour branch in the NPC path are permanently inert. NPCs are also skipped by the radar, the player list, the target selector and the threat banner.

**`cleardrawcache` is required but never called.** The load guard errors without it, yet the function appears nowhere else in the file — it is a capability probe only. An executor that exposes `Drawing` and `setrenderproperty` but not `cleardrawcache` is refused for no functional reason.

**`spec.get` and `spec.label` are not `pcall`-wrapped.** Only `spec.draw` is. An error in `get` or `label` propagates out of `tick`, which `start()` catches — it warns once and keeps the loop alive, but the rest of that frame does not draw.

**`addEnt` mutates the table you pass.** It writes `col`, `box`, `name`, `dist` and the normalised `ring` into your table and stores that same reference. Convenient for live retuning; surprising if you reuse one literal for several groups.

**`radar.range` widens the player roster even when the radar is off.** It is part of `reach`, so a large `radar.range` keeps distant players in the snapshot — and in the visibility/box/tool throttles — regardless of `radar.on`.

---

## Changelog

### Current version

- `GetDescriptors`, `GetDescriptorDefaults` and `GetDescriptor` no longer prepend the instance to the path/prefix when called method-style. `esp:GetDescriptors("ui")` now returns `ui.`-prefixed paths instead of garbage.
- `descLookup` no longer resolves `npc.*` paths to the player descriptor of the same tail. `"npc.box.on"` now correctly returns no descriptor, so a UI cannot silently validate NPC writes against player rules.
- `profile()` now reaches `cfg.npc.perf`, and `theme()`/`pack()` propagate to their NPC counterparts wherever one exists.
- The `_target` label no longer errors when the current target is an NPC.
- Entity `outline = false` is honoured; the box backing rectangle is skipped.
- `spec.ring` is normalised through `ringSpec()` at registration, so partial ring tables get proper defaults.
- `radar.ringLabels` has a real default instead of being read as `nil`.
- The duplicate radar circle was removed.
- Entity pool keys are namespaced `ent_*`, which is what makes `pool:carry("ent")` retire the right set on skipped entity frames.
- `characterBox`'s `GetBoundingBox` fallback is size-clamped like the primary path, so a character with no visible parts no longer produces a giant box.
- The friends API no longer throws when handed a non-`Player` instance; unresolvable arguments are ignored.
- `Toolkit.quick` no longer leaks its control keys (`theme`, `profile`, `pack`, `preset`, `on`) into the config seed.
- `clearEnts()` returns a real removed count instead of `0`.
- `nearest()` no longer returns `nil` while a valid player exists in the roster.

### Previous

Flicker work:

- **Draw-skip strobe.** A skipped draw pass left the pool's retire step to hide everything that had not been redrawn, so throttled layers blinked at the skip rate. Skips now bypass the pool bookkeeping (`frameSkip`) or re-mark their keys live (`pool:carry`).
- **Stale and frozen boxes at screen edges.** Cached 2D boxes were reused after their projection had gone invalid, pinning boxes at the last valid edge position.
- **Indexed pool-key collisions.** Keys built from loop indices could collide between features and entities, so two drawings fought over one object.
- **Unthrottled NPC visibility raycasts.** The NPC visibility test ran every frame for every NPC; it is now on the `npcBoxStep` rotation.
- **3D-box corner abort.** A single corner projecting behind the camera aborted the box, dropping the whole overlay for one frame at close range.

No public API, config key, default value or descriptor was removed or renamed in this release. It is a drop-in replacement for the previous build.
