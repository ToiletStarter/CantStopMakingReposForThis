local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EasyAim = (function()
    local path = "https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyaim/EasyAim.luau"
    local ok, s = pcall(game.HttpGet, game, path)
    if not ok or type(s) ~= "string" then return nil end
    local chunk = loadstring(s)
    return chunk and chunk() or nil
end)()

local Combat = {}
Combat.__index = Combat

function Combat.new(opt)
    opt = opt or {}
    local self = setmetatable({}, Combat)
    self.adapter = opt.adapter
    self.team = opt.team or "players"
    self.gunSystem = opt.gunSystem
    self.gunEvent = opt.gunEvent
    self.rigHealth = opt.rigHealth or function() return 100, 100 end
    self.rigSource = opt.rigSource or function() return {} end
    self.localRig = opt.localRig or function() return nil end
    self.notify = opt.notify or function() end

    self.legit = nil
    self.silent = nil
    self.magicBullet = false
    self.bulletTp = false

    self.lastFire = 0
    self.conns = {}

    self:_build()
    return self
end

function Combat:_buildAimInstance(mode, range, key)
    if not EasyAim then
        self.notify("aim", "EasyAim failed to load")
        return nil
    end
    return EasyAim.new({
        mode = mode,
        key = key,
        hitbox = { kind = "Head" },
        fov = { on = mode == "legit", radius = 130 },
        legit = { smooth = 0.18, maxStep = 60 },
        hold = mode ~= "silent",
        range = range,
        select = mode == "silent" and "distance" or "fov",
    })
end

function Combat:_build()
    local adapter = self.adapter
    self.legit = self:_buildAimInstance("legit", 1500, Enum.UserInputType.MouseButton2)
    if self.legit then
        self.legit:setSource(self.rigSource)
        self.legit:setAdapter(adapter)
        self.legit:on(false)
        self.legit:start()
    end

    self.silent = self:_buildAimInstance("silent", 3000, nil)
    if self.silent then
        self.silent:setSource(self.rigSource)
        self.silent:setAdapter(adapter)
        self.silent:on(false)
        self.silent:start()
    end

    table.insert(self.conns, RunService.Heartbeat:Connect(function(dt)
        self:_tick(dt)
    end))
end

function Combat:_tick(dt)
    if not self.silent or not self.silent.cfg.on then
        return
    end
    if not self.magicBullet and self.silent.target == nil then
        return
    end
    local now = os.clock()
    if (now - self.lastFire) < 0.05 then
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then
        return
    end
    local origin = cam.CFrame.Position

    local pos, part
    if self.magicBullet or self.bulletTp then
        local rec = self.silent:pick()
        if not rec then return end
        pos, part = self.silent:resolve(rec)
    else
        local _, hitPos = self.silent:aimDirection(origin)
        if not hitPos then return end
        pos = hitPos
        part = self.silent.hitPart and self.silent:hitPart(self.silent.target) or nil
    end

    if not pos then return end

    local target = part and part.Parent or (self.silent.target and self.silent.target.model)
    if not target or target == self.localRig() then
        return
    end

    local remote = self.gunEvent and self.gunEvent:FindFirstChild(self.team == "players" and "DamagePlayer" or "DamageCharacter")
    if not remote then return end

    self.lastFire = now

    local originPos = self.bulletTp and (pos + Vector3.new(0, 0, 0.01)) or origin
    pcall(function()
        remote:Fire(target, originPos, pos, {
            isPlayer = self.team == "players",
            partName = part and part.Name or "Head",
            model = target,
        })
    end)
end

function Combat:onLegit(v)
    if self.legit then self.legit:on(v) end
end

function Combat:onSilent(v)
    if self.silent then self.silent:on(v) end
end

function Combat:onMagicBullet(v)
    self.magicBullet = v
end

function Combat:onBulletTp(v)
    self.bulletTp = v
end

function Combat:destroy()
    for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
    self.conns = {}
    if self.legit then pcall(function() self.legit:destroy() end) end
    if self.silent then pcall(function() self.silent:destroy() end) end
end

return Combat
