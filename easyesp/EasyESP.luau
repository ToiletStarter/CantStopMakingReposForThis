if not Drawing or not setrenderproperty then
    error("EasyESP needs Drawing and setrenderproperty", 2)
end

local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Light = game:GetService("Lighting")
local Http = game:GetService("HttpService")
local CAS = game:GetService("ContextActionService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    cam = workspace.CurrentCamera
end)

local new = Drawing.new
local rp = setrenderproperty

local v2 = Vector2.new
local v3 = Vector3.new
local cf = CFrame.new
local rgb = Color3.fromRGB
local hsv = Color3.fromHSV
local c3 = Color3.new

local abs = math.abs
local atan2 = math.atan2
local clamp = math.clamp
local cos = math.cos
local floor = math.floor
local huge = math.huge
local max = math.max
local min = math.min
local pi = math.pi
local sin = math.sin
local sqrt = math.sqrt

local insert = table.insert
local remove = table.remove
local sort = table.sort

local TAU = pi * 2
local BLACK = c3(0, 0, 0)
local WHITE = c3(1, 1, 1)
local FONTS = Drawing.Fonts or {}
local FONT = FONTS.Plex or FONTS.UI or FONTS.System or 0

local R15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local R6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local CORNERS = {
    v3(-1, 1, -1), v3(1, 1, -1), v3(1, 1, 1), v3(-1, 1, 1),
    v3(-1, -1, -1), v3(1, -1, -1), v3(1, -1, 1), v3(-1, -1, 1),
}

local function hue(t)
    return hsv(t % 1, 1, 1)
end

local function isColor(x)
    return typeof(x) == "Color3"
end

local function col(x, fallback)
    if isColor(x) then
        return x
    end
    return fallback or WHITE
end

local function deep(x)
    if type(x) ~= "table" then
        return x
    end
    local out = {}
    for k, v in pairs(x) do
        if type(v) == "table" and typeof(v) ~= "Color3" and typeof(v) ~= "Vector2" and typeof(v) ~= "Vector3" then
            out[k] = deep(v)
        else
            out[k] = v
        end
    end
    return out
end

local function merge(a, b)
    for k, v in pairs(b) do
        if type(v) == "table" and type(a[k]) == "table" and typeof(v) ~= "Color3" then
            merge(a[k], v)
        else
            a[k] = v
        end
    end
    return a
end

local function fill(a, b)
    for k, v in pairs(b) do
        if a[k] == nil then
            a[k] = type(v) == "table" and deep(v) or v
        elseif type(a[k]) == "table" and type(v) == "table" and typeof(v) ~= "Color3" then
            fill(a[k], v)
        end
    end
    return a
end

local function cleanName(s)
    s = tostring(s or "default")
    s = s:gsub("[^%w_%-]", "_")
    if s == "" then
        s = "default"
    end
    return s
end

local function pathGet(t, path)
    local node = t
    for part in tostring(path or ""):gmatch("[^%.]+") do
        if type(node) ~= "table" then
            return nil
        end
        node = node[part]
    end
    return node
end

local function desc(path, kind, label, extra)
    local d = {
        path = path,
        kind = kind,
        label = label,
        bindable = kind ~= "label" and kind ~= "section" and kind ~= "note",
        resettable = true,
        persist = true,
    }
    if type(extra) == "table" then
        for k, v in pairs(extra) do
            d[k] = v
        end
    end
    return d
end

local function pack(v)
    if typeof(v) == "Color3" then
        return { __easyesp = "c", r = v.R, g = v.G, b = v.B }
    end
    if type(v) == "table" then
        local out = {}
        for k, x in pairs(v) do
            out[k] = pack(x)
        end
        return out
    end
    return v
end

local function unpack(v)
    if type(v) == "table" and v.__easyesp == "c" then
        return c3(tonumber(v.r) or 1, tonumber(v.g) or 1, tonumber(v.b) or 1)
    end
    if type(v) == "table" then
        local out = {}
        for k, x in pairs(v) do
            out[k] = unpack(x)
        end
        return out
    end
    return v
end

local PAL = {
    accent = rgb(190, 150, 255),
    good = rgb(125, 235, 165),
    bad = rgb(255, 110, 130),
    text = rgb(236, 238, 245),
    muted = rgb(175, 180, 190),
    friend = rgb(120, 190, 255),
    ink = rgb(14, 14, 18),
}

local THEMES = {
    pastel = {
        accent = rgb(190, 150, 255),
        good = rgb(125, 235, 165),
        bad = rgb(255, 110, 130),
        text = rgb(236, 238, 245),
        muted = rgb(175, 180, 190),
        friend = rgb(120, 190, 255),
        ink = rgb(14, 14, 18),
    },
    carbon = {
        accent = rgb(115, 200, 255),
        good = rgb(135, 230, 170),
        bad = rgb(255, 105, 115),
        text = rgb(228, 232, 240),
        muted = rgb(165, 170, 180),
        friend = rgb(130, 185, 255),
        ink = rgb(12, 13, 16),
    },
    rose = {
        accent = rgb(255, 140, 185),
        good = rgb(140, 230, 175),
        bad = rgb(255, 110, 120),
        text = rgb(244, 234, 240),
        muted = rgb(185, 170, 180),
        friend = rgb(150, 170, 255),
        ink = rgb(17, 13, 16),
    },
    mint = {
        accent = rgb(120, 235, 195),
        good = rgb(120, 235, 165),
        bad = rgb(255, 110, 115),
        text = rgb(230, 245, 240),
        muted = rgb(170, 185, 180),
        friend = rgb(130, 190, 255),
        ink = rgb(12, 16, 15),
    },
    mono = {
        accent = rgb(235, 235, 235),
        good = rgb(195, 195, 195),
        bad = rgb(120, 120, 120),
        text = rgb(245, 245, 245),
        muted = rgb(175, 175, 175),
        friend = rgb(210, 210, 210),
        ink = rgb(10, 10, 10),
    },
}

local PROFILES = {
    low = {
        perf = {
            frameSkip = 1,
            visStep = 3,
            boxStep = 2,
            toolStep = 20,
            near = 100,
            mid = 260,
            far = 600,
            pruneAfter = 160,
            pruneEvery = 75,
        },
        bones = { on = false },
        radar = { max = 12 },
    },
    balanced = {
        perf = {
            frameSkip = 0,
            visStep = 2,
            boxStep = 2,
            toolStep = 14,
            near = 120,
            mid = 320,
            far = 760,
            pruneAfter = 260,
            pruneEvery = 90,
        },
    },
    high = {
        perf = {
            frameSkip = 0,
            visStep = 1,
            boxStep = 1,
            toolStep = 10,
            near = 150,
            mid = 360,
            far = 850,
            pruneAfter = 360,
            pruneEvery = 120,
        },
        bones = { on = true },
    },
}

local PACKS = {
    clean = {
        box = { on = true, kind = "corner", outline = true, fill = false },
        name = { on = true },
        hp = { on = true },
        dist = { on = true },
        flags = { on = false },
        tracer = { on = false },
        arrow = { on = true, fill = true, dist = true },
        radar = { on = false },
        list = { on = false },
        target = { on = true, showFov = true },
    },
    comp = {
        box = { on = true, kind = "corner", outline = true, fill = false, mode = "hp" },
        name = { on = true },
        hp = { on = true },
        dist = { on = true },
        flags = { on = true },
        tracer = { on = false },
        arrow = { on = true, fill = true, dist = true },
        radar = { on = true },
        list = { on = true, max = 8 },
        target = { on = true, showFov = true, visOnly = true },
    },
    world = {
        radar = { on = true },
        list = { on = true },
        tracer = { on = true },
        arrow = { on = true },
        rings = { on = true, enemies = true },
    },
}

local PRESETS = {
    lite = {
        theme = "carbon",
        profile = "low",
        pack = "clean",
    },
    legit = {
        theme = "pastel",
        profile = "balanced",
        pack = "comp",
    },
    world = {
        theme = "mint",
        profile = "balanced",
        pack = "world",
    },
    full = {
        theme = "rose",
        profile = "high",
        pack = "comp",
        extra = {
            bones = { on = true },
            radar = { on = true, names = true },
            list = { on = true, max = 12 },
            self = { wm = { on = true }, compass = { on = true } },
        },
    },
}

local function ringSpec(p)
    return fill(p or {}, {
        rad = 10,
        col = PAL.accent,
        w = 1,
        a = 1,
        sides = 32,
        spin = 0,
        fill = false,
        fillA = 0.05,
        glow = false,
        pulse = false,
        pulseRate = 2,
        style = "solid",
        kind = "circle",
        ticks = 0,
        tickLen = 0.8,
    })
end

local function defaults()
    local p = PAL
    local t = {
        on = false,
        maxRange = 3000,
        espRange = 3000,
        priority = {
            scale = 100,
            player = 5,
            walker = 4,
            entity = 2,
            hud = 9,
        },
        team = false,
        rainbow = false,
        rainbowRate = 1,
        friendTint = true,
        friendCol = p.friend,
        vis = {
            check = false,
            hide = false,
            tint = false,
            points = 3,
        },
        perf = {
            mode = "auto",
            frameSkip = 0,
            visStep = 2,
            boxStep = 2,
            toolStep = 14,
            near = 120,
            mid = 320,
            far = 760,
            pruneAfter = 260,
            pruneEvery = 90,
            fpsMin = 35,
            fpsMax = 144,
            npcFrameSkip = 2,
            npcBoxStep = 4,
            entityStep = 3,
            cullMax = 80,
            cullMargin = 80,
        },
        box = {
            on = true,
            kind = "corner",
            col = p.accent,
            w = 1,
            outline = true,
            fill = false,
            fillCol = p.accent,
            fillA = 0.07,
            mode = "static",
            fade = false,
            fade0 = 140,
            fade1 = 700,
            hpFull = p.good,
            hpLow = p.bad,
            corner = 0.28,
        },
        name = {
            on = true,
            user = false,
            size = 13,
            col = p.text,
        },
        dist = {
            on = false,
            size = 11,
            col = p.muted,
            suf = "m",
        },
        hp = {
            on = true,
            side = "left",
            w = 3,
            outline = true,
            text = false,
            pct = false,
            full = p.good,
            low = p.bad,
        },
        flags = {
            on = false,
            side = "right",
            size = 10,
            gap = 1,
            col = p.text,
        },
        bones = {
            on = false,
            col = p.text,
            w = 1,
        },
        head = {
            on = false,
            size = 3,
            col = p.text,
        },
        gaze = {
            on = false,
            len = 10,
            col = p.text,
        },
        tracer = {
            on = false,
            from = "bottom",
            col = p.accent,
            w = 1,
        },
        arrow = {
            on = false,
            rad = 190,
            size = 14,
            col = p.accent,
            fill = true,
            outline = true,
            dist = false,
            a = 1,
            scale = 1,
        },
        radar = {
            on = false,
            x = 18,
            y = 170,
            r = 74,
            range = 500,
            rot = true,
            bg = true,
            grid = true,
            border = true,
            ringLabels = true,
            names = false,
            max = 24,
            allies = false,
            col = p.text,
            enemy = p.accent,
            ally = p.good,
            friend = p.friend,
            selfCol = WHITE,
            blip = 3,
            size = 9,
            a = 0.28,
        },
        target = {
            on = false,
            fov = 240,
            showFov = false,
            visOnly = false,
            friends = true,
            allies = false,
            col = p.accent,
            friend = p.friend,
            ally = p.good,
            w = 1,
            pad = 4,
            outline = true,
            brackets = true,
            line = false,
            label = true,
            hp = true,
            dist = true,
            card = true,
        },
        list = {
            on = false,
            x = 18,
            y = 350,
            w = 220,
            max = 10,
            row = 17,
            bg = true,
            title = true,
            allies = false,
            hp = true,
            dist = true,
            vis = true,
            idx = true,
            col = p.text,
            enemy = p.accent,
            ally = p.good,
            friend = p.friend,
            low = p.bad,
            full = p.good,
            a = 0.3,
        },
        threat = {
            on = false,
            y = 92,
            size = 13,
            col = p.bad,
            bg = true,
            a = 0.3,
            visOnly = false,
            dist = true,
            hp = true,
        },
        rings = {
            on = false,
            enemies = false,
            specs = { ringSpec() },
        },
        self = {
            fov = {
                on = false,
                rad = 120,
                sides = 64,
                w = 1,
                a = 1,
                fill = false,
                fillA = 0.04,
                col = p.text,
                rainbow = false,
            },
            cross = {
                on = false,
                gap = 4,
                len = 8,
                w = 1,
                a = 1,
                col = p.good,
                rainbow = false,
                outline = true,
                dot = false,
                dotSize = 1,
            },
            wm = {
                on = false,
                x = 8,
                y = 8,
                size = 12,
                col = p.text,
                accent = p.accent,
                bg = true,
                stats = true,
                a = 0.32,
            },
            compass = {
                on = false,
                y = 18,
                w = 360,
                scale = 2.2,
                size = 11,
                col = p.text,
                accent = p.accent,
                a = 1,
                bearing = true,
            },
        },
        chams = {
            on = false,
            mode = "highlight",
            depth = "top",
            team = false,
            fill = true,
            fillCol = WHITE,
            fillA = 0.55,
            line = true,
            lineCol = WHITE,
            lineA = 0,
            mat = "ForceField",
            matCol = WHITE,
            matA = 0.2,
            matHead = true,
            tint = false,
            vis = p.good,
            hid = p.bad,
            rainbow = false,
            rate = 1,
        },
        world = {
            on = false,
            full = false,
            fov = 70,
            noFog = false,
            bright = 1,
            amb = BLACK,
            out = BLACK,
            exp = 1,
            grade = false,
            sat = 0,
            con = 0,
        },
    }
    t.npc = {
        on = false,
        espRange = t.espRange,
        maxRange = t.maxRange,
        rainbow = false,
        rainbowRate = 1,
        friendTint = false,
        friendCol = t.friendCol,
        team = false,
        vis = deep(t.vis),
        box = deep(t.box),
        hp = deep(t.hp),
        name = deep(t.name),
        dist = deep(t.dist),
        flags = deep(t.flags),
        bones = deep(t.bones),
        head = deep(t.head),
        gaze = deep(t.gaze),
        tracer = deep(t.tracer),
        rings = { on = false, enemies = true, specs = { ringSpec(nil) } },
        chams = deep(t.chams),
        arrow = deep(t.arrow),
        perf = deep(t.perf),
    }
    return t
end

local DESCRIPTOR_DEFAULTS = defaults()

local DESCRIPTORS = {
    desc("target.on", "toggle", "Target", { window = "Combat", tab = "Target", subtab = "Selector", section = "Main", order = 10, default = pathGet(DESCRIPTOR_DEFAULTS, "target.on"), desc = "Enable target selection." }),
    desc("target.fov", "slider", "FOV", { window = "Combat", tab = "Target", subtab = "Selector", section = "Main", order = 20, min = 20, max = 500, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "target.fov"), desc = "Screen-space radius used for target selection." }),
    desc("target.showFov", "toggle", "Show FOV", { window = "Combat", tab = "Target", subtab = "Selector", section = "Main", order = 30, default = pathGet(DESCRIPTOR_DEFAULTS, "target.showFov") }),
    desc("target.visOnly", "toggle", "Visible Only", { window = "Combat", tab = "Target", subtab = "Checks", section = "Checks", order = 40, default = pathGet(DESCRIPTOR_DEFAULTS, "target.visOnly") }),
    desc("target.friends", "toggle", "Include Friends", { window = "Combat", tab = "Target", subtab = "Checks", section = "Checks", order = 50, default = pathGet(DESCRIPTOR_DEFAULTS, "target.friends") }),
    desc("target.allies", "toggle", "Include Allies", { window = "Combat", tab = "Target", subtab = "Checks", section = "Checks", order = 60, default = pathGet(DESCRIPTOR_DEFAULTS, "target.allies") }),
    desc("target.brackets", "toggle", "Brackets", { window = "Combat", tab = "Target", subtab = "Visuals", section = "Display", order = 70, default = pathGet(DESCRIPTOR_DEFAULTS, "target.brackets") }),
    desc("target.line", "toggle", "Snapline", { window = "Combat", tab = "Target", subtab = "Visuals", section = "Display", order = 80, default = pathGet(DESCRIPTOR_DEFAULTS, "target.line") }),

    desc("arrow.on", "toggle", "Arrows", { window = "Combat", tab = "Offscreen", section = "Arrows", order = 90, default = pathGet(DESCRIPTOR_DEFAULTS, "arrow.on") }),
    desc("arrow.rad", "slider", "Radius", { window = "Combat", tab = "Offscreen", section = "Arrows", order = 100, min = 80, max = 350, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "arrow.rad") }),
    desc("arrow.size", "slider", "Size", { window = "Combat", tab = "Offscreen", section = "Arrows", order = 110, min = 8, max = 28, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "arrow.size") }),
    desc("arrow.dist", "toggle", "Distance Text", { window = "Combat", tab = "Offscreen", section = "Arrows", order = 120, default = pathGet(DESCRIPTOR_DEFAULTS, "arrow.dist") }),

    desc("box.on", "toggle", "Box", { window = "Visuals", tab = "Box", subtab = "Core", section = "Main", order = 10, default = pathGet(DESCRIPTOR_DEFAULTS, "box.on") }),
    desc("box.kind", "dropdown", "Style", { window = "Visuals", tab = "Box", subtab = "Core", section = "Main", order = 20, items = { "corner", "box", "3d", "3dcorner" }, default = pathGet(DESCRIPTOR_DEFAULTS, "box.kind") }),
    desc("box.mode", "dropdown", "Color Mode", { window = "Visuals", tab = "Box", subtab = "Core", section = "Main", order = 30, items = { "static", "team", "hp", "dist" }, default = pathGet(DESCRIPTOR_DEFAULTS, "box.mode") }),
    desc("box.w", "slider", "Thickness", { window = "Visuals", tab = "Box", subtab = "Core", section = "Main", order = 40, min = 1, max = 4, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "box.w") }),
    desc("box.fill", "toggle", "Fill", { window = "Visuals", tab = "Box", subtab = "Fill", section = "Fill", order = 50, default = pathGet(DESCRIPTOR_DEFAULTS, "box.fill") }),
    desc("box.fillA", "slider", "Fill Alpha", { window = "Visuals", tab = "Box", subtab = "Fill", section = "Fill", order = 60, min = 0, max = 1, step = 0.01, decimals = 2, default = pathGet(DESCRIPTOR_DEFAULTS, "box.fillA") }),
    desc("box.col", "color", "Accent", { window = "Visuals", tab = "Box", subtab = "Color", section = "Color", order = 70, default = pathGet(DESCRIPTOR_DEFAULTS, "box.col") }),
    desc("box.fillCol", "color", "Fill Color", { window = "Visuals", tab = "Box", subtab = "Color", section = "Color", order = 80, default = pathGet(DESCRIPTOR_DEFAULTS, "box.fillCol") }),

    desc("hp.on", "toggle", "Health Bar", { window = "Visuals", tab = "Labels", section = "Bars", order = 90, default = pathGet(DESCRIPTOR_DEFAULTS, "hp.on") }),
    desc("name.on", "toggle", "Name", { window = "Visuals", tab = "Labels", section = "Text", order = 100, default = pathGet(DESCRIPTOR_DEFAULTS, "name.on") }),
    desc("dist.on", "toggle", "Distance", { window = "Visuals", tab = "Labels", section = "Text", order = 110, default = pathGet(DESCRIPTOR_DEFAULTS, "dist.on") }),
    desc("flags.on", "toggle", "Flags", { window = "Visuals", tab = "Labels", section = "Text", order = 120, default = pathGet(DESCRIPTOR_DEFAULTS, "flags.on") }),
    desc("bones.on", "toggle", "Bones", { window = "Visuals", tab = "Extras", section = "ESP", order = 130, default = pathGet(DESCRIPTOR_DEFAULTS, "bones.on") }),
    desc("tracer.on", "toggle", "Tracer", { window = "Visuals", tab = "Extras", section = "ESP", order = 140, default = pathGet(DESCRIPTOR_DEFAULTS, "tracer.on") }),
    desc("tracer.from", "dropdown", "Tracer From", { window = "Visuals", tab = "Extras", section = "ESP", order = 150, items = { "bottom", "center", "top", "mouse" }, default = pathGet(DESCRIPTOR_DEFAULTS, "tracer.from") }),
    desc("tracer.col", "color", "Tracer Color", { window = "Visuals", tab = "Extras", section = "ESP", order = 160, default = pathGet(DESCRIPTOR_DEFAULTS, "tracer.col") }),

    desc("radar.on", "toggle", "Radar", { window = "Radar", tab = "Radar", section = "Main", order = 10, default = pathGet(DESCRIPTOR_DEFAULTS, "radar.on") }),
    desc("radar.x", "slider", "X", { window = "Radar", tab = "Radar", section = "Position", order = 20, min = 0, max = 600, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "radar.x") }),
    desc("radar.y", "slider", "Y", { window = "Radar", tab = "Radar", section = "Position", order = 30, min = 0, max = 600, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "radar.y") }),
    desc("radar.r", "slider", "Radius", { window = "Radar", tab = "Radar", section = "Position", order = 40, min = 40, max = 160, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "radar.r") }),
    desc("radar.range", "slider", "Range", { window = "Radar", tab = "Radar", section = "Main", order = 50, min = 100, max = 2000, step = 10, default = pathGet(DESCRIPTOR_DEFAULTS, "radar.range") }),
    desc("radar.rot", "toggle", "Rotate", { window = "Radar", tab = "Radar", section = "Main", order = 60, default = pathGet(DESCRIPTOR_DEFAULTS, "radar.rot") }),
    desc("radar.names", "toggle", "Names", { window = "Radar", tab = "Radar", section = "Main", order = 70, default = pathGet(DESCRIPTOR_DEFAULTS, "radar.names") }),
    desc("radar.allies", "toggle", "Show Allies", { window = "Radar", tab = "Radar", section = "Main", order = 80, default = pathGet(DESCRIPTOR_DEFAULTS, "radar.allies") }),

    desc("list.on", "toggle", "List", { window = "Radar", tab = "List", section = "Main", order = 90, default = pathGet(DESCRIPTOR_DEFAULTS, "list.on") }),
    desc("list.x", "slider", "X", { window = "Radar", tab = "List", section = "Position", order = 100, min = 0, max = 700, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "list.x") }),
    desc("list.y", "slider", "Y", { window = "Radar", tab = "List", section = "Position", order = 110, min = 0, max = 700, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "list.y") }),
    desc("list.w", "slider", "Width", { window = "Radar", tab = "List", section = "Position", order = 120, min = 160, max = 360, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "list.w") }),
    desc("list.max", "slider", "Max Rows", { window = "Radar", tab = "List", section = "Main", order = 130, min = 4, max = 24, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "list.max") }),
    desc("list.hp", "toggle", "Health", { window = "Radar", tab = "List", section = "Main", order = 140, default = pathGet(DESCRIPTOR_DEFAULTS, "list.hp") }),
    desc("list.dist", "toggle", "Distance", { window = "Radar", tab = "List", section = "Main", order = 150, default = pathGet(DESCRIPTOR_DEFAULTS, "list.dist") }),

    desc("team", "toggle", "Team Check", { window = "World", tab = "Checks", section = "Main", order = 10, default = pathGet(DESCRIPTOR_DEFAULTS, "team") }),
    desc("vis.check", "toggle", "Visibility Check", { window = "World", tab = "Checks", section = "Main", order = 20, default = pathGet(DESCRIPTOR_DEFAULTS, "vis.check") }),
    desc("vis.hide", "toggle", "Hide Hidden", { window = "World", tab = "Checks", section = "Main", order = 30, default = pathGet(DESCRIPTOR_DEFAULTS, "vis.hide") }),
    desc("vis.tint", "toggle", "Tint Visibility", { window = "World", tab = "Checks", section = "Main", order = 40, default = pathGet(DESCRIPTOR_DEFAULTS, "vis.tint") }),
    desc("vis.points", "slider", "Vis Points", { window = "World", tab = "Checks", section = "Main", order = 50, min = 1, max = 5, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "vis.points") }),
    desc("world.on", "toggle", "World Overrides", { window = "World", tab = "World", section = "Main", order = 60, default = pathGet(DESCRIPTOR_DEFAULTS, "world.on") }),
    desc("world.full", "toggle", "Fullbright", { window = "World", tab = "World", section = "Lighting", order = 70, default = pathGet(DESCRIPTOR_DEFAULTS, "world.full") }),
    desc("world.noFog", "toggle", "No Fog", { window = "World", tab = "World", section = "Lighting", order = 80, default = pathGet(DESCRIPTOR_DEFAULTS, "world.noFog") }),
    desc("world.fov", "slider", "FOV", { window = "World", tab = "World", section = "View", order = 90, min = 40, max = 120, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "world.fov") }),
    desc("world.bright", "slider", "Brightness", { window = "World", tab = "World", section = "Lighting", order = 100, min = 0, max = 5, step = 0.1, decimals = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "world.bright") }),

    desc("self.wm.on", "toggle", "Watermark", { window = "Self", tab = "HUD", section = "Main", order = 10, default = pathGet(DESCRIPTOR_DEFAULTS, "self.wm.on") }),
    desc("self.compass.on", "toggle", "Compass", { window = "Self", tab = "HUD", section = "Main", order = 20, default = pathGet(DESCRIPTOR_DEFAULTS, "self.compass.on") }),
    desc("self.fov.on", "toggle", "Self FOV", { window = "Self", tab = "Crosshair", section = "FOV", order = 30, default = pathGet(DESCRIPTOR_DEFAULTS, "self.fov.on") }),
    desc("self.fov.rad", "slider", "Self FOV Radius", { window = "Self", tab = "Crosshair", section = "FOV", order = 40, min = 20, max = 500, step = 1, default = pathGet(DESCRIPTOR_DEFAULTS, "self.fov.rad") }),
    desc("self.cross.on", "toggle", "Crosshair", { window = "Self", tab = "Crosshair", section = "Crosshair", order = 50, default = pathGet(DESCRIPTOR_DEFAULTS, "self.cross.on") }),

    desc("chams.on", "toggle", "Chams", { window = "Visuals", tab = "Chams", section = "Main", order = 170, default = pathGet(DESCRIPTOR_DEFAULTS, "chams.on") }),
    desc("chams.mode", "dropdown", "Mode", { window = "Visuals", tab = "Chams", section = "Main", order = 180, items = { "highlight", "material" }, default = pathGet(DESCRIPTOR_DEFAULTS, "chams.mode") }),
    desc("chams.depth", "dropdown", "Depth", { window = "Visuals", tab = "Chams", section = "Main", order = 190, items = { "top", "occluded" }, default = pathGet(DESCRIPTOR_DEFAULTS, "chams.depth") }),
    desc("chams.team", "toggle", "Team Check", { window = "Visuals", tab = "Chams", section = "Main", order = 200, default = pathGet(DESCRIPTOR_DEFAULTS, "chams.team") }),
    desc("chams.tint", "toggle", "Visibility Tint", { window = "Visuals", tab = "Chams", section = "Main", order = 210, default = pathGet(DESCRIPTOR_DEFAULTS, "chams.tint") }),

    desc("rings.on", "toggle", "Enemy Rings", { window = "Visuals", tab = "Rings", section = "Main", order = 220, default = pathGet(DESCRIPTOR_DEFAULTS, "rings.on") }),
    desc("rings.enemies", "toggle", "On Enemies", { window = "Visuals", tab = "Rings", section = "Main", order = 230, default = pathGet(DESCRIPTOR_DEFAULTS, "rings.enemies") }),
}

local DESCRIPTOR_INDEX = {}
for i = 1, #DESCRIPTORS do
    DESCRIPTOR_INDEX[DESCRIPTORS[i].path] = DESCRIPTORS[i]
end

local function descLookup(path)
    path = tostring(path or "")
    local d = DESCRIPTOR_INDEX[path]
    if d then return d end
    local head, rest = path:match("^([^.]+)%.(.+)$")
    if rest and DESCRIPTOR_DEFAULTS[head] == nil then
        return DESCRIPTOR_INDEX[rest]
    end
end

local Pool = {}
Pool.__index = Pool

function Pool.new()
    return setmetatable({
        bank = {},
        sh = {},
        live = {},
        prev = {},
        idle = {},
        frame = 0,
        size = 0,
        zbias = 0,
    }, Pool)
end

function Pool:get(key, kind)
    local d = self.bank[key]
    if d and (not self.sh[key] or self.sh[key].kind ~= kind) then
        pcall(function()
            d:Destroy()
        end)
        d = nil
        self.size = max(0, self.size - 1)
    end
    if not d then
        d = new(kind)
        self.bank[key] = d
        self.sh[key] = { kind = kind }
        self.size = self.size + 1
    end
    self.live[key] = true
    self.idle[key] = nil
    return d, self.sh[key]
end

function Pool:begin()
    self.frame = self.frame + 1
    for k in pairs(self.live) do
        self.live[k] = nil
    end
end

function Pool:_hide(key)
    local d = self.bank[key]
    local s = self.sh[key]
    if d and (not s or s.vis ~= false) then
        pcall(rp, d, "Visible", false)
    end
    if s then
        s.vis = false
    end
    self.idle[key] = self.frame
end

function Pool:finish()
    for k in pairs(self.prev) do
        if not self.live[k] then
            self:_hide(k)
        end
        self.prev[k] = nil
    end
    for k in pairs(self.live) do
        self.prev[k] = true
    end
end

function Pool:carry(prefix)
    local n = #prefix
    for k in pairs(self.prev) do
        if not self.live[k] and k:sub(1, n) == prefix then
            self.live[k] = true
        end
    end
end

function Pool:prune(n)
    if not n or n <= 0 then
        return
    end
    local cut = self.frame - n
    for k, at in pairs(self.idle) do
        if at <= cut then
            local d = self.bank[k]
            if d then
                pcall(function()
                    d:Destroy()
                end)
            end
            self.bank[k] = nil
            self.sh[k] = nil
            self.idle[k] = nil
            self.prev[k] = nil
            self.live[k] = nil
            self.size = max(0, self.size - 1)
        end
    end
end

function Pool:reset()
    for k in pairs(self.bank) do
        self:_hide(k)
    end
    for k in pairs(self.prev) do
        self.prev[k] = nil
    end
    for k in pairs(self.live) do
        self.live[k] = nil
    end
end

function Pool:nuke()
    for _, d in pairs(self.bank) do
        pcall(function()
            d:Destroy()
        end)
    end
    self.bank = {}
    self.sh = {}
    self.live = {}
    self.prev = {}
    self.idle = {}
    self.frame = 0
    self.size = 0
end

function Pool:line(key, ax, ay, bx, by, c, w, a, z)
    local d, s = self:get(key, "Line")
    if self.zbias ~= 0 then z = (z or 0) + self.zbias end
    c = col(c, WHITE)
    if not s.vis then
        rp(d, "Visible", true)
        s.vis = true
    end
    if s.ax ~= ax or s.ay ~= ay then
        rp(d, "From", v2(ax, ay))
        s.ax, s.ay = ax, ay
    end
    if s.bx ~= bx or s.by ~= by then
        rp(d, "To", v2(bx, by))
        s.bx, s.by = bx, by
    end
    if s.c ~= c then
        rp(d, "Color", c)
        s.c = c
    end
    w = w or 1
    if s.w ~= w then
        rp(d, "Thickness", w)
        s.w = w
    end
    a = a or 1
    if s.a ~= a then
        rp(d, "Transparency", a)
        s.a = a
    end
    if z and s.z ~= z then
        rp(d, "ZIndex", z)
        s.z = z
    end
    return d
end

function Pool:box(key, x, y, w, h, c, fill0, thick, a, z)
    local d, s = self:get(key, "Square")
    if self.zbias ~= 0 then z = (z or 0) + self.zbias end
    c = col(c, WHITE)
    if not s.vis then
        rp(d, "Visible", true)
        s.vis = true
    end
    if s.x ~= x or s.y ~= y then
        rp(d, "Position", v2(x, y))
        s.x, s.y = x, y
    end
    if s.w0 ~= w or s.h0 ~= h then
        rp(d, "Size", v2(w, h))
        s.w0, s.h0 = w, h
    end
    if s.c ~= c then
        rp(d, "Color", c)
        s.c = c
    end
    local f = fill0 == true
    if s.f ~= f then
        rp(d, "Filled", f)
        s.f = f
    end
    thick = thick or 1
    if s.t ~= thick then
        rp(d, "Thickness", thick)
        s.t = thick
    end
    a = a or 1
    if s.a ~= a then
        rp(d, "Transparency", a)
        s.a = a
    end
    if z and s.z ~= z then
        rp(d, "ZIndex", z)
        s.z = z
    end
    return d
end

function Pool:dot(key, x, y, r, c, fill0, a, sides, z, thick)
    local d, s = self:get(key, "Circle")
    if self.zbias ~= 0 then z = (z or 0) + self.zbias end
    c = col(c, WHITE)
    if not s.vis then
        rp(d, "Visible", true)
        s.vis = true
    end
    if s.x ~= x or s.y ~= y then
        rp(d, "Position", v2(x, y))
        s.x, s.y = x, y
    end
    if s.r ~= r then
        rp(d, "Radius", r)
        s.r = r
    end
    if s.c ~= c then
        rp(d, "Color", c)
        s.c = c
    end
    local f = fill0 == true
    if s.f ~= f then
        rp(d, "Filled", f)
        s.f = f
    end
    sides = sides or 32
    if s.sides ~= sides then
        rp(d, "NumSides", sides)
        s.sides = sides
    end
    thick = thick or 1
    if s.t ~= thick then
        rp(d, "Thickness", thick)
        s.t = thick
    end
    a = a or 1
    if s.a ~= a then
        rp(d, "Transparency", a)
        s.a = a
    end
    if z and s.z ~= z then
        rp(d, "ZIndex", z)
        s.z = z
    end
    return d
end

function Pool:tri(key, ax, ay, bx, by, cx, cy, c, a, z)
    local d, s = self:get(key, "Triangle")
    if self.zbias ~= 0 then z = (z or 0) + self.zbias end
    c = col(c, WHITE)
    if not s.vis then
        rp(d, "Visible", true)
        s.vis = true
    end
    if s.ax ~= ax or s.ay ~= ay then
        rp(d, "PointA", v2(ax, ay))
        s.ax, s.ay = ax, ay
    end
    if s.bx ~= bx or s.by ~= by then
        rp(d, "PointB", v2(bx, by))
        s.bx, s.by = bx, by
    end
    if s.cx ~= cx or s.cy ~= cy then
        rp(d, "PointC", v2(cx, cy))
        s.cx, s.cy = cx, cy
    end
    if s.c ~= c then
        rp(d, "Color", c)
        s.c = c
    end
    if not s.f then
        rp(d, "Filled", true)
        s.f = true
    end
    a = a or 1
    if s.a ~= a then
        rp(d, "Transparency", a)
        s.a = a
    end
    if z and s.z ~= z then
        rp(d, "ZIndex", z)
        s.z = z
    end
    return d
end

function Pool:txt(key, str, x, y, size, c, center, font, outline, a, z)
    local d, s = self:get(key, "Text")
    if self.zbias ~= 0 then z = (z or 0) + self.zbias end
    c = col(c, WHITE)
    if not s.vis then
        rp(d, "Visible", true)
        s.vis = true
    end
    if s.str ~= str then
        rp(d, "Text", str)
        s.str = str
    end
    if s.x ~= x or s.y ~= y then
        rp(d, "Position", v2(x, y))
        s.x, s.y = x, y
    end
    size = size or 12
    if s.size ~= size then
        rp(d, "Size", size)
        s.size = size
    end
    if s.c ~= c then
        rp(d, "Color", c)
        s.c = c
    end
    local cen = center ~= false
    if s.center ~= cen then
        rp(d, "Center", cen)
        s.center = cen
    end
    local out = not self.noOutline and outline ~= false
    if s.outline ~= out then
        rp(d, "Outline", out)
        rp(d, "OutlineColor", BLACK)
        s.outline = out
    end
    font = font or FONT
    if s.font ~= font then
        rp(d, "Font", font)
        s.font = font
    end
    a = a or 1
    if s.a ~= a then
        rp(d, "Transparency", a)
        s.a = a
    end
    if z and s.z ~= z then
        rp(d, "ZIndex", z)
        s.z = z
    end
    return d
end

local G = (getgenv and getgenv()) or _G
G.__EASY_STACK = G.__EASY_STACK or {}
local Runtime = G.__EASY_STACK

local ESP = {}
ESP.__index = ESP
ESP.ver = "4.0.0"
ESP.version = ESP.ver

local active = {}

local function box2d(pivot, size, project)
    local half = size * 0.5
    local lx, ly, hx, hy = huge, huge, -huge, -huge
    for i = 1, 8 do
        local x, y, d = project((pivot * cf(CORNERS[i] * half)).Position)
        if d <= 0 then
            return nil
        end
        if x < lx then lx = x end
        if y < ly then ly = y end
        if x > hx then hx = x end
        if y > hy then hy = y end
    end
    return lx, ly, hx - lx, hy - ly
end

local function characterBox(char, root)
    local base = root.CFrame
    local lo, hi
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part ~= root and part.Transparency < 1 then
            local p = base:PointToObjectSpace(part.Position)
            local h = part.Size * 0.5
            local a, b = p - h, p + h
            lo = lo and v3(min(lo.X, a.X), min(lo.Y, a.Y), min(lo.Z, a.Z)) or a
            hi = hi and v3(max(hi.X, b.X), max(hi.Y, b.Y), max(hi.Z, b.Z)) or b
        end
    end
    local pivot, size
    if lo then
        pivot, size = base * cf((lo + hi) * 0.5), hi - lo
    else
        pivot, size = char:GetBoundingBox()
    end
    return pivot, v3(clamp(size.X, 1, 12), clamp(size.Y, 1, 16), clamp(size.Z, 1, 8))
end

local function feet(root, hum)
    if not root then
        return nil
    end
    local drop = 2.6
    if hum and hum.HipHeight and hum.HipHeight > 0 then
        drop = hum.HipHeight + 0.1
    end
    return root.Position - v3(0, drop, 0)
end

local function fontSizeWidth(txt, size)
    return #txt * size * 0.56
end

local function mstr(d)
    return tostring(floor(d + 0.5)) .. "m"
end

local function pctstr(p)
    return tostring(floor(p * 100)) .. "%"
end

local function userIdOf(x)
    if typeof(x) == "Instance" then
        return x:IsA("Player") and x.UserId or nil
    end
    return tonumber(x)
end

local function stripInsts(t)
    if type(t) ~= "table" then
        return t
    end
    local out = {}
    for k, v in pairs(t) do
        if typeof(v) ~= "Instance" and type(v) ~= "function" then
            out[k] = stripInsts(v)
        end
    end
    return out
end

function ESP.new(opt)
    local old = Runtime.esp
    if old then
        local link = Runtime.bridge
        if link and link.esp == old and link.detach then
            pcall(function()
                link:detach()
            end)
        end
        if Runtime.esp == old then
            pcall(function()
                if old.destroy then
                    old:destroy()
                elseif old.Destroy then
                    old:Destroy()
                end
            end)
        end
    end

    local self = setmetatable({}, ESP)
    if not cameraConnection then
        cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            cam = workspace.CurrentCamera
        end)
    end
    self.cfg = defaults()
    if opt then
        merge(self.cfg, opt)
    end
    fill(self.cfg, defaults())

    self.pool = Pool.new()
    self.rp = RaycastParams.new()
    self.rp.FilterType = Enum.RaycastFilterType.Exclude

    self.friends = {}
    self.mods = {}
    self.modOrder = {}
    self.hooks = {}
    self.hookOrder = {}
    self.flags = {}
    self.flagEnabled = {}
    self.flagOrder = {}
    self.ents = {}
    self.rings = {}
    self.recs = {}
    self.npcRecs = {}
    self.npcSrc = nil
    self.npcLabel = nil
    self._npcId = 0
    self.plrs = {}
    self.con = {}
    self.binds = {}
    self.snap = {}
    self.target = nil
    self.targetSrc = nil
    self.targetInfo = nil
    self.running = false
    self.frame = 0
    self.t = 0
    self.last = 0
    self.world0 = nil
    local fps0 = 60
    if type(getfpscap) == "function" then
        local ok, cap = pcall(getfpscap)
        if ok and type(cap) == "number" and cap > 0 then
            fps0 = cap
        end
    end
    self.stats = { fps = 0, fpsAvg = fps0, drawn = 0, pool = 0, roster = 0 }
    self._fa = 0
    self._fc = 0
    self._dragRects = {}
    self._drag = nil
    self._casAction = "EasyESP_M3_" .. tostring(floor(os.clock() * 1000000))
    self._proj = function(pos)
        if not cam then
            return 0, 0, -1, false
        end
        local p, on = cam:WorldToViewportPoint(pos)
        return p.X, p.Y, p.Z, on
    end

    self:_boot()
    self:_flags()
    self:_dragHooks()

    Runtime.esp = self
    active[#active + 1] = self
    return self
end

function ESP:_wmText()
    local txt = "EasyESP " .. ESP.ver
    if self.cfg.self.wm.stats then
        txt = txt .. " | FPS " .. tostring(self.stats.fps) .. " | Drawn " .. tostring(self.stats.drawn) .. " | Pool " .. tostring(self.pool.size)
    end
    return txt
end

function ESP:_dragHit(pos)
    local best, top = nil, -math.huge
    for kind, r in pairs(self._dragRects) do
        if r and pos.X >= r.x and pos.X <= r.x + r.w and pos.Y >= r.y and pos.Y <= r.y + r.h then
            local z = r.z or 0
            if z >= top then
                best = { kind = kind, rect = r }
                top = z
            end
        end
    end
    return best
end

function ESP:_dragHooks()
    pcall(function()
        local sink = function(_, state)
            if state ~= Enum.UserInputState.Begin or not self.cfg.on then
                return Enum.ContextActionResult.Pass
            end
            local pos = Input:GetMouseLocation()
            if self._drag or self:_dragHit(pos) then
                return Enum.ContextActionResult.Sink
            end
            return Enum.ContextActionResult.Pass
        end
        if CAS.BindActionAtPriority then
            CAS:BindActionAtPriority(self._casAction, sink, false, Enum.ContextActionPriority.High.Value + 50, Enum.UserInputType.MouseButton3)
        else
            CAS:BindAction(self._casAction, sink, false, Enum.UserInputType.MouseButton3)
        end
    end)

    insert(self.con, Input.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton3 then return end
        local hit = self:_dragHit(input.Position)
        if not hit then return end
        local r = hit.rect
        self._drag = {
            kind = hit.kind,
            offX = input.Position.X - r.x,
            offY = input.Position.Y - r.y,
        }
    end))

    insert(self.con, Input.InputChanged:Connect(function(input)
        local d = self._drag
        if not d then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local vp = cam and cam.ViewportSize or v2(1200, 800)
        if d.kind == "radar" then
            local r = self.cfg.radar.r
            self.cfg.radar.x = clamp(floor(input.Position.X - d.offX + 0.5), 0, max(0, vp.X - r * 2))
            self.cfg.radar.y = clamp(floor(input.Position.Y - d.offY + 0.5), 0, max(0, vp.Y - r * 2))
        elseif d.kind == "list" then
            local w = self.cfg.list.w
            local h = (self.cfg.list.title and 18 or 0) + self.cfg.list.row * self.cfg.list.max + 8
            self.cfg.list.x = clamp(floor(input.Position.X - d.offX + 0.5), 0, max(0, vp.X - w))
            self.cfg.list.y = clamp(floor(input.Position.Y - d.offY + 0.5), 0, max(0, vp.Y - h))
        elseif d.kind == "wm" then
            local w = fontSizeWidth(self:_wmText(), self.cfg.self.wm.size) + 10
            local h = self.cfg.self.wm.size + 8
            self.cfg.self.wm.x = clamp(floor(input.Position.X - d.offX + 0.5), 0, max(0, vp.X - w))
            self.cfg.self.wm.y = clamp(floor(input.Position.Y - d.offY + 0.5), 0, max(0, vp.Y - h))
        end
    end))

    insert(self.con, Input.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton3 then
            self._drag = nil
        end
    end))
end

function ESP:_boot()
    local function add(plr)
        if plr == lp then
            return
        end
        if self.recs[plr.UserId] then
            return
        end
        self.recs[plr.UserId] = {
            plr = plr,
            uid = plr.UserId,
            char = nil,
            hum = nil,
            root = nil,
            head = nil,
            tool = nil,
            vis = nil,
            pivot = nil,
            size = nil,
            box = nil,
            hitAt = -1,
            hitDmg = 0,
            hp = 0,
            maxHp = 0,
            hpCon = nil,
            maxHpCon = nil,
            cham = nil,
            mat = nil,
            matKind = nil,
        }
        insert(self.plrs, plr)
    end

    local function drop(plr)
        local uid = plr.UserId
        local r = self.recs[uid]
        if r then
            if r.hpCon then r.hpCon:Disconnect() end
            if r.maxHpCon then r.maxHpCon:Disconnect() end
            self:_clearCham(r)
        end
        self.recs[uid] = nil
        for i = #self.plrs, 1, -1 do
            if self.plrs[i] == plr then
                remove(self.plrs, i)
                break
            end
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        add(plr)
    end

    insert(self.con, Players.PlayerAdded:Connect(add))
    insert(self.con, Players.PlayerRemoving:Connect(drop))
end

function ESP:_flags()
    self:flag("vis", function(s)
        if s.vis == nil then
            return nil
        end
        local cfg = s.cfg or self.cfg
        return s.vis and { "VIS", cfg.friendCol:Lerp(cfg.box.hpFull, 0.55) } or { "HID", cfg.box.hpLow }
    end)
    self:flag("hp", function(s)
        if s.maxHp > 0 then
            return { tostring(floor(s.hp + 0.5)) .. "hp", (s.cfg or self.cfg).flags.col }
        end
    end)
    self:flag("tool", function(s)
        if s.tool and s.tool ~= "" then
            return { s.tool, (s.cfg or self.cfg).flags.col }
        end
    end)
    self:flag("spd", function(s)
        if s.root then
            local v = floor(s.root.AssemblyLinearVelocity.Magnitude + 0.5)
            if v > 2 then
                return { tostring(v), (s.cfg or self.cfg).friendCol }
            end
        end
    end)
    self:flag("friend", function(s)
        if s.friend then
            return { "FRIEND", (s.cfg or self.cfg).friendCol }
        end
    end)
end

function ESP:_plan()
    local p = self.cfg.perf
    if p.mode ~= "auto" then
        return p.visStep, p.boxStep, p.toolStep
    end
    local fps = self.stats.fpsAvg > 0 and self.stats.fpsAvg or 60
    local n = max(1, #self.plrs)
    local mult
    if fps >= 120 then
        mult = 1
    elseif fps >= 90 then
        mult = 1.15
    elseif fps >= 70 then
        mult = 1.35
    elseif fps >= 55 then
        mult = 1.6
    elseif fps >= 45 then
        mult = 1.95
    else
        mult = 2.4
    end
    local load = 1 + clamp((n - 8) / 18, 0, 1.8)
    return max(1, floor(p.visStep * mult * load + 0.5)), max(1, floor(p.boxStep * mult * load + 0.5)), max(3, floor(p.toolStep * mult + n * 0.15 + 0.5))
end

function ESP:_turn(uid, step, salt)
    return ((self.frame + uid + (salt or 0)) % step) == 0
end

function ESP:_rec(r)
    local plr = r.plr
    local char = plr.Character
    if char ~= r.char then
        if r.hpCon then r.hpCon:Disconnect(); r.hpCon=nil end
        if r.maxHpCon then r.maxHpCon:Disconnect(); r.maxHpCon=nil end
        r.char = char
        r.hum = char and char:FindFirstChildOfClass("Humanoid") or nil
        r.root = char and char:FindFirstChild("HumanoidRootPart") or nil
        r.head = char and char:FindFirstChild("Head") or nil
        r.tool = nil
        r.vis = nil
        r.pivot = nil
        r.size = nil
        r.box = nil
        if r.hum then
            r.hp=r.hum.Health
            r.maxHp=r.hum.MaxHealth
            r.hpCon=r.hum.HealthChanged:Connect(function(hp) r.hp=hp end)
            r.maxHpCon=r.hum:GetPropertyChangedSignal("MaxHealth"):Connect(function() r.maxHp=r.hum.MaxHealth end)
        end
    else
        if char then
            if not r.hum or r.hum.Parent ~= char then
                r.hum = char:FindFirstChildOfClass("Humanoid")
            end
            if not r.root or r.root.Parent ~= char then
                r.root = char:FindFirstChild("HumanoidRootPart")
            end
            if not r.head or r.head.Parent ~= char then
                r.head = char:FindFirstChild("Head")
            end
        else
            r.hum = nil
            r.root = nil
            r.head = nil
        end
    end
    return r.char, r.hum, r.root, r.head
end

function ESP:_canSee(char, points)
    if not char or not cam then
        return false
    end
    local eye = cam.CFrame.Position
    local mine = lp.Character
    self.rp.FilterDescendantsInstances = mine and { mine, char } or { char }

    local n = 0
    local parts = {}

    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if root then n = n + 1; parts[n] = root end
    if head then n = n + 1; parts[n] = head end
    if points >= 3 then
        local a = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if a then n = n + 1; parts[n] = a end
    end
    if points >= 4 then
        local a = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm")
        if a then n = n + 1; parts[n] = a end
    end
    if points >= 5 then
        local a = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm")
        if a then n = n + 1; parts[n] = a end
    end

    for i = 1, n do
        local part = parts[i]
        local dir = part.Position - eye
        if dir.Magnitude > 0.1 then
            local hit = workspace:Raycast(eye, dir, self.rp)
            if not hit or (hit.Instance and hit.Instance:IsDescendantOf(char)) then
                return true
            end
        end
    end

    return false
end

function ESP:_ally(plr)
    return plr.Team ~= nil and plr.Team == lp.Team
end

function ESP:_friend(x)
    local uid = userIdOf(x)
    return uid and self.friends[uid] == true or false
end

function ESP:_lod(d)
    local p = self.cfg.perf
    if d <= p.near then return 0 end
    if d <= p.mid then return 1 end
    if d <= p.far then return 2 end
    return 3
end

function ESP:_mkSnap(rec, char, root, head, hum, dist, boxStep, boxSalt, boxFn)
    local sx, sy, depth, on = self._proj(root.Position)
    local bx, by, bw, bh
    local fresh = rec.boxAt and (self.frame - rec.boxAt) <= boxStep * 3
    if depth > 0 and (self:_turn(rec.uid, boxStep, boxSalt) or not rec.box) then
        rec.pivot, rec.size = boxFn()
        bx, by, bw, bh = box2d(rec.pivot, rec.size, self._proj)
        if bx then
            rec.box = { bx, by, bw, bh }
            rec.boxAt = self.frame
        elseif rec.box and fresh then
            bx, by, bw, bh = rec.box[1], rec.box[2], rec.box[3], rec.box[4]
        end
    elseif rec.box and fresh then
        bx, by, bw, bh = rec.box[1], rec.box[2], rec.box[3], rec.box[4]
    end
    return {
        uid = rec.uid,
        char = char,
        hum = hum,
        root = root,
        head = head,
        hp = rec.hp,
        maxHp = rec.maxHp,
        hpPct = rec.maxHp > 0 and clamp(rec.hp / rec.maxHp, 0, 1) or 0,
        dist = dist,
        foot = feet(root, hum),
        vis = rec.vis,
        on = on,
        sx = sx,
        sy = sy,
        depth = depth,
        bx = bx,
        by = by,
        bw = bw,
        bh = bh,
        lod = self:_lod(dist),
        pivot = rec.pivot,
        size = rec.size,
        rec = rec,
    }
end

function ESP:_snap()
    if not cam then
        self.snap = {}
        self.stats.roster = 0
        return
    end

    local visStep, boxStep, toolStep = self:_plan()
    local eye = cam.CFrame.Position
    local out = {}
    local visualRange = self.cfg.espRange <= 0 and huge or self.cfg.espRange
    local maxRange = self.cfg.maxRange <= 0 and huge or self.cfg.maxRange
    local reach = max(maxRange, visualRange, self.cfg.radar.range)
    local needVis = self.cfg.vis.check or self.cfg.vis.hide or self.cfg.vis.tint or self.cfg.target.visOnly or (self.cfg.chams.on and self.cfg.chams.tint)

    for _, plr in ipairs(self.plrs) do
        local r = self.recs[plr.UserId]
        if r then
            local char, hum, root, head = self:_rec(r)
            if char and hum and root and hum.Health > 0 then
                local dist = (eye - root.Position).Magnitude
                if dist <= reach then
                    r.hp = hum.Health
                    r.maxHp = hum.MaxHealth
                    if r.hp0 and r.hp < r.hp0 then
                        self:_markHit(r, floor(r.hp0 - r.hp + 0.5))
                    end
                    r.hp0 = r.hp

                    if self:_turn(r.uid, toolStep, 5) or r.tool == nil then
                        local tool = char:FindFirstChildOfClass("Tool")
                        r.tool = tool and tool.Name or ""
                    end

                    if needVis and (self:_turn(r.uid, visStep, 9) or r.vis == nil) then
                        r.vis = self:_canSee(char, self.cfg.vis.points)
                    end

                    local s = self:_mkSnap(r, char, root, head, hum, dist, boxStep, 2, function()
                        return characterBox(char, root)
                    end)
                    s.plr = plr
                    s.tool = r.tool
                    s.team = plr.Team
                    s.teamCol = plr.TeamColor and plr.TeamColor.Color or nil
                    s.ally = self:_ally(plr)
                    s.friend = self:_friend(plr)
                    out[#out + 1] = s
                else
                    self:_clearCham(r)
                end
            else
                self:_clearCham(r)
            end
        end
    end

    self.stats.roster = #out
    self:_snapNPC(out, eye)

    if #out > 1 then
        sort(out, function(a, b)
            return a.dist < b.dist
        end)
    end

    self.snap = out
end

function ESP:_snapNPC(out, eye)
    local ncfg = self.cfg.npc
    if not ncfg or not ncfg.on or type(self.npcSrc) ~= "function" then
        if next(self.npcRecs) then
            for model, rec in pairs(self.npcRecs) do
                self:_clearCham(rec)
                self.npcRecs[model] = nil
            end
        end
        return
    end
    local ok, list = pcall(self.npcSrc)
    if not ok or type(list) ~= "table" then
        return
    end
    local maxRange = (ncfg.maxRange or 0) <= 0 and huge or ncfg.maxRange
    local visualRange = (ncfg.espRange or 0) <= 0 and huge or ncfg.espRange
    local reach = max(maxRange, visualRange)
    local needVis = ncfg.vis.check or ncfg.vis.hide or ncfg.vis.tint or (ncfg.chams.on and ncfg.chams.tint)
    local recs = self.npcRecs
    local seen = self._npcSeen or {}
    self._npcSeen = seen
    for k in pairs(seen) do
        seen[k] = nil
    end
    local npcBoxStep = max(1, tonumber(ncfg.perf.npcBoxStep) or 4)
    local cullMax = max(1, tonumber(ncfg.perf.cullMax) or 80)
    local added = 0
    for i = 1, #list do
        if added >= cullMax then break end
        local model = list[i]
        if typeof(model) == "Instance" and model.Parent then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if rootPart then
                local hAttr = model:GetAttribute("Health")
                local hp = tonumber(hAttr) or (hum and hum.Health) or 0
                local maxHp = (hum and hum.MaxHealth) or 100
                if maxHp <= 0 then
                    maxHp = 100
                end
                local dead = model:GetAttribute("Dead") == true or (hum and hum.Health <= 0 and hAttr == nil)
                if hp > 0 and not dead then
                    local dist = (eye - rootPart.Position).Magnitude
                    if dist <= reach then
                        local rec = recs[model]
                        if not rec then
                            self._npcId = (self._npcId or 0) + 1
                            rec = { uid = -self._npcId, model = model, hitAt = -1, hitDmg = 0, hp = hp, hp0 = hp, maxHp = maxHp }
                            recs[model] = rec
                        end
                        seen[model] = true
                        rec.hp = hp
                        rec.maxHp = maxHp
                        if rec.hp0 and hp < rec.hp0 then
                            self:_markHit(rec, floor(rec.hp0 - hp + 0.5))
                        end
                        rec.hp0 = hp
                        if needVis and (self:_turn(rec.uid, npcBoxStep, 23) or rec.vis == nil) then
                            rec.vis = self:_canSee(model, ncfg.vis.points)
                        end
                        local label = model.Name
                        if type(self.npcLabel) == "function" then
                            local ok2, lb = pcall(self.npcLabel, model)
                            if ok2 and lb then
                                label = lb
                            end
                        end
                        local s = self:_mkSnap(rec, model, rootPart, model:FindFirstChild("Head"), hum, dist, npcBoxStep, 17, function()
                            return model:GetBoundingBox()
                        end)
                        s.npc = true
                        s.tool = ""
                        s.name = label
                        s.ally = false
                        s.friend = false
                        s.cfg = ncfg
                        out[#out + 1] = s
                        added = added + 1
                    end
                end
            end
        end
    end
    for model, rec in pairs(recs) do
        if not seen[model] then
            self:_clearCham(rec)
            recs[model] = nil
        end
    end
end

function ESP:_accent(s)
    local cfg = s.cfg or self.cfg
    local b = cfg.box
    local c = cfg.rainbow and hue(self.t * cfg.rainbowRate * 0.12) or col(b.col, cfg.friendCol)

    if cfg.friendTint and s.friend then
        c = col(cfg.friendCol, c)
    end

    if b.mode == "team" and s.teamCol then
        c = s.teamCol
    elseif b.mode == "hp" then
        c = col(b.hpLow, c):Lerp(col(b.hpFull, c), s.hpPct)
    elseif b.mode == "dist" then
        c = col(b.hpFull, c):Lerp(col(b.hpLow, c), clamp(s.dist / max(cfg.espRange, 1), 0, 1))
    end

    if cfg.vis.tint and s.vis ~= nil then
        c = s.vis and col(cfg.box.hpFull, c) or col(cfg.box.hpLow, c)
    end

    local rec = s.rec
    if rec.hitAt >= 0 then
        local life = 0.35
        local dt = self.t - rec.hitAt
        if dt < life then
            c = c:Lerp(WHITE, 1 - dt / life)
        end
    end

    return c
end

function ESP:_fade(s)
    local b = (s.cfg or self.cfg).box
    if not b.fade then
        return 1
    end
    return 1 - clamp((s.dist - b.fade0) / max(b.fade1 - b.fade0, 1), 0, 0.85)
end

function ESP:_markHit(r, dmg)
    r.hitAt = self.t
    r.hitDmg = dmg or 0
end

function ESP:_lineW(key, a, b, c, w, alpha, z)
    local ax, ay, ad = self._proj(a)
    local bx, by, bd = self._proj(b)
    if ad > 0 and bd > 0 then
        self.pool:line(key, ax, ay, bx, by, c, w, alpha, z)
        return true
    end
    return false
end

function ESP:_ring(key, pos, spec, lod)
    if not pos then
        return
    end
    local sides = max(8, floor((spec.sides or 32) * (lod == 0 and 1 or lod == 1 and 0.75 or lod == 2 and 0.55 or 0.4)))
    local spin = self.t * (spec.spin or 0)
    local c = spec.col
    local a = spec.a or 1
    if spec.pulse then
        a = a * (0.6 + 0.4 * abs(sin(self.t * (spec.pulseRate or 2))))
    end
    local pts = self._ringPts or {}
    self._ringPts = pts
    local prevX, prevY, prevD
    local step = spec.style == "dashed" and 2 or 1
    for i = 0, sides do
        local ang = (i / sides) * TAU + spin
        local p = pos + v3(cos(ang) * spec.rad, 0, sin(ang) * spec.rad)
        local x, y, d = self._proj(p)
        if prevX and prevD > 0 and d > 0 and (i % step == 0) then
            self.pool:line(key .. "_" .. i, prevX, prevY, x, y, c, spec.w or 1, a)
            if spec.glow then
                self.pool:line(key .. "g_" .. i, prevX, prevY, x, y, c, (spec.w or 1) + 2, a * 0.25)
            end
        end
        pts[i + 1] = { x, y, d }
        prevX, prevY, prevD = x, y, d
    end
    if spec.fill then
        local cx, cy, cd = self._proj(pos)
        if cd > 0 then
            for i = 1, sides do
                local a0 = pts[i]
                local b0 = pts[(i % sides) + 1]
                if a0 and b0 and a0[3] > 0 and b0[3] > 0 then
                    self.pool:tri(key .. "f_" .. i, cx, cy, a0[1], a0[2], b0[1], b0[2], c, spec.fillA or 0.05)
                end
            end
        end
    end
    if spec.ticks and spec.ticks > 0 and lod < 2 then
        for i = 0, spec.ticks - 1 do
            local ang = (i / spec.ticks) * TAU + spin
            local p0 = pos + v3(cos(ang) * spec.rad, 0, sin(ang) * spec.rad)
            local p1 = pos + v3(cos(ang) * (spec.rad + (spec.tickLen or 0.8)), 0, sin(ang) * (spec.rad + (spec.tickLen or 0.8)))
            self:_lineW(key .. "t_" .. i, p0, p1, c, spec.w or 1, a)
        end
    end
end

function ESP:_bones(s, c)
    local set = s.char:FindFirstChild("UpperTorso") and R15 or R6
    for i, pair in ipairs(set) do
        local a = s.char:FindFirstChild(pair[1])
        local b = s.char:FindFirstChild(pair[2])
        if a and b then
            local ax, ay, ad = self._proj(a.Position)
            local bx, by, bd = self._proj(b.Position)
            if ad > 0 and bd > 0 then
                self.pool:line("b" .. s.uid .. "_" .. i, ax, ay, bx, by, c, (s.cfg or self.cfg).bones.w, 1)
            end
        end
    end
end

function ESP:_flagsDraw(s, x, y, w)
    local root = s.cfg or self.cfg
    if not root.flags.on then
        return
    end
    local cfg = root.flags
    local right = cfg.side ~= "left"
    local col = right and x + w + 5 or x - 5
    local row = y
    local i = 0
    for _, name in ipairs(self.flagOrder) do
        local fn = self.flags[name]
        if fn and self.flagEnabled[name] ~= false then
            local ok, out = pcall(fn, s)
            if ok and out then
                i = i + 1
                local txt = tostring(out[1])
                local tc = out[2] or cfg.col
                local width = fontSizeWidth(txt, cfg.size)
                local tx = right and col or col - width
                local d = self.pool:txt("f" .. s.uid .. "_" .. i, txt, tx, row, cfg.size, tc, false, FONT, true)
                if d and not right then
                    local bounds = d.TextBounds and d.TextBounds.X or width
                    if abs(bounds - width) > 1 then
                        self.pool:txt("f" .. s.uid .. "_" .. i, txt, col - bounds, row, cfg.size, tc, false, FONT, true)
                    end
                end
                row = row + cfg.size + cfg.gap
            end
        end
    end
end

local function cornerSegs(x, y, w, h, q)
    return {
        x, y, x + q, y,
        x, y, x, y + q,
        x + w, y, x + w - q, y,
        x + w, y, x + w, y + q,
        x, y + h, x + q, y + h,
        x, y + h, x, y + h - q,
        x + w, y + h, x + w - q, y + h,
        x + w, y + h, x + w, y + h - q,
    }
end

function ESP:_segs(key, seg, c, w, a, outline, aOut, zOut, zIn)
    for i = 1, #seg / 4 do
        local o = (i - 1) * 4
        if outline then
            self.pool:line(key .. "o" .. i, seg[o + 1], seg[o + 2], seg[o + 3], seg[o + 4], BLACK, w + 1, aOut or a, zOut)
        end
        self.pool:line(key .. "i" .. i, seg[o + 1], seg[o + 2], seg[o + 3], seg[o + 4], c, w, a, zIn)
    end
end

function ESP:_boxDraw(s, c, a)
    local b = (s.cfg or self.cfg).box
    local x, y, w, h = s.bx, s.by, s.bw, s.bh
    if not b.on or not x then
        return
    end
    if b.kind == "3d" or b.kind == "3dcorner" then
        local half = s.size * 0.5
        local pts = self._pts or {}
        self._pts = pts
        for i = 1, 8 do
            local px, py, d = self._proj((s.pivot * cf(CORNERS[i] * half)).Position)
            pts[i] = d > 0 and { px, py } or false
        end
        local edges = {
            {1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8},
        }
        for i, e in ipairs(edges) do
            local p0, p1 = pts[e[1]], pts[e[2]]
            if not p0 or not p1 then
            elseif b.kind == "3dcorner" then
                local dx, dy = p1[1] - p0[1], p1[2] - p0[2]
                local len = sqrt(dx * dx + dy * dy)
                if len > 0 then
                    local ux, uy = dx / len, dy / len
                    local q = len * 0.25
                    self.pool:line("bo" .. s.uid .. "_" .. i, p0[1], p0[2], p0[1] + ux * q, p0[2] + uy * q, c, b.w, a)
                    self.pool:line("bf" .. s.uid .. "_" .. i, p1[1], p1[2], p1[1] - ux * q, p1[2] - uy * q, c, b.w, a)
                end
            else
                self.pool:line("be" .. s.uid .. "_" .. i, p0[1], p0[2], p1[1], p1[2], c, b.w, a)
            end
        end
        return
    end

    if b.fill then
        self.pool:box("bf" .. s.uid, x, y, w, h, b.fillCol, true, 1, (b.fillA or 0.07) * a)
    end

    if b.kind == "corner" then
        self:_segs("c" .. s.uid, cornerSegs(x, y, w, h, min(w, h) * b.corner), c, b.w, a, b.outline)
    else
        if b.outline then
            self.pool:box("bo" .. s.uid, x - 1, y - 1, w + 2, h + 2, BLACK, false, b.w + 1, a)
        end
        self.pool:box("b" .. s.uid, x, y, w, h, c, false, b.w, a)
    end
end

function ESP:_hpDraw(s, a)
    local cfg = (s.cfg or self.cfg).hp
    if not cfg.on or s.maxHp <= 0 or not s.bx then
        return
    end
    local x = cfg.side == "right" and (s.bx + s.bw + 4) or (s.bx - 4 - cfg.w)
    local h = s.bh * s.hpPct
    local c = col(cfg.low, WHITE):Lerp(col(cfg.full, WHITE), s.hpPct)
    if cfg.outline then
        self.pool:box("ho" .. s.uid, x - 1, s.by - 1, cfg.w + 2, s.bh + 2, BLACK, true, 1, 0.7 * a)
    end
    self.pool:box("hg" .. s.uid, x, s.by, cfg.w, s.bh, c3(0.08, 0.08, 0.11), true, 1, 0.55 * a)
    self.pool:box("hf" .. s.uid, x, s.by + (s.bh - h), cfg.w, max(1, h), c, true, 1, a)
    if cfg.text and s.hpPct < 1 then
        self.pool:txt("ht" .. s.uid, tostring(floor(s.hp + 0.5)), x + cfg.w * 0.5, s.by - 12, 10, c, true, FONT, true, a)
    end
    if cfg.pct then
        self.pool:txt("hp" .. s.uid, pctstr(s.hpPct), s.bx + s.bw * 0.5, s.by + s.bh + 3, 10, c, true, FONT, true, a)
    end
end

function ESP:_nameDraw(s, c, a)
    local n = (s.cfg or self.cfg).name
    if not n.on or not s.bx then
        return s.by - 4
    end
    local txt
    if s.plr then
        if n.user and n.on then
            txt = s.plr.DisplayName .. " (" .. s.plr.Name .. ")"
        elseif n.user then
            txt = s.plr.Name
        else
            txt = s.plr.DisplayName
        end
    else
        txt = s.name or "?"
    end
    local y = s.by - n.size - 4
    self.pool:txt("n" .. s.uid, txt, s.bx + s.bw * 0.5, y, n.size, n.col or c, true, FONT, true, a)
    return y
end

function ESP:_distDraw(s, c, a, y)
    local root = s.cfg or self.cfg
    if not root.dist.on or not s.bx then
        return y
    end
    local d = root.dist
    local txt = tostring(floor(s.dist + 0.5)) .. d.suf
    self.pool:txt("d" .. s.uid, txt, s.bx + s.bw * 0.5, y, d.size, d.col or c, true, FONT, true, a)
    return y + d.size
end

function ESP:_tracer(s, c, a)
    local tc = (s.cfg or self.cfg).tracer
    if not tc.on or not s.bx then
        return
    end
    local vp = cam.ViewportSize
    local x, y = vp.X * 0.5, vp.Y
    local from = tc.from
    if from == "center" then
        y = vp.Y * 0.5
    elseif from == "top" then
        y = 0
    elseif from == "mouse" then
        local m = Input:GetMouseLocation()
        x, y = m.X, m.Y
    end
    self.pool:line("tr" .. s.uid, x, y, s.bx + s.bw * 0.5, s.by + s.bh, c, tc.w, a)
end

function ESP:_gaze(s, c, a)
    local g = (s.cfg or self.cfg).gaze
    if not g.on or not s.head then
        return
    end
    self:_lineW("gz" .. s.uid, s.head.Position, s.head.Position + s.head.CFrame.LookVector * g.len, c, 1, a)
end

function ESP:_head(s, c, a)
    local hc = (s.cfg or self.cfg).head
    if not hc.on or not s.head then
        return
    end
    local x, y, d = self._proj(s.head.Position)
    if d > 0 then
        self.pool:dot("hd" .. s.uid, x, y, hc.size, c, true, a, 12)
    end
end

function ESP:_player(s)
    local cfg = s.cfg or self.cfg
    if cfg.team and s.ally then
        return
    end
    if cfg.vis.hide and s.vis == false then
        return
    end
    if s.depth <= 0 or not s.bx then
        return
    end
    if cfg.espRange > 0 and s.dist > cfg.espRange then
        return
    end

    local c = self:_accent(s)
    local a = self:_fade(s)

    self:_boxDraw(s, c, a)
    self:_hpDraw(s, a)

    if cfg.bones.on and s.lod < 2 then
        self:_bones(s, cfg.bones.col or c)
    end

    self:_head(s, cfg.head.col or c, a)
    self:_gaze(s, cfg.gaze.col or c, a)
    self:_tracer(s, cfg.tracer.col or c, a)
    self:_flagsDraw(s, s.bx, s.by, s.bw)

    self:_nameDraw(s, c, a)
    local y = s.by + s.bh + 3

    if cfg.dist.on then
        y = self:_distDraw(s, cfg.dist.col or c, a, y)
    end

    if cfg.rings.on and cfg.rings.enemies and s.foot then
        for i, spec in ipairs(cfg.rings.specs) do
            self:_ring("rg" .. s.uid .. "_" .. i, s.foot, spec, s.lod)
        end
    end

    for _, name in ipairs(self.hookOrder) do
        local fn = self.hooks[name]
        if fn then
            pcall(fn, self, s)
        end
    end

    for _, name in ipairs(self.modOrder) do
        local m = self.mods[name]
        if m and m.on and m.player then
            pcall(m.player, m.state, self, s)
        end
    end

    self.stats.drawn = self.stats.drawn + 1
end

function ESP:_arrow(s)
    local root = s.cfg or self.cfg
    local cfg = root.arrow
    if not cfg.on or not cam then
        return
    end
    if root.team and s.ally then
        return
    end
    local vp = cam.ViewportSize
    if s.depth > 0 and s.bx and s.bx + s.bw > 0 and s.by + s.bh > 0 and s.bx < vp.X and s.by < vp.Y then
        return
    end
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local sx, sy = s.sx, s.sy
    if s.depth < 0 then
        sx, sy = vp.X - sx, vp.Y - sy
    end
    local dx, dy = sx - cx, sy - cy
    local len = sqrt(dx * dx + dy * dy)
    if len <= 0 then
        return
    end
    dx, dy = dx / len, dy / len
    local rad = min(cfg.rad, cfg.rad * cfg.scale * (500 / max(s.dist, 1)))
    local ax, ay = cx + dx * rad, cy + dy * rad
    local rot = atan2(dy, dx)
    local c = root.rainbow and hue(self.t * 0.12) or cfg.col
    local sz = cfg.size
    if cfg.fill then
        if cfg.outline then
            local os = sz + 2
            self.pool:tri("ao" .. s.uid, ax, ay, ax - cos(rot + 0.5) * os, ay - sin(rot + 0.5) * os, ax - cos(rot - 0.5) * os, ay - sin(rot - 0.5) * os, BLACK, cfg.a)
        end
        self.pool:tri("ar" .. s.uid, ax, ay, ax - cos(rot + 0.5) * sz, ay - sin(rot + 0.5) * sz, ax - cos(rot - 0.5) * sz, ay - sin(rot - 0.5) * sz, c, cfg.a)
    else
        self.pool:line("ar1" .. s.uid, ax, ay, ax - cos(rot + 0.5) * sz, ay - sin(rot + 0.5) * sz, c, 2, cfg.a)
        self.pool:line("ar2" .. s.uid, ax, ay, ax - cos(rot - 0.5) * sz, ay - sin(rot - 0.5) * sz, c, 2, cfg.a)
    end
    if cfg.dist then
        self.pool:txt("ard" .. s.uid, mstr(s.dist), ax, ay + sz + 2, 10, c, true, FONT, true, cfg.a)
    end
end

function ESP:_radar()
    self._dragRects.radar = nil
    local cfg = self.cfg.radar
    if not cfg.on or not cam then
        return
    end
    local my = lp.Character
    local root = my and my:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local cx, cy, r = cfg.x + cfg.r, cfg.y + cfg.r, cfg.r
    self._dragRects.radar = { x = cfg.x, y = cfg.y, w = r * 2, h = r * 2, z = 150 }
    if cfg.bg then
        self.pool:dot("rad_bg", cx, cy, r, BLACK, true, cfg.a, 48)
    end
    if cfg.grid then
        self.pool:line("rad_x", cx - r, cy, cx + r, cy, cfg.col, 1, 0.4)
        self.pool:line("rad_y", cx, cy - r, cx, cy + r, cfg.col, 1, 0.4)
    end
    if cfg.grid or cfg.ringLabels ~= false then
        self.pool:dot("rad_mid", cx, cy, r * 0.5, cfg.col, false, 0.3, 32, nil, 1)
    end
    if cfg.border then
        self.pool:dot("rad_bo", cx, cy, r, cfg.col, false, 0.9, 48, nil, 1)
    end
    if cfg.ringLabels ~= false then
        local ls = cfg.size or 11
        self.pool:txt("rad_rl0", floor(cfg.range) .. "m", cx, cy - r + 1, ls, cfg.col, true, FONT, true)
        self.pool:txt("rad_rl1", floor(cfg.range * 0.5) .. "m", cx, cy - r * 0.5 + 1, ls, cfg.col, true, FONT, true)
    end
    self.pool:dot("rad_me", cx, cy, cfg.blip + 1, cfg.selfCol, true, 1, 10)

    local look = cam.CFrame.LookVector
    local yaw = cfg.rot and atan2(look.X, look.Z) or 0
    local co, si = cos(-yaw), sin(-yaw)
    local n = 0

    for i = 1, #self.snap do
        if n >= cfg.max then
            break
        end
        local s = self.snap[i]
        if not s.npc and (cfg.allies or not s.ally) then
            local rel = s.root.Position - root.Position
            local dx, dz = rel.X, rel.Z
            local dist = sqrt(dx * dx + dz * dz)
            if dist <= cfg.range then
                local rx = dx * co - dz * si
                local rz = dx * si + dz * co
                local px = cx + clamp(rx / cfg.range, -1, 1) * r
                local py = cy - clamp(rz / cfg.range, -1, 1) * r
                local c = s.friend and cfg.friend or (s.ally and cfg.ally or (s.teamCol or cfg.enemy))
                n = n + 1
                self.pool:dot("rad_p" .. n, px, py, cfg.blip, c, true, 1, 10)
                if cfg.names then
                    self.pool:txt("rad_n" .. n, s.plr.DisplayName, px + 5, py - cfg.size * 0.5, cfg.size, c, false, FONT, true)
                end
            end
        end
    end
end

function ESP:_pick()
    self.target = nil
    local cfg = self.cfg.target
    if not cfg.on or not cam then
        return
    end
    local vp = cam.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    if type(self.targetSrc) == "function" then
        local ok, source = pcall(self.targetSrc)
        if ok and source then
            for i = 1, #self.snap do
                local s = self.snap[i]
                if s == source or s.char == source or s.plr == source then
                    self.target = s
                    return
                end
            end
        end
    end
    local best, score = nil, huge
    for i = 1, #self.snap do
        local s = self.snap[i]
        if not s.npc and s.bx and s.on and s.depth > 0 and (self.cfg.espRange <= 0 or s.dist <= self.cfg.espRange) then
            if (cfg.allies or not s.ally) and (cfg.friends or not s.friend) and (not cfg.visOnly or s.vis ~= false) then
                local tx = s.bx + s.bw * 0.5
                local ty = s.by + s.bh * 0.5
                local dx, dy = tx - cx, ty - cy
                local d = sqrt(dx * dx + dy * dy)
                if d < score and d <= cfg.fov then
                    score = d
                    best = s
                end
            end
        end
    end
    self.target = best
end

function ESP:_target()
    local cfg = self.cfg.target
    if not cfg.on or not cam then
        return
    end
    local vp = cam.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    if cfg.showFov then
        self.pool:dot("tg_fov", cx, cy, cfg.fov, cfg.col, false, 0.4, 64, nil, cfg.w)
    end
    local s = self.target
    if not s then
        return
    end
    if cfg.card then
        local info
        if type(self.targetInfo) == "function" then
            local ok, value = pcall(self.targetInfo, s)
            if ok and value then info = tostring(value) end
        end
        local name = s.plr and (s.plr.DisplayName .. "  @" .. s.plr.Name) or s.name or "TARGET"
        local text = name .. "\n" .. tostring(floor(s.hp + 0.5)) .. "/" .. tostring(floor(s.maxHp + 0.5)) .. " HP  |  " .. mstr(s.dist)
        if info and info ~= "" then text = text .. "\n" .. info end
        local lines = 2
        for _ in text:gmatch("\n") do lines = lines + 1 end
        local cw, ch = 280, lines * 15 + 14
        local cardX, cardY = vp.X - cw - 18, 70
        self.pool:box("tg_cb", cardX, cardY, cw, ch, BLACK, true, 1, 0.72, 80)
        self.pool:box("tg_co", cardX, cardY, cw, ch, cfg.col, false, 1, 0.9, 81)
        self.pool:txt("tg_ct", text, cardX + 9, cardY + 7, 12, cfg.col, false, FONT, true, 1, 82)
    end
    if not s.bx then
        return
    end
    local c = s.friend and cfg.friend or (s.ally and cfg.ally or cfg.col)
    local x, y, w, h = s.bx - cfg.pad, s.by - cfg.pad, s.bw + cfg.pad * 2, s.bh + cfg.pad * 2
    local mx, my = x + w * 0.5, y + h * 0.5
    if cfg.brackets then
        self:_segs("tg", cornerSegs(x, y, w, h, min(w, h) * 0.22), c, cfg.w, 1, cfg.outline, 0.85, 20, 21)
    end
    if cfg.line then
        if cfg.outline then
            self.pool:line("tg_so", cx, cy, mx, my, BLACK, cfg.w + 1, 0.85, 20)
        end
        self.pool:line("tg_s", cx, cy, mx, my, c, cfg.w, 1, 21)
    end
    if cfg.label then
        local txt = s.plr and s.plr.DisplayName or s.name
        if cfg.dist then
            txt = txt .. " [" .. mstr(s.dist) .. "]"
        end
        if cfg.hp and s.maxHp > 0 then
            txt = txt .. " " .. pctstr(s.hpPct)
        end
        self.pool:txt("tg_t", txt, mx, y - 15, 12, c, true, FONT, true, 1, 22)
    end
end

function ESP:_threat()
    local cfg = self.cfg.threat
    local s = self.target
    if not cfg.on or not s or s.npc or not s.plr or not cam then
        return
    end
    if cfg.visOnly and s.vis == false then
        return
    end
    local vp = cam.ViewportSize
    local cx = vp.X * 0.5
    local txt = "THREAT  " .. s.plr.DisplayName
    if cfg.dist then
        txt = txt .. "  " .. mstr(s.dist)
    end
    if cfg.hp and s.maxHp > 0 then
        txt = txt .. "  " .. pctstr(s.hpPct)
    end
    local w = max(180, fontSizeWidth(txt, cfg.size) + 12)
    if cfg.bg then
        self.pool:box("thr_bg", cx - w * 0.5 - 8, cfg.y - 4, w + 16, cfg.size + 9, BLACK, true, 1, cfg.a, 90)
        self.pool:box("thr_bd", cx - w * 0.5 - 8, cfg.y - 4, w + 16, cfg.size + 9, cfg.col, false, 1, 0.7, 91)
    end
    self.pool:txt("thr_t", txt, cx, cfg.y, cfg.size, cfg.col, true, FONT, true, 1, 92)
end

function ESP:_list()
    self._dragRects.list = nil
    local cfg = self.cfg.list
    if not cfg.on then
        return
    end
    local titleH = cfg.title and 18 or 0
    local h = titleH + cfg.row * cfg.max + 8
    self._dragRects.list = { x = cfg.x, y = cfg.y, w = cfg.w, h = h, z = 140 }
    if cfg.bg then
        self.pool:box("lst_bg", cfg.x, cfg.y, cfg.w, h, BLACK, true, 1, cfg.a, 60)
        self.pool:box("lst_bd", cfg.x, cfg.y, cfg.w, h, cfg.enemy, false, 1, 0.65, 61)
    end
    if cfg.title then
        local t = "PLAYERS " .. tostring(self.stats.roster)
        if self.target and not self.target.npc and self.target.plr then
            t = t .. "  TARGET: " .. self.target.plr.DisplayName
        end
        self.pool:txt("lst_title", t, cfg.x + 6, cfg.y + 3, 11, cfg.col, false, FONT, true, 1, 62)
    end
    local y0 = cfg.y + titleH + 4
    local n = 0
    for i = 1, #self.snap do
        if n >= cfg.max then
            break
        end
        local s = self.snap[i]
        if not s.npc and (cfg.allies or not s.ally) then
            n = n + 1
            local y = y0 + (n - 1) * cfg.row
            local c = s.friend and cfg.friend or (s.ally and cfg.ally or (s.teamCol or cfg.enemy))
            local hpC = col(cfg.low, c):Lerp(col(cfg.full, c), s.hpPct)
            if cfg.bg then
                self.pool:box("lst_r" .. n, cfg.x + 4, y, cfg.w - 8, cfg.row - 2, c3(0.09, 0.09, 0.11), true, 1, 0.4, 61)
            end
            self.pool:dot("lst_d" .. n, cfg.x + 10, y + cfg.row * 0.5 - 1, 2.5, c, true, 1, 10)
            local name = s.plr.DisplayName
            if cfg.idx then name = tostring(n) .. ". " .. name end
            if s.friend then name = name .. " [F]" end
            if cfg.vis and s.vis ~= nil then name = name .. (s.vis and " [V]" or " [H]") end
            self.pool:txt("lst_n" .. n, name, cfg.x + 17, y + 1, 10, cfg.col, false, FONT, true, 1, 62)
            if cfg.dist then
                self.pool:txt("lst_m" .. n, mstr(s.dist), cfg.x + cfg.w - 40, y + 1, 10, c, false, FONT, true, 1, 62)
            end
            if cfg.hp then
                self.pool:box("lst_hg" .. n, cfg.x + 17, y + cfg.row - 4, cfg.w - 58, 2, c3(0.15, 0.15, 0.18), true, 1, 0.9, 62)
                self.pool:box("lst_hp" .. n, cfg.x + 17, y + cfg.row - 4, (cfg.w - 58) * s.hpPct, 2, hpC, true, 1, 1, 63)
            end
        end
    end
end

function ESP:_self()
    self._dragRects.wm = nil
    if not cam then
        return
    end
    local vp = cam.ViewportSize
    local s = self.cfg.self

    if s.fov.on then
        local c = s.fov.rainbow and hue(self.t * 0.2) or s.fov.col
        self.pool:dot("sfov", vp.X * 0.5, vp.Y * 0.5, s.fov.rad, c, false, s.fov.a, s.fov.sides, nil, s.fov.w)
        if s.fov.fill then
            self.pool:dot("sfovf", vp.X * 0.5, vp.Y * 0.5, s.fov.rad, c, true, s.fov.fillA, s.fov.sides)
        end
    end

    if s.cross.on then
        local c = s.cross.rainbow and hue(self.t * 0.22) or s.cross.col
        local cx, cy = vp.X * 0.5, vp.Y * 0.5
        local g, l = s.cross.gap, s.cross.len
        self:_segs("x", {
            cx - g - l, cy, cx - g, cy,
            cx + g, cy, cx + g + l, cy,
            cx, cy - g - l, cx, cy - g,
            cx, cy + g, cx, cy + g + l,
        }, c, s.cross.w, s.cross.a, s.cross.outline)
        if s.cross.dot then
            self.pool:dot("xd", cx, cy, s.cross.dotSize, c, true, s.cross.a, 10)
        end
    end

    if s.wm.on then
        local txt = self:_wmText()
        local w = fontSizeWidth(txt, s.wm.size) + 10
        self._dragRects.wm = { x = s.wm.x - 4, y = s.wm.y - 3, w = w, h = s.wm.size + 8, z = 160 }
        if s.wm.bg then
            self.pool:box("wm_bg", s.wm.x - 4, s.wm.y - 3, w, s.wm.size + 8, BLACK, true, 1, s.wm.a)
            self.pool:box("wm_ac", s.wm.x - 4, s.wm.y - 3, 2, s.wm.size + 8, s.wm.accent, true, 1, 1)
        end
        self.pool:txt("wm_t", txt, s.wm.x, s.wm.y, s.wm.size, s.wm.col, false, FONT, true)
    end

    if s.compass.on and cam then
        local c = s.compass
        local cx = vp.X * 0.5
        local y = c.y
        local half = c.w * 0.5
        local look = cam.CFrame.LookVector
        local heading = (atan2(look.X, look.Z) * 180 / pi + 360) % 360
        self.pool:line("cmp_b", cx - half, y, cx + half, y, c.col, 1, c.a * 0.35)
        local n = 0
        for d = 0, 345, 15 do
            local delta = ((d - heading + 540) % 360) - 180
            local x = cx + delta * c.scale
            if x >= cx - half and x <= cx + half then
                n = n + 1
                local major = d % 90 == 0
                local tall = major and 8 or 4
                local cc = major and c.accent or c.col
                self.pool:line("cmp_t" .. n, x, y - tall, x, y + tall, cc, major and 2 or 1, c.a)
                if major then
                    local label = d == 0 and "N" or d == 90 and "E" or d == 180 and "S" or "W"
                    self.pool:txt("cmp_l" .. n, label, x, y + 9, c.size, cc, true, FONT, true, c.a)
                end
            end
        end
        if c.bearing then
            self.pool:txt("cmp_deg", tostring(floor(heading + 0.5)) .. "°", cx, y - c.size - 9, c.size, c.accent, true, FONT, true, c.a)
        end
    end

    for id, spec in pairs(self.rings) do
        local p = self:center(spec.at)
        if typeof(p) == "Instance" then
            p = self:center(p)
        end
        if p then
            self:_ring("sr" .. tostring(id), p + v3(0, spec.y or 0, 0), spec, 0)
        end
    end
end

function ESP:_ents()
    if not cam then
        return
    end
    local entityStep = max(1, tonumber(self.cfg.perf.entityStep) or 3)
    if self.frame % entityStep ~= 0 then
        self.pool:carry("ent")
        return
    end
    local eye = cam.CFrame.Position
    local vp = cam.ViewportSize

    local function drawOne(id, e, obj)
        local pos, size, pivot
        local kind = typeof(obj)
        if kind == "Vector3" then
            pos = obj
            size = e.size or v3(3, 4, 3)
            pivot = cf(pos)
        elseif kind == "Instance" then
            if obj:IsA("BasePart") then
                pos = obj.Position
                size = obj.Size
                pivot = obj.CFrame
            elseif obj:IsA("Model") then
                pivot, size = obj:GetBoundingBox()
                pos = pivot.Position
            end
        end
        if not (pos and size and pivot) then return end
        local dist = (eye - pos).Magnitude
        local emax = e.max or self.cfg.maxRange
        if emax > 0 and dist > emax then return end
        local _, _, d, on = self._proj(pos)
        if not on or d <= 0 then return end
        local lx, ly, bw, bh = box2d(pivot, size, self._proj)
        if not lx then return end
        if e.box then
            if e.outline ~= false then
                self.pool:box("ent_b0" .. id, lx - 1, ly - 1, bw + 2, bh + 2, BLACK, false, 2, 1)
            end
            self.pool:box("ent_b1" .. id, lx, ly, bw, bh, e.col, false, 1, 1)
        end
        if e.dot then
            self.pool:dot("ent_d" .. id, lx + bw * 0.5, ly + bh, 3, e.col, true, 1, 12)
        end
        if e.name and e.label then
            local ok, label = true, e.label
            if type(e.label) == "function" then
                ok, label = pcall(e.label, obj)
            end
            if ok and label and label ~= "" then
                self.pool:txt("ent_n" .. id, tostring(label), lx + bw * 0.5, ly - 16, 12, e.col, true, FONT, true)
            end
        end
        if e.dist then
            self.pool:txt("ent_m" .. id, mstr(dist), lx + bw * 0.5, ly + bh + 3, 10, e.col, true, FONT, true)
        end
        if e.tracer then
            self.pool:line("ent_t" .. id, vp.X * 0.5, vp.Y, lx + bw * 0.5, ly + bh, e.col, 1, 1)
        end
        if e.ring then
            self:_ring("ent_r" .. id, pos - v3(0, size.Y * 0.5, 0), e.ring, 0)
        end
        if e.draw then
            pcall(e.draw, self, id, obj, pos, lx, ly, bw, bh, dist)
        end
    end

    local pri = self.cfg.priority
    for id, e in pairs(self.ents) do
        self.pool.zbias = pri and ((e.priority or pri.entity or 1) * (pri.scale or 100)) or 0
        local ok, obj = pcall(e.get)
        if ok and obj then
            if typeof(obj) == "table" then
                for i = 1, #obj do
                    drawOne(id .. "_" .. i, e, obj[i])
                end
            else
                drawOne(id, e, obj)
            end
        end
    end
    self.pool.zbias = 0
end

function ESP:_clearCham(r)
    if r.cham then
        pcall(function()
            r.cham.Enabled = false
            r.cham:Destroy()
        end)
        r.cham = nil
    end
    if r.mat then
        for part, old in pairs(r.mat) do
            if part and part.Parent then
                part.Material = old[1]
                part.Color = old[2]
                part.Transparency = old[3]
            end
        end
        r.mat = nil
        r.matKind = nil
    end
    r.matAt = nil
end

function ESP:_cham(s)
    local cfg = (s.cfg or self.cfg).chams
    local r = s.rec
    if not cfg.on then
        self:_clearCham(r)
        return
    end
    if cfg.team and s.ally then
        self:_clearCham(r)
        return
    end
    local c = cfg.fillCol
    local line = cfg.lineCol
    if cfg.tint and s.vis ~= nil then
        c = s.vis and cfg.vis or cfg.hid
        line = c
    elseif cfg.rainbow then
        c = hue(self.t * cfg.rate * 0.12 + s.uid * 0.01)
        line = c
    end
    if cfg.mode == "material" then
        if r.cham then
            pcall(function()
                r.cham:Destroy()
            end)
            r.cham = nil
        end
        local ok, mat = pcall(function()
            return Enum.Material[cfg.mat]
        end)
        mat = ok and mat or Enum.Material.ForceField
        if r.matKind ~= cfg.mat then
            self:_clearCham(r)
            r.matKind = cfg.mat
        end
        if r.mat and r.matAt and self.frame - r.matAt < max(1, tonumber(self.cfg.perf.toolStep) or 14) then
            for part in pairs(r.mat) do
                if part.Parent then
                    part.Color = c
                end
            end
            return
        end
        r.matAt = self.frame
        local map = r.mat or setmetatable({}, { __mode = "k" })
        r.mat = map
        for _, part in ipairs(s.char:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HumanoidRootPart" and (part.Name ~= "Head" or cfg.matHead) then
                if not map[part] then
                    map[part] = { part.Material, part.Color, part.Transparency }
                end
                part.Material = mat
                part.Color = c
                part.Transparency = clamp(cfg.matA, 0, 0.95)
            end
        end
    else
        if r.mat then
            self:_clearCham(r)
        end
        local h = r.cham
        if not h or h.Parent ~= s.char then
            if h then
                pcall(function()
                    h:Destroy()
                end)
            end
            h = Instance.new("Highlight")
            h.Name = "easyesp"
            h.Adornee = s.char
            h.Parent = s.char
            r.cham = h
        end
        h.Enabled = true
        h.FillColor = c
        h.FillTransparency = cfg.fill and cfg.fillA or 1
        h.OutlineColor = line
        h.OutlineTransparency = cfg.line and cfg.lineA or 1
        h.DepthMode = cfg.depth == "occluded" and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
    end
end

function ESP:_worldSnap()
    if self.world0 or not cam then
        return
    end
    self.world0 = {
        Light.Brightness,
        Light.Ambient,
        Light.OutdoorAmbient,
        Light.ExposureCompensation,
        Light.FogEnd,
        cam.FieldOfView,
    }
end

function ESP:_worldRestore()
    local s = self.world0
    if not s then
        return
    end
    Light.Brightness = s[1]
    Light.Ambient = s[2]
    Light.OutdoorAmbient = s[3]
    Light.ExposureCompensation = s[4]
    Light.FogEnd = s[5]
    if cam then
        cam.FieldOfView = s[6]
    end
    local g = Light:FindFirstChild("easyesp_cc")
    if g then
        g:Destroy()
    end
    self.world0 = nil
end

function ESP:_world()
    if not cam then
        return
    end
    local w = self.cfg.world
    if not w.on then
        if self.world0 then
            self:_worldRestore()
        end
        return
    end
    self:_worldSnap()
    Light.Brightness = w.full and 3 or w.bright
    Light.Ambient = w.amb
    Light.OutdoorAmbient = w.out
    Light.ExposureCompensation = w.exp
    cam.FieldOfView = w.fov
    Light.FogEnd = w.noFog and 1e7 or self.world0[5]
    local g = Light:FindFirstChild("easyesp_cc")
    if not g then
        g = Instance.new("ColorCorrectionEffect")
        g.Name = "easyesp_cc"
        g.Parent = Light
    end
    g.Enabled = w.grade
    g.Saturation = w.sat
    g.Contrast = w.con
end

function ESP:tick(dt)
    if not cam then
        return
    end

    self._fa = self._fa + dt
    self._fc = self._fc + 1
    if self._fa >= 0.45 then
        self.stats.fps = floor(self._fc / self._fa + 0.5)
        self.stats.fpsAvg = self.stats.fpsAvg * 0.7 + self.stats.fps * 0.3
        self._fa = 0
        self._fc = 0
    end

    if not self.cfg.on then
        if not self._idled then
            self._idled = true
            self.pool:begin()
            self.pool:reset()
            self.pool:finish()
            if self.world0 then
                self:_worldRestore()
            end
            for _, r in pairs(self.recs) do
                self:_clearCham(r)
            end
            for _, r in pairs(self.npcRecs) do
                self:_clearCham(r)
            end
        end
        return
    end
    self._idled = false

    self.t = self.t + dt
    self._ticks = (self._ticks or 0) + 1

    if self.cfg.perf.frameSkip > 0 and (self._ticks % (self.cfg.perf.frameSkip + 1)) ~= 0 then
        return
    end

    self.frame = self.frame + 1

    self.pool:begin()
    self.stats.drawn = 0

    self:_world()
    self:_snap()
    self:_pick()

    for _, name in ipairs(self.modOrder) do
        local m = self.mods[name]
        if m and m.on and m.world then
            pcall(m.world, m.state, self)
        end
    end

    local npcFrameSkip = max(1, tonumber(self.cfg.perf.npcFrameSkip) or 2)
    for i = 1, #self.snap do
        local s = self.snap[i]
        if not s.npc or self.frame % npcFrameSkip == 0 then self:_cham(s) end
    end

    self:_ents()

    local pri = self.cfg.priority
    local scale = pri and (pri.scale or 100) or 0
    self.pool.zbias = pri and ((pri.hud or 9) * scale) or 0
    self:_radar()

    for i = 1, #self.snap do
        local s = self.snap[i]
        self.pool.zbias = pri and ((s.npc and (pri.walker or 4) or (pri.player or 5)) * scale) or 0
        self:_player(s)
    end

    self.pool.zbias = pri and ((pri.hud or 9) * scale) or 0
    if self.cfg.arrow.on or self.cfg.npc.arrow.on then
        for i = 1, #self.snap do
            self:_arrow(self.snap[i])
        end
    end

    self:_target()
    self:_threat()
    self:_list()
    self:_self()
    self.pool.zbias = 0

    for _, name in ipairs(self.modOrder) do
        local m = self.mods[name]
        if m and m.on and m.screen then
            pcall(m.screen, m.state, self)
        end
    end

    self.pool:finish()

    local p = self.cfg.perf
    if p.pruneAfter > 0 and self.frame % max(1, p.pruneEvery) == 0 then
        self.pool:prune(p.pruneAfter)
    end

    self.stats.pool = self.pool.size
end

function ESP:start()
    if self.running then
        return self
    end
    self.running = true
    self.loop = Run.RenderStepped:Connect(function(dt)
        local ok,err=pcall(self.tick,self,dt)
        if not ok then
            self._tickErrors=(self._tickErrors or 0)+1
            if self._tickErrors==1 then warn("[EasyESP]",err) end
            self.pool:finish()
        else
            self._tickErrors=0
        end
    end)
    return self
end

function ESP:stop()
    self.running = false
    self._drag = nil
    if self.loop then
        self.loop:Disconnect()
        self.loop = nil
    end
    self.pool:reset()
    if self.world0 then
        self:_worldRestore()
    end
    for _, r in pairs(self.recs) do
        self:_clearCham(r)
    end
    for _, r in pairs(self.npcRecs) do
        self:_clearCham(r)
    end
    return self
end

function ESP:destroy()
    local link = Runtime.bridge
    if link and link.esp == self and link.detach then
        pcall(function()
            link:detach()
        end)
    end
    pcall(function()
        CAS:UnbindAction(self._casAction)
    end)
    self:stop()
    self:clearBinds()
    if Runtime.esp == self then
        Runtime.esp = nil
    end
    for i = #active, 1, -1 do
        if active[i] == self then
            remove(active, i)
        end
    end
    for i = #self.con, 1, -1 do
        local c = self.con[i]
        self.con[i] = nil
        if c then
            pcall(function()
                c:Disconnect()
            end)
        end
    end
    for _,r in pairs(self.recs) do
        if r.hpCon then r.hpCon:Disconnect() end
        if r.maxHpCon then r.maxHpCon:Disconnect() end
    end
    self.pool:nuke()
    self.recs = {}
    self.npcRecs = {}
    self.plrs = {}
    self.ents = {}
    self.rings = {}
    self.mods = {}
    self.modOrder = {}
    self.hooks = {}
    self.hookOrder = {}
    self.flags = {}
    self.flagEnabled = {}
    self.flagOrder = {}
    self.snap = {}
    self.friends = {}
    if #active == 0 and cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
end

function ESP:on(v)
    self.cfg.on = v and true or false
    return self
end

function ESP:setEnabled(v)
    return self:on(v)
end

function ESP:toggle()
    self.cfg.on = not self.cfg.on
    return self.cfg.on
end

function ESP:setNPCSource(fn)
    self.npcSrc = type(fn) == "function" and fn or nil
    return self
end

function ESP:setTargetSource(fn)
    self.targetSrc = type(fn) == "function" and fn or nil
    return self
end

function ESP:setTargetInfo(fn)
    self.targetInfo = type(fn) == "function" and fn or nil
    return self
end

function ESP:setNPCLabel(fn)
    self.npcLabel = type(fn) == "function" and fn or nil
    return self
end

function ESP:npc(v)
    self.cfg.npc.on = v and true or false
    return self
end

function ESP:theme(nameOrTbl)
    local t = type(nameOrTbl) == "table" and nameOrTbl or THEMES[nameOrTbl or "pastel"]
    if not t then
        return false
    end
    local cfg = self.cfg
    local a = col(t.accent, cfg.box.col)
    local good = col(t.good, cfg.box.hpFull)
    local bad = col(t.bad, cfg.box.hpLow)
    local text = col(t.text, cfg.name.col)
    local muted = col(t.muted, cfg.dist.col)
    local friend = col(t.friend, cfg.friendCol)
    local ink = col(t.ink, BLACK)

    cfg.friendCol = friend
    cfg.box.col = a
    cfg.box.fillCol = a
    cfg.box.hpFull = good
    cfg.box.hpLow = bad
    cfg.name.col = text
    cfg.dist.col = muted
    cfg.hp.full = good
    cfg.hp.low = bad
    cfg.flags.col = text
    cfg.bones.col = text
    cfg.head.col = text
    cfg.gaze.col = text
    cfg.tracer.col = a
    cfg.arrow.col = a
    cfg.radar.col = text
    cfg.radar.enemy = a
    cfg.radar.ally = good
    cfg.radar.friend = friend
    cfg.target.col = a
    cfg.target.friend = friend
    cfg.target.ally = good
    cfg.list.col = text
    cfg.list.enemy = a
    cfg.list.ally = good
    cfg.list.friend = friend
    cfg.list.low = bad
    cfg.list.full = good
    cfg.threat.col = bad
    cfg.self.fov.col = text
    cfg.self.cross.col = good
    cfg.self.wm.col = text
    cfg.self.wm.accent = a
    cfg.self.compass.col = text
    cfg.self.compass.accent = a
    cfg.chams.fillCol = a
    cfg.chams.lineCol = a
    cfg.chams.vis = good
    cfg.chams.hid = bad
    cfg.world.amb = ink
    cfg.world.out = ink
    if cfg.rings.specs[1] then
        cfg.rings.specs[1].col = a
    end

    local n = cfg.npc
    if n then
        n.friendCol = friend
        n.box.col = a
        n.box.fillCol = a
        n.box.hpFull = good
        n.box.hpLow = bad
        n.name.col = text
        n.dist.col = muted
        n.hp.full = good
        n.hp.low = bad
        n.flags.col = text
        n.bones.col = text
        n.head.col = text
        n.gaze.col = text
        n.tracer.col = a
        n.arrow.col = a
        n.chams.fillCol = a
        n.chams.lineCol = a
        n.chams.vis = good
        n.chams.hid = bad
        if n.rings.specs[1] then
            n.rings.specs[1].col = a
        end
    end
    return true
end

function ESP:applyTheme(nameOrTbl)
    return self:theme(nameOrTbl)
end

function ESP:profile(name)
    local p = PROFILES[name]
    if not p then
        return false
    end
    merge(self.cfg, deep(p))
    if p.perf and self.cfg.npc and self.cfg.npc.perf then
        merge(self.cfg.npc.perf, deep(p.perf))
    end
    fill(self.cfg, defaults())
    return true
end

function ESP:applyPerformance(name)
    return self:profile(name)
end

function ESP:pack(name)
    local p = PACKS[name]
    if not p then
        return false
    end
    merge(self.cfg, deep(p))
    local n = self.cfg.npc
    if n then
        for k, v in pairs(p) do
            if type(v) == "table" and type(n[k]) == "table" then
                merge(n[k], deep(v))
            end
        end
    end
    fill(self.cfg, defaults())
    return true
end

function ESP:applyFeaturePack(name)
    return self:pack(name)
end

function ESP:themes()
    local out = {}
    for k in pairs(THEMES) do
        out[#out + 1] = k
    end
    sort(out)
    return out
end

function ESP:performanceProfiles()
    local out = {}
    for k in pairs(PROFILES) do
        out[#out + 1] = k
    end
    sort(out)
    return out
end

function ESP:featurePacks()
    local out = {}
    for k in pairs(PACKS) do
        out[#out + 1] = k
    end
    sort(out)
    return out
end

function ESP:preset(name)
    local p = PRESETS[name]
    if not p then
        return false
    end
    if p.theme then
        self:theme(p.theme)
    end
    if p.profile then
        self:profile(p.profile)
    end
    if p.pack then
        self:pack(p.pack)
    end
    if p.extra then
        merge(self.cfg, deep(p.extra))
        fill(self.cfg, defaults())
    end
    return true
end

function ESP:applyPreset(name)
    return self:preset(name)
end

function ESP:presets()
    local out = {}
    for k in pairs(PRESETS) do
        out[#out + 1] = k
    end
    sort(out)
    return out
end

local function getDescriptors(prefix)
    local out = deep(DESCRIPTORS)
    if prefix and prefix ~= "" then
        for i = 1, #out do
            out[i].path = tostring(prefix) .. "." .. out[i].path
        end
    end
    return out
end

local function getDescriptorDefaults(prefix)
    local out = {}
    for i = 1, #DESCRIPTORS do
        local d = DESCRIPTORS[i]
        local key = prefix and prefix ~= "" and (tostring(prefix) .. "." .. d.path) or d.path
        out[key] = deep(d.default)
    end
    return out
end

local function getDescriptor(path)
    local d = descLookup(path)
    return d and deep(d) or nil
end

local function validateDescriptor(path, value)
    local d = descLookup(path)
    if not d then return value end
    if d.kind == "toggle" then
        return value and true or false
    elseif d.kind == "slider" or d.kind == "number" then
        local n = tonumber(value) or d.default or 0
        if d.min ~= nil then n = max(d.min, n) end
        if d.max ~= nil then n = min(d.max, n) end
        if d.step and d.step > 0 then
            local base = d.min or 0
            n = floor((n - base) / d.step + 0.5) * d.step + base
        end
        return n
    elseif d.kind == "dropdown" or d.kind == "mode" then
        local s = tostring(value)
        for _, item in ipairs(d.items or {}) do
            if tostring(item) == s then return s end
        end
        return d.default
    elseif d.kind == "color" then
        return col(value, d.default)
    elseif d.kind == "keybind" then
        return typeof(value) == "EnumItem" and value or d.default
    end
    return value
end

local function argOf(a, b)
    if type(a) == "table" then
        return b
    end
    return a
end

function ESP.GetDescriptors(selfOrPrefix, prefix)
    return getDescriptors(argOf(selfOrPrefix, prefix))
end

function ESP.GetDescriptorDefaults(selfOrPrefix, prefix)
    return getDescriptorDefaults(argOf(selfOrPrefix, prefix))
end

function ESP.GetDescriptor(selfOrPath, path)
    return getDescriptor(argOf(selfOrPath, path))
end

function ESP.Validate(selfOrPath, path, value)
    if type(selfOrPath) == "table" then
        return validateDescriptor(path, value)
    end
    return validateDescriptor(selfOrPath, path)
end

function ESP:flag(name, fn)
    if not self.flags[name] then
        insert(self.flagOrder, name)
    end
    self.flags[name] = fn
    if self.flagEnabled[name] == nil then
        self.flagEnabled[name] = true
    end
    return fn
end

function ESP:setFlagEnabled(name, on)
    self.flagEnabled[name] = not not on
    return self
end

function ESP:dropFlag(name)
    self.flags[name] = nil
    self.flagEnabled[name] = nil
    for i = #self.flagOrder, 1, -1 do
        if self.flagOrder[i] == name then
            remove(self.flagOrder, i)
            break
        end
    end
end

function ESP:hook(name, fn)
    if not self.hooks[name] then
        insert(self.hookOrder, name)
    end
    self.hooks[name] = fn
    return fn
end

function ESP:unhook(name)
    self.hooks[name] = nil
    for i = #self.hookOrder, 1, -1 do
        if self.hookOrder[i] == name then
            remove(self.hookOrder, i)
            break
        end
    end
end

function ESP:mod(spec)
    assert(spec and spec.name, "module needs a name")
    if not self.mods[spec.name] then
        insert(self.modOrder, spec.name)
    elseif self.mods[spec.name].down then
        pcall(self.mods[spec.name].down, self.mods[spec.name].state, self)
    end
    local m = {
        name = spec.name,
        on = spec.on == true,
        state = spec.state or {},
        up = spec.up,
        down = spec.down,
        player = spec.player,
        world = spec.world,
        screen = spec.screen,
    }
    m.state.esp = self
    self.mods[spec.name] = m
    if m.up then
        pcall(m.up, m.state, self)
    end
    return m
end

function ESP:module(name)
    return self.mods[name]
end

function ESP:toggleMod(name, on)
    local m = self.mods[name]
    if m then
        m.on = on == nil and not m.on or on
    end
end

function ESP:dropMod(name)
    local m = self.mods[name]
    if not m then
        return
    end
    if m.down then
        pcall(m.down, m.state, self)
    end
    self.mods[name] = nil
    for i = #self.modOrder, 1, -1 do
        if self.modOrder[i] == name then
            remove(self.modOrder, i)
            break
        end
    end
end

function ESP:friend(x)
    local uid = userIdOf(x)
    if uid then
        self.friends[uid] = true
    end
end

function ESP:markFriend(x)
    self:friend(x)
end

function ESP:unfriend(x)
    local uid = userIdOf(x)
    if uid then
        self.friends[uid] = nil
    end
end

function ESP:unmarkFriend(x)
    self:unfriend(x)
end

function ESP:clearFriends()
    for k in pairs(self.friends) do
        self.friends[k] = nil
    end
end

function ESP:isFriend(x)
    return self:_friend(x)
end

function ESP:center(x)
    if x == nil then
        local my = lp.Character
        local root = my and my:FindFirstChild("HumanoidRootPart")
        local hum = my and my:FindFirstChildOfClass("Humanoid")
        return root and feet(root, hum) or nil
    end
    local t = typeof(x)
    if t == "Vector3" then
        return x
    elseif t == "function" then
        return x()
    elseif t == "Instance" then
        if x:IsA("Player") then
            local char = x.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            return root and feet(root, hum) or nil
        elseif x:IsA("BasePart") then
            return x.Position - v3(0, x.Size.Y * 0.5, 0)
        elseif x:IsA("Model") then
            local p = x.PrimaryPart or x:FindFirstChildWhichIsA("BasePart")
            return p and p.Position or nil
        end
    end
end

function ESP:addRing(id, spec)
    spec = ringSpec(spec or {})
    self.rings[id] = spec
    return spec
end

function ESP:dropRing(id)
    self.rings[id] = nil
end

function ESP:clearRings()
    self.rings = {}
end

function ESP:addRingSpec(spec)
    local s = ringSpec(spec or {})
    insert(self.cfg.rings.specs, s)
    return s
end

function ESP:dropRingSpec(i)
    remove(self.cfg.rings.specs, i or #self.cfg.rings.specs)
end

function ESP:clearRingSpecs()
    self.cfg.rings.specs = {}
end

function ESP:addEnt(id, spec)
    assert(spec and spec.get, "entity needs get()")
    spec.col = col(spec.col, self.cfg.box.col)
    spec.box = spec.box ~= false
    spec.name = spec.name ~= false
    spec.dist = spec.dist ~= false
    if spec.ring then
        spec.ring = ringSpec(spec.ring)
    end
    self.ents[id] = spec
    return spec
end

function ESP:addEntity(id, spec)
    return self:addEnt(id, spec)
end

function ESP:dropEnt(id)
    self.ents[id] = nil
end

function ESP:removeEntity(id)
    self:dropEnt(id)
end

function ESP:addInst(id, inst, opt)
    opt = opt or {}
    local key = id
    if self.ents[key] and typeof(inst) == "Instance" and inst.GetDebugId then
        local ok, gid = pcall(function() return inst:GetDebugId() end)
        if ok and gid then
            key = tostring(id) .. "_" .. tostring(gid)
        else
            key = tostring(id) .. "_" .. tostring(floor(os.clock() * 1000000))
        end
    end
    return self:addEnt(key, {
        get = function()
            return inst and inst.Parent and inst or nil
        end,
        label = opt.label or (inst and inst.Name) or tostring(id),
        col = opt.col or self.cfg.box.col,
        box = opt.box ~= false,
        name = opt.name ~= false,
        dist = opt.dist ~= false,
        tracer = opt.tracer == true,
        dot = opt.dot == true,
        ring = opt.ring,
        size = opt.size,
        max = opt.max or self.cfg.maxRange,
        draw = opt.draw,
    })
end

function ESP:addInstanceEntity(id, inst, opt)
    return self:addInst(id, inst, opt)
end

function ESP:clearEnts(prefix)
    local n = 0
    if not prefix then
        for _ in pairs(self.ents) do
            n = n + 1
        end
        self.ents = {}
        return n
    end
    for id in pairs(self.ents) do
        if tostring(id):sub(1, #prefix) == prefix then
            self.ents[id] = nil
            n = n + 1
        end
    end
    return n
end

function ESP:clearEntities(prefix)
    return self:clearEnts(prefix)
end

function ESP:scan(root, spec)
    root = root or workspace
    spec = spec or {}
    local prefix = spec.prefix or "scan_"
    local limit = spec.limit or 80
    local onlyModels = spec.models == true
    local onlyParts = spec.parts == true
    local names = spec.names
    local classes = spec.classes
    if spec.clear ~= false then
        self:clearEnts(prefix)
    end
    local n = 0
    for _, inst in ipairs(root:GetDescendants()) do
        if n >= limit then
            break
        end
        local ok = false
        if names then
            local low = inst.Name:lower()
            for _, name in ipairs(names) do
                if low:find(tostring(name):lower(), 1, true) then
                    ok = true
                    break
                end
            end
        elseif classes then
            for _, className in ipairs(classes) do
                if inst:IsA(className) then
                    ok = true
                    break
                end
            end
        elseif onlyModels then
            ok = inst:IsA("Model")
        elseif onlyParts then
            ok = inst:IsA("BasePart")
        else
            ok = inst:IsA("Model")
        end
        if ok and (inst:IsA("Model") or inst:IsA("BasePart")) then
            n = n + 1
            self:addInst(prefix .. n, inst, {
                label = spec.label and (type(spec.label) == "function" and spec.label(inst) or spec.label) or inst.Name,
                col = spec.col or self.cfg.box.col,
                box = spec.box ~= false,
                name = spec.name ~= false,
                dist = spec.dist ~= false,
                tracer = spec.tracer == true,
                dot = spec.dot == true,
                ring = spec.ring,
                max = spec.max or self.cfg.maxRange,
            })
        end
    end
    return n
end

function ESP:scanInstances(root, spec)
    return self:scan(root, spec)
end

function ESP:scanNPCs(opt)
    opt = opt or {}
    local prefix = opt.prefix or "npc_"
    if opt.clear ~= false then
        self:clearEnts(prefix)
    end
    local n = 0
    for _, m in ipairs((opt.root or workspace):GetDescendants()) do
        if n >= (opt.limit or 40) then
            break
        end
        if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(m) then
            local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
            if root then
                n = n + 1
                self:addInst(prefix .. n, m, {
                    label = opt.label and (type(opt.label) == "function" and opt.label(m) or opt.label) or ("NPC: " .. m.Name),
                    col = opt.col or rgb(255, 135, 135),
                    box = opt.box ~= false,
                    name = opt.name ~= false,
                    dist = opt.dist ~= false,
                    tracer = opt.tracer == true,
                    dot = opt.dot == true,
                    ring = opt.ring,
                    max = opt.max or self.cfg.maxRange,
                })
            end
        end
    end
    return n
end

function ESP:scanTools(opt)
    opt = opt or {}
    local prefix = opt.prefix or "tool_"
    if opt.clear ~= false then
        self:clearEnts(prefix)
    end
    local n = 0
    for _, tool in ipairs((opt.root or workspace):GetDescendants()) do
        if n >= (opt.limit or 60) then
            break
        end
        if tool:IsA("Tool") then
            local h = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
            if h then
                n = n + 1
                self:addInst(prefix .. n, h, {
                    label = opt.label and (type(opt.label) == "function" and opt.label(tool) or opt.label) or ("Tool: " .. tool.Name),
                    col = opt.col or rgb(255, 220, 110),
                    box = opt.box ~= false,
                    name = opt.name ~= false,
                    dist = opt.dist ~= false,
                    tracer = opt.tracer == true,
                    dot = opt.dot == true,
                    ring = opt.ring,
                    max = opt.max or self.cfg.maxRange,
                })
            end
        end
    end
    return n
end

function ESP:scanPickups(opt)
    opt = opt or {}
    return self:scan(opt.root or workspace, {
        prefix = opt.prefix or "pickup_",
        limit = opt.limit or 80,
        names = opt.names or { "ammo", "coin", "cash", "drop", "pickup", "weapon", "med", "armor" },
        col = opt.col or rgb(120, 255, 190),
        box = opt.box ~= false,
        name = opt.name ~= false,
        dist = opt.dist ~= false,
        tracer = opt.tracer == true,
        dot = opt.dot == true,
        ring = opt.ring,
        max = opt.max or self.cfg.maxRange,
        clear = opt.clear,
    })
end

function ESP:bind(key, fn)
    local c = Input.InputBegan:Connect(function(i, gp)
        if gp then
            return
        end
        if i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode == key then
            pcall(fn, self)
        end
    end)
    insert(self.binds, c)
    return c
end

function ESP:clearBinds()
    local n = 0
    for i = #self.binds, 1, -1 do
        local c = self.binds[i]
        self.binds[i] = nil
        if c then
            pcall(function()
                c:Disconnect()
            end)
        end
        n = n + 1
    end
    return n
end

function ESP:nearest(maxRange, allies)
    local limit = maxRange or huge
    for i = 1, #self.snap do
        local s = self.snap[i]
        if s.plr and s.dist <= limit and (allies or not s.ally) then
            return s.plr
        end
    end
    return nil
end

function ESP:statsGet()
    return {
        fps = self.stats.fps,
        fpsAvg = self.stats.fpsAvg,
        drawn = self.stats.drawn,
        pool = self.pool.size,
        roster = self.stats.roster,
        target = self.target and self.target.plr and self.target.plr.DisplayName or self.target and self.target.name or nil,
        ents = (function()
            local n = 0
            for _ in pairs(self.ents) do
                n = n + 1
            end
            return n
        end)(),
        friends = (function()
            local n = 0
            for _ in pairs(self.friends) do
                n = n + 1
            end
            return n
        end)(),
    }
end

function ESP:getStats()
    return self:statsGet()
end

function ESP:export()
    local data = {
        ver = ESP.ver,
        cfg = pack(stripInsts(self.cfg)),
    }
    return Http:JSONEncode(data)
end

function ESP:import(str)
    local ok, data = pcall(function()
        return Http:JSONDecode(str)
    end)
    if not ok or type(data) ~= "table" or type(data.cfg) ~= "table" then
        return false
    end
    local nextCfg = unpack(data.cfg)
    if type(nextCfg) ~= "table" then
        return false
    end
    local base = defaults()
    fill(nextCfg, base)
    local function validShape(value, expected)
        if type(expected) ~= "table" then
            return typeof(value) == typeof(expected)
        end
        if type(value) ~= "table" then
            return false
        end
        for key, child in pairs(expected) do
            if not validShape(value[key], child) then
                return false
            end
        end
        return true
    end
    if not validShape(nextCfg, base) then
        return false
    end
    local cur = self.cfg or {}
    for k in pairs(cur) do
        cur[k] = nil
    end
    for k, v in pairs(nextCfg) do
        cur[k] = v
    end
    self.cfg = cur
    return true
end

function ESP:save(name)
    if type(writefile) ~= "function" then
        return false
    end
    local dir = "EasyESP4"
    if type(makefolder) == "function" then
        if type(isfolder) == "function" then
            if not isfolder(dir) then
                pcall(makefolder, dir)
            end
        else
            pcall(makefolder, dir)
        end
    end
    local ok, data = pcall(function()
        return self:export()
    end)
    if not ok then
        return false
    end
    return pcall(writefile, dir .. "/" .. cleanName(name) .. ".json", data)
end

function ESP:load(name)
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return false
    end
    local path = "EasyESP4/" .. cleanName(name) .. ".json"
    if not isfile(path) then
        return false
    end
    local ok, data = pcall(readfile, path)
    if not ok then
        return false
    end
    return self:import(data)
end

function ESP:configs()
    if type(isfolder) ~= "function" or type(listfiles) ~= "function" or not isfolder("EasyESP4") then
        return {}
    end
    local out = {}
    local ok, files = pcall(listfiles, "EasyESP4")
    if ok and type(files) == "table" then
        for _, path in ipairs(files) do
            local name = path:match("([^/\\]+)%.json$")
            if name then
                out[#out + 1] = name
            end
        end
    end
    sort(out)
    return out
end

function ESP:repair()
    fill(self.cfg, defaults())
    return self.cfg
end

function ESP:repairConfig()
    return self:repair()
end

function ESP:setAccent(c)
    self.cfg.box.col = col(c, self.cfg.box.col)
    self.cfg.box.fillCol = self.cfg.box.col
    self.cfg.tracer.col = self.cfg.box.col
    self.cfg.arrow.col = self.cfg.box.col
    self.cfg.radar.enemy = self.cfg.box.col
    self.cfg.target.col = self.cfg.box.col
    self.cfg.list.enemy = self.cfg.box.col
    self.cfg.self.wm.accent = self.cfg.box.col
    self.cfg.self.compass.accent = self.cfg.box.col
    if self.cfg.rings.specs[1] then
        self.cfg.rings.specs[1].col = self.cfg.box.col
    end
    return self.cfg.box.col
end

function ESP:project(pos)
    return self._proj(pos)
end

function ESP:sees(char, points)
    return self:_canSee(char, points or self.cfg.vis.points)
end

ESP.Descriptors = DESCRIPTORS
ESP.addFlag = ESP.flag
ESP.removeFlag = ESP.dropFlag
ESP.onDraw = ESP.hook
ESP.removeDraw = ESP.unhook
ESP.register = ESP.mod
ESP.toggleModule = ESP.toggleMod
ESP.unregister = ESP.dropMod
ESP.attachRing = ESP.addRing
ESP.detachRing = ESP.dropRing
ESP.GetStats = ESP.getStats
ESP.Start = ESP.start
ESP.Stop = ESP.stop
ESP.Destroy = ESP.destroy

function ESP.DestroyAll()
    for i = #active, 1, -1 do
        if active[i] then
            active[i]:destroy()
        end
    end
end

local Toolkit = {}
Toolkit.version = ESP.ver
Toolkit.themes = THEMES
Toolkit.profiles = PROFILES
Toolkit.packs = PACKS
Toolkit.presets = PRESETS
Toolkit.descriptors = DESCRIPTORS

function Toolkit.clone(x)
    return deep(x)
end

function Toolkit.merge(a, b)
    return merge(a, b)
end

function Toolkit.fill(a, b)
    return fill(a, b)
end

function Toolkit.color(r, g, b)
    return rgb(r or 255, g or 255, b or 255)
end

function Toolkit.hsv(h, s, v)
    return hsv(h or 0, s or 1, v or 1)
end

function Toolkit.ring(spec)
    return ringSpec(spec)
end

function Toolkit.flag(txt, c)
    return { tostring(txt), c }
end

function Toolkit.pathGet(t, path)
    local n = t
    for part in tostring(path):gmatch("[^%.]+") do
        if type(n) ~= "table" then
            return nil
        end
        n = n[part]
    end
    return n
end

function Toolkit.pathSet(t, path, value)
    local n = t
    local parts = {}
    for part in tostring(path):gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    for i = 1, #parts - 1 do
        local k = parts[i]
        if type(n[k]) ~= "table" then
            n[k] = {}
        end
        n = n[k]
    end
    n[parts[#parts]] = value
    return value
end

function Toolkit.pathToggle(t, path)
    return Toolkit.pathSet(t, path, not Toolkit.pathGet(t, path))
end

function Toolkit.findPlayer(q)
    q = tostring(q or ""):lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower():find(q, 1, true) or plr.DisplayName:lower():find(q, 1, true) then
            return plr
        end
    end
end

function Toolkit.scan(root, pred, limit)
    root = root or workspace
    limit = limit or 100
    local out = {}
    for _, inst in ipairs(root:GetDescendants()) do
        if #out >= limit then
            break
        end
        local ok, yes = pcall(pred, inst)
        if ok and yes then
            out[#out + 1] = inst
        end
    end
    return out
end

function Toolkit.applyTheme(esp, name)
    return esp:theme(name)
end

function Toolkit.applyProfile(esp, name)
    return esp:profile(name)
end

function Toolkit.applyPack(esp, name)
    return esp:pack(name)
end

function Toolkit.applyPreset(esp, name)
    return esp:preset(name)
end

function Toolkit.getDescriptors(prefix)
    return ESP.GetDescriptors(prefix)
end

function Toolkit.getDescriptorDefaults(prefix)
    return ESP.GetDescriptorDefaults(prefix)
end

function Toolkit.getDescriptor(path)
    return ESP.GetDescriptor(path)
end

function Toolkit.validate(path, value)
    return ESP.Validate(path, value)
end

local QUICK_KEYS = { theme = true, profile = true, pack = true, preset = true, on = true }

function Toolkit.quick(opt)
    opt = opt or {}
    local seed = {}
    for k, v in pairs(opt) do
        if not QUICK_KEYS[k] then
            seed[k] = v
        end
    end
    local esp = ESP.new(seed)
    if opt.theme then
        esp:theme(opt.theme)
    end
    if opt.profile then
        esp:profile(opt.profile)
    end
    if opt.pack then
        esp:pack(opt.pack)
    end
    if opt.preset then
        esp:preset(opt.preset)
    end
    esp:on(opt.on ~= false)
    return esp:start()
end

Toolkit.quickESP = Toolkit.quick

ESP.Toolkit = Toolkit
return ESP
