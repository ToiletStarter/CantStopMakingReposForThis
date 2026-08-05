local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

local Cap = {}
Cap._ok = {}
Cap._missing = {}
Cap._features = {}

local function test(name, required, fallback)
    local ok, value = pcall(function()
        if type(required) == "function" then
            return required()
        end
        return required
    end)
    if ok and value ~= nil and value ~= false then
        Cap._ok[name] = true
        Cap._features[name] = value
    else
        Cap._ok[name] = false
        Cap._missing[name] = tostring(value)
    end
    return Cap._ok[name]
end

function Cap.run()
    Cap._ok = {}
    Cap._missing = {}
    Cap._features = {}

    test("loadstring", function() return loadstring end)
    test("httpget", function() return game.HttpGet end)
    test("getgenv", function() return getgenv end)
    test("gethui", function() return gethui end)
    test("setclipboard", function() return setclipboard end)
    test("writefile", function() return writefile end)
    test("readfile", function() return readfile end)
    test("identifyexecutor", function() return identifyexecutor end)
    test("mousemoverel", function() return mousemoverel end)
    test("mouse1press", function() return mouse1press end)
    test("mouse1release", function() return mouse1release end)
    test("drawing", function() return Drawing end)
    test("dex", function() return gethui and gethui() end)

    if Cap._ok.drawing then
        test("drawing.circle", function() return Drawing.new end)
    else
        Cap._ok["drawing.circle"] = false
    end
end

function Cap.supports(name)
    return Cap._ok[name] == true
end

function Cap.report()
    local lines = {}
    table.insert(lines, "Executor: " .. tostring(identifyexecutor and select(1, identifyexecutor()) or "?"))
    table.insert(lines, "")
    local groups = {
        core = { "loadstring", "httpget", "getgenv" },
        ui = { "drawing", "drawing.circle", "gethui" },
        input = { "mousemoverel", "mouse1press", "mouse1release" },
        io = { "setclipboard", "writefile", "readfile" },
        other = { "identifyexecutor", "dex" },
    }
    for gname, keys in pairs(groups) do
        table.insert(lines, "[" .. gname .. "]")
        for _, k in ipairs(keys) do
            local ok = Cap._ok[k]
            lines[#lines + 1] = string.format("  %-18s %s", k, ok and "OK" or ("NO  " .. (Cap._missing[k] or "")))
        end
    end
    return table.concat(lines, "\n")
end

function Cap.missingList()
    local out = {}
    for k in pairs(Cap._missing) do
        out[#out + 1] = k
    end
    return out
end

function Cap.warnOnMissing(keys)
    if type(keys) == "string" then
        keys = { keys }
    end
    local missing = {}
    for _, k in ipairs(keys) do
        if not Cap._ok[k] then
            missing[#missing + 1] = k
        end
    end
    if #missing == 0 then
        return false, nil
    end
    return true, table.concat(missing, ", ")
end

return Cap
