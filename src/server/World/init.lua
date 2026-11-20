-- Builds the world and returns spawn points for players and cars.
--
-- Each district is a module in World/Districts with:
--   name    : folder name under Workspace.City
--   bounds  : { minX, maxX, minZ, maxZ } in studs (north is -Z)
--   budget  : part budget; going over prints a warning
--   layout(ctx)          : claim land and lay out roads (no buildings yet)
--   build(ctx) -> result : buildings, props, etc. result = { carSpawns, jobCFrame? }
-- Every district lays out first, so later roads (bridges, extensions) are known
-- before anything is built next to them.
local Workspace = game:GetService("Workspace")

local Util = require(script.Util)
local Atmosphere = require(script.Atmosphere)
local Highways = require(script.Highways)
local Buildings = require(script.Buildings)
local Transit = require(script.Transit)

local World = {}

local SEED = 1986

-- Order matters: later districts connect to roads from earlier ones.
local DISTRICTS = {
	require(script.Districts.Downtown),
	require(script.Districts.Toronto),
	require(script.Districts.Industrial),
	require(script.Districts.Suburbs),
	require(script.Districts.ViceBeach),
}

local function makeFolder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Water everywhere, tiled because parts can't exceed 2048 studs. The water is
-- registered now and built with the land (so stairwells can cut through it); the
-- riverbed sits deep, below the subway tunnels.
local function buildWater(folder)
	local tile = 2000
	for x = -3000, 3000, tile do
		for z = -9000, 3000, tile do
			Util.waterBox(folder, Vector3.new(x - tile / 2, -3, z - tile / 2), Vector3.new(x + tile / 2, -2, z + tile / 2))
			local bed = Util.solid(folder, Vector3.new(tile, 2, tile), CFrame.new(x, -63, z), Color3.fromRGB(40, 38, 34), Enum.Material.Mud)
			bed.CastShadow = false
		end
	end
end

local function reportDistrict(folder, name, budget, started)
	local count = Util.partCounts[name]
	folder:SetAttribute("PartCount", count)
	folder:SetAttribute("PartBudget", budget)
	print(string.format("[World] %s: %d parts (budget %d) in %.1fs", name, count, budget or 0, os.clock() - started))
	if budget and count > budget then
		warn(string.format("[World] %s is over its part budget by %d", name, count - budget))
	end
end

function World.build(Cars)
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	Atmosphere.apply()

	local root = makeFolder(Workspace, "City")
	local shared = makeFolder(root, "Shared")
	Util.beginDistrict("Shared")
	buildWater(shared)

	local spawnCF = nil
	local function setSpawn(cframe)
		if spawnCF then
			return -- the first district to offer a spawn keeps it
		end
		spawnCF = cframe
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = cframe
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = Workspace
	end

	-- 1. Layout: land and roads for every district, then the highways.
	local sharedState = {}
	local contexts = {}
	for i, district in ipairs(DISTRICTS) do
		Util.beginDistrict(district.name)
		local ctx = {
			folder = makeFolder(root, district.name),
			rng = Random.new(SEED + (i - 1) * 1000),
			Cars = Cars,
			makeFolder = makeFolder,
			setSpawn = setSpawn,
			shared = sharedState,
			started = os.clock(),
		}
		contexts[i] = ctx
		district.layout(ctx)
	end
	Util.beginDistrict("Highways")
	local highwayStart = os.clock()
	Highways.layout(sharedState)
	Util.beginDistrict("Transit")
	local transitStart = os.clock()
	Transit.layout(sharedState)
	-- Now that all underground space is known, build the land and water.
	Util.beginDistrict("Shared")
	Util.buildGround()

	-- 2. Build: buildings and props per district, then highways and the skyline.
	local info = { carSpawns = {}, jobCFrame = nil }
	for i, district in ipairs(DISTRICTS) do
		Util.beginDistrict(district.name)
		local ctx = contexts[i]
		local result = district.build(ctx) or {}
		for _, carSpawn in ipairs(result.carSpawns or {}) do
			table.insert(info.carSpawns, carSpawn)
		end
		info.jobCFrame = info.jobCFrame or result.jobCFrame
		reportDistrict(ctx.folder, district.name, district.budget, ctx.started)
	end

	Util.beginDistrict("Highways")
	local highways = makeFolder(root, "Highways")
	Highways.build(highways)
	Util.beginDistrict("Transit")
	local transitFolder = makeFolder(root, "Transit")
	local transitInfo = Transit.build(transitFolder)
	reportDistrict(transitFolder, "Transit", 70000, transitStart)
	info.safeZones = transitInfo.safeZones
	reportDistrict(highways, "Highways", 6000, highwayStart)

	Util.beginDistrict("Shared")
	Buildings.background(makeFolder(shared, "Skyline"), Random.new(SEED - 1))

	-- Map data for the minimap (the south extension's stations too).
	require(script.Minimap).publish({
		{ "HARBOUR", 100, -560 },
		{ "CENTRAL", 100, 0 },
		{ "PORTLANDS", 100, 962 },
	})

	root:SetAttribute("PartCount", Util.totalParts())
	print(string.format("[World] Total: %d parts", Util.totalParts()))

	info.spawnCFrame = spawnCF or CFrame.new(0, 5, 0)
	info.jobCFrame = info.jobCFrame or info.spawnCFrame * CFrame.new(0, -0.75, 14)
	return info
end

return World
