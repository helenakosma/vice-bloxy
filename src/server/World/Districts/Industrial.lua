-- Industrial waterfront (south of downtown): avenues continue south as truck
-- routes, linked by two east-west roads and a spur to the bridge. Phase 1: roads only.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Layout = require(World.Layout)

local Industrial = {
	name = "Industrial",
	bounds = Layout.INDUSTRIAL,
	budget = 9000,
}

function Industrial.layout(ctx)
	local b = Industrial.bounds
	local rng = ctx.rng
	Util.land(ctx.folder, b.minX, b.maxX, b.minZ, b.maxZ, Color3.fromRGB(92, 88, 82))

	local roads = {}
	-- Avenues continue south. East of x = 300 they stop at the main road so they
	-- don't run into the expressway's ramp down to the bridge.
	for _, ending in ipairs(Roads.avenueEnds(ctx.shared.downtownRoads, "south")) do
		local x = ending.point.X
		local stopZ = b.maxZ - 20
		if x > 300 then
			stopZ = Layout.INDUSTRIAL_MAIN_Z
		end
		local south = Vector2.new(x + rng:NextNumber(-10, 10), stopZ)
		table.insert(roads, Roads.add("industrial", Roads.path(rng, Vector2.new(x, Util.MAX_Z), south, 110, 4)))
	end

	-- East-west roads. The northern one carries on west into the suburbs.
	local northZ, mainZ = Layout.INDUSTRIAL_NORTH_Z, Layout.INDUSTRIAL_MAIN_Z
	table.insert(roads, Roads.add("industrial", Roads.path(rng, Vector2.new(-1050, northZ), Vector2.new(b.maxX - 6, northZ), 130, 5)))
	table.insert(roads, Roads.add("industrial", Roads.path(rng, Vector2.new(b.minX, mainZ), Vector2.new(b.maxX - 6, mainZ), 130, 4)))

	-- Spur from the main road to the expressway / bridge approach.
	local x = Layout.BRIDGE_LINK_X
	table.insert(roads, Roads.add("street", { Vector2.new(x, mainZ), Vector2.new(x, Layout.BRIDGE[1].Z) }))

	Roads.rasterize(roads)
	ctx.roads = roads
end

function Industrial.build(ctx)
	Roads.render(ctx.makeFolder(ctx.folder, "Roads"), ctx.roads)
	return {}
end

return Industrial
