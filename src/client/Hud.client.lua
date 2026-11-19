local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(220, 44)
label.Position = UDim2.new(1, -236, 0, 12)
label.BackgroundColor3 = Color3.fromRGB(30, 18, 49)
label.TextColor3 = Color3.fromRGB(38, 224, 255)
label.Font = Enum.Font.GothamBold
label.TextSize = 24
label.Parent = gui

local stats = player:WaitForChild("leaderstats")
local cash = stats:WaitForChild("Cash")
local function update()
	label.Text = "$" .. cash.Value
end
cash.Changed:Connect(update)
update()
