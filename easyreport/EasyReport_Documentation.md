# EasyReport

Bounded structured reporting for Roblox executor scripts. It writes compact JSON snapshots, maintains a ring buffer, redacts obvious secret fields, and rate-limits file output.

## Install

```lua
local Report = loadstring(game:HttpGet(BASE .. "easyreport/EasyReport.luau"))()
local report = Report.new({ path = "MyScript/live.json", maxEntries = 500 })
```

## API

| Method | Purpose |
| --- | --- |
| `Report.new(options)` | Create a report sink. |
| `report:info(section, message, data)` | Add an info entry. |
| `report:warn(section, message, data)` | Add a warning entry. |
| `report:error(section, message, data)` | Add an error entry. |
| `report:event(section, message, data)` | Add a neutral event entry. |
| `report:addSink(fn)` | Stream each entry to UI/console/custom storage. |
| `report:recent(limit)` | Return the last N entries. |
| `report:snapshot(extra)` | Return a JSON-friendly report object. |
| `report:flush(path, extra)` | Write a full JSON report. |
| `report:flushDue(path, extra)` | Write only when `flushInterval` has elapsed. |
| `report:write(path, value)` | Write a string/table safely. |
| `report:clear()` | Clear the ring buffer. |
| `report:destroy()` | Remove sinks. |

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `path` | nil | Default file path. |
| `maxEntries` | 500 | Ring-buffer entry cap. |
| `maxBytes` | 120000 | Approximate encoded byte cap. |
| `flushInterval` | 5 | Minimum seconds between `flushDue` writes. |
| `verbose` | false | Print entries to executor console. |
| `consolePrefix` | `[EasyReport]` | Console prefix. |
| `maxDepth` | 4 | Table compaction depth. |
| `maxItems` | 80 | Max table items per object. |
| `maxString` | 180 | Max string length per field. |

## Safety defaults

Fields containing `token`, `password`, `secret`, `key`, `authorization`, or `cookie` are written as `[REDACTED]`. Deep tables, huge strings, cycles, and Instances are compacted before encoding.

## Pattern

```lua
report:info("boot", "loaded")
report:event("state", "sample", watcher:getStats())
report:flushDue("MyScript/live.json", {
    stats = stats:snapshot(),
    state = watcher:getStats(),
})
```

The module registers itself into EasyStack as `report.library` when EasyStack is loaded.
