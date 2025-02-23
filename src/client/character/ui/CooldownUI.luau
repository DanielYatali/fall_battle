local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Logger)
local TweenService = game:GetService("TweenService")

local CooldownUI = {}

local function createCooldownFrame()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CooldownUI"
    
    -- Create main frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 60, 0, 60)
    frame.Position = UDim2.new(0.85, 0, 0.49, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Name = "KickCooldown"
    
    -- Make the frame interactive
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.Position = UDim2.new(0, 0, 0, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Name = "KickButton"
    button.Parent = frame
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.15, 0)
    corner.Parent = frame
    
    -- Create background circle
    local backgroundCircle = Instance.new("Frame")
    backgroundCircle.Size = UDim2.new(0.9, 0, 0.9, 0)
    backgroundCircle.Position = UDim2.new(0.05, 0, 0.05, 0)
    backgroundCircle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    backgroundCircle.BorderSizePixel = 0
    backgroundCircle.Name = "BackgroundCircle"
    
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = backgroundCircle
    backgroundCircle.Parent = frame
    
    -- Create cooldown overlay (circular progress)
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 0, 0)
    overlay.Position = UDim2.new(0, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(85, 255, 255)
    overlay.BorderSizePixel = 0
    overlay.Name = "Overlay"
    overlay.AnchorPoint = Vector2.new(0, 1)
    overlay.Parent = backgroundCircle
    
    -- Create text label for key
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(0.6, 0, 0.4, 0)
    keyLabel.Position = UDim2.new(0.2, 0, 0.15, 0)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Text = "🦵"
    keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyLabel.TextScaled = true
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.Name = "KeyLabel"
    keyLabel.Parent = frame
    
    -- Create text label for countdown
    local timeLabel = Instance.new("TextLabel")
    timeLabel.Size = UDim2.new(0.8, 0, 0.4, 0)
    timeLabel.Position = UDim2.new(0.1, 0, 0.5, 0)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Text = "Ready"
    timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timeLabel.TextScaled = true
    timeLabel.Font = Enum.Font.GothamMedium
    timeLabel.Name = "TimeLabel"
    timeLabel.Parent = frame
    
    -- Add glow effect when ready
    local glowEffect = Instance.new("Frame")
    glowEffect.Size = UDim2.new(1.2, 0, 1.2, 0)
    glowEffect.Position = UDim2.new(-0.1, 0, -0.1, 0)
    glowEffect.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    glowEffect.BackgroundTransparency = 0.9
    glowEffect.Name = "GlowEffect"
    glowEffect.Visible = false
    
    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0.15, 0)
    glowCorner.Parent = glowEffect
    glowEffect.Parent = frame
    
    frame.Parent = screenGui
    screenGui.Parent = playerGui
    
    return frame
end

function CooldownUI.new()
    local cooldownFrame = createCooldownFrame()
    local lastProgress = 0
    local isReady = false
    
    local function updateCooldown(progress)
        local overlay = cooldownFrame.BackgroundCircle.Overlay
        local timeLabel = cooldownFrame.TimeLabel
        local glowEffect = cooldownFrame.GlowEffect
        
        isReady = progress >= 1
        
        -- Update progress bar
        overlay.Size = UDim2.new(1, 0, 1 - progress, 0)
        
        -- Update time label
        if progress >= 1 then
            timeLabel.Text = "Ready"
            timeLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
            
            -- Show glow effect when ability becomes ready
            if lastProgress < 1 then
                glowEffect.Visible = true
                local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local glowTween = TweenService:Create(glowEffect, tweenInfo, {BackgroundTransparency = 0.7})
                glowTween:Play()
                task.delay(0.5, function()
                    local fadeTween = TweenService:Create(glowEffect, tweenInfo, {BackgroundTransparency = 0.9})
                    fadeTween:Play()
                end)
            end
        else
            local timeLeft = math.ceil((1 - progress) * 13)
            timeLabel.Text = tostring(timeLeft)
            timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            glowEffect.Visible = false
        end
        
        -- Update colors based on progress
        if progress >= 1 then
            cooldownFrame.BackgroundCircle.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
        else
            cooldownFrame.BackgroundCircle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end
        
        lastProgress = progress
    end
    
    -- Return the button for input handling
    return {
        updateCooldown = updateCooldown,
        button = cooldownFrame.KickButton,
        isReady = function() return isReady end
    }
end

return CooldownUI 