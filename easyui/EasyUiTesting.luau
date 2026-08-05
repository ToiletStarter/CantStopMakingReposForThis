local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Tween = game:GetService("TweenService")
local Run = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Http = game:GetService("HttpService")
local CAS = game:GetService("ContextActionService")

local LP = Players.LocalPlayer

local function fontOr(name, fallback)
	for _, item in ipairs(Enum.Font:GetEnumItems()) do
		if item.Name == name then
			return item
		end
	end
	return fallback
end

local Theme = {
	Font = fontOr("BuilderSansBold", fontOr("GothamBold", Enum.Font.GothamMedium)),
	Bold = fontOr("BuilderSansExtraBold", fontOr("GothamBold", Enum.Font.GothamBold)),
	Mono = Enum.Font.Code,

	Accent = Color3.fromRGB(236, 236, 240),
	Window = Color3.fromRGB(15, 15, 17),
	Panel = Color3.fromRGB(21, 21, 24),
	Card = Color3.fromRGB(27, 27, 31),
	Control = Color3.fromRGB(33, 33, 38),
	Hover = Color3.fromRGB(43, 43, 49),
	Stroke = Color3.fromRGB(46, 46, 53),
	Soft = Color3.fromRGB(36, 36, 42),
	Text = Color3.fromRGB(240, 240, 245),
	Sub = Color3.fromRGB(150, 150, 160),
	Muted = Color3.fromRGB(96, 96, 106),

	Ok = Color3.fromRGB(172, 226, 191),
	Warn = Color3.fromRGB(240, 214, 168),
	Err = Color3.fromRGB(240, 172, 178),
	Info = Color3.fromRGB(176, 205, 240),
}
local Kind = { ok = Theme.Ok, warn = Theme.Warn, error = Theme.Err, info = Theme.Info }

local TOPMOST = 2147483647
local Layers = {
	window = 1,
	hud = 15,
	toast = 30,
	context = 60,
	picker = 70,
	loader = 100,
	cursor = 1000,
}
local Visuals = {
	world = 1,
	tracers = 2,
	boxes = 3,
	fill = 4,
	text = 5,
	overlay = 6,
}

local E = {
	Smooth = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Snap = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Now = TweenInfo.new(0.04, Enum.EasingStyle.Linear),
	Grow = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Shrink = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
	Glide = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

local function new(class, props, kids)
	local i = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				i[k] = v
			end
		end
	end
	if kids then
		for _, c in ipairs(kids) do
			c.Parent = i
		end
	end
	if props and props.Parent then
		i.Parent = props.Parent
	end
	return i
end

local function tw(i, info, props)
	local t = Tween:Create(i, info, props)
	t:Play()
	return t
end

local function corner(r, p)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p })
end

local function stroke(c, t, tr, p)
	return new("UIStroke", { Color = c or Theme.Stroke, Thickness = t or 1, Transparency = tr or 0, Parent = p })
end

local function pad(a, p, l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l or a),
		PaddingRight = UDim.new(0, r or a),
		PaddingTop = UDim.new(0, t or a),
		PaddingBottom = UDim.new(0, b or a),
		Parent = p,
	})
end

local function list(p, gap, dir)
	return new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap or 6),
		Parent = p,
	})
end

local function escapeRich(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function label(text, size, color, font, p)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text or "",
		TextSize = size or 13,
		TextColor3 = color or Theme.Text,
		Font = font or Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
		Parent = p,
	})
end

local TextSvc = game:GetService("TextService")
local function textWidth(text, size, font)
	text = tostring(text):gsub("<[^<>]->", "")
	local ok, v = pcall(function()
		return TextSvc:GetTextSize(text, size, font, Vector2.new(4000, 40)).X
	end)
	return ok and v or (#text * size * 0.5)
end

local function bindHeight(frame, layout, extra)
	local function upd()
		frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, layout.AbsoluteContentSize.Y + (extra or 0))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(upd)
	upd()
	return upd
end

local function hover(i, base, to)
	i.MouseEnter:Connect(function()
		tw(i, E.Fast, { BackgroundColor3 = to })
	end)
	i.MouseLeave:Connect(function()
		tw(i, E.Fast, { BackgroundColor3 = base })
	end)
end

local function ripple(p)
	local c = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 30,
		Parent = p,
	})
	corner(999, c)
	local s = math.max(p.AbsoluteSize.X, p.AbsoluteSize.Y) * 1.7
	tw(c, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(s, s),
		BackgroundTransparency = 1,
	})
	task.delay(0.46, function()
		c:Destroy()
	end)
end

local function inside(gui, pos)
	if not (gui and gui.Parent and gui.Visible) then
		return false
	end
	local a, s = gui.AbsolutePosition, gui.AbsoluteSize
	return pos.X >= a.X and pos.X <= a.X + s.X and pos.Y >= a.Y and pos.Y <= a.Y + s.Y
end

local Color = {}
function Color.hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
function Color.fromHex(s)
	s = s:gsub("#", "")
	return Color3.fromRGB(tonumber(s:sub(1, 2), 16) or 0, tonumber(s:sub(3, 4), 16) or 0, tonumber(s:sub(5, 6), 16) or 0)
end
function Color.lerp(a, b, t)
	return a:Lerp(b, t)
end

local function beginDrag(ui, move, up)
	local pending = ui._dragUp
	ui._dragMove, ui._dragUp = nil, nil
	if pending then
		pcall(pending)
	end
	ui._dragMove, ui._dragUp = move, up
end

local function pathKey(container, key)
	if type(container) == "table" and container[key] == nil then
		local numeric = tonumber(key)
		if numeric and container[numeric] ~= nil then
			return numeric
		end
	end
	return key
end

local function pathGet(root, path)
	local value = root
	for key in tostring(path):gmatch("[^.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[pathKey(value, key)]
		if value == nil then
			return nil
		end
	end
	return value
end

local function pathSet(root, path, value)
	local keys = {}
	for key in tostring(path):gmatch("[^.]+") do
		keys[#keys + 1] = key
	end
	for i = 1, #keys - 1 do
		local key = pathKey(root, keys[i])
		if type(root[key]) ~= "table" then
			root[key] = {}
		end
		root = root[key]
	end
	if keys[1] then
		root[pathKey(root, keys[#keys])] = value
	end
	return value
end

local function packValue(value, seen)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __t = "c", r = value.R, g = value.G, b = value.B }
	end
	if kind == "EnumItem" then
		local enum, item = tostring(value):match("Enum%.([^.]+)%.(.+)")
		return { __t = "e", enum = enum, item = item }
	end
	if type(value) == "table" then
		seen = seen or {}
		if seen[value] then
			return nil
		end
		seen[value] = true
		local out = {}
		for k, v in pairs(value) do
			local packed = packValue(v, seen)
			if packed ~= nil then
				out[k] = packed
			end
		end
		seen[value] = nil
		return out
	end
	if type(value) == "string" or type(value) == "number" or type(value) == "boolean" or value == nil then
		return value
	end
end

local function unpackValue(value)
	if type(value) ~= "table" then
		return value
	end
	if value.__t == "c" then
		return Color3.new(value.r or 0, value.g or 0, value.b or 0)
	end
	if value.__t == "e" then
		local ok, item = pcall(function()
			return Enum[value.enum][value.item]
		end)
		return ok and item or nil
	end
	if value.__t == "n" then
		return nil
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = unpackValue(v)
	end
	return out
end

local function safeName(name)
	name = tostring(name or "default"):gsub("[^%w_%-]", "_"):sub(1, 64)
	return name ~= "" and name or "default"
end

local function dispose(value)
	if typeof(value) == "RBXScriptConnection" then
		value:Disconnect()
	elseif typeof(value) == "Instance" then
		value:Destroy()
	elseif type(value) == "function" then
		value()
	elseif type(value) == "table" then
		local fn = value.Destroy or value.destroy or value.Cancel or value.cancel or value.Stop or value.stop
		if fn then
			fn(value)
		end
	end
end

local function ensureGuides(ui)
	if ui._guides then
		return ui._guides
	end
	local function line(w, h, ax, ay, sx, sy)
		return new("Frame", { Size = UDim2.new(0, w, 0, h) + UDim2.new(sx or 0, 0, sy or 0, 0), Position = UDim2.new(ax, 0, ay, 0), AnchorPoint = Vector2.new(ax, ay), BackgroundColor3 = ui._accent or Theme.Accent, BackgroundTransparency = 0.45, BorderSizePixel = 0, Visible = false, ZIndex = Layers.cursor - 1, Parent = ui.gui })
	end
	local v = line(1, 0, 0.5, 0, 0, 1)
	local h = line(0, 1, 0, 0.5, 1, 0)
	local lbl = new("TextLabel", { Size = UDim2.fromOffset(92, 20), BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.05, Text = "", TextColor3 = Theme.Text, Font = Theme.Mono, TextSize = 11, BorderSizePixel = 0, Visible = false, ZIndex = Layers.cursor - 1, Parent = ui.gui })
	corner(6, lbl)
	ui._guides = { v = v, h = h, lbl = lbl }
	return ui._guides
end

local function viewport()
	return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
end

local function clampOnScreen(pos, target, vp)
	local size = target.AbsoluteSize
	local left = pos.X.Scale * vp.X + pos.X.Offset
	local top = pos.Y.Scale * vp.Y + pos.Y.Offset
	left = math.clamp(left, 40 - size.X, vp.X - 40)
	top = math.clamp(top, 0, vp.Y - 40)
	return UDim2.new(pos.X.Scale, left - pos.X.Scale * vp.X, pos.Y.Scale, top - pos.Y.Scale * vp.Y)
end

local function draggable(ui, handle, target, finished, opts)
	opts = opts or {}
	handle.Active = true
	handle.InputBegan:Connect(function(i)
		local t = i.UserInputType
		local allowed
		if opts.hud then
			allowed = t == Enum.UserInputType.MouseButton3
				or (ui.visible and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch))
		else
			allowed = t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
		end
		if not allowed then
			return
		end
		local start = Input:GetMouseLocation()
		local base = target.Position
		local desired = base
		local guides = opts.guides and ensureGuides(ui)
		local remove = ui:Schedule("__drag", function()
			target.Position = target.Position:Lerp(desired, 0.35)
			if guides then
				local vp = viewport()
				local size = target.AbsoluteSize
				local left = target.AbsolutePosition.X
				local top = target.AbsolutePosition.Y
				guides.v.Visible = math.abs(left + size.X / 2 - vp.X / 2) < 1.5
				guides.h.Visible = math.abs(top + size.Y / 2 - vp.Y / 2) < 1.5
				guides.lbl.Visible = true
				guides.lbl.Text = ("%d, %d"):format(math.floor(left), math.floor(top))
				guides.lbl.Position = UDim2.fromOffset(math.floor(left), math.floor(top) - 24)
			end
		end, nil, 3000)
		beginDrag(ui, function(m)
			local d = m - start
			desired = UDim2.new(base.X.Scale, base.X.Offset + d.X, base.Y.Scale, base.Y.Offset + d.Y)
			local vp = viewport()
			if guides then
				local size = target.AbsoluteSize
				local left = desired.X.Scale * vp.X + desired.X.Offset
				local top = desired.Y.Scale * vp.Y + desired.Y.Offset
				if math.abs(left + size.X / 2 - vp.X / 2) < 8 then
					desired = UDim2.new(desired.X.Scale, vp.X / 2 - size.X / 2 - desired.X.Scale * vp.X, desired.Y.Scale, desired.Y.Offset)
				end
				if math.abs(top + size.Y / 2 - vp.Y / 2) < 8 then
					desired = UDim2.new(desired.X.Scale, desired.X.Offset, desired.Y.Scale, vp.Y / 2 - size.Y / 2 - desired.Y.Scale * vp.Y)
				end
			end
			desired = clampOnScreen(desired, target, vp)
		end, function()
			remove()
			target.Position = desired
			if guides then
				guides.v.Visible = false
				guides.h.Visible = false
				guides.lbl.Visible = false
			end
			if finished then
				finished()
			end
		end)
	end)
end

local function resizeGrip(ui, target, opts, finished)
	opts = opts or {}
	if opts.resizable == false then
		return
	end
	local minWidth = tonumber(opts.minWidth) or 420
	local maxWidth = math.max(minWidth, tonumber(opts.maxWidth) or 960)
	local minHeight = tonumber(opts.minHeight) or 300
	local maxHeight = math.max(minHeight, tonumber(opts.maxHeight) or 720)
	local grip = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -2, 1, -2), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = target })
	for _, off in ipairs({ { -3, -3 }, { -8, -3 }, { -3, -8 } }) do
		local dot = new("Frame", { Size = UDim2.fromOffset(3, 3), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, off[1], 1, off[2]), BackgroundColor3 = Theme.Muted, BorderSizePixel = 0, Parent = grip })
		corner(999, dot)
	end
	grip.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local start = Input:GetMouseLocation()
		local baseSize = target.Size
		beginDrag(ui, function(mouse)
			local delta = mouse - start
			target.Size = UDim2.fromOffset(
				math.clamp(baseSize.X.Offset + delta.X, minWidth, maxWidth),
				math.clamp(baseSize.Y.Offset + delta.Y, minHeight, maxHeight)
			)
		end, finished)
	end)
end

local function mountGui()
	local g = new("ScreenGui", {
		Name = "EasyUI_" .. tostring(math.random(1e5, 9e5)),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = TOPMOST,
	})
	local ok = pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(g)
			g.Parent = CoreGui
		elseif gethui then
			g.Parent = gethui()
		else
			g.Parent = CoreGui
		end
	end)
	if not ok or not g.Parent then
		g.Parent = LP and (LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 5)) or CoreGui
	end
	return g
end

local UI = {}
UI.__index = UI
UI._Tab = {}
UI._Sec = {}
UI._Window = {}
UI._Window.__index = UI._Window
UI._widgetBuilders = {}
UI._mediaHandlers = {}
UI._hudBuilders = {}

function UI:_connect(signal, callback)
	local connection = signal:Connect(callback)
	self._connections[#self._connections + 1] = connection
	return connection
end

function UI:_cleanup()
	if self._escBound then
		pcall(function() self:_setCapture(nil) end)
	end
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}
	self._jobConnection = nil
end

local NO_BINDS = {}

function UI:_bindsFor(key)
	if self._bindIndexDirty ~= false then
		local index = {}
		for _, wd in ipairs(self.widgets) do
			if wd.bindKey and wd.activate then
				local bucket = index[wd.bindKey]
				if not bucket then
					bucket = {}
					index[wd.bindKey] = bucket
				end
				bucket[#bucket + 1] = wd
			end
		end
		self._bindIndex = index
		self._bindIndexDirty = false
	end
	return self._bindIndex[key] or NO_BINDS
end

function UI.new(o)
	o = o or {}
	local self = setmetatable({}, UI)
	local env = typeof(getgenv) == "function" and getgenv() or _G
	local previous = env.__EASYUI_ACTIVE
	if previous and previous ~= self and type(previous.Close) == "function" then
		pcall(previous.Close, previous)
	end
	self._connections = {}
	self.gui = mountGui()
	self:_connect(Input.InputChanged, function(i)
		if self._dragMove and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local ok = pcall(self._dragMove, Input:GetMouseLocation())
			if not ok then
				self._dragMove, self._dragUp = nil, nil
			end
		end
	end)
	self:_connect(Input.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.MouseButton3 or i.UserInputType == Enum.UserInputType.Touch then
			local finished = self._dragUp
			self._dragMove, self._dragUp = nil, nil
			if finished then
				pcall(finished)
			end
		end
	end)
	self.gui.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:_cleanup()
		end
	end)
	self.title = o.title or "EasyUI"
	self.toggleKey = o.toggleKey == false and nil or o.toggleKey or Enum.KeyCode.RightShift
	self.visible = true
	self.tabs = {}
	self._windows = {}
	self._mounts = {}
	self._jobs = {}
	self._jobOrder = {}
	self._jobsDirty = false
	self._queue = {}
	self._queued = {}
	self._batches = {}
	self._queueSeq = 0
	self._validators = {}
	self._accentUpdaters = {}
	self._tweens = setmetatable({}, { __mode = "k" })
	self.widgets = {}
	self.flags = {}
	self._flagWidgets = {}
	self._features = {}
	self._runtimeFolder = new("Folder", { Name = "Runtime", Archivable = false, Parent = self.gui })
	self._accent = o.accent or Theme.Accent

	local w, h = o.width or 560, o.height or 420
	local win = new("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2),
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		Parent = self.gui,
	})
	corner(12, win)
	stroke(Theme.Stroke, 1, 0.2, win)
	self.window = win

	local light = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1, Parent = win })
	corner(12, light)
	new("UIGradient", {
		Rotation = 128,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.45, 0.965),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = light,
	})

	local scale = new("UIScale", { Scale = 1, Parent = win })
	self._scale = scale

	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = win })
	draggable(self, bar, win, nil, { guides = true })
	local dot = new("Frame", {
		Size = UDim2.fromOffset(9, 9),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = self._accent,
		BorderSizePixel = 0,
		Parent = bar,
	})
	corner(999, dot)
	self._dot = dot
	local tlbl = label(self.title, 14, Theme.Text, Theme.Bold, bar)
	tlbl.Position = UDim2.new(0, 34, 0, 0)
	tlbl.Size = UDim2.new(1, -120, 1, 0)
	self._titleLbl = tlbl

	local function pill(x, color, cb)
		local b = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.new(1, x, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Theme.Control,
			BorderSizePixel = 0,
			Parent = bar,
		})
		corner(7, b)
		stroke(Theme.Soft, 1, 0, b)
		local ic = new("Frame", {
			Size = UDim2.fromOffset(9, 2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = b,
		})
		corner(2, ic)
		hover(b, Theme.Control, Theme.Hover)
		b.MouseButton1Click:Connect(cb)
	end
	pill(-14, Theme.Err, function()
		self:Close()
	end)
	pill(-44, Theme.Sub, function()
		self:SetVisible(false, "minimize")
	end)

	new("Frame", {
		Size = UDim2.new(1, -32, 0, 1),
		Position = UDim2.new(0, 16, 0, 42),
		BackgroundColor3 = Theme.Soft,
		BorderSizePixel = 0,
		Parent = win,
	})

	local tabBar = new("ScrollingFrame", {
		Size = UDim2.new(1, -32, 0, 34),
		Position = UDim2.new(0, 16, 0, 50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Stroke,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		Parent = win,
	})
	local tabBarList = list(tabBar, 6, Enum.FillDirection.Horizontal)
	tabBarList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		tabBar.CanvasSize = UDim2.new(0, tabBarList.AbsoluteContentSize.X, 0, 0)
	end)
	self._strip = tabBar

	local content = new("Frame", {
		Size = UDim2.new(1, 0, 1, -90),
		Position = UDim2.new(0, 0, 0, 90),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = win,
	})
	self._holder = content

	resizeGrip(self, win, o)

	local wm = new("Frame", {
		Size = UDim2.fromOffset(200, 28),
		Position = UDim2.new(0, 16, 0, 16),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = self.gui,
	})
	corner(999, wm)
	stroke(Theme.Stroke, 1, 0.1, wm)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Theme.Panel, Theme.Window),
		Parent = wm,
	})
	wm.ZIndex = Layers.hud
	draggable(self, wm, wm, nil, { hud = true, guides = true })
	local wmDot = new("Frame", {
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = self._accent,
		BorderSizePixel = 0,
		Parent = wm,
	})
	corner(999, wmDot)
	self._wmDot = wmDot
	local wmt = label(self.title .. "  •  0 fps", 12, Theme.Text, Theme.Mono, wm)
	wmt.Position = UDim2.new(0, 26, 0, 0)
	wmt.Size = UDim2.new(1, -34, 1, 0)
	self._wm, self._wmt = wm, wmt
	wm.Visible = o.watermark ~= false
	local gameName = ("Place %d"):format(game.PlaceId)
	local lastFps = 0
	local function paint(fps)
		if not wmt.Parent then
			return
		end
		lastFps = fps or lastFps
		wmt.Text = self.title .. "  •  " .. gameName .. "  •  " .. lastFps .. " fps"
		wm.Size = UDim2.fromOffset(textWidth(wmt.Text, 12, Theme.Mono) + 42, 28)
	end
	task.spawn(function()
		local info = self:GameInfo()
		if info and info.name then
			gameName = escapeRich(info.name)
			paint()
		end
	end)
	do
		local acc, frames = 0, 0
		self:_connect(Run.RenderStepped, function(dt)
			if not wmt.Parent then
				return
			end
			acc += dt
			frames += 1
			if acc >= 0.5 then
				paint(math.floor(frames / acc + 0.5))
				acc, frames = 0, 0
			end
		end)
	end

	self:_connect(Input.InputBegan, function(i, gp)
		if self._captureKey then
			if i.KeyCode ~= Enum.KeyCode.Unknown then
				local capture = self._captureKey
				self:_setCapture(nil)
				capture(i)
				return
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.Touch then
				local capture = self._captureKey
				self:_setCapture(nil)
				capture(nil)
			end
		end
		if i.KeyCode == self.toggleKey then
			if not Input:GetFocusedTextBox() then
				self:SetVisible(not self.visible)
			end
			return
		end
		if gp then
			return
		end
		if i.KeyCode ~= Enum.KeyCode.Unknown then
			for _, wd in ipairs(self:_bindsFor(i.KeyCode)) do
				if wd.bindKey == i.KeyCode and wd.activate and (not wd.row or wd.row:IsDescendantOf(self.gui)) then
					if wd.bindMode == "hold" then
						if wd.setState then
							wd._heldPrev = wd.getState and wd.getState() or false
							wd._held = true
							task.spawn(wd.setState, true)
						else
							wd._held = true
							task.spawn(wd.activate)
						end
					else
						task.spawn(wd.activate)
					end
					if wd.getState and not (wd.opt and wd.opt.silent) then
						task.defer(function()
							local on = wd.getState()
							self:Notify({ title = (wd.opt and wd.opt.text) or "Keybind", text = on and "Enabled" or "Disabled", kind = on and "ok" or "warn", duration = 1.4 })
						end)
					end
				end
			end
		end
	end)
	self:_connect(Input.InputEnded, function(i)
		if i.KeyCode == Enum.KeyCode.Unknown then
			return
		end
		for _, wd in ipairs(self:_bindsFor(i.KeyCode)) do
			if wd._held and wd.bindKey == i.KeyCode and wd.bindMode == "hold" then
				wd._held = false
				if wd.setState then
					task.spawn(wd.setState, wd._heldPrev and true or false)
				elseif wd.activate then
					task.spawn(wd.activate)
				end
				self:_refreshBindHUD()
			end
		end
	end)
	self:_ctxInit()
	if o.debug then self:SetVerbose(true) end
	self:Log("info", "created", self.title)
	if o.cursor then self:SetCursor(true, type(o.cursor) == "table" and o.cursor or nil) end
	if o.keybindHud then self:SetKeybindHUD(true, type(o.keybindHud) == "table" and o.keybindHud or nil) end

	local function reveal()
		self._loading = false
		if not self.visible then
			return
		end
		win.Visible = true
		win.Rotation = 0
		win.BackgroundTransparency = 0
		scale.Scale = 0.35
		tw(scale, E.Grow, { Scale = 1 })
	end
	if o.loader == false then
		reveal()
	else
		self._loading = true
		win.Visible = false
		self:_showLoader(o.loadTime or 2.6, reveal)
	end
	env.__EASYUI_ACTIVE = self
	return self
end

function UI:_showLoader(dur, done)
	dur = math.max(tonumber(dur) or 0, 0.01)
	local overlay = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 100,
		Parent = self.gui,
	})
	local sc = new("UIScale", { Scale = 0.95, Parent = overlay })
	local card = new("Frame", {
		Size = UDim2.fromOffset(240, 250),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		ZIndex = 101,
		Parent = overlay,
	})
	corner(18, card)
	stroke(Theme.Stroke, 1, 0.1, card)
	local title = label(self.title, 16, Theme.Text, Theme.Bold, card)
	title.Position = UDim2.new(0, 0, 0, 20)
	title.Size = UDim2.new(1, 0, 0, 20)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 102
	local beaker = new("Frame", {
		Size = UDim2.fromOffset(112, 112),
		Position = UDim2.new(0.5, 0, 0, 54),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 102,
		Parent = card,
	})
	corner(999, beaker)
	stroke(Theme.Soft, 1, 0, beaker)
	local fill = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = self._accent,
		BorderSizePixel = 0,
		ZIndex = 102,
		Parent = beaker,
	})
	local blobs = {}
	for i = 1, 3 do
		local b = new("Frame", {
			Size = UDim2.fromOffset(72, 72),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = self._accent,
			BorderSizePixel = 0,
			ZIndex = 102,
			Parent = fill,
		})
		corner(999, b)
		blobs[i] = b
	end
	local pct = label("0%", 18, Theme.Text, Theme.Bold, card)
	pct.Position = UDim2.new(0, 0, 0, 178)
	pct.Size = UDim2.new(1, 0, 0, 22)
	pct.TextXAlignment = Enum.TextXAlignment.Center
	pct.ZIndex = 102
	local subl = label("loading", 11, Theme.Sub, Theme.Mono, card)
	subl.Position = UDim2.new(0, 0, 0, 204)
	subl.Size = UDim2.new(1, 0, 0, 16)
	subl.TextXAlignment = Enum.TextXAlignment.Center
	subl.ZIndex = 102

	tw(overlay, E.Fast, { BackgroundTransparency = 0.4 })
	tw(sc, E.Pop, { Scale = 1 })

	local t0 = os.clock()
	local conn
	conn = self:_connect(Run.RenderStepped, function()
		if not overlay.Parent then
			conn:Disconnect()
			return
		end
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		local eased = 1 - (1 - a) * (1 - a)
		fill.Size = UDim2.new(1, 0, eased, 0)
		pct.Text = math.floor(eased * 100) .. "%"
		local now = os.clock()
		for i, b in ipairs(blobs) do
			local ph = i * 2.1
			b.Position = UDim2.new(0.5 + math.sin(now * 2.2 + ph) * 0.34, 0, 0, math.sin(now * 3.1 + ph) * 7)
		end
		if a >= 1 then
			conn:Disconnect()
			task.delay(0.12, function()
				if not overlay.Parent then
					return
				end
				if self._closing then
					overlay:Destroy()
					return
				end
				if done then
					done()
				end
				tw(sc, E.Smooth, { Scale = 1.06 })
				local out = tw(overlay, E.Smooth, { BackgroundTransparency = 1 })
				for _, d in ipairs(overlay:GetDescendants()) do
					if d:IsA("GuiObject") then
						pcall(function()
							tw(d, E.Smooth, { BackgroundTransparency = 1 })
						end)
					end
					if d:IsA("TextLabel") then
						tw(d, E.Smooth, { TextTransparency = 1 })
					elseif d:IsA("UIStroke") then
						tw(d, E.Smooth, { Transparency = 1 })
					end
				end
				out.Completed:Connect(function()
					overlay:Destroy()
				end)
			end)
		end
	end)
end

function UI:SetVisible(v, reason)
	v = v and true or false
	if self._cursorNative ~= nil then
		if v or self._cursorAlways then
			Input.MouseIconEnabled = false
		else
			Input.MouseIconEnabled = self._cursorNative
		end
	end
	if self._loading or v == self.visible then
		self.visible = v
		return
	end
	self.visible = v
	if not v then
		if self._openPicker then self._openPicker.Visible = false self._openPicker = nil self._openPickerSw = nil end
		self:_closeContext()
	end
	for _, window in pairs(self._windows) do
		window.frame.Visible = v and window.open
	end
	if v then
		self.window.Visible = true
		self.window.BackgroundTransparency = 0
		self._scale.Scale = 0.35
		tw(self.window, E.Grow, { Rotation = 0 })
		tw(self._scale, E.Grow, { Scale = 1 })
	elseif reason == "minimize" then
		tw(self.window, E.Shrink, { Rotation = -7 })
		local t = tw(self._scale, E.Shrink, { Scale = 0.02 })
		t.Completed:Connect(function()
			if not self.visible then
				self.window.Visible = false
				self.window.Rotation = 0
				self._scale.Scale = 1
			end
		end)
	else
		local t = tw(self._scale, E.Shrink, { Scale = 0.35 })
		t.Completed:Connect(function()
			if not self.visible then
				self.window.Visible = false
				self._scale.Scale = 1
			end
		end)
	end
end

function UI:Close()
	if self._closing or not self.gui.Parent then
		return
	end
	self._closing = true
	self:Log("info", "closing", self.title)
	self._dragMove, self._dragUp = nil, nil
	self:_setCapture(nil)
	self:SetCursor(false)
	if self._espLink then
		self._espLink:detach()
	end
	while next(self._features) do self:Drop(next(self._features)) end
	self:_cleanup()
	local env = typeof(getgenv) == "function" and getgenv() or _G
	if env.__EASYUI_ACTIVE == self then
		env.__EASYUI_ACTIVE = nil
	end
	local t = tw(self._scale, E.Smooth, { Scale = 0.7 })
	t.Completed:Connect(function()
		self.gui:Destroy()
	end)
end

function UI:SetAccent(c)
	self._accent = c
	self._dot.BackgroundColor3 = c
	if self._wmDot then
		self._wmDot.BackgroundColor3 = c
	end
	if self._cursor and not self._cursorCustom then
		self._cursor.BackgroundColor3 = c
	end
	for i = #self._accentUpdaters, 1, -1 do
		local entry = self._accentUpdaters[i]
		if entry[1] and entry[1]:IsDescendantOf(self.gui) then
			entry[2](c)
		else
			table.remove(self._accentUpdaters, i)
		end
	end
end

function UI:SetCursor(enabled, o)
	o = o or {}
	if not enabled then
		if self._cursorRemove then self._cursorRemove() self._cursorRemove = nil end
		if self._cursorPaint then self._cursorPaint:Disconnect() self._cursorPaint = nil end
		if self._cursor then self._cursor:Destroy() self._cursor = nil end
		if self._cursorNative ~= nil then Input.MouseIconEnabled = self._cursorNative self._cursorNative = nil end
		self._cursorEnabled, self._cursorAlways = false, false
		return
	end
	if self._cursorEnabled then
		self:SetCursor(false)
	end
	self._cursorEnabled, self._cursorAlways = true, o.always == true
	self._cursorCustom = o.color ~= nil
	self._cursorNative = Input.MouseIconEnabled
	Input.MouseIconEnabled = false
	if type(DrawingImmediate) == "table" and type(DrawingImmediate.GetPaint) == "function" and type(DrawingImmediate.FilledTriangle) == "function" then
		self._cursorPaint = DrawingImmediate.GetPaint(1000):Connect(function()
			if self.visible or o.always then
				local p, size = Input:GetMouseLocation(), o.size or 14
				DrawingImmediate.FilledTriangle(p, p + Vector2.new(0, size), p + Vector2.new(size * 0.7, size * 0.7), o.color or self._accent, 1)
			end
		end)
		return self._cursorPaint
	end
	local cursor = new("Frame", { Size = UDim2.fromOffset(o.size or 12, o.size or 12), AnchorPoint = Vector2.new(0, 0), Rotation = 45, BackgroundColor3 = o.color or self._accent, BorderSizePixel = 0, ZIndex = Layers.cursor, Parent = self.gui })
	corner(2, cursor)
	stroke(Color3.new(0, 0, 0), 1, 0.25, cursor)
	self._cursor = cursor
	self._cursorRemove = self:Schedule("__cursor", function()
		local p = Input:GetMouseLocation()
		cursor.Position = UDim2.fromOffset(p.X, p.Y)
		cursor.Visible = self.visible or o.always
	end, nil, 1000)
	return cursor
end

function UI:_refreshBindHUD()
	self._bindIndexDirty = true
	if not self._bindHud or self._bindHudPending then return end
	self._bindHudPending = true
	task.defer(function()
		self._bindHudPending = false
		if self._bindHud and self._bindHud.Parent then
			self:_refreshBindHUDNow()
		end
	end)
end

function UI:_refreshBindHUDNow()
	local rows = self._bindHudRows
	if not rows then
		rows = {}
		self._bindHudRows = rows
	end
	local count = 0
	for _, widget in ipairs(self.widgets) do
		if widget.bindKey and widget.activate and (not widget.row or widget.row:IsDescendantOf(self.gui)) then
			count += 1
			local state = widget.getState and widget.getState()
			local col = widget.opt and widget.opt.hudColor
			if type(col) == "function" then
				local ok, result = pcall(col, state)
				col = ok and result or nil
			end
			if typeof(col) ~= "Color3" then
				col = state and Theme.Ok or Theme.Sub
			end
			local row = rows[count]
			if not row or row.Parent ~= self._bindHudBody then
				row = label("", 11, col, Theme.Mono, self._bindHudBody)
				row.Size = UDim2.new(1, 0, 0, 16)
				rows[count] = row
			end
			row.LayoutOrder = count
			row.Text = "[" .. widget.bindKey.Name .. "]  " .. ((widget.opt and widget.opt.text) or widget.kind)
			row.TextColor3 = col
			row.Visible = true
		end
	end
	for i = count + 1, #rows do
		rows[i].Visible = false
	end
	self._bindHud.Size = UDim2.fromOffset(220, 34 + count * 18)
	self._bindHud.Visible = count > 0
end

function UI:SetKeybindHUD(enabled, o)
	o = o or {}
	if not enabled then
		if self._bindHud then self._bindHud:Destroy() self._bindHud = nil end
		self._bindHudRows = nil
		return
	end
	if self._bindHud then
		self._bindHud:Destroy()
		self._bindHud = nil
	end
	self._bindHudRows = nil
	local hud = new("Frame", { Size = UDim2.fromOffset(220, 34), Position = o.position or UDim2.new(0, 16, 0, 54), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ZIndex = Layers.hud, Parent = self.gui })
	corner(10, hud)
	stroke(Theme.Stroke, 1, 0.1, hud)
	draggable(self, hud, hud, nil, { hud = true, guides = true })
	local title = label(o.title or "Keybinds", 12, Theme.Text, Theme.Bold, hud)
	title.Position = UDim2.new(0, 10, 0, 4)
	title.Size = UDim2.new(1, -20, 0, 20)
	local body = new("Frame", { Size = UDim2.new(1, -20, 1, -28), Position = UDim2.new(0, 10, 0, 26), BackgroundTransparency = 1, Parent = hud })
	list(body, 2)
	self._bindHud, self._bindHudBody = hud, body
	self:_refreshBindHUDNow()
	return hud
end

function UI:Animate(instance, preset, props)
	local old = self._tweens[instance]
	if old then
		old:Cancel()
	end
	local tween = tw(instance, type(preset) == "string" and (E[preset] or E.Smooth) or preset or E.Smooth, props)
	self._tweens[instance] = tween
	return tween
end

function UI:Schedule(name, callback, fps, priority)
	name = tostring(name)
	local scheduled = { fn = callback, step = fps and fps > 0 and 1 / fps or 0, elapsed = 0, priority = priority or 0 }
	self._jobs[name] = scheduled
	self._jobsDirty = true
	if not self._jobConnection then
		self._jobConnection = self:_connect(Run.RenderStepped, function(dt)
			if self._jobsDirty then
				self._jobOrder = {}
				for key, job in pairs(self._jobs) do
					self._jobOrder[#self._jobOrder + 1] = { key, job }
				end
				table.sort(self._jobOrder, function(a, b)
				return a[2].priority > b[2].priority
				end)
				self._jobsDirty = false
			end
			for _, pair in ipairs(self._jobOrder) do
				local job = pair[2]
				if self._jobs[pair[1]] == job then
					job.elapsed += dt
					if job.elapsed >= job.step then
						local elapsed = job.elapsed
						job.elapsed = job.step > 0 and job.elapsed % job.step or 0
						local ok, err = pcall(job.fn, elapsed)
						if not ok then
							self._jobs[pair[1]] = nil
							self._jobsDirty = true
							warn("[EasyUI] " .. tostring(err))
							if not next(self._jobs) and self._jobConnection then self._jobConnection:Disconnect() self._jobConnection = nil end
						end
					end
				end
			end
		end)
	end
	return function()
		if self._jobs[name] == scheduled then
			self._jobs[name] = nil
			self._jobsDirty = true
			if not next(self._jobs) and self._jobConnection then self._jobConnection:Disconnect() self._jobConnection = nil end
		end
	end
end

function UI:Every(name, interval, callback, priority)
	interval = math.max(tonumber(interval) or 0, 0)
	return self:Schedule(name, callback, interval > 0 and 1 / interval or nil, priority)
end

function UI:Batch(name, items, worker, options)
	options = options or {}
	name = tostring(name)
	local replaced = self._batches[name]
	if replaced then
		replaced.running = false
	end
	local index, count = 1, #items
	local handle = { running = true, processed = 0, total = count }
	self._batches[name] = handle
	local remove
	remove = self:Every("batch:" .. tostring(name), options.interval or 0.01, function()
		if not handle.running then
			return
		end
		local deadline = os.clock() + (options.budget or 0.002)
		local chunk = options.chunk or 50
		local done = 0
		while index <= count and done < chunk and os.clock() < deadline do
			local ok, err = pcall(worker, items[index], index, handle)
			if not ok then
				handle.running, handle.error = false, err
				remove()
				warn("[EasyUI] " .. tostring(err))
				return
			end
			index += 1
			done += 1
			handle.processed = index - 1
		end
		if index > count then
			handle.running = false
			remove()
			if options.done then
				options.done(handle)
			end
		end
	end, options.priority)
	function handle:Pause()
		self.running = false
	end
	function handle:Resume()
		if index <= count then
			self.running = true
		end
	end
	function handle:Cancel()
		self.running = false
		remove()
	end
	return handle
end

function UI:Queue(name, priority, callback)
	if type(priority) == "function" then
		callback, priority = priority, 0
	end
	name = name and tostring(name) or nil
	local old = name and self._queued[name]
	if old then
		old.cancelled = true
		for i = #self._queue, 1, -1 do if self._queue[i] == old then table.remove(self._queue, i) break end end
	end
	self._queueSeq += 1
	local job = { name = name, priority = priority or 0, seq = self._queueSeq, fn = callback }
	self._queue[#self._queue + 1] = job
	if name then
		self._queued[name] = job
	end
	if not self._queueRunning then
		self._queueRunning = true
		task.spawn(function()
			while not self._closing and #self._queue > 0 do
				local best = 1
				for i = 2, #self._queue do
					local candidate, current = self._queue[i], self._queue[best]
					if candidate.priority > current.priority or candidate.priority == current.priority and candidate.seq < current.seq then
						best = i
					end
				end
				local nextJob = table.remove(self._queue, best)
				if nextJob.name and self._queued[nextJob.name] == nextJob then
					self._queued[nextJob.name] = nil
				end
				if not nextJob.cancelled then
					local done, ok, err = false, nil, nil
					nextJob.thread = task.spawn(function()
						ok, err = pcall(nextJob.fn)
						done = true
					end)
					while not done and not nextJob.cancelled do task.wait() end
					if nextJob.cancelled and not done then pcall(task.cancel, nextJob.thread) end
					if done and not ok then warn("[EasyUI] " .. tostring(err)) end
				end
				task.wait()
			end
			self._queueRunning = false
		end)
	end
	return function()
		job.cancelled = true
		if job.thread then pcall(task.cancel, job.thread) end
		for i = #self._queue, 1, -1 do if self._queue[i] == job then table.remove(self._queue, i) break end end
		if name and self._queued[name] == job then self._queued[name] = nil end
	end
end

function UI:Use(name, feature)
	name = tostring(name)
	self:Drop(name)
	local folder = new("Folder", { Name = name, Archivable = false, Parent = self._runtimeFolder })
	local entry = { folder = folder, owned = {}, enabled = true }
	self._features[name] = entry
	local function own(value)
		entry.owned[#entry.owned + 1] = value
		return value
	end
	local ok, value = pcall(function()
		if type(feature) == "function" then
			return feature(self, folder, own)
		end
		return feature
	end)
	if not ok then
		for i = #entry.owned, 1, -1 do pcall(dispose, entry.owned[i]) end
		if self._features[name] == entry then self._features[name] = nil end
		folder:Destroy()
		error(value, 0)
	end
	entry.value = value
	local start = type(value) == "table" and (value.Start or value.start)
	if start then
		local started, err = pcall(start, value)
		if not started then
			self:Drop(name)
			error(err, 0)
		end
	end
	self:Log("debug", "feature +", name)
	local flag = "features." .. name .. ".enabled"
	local seeded = self.flags[flag]
	self.flags[flag] = true
	self._flagWidgets[flag] = { Set = function(_, enabled)
		self:SetFeatureEnabled(name, enabled)
	end, Get = function()
		return entry.enabled
	end }
	if seeded == false then
		self:SetFeatureEnabled(name, false)
	end
	return value
end

function UI:Drop(name)
	local entry = self._features[tostring(name)]
	if not entry then
		return false
	end
	self._features[tostring(name)] = nil
	self:Log("debug", "feature -", name)
	local value = entry.value
	pcall(dispose, value)
	for i = #entry.owned, 1, -1 do
		pcall(dispose, entry.owned[i])
	end
	entry.folder:Destroy()
	self.flags["features." .. tostring(name) .. ".enabled"] = nil
	self._flagWidgets["features." .. tostring(name) .. ".enabled"] = nil
	return true
end

function UI:GetFeature(name)
	local entry = self._features[tostring(name)]
	return entry and entry.value
end

function UI:SetFeatureEnabled(name, enabled)
	local entry = self._features[tostring(name)]
	if not entry then
		return false
	end
	enabled = enabled and true or false
	if entry.enabled == enabled then return true end
	entry.enabled = enabled
	self.flags["features." .. tostring(name) .. ".enabled"] = entry.enabled
	local value = entry.value
	local set = type(value) == "table" and (value.SetEnabled or value.Enable)
	if set then
		pcall(set, value, entry.enabled)
	else
		local fn
		if type(value) == "table" then
			if entry.enabled then
				fn = value.Start or value.start
			else
				fn = value.Stop or value.stop
			end
		end
		if fn then
			pcall(fn, value)
		end
	end
	return true
end

function UI:Exec(name, source, options)
	options = options or {}
	local owner = self
	local handle = { status = "queued", cancelled = false }
	handle.cancel = self:Queue("script:" .. tostring(name), options.priority or 0, function()
		handle.status = "running"
		local ok, result = pcall(function()
			return self:Use(name, function(ui, folder, own)
				local ctx = {
					UI = ui,
					Folder = folder,
					Own = own,
					Get = function(_, flag) return ui:Get(flag) end,
					Set = function(_, flag, value) return ui:Set(flag, value) end,
					Queue = function(_, key, priority, fn) return own(ui:Queue(key, priority, fn)) end,
					Schedule = function(_, key, fn, fps, priority) return own(ui:Schedule(key, fn, fps, priority)) end,
					Every = function(_, key, interval, fn, priority) return own(ui:Every(key, interval, fn, priority)) end,
					Batch = function(_, key, items, fn, opt) return own(ui:Batch(key, items, fn, opt)) end,
					Window = function(_, id, opt) return own(ui:Window(id, opt)) end,
					Notify = function(_, opt) return ui:Notify(opt) end,
				}
				local loaded = source
				if typeof(source) == "Instance" and source:IsA("ModuleScript") then
					loaded = require(source)
				elseif type(source) == "string" then
					local code = source:match("^https?://") and game:HttpGet(source) or source
					local chunk, err = loadstring(code, "EasyUI:" .. tostring(name))
					if not chunk then
						error(err, 0)
					end
					loaded = chunk()
				end
				if type(loaded) == "function" then
					return loaded(ctx)
				end
				return loaded
			end)
		end)
		if handle.cancelled then
			self:Drop(name)
			return
		end
		handle.status = ok and "loaded" or "failed"
		if ok then
			handle.value, handle.error = result, nil
		else
			handle.value, handle.error = nil, result
		end
		self:Log(ok and "info" or "error", "exec", name, handle.status, not ok and tostring(result) or "")
		if not ok then
			warn("[EasyUI] " .. tostring(result))
		end
	end)
	handle._dequeue = handle.cancel
	function handle:Cancel()
		self.cancelled = true
		self._dequeue()
		owner:Drop(name)
		self.status = "cancelled"
	end
	return handle
end

function UI:ImportFeature(name, source, options)
	return self:Exec(name, source, options)
end

function UI:ImportHUD(name, source, options)
	return self:Exec("hud:" .. tostring(name), source, options)
end

function UI:HUD(name, o)
	local builder = UI._hudBuilders[tostring(name)]
	assert(builder, "Unknown HUD: " .. tostring(name))
	return self:Use("hud:" .. tostring(name), function(ui, folder, own)
		return builder(ui, o or {}, folder, own)
	end)
end

function UI:GameInfo()
	local info = self._gameInfo
	if not info then
		info = {
			placeId = game.PlaceId,
			gameId = game.GameId,
			jobId = game.JobId,
			name = ("Place %d"):format(game.PlaceId),
			creator = "",
			maxPlayers = Players.MaxPlayers,
		}
		pcall(function()
			local data = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
			if data then
				info.name = data.Name or info.name
				info.description = data.Description
				info.creator = data.Creator and data.Creator.Name or ""
			end
		end)
		self._gameInfo = info
	end
	info.players = #Players:GetPlayers()
	return info
end

function UI:Attach(instance, layer)
	instance.ZIndex = type(layer) == "number" and layer or (Layers[layer] or Layers.window)
	instance.Parent = self.gui
	return instance
end

function UI:Mount(name, root)
	assert(type(root) == "table", "Mount root must be a table")
	self._mounts[tostring(name)] = root
	return root
end

function UI:Unmount(name)
	local root = self._mounts[tostring(name)]
	self._mounts[tostring(name)] = nil
	self._validators[tostring(name)] = nil
	return root
end

function UI:_read(flag)
	local root, path = tostring(flag):match("^([^.]+)%.(.+)$")
	if root and self._mounts[root] then
		return pathGet(self._mounts[root], path)
	end
	return self.flags[flag]
end

function UI:_write(flag, value)
	local root, path = tostring(flag):match("^([^.]+)%.(.+)$")
	if root and self._mounts[root] then
		local validate = self._validators[root]
		if validate then
			local ok, validated = pcall(validate, path, value)
			if ok and validated ~= nil then
				value = validated
			end
		end
		return pathSet(self._mounts[root], path, value)
	end
	self.flags[flag] = value
	return value
end

function UI:Get(flag)
	return self:_read(flag)
end

function UI:Set(flag, v)
	local api = self._flagWidgets[flag]
	if api and api.Set then
		api:Set(v)
	else
		self:_write(flag, v)
	end
	return self:_read(flag)
end

function UI:Sync(prefix)
	local lead = prefix and (tostring(prefix) .. ".") or nil
	for flag, api in pairs(self._flagWidgets) do
		if not lead or flag:sub(1, #lead) == lead then
			local value = self:_read(flag)
			if value ~= nil and api.Set and (not api.Get or api:Get() ~= value) then
				pcall(api.Set, api, value)
			end
		end
	end
end

function UI:ExportConfig()
	local values, binds, mounts = packValue(self.flags), {}, {}
	for name, root in pairs(self._mounts) do mounts[name] = packValue(root) end
	for flag, api in pairs(self._flagWidgets) do
		if api.Get then
			values[flag] = packValue(api:Get())
		end
	end
	for _, widget in ipairs(self.widgets) do
		local bindId = widget.opt and (widget.opt.bindId or widget.opt.flag or widget.opt.id or widget.opt.text)
		if bindId and (widget.activate or widget.kind == "keybind") then
			binds[tostring(bindId)] = widget.bindKey and packValue(widget.bindKey) or { __t = "n" }
		end
	end
	return Http:JSONEncode({ version = 1, values = values, binds = binds, mounts = mounts, accent = packValue(self._accent) })
end

function UI:ImportConfig(json)
	local ok, data = pcall(Http.JSONDecode, Http, json)
	if not ok or type(data) ~= "table" or data.version ~= 1 or data.values ~= nil and type(data.values) ~= "table" or data.binds ~= nil and type(data.binds) ~= "table" or data.mounts ~= nil and type(data.mounts) ~= "table" then
		return false
	end
	local function mergeInto(target, source)
		for key, value in pairs(source) do
			local resolved = pathKey(target, key)
			if type(value) == "table" and type(target[resolved]) == "table" then
				mergeInto(target[resolved], value)
			else
				target[resolved] = value
			end
		end
	end
	for name, packed in pairs(data.mounts or {}) do
		local root, decoded = self._mounts[name], unpackValue(packed)
		if root and type(decoded) == "table" then
			mergeInto(root, decoded)
		end
	end
	for flag, packed in pairs(data.values or {}) do
		pcall(self.Set, self, flag, unpackValue(packed))
	end
	for _, widget in ipairs(self.widgets) do
		local bindId = widget.opt and (widget.opt.bindId or widget.opt.flag or widget.opt.id or widget.opt.text)
		local packed = bindId and data.binds and data.binds[tostring(bindId)]
		if packed then
			local key = unpackValue(packed)
			if widget.setBind then widget.setBind(key) else widget.bindKey = key end
		end
	end
	for name in pairs(data.mounts or {}) do self:Sync(name) end
	self:_refreshBindHUD()
	local accent = unpackValue(data.accent)
	if typeof(accent) == "Color3" then
		self:SetAccent(accent)
	end
	return true
end

function UI:SaveConfig(name)
	if type(writefile) ~= "function" then
		return false
	end
	if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("EasyUI") then
		makefolder("EasyUI")
	end
	return (pcall(writefile, "EasyUI/" .. safeName(name) .. ".json", self:ExportConfig()))
end

function UI:LoadConfig(name)
	if type(readfile) ~= "function" then
		return false
	end
	local path = "EasyUI/" .. safeName(name) .. ".json"
	if type(isfile) == "function" and not isfile(path) then
		return false
	end
	local ok, json = pcall(readfile, path)
	return ok and self:ImportConfig(json)
end

function UI:DeleteConfig(name)
	if type(delfile) ~= "function" then return false end
	local path = "EasyUI/" .. safeName(name) .. ".json"
	if type(isfile) == "function" and not isfile(path) then return false end
	return (pcall(delfile, path))
end

function UI:ListConfigs()
	if type(listfiles) ~= "function" then return {} end
	local ok, files = pcall(listfiles, "EasyUI")
	if not ok then return {} end
	local out = {}
	for _, path in ipairs(files) do
		local name = path:match("([^/\\]+)%.json$")
		if name and name ~= "autoload" then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

function UI:SetAutoload(name)
	if type(writefile) ~= "function" then return false end
	if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("EasyUI") then makefolder("EasyUI") end
	return (pcall(writefile, "EasyUI/autoload.json", safeName(name)))
end

function UI:LoadAutoload()
	if type(readfile) ~= "function" or type(isfile) == "function" and not isfile("EasyUI/autoload.json") then return false end
	local ok, name = pcall(readfile, "EasyUI/autoload.json")
	return ok and self:LoadConfig(name)
end

function UI:ConfigTab(o)
	o = o or {}
	local tab = self:Tab(o.title or "Configs")
	local section = tab:Section(o.section or "Profiles")
	local chosen

	local current = section:Label("Current: none")
	local name = section:Textbox({ text = "Name", placeholder = "new profile...", default = "" })

	local listCard = new("Frame", { Size = UDim2.new(1, 0, 0, 108), BackgroundColor3 = Theme.Control, BorderSizePixel = 0, Parent = section._card })
	corner(8, listCard)
	stroke(Theme.Soft, 1, 0, listCard)
	local scroll = new("ScrollingFrame", { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke, CanvasSize = UDim2.new(), Parent = listCard })
	local slist = list(scroll, 3)
	slist:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, slist.AbsoluteContentSize.Y + 4)
	end)

	local function setCurrent(value)
		chosen = value
		current.Text = "Current: " .. (value or "none")
	end
	local function target()
		local typed = name:Get()
		if typed ~= "" then
			return typed
		end
		return chosen or "default"
	end
	local rebuild
	rebuild = function()
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local names = self:ListConfigs()
		if #names == 0 then
			local empty = label("no saved configs", 12, Theme.Muted, Theme.Font, scroll)
			empty.Size = UDim2.new(1, 0, 0, 22)
			empty.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		for _, cfg in ipairs(names) do
			local sel = cfg == chosen
			local row = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.Hover, BackgroundTransparency = sel and 0 or 1, BorderSizePixel = 0, Parent = scroll })
			corner(6, row)
			local rl = label(cfg, 12, sel and Theme.Text or Theme.Sub, Theme.Font, row)
			rl.Position = UDim2.new(0, 10, 0, 0)
			rl.Size = UDim2.new(1, -12, 1, 0)
			row.MouseEnter:Connect(function()
				if cfg ~= chosen then
					tw(row, E.Fast, { BackgroundTransparency = 0.5 })
				end
			end)
			row.MouseLeave:Connect(function()
				if cfg ~= chosen then
					tw(row, E.Fast, { BackgroundTransparency = 1 })
				end
			end)
			row.MouseButton1Click:Connect(function()
				setCurrent(cfg)
				name:Set("")
				rebuild()
			end)
		end
	end
	rebuild()

	section:Button({ text = "Save", callback = function()
		local p = target()
		self:SaveConfig(p)
		setCurrent(p)
		name:Set("")
		rebuild()
	end })
	section:Button({ text = "Load", callback = function()
		local p = target()
		if self:LoadConfig(p) then
			setCurrent(p)
			rebuild()
		end
	end })
	section:Button({ text = "Delete", callback = function()
		local p = target()
		self:DeleteConfig(p)
		if chosen == p then
			setCurrent(nil)
		end
		name:Set("")
		rebuild()
	end })
	section:Button({ text = "Set Autoload", callback = function() self:SetAutoload(target()) end })
	return tab
end

UI.CFG = UI.ExportConfig
UI.ICFG = UI.ImportConfig
UI.SCFG = UI.SaveConfig
UI.LCFG = UI.LoadConfig

function UI:_pruneWidgets()
	local removedFlags = {}
	for i = #self.widgets, 1, -1 do
		local wd = self.widgets[i]
		if wd.row and not wd.row:IsDescendantOf(self.gui) then
			if wd.opt and wd.opt.flag then
				removedFlags[wd.opt.flag] = true
			end
			table.remove(self.widgets, i)
		end
	end
	for _, wd in ipairs(self.widgets) do
		if wd.opt and wd.opt.flag then
			removedFlags[wd.opt.flag] = nil
		end
	end
	for flag in pairs(removedFlags) do
		self._flagWidgets[flag] = nil
	end
	for i = #self._accentUpdaters, 1, -1 do
		local entry = self._accentUpdaters[i]
		if not (entry[1] and entry[1]:IsDescendantOf(self.gui)) then
			table.remove(self._accentUpdaters, i)
		end
	end
	self:_refreshBindHUD()
end

function UI:_reg(wd)
	if self._ctxHold and wd.row and wd.row:IsDescendantOf(self._ctxHold) then
		return wd
	end
	self.widgets[#self.widgets + 1] = wd
	local hasKeybind = wd.activate and not wd.noKeybind and not (wd.opt and wd.opt.noKeybind)
	if wd.row and (hasKeybind or (wd.opt and wd.opt.context)) then
		wd.row.Active = true
		wd.row.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton2 then
				self:_openContext(wd)
			end
		end)
	end
	self:_refreshBindHUD()
	return wd
end

local function makeStrip(parent, y, inset)
	local strip = new("ScrollingFrame", {
		Size = UDim2.new(1, -inset * 2, 0, 30),
		Position = UDim2.new(0, inset, 0, y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Stroke,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		Parent = parent,
	})
	local layout = list(strip, 6, Enum.FillDirection.Horizontal)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		strip.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X, 0, 0)
	end)
	return strip
end

local function addTab(m, scope, name)
	local btn = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(math.max(58, textWidth(name, 13, Theme.Font) + 26), 26),
		BackgroundColor3 = Theme.Control,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = (scope._tabOrder or 0) + 1,
		Parent = scope._strip,
	})
	scope._tabOrder = (scope._tabOrder or 0) + 1
	corner(8, btn)
	local tl = label(name, 13, Theme.Sub, Theme.Font, btn)
	tl.Size = UDim2.fromScale(1, 1)
	tl.TextXAlignment = Enum.TextXAlignment.Center
	local mark = new("Frame", {
		Size = UDim2.new(1, -20, 0, 2),
		Position = UDim2.new(0, 10, 1, -3),
		BackgroundColor3 = m._accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = btn,
	})
	corner(999, mark)
	m._accentUpdaters[#m._accentUpdaters + 1] = { mark, function(c)
		mark.BackgroundColor3 = c
	end }

	local page = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = scope._holder })
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Parent = page })
	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		Parent = holder,
	})
	pad(14, scroll, 14, 12, 14, 16)
	local pl = list(scroll, 12)
	pl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, pl.AbsoluteContentSize.Y + 28)
	end)

	local tab = { button = btn, mark = mark, label = tl, page = page, _holder = holder, scroll = scroll, tabs = {}, scope = scope, parent = scope.page and scope or nil }
	scope.tabs[#scope.tabs + 1] = tab

	local function activate()
		scope.activeTab = tab
		for _, t in ipairs(scope.tabs) do
			t.page.Visible = false
			tw(t.mark, E.Fast, { BackgroundTransparency = 1 })
			tw(t.label, E.Fast, { TextColor3 = Theme.Sub })
		end
		page.Visible = true
		tw(mark, E.Fast, { BackgroundTransparency = 0 })
		tw(tl, E.Fast, { TextColor3 = Theme.Text })
		if #tab.tabs > 0 then
			(tab.activeTab or tab.tabs[1]).activate()
		end
	end
	tab.activate = activate
	btn.MouseButton1Click:Connect(activate)
	btn.MouseEnter:Connect(function()
		if not page.Visible then
			tw(tl, E.Fast, { TextColor3 = Theme.Text })
		end
	end)
	btn.MouseLeave:Connect(function()
		if not page.Visible then
			tw(tl, E.Fast, { TextColor3 = Theme.Sub })
		end
	end)
	if #scope.tabs == 1 then
		task.defer(function()
			if not scope.activeTab and btn.Parent then
				activate()
			end
		end)
	end
	return setmetatable({ _m = m, _page = scroll, _entry = tab, _scope = scope }, { __index = UI._Tab })
end

function UI:Tab(name)
	return addTab(self, self, name)
end

function UI._Tab:SubTab(name)
	local entry = self._entry
	if not entry._strip then
		entry._strip = makeStrip(entry.page, 4, 12)
		entry._holder.Position = UDim2.new(0, 0, 0, 38)
		entry._holder.Size = UDim2.new(1, 0, 1, -38)
		entry.scroll.Visible = false
	end
	return addTab(self._m, entry, name)
end

UI._Tab.Tab = UI._Tab.SubTab

function UI._Tab:Open()
	local chain, entry = {}, self._entry
	while entry do
		table.insert(chain, 1, entry)
		entry = entry.parent
	end
	local rootScope = chain[1] and chain[1].scope
	if rootScope and rootScope.frame and rootScope.Open then
		rootScope:Open()
	end
	for _, tab in ipairs(chain) do
		tab.activate()
	end
	return self
end

function UI:Window(id, o)
	o = o or {}
	id = tostring(id)
	local old = self._windows[id]
	if old then
		return old
	end
	local minWidth = tonumber(o.minWidth) or 280
	local maxWidth = math.max(minWidth, tonumber(o.maxWidth) or 960)
	local minHeight = tonumber(o.minHeight) or 220
	local maxHeight = math.max(minHeight, tonumber(o.maxHeight) or 720)
	local w = math.clamp(o.width or 360, minWidth, maxWidth)
	local h = math.clamp(o.height or 320, minHeight, maxHeight)
	local frame = new("Frame", {
		Name = id,
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.fromOffset(o.x or 80, o.y or 80),
		BackgroundColor3 = Theme[o.style == "card" and "Card" or o.style == "panel" and "Panel" or "Window"],
		BorderSizePixel = 0,
		Visible = o.open ~= false and self.visible,
		Parent = self.gui,
	})
	corner(o.radius or 12, frame)
	stroke(Theme.Stroke, 1, 0.1, frame)
	local scale = new("UIScale", { Scale = 1, Parent = frame })
	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = frame })
	local header = o.header == false and "" or type(o.header) == "table" and o.header.text or o.header or id
	local title = label(header, 13, Theme.Text, Theme.Bold, bar)
	title.Position = UDim2.new(0, 14, 0, 0)
	title.Size = UDim2.new(1, -50, 1, 0)
	local strip = makeStrip(frame, 40, 12)
	local content = new("Frame", { Size = UDim2.new(1, 0, 1, -76), Position = UDim2.new(0, 0, 0, 76), BackgroundTransparency = 1, ClipsDescendants = true, Parent = frame })
	local window = setmetatable({ _m = self, id = id, flag = o.flag, frame = frame, scale = scale, _strip = strip, _holder = content, tabs = {}, open = o.open ~= false, minWidth = minWidth, maxWidth = maxWidth, minHeight = minHeight, maxHeight = maxHeight }, UI._Window)
	self._windows[id] = window
	resizeGrip(self, frame, { resizable = o.resizable, minWidth = minWidth, maxWidth = maxWidth, minHeight = minHeight, maxHeight = maxHeight }, function()
		if o.flag then
			self:_write(o.flag, window:GetState())
		end
	end)
	draggable(self, bar, frame, function()
		if o.flag then
			self:_write(o.flag, window:GetState())
		end
	end, { guides = true })
	if o.close ~= false then
		local close = new("TextButton", { Text = "×", TextSize = 18, TextColor3 = Theme.Sub, Font = Theme.Font, AutoButtonColor = false, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0, 5), BackgroundColor3 = Theme.Control, BorderSizePixel = 0, Parent = bar })
		corner(8, close)
		hover(close, Theme.Control, Theme.Hover)
		close.MouseButton1Click:Connect(function() window:Close() end)
	end
	if o.flag then
		local stored = self:_read(o.flag)
		if type(stored) == "table" then
			window:Set(stored)
		else
			self.flags[o.flag] = window:GetState()
		end
		self._flagWidgets[o.flag] = window
	end
	if frame.Visible and o.animation ~= false then
		scale.Scale = 0.9
		tw(scale, E.Pop, { Scale = 1 })
	end
	return window
end

function UI._Window:Tab(name)
	return addTab(self._m, self, name)
end

function UI._Window:SetVisible(visible)
	self.open = visible and true or false
	if self.open then
		self.frame.Visible = self._m.visible
		self.scale.Scale = 0.9
		tw(self.scale, E.Pop, { Scale = 1 })
	else
		if self._m._openPicker then self._m._openPicker.Visible = false self._m._openPicker = nil self._m._openPickerSw = nil end
		local out = tw(self.scale, E.Fast, { Scale = 0.9 })
		out.Completed:Connect(function()
			if not self.open and self.frame.Parent then self.frame.Visible = false end
		end)
	end
	if self.flag then self._m:_write(self.flag, self:GetState()) end
end

function UI._Window:Open() self:SetVisible(true) end
function UI._Window:Close() self:SetVisible(false) end
function UI._Window:GetVisible() return self.open end
function UI._Window:GetFrame() return self.frame end
function UI._Window:GetState()
	return { x = self.frame.Position.X.Offset, y = self.frame.Position.Y.Offset, width = self.frame.Size.X.Offset, height = self.frame.Size.Y.Offset, open = self.open }
end
function UI._Window:Get() return self:GetState() end
function UI._Window:Set(state)
	if type(state) ~= "table" then return end
	self.frame.Position = UDim2.fromOffset(tonumber(state.x) or self.frame.Position.X.Offset, tonumber(state.y) or self.frame.Position.Y.Offset)
	self.frame.Size = UDim2.fromOffset(
		math.clamp(tonumber(state.width) or self.frame.Size.X.Offset, self.minWidth, self.maxWidth),
		math.clamp(tonumber(state.height) or self.frame.Size.Y.Offset, self.minHeight, self.maxHeight)
	)
	self:SetVisible(state.open ~= false)
end
function UI._Window:Destroy()
	self._m._windows[self.id] = nil
	if self.flag then
		self._m._flagWidgets[self.flag] = nil
		self._m.flags[self.flag] = nil
	end
	self.frame:Destroy()
	self._m:_pruneWidgets()
end

function UI:GetWindow(id) return self._windows[tostring(id)] end
function UI:OpenWindow(id) local w = self:GetWindow(id) if w then w:Open() end return w end
function UI:CloseWindow(id) local w = self:GetWindow(id) if w then w:Close() end return w end

function UI:AttachESP(esp, o)
	o = o or {}
	if self._espLink then self._espLink:detach() end
	assert(type(esp) == "table" and type(esp.cfg) == "table", "AttachESP needs an EasyESP instance")
	local prefix = tostring(o.prefix or "esp")
	self:Mount(prefix, esp.cfg)
	self._validators[prefix] = esp.Validate and function(path, value) return esp:Validate(path, value) end or nil
	local link = { ui = self, esp = esp, prefix = prefix, tabs = {}, flags = {}, widgets = {}, own = o.own == true }
	if o.enabled ~= false and esp.on then esp:on(true) end
	if o.start ~= false and esp.start then
		local wasRunning = esp.running == true
		esp:start()
		link.started = not wasRunning
	end
	if o.build ~= false and esp.GetDescriptors then
		local nodes, sections, windows = {}, {}, {}
		local function node(scope, parent, key)
			local full = (parent and parent._key or tostring(scope.id or "main")) .. "/" .. key
			if not nodes[full] then
				nodes[full] = parent and parent:SubTab(key) or scope:Tab(key)
				nodes[full]._key = full
				if not parent then link.tabs[#link.tabs + 1] = nodes[full] end
			end
			return nodes[full]
		end
		for _, d in ipairs(esp:GetDescriptors()) do
			local windowName = tostring(d.window or "ESP")
			local scope = self
			if not o.singleWindow then
				if not windows[windowName] then
					local index = 0
					for _ in pairs(windows) do index += 1 end
					windows[windowName] = self:Window("__esp:" .. windowName, { x = 80 + index * 28, y = 70 + index * 24, width = o.width or 430, height = o.height or 390, header = windowName, open = o.open ~= false })
				end
				scope = windows[windowName]
			end
			local topName = o.singleWindow and windowName or tostring(d.tab or "Main")
			local top = node(scope, nil, topName)
			local current = o.singleWindow and d.tab and node(scope, top, tostring(d.tab)) or top
			current = d.subtab and node(scope, current, tostring(d.subtab)) or current
			local sectionKey = current._key .. "/" .. tostring(d.section or "Main")
			sections[sectionKey] = sections[sectionKey] or current:Section(d.section or "Main")
			local flag = prefix .. "." .. d.path
			local opt = { text = d.label or d.path, flag = flag, default = pathGet(esp.cfg, d.path), min = d.min, max = d.max, step = d.step, decimals = d.decimals, options = d.items, noKeybind = d.bindable == false }
			local method = d.kind == "toggle" and "Toggle" or d.kind == "slider" and "Slider" or (d.kind == "dropdown" or d.kind == "mode") and "Dropdown" or d.kind == "color" and "Colorpicker" or d.kind == "keybind" and "Keybind"
			if method then
				local before = #self.widgets
				sections[sectionKey][method](sections[sectionKey], opt)
				for wi = before + 1, #self.widgets do
					link.widgets[#link.widgets + 1] = self.widgets[wi]
				end
				link.flags[#link.flags + 1] = flag
			end
		end
		link.windows = windows
	end
	function link:sync() self.ui:Sync(self.prefix) end
	function link:SetEnabled(enabled) if self.esp.on then self.esp:on(enabled) end end
	function link:applyTheme(name) if self.esp.theme then self.esp:theme(name) self:sync() end end
	function link:applySetup(name) if self.esp.preset then self.esp:preset(name) self:sync() end end
	function link:save(name) return self.esp.save and self.esp:save(name) end
	function link:load(name) local ok = self.esp.load and self.esp:load(name) self:sync() return ok end
	function link:detach()
		if self.detached then return false end
		self.detached = true
		for _, tab in ipairs(self.tabs) do if tab._entry.button.Parent then tab:Destroy() end end
		for _, window in pairs(self.windows or {}) do window:Destroy() end
		local generated = {}
		for _, widget in ipairs(self.widgets) do generated[widget] = true end
		for i = #self.ui.widgets, 1, -1 do if generated[self.ui.widgets[i]] then table.remove(self.ui.widgets, i) end end
		self.ui._bindIndexDirty = true
		for _, flag in ipairs(self.flags) do self.ui._flagWidgets[flag] = nil end
		self.ui:Unmount(self.prefix)
		self.ui._validators[self.prefix] = nil
		local env = typeof(getgenv) == "function" and getgenv() or _G
		if env.__EASY_STACK and env.__EASY_STACK.bridge == self then env.__EASY_STACK.bridge = nil end
		if self.own and self.esp.destroy then self.esp:destroy() elseif self.started and o.stopOnDetach and self.esp.stop then self.esp:stop() end
		if self.ui._espLink == self then self.ui._espLink = nil end
		return true
	end
	self._espLink = link
	local env = typeof(getgenv) == "function" and getgenv() or _G
	env.__EASY_STACK = env.__EASY_STACK or {}
	env.__EASY_STACK.bridge = link
	link:sync()
	return link
end

function UI._Tab:Section(title)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = self._page,
	})
	corner(10, card)
	stroke(Theme.Soft, 1, 0, card)
	pad(12, card)
	bindHeight(card, list(card, 8), 24)
	if title then
		local head = label(title, 13, Theme.Text, Theme.Bold, card)
		head.Size = UDim2.new(1, 0, 0, 18)
		head.LayoutOrder = -1
	end
	return setmetatable({ _m = self._m, _card = card }, { __index = UI._Sec })
end

function UI._Tab:Destroy()
	local entry, scope = self._entry, self._scope
	local function wipe(tab)
		for i = #tab.tabs, 1, -1 do
			wipe(tab.tabs[i])
			table.remove(tab.tabs, i)
		end
		tab.button:Destroy()
		tab.page:Destroy()
	end
	for i = #scope.tabs, 1, -1 do
		if scope.tabs[i] == entry then
			wipe(entry)
			table.remove(scope.tabs, i)
			break
		end
	end
	if scope.activeTab == entry then
		scope.activeTab = nil
		if scope.tabs[1] then
			scope.tabs[1].activate()
		end
	end
	self._m:_pruneWidgets()
end

local function rowFrame(parent, h)
	return new("Frame", { Size = UDim2.new(1, 0, 0, h or 30), BackgroundTransparency = 1, Parent = parent })
end

function UI._Sec:Label(text, color)
	local l = label(text, 12, color or Theme.Sub, Theme.Font, self._card)
	l.Size = UDim2.new(1, 0, 0, 16)
	return l
end

function UI._Sec:Divider()
	local d = new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Soft,
		BorderSizePixel = 0,
		Parent = self._card,
	})
	return d
end

function UI._Sec:Widget(name, o)
	local builder = UI._widgetBuilders[tostring(name)]
	assert(builder, "Unknown widget: " .. tostring(name))
	return builder(self, o or {}, UI.Toolkit)
end

function UI._Sec:Info(o)
	o = o or {}
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, ClipsDescendants = true, Parent = self._card })
	local head = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = holder })
	local title = label(o.text or "Info", 12, o.color or Theme.Sub, o.font or Theme.Font, head)
	title.RichText = true
	title.Size = UDim2.new(1, -30, 1, 0)
	local chip = new("Frame", { Size = UDim2.fromOffset(22, 18), Position = UDim2.new(1, -22, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Control, BorderSizePixel = 0, Parent = head })
	corner(6, chip)
	stroke(Theme.Soft, 1, 0, chip)
	local arrow = label("⌄", 15, Theme.Text, Theme.Bold, chip)
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	head.MouseEnter:Connect(function() tw(chip, E.Fast, { BackgroundColor3 = Theme.Hover }) end)
	head.MouseLeave:Connect(function() tw(chip, E.Fast, { BackgroundColor3 = Theme.Control }) end)
	local body = label(o.description or "", 11, Theme.Muted, o.font or Theme.Font, holder)
	body.RichText = true
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Position = UDim2.new(0, 0, 0, 24)
	body.Size = UDim2.new(1, 0, 0, 40)
	local open = o.open == true
	local function relayout()
		local lines = open and math.max(1, math.ceil(textWidth(body.Text, 11, Theme.Font) / (self._card.AbsoluteSize.X - 24))) or 0
		body.Size = UDim2.new(1, 0, 0, lines * 15)
		holder.Size = UDim2.new(1, 0, 0, 22 + (open and (lines * 15 + 4) or 0))
		arrow.Rotation = open and 180 or 0
	end
	head.MouseButton1Click:Connect(function()
		open = not open
		relayout()
	end)
	task.defer(relayout)
	return {
		SetDescription = function(_, text) body.Text = text relayout() end,
		SetOpen = function(_, v) open = v and true or false relayout() end,
	}
end

function UI.RegisterWidget(name, builder)
	UI._widgetBuilders[tostring(name)] = builder
end

function UI.RegisterHUD(name, builder)
	UI._hudBuilders[tostring(name)] = builder
end

function UI.Extend(name, value)
	UI.Toolkit[tostring(name)] = value
	return value
end

function UI._Sec:Badge(text, kind)
	local col = Kind[kind] or self._m._accent
	local r = rowFrame(self._card, 20)
	local function widthFor(t2)
		return textWidth(tostring(t2), 11, Theme.Font) + 28
	end
	local b = new("Frame", {
		Size = UDim2.fromOffset(widthFor(text), 18),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		Parent = r,
	})
	corner(6, b)
	stroke(Theme.Soft, 1, 0, b)
	local dotc = new("Frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.new(0, 9, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = col,
		BorderSizePixel = 0,
		Parent = b,
	})
	corner(999, dotc)
	local l = label(tostring(text), 11, Theme.Sub, Theme.Font, b)
	l.Position = UDim2.new(0, 18, 0, 0)
	l.Size = UDim2.new(1, -22, 1, 0)
	return {
		Set = function(_, t2, k2)
			l.Text = tostring(t2)
			b.Size = UDim2.fromOffset(widthFor(t2), 18)
			dotc.BackgroundColor3 = Kind[k2] or col
		end,
	}
end

function UI._Sec:Toggle(o)
	o = o or {}
	local stored = o.flag and self._m:_read(o.flag)
	local state = o.default or false
	if stored ~= nil then
		state = stored
	end
	local r = rowFrame(self._card, 28)
	local l = label(o.text or "Toggle", 13, Theme.Text, Theme.Font, r)
	l.Size = UDim2.new(1, -50, 1, 0)
	local track = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(40, 22),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = state and self._m._accent or Theme.Control,
		BorderSizePixel = 0,
		Parent = r,
	})
	corner(999, track)
	stroke(Theme.Soft, 1, 0, track)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = state and UDim2.new(1, -3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(state and 1 or 0, 0.5),
		BackgroundColor3 = state and Theme.Window or Theme.Sub,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(999, knob)
	self._m._accentUpdaters[#self._m._accentUpdaters + 1] = { track, function(c) if state then tw(track, E.Fast, { BackgroundColor3 = c }) end end }

	local api = {}
	local m0 = self._m
	function api:Set(v)
		v = v and true or false
		if v == state then
			return
		end
		state = v
		tw(track, E.Smooth, { BackgroundColor3 = state and m0._accent or Theme.Control })
		tw(knob, E.Snap, {
			Position = state and UDim2.new(1, -3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			AnchorPoint = Vector2.new(state and 1 or 0, 0.5),
			BackgroundColor3 = state and Theme.Window or Theme.Sub,
		})
		m0:_refreshBindHUD()
		if o.callback then
			task.spawn(o.callback, state)
		end
	end
	function api:Get()
		return state
	end
	if o.flag then
		self._m:_write(o.flag, state)
		self._m._flagWidgets[o.flag] = api
		local base = api.Set
		api.Set = function(_, v)
			self._m:_write(o.flag, v and true or false)
			base(api, v)
		end
	end
	track.MouseButton1Click:Connect(function()
		api:Set(not state)
	end)
	self._m:_reg({ kind = "toggle", opt = o, row = r, getState = function()
		return state
	end, setState = function(v)
		api:Set(v)
	end, activate = function()
		api:Set(not state)
	end })
	return api
end

function UI._Sec:Button(o)
	o = o or {}
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self._card,
	})
	corner(8, b)
	stroke(Theme.Soft, 1, 0, b)
	local l = label(o.text or "Button", 13, Theme.Text, Theme.Font, b)
	l.Size = UDim2.fromScale(1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Center
	hover(b, Theme.Control, Theme.Hover)
	local scale = new("UIScale", { Scale = 1, Parent = b })
	b.MouseButton1Down:Connect(function() tw(scale, E.Fast, { Scale = 0.97 }) end)
	b.MouseButton1Up:Connect(function() tw(scale, E.Snap, { Scale = 1 }) end)
	b.MouseLeave:Connect(function() tw(scale, E.Snap, { Scale = 1 }) end)
	local function fire()
		ripple(b)
		if o.callback then
			task.spawn(o.callback)
		end
	end
	b.MouseButton1Click:Connect(fire)
	self._m:_reg({ kind = "button", opt = o, row = b, activate = fire })
	return { SetText = function(_, t2)
		l.Text = t2
	end }
end

function UI._Sec:Slider(o)
	o = o or {}
	local min, max = tonumber(o.min) or 0, tonumber(o.max) or 100
	if min > max then
		min, max = max, min
	end
	local step, dec = math.abs(tonumber(o.step) or 1), o.decimals or 0
	if step == 0 then
		step = 1
	end
	local stored = o.flag and self._m:_read(o.flag)
	local value = math.clamp(tonumber(stored ~= nil and stored or o.default) or min, min, max)
	local r = rowFrame(self._card, 40)
	local l = label(o.text or "Slider", 13, Theme.Text, Theme.Font, r)
	l.Size = UDim2.new(1, -60, 0, 18)
	local val = label("", 12, Theme.Sub, Theme.Mono, r)
	val.Size = UDim2.new(0, 60, 0, 18)
	val.Position = UDim2.new(1, -60, 0, 0)
	val.TextXAlignment = Enum.TextXAlignment.Right
	local track = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 0, 28),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		Parent = r,
	})
	corner(999, track)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = self._m._accent, BorderSizePixel = 0, Parent = track })
	self._m._accentUpdaters[#self._m._accentUpdaters + 1] = { fill, function(c) fill.BackgroundColor3 = c end }
	corner(999, fill)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(0, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Text,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = track,
	})
	corner(999, knob)
	local knobStroke = stroke(Theme.Soft, 1, 1, knob)

	local function fmt(v)
		if dec > 0 then
			return string.format("%." .. dec .. "f", v)
		end
		return tostring(math.floor(v + 0.5))
	end
	local dragging = false
	local shown = value
	local function showKnob(on)
		tw(knob, E.Snap, { Size = on and UDim2.fromOffset(14, 14) or UDim2.fromOffset(0, 0), BackgroundTransparency = on and 0 or 1 })
		tw(knobStroke, E.Fast, { Transparency = on and 0 or 1 })
	end
	local api = {}
	local function apply(v, mode, fire)
		local snapped = math.clamp(min + math.floor(((tonumber(v) or min) - min) / step + 0.5) * step, min, max)
		if dec > 0 then
			snapped = tonumber(string.format("%." .. dec .. "f", snapped)) or snapped
		end
		if fire and snapped == value then
			return
		end
		value = snapped
		local span = max - min
		local a = span == 0 and 0 or (value - min) / span
		if mode == "drag" then
			tw(fill, E.Now, { Size = UDim2.new(a, 0, 1, 0) })
			tw(knob, E.Now, { Position = UDim2.new(a, 0, 0.5, 0) })
		elseif mode then
			tw(fill, E.Glide, { Size = UDim2.new(a, 0, 1, 0) })
			tw(knob, E.Glide, { Position = UDim2.new(a, 0, 0.5, 0) })
		else
			fill.Size = UDim2.new(a, 0, 1, 0)
			knob.Position = UDim2.new(a, 0, 0.5, 0)
		end
		if not dragging then
			shown = value
			val.Text = fmt(value)
		end
		if o.flag then
			self._m:_write(o.flag, value)
		end
		if fire and o.callback then
			task.spawn(o.callback, value)
		end
	end
	function api:Set(v)
		apply(v, true, true)
	end
	function api:Get()
		return value
	end
	apply(value, false, false)
	if o.flag then
		self._m._flagWidgets[o.flag] = api
	end
	local sliderRemove
	local function fromX()
		local a = math.clamp((Input:GetMouseLocation().X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		apply(min + a * (max - min), "drag", true)
	end
	track.MouseButton1Down:Connect(function()
		dragging = true
		showKnob(true)
		sliderRemove = self._m:Schedule("__slider", function(dt)
			shown += (value - shown) * math.min(1, dt * 16)
			if math.abs(shown - value) < (step / 100 + 1e-4) then
				shown = value
			end
			val.Text = fmt(shown)
		end, nil, 2500)
		fromX()
		beginDrag(self._m, function()
			if dragging then
				fromX()
			end
		end, function()
			dragging = false
			showKnob(false)
			if sliderRemove then
				sliderRemove()
				sliderRemove = nil
			end
			shown = value
			val.Text = fmt(value)
		end)
	end)
	self._m:_reg({ kind = "slider", opt = o, row = r, activate = function() api:Set(value + step) end })
	return api
end

function UI._Sec:Dropdown(o)
	o = o or {}
	local items = o.options or {}
	local stored = o.flag and self._m:_read(o.flag)
	local value = stored ~= nil and stored or o.default or items[1]
	local open = false
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self._card,
	})
	local head = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		Parent = holder,
	})
	corner(8, head)
	stroke(Theme.Soft, 1, 0, head)
	local l = label((o.text and o.text .. ":  " or "") .. tostring(value or ""), 13, Theme.Text, Theme.Font, head)
	l.Position = UDim2.new(0, 10, 0, 0)
	l.Size = UDim2.new(1, -34, 1, 0)
	local arrow = label("▾", 12, Theme.Sub, Theme.Font, head)
	arrow.Position = UDim2.new(1, -22, 0, 0)
	arrow.Size = UDim2.fromOffset(16, 30)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	local body = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 34),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Visible = false,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		Parent = holder,
	})
	corner(8, body)
	stroke(Theme.Soft, 1, 0, body)
	pad(4, body)
	local bodyLayout = list(body, 3)
	local function updHolder()
		local full = bodyLayout.AbsoluteContentSize.Y + 8
		local shown = math.min(full, 180)
		body.Size = UDim2.new(1, 0, 0, shown)
		body.CanvasSize = UDim2.new(0, 0, 0, full)
		holder.Size = UDim2.new(1, 0, 0, open and (34 + shown) or 30)
	end
	bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updHolder)

	local api = {}
	local m = self._m
	function api:Get()
		return value
	end
	function api:Set(v)
		if v == value then
			l.Text = (o.text and o.text .. ":  " or "") .. tostring(value or "")
			return
		end
		value = v
		l.Text = (o.text and o.text .. ":  " or "") .. tostring(value or "")
		if o.flag then
			m:_write(o.flag, v)
		end
		if o.callback then
			task.spawn(o.callback, value)
		end
	end
	local function rebuild()
		for _, c in ipairs(body:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for _, it in ipairs(items) do
			local opt = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = Theme.Hover,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = body,
			})
			corner(6, opt)
			local ol = label(tostring(it), 12, it == value and Theme.Text or Theme.Sub, Theme.Font, opt)
			ol.Position = UDim2.new(0, 8, 0, 0)
			ol.Size = UDim2.new(1, -8, 1, 0)
			opt.MouseEnter:Connect(function()
				tw(opt, E.Fast, { BackgroundTransparency = 0 })
			end)
			opt.MouseLeave:Connect(function()
				tw(opt, E.Fast, { BackgroundTransparency = 1 })
			end)
			opt.MouseButton1Click:Connect(function()
				api:Set(it)
				open = false
				body.Visible = false
				updHolder()
				tw(arrow, E.Fast, { Rotation = 0 })
				rebuild()
			end)
		end
	end
	head.MouseButton1Click:Connect(function()
		open = not open
		if open then
			rebuild()
			body.Visible = true
			updHolder()
			tw(arrow, E.Fast, { Rotation = 180 })
		else
			body.Visible = false
			updHolder()
			tw(arrow, E.Fast, { Rotation = 0 })
		end
	end)
	hover(head, Theme.Control, Theme.Hover)
	function api:SetItems(t)
		items = t or {}
		local found = false
		for _, item in ipairs(items) do
			if item == value then
				found = true
				break
			end
		end
		if not found then
			api:Set(items[1])
		end
		rebuild()
	end
	if o.flag then
		self._m:_write(o.flag, value)
		self._m._flagWidgets[o.flag] = api
	end
	self._m:_reg({ kind = "dropdown", opt = o, row = head, activate = function()
		for i, item in ipairs(items) do
			if item == value then api:Set(items[i % #items + 1]) break end
		end
	end })
	return api
end

function UI._Sec:Keybind(o)
	o = o or {}
	local stored = o.flag and self._m:_read(o.flag)
	local key = typeof(stored) == "EnumItem" and stored or o.default
	local r = rowFrame(self._card, 28)
	local l = label(o.text or "Keybind", 13, Theme.Text, Theme.Font, r)
	l.Size = UDim2.new(1, -80, 1, 0)
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(76, 24),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		Parent = r,
	})
	corner(7, b)
	stroke(Theme.Soft, 1, 0, b)
	local bl = label(key and key.Name or "None", 12, Theme.Sub, Theme.Mono, b)
	bl.Size = UDim2.fromScale(1, 1)
	bl.TextXAlignment = Enum.TextXAlignment.Center
	local wd
	local api = {}
	function api:Get() return key end
	function api:Set(value)
		value = typeof(value) == "EnumItem" and value or nil
		local changed = value ~= key
		key = value
		bl.Text = key and key.Name or "None"
		if wd then wd.bindKey = key end
		if o.flag then self._m:_write(o.flag, key) end
		self._m:_refreshBindHUD()
		if changed and o.onChange then
			task.spawn(o.onChange, key)
		end
	end
	b.MouseButton1Click:Connect(function()
		bl.Text = "..."
		tw(b, E.Fast, { BackgroundColor3 = Theme.Hover })
		self._m:_setCapture(function(i)
			tw(b, E.Fast, { BackgroundColor3 = Theme.Control })
			if not i then
				api:Set(key)
			elseif i.KeyCode == Enum.KeyCode.Escape then
				api:Set(nil)
			else
				api:Set(i.KeyCode)
			end
		end)
	end)
	wd = self._m:_reg({
		kind = "keybind",
		opt = o,
		row = r,
		noKeybind = true,
		bindKey = key,
		activate = o.callback and function()
			task.spawn(o.callback, key)
		end or nil,
	})
	wd.setBind = function(value) api:Set(value) end
	if o.flag then
		self._m:_write(o.flag, key)
		self._m._flagWidgets[o.flag] = api
	end
	return api
end

function UI._Sec:Textbox(o)
	o = o or {}
	local stored = o.flag and self._m:_read(o.flag)
	local r = rowFrame(self._card, 30)
	local box = new("TextBox", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		Text = stored ~= nil and tostring(stored) or o.default or "",
		PlaceholderText = o.placeholder or "",
		PlaceholderColor3 = Theme.Muted,
		TextColor3 = Theme.Sub,
		Font = Theme.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = r,
	})
	corner(8, box)
	local st = stroke(Theme.Soft, 1, 0, box)
	pad(0, box, 10, 0, 10, 0)
	if o.text then
		local tl = label(o.text, 13, Theme.Sub, Theme.Font, r)
		tl.Size = UDim2.new(0.45, -8, 1, 0)
		box.Size = UDim2.new(0.55, 0, 1, 0)
		box.Position = UDim2.new(0.45, 0, 0, 0)
	end
	box.Focused:Connect(function()
		tw(st, E.Fast, { Color = Theme.Stroke })
	end)
	box.FocusLost:Connect(function(enter)
		tw(st, E.Fast, { Color = Theme.Soft })
		if o.flag then
			self._m:_write(o.flag, box.Text)
		end
		if enter and o.callback then
			task.spawn(o.callback, box.Text)
		end
	end)
	local api = { Get = function()
		return box.Text
	end, Set = function(_, t2)
		box.Text = tostring(t2 ~= nil and t2 or "")
		if o.flag then
			self._m:_write(o.flag, box.Text)
		end
	end }
	if o.flag then
		self._m:_write(o.flag, box.Text)
		self._m._flagWidgets[o.flag] = api
	end
	self._m:_reg({ kind = "textbox", opt = o, row = r, activate = function() box:CaptureFocus() end })
	return api
end

function UI._Sec:Colorpicker(o)
	o = o or {}
	local stored = o.flag and self._m:_read(o.flag)
	local color = typeof(stored) == "Color3" and stored or o.default or self._m._accent
	local r = rowFrame(self._card, 28)
	local l = label(o.text or "Color", 13, Theme.Text, Theme.Font, r)
	l.Size = UDim2.new(1, -40, 1, 0)
	local sw = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(34, 20),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = r,
	})
	corner(6, sw)
	stroke(Theme.Soft, 1, 0, sw)
	local pop = new("Frame", {
		Size = UDim2.fromOffset(210, 190),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 70,
		Parent = self._m.gui,
	})
	r.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end
		if self._m._openPicker == pop then
			self._m._openPicker = nil
			self._m._openPickerSw = nil
		end
		if pop.Parent then
			pop:Destroy()
		end
	end)
	corner(8, pop)
	stroke(Theme.Stroke, 1, 0, pop)
	pad(8, pop)
	local sat = new("ImageButton", {
		Size = UDim2.new(1, -30, 1, -42),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 71,
		Parent = pop,
	})
	corner(6, sat)
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 72, Parent = sat })
	corner(6, white)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = white })
	local dark = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 72, Parent = sat })
	corner(6, dark)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = dark })
	local satMark = new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 73, Parent = sat })
	corner(999, satMark)
	stroke(Color3.new(0, 0, 0), 1, 0, satMark)
	local hueBar = new("ImageButton", {
		Size = UDim2.new(0, 22, 1, -42),
		Position = UDim2.new(1, -22, 0, 0),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 71,
		Parent = pop,
	})
	corner(6, hueBar)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
			ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
			ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
			ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		}),
		Parent = hueBar,
	})
	local hueMark = new("Frame", { Size = UDim2.new(1, 4, 0, 3), Position = UDim2.new(0, -2, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 73, Parent = hueBar })
	stroke(Color3.new(0, 0, 0), 1, 0, hueMark)
	local hex = new("TextBox", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -30), BackgroundColor3 = Theme.Control, BorderSizePixel = 0, TextColor3 = Theme.Text, PlaceholderText = "#FFFFFF", TextSize = 12, Font = Theme.Mono, ClearTextOnFocus = false, ZIndex = 72, Parent = pop })
	corner(6, hex)
	pad(0, hex, 8, 0, 8, 0)
	local hu, sa, va = color:ToHSV()
	local api = {}
	local markLift = 0
	local function refresh(fire)
		color = Color3.fromHSV(hu, sa, va)
		sw.BackgroundColor3 = color
		sat.BackgroundColor3 = Color3.fromHSV(hu, 1, 1)
		satMark.BackgroundColor3 = color
		satMark.Position = UDim2.new(sa, 0, 1 - va, -markLift)
		hueMark.Position = UDim2.new(0, -2, hu, -3 * hu)
		hex.Text = Color.hex(color)
		if o.flag then
			self._m:_write(o.flag, color)
		end
		if fire ~= false and o.callback then
			task.spawn(o.callback, color)
		end
	end
	local ds, dh
	sat.MouseButton1Down:Connect(function()
		ds = true
		markLift = 0
		tw(satMark, E.Snap, { Size = UDim2.fromOffset(16, 16) })
		local m = Input:GetMouseLocation()
		sa = math.clamp((m.X - sat.AbsolutePosition.X) / math.max(sat.AbsoluteSize.X, 1), 0, 1)
		va = 1 - math.clamp((m.Y - sat.AbsolutePosition.Y) / math.max(sat.AbsoluteSize.Y, 1), 0, 1)
		refresh()
		beginDrag(self._m, function(m)
			if ds then
				sa = math.clamp((m.X - sat.AbsolutePosition.X) / math.max(sat.AbsoluteSize.X, 1), 0, 1)
				va = 1 - math.clamp((m.Y - sat.AbsolutePosition.Y) / math.max(sat.AbsoluteSize.Y, 1), 0, 1)
				refresh()
			end
		end, function()
			ds = false
			markLift = 0
			tw(satMark, E.Snap, { Size = UDim2.fromOffset(8, 8) })
			refresh(false)
		end)
	end)
	hueBar.MouseButton1Down:Connect(function()
		dh = true
		local m = Input:GetMouseLocation()
		hu = math.clamp((m.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
		refresh()
		beginDrag(self._m, function(m)
			if dh then
				hu = math.clamp((m.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
				refresh()
			end
		end, function()
			dh = false
		end)
	end)
	local function togglePicker()
		local opening = not pop.Visible
		if self._m._openPicker and self._m._openPicker ~= pop then self._m._openPicker.Visible = false end
		pop.Visible = opening
		self._m._openPicker = opening and pop or nil
		self._m._openPickerSw = opening and sw or nil
		if opening then
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
			pop.Position = UDim2.fromOffset(math.clamp(sw.AbsolutePosition.X + sw.AbsoluteSize.X - pop.AbsoluteSize.X, 4, math.max(4, viewport.X - pop.AbsoluteSize.X - 4)), math.clamp(sw.AbsolutePosition.Y + sw.AbsoluteSize.Y + 6, 4, math.max(4, viewport.Y - pop.AbsoluteSize.Y - 4)))
		end
	end
	sw.MouseButton1Click:Connect(togglePicker)
	hex.FocusLost:Connect(function()
		if hex.Text:match("^#?%x%x%x%x%x%x$") then api:Set(Color.fromHex(hex.Text)) else hex.Text = Color.hex(color) end
	end)
	refresh(false)
	function api:Get()
		return color
	end
	function api:Set(c)
		local h2, s2, v2 = c:ToHSV()
		if s2 > 0 then
			hu = h2
		end
		sa, va = s2, v2
		refresh()
	end
	function api:GetHex() return Color.hex(color) end
	function api:SetHex(value) api:Set(Color.fromHex(value)) end
	if o.flag then
		self._m._flagWidgets[o.flag] = api
	end
	self._m:_reg({ kind = "color", opt = o, row = r, activate = togglePicker })
	return api
end

function UI.RegisterMedia(kind, handler)
	UI._mediaHandlers[(string.lower(tostring(kind)):gsub("^%.+", ""))] = handler
end

function UI:ImportMedia(source, o)
	o = o or {}
	local url = tostring(source)
	local youtube = url:match("youtu%.be/([%w_-]+)") or url:match("[?&]v=([%w_-]+)") or url:match("youtube%.com/shorts/([%w_-]+)")
	if youtube then
		url = "https://i.ytimg.com/vi/" .. youtube .. "/hqdefault.jpg"
	end
	local clean = url:lower():match("^[^?#]+") or url:lower()
	local ext = (clean:match("/([^/]*)$") or ""):match("%.([%w]+)$") or o.type
	ext = ext and string.lower(ext)
	ext = ext == "jpeg" and "jpg" or ext
	local custom = UI._mediaHandlers[ext or ""]
	if custom then return custom(self, url, o) end
	assert(type(writefile) == "function" and type(getcustomasset) == "function", "Custom assets unavailable")
	local body
	if type(request) == "function" or type(http_request) == "function" then
		local response = (request or http_request)({ Url = url, Method = "GET" })
		assert(response and response.Success ~= false and (not response.StatusCode or response.StatusCode >= 200 and response.StatusCode < 300), "Media download failed")
		body = response.Body
	elseif type(httpget) == "function" then
		body = httpget(url)
	else
		body = game:HttpGet(url)
	end
	assert(type(body) == "string" and #body > 0 and #body <= (o.maxBytes or 20 * 1024 * 1024), "Invalid media response")
	assert(body:sub(1, 1) ~= "<", "Media download returned a page, not a file")
	local sniffed = body:sub(1, 8) == "\137PNG\r\n\26\n" and "png" or body:sub(1, 3) == "\255\216\255" and "jpg" or body:sub(1, 3) == "ID3" and "mp3" or body:sub(1, 6) == "GIF87a" and "gif" or body:sub(1, 6) == "GIF89a" and "gif" or body:sub(5, 8) == "ftyp" and "mp4" or nil
	ext = sniffed or ext
	assert(ext, "Unknown media format")
	local folder = "EasyUI/media"
	if type(makefolder) == "function" then
		pcall(makefolder, "EasyUI")
		pcall(makefolder, folder)
	end
	local hash = 0
	for i = 1, #body, 97 do
		hash = (hash * 33 + body:byte(i)) % 2147483647
	end
	local path = folder .. "/" .. safeName(o.name or ("m" .. hash .. "_" .. #body)) .. "." .. ext
	writefile(path, body)
	local asset = getcustomasset(path)
	local object
	if ext == "png" or ext == "jpg" or ext == "gif" then
		object = new(o.button and "ImageButton" or "ImageLabel", { BackgroundTransparency = 1, Image = asset, ScaleType = Enum.ScaleType.Fit })
	elseif ext == "mp3" or ext == "ogg" or ext == "wav" or ext == "flac" then
		object = new("Sound", { SoundId = asset, Volume = o.volume or 1 })
	elseif ext == "mp4" or ext == "mov" then
		object = new("VideoFrame", { BackgroundTransparency = 1, Video = asset, Looped = o.looped == true })
	else
		error("Unsupported media type: " .. ext)
	end
	return { object = object, asset = asset, path = path, type = ext, youtube = youtube ~= nil, Destroy = function(media) media.object:Destroy() end }
end

function UI._Sec:Media(source, o)
	o = o or {}
	local media = self._m:ImportMedia(source, o)
	local object = media.object
	if object:IsA("GuiObject") then
		object.Size = UDim2.new(1, 0, 0, o.height or 160)
		object.Parent = self._card
	else
		object.Parent = self._m.gui
		if o.play ~= false and object.Play then object:Play() end
	end
	return media
end

UI.RegisterHUD("Compass", function(ui, o, _, own)
	local width = o.width or 260
	local frame = own(new("Frame", { Size = UDim2.fromOffset(width, 34), Position = o.position or UDim2.new(0.5, -width / 2, 0, 18), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ZIndex = Layers.hud, Parent = ui.gui }))
	corner(10, frame)
	stroke(Theme.Stroke, 1, 0.1, frame)
	local text = label("N  000°", 12, Theme.Text, Theme.Mono, frame)
	text.Size = UDim2.fromScale(1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Center
	draggable(ui, frame, frame, nil, { hud = true, guides = true })
	local enabled = true
	local remove = own(ui:Every("hud:compass", o.interval or 0.05, function()
		if not enabled then return end
		local camera = workspace.CurrentCamera
		if not camera then return end
		local look = camera.CFrame.LookVector
		local degrees = (math.deg(math.atan2(-look.X, -look.Z)) + 360) % 360
		local index = math.floor((degrees + 22.5) / 45) % 8 + 1
		text.Text = ({ "N", "NE", "E", "SE", "S", "SW", "W", "NW" })[index] .. ("  %03d°"):format(math.floor(degrees + 0.5) % 360)
	end, o.priority or 10))
	return { SetEnabled = function(_, on)
		enabled = on and true or false
		frame.Visible = enabled
	end, Remove = remove }
end)

function UI:Notify(o)
	o = o or {}
	local dur = o.duration or 4
	local col = Kind[o.kind] or self._accent
	if not self._toasts then
		self._toasts = new("Frame", {
			Size = UDim2.new(0, 290, 1, -32),
			ZIndex = Layers.toast,
			Position = UDim2.new(1, -16, 1, -16),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Parent = self.gui,
		})
		local ll = list(self._toasts, 8)
		ll.VerticalAlignment = Enum.VerticalAlignment.Bottom
		ll.HorizontalAlignment = Enum.HorizontalAlignment.Right
	end
	local lines = math.max(1, math.ceil(textWidth(o.text or "", 12, Theme.Font) / 250))
	local height = 40 + lines * 16
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Parent = self._toasts,
	})
	local card = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Position = UDim2.new(1, 320, 0, 0),
		Parent = holder,
	})
	corner(10, card)
	stroke(Theme.Stroke, 1, 0.05, card)
	pad(10, card, 16, 10, 12, 10)
	local acc = new("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.new(0, -8, 0, 8), BackgroundColor3 = col, BorderSizePixel = 0, Parent = card })
	corner(999, acc)
	local t = label(o.title or "Notice", 13, Theme.Text, Theme.Bold, card)
	t.Position = UDim2.new(0, 6, 0, 0)
	t.Size = UDim2.new(1, -6, 0, 18)
	local msg = label(o.text or "", 12, Theme.Sub, Theme.Font, card)
	msg.Position = UDim2.new(0, 6, 0, 18)
	msg.Size = UDim2.new(1, -6, 0, lines * 16)
	msg.TextWrapped = true
	msg.TextYAlignment = Enum.TextYAlignment.Top
	local prog = new("Frame", { Size = UDim2.new(1, -12, 0, 2), Position = UDim2.new(0, 6, 1, 2), BackgroundColor3 = col, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = card })
	corner(999, prog)
	tw(card, E.Pop, { Position = UDim2.new(0, 0, 0, 0) })
	tw(prog, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })
	local dismissed = false
	local function dismiss()
		if dismissed or not card.Parent then
			return
		end
		dismissed = true
		for _, d in ipairs(card:GetDescendants()) do
			if d:IsA("TextLabel") then
				tw(d, E.Smooth, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				tw(d, E.Smooth, { Transparency = 1 })
			elseif d:IsA("Frame") then
				tw(d, E.Smooth, { BackgroundTransparency = 1 })
			end
		end
		local out = tw(card, E.Smooth, { Position = UDim2.new(1, 340, 0, 0), BackgroundTransparency = 1 })
		out.Completed:Connect(function()
			holder:Destroy()
		end)
	end
	card.Active = true
	card.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dismiss()
		end
	end)
	task.delay(dur, dismiss)
	return { Dismiss = dismiss }
end

function UI:_ctxInit()
	local pop = new("Frame", {
		Size = UDim2.fromOffset(210, 40),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 60,
		Parent = self.gui,
	})
	corner(10, pop)
	stroke(Theme.Stroke, 1, 0.05, pop)
	local head = label("", 13, Theme.Text, Theme.Bold, pop)
	head.Position = UDim2.new(0, 12, 0, 8)
	head.Size = UDim2.new(1, -24, 0, 18)
	head.ZIndex = 61
	local hold = new("Frame", {
		Size = UDim2.new(1, -16, 0, 0),
		Position = UDim2.new(0, 8, 0, 30),
		BackgroundTransparency = 1,
		ZIndex = 61,
		Parent = pop,
	})
	pad(4, hold)
	local holdLayout = list(hold, 6)
	holdLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local hh = holdLayout.AbsoluteContentSize.Y + 8
		hold.Size = UDim2.new(1, -16, 0, hh)
		pop.Size = UDim2.fromOffset(210, hh + 38)
	end)
	self._ctx = pop
	self._ctxHead = head
	self._ctxHold = hold
	self._ctxScale = new("UIScale", { Scale = 1, Parent = pop })

	self:_connect(Input.InputBegan, function(i)
		if self._openPicker and self._openPicker.Visible and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and not inside(self._openPicker, Input:GetMouseLocation()) and not inside(self._openPickerSw, Input:GetMouseLocation()) then
			self._openPicker.Visible = false
			self._openPicker = nil
			self._openPickerSw = nil
		end
		if pop.Visible and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			local mouse = Input:GetMouseLocation()
			if not inside(pop, mouse) and not (self._openPicker and inside(self._openPicker, mouse)) then
				self:_closeContext()
			end
		end
	end)
end

function UI:_setCapture(fn)
	self._captureKey = fn
	if fn and not self._escBound then
		self._escBound = true
		pcall(function()
			CAS:BindActionAtPriority("EasyUI_CaptureEsc", function()
				return Enum.ContextActionResult.Sink
			end, false, 3000, Enum.KeyCode.Escape)
		end)
	elseif not fn and self._escBound then
		self._escBound = false
		pcall(CAS.UnbindAction, CAS, "EasyUI_CaptureEsc")
	end
end

function UI:_closeContext()
	if self._ctx then self._ctx.Visible = false end
	self:_setCapture(nil)
	for flag, api in pairs(self._ctxFlags or {}) do
		if self._flagWidgets[flag] == api.current then
			self._flagWidgets[flag] = api.previous
			if api.previous and api.previous.Set then
				pcall(api.previous.Set, api.previous, self:_read(flag))
			end
		end
	end
	self._ctxFlags = {}
end

function UI:_openContext(wd)
	local pop = self._ctx
	self:_closeContext()
	for _, c in ipairs(self._ctxHold:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	self._ctxHead.Text = (wd.opt and wd.opt.text) or wd.kind or "Options"
	local sec = setmetatable({ _m = self, _card = self._ctxHold }, { __index = UI._Sec })

	if wd.activate and not wd.noKeybind and not (wd.opt and wd.opt.noKeybind) then
		local r = rowFrame(self._ctxHold, 26)
		local l = label("Keybind", 12, Theme.Sub, Theme.Font, r)
		l.Size = UDim2.new(1, -80, 1, 0)
		local b = new("TextButton", {
			Text = "",
		AutoButtonColor = false,
		Modal = true,
		Size = UDim2.fromOffset(76, 22),
			Position = UDim2.new(1, 0, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Theme.Control,
			BorderSizePixel = 0,
			ZIndex = 62,
			Parent = r,
		})
		corner(6, b)
		stroke(Theme.Soft, 1, 0, b)
		local bl = label(wd.bindKey and wd.bindKey.Name or "None", 11, Theme.Sub, Theme.Mono, b)
		bl.Size = UDim2.fromScale(1, 1)
		bl.TextXAlignment = Enum.TextXAlignment.Center
		bl.ZIndex = 63
		b.MouseButton1Click:Connect(function()
			bl.Text = "..."
			self:_setCapture(function(i)
				if not i then
					bl.Text = wd.bindKey and wd.bindKey.Name or "None"
				elseif i.KeyCode == Enum.KeyCode.Escape then
					wd.bindKey = nil
					bl.Text = "None"
				elseif i.KeyCode ~= Enum.KeyCode.Unknown then
					wd.bindKey = i.KeyCode
					bl.Text = i.KeyCode.Name
				end
				self:_refreshBindHUD()
			end)
		end)
	end

	local before = {}
	for flag, api in pairs(self._flagWidgets) do before[flag] = api end
	if wd.opt and wd.opt.context then
		wd.opt.context(sec, wd)
	end
	for flag, api in pairs(self._flagWidgets) do
		if before[flag] ~= api then self._ctxFlags[flag] = { current = api, previous = before[flag] } end
	end

	local m = Input:GetMouseLocation()
	local function place()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		pop.Position = UDim2.fromOffset(math.clamp(m.X + 4, 4, math.max(4, viewport.X - 214)), math.clamp(m.Y + 4, 4, math.max(4, viewport.Y - pop.AbsoluteSize.Y - 4)))
	end
	place()
	pop.Visible = true
	pop.BackgroundTransparency = 1
	self._ctxScale.Scale = 0.9
	tw(pop, E.Fast, { BackgroundTransparency = 0 })
	tw(self._ctxScale, E.Pop, { Scale = 1 })
	task.defer(function()
		if pop.Visible then
			place()
		end
	end)
end

function UI:Preview(o)
	o = o or {}
	local w, h = 220, 300
	local win = new("Frame", {
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.new(0.5, 220, 0.5, -h / 2),
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		Parent = self.gui,
	})
	corner(12, win)
	stroke(Theme.Stroke, 1, 0.2, win)
	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = win })
	draggable(self, bar, win)
	local t = label(self.title .. " — Preview", 12, Theme.Sub, Theme.Mono, bar)
	t.Position = UDim2.new(0, 14, 0, 0)
	t.Size = UDim2.new(1, -20, 1, 0)
	local holder = new("Frame", {
		Size = UDim2.new(1, -20, 1, -46),
		Position = UDim2.new(0, 10, 0, 38),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = win,
	})
	corner(10, holder)
	stroke(Theme.Soft, 1, 0, holder)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.new(1, 1, 1), Parent = holder })
	local cam = new("Camera", { Parent = vp })
	vp.CurrentCamera = cam
	local model = new("Model", { Parent = vp })
	local function part(size, pos, color)
		local p = new("Part", { Size = size, Color = color or Color3.fromRGB(210, 210, 215), Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, Parent = model })
		p.CFrame = CFrame.new(pos)
		return p
	end
	local torso = part(Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), Color3.fromRGB(225, 205, 215))
	part(Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.7, 0), Color3.fromRGB(240, 225, 230))
	part(Vector3.new(0.8, 2, 0.8), Vector3.new(-1.4, 0, 0))
	part(Vector3.new(0.8, 2, 0.8), Vector3.new(1.4, 0, 0))
	part(Vector3.new(0.9, 2, 0.9), Vector3.new(-0.5, -2, 0), Color3.fromRGB(60, 60, 66))
	part(Vector3.new(0.9, 2, 0.9), Vector3.new(0.5, -2, 0), Color3.fromRGB(60, 60, 66))
	model.PrimaryPart = torso
	local box = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(76, 150), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = holder })
	local boxStroke = stroke(self._accent, 1.5, 0, box)
	self._accentUpdaters[#self._accentUpdaters + 1] = { box, function(c) boxStroke.Color = c end }
	corner(3, box)
	local nm = label("Player", 11, Theme.Text, Theme.Bold, holder)
	nm.Size = UDim2.fromOffset(120, 14)
	nm.AnchorPoint = Vector2.new(0.5, 1)
	nm.TextXAlignment = Enum.TextXAlignment.Center
	local hp = new("Frame", { Size = UDim2.fromOffset(3, 150), BackgroundColor3 = Theme.Ok, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Parent = holder })
	corner(999, hp)
	local ang = 0
	local conn
	conn = self:_connect(Run.RenderStepped, function(dt)
		if not vp:IsDescendantOf(self.gui) then
			conn:Disconnect()
			return
		end
		ang += dt * 0.6
		model:PivotTo(CFrame.Angles(0, ang, 0))
		cam.CFrame = CFrame.new(Vector3.new(0, 0.2, 8), Vector3.new(0, -0.2, 0))
		local by = box.AbsoluteSize
		nm.Position = UDim2.fromOffset(box.AbsolutePosition.X - holder.AbsolutePosition.X + by.X / 2, box.AbsolutePosition.Y - holder.AbsolutePosition.Y - 2)
		hp.Position = UDim2.fromOffset(box.AbsolutePosition.X - holder.AbsolutePosition.X - 4, box.AbsolutePosition.Y - holder.AbsolutePosition.Y + by.Y / 2)
		local pct = math.sin(ang * 1.5) * 0.5 + 0.5
		hp.Size = UDim2.fromOffset(3, by.Y)
		hp.BackgroundColor3 = Theme.Err:Lerp(Theme.Ok, pct)
	end)
	return win
end

function UI:GetMouse()
	return Input:GetMouseLocation()
end

function UI:OnInput(fn)
	return self:_connect(Input.InputBegan, function(i, gp) fn(i, gp) end)
end

function UI:OnInputEnded(fn)
	return self:_connect(Input.InputEnded, function(i, gp) fn(i, gp) end)
end

function UI:OnMouseMove(fn)
	return self:_connect(Input.InputChanged, function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement then
			fn(Input:GetMouseLocation(), i.Delta)
		end
	end)
end

function UI:Log(level, ...)
	self._log = self._log or {}
	local parts = {}
	for _, v in ipairs({ ... }) do
		parts[#parts + 1] = typeof(v) == "Instance" and v:GetFullName() or tostring(v)
	end
	local line = ("[%7.2f][%s] %s"):format(os.clock(), tostring(level):upper(), table.concat(parts, " "))
	self._log[#self._log + 1] = line
	if #self._log > 800 then
		table.remove(self._log, 1)
	end
	if self._verbose then
		if type(rconsoleprint) == "function" then
			pcall(rconsoleprint, line .. "\n")
		else
			print(line)
		end
	end
	return line
end

function UI:SetVerbose(on)
	self._verbose = on and true or false
	if self._verbose and type(rconsolename) == "function" then
		pcall(rconsolename, "EasyUI Debug")
	end
	return self
end

function UI:GetLog()
	return table.concat(self._log or {}, "\n")
end

function UI:ClearLog()
	self._log = {}
end

function UI:CopyLog()
	if type(setclipboard) == "function" then
		return (pcall(setclipboard, self:GetLog()))
	end
	return false
end

function UI:OpenConsole()
	self._verbose = true
	if type(rconsolecreate) == "function" then pcall(rconsolecreate) end
	if type(rconsolename) == "function" then pcall(rconsolename, "EasyUI Debug") end
	if type(rconsoleprint) == "function" then pcall(rconsoleprint, self:GetLog() .. "\n") end
	return self
end

local function richText(text, o)
	o = o or {}
	local s = escapeRich(text)
	if o.color then s = ('<font color="%s">%s</font>'):format(Color.hex(o.color), s) end
	if o.size then s = ('<font size="%d">%s</font>'):format(o.size, s) end
	if o.face or o.font then s = ('<font face="%s">%s</font>'):format(tostring(o.face or o.font), s) end
	if o.bold then s = "<b>" .. s .. "</b>" end
	if o.italic then s = "<i>" .. s .. "</i>" end
	if o.underline then s = "<u>" .. s .. "</u>" end
	if o.strike then s = "<s>" .. s .. "</s>" end
	return s
end

function UI.LoadFont(source)
	local ok, f = pcall(function()
		local id = source
		if type(getcustomasset) == "function" and not tostring(source):match("^rbx") then
			id = getcustomasset(source)
		end
		return Font.new(id)
	end)
	return ok and f or nil
end

UI.Toolkit = {
	Color = Color,
	Create = new,
	Tween = tw,
	Theme = Theme,
	Kinds = Kind,
	Easing = E,
	PathGet = pathGet,
	PathSet = pathSet,
	RegisterWidget = UI.RegisterWidget,
	RegisterHUD = UI.RegisterHUD,
	RegisterMedia = UI.RegisterMedia,
	Extend = UI.Extend,
	Rich = richText,
	LoadFont = UI.LoadFont,
	Layers = Layers,
	Visuals = Visuals,
	Layer = function(name) return Layers[name] end,
	SetLayer = function(name, z) Layers[name] = z return z end,
	VisualLayer = function(name) return Visuals[name] end,
	SetVisualLayer = function(name, z) Visuals[name] = z return z end,
}

return UI
