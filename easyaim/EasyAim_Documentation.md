# EasyAim

Single-file Roblox executor aim library (`EasyAim.luau`, version `1.0.0`). It provides target selection, hitbox resolution, prediction, legit smoothing, rage snapping, silent-aim position resolution, a triggerbot and an FOV circle. It is game-agnostic: every game-specific detail (how to list targets, how to find a root part, where health lives) is supplied through a small **adapter** table, so plugging it into a new game is a matter of filling in a handful of functions rather than rewriting the aim logic.

---

## Requirements

Nothing is hard-required. Every optional API degrades:

| Missing API | Behaviour |
|---|---|
| `Drawing` | FOV circle is skipped; everything else works. |
| `mousemoverel` | `legit` mode does nothing; `rage` and `silent` still work. |
| `getgenv` | Falls back to `_G` for the `__EASY_STACK` runtime table. |

`silent` mode never moves the mouse or the camera — it only computes a position for you to feed into a remote, so it works on any executor.

---

## Install

```lua
local EasyAim = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyaim/EasyAim.luau"))()
```

The returned value is the `EasyAim` class table (`EasyAim.new`, `EasyAim.ver`, `EasyAim.Adapters`, `EasyAim.Descriptors`, `EasyAim.Toolkit`, `EasyAim.DestroyAll`).

---

## Quick start

```lua
local EasyAim = loadstring(game:HttpGet(URL))()

local aim = EasyAim.new({
    mode = "legit",
    key = Enum.UserInputType.MouseButton2,
    hitbox = { kind = "Head" },
    fov = { on = true, radius = 140 },
})

aim:on(true)
aim:start()
```

Teardown:

```lua
aim:stop()      -- disconnect the loop and input, hide the FOV circle
aim:destroy()   -- stop() + clear binds + remove the circle + drop callbacks
```

`EasyAim.new` is single-instance by convention: it destroys the previously registered instance in `getgenv().__EASY_STACK.aim` before constructing, so re-running a script never stacks two aim loops. `EasyAim.DestroyAll()` kills the registered instance.

---

## Concepts

### The per-frame pipeline

`aim:tick(dt)` is the whole engine; `start()` connects it to `RenderStepped`. Order per frame:

1. **FOV circle** — drawn (or hidden) before anything else, so it stays visible while the aim key is up.
2. **Master-off path** — if `cfg.on` is false, the target is cleared and the frame ends.
3. **Roster build** — `build()` calls the source, runs each raw entry through the adapter, and produces a record list.
4. **Triggerbot** — `_trigger(dt)` runs independently of the aim key.
5. **Engagement gate** — if `cfg.hold` is true and the key is not held, the frame ends here.
6. **Selection** — `pick()` chooses `self.target` by the `cfg.select` rule.
7. **Resolution** — `resolve()` picks a hitbox part and applies prediction, producing `self.aimPoint`.
8. **Application** — `legit` moves the mouse, `rage` moves the camera, `silent` does nothing (you read `aim.aimPoint`).

A **record** carries `raw`, `model`, `root`, `health`, `maxHealth`, `name`, `team`, `dist`, `sx`, `sy`, `depth`, `onScreen` and `screenDist`.

### Adapters

An adapter tells EasyAim how to read a game. Every field is optional and falls back to `Adapters.Default`.

| Field | Signature | Purpose |
|---|---|---|
| `targets` | `() -> {any}` | The raw candidate list. Default: `Players:GetPlayers()`. |
| `model` | `(raw) -> Model?` | Raw entry to a character model. Default: `raw.Character` for `Player`, else `raw`. |
| `root` | `(model) -> BasePart?` | The root part. Default: `HumanoidRootPart`, `PrimaryPart`, a known name, then any `BasePart`. |
| `part` | `(model, kind) -> BasePart?` | Resolve a named hitbox (`"Head"`, `"Torso"`). |
| `health` | `(model, raw) -> number, number` | Returns `health, maxHealth`. Default: reads a `Humanoid`. |
| `alive` | `(model, raw, health, maxHealth) -> boolean` | Liveness test. |
| `name` | `(model, raw) -> string` | Display name. |
| `team` | `(model, raw) -> any` | Team identity; compared with `==` against the local player's. |
| `ignore` | `(model, raw) -> boolean` | Return true to drop the entry. Default: drops the local player. |

Two adapters ship built in:

- **`Default`** — standard Roblox: `Players`, `Humanoid`, `Team`.
- **`Attribute`** — games that store state as attributes: reads the `Health` / `MaxHealth` / `Dead` / `SquadName` attributes, falling back to `Default` behaviour when they are absent.

```lua
aim:useAdapter("Attribute")
```

Custom adapters only need to override what differs:

```lua
aim:setAdapter({
    targets = function() return workspace.Entities:GetChildren() end,
    root    = function(m) return m:FindFirstChild("Root") end,
    health  = function(m) return m:GetAttribute("HP") or 0, 100 end,
    name    = function(m) return m:GetAttribute("Kind") or m.Name end,
})
```

`setAdapter` merges over `Default`, so unspecified fields keep working.

### Sources

`setSource(fn)` overrides `adapter.targets` without replacing the rest of the adapter. Use it when the target list is dynamic but the reading logic is unchanged:

```lua
aim:setSource(function()
    return State.targetZombies and workspace.Zombies:GetChildren() or Players:GetPlayers()
end)
```

---

## Configuration reference

`EasyAim.new(opt)` deep-merges `opt` over the defaults, then refills any gaps.

### Top level

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Master switch. |
| `mode` | string | `"legit"` | `"legit"` (mouse move), `"rage"` (camera lock), `"silent"` (position only). |
| `key` | EnumItem | `MouseButton2` | Aim key. Accepts a `KeyCode` or a `UserInputType`. |
| `hold` | boolean | `true` | `true` = aim only while held; `false` = always on. |
| `range` | number | `2000` | Max world distance. `0` means unlimited. |
| `team` | boolean | `false` | Skip targets whose team matches yours. |
| `wallCheck` | boolean | `false` | Skip targets that fail the visibility ray. Needs `vis.on`. |
| `deadCheck` | boolean | `true` | Skip targets the adapter reports as dead. |
| `select` | string | `"fov"` | `"fov"` (closest to cursor), `"distance"`, `"health"` (lowest), `"threat"`. |
| `sticky` | boolean | `false` | Keep the current target until it leaves an enlarged FOV. |
| `stickyLoss` | number | `1.35` | FOV multiplier before a sticky target is dropped. |

### `hitbox`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `kind` | string | `"Head"` | `"Head"`, `"Torso"`, `"Root"`, `"Nearest"` (closest of `list` to the cursor), `"Random"` (random from `list`). |
| `list` | `{string}` | `{"Head","Torso","Root"}` | Candidate parts for `Nearest` and `Random`. |
| `offset` | Vector3 | `(0,0,0)` | Added to the resolved part position. |

### `fov`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `true` | Draw the circle. |
| `radius` | number | `140` | Selection radius in pixels. `0` means unlimited. |
| `col` | Color3 | `(190,150,255)` | Circle colour. |
| `thickness` | number | `1` | Line thickness. |
| `filled` | boolean | `false` | Fill the circle. |
| `fillA` | number | `0.06` | Fill transparency. |
| `sides` | number | `48` | Circle resolution. |
| `follow` | boolean | `false` | `false` = screen centre; `true` = follow the mouse. |

### `legit`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `smooth` | number | `0.22` | Fraction of the pixel delta applied per frame. Lower is slower. |
| `smoothY` | number | `0` | Separate vertical smoothing. `0` reuses `smooth`. |
| `deadzone` | number | `0` | Skip correction inside this pixel radius. |
| `maxStep` | number | `90` | Clamp on per-frame pixel movement. `0` disables the clamp. |

### `rage`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `snap` | number | `1` | `1` snaps instantly; lower values lerp. |
| `lockCam` | boolean | `true` | Whether to write `Camera.CFrame`. |

### `humanize`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Add noise to legit movement. |
| `jitter` | number | `0.6` | Random pixel jitter per axis. |
| `reaction` | number | `0.05` | Reserved for consumer-side reaction delay. |
| `breath` | number | `0.35` | Amplitude of a slow sine sway. |

### `predict`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Enable velocity prediction. |
| `factor` | number | `0.165` | Seconds of lead when `speed` is `0`. |
| `speed` | number | `0` | Projectile speed. Above `0`, lead time becomes `distance / speed`. |
| `gravity` | number | `0` | Vertical drop compensation applied over the lead time. |
| `useVelocity` | boolean | `true` | Read `AssemblyLinearVelocity` from the hitbox part. |

### `vis`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Enable the raycast test. |
| `points` | number | `1` | `1` root only, `2` adds head, `3` adds torso. Any clear ray means visible. |

### `trigger`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `on` | boolean | `false` | Enable the triggerbot. |
| `key` | EnumItem | `nil` | Optional key that toggles `trigger.on`. |
| `fov` | number | `8` | Pixel radius that counts as "on target". |
| `delay` | number | `0.03` | Seconds on target before firing. |
| `reset` | number | `0.12` | Minimum seconds between shots. |
| `visOnly` | boolean | `true` | Require a clear visibility ray. |

The triggerbot never clicks by itself — it calls your `setFireCallback`, so you decide whether that means `mouse1click()` or a remote call.

---

## API reference

### Lifecycle

| Signature | Returns | Notes |
|---|---|---|
| `EasyAim.new(opt?)` | instance | Merges `opt` over defaults. Destroys the previous instance. |
| `aim:start()` | `self` | Connects `RenderStepped` and input. No-op if running. |
| `aim:stop()` | `self` | Disconnects, clears the target, hides the circle. |
| `aim:destroy()` | `nil` | `stop()` + `clearBinds()` + removes the circle + drops callbacks. |
| `EasyAim.DestroyAll()` | `nil` | Destroys the registered instance. |
| `aim:on(v)` | `self` | Sets `cfg.on`. |
| `aim:toggle()` | boolean | Flips `cfg.on`, returns the new state. |

### Configuration

| Signature | Returns | Notes |
|---|---|---|
| `aim:set(path, value)` | value | Dot-path write, e.g. `aim:set("fov.radius", 200)`. |
| `aim:get(path)` | value | Dot-path read. |

### Adapters and sources

| Signature | Returns | Notes |
|---|---|---|
| `aim:setAdapter(tbl)` | `self` | Merges over `Adapters.Default`. |
| `aim:useAdapter(name)` | boolean | `"Default"` or `"Attribute"`. |
| `aim:setSource(fn)` | `self` | Overrides `adapter.targets`. |
| `aim:setFilter(fn)` | `self` | `fn(record) -> boolean`; return false to drop. Runs after all built-in filters. |
| `aim:setPredictor(fn)` | `self` | `fn(pos, part, rec, aim) -> Vector3?` replaces built-in prediction. |
| `aim:setResolver(fn)` | `self` | `fn(pos, part, rec, aim) -> Vector3?` post-processes the final point. |
| `aim:setFireCallback(fn)` | `self` | `fn(rec, aim)` fired by the triggerbot. |
| `aim:setTargetCallback(fn)` | `self` | `fn(rec, pos, aim)` fired each frame a target is locked. |

### Queries

| Signature | Returns | Notes |
|---|---|---|
| `aim:build()` | `{record}` | Rebuilds and returns the roster. |
| `aim:pick()` | record or `nil` | Selects and stores `self.target`. |
| `aim:resolve(rec?)` | `Vector3, BasePart` | Hitbox + prediction for a record. |
| `aim:aimPosition()` | `Vector3` or `nil` | The point to aim at right now. **This is the silent-aim entry point.** |
| `aim:aimDirection(origin?)` | `Vector3, Vector3` | Unit direction and the target point. |
| `aim:getTarget()` | record or `nil` | Current target. |
| `aim:project(pos)` | `x, y, depth, onScreen` | World to screen. |
| `aim:sees(model, root)` | boolean | Immediate visibility raycast. |
| `aim:getStats()` | table | `roster`, `locked`, `name`, `dist`, `mode`, `held`. |

### Input

| Signature | Returns | Notes |
|---|---|---|
| `aim:bind(key, fn)` | connection | `fn(aim)` on key press. Tracked and dropped by `clearBinds`/`destroy`. |
| `aim:clearBinds()` | number | Disconnects tracked binds. |

### UI bridge

`EasyAim.Descriptors` is a flat array of 32 entries describing the config keys a settings UI should expose, in the same shape EasyESP uses, so `EasyUI` can build a panel from it.

| Signature | Returns |
|---|---|
| `EasyAim.GetDescriptors(prefix?)` | deep copy of the array, paths optionally prefixed |
| `EasyAim.GetDescriptor(path)` | one entry or `nil` |
| `EasyAim.Validate(path, value)` | value coerced by `kind` (dot-call or method-call) |

```lua
M:Mount("aim", aim.cfg)
for _, d in ipairs(EasyAim.GetDescriptors()) do
    local sec = M:Tab(d.tab):Section(d.section)
    if d.kind == "toggle" then
        sec:Toggle({ text = d.label, flag = "aim." .. d.path, default = aim:get(d.path) })
    elseif d.kind == "slider" then
        sec:Slider({ text = d.label, flag = "aim." .. d.path, min = d.min, max = d.max, step = d.step, default = aim:get(d.path) })
    elseif d.kind == "dropdown" then
        sec:Dropdown({ text = d.label, flag = "aim." .. d.path, options = d.items, default = aim:get(d.path) })
    elseif d.kind == "color" then
        sec:Colorpicker({ text = d.label, flag = "aim." .. d.path, default = aim:get(d.path) })
    end
end
```

### `EasyAim.Toolkit`

| Member | Purpose |
|---|---|
| `version` | Version string. |
| `adapters` | The live `Adapters` table. |
| `clone` / `merge` / `fill` | Table helpers. |
| `pathGet` / `pathSet` | Dot-path helpers. |
| `descriptors` | The live descriptor array. |
| `validate(path, value)` | Dot-style `Validate`. |
| `quick(opt)` | Builds, configures, enables and starts an instance in one call. `adapter` and `source` are consumed as control keys. |

```lua
local aim = EasyAim.Toolkit.quick({
    adapter = "Attribute",
    source = function() return workspace.Entities:GetChildren() end,
    mode = "silent",
    hitbox = { kind = "Torso" },
})
```

---

## Recipes

### Legit aim assist

```lua
local aim = EasyAim.new({
    mode = "legit",
    key = Enum.UserInputType.MouseButton2,
    hitbox = { kind = "Torso" },
    fov = { on = true, radius = 90 },
    legit = { smooth = 0.14, maxStep = 40 },
    humanize = { on = true, jitter = 0.5, breath = 0.3 },
    wallCheck = true,
    vis = { on = true, points = 2 },
})
aim:on(true):start()
```

### Rage / closet

```lua
local aim = EasyAim.new({
    mode = "rage",
    hold = false,
    select = "distance",
    hitbox = { kind = "Head" },
    fov = { on = false, radius = 0 },
    rage = { snap = 1, lockCam = true },
})
aim:on(true):start()
```

### Silent aim through a remote

`silent` mode computes the point and leaves delivery to you. Combine it with a namecall hook so the game's own fire call carries your direction:

```lua
local aim = EasyAim.new({ mode = "silent", hold = true, hitbox = { kind = "Head" } })
aim:on(true):start()

local old
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and method == "FireServer" and self.Name == "GunFire" then
        local pos = aim:aimPosition()
        if pos then
            local args = { ... }
            args[2] = pos
            return old(self, unpack(args))
        end
    end
    return old(self, ...)
end))
```

### Triggerbot

```lua
aim:set("trigger.on", true)
aim:set("trigger.fov", 6)
aim:setFireCallback(function(rec)
    if mouse1click then mouse1click() end
end)
```

### Projectile lead

```lua
aim:set("predict.on", true)
aim:set("predict.speed", 900)
aim:set("predict.gravity", -196.2)
```

---

## Gotchas

**`silent` mode does nothing on its own.** It never moves the mouse or camera by design. You must call `aim:aimPosition()` (or `aim:aimDirection()`) and feed the result somewhere — a remote, a hook, a raycast override. If nothing reads it, nothing happens.

**`hold = true` gates `aimPosition()` in silent mode too.** When `cfg.hold` is true and the aim key is not held, `aimPosition()` returns `nil`. Set `hold = false` for always-on silent aim.

**`wallCheck` needs `vis.on`.** The visibility filter in `pick()` requires both `cfg.wallCheck` and `cfg.vis.on`. Setting only `wallCheck` does nothing.

**Team comparison uses `==` on whatever the adapter returns.** The `Default` adapter returns the `Team` instance; the `Attribute` adapter returns the `SquadName` string. If your adapter returns a fresh table each call, the comparison never matches and the filter is inert.

**`setAdapter` merges, `useAdapter` replaces.** `setAdapter(t)` layers `t` over `Default`, so partial tables are safe. `useAdapter(name)` swaps in a whole built-in adapter.

**`range = 0` and `fov.radius = 0` mean unlimited, not zero.** Setting either to `0` disables that cutoff rather than rejecting every target.

**Prediction reads the hitbox part, not the root.** `AssemblyLinearVelocity` comes from the part chosen by `hitbox.kind`. For ragdoll-style rigs where limbs move independently of the body, `Root` gives a steadier velocity than `Head`.

**`Nearest` and `Random` fall back to the root.** If `adapter.part` cannot resolve any entry in `hitbox.list`, the root part is used, so aim never breaks on an unusual rig.
