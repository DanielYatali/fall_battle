local TileManager = require(script.Parent.TileManager)
local BotManager = require(script.Parent.BotManager)

local GameManager = {}
GameManager.__index = GameManager

-- Constants
local GAME_DURATION = 180 -- 3 minutes max game time
local HUD_UPDATE_INTERVAL = 1 -- Update HUD every 0.5 seconds

function GameManager.new()
    local self = setmetatable({}, GameManager)
    self.tileManager = TileManager.new()
    self.isGameRunning = false
    self.lobbyManager = require(script.Parent.LobbyManager).new(self)
    self.gameTimer = GAME_DURATION
    self.activePlayers = {}
    self.botManager = BotManager.new()
    self:SetupKillBrick()
    return self
end

function GameManager:UpdateHUD()
    if not self.isGameRunning then
        print("[GameManager] UpdateHUD called but game is not running")
        return
    end

    local playerCount = 0
    for _ in pairs(self.activePlayers) do
        playerCount += 1
    end

    print(`[GameManager] DEBUG: Active players: {playerCount}`)
    print(`[GameManager] DEBUG: Active tiles: {#self.tileManager.activeTilesList}`)
    print(`[GameManager] DEBUG: Time remaining: {self.gameTimer}`)

    -- Send HUD update to all players
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    if not ReplicatedStorage.Remotes then
        print("[GameManager] ERROR: Remotes folder not found!")
        return
    end
    if not ReplicatedStorage.Remotes.ClientEvent then
        print("[GameManager] ERROR: ClientEvent not found!")
        return
    end

    print("[GameManager] DEBUG: Attempting to fire ClientEvent...")
    ReplicatedStorage.Remotes.ClientEvent:FireAllClients("updateHUD", {
        playerCount = playerCount,
        tileCount = #self.tileManager.activeTilesList,
        timeLeft = self.gameTimer
    })
    print("[GameManager] DEBUG: ClientEvent fired")
end

function GameManager:StartGame(readyPlayers)
    if self.isGameRunning then 
        print("[GameManager] Game already running - Start request ignored")
        return 
    end
    
    if not readyPlayers then
        print("[GameManager] No ready players provided - Start request ignored")
        return
    end
    
    -- Add bots if only one player
    local playerCount = 0
    for _ in pairs(readyPlayers) do
        playerCount += 1
    end
    
    print(`[GameManager] Initial player count: {playerCount}`)
    
    -- Add bots BEFORE setting game state
    if playerCount == 1 then
        print("[GameManager] Single player detected, adding bots...")
        self:AddBots(2)
        -- Update readyPlayers with bot data
        for botName, _ in pairs(self.activePlayers) do
            readyPlayers[botName] = true
        end
    end
    
    self.isGameRunning = true
    self.gameTimer = GAME_DURATION
    self.activePlayers = readyPlayers
    
    print("[GameManager] Final player list:")
    for playerId, _ in pairs(self.activePlayers) do
        print(`- {playerId}`)
    end
    
    -- Notify clients that game is starting
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    ReplicatedStorage.Remotes.ClientEvent:FireAllClients("gameState", {
        isRunning = true
    })
    
    -- Create the tile platform
    print("[GameManager] Creating tile platform...")
    self.tileManager:CreateTilePlatform()
    -- print(`[GameManager] Platform created with {#self.tileManager.activeTiles} tiles`)
    
    -- Set up death handlers for all players
    for userId, _ in pairs(readyPlayers) do
        if typeof(userId) == "number" then
            local player = game:GetService("Players"):GetPlayerByUserId(userId)
            if player and player.Character then
                local humanoid = player.Character:WaitForChild("Humanoid")
                humanoid.Died:Connect(function()
                    self:HandlePlayerDeath(userId)
                end)
            end
            
            -- Also handle when player's character is removed
            player.CharacterRemoving:Connect(function()
                self:HandlePlayerDeath(userId)
            end)
        end
    end
    
    -- Spawn players
    self:SpawnPlayers(readyPlayers)
    
    -- Start game loop
    print("[GameManager] Starting game loop...")
    task.spawn(function()
        while self.isGameRunning do
            self.gameTimer -= HUD_UPDATE_INTERVAL
            self:UpdateHUD()
            
            -- Check for game end conditions
            if self.gameTimer <= 0 then
                print("[GameManager] Game ended - Time limit reached")
                self:EndGame("Time's up!")
                break
            end
            
            if #self.tileManager.activeTilesList == 0 then
                print("[GameManager] Game ended - All tiles destroyed")
                self:EndGame("No tiles left!")
                break
            end
            
            task.wait(HUD_UPDATE_INTERVAL)
        end
    end)
    
    -- Start tile removal loop
    print("[GameManager] Starting tile removal loop...")
    task.spawn(function()
        while self.isGameRunning do
            print(`[GameManager] Removing tiles... ({#self.tileManager.activeTilesList} remaining)`)
            task.wait(4)
            self.tileManager:RemoveRandomTile()
            task.wait(0.5)
            self.tileManager:RemoveRandomTile()
        end
    end)
end

function GameManager:EndGame(reason)
    if not self.isGameRunning then return end
    
    self.isGameRunning = false
    
    -- Notify clients that game is ending
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    ReplicatedStorage.Remotes.ClientEvent:FireAllClients("gameState", {
        isRunning = false,
        endReason = reason
    })
    
    print(`[GameManager] Game ended: {reason}`)
    
    -- Clean up any remaining bots
    for playerId, _ in pairs(self.activePlayers) do
        if typeof(playerId) == "string" and string.match(playerId, "Bot_") then
            local bot = workspace:FindFirstChild(playerId)
            if bot then
                bot:Destroy()
            end
        end
    end
    
    self.activePlayers = {}
end

function GameManager:SpawnPlayers(readyPlayers)
    if not readyPlayers then return end
    
    local spawnedCount = 0
    local SPAWN_HEIGHT_OFFSET = 40
    
    for userId, _ in pairs(readyPlayers) do
        local character
        if typeof(userId) == "number" then
            -- Real player
            local player = game:GetService("Players"):GetPlayerByUserId(userId)
            if player then
                character = player.Character
            end
        else
            -- Bot
            character = workspace:FindFirstChild(userId)
        end
        
        if character then
            if #self.tileManager.activeTilesList > 0 then
                local randomTile = self.tileManager.activeTilesList[math.random(1, #self.tileManager.activeTilesList)]
                local spawnPos = randomTile.Position + Vector3.new(
                    math.random(-3, 3),
                    SPAWN_HEIGHT_OFFSET,
                    math.random(-3, 3)
                )
                
                character:PivotTo(CFrame.new(spawnPos))
                spawnedCount += 1
                print(`[GameManager] Spawned {character.Name} at position {spawnPos}`)
            end
        end
    end
    
    print(`[GameManager] Spawned {spawnedCount} players/bots`)
end

function GameManager:SetupKillBrick()
    local arena = workspace:WaitForChild("Arena")
    arena.Touched:Connect(function(hit)
        local humanoid = hit.Parent:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Health = 0
            -- Handle player/bot death
            local model = humanoid.Parent
            if model then
                self:HandlePlayerDeath(model.Name)
            end
        end
    end)
    print("[GameManager] Arena kill trigger setup complete")
end

function GameManager:HandlePlayerDeath(playerNameOrId)
    if not self.isGameRunning then return end
    
    print(`[GameManager] Handling death of: {playerNameOrId}`)
    
    -- Remove from active players
    self.activePlayers[playerNameOrId] = nil
    
    -- Count remaining players
    local remainingCount = 0
    local lastPlayer = nil
    for playerId, _ in pairs(self.activePlayers) do
        remainingCount += 1
        lastPlayer = playerId
    end
    
    print(`[GameManager] Players remaining: {remainingCount}`)
    
    -- Check for game end (one or zero players remaining)
    if remainingCount <= 1 then
        if remainingCount == 1 then
            -- Get winner name
            local winnerName = "Unknown"
            if typeof(lastPlayer) == "number" then
                local player = game:GetService("Players"):GetPlayerByUserId(lastPlayer)
                if player then
                    winnerName = player.Name
                end
            else
                winnerName = lastPlayer -- Bot name
            end
            self:EndGame(`{winnerName} wins!`)
        else
            self:EndGame("No players remaining!")
        end
    end
end

function GameManager:AddBots(count)
    print(`[GameManager] Starting to add {count} bots`)
    
    -- Check if ReplicatedStorage has the Dummy model
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local dummyTemplate = ReplicatedStorage:FindFirstChild("Dummy")
    if not dummyTemplate then
        print("[GameManager] ERROR: Dummy template not found in ReplicatedStorage!")
        return
    end
    print("[GameManager] Found Dummy template")
    
    for i = 1, count do
        print(`[GameManager] Creating bot {i} of {count}`)
        local bot = self.botManager:CreateBot()
        if bot then
            print(`[GameManager] Successfully created bot: {bot.Name}`)
            self.activePlayers[bot.Name] = true
            print(`[GameManager] Added bot {bot.Name} to active players`)
        else
            print("[GameManager] Failed to create bot!")
        end
    end
    
    -- Print final bot count
    local botCount = 0
    for playerId, _ in pairs(self.activePlayers) do
        if typeof(playerId) == "string" and string.match(playerId, "Bot_") then
            botCount += 1
        end
    end
    print(`[GameManager] Total bots added: {botCount}`)
end

return GameManager 