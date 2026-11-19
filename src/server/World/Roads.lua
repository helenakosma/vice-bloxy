-- Road network: wandering avenues, irregular cross streets (some ending at T-junctions),
-- a diagonal Broadway-style boulevard, a waterfront drive, alleys and crooked lanes.
local Util = require(script.Parent.Util)

local Roads = {}

-- Lanes are about 15 studs (roughly twice a car's width).
Roads.KINDS = {
	avenue = { width = 60, walk = 10, main = true }, -- 4 lanes
	broadway = { width = 56, walk = 10, main = true },
	waterfront = { width = 56, walk = 10, main = true },
	street = { width = 32, walk = 8 }, -- 2 lanes
	lane = { width = 22, walk = 5 },
	alley = { width = 14, walk = 0 },
	-- Outer districts
	arterial = { width = 64, walk = 10, main = true },
	boulevard = { width = 44, walk = 14, main = true },
	bridge = { width = 60, walk = 6, main = true },
	residential = { width = 30, walk = 7 },
	industrial = { width = 36, walk = 4 },
}

Roads.list = {} -- every road in the world
Roads.intersections = {}

local nextId = 0
function Roads.allocateId()
	nextId = nextId + 1
	return nextId
end

-- Registers a road and returns it. points = Vector2 polyline (x, z).
function Roads.add(kind, points)
	local spec = Roads.KINDS[kind]
	local road = {
		id = Roads.allocateId(),
		kind = kind,
		width = spec.width,
		walk = spec.walk,
		main = spec.main == true,
		points = points,
	}
	table.insert(Roads.list, road)
	return road
end

-- Park: no roads cross it.
Roads.PARK = { minX = -650, maxX = -430, minZ = 300, maxZ = 600 }

local ASPHALT = Color3.fromRGB(62, 62, 64)
local ALLEY_ASPHALT = Color3.fromRGB(52, 50, 48)
local SIDEWALK = Color3.fromRGB(158, 154, 146)
local YELLOW = Color3.fromRGB(214, 170, 40)
local WHITE = Color3.fromRGB(222, 222, 218)

local function inPark(p, margin)
	margin = margin or 0
	local r = Roads.PARK
	return p.X > r.minX - margin and p.X < r.maxX + margin and p.Y > r.minZ - margin and p.Y < r.maxZ + margin
end

-- X position (and direction) of a north-south road at a given z.
local function xAt(road, z)
	local pts = road.points
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		if z >= a.Y and z <= b.Y then
			local t = (z - a.Y) / (b.Y - a.Y)
			return a.X + (b.X - a.X) * t, (b - a).Unit
		end
	end
	local n = #pts
	return pts[n].X, (pts[n] - pts[n - 1]).Unit
end

-- Splits a polyline wherever a segment enters the park.
local function clipToPark(points)
	local pieces, current = {}, {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local blocked = inPark(a) or inPark(b) or inPark((a + b) / 2)
		if blocked then
			if #current >= 2 then
				table.insert(pieces, current)
			end
			current = {}
		else
			if #current == 0 then
				table.insert(current, a)
			end
			table.insert(current, b)
		end
	end
	if #current >= 2 then
		table.insert(pieces, current)
	end
	return pieces
end

function Roads.generate(rng)
	local raw = {} -- { kind, points, clip }
	local function add(kind, points, clip)
		local entry = { kind = kind, points = points, clip = clip }
		table.insert(raw, entry)
		return entry
	end

	-- Avenues run north-south and wander a little.
	local avenueX = { -560, -360, -170, 20, 210, 400 }
	local verticals = {}
	for _, ax in ipairs(avenueX) do
		local pts = {}
		local x = ax + rng:NextNumber(-12, 12)
		for z = Util.MIN_Z, Util.MAX_Z, 70 do
			x = math.clamp(x + rng:NextNumber(-5, 5), ax - 26, ax + 26)
			table.insert(pts, Vector2.new(x, z))
		end
		table.insert(verticals, add("avenue", pts, true))
	end

	local waterfrontPts = {}
	for z = Util.MIN_Z, Util.MAX_Z, 100 do
		table.insert(waterfrontPts, Vector2.new(558 + rng:NextNumber(-5, 5), z))
	end
	table.insert(verticals, add("waterfront", waterfrontPts, false))

	-- Cross streets: irregular spacing, small bends, some stop at an avenue.
	local streetZs = {}
	local z = Util.MIN_Z + 55
	while z < Util.MAX_Z - 45 do
		table.insert(streetZs, z)
		local first, last = 0, #verticals -- 0 = start at the west edge of the map
		if rng:NextNumber() < 0.3 then
			first = rng:NextInteger(1, #verticals - 2)
			last = rng:NextInteger(first + 1, #verticals)
		end
		local pts = {}
		if first == 0 then
			table.insert(pts, Vector2.new(Util.MIN_X, z + rng:NextNumber(-4, 4)))
			first = 1
		end
		for vi = first, last do
			local zz = z + rng:NextNumber(-7, 7)
			local x, dir = xAt(verticals[vi], zz)
			local p = Vector2.new(x, zz)
			table.insert(pts, p)
			if not inPark(p, 20) then
				table.insert(Roads.intersections, {
					position = p,
					mainDir = dir,
					mainWidth = Roads.KINDS[verticals[vi].kind].width,
					crossWidth = Roads.KINDS.street.width,
				})
			end
		end
		add("street", pts, true)
		z = z + rng:NextNumber(130, 170)
	end

	-- Alleys halfway between some pairs of streets, from one avenue to the next.
	for s = 1, #streetZs - 1 do
		local zm = (streetZs[s] + streetZs[s + 1]) / 2
		for vi = 1, #verticals - 1 do
			if rng:NextNumber() < 0.45 then
				local xa = xAt(verticals[vi], zm)
				local xb = xAt(verticals[vi + 1], zm)
				add("alley", { Vector2.new(xa, zm), Vector2.new(xb, zm + rng:NextNumber(-3, 3)) }, true)
			end
		end
	end

	-- Crooked lanes linking neighbouring streets mid-block.
	for _ = 1, 9 do
		local s = rng:NextInteger(1, #streetZs - 1)
		local vi = rng:NextInteger(1, #verticals - 1)
		local x0 = (xAt(verticals[vi], streetZs[s]) + xAt(verticals[vi + 1], streetZs[s])) / 2 + rng:NextNumber(-30, 30)
		local x1 = x0 + rng:NextNumber(-28, 28)
		local zA, zB = streetZs[s], streetZs[s + 1]
		add("lane", { Vector2.new(x0, zA), Vector2.new((x0 + x1) / 2 + rng:NextNumber(-8, 8), (zA + zB) / 2), Vector2.new(x1, zB) }, true)
	end

	-- A long diagonal boulevard that cuts across the grid.
	local bw = {}
	local from, to = Vector2.new(-330, Util.MAX_Z), Vector2.new(360, Util.MIN_Z)
	local perp = Vector2.new(-(to - from).Y, (to - from).X).Unit
	for i = 0, 14 do
		local t = i / 14
		table.insert(bw, from:Lerp(to, t) + perp * math.sin(t * math.pi * 1.4) * 38)
	end
	add("broadway", bw, false)

	-- Register roads (clipped around the park) with ids.
	local created = {}
	for _, entry in ipairs(raw) do
		local pieces = { entry.points }
		if entry.clip then
			pieces = clipToPark(entry.points)
		end
		for _, pts in ipairs(pieces) do
			table.insert(created, Roads.add(entry.kind, pts))
		end
	end
	return created
end

-- Polyline from a to b with a point every `step` studs, drifting sideways by up to
-- `wobble` per point (capped at 3x), so long roads are never perfectly straight.
function Roads.path(rng, a, b, step, wobble)
	local points = { a }
	local delta = b - a
	local length = delta.Magnitude
	local dir = delta.Unit
	local normal = Vector2.new(-dir.Y, dir.X)
	local n = math.max(1, math.floor(length / step))
	local offset = 0
	for i = 1, n - 1 do
		offset = math.clamp(offset + rng:NextNumber(-wobble, wobble), -wobble * 3, wobble * 3)
		table.insert(points, a + dir * (length * i / n) + normal * offset)
	end
	table.insert(points, b)
	return points
end

-- Downtown avenue pieces that reach an edge of downtown: "north" or "south".
function Roads.avenueEnds(roads, edge)
	local found = {}
	for _, road in ipairs(roads) do
		if road.kind == "avenue" or road.kind == "waterfront" then
			local pts = road.points
			if edge == "north" and math.abs(pts[1].Y - Util.MIN_Z) < 1 then
				table.insert(found, { road = road, point = pts[1] })
			elseif edge == "south" and math.abs(pts[#pts].Y - Util.MAX_Z) < 1 then
				table.insert(found, { road = road, point = pts[#pts] })
			end
		end
	end
	return found
end

-- Records road and sidewalk cells in the occupancy grid.
function Roads.rasterize(list)
	for _, road in ipairs(list) do
		for i = 1, #road.points - 1 do
			Util.markSegment(road.points[i], road.points[i + 1], road.width / 2, Util.ROAD, road.id, false)
		end
	end
	for _, road in ipairs(list) do
		if road.walk > 0 then
			for i = 1, #road.points - 1 do
				Util.markSegment(road.points[i], road.points[i + 1], road.width / 2 + road.walk, Util.WALK, nil, true)
			end
		end
	end
end

-- Iterates every segment of `list` (default: all roads): fn(road, a, b, dir, normal, length).
function Roads.eachSegment(fn, list)
	for _, road in ipairs(list or Roads.list) do
		for i = 1, #road.points - 1 do
			local a, b = road.points[i], road.points[i + 1]
			local delta = b - a
			local length = delta.Magnitude
			if length > 0.5 then
				local dir = delta.Unit
				fn(road, a, b, dir, Vector2.new(-dir.Y, dir.X), length)
			end
		end
	end
end

-- Draws a painted line along a segment, broken wherever it crosses another road.
local function paintLine(folder, a, dir, length, offset, normal, width, color, dashLength, gap)
	local step = 2
	local runStart = nil
	local function flush(endT)
		if runStart and endT - runStart > 1 then
			local midT = (runStart + endT) / 2
			local p = a + dir * midT + normal * offset
			Util.deco(folder, Vector3.new(width, 0.04, endT - runStart), Util.groundCF(p, dir, 0.33), color, Enum.Material.SmoothPlastic)
		end
		runStart = nil
	end
	local t = 0
	while t <= length do
		local p = a + dir * t + normal * offset
		local ok = not Util.isJunction(p.X, p.Y)
			and not Util.isJunction(p.X + dir.X * 5, p.Y + dir.Y * 5)
			and not Util.isJunction(p.X - dir.X * 5, p.Y - dir.Y * 5)
		if dashLength then
			local phase = t % (dashLength + gap)
			ok = ok and phase < dashLength
		end
		if ok then
			runStart = runStart or t
		else
			flush(t)
		end
		t = t + step
	end
	flush(length)
end

local function bridgeDetails(folder, road, mid, dir, length)
	-- Railings on both edges and a steel girder under the deck.
	local normal = Vector2.new(-dir.Y, dir.X)
	local edge = road.width / 2 + road.walk - 0.4
	for _, side in ipairs({ -1, 1 }) do
		local p = mid + normal * side * edge
		Util.solid(folder, Vector3.new(0.8, 3.4, length), Util.groundCF(p, dir, 0.25 + 1.7), Color3.fromRGB(70, 74, 72), Enum.Material.Metal)
	end
	Util.deco(folder, Vector3.new(road.width + road.walk * 2, 4, length), Util.groundCF(mid, dir, -2.6), Color3.fromRGB(58, 64, 62), Enum.Material.Metal)
end

-- Draws road surfaces, sidewalks and markings for the given roads.
function Roads.render(folder, list)
	for _, road in ipairs(list) do
		local yTop = 0.3 + (road.id % 7) * 0.004 -- tiny offsets stop overlapping roads flickering
		local color = road.kind == "alley" and ALLEY_ASPHALT or ASPHALT
		for i = 1, #road.points - 1 do
			local a, b = road.points[i], road.points[i + 1]
			local delta = b - a
			local length = delta.Magnitude
			if length > 0.5 then
				local dir = delta.Unit
				local mid = (a + b) / 2
				local extra = road.width * 0.5 -- overlap at joints so bends have no gaps
				Util.solid(folder, Vector3.new(road.width, 1, length + extra), Util.groundCF(mid, dir, yTop - 0.5), color, Enum.Material.Asphalt)
				if road.walk > 0 then
					Util.solid(folder, Vector3.new(road.width + road.walk * 2, 1, length + extra), Util.groundCF(mid, dir, 0.25 - 0.5), SIDEWALK, Enum.Material.Pavement)
				end
				if road.kind == "bridge" then
					bridgeDetails(folder, road, mid, dir, length)
				end
			end
		end
	end

	-- Lane markings on the big roads.
	Roads.eachSegment(function(road, a, _, dir, normal, length)
		if road.main then
			paintLine(folder, a, dir, length, 0.35, normal, 0.3, YELLOW)
			paintLine(folder, a, dir, length, -0.35, normal, 0.3, YELLOW)
			for _, side in ipairs({ -1, 1 }) do
				paintLine(folder, a, dir, length, side * road.width / 4, normal, 0.35, WHITE, 8, 22)
			end
		end
	end, list)
end

return Roads
