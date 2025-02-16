local BotManager = {}
BotManager.__index = BotManager

local BOT_NAMES = {"Bot_Alpha", "Bot_Beta", "Bot_Charlie", "Bot_Delta", "Bot_Echo"}
local BOT_COLORS = {
    Color3.fromRGB(255, 100, 100), -- Red
    Color3.fromRGB(100, 255, 100), -- Green
    Color3.fromRGB(100, 100, 255), -- Blue
}

function BotManager.new()
    local self = setmetatable({}, BotManager)
    self.bots = {}
    return self
end

function BotManager:CreateBot()
    
    -- Clone the dummy from ReplicatedStorage
    local dummyTemplate = game:GetService("ReplicatedStorage"):WaitForChild("Dummy")
    if not dummyTemplate then
        print("[BotManager] ERROR: Could not find Dummy template!")
        return nil
    end
    
    local botModel = dummyTemplate:Clone()
    if not botModel then
        print("[BotManager] ERROR: Failed to clone Dummy template!")
        return nil
    end
    
    -- Set random color
    local botColor = BOT_COLORS[math.random(1, #BOT_COLORS)]
    for _, part in botModel:GetDescendants() do
        if part:IsA("BasePart") then
            part.Color = botColor
        end
    end
    
    -- Set up humanoid
    local humanoid = botModel:WaitForChild("Humanoid")
    if not humanoid then
        print("[BotManager] ERROR: No Humanoid found in bot model!")
        botModel:Destroy()
        return nil
    end
    
    -- Position bot on the arena
    local arena = workspace:WaitForChild("SpawnLocation")
    local rootPart = botModel:WaitForChild("HumanoidRootPart")
    if rootPart then
        -- Random position on the arena
        local offset = Vector3.new(
            math.random(-10, 10),
            40, -- Slight height offset to prevent clipping
            math.random(-10, 10)
        )
        rootPart.CFrame = CFrame.new(arena.Position + offset)
    end
    
    -- Set name and parent
    botModel.Name = BOT_NAMES[math.random(1, #BOT_NAMES)] .. "_" .. math.random(1, 1000000)
    botModel.Parent = workspace
    
    -- Add basic movement behavior
    task.spawn(function()
        while humanoid.Health > 0 do
            local rootPart = botModel:FindFirstChild("HumanoidRootPart")
            if rootPart and not rootPart.Anchored then
                humanoid:MoveTo(rootPart.Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)))
            end
            task.wait(math.random(1, 3))
        end
        task.wait(1)
        botModel:Destroy()
    end)
    
    return botModel
end

return BotManager 