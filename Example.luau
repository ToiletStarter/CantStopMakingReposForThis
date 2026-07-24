local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/EasyUiTesting.luau"))()

local M = UI.new({
	title = "EasyUI",
	toggleKey = Enum.KeyCode.RightShift,
	loadTime = 0.8,
	watermark = true,
	cursor = true,
	keybindHud = true,
})

local widgets = M:Tab("Widgets")
local basics = widgets:SubTab("Basics"):Section("Controls")
M:Set("demo.strength", 50)
M:Set("demo.tint", UI.Toolkit.Theme.Accent)
basics:Toggle({
	text = "Master Switch",
	flag = "demo.enabled",
	default = true,
	context = function(ctx)
		ctx:Slider({ text = "Strength", flag = "demo.strength", min = 0, max = 100, default = 50 })
		ctx:Colorpicker({ text = "Tint", flag = "demo.tint", default = UI.Toolkit.Theme.Accent })
	end,
})
basics:Slider({ text = "Speed", flag = "demo.speed", min = 0, max = 200, default = 60 })
basics:Dropdown({ text = "Mode", flag = "demo.mode", options = { "Legit", "Rage", "Silent" }, default = "Legit" })
basics:Keybind({ text = "Action Key", flag = "demo.key", default = Enum.KeyCode.F, callback = function()
	M:Notify({ title = "Keybind", text = "Action key pressed.", kind = "info", duration = 2 })
end })
basics:Textbox({ text = "Nickname", flag = "demo.name", placeholder = "type..." })
basics:Colorpicker({ text = "Accent", flag = "demo.accent", default = UI.Toolkit.Theme.Accent, callback = function(color)
	M:SetAccent(color)
end })

local extras = widgets:SubTab("Extras"):Section("Display")
extras:Label("Labels, badges, and dividers:")
local badge = extras:Badge("Idle", "info")
extras:Divider()
extras:Button({ text = "Toast: OK", callback = function()
	badge:Set("Working", "ok")
	M:Notify({ title = "EasyUI", text = "Everything nominal.", kind = "ok" })
end })
extras:Button({ text = "Toast: Error", callback = function()
	badge:Set("Broken", "error")
	M:Notify({ title = "EasyUI", text = "That did not work.", kind = "error" })
end })

local runtime = M:Tab("Runtime"):Section("Jobs")
runtime:Button({ text = "Budgeted Batch (1k items)", callback = function()
	M:Batch("demo", table.create(1000, 0), function() end, {
		interval = 0.01,
		budget = 0.002,
		chunk = 100,
		done = function()
			M:Notify({ title = "Runtime", text = "Processed 1,000 items.", kind = "ok" })
		end,
	})
end })
runtime:Button({ text = "Exec Managed Script", callback = function()
	M:Exec("pulse", function(ctx)
		local count = 0
		ctx:Every("pulse", 1, function()
			count += 1
			ctx:Notify({ title = "Pulse", text = "Tick " .. count, kind = "info", duration = 1.5 })
			if count >= 3 then
				M:Drop("pulse")
			end
		end)
	end)
end })

local tools = M:Window("Tools", {
	x = 720,
	y = 140,
	width = 400,
	height = 320,
	style = "panel",
	header = "Split Window",
	open = false,
	flag = "windows.tools",
})
local media = tools:Tab("Media"):Section("Import")
local mediaLoaded = false
media:Button({ text = "Load YouTube Thumbnail", callback = function()
	if mediaLoaded then
		return
	end
	local ok, err = pcall(function()
		media:Media("https://www.youtube.com/watch?v=dQw4w9WgXcQ", { height = 150 })
	end)
	mediaLoaded = ok
	if not ok then
		M:Notify({ title = "Media", text = tostring(err), kind = "error" })
	end
end })
tools:Tab("About"):Section("Info"):Label("Split windows nest tabs and subtabs too.")

local windows = M:Tab("Windows"):Section("Split Windows")
windows:Button({ text = "Open Tools Window", callback = function() tools:Open() end })
windows:Button({ text = "Close Tools Window", callback = function() tools:Close() end })

M:HUD("Compass")
M:ConfigTab()

task.delay(1.2, function()
	M:Notify({ title = "EasyUI", text = "RightShift toggles. Right-click any control for keybinds.", kind = "info", duration = 6 })
end)

return M
