# EasyBudget

Single-file Roblox executor **remote rate budgeting** library (`EasyBudget.luau`, version `1.0.0`).

Most games rate-limit their remotes, and many report you to a server-side detection service when you
exceed the limit. A killaura that fires faster than the limit does not get "blocked" harmlessly — it
gets you flagged. EasyBudget is a sliding-window token bucket per remote, plus a pacer that spaces
calls out and round-robins across targets, so a feature stays inside the game's own limits by
construction rather than by hoping the CPS slider is set sensibly.

It is pure Lua. It makes no `game:GetService` calls and touches no Roblox API, so it loads anywhere.

---

## Why this exists

Roblox BedWars is the worked example. Its remote layer installs a global rate limiter with a default
of **300 requests per minute (5/sec)** for every remote, and on breach calls
`ExploitDetectionService:incrementDetection(player, "rate_limit_exceeded")` — except for four
whitelisted remotes where breaching is analytics-only.

The trap: BedWars' *own* client-side click gate allows ~9 CPS, which is nearly **double** what its
rate limiter permits. Matching the client gate flags you. You have to know the real number.

Worse, the budget is per-remote and per-player, **not per-target**. An aura hitting 5 enemies at
3 CPS each is 15 calls/sec through one bucket — 3x over.

---

## Install

```lua
local EasyBudget = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easybudget/EasyBudget.luau"))()
```

---

## Quick start

```lua
local budget = EasyBudget.new({ headroom = 0.8 })
budget:loadPreset("bedwars")

if budget:consume("SwordHit") then
    swordHitRemote:FireServer(payload)
end
```

`headroom = 0.8` means the library will stop you at 80% of the real limit, leaving margin for the
game's own legitimate traffic on the same remote.

---

## Concepts

### The bucket

One sliding window per remote name. `consume(name, count)` returns `true` and records timestamps if
there is room, or `false` and increments a denial counter if not. The window slides continuously —
there are no fixed reset boundaries to burst across.

Old timestamps are compacted out as the window slides, so memory stays bounded regardless of runtime.

### The pacer

A bucket alone permits bursts: 300 calls in the first second, then silence for 59. That pattern is
trivially detectable even though it never exceeds the limit. A pacer additionally enforces a minimum
gap between calls, derived from the bucket's own rate.

```lua
local pacer = budget:pacer("SwordHit")

if pacer:tryFire() then
    attack(target)
end
```

`tryFire()` checks both the spacing and the bucket. For `SwordHit` at 300/min the spacing is 0.2s, so
a loop calling `tryFire()` every frame produces a smooth 5/sec, never a burst.

### Round-robin targeting

`cycle(list)` combines pacing with target rotation, which is the correct shape for a multi-target
aura: one call per tick, distributed across targets, all inside a single shared budget.

```lua
local target = pacer:cycle(enemies)
if target then
    attack(target)
end
```

### Headroom

`headroom` scales every limit down. `0.8` on a 300/min remote gives you 240/min. Use it because the
game's own code shares those buckets — your script is not the only thing firing `SwordHit`.

---

## API reference

### Lifecycle

| Signature | Returns | Notes |
|---|---|---|
| `EasyBudget.new(opt?)` | instance | `opt.defaultLimit` (300), `opt.defaultWindow` (60), `opt.headroom` (0.8), `opt.onDenied`, `opt.on`. Destroys the previous instance. |
| `budget:destroy()` | `nil` | Clears buckets and the registry slot. Safe twice. |
| `EasyBudget.DestroyAll()` | `nil` | Destroys the registered instance. |
| `budget:on(v)` | `self` | `false` makes every `consume` a pass-through. |

### Defining limits

| Signature | Returns | Notes |
|---|---|---|
| `budget:define(name, limit, opt?)` | bucket | `opt.window`, `opt.headroom`, `opt.exempt`, `opt.label`. |
| `budget:loadPreset(name)` | boolean | Bulk-define from `EasyBudget.Presets`. |
| `budget:setLimit(name, limit)` | bucket | |
| `budget:setHeadroom(v)` | `self` | Applies to every existing bucket. |
| `budget:bucket(name)` | bucket | Auto-creates at the default limit if undefined. |

### Spending

| Signature | Returns | Notes |
|---|---|---|
| `budget:consume(name, count?)` | boolean | The main call. `false` means do not send. |
| `budget:check(name)` | boolean | Peek without spending. |
| `budget:guard(name, fn, ...)` | `ok, err` | Consume, then `pcall(fn, ...)`. |
| `budget:wrap(name, fn)` | function | Returns a rate-limited version of `fn`. |

### Queries

| Signature | Returns |
|---|---|
| `budget:used(name)` | calls inside the current window |
| `budget:remaining(name)` | calls left before the cap |
| `budget:capacity(name)` | `floor(limit * headroom)` |
| `budget:rate(name)` | permitted calls per second |
| `budget:interval(name)` | minimum seconds between calls |
| `budget:isExempt(name)` | whether breaching is detection-exempt |
| `budget:stats(name?)` | one stat table, or all of them sorted by name |
| `budget:report()` | printable multi-line summary |
| `budget:reset(name?)` | clear one or all windows |

### Pacer

| Signature | Returns | Notes |
|---|---|---|
| `budget:pacer(name, opt?)` | pacer | `opt.minGap` overrides the derived interval; `opt.jitter` (0..1) randomizes it. |
| `pacer:tryFire()` | boolean | Spacing check + bucket consume. |
| `pacer:ready()` | boolean | Spacing check only. |
| `pacer:gap()` | number | Current interval, jitter applied. |
| `pacer:next(list)` | `item, index` | Advance the round-robin cursor. |
| `pacer:cycle(list)` | item or `nil` | `tryFire()` then `next(list)`. |
| `pacer:reset()` | `self` | Clear cursor and timing. |

---

## Presets

### `bedwars`

Transcribed from the decompiled remote definitions. `exempt` marks the four remotes that do **not**
increment the server-side detection counter on breach.

| Remote | Limit/min | Per sec | Exempt |
|---|---|---|---|
| `SwordHit` | 300 | 5.00 | no |
| `SwordSwingMiss` | 1200 | 20.00 | **yes** |
| `SwordChargeState` | 300 | 5.00 | **yes** |
| `ProjectileFire` | 1200 | 20.00 | no |
| `ProjectileHit` | 300 | 5.00 | **yes** |
| `SetInvItem` | 300 | 5.00 | **yes** |
| `MomentumUpdate` | 900 | 15.00 | no |
| `CannonLookVectorUpdate` | 600 | 10.00 | no |
| `FrostyGunFire` | 900 | 15.00 | no |
| `ElkKitMounted` | 30 | 0.50 | no |
| `PlaceBlock` / `BreakBlock` / `DamageBlock` | 300 | 5.00 | no |

Any remote not defined falls back to `defaultLimit` (300), which matches the game's own fallback.

---

## Recipes

### Rate-safe killaura

```lua
local budget = EasyBudget.new({ headroom = 0.85 })
budget:loadPreset("bedwars")
local pacer = budget:pacer("SwordHit", { jitter = 0.12 })

RunService.Heartbeat:Connect(function()
    local enemies = getValidTargets()
    local target = pacer:cycle(enemies)
    if target then
        swingAt(target)
    end
end)
```

Jitter here is not about humanization — it stops every swing landing on an exact 200ms grid.

### Batched auto-buy

```lua
local perCall = 16
local wanted = 64
while wanted > 0 do
    if budget:consume("SetInvItem") then
        buy("wool", math.min(perCall, wanted))
        wanted = wanted - perCall
    end
    task.wait(budget:interval("SetInvItem"))
end
```

### Warn the user when a setting is unsafe

```lua
local budget = EasyBudget.new({
    onDenied = function(name, bucket)
        if not bucket.exempt then
            UI:Notify({ title = "Rate limit", text = name .. " throttled", kind = "warn" })
        end
    end,
})
```

### Show live usage in the menu

```lua
UI:Every("budget", 0.5, function()
    local s = budget:stats("SwordHit")
    label:Set(string.format("%d/%d (%.1f/s)", s.used, s.capacity, s.perSecond))
end)
```

---

## Gotchas

**A budget is per remote, not per target.** Hitting 5 players still spends 5 tokens from one bucket.
This is the mistake the library exists to prevent — use `pacer:cycle` rather than looping targets.

**`headroom` is not paranoia.** The game's own code fires the same remotes. If you consume 100% of
the budget, legitimate gameplay traffic trips the limiter instead of you, which is arguably worse.

**Exempt does not mean safe.** The four exempt BedWars remotes skip the *detection counter*, but
breaching them still logs a `RATE_LIMIT_EXCEEDED` analytics event against your UserId.

**The window is 60s by default and slides.** `remaining()` immediately after a burst will be 0 and
will recover gradually, not all at once.

**`consume` returning false is not an error.** It is the normal signal to skip this tick. Do not
retry in a tight loop; that just burns CPU while denied.

**Timestamps use `os.clock()`**, which is monotonic process time. It is unaffected by the player's
clock or by server time sync.

**This library only tracks what you tell it about.** Calls you make without going through `consume`
are invisible to it, and the game's own traffic is invisible to it. It is a discipline tool, not a
network interceptor.
