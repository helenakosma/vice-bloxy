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

-- Transit Card balance (and a running transfer) under the cash.
local cardLabel = Instance.new("TextLabel")
cardLabel.AnchorPoint = Vector2.new(1, 0)
cardLabel.Position = UDim2.new(1, -24, 0, 60)
cardLabel.Size = UDim2.fromOffset(300, 26)
cardLabel.BackgroundTransparency = 1
cardLabel.Font = Enum.Font.GothamBold
cardLabel.TextSize = 20
cardLabel.TextXAlignment = Enum.TextXAlignment.Right
cardLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
cardLabel.TextStrokeTransparency = 0.3
cardLabel.Visible = false
cardLabel.Parent = gui

task.spawn(function()
	while true do
		if player:GetAttribute("HasTransitCard") then
			local text = "TRANSIT CARD $" .. tostring(player:GetAttribute("CardBalance") or 0)
			local left = (player:GetAttribute("FareValidUntil") or 0) - workspace:GetServerTimeNow()
			if left > 0 then
				text = text .. string.format("  ·  TRANSFER %d:%02d", math.floor(left / 60), math.floor(left % 60))
			end
			cardLabel.Text = text
			cardLabel.Visible = true
		else
			cardLabel.Visible = false
		end
		task.wait(0.5)
	end
end)
