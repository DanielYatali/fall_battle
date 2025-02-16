local TileManager = {}
local TilesFolder = workspace:WaitForChild("Tiles")
if not TilesFolder then
    TilesFolder = Instance.new("Folder")
    TilesFolder.Name = "Tiles"
    TilesFolder.Parent = workspace
end

TileManager.__index = TileManager

-- Constants
local TILE_SIZE = Vector3.new(8, 1, 8) -- Increased from 4x4 to 8x8
local GRID_SIZE = Vector2.new(20, 20) -- Increased from 10x10 to 20x20
local BASE_HEIGHT = 10 -- Height from baseplate
local WARNING_TIME = 2 -- Time in seconds to show warning
local WARNING_COLOR = Color3.fromRGB(255, 100, 100) -- Red warning color
local DEFAULT_COLOR = Color3.fromRGB(200, 200, 200)

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

function TileManager:CreateTilePlatform()
    local arena = workspace:WaitForChild("Arena")
    local centerPos = arena.Position + Vector3.new(0, BASE_HEIGHT, 0)
    self.activeTilesList = {}
    
    local tileCount = 0
    for x = 1, GRID_SIZE.X do
        self.tiles[x] = {}
        for z = 1, GRID_SIZE.Y do
            local position = centerPos + Vector3.new(
                (x - GRID_SIZE.X/2) * TILE_SIZE.X,
                0,
                (z - GRID_SIZE.Y/2) * TILE_SIZE.Z
            )
            
            local tile = Instance.new("Part")
            tile.Size = TILE_SIZE
            tile.Position = position
            tile.Anchored = true
            tile.Material = Enum.Material.Concrete
            tile.Color = Color3.fromRGB(200, 200, 200)
            tile.Parent = TilesFolder
            
            self.tiles[x][z] = tile
            -- Store in flat list for more efficient random selection
            table.insert(self.activeTilesList, tile)
            tileCount += 1
        end
    end
end

function TileManager:RemoveTile(tile)
    local tweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    
    local tween = tweenService:Create(tile, tweenInfo, {
        Position = tile.Position - Vector3.new(0, 10, 0),
        Transparency = 1
    })
    
    tween:Play()
    tween.Completed:Connect(function()
        tile:Destroy()
    end)
end

function TileManager:WarnTile(tile)
    -- Use fewer property changes
    local function flash()
        tile.Color = WARNING_COLOR
        tile.Material = Enum.Material.Neon
        task.wait(0.3)
        tile.Color = DEFAULT_COLOR
        task.wait(0.3)
    end
    
    -- Use a single task.spawn instead of multiple
    task.spawn(function()
        for i = 1, 3 do -- Fixed number of flashes instead of time-based
            flash()
        end
        self:RemoveTile(tile)
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