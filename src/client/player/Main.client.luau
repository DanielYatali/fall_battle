print("[Client] Script starting...")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientEvent = ReplicatedStorage.Remotes.ClientEvent
local GameEvents = require(ReplicatedStorage.GameEvents)
local localPlayer = Players.LocalPlayer
-- local AnimationController = require(ReplicatedStorage.AnimationController)

local GUIhandler = require(ReplicatedStorage.GUIhandler)
local GUI = GUIhandler.new(localPlayer)

local EventHandlers = {
    [GameEvents.GameStart] = function(data)
        GUI:GameStart(data)
    end,
    [GameEvents.GameEnd] = function(data)
        GUI:GameEnd(data)
    end,
    [GameEvents.UpdateHUD] = function(data)
        GUI:UpdateHUD(data)
    end,
    [GameEvents.Results] = function(data)
        GUI:Results(data)
    end,
    [GameEvents.SetState] = function(data)
        GUI:SetState(data)
    end,
    [GameEvents.UpdateState] = function(data)
        GUI:UpdateState(data)
    end,
    [GameEvents.ApplyKnockback] = function(data)
        local character = localPlayer.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            if rootPart and humanoid then
                -- Don't disable jumping or movement controls
                humanoid.PlatformStand = false
                humanoid.AutoRotate = true
                
                -- Apply the knockback force
                rootPart.Anchored = false
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                rootPart:ApplyImpulse(data.impulseVector)
                rootPart.AssemblyLinearVelocity = data.impulseVector / data.mass
            end
        end
    end
}

-- Handle server events
ClientEvent.OnClientEvent:Connect(function(eventName, data)
    if EventHandlers[eventName] then
        -- print("Event received:", eventName, data)
        EventHandlers[eventName](data)
    end
end)

print("[Client] UI Setup Complete")

-- Add character spawned handler
localPlayer.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid")

    -- Optional: Add character modifications here
    humanoid.WalkSpeed = 16
    humanoid.JumpPower = 50

    -- Reinitialize the GUI handler
    GUI = GUIhandler.new(localPlayer)

    -- Request current game state
    -- ClientEvent:FireServer(GameEvents.RequestGameState)
end)

-- //clean up on death
localPlayer.CharacterRemoving:Connect(function()
    GUI = nil
end)

