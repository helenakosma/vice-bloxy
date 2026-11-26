local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Nobody gets a character until the world is built and the spawn point is at
-- the arrival place (Yonge & Dundas for now); otherwise players appear at the
-- first district's spawn and are then moved. The client shows a loading
-- screen until WorldReady is set (Client/Loading).
Players.CharacterAutoLoads = false
local worldReady = Instance.new("BoolValue")
worldReady.Name = "WorldReady"
worldReady.Value = false
worldReady.Parent = ReplicatedStorage

local Remotes = require(script.Parent.Remotes)
require(script.Parent.Fares) -- transit card, fare gates, bus fares
local Cars = require(script.Parent.Cars)
local World = require(script.Parent.World)

-- The society's services start before the (slow) world build, so players who join
-- early get their profiles loaded straight away.
local Services = script.Parent.Services
require(Services.PlayerData).start()
require(Services.Economy).start()
require(Services.Phone).start()
require(Services.Employment).start()
require(Services.Router).start()

Cars.init()
local info = World.build(Cars)
-- Work puts its prompts on the workplaces the world just built.
local workOk, workErr = pcall(function()
	require(Services.Work).start()
end)
if not workOk then
	warn("[Work] failed to start: " .. tostring(workErr))
end

-- Places by id (Services/Locations), and where new players arrive (Catalog/Locations
-- ARRIVAL: Yonge & Dundas for now).
-- The world's own spawn point (the first district that offers one) is moved there,
-- so respawns land there too; anyone who already spawned at the old point while
-- the world was building is brought over.
local locOk, locErr = pcall(function()
	local Locations = require(Services.Locations)
	Locations.start()
	local arrival = Locations.arrival()
	local spawn = workspace:FindFirstChild("Spawn")
	if arrival and spawn and spawn:IsA("SpawnLocation") then
		local old = spawn.Position
		spawn.CFrame = arrival + Vector3.new(0, 0.5, 0)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - old).Magnitude < 80 then
				player.Character:PivotTo(arrival + Vector3.new(0, 3, 0))
			end
		end
		print(string.format("[Locations] new players arrive at (%.0f, %.0f, %.0f)", arrival.X, arrival.Y, arrival.Z))
	elseif not arrival then
		warn("[Locations] no arrival point; players keep the district spawn")
	end
end)
if not locOk then
	warn("[Locations] failed to start: " .. tostring(locErr))
end

-- The spawn point is where it belongs: characters load now, and respawns use
-- it from here on.
Players.CharacterAutoLoads = true
worldReady.Value = true
for _, player in ipairs(Players:GetPlayers()) do
	if not player.Character then
		task.spawn(function()
			pcall(function()
				player:LoadCharacter()
			end)
		end)
	end
end

-- Shopping in the Eaton Centre's stores (prompts on the displays and tills the
-- world just built), and the cashiers and shoppers near players.
-- Store contents are built only where players are (World/EatonCentre/Lazy).
do
	local ok, err = pcall(function()
		require(script.Parent.World.EatonCentre.Lazy).start()
	end)
	if not ok then
		warn("[Lazy] failed to start: " .. tostring(err))
	end
end
for _, name in ipairs({ "Shopping", "ShopNPCs" }) do
	local ok, err = pcall(function()
		require(Services[name]).start()
	end)
	if not ok then
		warn("[" .. name .. "] failed to start: " .. tostring(err))
	end
end
require(script.Parent.World.Atmosphere).startCycle()

for _, spawn in ipairs(info.carSpawns) do
	Cars.spawn(spawn.cframe, { taxi = spawn.taxi })
end

-- Falling into the water is fatal (there's no swimming): respawn at the spawn point.
-- The subway's underground spaces (info.safeZones) don't count.
local safeZones = info.safeZones or {}
local function underground(pos)
	for _, zone in ipairs(safeZones) do
		local a, b = zone.min, zone.max
		if pos.X >= a.X and pos.X <= b.X and pos.Y >= a.Y and pos.Y <= b.Y and pos.Z >= a.Z and pos.Z <= b.Z then
			return true
		end
	end
	return false
end

task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				local pos = root.Position
				if (pos.Y < -4 and not underground(pos)) or pos.Y < -70 then
					humanoid.Health = 0
					Remotes.notify(player, "You fell in the water")
				end
			end
		end
	end
end)
