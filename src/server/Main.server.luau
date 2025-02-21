-- Add this at the top of your server script
if _G.GameManagerInstance then
    warn("GameManager instance already exists! Preventing duplicate initialization.")
    return
end
_G.GameManagerInstance = true

local GameManager = require(script.Parent.Services.GameManager)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.GameEvents)
local ClientEvent = ReplicatedStorage.Remotes.ClientEvent
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService.PlayerData)
local gameManager = GameManager.new(PlayerData)

-- Add this during development to help spot duplicates
local serverScriptService = game:GetService("ServerScriptService")
for _, instance in ipairs(serverScriptService:GetDescendants()) do
    if instance.Name == script.Name and instance ~= script then
        warn("Duplicate script found:", instance:GetFullName())
    end
end

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

function overrideAnimation(player)
    print("Overriding animation for player: " .. player.Name)
    player.CharacterAdded:Connect(function(character)
        print("Character added for player: " .. player.Name)
        local animate = character:WaitForChild("Animate")

        -- Override the animation values in the Animate script
        local idle = animate.idle
        local idleAnim = idle.Animation1
        idleAnim.AnimationId = "rbxassetid://124789207248087" -- Replace with your idle animation ID

        local walk = animate.walk
        -- local walkAnim = walk:WaitForChild("WalkAnim")
        walk.WalkAnim.AnimationId = "rbxassetid://89085870385546" -- Replace with your walk animation ID

        local run = animate.run
        run.RunAnim.AnimationId = "rbxassetid://89085870385546" -- Replace with your run animation ID

        local jump = animate.jump
        jump.JumpAnim.AnimationId = "rbxassetid://105651035389777" -- Replace with your jump animation ID

        local fall = animate.fall
        fall.FallAnim.AnimationId = "rbxassetid://124675750517899" -- Replace with your fall animation ID

    end)
end

-- Notify new players of game state
Players.PlayerAdded:Connect(function(player)
    print("Player added: " .. player.Name)
    overrideAnimation(player)
    task.wait(1) -- Give time for UI to load
    ClientEvent:FireClient(player, GameEvents.GameState, {
        isRunning = gameManager.isGameRunning
    })
end)

game:BindToClose(function()
    _G.GameManagerInstance = nil
    -- Any other cleanup needed
end)

