LatestGameState = LatestGameState or nil
InAction = InAction or false
Logs = Logs or {}

colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function findNearestPlayer()
    local me = LatestGameState.Players[ao.id]
    local nearestPlayer = nil
    local nearestDistance = nil

    for target, state in pairs(LatestGameState.Players) do
        if target == ao.id then goto continue end
        local xdiff = me.x - state.x
        local ydiff = me.y - state.y
        local distance = math.sqrt(xdiff * xdiff + ydiff * ydiff)

        if nearestPlayer == nil or nearestDistance > distance then
            nearestPlayer = state
            nearestDistance = distance
        end
        ::continue::
    end
    return nearestPlayer
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

    for target, state in pairs(LatestGameState.Players) do
        if target == ao.id then goto continue end
        local avoidVector = { x = me.x - state.x, y = me.y - state.y }
        avoidDirection.x = avoidDirection.x + avoidVector.x
        avoidDirection.y = avoidDirection.y + avoidVector.y
        ::continue::
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
    local otherPlayer = findNearestPlayer()
    local approachVector = { x = otherPlayer.x - me.x, y = otherPlayer.y - me.y }
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

function isPlayerInAttackRange(player)
    local me = LatestGameState.Players[ao.id]
    return inRange(me.x, me.y, player.x, player.y, 1)
end

function normalizeDirection(direction)
    local length = math.sqrt(direction.x * direction.x + direction.y * direction.y)
    return { x = direction.x / length, y = direction.y / length }
end

function decideNextAction()
    local me = LatestGameState.Players[ao.id]
    local nearestPlayer = findNearestPlayer()
    local isNearestPlayerInAttackRange = isPlayerInAttackRange(nearestPlayer)

    nearestPlayer.isInAttackRange = isNearestPlayerInAttackRange
    nearestPlayer.meEnergy = me.energy
    print(nearestPlayer)

    if me.energy < 50 then
        CurrentStrategy = "avoid"
    elseif nearestPlayer.isInAttackRange then
        CurrentStrategy = "attack"
    else
        CurrentStrategy = "approach"
    end

    local tableOfActions = {}
    tableOfActions["avoid"] = function()
        local direction = findAvoidDirection()
        print(colors.green .. "saving energy. avoiding" .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction })
    end
    tableOfActions["approach"] = function()
        local direction = findApproachDirection()
        print(colors.blue .. "be angry. approach" .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction })
    end
    tableOfActions["attack"] = function()
        print(colors.red .. "smash them. attack" .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(me.energy) })
    end

    tableOfActions[CurrentStrategy]()
    InAction = false
end

Handlers.add("PrintAnnouncements", Handlers.utils.hasMatchingTag("Action", "Announcement"), function(msg)
    if msg.Event == "Started-Waiting-Period" then
        ao.send({ Target = ao.id, Action = "AutoPay" })
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
        InAction = true
        ao.send({ Target = Game, Action = "GetGameState" })
    elseif InAction then
        print("Previous action still in progress. Skipping.")
    end

    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
end)

Handlers.add("GetGameStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"), function()
    if not InAction then
        InAction = true
        print(colors.gray .. "Getting game state..." .. colors.reset)
        ao.send({ Target = Game, Action = "GetGameState" })
    else
        print("Previous action still in progress. Skipping.")
    end
end)

Handlers.add("AutoPay", Handlers.utils.hasMatchingTag("Action", "AutoPay"), function(msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
end)

Handlers.add("UpdateGameState", Handlers.utils.hasMatchingTag("Action", "GameState"), function(msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({ Target = ao.id, Action = "UpdatedGameState" })
    print("Game state updated. Print 'LatestGameState' for detailed view.")
    print("energy:" .. LatestGameState.Players[ao.id].energy)
end)

Handlers.add("decideNextAction", Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"), function()
    if LatestGameState.GameMode ~= "Playing" then
        print("game not start")
        InAction = false
        return
    end
    print("Deciding next action.")
    decideNextAction()
    ao.send({ Target = ao.id, Action = "Tick" })
end)

