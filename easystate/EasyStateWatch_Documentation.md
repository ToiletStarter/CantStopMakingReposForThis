# EasyStateWatch

Client-visible replicated-state detector. It scans bounded roots, records Instance class/name/path/value/attributes, and returns diffs between samples. This is server-state observation through Roblox replication, not hidden server memory access.

## Install

```lua
local StateWatch = loadstring(game:HttpGet(BASE .. "easystate/EasyStateWatch.luau"))()
local watcher = StateWatch.quick({ maxDepth = 4, maxNodes = 2500 })
```

## API

| Method | Purpose |
| --- | --- |
| `StateWatch.new(options)` | Create a watcher. |
| `watcher:setRoots(roots)` | Replace scan roots. |
| `watcher:scan()` | Return map, sorted list, and counters. |
| `watcher:sample()` | Scan and diff against the prior sample. |
| `watcher:getStats()` | Return counters and last diff counts. |
| `watcher:start(callback)` | Sample on Heartbeat at `interval`. |
| `watcher:stop()` | Stop periodic sampling. |
| `watcher:destroy()` | Stop and clear cached state. |
| `StateWatch.quick(options)` | Create and take the first sample. |

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `roots` | ReplicatedStorage, Workspace, LocalPlayer, Teams | Scan roots. |
| `maxDepth` | 5 | Max recursive depth per root. |
| `maxNodes` | 3000 | Hard node cap. |
| `maxChanges` | 200 | Max detailed added/removed/changed records per sample. |
| `maxAttributes` | 40 | Max attributes captured per Instance. |
| `attributes` | true | Include attributes. |
| `values` | true | Include ValueBase values. |
| `interval` | 2 | Periodic sample interval. |
| `filter` | nil | Optional `fn(instance, depth)` gate. |

## Pattern

```lua
local watcher = StateWatch.new({
    roots = { ReplicatedStorage, Workspace, Players.LocalPlayer },
    maxDepth = 4,
    maxNodes = 2000,
    interval = 2,
})

watcher:start(function(diff)
    if diff.changedCount > 0 then
        print("state changed", diff.changedCount)
    end
end)
```

The first sample is marked `initial = true` and does not report the whole tree as added. Later samples report bounded changes plus counters.

The module registers itself into EasyStack as `state.library` when EasyStack is loaded.
