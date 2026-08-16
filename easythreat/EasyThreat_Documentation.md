# EasyThreat

EasyThreat is a read-only monster observation module. It samples a caller-provided model source, measures distance and approach direction, classifies direct target/attack/proximity state, and produces bounded kinematic future paths from current velocity, MoveDirection, and WalkToPoint data. It does not expose server navigation plans.

## Install

```lua
local Threat = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easythreat/EasyThreat.luau"))()
```

## Usage

```lua
local threat = Threat.new({
    source = function()
        return workspace._Monsters:GetChildren()
    end,
    localRoot = function()
        return game:GetService("Players").LocalPlayer.Character.HumanoidRootPart
    end,
    dangerRange = 200,
    futureSteps = 8,
    futureStepTime = 0.25,
})
threat:start()
```

Classification order:

- `TARGETED`: a target object, attribute, or value identifies the local player or character.
- `ATTACKING`: the model exposes an `Attacking` state.
- `APPROACHING`: distance is decreasing while inside the danger range.
- `NEAR`: distance is inside the configured danger range.
- `CLOSING`: distance is decreasing outside the danger range.
- `IDLE`: none of the above is observable.

`confidence` is `direct`, `attack-state`, `inferred`, `proximity`, or `none`. The module never invokes a remote, changes a model, simulates input, or claims that inferred movement proves server aggro.

## API

```lua
threat:sample()
threat:records()
threat:get(model)
threat:paths()
threat:snapshot()
threat:setDangerRange(200)
threat:setFutureSteps(8)
threat:stop()
threat:destroy()
```
