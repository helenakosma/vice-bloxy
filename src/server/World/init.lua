-- Builds the city district by district and returns spawn points for players and cars.
--
-- Each district is a module in World/Districts with:
--   name    : folder name under Workspace.City
--   bounds  : { minX, maxX, minZ, maxZ } in studs (north is -Z)
--   budget  : part budget; going over prints a warning
--   build(ctx) -> { carSpawns = {...}, jobCFrame = CFrame? }
-- ctx gives the district its folder, a seeded Random, the Cars module and helpers.
local Workspace = game:GetService("Workspace")

local Util = require(script.Util)
local Atmosphere = require(script.Atmosphere)

local World = {}

local SEED = 1986

-- Build order matters: later districts can rely on roads from earlier ones.
local DISTRICTS = {
	require(script.Districts.Downtown),
}

local function makeFolder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
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

	-- Ground first, so early joiners have something to stand on.
	Util.beginDistrict("Shared")
	local width = Util.RIVER_X - Util.MIN_X + 40
	Util.solid(shared, Vector3.new(width, 2, Util.MAX_Z - Util.MIN_Z + 40), CFrame.new(Util.MIN_X - 20 + width / 2, -1, 0), Color3.fromRGB(96, 93, 88), Enum.Material.Concrete)
	local outer = Util.deco(shared, Vector3.new(2000, 2, 2000), CFrame.new(0, -1.2, 0), Color3.fromRGB(80, 78, 74), Enum.Material.Concrete)
	outer.CastShadow = false

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

	local info = { carSpawns = {}, jobCFrame = nil }
	for i, district in ipairs(DISTRICTS) do
		Util.beginDistrict(district.name)
		local folder = makeFolder(root, district.name)
		local started = os.clock()
		local result = district.build({
			folder = folder,
			rng = Random.new(SEED + (i - 1) * 1000),
			Cars = Cars,
			makeFolder = makeFolder,
			setSpawn = setSpawn,
		}) or {}
		for _, carSpawn in ipairs(result.carSpawns or {}) do
			table.insert(info.carSpawns, carSpawn)
		end
		info.jobCFrame = info.jobCFrame or result.jobCFrame

		local count = Util.partCounts[district.name]
		folder:SetAttribute("PartCount", count)
		folder:SetAttribute("PartBudget", district.budget)
		print(string.format("[World] %s: %d parts (budget %d) in %.1fs", district.name, count, district.budget, os.clock() - started))
		if district.budget and count > district.budget then
			warn(string.format("[World] %s is over its part budget by %d", district.name, count - district.budget))
		end
	end

	-- Invisible boundary walls around the playable area.
	Util.beginDistrict("Shared")
	local function wall(size, pos)
		local p = Util.solid(shared, size, CFrame.new(pos), Color3.new(), Enum.Material.SmoothPlastic)
		p.Transparency = 1
	end
	local h = 120
	local spanZ = Util.MAX_Z - Util.MIN_Z
	local spanX = Util.RIVER_X - Util.MIN_X
	wall(Vector3.new(2, h, spanZ), Vector3.new(Util.MIN_X - 4, h / 2, 0))
	wall(Vector3.new(spanX, h, 2), Vector3.new(Util.MIN_X + spanX / 2, h / 2, Util.MAX_Z + 4))
	wall(Vector3.new(spanX, h, 2), Vector3.new(Util.MIN_X + spanX / 2, h / 2, Util.MIN_Z - 4))

	root:SetAttribute("PartCount", Util.totalParts())
	print(string.format("[World] Total: %d parts", Util.totalParts()))

	info.spawnCFrame = spawnCF or CFrame.new(0, 5, 0)
	info.jobCFrame = info.jobCFrame or info.spawnCFrame * CFrame.new(0, -0.75, 14)
	return info
end

return World
