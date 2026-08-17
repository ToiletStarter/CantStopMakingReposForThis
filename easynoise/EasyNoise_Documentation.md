# EasyNoise

EasyNoise observes a local `BindableEvent` audio meter and, when supplied, a game-provided client `RemoteEvent` that delivers server-adjusted numeric noise weights. It calculates estimated sound reach from the observed weight and a game-provided multiplier, then compares that estimate to EasyThreat records.

It does not fire the corresponding voice or ping remote. It cannot prove that a server-side monster heard the player; `inferredResponses` only counts monsters already showing a targeted or attacking state inside the estimated reach.

```lua
local Noise = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easynoise/EasyNoise.luau"))()
local noise = Noise.new({
    event = game.ReplicatedStorage.Events.Bindables.AudioMeter,
    pingEvent = game.ReplicatedStorage.Events.Remotes.Ping,
    threat = threat,
    multiplier = 90,
    maxWeight = 3,
})
noise:start()
local snapshot = noise:snapshot()
```

The snapshot contains the last weight, last source, available sources, per-source event counts, estimated reach, an expanding puddle radius/alpha, active state, monsters inside the estimate, and inferred responses. `AudioMeter` and `GamePing` are listeners only; EasyNoise never invokes either event.
