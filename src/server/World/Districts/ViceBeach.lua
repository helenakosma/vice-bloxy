-- Vice Beach (Miami-inspired): an island across the river, reached by the
-- suspension bridge. Ocean Drive runs along the beach. Phase 1: roads and sand.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Layout = require(World.Layout)

local ViceBeach = {
	name = "ViceBeach",
	bounds = Layout.VICE_BEACH,
	budget = 16000,
}

local OCEAN_DRIVE_X = 2110
local COLLINS_X = 1880
local BAY_X = 1240
local SAND_FROM_X = 2150

function ViceBeach.layout(ctx)
	local b = ViceBeach.bounds
	local rng = ctx.rng
	Util.land(ctx.folder, b.minX, b.maxX, b.minZ, b.maxZ, Color3.fromRGB(150, 142, 128))
	-- Beach: sand along the eastern edge, kept clear of buildings.
	local sandSize = Vector3.new(b.maxX - SAND_FROM_X, 0.4, b.maxZ - b.minZ)
	local sandCF = CFrame.new((SAND_FROM_X + b.maxX) / 2, 0.2, (b.minZ + b.maxZ) / 2)
	Util.solid(ctx.folder, sandSize, sandCF, Color3.fromRGB(226, 206, 160), Enum.Material.Sand)
	Util.markRect(SAND_FROM_X, b.maxX, b.minZ, b.maxZ, Util.PARK)

	local north, south = b.minZ + 40, b.maxZ - 40
	local roads = {
		Roads.add("boulevard", Roads.path(rng, Vector2.new(OCEAN_DRIVE_X, north), Vector2.new(OCEAN_DRIVE_X, south), 100, 4)),
		Roads.add("avenue", Roads.path(rng, Vector2.new(COLLINS_X, north), Vector2.new(COLLINS_X, south), 110, 5)),
		Roads.add("avenue", Roads.path(rng, Vector2.new(BAY_X, north), Vector2.new(BAY_X, south), 110, 5)),
	}
	for _, z in ipairs({ -200, 150, 500, 850, 1240 }) do
		local east = Vector2.new(OCEAN_DRIVE_X, z + rng:NextNumber(-10, 10))
		table.insert(roads, Roads.add("street", Roads.path(rng, Vector2.new(BAY_X, z), east, 110, 4)))
	end
	-- The bridge lands here and the road carries straight on to Ocean Drive.
	local landing = Layout.BRIDGE[#Layout.BRIDGE]
	table.insert(roads, Roads.add("avenue", {
		Vector2.new(landing.X, landing.Z),
		Vector2.new(BAY_X, landing.Z),
		Vector2.new(COLLINS_X, landing.Z),
		Vector2.new(OCEAN_DRIVE_X, landing.Z),
	}))

	Roads.rasterize(roads)
	ctx.roads = roads
end

function ViceBeach.build(ctx)
	Roads.render(ctx.makeFolder(ctx.folder, "Roads"), ctx.roads)
	return {}
end

return ViceBeach
