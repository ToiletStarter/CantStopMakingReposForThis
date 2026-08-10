local RunService = game:GetService("RunService")

local GENV = (getgenv and getgenv()) or shared or _G

local EasySignals = {}
EasySignals.__index = EasySignals
EasySignals.version = "1.0.0"

local function callable(value)
    return type(value) == "function"
end

function EasySignals.new(options)
    options = type(options) == "table" and options or {}
    local self = setmetatable({}, EasySignals)
    self.connections = {}
    self.cleaners = {}
    self.jobs = {}
    self.tags = {}
    self.dead = false
    self.clock = options.clock or os.clock
    return self
end

function EasySignals:track(value, tag)
    if self.dead or value == nil then
        return value
    end
    local record = { value = value, tag = tag or "connection" }
    self.connections[#self.connections + 1] = record
    return value
end

function EasySignals:cleanupWith(fn, tag)
    if callable(fn) then
        self.cleaners[#self.cleaners + 1] = { fn = fn, tag = tag or "cleanup" }
    end
    return fn
end

function EasySignals:bind(signal, fn, tag)
    if self.dead or signal == nil or not callable(fn) or not callable(signal.Connect) then
        return nil
    end
    local ok, connection = pcall(function()
        return signal:Connect(function(...)
            if self.dead then
                return
            end
            local pass, err = pcall(fn, ...)
            if not pass and callable(self.onError) then
                pcall(self.onError, err, tag or "signal")
            end
        end)
    end)
    if ok then
        return self:track(connection, tag or "signal")
    end
    if callable(self.onError) then
        pcall(self.onError, connection, tag or "signal")
    end
    return nil
end

function EasySignals:once(signal, fn, tag)
    local connection
    connection = self:bind(signal, function(...)
        if connection then
            pcall(function() connection:Disconnect() end)
        end
        fn(...)
    end, tag or "once")
    return connection
end

function EasySignals:every(name, interval, fn)
    name = tostring(name or (#self.jobs + 1))
    interval = tonumber(interval) or 1
    if interval < 0.03 then
        interval = 0.03
    end
    if not callable(fn) then
        return nil
    end
    local job = { name = name, interval = interval, fn = fn, last = 0, running = true }
    self.jobs[name] = job
    if not self._heartbeat then
        self._heartbeat = self:bind(RunService.Heartbeat, function()
            self:_step()
        end, "heartbeat")
    end
    return function()
        job.running = false
        self.jobs[name] = nil
    end
end

function EasySignals:throttle(name, interval, fn)
    name = tostring(name or "throttle")
    interval = tonumber(interval) or 1
    return function(...)
        local now = self.clock()
        local last = self.tags[name] or 0
        if now - last < interval then
            return false
        end
        self.tags[name] = now
        return fn(...)
    end
end

function EasySignals:debounce(name, interval, fn)
    name = tostring(name or "debounce")
    interval = tonumber(interval) or 1
    return function(...)
        local token = {}
        self.tags[name] = token
        local args = table.pack(...)
        task.delay(interval, function()
            if self.dead or self.tags[name] ~= token then
                return
            end
            fn(table.unpack(args, 1, args.n))
        end)
    end
end

function EasySignals:_step()
    if self.dead then
        return
    end
    local now = self.clock()
    for name, job in pairs(self.jobs) do
        if not job.running then
            self.jobs[name] = nil
        elseif now - job.last >= job.interval then
            job.last = now
            local ok, err = pcall(job.fn, now)
            if not ok and callable(self.onError) then
                pcall(self.onError, err, job.name)
            end
        end
    end
end

function EasySignals:count()
    local n = 0
    for _ in pairs(self.jobs) do
        n = n + 1
    end
    return { connections = #self.connections, cleaners = #self.cleaners, jobs = n, dead = self.dead }
end

function EasySignals:cleanup()
    if self.dead then
        return false
    end
    self.dead = true
    for _, record in ipairs(self.connections) do
        local value = record.value
        if value then
            pcall(function()
                if callable(value.Disconnect) then
                    value:Disconnect()
                elseif callable(value.disconnect) then
                    value:disconnect()
                elseif callable(value.Destroy) then
                    value:Destroy()
                elseif callable(value.destroy) then
                    value:destroy()
                end
            end)
        end
    end
    for _, record in ipairs(self.cleaners) do
        pcall(record.fn)
    end
    self.connections = {}
    self.cleaners = {}
    self.jobs = {}
    self.tags = {}
    return true
end

EasySignals.destroy = EasySignals.cleanup
EasySignals.Destroy = EasySignals.cleanup

function EasySignals.quick(options)
    return EasySignals.new(options)
end

local Stack = GENV.__EASYSTACK or GENV.__EASY_STACK
if type(Stack) == "table" and type(Stack.register) == "function" then
    Stack.register("signals.library", EasySignals)
end

return EasySignals
