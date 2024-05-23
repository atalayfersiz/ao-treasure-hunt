Certainly! Let's design a new game that adheres to the rules and structure established in your original game. The new game will still involve players interacting within a grid, but we'll introduce a different theme and set of actions. This new game will be a **treasure hunt** where players search for hidden treasures while avoiding obstacles.

### Game Rules

1. **Game Area**: The game is played on a grid.
2. **Players**: Multiple players move around the grid.
3. **Treasures**: Treasures are hidden at random locations on the grid.
4. **Obstacles**: Obstacles are placed randomly on the grid and cannot be moved through.
5. **Actions**: Players can move in eight directions (up, down, left, right, and diagonals) and can pick up treasures if they move onto a cell containing a treasure.
6. **Energy**: Players have limited energy which decreases with movement and increases when a treasure is found.

### Key Elements

1. **Player Object**: Each player has a position `(x, y)`, energy, and a score (number of treasures found).
2. **Game State**: Includes the positions of all players, treasures, and obstacles.
3. **Actions**: Players can move or pick up treasures based on their current position and energy level.

### Lua Code Implementation

```lua
-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil
InAction = InAction or false -- Prevents the agent from taking multiple actions at once.
Logs = Logs or {}

colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

function addLog(msg, text) -- Function definition commented for performance, can be used for debugging
    Logs[msg] = Logs[msg] or {}
    table.insert(Logs[msg], text)
end

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function findNearestTreasure()
    local me = LatestGameState.Players[ao.id]

    local nearestTreasure = nil
    local nearestDistance = nil

    for _, treasure in ipairs(LatestGameState.Treasures) do
        local xdiff = me.x - treasure.x
        local ydiff = me.y - treasure.y
        local distance = math.sqrt(xdiff * xdiff + ydiff * ydiff)

        if nearestTreasure == nil or nearestDistance > distance then
            nearestTreasure = treasure
            nearestDistance = distance
        end
    end

    return nearestTreasure
end

directionMap = {}
directionMap[{ x = 0, y = 1 }] = "Up"
directionMap[{ x = 0, y = -1 }] = "Down"
directionMap[{ x = -1, y = 0 }] = "Left"
directionMap[{ x = 1, y = 0 }] = "Right"
directionMap[{ x = 1, y = 1 }] = "UpRight"
directionMap[{ x = -1, y = 1 }] = "UpLeft"
directionMap[{ x = 1, y = -1 }] = "DownRight"
directionMap[{ x = -1, y = -1 }] = "DownLeft"

function findAvoidDirection()
    local me = LatestGameState.Players[ao.id]

    local avoidDirection = { x = 0, y = 0 }
    for _, obstacle in ipairs(LatestGameState.Obstacles) do
        local avoidVector = { x = me.x - obstacle.x, y = me.y - obstacle.y }
        avoidDirection.x = avoidDirection.x + avoidVector.x
        avoidDirection.y = avoidDirection.y + avoidVector.y
    end
    avoidDirection = normalizeDirection(avoidDirection)

    local closestDirection = nil
    local closestDotResult = nil

    for direction, name in pairs(directionMap) do
        local normalized = normalizeDirection(direction)
        local dotResult = avoidDirection.x * normalized.x + avoidDirection.y * normalized.y

        if closestDirection == nil or closestDotResult < dotResult then
            closestDirection = name
            closestDotResult = dotResult
        end
    end

    return closestDirection
end

function findApproachDirection()
    local me = LatestGameState.Players[ao.id]

    local approachDirection = { x = 0, y = 0 }
    local nearestTreasure = findNearestTreasure()
    local approachVector = { x = nearestTreasure.x - me.x, y = nearestTreasure.y - me.y }
    approachDirection.x = approachDirection.x + approachVector.x
    approachDirection.y = approachDirection.y + approachVector.y
    approachDirection = normalizeDirection(approachDirection)

    local closestDirection = nil
    local closestDotResult = nil

    for direction, name in pairs(directionMap) do
        local normalized = normalizeDirection(direction)
        local dotResult = approachDirection.x * normalized.x + approachDirection.y * normalized.y

        if closestDirection == nil or closestDotResult < dotResult then
            closestDirection = name
            closestDotResult = dotResult
        end
    end

    return closestDirection
end

function isTreasureInRange(treasure)
    local me = LatestGameState.Players[ao.id]
    return inRange(me.x, me.y, treasure.x, treasure.y, 1)
end

function normalizeDirection(direction)
    local length = math.sqrt(direction.x * direction.x + direction.y * direction.y)
    return { x = direction.x / length, y = direction.y / length }
end

-- Decides the next action based on player proximity and energy.
-- If any treasure is within range, it initiates a pickup; otherwise, moves towards the nearest treasure.
function decideNextAction()
    local me = LatestGameState.Players[ao.id]

    local nearestTreasure = findNearestTreasure()
    local isNearestTreasureInRange = isTreasureInRange(nearestTreasure)

    nearestTreasure.isInRange = isNearestTreasureInRange
    nearestTreasure.meEnergy = me.energy
    print(nearestTreasure)

    if me.energy < 50 then
        CurrentStrategy = "avoid"
    elseif nearestTreasure.isInRange then
        CurrentStrategy = "pickup"
    else
        CurrentStrategy = "approach"
    end

    local tableOfActions = {}
    tableOfActions["avoid"] = function()
        local direction = findAvoidDirection()
        print(colors.green .. "saving energy. avoiding obstacles" .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction })
    end
    tableOfActions["approach"] = function()
        local direction = findApproachDirection()
        print(colors.blue .. "searching for treasure. approach" .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction })
    end
    tableOfActions["pickup"] = function()
        print(colors.red .. "found treasure. picking up" .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerPickup", Player = ao.id, Treasure = nearestTreasure.id })
    end

    tableOfActions[CurrentStrategy]()
    InAction = false -- InAction logic added
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        if msg.Event == "Started-Waiting-Period" then
            ao.send({ Target = ao.id, Action = "AutoPay" })
        elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
            InAction = true  -- InAction logic added
            ao.send({ Target = Game, Action = "GetGameState" })
        elseif InAction then -- InAction logic added
            print("Previous action still in progress. Skipping.")
        end

        print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    end
)

-- Handler to trigger game state updates.
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        if not InAction then -- InAction logic added
            InAction = true  -- InAction logic added
            print(colors.gray .. "Getting game state..." .. colors.reset)
            ao.send({ Target = Game, Action = "GetGameState" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add(
    "AutoPay",
    Handlers.utils.hasMatchingTag("Action", "AutoPay"),
    function(msg)
        print("Auto-paying confirmation fees.")
        ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
    end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Hand
