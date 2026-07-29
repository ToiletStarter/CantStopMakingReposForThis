# CantStopMakingReposForThis

Two single-file Roblox executor libraries. Built for Potassium and UNC-style executors; EasyUI degrades where optional APIs are missing, while EasyESP requires its Drawing APIs.

| Library | Folder | Purpose |
| --- | --- | --- |
| **EasyUI** | [`easyui/`](easyui/) | Menu framework — windows, tabs, widgets, context menus, managed runtime, config profiles. |
| **EasyESP** | [`easyesp/`](easyesp/) | Drawing-based ESP engine — boxes, names, health, bones, chams, radar, entity tracking. |

They are independent. Load either on its own, or attach the ESP to the UI with `UI:AttachESP` for an auto-generated settings panel.

## Tags

`roblox` `roblox-ui-library` `roblox-esp-library` `luau` `drawing-api` `roblox-overlay` `roblox-menu` `roblox-gui` `executor-ui`

```lua
local UI      = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyui/EasyUiTesting.luau"))()
local EasyESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyesp/EasyESP.luau"))()
```

---

# EasyUI

A single-file Roblox executor UI library — menus, split windows, nested tabs, a full widget set, right-click context menus, a managed script runtime (priority queue, frame scheduler, budgeted batching, lifecycle-managed `Exec`), config profiles, direct EasyESP hosting, media import, HUD modules, a custom cursor, a keybind list, a top-most overlay with a named layer priority system, input tools, and a verbose debug log.

## Install

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyui/EasyUiTesting.luau"))()
```

Or run the full example straight away:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyui/Example.luau"))()
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
local EasyESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyesp/EasyESP.luau"))()
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

Requires `Drawing`, `setrenderproperty` and `cleardrawcache`; it errors on load without them.

## Install

```lua
local EasyESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyesp/EasyESP.luau"))()
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
end)
esp:setFlagEnabled("holding", true)
```

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
