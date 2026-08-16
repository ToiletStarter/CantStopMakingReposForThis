# EasyAdapter

EasyAdapter is a game-agnostic source binder for EasyESP and EasyWorld. It turns tagged collections, folders, or arbitrary read-only callbacks into dynamic visual sources without putting game-specific paths into the visual libraries.

## Install

```lua
local Adapter = loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/easyadapter/EasyAdapter.luau"))()
```

## Sources

A source has a stable id, a kind, and a callback returning one Instance or an array of Instances.

```lua
local adapter = Adapter.new({ name = "Game", prefix = "game" })
adapter:addSource("loot", {
    kind = "entity",
    get = function()
        return workspace.Loot:GetChildren()
    end,
    label = function(item)
        return item.Name
    end,
    color = Color3.fromRGB(120, 255, 190),
})
```

Tagged and folder helpers keep the game adapter resilient to respawns and streamed objects.

```lua
adapter:addTagSource("monsters", "Monster", {
    kind = "npc",
    fallback = function()
        return workspace.Monsters:GetChildren()
    end,
    label = function(model)
        return "Monster " .. model.Name
    end,
})
```

## EasyESP binding

`attachESP` creates dynamic entity sources, combines all NPC sources, and maps labels back to their source. It does not fire remotes, synthesize input, change character properties, or install hooks.

```lua
adapter:attachESP(esp)
esp:npc(true)
esp:on(true)
esp:start()
```

Disable a source without rebuilding the overlay.

```lua
adapter:setEnabled("loot", false)
```

## EasyWorld binding

World bindings accept any EasyWorld shape whose `get` callback returns a Vector3, CFrame, BasePart, or Model.

```lua
adapter:bindWorld("local", world, {
    kind = "marker",
    get = function()
        return workspace.CurrentCamera.CFrame.Position
    end,
    col = Color3.fromRGB(140, 190, 250),
})
```

## Snapshot and cleanup

```lua
local snapshot = adapter:snapshot()
adapter:destroy()
```

`snapshot` contains source counts and enabled state. `destroy` detaches only the bindings created by the adapter.
