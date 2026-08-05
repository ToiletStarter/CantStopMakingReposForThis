# EasyStack

Registry that every Easy* library plus the script writes into once. Lets the script ask for the active instances by name (`Stack.get("aim.silentPlayers")`) and lets libraries hook each other without knowing the concrete wiring.

No game logic here. One shared table, one destroy-all helper.

## Usage

```lua
local Stack = loadstring(game:HttpGet('.../easystack/EasyStack.luau'))()
Stack.register('esp.players', esp)
Stack.setFeature('cap.drawing', true)
local esp = Stack.get('esp.players')
```
