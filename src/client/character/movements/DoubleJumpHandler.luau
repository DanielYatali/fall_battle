local UserInputService = game:GetService("UserInputService")
local Logger = require(game:GetService("ReplicatedStorage").Logger)
local Animator = require(game:GetService("ReplicatedStorage").AnimationController)

local DoubleJumpHandler = {}

-- Configuration
local MAX_JUMPS = 2
local JUMP_COOLDOWN = 0.1
local DOUBLE_JUMP_FORCE = 80 -- Adjust this value to change jump height

-- Module state
local state = {
    -- References
    Humanoid = nil,
    RootPart = nil,

    -- Jump state
    NumJumps = 0,
    CanJump = false,
    IsActive = false,

    -- Connections
    StateConnection = nil,
    JumpConnection = nil
}

local function handleStateChange(oldState, newState)
    if newState == Enum.HumanoidStateType.Landed then
        state.NumJumps = 0
        state.CanJump = false

    elseif newState == Enum.HumanoidStateType.Jumping then
        if oldState == Enum.HumanoidStateType.Running then
            state.NumJumps = 1
            state.CanJump = false
        else
            state.CanJump = false
            state.NumJumps = state.NumJumps + 1
        end

    elseif newState == Enum.HumanoidStateType.Freefall then
        if state.NumJumps == 1 and not state.CanJump then
            task.wait(JUMP_COOLDOWN)
            state.CanJump = true
        end
    end
end

local function handleJumpRequest()
    if not state.CanJump then
        return
    end
    if state.NumJumps >= MAX_JUMPS then
        return
    end

    -- Apply upward force
    local currentVelocity = state.RootPart.AssemblyLinearVelocity
    state.RootPart.AssemblyLinearVelocity = Vector3.new(currentVelocity.X, DOUBLE_JUMP_FORCE, currentVelocity.Z)

    -- Change state and play animation
    state.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    Animator.playAnimation("doubleJump")
end

local function bindStateTracking()
    if state.StateConnection then
        state.StateConnection:Disconnect()
    end

    state.StateConnection = state.Humanoid.StateChanged:Connect(handleStateChange)
end

local function bindJumpRequest()
    if state.JumpConnection then
        state.JumpConnection:Disconnect()
    end

    state.JumpConnection = UserInputService.JumpRequest:Connect(handleJumpRequest)
end

function DoubleJumpHandler.new(humanoid, rootPart)
    assert(humanoid, "Humanoid is required")
    assert(rootPart, "RootPart is required")

    -- Cleanup any existing state
    DoubleJumpHandler.destroy()

    -- Initialize new state
    state.Humanoid = humanoid
    state.RootPart = rootPart
    state.IsActive = true

    -- Bind events
    bindStateTracking()
    bindJumpRequest()

    return DoubleJumpHandler
end

function DoubleJumpHandler.stop()
    Animator.stopAnimation("doubleJump")
    state.IsActive = false
end

function DoubleJumpHandler.destroy()
    if state.StateConnection then
        state.StateConnection:Disconnect()
    end
    if state.JumpConnection then
        state.JumpConnection:Disconnect()
    end

    -- Reset all state
    for key in state do
        state[key] = nil
    end

    state.NumJumps = 0
    state.CanJump = false
    state.IsActive = false

end

return DoubleJumpHandler
