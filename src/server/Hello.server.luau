local GameManager = require(script.Parent.Services.GameManager)
local gameManager = GameManager.new()

-- Start the game when the server starts
-- In a real game, you might want to add a waiting lobby system
game:GetService("Players").PlayerAdded:Connect(function()
    task.wait(3) -- Give time for character to load
    gameManager:StartGame()
end) 