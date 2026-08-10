# EasyStats

A small stats bus for composing runtime metrics from multiple Easy* libraries. Scripts register provider functions and get one unified snapshot for UI labels, JSON reports, and live debugging.

## Install

```lua
local Stats = loadstring(game:HttpGet(BASE .. "easystats/EasyStats.luau"))()
local stats = Stats.quick()
```

## API

| Method | Purpose |
| --- | --- |
| `Stats.new(options)` | Create a stats bus. |
| `stats:start()` | Start FPS accounting. |
| `stats:register(name, provider)` | Register a provider function. |
| `stats:unregister(name)` | Remove a provider. |
| `stats:snapshot()` | Call every provider and return `{sources, errors}`. |
| `stats:report()` | Return a human-readable provider status report. |
| `stats:destroy()` | Stop FPS accounting and clear providers. |
| `Stats.quick(options)` | Create and start in one call. |

## Built-in sources

Enabled by default:

- `runtime`: uptime, FPS, player count, place ID, game ID, job ID
- `localPlayer`: health, state, position, team, leaderstats
- `memory`: DataModel memory when available and instance count

Disable built-ins with:

```lua
local stats = Stats.new({ builtins = false })
```

## Pattern

```lua
stats:register("esp", function()
    return esp and esp:getStats() or {}
end)

stats:register("trace", function()
    return trace and trace:getStats() or {}
end)

stats:register("state", function()
    return watcher and watcher:getStats() or {}
end)

local snapshot = stats:snapshot()
```

Provider errors are captured in `snapshot.errors`; one broken provider does not break the report.

The module registers itself into EasyStack as `stats.library` when EasyStack is loaded.
