local LobbyManager = {}
LobbyManager.__index = LobbyManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Constants
local GAME_START_THRESHOLD = 1 -- Changed to 1 player needed to start

function LobbyManager.new(gameManager)
    local self = setmetatable({}, LobbyManager)
    self.gameManager = gameManager
    self.playersReady = {}
    self.isWaitingForPlayers = false
    self:SetupTrigger()
    return self
end

function LobbyManager:SetupTrigger()
    local waitingArea = workspace:WaitForChild("WaitingArea")
    
    -- Create trigger slightly larger than waiting area
    local triggerSize = waitingArea.Size + Vector3.new(2, 4, 2)
    local triggerPos = waitingArea.Position + Vector3.new(0, triggerSize.Y/2, 0)
    
    local waitingTrigger = Instance.new("Part")
    waitingTrigger.Size = triggerSize
    waitingTrigger.Position = triggerPos
    waitingTrigger.Anchored = true
    waitingTrigger.CanCollide = false
    waitingTrigger.Transparency = 0.8
    waitingTrigger.Material = Enum.Material.Neon
    waitingTrigger.Color = Color3.fromRGB(0, 255, 0)
    waitingTrigger.Parent = workspace

    -- Create trigger detection
    waitingTrigger.Touched:Connect(function(hit)
        local humanoid = hit.Parent:FindFirstChild("Humanoid")
        if humanoid then
            local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
            if player then
                self:PlayerEnterWaitingArea(player)
            end
        end
    end)
end

function LobbyManager:PlayerEnterWaitingArea(player)
    if not self.playersReady[player.UserId] then
        self.playersReady[player.UserId] = true
        print(`[LobbyManager] {player.Name} entered waiting area`)
        self:UpdateWaitingStatus()
    end
end

function LobbyManager:UpdateWaitingStatus()
    local readyCount = 0
    for _, player in pairs(game:GetService("Players"):GetPlayers()) do
        if self.playersReady[player.UserId] then
            readyCount += 1
        end
    end

    print(`[LobbyManager] Players ready: {readyCount}/{GAME_START_THRESHOLD}`)

    if readyCount >= GAME_START_THRESHOLD and not self.isWaitingForPlayers then
        self.isWaitingForPlayers = true
        print("[LobbyManager] Starting countdown!")
        self:StartCountdown()
    end
end

function LobbyManager:StartCountdown()
    local countdown = 5
    
    task.spawn(function()
        while countdown > 0 do
            print(`[LobbyManager] Game starting in: {countdown}`)
            -- Broadcast countdown to all players
            ReplicatedStorage.Remotes.ClientEvent:FireAllClients("countdown", countdown)
            countdown -= 1
            task.wait(1)
        end
        
        print("[LobbyManager] Starting game!")
        self.gameManager:StartGame(self.playersReady)
        self.playersReady = {}
        self.isWaitingForPlayers = false
    end)
end

return LobbyManager 