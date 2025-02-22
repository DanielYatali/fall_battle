local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local DoubleJumpHandler = require(script.Parent.DoubleJumpHandler)
local Logger = require(game:GetService("ReplicatedStorage").Logger)
local KickHandler = require(script.Parent.KickHandler)

local MovementController = {}

-- Group related state into a state table
local state = {
    -- Character references
    Character = nil,
    Humanoid = nil,
    RootPart = nil,

    -- Movement components
    DoubleJump = nil,
    CurrentAnimation = nil,

    -- Connections
    InputBeganConnection = nil,
    InputEndedConnection = nil,

    -- New state
    Push = nil,
}

local function cancelCurrentMovement()
    if state.DoubleJump and state.DoubleJump.isActive then
        state.DoubleJump:stop()
    end
end

local function bindInputs()

    if state.InputBeganConnection then
        state.InputBeganConnection:Disconnect()
    end

    state.InputBeganConnection = UserInputService.InputBegan:Connect(
        function(input, gameProcessed)
            if gameProcessed then
                return
            end

            if input.KeyCode == Enum.KeyCode.Space then
                cancelCurrentMovement()
            end

            if input.KeyCode == Enum.KeyCode.E then
                KickHandler.Activate()
            end
        end)
end

function MovementController.onStart(newCharacter)

    -- Cleanup existing state
    MovementController.destroy()

    -- Initialize new state
    state.Character = newCharacter
    state.Humanoid = state.Character:WaitForChild("Humanoid")
    state.RootPart = state.Character:WaitForChild("HumanoidRootPart")

    -- Initialize movements
    state.DoubleJump = DoubleJumpHandler.new(state.Humanoid, state.RootPart)
    state.Kick = KickHandler.new(state.Humanoid, state.RootPart, state.Character)

    -- Bind events
    bindInputs()

end

function MovementController.destroy()
    if state.InputBeganConnection then
        state.InputBeganConnection:Disconnect()
    end

    if state.InputEndedConnection then
        state.InputEndedConnection:Disconnect()
    end

    if state.CurrentAnimation then
        state.Animator:stopAnimation(state.CurrentAnimation)
    end

    if state.DoubleJump then
        state.DoubleJump:destroy()
    end

    if state.Push then
        state.Push:destroy()
    end

    -- Reset all state
    for key in state do
        state[key] = nil
    end
end

-- Initialize for current character if it exists
local player = Players.LocalPlayer
if player.Character then
    MovementController.onStart(player.Character)
end

-- Handle character respawning
player.CharacterAdded:Connect(MovementController.onStart)

return MovementController
