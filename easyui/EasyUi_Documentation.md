# EasyUI Documentation

A single-file Roblox executor UI library: menus, split windows, nested tabs, a full widget set, right-click context menus, a managed runtime (priority queue, frame scheduler, budgeted batching, managed script execution), config profiles, direct EasyESP hosting, media import, HUD modules, a custom cursor, a keybind list, and a hardcoded top-most overlay with a named layer priority system.

- Library: `EasyUiTesting.luau`
- Example: `Example.luau`
- Loads under Potassium and UNC-style executors; degrades gracefully where APIs are missing.

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/EasyUiTesting.luau"))()

local M = UI.new({
	title = "My Menu",
	toggleKey = Enum.KeyCode.RightShift,
	cursor = true,
	keybindHud = true,
})
```

---

## Table of contents

1. [Creating the UI](#creating-the-ui)
2. [Core methods](#core-methods)
3. [Navigation — tabs and subtabs](#navigation)
4. [Sections](#sections)
5. [Widgets](#widgets)
6. [Right-click context menus](#right-click-context-menus)
7. [Split windows](#split-windows)
8. [State — mounts, Get/Set/Sync, flags](#state)
9. [Config profiles](#config-profiles)
10. [Runtime — Schedule, Every, Batch, Queue](#runtime)
11. [Features — Use, Drop, Exec, HUD](#features)
12. [Direct EasyESP hosting](#direct-easyesp-hosting)
13. [Notifications](#notifications)
14. [Custom cursor](#custom-cursor)
15. [Keybind HUD](#keybind-hud)
16. [Media import](#media-import)
17. [Overlay layers & priority](#overlay-layers)
18. [Toolkit & extensibility](#toolkit)
19. [Window behavior — drag, resize, top-most](#window-behavior)
20. [Theme](#theme)
21. [Full API reference](#api-reference)
22. [Changelog](#changelog)

---

## Creating the UI

```lua
local M = UI.new({
	title = "My Menu",            -- title bar text and watermark name (default "EasyUI")
	toggleKey = Enum.KeyCode.RightShift, -- key that shows/hides the menu; pass false to disable
	width = 560, height = 420,    -- initial window size in pixels
	accent = Color3.fromRGB(...), -- initial accent color (optional)
	watermark = true,             -- draggable fps/game pill (default true)
	cursor = true,                -- custom cursor; or a table of cursor options
	keybindHud = true,            -- keybind list; or a table of options
	loader = true,                -- animated loader before reveal (set false to skip)
	loadTime = 2.6,               -- loader duration in seconds (throttled to show the full animation)
	debug = false,                -- start the verbose debug log streaming to rconsole
	resizable = true,             -- bottom-right resize grip (default true)
	minWidth = 420, maxWidth = 960,
	minHeight = 300, maxHeight = 720,
})
```

Creating a new instance automatically closes the previous one (tracked in `getgenv().__EASYUI_ACTIVE`), so re-running your script never stacks menus.

---

## Core methods

```lua
M:SetVisible(true)   -- show/hide the menu (no-op if already in that state)
M:Toggle()           -- not a method; use SetVisible(not M.visible)
M:Close()            -- tween out, destroy the GUI, clean up all connections/features
M:SetAccent(Color3)  -- recolor accent-driven elements (toggles, sliders, tabs, cursor, ESP box, etc.)
M:GameInfo()         -- { placeId, gameId, jobId, name, creator, players, maxPlayers, description }
M:Notify({ ... })    -- toast (see Notifications)
```

`M.visible` is a readable boolean. `M.gui` is the protected `ScreenGui`. `M.window` is the main window frame.

---

## Navigation

Top-level tabs render as a horizontal bar under the title bar. Subtabs render as a smaller strip inside their parent tab's page and are only visible while that parent is active. `Tab` and `SubTab` are aliases on any navigation node, so you can nest to any depth.

```lua
local visuals = M:Tab("Visuals")
local players = visuals:SubTab("Players")
local enemies = players:SubTab("Enemies")
local section = enemies:Section("Boxes")
```

Reading it like a path: `M:Tab("Visuals"):SubTab("Players"):SubTab("Enemies"):Section("Boxes")`.

Node methods:

```lua
local tab = M:Tab("Combat")
tab:SubTab("Aim")     -- nested tab (alias: tab:Tab("Aim"))
tab:Section("Main")   -- a section card inside this tab's page
tab:Open()            -- activate this tab (and every ancestor / owning window)
tab:Destroy()         -- remove this tab and all its subtabs, prune their widgets
```

> **Rule:** a tab holds *either* direct sections *or* subtabs. Once a tab gains a subtab, its own direct sections are hidden. Put sections on leaf tabs.

---

## Sections

A section is a titled card that stacks widgets vertically and auto-sizes.

```lua
local sec = tab:Section("Aimbot")   -- title optional: tab:Section()
```

All widget methods below are called on a section.

---

## Widgets

Every widget takes an options table. Common option keys:

- `text` — label shown next to the control.
- `flag` — a dotted path this control reads/writes (see [State](#state)); enables config persistence.
- `default` — initial value if no stored/flag value exists.
- `callback` — `function(value)` fired on change (never on construction).
- `context` — `function(section, widget)` builds a right-click mini-panel (see [context menus](#right-click-context-menus)).
- `noKeybind = true` — disable the right-click "assign keybind" row for this control.
- `bindMode = "toggle" | "hold"` — default activation mode for its right-click keybind. Invalid values become `"toggle"`.
- `hudColor` — `Color3` or `function(active) -> Color3` for the keybind HUD row color.

### Label

```lua
sec:Label("Status: ready", Color3?)   -- returns the TextLabel (mutate .Text freely)
```

### Divider

```lua
sec:Divider()   -- thin horizontal rule
```

### Badge

```lua
local badge = sec:Badge("Ready", "ok")   -- kinds: "ok" | "warn" | "error" | "info"
badge:Set("Broken", "error")             -- update text + dot color
```

### Toggle

```lua
local t = sec:Toggle({
	text = "Enabled",
	flag = "aim.enabled",
	default = true,
	callback = function(state) end,
	context = function(ctx) ... end,   -- optional mini-panel
})
t:Get()        -- boolean
t:Set(true)    -- no-op if unchanged (won't re-fire callback)
```

Right-click a toggle to assign an activation keybind or open its context panel.

### Button

```lua
sec:Button({ text = "Run", callback = function() end })
-- returns { SetText = function(_, newText) end }
```

Buttons have hover, press-scale, and ripple feedback. Right-click to bind a key that fires it.

### Slider

```lua
local s = sec:Slider({
	text = "FOV",
	flag = "aim.fov",
	min = 0, max = 500, step = 1,
	decimals = 0,          -- display/stored precision
	default = 120,
	callback = function(value) end,
})
s:Get(); s:Set(200)
```

Steps are anchored at `min`. The stored value is rounded to `decimals`. Dragging fires the callback only when the stepped value actually changes.

### Dropdown

```lua
local d = sec:Dropdown({
	text = "Mode",
	flag = "aim.mode",
	options = { "Silent", "Assist", "Lock" },
	default = "Silent",
	callback = function(value) end,
})
d:Get(); d:Set("Lock")
d:SetItems({ "A", "B" })   -- resets value if the current one is gone
```

Right-click activation cycles to the next option. The open option list is capped in height and scrolls once the items overflow, so long lists don't run past the window.

### Keybind

A dedicated keybind widget (does not itself get a right-click keybind).

```lua
local k = sec:Keybind({
	text = "Aim Key",
	flag = "aim.key",
	default = Enum.KeyCode.E,
	callback = function(key) end,    -- fired when the bound key is pressed
	onChange = function(key) end,    -- fired when the binding changes
})
k:Get()            -- EnumItem or nil
k:Set(Enum.KeyCode.F)
```

Click the button, then press a key (Escape clears, clicking away cancels).

### Textbox

```lua
local box = sec:Textbox({
	text = "Name",              -- optional left label
	flag = "player.name",
	placeholder = "type...",
	default = "",
	callback = function(text) end,  -- on Enter
})
box:Get(); box:Set("hello")
```

### Colorpicker

Saturation/value square, vertical hue bar, marker cursors, and a hex input.

```lua
local cp = sec:Colorpicker({
	text = "Color",
	flag = "esp.color",
	default = Color3.fromRGB(120, 200, 255),
	callback = function(color) end,
})
cp:Get()            -- Color3
cp:Set(Color3.new(1, 0, 0))
cp:GetHex(); cp:SetHex("#78C8FF")
```

The popup renders above context menus and closes on outside click.

### Media

See [Media import](#media-import).

```lua
sec:Media("https://example.com/image.png", { height = 160 })
```

### Custom widgets

```lua
UI.RegisterWidget("vector", function(section, options, toolkit)
	-- build and return your control table
end)

sec:Widget("vector", { text = "Offset" })
```

---

## Right-click context menus

Right-clicking any actionable control (toggle, button, slider, dropdown, textbox, colorpicker) opens a Neverlose-style mini-panel. By default it contains an **assign keybind** row and a **Mode** row that switches between `Toggle` and `Hold`. Add your own controls with the `context` option — this is the place for extra per-feature settings you didn't want to give dedicated rows:

```lua
sec:Toggle({
	text = "ESP",
	flag = "esp.on",
	context = function(ctx, widget)
		ctx:Slider({ text = "Range", flag = "esp.range", min = 0, max = 5000 })
		ctx:Colorpicker({ text = "Color", flag = "esp.color" })
		ctx:Dropdown({ text = "Mode", options = { "Box", "Corner" } })
	end,
})
```

Context controls that share a `flag` with a main widget stay in sync — editing one updates the other. Pass `noKeybind = true` on a control to remove the keybind row. Context values persist through configs even before the panel is first opened, as long as you pre-declare them (`M:Set("esp.range", 500)`).

`Toggle` mode runs the control's normal activation once per key press. On a toggle widget, `Hold` forces the state on while the key is down and restores the state that existed before the press when released. Non-stateful controls run once on key down in either mode and are never fired a second time on release. The mode is initialized when the widget is built, so `bindMode = "hold"` works before the context menu has ever opened.

---

## Split windows

Detached, draggable, resizable windows that reuse the exact same tab/section/widget API. Open them from a button.

```lua
local tools = M:Window("Tools", {
	x = 720, y = 140,
	width = 400, height = 320,
	style = "panel",         -- "window" | "panel" | "card" (theme background)
	header = "Runtime Tools",-- string, table { text = ... }, or false for an untitled drag strip
	open = false,            -- start hidden
	flag = "windows.tools",  -- persist position/size/open state in configs
	close = true,            -- show a close button
	animation = true,
	resizable = true,        -- default true
	minWidth = 320, maxWidth = 960,
	minHeight = 240, maxHeight = 720,
})

local sec = tools:Tab("Runtime"):Section("Jobs")
sec:Button({ text = "Close", callback = function() tools:Close() end })

M:Tab("Windows"):Section("Split"):Button({
	text = "Open Tools",
	callback = function() tools:Open() end,
})
```

Window methods: `Open`, `Close`, `SetVisible(v)`, `GetVisible`, `GetFrame`, `GetState`, `Set(state)`, `Destroy`, plus `Tab`/`SubTab`. Window lookups on the UI: `M:GetWindow(id)`, `M:OpenWindow(id)`, `M:CloseWindow(id)`.

Split windows hide with the main menu and reappear only if they were open. Resize them with the bottom-right grip; flagged windows save the resulting size. `M:Window(id)` called again returns the existing window (options ignored).

---

## State

Flags are the value bus. Each stateful widget with a `flag` reads its initial value from state and writes changes back.

```lua
M:Set("aim.fov", 200)      -- routes through the widget's Set if one owns the flag
M:Get("aim.fov")           -- reads current value
```

### Mounts

Mount an external table under a prefix; dotted flags then read/write straight into it. This is how ESP config is hosted with zero copying.

```lua
M:Mount("esp", esp.cfg)
M:Set("esp.box.on", true)  -- writes esp.cfg.box.on = true
M:Get("esp.box.on")
M:Unmount("esp")
M:Sync("esp")              -- push mounted values back into every esp.* widget
```

Numeric keys survive JSON round-trips (`esp.list.1.x` resolves `[1]`).

---

## Config profiles

Save/load the whole flag + mount + keybind + keybind-mode + accent state as JSON. Both `toggle` and `hold` are written explicitly so importing a toggle profile reliably replaces a currently-held mode. Requires executor filesystem APIs (`writefile`/`readfile`/...); degrades to no-op where missing.

```lua
M:ExportConfig()          -- returns JSON string  (alias M:CFG())
M:ImportConfig(json)      -- returns bool         (alias M:ICFG(json))
M:SaveConfig("legit")     -- write EasyUI/legit.json (alias M:SCFG)
M:LoadConfig("legit")     -- read + import         (alias M:LCFG)
M:DeleteConfig("legit")
M:ListConfigs()           -- { "legit", "rage", ... }
M:SetAutoload("legit")    -- remember a profile
M:LoadAutoload()          -- load the remembered profile (call after building your UI)
```

### ConfigTab

A ready-made profiles tab: a **Current** line, a **Name** box for new profiles, a scrollable clickable list of saved configs, and Save / Load / Delete / Set Autoload buttons.

```lua
M:ConfigTab()             -- adds a "Configs" tab
M:ConfigTab({ title = "Profiles", section = "Saved" })
```

Click a saved profile to select it (shown as *Current*); type a name to save a new one; the list refreshes on every action.

---

## Runtime

A managed backend so scripts run *through* the UI get optimization and cleanup for free. Everything is owned by the UI and dies with it (or with the owning feature).

### Schedule / Every

```lua
local stop = M:Schedule("name", function(dt) end, fps?, priority?)
local stop = M:Every("name", interval, function(dt) end, priority?)
stop()   -- cancel
```

One shared `RenderStepped` connection drives all jobs, sorted by priority (higher runs first). `fps`/`interval` throttle a job; omit for every frame. A job that errors is dropped, not fatal. `interval` can be as low as `0.01`, but nothing runs faster than the client's real frame rate.

### Batch — split heavy work across frames

```lua
local job = M:Batch("name", items, function(item, index, handle) end, {
	interval = 0.01,   -- how often to resume
	budget = 0.002,    -- max seconds of work per resume
	chunk = 100,       -- max items per resume
	priority = 0,
	done = function(handle) end,
})
job:Pause(); job:Resume(); job:Cancel()
-- job.processed / job.total
```

Processes items until the time budget or chunk cap is hit, then continues next frame. Use it to keep a 10k-item loop from freezing the client.

### Queue — serial priority dispatch

```lua
local cancel = M:Queue("name", priority, function() end)
```

Jobs run one at a time, highest priority first, FIFO within a priority. Re-queuing the same name replaces the pending job (coalescing). Cancellation stops a job even mid-run.

---

## Features

`Use` registers an owned feature with automatic cleanup. The builder receives `own`, which tags any connection / instance / function / handle for disposal on `Drop`.

```lua
M:Use("spinner", function(ui, folder, own)
	own(ui:Every("spin", 0.03, function() ... end))
	own(SomeConnection)
	return {
		SetEnabled = function(self, on) end,   -- or Enable / Start+Stop
		Destroy = function(self) end,
	}
end)

M:Drop("spinner")               -- stop + dispose everything owned
M:GetFeature("spinner")
M:SetFeatureEnabled("spinner", false)   -- also via flag "features.spinner.enabled"
```

Every feature auto-registers the flag `features.<name>.enabled`, so enabling/disabling persists in configs.

### Exec — run a whole script through the UI

```lua
local handle = M:Exec("myscript", source, { priority = 0 })
-- source: a function(ctx), a ModuleScript, a code string, or an https URL
handle:Cancel()      -- dequeue if pending, drop if running
-- handle.status: "queued" | "running" | "loaded" | "failed" | "cancelled"
-- handle.value: the loaded script's return value on success, nil otherwise
-- handle.error: set only when status == "failed"; nil on success
```

The script receives a constrained context so it plugs into the UI's optimizations without touching internals:

```lua
return function(ctx)
	ctx:Set("feat.on", true)
	ctx:Schedule("tick", function() end, 30)
	ctx:Every("poll", 0.1, function() end)
	ctx:Batch("scan", players, worker, opts)
	ctx:Window("panel", { ... })
	ctx:Notify({ title = "Hi", text = "..." })
	return function() end   -- optional teardown
end
```

`M:ImportFeature(name, source, opts)` and `M:ImportHUD(name, source, opts)` are thin wrappers over `Exec`.

### HUD modules

Register reusable HUD builders and drop them in by name.

```lua
UI.RegisterHUD("Compass", function(ui, options, folder, own)
	local frame = own(...)
	return { SetEnabled = function(_, on) end }
end)

M:HUD("Compass", { width = 260 })   -- built-in; draggable, follows hud drag rules
```

---

## Direct EasyESP hosting

`AttachESP` mounts `esp.cfg`, validates writes with the descriptor system, builds the controls from ESP descriptors, and starts ESP. Its link is registered with EasyESP so recreating either side detaches generated controls before the old instance is destroyed.

```lua
local EasyESP = loadstring(game:HttpGet(".../esp"))()
local esp = EasyESP.new()

local link = M:AttachESP(esp, {
	prefix = "esp",       -- flag namespace (default "esp")
	build = true,         -- generate controls from descriptors
	enabled = true,       -- esp:on(true)
	start = true,         -- esp:start()
	own = true,           -- destroy the ESP when detaching / UI closes
	singleWindow = false, -- false: each descriptor window becomes a split window
	                      -- true: everything as tabs in the main window
})

link:SetEnabled(false)
link:applyTheme("carbon")
link:applySetup("legit")
link:save("cfg"); link:load("cfg")
link:sync()
link:detach()
```

By default each ESP descriptor `window` (Combat, Visuals, Radar, World, Self) opens as its own split window. Set `singleWindow = true` to fold them into the main window as tabs.

---

## Notifications

```lua
local n = M:Notify({
	title = "EasyUI",
	text = "Saved profile.",
	kind = "ok",        -- "ok" | "warn" | "error" | "info"
	duration = 4,       -- seconds
})
n.Dismiss()            -- close early
```

Toasts stack bottom-right, size to their text, slide in, and fade out fully (text, stroke, and background) — no abrupt pop.

---

## Custom cursor

```lua
M:SetCursor(true, {
	color = Color3.fromRGB(...),  -- optional; otherwise follows accent
	size = 14,
	always = false,               -- keep visible when the menu is hidden
})
M:SetCursor(false)               -- restore the native cursor
```

Uses Potassium `DrawingImmediate` when available, otherwise a GUI cursor. The native `MouseIcon` state is saved and restored. Enable at construction with `cursor = true` (or a table of the options above).

---

## Keybind HUD

A draggable list of active keybinds. Rows are **green while the bound control is active, grey while inactive**.

```lua
M:SetKeybindHUD(true, {
	title = "Keybinds",
	position = UDim2.fromOffset(16, 54),
})
M:SetKeybindHUD(false)
```

Override a row's color per control:

```lua
sec:Toggle({
	text = "Fly",
	hudColor = function(active)
		return active and Color3.fromRGB(150, 200, 255) or Color3.fromRGB(120, 120, 130)
	end,
})
```

`hudColor` accepts a `Color3` or a `function(active)`.

---

## Media import

Download and display web media. PNG/JPG and MP3 are the reliable Potassium paths; GIF and MP4/MOV are probed through `getcustomasset` (decoder support varies). YouTube watch/share URLs resolve to the video *thumbnail* (the video stream is not downloadable).

```lua
local media = M:ImportMedia("https://example.com/image.png", {
	height = 160,       -- for section display
	button = false,     -- ImageButton instead of ImageLabel
	volume = 1,         -- for audio
	looped = false,     -- for video
	name = "logo",      -- cache filename (defaults to a content hash)
	maxBytes = 20*1024*1024,
})
-- media.object (Instance), media.asset (content id), media.type, media:Destroy()

sec:Media("https://youtube.com/watch?v=VIDEO_ID")   -- section helper (thumbnail)
```

Downloads are content-sniffed (magic bytes preferred over URL extension), HTML error pages are rejected, and files are cached by a content hash.

```lua
UI.RegisterMedia("webp", function(ui, url, options) ... end)  -- custom handler by extension
```

---

## Overlay layers

The UI's `ScreenGui` is forced **top-most** with a hardcoded max `DisplayOrder`, so nothing from other scripts or the game can render over it. Internally, a named layer table sets consistent `ZIndex` values so elements never overlap by accident:

| Layer | ZIndex | Used by |
|---|---|---|
| `window` | 1 | main window, split windows |
| `hud` | 15 | watermark, keybind HUD, compass |
| `toast` | 30 | notifications |
| `context` | 60 | right-click menu |
| `picker` | 70 | color popup |
| `loader` | 100 | startup loader |
| `cursor` | 1000 | custom cursor |

Attach your own GUI into the protected, top-most layer at a chosen priority:

```lua
M:Attach(myFrame, "hud")     -- parent into M.gui at the hud ZIndex
M:Attach(myFrame, 45)        -- or an explicit ZIndex between layers
```

Read or reprioritize layers:

```lua
UI.Toolkit.Layer("context")            -- 60
UI.Toolkit.SetLayer("mylayer", 55)     -- register a custom layer
```

### Visual (Drawing) layers

A parallel priority list for Drawing-based scripts (ESP, tracers), so overlays from different scripts don't fight over draw order:

| Layer | ZIndex |
|---|---|
| `world` | 1 |
| `tracers` | 2 |
| `boxes` | 3 |
| `fill` | 4 |
| `text` | 5 |
| `overlay` | 6 |

```lua
local z = UI.Toolkit.VisualLayer("boxes")   -- set your Drawing object's ZIndex to this
UI.Toolkit.SetVisualLayer("radar", 7)
```

Set `drawing.ZIndex = UI.Toolkit.VisualLayer("boxes")` on your Drawing objects and every script that shares the convention layers predictably.

---

## Toolkit

`UI.Toolkit` is the extension surface — everything a consumer script needs to build widgets, HUDs, and overlays that match the UI.

```lua
local tk = UI.Toolkit

tk.Theme        -- live theme table (see Theme)
tk.Kinds        -- { ok, warn, error, info } colors
tk.Color        -- { hex(c), fromHex(s), lerp(a,b,t) }
tk.Create(class, props, kids)   -- Instance factory (like the internal `new`)
tk.Tween(inst, tweenInfo, props)
tk.PathGet(root, "a.b.c"); tk.PathSet(root, "a.b.c", value)

tk.Layers; tk.Visuals
tk.Layer(name); tk.SetLayer(name, z)
tk.VisualLayer(name); tk.SetVisualLayer(name, z)

tk.RegisterWidget(name, builder)
tk.RegisterHUD(name, builder)
tk.RegisterMedia(ext, handler)
tk.Extend(name, value)          -- attach anything to the toolkit
```

Registration is also available as `UI.RegisterWidget`, `UI.RegisterHUD`, `UI.RegisterMedia`, `UI.Extend`.

---

## Window behavior

- **Drag:** grab the title bar (or any HUD element per the rules below). Dragging is smoothed with a short lerp so the window glides rather than snaps. While dragging the main or split windows, **centering guides** appear when a window's center aligns with the screen center (it snaps), and a live **x, y** coordinate readout follows the window.
- **Resize:** drag the dotted grip in the bottom-right corner with mouse or touch (disable with `resizable = false`; clamp with `minWidth`, `maxWidth`, `minHeight`, and `maxHeight`).
- **Open/close animation:** the window scales out of its top-left corner (Apple genie style) — tiny to full on show, full to tiny on the toggle key. The **minimize button** uses a distinct collapse (a slight tilt + shrink to nothing) so you can tell how it was closed.
- **Top-most:** the `ScreenGui` uses the maximum `DisplayOrder`, so the menu is always above other GUIs.
- **HUD elements** (watermark, keybind HUD, compass): to prevent accidental nudging, they only drag with **left-click while the menu is open**, and with **middle-click when the menu is closed**.

---

## Input tools

Owned input hooks (auto-disconnected on `Close`) so scripts running through the UI don't manage their own connections:

```lua
M:GetMouse()                              -- Vector2 mouse location
M:OnInput(function(input, gameProcessed) end)      -- InputBegan
M:OnInputEnded(function(input, gameProcessed) end) -- InputEnded
M:OnMouseMove(function(pos, delta) end)            -- mouse movement
```

## Description element

A collapsible, richly styled explainer row — click the chevron to expand the description. Great for "what does this do?" text next to a feature.

```lua
sec:Info({
	text = "Aimbot",
	description = UI.Toolkit.Rich("Locks aim to the nearest target. ", { color = Color3.fromRGB(150,200,255) })
		.. UI.Toolkit.Rich("Use responsibly.", { bold = true, italic = true }),
	color = Color3.fromRGB(220, 220, 230),
	open = false,
})
```

## Rich text & custom fonts

Every label supports rich text. Build styled strings with the toolkit helper (it escapes your text, then applies tags):

```lua
local tk = UI.Toolkit
tk.Rich("Danger", { color = Color3.fromRGB(240,120,120), bold = true, size = 16, underline = true })
-- also: italic, strike, face = "GothamBlack"
sec:Label(tk.Rich("Status: ", {}) .. tk.Rich("online", { color = Color3.fromRGB(150,220,170), bold = true }))
```

Load a custom font from a local file or content id (needs a valid Roblox font asset, not a raw `.ttf`; returns `nil` if unsupported):

```lua
local face = UI.LoadFont("myfont.json")   -- or a rbxasset id
if face then someLabel.FontFace = face end
```

## Debug & introspection

An ultra-verbose ring-buffer log (last 800 lines) you can stream to an executor console (`rconsole*`) and copy to clipboard.

```lua
local M = UI.new({ debug = true })   -- verbose from the start
M:SetVerbose(true)                   -- toggle live streaming
M:Log("info", "hello", somePart)     -- levels are free-form (info/warn/error/debug)
M:GetLog()                           -- the whole buffer as a string
M:OpenConsole()                      -- open/name the rconsole and dump the buffer
M:CopyLog()                          -- setclipboard the buffer (returns bool)
M:ClearLog()
```

The UI logs its own lifecycle (create, close, feature add/remove, `Exec` results) so you can see exactly what your scripts did through it.

---

## Limitations & security

**What the UI touches.** EasyUI itself only creates and mutates **its own `ScreenGui`** and reads client-local services (input, tween, camera, `MarketplaceService:GetProductInfo` for the watermark name). It sends no remotes, never writes to `workspace`, and never reads or writes other players. `AttachESP` can start and configure the supplied ESP instance, whose effects are documented separately. When the UI needs a 3D preview it builds a dummy **inside a `ViewportFrame`** — never in the world. Configs are JSON only (no `loadstring`), and filenames are sanitized against path traversal.

**`Exec` is a script loader, not a sandbox.** `Exec`/`ImportFeature`/`ImportHUD` run whatever you give them (function, `ModuleScript`, code string, or URL via `HttpGet`+`loadstring`). The `ctx` handed to a loaded script exposes the full UI, so **only run code you trust** — the UI gives it a clean, owned lifecycle (auto-cleanup, scheduling, windows), not isolation. True Lua sandboxing isn't possible against executor-level identity.

**YouTube.** Only the video **thumbnail** is importable. Actual video playback isn't supported: Roblox can't reliably decode an arbitrary downloaded `.mp4`, and YouTube serves expiring, split DASH/HLS streams that aren't a single downloadable file. `sec:Media("youtube.com/watch?v=...")` shows the thumbnail; for real video, upload a rights-cleared file to Roblox and use its asset id.

**Escape capture.** While assigning a keybind, Escape is temporarily sunk via `ContextActionService` so pressing it to clear a bind won't open the Roblox menu; it's always unbound when capture ends or the UI closes.

---

## Theme

```lua
local Theme = UI.Toolkit.Theme
Theme.Accent, Theme.Window, Theme.Panel, Theme.Card, Theme.Control,
Theme.Hover, Theme.Stroke, Theme.Soft, Theme.Text, Theme.Sub, Theme.Muted,
Theme.Ok, Theme.Warn, Theme.Err, Theme.Info
Theme.Font, Theme.Bold, Theme.Mono   -- BuilderSans family with Gotham fallback
```

`M:SetAccent(color)` recolors every accent-driven element live.

**Accent is per-instance.** `accent` in `UI.new` and `M:SetAccent(color)` store the color on the instance, so two instances never inherit each other's accent and closing one leaves nothing to restore. The rest of the theme table (colors, fonts) is shared module state, and `UI.Toolkit.Theme.Accent` is the library default rather than the live instance accent — read the current one from the instance instead. Custom widgets that need the live accent should paint from the color passed by `M:SetAccent` (register in the accent updater list the same way built-in widgets do) or take an explicit color option.

---

## API reference

### `UI`
`UI.new(options) -> M` · `UI.RegisterWidget(name, fn)` · `UI.RegisterHUD(name, fn)` · `UI.RegisterMedia(ext, fn)` · `UI.Extend(name, value)` · `UI.Toolkit`

### Instance `M`
**Core:** `SetVisible(v, reason?)` · `Close()` · `SetAccent(c)` · `GameInfo()` · `Attach(instance, layer)`
**Input:** `GetMouse()` · `OnInput(fn)` · `OnInputEnded(fn)` · `OnMouseMove(fn)`
**Debug:** `Log(level, ...)` · `SetVerbose(on)` · `GetLog()` · `ClearLog()` · `CopyLog()` · `OpenConsole()`
**Nav:** `Tab(name)` · `Window(id, opts)` · `GetWindow(id)` · `OpenWindow(id)` · `CloseWindow(id)`
**State:** `Get(flag)` · `Set(flag, v)` · `Mount(name, root)` · `Unmount(name)` · `Sync(prefix)`
**Config:** `ExportConfig/CFG` · `ImportConfig/ICFG` · `SaveConfig/SCFG` · `LoadConfig/LCFG` · `DeleteConfig` · `ListConfigs` · `SetAutoload` · `LoadAutoload` · `ConfigTab(opts)`
**Runtime:** `Schedule(name, fn, fps, priority)` · `Every(name, interval, fn, priority)` · `Batch(name, items, fn, opts)` · `Queue(name, priority, fn)`
**Features:** `Use(name, fn)` · `Drop(name)` · `GetFeature(name)` · `SetFeatureEnabled(name, on)` · `Exec(name, source, opts)` · `ImportFeature` · `ImportHUD` · `HUD(name, opts)`
**ESP/media/hud:** `AttachESP(esp, opts)` · `ImportMedia(url, opts)` · `Notify(opts)` · `SetCursor(on, opts)` · `SetKeybindHUD(on, opts)`

### Node (Tab / SubTab)
`Tab(name)` · `SubTab(name)` · `Section(title)` · `Open()` · `Destroy()`

### Section
`Label` · `Divider` · `Badge` · `Toggle` · `Button` · `Slider` · `Dropdown` · `Keybind` · `Textbox` · `Colorpicker` · `Media` · `Info(opts)` · `Widget(name, opts)`

### Toolkit
`Color` · `Create` · `Tween` · `Theme` · `Kinds` · `Easing` · `PathGet` · `PathSet` · `Rich(text, style)` · `LoadFont(source)` · `RegisterWidget` · `RegisterHUD` · `RegisterMedia` · `Extend` · `Layers` · `Visuals` · `Layer` · `SetLayer` · `VisualLayer` · `SetVisualLayer`

### Window
`Tab` · `SubTab` · `Open` · `Close` · `SetVisible(v)` · `GetVisible` · `GetFrame` · `GetState` · `Set(state)` · `Destroy`

---

## Changelog

### Keybind mode pass

- Every right-click-bindable control now exposes `Toggle` / `Hold` mode beside its key assignment.
- `bindMode` is applied during widget registration instead of waiting for the context menu to open.
- Configs explicitly persist both modes and update the live widget immediately on import.
- Hold-mode toggles restore their previous state on release, repeated key-down events are ignored, and one-shot controls are never replayed on key-up.

### Stability pass

- **Accent is per-instance.** `accent` / `SetAccent` no longer mutate the shared theme table, so a second `UI.new` no longer inherits the previous instance's accent and closing an instance leaves no residue. `UI.Toolkit.Theme.Accent` now reports the library default. See [Theme](#theme).
- **`Exec` handle.** `handle.error` is set only when the load fails; a successful `Exec` now reports `error = nil`. See [Exec](#exec--run-a-whole-script-through-the-ui).
- **Feature setup no longer runs twice.** A setup function returning `nil`/`false` was stored as the feature value itself, so teardown re-invoked the setup. `Use`/`Exec` now keep the returned value verbatim.
- **`SetFeatureEnabled(name, true)`** no longer calls the feature's `Stop` when it has no `Start`.
- **Overlapping drags.** Starting a drag while another is in flight now finishes the first one, instead of stranding the earlier widget in a permanent drag state with a leaked per-frame job.
- **Keybind dispatch** is a keycode lookup instead of a scan over every widget on every key press.
- **Keybind HUD rows** are repainted in place rather than destroyed and rebuilt on every toggle or rebind.
- **Dropdown lists** cap their height and scroll instead of growing past the window.
- **Leaks fixed:** the frame-scheduler connection is cleared on cleanup (previously `Schedule`/`Every`/`Batch` silently stopped running after the GUI was reparented away), accent updaters are pruned with destroyed widgets, and a color picker whose row is destroyed no longer leaves a dangling open-picker reference.
