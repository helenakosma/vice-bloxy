local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local Cars = require(script.Parent.Cars)
local World = require(script.Parent.World)

-- Leaderboard stats (the built-in Roblox leaderboard shows anything in "leaderstats").
local function setupPlayer(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = Config.StartingCash
	cash.Parent = stats
	stats.Parent = player
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Cars.init()
local info = World.build(Cars)

-- Courier job marker near spawn: a glowing cylinder like a mission marker.
local function makeJobMarker(cframe)
	local marker = Instance.new("Part")
	marker.Name = "JobMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.4, 7, 7)
	marker.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	marker.Anchored = true
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 205, 40)
	marker.Transparency = 0.35
	marker.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Start delivery job"
	prompt.ObjectText = "Courier"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker

	local lastUsed = {}
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if lastUsed[player] and now - lastUsed[player] < Config.JobCooldown then
			Remotes.notify(player, "No jobs right now, come back soon")
			return
		end
		lastUsed[player] = now
		local stats = player:FindFirstChild("leaderstats")
		local cash = stats and stats:FindFirstChild("Cash")
		if cash then
			cash.Value = cash.Value + Config.JobPayout
			Remotes.notify(player, "Delivery done: +$" .. Config.JobPayout)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastUsed[player] = nil
	end)
end
makeJobMarker(info.jobCFrame)

for _, spawn in ipairs(info.carSpawns) do
	Cars.spawn(spawn.cframe, { taxi = spawn.taxi })
end
