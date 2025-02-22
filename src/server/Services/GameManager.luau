local TileManager = require(script.Parent.TileManager)
local BotManager = require(script.Parent.BotManager)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientEvent = ReplicatedStorage.Remotes.ClientEvent
local GameEvents = require(ReplicatedStorage.GameEvents)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local SpawnLocation = Workspace:WaitForChild("SpawnLocation")
local GameManager = {}
GameManager.__index = GameManager

-- Constants
local CONSTANTS = {
    GAME_DURATION = 300, -- 5 minutes
    HUD_UPDATE_INTERVAL = 1,
    LOBBY_COUNTDOWN = 20,
    MINIMUM_PLAYERS = 2,
    SPAWN_HEIGHT_OFFSET = 40,
    TILE_REMOVAL_INTERVAL = 0.5,
    TILE_REMOVAL_COUNT = 1,
    REWARD_MULTIPLIER = 20
}

--[[ Constructor ]]
function GameManager.new(PlayerData)
    local self = setmetatable({}, GameManager)
    self.PlayerData = PlayerData
    
    -- Initialize state
    self.tileManager = TileManager.new()
    self.botManager = BotManager.new()
    self.isGameRunning = false
    self.gameTimer = CONSTANTS.GAME_DURATION
    self.lobbyTimer = CONSTANTS.LOBBY_COUNTDOWN
    self.activePlayers = {}
    self.readyPlayers = {}
    self.tilesGenerated = false
    
    -- Setup initial game state
    self:InitializeGame()
    
    return self
end

--[[ Game Initialization ]]
function GameManager:InitializeGame()
    self:SetupKillBrick()
    self:StartGameLoop()
end

--[[ Core Game Loop ]]
function GameManager:StartGameLoop()
    task.spawn(function()
        while true do
            if self.isGameRunning then
                self:CheckGameEnd()
            end
            self:CheckStartAndStatus()
            task.wait(CONSTANTS.HUD_UPDATE_INTERVAL)
        end
    end)
end

function GameManager:CheckStartAndStatus()
    -- Get accurate counts
    local playerCount
    if self.isGameRunning then
        playerCount = self:GetCount(self.activePlayers)
    else
        playerCount = self:GetCount(self.readyPlayers)
        if playerCount > 0 then
            self.lobbyTimer -= 1
        if self.lobbyTimer <= 0 then
            self:StartGame(self.readyPlayers)
            self.readyPlayers = {}
            self.lobbyTimer = CONSTANTS.LOBBY_COUNTDOWN
            end
        else
            self.lobbyTimer = CONSTANTS.LOBBY_COUNTDOWN
        end
    end
    
    local tileCount = #self.tileManager.activeTilesList
    local timeLeft = self.isGameRunning and self.gameTimer or self.lobbyTimer
    
    ClientEvent:FireAllClients(GameEvents.UpdateHUD, {
        playerCount = playerCount,
        tileCount = tileCount,
        timeLeft = timeLeft,
        isGameRunning = self.isGameRunning
    })
end

--[[ Player Management ]]
function GameManager:HandlePlayerReady(player, isReady)
    if self.isGameRunning then 
        print(`[GameManager] {player.Name} tried to ready while game in progress`)
        return 
    end
    
    if isReady then
        self.readyPlayers[player.UserId] = true
        
        -- Generate tiles when first player readies up
        if not self.tilesGenerated then
            task.spawn(function()
                self.tileManager:CreateTilePlatform()
                self.tilesGenerated = true
            end)
        end
    else
        self.readyPlayers[player.UserId] = nil
        
        -- If no players are ready, clean up tiles
        -- if self:GetReadyPlayerCount() == 0 then
        --     self.tileManager:RemoveAllTiles()
        --     self.tilesGenerated = false
        -- end
    end
end

function GameManager:CheckGameEnd()
    if not self.isGameRunning then return end -- Safety check
    
    self.gameTimer -= CONSTANTS.HUD_UPDATE_INTERVAL
    
    -- Check game end conditions
    if self.gameTimer <= 0 then
        self:EndGame("Time's up!")
        return
    end
    
    -- if #self.tileManager.activeTilesList == 0 then
    --     self:EndGame("No tiles left!")
    --     return
    -- end
    
    -- Check if we have enough active players
    local activePlayerCount = self:GetCount(self.activePlayers)
    if activePlayerCount == 0 then
        self:EndGame("No players remaining!")
    end
end

function GameManager:StartGame(readyPlayers)
    print("Starting game")
    if self.isGameRunning or not readyPlayers then return end
    print("Game not running and ready players exist")
    
    -- Initialize game state first
    self.isGameRunning = true
    self.gameTimer = CONSTANTS.GAME_DURATION
    self.activePlayers = {}  -- Clear active players before adding new ones
    
    -- Only generate tiles if they haven't been generated yet
    if not self.tilesGenerated then
        self.tileManager:CreateTilePlatform()
        self.tilesGenerated = true
    end
    
    -- Handle single player case
    if self:GetReadyPlayerCount() == 1 then
        self:AddBots(20)
    end
    
    -- Add ready players to active players and notify them
    for playerId, _ in pairs(readyPlayers) do
        self.activePlayers[playerId] = true
    end
    
    -- Setup game environment
    self:NotifyGameStart()
    self:SpawnPlayers(self.activePlayers)
    self:StartTileRemovalLoop()
    
    print("[GameManager] Game started with players:", self:GetCount(self.activePlayers))
end

function GameManager:NotifyGameStart()
    ClientEvent:FireAllClients(GameEvents.GameStart, {players  = self.activePlayers})
end

function GameManager:NotifyGameEnd(reason)
    ClientEvent:FireAllClients(GameEvents.GameEnd, {reason = reason})
end

function GameManager:EndGame(reason)
    if not self.isGameRunning then return end
    
    self.isGameRunning = false
    self:NotifyGameEnd(reason)
    self:CleanupBots()
    self.activePlayers = {}
    self.gameTimer = CONSTANTS.GAME_DURATION
    task.wait(2)
    self.tileManager:RemoveAllTiles()
    self.tilesGenerated = false  -- Reset the flag when game ends
end

function GameManager:HandlePlayerDeath(playerNameOrId)
    if not self.isGameRunning then return end
    
    
    self.activePlayers[playerNameOrId] = nil
    
    local remainingCount = self:GetCount(self.activePlayers)
    local rewardAmount = CONSTANTS.REWARD_MULTIPLIER / (remainingCount + 1)
    local rewardInt = math.floor(rewardAmount)
    --this could error because of bot so we handle it
    --convert playerNameOrId to number
    if typeof(playerNameOrId) == "number" then
        local player = Players:GetPlayerByUserId(playerNameOrId)
        ClientEvent:FireClient(player, GameEvents.Results, {result = "You Died!", won = false,rewardAmount = rewardInt})
        self.PlayerData.UpdateGems(player, rewardInt)
    end
    
    -- if remainingCount <= 1 then
        if remainingCount == 1 then
            local winner, winnerType = self:GetWinner()

            if winnerType == "Player" then
                self.PlayerData.UpdateGems(winner, rewardInt)
                ClientEvent:FireClient(winner, GameEvents.Results, {result = "Winner", won = true,rewardAmount = rewardInt})
                self:TeleportPlayerToSpawn(winner)
            end
            local winnerName = winner.Name
            if winnerType == "Bot" then
                winnerName = winner
            end
            self:EndGame(`{winnerName} wins!`)
        -- else
        --     ClientEvent:FireClient(player, GameEvents.Results, {result = "You Died!", won = false,rewardAmount = rewardInt})
        --     self:EndGame("No players remaining!")
        end

    -- end
end

--[[ Bot Management ]]
function GameManager:AddBots(count)
    for i = 1, count do
        local bot = self.botManager:CreateBot()
        if bot then
            self.activePlayers[bot.Name] = true
        end
    end
end

function GameManager:CleanupBots()
    for playerId, _ in pairs(self.activePlayers) do
        if typeof(playerId) == "string" and string.match(playerId, "Bot_") then
            local bot = workspace:FindFirstChild(playerId)
            if bot then bot:Destroy() end
        end
    end
end

--[[ Helper Methods ]]
function GameManager:GetWinner()
    local lastPlayer = next(self.activePlayers)
    if typeof(lastPlayer) == "number" then
        local player = Players:GetPlayerByUserId(lastPlayer)
        return player, "Player"
    end
    return lastPlayer, "Bot"
end

function GameManager:GetReadyPlayerCount()
    return self:GetCount(self.readyPlayers)
end

function GameManager:GetCount(object)
    local count = 0
    for _ in pairs(object) do count += 1 end
    return count
end

function GameManager:SpawnPlayers(readyPlayers)
    if not readyPlayers then return end
    
    local spawnedCount = 0
    
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
                local tilePosition = randomTile:GetPivot().Position
                local spawnPos = tilePosition + Vector3.new(
                    math.random(-3, 3),
                    CONSTANTS.SPAWN_HEIGHT_OFFSET,
                    math.random(-3, 3)
                )
                
                character:PivotTo(CFrame.new(spawnPos))
                spawnedCount += 1
            end
        end
    end
    
end

function GameManager:SetupKillBrick()
    local arena = workspace:WaitForChild("Arena")
    arena.Touched:Connect(function(hit)
        if(hit.Parent == nil) then 
            print("Hit parent is nil")
            return 
        end
        local humanoid = hit.Parent:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local model = humanoid.Parent
            if model then
                -- Get the correct ID (either UserId for players or Name for bots)
                local playerId
                local player = Players:GetPlayerFromCharacter(model)
                if player then
                    playerId = player.UserId
                else
                    -- If no player found, assume it's a bot
                    playerId = model.Name
                end
                
                -- Set health to 0 after getting the ID to ensure proper death handling
                humanoid.Health = 0
                self:HandlePlayerDeath(playerId)
            end
        end
    end)
end

function GameManager:StartTileRemovalLoop()
    task.spawn(function()
        while self.isGameRunning do
            for i = 1, CONSTANTS.TILE_REMOVAL_COUNT do
                self.tileManager:RemoveRandomTile()
            end
            task.wait(CONSTANTS.TILE_REMOVAL_INTERVAL)
        end
    end)
end

function GameManager:TeleportPlayerToSpawn(player)
    player.Character:PivotTo(SpawnLocation.CFrame + Vector3.new(0, 20, 0))
end

return GameManager 