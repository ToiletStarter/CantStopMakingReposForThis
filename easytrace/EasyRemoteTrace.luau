local HttpService = game:GetService("HttpService")

local GENV = (getgenv and getgenv()) or shared or _G
GENV.__EASY_STACK = GENV.__EASY_STACK or {}
local Runtime = GENV.__EASY_STACK

local Trace = {}
Trace.__index = Trace
Trace.version = "1.0.0"

local METHODS = {
    FireServer = true,
    InvokeServer = true,
}

local REMOTE_CLASSES = {
    RemoteEvent = true,
    RemoteFunction = true,
    UnreliableRemoteEvent = true,
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

local function isRemote(value)
    if kind(value) ~= "Instance" then
        return false
    end
    return REMOTE_CLASSES[value.ClassName] == true
end

local function pathOf(value)
    local ok, path = pcall(function()
        return value:GetFullName()
    end)
    if ok and path then
        return path
    end
    local name = ""
    pcall(function() name = value.Name end)
    return name
end

local function compact(value, depth, seen, allowRaw)
    depth = depth or 0
    seen = seen or {}
    local tv = type(value)
    if tv == "nil" or tv == "number" or tv == "boolean" then
        return value
    end
    if tv == "string" then
        if not allowRaw then
            return "string(" .. tostring(#value) .. ")"
        end
        if #value > 160 then
            return value:sub(1, 160) .. "..."
        end
        return value
    end
    local tk = kind(value)
    if tk == "Instance" then
        return { type = "Instance", class = value.ClassName, name = value.Name, path = pathOf(value) }
    end
    if tk == "Vector3" then
        return { type = "Vector3", x = value.X, y = value.Y, z = value.Z }
    end
    if tk == "Vector2" then
        return { type = "Vector2", x = value.X, y = value.Y }
    end
    if tk == "Color3" then
        return { type = "Color3", r = value.R, g = value.G, b = value.B }
    end
    if tk == "CFrame" then
        local p = value.Position
        return { type = "CFrame", x = p.X, y = p.Y, z = p.Z }
    end
    if tv ~= "table" then
        return tostring(value)
    end
    if not allowRaw then
        return "table"
    end
    if seen[value] then
        return "[cycle]"
    end
    if depth >= 2 then
        return "[table]"
    end
    seen[value] = true
    local out = {}
    local n = 0
    for k, v in pairs(value) do
        n = n + 1
        if n > 20 then
            out.__truncated = true
            break
        end
        out[type(k) == "string" and k or tostring(k)] = compact(v, depth + 1, seen, allowRaw)
    end
    seen[value] = nil
    return out
end

local function argTypes(argc, ...)
    local out = {}
    for i = 1, argc do
        out[i] = kind(select(i, ...))
    end
    return out
end

local function argSummary(argc, allowRaw, ...)
    local out = {}
    for i = 1, math.min(argc, 12) do
        out[i] = compact(select(i, ...), 0, {}, allowRaw)
    end
    if argc > 12 then
        out.__truncated = true
    end
    return out
end

function Trace.new(options)
    options = type(options) == "table" and options or {}
    local previous = Runtime.remoteTrace
    if previous and previous ~= Trace and type(previous.stop) == "function" then
        pcall(function() previous:stop() end)
    end
    local self = setmetatable({}, Trace)
    self.entries = {}
    self.maxEntries = options.maxEntries or 300
    self.mode = options.mode or "metadata"
    self.allowRaw = options.allowRaw == true
    self.includeOwn = options.includeOwn == true
    self.enabled = false
    self.hooked = false
    self.oldNamecall = nil
    self.listeners = {}
    self.counts = {}
    self.denied = 0
    self.filter = options.filter
    self.onError = options.onError
    Runtime.remoteTrace = self
    return self
end

function Trace:on(event, fn)
    event = tostring(event or "call")
    if type(fn) ~= "function" then
        return nil
    end
    self.listeners[event] = self.listeners[event] or {}
    self.listeners[event][#self.listeners[event] + 1] = fn
    return fn
end

function Trace:emit(event, data)
    local listeners = self.listeners[event]
    if not listeners then
        return
    end
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, data)
        if not ok and type(self.onError) == "function" then
            pcall(self.onError, err, event)
        end
    end
end

function Trace:push(remote, method, argc, ...)
    local path = pathOf(remote)
    local entry = {
        t = os.clock(),
        path = path,
        name = remote.Name,
        class = remote.ClassName,
        method = method,
        argc = argc,
        argTypes = argTypes(argc, ...),
    }
    if self.mode == "summary" then
        entry.args = argSummary(argc, false, ...)
    elseif self.mode == "raw" and self.allowRaw then
        entry.args = argSummary(argc, true, ...)
    end
    if self.filter and not self.filter(entry, remote, ...) then
        return nil
    end
    self.entries[#self.entries + 1] = entry
    while #self.entries > self.maxEntries do
        table.remove(self.entries, 1)
    end
    local key = path .. ":" .. method
    self.counts[key] = (self.counts[key] or 0) + 1
    self:emit("call", entry)
    return entry
end

function Trace:start()
    if self.enabled then
        return true
    end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        return false, "hookmetamethod/getnamecallmethod unavailable"
    end
    self.enabled = true
    if self.hooked then
        return true
    end
    local trace = self
    local closure = function(remote, ...)
        local args = table.pack(...)
        local method = getnamecallmethod()
        if trace.enabled and METHODS[method] and isRemote(remote) then
            local own = false
            if type(checkcaller) == "function" then
                local ok, value = pcall(checkcaller)
                own = ok and value == true
            end
            if trace.includeOwn or not own then
                local argc = args.n
                pcall(function()
                    trace:push(remote, method, argc, table.unpack(args, 1, args.n))
                end)
            end
        end
        return trace.oldNamecall(remote, table.unpack(args, 1, args.n))
    end
    if type(newcclosure) == "function" then
        closure = newcclosure(closure)
    end
    self.oldNamecall = hookmetamethod(game, "__namecall", closure)
    self.hooked = true
    return true
end

function Trace:stop()
    self.enabled = false
    return true
end

function Trace:clear()
    self.entries = {}
    self.counts = {}
end

function Trace:setFilter(fn)
    self.filter = type(fn) == "function" and fn or nil
end

function Trace:getRecent(limit)
    limit = math.min(tonumber(limit) or #self.entries, #self.entries)
    local out = {}
    local first = math.max(1, #self.entries - limit + 1)
    for i = first, #self.entries do
        out[#out + 1] = self.entries[i]
    end
    return out
end

function Trace:getStats()
    local hot = {}
    for key, count in pairs(self.counts) do
        hot[#hot + 1] = { key = key, count = count }
    end
    table.sort(hot, function(a, b)
        if a.count == b.count then
            return a.key < b.key
        end
        return a.count > b.count
    end)
    while #hot > 20 do
        table.remove(hot)
    end
    return {
        version = Trace.version,
        enabled = self.enabled,
        hooked = self.hooked,
        mode = self.mode,
        entries = #self.entries,
        hot = hot,
    }
end

function Trace:encodeRecent(limit)
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(self:getRecent(limit))
    end)
    if ok then
        return encoded
    end
    return "[]"
end

function Trace:destroy()
    self:stop()
    self.listeners = {}
    self.entries = {}
    self.counts = {}
end

Trace.Destroy = Trace.destroy

function Trace.quick(options)
    local self = Trace.new(options)
    self:start()
    return self
end

local Stack = GENV.__EASYSTACK or GENV.__EASY_STACK
if type(Stack) == "table" and type(Stack.register) == "function" then
    Stack.register("trace.library", Trace)
end

return Trace
