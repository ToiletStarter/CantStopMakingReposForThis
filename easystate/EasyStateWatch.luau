local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local GENV = (getgenv and getgenv()) or shared or _G

local StateWatch = {}
StateWatch.__index = StateWatch
StateWatch.version = "1.1.0"

local VALUE_CLASSES = {
    BoolValue = true,
    BrickColorValue = true,
    CFrameValue = true,
    Color3Value = true,
    IntValue = true,
    NumberValue = true,
    ObjectValue = true,
    RayValue = true,
    StringValue = true,
    Vector3Value = true,
}

local function kind(value)
    local ok, result = pcall(function()
        return typeof(value)
    end)
    if ok and result then
        return result
    end
    return type(value)
end

local function rounded(value)
    return math.floor((tonumber(value) or 0) * 100 + 0.5) / 100
end

local function compact(value)
    local tv = type(value)
    if tv == "nil" or tv == "boolean" or tv == "number" or tv == "string" then
        return value
    end
    local tk = kind(value)
    if tk == "Vector3" then
        return { x = rounded(value.X), y = rounded(value.Y), z = rounded(value.Z) }
    end
    if tk == "Vector2" then
        return { x = rounded(value.X), y = rounded(value.Y) }
    end
    if tk == "Color3" then
        return { r = rounded(value.R), g = rounded(value.G), b = rounded(value.B) }
    end
    if tk == "CFrame" then
        return compact(value.Position)
    end
    if tk == "Instance" then
        local out = {}
        pcall(function() out.name = value.Name end)
        pcall(function() out.class = value.ClassName end)
        pcall(function() out.path = value:GetFullName() end)
        return out
    end
    return tostring(value)
end

local function encode(value)
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(value)
    end)
    if ok then
        return encoded
    end
    return tostring(value)
end

local function pathOf(obj)
    local ok, path = pcall(function()
        return obj:GetFullName()
    end)
    if ok and path then
        return path
    end
    return tostring(obj)
end

local function attributesOf(obj, maxAttributes)
    local out = {}
    local count = 0
    local ok, attrs = pcall(function()
        return obj:GetAttributes()
    end)
    if ok and type(attrs) == "table" then
        for k, v in pairs(attrs) do
            count = count + 1
            if count > maxAttributes then
                out.__truncated = true
                break
            end
            out[k] = compact(v)
        end
    end
    return out, count
end

local function valueOf(obj)
    if VALUE_CLASSES[obj.ClassName] then
        local ok, value = pcall(function()
            return obj.Value
        end)
        if ok then
            return compact(value)
        end
    end
    return nil
end

local function defaultRoots()
    local roots = { ReplicatedStorage, Workspace }
    if Players.LocalPlayer then
        roots[#roots + 1] = Players.LocalPlayer
    end
    local teamsOk, teams = pcall(function()
        return game:GetService("Teams")
    end)
    if teamsOk and teams then
        roots[#roots + 1] = teams
    end
    return roots
end

function StateWatch.new(options)
    options = type(options) == "table" and options or {}
    local self = setmetatable({}, StateWatch)
    self.roots = type(options.roots) == "table" and options.roots or defaultRoots()
    self.rootProvider = type(options.rootProvider) == "function" and options.rootProvider or nil
    self.maxDepth = options.maxDepth or 5
    self.maxNodes = options.maxNodes or 3000
    self.maxChanges = options.maxChanges or 200
    self.maxAttributes = options.maxAttributes or 40
    self.includeAttributes = options.attributes ~= false
    self.includeValues = options.values ~= false
    self.filter = options.filter
    self.last = nil
    self.lastDiff = nil
    self.lastCounters = {}
    self.connection = nil
    self.interval = options.interval or 2
    self.lastSample = 0
    return self
end

function StateWatch:setRoots(roots)
    if type(roots) == "table" then
        self.roots = roots
        self.last = nil
    end
    return self
end

function StateWatch:setRootProvider(provider)
    self.rootProvider = type(provider) == "function" and provider or nil
    self.last = nil
    return self
end

function StateWatch:resolvedRoots()
    if self.rootProvider then
        local ok, roots = pcall(self.rootProvider)
        if ok and type(roots) == "table" then
            return roots
        end
    end
    return self.roots
end

function StateWatch:record(obj)
    local attrs, attrCount = {}, 0
    if self.includeAttributes then
        attrs, attrCount = attributesOf(obj, self.maxAttributes)
    end
    local value = nil
    if self.includeValues then
        value = valueOf(obj)
    end
    local rec = {
        path = pathOf(obj),
        name = obj.Name,
        class = obj.ClassName,
        childCount = #obj:GetChildren(),
        attrCount = attrCount,
    }
    if next(attrs) ~= nil then
        rec.attributes = attrs
    end
    if value ~= nil then
        rec.value = value
    end
    rec.fingerprint = encode({ rec.class, rec.childCount, rec.attributes, rec.value })
    return rec
end

function StateWatch:scan()
    local map = {}
    local list = {}
    local counters = {
        nodes = 0,
        attributes = 0,
        values = 0,
        remotes = 0,
        folders = 0,
        players = #Players:GetPlayers(),
        truncated = false,
    }
    local function visit(obj, depth)
        if counters.nodes >= self.maxNodes then
            counters.truncated = true
            return
        end
        if self.filter and not self.filter(obj, depth) then
            return
        end
        counters.nodes = counters.nodes + 1
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            counters.remotes = counters.remotes + 1
        end
        if obj:IsA("Folder") then
            counters.folders = counters.folders + 1
        end
        local rec = self:record(obj)
        counters.attributes = counters.attributes + (rec.attrCount or 0)
        if rec.value ~= nil then
            counters.values = counters.values + 1
        end
        map[rec.path] = rec
        list[#list + 1] = rec
        if depth >= self.maxDepth then
            return
        end
        for _, child in ipairs(obj:GetChildren()) do
            visit(child, depth + 1)
            if counters.nodes >= self.maxNodes then
                counters.truncated = true
                break
            end
        end
    end
    for _, root in ipairs(self:resolvedRoots()) do
        if root then
            pcall(visit, root, 0)
        end
    end
    table.sort(list, function(a, b)
        return a.path < b.path
    end)
    return map, list, counters
end

function StateWatch:diff(current, previous)
    local out = { added = {}, removed = {}, changed = {}, addedCount = 0, removedCount = 0, changedCount = 0 }
    if not previous then
        out.initial = true
        return out
    end
    for path, rec in pairs(current) do
        local old = previous[path]
        if not old then
            out.addedCount = out.addedCount + 1
            if #out.added < self.maxChanges then
                out.added[#out.added + 1] = rec
            end
        elseif old.fingerprint ~= rec.fingerprint then
            out.changedCount = out.changedCount + 1
            if #out.changed < self.maxChanges then
                out.changed[#out.changed + 1] = { before = old, after = rec }
            end
        end
    end
    for path, rec in pairs(previous) do
        if not current[path] then
            out.removedCount = out.removedCount + 1
            if #out.removed < self.maxChanges then
                out.removed[#out.removed + 1] = rec
            end
        end
    end
    return out
end

function StateWatch:sample()
    local current, list, counters = self:scan()
    local diff = self:diff(current, self.last)
    diff.counters = counters
    diff.sample = list
    diff.t = os.clock()
    self.last = current
    self.lastDiff = diff
    self.lastCounters = counters
    return diff
end

function StateWatch:getStats()
    return {
        version = StateWatch.version,
        counters = self.lastCounters,
        last = self.lastDiff and {
            added = self.lastDiff.addedCount,
            removed = self.lastDiff.removedCount,
            changed = self.lastDiff.changedCount,
            initial = self.lastDiff.initial == true,
        } or nil,
    }
end

function StateWatch:start(callback)
    if self.connection then
        return self
    end
    self.connection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - self.lastSample < self.interval then
            return
        end
        self.lastSample = now
        local diff = self:sample()
        if type(callback) == "function" then
            pcall(callback, diff)
        end
    end)
    return self
end

function StateWatch:stop()
    if self.connection then
        pcall(function() self.connection:Disconnect() end)
    end
    self.connection = nil
end

function StateWatch:destroy()
    self:stop()
    self.last = nil
    self.lastDiff = nil
    self.rootProvider = nil
end

StateWatch.Destroy = StateWatch.destroy

function StateWatch.quick(options)
    local self = StateWatch.new(options)
    self:sample()
    return self
end

local Stack = GENV.__EASYSTACK or GENV.__EASY_STACK
if type(Stack) == "table" and type(Stack.register) == "function" then
    Stack.register("state.library", StateWatch)
end

return StateWatch
