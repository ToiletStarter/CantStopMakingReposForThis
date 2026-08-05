local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local LP = Players.LocalPlayer

local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local sin, cos, sqrt, pi = math.sin, math.cos, math.sqrt, math.pi
local clamp, noise = math.clamp, math.noise
local TAU = pi * 2
local v2, v3, cf = Vector2.new, Vector3.new, CFrame.new
local insert = table.insert

local WHITE = Color3.new(1, 1, 1)

if type(Drawing) ~= "table" and type(Drawing) ~= "userdata" then
    error("EasyWorld requires the Drawing API", 0)
end

local rp = type(setrenderproperty) == "function" and setrenderproperty or function(obj, prop, value)
    obj[prop] = value
end

local newDraw = Drawing.new

local function col3(c, fallback)
    if typeof(c) == "Color3" then
        return c
    end
    return fallback or WHITE
end

local function isPlainTable(v)
    return type(v) == "table" and typeof(v) == "table"
end

local function clone(t)
    if not isPlainTable(t) then
        return t
    end
    local out = {}
    for k, v in pairs(t) do
        out[k] = isPlainTable(v) and clone(v) or v
    end
    return out
end

local function fill(t, d)
    t = type(t) == "table" and t or {}
    for k, v in pairs(d) do
        if t[k] == nil then
            t[k] = isPlainTable(v) and clone(v) or v
        elseif isPlainTable(v) and isPlainTable(t[k]) then
            fill(t[k], v)
        end
    end
    return t
end

local function merge(base, over)
    if not isPlainTable(over) then
        return base
    end
    for k, v in pairs(over) do
        if isPlainTable(v) and isPlainTable(base[k]) then
            merge(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

local function pathGet(root, path)
    local node = root
    for key in tostring(path or ""):gmatch("[^%.]+") do
        if type(node) ~= "table" then
            return nil
        end
        node = node[tonumber(key) or key]
    end
    return node
end

local function pathSet(root, path, value)
    local node, last = root, nil
    local keys = {}
    for key in tostring(path or ""):gmatch("[^%.]+") do
        keys[#keys + 1] = tonumber(key) or key
    end
    for i = 1, #keys - 1 do
        local k = keys[i]
        if type(node[k]) ~= "table" then
            node[k] = {}
        end
        node = node[k]
    end
    last = keys[#keys]
    if last ~= nil then
        node[last] = value
    end
    return value
end

local Pool = {}
Pool.__index = Pool

function Pool.new()
    return setmetatable({
        bank = {},
        shadow = {},
        live = {},
        prev = {},
        idle = {},
        frame = 0,
        size = 0,
        zbias = 0,
    }, Pool)
end

function Pool:get(key, kind)
    local d = self.bank[key]
    local s = self.shadow[key]
    if d and (not s or s.kind ~= kind) then
        pcall(function() d:Destroy() end)
        d = nil
        self.size = max(0, self.size - 1)
    end
    if not d then
        d = newDraw(kind)
        self.bank[key] = d
        s = { kind = kind }
        self.shadow[key] = s
        self.size = self.size + 1
    end
    self.live[key] = true
    self.idle[key] = nil
    return d, s
end

function Pool:begin()
    self.frame = self.frame + 1
    for k in pairs(self.live) do
        self.live[k] = nil
    end
end

function Pool:hide(key)
    local d, s = self.bank[key], self.shadow[key]
    if d and (not s or s.vis ~= false) then
        pcall(rp, d, "Visible", false)
    end
    if s then
        s.vis = false
    end
    self.idle[key] = self.frame
end

function Pool:finish()
    for k in pairs(self.prev) do
        if not self.live[k] then
            self:hide(k)
        end
        self.prev[k] = nil
    end
    for k in pairs(self.live) do
        self.prev[k] = true
    end
end

function Pool:prune(age)
    if not age or age <= 0 then
        return
    end
    local cut = self.frame - age
    for k, at in pairs(self.idle) do
        if at <= cut then
            local d = self.bank[k]
            if d then
                pcall(function() d:Destroy() end)
            end
            self.bank[k] = nil
            self.shadow[k] = nil
            self.idle[k] = nil
            self.prev[k] = nil
            self.live[k] = nil
            self.size = max(0, self.size - 1)
        end
    end
end

function Pool:reset()
    for k in pairs(self.bank) do
        self:hide(k)
    end
    for k in pairs(self.prev) do
        self.prev[k] = nil
    end
    for k in pairs(self.live) do
        self.live[k] = nil
    end
end

function Pool:nuke()
    for _, d in pairs(self.bank) do
        pcall(function() d:Destroy() end)
    end
    self.bank, self.shadow, self.live, self.prev, self.idle = {}, {}, {}, {}, {}
    self.frame, self.size = 0, 0
end

function Pool:line(key, ax, ay, bx, by, c, w, a, z)
    if a ~= nil and a <= 0.004 then
        return
    end
    local d, s = self:get(key, "Line")
    z = (z or 0) + self.zbias
    c = col3(c)
    if s.ax ~= ax or s.ay ~= ay then
        s.ax, s.ay = ax, ay
        rp(d, "From", v2(ax, ay))
    end
    if s.bx ~= bx or s.by ~= by then
        s.bx, s.by = bx, by
        rp(d, "To", v2(bx, by))
    end
    if s.c ~= c then
        s.c = c
        rp(d, "Color", c)
    end
    w = w or 1
    if s.w ~= w then
        s.w = w
        rp(d, "Thickness", w)
    end
    a = a == nil and 1 or a
    if s.a ~= a then
        s.a = a
        rp(d, "Transparency", a)
    end
    if s.z ~= z then
        s.z = z
        rp(d, "ZIndex", z)
    end
    if not s.vis then
        s.vis = true
        rp(d, "Visible", true)
    end
end

function Pool:tri(key, ax, ay, bx, by, cx, cy, c, a, z)
    if a ~= nil and a <= 0.004 then
        return
    end
    local d, s = self:get(key, "Triangle")
    z = (z or 0) + self.zbias
    c = col3(c)
    if s.ax ~= ax or s.ay ~= ay then
        s.ax, s.ay = ax, ay
        rp(d, "PointA", v2(ax, ay))
    end
    if s.bx ~= bx or s.by ~= by then
        s.bx, s.by = bx, by
        rp(d, "PointB", v2(bx, by))
    end
    if s.cx ~= cx or s.cy ~= cy then
        s.cx, s.cy = cx, cy
        rp(d, "PointC", v2(cx, cy))
    end
    if s.c ~= c then
        s.c = c
        rp(d, "Color", c)
    end
    if not s.filled then
        s.filled = true
        rp(d, "Filled", true)
    end
    a = a == nil and 1 or a
    if s.a ~= a then
        s.a = a
        rp(d, "Transparency", a)
    end
    if s.z ~= z then
        s.z = z
        rp(d, "ZIndex", z)
    end
    if not s.vis then
        s.vis = true
        rp(d, "Visible", true)
    end
end

function Pool:dot(key, x, y, r, c, filled, a, sides, z, w)
    if a ~= nil and a <= 0.004 then
        return
    end
    local d, s = self:get(key, "Circle")
    z = (z or 0) + self.zbias
    c = col3(c)
    if s.x ~= x or s.y ~= y then
        s.x, s.y = x, y
        rp(d, "Position", v2(x, y))
    end
    if s.r ~= r then
        s.r = r
        rp(d, "Radius", r)
    end
    if s.c ~= c then
        s.c = c
        rp(d, "Color", c)
    end
    filled = filled and true or false
    if s.filled ~= filled then
        s.filled = filled
        rp(d, "Filled", filled)
    end
    sides = sides or 24
    if s.sides ~= sides then
        s.sides = sides
        rp(d, "NumSides", sides)
    end
    w = w or 1
    if s.w ~= w then
        s.w = w
        rp(d, "Thickness", w)
    end
    a = a == nil and 1 or a
    if s.a ~= a then
        s.a = a
        rp(d, "Transparency", a)
    end
    if s.z ~= z then
        s.z = z
        rp(d, "ZIndex", z)
    end
    if not s.vis then
        s.vis = true
        rp(d, "Visible", true)
    end
end

function Pool:txt(key, str, x, y, size, c, center, outline, a, z)
    if a ~= nil and a <= 0.004 then
        return
    end
    local d, s = self:get(key, "Text")
    z = (z or 0) + self.zbias
    c = col3(c)
    str = tostring(str)
    if s.str ~= str then
        s.str = str
        rp(d, "Text", str)
    end
    size = size or 12
    if s.size ~= size then
        s.size = size
        rp(d, "Size", size)
    end
    if s.c ~= c then
        s.c = c
        rp(d, "Color", c)
    end
    center = center and true or false
    if s.center ~= center then
        s.center = center
        rp(d, "Center", center)
    end
    outline = outline ~= false
    if s.outline ~= outline then
        s.outline = outline
        rp(d, "Outline", outline)
    end
    if s.x ~= x or s.y ~= y then
        s.x, s.y = x, y
        rp(d, "Position", v2(x, y))
    end
    a = a == nil and 1 or a
    if s.a ~= a then
        s.a = a
        rp(d, "Transparency", a)
    end
    if s.z ~= z then
        s.z = z
        rp(d, "ZIndex", z)
    end
    if not s.vis then
        s.vis = true
        rp(d, "Visible", true)
    end
    return d
end

local UP = v3(0, 1, 0)
local FWD = v3(0, 0, -1)

local function normalize(v)
    local m = v.Magnitude
    if m < 1e-6 then
        return UP
    end
    return v / m
end

local function basisFromNormal(n)
    n = normalize(n)
    local ref = abs(n.Y) > 0.99 and FWD or UP
    local u = normalize(n:Cross(ref))
    local w = n:Cross(u)
    return u, w
end

local function tiltNormal(tilt, yaw)
    if (tilt or 0) == 0 and (yaw or 0) == 0 then
        return UP
    end
    local t = math.rad(tilt or 0)
    local y = math.rad(yaw or 0)
    local sy, cy = sin(y), cos(y)
    local st, ct = sin(t), cos(t)
    return normalize(v3(sy * st, ct, cy * st))
end

local Shapes = {}

local Runtime = {}
local GENV = (type(getgenv) == "function" and getgenv()) or shared or _G
GENV.__EASY_STACK = GENV.__EASY_STACK or {}
Runtime = GENV.__EASY_STACK

local World = {}
World.__index = World
World.ver = "1.0.0"

local function commonSpec(p)
    return fill(p or {}, {
        on = true,
        col = Color3.fromRGB(150, 190, 255),
        col2 = nil,
        a = 1,
        w = 2,
        glow = true,
        glowLayers = 2,
        glowGain = 0.28,
        glowSpread = 2.5,
        pulse = false,
        pulseRate = 2,
        pulseDepth = 0.35,
        depthFade = true,
        depthFadeGain = 0.55,
        scaleWidth = true,
        widthNear = 60,
        widthGain = 1.9,
        maxDist = 0,
        fadeDist = 0,
        occlude = false,
        occludeStep = 3,
        z = 0,
        priority = 0,
        label = nil,
        labelSize = 12,
        labelOffset = -14,
    })
end

function World.new(opt)
    opt = opt or {}
    local previous = Runtime.world
    if previous and previous ~= World and type(previous.destroy) == "function" then
        pcall(function() previous:destroy() end)
    end

    local self = setmetatable({}, World)
    self.pool = Pool.new()
    self.items = {}
    self.order = {}
    self.t = 0
    self.dt = 1 / 60
    self.enabled = opt.on ~= false
    self.running = false
    self.conn = nil
    self.stats = { drawn = 0, culled = 0, segs = 0, pool = 0 }
    self.cam = Workspace.CurrentCamera
    self.rayParams = RaycastParams.new()
    self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
    self.rayParams.IgnoreWater = true
    self.cfg = fill(opt.cfg, {
        quality = 1,
        pruneAge = 240,
        maxSegs = 12000,
        cullBehind = true,
        globalAlpha = 1,
    })
    self._occCache = {}
    self._occFrame = -1

    self._camConn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        self.cam = Workspace.CurrentCamera
    end)

    Runtime.world = self
    return self
end

function World:_ignore()
    local list = {}
    local char = LP and LP.Character
    if char then
        insert(list, char)
    end
    if self.ignoreExtra then
        for _, v in ipairs(self.ignoreExtra) do
            insert(list, v)
        end
    end
    self.rayParams.FilterDescendantsInstances = list
    return self.rayParams
end

function World:setIgnore(list)
    self.ignoreExtra = list
    return self
end

function World:project(pos)
    local cam = self.cam
    if not cam then
        return 0, 0, -1, false
    end
    local p, on = cam:WorldToViewportPoint(pos)
    return p.X, p.Y, p.Z, on
end

function World:_visible(pos)
    if self._occFrame ~= self.pool.frame then
        self._occFrame = self.pool.frame
        self._occCache = {}
    end
    local cam = self.cam
    if not cam then
        return true
    end
    local origin = cam.CFrame.Position
    local delta = pos - origin
    local dist = delta.Magnitude
    if dist < 1 then
        return true
    end
    local hit = Workspace:Raycast(origin, delta.Unit * (dist - 0.5), self:_ignore())
    return hit == nil
end

function World:_alpha(spec, dist, depth)
    local a = tonumber(spec.a) or 1
    a = a * (tonumber(self.cfg.globalAlpha) or 1)
    if spec.pulse then
        local depthAmt = tonumber(spec.pulseDepth) or 0.35
        a = a * (1 - depthAmt + depthAmt * abs(sin(self.t * (tonumber(spec.pulseRate) or 2))))
    end
    local fade = tonumber(spec.fadeDist)
    if fade and fade > 0 and dist then
        a = a * clamp(1 - (dist / fade), 0, 1)
    end
    if spec.depthFade and depth and depth > 0 then
        a = a * clamp(1 - (depth / 900) * (tonumber(spec.depthFadeGain) or 0.55), 0.18, 1)
    end
    return clamp(a, 0, 1)
end

function World:_width(spec, depth)
    local w = spec.w or 1
    if not spec.scaleWidth or not depth or depth <= 0 then
        return w
    end
    local k = clamp((spec.widthNear or 60) / depth, 0.35, spec.widthGain or 1.9)
    return max(0.6, w * k)
end

function World:_stroke(key, ax, ay, bx, by, spec, c, a, w, z)
    if a <= 0.004 then
        return
    end
    local pool = self.pool
    if spec.glow and (spec.glowLayers or 0) > 0 then
        local layers = min(4, spec.glowLayers)
        for i = 1, layers do
            local t = i / layers
            pool:line(key .. "_g" .. i, ax, ay, bx, by, c, w + (spec.glowSpread or 2.5) * t * 2, a * (spec.glowGain or 0.28) * (1 - t * 0.55), z - 1)
        end
    end
    pool:line(key, ax, ay, bx, by, c, w, a, z)
    self.stats.segs = self.stats.segs + 1
end

local function lerpColor(a, b, t)
    if not b then
        return a
    end
    return a:Lerp(b, clamp(t, 0, 1))
end

function World:_polyline(key, pts, spec, closed, alphaScale)
    local n = #pts
    if n < 2 then
        return
    end
    local last = closed and n or n - 1
    local dash = spec.style == "dashed"
    local dashOn = max(1, floor(spec.dashOn or 2))
    local dashOff = max(1, floor(spec.dashOff or 2))
    local period = dashOn + dashOff
    local phase = dash and floor((self.t * (spec.dashSpeed or 0)) % period) or 0
    for i = 1, last do
        if not dash or (((i + phase) % period) < dashOn) then
            local A = pts[i]
            local B = pts[(i % n) + 1]
            if A[3] > 0 and B[3] > 0 then
                local depth = (A[3] + B[3]) * 0.5
                local a = self:_alpha(spec, spec._dist, depth) * (alphaScale or 1)
                if A[4] then
                    a = a * A[4]
                end
                local c = spec.col
                if spec.col2 then
                    c = lerpColor(spec.col, spec.col2, (i - 1) / max(1, last - 1))
                end
                self:_stroke(key .. "_" .. i, A[1], A[2], B[1], B[2], spec, c, a, self:_width(spec, depth), spec.z)
            end
        end
    end
end

function World:_ringPoints(center, radius, normal, spec, sides, phase)
    local u, w = basisFromNormal(normal)
    local pts = {}
    local wig = spec.wiggle or 0
    local wigFreq = spec.wiggleFreq or 6
    local wigSpeed = spec.wiggleSpeed or 2
    local wigMode = spec.wiggleMode or "sine"
    local spin = self.t * (spec.spin or 0) + (phase or 0)
    local squash = spec.squash or 1
    local occStep = max(1, spec.occludeStep or 3)
    for i = 0, sides do
        local ang = (i / sides) * TAU + spin
        local r = radius
        if wig ~= 0 then
            if wigMode == "noise" then
                r = r + noise(cos(ang) * wigFreq * 0.35, sin(ang) * wigFreq * 0.35, self.t * wigSpeed * 0.5) * wig * 2
            else
                r = r + sin(ang * wigFreq + self.t * wigSpeed) * wig
            end
        end
        local p = center + u * (cos(ang) * r) + w * (sin(ang) * r * squash)
        local x, y, d = self:project(p)
        local fade = nil
        if spec.occlude and (i % occStep == 0) then
            fade = self:_visible(p) and 1 or (spec.occludeAlpha or 0.22)
            spec._lastOcc = fade
        elseif spec.occlude then
            fade = spec._lastOcc or 1
        end
        pts[i + 1] = { x, y, d, fade }
    end
    pts[#pts] = nil
    return pts
end

Shapes.ring = function(self, key, spec)
    local center = spec._pos
    if not center then
        return
    end
    local sides = max(8, floor((spec.sides or 48) * (self.cfg.quality or 1)))
    local normal = spec.normal or tiltNormal(spec.tilt, spec.yaw)
    local lanes = max(1, floor(spec.lanes or 1))
    for lane = 1, lanes do
        local off = lanes > 1 and (lane - (lanes + 1) * 0.5) * (spec.laneGap or 0.6) or 0
        local rad = (spec.rad or 10) + off
        if rad > 0.05 then
            local phase = lanes > 1 and (lane / lanes) * (spec.lanePhase or 0) or 0
            local pts = self:_ringPoints(center + normal * ((spec.lift or 0) + (lanes > 1 and off * (spec.laneLift or 0) or 0)), rad, normal, spec, sides, phase)
            self:_polyline(key .. "_l" .. lane, pts, spec, true, lanes > 1 and (1 - (lane - 1) / lanes * 0.35) or 1)
            if spec.fill then
                local cx, cy, cd = self:project(center)
                if cd > 0 then
                    local fa = self:_alpha(spec, spec._dist, cd) * (spec.fillA or 0.06)
                    for i = 1, #pts do
                        local A, B = pts[i], pts[(i % #pts) + 1]
                        if A[3] > 0 and B[3] > 0 then
                            self.pool:tri(key .. "_f" .. lane .. "_" .. i, cx, cy, A[1], A[2], B[1], B[2], spec.col, fa, (spec.z or 0) - 2)
                        end
                    end
                end
            end
            if (spec.ticks or 0) > 0 then
                local u, w = basisFromNormal(normal)
                local tl = spec.tickLen or 1.2
                local spin = self.t * (spec.spin or 0)
                for i = 0, spec.ticks - 1 do
                    local ang = (i / spec.ticks) * TAU + spin
                    local dir = u * cos(ang) + w * sin(ang)
                    local p0 = center + dir * rad
                    local p1 = center + dir * (rad + tl)
                    local x0, y0, d0 = self:project(p0)
                    local x1, y1, d1 = self:project(p1)
                    if d0 > 0 and d1 > 0 then
                        self:_stroke(key .. "_t" .. lane .. "_" .. i, x0, y0, x1, y1, spec, spec.col, self:_alpha(spec, spec._dist, d0), self:_width(spec, d0), spec.z)
                    end
                end
            end
        end
    end
end

Shapes.disc = function(self, key, spec)
    local center = spec._pos
    if not center then
        return
    end
    local normal = spec.normal or tiltNormal(spec.tilt, spec.yaw)
    local sides = max(10, floor((spec.sides or 44) * (self.cfg.quality or 1)))
    local rings = max(1, floor(spec.bands or 1))
    local cx, cy, cd = self:project(center + normal * (spec.lift or 0.05))
    if cd <= 0 then
        return
    end
    for b = 1, rings do
        local rad = (spec.rad or 10) * (b / rings)
        local pts = self:_ringPoints(center + normal * (spec.lift or 0.05), rad, normal, spec, sides, 0)
        local fa = self:_alpha(spec, spec._dist, cd) * (spec.fillA or 0.07) * (1 - (b - 1) / rings * 0.6)
        for i = 1, #pts do
            local A, B = pts[i], pts[(i % #pts) + 1]
            if A[3] > 0 and B[3] > 0 then
                self.pool:tri(key .. "_f" .. b .. "_" .. i, cx, cy, A[1], A[2], B[1], B[2], spec.col2 or spec.col, fa, (spec.z or 0) - 2)
            end
        end
        if b == rings then
            self:_polyline(key .. "_edge", pts, spec, true, 1)
        end
    end
end

Shapes.sphere = function(self, key, spec)
    local center = spec._pos
    if not center then
        return
    end
    local rad = spec.rad or 3
    local sides = max(10, floor((spec.sides or 30) * (self.cfg.quality or 1)))
    local bands = max(1, floor(spec.bands or 3))
    local meridians = max(0, floor(spec.meridians or 3))
    local spinN = spec.gyro and normalize(v3(sin(self.t * (spec.spin or 0.4)), 1, cos(self.t * (spec.spin or 0.4)))) or UP

    for b = 1, bands do
        local t = bands == 1 and 0 or ((b - 1) / (bands - 1)) * 2 - 1
        local y = t * rad * (spec.bandSpread or 0.72)
        local r = sqrt(max(0, rad * rad - y * y))
        if r > 0.05 then
            local sub = clone(spec)
            sub.wiggle = spec.wiggle
            sub.spin = spec.spin
            local pts = self:_ringPoints(center + spinN * y, r, spinN, sub, sides, 0)
            self:_polyline(key .. "_b" .. b, pts, spec, true, 1 - abs(t) * 0.35)
        end
    end

    for m = 1, meridians do
        local yaw = (m - 1) / meridians * pi + self.t * (spec.meridianSpin or 0)
        local n = normalize(v3(cos(yaw), 0, sin(yaw)))
        local pts = self:_ringPoints(center, rad, n, spec, sides, 0)
        self:_polyline(key .. "_m" .. m, pts, spec, true, 0.75)
    end

    if spec.core then
        local x, y, d = self:project(center)
        if d > 0 then
            self.pool:dot(key .. "_core", x, y, spec.coreSize or 3, spec.col2 or spec.col, true, self:_alpha(spec, spec._dist, d) * (spec.coreA or 0.9), 16, spec.z)
        end
    end
end

Shapes.cylinder = function(self, key, spec)
    local center = spec._pos
    if not center then
        return
    end
    local normal = spec.normal or tiltNormal(spec.tilt, spec.yaw)
    local h = spec.height or 6
    local rad = spec.rad or 5
    local sides = max(8, floor((spec.sides or 40) * (self.cfg.quality or 1)))
    local rings = max(2, floor(spec.rings or 2))
    local stored = {}
    for i = 1, rings do
        local t = (i - 1) / (rings - 1)
        local rr = spec.taper and rad * (1 - t * spec.taper) or rad
        local pts = self:_ringPoints(center + normal * (h * t), rr, normal, spec, sides, 0)
        stored[i] = pts
        self:_polyline(key .. "_r" .. i, pts, spec, true, i == 1 and 1 or (0.5 + 0.5 * (1 - t)))
    end
    local posts = max(0, floor(spec.posts or 8))
    if posts > 0 then
        local step = max(1, floor(sides / posts))
        local a1, a2 = stored[1], stored[rings]
        for i = 1, sides, step do
            local A, B = a1[i], a2[i]
            if A and B and A[3] > 0 and B[3] > 0 then
                local depth = (A[3] + B[3]) * 0.5
                self:_stroke(key .. "_p" .. i, A[1], A[2], B[1], B[2], spec, spec.col, self:_alpha(spec, spec._dist, depth) * (spec.postA or 0.55), self:_width(spec, depth), spec.z)
            end
        end
    end
end

local CUBE_CORNERS = {
    v3(-1, -1, -1), v3(1, -1, -1), v3(1, -1, 1), v3(-1, -1, 1),
    v3(-1, 1, -1), v3(1, 1, -1), v3(1, 1, 1), v3(-1, 1, 1),
}
local CUBE_EDGES = {
    { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
    { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

Shapes.box = function(self, key, spec)
    local pivot = spec._cframe
    if not pivot then
        local p = spec._pos
        if not p then
            return
        end
        pivot = cf(p)
    end
    local size = spec.size or v3(3, 3, 3)
    local half = size * 0.5
    local pts = {}
    for i, c in ipairs(CUBE_CORNERS) do
        local wp = pivot:PointToWorldSpace(v3(c.X * half.X, c.Y * half.Y, c.Z * half.Z))
        local x, y, d = self:project(wp)
        pts[i] = { x, y, d, wp }
    end
    local corner = spec.corner or 0
    for i, e in ipairs(CUBE_EDGES) do
        local A, B = pts[e[1]], pts[e[2]]
        if A[3] > 0 and B[3] > 0 then
            local depth = (A[3] + B[3]) * 0.5
            local a = self:_alpha(spec, spec._dist, depth)
            local w = self:_width(spec, depth)
            local c = spec.col
            if corner > 0 and corner < 0.5 then
                local dx, dy = B[1] - A[1], B[2] - A[2]
                self:_stroke(key .. "_e" .. i .. "a", A[1], A[2], A[1] + dx * corner, A[2] + dy * corner, spec, c, a, w, spec.z)
                self:_stroke(key .. "_e" .. i .. "b", B[1], B[2], B[1] - dx * corner, B[2] - dy * corner, spec, c, a, w, spec.z)
            else
                self:_stroke(key .. "_e" .. i, A[1], A[2], B[1], B[2], spec, c, a, w, spec.z)
            end
        end
    end
    if spec.fill then
        local faces = {
            { 1, 2, 3, 4 }, { 5, 6, 7, 8 }, { 1, 2, 6, 5 },
            { 2, 3, 7, 6 }, { 3, 4, 8, 7 }, { 4, 1, 5, 8 },
        }
        for fi, f in ipairs(faces) do
            local a1, b1, c1, d1 = pts[f[1]], pts[f[2]], pts[f[3]], pts[f[4]]
            if a1[3] > 0 and b1[3] > 0 and c1[3] > 0 and d1[3] > 0 then
                local depth = (a1[3] + b1[3] + c1[3] + d1[3]) * 0.25
                local fa = self:_alpha(spec, spec._dist, depth) * (spec.fillA or 0.07)
                self.pool:tri(key .. "_f" .. fi .. "a", a1[1], a1[2], b1[1], b1[2], c1[1], c1[2], spec.col2 or spec.col, fa, (spec.z or 0) - 2)
                self.pool:tri(key .. "_f" .. fi .. "b", a1[1], a1[2], c1[1], c1[2], d1[1], d1[2], spec.col2 or spec.col, fa, (spec.z or 0) - 2)
            end
        end
    end
end

Shapes.path = function(self, key, spec)
    local list = spec._points
    if type(list) ~= "table" or #list < 2 then
        return
    end
    local pts = {}
    for i, p in ipairs(list) do
        local x, y, d = self:project(p)
        pts[i] = { x, y, d }
    end
    self:_polyline(key, pts, spec, false, 1)
    if spec.head then
        local last = pts[#pts]
        if last and last[3] > 0 then
            self.pool:dot(key .. "_h", last[1], last[2], spec.headSize or 4, spec.col2 or spec.col, true, self:_alpha(spec, spec._dist, last[3]), 16, spec.z)
        end
    end
end

Shapes.beam = function(self, key, spec)
    local a, b = spec._pos, spec._pos2
    if not a or not b then
        return
    end
    local segs = max(1, floor(spec.segments or 1))
    local pts = {}
    for i = 0, segs do
        local t = i / segs
        local p = a:Lerp(b, t)
        if spec.sag and spec.sag ~= 0 then
            p = p + UP * (-spec.sag * sin(t * pi))
        end
        local x, y, d = self:project(p)
        pts[i + 1] = { x, y, d }
    end
    self:_polyline(key, pts, spec, false, 1)
    if spec.arrow then
        local A, B = pts[#pts - 1], pts[#pts]
        if A and B and A[3] > 0 and B[3] > 0 then
            local dx, dy = B[1] - A[1], B[2] - A[2]
            local m = sqrt(dx * dx + dy * dy)
            if m > 0.5 then
                dx, dy = dx / m, dy / m
                local sz = spec.arrowSize or 9
                local px, py = -dy, dx
                local alpha = self:_alpha(spec, spec._dist, B[3])
                self.pool:tri(key .. "_ar", B[1], B[2], B[1] - dx * sz + px * sz * 0.5, B[2] - dy * sz + py * sz * 0.5, B[1] - dx * sz - px * sz * 0.5, B[2] - dy * sz - py * sz * 0.5, spec.col, alpha, spec.z)
            end
        end
    end
end

Shapes.marker = function(self, key, spec)
    local p = spec._pos
    if not p then
        return
    end
    local x, y, d = self:project(p)
    if d <= 0 then
        return
    end
    local a = self:_alpha(spec, spec._dist, d)
    local size = spec.size2d or 8
    local w = self:_width(spec, d)
    local shape = spec.marker or "diamond"
    if shape == "cross" then
        self:_stroke(key .. "_1", x - size, y, x + size, y, spec, spec.col, a, w, spec.z)
        self:_stroke(key .. "_2", x, y - size, x, y + size, spec, spec.col, a, w, spec.z)
    elseif shape == "dot" then
        self.pool:dot(key .. "_d", x, y, size * 0.5, spec.col, true, a, 18, spec.z)
    else
        self:_stroke(key .. "_1", x, y - size, x + size, y, spec, spec.col, a, w, spec.z)
        self:_stroke(key .. "_2", x + size, y, x, y + size, spec, spec.col, a, w, spec.z)
        self:_stroke(key .. "_3", x, y + size, x - size, y, spec, spec.col, a, w, spec.z)
        self:_stroke(key .. "_4", x - size, y, x, y - size, spec, spec.col, a, w, spec.z)
    end
end

Shapes.text = function(self, key, spec)
    local p = spec._pos
    if not p then
        return
    end
    local x, y, d = self:project(p)
    if d <= 0 then
        return
    end
    self.pool:txt(key, spec._text or spec.text or "", x, y + (spec.textOffset or 0), spec.labelSize or 12, spec.col, spec.center ~= false, true, self:_alpha(spec, spec._dist, d), spec.z)
end

Shapes.orbit = function(self, key, spec)
    local center = spec._pos
    if not center then
        return
    end
    local normal = spec.normal or tiltNormal(spec.tilt, spec.yaw)
    local sides = max(12, floor((spec.sides or 56) * (self.cfg.quality or 1)))
    local lanes = max(1, floor(spec.lanes or 1))
    local u, w = basisFromNormal(normal)

    for lane = 1, lanes do
        local laneT = lanes == 1 and 0 or (lane - 1) / (lanes - 1)
        local rad = (spec.rad or 8) + (lanes > 1 and (laneT - 0.5) * (spec.laneGap or 1.2) or 0)
        local lift = (spec.lift or 0) + (lanes > 1 and (laneT - 0.5) * (spec.laneLift or 0) or 0)
        if rad > 0.05 then
            local sub = clone(spec)
            local pts = self:_ringPoints(center + normal * lift, rad, normal, sub, sides, laneT * (spec.lanePhase or 0))
            self:_polyline(key .. "_l" .. lane, pts, spec, true, 1 - laneT * 0.3)
        end
    end

    local ang = spec._angle
    if ang then
        local rad = spec.rad or 8
        local p = center + u * (cos(ang) * rad) + w * (sin(ang) * rad) + normal * (spec.lift or 0)
        local x, y, d = self:project(p)
        if d > 0 then
            local a = self:_alpha(spec, spec._dist, d)
            self.pool:dot(key .. "_pos", x, y, spec.markerSize or 5, spec.col2 or spec.col, true, a, 20, (spec.z or 0) + 1)
            self.pool:dot(key .. "_posr", x, y, (spec.markerSize or 5) + 4, spec.col2 or spec.col, false, a * 0.5, 20, (spec.z or 0) + 1, 1.5)
        end
        local trail = max(0, floor(spec.trail or 0))
        if trail > 0 then
            local tp = {}
            local dir = spec.dir or 1
            for i = 0, trail do
                local aa = ang - dir * (i / trail) * (spec.trailArc or 1.1)
                local p2 = center + u * (cos(aa) * rad) + w * (sin(aa) * rad) + normal * (spec.lift or 0)
                local x2, y2, d2 = self:project(p2)
                tp[i + 1] = { x2, y2, d2, 1 - i / trail }
            end
            local ts = clone(spec)
            ts.glow = false
            ts.w = (spec.w or 2) + 1.5
            self:_polyline(key .. "_tr", tp, ts, false, 1)
        end
    end
end

Shapes.arc = function(self, key, spec)
    local center = spec._pos
    if not center then
        return
    end
    local normal = spec.normal or tiltNormal(spec.tilt, spec.yaw)
    local u, w = basisFromNormal(normal)
    local from = math.rad(spec.from or 0)
    local to = math.rad(spec.to or 90)
    local sides = max(4, floor((spec.sides or 28) * (self.cfg.quality or 1)))
    local rad = spec.rad or 6
    local pts = {}
    for i = 0, sides do
        local ang = from + (to - from) * (i / sides)
        local p = center + u * (cos(ang) * rad) + w * (sin(ang) * rad)
        local x, y, d = self:project(p)
        pts[i + 1] = { x, y, d }
    end
    self:_polyline(key, pts, spec, false, 1)
    if spec.wedge then
        local cx, cy, cd = self:project(center)
        if cd > 0 then
            local fa = self:_alpha(spec, spec._dist, cd) * (spec.fillA or 0.06)
            for i = 1, #pts - 1 do
                local A, B = pts[i], pts[i + 1]
                if A[3] > 0 and B[3] > 0 then
                    self.pool:tri(key .. "_w" .. i, cx, cy, A[1], A[2], B[1], B[2], spec.col, fa, (spec.z or 0) - 2)
                end
            end
        end
    end
end

Shapes.trail = Shapes.path

local SHAPE_DEFAULTS = {
    ring = { rad = 10, sides = 48, tilt = 0, yaw = 0, lift = 0.08, spin = 0, wiggle = 0, wiggleFreq = 6, wiggleSpeed = 2, lanes = 1, laneGap = 0.6, laneLift = 0, lanePhase = 0, fill = false, fillA = 0.06, ticks = 0, tickLen = 1.2, squash = 1, style = "solid", dashOn = 2, dashOff = 2, dashSpeed = 0 },
    disc = { rad = 10, sides = 44, bands = 3, fillA = 0.07, lift = 0.06 },
    sphere = { rad = 3, sides = 30, bands = 3, meridians = 3, bandSpread = 0.72, gyro = true, spin = 0.4, meridianSpin = 0, core = false, coreSize = 3, coreA = 0.9 },
    cylinder = { rad = 5, height = 6, sides = 40, rings = 2, posts = 8, postA = 0.55, taper = 0 },
    box = { size = v3(3, 3, 3), corner = 0, fill = false, fillA = 0.07 },
    path = { head = false, headSize = 4 },
    trail = { head = false, headSize = 4 },
    beam = { segments = 1, sag = 0, arrow = false, arrowSize = 9 },
    marker = { marker = "diamond", size2d = 8 },
    text = { labelSize = 12, center = true, textOffset = 0 },
    orbit = { rad = 8, sides = 56, lanes = 1, laneGap = 1.2, laneLift = 0, lanePhase = 0, tilt = 0, yaw = 0, lift = 0, spin = 0, wiggle = 0, markerSize = 5, trail = 10, trailArc = 1.1, dir = 1 },
    arc = { rad = 6, from = 0, to = 90, sides = 28, wedge = false, fillA = 0.06 },
}

function World:add(id, spec)
    id = tostring(id)
    spec = spec or {}
    local kind = spec.kind or "ring"
    if not Shapes[kind] then
        return nil
    end
    local merged = commonSpec(clone(spec))
    fill(merged, SHAPE_DEFAULTS[kind] or {})
    merged.kind = kind
    merged.id = id
    if self.items[id] then
        self:remove(id)
    end
    self.items[id] = merged
    insert(self.order, id)
    table.sort(self.order, function(a, b)
        local A, B = self.items[a], self.items[b]
        if not A or not B then
            return false
        end
        if (A.priority or 0) == (B.priority or 0) then
            return a < b
        end
        return (A.priority or 0) < (B.priority or 0)
    end)
    return merged
end

function World:remove(id)
    id = tostring(id)
    if not self.items[id] then
        return false
    end
    self.items[id] = nil
    for i, v in ipairs(self.order) do
        if v == id then
            table.remove(self.order, i)
            break
        end
    end
    local prefix = "w_" .. id
    local n = #prefix
    for k in pairs(self.pool.bank) do
        if k:sub(1, n) == prefix then
            self.pool:hide(k)
        end
    end
    return true
end

function World:clear()
    for id in pairs(self.items) do
        self:remove(id)
    end
    self.items = {}
    self.order = {}
    self.pool:reset()
    return self
end

function World:get(id)
    return self.items[tostring(id)]
end

function World:has(id)
    return self.items[tostring(id)] ~= nil
end

function World:enable(id, value)
    local item = self.items[tostring(id)]
    if item then
        item.on = value ~= false
    end
    return self
end

function World:set(id, patch)
    local item = self.items[tostring(id)]
    if not item then
        return nil
    end
    if type(patch) == "table" then
        merge(item, patch)
    end
    return item
end

function World:setPath(id, path, value)
    local item = self.items[tostring(id)]
    if not item then
        return nil
    end
    return pathSet(item, path, value)
end

function World:getPath(id, path)
    local item = self.items[tostring(id)]
    if not item then
        return nil
    end
    return pathGet(item, path)
end

local function resolvePosition(spec)
    local src = spec.get or spec.pos
    local value = src
    if type(src) == "function" then
        local ok, result = pcall(src)
        if not ok then
            return nil
        end
        value = result
    end
    if typeof(value) == "Vector3" then
        return value
    end
    if typeof(value) == "CFrame" then
        return value.Position, value
    end
    if typeof(value) == "Instance" then
        if value:IsA("BasePart") then
            return value.Position, value.CFrame
        end
        if value:IsA("Model") then
            local ok, pivot = pcall(function() return value:GetPivot() end)
            if ok and pivot then
                return pivot.Position, pivot
            end
        end
    end
    return nil
end

function World:_drawItem(id, spec)
    if spec.on == false then
        return
    end
    local cam = self.cam
    if not cam then
        return
    end

    if spec.kind == "path" or spec.kind == "trail" then
        local src = spec.points or spec.get
        local list = src
        if type(src) == "function" then
            local ok, result = pcall(src)
            if not ok then
                return
            end
            list = result
        end
        if type(list) ~= "table" or #list < 2 then
            return
        end
        spec._points = list
        spec._dist = (list[1] - cam.CFrame.Position).Magnitude
    elseif spec.kind == "beam" then
        local a = resolvePosition(spec)
        local bSpec = { get = spec.get2 or spec.pos2 }
        local b = resolvePosition(bSpec)
        if not a or not b then
            return
        end
        spec._pos, spec._pos2 = a, b
        spec._dist = (a - cam.CFrame.Position).Magnitude
    else
        local pos, frame = resolvePosition(spec)
        if not pos then
            return
        end
        if spec.offset then
            pos = pos + spec.offset
            if frame then
                frame = frame + spec.offset
            end
        end
        spec._pos = pos
        spec._cframe = spec.cframe ~= false and frame or nil
        spec._dist = (pos - cam.CFrame.Position).Magnitude
    end

    if spec.maxDist and spec.maxDist > 0 and spec._dist and spec._dist > spec.maxDist then
        self.stats.culled = self.stats.culled + 1
        return
    end

    if spec.kind == "text" then
        local t = spec.text
        if type(t) == "function" then
            local ok, result = pcall(t)
            t = ok and result or ""
        end
        spec._text = t
    end

    if spec.kind == "orbit" and type(spec.angle) == "function" then
        local ok, result = pcall(spec.angle)
        spec._angle = ok and result or nil
    elseif spec.kind == "orbit" then
        spec._angle = spec.angle
    end

    local ok, err = pcall(Shapes[spec.kind], self, "w_" .. id, spec)
    if not ok then
        spec.on = false
        warn("[EasyWorld] shape '" .. tostring(id) .. "' disabled: " .. tostring(err))
        return
    end

    self.stats.drawn = self.stats.drawn + 1

    if spec.label and spec._pos then
        local text = spec.label
        if type(text) == "function" then
            local okL, result = pcall(text)
            text = okL and result or nil
        end
        if type(text) == "string" and text ~= "" then
            local x, y, d = self:project(spec._pos)
            if d > 0 then
                self.pool:txt("w_" .. id .. "_lb", text, x, y + (spec.labelOffset or -14), spec.labelSize or 12, spec.col2 or spec.col, true, true, self:_alpha(spec, spec._dist, d), (spec.z or 0) + 2)
            end
        end
    end
end

function World:tick(dt)
    self.dt = dt or (1 / 60)
    self.t = self.t + self.dt
    self.cam = self.cam or Workspace.CurrentCamera
    local pool = self.pool
    pool:begin()
    self.stats.drawn, self.stats.culled, self.stats.segs = 0, 0, 0

    if self.enabled then
        for _, id in ipairs(self.order) do
            local spec = self.items[id]
            if spec then
                pool.zbias = (spec.priority or 0) * 100
                self:_drawItem(id, spec)
                if self.stats.segs > (self.cfg.maxSegs or 12000) then
                    break
                end
            end
        end
    end

    pool.zbias = 0
    pool:finish()
    pool:prune(self.cfg.pruneAge)
    self.stats.pool = pool.size
end

function World:start()
    if self.running then
        return self
    end
    self.running = true
    self.conn = RunService.RenderStepped:Connect(function(dt)
        local ok, err = pcall(self.tick, self, dt)
        if not ok and not self._warned then
            self._warned = true
            warn("[EasyWorld] tick error: " .. tostring(err))
        end
    end)
    return self
end

function World:stop()
    self.running = false
    if self.conn then
        pcall(function() self.conn:Disconnect() end)
        self.conn = nil
    end
    self.pool:reset()
    return self
end

function World:on(value)
    self.enabled = value ~= false
    if not self.enabled then
        self.pool:reset()
    end
    return self
end

function World:toggle()
    self:on(not self.enabled)
    return self.enabled
end

function World:destroy()
    self:stop()
    if self._camConn then
        pcall(function() self._camConn:Disconnect() end)
        self._camConn = nil
    end
    self.pool:nuke()
    self.items = {}
    self.order = {}
    if Runtime.world == self then
        Runtime.world = nil
    end
end

function World.DestroyAll()
    if Runtime.world and type(Runtime.world.destroy) == "function" then
        pcall(function() Runtime.world:destroy() end)
    end
    Runtime.world = nil
end

function World:ring(id, spec)
    spec = spec or {}
    spec.kind = "ring"
    return self:add(id, spec)
end

function World:sphere(id, spec)
    spec = spec or {}
    spec.kind = "sphere"
    return self:add(id, spec)
end

function World:box(id, spec)
    spec = spec or {}
    spec.kind = "box"
    return self:add(id, spec)
end

function World:orbit(id, spec)
    spec = spec or {}
    spec.kind = "orbit"
    return self:add(id, spec)
end

function World:beam(id, spec)
    spec = spec or {}
    spec.kind = "beam"
    return self:add(id, spec)
end

function World:path(id, spec)
    spec = spec or {}
    spec.kind = "path"
    return self:add(id, spec)
end

function World:cylinder(id, spec)
    spec = spec or {}
    spec.kind = "cylinder"
    return self:add(id, spec)
end

function World:disc(id, spec)
    spec = spec or {}
    spec.kind = "disc"
    return self:add(id, spec)
end

function World:marker(id, spec)
    spec = spec or {}
    spec.kind = "marker"
    return self:add(id, spec)
end

function World:arc(id, spec)
    spec = spec or {}
    spec.kind = "arc"
    return self:add(id, spec)
end

function World:label(id, spec)
    spec = spec or {}
    spec.kind = "text"
    return self:add(id, spec)
end

function World:group(prefix, list)
    local made = {}
    for suffix, spec in pairs(list) do
        made[suffix] = self:add(prefix .. "." .. suffix, spec)
    end
    return made
end

function World:removeGroup(prefix)
    local lead = prefix .. "."
    local n = #lead
    local doomed = {}
    for id in pairs(self.items) do
        if id:sub(1, n) == lead then
            doomed[#doomed + 1] = id
        end
    end
    for _, id in ipairs(doomed) do
        self:remove(id)
    end
    return #doomed
end

function World:getStats()
    return {
        items = #self.order,
        drawn = self.stats.drawn,
        culled = self.stats.culled,
        segments = self.stats.segs,
        pool = self.stats.pool,
        running = self.running,
        enabled = self.enabled,
    }
end

local PRESETS = {
    clean = { glow = false, w = 1.5, a = 0.9, pulse = false, depthFade = true },
    neon = { glow = true, glowLayers = 3, glowGain = 0.35, glowSpread = 3.5, w = 2, a = 1, pulse = false },
    pulse = { glow = true, glowLayers = 2, pulse = true, pulseRate = 2.4, pulseDepth = 0.4, w = 2.5 },
    ghost = { glow = false, w = 1, a = 0.45, depthFade = true, depthFadeGain = 0.9 },
    heavy = { glow = true, glowLayers = 4, glowGain = 0.4, glowSpread = 5, w = 3.5, a = 1 },
}

function World:preset(id, name)
    local p = PRESETS[name]
    if not p then
        return false
    end
    if id then
        return self:set(id, clone(p)) ~= nil
    end
    for _, spec in pairs(self.items) do
        merge(spec, clone(p))
    end
    return true
end

World.Presets = PRESETS
World.Shapes = Shapes

World.Toolkit = {
    version = World.ver,
    clone = clone,
    merge = merge,
    fill = fill,
    pathGet = pathGet,
    pathSet = pathSet,
    basis = basisFromNormal,
    normalFromTilt = tiltNormal,
    shapeDefaults = SHAPE_DEFAULTS,
    presets = PRESETS,
}

function World.Toolkit.quick(opt)
    opt = opt or {}
    local inst = World.new(opt)
    inst:start()
    return inst
end

return World
