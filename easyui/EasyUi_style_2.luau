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
    local dot = create("Frame", {
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.75,
        Size = UDim2.fromOffset(0, 0),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        Parent = parent,
    })
    corner(dot, 999)
    local size = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 1.6
    tween(dot, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
    })
    task.delay(0.45, function()
        dot:Destroy()
    end)
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
    return setmetatable({
        owner = owner,
        kind = kind,
        frame = frame,
        opts = opts or {},
        flag = opts and opts.flag,
    }, Widget)
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
    pad(holder, 10)
    local layout = list(holder, 7)

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
        Size = UDim2.new(1, 0, 0, height or 30),
        BorderSizePixel = 0,
        Parent = section.holder,
    })
    corner(row, 7)
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
    local row = rowBase(self, 30)
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
    local row = rowBase(self, 30)
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

    local row = create("Frame", {
        BackgroundColor3 = Theme.Control,
        BackgroundTransparency = 0.35,
        Size = UDim2.new(1, 0, 0, 42),
        BorderSizePixel = 0,
        Parent = self.holder,
    })
    corner(row, 7)

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 4),
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
        Position = UDim2.new(0, 10, 0, 27),
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
        Position = UDim2.new(0, 4, 0, 20),
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

    local row = rowBase(self, 30)
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
        if menu then
            local m = menu
            menu = nil
            tween(m, QUICK, { BackgroundTransparency = 1, Size = UDim2.fromOffset(m.Size.X.Offset, 0) })
            task.delay(0.16, function()
                m:Destroy()
            end)
        end
        open = false
    end

    chip.MouseButton1Click:Connect(function()
        if open then
            return close()
        end
        open = true
        local count = math.min(#options, 6)
        menu = create("Frame", {
            BackgroundColor3 = Theme.Panel,
            Position = UDim2.fromOffset(
                chip.AbsolutePosition.X,
                chip.AbsolutePosition.Y + chip.AbsoluteSize.Y + 4
            ),
            Size = UDim2.fromOffset(chip.AbsoluteSize.X, 0),
            BorderSizePixel = 0,
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
        tween(menu, SPRING, { Size = UDim2.fromOffset(chip.AbsoluteSize.X, count * 25 + 8) })
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
    local row = rowBase(self, 30)
    rowLabel(row, opts.text)

    local chip = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(72, 21),
        BackgroundColor3 = Theme.Hover,
        Font = Theme.Mono,
        Text = key and key.Name or "NONE",
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
        chip.Text = v and v.Name or "NONE"
        if opts.flag then
            ui:_writeFlag(opts.flag, v, w)
        end
        if not silent and opts.changed then
            task.spawn(opts.changed, v)
        end
    end

    chip.MouseButton1Click:Connect(function()
        listening = true
        chip.Text = "..."
        tween(chip, QUICK, { BackgroundColor3 = ui.accent })
    end)

    ui:_connect(UserInputService.InputBegan, function(input, gpe)
        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            tween(chip, QUICK, { BackgroundColor3 = Theme.Hover })
            if input.KeyCode == Enum.KeyCode.Backspace then
                w:Set(nil)
            else
                w:Set(input.KeyCode)
            end
            return
        end
        if gpe or listening or not key then
            return
        end
        if input.KeyCode == key and opts.callback then
            task.spawn(opts.callback)
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
    local row = rowBase(self, 30)
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
    local row = rowBase(self, 30)
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
            row.Size = UDim2.new(1, 0, 0, 30)
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
    }
    tab._page = scroller

    function tab:Section(title)
        return newSection({ ui = ui, _page = scroller }, title)
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
    if v then
        self.frame.Visible = true
        self.frame.Size = UDim2.fromOffset(self.width, 40)
        self.frame.BackgroundTransparency = 1
        tween(self.frame, POP, { Size = UDim2.fromOffset(self.width, self.height) })
        tween(self.frame, SPRING, { BackgroundTransparency = self.ui.transparency })
    else
        tween(self.frame, QUICK, { BackgroundTransparency = 1 })
        local t = tween(self.frame, QUICK, { Size = UDim2.fromOffset(self.width, 40) })
        t.Completed:Once(function()
            self.frame.Visible = false
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

function Window:Destroy()
    self.frame:Destroy()
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
    for _, w in ipairs(self._widgets[flag] or {}) do
        if w ~= source then
            w:Set(value, true)
        end
    end
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

function UI:Notify(opts)
    opts = opts or {}
    local kinds = { ok = Theme.Ok, warn = Theme.Warn, error = Theme.Err, info = Theme.Info }
    local col = kinds[opts.kind or "info"] or Theme.Info

    local card = create("Frame", {
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.06,
        Size = UDim2.fromOffset(258, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = self._toasts,
    })
    corner(card, 10)
    stroke(card, Theme.Stroke, 1, 0.25)
    pad(card, 10)
    list(card, 3)

    create("Frame", {
        BackgroundColor3 = col,
        Size = UDim2.fromOffset(3, 26),
        Position = UDim2.fromOffset(-6, 0),
        BorderSizePixel = 0,
        Parent = card,
    })

    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 15),
        Font = Theme.Bold,
        Text = opts.title or "Notice",
        TextSize = 12,
        TextColor3 = col,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    if opts.text then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.Y,
            Font = Theme.Font,
            Text = opts.text,
            TextSize = 11,
            TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Parent = card,
        })
    end

    card.Position = UDim2.fromOffset(28, 0)
    card.BackgroundTransparency = 1
    tween(card, SPRING, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0.06 })

    local bar = create("Frame", {
        BackgroundColor3 = col,
        BackgroundTransparency = 0.4,
        Size = UDim2.new(1, 0, 0, 2),
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(bar, 999)

    local dur = opts.duration or 3.5
    tween(bar, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })

    task.delay(dur, function()
        tween(card, QUICK, { Position = UDim2.fromOffset(28, 0), BackgroundTransparency = 1 })
        task.delay(0.2, function()
            card:Destroy()
        end)
    end)
    return card
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
    stroke(frame, Theme.Stroke, 1, 0.25)

    local titlebar = create("Frame", {
        BackgroundColor3 = Theme.Titlebar,
        BackgroundTransparency = 0.25,
        Size = UDim2.new(1, 0, 0, 30),
        BorderSizePixel = 0,
        Parent = frame,
    })
    corner(titlebar, 12)
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
        Text = self.title .. ": " .. tostring(title),
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

    local dragging, dragStart, startPos
    titlebar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            tween(frame, QUICK, { BackgroundTransparency = math.max(self.transparency - 0.08, 0) })
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            frame.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            tween(frame, QUICK, { BackgroundTransparency = self.transparency })
        end
    end)

    titlebar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
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
    return self
end

function UI:Toggle()
    return self:SetVisible(not self.visible)
end

function UI:Destroy()
    for _, c in ipairs(self._conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    self._conns = {}
    if self.gui then
        self.gui:Destroy()
    end
end

function UI.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI)
    self.title = opts.title or "rotware"
    self.accent = opts.accent or Theme.Accent
    self.transparency = opts.transparency or 0.08
    self.visible = true
    self.flags = {}
    self.windows = {}
    self._conns = {}
    self._widgets = {}
    self._accentBinds = {}

    self.gui = screenGui(opts.name or ("UI_" .. tostring(math.random(1e6, 9e6))))

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

    if opts.toggleKey ~= false then
        local key = opts.toggleKey or Enum.KeyCode.RightShift
        self:_connect(UserInputService.InputBegan, function(input, gpe)
            if not gpe and input.KeyCode == key then
                self:Toggle()
            end
        end)
    end

    return self
end

UI.Toolkit = {
    Theme = Theme,
    Create = create,
    Tween = tween,
    Corner = corner,
    Stroke = stroke,
    Easing = { Spring = SPRING, Quick = QUICK, Pop = POP },
}

return UI
