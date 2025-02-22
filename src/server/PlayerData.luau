local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientEvent = ReplicatedStorage.Remotes.ClientEvent
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local GameEvents = require(ReplicatedStorage.GameEvents)
local PlayerDataTemplate = require(ReplicatedStorage.PlayerData)
local ProfileStore = require(ServerScriptService.Packages.ProfileStore)


local DATA_STORE_KEY = "Production"

if RunService:IsStudio() then
    DATA_STORE_KEY = "Test"
end

local PlayerStore = ProfileStore.New(DATA_STORE_KEY, PlayerDataTemplate.DEFAULT_PLAYER_DATA)
local Profiles : {
    [player]: typeof(PlayerStore:StartSessionAsync())
} = {}


local Local = {}

local Shared = {}

function Local.OnStart()
    for _, player in Players:GetPlayers() do
        task.spawn(Local.LoadProfile, player)
    end
    Players.PlayerAdded:Connect(function(player)
        Local.LoadProfile(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        Local.RemoveProfile(player)
    end)
end


function Local.LoadProfile(player: Player)
    local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
        Cancel = function()
            return player.Parent ~= Players
        end
    })
    if profile == nil then
        return player:Kick("Failed to load profile. Please rejoin the game.")
    end
    profile:AddUserId(player.UserId)
    profile:Reconcile()

    profile.OnSessionEnd:Connect(function()
        Profiles[player] = nil
        player:Kick("Profile session ended. Please rejoin the game.")
    end)

    local isInGame = player.Parent == Players

    if isInGame then
        Profiles[player] = profile
        local data = Shared.GetData(player)
        if data then
            ClientEvent:FireClient(player, GameEvents.SetState, data)
        end
    else
        profile:EndSession()
    end
end

function Local.RemoveProfile(player: Player)
    local profile = Profiles[player]
    if profile ~= nil then
        profile:EndSession()
    end
end

function Shared.GetData(player: Player): PlayerDataTemplate.PlayerData?
    local profile = Profiles[player]
    if profile == nil then return end
    return profile.Data
end

function Shared.UpdateGems(player: Player, amount: number)
    local data = Shared.GetData(player)
    if not data then return end
    local gems = data.gems
    print(`{player.Name} has {gems} gems`)
    data.gems = gems + amount
    print(`{player.Name} now has {data.gems} gems`)
    print(data)
    ClientEvent:FireClient(player, GameEvents.UpdateState, {gems = data.gems})
end

function Shared.UpdateWins(player: Player, amount: number)
    local data = Shared.GetData(player)
    if not data then return end
    local wins = data.wins
    data.wins = wins + amount
end



Local.OnStart()












return Shared