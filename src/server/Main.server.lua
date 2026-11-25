local Players = game:GetService("Players")

-- Spawn only after the city and the player's profile are ready.
Players.CharacterAutoLoads = false

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
require(script.Parent.World.Atmosphere).startCycle()

for _, spawn in ipairs(info.carSpawns) do
	Cars.spawn(spawn.cframe, { taxi = spawn.taxi })
end
require(Services.Characters).start()

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
