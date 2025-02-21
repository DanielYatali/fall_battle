local TileManager = {}
local TilesFolder = workspace:WaitForChild("Tiles")
if not TilesFolder then
    TilesFolder = Instance.new("Folder")
    TilesFolder.Name = "Tiles"
    TilesFolder.Parent = workspace
end

TileManager.__index = TileManager

-- Constants
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TileModels = ReplicatedStorage:WaitForChild("Tiles")
local TILE_SIZE = Vector3.new(10, 1, 10) -- Updated from 8x8 to 10x10
local GRID_SIZE = Vector2.new(20, 20) -- Increased from 10x10 to 20x20
local BASE_HEIGHT = 10 -- Height from baseplate
local WARNING_TIME = 2 -- Time in seconds to show warning
local WARNING_COLOR = Color3.fromRGB(255, 100, 100) -- Red warning color
local DEFAULT_COLOR = Color3.fromRGB(200, 200, 200)

-- Add these new constants after the other constants
local LAYOUTS = {
    FULL = "full",
    CHECKERBOARD = "checkerboard",
    SPIRAL = "spiral",
    CROSS = "cross",
    DONUT = "donut",
}

TileManager.LAYOUTS = LAYOUTS -- Make layouts accessible to other modules

-- Make constants accessible to other modules
TileManager.GRID_SIZE = GRID_SIZE
TileManager.TILE_SIZE = TILE_SIZE
TileManager.BASE_HEIGHT = BASE_HEIGHT

function TileManager.new()
    local self = setmetatable({}, TileManager)
    self.tiles = {}
    -- Store tiles in a more efficient way for random selection
    self.activeTilesList = table.create(GRID_SIZE.X * GRID_SIZE.Y)
    return self
end

function TileManager:ShouldCreateTile(x, z, layout)
    local centerX = GRID_SIZE.X / 2
    local centerZ = GRID_SIZE.Y / 2
    
    if layout == LAYOUTS.FULL then
        return true
    elseif layout == LAYOUTS.CHECKERBOARD then
        return (x + z) % 2 == 0
    elseif layout == LAYOUTS.SPIRAL then
        -- Create a spiral pattern
        local dx = x - centerX
        local dz = z - centerZ
        local distance = math.sqrt(dx * dx + dz * dz)
        return (distance + math.atan2(dz, dx) * 2) % 4 < 2
    elseif layout == LAYOUTS.CROSS then
        -- Create a cross/plus pattern
        local margin = GRID_SIZE.X * 0.2 -- 20% margin
        return (math.abs(x - centerX) < margin) or (math.abs(z - centerZ) < margin)
    elseif layout == LAYOUTS.DONUT then
        -- Create a donut/ring pattern
        local dx = x - centerX
        local dz = z - centerZ
        local distance = math.sqrt(dx * dx + dz * dz)
        local innerRadius = GRID_SIZE.X * 0.2 -- 20% inner radius
        local outerRadius = GRID_SIZE.X * 0.4 -- 40% outer radius
        return distance > innerRadius and distance < outerRadius
    end
    return true
end

function TileManager:CreateTilePlatform()
    local layouts = {"spiral", "cross", "donut", "checkerboard"}
    local layout = layouts[math.random(1, #layouts)]
    print("Layout: " .. layout)
    -- layout = layout or LAYOUTS.FULL -- Default to full layout if none specified
    

    
    local arena = workspace:WaitForChild("Arena")
    local centerPos = arena.Position + Vector3.new(0, BASE_HEIGHT, 0)
    self.activeTilesList = {}
    
    local tileCount = 0
    for x = 1, GRID_SIZE.X do
        self.tiles[x] = {}
        for z = 1, GRID_SIZE.Y do
            if not self:ShouldCreateTile(x, z, layout) then
                continue
            end
            
            -- Calculate grid position relative to center
            local gridX = (x - GRID_SIZE.X/2 - 0.5) * TILE_SIZE.X
            local gridZ = (z - GRID_SIZE.Y/2 - 0.5) * TILE_SIZE.Z
            local position = centerPos + Vector3.new(gridX, 0, gridZ)
            
            -- Randomly select one of the tile models
            local modelNumber = math.random(1, 5)
            local tileModel = TileModels:WaitForChild("Block" .. modelNumber):Clone()
            local tilePart = tileModel:WaitForChild("Part")
            
            -- Set the position using PivotTo
            tileModel:PivotTo(CFrame.new(position))
            tilePart.Anchored = true
            -- tilePart.Color = Color3.fromRGB(200, 200, 200)
            tileModel.Parent = TilesFolder
            
            self.tiles[x][z] = tileModel
            table.insert(self.activeTilesList, tileModel)
            tileCount += 1
        end
    end
end

function TileManager:RemoveTile(tileModel)
    local tweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    
    -- Create explosion effect
    local explosion = Instance.new("Explosion")
    explosion.BlastPressure = 0  -- No physics force
    explosion.BlastRadius = 0
    explosion.Position = tileModel:GetPivot().Position
    explosion.DestroyJointRadiusPercent = 0
    explosion.Parent = workspace
    
    -- Create smoke effect
    local smoke = Instance.new("Smoke")
    smoke.Color = Color3.fromRGB(100, 100, 100)
    smoke.Size = 0.5
    smoke.RiseVelocity = 2
    smoke.Parent = tileModel:WaitForChild("Part")
    
    -- Tween the whole model down
    local currentCFrame = tileModel:GetPivot()
    local targetCFrame = currentCFrame * CFrame.new(0, -10, 0)
    
    local function tweenModel()
        local delta = 0
        local startTime = tick()
        
        while delta < 1 do
            local currentTime = tick()
            delta = (currentTime - startTime) / tweenInfo.Time
            
            -- Interpolate CFrame
            local lerpedCFrame = currentCFrame:Lerp(targetCFrame, delta)
            tileModel:PivotTo(lerpedCFrame)
            
            task.wait()
        end
        
        tileModel:Destroy()
    end
    
    task.spawn(tweenModel)
end

function TileManager:WarnTile(tileModel)
    local tilePart = tileModel:WaitForChild("Part")
    
    -- Create warning particles
    local warning = Instance.new("ParticleEmitter")
    warning.Color = ColorSequence.new(WARNING_COLOR)
    warning.Size = NumberSequence.new(0.5)
    warning.Rate = 20
    warning.Speed = NumberRange.new(2)
    warning.Lifetime = NumberRange.new(0.5)
    warning.Parent = tilePart
    
    -- Use fewer property changes
    local function flash()
        tilePart.Material = Enum.Material.Neon
        task.wait(0.3)
        tilePart.Material = Enum.Material.Plastic
        task.wait(0.3)
    end
    
    -- Use a single task.spawn instead of multiple
    task.spawn(function()
        for i = 1, 3 do
            flash()
        end
        warning:Destroy()
        self:RemoveTile(tileModel)
    end)
end

function TileManager:RemoveRandomTile()
    if #self.activeTilesList == 0 then 
        return 
    end
    
    -- More efficient random tile selection
    local index = math.random(#self.activeTilesList)
    local tileToRemove = self.activeTilesList[index]
    
    -- Faster removal from array (swap with last element)
    self.activeTilesList[index] = self.activeTilesList[#self.activeTilesList]
    self.activeTilesList[#self.activeTilesList] = nil
    
    self:WarnTile(tileToRemove)
end

function TileManager:RemoveAllTiles()
    for _, tile in self.activeTilesList do
        self:RemoveTile(tile)
    end
end

return TileManager 