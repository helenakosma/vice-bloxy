local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Cars = require(script.Parent.Cars)
local Map = require(script.Parent.Map)

Map.build()

-- Leaderboard stats (the built-in Roblox leaderboard shows anything in "leaderstats").
Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = Config.StartingCash
	cash.Parent = stats
end)

-- A simple starter job pad: walk up, press E, get paid. Replace with real missions later.
local function makeJobPad(position)
	local pad = Instance.new("Part")
	pad.Name = "JobPad"
	pad.Size = Vector3.new(8, 1, 8)
	pad.Position = position
	pad.Anchored = true
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(255, 61, 154)
	pad.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Do a delivery job"
	prompt.ObjectText = "Vice Bloxy Courier"
	prompt.Parent = pad

	local lastUsed = {}
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if lastUsed[player] and now - lastUsed[player] < Config.JobCooldown then
			return
		end
		lastUsed[player] = now
		local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
		if cash then
			cash.Value += Config.JobPayout
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastUsed[player] = nil
	end)
end

makeJobPad(Vector3.new(0, 1, 20))

-- Starter cars near the job pad.
for i = 0, 2 do
	Cars.spawn(Vector3.new(-30 + i * 15, 1, 0))
end
