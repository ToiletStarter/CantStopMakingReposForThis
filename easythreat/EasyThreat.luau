local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Threat = {}
Threat.__index = Threat
Threat.version = "1.1.0"

local function child(root, name)
    if not root then
        return nil
    end
    local ok, value = pcall(function()
        return root:FindFirstChild(name)
    end)
    return ok and value or nil
end

local function rootOf(model)
    if not model then
        return nil
    end
    return child(model, "HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function valueOf(root, name)
    local object = child(root, name)
    if not object then
        return nil
    end
    local ok, value = pcall(function()
        return object.Value
    end)
    return ok and value or nil
end

local function boolOf(root, name)
    return valueOf(root, name) == true
end

local function targetMatches(value, localPlayer, localCharacter)
    if value == localPlayer or value == localCharacter then
        return true
    end
    if typeof(value) == "Instance" then
        return value == localPlayer or value == localCharacter
    end
    if type(value) == "string" then
        return value == localPlayer.Name or value == localPlayer.DisplayName
    end
    if type(value) == "number" then
        return value == localPlayer.UserId
    end
    return false
end

local function hasTarget(model, localPlayer, localCharacter)
    local names = {
        "Target",
        "TargetPlayer",
        "TargetCharacter",
        "TargetModel",
        "LockedTarget",
        "AggroTarget",
        "Chasing",
    }
    local values = child(model, "Values")
    for _, name in ipairs(names) do
        local object = child(values, name) or child(model, name)
        if object then
            local ok, value = pcall(function()
                return object.Value
            end)
            if ok and targetMatches(value, localPlayer, localCharacter) then
                return true
            end
        end
        local ok, value = pcall(function()
            return model:GetAttribute(name)
        end)
        if ok and targetMatches(value, localPlayer, localCharacter) then
            return true
        end
    end
    return false
end

local function recordId(model)
    local ok, id = pcall(function()
        return model:GetDebugId()
    end)
    if ok and id then
        return tostring(id)
    end
    return model:GetFullName()
end

local function vector(value)
    return {
        x = value.X,
        y = value.Y,
        z = value.Z,
    }
end

local function copyPoints(points)
    local out = {}
    for i, point in ipairs(points) do
        out[i] = point
    end
    return out
end

function Threat.new(options)
    options = type(options) == "table" and options or {}
    local self = setmetatable({}, Threat)
    self.source = options.source or function() return {} end
    self.localRoot = options.localRoot or function()
        local player = Players.LocalPlayer
        local character = player and player.Character
        return rootOf(character)
    end
    self.localPlayer = options.localPlayer or Players.LocalPlayer
    self.interval = tonumber(options.interval) or 0.2
    self.dangerRange = tonumber(options.dangerRange) or 200
    self.futureSteps = math.max(2, math.floor(tonumber(options.futureSteps or options.historyLimit) or 8))
    self.futureStepTime = math.max(0.05, tonumber(options.futureStepTime) or 0.25)
    self.recordsByModel = {}
    self.order = {}
    self.lastSample = 0
    self.connection = nil
    self.running = false
    return self
end

function Threat:setDangerRange(value)
    self.dangerRange = math.max(1, tonumber(value) or self.dangerRange)
    return self
end

function Threat:setHistoryLimit(value)
    self.futureSteps = math.max(2, math.floor(tonumber(value) or self.futureSteps))
    return self
end

function Threat:setFutureSteps(value)
    return self:setHistoryLimit(value)
end

function Threat:_list()
    local ok, value = pcall(self.source)
    if not ok or type(value) ~= "table" then
        return {}
    end
    return value
end

function Threat:_update(model, now, localRoot, localCharacter)
    if typeof(model) ~= "Instance" or not model.Parent then
        return nil
    end
    local root = rootOf(model)
    if not root then
        return nil
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local values = child(model, "Values")
    local position = root.Position
    local distance = localRoot and (position - localRoot.Position).Magnitude or nil
    local record = self.recordsByModel[model]
    if not record then
        record = {
            id = recordId(model),
            model = model,
            futurePath = {},
            lastPosition = nil,
            lastDistance = nil,
            lastTime = nil,
        }
        self.recordsByModel[model] = record
        self.order[#self.order + 1] = model
    end
    local deltaTime = record.lastTime and math.max(now - record.lastTime, 0.001) or nil
    local speed = record.lastPosition and (position - record.lastPosition).Magnitude / (deltaTime or 1) or 0
    local approaching = record.lastDistance and distance and distance < record.lastDistance - 0.25 or false
    local targeted = hasTarget(model, self.localPlayer, localCharacter)
    local attacking = boolOf(values, "Attacking") or boolOf(model, "Attacking")
    local acting = boolOf(values, "Acting") or boolOf(model, "Acting")
    local near = distance and distance <= self.dangerRange or false
    local aggro = targeted or attacking or (approaching and near)
    local status
    local confidence
    if targeted then
        status, confidence = "TARGETED", "direct"
    elseif attacking then
        status, confidence = "ATTACKING", "attack-state"
    elseif approaching and near then
        status, confidence = "APPROACHING", "inferred"
    elseif near then
        status, confidence = "NEAR", "proximity"
    elseif approaching then
        status, confidence = "CLOSING", "inferred"
    else
        status, confidence = "IDLE", "none"
    end
    local velocity = root.AssemblyLinearVelocity
    local moveInput = humanoid and humanoid.MoveDirection or Vector3.zero
    local hasMoveInput = moveInput.Magnitude > 0.05
    local moveDirection = velocity.Magnitude > 0.1 and velocity.Unit or (hasMoveInput and moveInput.Unit or Vector3.zero)
    local walkToPoint = humanoid and humanoid.WalkToPoint or Vector3.zero
    local walkDistance = (walkToPoint - position).Magnitude
    local prediction = velocity.Magnitude > 0.1 and "velocity" or (hasMoveInput and "move-direction" or "none")
    local stepSpeed = velocity.Magnitude
    if hasMoveInput then
        stepSpeed = math.max(stepSpeed, humanoid and humanoid.WalkSpeed or 0)
    end
    if hasMoveInput and walkDistance > 1 then
        moveDirection = (walkToPoint - position).Unit
        stepSpeed = math.max(stepSpeed, humanoid and humanoid.WalkSpeed or 0, 8)
        prediction = "walk-target"
    end
    local futurePath = {}
    for step = 0, self.futureSteps do
        futurePath[#futurePath + 1] = position + moveDirection * stepSpeed * self.futureStepTime * step
    end
    record.root = root
    record.name = model.Name
    record.health = humanoid and humanoid.Health or nil
    record.maxHealth = humanoid and humanoid.MaxHealth or nil
    record.position = position
    record.distance = distance
    record.speed = speed
    record.velocity = velocity
    record.moveDirection = moveDirection
    record.walkToPoint = walkToPoint
    record.prediction = prediction
    record.futurePath = futurePath
    record.approaching = approaching
    record.targeted = targeted
    record.attacking = attacking
    record.acting = acting
    record.near = near
    record.aggro = aggro
    record.status = status
    record.confidence = confidence
    record.lastDistance = distance
    record.lastPosition = position
    record.lastTime = now
    record.lastSeen = now
    return record
end

function Threat:sample(now)
    now = tonumber(now) or os.clock()
    if now - self.lastSample < self.interval and self.lastSample > 0 then
        return self:records()
    end
    self.lastSample = now
    local localRoot = self.localRoot()
    local localCharacter = localRoot and localRoot.Parent or nil
    local seen = {}
    for _, model in ipairs(self:_list()) do
        local record = self:_update(model, now, localRoot, localCharacter)
        if record then
            seen[model] = true
        end
    end
    for model, record in pairs(self.recordsByModel) do
        if not seen[model] or not model.Parent then
            self.recordsByModel[model] = nil
        end
    end
    local order = {}
    for _, model in ipairs(self.order) do
        if self.recordsByModel[model] then
            order[#order + 1] = model
        end
    end
    self.order = order
    table.sort(self.order, function(a, b)
        local A = self.recordsByModel[a]
        local B = self.recordsByModel[b]
        return (A.distance or math.huge) < (B.distance or math.huge)
    end)
    return self:records()
end

function Threat:records()
    local out = {}
    for _, model in ipairs(self.order) do
        local record = self.recordsByModel[model]
        if record then
            out[#out + 1] = record
        end
    end
    return out
end

function Threat:get(model)
    return self.recordsByModel[model]
end

function Threat:paths()
    local out = {}
    for _, record in ipairs(self:records()) do
        out[#out + 1] = {
            id = record.id,
            name = record.name,
            status = record.status,
            prediction = record.prediction,
            points = copyPoints(record.futurePath),
        }
    end
    return out
end

function Threat:snapshot()
    local records = {}
    for _, record in ipairs(self:records()) do
        records[#records + 1] = {
            id = record.id,
            name = record.name,
            status = record.status,
            confidence = record.confidence,
            aggro = record.aggro,
            targeted = record.targeted,
            attacking = record.attacking,
            acting = record.acting,
            near = record.near,
            approaching = record.approaching,
            distance = record.distance,
            speed = record.speed,
            prediction = record.prediction,
            futurePoints = #record.futurePath,
            health = record.health,
            maxHealth = record.maxHealth,
            position = record.position and vector(record.position) or nil,
        }
    end
    return {
        version = Threat.version,
        dangerRange = self.dangerRange,
        futureSteps = self.futureSteps,
        futureStepTime = self.futureStepTime,
        running = self.running,
        records = records,
    }
end

function Threat:start()
    if self.connection then
        return self
    end
    self.running = true
    self.connection = RunService.Heartbeat:Connect(function()
        pcall(function()
            self:sample()
        end)
    end)
    return self
end

function Threat:stop()
    self.running = false
    if self.connection then
        pcall(function()
            self.connection:Disconnect()
        end)
    end
    self.connection = nil
    return self
end

function Threat:destroy()
    self:stop()
    self.recordsByModel = {}
    self.order = {}
end

Threat.Destroy = Threat.destroy

return Threat
