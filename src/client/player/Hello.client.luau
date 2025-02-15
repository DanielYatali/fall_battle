print("[Client] Script starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

print("[Client] DEBUG: Got services")

-- Wait for Remotes folder
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    print("[Client] ERROR: Remotes folder not found after 10 seconds!")
    return
end

print("[Client] DEBUG: Found Remotes folder")

-- Wait for ClientEvent
local ClientEvent = Remotes:WaitForChild("ClientEvent", 10)
if not ClientEvent then
    print("[Client] ERROR: ClientEvent not found after 10 seconds!")
    return
end

print("[Client] DEBUG: Found ClientEvent")

-- Cache UI references
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local HUD = PlayerGui:WaitForChild("HUD")

-- Initially hide HUD
HUD.Enabled = false

local playerCountLabel = HUD:WaitForChild("PlayerCount"):WaitForChild("TextLabel")
local tileCountLabel = HUD:WaitForChild("TileCount"):WaitForChild("TextLabel")
local timerLabel = HUD:WaitForChild("Timer"):WaitForChild("TextLabel")

-- Get UI elements
local function handleClientEvent(eventName: string, data: any)
    print(`[Client] DEBUG: Event received: {eventName}`)
    
    if eventName == "gameState" then
        -- Show/hide HUD based on game state
        HUD.Enabled = data.isRunning
        print(`[Client] HUD visibility set to {data.isRunning}`)
    elseif eventName == "updateHUD" then
        print("[Client] DEBUG: Processing updateHUD event")
        local hudData = data
        
        -- Only update if HUD is enabled
        if HUD.Enabled then
            local success, error = pcall(function()
                -- Try to get StarterGui first
                local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
                if not playerGui then
                    error("PlayerGui not found")
                    return
                end
                print("[Client] DEBUG: Found PlayerGui")
                
                -- Use cached references
                playerCountLabel.Text = tostring(hudData.playerCount)
                tileCountLabel.Text = tostring(hudData.tileCount)
                timerLabel.Text = string.format("%02d:%02d", 
                    math.floor(hudData.timeLeft / 60),
                    math.floor(hudData.timeLeft % 60)
                )
                print("[Client] DEBUG: Updated all UI elements")
            end)
            
            if not success then
                print("[Client] ERROR in handleClientEvent:", error)
            end
        end
    elseif eventName == "countdown" then
        print(`[Client] Countdown update: {data}`)
    end
end

print("[Client] Setting up event connection...")
ClientEvent.OnClientEvent:Connect(handleClientEvent)
print("[Client] Event connection established")

-- Add character spawned handler
localPlayer.CharacterAdded:Connect(function(character)
    print("[Client] Character added")
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Optional: Add character modifications here
    humanoid.WalkSpeed = 16
    humanoid.JumpPower = 50
    print("[Client] Character modifications applied")
end)