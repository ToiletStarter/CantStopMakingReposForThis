local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Input = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local abs, min, max, sqrt, huge = math.abs, math.min, math.max, math.sqrt, math.huge
local clamp, random, floor = math.clamp, math.random, math.floor
local sin, cos, pi = math.sin, math.cos, math.pi

local EasyAim = {}
EasyAim.__index = EasyAim
EasyAim.ver = "1.0.0"
EasyAim.version = EasyAim.ver

local STACK = (getgenv and getgenv() or _G)
STACK.__EASY_STACK = STACK.__EASY_STACK or {}

local function isCallable(f)
    return type(f) == "function"
end

local ATOMS = {
    Color3 = true,
    Vector2 = true,
    Vector3 = true,
    CFrame = true,
    UDim = true,
    UDim2 = true,
    EnumItem = true,
    Instance = true,
}

local function isAtom(v)
    return type(v) ~= "table" or ATOMS[typeof(v)] == true
end

local function deep(t)
    if isAtom(t) then
        return t
    end
    local o = {}
    for k, v in pairs(t) do
        o[k] = deep(v)
    end
    return o
end

local function merge(a, b)
    for k, v in pairs(b) do
        if not isAtom(v) and not isAtom(a[k]) then
            merge(a[k], v)
        else
            a[k] = deep(v)
        end
    end
    return a
end

local function fill(a, b)
    for k, v in pairs(b) do
        if a[k] == nil then
            a[k] = deep(v)
        elseif not isAtom(v) and not isAtom(a[k]) then
            fill(a[k], v)
        end
    end
    return a
end

local function pathGet(t, path)
    local cur = t
    for seg in tostring(path):gmatch("[^%.]+") do
        if type(cur) ~= "table" then
            return nil
        end
        cur = cur[tonumber(seg) or seg]
    end
    return cur
end

local function pathSet(t, path, value)
    local cur = t
    local keys = {}
    for seg in tostring(path):gmatch("[^%.]+") do
        keys[#keys + 1] = tonumber(seg) or seg
    end
    for i = 1, #keys - 1 do
        local k = keys[i]
        if type(cur[k]) ~= "table" then
            cur[k] = {}
        end
        cur = cur[k]
    end
    cur[keys[#keys]] = value
    return value
end

local function partOf(model, names)
    if typeof(model) ~= "Instance" then
        return nil
    end
    for _, n in ipairs(names) do
        local p = model:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            return p
        end
    end
    return nil
end

local ROOTS = { "HumanoidRootPart", "Torso", "UpperTorso", "Root", "Head" }
local HEADS = { "Head" }
local TORSOS = { "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart" }

local Adapters = {}

Adapters.Default = {
    targets = function()
        return Players:GetPlayers()
    end,
    model = function(raw)
        if typeof(raw) == "Instance" and raw:IsA("Player") then
            return raw.Character
        end
        return raw
    end,
    root = function(model)
        if typeof(model) ~= "Instance" then
            return nil
        end
        return model:FindFirstChild("HumanoidRootPart")
            or model.PrimaryPart
            or partOf(model, ROOTS)
            or model:FindFirstChildWhichIsA("BasePart")
    end,
    part = function(model, kind)
        if kind == "Head" then
            return partOf(model, HEADS)
        elseif kind == "Torso" then
            return partOf(model, TORSOS)
        end
        return nil
    end,
    health = function(model)
        local h = typeof(model) == "Instance" and model:FindFirstChildOfClass("Humanoid")
        if h then
            return h.Health, h.MaxHealth
        end
        return 0, 0
    end,
    alive = function(model, raw, health, maxHealth)
        if maxHealth and maxHealth > 0 then
            return health > 0
        end
        return model ~= nil
    end,
    name = function(model, raw)
        if typeof(raw) == "Instance" and raw:IsA("Player") then
            return raw.DisplayName
        end
        return typeof(model) == "Instance" and model.Name or "?"
    end,
    team = function(model, raw)
        if typeof(raw) == "Instance" and raw:IsA("Player") then
            return raw.Team
        end
        return nil
    end,
    ignore = function(model, raw)
        return raw == lp
    end,
}

Adapters.Attribute = {
    targets = function()
        return Players:GetPlayers()
    end,
    model = function(raw)
        if typeof(raw) == "Instance" and raw:IsA("Player") then
            return raw.Character
        end
        return raw
    end,
    root = Adapters.Default.root,
    part = Adapters.Default.part,
    health = function(model, raw)
        local src = typeof(raw) == "Instance" and raw or model
        if typeof(src) == "Instance" then
            local h = src:GetAttribute("Health")
            local m = src:GetAttribute("MaxHealth")
            if h then
                return h, m or 100
            end
        end
        return Adapters.Default.health(model)
    end,
    alive = function(model, raw, health, maxHealth)
        local src = typeof(raw) == "Instance" and raw or model
        if typeof(src) == "Instance" and src:GetAttribute("Dead") == true then
            return false
        end
        if maxHealth and maxHealth > 0 then
            return health > 0
        end
        return model ~= nil
    end,
    name = Adapters.Default.name,
    team = function(model, raw)
        local src = typeof(raw) == "Instance" and raw or model
        if typeof(src) == "Instance" then
            local s = src:GetAttribute("SquadName")
            if s then
                return s
            end
        end
        return Adapters.Default.team(model, raw)
    end,
    ignore = Adapters.Default.ignore,
}

EasyAim.Adapters = Adapters

local function defaults()
    return {
        on = false,
        mode = "legit",
        key = Enum.UserInputType.MouseButton2,
        hold = true,
        range = 2000,
        team = false,
        wallCheck = false,
        deadCheck = true,
        select = "fov",
        sticky = false,
        stickyLoss = 1.35,
        hitbox = {
            kind = "Head",
            list = { "Head", "Torso", "Root" },
            offset = Vector3.new(0, 0, 0),
        },
        fov = {
            on = true,
            radius = 140,
            col = Color3.fromRGB(190, 150, 255),
            thickness = 1,
            filled = false,
            fillA = 0.06,
            sides = 48,
            follow = false,
        },
        legit = {
            smooth = 0.22,
            smoothY = 0,
            deadzone = 0,
            maxStep = 90,
        },
        rage = {
            snap = 1,
            lockCam = true,
        },
        humanize = {
            on = false,
            jitter = 0.6,
            reaction = 0.05,
            breath = 0.35,
        },
        predict = {
            on = false,
            factor = 0.165,
            speed = 0,
            gravity = 0,
            useVelocity = true,
        },
        vis = {
            on = false,
            points = 1,
        },
        trigger = {
            on = false,
            key = nil,
            fov = 8,
            delay = 0.03,
            reset = 0.12,
            visOnly = true,
        },
    }
end

local function drawing(kind)
    local ok, d = pcall(function()
        return Drawing.new(kind)
    end)
    if ok then
        return d
    end
    return nil
end

function EasyAim.new(opt)
    local prev = STACK.__EASY_STACK.aim
    if prev and prev.destroy then
        pcall(function()
            prev:destroy()
        end)
    end

    local self = setmetatable({}, EasyAim)
    self.cfg = fill(merge(defaults(), type(opt) == "table" and opt or {}), defaults())
    self.adapter = deep(Adapters.Default)
    self.source = nil
    self.filter = nil
    self.predictor = nil
    self.resolver = nil
    self.onFire = nil
    self.onTarget = nil
    self.roster = {}
    self.target = nil
    self.aimPoint = nil
    self.active = false
    self.held = false
    self.conns = {}
    self.binds = {}
    self.circle = nil
    self.t = 0
    self.triggerAt = 0
    self.triggeredAt = 0
    self.stats = { roster = 0, locked = false, name = "", dist = 0 }
    self.rayParams = RaycastParams.new()
    self.rayParams.FilterType = Enum.RaycastFilterType.Exclude

    STACK.__EASY_STACK.aim = self
    return self
end

function EasyAim:setAdapter(a)
    if type(a) ~= "table" then
        return self
    end
    local base = deep(Adapters.Default)
    for k, v in pairs(a) do
        base[k] = v
    end
    self.adapter = base
    return self
end

function EasyAim:useAdapter(name)
    local a = Adapters[name]
    if a then
        self:setAdapter(a)
        return true
    end
    return false
end

function EasyAim:setSource(fn)
    self.source = isCallable(fn) and fn or nil
    return self
end

function EasyAim:setFilter(fn)
    self.filter = isCallable(fn) and fn or nil
    return self
end

function EasyAim:setPredictor(fn)
    self.predictor = isCallable(fn) and fn or nil
    return self
end

function EasyAim:setResolver(fn)
    self.resolver = isCallable(fn) and fn or nil
    return self
end

function EasyAim:setFireCallback(fn)
    self.onFire = isCallable(fn) and fn or nil
    return self
end

function EasyAim:setTargetCallback(fn)
    self.onTarget = isCallable(fn) and fn or nil
    return self
end

function EasyAim:on(v)
    self.cfg.on = v and true or false
    return self
end

function EasyAim:toggle()
    self.cfg.on = not self.cfg.on
    return self.cfg.on
end

function EasyAim:set(path, value)
    return pathSet(self.cfg, path, value)
end

function EasyAim:get(path)
    return pathGet(self.cfg, path)
end

function EasyAim:project(pos)
    if not cam then
        return 0, 0, -1, false
    end
    local p, on = cam:WorldToViewportPoint(pos)
    return p.X, p.Y, p.Z, on and p.Z > 0
end

function EasyAim:cursor()
    if self.cfg.fov.follow then
        local m = Input:GetMouseLocation()
        return m.X, m.Y
    end
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    return vp.X * 0.5, vp.Y * 0.5
end

function EasyAim:_ignoreList()
    local t = { lp.Character }
    local c = self.adapter.model and self.adapter.model(lp) or lp.Character
    if c and c ~= t[1] then
        t[#t + 1] = c
    end
    return t
end

function EasyAim:sees(model, root)
    if not cam or not root then
        return true
    end
    local ig = self:_ignoreList()
    ig[#ig + 1] = model
    self.rayParams.FilterDescendantsInstances = ig
    local origin = cam.CFrame.Position
    local pts = { root.Position }
    local n = self.cfg.vis.points
    if n > 1 then
        local h = self.adapter.part and self.adapter.part(model, "Head")
        if h then
            pts[#pts + 1] = h.Position
        end
    end
    if n > 2 then
        local tp = self.adapter.part and self.adapter.part(model, "Torso")
        if tp then
            pts[#pts + 1] = tp.Position
        end
    end
    for _, p in ipairs(pts) do
        local dir = p - origin
        local hit = workspace:Raycast(origin, dir, self.rayParams)
        if not hit then
            return true
        end
    end
    return false
end

function EasyAim:_record(raw)
    local a = self.adapter
    local model = a.model and a.model(raw) or raw
    if not model then
        return nil
    end
    if a.ignore and a.ignore(model, raw) then
        return nil
    end
    local root = a.root and a.root(model)
    if not root then
        return nil
    end
    local health, maxHealth = 0, 0
    if a.health then
        health, maxHealth = a.health(model, raw)
    end
    health = tonumber(health) or 0
    maxHealth = tonumber(maxHealth) or 0
    if self.cfg.deadCheck and a.alive and not a.alive(model, raw, health, maxHealth) then
        return nil
    end
    if self.cfg.team and a.team then
        local mine = a.team(self.adapter.model and self.adapter.model(lp) or lp.Character, lp)
        local theirs = a.team(model, raw)
        if mine ~= nil and mine == theirs then
            return nil
        end
    end

    local origin = cam and cam.CFrame.Position or Vector3.zero
    local dist = (root.Position - origin).Magnitude
    if self.cfg.range > 0 and dist > self.cfg.range then
        return nil
    end

    local sx, sy, depth, onScreen = self:project(root.Position)
    local cx, cy = self:cursor()
    local dx, dy = sx - cx, sy - cy
    local screenDist = sqrt(dx * dx + dy * dy)

    local rec = {
        raw = raw,
        model = model,
        root = root,
        health = health,
        maxHealth = maxHealth,
        name = a.name and a.name(model, raw) or model.Name,
        team = a.team and a.team(model, raw) or nil,
        dist = dist,
        sx = sx,
        sy = sy,
        depth = depth,
        onScreen = onScreen,
        screenDist = screenDist,
    }

    if self.filter and not self.filter(rec) then
        return nil
    end
    return rec
end

function EasyAim:build()
    local list = {}
    local src = self.source or self.adapter.targets
    if not src then
        self.roster = list
        return list
    end
    local ok, raws = pcall(src)
    if not ok or type(raws) ~= "table" then
        self.roster = list
        return list
    end
    for _, raw in ipairs(raws) do
        local okr, rec = pcall(self._record, self, raw)
        if okr and rec then
            list[#list + 1] = rec
        end
    end
    self.roster = list
    self.stats.roster = #list
    return list
end

function EasyAim:pick()
    local cfg = self.cfg
    local best, bestScore = nil, huge
    local radius = cfg.fov.radius
    local mode = cfg.select

    if cfg.sticky and self.target then
        for _, r in ipairs(self.roster) do
            if r.raw == self.target.raw then
                if r.onScreen and (radius <= 0 or r.screenDist <= radius * cfg.stickyLoss) then
                    if not (cfg.wallCheck and cfg.vis.on) or self:sees(r.model, r.root) then
                        self.target = r
                        return r
                    end
                end
                break
            end
        end
    end

    for _, r in ipairs(self.roster) do
        local eligible = r.onScreen
        if eligible and radius > 0 and r.screenDist > radius then
            eligible = false
        end
        if eligible and cfg.wallCheck and cfg.vis.on and not self:sees(r.model, r.root) then
            eligible = false
        end
        if eligible then
            local score
            if mode == "distance" then
                score = r.dist
            elseif mode == "health" then
                score = r.health
            elseif mode == "threat" then
                score = r.screenDist * (r.dist * 0.01 + 1)
            else
                score = r.screenDist
            end
            if score < bestScore then
                best, bestScore = r, score
            end
        end
    end

    self.target = best
    return best
end

function EasyAim:hitPart(rec)
    local a = self.adapter
    local kind = self.cfg.hitbox.kind

    if kind == "Root" then
        return rec.root
    end
    if kind == "Random" then
        local list = self.cfg.hitbox.list
        kind = list[random(1, #list)]
    end
    if kind == "Nearest" then
        local cx, cy = self:cursor()
        local best, bestD = rec.root, huge
        for _, name in ipairs(self.cfg.hitbox.list) do
            local p = (name == "Root") and rec.root or (a.part and a.part(rec.model, name))
            if p then
                local sx, sy, _, on = self:project(p.Position)
                if on then
                    local dx, dy = sx - cx, sy - cy
                    local d = dx * dx + dy * dy
                    if d < bestD then
                        best, bestD = p, d
                    end
                end
            end
        end
        return best
    end
    if kind == "Root" then
        return rec.root
    end
    local p = a.part and a.part(rec.model, kind)
    return p or rec.root
end

function EasyAim:predictPos(part, rec)
    local pos = part.Position + self.cfg.hitbox.offset
    local p = self.cfg.predict
    if not p.on then
        return pos
    end
    if self.predictor then
        local ok, custom = pcall(self.predictor, pos, part, rec, self)
        if ok and typeof(custom) == "Vector3" then
            return custom
        end
    end
    local vel = Vector3.zero
    if p.useVelocity then
        local okv, v = pcall(function()
            return part.AssemblyLinearVelocity
        end)
        if okv and typeof(v) == "Vector3" then
            vel = v
        end
    end
    local travel = p.factor
    if p.speed > 0 then
        local origin = cam and cam.CFrame.Position or Vector3.zero
        travel = (pos - origin).Magnitude / p.speed
    end
    local out = pos + vel * travel
    if p.gravity ~= 0 then
        out = out + Vector3.new(0, 0.5 * p.gravity * travel * travel, 0)
    end
    return out
end

function EasyAim:resolve(rec)
    rec = rec or self.target
    if not rec then
        return nil
    end
    local part = self:hitPart(rec)
    if not part then
        return nil
    end
    local pos = self:predictPos(part, rec)
    if self.resolver then
        local ok, custom = pcall(self.resolver, pos, part, rec, self)
        if ok and typeof(custom) == "Vector3" then
            pos = custom
        end
    end
    self.aimPoint = pos
    return pos, part
end

function EasyAim:aimPosition()
    if not self.cfg.on then
        return nil
    end
    if self.cfg.mode == "silent" and not self.held and self.cfg.hold then
        return nil
    end
    local rec = self.target or self:pick()
    if not rec then
        return nil
    end
    return (self:resolve(rec))
end

function EasyAim:aimDirection(origin)
    local pos = self:aimPosition()
    if not pos then
        return nil
    end
    origin = origin or (cam and cam.CFrame.Position) or Vector3.zero
    local d = pos - origin
    if d.Magnitude <= 0 then
        return nil
    end
    return d.Unit, pos
end

function EasyAim:_humanOffset()
    local h = self.cfg.humanize
    if not h.on then
        return 0, 0
    end
    local j = h.jitter
    local bx = sin(self.t * 1.7) * h.breath
    local by = cos(self.t * 2.3) * h.breath * 0.6
    return (random() - 0.5) * 2 * j + bx, (random() - 0.5) * 2 * j + by
end

function EasyAim:_applyLegit(pos, dt)
    if not mousemoverel or not cam then
        return
    end
    local sx, sy, _, on = self:project(pos)
    if not on then
        return
    end
    local cx, cy = self:cursor()
    local dx, dy = sx - cx, sy - cy
    local cfg = self.cfg.legit

    local mag = sqrt(dx * dx + dy * dy)
    if cfg.deadzone > 0 and mag <= cfg.deadzone then
        return
    end

    local sm = clamp(cfg.smooth, 0.01, 1)
    local smY = cfg.smoothY > 0 and clamp(cfg.smoothY, 0.01, 1) or sm
    local mx, my = dx * sm, dy * smY

    local hx, hy = self:_humanOffset()
    mx, my = mx + hx, my + hy

    local step = cfg.maxStep
    if step > 0 then
        mx = clamp(mx, -step, step)
        my = clamp(my, -step, step)
    end

    pcall(mousemoverel, mx, my)
end

function EasyAim:_applyRage(pos)
    if not cam then
        return
    end
    if self.cfg.rage.lockCam then
        local origin = cam.CFrame.Position
        local snap = clamp(self.cfg.rage.snap, 0.01, 1)
        local goal = CFrame.new(origin, pos)
        if snap >= 1 then
            cam.CFrame = goal
        else
            cam.CFrame = cam.CFrame:Lerp(goal, snap)
        end
    end
end

function EasyAim:_trigger(dt)
    local tr = self.cfg.trigger
    if not tr.on then
        self.triggerAt = 0
        return
    end
    local rec = self.roster[1]
    local cx, cy = self:cursor()
    local best, bestD = nil, huge
    for _, r in ipairs(self.roster) do
        if r.onScreen and r.screenDist < bestD then
            best, bestD = r, r.screenDist
        end
    end
    rec = best
    if not rec or bestD > tr.fov then
        self.triggerAt = 0
        return
    end
    if tr.visOnly and not self:sees(rec.model, rec.root) then
        self.triggerAt = 0
        return
    end
    if self.triggerAt == 0 then
        self.triggerAt = self.t + tr.delay
        return
    end
    if self.t >= self.triggerAt and (self.t - self.triggeredAt) >= tr.reset then
        self.triggeredAt = self.t
        self.triggerAt = 0
        if self.onFire then
            pcall(self.onFire, rec, self)
        end
    end
end

function EasyAim:_fov()
    local f = self.cfg.fov
    if not f.on or not Drawing then
        if self.circle then
            self.circle.Visible = false
        end
        return
    end
    if not self.circle then
        self.circle = drawing("Circle")
        if not self.circle then
            return
        end
    end
    local c = self.circle
    local cx, cy = self:cursor()
    c.Visible = self.cfg.on
    c.Position = Vector2.new(cx, cy)
    c.Radius = f.radius
    c.Color = f.col
    c.Thickness = f.thickness
    c.NumSides = f.sides
    c.Filled = f.filled
    c.Transparency = f.filled and f.fillA or 1
end

function EasyAim:tick(dt)
    self.t = self.t + dt
    cam = workspace.CurrentCamera

    self:_fov()

    if not self.cfg.on then
        self.target = nil
        self.aimPoint = nil
        self.stats.locked = false
        return
    end

    self:build()
    self:_trigger(dt)

    local engaged = (not self.cfg.hold) or self.held
    if not engaged then
        self.target = nil
        self.aimPoint = nil
        self.stats.locked = false
        return
    end

    local rec = self:pick()
    if not rec then
        self.aimPoint = nil
        self.stats.locked = false
        return
    end

    local pos = self:resolve(rec)
    if not pos then
        self.stats.locked = false
        return
    end

    self.stats.locked = true
    self.stats.name = rec.name
    self.stats.dist = rec.dist

    if self.onTarget then
        pcall(self.onTarget, rec, pos, self)
    end

    local mode = self.cfg.mode
    if mode == "legit" then
        self:_applyLegit(pos, dt)
    elseif mode == "rage" then
        self:_applyRage(pos)
    end
end

function EasyAim:_keyMatches(input)
    local k = self.cfg.key
    if not k then
        return false
    end
    if typeof(k) == "EnumItem" then
        if k.EnumType == Enum.UserInputType then
            return input.UserInputType == k
        end
        return input.KeyCode == k
    end
    return false
end

function EasyAim:start()
    if self.running then
        return self
    end
    self.running = true

    self.conns[#self.conns + 1] = Run.RenderStepped:Connect(function(dt)
        local ok, err = pcall(self.tick, self, dt)
        if not ok and not self._warned then
            self._warned = true
            warn("EasyAim tick error: " .. tostring(err))
        end
    end)

    self.conns[#self.conns + 1] = Input.InputBegan:Connect(function(input, gp)
        if gp then
            return
        end
        if self:_keyMatches(input) then
            self.held = true
        end
        local tk = self.cfg.trigger.key
        if tk and ((typeof(tk) == "EnumItem" and tk.EnumType == Enum.UserInputType and input.UserInputType == tk) or input.KeyCode == tk) then
            self.cfg.trigger.on = not self.cfg.trigger.on
        end
    end)

    self.conns[#self.conns + 1] = Input.InputEnded:Connect(function(input)
        if self:_keyMatches(input) then
            self.held = false
        end
    end)

    return self
end

function EasyAim:stop()
    self.running = false
    for _, c in ipairs(self.conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    self.conns = {}
    self.held = false
    self.target = nil
    self.aimPoint = nil
    if self.circle then
        self.circle.Visible = false
    end
    return self
end

function EasyAim:bind(key, fn)
    if not isCallable(fn) then
        return nil
    end
    local c = Input.InputBegan:Connect(function(input, gp)
        if gp then
            return
        end
        if input.KeyCode == key or input.UserInputType == key then
            pcall(fn, self)
        end
    end)
    self.binds[#self.binds + 1] = c
    return c
end

function EasyAim:clearBinds()
    local n = #self.binds
    for _, c in ipairs(self.binds) do
        pcall(function()
            c:Disconnect()
        end)
    end
    self.binds = {}
    return n
end

function EasyAim:destroy()
    self:stop()
    self:clearBinds()
    if self.circle then
        pcall(function()
            if self.circle.Destroy then
                self.circle:Destroy()
            elseif self.circle.Remove then
                self.circle:Remove()
            end
        end)
        self.circle = nil
    end
    self.roster = {}
    self.source = nil
    self.filter = nil
    self.resolver = nil
    self.predictor = nil
    self.onFire = nil
    self.onTarget = nil
    if STACK.__EASY_STACK.aim == self then
        STACK.__EASY_STACK.aim = nil
    end
    return nil
end

function EasyAim:getStats()
    return {
        roster = #self.roster,
        locked = self.stats.locked,
        name = self.stats.name,
        dist = self.stats.dist,
        mode = self.cfg.mode,
        held = self.held,
    }
end

EasyAim.Start = EasyAim.start
EasyAim.Stop = EasyAim.stop
EasyAim.Destroy = EasyAim.destroy
EasyAim.setEnabled = EasyAim.on
EasyAim.getTarget = function(self)
    return self.target
end

local DESCRIPTORS = {
    { path = "on", label = "Enabled", kind = "toggle", tab = "Aimbot", section = "Main", order = 10 },
    { path = "mode", label = "Mode", kind = "dropdown", items = { "legit", "rage", "silent" }, tab = "Aimbot", section = "Main", order = 20 },
    { path = "hold", label = "Hold Key", kind = "toggle", tab = "Aimbot", section = "Main", order = 30 },
    { path = "select", label = "Selection", kind = "dropdown", items = { "fov", "distance", "health", "threat" }, tab = "Aimbot", section = "Main", order = 40 },
    { path = "sticky", label = "Sticky Target", kind = "toggle", tab = "Aimbot", section = "Main", order = 50 },
    { path = "range", label = "Range", kind = "slider", min = 0, max = 5000, step = 25, tab = "Aimbot", section = "Main", order = 60 },
    { path = "team", label = "Team Check", kind = "toggle", tab = "Aimbot", section = "Filters", order = 70 },
    { path = "wallCheck", label = "Wall Check", kind = "toggle", tab = "Aimbot", section = "Filters", order = 80 },
    { path = "vis.on", label = "Visibility Rays", kind = "toggle", tab = "Aimbot", section = "Filters", order = 90 },
    { path = "vis.points", label = "Ray Points", kind = "slider", min = 1, max = 3, step = 1, tab = "Aimbot", section = "Filters", order = 100 },
    { path = "hitbox.kind", label = "Hitbox", kind = "dropdown", items = { "Head", "Torso", "Root", "Nearest", "Random" }, tab = "Aimbot", section = "Hitbox", order = 110 },
    { path = "fov.on", label = "FOV Circle", kind = "toggle", tab = "Aimbot", section = "FOV", order = 120 },
    { path = "fov.radius", label = "FOV Radius", kind = "slider", min = 0, max = 600, step = 5, tab = "Aimbot", section = "FOV", order = 130 },
    { path = "fov.col", label = "FOV Color", kind = "color", tab = "Aimbot", section = "FOV", order = 140 },
    { path = "fov.filled", label = "FOV Filled", kind = "toggle", tab = "Aimbot", section = "FOV", order = 150 },
    { path = "fov.follow", label = "Follow Mouse", kind = "toggle", tab = "Aimbot", section = "FOV", order = 160 },
    { path = "legit.smooth", label = "Smoothing", kind = "slider", min = 0.01, max = 1, step = 0.01, decimals = 2, tab = "Aimbot", section = "Legit", order = 170 },
    { path = "legit.deadzone", label = "Deadzone", kind = "slider", min = 0, max = 100, step = 1, tab = "Aimbot", section = "Legit", order = 180 },
    { path = "legit.maxStep", label = "Max Step", kind = "slider", min = 0, max = 300, step = 5, tab = "Aimbot", section = "Legit", order = 190 },
    { path = "rage.snap", label = "Snap", kind = "slider", min = 0.01, max = 1, step = 0.01, decimals = 2, tab = "Aimbot", section = "Rage", order = 200 },
    { path = "rage.lockCam", label = "Lock Camera", kind = "toggle", tab = "Aimbot", section = "Rage", order = 210 },
    { path = "humanize.on", label = "Humanize", kind = "toggle", tab = "Aimbot", section = "Humanize", order = 220 },
    { path = "humanize.jitter", label = "Jitter", kind = "slider", min = 0, max = 5, step = 0.1, decimals = 1, tab = "Aimbot", section = "Humanize", order = 230 },
    { path = "humanize.breath", label = "Breath", kind = "slider", min = 0, max = 5, step = 0.1, decimals = 1, tab = "Aimbot", section = "Humanize", order = 240 },
    { path = "predict.on", label = "Prediction", kind = "toggle", tab = "Aimbot", section = "Prediction", order = 250 },
    { path = "predict.factor", label = "Factor", kind = "slider", min = 0, max = 1, step = 0.005, decimals = 3, tab = "Aimbot", section = "Prediction", order = 260 },
    { path = "predict.speed", label = "Projectile Speed", kind = "slider", min = 0, max = 3000, step = 25, tab = "Aimbot", section = "Prediction", order = 270 },
    { path = "predict.gravity", label = "Gravity", kind = "slider", min = -200, max = 200, step = 1, tab = "Aimbot", section = "Prediction", order = 280 },
    { path = "trigger.on", label = "Triggerbot", kind = "toggle", tab = "Aimbot", section = "Trigger", order = 290 },
    { path = "trigger.fov", label = "Trigger FOV", kind = "slider", min = 1, max = 60, step = 1, tab = "Aimbot", section = "Trigger", order = 300 },
    { path = "trigger.delay", label = "Trigger Delay", kind = "slider", min = 0, max = 1, step = 0.01, decimals = 2, tab = "Aimbot", section = "Trigger", order = 310 },
    { path = "trigger.visOnly", label = "Trigger Vis Only", kind = "toggle", tab = "Aimbot", section = "Trigger", order = 320 },
}

local D = defaults()
for _, d in ipairs(DESCRIPTORS) do
    d.default = pathGet(D, d.path)
    d.bindable = true
    d.persist = true
end

EasyAim.Descriptors = DESCRIPTORS

function EasyAim.GetDescriptors(prefix)
    if type(prefix) == "table" then
        prefix = nil
    end
    local out = {}
    for i, d in ipairs(DESCRIPTORS) do
        local c = deep(d)
        if type(prefix) == "string" and #prefix > 0 then
            c.path = prefix .. "." .. c.path
        end
        out[i] = c
    end
    return out
end

function EasyAim.GetDescriptor(path)
    if type(path) == "table" then
        return nil
    end
    for _, d in ipairs(DESCRIPTORS) do
        if d.path == path then
            return deep(d)
        end
    end
    return nil
end

function EasyAim.Validate(selfOrPath, path, value)
    local p, v
    if type(selfOrPath) == "table" then
        p, v = path, value
    else
        p, v = selfOrPath, path
    end
    local d = EasyAim.GetDescriptor(p)
    if not d then
        return v
    end
    if d.kind == "toggle" then
        return not not v
    elseif d.kind == "slider" then
        local n = tonumber(v) or d.default or 0
        n = clamp(n, d.min or -huge, d.max or huge)
        if d.step and d.step > 0 then
            n = (d.min or 0) + floor((n - (d.min or 0)) / d.step + 0.5) * d.step
        end
        return n
    elseif d.kind == "dropdown" then
        local s = tostring(v)
        for _, item in ipairs(d.items or {}) do
            if item == s then
                return s
            end
        end
        return d.default
    elseif d.kind == "color" then
        return typeof(v) == "Color3" and v or d.default
    end
    return v
end

EasyAim.Toolkit = {
    version = EasyAim.ver,
    adapters = Adapters,
    clone = deep,
    merge = merge,
    fill = fill,
    pathGet = pathGet,
    pathSet = pathSet,
    descriptors = DESCRIPTORS,
    validate = function(path, value)
        return EasyAim.Validate(path, value)
    end,
    quick = function(opt)
        opt = type(opt) == "table" and opt or {}
        local adapter = opt.adapter
        local source = opt.source
        opt.adapter, opt.source = nil, nil
        local a = EasyAim.new(opt)
        if type(adapter) == "string" then
            a:useAdapter(adapter)
        elseif type(adapter) == "table" then
            a:setAdapter(adapter)
        end
        if isCallable(source) then
            a:setSource(source)
        end
        a:on(opt.on ~= false)
        a:start()
        return a
    end,
}

function EasyAim.DestroyAll()
    local a = STACK.__EASY_STACK.aim
    if a and a.destroy then
        pcall(function()
            a:destroy()
        end)
    end
end

return EasyAim
