local Noise = {}
Noise.__index = Noise
Noise.version = "1.2.0"

function Noise.new(options)
    options = type(options) == "table" and options or {}
    local self = setmetatable({}, Noise)
    self.event = options.event
    self.pingEvent = options.pingEvent
    self.threat = options.threat
    self.multiplier = tonumber(options.multiplier) or 90
    self.maxWeight = tonumber(options.maxWeight) or 3
    self.activeWindow = tonumber(options.activeWindow) or 0.8
    self.pulseDuration = tonumber(options.pulseDuration) or 0.8
    self.weight = 0
    self.pulseWeight = 0
    self.lastAt = 0
    self.pulseAt = 0
    self.lastSource = "unavailable"
    self.sourceCounts = {}
    self.connections = {}
    self.running = false
    self.lastSnapshot = nil
    return self
end

function Noise:setMultiplier(value)
    self.multiplier = math.max(0, tonumber(value) or self.multiplier)
    return self
end

function Noise:setThreat(threat)
    self.threat = threat
    return self
end

function Noise:setEvent(event)
    self.event = event
    return self
end

function Noise:setPingEvent(event)
    self.pingEvent = event
    return self
end

function Noise:setPulseDuration(value)
    self.pulseDuration = math.max(0.05, tonumber(value) or self.pulseDuration)
    return self
end

function Noise:setActiveWindow(value)
    self.activeWindow = math.max(0.05, tonumber(value) or self.activeWindow)
    return self
end

function Noise:_onWeight(value, source)
    value = tonumber(value) or 0
    self.weight = math.clamp(value, 0, self.maxWeight)
    self.lastAt = os.clock()
    self.lastSource = source or self.lastSource
    self.sourceCounts[self.lastSource] = (self.sourceCounts[self.lastSource] or 0) + 1
    if self.weight > 0 then
        self.pulseWeight = self.weight
        self.pulseAt = self.lastAt
    end
end

function Noise:_onSignal(source, ...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "number" then
            self:_onWeight(value, source)
            return
        end
    end
end

function Noise:_connect(event, signalName, source)
    if not event then
        return false
    end
    local ok, connection = pcall(function()
        local signal = event[signalName]
        if not signal then
            return nil
        end
        return signal:Connect(function(...)
            self:_onSignal(source, ...)
        end)
    end)
    if ok and connection then
        self.connections[#self.connections + 1] = connection
        return true
    end
    return false
end

function Noise:start()
    if #self.connections > 0 then
        self.running = true
        return self
    end
    self:_connect(self.event, "Event", "AudioMeter")
    self:_connect(self.pingEvent, "OnClientEvent", "GamePing")
    self.running = #self.connections > 0
    return self
end

function Noise:stop()
    self.running = false
    for _, connection in ipairs(self.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.connections = {}
    return self
end

function Noise:pulse(now)
    now = tonumber(now) or os.clock()
    local age = self.pulseAt > 0 and now - self.pulseAt or math.huge
    local active = age >= 0 and age <= self.pulseDuration and self.pulseWeight > 0
    local progress = active and math.clamp(age / self.pulseDuration, 0, 1) or 0
    local reach = self.pulseWeight * self.multiplier
    return {
        active = active,
        age = age,
        progress = progress,
        radius = reach * progress,
        reach = reach,
        alpha = active and (1 - progress) * 0.85 or 0,
        weight = self.pulseWeight,
        source = self.lastSource,
    }
end

function Noise:estimate(now)
    now = tonumber(now) or os.clock()
    local age = self.lastAt > 0 and now - self.lastAt or math.huge
    local active = age <= self.activeWindow and self.weight > 0
    local reach = self.weight * self.multiplier
    local inRange = 0
    local response = 0
    local records = {}
    if self.threat then
        records = self.threat:records()
        for _, record in ipairs(records) do
            local inside = active and record.distance and record.distance <= reach or false
            local responded = inside and (record.targeted or record.attacking) or false
            if inside then
                inRange = inRange + 1
            end
            if responded then
                response = response + 1
            end
        end
    end
    local puddle = self:pulse(now)
    local available = {}
    if self.event then
        available[#available + 1] = "AudioMeter"
    end
    if self.pingEvent then
        available[#available + 1] = "GamePing"
    end
    local snapshot = {
        version = Noise.version,
        running = self.running,
        active = active,
        age = age,
        weight = self.weight,
        pulseWeight = self.pulseWeight,
        maxWeight = self.maxWeight,
        multiplier = self.multiplier,
        estimatedReach = reach,
        monstersInEstimatedReach = inRange,
        inferredResponses = response,
        responseConfirmed = false,
        puddleActive = puddle.active,
        puddleProgress = puddle.progress,
        puddleRadius = puddle.radius,
        puddleReach = puddle.reach,
        puddleAlpha = puddle.alpha,
        source = self.lastSource,
        availableSources = available,
        sourceCounts = self.sourceCounts,
    }
    self.lastSnapshot = snapshot
    return snapshot
end

function Noise:snapshot()
    return self:estimate()
end

function Noise:destroy()
    self:stop()
    self.event = nil
    self.pingEvent = nil
    self.threat = nil
    self.sourceCounts = {}
    self.lastSnapshot = nil
end

Noise.Destroy = Noise.destroy

return Noise
