# EasyNoise

EasyNoise observes a local `BindableEvent` audio meter and calculates an estimated sound reach from the observed weight and a game-provided multiplier. It can compare that estimate to EasyThreat records.

It does not fire the corresponding voice or ping remote. It cannot prove that a server-side monster heard the player; `inferredResponses` only counts monsters already showing a targeted or attacking state inside the estimated reach.

```lua
local Noise = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easynoise/EasyNoise.luau"))()
local noise = Noise.new({
    event = game.ReplicatedStorage.Events.Bindables.AudioMeter,
    threat = threat,
    multiplier = 90,
    maxWeight = 3,
})
noise:start()
local snapshot = noise:snapshot()
```

The snapshot contains the last weight, estimated reach, an expanding puddle radius/alpha, active state, monsters inside the estimate, and inferred responses.
