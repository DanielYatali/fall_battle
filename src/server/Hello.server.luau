local GameManager = require(script.Parent.Services.GameManager)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.GameEvents)
local ClientEvent = ReplicatedStorage.Remotes.ClientEvent
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService.PlayerData)
local gameManager = GameManager.new(PlayerData)

-- while true do
--     for _, player in Players:GetPlayers() do
--         PlayerData.UpdateGems(player, 1)
--     end
--     task.wait(1)
-- end
local EventHandlers = {
    [GameEvents.PlayerReady] = function(player, data)
        gameManager:HandlePlayerReady(player, data)
    end
}

-- Handle player ready events
ClientEvent.OnServerEvent:Connect(function(player, eventName, data)
    if EventHandlers[eventName] then
        EventHandlers[eventName](player, data)
    end
end)

-- Notify new players of game state
Players.PlayerAdded:Connect(function(player)
    task.wait(1) -- Give time for UI to load
    ClientEvent:FireClient(
        player,
        GameEvents.GameState,
        {
            isRunning = gameManager.isGameRunning
        }
    )
end) 