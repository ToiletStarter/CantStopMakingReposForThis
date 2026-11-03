# EasyUI Style 2

A second visual style for EasyUI. Same authoring shape — `UI.new` → `Window` → `Tab` → `Section` → widgets — with a different look: floating multi-window panels, springs, toast stack, compact density, and optional horizontal control grids.

Where `EasyUiTesting.luau` is one large window with a tab strip, `EasyUi_style_2.luau` supports both scattered windows and a single tailored window with horizontal groups. Loading it does not change `EasyUiTesting.luau`, and both can run at once.

## Install

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyui/EasyUi_style_2.luau"))()
```

## Quick start

```lua
local M = UI.new({
    title = "rotware",
    accent = Color3.fromRGB(96, 205, 255),
    toggleKey = Enum.KeyCode.RightShift,
})

local combat = M:Window("Combat", { x = 40, y = 90, width = 300, height = 330 })
local legit = combat:Tab("Legit")
local aim = legit:Section("Aim assist")

aim:Toggle({ text = "Enabled", flag = "legit.on", default = true })
aim:Slider({ text = "FOV radius", flag = "legit.fov", min = 10, max = 400, default = 120 })
aim:Slider({ text = "Smoothing", flag = "legit.smooth", min = 0, max = 1, decimals = 2, default = 0.22 })
aim:Dropdown({ text = "Hitbox", flag = "legit.part", options = { "Head", "Torso", "Nearest" }, default = "Head" })
aim:Keybind({ text = "Aim key", flag = "legit.key", default = Enum.KeyCode.C })

M:Notify({ title = "rotware", text = "Loaded.", kind = "ok" })
```

## Differences from EasyUI

| | EasyUI | Style 2 |
| --- | --- | --- |
| Shape | one window, tabs + subtabs | many windows, tabs per window |
| Entry | `M:Tab(name)` | `M:Window(title, opts):Tab(name)` |
| Titlebar | header + controls | accent dot, `title: subtitle`, collapse |
| Motion | Apple-style open/close | Quint/Back springs, ripple, sliding tab indicator |
| Toasts | click-to-dismiss | bottom-right stack with a draining progress bar |
| Subtabs | yes | no — use another window |
| Config profiles | yes | no |
| Runtime (`Batch`/`Every`) | yes | no |

Style 2 is deliberately smaller. If you need config profiles, the managed runtime, context menus, media import or `AttachESP`, use `EasyUiTesting.luau`.

## `UI.new(options)`

| key | default | meaning |
| --- | --- | --- |
| `title` | `"rotware"` | watermark text and window titlebar prefix |
| `accent` | `#60CDFF` | accent color, live-swappable |
| `transparency` | `0.08` | window background transparency |
| `toggleKey` | `RightShift` | key to show/hide everything; `false` disables |
| `separator` | `" | "` | text between the UI title and window titlebar label |
| `compact` | `false` | reduces section padding, row height, and slider height |
| `cursor` | `true` | alias for `customCursor`; when false the native cursor remains visible |
| `watermark` | `true` | top-left pill with live fps and ping |
| `name` | random | `ScreenGui` name |

## Instance `M`

`Window(title, opts)` · `SetVisible(v)` · `Toggle()` · `Get(flag)` · `Set(flag, v)` · `SetAccent(color)` · `SetStyle(opts)` · `SetGrouped(v)` · `ShowAll()` · `Notify(opts)` · `Destroy()`

`M.flags` is the live flag table. `M.windows` is the window list.

## Window

`Tab(name)` · `SubTab(name)` · `SetVisible(v)` · `GetVisible()` · `Toggle()` · `Destroy()`

```lua
local w = M:Window("Visuals", { x = 370, y = 90, width = 280, height = 260 })
```

| key | default |
| --- | --- |
| `x`, `y` | `40`, `40` |
| `width` | `300` |
| `height` | `340` |

Windows drag by the titlebar, raise on click, collapse to the titlebar with the `—` button, and resize from the bottom-right grip. Minimum size is 190×120 pixels.

## Tab

`Section(title)` · `SubTab(name)` · `Open()`

Tabs animate in and the accent indicator glides to the active tab. Subtab pages render below a dedicated, visible subtab strip and keep their own section layout.

## Section layout

`section:Grid(columns, opts)` creates horizontal columns that accept the same widget methods as a section. `section:Columns(...)` is an alias. Use `grid:Column(index)` to target a column or `grid:Each(fn)` to iterate them. `compact = true` reduces the default vertical spacing for dense panels.

```lua
local layout = section:Grid(2, { gap = 5 })
layout:Column(1):Toggle({ text = "Names", flag = "esp.names", default = true })
layout:Column(2):Toggle({ text = "Health", flag = "esp.health", default = true })
```

## Section widgets

Every widget returns a handle with `Set(value, silent)`, `Get()` and `Destroy()`. Passing `silent = true` updates the control without firing `callback`.

### Toggle

```lua
section:Toggle({ text = "Enabled", flag = "esp.on", default = true, callback = function(v) end })
```

### Button

```lua
section:Button({ text = "Refill", callback = function() end })
```

### Slider

```lua
section:Slider({
    text = "Max distance",
    flag = "esp.dist",
    min = 50, max = 1500, default = 500,
    decimals = 0,          -- 2 for fractional values
    suffix = "m",          -- appended to the readout
    callback = function(v) end,
})
```

### Dropdown

```lua
section:Dropdown({ text = "Style", flag = "esp.style", options = { "Corner", "Full" }, default = "Corner" })
```

The popup is a scrolling list capped at six visible rows and rendered at GUI root so it is never clipped by the window. It opens below the exact control position, animates from a four-pixel offset, and repositions from the control's current screen position.

### Keybind

```lua
section:Keybind({ text = "Aim key", flag = "aim.key", default = Enum.KeyCode.C,
    callback = function() end,   -- fired when the bound key is pressed
    changed = function(k) end,   -- fired when the binding changes
})
```

Click the chip, then press a keyboard key or mouse button. `Backspace` clears the binding.

### Textbox

```lua
section:Textbox({ text = "Name", flag = "cfg.name", placeholder = "type...", callback = function(s) end })
```

### Colorpicker

```lua
section:Colorpicker({ text = "Accent", default = Color3.fromRGB(96, 205, 255), callback = function(c)
    M:SetAccent(c)
end })
```

Clicking the swatch expands an inline hue strip inside the row.

Every widget may receive a `context` builder. Right-clicking the widget opens a compact menu. A context entry can be a `toggle`, `color`, or action entry; color entries render a palette and call `set(color, widget, ui)`.

```lua
section:Toggle({
    text = "Tracers",
    flag = "esp.tracers",
    context = function()
        return {
            { kind = "toggle", text = "Hide occluded", get = function() return false end, set = function(v) end },
            { kind = "color", text = "Color", colors = {
                { name = "Cyan", color = Color3.fromRGB(100, 200, 255) },
                { name = "Gold", color = Color3.fromRGB(255, 210, 90) },
            }, set = function(color) end },
        }
    end,
})
```

Right-click context menus are owned by the UI instance and are destroyed with it.

### Label, Divider, Badge

```lua
section:Label("Plain text.")
section:Divider()
local badge = section:Badge("Idle", "info")
badge:Set("Running", "ok")
```

Badge kinds: `ok`, `warn`, `error`, `info`.

## Flags

A widget with a `flag` registers into `M.flags`. Two widgets sharing a flag stay in sync — setting one silently updates the other, without re-firing callbacks.

```lua
M:Set("esp.on", true)
print(M:Get("esp.on"))
```

## Notifications

```lua
M:Notify({ title = "rotware", text = "Everything nominal.", kind = "ok", duration = 3.5, priority = false })
```

Kinds: `ok`, `warn`, `error`, `info`. Toasts stack bottom-right, slide in from the right, and drain a progress bar for their duration. Three normal notifications are kept active; `priority = true` bypasses that cap.

## Accent

`M:SetAccent(color)` repaints every accent-driven element live — window dots, tab indicators, toggle tracks, slider fills, watermark dot and custom cursor.

## Style controls

```lua
M:SetStyle({
    windowColor = Color3.fromRGB(18, 19, 23),
    titlebarColor = Color3.fromRGB(26, 28, 34),
    cardColor = Color3.fromRGB(28, 30, 36),
    controlColor = Color3.fromRGB(35, 37, 44),
    windowTransparency = 0.08,
    strokeColor = Color3.fromRGB(52, 56, 66),
    textColor = Color3.fromRGB(238, 240, 245),
    cornerRadius = 10,
})
```

`Background(opts)` is an alias for `SetStyle(opts)`. Style changes apply to all existing windows, titlebars, sections, controls, strokes, text and corners owned by the UI instance.

## Toolkit

```lua
UI.Toolkit.Theme     -- color and font table
UI.Toolkit.Create    -- create(class, props, children)
UI.Toolkit.Tween     -- tween(inst, info, goal)
UI.Toolkit.Corner    -- corner(parent, radius)
UI.Toolkit.Stroke    -- stroke(parent, color, thickness, transparency)
UI.Toolkit.Easing    -- { Spring, Quick, Pop }
```

## Theme

```
Accent   #60CDFF     Window  #121317     Titlebar #1A1C22
Panel    #16171C     Card    #1C1E24     Control  #23252C
Hover    #2C2F37     Stroke  #343842
Text     #EEF0F5     Sub     #9298A5     Muted    #606672
Ok       #7EE0A8     Warn    #F0CE8C     Err      #F08A94     Info #8CBEFA
```

Fonts resolve `BuilderSans` → `Gotham` → `SourceSans`, so it renders on clients without the newer family.

## Notes

- The GUI is parented through `gethui()` when available, then `syn.protect_gui`, then `PlayerGui`.
- `DisplayOrder` is `9999`.
- Only the library's own `ScreenGui` is created or mutated. No remotes, no `workspace` writes, no other-player access.
- `M:Destroy()` disconnects every input connection and removes the GUI.
- The custom cursor is an owned ScreenGui element. It hides the native cursor only while the UI is visible and cursor-enabled; hiding the UI or calling `SetCursorVisible(false)` restores the prior native cursor state.
- Host-side Potassium capture is the supported visual verification path: `potagent shot <label>`.
