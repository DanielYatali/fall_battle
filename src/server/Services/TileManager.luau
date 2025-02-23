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

-- Add these new constants after other constants
local BATCH_SIZE = 50 -- Reduced from 50 to 20 tiles per batch
local BATCH_DELAY = 0.1 -- Added delay between batches in seconds
local ObjectPool = {} -- Pool for reusing tile models

-- Add this at the top with other constants
local DEFAULT_COLORS = {
    Block1 = Color3.fromRGB(58, 125, 21),
    Block2 = Color3.fromRGB(58, 125, 21),
    Block3 = Color3.fromRGB(58, 125, 21),
    Block4 = Color3.fromRGB(58, 125, 21),
    Block5 = Color3.fromRGB(58, 125, 21),
}

function TileManager.new()
    local self = setmetatable({}, TileManager)
    self.tiles = {}
    self.activeTilesList = table.create(GRID_SIZE.X * GRID_SIZE.Y)
    self.isGenerating = false  -- Add this to prevent multiple generations
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

-- Modify GetTileFromPool to reset the color
function TileManager:GetTileFromPool(modelNumber)
    -- Check if we have this model type in the pool
    if not ObjectPool[modelNumber] then
        ObjectPool[modelNumber] = {}
    end
    
    local tile
    -- Reuse a tile from pool if available
    if #ObjectPool[modelNumber] > 0 then
        tile = table.remove(ObjectPool[modelNumber])
        -- Reset the color to original
        local tilePart = tile:WaitForChild("Part")
        tilePart.Color = DEFAULT_COLORS["Block" .. modelNumber]
        tile.Parent = TilesFolder
        return tile
    end
    
    -- Create new tile if none in pool
    tile = TileModels:WaitForChild("Block" .. modelNumber):Clone()
    return tile
end

-- Add this helper function to sort tiles by distance from center
function TileManager:SortTilesByDistance(tilesToCreate, centerPos)
    table.sort(tilesToCreate, function(a, b)
        local distA = (a.position - centerPos).Magnitude
        local distB = (b.position - centerPos).Magnitude
        return distA < distB
    end)
end

-- Modify CreateTilePlatform to generate from center outwards
function TileManager:CreateTilePlatform()
    if self.isGenerating then
        print("Tile platform already being generated")
        return
    end
    
    print("Creating tile platform")
    self.isGenerating = true
    
    local layouts = {"spiral", "cross", "donut", "checkerboard"}
    local layout = layouts[math.random(1, #layouts)]
    -- layout = "full"
    
    local arena = workspace:WaitForChild("Arena")
    local centerPos = arena.Position + Vector3.new(0, BASE_HEIGHT, 0)
    self.activeTilesList = {}
    
    -- Pre-calculate all tile positions and models
    local tilesToCreate = {}
    for x = 1, GRID_SIZE.X do
        self.tiles[x] = {}
        for z = 1, GRID_SIZE.Y do
            if not self:ShouldCreateTile(x, z, layout) then
                continue
            end
            
            local gridX = (x - GRID_SIZE.X/2 - 0.5) * TILE_SIZE.X
            local gridZ = (z - GRID_SIZE.Y/2 - 0.5) * TILE_SIZE.Z
            local position = centerPos + Vector3.new(gridX, 0, gridZ)
            
            table.insert(tilesToCreate, {
                position = position,
                x = x,
                z = z,
                modelNumber = math.random(1, 5)
            })
        end
    end
    
    -- Sort tiles by distance from center
    self:SortTilesByDistance(tilesToCreate, centerPos)
    
    -- Create tiles in batches, from center outwards
    task.spawn(function()
        local totalTiles = #tilesToCreate
        local tilesCreated = 0
        
        for i = 1, #tilesToCreate, BATCH_SIZE do
            local batchEnd = math.min(i + BATCH_SIZE - 1, #tilesToCreate)
            
            for j = i, batchEnd do
                local tileInfo = tilesToCreate[j]
                local tileModel = self:GetTileFromPool(tileInfo.modelNumber)
                local tilePart = tileModel:WaitForChild("Part")
                
                tileModel:PivotTo(CFrame.new(tileInfo.position))
                tilePart.Anchored = true
                tileModel.Parent = TilesFolder
                
                self.tiles[tileInfo.x][tileInfo.z] = tileModel
                table.insert(self.activeTilesList, tileModel)
                
                tilesCreated += 1
            end
            
            -- Print progress
            local progress = math.floor((tilesCreated / totalTiles) * 100)
            print(`Tile generation progress: {progress}%`)
            
            task.wait(BATCH_DELAY) -- Longer delay between batches
        end
        
        self.isGenerating = false
        print("Tile platform generation complete")
    end)
end

-- Optimize RemoveTile to use less resources
function TileManager:RemoveTile(tileModel)
    if not tileModel or not tileModel.Parent then return end
    
    local tilePart = tileModel:WaitForChild("Part")
    local modelNumber = tonumber(tileModel.Name:match("Block(%d+)"))
    
    -- Simplified effects
    local explosion = Instance.new("Explosion")
    explosion.BlastPressure = 0
    explosion.BlastRadius = 0
    explosion.Position = tileModel:GetPivot().Position
    explosion.DestroyJointRadiusPercent = 0
    explosion.Parent = workspace
    
    -- Simple drop animation without tweening
    task.spawn(function()
        local startPos = tileModel:GetPivot().Position
        for i = 1, 10 do
            tileModel:PivotTo(CFrame.new(startPos - Vector3.new(0, i, 0)))
            task.wait(0.03)
        end
        
        -- Return to pool instead of destroying
        tileModel.Parent = nil
        if modelNumber then
            if not ObjectPool[modelNumber] then
                ObjectPool[modelNumber] = {}
            end
            table.insert(ObjectPool[modelNumber], tileModel)
        end
    end)
end

-- Optimize WarnTile to use less resources
function TileManager:WarnTile(tileModel)
    local tilePart = tileModel:WaitForChild("Part")
    
    -- Simplified warning effect
    task.spawn(function()
        for i = 1, 3 do
            tilePart.Color = WARNING_COLOR
            task.wait(0.2)
            tilePart.Color = DEFAULT_COLOR
            task.wait(0.2)
        end
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

-- Modify RemoveAllTiles to handle generation status
function TileManager:RemoveAllTiles()
    -- Wait for any ongoing generation to complete
    while self.isGenerating do
        task.wait()
    end
    
    for _, tile in self.activeTilesList do
        self:RemoveTile(tile)
    end
end

return TileManager 