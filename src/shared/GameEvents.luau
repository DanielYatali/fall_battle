local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = Instance.new("Folder")
GameEvents.Name = "GameEvents"
GameEvents.Parent = ReplicatedStorage

local UpdateCountdown = Instance.new("RemoteEvent")
UpdateCountdown.Name = "UpdateCountdown"
UpdateCountdown.Parent = GameEvents

-- Add new RemoteEvent for HUD updates
local UpdateHUD = Instance.new("RemoteEvent")
UpdateHUD.Name = "UpdateHUD"
UpdateHUD.Parent = GameEvents

return GameEvents 