local TileManager = require(script.Parent.TileManager)

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
    
    local playerCount = 0
    for _ in pairs(readyPlayers) do
        playerCount += 1
    end
    print(`[GameManager] Starting game with {playerCount} players`)
    
    self.isGameRunning = true
    self.gameTimer = GAME_DURATION
    self.activePlayers = readyPlayers
    
    -- Notify clients that game is starting
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    ReplicatedStorage.Remotes.ClientEvent:FireAllClients("gameState", {
        isRunning = true
    })
    
    -- Create the tile platform
    print("[GameManager] Creating tile platform...")
    self.tileManager:CreateTilePlatform()
    -- print(`[GameManager] Platform created with {#self.tileManager.activeTiles} tiles`)
    
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
    self.isGameRunning = false
    
    -- Notify clients that game is ending
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    ReplicatedStorage.Remotes.ClientEvent:FireAllClients("gameState", {
        isRunning = false
    })
    
    print(`[GameManager] Game ended: {reason}`)
    -- Add any end game logic here (e.g., declaring winners, resetting players)
end

function GameManager:SpawnPlayers(readyPlayers)
    if not readyPlayers then return end
    
    local spawnedCount = 0
    local SPAWN_HEIGHT_OFFSET = 40 -- Height above the platform to spawn players
    
    for userId in pairs(readyPlayers) do
        local player = game:GetService("Players"):GetPlayerByUserId(userId)
        if player and player.Character then
            -- Get a random tile from the platform
            if #self.tileManager.activeTilesList > 0 then
                local randomTile = self.tileManager.activeTilesList[math.random(1, #self.tileManager.activeTilesList)]
                local spawnPos = randomTile.Position + Vector3.new(
                    math.random(-3, 3), -- Random offset within tile
                    SPAWN_HEIGHT_OFFSET,
                    math.random(-3, 3)
                )
                
                player.Character:PivotTo(CFrame.new(spawnPos))
                spawnedCount += 1
                print(`[GameManager] Spawned player {player.Name} at position {spawnPos}`)
            end
        end
    end
    
    print(`[GameManager] Spawned {spawnedCount} players`)
end

return GameManager 