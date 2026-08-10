local HttpService = game:GetService("HttpService")

local GENV = (getgenv and getgenv()) or shared or _G

local Report = {}
Report.__index = Report
Report.version = "1.0.0"

local SECRET_WORDS = {
    token = true,
    password = true,
    secret = true,
    key = true,
    authorization = true,
    cookie = true,
}

local function now()
    return os.clock()
end

local function shallowCopy(value)
    local out = {}
    for k, v in pairs(value) do
        out[k] = v
    end
    return out
end

local function redactKey(key)
    key = tostring(key or ""):lower()
    for word in pairs(SECRET_WORDS) do
        if key:find(word, 1, true) then
            return true
        end
    end
    return false
end

local function valueKind(value)
    local ok, kind = pcall(function()
        return typeof(value)
    end)
    if ok and kind then
        return kind
    end
    return type(value)
end

local function instanceSummary(value)
    local out = { type = "Instance" }
    pcall(function() out.name = value.Name end)
    pcall(function() out.class = value.ClassName end)
    pcall(function() out.path = value:GetFullName() end)
    return out
end

local function compact(value, depth, seen, options, key)
    options = options or {}
    depth = depth or 0
    seen = seen or {}
    if key and redactKey(key) then
        return "[REDACTED]"
    end
    local tv = type(value)
    if tv == "nil" or tv == "number" or tv == "boolean" then
        return value
    end
    if tv == "string" then
        local maxString = options.maxString or 180
        if #value > maxString then
            return value:sub(1, maxString) .. "..."
        end
        return value
    end
    local kind = valueKind(value)
    if kind == "Instance" then
        return instanceSummary(value)
    end
    if kind == "Vector3" then
        return { x = value.X, y = value.Y, z = value.Z }
    end
    if kind == "Vector2" then
        return { x = value.X, y = value.Y }
    end
    if kind == "Color3" then
        return { r = value.R, g = value.G, b = value.B }
    end
    if kind == "CFrame" then
        local p = value.Position
        return { x = p.X, y = p.Y, z = p.Z }
    end
    if tv ~= "table" then
        return tostring(value)
    end
    if seen[value] then
        return "[cycle]"
    end
    if depth >= (options.maxDepth or 4) then
        return "[table]"
    end
    seen[value] = true
    local out = {}
    local n = 0
    local maxItems = options.maxItems or 80
    for k, v in pairs(value) do
        n = n + 1
        if n > maxItems then
            out.__truncated = true
            break
        end
        local safeKey = type(k) == "string" and k or tostring(k)
        out[safeKey] = compact(v, depth + 1, seen, options, safeKey)
    end
    seen[value] = nil
    return out
end

function Report.new(options)
    options = type(options) == "table" and options or {}
    local self = setmetatable({}, Report)
    self.entries = {}
    self.maxEntries = options.maxEntries or 500
    self.maxBytes = options.maxBytes or 120000
    self.path = options.path
    self.verbose = options.verbose == true
    self.consolePrefix = options.consolePrefix or "[EasyReport]"
    self.clock = options.clock or now
    self.sinks = {}
    self.bytes = 0
    self.lastFlush = 0
    self.flushInterval = options.flushInterval or 5
    self.compactOptions = {
        maxDepth = options.maxDepth or 4,
        maxItems = options.maxItems or 80,
        maxString = options.maxString or 180,
    }
    return self
end

function Report:addSink(fn)
    if type(fn) == "function" then
        self.sinks[#self.sinks + 1] = fn
    end
    return fn
end

function Report:entry(level, section, message, data)
    local item = {
        t = self.clock(),
        level = tostring(level or "info"),
        section = tostring(section or "main"),
        message = tostring(message or ""),
    }
    if data ~= nil then
        item.data = compact(data, 0, {}, self.compactOptions)
    end
    local encoded = self:encode(item)
    self.entries[#self.entries + 1] = item
    self.bytes = self.bytes + #encoded
    while #self.entries > self.maxEntries do
        local old = table.remove(self.entries, 1)
        self.bytes = math.max(0, self.bytes - #self:encode(old))
    end
    while self.bytes > self.maxBytes and #self.entries > 1 do
        local old = table.remove(self.entries, 1)
        self.bytes = math.max(0, self.bytes - #self:encode(old))
    end
    for _, sink in ipairs(self.sinks) do
        pcall(sink, item)
    end
    if self.verbose then
        print(string.format("%s [%s][%s] %s", self.consolePrefix, item.level, item.section, item.message))
    end
    return item
end

function Report:info(section, message, data)
    return self:entry("info", section, message, data)
end

function Report:warn(section, message, data)
    return self:entry("warn", section, message, data)
end

function Report:error(section, message, data)
    return self:entry("error", section, message, data)
end

function Report:event(section, message, data)
    return self:entry("event", section, message, data)
end

function Report:recent(limit)
    limit = math.min(tonumber(limit) or #self.entries, #self.entries)
    local out = {}
    local first = math.max(1, #self.entries - limit + 1)
    for i = first, #self.entries do
        out[#out + 1] = shallowCopy(self.entries[i])
    end
    return out
end

function Report:clear()
    self.entries = {}
    self.bytes = 0
end

function Report:encode(value)
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(value)
    end)
    if ok then
        return encoded
    end
    return "{}"
end

function Report:snapshot(extra)
    local out = {
        version = Report.version,
        t = self.clock(),
        count = #self.entries,
        bytes = self.bytes,
        entries = self:recent(self.maxEntries),
    }
    if type(extra) == "table" then
        for k, v in pairs(extra) do
            out[k] = compact(v, 0, {}, self.compactOptions, k)
        end
    end
    return out
end

function Report:write(path, value)
    if type(writefile) ~= "function" then
        return false, "writefile unavailable"
    end
    path = path or self.path
    if not path or path == "" then
        return false, "path missing"
    end
    local folder = path:match("^(.+)/[^/]+$")
    if folder and type(makefolder) == "function" then
        local current = ""
        for part in folder:gmatch("[^/]+") do
            current = current == "" and part or current .. "/" .. part
            pcall(makefolder, current)
        end
    end
    local data = type(value) == "string" and value or self:encode(value)
    local ok, err = pcall(writefile, path, data)
    return ok, err
end

function Report:flush(path, extra)
    self.lastFlush = self.clock()
    return self:write(path or self.path, self:snapshot(extra))
end

function Report:flushDue(path, extra)
    if self.clock() - self.lastFlush < self.flushInterval then
        return false, "not due"
    end
    return self:flush(path, extra)
end

function Report:destroy()
    self.sinks = {}
end

Report.Destroy = Report.destroy

function Report.compact(value, options)
    return compact(value, 0, {}, options or {})
end

function Report.quick(options)
    return Report.new(options)
end

local Stack = GENV.__EASYSTACK or GENV.__EASY_STACK
if type(Stack) == "table" and type(Stack.register) == "function" then
    Stack.register("report.library", Report)
end

return Report
