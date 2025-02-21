local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Logger = require(script.Parent.Logger)

local AnimationController = {}

local Animations = {
    doubleJump = {
        id = "rbxassetid://80125441179209",
        speed = 1.5,
        transitionTime = 0.2,
        weight = 1.0
    }
}

local LoadedAnimations = {}
local animator = nil

-- Initialize animator when character loads
local function initializeAnimator()
    Logger.log("Initializing animator for new character")
    local character = player.Character
    if not character then
        Logger.log("No character found, waiting for CharacterAdded")
        return
    end

    local humanoid = character:WaitForChild("Humanoid")
    animator = humanoid:WaitForChild("Animator")
    AnimationController.onStart(animator)
end

function AnimationController.onStart(newAnimator)

    if newAnimator then
        -- when the character dies they get a new animator
        animator = newAnimator
        LoadedAnimations = {}
    end

    if #LoadedAnimations == 0 and animator then
        for name, config in pairs(Animations) do
            local animation = Instance.new("Animation")
            animation.AnimationId = config.id

            local track = animator:LoadAnimation(animation)
            -- track.Priority = config.priority
            -- track.Looped = config.looped

            LoadedAnimations[name] = {
                track = track,
                config = config
            }
        end
    end
    return LoadedAnimations
end

function AnimationController.playAnimation(name, speed)
    local animData = LoadedAnimations[name]
    if animData then
        local track = animData.track
        local config = animData.config

        track:Play(config.transitionTime)
        track:AdjustSpeed(speed or config.speed)
    else
    end
end

function AnimationController:stopAnimation(name)
    local animData = LoadedAnimations[name]
    if animData then
        animData.track:Stop(animData.config.transitionTime)
    else
        Logger.log("Warning: Animation not found:", name)
    end
end

-- Initialize for current character if it exists
if player.Character then
    initializeAnimator()
end

-- Handle character respawning
player.CharacterAdded:Connect(initializeAnimator)

return AnimationController
