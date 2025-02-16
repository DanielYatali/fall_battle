local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local ClientEvent = Remotes.ClientEvent
local GameEvents = require(ReplicatedStorage.GameEvents)
local GUIhandler = {}
GUIhandler.__index = GUIhandler


function GUIhandler:BindEvents()
    self.readyButton.MouseButton1Click:Connect(function()
        self.isReady = not self.isReady
        self.readyButton.Text = self.isReady and "Cancel Ready" or "Ready Up"
        ClientEvent:FireServer(GameEvents.PlayerReady, self.isReady)
    end)
end

function GUIhandler.new(player)
    local self = setmetatable({}, GUIhandler)
    self.player = player
    self.playerGui = player:WaitForChild("PlayerGui")
    self.hud = self.playerGui:WaitForChild("HUD")
    self.lobby = self.playerGui:WaitForChild("Lobby")
    self.readyButton = self.lobby:WaitForChild("Frame"):WaitForChild("Ready")
    self.gameStatus = self.lobby:WaitForChild("Frame"):WaitForChild("GameStatus")
    self.playerCountLabel = self.hud:WaitForChild("PlayerCount"):WaitForChild("TextLabel")
    self.tileCountLabel = self.hud:WaitForChild("TileCount"):WaitForChild("TextLabel")
    self.timerLabel = self.hud:WaitForChild("Timer"):WaitForChild("TextLabel")
    self.isReady = false
    self:BindEvents()
    return self
end

function GUIhandler:GameStart(data)
    print("GameStart", data)
    local inGame = false
    if data.players then
        print("Players table:", data.players)
        print("Looking for player ID:", self.player.UserId)
        
        -- Convert UserId to string for table lookup
        inGame = data.players[tostring(self.player.UserId)] == true
        print("Is player in game?", inGame)
    end
    
    if inGame then
        -- reset the ready button and hide the lobby frame
        self.readyButton.Text = "Ready Up"
        self.isReady = false
        self.lobby.Enabled = false
    end
end

function GUIhandler:GameEnd(data)
    self.lobby.Enabled = true
    self.readyButton.Text = "Ready Up"
    self.isReady = false
    self.readyButton.Visible = true
    if data.reason then
        self.gameStatus.Text = data.reason
    end
end

-- function GUIhandler:GameState(data)
--     if data.isRunning then
--         self.gameStatus.Text = "Game in Progress"
--         self.readyButton.Visible = false
--     else
--         self.gameStatus.Text = "Waiting for Players"
--         self.readyButton.Visible = true
--         if data.endReason then
--             self.gameStatus.Text = data.endReason
--         end
--     end
-- end



function GUIhandler:UpdateHUD(data)
    self.playerCountLabel.Text = tostring(data.playerCount)
    self.tileCountLabel.Text = tostring(data.tileCount)
    self.timerLabel.Text = string.format("%d:%02d", 
        math.floor(data.timeLeft / 60),
        math.floor(data.timeLeft % 60))
    if data.isGameRunning then
        self.gameStatus.Text = "Game in Progress"
        self.readyButton.Visible = false
    else
        self.gameStatus.Text = "Waiting for Players"
        self.readyButton.Visible = true
    end

end

return GUIhandler


