# EasyRemoteTrace

Metadata-first Luau remote call tracing for executor diagnostics. It observes outbound `FireServer` and `InvokeServer` calls from the local client and stores bounded metadata. It forwards every call unchanged.

## Install

```lua
local Trace = loadstring(game:HttpGet(BASE .. "easytrace/EasyRemoteTrace.luau"))()
local trace = Trace.new({ mode = "metadata", maxEntries = 300 })
trace:start()
```

## API

| Method | Purpose |
| --- | --- |
| `Trace.new(options)` | Create a trace object. |
| `trace:start()` | Install the namecall observer when executor hooks exist. |
| `trace:stop()` | Disable recording. Calls continue to forward. |
| `trace:on("call", fn)` | Subscribe to trace entries. |
| `trace:setFilter(fn)` | Filter entries before storage. |
| `trace:getRecent(limit)` | Return the last N entries. |
| `trace:getStats()` | Return counts and hottest remote/method pairs. |
| `trace:encodeRecent(limit)` | JSON encode recent entries. |
| `trace:clear()` | Clear entries and counts. |
| `trace:destroy()` | Stop and clear. |
| `Trace.quick(options)` | Create and start in one call. |

## Modes

| Mode | Stored data |
| --- | --- |
| `metadata` | path, class, method, argc, arg types |
| `summary` | metadata plus compact non-sensitive type summaries |
| `raw` | only when `allowRaw = true`; bounded primitive/table summaries |

Default mode is `metadata`. Raw arguments are never captured by default.

## Safety shape

Entries look like:

```lua
{
    t = 123.45,
    path = "ReplicatedStorage.Remotes.Fire",
    name = "Fire",
    class = "RemoteEvent",
    method = "FireServer",
    argc = 3,
    argTypes = { "Vector3", "Instance", "table" },
}
```

`stop()` disables recording but does not attempt to mutate or block the game call path. The hook always forwards to the previous namecall.

## Pattern

```lua
local trace = Trace.new({ mode = "metadata", maxEntries = 300 })
local ok, reason = trace:start()
if not ok then
    warn(reason)
end

trace:on("call", function(entry)
    report:event("remote", entry.path, entry)
end)
```

The module registers itself into EasyStack as `trace.library` when EasyStack is loaded.
