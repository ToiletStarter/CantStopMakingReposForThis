# EasySignals

Single-file lifecycle manager for Roblox executor scripts. It owns connections, scheduled jobs, throttles, debounces, and teardown callbacks so re-running a script does not leak old loops or UI state.

## Install

```lua
local Signals = loadstring(game:HttpGet(BASE .. "easysignals/EasySignals.luau"))()
local signals = Signals.new()
```

## API

| Method | Purpose |
| --- | --- |
| `Signals.new(options)` | Create a lifecycle owner. |
| `signals:track(value, tag)` | Store a connection or destroyable object for cleanup. |
| `signals:bind(signal, fn, tag)` | Connect a Roblox signal and wrap the callback in `pcall`. |
| `signals:once(signal, fn, tag)` | Run a callback once, then disconnect it. |
| `signals:cleanupWith(fn, tag)` | Register an arbitrary cleanup function. |
| `signals:every(name, interval, fn)` | Run a bounded Heartbeat-backed periodic job. |
| `signals:throttle(name, interval, fn)` | Return a wrapper that runs at most once per interval. |
| `signals:debounce(name, interval, fn)` | Return a wrapper that delays until calls settle. |
| `signals:count()` | Return connection/job/cleanup counts. |
| `signals:cleanup()` / `destroy()` | Stop everything exactly once. |

## Pattern

```lua
local signals = Signals.new()
signals.onError = function(err, tag)
    warn("[signals] " .. tostring(tag) .. ": " .. tostring(err))
end

signals:bind(Players.PlayerAdded, function(player)
    print("joined", player.Name)
end, "players")

signals:every("report", 5, function()
    print("write bounded report")
end)

function Session.unload()
    signals:cleanup()
end
```

## Notes

- `cleanup()` is idempotent.
- Jobs are Heartbeat-backed but interval-limited.
- A callback error does not break the owning script when `onError` is set.
- The module registers itself into EasyStack as `signals.library` when EasyStack is loaded.
