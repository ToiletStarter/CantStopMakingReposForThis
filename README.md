# CantStopMakingReposForThis

Single-file Roblox executor libraries. Built for Potassium and UNC-style executors. Each one loads on its own, and they compose through a shared registry.

| Library | Folder | Purpose |
| --- | --- | --- |
| **EasyStack** | [`easystack/`](easystack/) | Shared registry — one table every library and script writes into, plus a destroy-all helper. |
| **EasyUI** | [`easyui/`](easyui/) | Menu framework — windows, tabs, widgets, context menus, managed runtime, config profiles. |
| **EasyESP** | [`easyesp/`](easyesp/) | Drawing-based ESP engine — boxes, names, health, bones, chams, radar, entity tracking. |
| **EasyWorld** | [`easyworld/`](easyworld/) | World-space 3D visual engine — ground rings, spheres, orbit paths, wireframe boxes, beams, arcs, with occlusion. |
| **EasyAim** | [`easyaim/`](easyaim/) | Adapter-driven aim engine — legit smoothing, rage snapping, silent aim, prediction, triggerbot, FOV. |
| **EasyAntiAim** | [`easyantiaim/`](easyantiaim/) | Anti-aim — angle manipulation, yaw jitter, fake lag, desync, hitbox hiding. |
| **EasyCombat** | [`easycombat/`](easycombat/) | Combat helper on top of EasyAim — magic bullet, bullet TP, gun-system bridging. |
| **EasyCap** | [`easycap/`](easycap/) | Capability probe — detects which executor APIs exist so features can degrade instead of erroring. |

They are independent. Load any on its own, or attach the ESP to the UI with `UI:AttachESP` for an auto-generated settings panel. EasyAim exposes the same descriptor shape, so a UI panel can be generated from `EasyAim.GetDescriptors()`.

## Tags

`roblox` `roblox-ui-library` `roblox-esp-library` `roblox-aimbot-library` `luau` `drawing-api` `roblox-overlay` `roblox-menu` `roblox-gui` `executor-ui` `3d-visuals`

```lua
local BASE    = "https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/"
local Stack   = loadstring(game:HttpGet(BASE .. "easystack/EasyStack.luau"))()
local UI      = loadstring(game:HttpGet(BASE .. "easyui/EasyUiTesting.luau"))()
local EasyESP = loadstring(game:HttpGet(BASE .. "easyesp/EasyESP.luau"))()
local EasyWorld = loadstring(game:HttpGet(BASE .. "easyworld/EasyWorld.luau"))()
local EasyAim = loadstring(game:HttpGet(BASE .. "easyaim/EasyAim.luau"))()
```

---

## Recommended loader

Every published script in this repo uses the same shape: one `loadLib` helper that fails soft, a `getgenv()` slot so re-running unloads the previous instance, and a `Session` table that owns every connection and instance.

```lua
local GENV = (getgenv and getgenv()) or shared or _G
local SLOT = "__MYSCRIPT_INSTANCE"
local BASE = "https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/"

local prev = GENV[SLOT]
if type(prev) == "table" and type(prev.unload) == "function" then
    pcall(prev.unload)
end

local function loadLib(path)
    if type(loadstring) ~= "function" then return nil, "loadstring unavailable" end
    local okHttp, source = pcall(function() return game:HttpGet(BASE .. path) end)
    if not okHttp or type(source) ~= "string" then return nil, "HttpGet failed" end
    local okCompile, chunk = pcall(loadstring, source)
    if not okCompile or type(chunk) ~= "function" then return nil, "compile failed" end
    local okRun, value = pcall(chunk)
    if not okRun then return nil, "module error: " .. tostring(value) end
    return value
end

local Stack = loadLib("easystack/EasyStack.luau")
local UI, uiErr = loadLib("easyui/EasyUiTesting.luau")
if type(UI) ~= "table" then return end
```

Why this order: **EasyStack first** (so every later library can register itself), **EasyUI second** (it owns the runtime scheduler), **everything else after**. `loadLib` returning `nil, reason` instead of erroring means a missing optional library downgrades one feature instead of killing the script.

### Owning your teardown

`M:Schedule` / `M:Every` return a stop function. Keep them, and disconnect everything in one `unload`:

```lua
local Session = { conns = {}, loops = {}, instances = {}, unloaded = false }

local function schedule(name, fn, fps, priority)
    local stop = M:Schedule(name, function(dt)
        if Session.unloaded then return end
        fn(dt)
    end, fps, priority)
    Session.loops[name] = stop
    return stop
end

function Session.unload()
    if Session.unloaded then return end
    Session.unloaded = true
    for _, stop in pairs(Session.loops) do pcall(stop) end
    for _, c in ipairs(Session.conns) do pcall(function() c:Disconnect() end) end
    for _, i in ipairs(Session.instances) do pcall(function() i:Destroy() end) end
    if esp then pcall(function() esp:destroy() end) end
    if Stack then pcall(Stack.destroyAll) end
    pcall(function() M:Close() end)
    GENV[SLOT] = nil
end

GENV[SLOT] = Session
```

The `Session.unloaded` guard inside every scheduled job matters: a job can fire once more after `stop()` on the same frame, and without the guard it touches instances you already destroyed.

---

# EasyStack

Registry that every Easy* library plus the script writes into once. Lets the script ask for active instances by name and lets libraries hook each other without knowing the concrete wiring. No game logic — one shared table and a destroy-all helper.

## Install

```lua
local Stack = loadstring(game:HttpGet(".../easystack/EasyStack.luau"))()
```

## API

```lua
Stack.register(name, instance)   -- store and return instance
Stack.get(name)                  -- retrieve
Stack.each(fn)                   -- pcall fn(name, inst) over everything
Stack.setFeature(key, value)     -- feature flag write
Stack.feature(key)               -- feature flag read
Stack.destroyAll()               -- :destroy() / :Destroy() everything, then clear
```

It publishes itself at `getgenv().__EASYSTACK`, so a second script can find an already-loaded stack instead of re-fetching every library.

```lua
Stack.register("esp", esp)
Stack.setFeature("cap.drawing", true)
local esp = Stack.get("esp")
```

`destroyAll` is the single call that tears down every registered library — put it in your `unload` and you cannot leak an ESP loop.

---

# EasyUI

A single-file Roblox executor UI library — menus, split windows, nested tabs, a full widget set, right-click context menus, a managed script runtime (priority queue, frame scheduler, budgeted batching, lifecycle-managed `Exec`), config profiles, direct EasyESP hosting, media import, HUD modules, a custom cursor, a keybind list, a top-most overlay with a named layer priority system, input tools, and a verbose debug log.

## Install

```lua
local UI = loadstring(game:HttpGet(".../easyui/EasyUiTesting.luau"))()
```

Or run the full example straight away:

```lua
loadstring(game:HttpGet(".../easyui/Example.luau"))()
```

## Documentation

Full, detailed docs — every method, widget, option, and system — are in **[easyui/EasyUi_Documentation.md](easyui/EasyUi_Documentation.md)**.

## Quick start

```lua
local M = UI.new({
	title = "My Menu",
	toggleKey = Enum.KeyCode.RightShift,
	cursor = true,
	keybindHud = true,
})

local combat = M:Tab("Combat")
local aim = combat:SubTab("Aimbot"):Section("Main")

aim:Toggle({
	text = "Enabled",
	flag = "aim.enabled",
	default = true,
	context = function(ctx)                 -- right-click for a mini panel
		ctx:Slider({ text = "FOV", flag = "aim.fov", min = 0, max = 500, default = 120 })
		ctx:Colorpicker({ text = "FOV Color", flag = "aim.color" })
	end,
})
aim:Slider({ text = "Smoothing", flag = "aim.smooth", min = 0, max = 100, default = 40 })
aim:Dropdown({ text = "Hit Part", flag = "aim.part", options = { "Head", "Torso", "Nearest" }, default = "Head" })
aim:Keybind({ text = "Aim Key", flag = "aim.key", default = Enum.KeyCode.E })

M:ConfigTab()   -- ready-made save/load profiles tab
```

## Feature examples

### Split window opened from a button

```lua
local tools = M:Window("Tools", {
	x = 720, y = 140, width = 400, height = 320,
	style = "panel", header = "Tools", open = false, flag = "windows.tools",
})
tools:Tab("Runtime"):Section("Jobs"):Button({ text = "Close", callback = function() tools:Close() end })

M:Tab("Windows"):Section("Split"):Button({ text = "Open Tools", callback = function() tools:Open() end })
```

### Managed runtime (won't freeze the client)

```lua
M:Batch("scan", game:GetService("Players"):GetPlayers(), function(player, index)
	-- heavy per-player work, split across frames
end, { interval = 0.01, budget = 0.002, chunk = 25, done = function()
	M:Notify({ title = "Done", text = "Scan complete.", kind = "ok" })
end })

M:Every("poll", 0.1, function() end, 5)   -- throttled, priority 5
```

### Run a whole script through the UI

```lua
M:Exec("myfeature", function(ctx)
	ctx:Schedule("tick", function() end, 30)
	ctx:Set("feature.enabled", true)
	return function() end   -- teardown
end)
```

### Attached EasyESP

```lua
local EasyESP = loadstring(game:HttpGet(".../easyesp/EasyESP.luau"))()
local link = M:AttachESP(EasyESP.new(), { enabled = true, start = true, build = true, own = true })
```

### Config profiles

```lua
M:SaveConfig("legit")
M:LoadConfig("legit")
M:SetAutoload("legit")
M:LoadAutoload()
```

### Debug log

```lua
local M = UI.new({ debug = true })  -- stream verbose log to rconsole
M:Log("info", "hello")
M:CopyLog()                          -- to clipboard
M:OpenConsole()
```

## Highlights

- **Navigation:** top tab bar with nested subtab strips (`M:Tab():SubTab():Section()`).
- **Widgets:** toggle, button, slider (fluid, dot-on-grab), dropdown, keybind, textbox, colorpicker, badge, label, divider, media, collapsible `Info`, custom widgets.
- **Right-click context menus** on every control for keybinds and per-feature settings.
- **Split windows** that reuse the full tab/widget API; draggable, resizable, with center-snap guides + live x/y readout.
- **Runtime:** `Schedule` / `Every` / `Batch` / `Queue` / `Use` / `Drop` / `Exec`, all owned and auto-cleaned.
- **Configs:** JSON profiles with mounts, keybinds, and a ready-made `ConfigTab`.
- **Overlay:** hardcoded top-most `DisplayOrder` + named layer table (`M:Attach`, `Toolkit.Layer`, `Toolkit.Visuals`).
- **Polish:** Apple-style open/close, frosted top-left light, custom cursor fused to the pointer, keybind HUD with state colors, click-to-dismiss toasts, rich text + custom fonts.
- **Tools:** input hooks (`OnInput` / `OnMouseMove` / `GetMouse`) and a verbose debug log (rconsole + clipboard).

## Limitations

- **YouTube:** only the thumbnail is importable — Roblox can't decode arbitrary downloaded `.mp4`, and YouTube serves expiring split streams. Upload rights-cleared video to Roblox for real playback.
- **`Exec` is a script loader, not a sandbox.** It runs the code you give it with full executor identity and hands it the UI. Run only trusted code; the UI provides clean lifecycle/cleanup, not isolation.

## Security

The library only creates and mutates **its own `ScreenGui`** and reads client-local services (input, tween, camera, marketplace name for the watermark). No remotes, no `workspace` writes, no other-player access. Configs are JSON only (no `loadstring`); filenames are sanitized. See the docs for the full breakdown.

---

# EasyESP

A single-file `Drawing`-based ESP engine — 2D/3D/corner boxes, names, distance, health bars, bones, head dots, flag columns, tracers, off-screen arrows, a draggable radar, a player list, target and threat panels, `Highlight` chams, visibility raycasting, per-target LOD, and arbitrary entity/instance tracking.

Requires `Drawing`, `setrenderproperty` and `cleardrawcache`; it errors on load without them. Probe with EasyCap first if you want a soft failure.

## Install

```lua
local EasyESP = loadstring(game:HttpGet(".../easyesp/EasyESP.luau"))()
```

## Documentation

Full reference — every config key, method, entity spec field and snapshot field — is in **[easyesp/EasyESP_Documentation.md](easyesp/EasyESP_Documentation.md)**.

## Quick start

```lua
local esp = EasyESP.new()
esp:on(true)
esp:start()

esp.cfg.box.on   = true
esp.cfg.name.on  = true
esp.cfg.hp.on    = true
esp.cfg.maxRange = 0        -- 0 = unlimited

esp:destroy()                -- full teardown
```

## NPCs and entities

NPCs come from a source callback you supply. `cfg.npc` is an **independent deep copy** of the player config, so writing a root key does not affect NPCs.

```lua
esp:setNPCSource(function()
	return workspace.AI.Walkers:GetChildren()
end)
esp:npc(true)
esp.cfg.npc.box.on = true
```

Anything else — loot, vehicles, corpses — goes through `addEnt`:

```lua
esp:addEnt("loot", {
	get     = function() return workspace.Lootables:GetChildren() end,
	label   = "Loot",
	box     = true,
	name    = true,
	dist    = true,
	col     = Color3.fromRGB(255, 230, 80),
	outline = false,
})
```

## Custom flags

Flags add text rows beside a target. The callback receives the target snapshot and returns `{ text, color }`.

```lua
esp:flag("holding", function(s)
	if s.tool and s.tool ~= "" then
		return { "HOLD: " .. s.tool, Color3.new(1, 1, 1) }
	end
	return nil
end)
esp:setFlagEnabled("holding", true)
```

Return a **table or nothing** — a bare string or `true` makes the engine index `out[1]` outside its `pcall` and aborts the frame. Always guard `s.char` before reading it; NPC snapshots have no `plr`.

## Highlights

- **Targets:** players, callback-sourced NPCs, and unlimited `addEnt` entity groups, each with its own config tree.
- **Drawing pool:** every visual is a reused, key-addressed `Drawing` with shadow-property diffing, idle pruning, and a `zbias` priority band system.
- **Performance:** `perf.mode = "auto"` rescales box/visibility cadence from measured FPS; per-target work is staggered by uid so cost spreads across frames.
- **UI bridge:** 65 self-describing descriptors let `UI:AttachESP` build a complete settings panel with validation, no glue code.
- **Presets:** themes, performance profiles, feature packs and combined presets, all applied by name.

## Gotchas

- `cfg.npc` is a separate copy — set npc keys explicitly.
- `esp.pool.noOutline = true` is the only global outline kill-switch.
- `maxRange` / `espRange` treat `0` as unlimited, not "hide everything".
- `perf.npcFrameSkip` throttles chams only; target drawing is per-frame by design, because skipping a draw pass makes the pool retire the visuals and strobe.
- `get` and `label` on an entity spec are **not** `pcall`-wrapped. An error in either kills the whole frame's drawing.

---

# EasyWorld

A world-space visual engine. Where EasyESP draws 2D overlays anchored to entities on screen, EasyWorld draws geometry that lives **in the world** — rings that lie flat on the ground, spheres that wrap a target, orbit paths showing where a player will move, wireframe boxes previewing a block placement. Everything is projected through the camera each frame, so it has real perspective, real occlusion, and real depth.

Requires `Drawing`; it errors on load without it. `setrenderproperty` is used when available.

## Install

```lua
local EasyWorld = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyworld/EasyWorld.luau"))()
```

## Documentation

Full reference — every shape, every spec field, performance guidance — is in **[easyworld/EasyWorld_Documentation.md](easyworld/EasyWorld_Documentation.md)**.

## Quick start

```lua
local world = EasyWorld.new()
world:start()

world:ring("range", {
    get   = function() return workspace.SomePlayer.HumanoidRootPart.Position - Vector3.new(0, 3, 0) end,
    rad   = 14.4,
    col   = Color3.fromRGB(255, 70, 70),
    sides = 64,
    ticks = 12,
})

world:destroy()
```

## Shapes

`ring`, `disc`, `sphere`, `cylinder`, `box`, `orbit`, `arc`, `beam`, `path`, `marker`, `text` — each with a convenience constructor (`world:ring(id, spec)`, `world:sphere(id, spec)`, …).

```lua
world:sphere("bubble", { get = function() return target end, rad = 3.5, pulse = true, core = true })
world:box("preview",   { get = function() return nextBlockPos end, size = Vector3.new(3,3,3), fill = true })
world:orbit("strafe",  { get = function() return target end, angle = function() return theta end, lanes = 3 })
world:path("arc",      { points = function() return solveTrajectory() end, head = true })
```

## Highlights

- **Real 3D orientation** — `tilt` / `yaw` in degrees, or supply a `normal` vector. A ring can lie flat, stand upright, or lean.
- **Occlusion** — `occlude = true` raycasts along the shape and dims the segments hidden behind geometry.
- **Motion** — `spin`, `pulse`, `wiggle` (sine or Perlin noise), animated dashes, multi-lane rings with phase offsets, comet trails on orbits.
- **Depth-aware styling** — lines thicken up close and fade with distance automatically.
- **Diffing pool** — every primitive is reused and keyed; a property is only written when it actually changed. Idle drawings are pruned.
- **Frame budget** — `cfg.maxSegs` caps per-frame segment count; shapes are drawn in `priority` order so the important ones survive.
- **Presets** — `clean`, `neon`, `pulse`, `ghost`, `heavy`, applied per shape or globally.

## Gotchas

- `glow` multiplies segment count: `glowLayers = 2` draws every line 3 times. It is the first thing to turn off for performance.
- A `get` that returns `nil` draws nothing, silently. That is the intended way to hide a shape when there is no target.
- A shape whose draw call errors is **disabled permanently** with a warning naming its id; it does not retry.
- `maxDist = 0` and `fadeDist = 0` mean unlimited, not zero.
- `tilt`/`yaw`/`arc.from`/`arc.to` are **degrees**; `orbit.angle` is **radians**.
- `labelOffset` positions the optional `label` on any shape; the `text` shape uses `textOffset`.

---

# EasyAim

An adapter-driven aim library. Target selection, hitbox resolution, prediction, legit smoothing, rage snapping, silent-aim resolution, a triggerbot and an FOV circle. Game-specific details live in a small adapter table, so a new game is a handful of functions rather than a rewrite.

## Install

```lua
local EasyAim = loadstring(game:HttpGet(".../easyaim/EasyAim.luau"))()
```

## Quick start

```lua
local aim = EasyAim.new({
    mode = "legit",
    key = Enum.UserInputType.MouseButton2,
    hitbox = { kind = "Head" },
    fov = { on = true, radius = 140 },
})
aim:on(true)
aim:start()
```

## Adapters

An adapter tells EasyAim how to read a game. `setAdapter` merges over the default, so you only override what differs.

```lua
aim:setAdapter({
    targets = function() return workspace.Entities:GetChildren() end,
    root    = function(m) return m:FindFirstChild("Root") end,
    health  = function(m) return m:GetAttribute("HP") or 0, 100 end,
})
```

Built-in adapters: `Default` (Players / Humanoid / Team) and `Attribute` (Health / MaxHealth / Dead / SquadName attributes).

## Silent aim

`silent` mode computes the point and leaves delivery to you:

```lua
local pos = aim:aimPosition()
```

## Documentation

Full reference: [`easyaim/EasyAim_Documentation.md`](easyaim/EasyAim_Documentation.md)

---

# EasyAntiAim

Anti-aim for games where other clients resolve your position. Angle manipulation, yaw jitter, fake lag, desync and hitbox hiding, all driven from a `localRig` callback so it works with custom character rigs, not just `Players.LocalPlayer.Character`.

## Install

```lua
local AntiAim = loadstring(game:HttpGet(".../easyantiaim/EasyAntiAim.luau"))()
```

## Quick start

```lua
local aa = AntiAim.new({
    localRig = function() return myRigModel end,
    mode = "angle",       -- angle manipulation
    pitch = 0,
    yaw = 180,            -- face away
    yawJitter = 20,       -- +/- degrees of jitter
    fakeLag = true,
    fakeLagTicks = 4,
    desyncOn = true,
    desyncSpeed = 8,
    hideHitbox = false,
})
aa:on(true)
```

| Option | Meaning |
| --- | --- |
| `localRig` | Callback returning your character model. Required for anything to apply. |
| `mode` | `"angle"` and related manipulation modes. |
| `pitch` / `yaw` | Base angles applied to the rig. |
| `yawJitter` | Random yaw spread, in degrees, per tick. |
| `fakeLag` / `fakeLagTicks` | Withhold replication for N ticks to break interpolation. |
| `desyncOn` / `desyncSpeed` | Split visual and real position. |
| `fakeAngleOn` / `fakeAngleYaw` | Static fake angle overlay. |
| `hideHitbox` | Move the resolvable hitbox off the visible model. |

Anti-aim only matters where other clients (or a client-authoritative server) resolve hits from your replicated rig. In a server-authoritative hitscan game it does nothing.

---

# EasyCombat

A combat layer on top of EasyAim. It fetches EasyAim itself on load, so you only need this one URL when you want both. Adds magic bullet, bullet teleport, and a bridge into a game's own gun system/remote.

## Install

```lua
local EasyCombat = loadstring(game:HttpGet(".../easycombat/EasyCombat.luau"))()
```

## Quick start

```lua
local combat = EasyCombat.new({
    team = "players",
    gunSystem = someGunModule,
    gunEvent = ReplicatedStorage.Remotes.Fire,
    rigSource = function() return workspace.Entities:GetChildren() end,
    rigHealth = function(rig) return rig:GetAttribute("HP") or 0, 100 end,
    localRig = function() return myRig end,
    notify = function(msg) print(msg) end,
})

combat.magicBullet = true
combat.bulletTp = true
```

| Option | Meaning |
| --- | --- |
| `adapter` | Passed through to the underlying EasyAim instance. |
| `team` | Target category. |
| `gunSystem` / `gunEvent` | The game's weapon module and fire remote to bridge into. |
| `rigSource` | Callback returning candidate target rigs. |
| `rigHealth` | Callback returning `health, maxHealth` for a rig. |
| `localRig` | Callback returning your own rig. |
| `notify` | Message sink; defaults to a no-op. |

`magicBullet` and `bulletTp` are the two toggles most games only need — both operate on the fire call, so they require `gunEvent` (or `gunSystem`) to be wired.

---

# EasyCap

A capability probe. Tests which executor APIs actually exist and records what is missing, so a script can disable one feature with a message instead of erroring on load.

## Install

```lua
local Cap = loadstring(game:HttpGet(".../easycap/EasyCap.luau"))()
```

## Usage

```lua
if Cap._ok["drawing"] then
    -- safe to load EasyESP
end

for name, reason in pairs(Cap._missing) do
    warn("missing: " .. name .. " (" .. reason .. ")")
end
```

| Field | Meaning |
| --- | --- |
| `Cap._ok[name]` | `true` / `false` per probed capability. |
| `Cap._features[name]` | The resolved value when the probe succeeded. |
| `Cap._missing[name]` | Failure reason when the probe failed. |

Probe before you load: EasyESP hard-errors without `Drawing`, `setrenderproperty` and `cleardrawcache`. Checking with EasyCap first turns a dead script into a disabled ESP tab.

---

## Building a game script with the stack

The pattern used across published scripts:

1. **Probe** with EasyCap so missing APIs downgrade a feature instead of killing the load.
2. **Load** EasyStack, then EasyUI, then the rest via a soft-failing `loadLib`.
3. **Register** each library into EasyStack so `unload` can find them all.
4. **Wire ESP sources** — `setNPCSource` for AI, `addEnt` for loot/objectives, `flag` for per-target text.
5. **Add world visuals** with EasyWorld for anything that belongs in 3D space — range rings, target bubbles, placement previews — rather than faking depth with 2D drawings.
6. **Drive every loop** through `M:Schedule` / `M:Every` (never a bare `RunService` connection) so the UI owns cleanup.
7. **Attach the ESP panel** with `M:AttachESP(esp, { build = true, singleWindow = true })` instead of hand-building controls.
8. **Expose `Session.unload`** and stash it in `getgenv()` so re-running the script cleanly replaces the old instance.

```lua
esp:setNPCSource(function() return collectEnemies() end)
esp:addEnt("pickups", { get = collectPickups, col = Color3.fromRGB(120, 255, 190) })
esp:flag("state", function(s)
    local st = s.char and s.char:GetAttribute("_State")
    if st then return { tostring(st), Color3.fromRGB(200, 200, 200) } end
    return nil
end)

local link = M:AttachESP(esp, { build = true, enabled = true, start = true, own = true, singleWindow = true })
```

Two rules worth repeating, because both produce bugs that only show up in a live game:

- **Guard every scheduled job against a dead character.** `LocalPlayer.Character` goes `nil` on respawn; a job that assumes a root part will spam errors for the whole death animation. Re-resolve the character on `CharacterAdded` and bail early when it is missing.
- **Restore what you mutate.** Noclip sets `CanCollide = false` on every part; if `unload` does not set it back, the player keeps falling through the map after the script is gone.
