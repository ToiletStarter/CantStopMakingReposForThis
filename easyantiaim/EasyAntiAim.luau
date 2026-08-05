local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer

local AntiAim = {}
AntiAim.__index = AntiAim

local function pathOf(inst, root)
    root = root or game
    local p, cur = {}, inst
    while cur and cur ~= root do
        table.insert(p, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(p, ".")
end

function AntiAim.new(opt)
    opt = opt or {}
    local self = setmetatable({}, AntiAim)

    self.localRig = opt.localRig or function() return nil end
    self.notify = opt.notify or print

    self.mode = opt.mode or "angle"
    self.pitch = opt.pitch or 0
    self.yaw = opt.yaw or 180
    self.yawJitter = opt.yawJitter or 20
    self.fakeLag = opt.fakeLag or false
    self.fakeLagTicks = opt.fakeLagTicks or 4
    self.desyncOn = opt.desyncOn or false
    self.desyncSpeed = opt.desyncSpeed or 8
    self.fakeAngleOn = opt.fakeAngleOn or false
    self.fakeAngleYaw = opt.fakeAngleYaw or 0
    self.hideHitbox = opt.hideHitbox or false

    self.on = false
    self.conns = {}
    self.original = {}

    self._fakeRealRoot = nil
    return self
end

function AntiAim:_localRoot()
    local rig = self.localRig()
    if not rig then return nil end
    return rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart
end

function AntiAim:_storeOriginal(root)
    if not root or self._origStored then return end
    self.original.CFrame = root.CFrame
    self.original.Velocity = root.AssemblyLinearVelocity
    self.original.CanCollide = root.CanCollide
    self.original.Transparency = root.Transparency
    self._origStored = true
end

function AntiAim:_applyAngle(root, pitchDeg, yawDeg)
    local cf = root.CFrame
    local rx = math.rad(pitchDeg)
    local ry = math.rad(yawDeg)
    root.CFrame = CFrame.new(cf.Position) * CFrame.fromOrientation(rx, ry, 0)
end

function AntiAim:_applyDesync(root, dt)
    local jitter = math.noise(os.clock() * self.desyncSpeed) * 0.5 + math.random() * 0.3
    local cf = root.CFrame
    root.CFrame = cf * CFrame.fromOrientation(0, math.rad(jitter * 30), 0)
    root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2
end

function AntiAim:_applyFakeAngle(root)
    local fake = self._fakeRealRoot
    if not fake then
        fake = Instance.new("Part")
        fake.Name = "__FAKE_AA"
        fake.Size = Vector3.new(1.5, 2, 1.5)
        fake.Transparency = 1
        fake.CanCollide = false
        fake.Anchored = true
        fake.Parent = Workspace
        self._fakeRealRoot = fake
    end
    fake.CFrame = root.CFrame * CFrame.fromOrientation(0, math.rad(self.fakeAngleYaw), 0)
end

function AntiAim:_hideHitbox(root)
    for _, part in ipairs(root.Parent:GetChildren()) do
        if part:IsA("BasePart") and part ~= root then
            part.CanCollide = false
            part.Transparency = 1
        end
    end
    root.CanCollide = false
    root.Transparency = 0.4
end

function AntiAim:enable(v)
    if v == self.on then return self end
    self.on = v
    if not v then
        self:_restore()
    end
    return self
end

function AntiAim:_restore()
    local root = self:_localRoot()
    if not root then return end
    if self.original.CFrame then
        pcall(function() root.CFrame = self.original.CFrame end)
    end
    if self.original.Velocity then
        pcall(function() root.AssemblyLinearVelocity = self.original.Velocity end)
    end
    if self.original.Transparency then
        pcall(function() root.Transparency = self.original.Transparency end)
    end
    if self._fakeRealRoot then
        pcall(function() self._fakeRealRoot:Destroy() end)
        self._fakeRealRoot = nil
    end
    self._origStored = false
end

function AntiAim:destroy()
    self:enable(false)
    for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
    self.conns = {}
end

function AntiAim:_tick(dt)
    if not self.on then return end
    local root = self:_localRoot()
    if not root then return end

    self:_storeOriginal(root)

    if self.mode == "angle" then
        local jitter = (math.random() - 0.5) * self.yawJitter * 2
        self:_applyAngle(root, self.pitch, self.yaw + jitter)
    elseif self.mode == "spin" then
        self:_applyAngle(root, self.pitch, (os.clock() * 360) % 360)
    end

    if self.desyncOn then
        self:_applyDesync(root, dt)
    end

    if self.fakeAngleOn then
        self:_applyFakeAngle(root)
    end

    if self.hideHitbox then
        self:_hideHitbox(root)
    end

    if self.fakeLag then
        self._lagTick = (self._lagTick or 0) + 1
        if self._lagTick % self.fakeLagTicks == 0 then
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

function AntiAim:start()
    self.conns[#self.conns + 1] = RunService.Heartbeat:Connect(function(dt)
        pcall(function() self:_tick(dt) end)
    end)
    return self
end

return AntiAim
