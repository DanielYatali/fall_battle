local Animator = require(game:GetService("ReplicatedStorage").AnimationController)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientEvent = ReplicatedStorage.Remotes.ClientEvent
local GameEvents = require(ReplicatedStorage.GameEvents)
local Logger = require(ReplicatedStorage.Logger)
local CooldownUI = require(script.Parent.Parent.ui.CooldownUI)

local KickHandler = {}

local COOLDOWN_DURATION = 5 -- 20 second cooldown

local state = {
    Humanoid = nil,
    Character = nil,
    RootPart = nil,
    IsActive = false,
    LastKickTime = 0,
    cooldownUI = nil,
}

function KickHandler.new(humanoid, rootPart, character)
    assert(humanoid, "Humanoid is required")
    assert(rootPart, "RootPart is required")
    assert(character, "Character is required")

    -- First destroy the previous state
    KickHandler.destroy()

    -- Then set the new state
    state.Humanoid = humanoid
    state.RootPart = rootPart
    state.Character = character
    state.cooldownUI = CooldownUI.new()

    -- Connect button press for mobile users
    state.cooldownUI.button.Activated:Connect(function()
        if state.cooldownUI.isReady() then
            KickHandler.Activate()
        end
    end)

    -- Start cooldown update loop
    task.spawn(function()
        while state.Character do
            local currentTime = tick()
            local timeSinceLastKick = currentTime - state.LastKickTime
            local progress = math.clamp(timeSinceLastKick / COOLDOWN_DURATION, 0, 1)
            state.cooldownUI.updateCooldown(progress)
            task.wait(0.1)
        end
    end)

    return KickHandler
end

function KickHandler.isOnCooldown()
    return (tick() - state.LastKickTime) < COOLDOWN_DURATION
end

function handleHitDetection()
    if not state.RootPart then
        Logger.warn("Cannot perform hit detection - RootPart is nil")
        return
    end

    local cf = state.RootPart.CFrame
    local size = Vector3.new(8, 8, 8)

    local box = Instance.new("Part")
    box.Anchored = true
    box.CanCollide = false
    box.Transparency = 1
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Size = size
    box.CFrame = cf
    box.Parent = workspace
    game.Debris:AddItem(box, 0.5)

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {state.Character}
    local hitResults = {}
    local hitCharacters = {} -- Track which characters we've already hit

    local parts = workspace:GetPartBoundsInBox(cf, size, overlapParams)
    for _, part in ipairs(parts) do
        local hitCharacter = part:FindFirstAncestorOfClass("Model")
        if hitCharacter and not hitCharacters[hitCharacter] then
            local humanoid = hitCharacter:FindFirstChild("Humanoid")
            if humanoid then
                hitCharacters[hitCharacter] = true -- Mark this character as processed
                table.insert(hitResults, {
                    character = hitCharacter,
                    instance = part,
                })
            end
        end
    end

    if #hitResults > 0 then
        Logger.info("Kick detected - " .. #hitResults .. " unique characters hit")
        ClientEvent:FireServer(GameEvents.Kick, hitResults)
    end
end

function KickHandler.Activate()
    if not state.RootPart then
        Logger.warn("Cannot activate kick - RootPart is nil")
        return
    end

    if KickHandler.isOnCooldown() then
        Logger.info("Kick is on cooldown")
        return
    end

    state.IsActive = true
    state.LastKickTime = tick()
    Animator.playAnimation("kick")
    task.delay(0.3, handleHitDetection)
end

function KickHandler.stop()
    Animator.stopAnimation("kick")
    state.IsActive = false
end

function KickHandler.destroy()
    state.Humanoid = nil
    state.RootPart = nil
    state.IsActive = false
    state.LastKickTime = 0
    -- Clean up UI if it exists
    if state.cooldownUI then
        -- Find and remove the UI
        local player = game.Players.LocalPlayer
        local cooldownUI = player.PlayerGui:FindFirstChild("CooldownUI")
        if cooldownUI then
            cooldownUI:Destroy()
        end
    end
end

return KickHandler