local GENV = (getgenv and getgenv()) or shared or _G

local Stack = {}
Stack._version = "1.0.0"
Stack._libs = {}
Stack._features = {}

function Stack.register(name, instance)
    Stack._libs[name] = instance
    return instance
end

function Stack.get(name)
    return Stack._libs[name]
end

function Stack.each(fn)
    for name, inst in pairs(Stack._libs) do
        pcall(fn, name, inst)
    end
end

function Stack.setFeature(key, value)
    Stack._features[key] = value
end

function Stack.feature(key)
    return Stack._features[key]
end

function Stack.destroyAll()
    for name, inst in pairs(Stack._libs) do
        if inst and type(inst.destroy) == "function" then
            pcall(function() inst:destroy() end)
        elseif inst and type(inst.Destroy) == "function" then
            pcall(function() inst:Destroy() end)
        end
    end
    Stack._libs = {}
end

GENV.__EASYSTACK = Stack
return Stack
