local floor, max = math.floor, math.max
local clock = os.clock

local GENV = (type(getgenv) == "function" and getgenv()) or shared or _G
GENV.__EASY_STACK = GENV.__EASY_STACK or {}
local Runtime = GENV.__EASY_STACK

local Budget = {}
Budget.__index = Budget
Budget.ver = "1.0.0"

local DEFAULT_WINDOW = 60

local function newBucket(limit, window, headroom, exempt, label)
    return {
        limit = limit,
        window = window or DEFAULT_WINDOW,
        headroom = headroom,
        exempt = exempt and true or false,
        label = label,
        stamps = {},
        head = 1,
        spent = 0,
        denied = 0,
        peak = 0,
    }
end

function Budget.new(opt)
    opt = opt or {}
    local previous = Runtime.budget
    if previous and previous ~= Budget and type(previous.destroy) == "function" then
        pcall(function() previous:destroy() end)
    end

    local self = setmetatable({}, Budget)
    self.buckets = {}
    self.defaultLimit = opt.defaultLimit or 300
    self.defaultWindow = opt.defaultWindow or DEFAULT_WINDOW
    self.headroom = opt.headroom or 0.8
    self.onDenied = opt.onDenied
    self.enabled = opt.on ~= false
    self.strict = opt.strict ~= false

    Runtime.budget = self
    return self
end

function Budget:define(name, limit, opt)
    opt = opt or {}
    name = tostring(name)
    local b = newBucket(
        limit or self.defaultLimit,
        opt.window or self.defaultWindow,
        opt.headroom or self.headroom,
        opt.exempt,
        opt.label or name
    )
    self.buckets[name] = b
    return b
end

function Budget:bucket(name)
    name = tostring(name)
    local b = self.buckets[name]
    if not b then
        b = self:define(name, self.defaultLimit, {})
    end
    return b
end

local function sweep(b, now)
    local cutoff = now - b.window
    local stamps = b.stamps
    local head = b.head
    local n = #stamps
    while head <= n and stamps[head] < cutoff do
        stamps[head] = nil
        head = head + 1
    end
    if head > n then
        b.stamps = {}
        b.head = 1
        return 0
    end
    if head > 64 then
        local moved = {}
        local k = 0
        for i = head, n do
            k = k + 1
            moved[k] = stamps[i]
        end
        b.stamps = moved
        b.head = 1
        return k
    end
    b.head = head
    return n - head + 1
end

function Budget:used(name)
    local b = self:bucket(name)
    return sweep(b, clock())
end

function Budget:capacity(name)
    local b = self:bucket(name)
    return floor(b.limit * b.headroom)
end

function Budget:remaining(name)
    local b = self:bucket(name)
    local used = sweep(b, clock())
    return max(0, floor(b.limit * b.headroom) - used)
end

function Budget:rate(name)
    local b = self:bucket(name)
    return (b.limit * b.headroom) / b.window
end

function Budget:interval(name)
    local r = self:rate(name)
    if r <= 0 then
        return math.huge
    end
    return 1 / r
end

function Budget:check(name)
    if not self.enabled then
        return true
    end
    local b = self:bucket(name)
    local used = sweep(b, clock())
    return used < floor(b.limit * b.headroom)
end

function Budget:consume(name, count)
    count = count or 1
    if not self.enabled then
        return true
    end
    local b = self:bucket(name)
    local now = clock()
    local used = sweep(b, now)
    local cap = floor(b.limit * b.headroom)

    if used + count > cap then
        b.denied = b.denied + 1
        if self.onDenied then
            pcall(self.onDenied, name, b, used, cap)
        end
        return false
    end

    local stamps = b.stamps
    local n = #stamps
    for i = 1, count do
        stamps[n + i] = now
    end
    b.spent = b.spent + count
    local total = used + count
    if total > b.peak then
        b.peak = total
    end
    return true
end

function Budget:guard(name, fn, ...)
    if not self:consume(name, 1) then
        return false
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        return false, err
    end
    return true, err
end

function Budget:wrap(name, fn)
    return function(...)
        if not self:consume(name, 1) then
            return nil
        end
        return fn(...)
    end
end

function Budget:setLimit(name, limit)
    local b = self:bucket(name)
    b.limit = limit
    return b
end

function Budget:setHeadroom(value)
    self.headroom = value
    for _, b in pairs(self.buckets) do
        b.headroom = value
    end
    return self
end

function Budget:isExempt(name)
    return self:bucket(name).exempt == true
end

function Budget:reset(name)
    if name then
        local b = self:bucket(name)
        b.stamps = {}
        b.head = 1
        return self
    end
    for _, b in pairs(self.buckets) do
        b.stamps = {}
        b.head = 1
    end
    return self
end

function Budget:stats(name)
    if name then
        local b = self:bucket(name)
        local used = sweep(b, clock())
        return {
            name = name,
            label = b.label,
            limit = b.limit,
            window = b.window,
            headroom = b.headroom,
            capacity = floor(b.limit * b.headroom),
            used = used,
            remaining = max(0, floor(b.limit * b.headroom) - used),
            perSecond = (b.limit * b.headroom) / b.window,
            exempt = b.exempt,
            spent = b.spent,
            denied = b.denied,
            peak = b.peak,
        }
    end
    local out = {}
    for key in pairs(self.buckets) do
        out[#out + 1] = self:stats(key)
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function Budget:report()
    local rows = self:stats()
    local lines = { "EasyBudget " .. Budget.ver }
    for _, s in ipairs(rows) do
        lines[#lines + 1] = string.format(
            "  %-24s %3d/%-3d  %.2f/s  denied=%d%s",
            s.name, s.used, s.capacity, s.perSecond, s.denied, s.exempt and "  [exempt]" or ""
        )
    end
    return table.concat(lines, "\n")
end

function Budget:on(value)
    self.enabled = value ~= false
    return self
end

function Budget:destroy()
    self.buckets = {}
    if Runtime.budget == self then
        Runtime.budget = nil
    end
end

function Budget.DestroyAll()
    if Runtime.budget and type(Runtime.budget.destroy) == "function" then
        pcall(function() Runtime.budget:destroy() end)
    end
    Runtime.budget = nil
end

local Pacer = {}
Pacer.__index = Pacer

function Budget:pacer(name, opt)
    opt = opt or {}
    local p = setmetatable({
        budget = self,
        name = name,
        last = 0,
        cursor = 0,
        minGap = opt.minGap,
        jitter = opt.jitter or 0,
    }, Pacer)
    return p
end

function Pacer:gap()
    local base = self.minGap or self.budget:interval(self.name)
    if self.jitter and self.jitter > 0 then
        base = base * (1 + (math.random() * 2 - 1) * self.jitter)
    end
    return base
end

function Pacer:ready()
    return (clock() - self.last) >= self:gap()
end

function Pacer:tryFire()
    if not self:ready() then
        return false
    end
    if not self.budget:consume(self.name, 1) then
        return false
    end
    self.last = clock()
    return true
end

function Pacer:next(list)
    local n = #list
    if n == 0 then
        return nil
    end
    self.cursor = (self.cursor % n) + 1
    return list[self.cursor], self.cursor
end

function Pacer:cycle(list)
    if not self:tryFire() then
        return nil
    end
    return self:next(list)
end

function Pacer:reset()
    self.last = 0
    self.cursor = 0
    return self
end

Budget.Pacer = Pacer

Budget.Presets = {
    bedwars = {
        SwordHit = { limit = 300, exempt = false },
        SwordSwingMiss = { limit = 1200, exempt = true },
        SwordChargeState = { limit = 300, exempt = true },
        ProjectileFire = { limit = 1200, exempt = false },
        ProjectileHit = { limit = 300, exempt = true },
        SetInvItem = { limit = 300, exempt = true },
        MomentumUpdate = { limit = 900, exempt = false },
        CannonLookVectorUpdate = { limit = 600, exempt = false },
        FrostyGunFire = { limit = 900, exempt = false },
        ElkKitMounted = { limit = 30, exempt = false },
        PlaceBlock = { limit = 300, exempt = false },
        BreakBlock = { limit = 300, exempt = false },
        DamageBlock = { limit = 300, exempt = false },
    },
}

function Budget:loadPreset(name)
    local preset = Budget.Presets[name]
    if not preset then
        return false
    end
    for remote, spec in pairs(preset) do
        self:define(remote, spec.limit, { exempt = spec.exempt, label = remote })
    end
    return true
end

Budget.Toolkit = {
    version = Budget.ver,
    presets = Budget.Presets,
}

function Budget.Toolkit.quick(presetName, opt)
    local inst = Budget.new(opt)
    if presetName then
        inst:loadPreset(presetName)
    end
    return inst
end

return Budget
