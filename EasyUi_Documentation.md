# EasyUiTesting

```luau
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/EasyUiTesting.luau"))()
local menu = UI.new({ title = "Menu", cursor = true, keybindHud = true })
```

## Navigation

```luau
local tab = menu:Tab("Visuals")
local subtab = tab:SubTab("Players")
local nested = subtab:SubTab("Enemies")
local section = nested:Section("Boxes")
```

`SubTab` and `Tab` are aliases on navigation nodes, so deeper paths use the same API.

## Split Windows

```luau
local tools = menu:Window("Tools", {
	x = 700,
	y = 120,
	width = 380,
	height = 330,
	style = "panel",
	header = "Tools",
	open = false,
	flag = "windows.tools",
})

tools:Tab("Main"):Section("Actions"):Button({
	text = "Close",
	callback = function() tools:Close() end,
})

tools:Open()
```

## Runtime

```luau
menu:Queue("load-data", 20, function() end)
menu:Every("poll", 0.1, function(elapsed) end, 5)

menu:Batch("players", game:GetService("Players"):GetPlayers(), function(player, index)
	print(index, player)
end, { interval = 0.01, budget = 0.002, chunk = 25 })
```

`Batch` resumes on later frames after its time budget or chunk limit is reached. Intervals below the current frame duration run on the next available frame.

Managed scripts receive a runtime context:

```luau
menu:Exec("feature", function(ctx)
	ctx:Schedule("update", function() end, 30)
	ctx:Set("feature.enabled", true)
	return function() end
end, { priority = 10 })
```

## Configs

```luau
menu:SaveConfig("default")
menu:LoadConfig("default")
menu:DeleteConfig("default")
menu:SetAutoload("default")
menu:LoadAutoload()
menu:ConfigTab()
```

Short aliases: `CFG`, `ICFG`, `SCFG`, and `LCFG`.

## ESP

```luau
local EasyESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/hold/refs/heads/main/esp"))()
local esp = EasyESP.new()
local link = menu:AttachESP(esp, { enabled = true, start = true, build = true, own = true })
```

`AttachESP` mounts `esp.cfg`, validates descriptor writes, builds controls, starts ESP, and removes the old bridge requirement. ESP descriptor windows become split windows by default; set `singleWindow = true` for one sidebar window.

## Context Menus

Buttons, toggles, sliders, dropdowns, textboxes, and color pickers support right-click keybind assignment. Use `noKeybind = true` to disable it. Dedicated keybind controls do not receive another keybind.

Add contextual settings with `context`:

```luau
section:Toggle({
	text = "ESP",
	context = function(context)
		context:Colorpicker({ text = "Color" })
		context:Slider({ text = "Range", min = 0, max = 5000 })
	end,
})
```

## Media

```luau
section:Media("https://example.com/image.png", { height = 180 })
section:Media("https://example.com/audio.mp3", { play = true })
section:Media("https://youtube.com/watch?v=VIDEO_ID")
```

PNG/JPG and MP3 are the reliable Potassium paths. GIF and MP4/MOV are capability-probed through `getcustomasset`; decoder support varies. YouTube URLs import their thumbnail, not the video stream.

## Toolkit

```luau
UI.RegisterWidget("custom", function(section, options, toolkit)
	return section:Label(options.text)
end)

UI.RegisterHUD("CustomHUD", function(menu, options, folder, own)
	return { SetEnabled = function(self, enabled) end }
end)

UI.RegisterMedia("webp", function(menu, url, options) end)
UI.Extend("Helper", function() end)
```

Built-in HUD:

```luau
menu:HUD("Compass")
```
