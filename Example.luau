local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/EasyUiTesting.luau"))()
local EasyESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/hold/refs/heads/main/esp"))()

local M = UI.new({
	title = "EasyUI Testing",
	toggleKey = Enum.KeyCode.RightShift,
	loadTime = 1.2,
	watermark = true,
	cursor = true,
	keybindHud = true,
})

local main = M:Tab("Main")
local combat = main:SubTab("Combat")
local aiming = combat:SubTab("Aiming")
local section = aiming:Section("Controls")

section:Toggle({
	text = "Enabled",
	flag = "demo.enabled",
	default = true,
	context = function(context)
		context:Slider({ text = "FOV", flag = "demo.fov", min = 20, max = 500, default = 120 })
		context:Dropdown({ text = "Mode", flag = "demo.mode", options = { "Silent", "Assist", "Lock" }, default = "Silent" })
		context:Colorpicker({ text = "Color", flag = "demo.color", default = UI.Toolkit.Theme.Accent })
	end,
})
section:Slider({ text = "Smoothing", flag = "demo.smoothing", min = 0, max = 100, default = 45 })
section:Textbox({ text = "Target Name", flag = "demo.target", placeholder = "player..." })

local tools = M:Window("Tools", {
	x = 700,
	y = 120,
	width = 380,
	height = 330,
	style = "panel",
	header = "Runtime Tools",
	open = false,
	flag = "windows.tools",
})

local runtime = tools:Tab("Runtime"):Section("Queue")
runtime:Button({ text = "Run Budgeted Batch", callback = function()
	local work = table.create(1000, 0)
	M:Batch("example", work, function(_, index)
		work[index] = index * 2
	end, {
		interval = 0.01,
		budget = 0.002,
		chunk = 100,
		done = function()
			M:Notify({ title = "Runtime", text = "Processed 1,000 items.", kind = "ok" })
		end,
	})
end })
runtime:Button({ text = "Close Tools", callback = function() tools:Close() end })

local mediaTab = tools:Tab("Media")
local mediaSection = mediaTab:Section("Thumbnail")
local mediaLoaded = false

section:Button({ text = "Open Runtime Tools", callback = function() tools:Open() end })
section:Button({ text = "Load YouTube Thumbnail", callback = function()
	if not mediaLoaded then
		mediaLoaded = true
		mediaSection:Media("https://www.youtube.com/watch?v=dQw4w9WgXcQ", { height = 160 })
	end
	mediaTab:Open()
	tools:Open()
end })

M:HUD("Compass")
M:ConfigTab()

local esp = EasyESP.new()
M:AttachESP(esp, { enabled = true, start = true, build = true, own = true, singleWindow = true })

task.delay(1.5, function()
	M:Notify({ title = "EasyUI", text = "Right-click controls for keybinds and mini settings.", kind = "info", duration = 6 })
end)

return M
