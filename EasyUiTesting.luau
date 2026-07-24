local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Tween = game:GetService("TweenService")
local Run = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Http = game:GetService("HttpService")

local LP = Players.LocalPlayer

local Theme = {
	Font = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
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

local E = {
	Smooth = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Snap = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Now = TweenInfo.new(0.04, Enum.EasingStyle.Linear),
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
	local ok, v = pcall(function()
		return TextSvc:GetTextSize(text, size, font, Vector2.new(4000, 40)).X
	end)
	return ok and v or (#tostring(text) * size * 0.5)
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
	ui._dragMove, ui._dragUp = move, up
end

local function pathGet(root, path)
	local value = root
	for key in tostring(path):gmatch("[^.]+") do
		value = type(value) == "table" and value[key] or nil
		if value == nil then
			break
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
		local key = keys[i]
		if type(root[key]) ~= "table" then
			root[key] = {}
		end
		root = root[key]
	end
	if keys[1] then
		root[keys[#keys]] = value
	end
	return value
end

local function packValue(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __t = "c", r = value.R, g = value.G, b = value.B }
	end
	if kind == "EnumItem" then
		local enum, item = tostring(value):match("Enum%.([^.]+)%.(.+)")
		return { __t = "e", enum = enum, item = item }
	end
	if type(value) == "table" then
		local out = {}
		for k, v in pairs(value) do
			local packed = packValue(v)
			if packed ~= nil then
				out[k] = packed
			end
		end
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
		return Enum[value.enum] and Enum[value.enum][value.item] or nil
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

local function draggable(ui, handle, target, finished)
	handle.Active = true
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			local start = Input:GetMouseLocation()
			local base = target.Position
			beginDrag(ui, function(m)
				local d = m - start
				target.Position = UDim2.new(base.X.Scale, base.X.Offset + d.X, base.Y.Scale, base.Y.Offset + d.Y)
			end, finished)
		end
	end)
end

local function mountGui()
	local g = new("ScreenGui", {
		Name = "EasyUI_" .. tostring(math.random(1e5, 9e5)),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
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
		g.Parent = LP and LP:WaitForChild("PlayerGui") or CoreGui
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
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}
end

function UI.new(o)
	o = o or {}
	local self = setmetatable({}, UI)
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
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
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
	self.toggleKey = o.toggleKey or Enum.KeyCode.RightShift
	self.visible = true
	self.tabs = {}
	self._windows = {}
	self._mounts = {}
	self._jobs = {}
	self._jobOrder = {}
	self._jobsDirty = false
	self._queue = {}
	self._queued = {}
	self._queueSeq = 0
	self._validators = {}
	self._accentUpdaters = {}
	self._tweens = setmetatable({}, { __mode = "k" })
	self.widgets = {}
	self.flags = {}
	self._flagWidgets = {}
	self._features = {}
	self._runtimeFolder = new("Folder", { Name = "Runtime", Archivable = false, Parent = self.gui })
	if o.accent then
		Theme.Accent = o.accent
	end

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

	new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://5554236805",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(23, 23, 277, 277),
		Size = UDim2.new(1, 60, 1, 60),
		Position = UDim2.new(0, -30, 0, -30),
		ZIndex = 0,
		Parent = win,
	})
	local scale = new("UIScale", { Scale = 1, Parent = win })
	self._scale = scale

	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = win })
	draggable(self, bar, win)
	local dot = new("Frame", {
		Size = UDim2.fromOffset(9, 9),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
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
		self:SetVisible(false)
	end)

	new("Frame", {
		Size = UDim2.new(1, -32, 0, 1),
		Position = UDim2.new(0, 16, 0, 42),
		BackgroundColor3 = Theme.Soft,
		BorderSizePixel = 0,
		Parent = win,
	})

	local side = new("Frame", {
		Size = UDim2.new(0, 150, 1, -54),
		Position = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = win,
	})
	pad(12, side, 12, 6, 6, 12)
	list(side, 4)
	self._side = side

	local content = new("Frame", {
		Size = UDim2.new(1, -150, 1, -54),
		Position = UDim2.new(0, 150, 0, 50),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = win,
	})
	self._content = content

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
	draggable(self, wm, wm)
	local wmDot = new("Frame", {
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
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
	local function paint(fps)
		if not wmt.Parent then
			return
		end
		wmt.Text = self.title .. "  •  " .. gameName .. "  •  " .. fps .. " fps"
		wm.Size = UDim2.fromOffset(textWidth(wmt.Text, 12, Theme.Mono) + 42, 28)
	end
	task.spawn(function()
		local info = self:GameInfo()
		if info and info.name then
			gameName = info.name
			paint(0)
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
		if gp then
			return
		end
		if self._captureKey and i.KeyCode ~= Enum.KeyCode.Unknown then
			local capture = self._captureKey
			self._captureKey = nil
			capture(i)
			return
		end
		if i.KeyCode == self.toggleKey then
			self:SetVisible(not self.visible)
			return
		end
		if i.KeyCode ~= Enum.KeyCode.Unknown then
			for _, wd in ipairs(self.widgets) do
				if wd.bindKey == i.KeyCode and wd.activate then
					task.spawn(wd.activate)
				end
			end
		end
	end)
	self:_ctxInit()
	if o.cursor then self:SetCursor(true, type(o.cursor) == "table" and o.cursor or nil) end
	if o.keybindHud then self:SetKeybindHUD(true, type(o.keybindHud) == "table" and o.keybindHud or nil) end

	local function reveal()
		win.Visible = true
		scale.Scale = 0.9
		win.BackgroundTransparency = 1
		tw(win, E.Pop, { BackgroundTransparency = 0 })
		tw(scale, E.Pop, { Scale = 1 })
	end
	if o.loader == false then
		reveal()
	else
		win.Visible = false
		self:_showLoader(o.loadTime or 1.8, reveal)
	end
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
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		ZIndex = 102,
		Parent = beaker,
	})
	local blobs = {}
	for i = 1, 3 do
		local b = new("Frame", {
			Size = UDim2.fromOffset(72, 72),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Accent,
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
					end
				end
				out.Completed:Connect(function()
					overlay:Destroy()
				end)
			end)
		end
	end)
end

function UI:SetVisible(v)
	self.visible = v
	if not v then
		if self._openPicker then self._openPicker.Visible = false self._openPicker = nil self._openPickerSw = nil end
		self:_closeContext()
	end
	if self._cursorNative ~= nil then
		Input.MouseIconEnabled = not v and not self._cursorAlways and self._cursorNative or false
	end
	for _, window in pairs(self._windows) do
		window.frame.Visible = v and window.open
	end
	if v then
		self.window.Visible = true
		self._scale.Scale = 0.92
		self.window.BackgroundTransparency = 1
		tw(self.window, E.Pop, { BackgroundTransparency = 0 })
		tw(self._scale, E.Pop, { Scale = 1 })
	else
		tw(self._scale, E.Smooth, { Scale = 0.92 })
		local t = tw(self.window, E.Smooth, { BackgroundTransparency = 1 })
		t.Completed:Connect(function()
			if not self.visible then
				self.window.Visible = false
			end
		end)
	end
end

function UI:Close()
	if self._closing or not self.gui.Parent then
		return
	end
	self._closing = true
	self._dragMove, self._dragUp = nil, nil
	self:SetCursor(false)
	if self._espLink then
		self._espLink:detach()
	end
	while next(self._features) do self:Drop(next(self._features)) end
	self:_cleanup()
	tw(self._scale, E.Smooth, { Scale = 0.85 })
	local t = tw(self.window, E.Smooth, { BackgroundTransparency = 1 })
	t.Completed:Connect(function()
		self.gui:Destroy()
	end)
end

function UI:SetAccent(c)
	Theme.Accent = c
	self._dot.BackgroundColor3 = c
	if self._wmDot then
		self._wmDot.BackgroundColor3 = c
	end
	if self._cursor then
		self._cursor.BackgroundColor3 = c
	end
	for _, update in ipairs(self._accentUpdaters) do update(c) end
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
	if self._cursorEnabled then return self._cursor or self._cursorPaint end
	self._cursorEnabled, self._cursorAlways = true, o.always == true
	self._cursorNative = Input.MouseIconEnabled
	Input.MouseIconEnabled = false
	if type(DrawingImmediate) == "table" and type(DrawingImmediate.GetPaint) == "function" and type(DrawingImmediate.FilledTriangle) == "function" then
		self._cursorPaint = DrawingImmediate.GetPaint(1000):Connect(function()
			if self.visible or o.always then
				local p, size = Input:GetMouseLocation(), o.size or 14
				DrawingImmediate.FilledTriangle(p, p + Vector2.new(0, size), p + Vector2.new(size * 0.7, size * 0.7), o.color or Theme.Accent, 1)
			end
		end)
		return self._cursorPaint
	end
	local cursor = new("Frame", { Size = UDim2.fromOffset(o.size or 12, o.size or 12), AnchorPoint = Vector2.new(0.15, 0.15), Rotation = 45, BackgroundColor3 = o.color or Theme.Accent, BorderSizePixel = 0, ZIndex = 1000, Parent = self.gui })
	corner(2, cursor)
	stroke(Color3.new(0, 0, 0), 1, 0.25, cursor)
	self._cursor = cursor
	self._cursorRemove = self:Schedule("cursor", function()
		local p = Input:GetMouseLocation()
		cursor.Position = UDim2.fromOffset(p.X, p.Y)
		cursor.Visible = self.visible or o.always
	end, nil, 1000)
	return cursor
end

function UI:_refreshBindHUD()
	if not self._bindHud then return end
	for _, child in ipairs(self._bindHudBody:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	local count = 0
	for _, widget in ipairs(self.widgets) do
		if widget.bindKey and widget.activate then
			count += 1
			local row = label("[" .. widget.bindKey.Name .. "]  " .. ((widget.opt and widget.opt.text) or widget.kind), 11, Theme.Sub, Theme.Mono, self._bindHudBody)
			row.Size = UDim2.new(1, 0, 0, 16)
		end
	end
	self._bindHud.Size = UDim2.fromOffset(220, 34 + count * 18)
	self._bindHud.Visible = count > 0
end

function UI:SetKeybindHUD(enabled, o)
	o = o or {}
	if not enabled then
		if self._bindHud then self._bindHud:Destroy() self._bindHud = nil end
		return
	end
	if self._bindHud then return self._bindHud end
	local hud = new("Frame", { Size = UDim2.fromOffset(220, 34), Position = o.position or UDim2.new(0, 16, 0, 54), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = self.gui })
	corner(10, hud)
	stroke(Theme.Stroke, 1, 0.1, hud)
	draggable(self, hud, hud)
	local title = label(o.title or "Keybinds", 12, Theme.Text, Theme.Bold, hud)
	title.Position = UDim2.new(0, 10, 0, 4)
	title.Size = UDim2.new(1, -20, 0, 20)
	local body = new("Frame", { Size = UDim2.new(1, -20, 1, -28), Position = UDim2.new(0, 10, 0, 26), BackgroundTransparency = 1, Parent = hud })
	list(body, 2)
	self._bindHud, self._bindHudBody = hud, body
	self:_refreshBindHUD()
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
				end
				if self._jobs[pair[1]] == job and job.elapsed >= job.step then
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
	local index, count = 1, #items
	local handle = { running = true, processed = 0, total = count }
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
					local done, ok, err = false
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
		return type(feature) == "function" and feature(self, folder, own) or feature
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
	local flag = "features." .. name .. ".enabled"
	self.flags[flag] = true
	self._flagWidgets[flag] = { Set = function(_, enabled)
		self:SetFeatureEnabled(name, enabled)
	end, Get = function()
		return entry.enabled
	end }
	return value
end

function UI:Drop(name)
	local entry = self._features[tostring(name)]
	if not entry then
		return false
	end
	self._features[tostring(name)] = nil
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
		local fn = type(value) == "table" and (entry.enabled and (value.Start or value.start) or (value.Stop or value.stop))
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
				return type(loaded) == "function" and loaded(ctx) or loaded
			end)
		end)
		if handle.cancelled then
			self:Drop(name)
			return
		end
		handle.status = ok and "running" or "failed"
		handle.value, handle.error = ok and result or nil, ok and nil or result
		if not ok then
			warn("[EasyUI] " .. tostring(result))
		end
	end)
	function handle:Cancel()
		self.cancelled = true
		self.cancel()
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
	if self._gameInfo then
		return self._gameInfo
	end
	local info = {
		placeId = game.PlaceId,
		gameId = game.GameId,
		jobId = game.JobId,
		name = ("Place %d"):format(game.PlaceId),
		creator = "",
		players = #Players:GetPlayers(),
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
	return info
end

function UI:Mount(name, root)
	assert(type(root) == "table", "Mount root must be a table")
	self._mounts[tostring(name)] = root
	return root
end

function UI:Unmount(name)
	local root = self._mounts[tostring(name)]
	self._mounts[tostring(name)] = nil
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
		value = validate and validate(path, value) or value
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
			if value ~= nil and api.Set then
				api:Set(value)
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
		if bindId and widget.activate then
			binds[bindId] = widget.bindKey and packValue(widget.bindKey) or { __t = "n" }
		end
	end
	return Http:JSONEncode({ version = 1, values = values, binds = binds, mounts = mounts, accent = packValue(Theme.Accent) })
end

function UI:ImportConfig(json)
	local ok, data = pcall(Http.JSONDecode, Http, json)
	if not ok or type(data) ~= "table" or data.version ~= 1 or data.values ~= nil and type(data.values) ~= "table" or data.binds ~= nil and type(data.binds) ~= "table" or data.mounts ~= nil and type(data.mounts) ~= "table" then
		return false
	end
	for name, packed in pairs(data.mounts or {}) do
		local root, decoded = self._mounts[name], unpackValue(packed)
		if root and type(decoded) == "table" then
			for key in pairs(root) do root[key] = nil end
			for key, value in pairs(decoded) do root[key] = value end
		end
	end
	for flag, packed in pairs(data.values or {}) do
		self:Set(flag, unpackValue(packed))
	end
	for _, widget in ipairs(self.widgets) do
		local bindId = widget.opt and (widget.opt.bindId or widget.opt.flag or widget.opt.id or widget.opt.text)
		local packed = bindId and data.binds and data.binds[bindId]
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
	return pcall(writefile, "EasyUI/" .. safeName(name) .. ".json", self:ExportConfig())
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
	return pcall(delfile, path)
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
	return pcall(writefile, "EasyUI/autoload.json", safeName(name))
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
	local name = section:Textbox({ text = "Name", default = o.default or "default" })
	local profiles = section:Dropdown({ text = "Saved", options = self:ListConfigs() })
	local function selected() return name:Get() ~= "" and name:Get() or profiles:Get() or "default" end
	section:Button({ text = "Save", callback = function() self:SaveConfig(selected()) profiles:SetItems(self:ListConfigs()) end })
	section:Button({ text = "Load", callback = function() self:LoadConfig(selected()) end })
	section:Button({ text = "Delete", callback = function() self:DeleteConfig(selected()) profiles:SetItems(self:ListConfigs()) end })
	section:Button({ text = "Set Autoload", callback = function() self:SetAutoload(selected()) end })
	return tab
end

UI.CFG = UI.ExportConfig
UI.ICFG = UI.ImportConfig
UI.SCFG = UI.SaveConfig
UI.LCFG = UI.LoadConfig

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

local function addTab(m, scope, name, parent)
	local depth = parent and ((parent.depth or 0) + 1) or 0
	local btn = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Control,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = #scope.tabs + 1,
		Parent = scope._side,
	})
	corner(8, btn)
	local bs = stroke(Theme.Soft, 1, 1, btn)
	local tl = label(name, 13, Theme.Sub, Theme.Font, btn)
	tl.Position = UDim2.new(0, 12 + depth * 10, 0, 0)
	tl.Size = UDim2.new(1, -12 - depth * 10, 1, 0)

	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = scope._content,
	})
	pad(14, page, 14, 12, 14, 16)
	local pl = list(page, 12)
	pl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, pl.AbsoluteContentSize.Y + 28)
	end)

	local tab = { button = btn, stroke = bs, page = page, label = tl, depth = depth, parent = parent, scope = scope }
	scope.tabs[#scope.tabs + 1] = tab

	local function activate()
		for _, t in ipairs(scope.tabs) do
			t.page.Visible = false
			tw(t.button, E.Fast, { BackgroundTransparency = 1 })
			tw(t.stroke, E.Fast, { Transparency = 1 })
			tw(t.label, E.Fast, { TextColor3 = Theme.Sub })
		end
		page.Visible = true
		tw(btn, E.Fast, { BackgroundTransparency = 0 })
		tw(bs, E.Fast, { Transparency = 0 })
		tw(tl, E.Fast, { TextColor3 = Theme.Text })
	end
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
	tab.activate = activate
	if #scope.tabs == 1 then
		task.defer(activate)
	end
	return setmetatable({ _m = m, _page = page, _entry = tab, _scope = scope }, { __index = UI._Tab })
end

function UI:Tab(name)
	return addTab(self, self, name)
end

function UI._Tab:SubTab(name)
	return addTab(self._m, self._scope, name, self._entry)
end

UI._Tab.Tab = UI._Tab.SubTab
function UI._Tab:Open() self._entry.activate() return self end

function UI:Window(id, o)
	o = o or {}
	id = tostring(id)
	local old = self._windows[id]
	if old then
		return old
	end
	local w, h = o.width or 360, o.height or 320
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
	local title = label(type(o.header) == "table" and o.header.text or o.header or id, 13, Theme.Text, Theme.Bold, bar)
	title.Position = UDim2.new(0, 14, 0, 0)
	title.Size = UDim2.new(1, -50, 1, 0)
	local side = new("Frame", { Size = UDim2.new(0, 112, 1, -46), Position = UDim2.new(0, 0, 0, 42), BackgroundTransparency = 1, Parent = frame })
	pad(8, side)
	list(side, 4)
	local content = new("Frame", { Size = UDim2.new(1, -112, 1, -46), Position = UDim2.new(0, 112, 0, 42), BackgroundTransparency = 1, ClipsDescendants = true, Parent = frame })
	local window = setmetatable({ _m = self, id = id, flag = o.flag, frame = frame, scale = scale, _side = side, _content = content, tabs = {}, open = o.open ~= false }, UI._Window)
	self._windows[id] = window
	draggable(self, bar, frame, function()
		if o.flag then
			self:_write(o.flag, window:GetState())
		end
	end)
	if o.close ~= false then
		local close = new("TextButton", { Text = "×", TextSize = 18, TextColor3 = Theme.Sub, Font = Theme.Font, AutoButtonColor = false, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0, 5), BackgroundColor3 = Theme.Control, BorderSizePixel = 0, Parent = bar })
		corner(8, close)
		close.MouseButton1Click:Connect(function() window:Close() end)
	end
	if o.flag then
		self.flags[o.flag] = window:GetState()
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
	self.frame.Position = UDim2.fromOffset(state.x or self.frame.Position.X.Offset, state.y or self.frame.Position.Y.Offset)
	self.frame.Size = UDim2.fromOffset(state.width or self.frame.Size.X.Offset, state.height or self.frame.Size.Y.Offset)
	self:SetVisible(state.open ~= false)
end
function UI._Window:Destroy()
	self._m._windows[self.id] = nil
	if self.flag then self._m._flagWidgets[self.flag] = nil end
	self.frame:Destroy()
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
	if o.start ~= false and esp.start then esp:start() link.started = true end
	if o.build ~= false and esp.GetDescriptors then
		local nodes, sections, windows = {}, {}, {}
		local function node(scope, parent, key)
			local full = tostring(scope.id or "main") .. "/" .. (parent and parent._key .. "/" or "") .. key
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
					windows[windowName] = self:Window("ESP " .. windowName, { x = 80 + index * 28, y = 70 + index * 24, width = o.width or 430, height = o.height or 390, header = windowName, open = o.open ~= false })
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
				if #self.widgets > before then link.widgets[#link.widgets + 1] = self.widgets[#self.widgets] end
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
		for _, flag in ipairs(self.flags) do self.ui._flagWidgets[flag] = nil end
		self.ui:Unmount(self.prefix)
		self.ui._validators[self.prefix] = nil
		if self.own and self.esp.destroy then self.esp:destroy() elseif self.started and o.stopOnDetach and self.esp.stop then self.esp:stop() end
		if self.ui._espLink == self then self.ui._espLink = nil end
		return true
	end
	self._espLink = link
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
	for i = #scope.tabs, 1, -1 do
		local tab = scope.tabs[i]
		local owner = tab
		while owner and owner ~= entry do owner = owner.parent end
		if owner == entry then
			tab.button:Destroy()
			tab.page:Destroy()
			table.remove(scope.tabs, i)
		end
	end
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
	local col = Kind[kind] or Theme.Accent
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
	local state = stored ~= nil and stored or (o.default or false)
	if stored == false then state = false end
	local r = rowFrame(self._card, 28)
	local l = label(o.text or "Toggle", 13, Theme.Text, Theme.Font, r)
	l.Size = UDim2.new(1, -50, 1, 0)
	local track = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(40, 22),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = state and Theme.Accent or Theme.Control,
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
	self._m._accentUpdaters[#self._m._accentUpdaters + 1] = function(c) if state then track.BackgroundColor3 = c end end

	local api = {}
	function api:Set(v)
		state = v and true or false
		tw(track, E.Smooth, { BackgroundColor3 = state and Theme.Accent or Theme.Control })
		tw(knob, E.Snap, {
			Position = state and UDim2.new(1, -3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			AnchorPoint = Vector2.new(state and 1 or 0, 0.5),
			BackgroundColor3 = state and Theme.Window or Theme.Sub,
		})
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
	self._m:_reg({ kind = "toggle", opt = o, row = r, activate = function()
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
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track })
	self._m._accentUpdaters[#self._m._accentUpdaters + 1] = function(c) fill.BackgroundColor3 = c end
	corner(999, fill)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Text,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = track,
	})
	corner(999, knob)
	stroke(Theme.Soft, 1, 0, knob)

	local function fmt(v)
		if dec > 0 then
			return string.format("%." .. dec .. "f", v)
		end
		return tostring(math.floor(v + 0.5))
	end
	local api = {}
	local function apply(v, anim)
		value = math.clamp(math.floor(v / step + 0.5) * step, min, max)
		local span = max - min
		local a = span == 0 and 0 or (value - min) / span
		if anim then
			tw(fill, E.Fast, { Size = UDim2.new(a, 0, 1, 0) })
			tw(knob, E.Fast, { Position = UDim2.new(a, 0, 0.5, 0) })
		else
			fill.Size = UDim2.new(a, 0, 1, 0)
			knob.Position = UDim2.new(a, 0, 0.5, 0)
		end
		val.Text = fmt(value)
		if o.flag then
			self._m:_write(o.flag, value)
		end
		if o.callback then
			task.spawn(o.callback, value)
		end
	end
	function api:Set(v)
		apply(v, true)
	end
	function api:Get()
		return value
	end
	apply(value, false)
	if o.flag then
		self._m._flagWidgets[o.flag] = api
	end
	local dragging = false
	local function fromX()
		local a = math.clamp((Input:GetMouseLocation().X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		apply(min + a * (max - min), false)
	end
	track.MouseButton1Down:Connect(function()
		dragging = true
		fromX()
		beginDrag(self._m, function()
			if dragging then
				fromX()
			end
		end, function()
			dragging = false
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
	local l = label((o.text and o.text .. ":  " or "") .. tostring(value), 13, Theme.Text, Theme.Font, head)
	l.Position = UDim2.new(0, 10, 0, 0)
	l.Size = UDim2.new(1, -34, 1, 0)
	local arrow = label("▾", 12, Theme.Sub, Theme.Font, head)
	arrow.Position = UDim2.new(1, -22, 0, 0)
	arrow.Size = UDim2.fromOffset(16, 30)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 34),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Visible = false,
		Parent = holder,
	})
	corner(8, body)
	stroke(Theme.Soft, 1, 0, body)
	pad(4, body)
	local bodyLayout = list(body, 3)
	local function updHolder()
		body.Size = UDim2.new(1, 0, 0, bodyLayout.AbsoluteContentSize.Y + 8)
		holder.Size = UDim2.new(1, 0, 0, open and (34 + body.Size.Y.Offset) or 30)
	end
	bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updHolder)

	local api = {}
	local m = self._m
	function api:Get()
		return value
	end
	function api:Set(v)
		value = v
		l.Text = (o.text and o.text .. ":  " or "") .. tostring(value)
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
		items = t
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
		key = typeof(value) == "EnumItem" and value or nil
		bl.Text = key and key.Name or "None"
		if wd then wd.bindKey = key end
		if o.flag then self._m:_write(o.flag, key) end
		self._m:_refreshBindHUD()
	end
	b.MouseButton1Click:Connect(function()
		bl.Text = "..."
		tw(b, E.Fast, { BackgroundColor3 = Theme.Hover })
		self._m._captureKey = function(i)
			tw(b, E.Fast, { BackgroundColor3 = Theme.Control })
			if i.KeyCode == Enum.KeyCode.Escape then api:Set(nil) else api:Set(i.KeyCode) end
			if o.onChange then
				task.spawn(o.onChange, key)
			end
		end
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
		TextColor3 = Theme.Text,
		Font = Theme.Font,
		TextSize = 13,
		ClearTextOnFocus = false,
		Parent = r,
	})
	corner(8, box)
	local st = stroke(Theme.Soft, 1, 0, box)
	pad(0, box, 10, 0, 10, 0)
	box.Focused:Connect(function()
		tw(st, E.Fast, { Color = Theme.Accent })
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
		box.Text = t2
		if o.flag then
			self._m:_write(o.flag, t2)
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
	local color = typeof(stored) == "Color3" and stored or o.default or Theme.Accent
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
		ZIndex = 40,
		Parent = self._m.gui,
	})
	r.AncestryChanged:Connect(function(_, parent) if not parent and pop.Parent then pop:Destroy() end end)
	corner(8, pop)
	stroke(Theme.Stroke, 1, 0, pop)
	pad(8, pop)
	local sat = new("ImageButton", {
		Size = UDim2.new(1, -30, 1, -42),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 41,
		Parent = pop,
	})
	corner(6, sat)
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 42, Parent = sat })
	corner(6, white)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = white })
	local dark = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 42, Parent = sat })
	corner(6, dark)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = dark })
	local satMark = new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 43, Parent = sat })
	corner(999, satMark)
	stroke(Color3.new(0, 0, 0), 1, 0, satMark)
	local hueBar = new("ImageButton", {
		Size = UDim2.new(0, 22, 1, -42),
		Position = UDim2.new(1, -22, 0, 0),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ZIndex = 41,
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
	local hueMark = new("Frame", { Size = UDim2.new(1, 4, 0, 3), Position = UDim2.new(0, -2, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 43, Parent = hueBar })
	stroke(Color3.new(0, 0, 0), 1, 0, hueMark)
	local hex = new("TextBox", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -30), BackgroundColor3 = Theme.Control, BorderSizePixel = 0, TextColor3 = Theme.Text, PlaceholderText = "#FFFFFF", TextSize = 12, Font = Theme.Mono, ClearTextOnFocus = false, ZIndex = 42, Parent = pop })
	corner(6, hex)
	pad(0, hex, 8, 0, 8, 0)
	local hu, sa, va = color:ToHSV()
	local api = {}
	local function refresh()
		color = Color3.fromHSV(hu, sa, va)
		sw.BackgroundColor3 = color
		sat.BackgroundColor3 = Color3.fromHSV(hu, 1, 1)
		satMark.Position = UDim2.fromScale(sa, 1 - va)
		hueMark.Position = UDim2.new(0, -2, hu, -1)
		hex.Text = Color.hex(color)
		if o.flag then
			self._m:_write(o.flag, color)
		end
		if o.callback then
			task.spawn(o.callback, color)
		end
	end
	local ds, dh
	sat.MouseButton1Down:Connect(function()
		ds = true
		local m = Input:GetMouseLocation()
		sa = math.clamp((m.X - sat.AbsolutePosition.X) / math.max(sat.AbsoluteSize.X, 1), 0, 1)
		va = 1 - math.clamp((m.Y - sat.AbsolutePosition.Y) / math.max(sat.AbsoluteSize.Y, 1), 0, 1)
		refresh()
		beginDrag(self._m, function(m)
			if ds then
				sa = math.clamp((m.X - sat.AbsolutePosition.X) / sat.AbsoluteSize.X, 0, 1)
				va = 1 - math.clamp((m.Y - sat.AbsolutePosition.Y) / sat.AbsoluteSize.Y, 0, 1)
				refresh()
			end
		end, function()
			ds = false
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
	refresh()
	function api:Get()
		return color
	end
	function api:Set(c)
		hu, sa, va = c:ToHSV()
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

function UI:RegisterMedia(kind, handler)
	UI._mediaHandlers[string.lower(tostring(kind))] = handler
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
	if not ext then
		ext = body:sub(1, 8) == "\137PNG\r\n\26\n" and "png" or body:sub(1, 3) == "\255\216\255" and "jpg" or body:sub(1, 3) == "ID3" and "mp3" or nil
	end
	assert(ext, "Unknown media format")
	local folder = "EasyUI/media"
	if type(makefolder) == "function" then
		pcall(makefolder, "EasyUI")
		pcall(makefolder, folder)
	end
	local path = folder .. "/" .. safeName(o.name or tostring(math.abs(#url * 7919 + #body))) .. "." .. ext
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
	local frame = own(new("Frame", { Size = UDim2.fromOffset(o.width or 260, 34), Position = o.position or UDim2.new(0.5, -130, 0, 18), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = ui.gui }))
	corner(10, frame)
	stroke(Theme.Stroke, 1, 0.1, frame)
	local text = label("N  000°", 12, Theme.Text, Theme.Mono, frame)
	text.Size = UDim2.fromScale(1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Center
	local remove = own(ui:Every("hud:compass", o.interval or 0.05, function()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local look = camera.CFrame.LookVector
		local degrees = (math.deg(math.atan2(-look.X, -look.Z)) + 360) % 360
		local index = math.floor((degrees + 22.5) / 45) % 8 + 1
		text.Text = ({ "N", "NE", "E", "SE", "S", "SW", "W", "NW" })[index] .. ("  %03d°"):format(math.floor(degrees + 0.5) % 360)
	end, o.priority or 10))
	return { SetEnabled = function(_, enabled) frame.Visible = enabled end, Remove = remove }
end)

function UI:Notify(o)
	o = o or {}
	local dur = o.duration or 4
	local col = Kind[o.kind] or Theme.Accent
	if not self._toasts then
		self._toasts = new("Frame", {
			Size = UDim2.new(0, 290, 1, -32),
			Position = UDim2.new(1, -16, 1, -16),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Parent = self.gui,
		})
		local ll = list(self._toasts, 8)
		ll.VerticalAlignment = Enum.VerticalAlignment.Bottom
		ll.HorizontalAlignment = Enum.HorizontalAlignment.Right
	end
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Position = UDim2.new(1, 320, 0, 0),
		Parent = self._toasts,
	})
	corner(10, card)
	stroke(Theme.Stroke, 1, 0.05, card)
	pad(10, card, 16, 10, 12, 10)
	local acc = new("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.new(0, 4, 0, 8), BackgroundColor3 = col, BorderSizePixel = 0, Parent = card })
	corner(999, acc)
	local t = label(o.title or "Notice", 13, Theme.Text, Theme.Bold, card)
	t.Position = UDim2.new(0, 6, 0, 0)
	t.Size = UDim2.new(1, -6, 0, 18)
	local msg = label(o.text or "", 12, Theme.Sub, Theme.Font, card)
	msg.Position = UDim2.new(0, 6, 0, 18)
	msg.Size = UDim2.new(1, -6, 0, 16)
	msg.TextWrapped = true
	local prog = new("Frame", { Size = UDim2.new(1, -12, 0, 2), Position = UDim2.new(0, 6, 1, -6), BackgroundColor3 = col, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = card })
	corner(999, prog)
	tw(card, E.Pop, { Position = UDim2.new(1, 0, 0, 0) })
	tw(prog, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })
	task.delay(dur, function()
		if not card.Parent then
			return
		end
		local out = tw(card, E.Smooth, { Position = UDim2.new(1, 340, 0, 0), BackgroundTransparency = 1 })
		out.Completed:Connect(function()
			card:Destroy()
		end)
	end)
end

function UI:_ctxInit()
	local pop = new("Frame", {
		Size = UDim2.fromOffset(210, 40),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
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
		end
		if pop.Visible and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			if not inside(pop, Input:GetMouseLocation()) then
				self:_closeContext()
			end
		end
	end)
end

function UI:_closeContext()
	if self._ctx then self._ctx.Visible = false end
	for flag, api in pairs(self._ctxFlags or {}) do
		if self._flagWidgets[flag] == api.current then self._flagWidgets[flag] = api.previous end
	end
	self._ctxFlags = {}
end

function UI:_openContext(wd)
	local pop = self._ctx
	self._captureKey = nil
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
			self._captureKey = function(i)
				if i.KeyCode == Enum.KeyCode.Escape then
					wd.bindKey = nil
					bl.Text = "None"
				elseif i.KeyCode ~= Enum.KeyCode.Unknown then
					wd.bindKey = i.KeyCode
					bl.Text = i.KeyCode.Name
				end
				self:_refreshBindHUD()
			end
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
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	pop.Position = UDim2.fromOffset(math.clamp(m.X + 4, 4, math.max(4, viewport.X - 214)), math.clamp(m.Y + 4, 4, math.max(4, viewport.Y - pop.AbsoluteSize.Y - 4)))
	pop.Visible = true
	pop.BackgroundTransparency = 1
	self._ctxScale.Scale = 0.9
	tw(pop, E.Fast, { BackgroundTransparency = 0 })
	tw(self._ctxScale, E.Pop, { Scale = 1 })
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
	stroke(Theme.Accent, 1.5, 0, box)
	corner(3, box)
	local nm = label("Player", 11, Theme.Text, Theme.Bold, holder)
	nm.Size = UDim2.fromOffset(120, 14)
	nm.AnchorPoint = Vector2.new(0.5, 1)
	nm.TextXAlignment = Enum.TextXAlignment.Center
	local hp = new("Frame", { Size = UDim2.fromOffset(3, 150), BackgroundColor3 = Theme.Ok, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Parent = holder })
	corner(999, hp)
	local ang = 0
	self:_connect(Run.RenderStepped, function(dt)
		if not vp.Parent then
			return
		end
		ang += dt * 0.6
		model:SetPrimaryPartCFrame(CFrame.new(0, 0, 0) * CFrame.Angles(0, ang, 0))
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

UI.Toolkit = {
	Color = Color,
	Create = new,
	Tween = tw,
	Theme = Theme,
	Kinds = Kind,
	PathGet = pathGet,
	PathSet = pathSet,
	RegisterWidget = UI.RegisterWidget,
	RegisterHUD = UI.RegisterHUD,
	RegisterMedia = UI.RegisterMedia,
	Extend = UI.Extend,
}

return UI
