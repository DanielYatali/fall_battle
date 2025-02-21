local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local ClientEvent = Remotes.ClientEvent
local GameEvents = require(ReplicatedStorage.GameEvents)
local GUIhandler = {}
GUIhandler.__index = GUIhandler

function GUIhandler:BindEvents()
    self.readyButton.MouseButton1Click:Connect(function()
        self.isReady = not self.isReady
        self.readyButton.Text = self.isReady and "Cancel" or "Ready Up"
        ClientEvent:FireServer(GameEvents.PlayerReady, self.isReady)
    end)
    self.SummaryButton.MouseButton1Click:Connect(function()
        self.summary.Enabled = false
    end)
end

function GUIhandler.new(player)
    local self = setmetatable({}, GUIhandler)
    self.player = player
    self.playerGui = player:WaitForChild("PlayerGui")
    self.top = self.playerGui:WaitForChild("Top")
    self.topFrame = self.top:WaitForChild("Frame")
    self.top.Enabled = true

    self.ready = self.playerGui:WaitForChild("Ready")
    self.ready.Enabled = true
    self.readyFrame = self.ready:WaitForChild("Frame")
    self.readyButton = self.readyFrame:WaitForChild("Ready")
    self.gameStatus = self.readyFrame:WaitForChild("GameStatus")
    self.playerCountLabel = self.topFrame:WaitForChild("PlayersCount")
    self.tileCountLabel = self.topFrame:WaitForChild("TilesCount")
    self.timerLabel = self.topFrame:WaitForChild("Timer")
    self.summary = self.playerGui:WaitForChild("MatchSummary")
    self.summaryFrame = self.summary:WaitForChild("Frame")
    self.summaryText = self.summaryFrame:WaitForChild("Summary")
    self.SummaryButton = self.summaryFrame:WaitForChild("TextButton")
    self.RewardAmount = self.summaryFrame:WaitForChild("RewardAmount")
    self.gemsLabel = self.topFrame:WaitForChild("GemsCount")

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
        self.ready.Enabled = false
    end
end

function GUIhandler:SetState(data)
    print("SetState", data)
    self.gemsLabel.Text = tostring(data.gems)
end

function GUIhandler:UpdateState(data)
    print("UpdateState", data)
    self.gemsLabel.Text = tostring(data.gems)
end

function GUIhandler:GameEnd(data)
    self.ready.Enabled = true
    self.readyButton.Text = "Ready Up"
    self.isReady = false
    self.readyButton.Visible = true
    if data.reason then
        self.gameStatus.Text = data.reason
    end
end

function GUIhandler:UpdateHUD(data)
    self.playerCountLabel.Text = tostring(data.playerCount)
    self.tileCountLabel.Text = tostring(data.tileCount)
    self.timerLabel.Text = string.format("%d:%02d", math.floor(data.timeLeft / 60), math.floor(data.timeLeft % 60))
    if data.isGameRunning then
        self.gameStatus.Text = "Game in Progress"
        self.readyButton.Visible = false
    else
        self.gameStatus.Text = "Waiting for Players"
        self.readyButton.Visible = true
    end

end

function GUIhandler:Results(data)
    self.summaryText.Text = data.result
    self.RewardAmount.Text = data.rewardAmount
    self.summary.Enabled = true
end

return GUIhandler

