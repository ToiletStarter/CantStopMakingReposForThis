# EasyUI

A single-file Roblox executor UI library — menus, split windows, nested tabs, a full widget set, right-click context menus, a managed script runtime (priority queue, frame scheduler, budgeted batching, sandboxed-lifecycle `Exec`), config profiles, direct EasyESP hosting, media import, HUD modules, a custom cursor, a keybind list, a top-most overlay with a named layer priority system, input tools, and a verbose debug log.

Built for Potassium and UNC-style executors; degrades gracefully where APIs are missing.

## Install

Load the library:

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/EasyUiTesting.luau"))()
```

Or run the full example straight away:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/Example.luau"))()
```

## Documentation

Full, detailed docs — every method, widget, option, and system — are in **[EasyUi_Documentation.md](EasyUi_Documentation.md)**.

## Quick start

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/EasyUiTesting.luau"))()

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

### Direct EasyESP (no bridge)

```lua
local EasyESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/hold/refs/heads/main/esp"))()
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
