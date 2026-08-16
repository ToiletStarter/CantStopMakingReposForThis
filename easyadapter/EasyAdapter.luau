local CollectionService = game:GetService("CollectionService")

local Adapter = {}
Adapter.__index = Adapter
Adapter.version = "1.0.0"

local function asList(value)
    if value == nil then
        return {}
    end
    if typeof(value) == "Instance" then
        return { value }
    end
    if type(value) ~= "table" then
        return {}
    end
    local out = {}
    for _, item in ipairs(value) do
        if typeof(item) == "Instance" then
            out[#out + 1] = item
        end
    end
    return out
end

local function safeCall(fn)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, value = pcall(fn)
    return ok and value or nil
end

local function safeLabel(label, item, fallback)
    local value = label
    if type(label) == "function" then
        local ok, result = pcall(label, item)
        value = ok and result or nil
    end
    if value == nil or value == "" then
        return fallback or (item and item.Name) or ""
    end
    return tostring(value)
end

local function cloneSpec(spec)
    local out = {}
    for key, value in pairs(spec or {}) do
        out[key] = value
    end
    return out
end

function Adapter.new(options)
    options = type(options) == "table" and options or {}
    local self = setmetatable({}, Adapter)
    self.name = tostring(options.name or "adapter")
    self.prefix = tostring(options.prefix or self.name)
    self.sources = {}
    self.order = {}
    self.esp = nil
    self.espIds = {}
    self.espBindings = {}
    self.npcBound = false
    self.npcSourceMap = {}
    self.world = nil
    self.worldIds = {}
    return self
end

function Adapter:addSource(id, spec)
    id = tostring(id)
    spec = type(spec) == "table" and spec or {}
    if type(spec.get) ~= "function" then
        return nil, "source.get must be a function"
    end
    if not self.sources[id] then
        self.order[#self.order + 1] = id
    end
    local source = {
        id = id,
        kind = spec.kind == "npc" and "npc" or "entity",
        get = spec.get,
        label = spec.label,
        fallback = spec.fallback,
        color = spec.color,
        max = spec.max,
        box = spec.box ~= false,
        name = spec.name ~= false,
        dist = spec.dist ~= false,
        tracer = spec.tracer == true,
        dot = spec.dot == true,
        ring = spec.ring,
        draw = spec.draw,
        enabled = spec.enabled ~= false,
    }
    self.sources[id] = source
    return source
end

function Adapter:addTagSource(id, tag, spec)
    spec = cloneSpec(spec)
    tag = tostring(tag)
    local fallback = spec.fallback
    spec.get = function()
        local tagged = CollectionService:GetTagged(tag)
        if #tagged > 0 or type(fallback) ~= "function" then
            return tagged
        end
        return fallback()
    end
    return self:addSource(id, spec)
end

function Adapter:addFolderSource(id, folder, spec)
    spec = cloneSpec(spec)
    spec.get = function()
        local root = type(folder) == "function" and safeCall(folder) or folder
        if typeof(root) ~= "Instance" then
            return {}
        end
        return root:GetChildren()
    end
    return self:addSource(id, spec)
end

function Adapter:source(id)
    return self.sources[tostring(id)]
end

function Adapter:setEnabled(id, value)
    local source = self:source(id)
    if source then
        source.enabled = value ~= false
    end
    return self
end

function Adapter:setOption(id, key, value)
    local source = self:source(id)
    if not source then
        return self
    end
    source[key] = value
    local binding = self.espBindings[id]
    if binding then
        binding[key] = value
    end
    return self
end

function Adapter:isEnabled(id)
    local source = self:source(id)
    return source and source.enabled == true or false
end

function Adapter:_values(source)
    if not source or not source.enabled then
        return {}
    end
    local value = safeCall(source.get)
    local list = asList(value)
    local out = {}
    for _, item in ipairs(list) do
        if item.Parent then
            out[#out + 1] = item
        end
    end
    if #out == 0 and type(source.fallback) == "function" then
        local fallback = asList(safeCall(source.fallback))
        for _, item in ipairs(fallback) do
            if item.Parent then
                out[#out + 1] = item
            end
        end
    end
    return out
end

function Adapter:_label(source, item)
    return safeLabel(source and source.label, item, source and source.id or nil)
end

function Adapter:_npcValues()
    local out = {}
    self.npcSourceMap = {}
    local seen = {}
    for _, id in ipairs(self.order) do
        local source = self.sources[id]
        if source and source.kind == "npc" then
            for _, item in ipairs(self:_values(source)) do
                if not seen[item] then
                    seen[item] = true
                    self.npcSourceMap[item] = source
                    out[#out + 1] = item
                end
            end
        end
    end
    return out
end

function Adapter:attachESP(esp)
    if type(esp) ~= "table" then
        return nil, "ESP instance missing"
    end
    self:detachESP()
    self.esp = esp
    for _, id in ipairs(self.order) do
        local source = self.sources[id]
        if source and source.kind == "entity" then
            local entityId = self.prefix .. "." .. id
            self.espIds[#self.espIds + 1] = entityId
            local binding = {
                get = function()
                    return self:_values(source)
                end,
                label = function(item)
                    return self:_label(source, item)
                end,
                col = source.color,
                box = source.box,
                name = source.name,
                dist = source.dist,
                tracer = source.tracer,
                dot = source.dot,
                ring = source.ring,
                max = source.max,
                draw = source.draw,
            }
            self.espBindings[id] = binding
            esp:addEnt(entityId, binding)
        end
    end
    esp:setNPCSource(function()
        return self:_npcValues()
    end)
    esp:setNPCLabel(function(item)
        return self:_label(self.npcSourceMap[item], item, "NPC")
    end)
    self.npcBound = true
    return self
end

function Adapter:detachESP()
    if self.esp then
        for _, id in ipairs(self.espIds) do
            pcall(function()
                self.esp:dropEnt(id)
            end)
        end
        if self.npcBound then
            pcall(function()
                self.esp:setNPCSource(nil)
                self.esp:setNPCLabel(nil)
            end)
        end
    end
    self.espIds = {}
    self.espBindings = {}
    self.npcBound = false
    self.esp = nil
    self.npcSourceMap = {}
    return self
end

function Adapter:bindWorld(id, world, spec)
    id = tostring(id)
    if self.worldIds[id] and self.world then
        pcall(function()
            self.world:remove(self.worldIds[id])
        end)
    end
    if type(world) ~= "table" or type(world.add) ~= "function" then
        return nil, "World instance missing"
    end
    spec = cloneSpec(spec)
    local getter = spec.get or spec.pos
    spec.get = function()
        if type(getter) == "function" then
            return safeCall(getter)
        end
        return getter
    end
    local worldId = self.prefix .. "." .. id
    world:add(worldId, spec)
    self.world = world
    self.worldIds[id] = worldId
    return worldId
end

function Adapter:unbindWorld(id)
    id = tostring(id)
    local worldId = self.worldIds[id]
    if worldId and self.world then
        pcall(function()
            self.world:remove(worldId)
        end)
    end
    self.worldIds[id] = nil
    return self
end

function Adapter:sourceCount(id)
    local source = self:source(id)
    return source and #self:_values(source) or 0
end

function Adapter:snapshot()
    local sources = {}
    for _, id in ipairs(self.order) do
        local source = self.sources[id]
        if source then
            sources[id] = {
                kind = source.kind,
                enabled = source.enabled,
                count = #self:_values(source),
            }
        end
    end
    return {
        version = Adapter.version,
        name = self.name,
        sources = sources,
    }
end

function Adapter:destroy()
    self:detachESP()
    local ids = {}
    for id in pairs(self.worldIds) do
        ids[#ids + 1] = id
    end
    for _, id in ipairs(ids) do
        self:unbindWorld(id)
    end
    self.sources = {}
    self.order = {}
    self.world = nil
end

return Adapter
