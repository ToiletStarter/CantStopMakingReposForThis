local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")

local GENV = (getgenv and getgenv()) or shared or _G

local Stats = {}
Stats.__index = Stats
Stats.version = "1.0.0"

local function kind(value)
    local ok, result = pcall(function()
        return typeof(value)
    end)
    if ok and result then
        return result
    end
    return type(value)
end

local function round(value, places)
    local scale = 10 ^ (places or 2)
    return math.floor((tonumber(value) or 0) * scale + 0.5) / scale
end

local function vector(value)
    if kind(value) ~= "Vector3" then
        return nil
    end
    return { x = round(value.X), y = round(value.Y), z = round(value.Z) }
end

local function localPlayerStats()
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    local leaderstats = {}
    if lp then
        local folder = lp:FindFirstChild("leaderstats")
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                local ok, value = pcall(function()
                    return child.Value
                end)
                if ok then
                    leaderstats[child.Name] = value
                end
            end
        end
    end
    return {
        name = lp and lp.Name or "",
        userId = lp and lp.UserId or 0,
        team = lp and lp.Team and lp.Team.Name or nil,
        health = hum and round(hum.Health) or nil,
        maxHealth = hum and round(hum.MaxHealth) or nil,
        state = hum and tostring(hum:GetState()) or nil,
        position = root and vector(root.Position) or nil,
        leaderstats = leaderstats,
    }
end

local function memoryStats()
    local out = {}
    pcall(function()
        out.dataModelMb = round(StatsService.DataModelMemoryUsageMb, 2)
    end)
    pcall(function()
        out.instanceCount = #game:GetDescendants()
    end)
    return out
end

function Stats.new(options)
    options = type(options) == "table" and options or {}
    local self = setmetatable({}, Stats)
    self.providers = {}
    self.order = {}
    self.errors = {}
    self.started = os.clock()
    self.frames = 0
    self.lastFpsAt = os.clock()
    self.fps = 0
    self.maxProviderMs = options.maxProviderMs or 25
    self.includeBuiltins = options.builtins ~= false
    self.connection = nil
    if self.includeBuiltins then
        self:register("runtime", function()
            return {
                uptime = round(os.clock() - self.started, 2),
                fps = self.fps,
                players = #Players:GetPlayers(),
                placeId = game.PlaceId,
                gameId = game.GameId,
                jobId = game.JobId,
            }
        end)
        self:register("localPlayer", localPlayerStats)
        self:register("memory", memoryStats)
    end
    return self
end

function Stats:start()
    if self.connection then
        return self
    end
    self.connection = RunService.Heartbeat:Connect(function()
        self.frames = self.frames + 1
        local now = os.clock()
        local elapsed = now - self.lastFpsAt
        if elapsed >= 0.45 then
            self.fps = round(self.frames / elapsed, 1)
            self.frames = 0
            self.lastFpsAt = now
        end
    end)
    return self
end

function Stats:register(name, provider)
    if type(provider) ~= "function" then
        return nil
    end
    name = tostring(name)
    if not self.providers[name] then
        self.order[#self.order + 1] = name
    end
    self.providers[name] = provider
    return provider
end

function Stats:unregister(name)
    name = tostring(name)
    self.providers[name] = nil
    for i = #self.order, 1, -1 do
        if self.order[i] == name then
            table.remove(self.order, i)
        end
    end
end

function Stats:snapshot()
    local out = {
        version = Stats.version,
        t = os.clock(),
        sources = {},
        errors = {},
    }
    for _, name in ipairs(self.order) do
        local provider = self.providers[name]
        if provider then
            local start = os.clock()
            local ok, value = pcall(provider)
            local ms = math.floor((os.clock() - start) * 100000 + 0.5) / 100
            if ok then
                out.sources[name] = value
                if ms > self.maxProviderMs then
                    out.errors[#out.errors + 1] = { source = name, error = "slow provider", ms = ms }
                end
            else
                local err = tostring(value)
                self.errors[name] = err
                out.errors[#out.errors + 1] = { source = name, error = err, ms = ms }
            end
        end
    end
    return out
end

function Stats:report()
    local snap = self:snapshot()
    local rows = { "EasyStats " .. Stats.version }
    for _, name in ipairs(self.order) do
        local value = snap.sources[name]
        rows[#rows + 1] = string.format("  %-18s %s", name, value ~= nil and "ok" or "missing")
    end
    for _, err in ipairs(snap.errors) do
        rows[#rows + 1] = string.format("  %-18s %s", err.source, err.error)
    end
    return table.concat(rows, "\n")
end

function Stats:destroy()
    if self.connection then
        pcall(function() self.connection:Disconnect() end)
    end
    self.connection = nil
    self.providers = {}
    self.order = {}
end

Stats.Destroy = Stats.destroy

function Stats.quick(options)
    local self = Stats.new(options)
    self:start()
    return self
end

local Stack = GENV.__EASYSTACK or GENV.__EASY_STACK
if type(Stack) == "table" and type(Stack.register) == "function" then
    Stack.register("stats.library", Stats)
end

return Stats
