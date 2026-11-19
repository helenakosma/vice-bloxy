-- North York (Toronto-inspired): wide arterial roads north of the channel, joined
-- to downtown by bridges that continue three avenues. Phase 1: roads only.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Layout = require(World.Layout)

local NorthYork = {
	name = "NorthYork",
	bounds = Layout.NORTH_YORK,
	budget = 16000,
}

function NorthYork.layout(ctx)
	local b = NorthYork.bounds
	local rng = ctx.rng
	Util.land(ctx.folder, b.minX, b.maxX, b.minZ, b.maxZ, Color3.fromRGB(104, 102, 96))

	local roads = {}
	local northEdge = b.minZ + 40

	-- Channel bridges continuing downtown avenues, then arterials heading north.
	for _, target in ipairs(Layout.NY_BRIDGE_AVENUES) do
		for _, ending in ipairs(Roads.avenueEnds(ctx.shared.downtownRoads, "north")) do
			local x = ending.point.X
			if ending.road.kind == "avenue" and math.abs(x - target) < 40 then
				table.insert(roads, Roads.add("bridge", { Vector2.new(x, Util.MIN_Z), Vector2.new(x, b.maxZ - 5) }))
				local north = Vector2.new(x + rng:NextNumber(-20, 20), northEdge)
				table.insert(roads, Roads.add("arterial", Roads.path(rng, Vector2.new(x, b.maxZ - 5), north, 115, 6)))
				break
			end
		end
	end

	-- Two more arterials: west of the expressway and along the east side.
	for _, x in ipairs({ -1050, 640 }) do
		local north = Vector2.new(x + rng:NextNumber(-15, 15), northEdge)
		table.insert(roads, Roads.add("arterial", Roads.path(rng, Vector2.new(x, b.maxZ - 30), north, 115, 6)))
	end

	-- Cross arterials, gently curving.
	for _, z in ipairs(Layout.NY_CROSS_Z) do
		local east = Vector2.new(b.maxX - 20, z + rng:NextNumber(-20, 20))
		table.insert(roads, Roads.add("arterial", Roads.path(rng, Vector2.new(b.minX + 20, z), east, 120, 7)))
	end

	Roads.rasterize(roads)
	ctx.roads = roads
end

function NorthYork.build(ctx)
	Roads.render(ctx.makeFolder(ctx.folder, "Roads"), ctx.roads)
	return {}
end

return NorthYork
