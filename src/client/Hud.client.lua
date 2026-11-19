-- Cash display (top right) and short notifications.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local cashLabel = Instance.new("TextLabel")
cashLabel.AnchorPoint = Vector2.new(1, 0)
cashLabel.Position = UDim2.new(1, -24, 0, 16)
cashLabel.Size = UDim2.fromOffset(260, 44)
cashLabel.BackgroundTransparency = 1
cashLabel.Font = Enum.Font.GothamBlack
cashLabel.TextSize = 36
cashLabel.TextXAlignment = Enum.TextXAlignment.Right
cashLabel.TextColor3 = Color3.fromRGB(118, 190, 96)
cashLabel.TextStrokeTransparency = 0.2
cashLabel.Parent = gui

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0, 1)
toast.Position = UDim2.new(0, 24, 1, -140)
toast.Size = UDim2.fromOffset(380, 40)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 1
toast.Font = Enum.Font.GothamMedium
toast.TextSize = 18
toast.TextColor3 = Color3.fromRGB(240, 236, 228)
toast.TextTransparency = 1
toast.TextXAlignment = Enum.TextXAlignment.Left
toast.Parent = gui
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.Parent = toast

local toastId = 0
local function showToast(text)
	toastId = toastId + 1
	local id = toastId
	toast.Text = text
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.35
	task.delay(3, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
remotes:WaitForChild("Notify").OnClientEvent:Connect(showToast)

local stats = player:WaitForChild("leaderstats")
local cash = stats:WaitForChild("Cash")
local function update()
	cashLabel.Text = "$" .. cash.Value
end
cash.Changed:Connect(update)
update()
