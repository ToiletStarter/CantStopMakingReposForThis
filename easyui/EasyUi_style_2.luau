local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local UI = {}
UI.__index = UI
UI._VERSION = "1.0.0"
UI._STYLE = "style_2"

local function fontOr(name, fallback)
    local ok, f = pcall(function()
        return Enum.Font[name]
    end)
    if ok and f then
        return f
    end
    return fallback
end

local Theme = {
    Font = fontOr("BuilderSans", fontOr("Gotham", Enum.Font.SourceSans)),
    Medium = fontOr("BuilderSansMedium", fontOr("GothamMedium", Enum.Font.SourceSansSemibold)),
    Bold = fontOr("BuilderSansBold", fontOr("GothamBold", Enum.Font.SourceSansBold)),
    Mono = Enum.Font.Code,

    Accent = Color3.fromRGB(96, 205, 255),
    Window = Color3.fromRGB(18, 19, 23),
    Titlebar = Color3.fromRGB(26, 28, 34),
    Panel = Color3.fromRGB(22, 23, 28),
    Card = Color3.fromRGB(28, 30, 36),
    Control = Color3.fromRGB(35, 37, 44),
    Hover = Color3.fromRGB(44, 47, 55),
    Stroke = Color3.fromRGB(52, 56, 66),
    Text = Color3.fromRGB(238, 240, 245),
    Sub = Color3.fromRGB(146, 152, 165),
    Muted = Color3.fromRGB(96, 102, 114),

    Ok = Color3.fromRGB(126, 224, 168),
    Warn = Color3.fromRGB(240, 206, 140),
    Err = Color3.fromRGB(240, 138, 148),
    Info = Color3.fromRGB(140, 190, 250),
}

local SPRING = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local DROPDOWN = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local DRAG = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    for _, c in ipairs(children or {}) do
        c.Parent = inst
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function corner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function pad(parent, all, extra)
    local p = create("UIPadding", {
        PaddingTop = UDim.new(0, all),
        PaddingBottom = UDim.new(0, all),
        PaddingLeft = UDim.new(0, all),
        PaddingRight = UDim.new(0, all),
        Parent = parent,
    })
    for k, v in pairs(extra or {}) do
        p[k] = UDim.new(0, v)
    end
    return p
end

local function list(parent, padding, direction)
    return create("UIListLayout", {
        Padding = UDim.new(0, padding or 6),
        FillDirection = direction or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

local function tween(inst, info, goal)
    local t = TweenService:Create(inst, info, goal)
    t:Play()
    return t
end

local function lerpColor(a, b, t)
    return a:Lerp(b, t)
end

local function hoverable(button, base, hover, target)
    target = target or button
    button.MouseEnter:Connect(function()
        tween(target, QUICK, { BackgroundColor3 = hover })
    end)
    button.MouseLeave:Connect(function()
        tween(target, QUICK, { BackgroundColor3 = base })
    end)
end

local function ripple(parent, accent)
    local ring = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        Parent = parent,
    })
    corner(ring, 999)
    local outline = stroke(ring, accent, 1, 0.15)
    local size = math.min(math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 0.7, 42)
    tween(ring, DROPDOWN, { Size = UDim2.fromOffset(size, size) })
    tween(outline, DROPDOWN, { Transparency = 1 })
    task.delay(0.2, function()
        if ring.Parent then
            ring:Destroy()
        end
    end)
end

local function bindingName(binding)
    if not binding then
        return "NONE"
    end
    local ok, name = pcall(function()
        return binding.Name
    end)
    return ok and name or tostring(binding)
end

local function inputBinding(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        return input.KeyCode
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.MouseButton3 then
        return input.UserInputType
    end
    return nil
end

local function bindingMatches(binding, input)
    return binding ~= nil and inputBinding(input) == binding
end

local function screenGui(name)
    local parent
    if gethui then
        local ok, h = pcall(gethui)
        if ok then
            parent = h
        end
    end
    parent = parent or (LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui"))
    local gui = create("ScreenGui", {
        Name = name,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
    })
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
    end
    gui.Parent = parent
    return gui
end

local Widget = {}
Widget.__index = Widget

function Widget.new(owner, kind, frame, opts)
    local widget = setmetatable({
        owner = owner,
        kind = kind,
        frame = frame,
        opts = opts or {},
        flag = opts and opts.flag,
    }, Widget)
    if widget.opts.context and owner.ui and owner.ui._bindContext then
        owner.ui:_bindContext(widget, frame, widget.opts.context)
    end
    return widget
end

function Widget:Set(value, silent)
    if self._set then
        self._set(value, silent)
    end
    return self
end

function Widget:Get()
    if self._get then
        return self._get()
    end
    return self.value
end

function Widget:Destroy()
    if self.frame then
        self.frame:Destroy()
    end
end

local Section = {}
Section.__index = Section

local Grid = {}
Grid.__index = Grid

local function childSection(ui, holder)
    return setmetatable({ ui = ui, holder = holder, layout = list(holder, ui.compact and 4 or 6), inline = true }, Section)
end

local function newSection(win, title)
    local holder = create("Frame", {
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 0.15,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = win._page,
    })
    corner(holder, 10)
    stroke(holder, Theme.Stroke, 1, 0.35)
    pad(holder, win.ui.compact and 8 or 10)
    local layout = list(holder, win.ui.compact and 4 or 7)
    if win.ui._styleNodes then
        table.insert(win.ui._styleNodes.cards, holder)
    end

    if title and title ~= "" then
        local head = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 15),
            Font = Theme.Bold,
            Text = string.upper(title),
            TextSize = 10,
            TextColor3 = Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = -1,
            Parent = holder,
        })
        head.Name = "SectionHeader"
    end

    return setmetatable({ win = win, ui = win.ui, holder = holder, layout = layout }, Section)
end

local function rowBase(section, height)
    local row = create("Frame", {
        BackgroundColor3 = Theme.Control,
        BackgroundTransparency = 0.35,
        Size = UDim2.new(1, 0, 0, height or (section.ui.compact and 26 or 30)),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = section.holder,
    })
    corner(row, 7)
    if section.ui._styleNodes then
        table.insert(section.ui._styleNodes.rows, row)
    end
    return row
end

local function rowLabel(row, text, inset)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, inset or 10, 0, 0),
        Size = UDim2.new(1, -(inset or 10) - 46, 1, 0),
        Font = Theme.Font,
        Text = text or "",
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
end

function Section:Label(text)
    local lbl = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = Theme.Font,
        Text = text or "",
        TextSize = 11,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = self.holder,
    })
    local w = Widget.new(self, "label", lbl, {})
    w._set = function(v)
        lbl.Text = tostring(v)
    end
    w._get = function()
        return lbl.Text
    end
    return w
end

function Section:Grid(columns, opts)
    opts = opts or {}
    columns = math.max(1, math.floor(tonumber(columns) or 2))
    local gap = opts.gap or (self.ui.compact and 5 or 7)
    local frame = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = self.holder,
    })
    list(frame, gap, Enum.FillDirection.Horizontal)
    local items = {}
    local offset = -gap * (columns - 1) / columns
    for i = 1, columns do
        local column = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1 / columns, offset, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0,
            LayoutOrder = i,
            Parent = frame,
        })
        items[i] = childSection(self.ui, column)
    end
    return setmetatable({ section = self, frame = frame, columns = items }, Grid)
end

function Section:Columns(columns, opts)
    return self:Grid(columns, opts)
end

function Grid:Column(index)
    return self.columns[index or 1]
end

function Grid:Each(callback)
    for index, column in ipairs(self.columns) do
        callback(column, index)
    end
    return self
end

function Grid:Destroy()
    if self.frame then
        self.frame:Destroy()
    end
end

function Section:Divider()
    local d = create("Frame", {
        BackgroundColor3 = Theme.Stroke,
        BackgroundTransparency = 0.4,
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        Parent = self.holder,
    })
    return Widget.new(self, "divider", d, {})
end

function Section:Badge(text, kind)
    local colors = { ok = Theme.Ok, warn = Theme.Warn, error = Theme.Err, info = Theme.Info }
    local row = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Parent = self.holder,
    })
    local chip = create("TextLabel", {
        BackgroundColor3 = colors[kind or "info"] or Theme.Info,
        BackgroundTransparency = 0.82,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = Theme.Medium,
        Text = "  " .. tostring(text) .. "  ",
        TextSize = 11,
        TextColor3 = colors[kind or "info"] or Theme.Info,
        Parent = row,
    })
    corner(chip, 6)
    local w = Widget.new(self, "badge", row, {})
    w._set = function(t, k)
        chip.Text = "  " .. tostring(t) .. "  "
        local c = colors[k or "info"] or Theme.Info
        tween(chip, QUICK, { TextColor3 = c, BackgroundColor3 = c })
    end
    return w
end

function Section:Toggle(opts)
    opts = opts or {}
    local ui = self.ui
    local row = rowBase(self)
    rowLabel(row, opts.text)

    local track = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(34, 18),
        BackgroundColor3 = Theme.Hover,
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(track, 999)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.Sub,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(knob, 999)

    local btn = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        Parent = row,
    })
    hoverable(btn, Theme.Control, Theme.Hover, row)

    local value = opts.default and true or false

    local function paint(animate)
        local info = animate and SPRING or TweenInfo.new(0)
        if value then
            tween(track, info, { BackgroundColor3 = ui.accent })
            tween(knob, info, { Position = UDim2.new(0, 18, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1) })
        else
            tween(track, info, { BackgroundColor3 = Theme.Hover })
            tween(knob, info, { Position = UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = Theme.Sub })
        end
    end

    local w = Widget.new(self, "toggle", row, opts)
    w._get = function()
        return value
    end
    w._set = function(v, silent)
        value = v and true or false
        paint(true)
        if opts.flag then
            ui:_writeFlag(opts.flag, value, w)
        end
        if not silent and opts.callback then
            task.spawn(opts.callback, value)
        end
    end

    btn.MouseButton1Click:Connect(function()
        ripple(row, ui.accent)
        w:Set(not value)
    end)

    paint(false)
    if opts.flag then
        ui:_register(opts.flag, w)
        ui:_writeFlag(opts.flag, value, w)
    end
    ui:_accentBind(function()
        paint(false)
    end)
    return w
end

function Section:Button(opts)
    opts = opts or {}
    local ui = self.ui
    local row = rowBase(self)
    local btn = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Theme.Medium,
        Text = opts.text or "Button",
        TextSize = 12,
        TextColor3 = Theme.Text,
        Parent = row,
    })
    hoverable(btn, Theme.Control, Theme.Hover, row)
    btn.MouseButton1Click:Connect(function()
        ripple(row, ui.accent)
        if opts.callback then
            task.spawn(opts.callback)
        end
    end)
    return Widget.new(self, "button", row, opts)
end

function Section:Slider(opts)
    opts = opts or {}
    local ui = self.ui
    local minv = opts.min or 0
    local maxv = opts.max or 100
    local decimals = opts.decimals or 0
    local value = math.clamp(opts.default or minv, minv, maxv)
    local sliderHeight = ui.compact and 38 or 42
    local sliderLabelY = ui.compact and 3 or 4
    local sliderTrackY = ui.compact and 24 or 27
    local sliderHitY = ui.compact and 17 or 20

    local row = create("Frame", {
        BackgroundColor3 = Theme.Control,
        BackgroundTransparency = 0.35,
        Size = UDim2.new(1, 0, 0, sliderHeight),
        BorderSizePixel = 0,
        Parent = self.holder,
    })
    corner(row, 7)

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, sliderLabelY),
        Size = UDim2.new(1, -60, 0, 15),
        Font = Theme.Font,
        Text = opts.text or "Slider",
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })

    local readout = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -10, 0, 4),
        Size = UDim2.fromOffset(52, 15),
        Font = Theme.Mono,
        Text = "0",
        TextSize = 11,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })

    local track = create("Frame", {
        Position = UDim2.new(0, 10, 0, sliderTrackY),
        Size = UDim2.new(1, -20, 0, 4),
        BackgroundColor3 = Theme.Hover,
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(track, 999)

    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = ui.accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, 999)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(11, 11),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = track,
    })
    corner(knob, 999)

    local function round(v)
        local mult = 10 ^ decimals
        return math.floor(v * mult + 0.5) / mult
    end

    local w = Widget.new(self, "slider", row, opts)

    local function paint(animate)
        local alpha = (value - minv) / math.max(maxv - minv, 1e-6)
        local info = animate and QUICK or TweenInfo.new(0)
        tween(fill, info, { Size = UDim2.fromScale(alpha, 1) })
        tween(knob, info, { Position = UDim2.fromScale(alpha, 0.5) })
        readout.Text = opts.suffix and (tostring(round(value)) .. opts.suffix) or tostring(round(value))
    end

    w._get = function()
        return value
    end
    w._set = function(v, silent)
        value = math.clamp(round(v), minv, maxv)
        paint(true)
        if opts.flag then
            ui:_writeFlag(opts.flag, value, w)
        end
        if not silent and opts.callback then
            task.spawn(opts.callback, value)
        end
    end

    local dragging = false
    local hit = create("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 4, 0, sliderHitY),
        Size = UDim2.new(1, -8, 0, 18),
        Text = "",
        Parent = row,
    })

    local function fromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        w:Set(minv + rel * (maxv - minv))
    end

    hit.MouseButton1Down:Connect(function()
        dragging = true
        tween(knob, QUICK, { Size = UDim2.fromOffset(14, 14) })
        fromX(UserInputService:GetMouseLocation().X)
    end)

    ui:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            tween(knob, QUICK, { Size = UDim2.fromOffset(11, 11) })
        end
    end)

    ui:_connect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            fromX(UserInputService:GetMouseLocation().X)
        end
    end)

    paint(false)
    if opts.flag then
        ui:_register(opts.flag, w)
        ui:_writeFlag(opts.flag, value, w)
    end
    ui:_accentBind(function()
        fill.BackgroundColor3 = ui.accent
    end)
    return w
end

function Section:Dropdown(opts)
    opts = opts or {}
    local ui = self.ui
    local options = opts.options or {}
    local value = opts.default or options[1]

    local row = rowBase(self)
    rowLabel(row, opts.text)

    local chip = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(96, 21),
        BackgroundColor3 = Theme.Hover,
        Font = Theme.Medium,
        Text = tostring(value or "-"),
        TextSize = 11,
        TextColor3 = Theme.Sub,
        AutoButtonColor = false,
        Parent = row,
    })
    corner(chip, 6)

    local open = false
    local menu
    local menuTween

    local w = Widget.new(self, "dropdown", row, opts)
    w._get = function()
        return value
    end
    w._set = function(v, silent)
        value = v
        chip.Text = tostring(v)
        if opts.flag then
            ui:_writeFlag(opts.flag, v, w)
        end
        if not silent and opts.callback then
            task.spawn(opts.callback, v)
        end
    end

    local function close()
        if not menu then
            open = false
            return
        end
        open = false
        local m = menu
        menu = nil
        if menuTween then
            pcall(function()
                menuTween:Cancel()
            end)
        end
        local targetX = chip.AbsolutePosition.X
        local targetY = chip.AbsolutePosition.Y + chip.AbsoluteSize.Y + 4
        menuTween = tween(m, DROPDOWN, {
            Position = UDim2.fromOffset(targetX, targetY - 4),
            Size = UDim2.fromOffset(chip.AbsoluteSize.X, 0),
            BackgroundTransparency = 1,
        })
        task.delay(0.2, function()
            if m.Parent then
                m:Destroy()
            end
        end)
    end

    local function positionMenu()
        if not menu then
            return
        end
        menu.Position = UDim2.fromOffset(
            chip.AbsolutePosition.X,
            chip.AbsolutePosition.Y + chip.AbsoluteSize.Y + 4
        )
    end

    chip.MouseButton1Click:Connect(function()
        if open then
            close()
            return
        end
        open = true
        local count = math.min(#options, 6)
        local targetX = chip.AbsolutePosition.X
        local targetY = chip.AbsolutePosition.Y + chip.AbsoluteSize.Y + 4
        menu = create("Frame", {
            BackgroundColor3 = Theme.Panel,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(targetX, targetY - 4),
            Size = UDim2.fromOffset(chip.AbsoluteSize.X, 0),
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 60,
            Parent = ui.gui,
        })
        corner(menu, 8)
        stroke(menu, Theme.Stroke, 1, 0.2)
        local sc = create("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Stroke,
            BorderSizePixel = 0,
            ZIndex = 61,
            Parent = menu,
        })
        pad(sc, 4)
        list(sc, 3)
        for _, o in ipairs(options) do
            local item = create("TextButton", {
                BackgroundColor3 = Theme.Control,
                BackgroundTransparency = o == value and 0 or 1,
                Size = UDim2.new(1, 0, 0, 22),
                Font = Theme.Font,
                Text = tostring(o),
                TextSize = 11,
                TextColor3 = o == value and ui.accent or Theme.Sub,
                AutoButtonColor = false,
                ZIndex = 62,
                Parent = sc,
            })
            corner(item, 5)
            item.MouseEnter:Connect(function()
                tween(item, QUICK, { BackgroundTransparency = 0.4 })
            end)
            item.MouseLeave:Connect(function()
                tween(item, QUICK, { BackgroundTransparency = o == value and 0 or 1 })
            end)
            item.MouseButton1Click:Connect(function()
                w:Set(o)
                close()
            end)
        end
        task.defer(function()
            if menu then
                positionMenu()
                menuTween = tween(menu, DROPDOWN, {
                    Position = UDim2.fromOffset(chip.AbsolutePosition.X, chip.AbsolutePosition.Y + chip.AbsoluteSize.Y + 4),
                    Size = UDim2.fromOffset(chip.AbsoluteSize.X, count * 25 + 8),
                    BackgroundTransparency = 0.03,
                })
            end
        end)
    end)

    if opts.flag then
        ui:_register(opts.flag, w)
        ui:_writeFlag(opts.flag, value, w)
    end
    return w
end

function Section:Keybind(opts)
    opts = opts or {}
    local ui = self.ui
    local key = opts.default
    local row = rowBase(self)
    rowLabel(row, opts.text)

    local chip = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(86, 21),
        BackgroundColor3 = Theme.Hover,
        Font = Theme.Mono,
        Text = bindingName(key),
        TextSize = 10,
        TextColor3 = Theme.Sub,
        AutoButtonColor = false,
        Parent = row,
    })
    corner(chip, 6)

    local listening = false
    local w = Widget.new(self, "keybind", row, opts)
    w._get = function()
        return key
    end
    w._set = function(v, silent)
        key = v
        chip.Text = bindingName(v)
        if opts.flag then
            ui:_writeFlag(opts.flag, v, w)
        end
        if not silent and opts.changed then
            task.spawn(opts.changed, v)
        end
    end

    chip.MouseButton1Click:Connect(function()
        listening = true
        chip.Text = "PRESS INPUT"
        tween(chip, QUICK, { BackgroundColor3 = ui.accent })
    end)

    ui:_connect(UserInputService.InputBegan, function(input, gpe)
        local captured = inputBinding(input)
        if listening and captured then
            listening = false
            tween(chip, QUICK, { BackgroundColor3 = Theme.Hover })
            if captured == Enum.KeyCode.Backspace then
                w:Set(nil)
            else
                w:Set(captured)
            end
            return
        end
        if gpe or listening or not key then
            return
        end
        if bindingMatches(key, input) and opts.callback then
            task.spawn(opts.callback, input)
        end
    end)

    if opts.flag then
        ui:_register(opts.flag, w)
    end
    return w
end

function Section:Textbox(opts)
    opts = opts or {}
    local ui = self.ui
    local row = rowBase(self)
    rowLabel(row, opts.text)
    local box = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(110, 21),
        BackgroundColor3 = Theme.Hover,
        Font = Theme.Font,
        Text = opts.default or "",
        PlaceholderText = opts.placeholder or "",
        TextSize = 11,
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.Muted,
        ClearTextOnFocus = false,
        Parent = row,
    })
    corner(box, 6)
    pad(box, 0, { PaddingLeft = 7, PaddingRight = 7 })

    local w = Widget.new(self, "textbox", row, opts)
    w._get = function()
        return box.Text
    end
    w._set = function(v, silent)
        box.Text = tostring(v)
        if opts.flag then
            ui:_writeFlag(opts.flag, box.Text, w)
        end
        if not silent and opts.callback then
            task.spawn(opts.callback, box.Text)
        end
    end
    box.Focused:Connect(function()
        tween(box, QUICK, { BackgroundColor3 = Theme.Control })
    end)
    box.FocusLost:Connect(function()
        tween(box, QUICK, { BackgroundColor3 = Theme.Hover })
        w:Set(box.Text)
    end)
    if opts.flag then
        ui:_register(opts.flag, w)
    end
    return w
end

function Section:Colorpicker(opts)
    opts = opts or {}
    local ui = self.ui
    local value = opts.default or ui.accent
    local row = rowBase(self)
    local baseHeight = ui.compact and 26 or 30
    rowLabel(row, opts.text)

    local swatch = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(34, 18),
        BackgroundColor3 = value,
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })
    corner(swatch, 6)
    stroke(swatch, Theme.Stroke, 1, 0.3)

    local expanded = false
    local tray

    local w = Widget.new(self, "colorpicker", row, opts)
    w._get = function()
        return value
    end
    w._set = function(v, silent)
        value = v
        swatch.BackgroundColor3 = v
        if opts.flag then
            ui:_writeFlag(opts.flag, v, w)
        end
        if not silent and opts.callback then
            task.spawn(opts.callback, v)
        end
    end

    swatch.MouseButton1Click:Connect(function()
        if expanded then
            expanded = false
            if tray then
                tray:Destroy()
                tray = nil
            end
            row.Size = UDim2.new(1, 0, 0, baseHeight)
            return
        end
        expanded = true
        row.Size = UDim2.new(1, 0, 0, 76)
        tray = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 34),
            Size = UDim2.new(1, -20, 0, 34),
            Parent = row,
        })
        local hueTrack = create("Frame", {
            Size = UDim2.new(1, 0, 0, 10),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = tray,
        })
        corner(hueTrack, 999)
        local grad = create("UIGradient", { Parent = hueTrack })
        local keys = {}
        for i = 0, 6 do
            keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))
        end
        grad.Color = ColorSequence.new(keys)

        local hit = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Text = "",
            Parent = tray,
        })
        local dragging = false
        local function apply(x)
            local rel = math.clamp(
                (x - hueTrack.AbsolutePosition.X) / math.max(hueTrack.AbsoluteSize.X, 1),
                0,
                1
            )
            w:Set(Color3.fromHSV(rel, 1, 1))
        end
        hit.MouseButton1Down:Connect(function()
            dragging = true
            apply(UserInputService:GetMouseLocation().X)
        end)
        ui:_connect(UserInputService.InputEnded, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        ui:_connect(UserInputService.InputChanged, function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                apply(UserInputService:GetMouseLocation().X)
            end
        end)
    end)

    if opts.flag then
        ui:_register(opts.flag, w)
        ui:_writeFlag(opts.flag, value, w)
    end
    return w
end

local Window = {}
Window.__index = Window

function Window:_makeTabButton(name, order)
    local ui = self.ui
    local btn = create("TextButton", {
        BackgroundColor3 = Theme.Control,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = Theme.Medium,
        Text = "",
        TextSize = 11,
        AutoButtonColor = false,
        LayoutOrder = order,
        Parent = self._tabbar,
    })
    corner(btn, 6)
    local lbl = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = Theme.Medium,
        Text = "  " .. name .. "  ",
        TextSize = 11,
        TextColor3 = Theme.Muted,
        Parent = btn,
    })
    return btn, lbl
end

function Window:Tab(name)
    local ui = self.ui
    local order = #self._tabs + 1
    local btn, lbl = self:_makeTabButton(name, order)

    local page = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        Parent = self._body,
    })
    local scroller = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = page,
    })
    list(scroller, 8)
    pad(scroller, 2)

    local tab = {
        name = name,
        button = btn,
        label = lbl,
        page = page,
        win = self,
        ui = ui,
        _scroller = scroller,
        _subtabs = {},
        _subbar = nil,
        _subactive = nil,
    }
    tab._page = scroller

    function tab:Section(title)
        return newSection({ ui = ui, _page = self._subactive and self._subactive.scroller or self._scroller }, title)
    end

    function tab:_selectSub(sub)
        if self._subactive == sub then
            return
        end
        for _, item in ipairs(self._subtabs) do
            local active = item == sub
            item.page.Visible = active
            tween(item.label, QUICK, { TextColor3 = active and Theme.Text or Theme.Muted })
            tween(item.button, QUICK, { BackgroundTransparency = active and 0.25 or 1 })
            if active then
                item.page.Position = UDim2.fromOffset(0, 4)
                tween(item.page, QUICK, { Position = UDim2.fromOffset(0, 0) })
            end
        end
        self._subactive = sub
        if self._subindicator then
            task.defer(function()
                tween(self._subindicator, DROPDOWN, {
                    Position = UDim2.fromOffset(sub.button.AbsolutePosition.X - self._subbar.AbsolutePosition.X, 0),
                    Size = UDim2.fromOffset(sub.button.AbsoluteSize.X, 2),
                })
            end)
        end
    end

    function tab:SubTab(subName)
        if not self._subbar then
            self._scroller.Visible = false
            self._subbar = create("Frame", {
                BackgroundTransparency = 1,
                ZIndex = 10,
                Size = UDim2.new(1, 0, 0, 24),
                Parent = self.page,
            })
            list(self._subbar, 2, Enum.FillDirection.Horizontal)
            local subline = create("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 22),
                Size = UDim2.new(1, 0, 0, 2),
                ZIndex = 11,
                Parent = self.page,
            })
            self._subindicator = create("Frame", {
                BackgroundColor3 = ui.accent,
                Size = UDim2.fromOffset(0, 2),
                BorderSizePixel = 0,
                Parent = subline,
            })
            corner(self._subindicator, 999)
            ui:_accentBind(function()
                self._subindicator.BackgroundColor3 = ui.accent
            end)
        end

        local button = create("TextButton", {
            BackgroundColor3 = Theme.Control,
            BackgroundTransparency = 1,
            ZIndex = 12,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Theme.Medium,
            Text = "",
            TextSize = 10,
            AutoButtonColor = false,
            LayoutOrder = #self._subtabs + 1,
            Parent = self._subbar,
        })
        corner(button, 6)
        local label = create("TextLabel", {
            BackgroundTransparency = 1,
            ZIndex = 13,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Theme.Medium,
            Text = "  " .. subName .. "  ",
            TextSize = 10,
            TextColor3 = Theme.Muted,
            Parent = button,
        })
        local subPage = create("ScrollingFrame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 30),
            Size = UDim2.new(1, 0, 1, -30),
            ZIndex = 1,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Stroke,
            BorderSizePixel = 0,
            Visible = false,
            Parent = self.page,
        })
        list(subPage, 8)
        pad(subPage, 2)
        local sub = {
            name = subName,
            button = button,
            label = label,
            page = subPage,
            scroller = subPage,
            tab = self,
            ui = ui,
        }
        function sub:Section(title)
            return newSection({ ui = ui, _page = self.scroller }, title)
        end
        function sub:Open()
            self.tab:_selectSub(self)
        end
        table.insert(self._subtabs, sub)
        button.MouseButton1Click:Connect(function()
            self:_selectSub(sub)
        end)
        button.MouseEnter:Connect(function()
            if self._subactive ~= sub then
                tween(label, QUICK, { TextColor3 = Theme.Sub })
            end
        end)
        button.MouseLeave:Connect(function()
            if self._subactive ~= sub then
                tween(label, QUICK, { TextColor3 = Theme.Muted })
            end
        end)
        if #self._subtabs == 1 then
            self:_selectSub(sub)
        end
        return sub
    end

    function tab:Open()
        self.win:_select(self)
    end

    self._tabs[#self._tabs + 1] = tab

    btn.MouseButton1Click:Connect(function()
        self:_select(tab)
    end)
    btn.MouseEnter:Connect(function()
        if self._active ~= tab then
            tween(lbl, QUICK, { TextColor3 = Theme.Sub })
        end
    end)
    btn.MouseLeave:Connect(function()
        if self._active ~= tab then
            tween(lbl, QUICK, { TextColor3 = Theme.Muted })
        end
    end)

    if #self._tabs == 1 then
        self:_select(tab)
    end
    return tab
end

function Window:_select(tab)
    if self._active == tab then
        return
    end
    for _, t in ipairs(self._tabs) do
        local on = t == tab
        t.page.Visible = on
        tween(t.label, QUICK, { TextColor3 = on and Theme.Text or Theme.Muted })
        tween(t.button, QUICK, { BackgroundTransparency = on and 0.25 or 1 })
        if on then
            t.page.Position = UDim2.fromOffset(0, 6)
            tween(t.page, SPRING, { Position = UDim2.fromOffset(0, 0) })
        end
    end
    self._active = tab
    if self._indicator then
        task.defer(function()
            tween(self._indicator, SPRING, {
                Position = UDim2.fromOffset(tab.button.AbsolutePosition.X - self._tabbar.AbsolutePosition.X, 0),
                Size = UDim2.fromOffset(tab.button.AbsoluteSize.X, 2),
            })
        end)
    end
end

function Window:SetVisible(v)
    self._visible = v
    self._transition = (self._transition or 0) + 1
    local token = self._transition
    local position = self.frame.Position
    if v then
        self.frame.Visible = true
        self.frame.Position = UDim2.fromOffset(position.X.Offset, position.Y.Offset + 6)
        self.frame.BackgroundTransparency = 1
        tween(self.frame, SPRING, {
            Position = position,
            BackgroundTransparency = self.ui.transparency,
        })
    else
        tween(self.frame, QUICK, {
            Position = UDim2.fromOffset(position.X.Offset, position.Y.Offset + 6),
            BackgroundTransparency = 1,
        })
        task.delay(0.16, function()
            if self._transition == token then
                self.frame.Visible = false
                self.frame.Position = position
            end
        end)
    end
    return self
end

function Window:GetVisible()
    return self._visible
end

function Window:Toggle()
    return self:SetVisible(not self._visible)
end

function Window:SubTab(name)
    local tab = self._active or self._tabs[1]
    if not tab then
        tab = self:Tab("Main")
    end
    return tab:SubTab(name)
end

function Window:Destroy()
    self.frame:Destroy()
end

function UI:_closeContext()
    if self._contextInput then
        pcall(function()
            self._contextInput:Disconnect()
        end)
        self._contextInput = nil
    end
    if self._contextPopup then
        self._contextPopup:Destroy()
        self._contextPopup = nil
    end
end

function UI:_bindContext(widget, frame, builder)
    self:_connect(frame.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self:_showContext(widget, builder)
        end
    end)
end

function UI:_showContext(widget, builder)
    self:_closeContext()
    local ok, entries = pcall(function()
        return type(builder) == "function" and builder(widget, self) or builder
    end)
    if not ok or type(entries) ~= "table" or #entries == 0 then
        return
    end
    local mouse = UserInputService:GetMouseLocation()
    local height = 14 + #entries * 30
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
    local x = math.clamp(mouse.X, 4, math.max(4, viewport.X - 224))
    local y = math.clamp(mouse.Y, 4, math.max(4, viewport.Y - height - 4))
    local menu = create("Frame", {
        Name = "ContextMenu",
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.02,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(220, height),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 100,
        Parent = self.gui,
    })
    corner(menu, 8)
    stroke(menu, Theme.Stroke, 1, 0.1)
    pad(menu, 5)
    list(menu, 3)
    self._contextPopup = menu
    local function reopen()
        if menu.Parent then
            self:_showContext(widget, builder)
        end
    end
    for index, entry in ipairs(entries) do
        if type(entry) == "table" and entry.kind == "color" and type(entry.colors) == "table" then
            local row = create("Frame", {
                BackgroundColor3 = Theme.Control,
                BackgroundTransparency = 0.15,
                Size = UDim2.new(1, 0, 0, 26),
                LayoutOrder = index,
                ZIndex = 101,
                Parent = menu,
            })
            corner(row, 5)
            local label = create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(7, 0),
                Size = UDim2.new(0.48, 0, 1, 0),
                Font = Theme.Font,
                Text = tostring(entry.text or "Color"),
                TextSize = 10,
                TextColor3 = Theme.Sub,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 102,
                Parent = row,
            })
            for colorIndex, colorEntry in ipairs(entry.colors) do
                local color = type(colorEntry) == "table" and colorEntry.color or colorEntry
                local name = type(colorEntry) == "table" and colorEntry.name or tostring(colorIndex)
                local swatch = create("TextButton", {
                    BackgroundColor3 = color,
                    Position = UDim2.new(0.48, (colorIndex - 1) * 21, 0.5, -8),
                    Size = UDim2.fromOffset(16, 16),
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 103,
                    Parent = row,
                })
                swatch.Name = name
                corner(swatch, 4)
                swatch.MouseButton1Click:Connect(function()
                    if entry.set then
                        pcall(entry.set, color, widget, self)
                    end
                    reopen()
                end)
            end
        else
            local button = create("TextButton", {
                BackgroundColor3 = Theme.Control,
                BackgroundTransparency = 0.15,
                Size = UDim2.new(1, 0, 0, 26),
                Font = Theme.Font,
                Text = tostring(entry.text or "Option"),
                TextSize = 10,
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                LayoutOrder = index,
                ZIndex = 101,
                Parent = menu,
            })
            corner(button, 5)
            pad(button, 0, { PaddingLeft = 7, PaddingRight = 7 })
            if entry.kind == "toggle" then
                local value = false
                if entry.get then
                    pcall(function()
                        value = entry.get(widget, self) and true or false
                    end)
                end
                button.Text = tostring(entry.text or "Option") .. "  " .. (value and "ON" or "OFF")
                button.TextColor3 = value and self.accent or Theme.Sub
            end
            button.MouseEnter:Connect(function()
                tween(button, QUICK, { BackgroundColor3 = Theme.Hover })
            end)
            button.MouseLeave:Connect(function()
                tween(button, QUICK, { BackgroundColor3 = Theme.Control })
            end)
            button.MouseButton1Click:Connect(function()
                if entry.kind == "toggle" then
                    local value = false
                    if entry.get then
                        pcall(function()
                            value = entry.get(widget, self) and true or false
                        end)
                    end
                    if entry.set then
                        pcall(entry.set, not value, widget, self)
                    end
                elseif entry.set then
                    pcall(entry.set, widget, self)
                end
                reopen()
            end)
        end
    end
    self._contextInput = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        local point = UserInputService:GetMouseLocation()
        local inside = point.X >= menu.AbsolutePosition.X and point.X <= menu.AbsolutePosition.X + menu.AbsoluteSize.X and point.Y >= menu.AbsolutePosition.Y and point.Y <= menu.AbsolutePosition.Y + menu.AbsoluteSize.Y
        if not inside then
            self:_closeContext()
        end
    end)
end

function UI:_connect(signal, fn)
    local c = signal:Connect(fn)
    self._conns[#self._conns + 1] = c
    return c
end

function UI:_register(flag, widget)
    self._widgets[flag] = self._widgets[flag] or {}
    table.insert(self._widgets[flag], widget)
end

function UI:_writeFlag(flag, value, source)
    self.flags[flag] = value
    self._syncingFlags = self._syncingFlags or {}
    if self._syncingFlags[flag] then
        return
    end
    self._syncingFlags[flag] = true
    for _, w in ipairs(self._widgets[flag] or {}) do
        if w ~= source then
            w:Set(value, true)
        end
    end
    self._syncingFlags[flag] = nil
end

function UI:_accentBind(fn)
    self._accentBinds[#self._accentBinds + 1] = fn
end

function UI:Get(flag)
    return self.flags[flag]
end

function UI:Set(flag, value)
    local ws = self._widgets[flag]
    if ws and ws[1] then
        ws[1]:Set(value)
    else
        self.flags[flag] = value
    end
    return self
end

function UI:SetAccent(color)
    self.accent = color
    for _, fn in ipairs(self._accentBinds) do
        pcall(fn)
    end
    return self
end

function UI:SetStyle(opts)
    opts = opts or {}
    if opts.windowColor then
        for _, item in ipairs(self._styleNodes.windows) do
            if item.Parent then
                item.BackgroundColor3 = opts.windowColor
            end
        end
    end
    if opts.titlebarColor then
        for _, item in ipairs(self._styleNodes.titlebars) do
            if item.Parent then
                item.BackgroundColor3 = opts.titlebarColor
            end
        end
    end
    if opts.cardColor then
        for _, item in ipairs(self._styleNodes.cards) do
            if item.Parent then
                item.BackgroundColor3 = opts.cardColor
            end
        end
    end
    if opts.controlColor then
        for _, item in ipairs(self._styleNodes.rows) do
            if item.Parent then
                item.BackgroundColor3 = opts.controlColor
            end
        end
    end
    if opts.windowTransparency ~= nil then
        self.transparency = math.clamp(opts.windowTransparency, 0, 1)
        for _, item in ipairs(self._styleNodes.windows) do
            if item.Parent then
                item.BackgroundTransparency = self.transparency
            end
        end
    end
    if opts.strokeColor then
        for _, item in ipairs(self.gui:GetDescendants()) do
            if item:IsA("UIStroke") then
                item.Color = opts.strokeColor
            end
        end
    end
    if opts.textColor then
        for _, item in ipairs(self.gui:GetDescendants()) do
            if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
                item.TextColor3 = opts.textColor
            end
        end
    end
    if opts.cornerRadius then
        local radius = math.max(0, math.floor(opts.cornerRadius))
        for _, item in ipairs(self.gui:GetDescendants()) do
            if item:IsA("UICorner") then
                item.CornerRadius = UDim.new(0, radius)
            end
        end
    end
    return self
end

function UI:Background(opts)
    return self:SetStyle(opts)
end

function UI:Notify(opts)
    opts = opts or {}
    local kinds = { ok = Theme.Ok, warn = Theme.Warn, error = Theme.Err, info = Theme.Info }
    local col = kinds[opts.kind or "info"] or Theme.Info
    self._toastEntries = self._toastEntries or {}

    if not opts.priority then
        local count = 0
        for _, entry in ipairs(self._toastEntries) do
            if not entry.priority and not entry.closed then
                count = count + 1
            end
        end
        if count >= 3 then
            for _, entry in ipairs(self._toastEntries) do
                if not entry.priority and not entry.closed then
                    entry.closed = true
                    if entry.card and entry.card.Parent then
                        entry.card:Destroy()
                    end
                    break
                end
            end
        end
    end

    local card = create("Frame", {
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(258, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = self._toastSerial or 0,
        Parent = self._toasts,
    })
    self._toastSerial = (self._toastSerial or 0) + 1
    corner(card, 10)
    stroke(card, Theme.Stroke, 1, 0.25)
    local content = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card,
    })
    pad(content, 10)
    list(content, 3)

    local rail = create("Frame", {
        BackgroundColor3 = col,
        Size = UDim2.fromOffset(3, 26),
        Position = UDim2.fromOffset(6, 10),
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(rail, 999)

    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 15),
        Font = Theme.Bold,
        Text = opts.title or "Notice",
        TextSize = 12,
        TextColor3 = col,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = content,
    })

    local body
    if opts.text then
        body = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.Y,
            Font = Theme.Font,
            Text = opts.text,
            TextSize = 11,
            TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Parent = content,
        })
    end

    local bar = create("Frame", {
        BackgroundColor3 = col,
        BackgroundTransparency = 0.4,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2),
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(bar, 999)

    local entry = {
        card = card,
        bar = bar,
        title = title,
        body = body,
        priority = opts.priority == true,
        closed = false,
    }
    table.insert(self._toastEntries, entry)
    card.Position = UDim2.fromOffset(28, 0)
    tween(card, SPRING, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0.06 })

    local duration = opts.duration or 3.5
    tween(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })

    local function close()
        if entry.closed then
            return
        end
        entry.closed = true
        tween(card, QUICK, { Position = UDim2.fromOffset(28, 0), BackgroundTransparency = 1 })
        task.delay(0.16, function()
            if card.Parent then
                card:Destroy()
            end
        end)
    end

    task.delay(duration, close)
    return card
end

function UI:SetGrouped(grouped)
    self.grouped = grouped == true
    if self.grouped and self.activeWindow then
        self:ShowOnly(self.activeWindow)
    end
    return self
end

function UI:IsGrouped()
    return self.grouped == true
end

function UI:ShowOnly(window)
    self.activeWindow = window
    for _, item in ipairs(self.windows) do
        item:SetVisible(item == window)
    end
    return self
end

function UI:ShowAll()
    for _, item in ipairs(self.windows) do
        item:SetVisible(true)
    end
    return self
end

function UI:Popup(title, opts)
    opts = opts or {}
    opts.width = opts.width or 260
    opts.height = opts.height or 220
    return self:Window(title, opts)
end

function UI:Window(title, opts)
    opts = opts or {}
    local width = opts.width or 300
    local height = opts.height or 340

    local frame = create("Frame", {
        Name = "Win_" .. tostring(title),
        BackgroundColor3 = Theme.Window,
        BackgroundTransparency = self.transparency,
        Position = UDim2.fromOffset(opts.x or 40, opts.y or 40),
        Size = UDim2.fromOffset(width, height),
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Parent = self.gui,
    })
    corner(frame, 12)
    local frameStroke = stroke(frame, Theme.Stroke, 1, 0.25)

    local titlebar = create("Frame", {
        BackgroundColor3 = Theme.Titlebar,
        BackgroundTransparency = 0.25,
        Size = UDim2.new(1, 0, 0, 30),
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(titlebar, 12)
    if self._styleNodes then
        table.insert(self._styleNodes.windows, frame)
        table.insert(self._styleNodes.titlebars, titlebar)
    end
    create("Frame", {
        BackgroundColor3 = Theme.Titlebar,
        BackgroundTransparency = 0.25,
        Position = UDim2.new(0, 0, 1, -8),
        Size = UDim2.new(1, 0, 0, 8),
        BorderSizePixel = 0,
        Parent = titlebar,
    })

    local dot = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 11, 0.5, 0),
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = self.accent,
        BorderSizePixel = 0,
        Parent = titlebar,
    })
    corner(dot, 999)
    self:_accentBind(function()
        dot.BackgroundColor3 = self.accent
    end)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -60, 1, 0),
        Font = Theme.Medium,
        Text = self.title .. self.separator .. tostring(title),
        TextSize = 11,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titlebar,
    })

    local collapse = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -9, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        Font = Theme.Bold,
        Text = "—",
        TextSize = 12,
        TextColor3 = Theme.Muted,
        Parent = titlebar,
    })

    local body = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 62),
        Size = UDim2.new(1, -20, 1, -72),
        ClipsDescendants = true,
        Parent = frame,
    })

    local tabbar = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 34),
        Size = UDim2.new(1, -16, 0, 22),
        Parent = frame,
    })
    list(tabbar, 2, Enum.FillDirection.Horizontal)

    local indicator = create("Frame", {
        BackgroundColor3 = self.accent,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(0, 2),
        AnchorPoint = Vector2.new(0, 0),
        BorderSizePixel = 0,
        Parent = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 56),
            Size = UDim2.new(1, -16, 0, 2),
            Parent = frame,
        }),
    })
    corner(indicator, 999)
    self:_accentBind(function()
        indicator.BackgroundColor3 = self.accent
    end)

    local win = setmetatable({
        ui = self,
        frame = frame,
        width = width,
        height = height,
        _tabs = {},
        _body = body,
        _tabbar = tabbar,
        _indicator = indicator,
        _visible = true,
        _collapsed = false,
        _frameStroke = frameStroke,
    }, Window)

    collapse.MouseButton1Click:Connect(function()
        win._collapsed = not win._collapsed
        if win._collapsed then
            body.Visible = false
            tabbar.Visible = false
            indicator.Parent.Visible = false
            tween(frame, SPRING, { Size = UDim2.fromOffset(width, 30) })
            collapse.Text = "+"
        else
            tween(frame, SPRING, { Size = UDim2.fromOffset(width, height) })
            collapse.Text = "—"
            task.delay(0.2, function()
                body.Visible = true
                tabbar.Visible = true
                indicator.Parent.Visible = true
            end)
        end
    end)

    local resizeHandle = create("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(16, 16),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 25,
        Parent = frame,
    })
    local resizeGrip = create("Frame", {
        BackgroundColor3 = Theme.Muted,
        BackgroundTransparency = 0.2,
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.fromOffset(6, 1),
        Rotation = 45,
        BorderSizePixel = 0,
        ZIndex = 26,
        Parent = resizeHandle,
    })
    local resizeGrip2 = resizeGrip:Clone()
    resizeGrip2.Position = UDim2.fromOffset(10, 10)
    resizeGrip2.Parent = resizeHandle

    local dragging, dragStart, startPos
    local resizing, resizeStart, resizeSize
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resizeStart = input.Position
            resizeSize = frame.AbsoluteSize
            self.activeWindow = win
            tween(frameStroke, QUICK, { Transparency = 0.08, Thickness = 1.5 })
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - resizeStart
            local nextWidth = math.max(190, resizeSize.X + delta.X)
            local nextHeight = math.max(120, resizeSize.Y + delta.Y)
            tween(frame, DRAG, { Size = UDim2.fromOffset(nextWidth, nextHeight) })
            win.width = nextWidth
            win.height = nextHeight
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and resizing then
            resizing = false
            tween(frameStroke, QUICK, { Transparency = 0.25, Thickness = 1 })
        end
    end)

    titlebar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            self.activeWindow = win
            tween(frame, QUICK, { BackgroundTransparency = math.max(self.transparency - 0.04, 0) })
            tween(frameStroke, QUICK, { Transparency = 0.08, Thickness = 1.5 })
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            tween(frame, DRAG, { Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y) })
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            tween(frame, QUICK, { BackgroundTransparency = self.transparency })
            tween(frameStroke, QUICK, { Transparency = 0.25, Thickness = 1 })
        end
    end)

    titlebar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.activeWindow = win
            for _, w in ipairs(self.windows) do
                w.frame.ZIndex = 1
            end
            frame.ZIndex = 5
        end
    end)

    frame.Size = UDim2.fromOffset(width, 40)
    frame.BackgroundTransparency = 1
    tween(frame, POP, { Size = UDim2.fromOffset(width, height) })
    tween(frame, SPRING, { BackgroundTransparency = self.transparency })

    self.windows[#self.windows + 1] = win
    return win
end

function UI:SetVisible(v)
    self.visible = v
    for _, w in ipairs(self.windows) do
        w:SetVisible(v)
    end
    if self._watermark then
        self._watermark.Visible = v
    end
    if self._cursor then
        self._cursor.Visible = v and self.cursorEnabled
        pcall(function()
            UserInputService.MouseIconEnabled = not (v and self.cursorEnabled) and self._mouseIconEnabled or false
        end)
    end
    return self
end

function UI:Toggle()
    return self:SetVisible(not self.visible)
end

function UI:SetCursorVisible(v)
    self.cursorEnabled = v == true
    if self._cursor then
        self._cursor.Visible = self.cursorEnabled and self.visible
        pcall(function()
            UserInputService.MouseIconEnabled = self.cursorEnabled and self.visible and false or self._mouseIconEnabled
        end)
    end
    return self
end

function UI:SetToggleKey(key)
    self.toggleKey = key
    if self._toggleConnection then
        pcall(function()
            self._toggleConnection:Disconnect()
        end)
        self._toggleConnection = nil
    end
    if key ~= false and key ~= nil then
        self._toggleConnection = self:_connect(UserInputService.InputBegan, function(input, gpe)
            if not gpe and bindingMatches(key, input) then
                self:Toggle()
            end
        end)
    end
    return self
end

function UI:Destroy()
    self:_closeContext()
    for _, c in ipairs(self._conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    self._conns = {}
    if self._cursor then
        pcall(function()
            UserInputService.MouseIconEnabled = self._mouseIconEnabled
        end)
    end
    if self.gui then
        self.gui:Destroy()
    end
end

function UI.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI)
    self.title = opts.title or "rotware"
    self.separator = opts.separator or " | "
    self.compact = opts.compact == true
    self.accent = opts.accent or Theme.Accent
    self.transparency = opts.transparency or 0.08
    self.visible = true
    self.grouped = opts.grouped == true
    self.toggleKey = opts.toggleKey == nil and Enum.KeyCode.RightShift or opts.toggleKey
    self.cursorEnabled = opts.customCursor ~= false and opts.cursor ~= false
    self.flags = {}
    self.windows = {}
    self._conns = {}
    self._widgets = {}
    self._accentBinds = {}
    self._styleNodes = {
        windows = {},
        titlebars = {},
        cards = {},
        rows = {},
    }
    self._toastEntries = {}
    self._toastSerial = 0

    self.gui = screenGui(opts.name or ("UI_" .. tostring(math.random(1e6, 9e6))))

    self._mouseIconEnabled = UserInputService.MouseIconEnabled
    if opts.customCursor ~= false then
        local cursor = create("Frame", {
            Name = "Cursor",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(16, 16),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BorderSizePixel = 0,
            ZIndex = 200,
            Parent = self.gui,
        })
        corner(cursor, 999)
        stroke(cursor, self.accent, 1, 0.12)
        create("Frame", {
            BackgroundColor3 = self.accent,
            BackgroundTransparency = 0.1,
            Size = UDim2.fromOffset(3, 3),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BorderSizePixel = 0,
            ZIndex = 201,
            Parent = cursor,
        })
        self._cursor = cursor
        self:_accentBind(function()
            local cursorStroke = cursor:FindFirstChildOfClass("UIStroke")
            if cursorStroke then
                cursorStroke.Color = self.accent
            end
            local dot = cursor:FindFirstChildOfClass("Frame")
            if dot then
                dot.BackgroundColor3 = self.accent
            end
        end)
        pcall(function()
            UserInputService.MouseIconEnabled = false
        end)
        self:_connect(RunService.RenderStepped, function()
            if self._cursor and self._cursor.Parent then
                local mouse = UserInputService:GetMouseLocation()
                self._cursor.Position = UDim2.fromOffset(mouse.X, mouse.Y)
            end
        end)
    end

    self._toasts = create("Frame", {
        Name = "Toasts",
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(258, 400),
        Parent = self.gui,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self._toasts,
    })

    if opts.watermark ~= false then
        local wm = create("Frame", {
            Name = "Watermark",
            BackgroundColor3 = Theme.Window,
            BackgroundTransparency = self.transparency,
            Position = UDim2.fromOffset(16, 16),
            Size = UDim2.fromOffset(0, 24),
            AutomaticSize = Enum.AutomaticSize.X,
            BorderSizePixel = 0,
            Parent = self.gui,
        })
        corner(wm, 8)
        stroke(wm, Theme.Stroke, 1, 0.3)
        pad(wm, 0, { PaddingLeft = 10, PaddingRight = 10 })
        local wmDot = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(5, 5),
            BackgroundColor3 = self.accent,
            BorderSizePixel = 0,
            Parent = wm,
        })
        corner(wmDot, 999)
        self:_accentBind(function()
            wmDot.BackgroundColor3 = self.accent
        end)
        local wmText = create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(11, 0),
            Size = UDim2.fromOffset(0, 24),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Theme.Medium,
            Text = self.title,
            TextSize = 11,
            TextColor3 = Theme.Sub,
            Parent = wm,
        })
        self._watermark = wm
        self._watermarkText = wmText

        task.spawn(function()
            while self.gui and self.gui.Parent do
                local fps = math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1e-4))
                local ping = 0
                pcall(function()
                    ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
                end)
                wmText.Text = string.format("%s  ·  %d fps  ·  %d ms", self.title, fps, ping)
                task.wait(1)
            end
        end)
    end

    self:SetToggleKey(self.toggleKey)

    return self
end

UI.Toolkit = {
    Theme = Theme,
    Create = create,
    Tween = tween,
    Corner = corner,
    Stroke = stroke,
    Easing = { Spring = SPRING, Quick = QUICK, Pop = POP, Dropdown = DROPDOWN, Drag = DRAG },
}

return UI
