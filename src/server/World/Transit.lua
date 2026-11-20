-- Transit: subway Line 1 and the King St streetcar.
--
-- Line 1 runs straight under Yonge Street (x = LINE_X) through the 17 Toronto
-- stations from Finch to Union (positions in TorontoLayout), under the harbour to
-- Harbour and Central in the other city, then climbs out through an open cut onto
-- a viaduct to the elevated Portlands terminal in the industrial district. Underground stations have street entrance buildings, passages to a
-- ticket hall just under the street, and stairs to an island platform between
-- the two tracks (see StationKit).
--
-- The server builds the structure and the vehicle models (parked out of sight) and
-- publishes each route (path, stops, timing) as JSON in ReplicatedStorage. Every
-- client moves the vehicles from the shared server clock, so they are smooth and
-- in the same place for everyone (see client/Transit.client.lua).
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(script.Parent.Util)
local Roads = require(script.Parent.Roads)
local Layout = require(script.Parent.Layout)
local TorontoLayout = require(script.Parent.TorontoLayout)
local Kit = require(script.Parent.StationKit)
local Billboards = require(script.Parent.Billboards)
local Config = require(ReplicatedStorage.Shared.Config)

local Transit = {}

local V3 = Vector3.new
local M = Enum.Material
local Front = Enum.NormalId.Front

local LINE_X = 100
local RAIL = -36 -- track bed underground
local FLOOR_UP = 5 -- train floor above the track bed (= platform height)
local TRACK = 20.5 -- track centres at LINE_X +- TRACK
local HALF = 31 -- tunnel and station half-width
local PLAT_HALF = 14 -- island platform half-width
local TUNNEL_TOP = 16 -- tunnel ceiling above the track bed
local STATION_TOP = -18 -- station ceiling
local STATION_HALF = 105 -- underground station half-length
local CONCOURSE = -17 -- ticket hall, passages and entrance lobbies: floor
local CONCOURSE_TOP = -1.5 -- ticket hall ceiling
local PASSAGE_TOP = -2.5 -- passage and lobby ceiling
local ELEVATED = 16 -- track bed on the viaduct
local PORT_HALF = 100 -- elevated station half-length
local PARK_Y = -300 -- where vehicle models wait on the server

-- Line 1: the 17 Toronto stations from Finch to Union (TorontoLayout), then the
-- extension under the harbour to the other cities.
local STATIONS = {}
for _, st in ipairs(TorontoLayout.STATIONS) do
	table.insert(STATIONS, { name = st.name, z = st.z, tile = st.tile, tier = st.tier })
end
table.insert(STATIONS, { name = "HARBOUR", z = -560, tile = Color3.fromRGB(110, 170, 150), tier = "major" })
table.insert(STATIONS, { name = "CENTRAL", z = 0, tile = Color3.fromRGB(190, 160, 200), tier = "major" })
table.insert(STATIONS, { name = "PORTLANDS", z = 962, elevated = true })
local STATION_NAMES = {}
for _, st in ipairs(STATIONS) do
	table.insert(STATION_NAMES, st.name)
end
local LINE_START = STATIONS[1].z - STATION_HALF - 30 -- tail tunnel past Finch
local LINE_END = STATIONS[#STATIONS].z + PORT_HALF + 4

local TTC_RED = Color3.fromRGB(206, 30, 40)
local CONCRETE = Color3.fromRGB(150, 148, 142)
local DARK = Color3.fromRGB(40, 40, 44)

local state = {} -- filled by layout, used by build

-- x of a train using a crossover { zA, xA, zB, xB }: xA on the zA side, xB past zB,
-- an S-curve between.
local function crossoverX(z, cross)
	local t = math.clamp((z - cross[1]) / (cross[3] - cross[1]), 0, 1)
	t = t * t * (3 - 2 * t)
	return cross[2] + (cross[4] - cross[2]) * t
end


---------------------------------------------------------------------------
-- Track profile
---------------------------------------------------------------------------
-- Monotone cubic through (xs, ys): smooth and never overshoots.
local function monotone(xs, ys)
	local n = #xs
	local d, m = {}, {}
	for i = 1, n - 1 do
		d[i] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])
	end
	m[1], m[n] = d[1], d[n - 1]
	for i = 2, n - 1 do
		m[i] = (d[i - 1] * d[i] <= 0) and 0 or (d[i - 1] + d[i]) / 2
	end
	for i = 1, n - 1 do
		if d[i] == 0 then
			m[i], m[i + 1] = 0, 0
		else
			local a, b = m[i] / d[i], m[i + 1] / d[i]
			local h = a * a + b * b
			if h > 9 then
				local t = 3 / math.sqrt(h)
				m[i], m[i + 1] = t * a * d[i], t * b * d[i]
			end
		end
	end
	return function(x)
		if x <= xs[1] then
			return ys[1]
		elseif x >= xs[n] then
			return ys[n]
		end
		local i = 1
		while xs[i + 1] < x do
			i = i + 1
		end
		local h = xs[i + 1] - xs[i]
		local t = (x - xs[i]) / h
		local t2, t3 = t * t, t * t * t
		return (2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h * m[i] + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h * m[i + 1]
	end
end

-- z of every road crossing the line's corridor between z0 and z1, padded by the
-- road's half-width plus sidewalk.
local function crossings(z0, z1)
	local found = {}
	for _, road in ipairs(Roads.list) do
		for i = 1, #road.points - 1 do
			local a, b = road.points[i], road.points[i + 1]
			if (a.X - LINE_X) * (b.X - LINE_X) <= 0 and math.abs(b.X - a.X) > 0.01 then
				local t = (LINE_X - a.X) / (b.X - a.X)
				local z = a.Y + (b.Y - a.Y) * t
				if z > z0 and z < z1 then
					table.insert(found, { z = z, pad = road.width / 2 + road.walk })
				end
			end
		end
	end
	return found
end

---------------------------------------------------------------------------
-- Layout: profile, holes in the ground, reserved land
---------------------------------------------------------------------------
-- Street entrances (see StationKit.entrance): a glass-and-steel entrance building
-- on a lot right behind a sidewalk, with stairs, an up escalator and an elevator
-- down to a lobby, then a passage to the ticket hall. sz = +1: you walk in from
-- the -z side and go down toward +z; sz = -1 is the mirror image.
-- In entrance coordinates the whole thing covers dz -26..41.5, x -23..23.
local ENTRANCE_W, ENTRANCE_D, ENTRANCE_MID = 46, 68, 7.75
local LOBBY_MID = 30 -- the passage leaves the lobby here (dz)
local HALL_HALF, HALL_LEN, FARE_AT = 36, 90, 36 -- ticket hall: half-width, length, fare line
local SPINE_OFF = HALL_HALF + 12 -- side passage runs alongside the hall at LINE_X +- this
local HALL_DOOR = 18 -- side doorways into the hall are this far in from its north end

-- When the side you walk in from touches a sidewalk across the full width, returns
-- how far out the sidewalk starts; otherwise nil.
local function frontsSidewalk(c, sz)
	local reach = 0
	for _, dx in ipairs({ -16, -6, 6, 16 }) do
		local found = nil
		for d = 27, 37, 2 do
			local cell = Util.get(c.X + dx, c.Y - sz * d)
			if cell == Util.WALK then
				found = d
				break
			elseif cell ~= Util.FREE then
				return nil
			end
		end
		if not found then
			return nil
		end
		reach = math.max(reach, found)
	end
	return reach
end

-- Keeps the ground between the entrance and the sidewalk clear of buildings.
local function claimApron(c, sz)
	for dx = -22, 22, 2 do
		for d = 25, 37, 2 do
			if Util.get(c.X + dx, c.Y - sz * d) == Util.FREE then
				Util.set(c.X + dx, c.Y - sz * d, Util.BUILT)
			end
		end
	end
end

-- Up to two entrances per station (one each side of the line where possible),
-- close to the ticket hall at the station's north end. A passage either comes in
-- through the hall's side wall (before the fare line) or, for an entrance further
-- north, along the line into the hall's north wall.
local function findEntrances(station)
	local cz0 = station.z - STATION_HALF
	local target = Vector2.new(LINE_X, cz0 + 15)
	local fwd, right = Vector2.new(0, -1), Vector2.new(1, 0)
	local best = {} -- side -> { c, sz, dist, reach }
	-- How a passage from a lobby at passZ reaches the hall: straight into its side
	-- wall, along the line into its north wall, or (from anywhere else) along a
	-- side passage that runs beside the hall to a side doorway.
	local function routeFor(x, passZ)
		if passZ >= cz0 + 11 and passZ <= cz0 + FARE_AT - 11 then
			return "inside", 0
		elseif passZ <= cz0 - 14 then
			return "north", 0
		elseif math.abs(x - LINE_X) >= SPINE_OFF + 11 + 23 + 4 then
			return "spine", 30
		end
		return nil, 0
	end
	for x = target.X - 360, target.X + 360, 4 do
		if math.abs(x - LINE_X) >= HALL_HALF + 28 then
			for z = target.Y - 300, target.Y + 320, 4 do
				for _, sz in ipairs({ 1, -1 }) do
					local route, penalty = routeFor(x, z + LOBBY_MID * sz)
					if route then
						local c = Vector2.new(x, z)
						local side = x < LINE_X and -1 or 1
						local dist = (c - target).Magnitude + penalty
						local current = best[side]
						if not current or dist < current.dist then
							local reach = frontsSidewalk(c, sz)
							local centre = c + Vector2.new(0, ENTRANCE_MID * sz)
							if reach and Util.rectFree(centre, fwd, right, ENTRANCE_W, ENTRANCE_D) then
								best[side] = { c = c, sz = sz, dist = dist, reach = reach, route = route }
							end
						end
					end
				end
			end
		end
	end
	local found = {}
	local northTaken = false -- only one passage can come in along the line from the north
	for _, side in ipairs({ -1, 1 }) do
		local b = best[side]
		local north = b and b.route == "north"
		local enough = station.tier == "minor" and #found >= 1
		if b and b.dist < 480 and not (north and northTaken) and not enough then
			local centre = b.c + Vector2.new(0, ENTRANCE_MID * b.sz)
			-- The other side's pick may overlap this one: check again before claiming.
			if Util.rectFree(centre, fwd, right, ENTRANCE_W, ENTRANCE_D) then
				northTaken = northTaken or north
				Util.rectMark(centre, fwd, right, ENTRANCE_W, ENTRANCE_D, Util.BUILT)
				claimApron(b.c, b.sz)
				table.insert(found, b)
			end
		end
	end
	return found
end

function Transit.layout(shared)
	-- 1. Vertical profile: deep until the last road it passes under, then up to the
	--    viaduct, high enough to clear the industrial north road.
	local southZ = STATIONS[#STATIONS - 1].z + STATION_HALF -- south end of the last underground station
	local northRoadZ = Layout.INDUSTRIAL_NORTH_Z
	local lastUnder = southZ + 125
	for _, c in ipairs(crossings(southZ, northRoadZ - 30)) do
		lastUnder = math.max(lastUnder, c.z + c.pad + 2)
	end
	local clearZ = northRoadZ - 26 -- must be up at viaduct height by here
	local grade = (13 + 17) / math.max(clearZ - lastUnder, 1)
	if grade > 0.2 then
		warn(string.format("[Transit] steep climb to the viaduct: %.0f%%", grade * 100))
	end
	-- A midpoint on the straight climb keeps the grade even (no hump in the middle).
	local xs = { LINE_START, lastUnder - 120, lastUnder, (lastUnder + clearZ) / 2, clearZ, clearZ + 26, LINE_END }
	local ys = { RAIL, RAIL, -17, -2, 13, ELEVATED, ELEVATED }
	state.railAt = monotone(xs, ys)
	-- Crossovers { zA, xA, zB, xB }: northbound trains move from the east to the west
	-- track just south of Finch; southbound from west to east just before Portlands.
	local finchSouth = STATIONS[1].z + STATION_HALF + 20
	state.finchCross = { finchSouth + 160, LINE_X + TRACK, finchSouth, LINE_X - TRACK }
	local portNorth = STATIONS[#STATIONS].z - PORT_HALF - 15
	state.portCross = { portNorth - 160, LINE_X - TRACK, portNorth, LINE_X + TRACK }
	local railAt = state.railAt

	-- Where the track comes out of the ground.
	local surfaceZ = clearZ
	for z = lastUnder, clearZ, 2 do
		if railAt(z) >= 0 then
			surfaceZ = z
			break
		end
	end
	state.surfaceZ = surfaceZ
	state.lastUnder = lastUnder

	local holes = {}
	local function hole(min, max)
		Util.carve(min, max)
		table.insert(holes, { min = min, max = max })
	end

	-- 2. Tunnel corridor (deep part), stations, concourses, stairwells.
	hole(V3(LINE_X - HALF - 1, RAIL - 2, LINE_START - 5), V3(LINE_X + HALF + 1, RAIL + TUNNEL_TOP + 1, lastUnder - 120))
	for z = lastUnder - 120, surfaceZ, 10 do
		local top = math.max(railAt(z), railAt(z + 10)) + TUNNEL_TOP + 1
		if railAt(z + 10) + TUNNEL_TOP > -1 then
			top = 2 -- open cut: through to the surface
		end
		hole(V3(LINE_X - HALF - 1, math.min(railAt(z), railAt(z + 10)) - 2, z), V3(LINE_X + HALF + 1, top, z + 10))
	end

	state.entrances = {}
	for _, station in ipairs(STATIONS) do
		if not station.elevated then
			local zc = station.z
			hole(V3(LINE_X - HALF - 1, RAIL - 2, zc - STATION_HALF - 1), V3(LINE_X + HALF + 1, STATION_TOP + 1, zc + STATION_HALF + 1))
			-- Ticket hall over the north end of the platform.
			local cz0, cz1 = zc - STATION_HALF, zc - STATION_HALF + HALL_LEN
			hole(V3(LINE_X - HALL_HALF - 1.5, CONCOURSE - 1, cz0 - 1.5), V3(LINE_X + HALL_HALF + 1.5, CONCOURSE_TOP + 0.5, cz1 + 1.5))
			-- Street entrances, and the passages from their lobbies to the hall.
			local list = {}
			for _, e in ipairs(findEntrances(station)) do
				local spot, sz = e.c, e.sz
				local function zr(a, b)
					local p, q = spot.Y + a * sz, spot.Y + b * sz
					return math.min(p, q), math.max(p, q)
				end
				local toward = LINE_X > spot.X and 1 or -1
				local passZ = spot.Y + LOBBY_MID * sz
				local route = e.route
				local inside = route == "inside"
				local sd = -toward -- which side of the line the entrance is on
				local spineX = LINE_X + sd * SPINE_OFF
				local hallZ = cz0 + HALL_DOOR
				-- Entrance: open down to the stairs under the building, roofed beyond.
				local a0, a1 = zr(-21.5, 11)
				hole(V3(spot.X - 23.5, CONCOURSE - 1, a0), V3(spot.X + 23.5, 2, a1))
				local b0, b1 = zr(10.5, 42.5)
				hole(V3(spot.X - 23.5, CONCOURSE - 1, b0), V3(spot.X + 23.5, -1.5, b1))
				-- Passage along x from the lobby wall.
				local xa = spot.X + toward * 23
				local xb
				if route == "inside" then
					xb = LINE_X - toward * (HALL_HALF + 1)
				elseif route == "north" then
					xb = LINE_X + toward * 11
				else
					xb = spineX + sd * 11
				end
				hole(V3(math.min(xa, xb), CONCOURSE - 1, passZ - 11), V3(math.max(xa, xb), PASSAGE_TOP + 1, passZ + 11))
				if route == "north" then
					hole(V3(LINE_X - 11, CONCOURSE - 1, passZ), V3(LINE_X + 11, PASSAGE_TOP + 1, cz0))
				elseif route == "spine" then
					hole(V3(spineX - 11, CONCOURSE - 1, math.min(passZ, hallZ) - 11), V3(spineX + 11, PASSAGE_TOP + 1, math.max(passZ, hallZ) + 11))
				end
				table.insert(list, { spot = spot, sz = sz, reach = e.reach, passZ = passZ, toward = toward, inside = inside, route = route, xa = xa, xb = xb, sd = sd, spineX = spineX, hallZ = hallZ })
				print(string.format("[Transit] %s station entrance at x=%.0f, z=%.0f (%s)", station.name, spot.X, spot.Y, route))
			end
			if #list == 0 then
				warn("[Transit] no space for a street entrance at " .. station.name)
			end
			state.entrances[station] = list
		end
	end
	state.holes = holes

	-- 3. Keep buildings off the open cut, viaduct and the elevated station.
	Util.markSegment(Vector2.new(LINE_X, state.lastUnder - 10), Vector2.new(LINE_X, LINE_END + 30), HALF + 4, Util.RESERVED, nil, true)
	local port = STATIONS[#STATIONS]
	Util.markSegment(Vector2.new(LINE_X, port.z + PORT_HALF), Vector2.new(LINE_X, port.z + PORT_HALF + 26), 8, Util.RESERVED, nil, true)
end

---------------------------------------------------------------------------
-- Building helpers
---------------------------------------------------------------------------
local span, stairs, light, nameSign, marker = Kit.span, Kit.stairs, Kit.light, Kit.nameSign, Kit.marker

---------------------------------------------------------------------------
-- Tunnel, open cut and viaduct
---------------------------------------------------------------------------
local function inStation(z)
	for _, s in ipairs(STATIONS) do
		local half = s.elevated and PORT_HALF or STATION_HALF
		if math.abs(z - s.z) < half then
			return s
		end
	end
	return nil
end

-- True inside either crossover (no centre columns there: trains pass through).
local function inCrossover(z)
	for _, c in ipairs({ state.finchCross, state.portCross }) do
		if z > math.min(c[1], c[3]) - 12 and z < math.max(c[1], c[3]) + 12 then
			return true
		end
	end
	return false
end

-- Diagonal track for a crossover (ballast and rails along the S-curve).
local function buildCrossover(folder, cross)
	local railAt = state.railAt
	local z0, z1 = math.min(cross[1], cross[3]), math.max(cross[1], cross[3])
	local z = z0
	while z < z1 do
		local z2 = math.min(z + 8, z1)
		local a = V3(crossoverX(z, cross), railAt(z), z)
		local b = V3(crossoverX(z2, cross), railAt(z2), z2)
		span(folder, a, b, 8.4, 0.3, 0.17, Color3.fromRGB(70, 64, 58), M.Slate, false)
		for _, r in ipairs({ -3, 3 }) do
			span(folder, a + V3(r, 0, 0), b + V3(r, 0, 0), 0.35, 0.4, 0.77, Color3.fromRGB(150, 150, 156), M.Metal, false)
		end
		z = z2
	end
end

local function buildLine(folder)
	local railAt = state.railAt
	local step = 20
	local z = LINE_START
	local n = 0
	local BALLAST = Color3.fromRGB(70, 64, 58)
	local SLEEPER = Color3.fromRGB(96, 92, 86)
	local RAIL_STEEL = Color3.fromRGB(150, 150, 156)
	while z < LINE_END - 0.1 do
		local z2 = math.min(z + step, LINE_END)
		local ya, yb = railAt(z), railAt(z2)
		local a, b = V3(LINE_X, ya, z), V3(LINE_X, yb, z2)
		local dir = (b - a).Unit
		local midZ = (z + z2) / 2
		local midY = (ya + yb) / 2
		local station = inStation(midZ)
		local elevated = math.min(ya, yb) >= 0
		n = n + 1

		-- Track bed (viaduct deck with parapets and columns when elevated).
		if elevated then
			span(folder, a, b, HALF * 2 + 2, 1.6, -0.8, CONCRETE, M.Concrete, true)
			for _, side in ipairs({ -1, 1 }) do
				span(folder, a + V3(side * (HALF + 0.4), 0, 0), b + V3(side * (HALF + 0.4), 0, 0), 0.8, 3.6, 1.8, CONCRETE, M.Concrete, true)
			end
			if n % 2 == 0 then
				for _, side in ipairs({ -1, 1 }) do
					local cx = LINE_X + side * (HALF - 4)
					local cell = Util.get(cx, midZ)
					if cell ~= Util.ROAD and cell ~= Util.WALK and midY > 3 then
						Util.solid(folder, V3(4, midY - 1.6, 4), CFrame.new(cx, (midY - 1.6) / 2, midZ), CONCRETE, M.Concrete)
					end
				end
				if midY > 3 then
					Util.deco(folder, V3(HALF * 2, 2.5, 4), CFrame.new(LINE_X, midY - 2.8, midZ), CONCRETE, M.Concrete)
				end
			end
		else
			span(folder, a, b, HALF * 2, 1, -0.5, Color3.fromRGB(90, 88, 84), M.Concrete, true)
		end

		-- Each track: ballast, sleepers, two running rails and the power rail on
		-- the outer side (with its yellow cover board).
		local sleeperEvery = station and 4 or 20 / 3
		for _, t in ipairs({ -TRACK, TRACK }) do
			span(folder, a + V3(t, 0, 0), b + V3(t, 0, 0), 8.4, 0.3, 0.15, BALLAST, M.Slate, false)
			for _, r in ipairs({ -3, 3 }) do
				span(folder, a + V3(t + r, 0, 0), b + V3(t + r, 0, 0), 0.35, 0.4, 0.75, RAIL_STEEL, M.Metal, false)
			end
			local outer = t > 0 and 1 or -1
			span(folder, a + V3(t + outer * 5, 0, 0), b + V3(t + outer * 5, 0, 0), 0.5, 0.5, 0.65, Color3.fromRGB(110, 110, 114), M.Metal, false)
			span(folder, a + V3(t + outer * 5, 0, 0), b + V3(t + outer * 5, 0, 0), 1.1, 0.12, 1.0, Color3.fromRGB(214, 176, 60), M.SmoothPlastic, false)
			local s = sleeperEvery / 2
			while s < step do
				local p = a + dir * s + V3(t, 0, 0)
				local sleeper = Util.deco(folder, V3(8.4, 0.4, 1.1), CFrame.lookAt(p, p + dir) * CFrame.new(0, 0.45, 0), SLEEPER, M.Concrete)
				sleeper.CastShadow = false
				s = s + sleeperEvery
			end
		end

		if not elevated and not station then
			local covered = math.max(ya, yb) + TUNNEL_TOP <= -1
			if covered then
				local frame = CFrame.lookAt((a + b) / 2, b)
				local len = (b - a).Magnitude + 0.2
				for _, side in ipairs({ -1, 1 }) do
					-- Walls, chamfered top corners, wall lamps.
					local w = span(folder, a + V3(side * (HALF + 0.5), 0, 0), b + V3(side * (HALF + 0.5), 0, 0), 1, TUNNEL_TOP, TUNNEL_TOP / 2, CONCRETE, M.Concrete, true)
					if w then
						Util.texture(w, side < 0 and Enum.NormalId.Right or Enum.NormalId.Left, "concrete_stained", 14, 14)
					end
					Util.deco(folder, V3(6, 1, len), frame * CFrame.new(side * (HALF - 2), TUNNEL_TOP - 2, 0) * CFrame.Angles(0, 0, side * math.rad(45)), CONCRETE, M.Concrete)
					if n % 2 == 0 then
						local lamp = Util.deco(folder, V3(0.4, 0.6, 1.6), CFrame.new(LINE_X + side * (HALF - 0.1), midY + 12, midZ), Color3.fromRGB(255, 236, 200), M.Neon)
						lamp.CastShadow = false
					end
					-- Maintenance walkway along the wall, with a handrail.
					span(folder, a + V3(side * (HALF - 2.25), 0, 0), b + V3(side * (HALF - 2.25), 0, 0), 4.5, 1.6, 0.8, Color3.fromRGB(120, 118, 112), M.Concrete, true)
					span(folder, a + V3(side * (HALF - 4.4), 0, 0), b + V3(side * (HALF - 4.4), 0, 0), 0.2, 0.2, 5.6, Color3.fromRGB(230, 190, 40), M.Metal, false)
					if n % 2 == 1 then
						local post = a + dir * 2 + V3(side * (HALF - 4.4), 0, 0)
						Util.deco(folder, V3(0.2, 4, 0.2), CFrame.new(post + V3(0, 3.6, 0)), Color3.fromRGB(230, 190, 40), M.Metal)
					end
					-- Cable trays.
					for _, h in ipairs({ 10, 11.2 }) do
						span(folder, a + V3(side * (HALF - 0.35), 0, 0), b + V3(side * (HALF - 0.35), 0, 0), 0.6, 0.25, h, Color3.fromRGB(46, 46, 50), M.Metal, false)
					end
				end
				span(folder, a, b, HALF * 2 + 2, 1, TUNNEL_TOP + 0.5, CONCRETE, M.Concrete, true)
				-- Columns between the tracks.
				if n % 2 == 1 and not inCrossover(midZ) then
					Util.solid(folder, V3(2, TUNNEL_TOP, 2), CFrame.new(LINE_X, midY + TUNNEL_TOP / 2, midZ), CONCRETE, M.Concrete)
				end
			else
				-- Open cut: retaining walls up to street level with a fence on top.
				for _, side in ipairs({ -1, 1 }) do
					local h = 1.2 - math.min(ya, yb)
					local cx = LINE_X + side * (HALF + 0.5)
					Util.solid(folder, V3(1, h, step + 0.2), CFrame.new(cx, 1.2 - h / 2, midZ), CONCRETE, M.Concrete)
					local fence = Util.solid(folder, V3(0.2, 4, step + 0.2), CFrame.new(cx, 3.2, midZ), Color3.fromRGB(90, 96, 92), M.DiamondPlate)
					fence.Transparency = 0.4
				end
			end
		end
		z = z2
	end
	-- Buffer stops at both ends.
	for _, t in ipairs({ -TRACK, TRACK }) do
		for _, info in ipairs({ { LINE_START + 2, railAt(LINE_START) }, { LINE_END - 2, railAt(LINE_END) } }) do
			Util.solid(folder, V3(5, 3, 1.5), CFrame.new(LINE_X + t, info[2] + 1.5, info[1]), Color3.fromRGB(230, 190, 30), M.Metal)
			local lamp = Util.deco(folder, V3(0.8, 0.8, 0.2), CFrame.new(LINE_X + t, info[2] + 3.4, info[1] + (info[1] < 0 and 0.85 or -0.85)), Color3.fromRGB(255, 40, 30), M.Neon)
			lamp.CastShadow = false
		end
	end
	buildCrossover(folder, state.finchCross)
	buildCrossover(folder, state.portCross)
	-- End wall of the tunnel.
	Util.solid(folder, V3(HALF * 2 + 2, TUNNEL_TOP + 2, 1), CFrame.new(LINE_X, RAIL + TUNNEL_TOP / 2, LINE_START - 1), CONCRETE, M.Concrete)
end

---------------------------------------------------------------------------
-- Underground stations
---------------------------------------------------------------------------
local function buildStation(folder, station, entrances)
	local zc = station.z
	local platformTop = RAIL + FLOOR_UP
	local z0, z1 = zc - STATION_HALF, zc + STATION_HALF
	local L = STATION_HALF * 2
	local tile = station.tile
	local cz0, cz1 = z0, z0 + HALL_LEN
	local stairZ0, stairZ1 = z0 + 50, z0 + 76
	local function inStairs(z, pad)
		return z > stairZ0 - pad and z < stairZ1 + pad
	end
	local rng = Random.new(math.floor(zc) + 7)
	local PAINT = Color3.fromRGB(226, 224, 218)
	local bandTop = platformTop + 9 -- top of the tiled band on the track walls

	-- Track walls: concrete below the platform level, the station's tiles with its
	-- name and big ads in the band, paint above. Each wall faces one direction of
	-- travel, so it carries that direction's header.
	for _, side in ipairs({ -1, 1 }) do
		local x = LINE_X + side * (HALF + 0.5)
		Util.solid(folder, V3(1, FLOOR_UP, L), CFrame.new(x, RAIL + FLOOR_UP / 2, zc), CONCRETE, M.Concrete)
		local band = Util.solid(folder, V3(1, bandTop - platformTop, L), CFrame.new(x, (platformTop + bandTop) / 2, zc), tile, M.CeramicTiles)
		band.Name = "StationWall"
		Util.solid(folder, V3(1, STATION_TOP - bandTop, L), CFrame.new(x, (bandTop + STATION_TOP) / 2, zc), PAINT, M.SmoothPlastic)
		local inner = LINE_X + side * HALF
		Util.deco(folder, V3(0.2, 0.5, L), CFrame.new(inner - side * 0.1, bandTop, zc), Util.shade(tile, 0.55), M.SmoothPlastic)
		local facing = V3(-side, 0, 0)
		local header = side > 0 and "LINE 1  ·  NORTHBOUND TO FINCH  ·  PLATFORM 2" or "LINE 1  ·  SOUTHBOUND TO PORTLANDS  ·  PLATFORM 1"
		if station == STATIONS[1] and side > 0 then
			header = "NO SERVICE  ·  TRAINS LEAVE FROM PLATFORM 1"
		end
		for k = -2, 2 do
			local nz = zc + k * 40
			local p = V3(inner - side * 0.06, platformTop + 5.2, nz)
			nameSign(folder, CFrame.lookAt(p, p + facing), V3(26, 4.6, 0.1), station.name, Util.shade(tile, 1.18), Color3.fromRGB(20, 20, 24))
			local h = V3(inner - side * 0.06, bandTop + 1.4, nz)
			nameSign(folder, CFrame.lookAt(h, h + facing), V3(28, 2, 0.1), header, Color3.fromRGB(22, 22, 26))
			if k < 2 then
				local ap = V3(inner - side * 0.05, platformTop + 4.9, nz + 20)
				if k == 0 then
					Kit.mapBoard(folder, CFrame.lookAt(ap, ap + facing), 17, 7, "LINE 1 YONGE", STATION_NAMES, station.name)
				else
					Kit.adPanel(folder, CFrame.lookAt(ap, ap + facing), 17, 7, rng)
				end
			end
		end
	end

	-- Ceiling. Under the ticket hall its floor is the roof; a lower finish layer
	-- hides it, open over the stairs up to the hall. Beams across, light rows over
	-- the platform edges and dimmer ones over the tracks.
	local ceilY = STATION_TOP + 0.5
	local CEIL = Color3.fromRGB(226, 226, 222)
	Util.solid(folder, V3(HALF * 2 + 2, 1, z1 - cz1), CFrame.new(LINE_X, ceilY, (cz1 + z1) / 2), CEIL, M.SmoothPlastic)
	local finishY = STATION_TOP - 0.3
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(HALF - 12, 0.4, cz1 - z0), CFrame.new(LINE_X + side * (12 + (HALF - 12) / 2), finishY, (z0 + cz1) / 2), CEIL, M.SmoothPlastic)
	end
	Util.deco(folder, V3(24, 0.4, stairZ0 - z0), CFrame.new(LINE_X, finishY, (z0 + stairZ0) / 2), CEIL, M.SmoothPlastic)
	Util.deco(folder, V3(24, 0.4, 6), CFrame.new(LINE_X, finishY, cz1 - 3), CEIL, M.SmoothPlastic)
	for z = z0 + 10, z1 - 5, 20 do
		if not inStairs(z, 2) then
			Util.deco(folder, V3(HALF * 2, 1.2, 1.4), CFrame.new(LINE_X, finishY - 0.8, z), Color3.fromRGB(200, 200, 196), M.Concrete)
		end
	end
	local lit = 0
	for z = z0 + 5, z1 - 5, 20 do
		for _, x in ipairs({ -11, 11, -24, 24 }) do
			local overTrack = math.abs(x) > 16
			local strip = Util.deco(folder, V3(1.2, 0.2, 14), CFrame.new(LINE_X + x, finishY - 0.3, z + 5), overTrack and Color3.fromRGB(220, 222, 230) or Color3.fromRGB(255, 252, 244), M.Neon)
			strip.CastShadow = false
			if not overTrack then
				lit = lit + 1
				if lit % 2 == 0 then
					light(strip, Enum.NormalId.Bottom, 20, 1.1, Color3.fromRGB(255, 246, 232))
				end
			end
		end
	end

	-- Island platform: granite floor, white edge coping, yellow tactile strip.
	Util.solid(folder, V3(PLAT_HALF * 2, FLOOR_UP + 1, L - 4), CFrame.new(LINE_X, (RAIL - 1 + platformTop) / 2, zc), Color3.fromRGB(176, 174, 168), M.Granite)
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(1, 0.08, L - 4), CFrame.new(LINE_X + side * (PLAT_HALF - 0.5), platformTop + 0.04, zc), Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
		Util.deco(folder, V3(2.6, 0.08, L - 4), CFrame.new(LINE_X + side * (PLAT_HALF - 2.3), platformTop + 0.04, zc), Color3.fromRGB(250, 204, 30), M.Pebble)
		-- Dark recess under the platform edge.
		Util.deco(folder, V3(0.6, FLOOR_UP - 0.6, L - 4), CFrame.new(LINE_X + side * (PLAT_HALF + 0.05), RAIL + (FLOOR_UP - 0.6) / 2, zc), Color3.fromRGB(30, 30, 32), M.Concrete)
	end

	-- Columns in two rows, with name plates, maps, emergency points and clocks.
	local colIndex = 0
	for z = z0 + 12, z1 - 8, 20 do
		if not inStairs(z, 3) then
			for _, side in ipairs({ -1, 1 }) do
				colIndex = colIndex + 1
				local x = LINE_X + side * 8.5
				Util.solid(folder, V3(2.4, STATION_TOP - platformTop, 2.4), CFrame.new(x, (platformTop + STATION_TOP) / 2, z), Color3.fromRGB(150, 152, 156), M.Metal)
				Util.solid(folder, V3(3, 4, 3), CFrame.new(x, platformTop + 2, z), tile, M.CeramicTiles)
				local out = V3(side, 0, 0)
				local plate = V3(x + side * 1.25, platformTop + 9, z)
				nameSign(folder, CFrame.lookAt(plate, plate + out), V3(2.3, 1.3, 0.1), station.name, Color3.fromRGB(22, 22, 26))
				local inside = V3(x - side * 1.25, platformTop + 6, z)
				if colIndex % 4 == 3 then
					Kit.emergency(folder, CFrame.lookAt(inside + V3(0, -1, 0), inside + V3(0, -1, 0) - out))
				end
			end
		end
	end
	-- Benches back to back down the middle, bins, clocks.
	local benchIndex = 0
	for z = z0 + 22, z1 - 12, 20 do
		if not inStairs(z, 6) then
			benchIndex = benchIndex + 1
			for _, side in ipairs({ -1, 1 }) do
				local p = V3(LINE_X + side * 1.4, platformTop, z)
				Kit.bench(folder, CFrame.lookAt(p, p + V3(side, 0, 0)) * CFrame.Angles(0, 0, 0))
			end
			if benchIndex % 2 == 0 then
				Kit.bin(folder, CFrame.lookAt(V3(LINE_X, platformTop, z + 5), V3(LINE_X + 1, platformTop, z + 5)))
			end
		end
	end
	for _, z in ipairs({ z0 + 30, z1 - 30 }) do
		local p = V3(LINE_X, STATION_TOP - 3, z)
		Util.deco(folder, V3(0.15, 2.4, 0.15), CFrame.new(LINE_X, STATION_TOP - 1.5, z), DARK, M.Metal)
		Kit.clock(folder, CFrame.lookAt(p, p + V3(0, 0, 1)))
		Kit.clock(folder, CFrame.lookAt(p, p - V3(0, 0, 1)))
	end

	-- Departure boards over each side of the platform (filled in by the timetable).
	for _, z in ipairs({ z0 + 90, zc + 25, z1 - 20 }) do
		for _, side in ipairs({ -1, 1 }) do
			Kit.departureBoard(folder, CFrame.new(LINE_X + side * 11, STATION_TOP - 5.2, z), station.name, side > 0 and "N" or "S", STATION_TOP - 0.5)
		end
	end

	-- Platform ends: railings and a no-entry sign.
	for _, info in ipairs({ { z0 + 2, 1 }, { z1 - 2, -1 } }) do
		local z = info[1] + info[2] * 0.2
		Util.solid(folder, V3(PLAT_HALF * 2, 4.4, 0.3), CFrame.new(LINE_X, platformTop + 2.2, z), Color3.fromRGB(230, 190, 40), M.Metal)
		local p = V3(LINE_X, platformTop + 2.2, z + info[2] * 0.2)
		local sign = Util.deco(folder, V3(13, 1.8, 0.1), CFrame.lookAt(p, p + V3(0, 0, info[2])), Color3.fromRGB(20, 20, 20), M.SmoothPlastic)
		Util.sign(sign, Front, "NO ENTRY · AUTHORIZED PERSONNEL", Color3.fromRGB(250, 204, 30), Enum.Font.GothamBold).LightInfluence = 0.3
	end

	-- Signals at the platform ends, on the walkway side of each track.
	for _, side in ipairs({ -1, 1 }) do
		-- Northbound (east, +x) trains leave from the north end; southbound from the south.
		local z = side > 0 and (z0 - 8) or (z1 + 8)
		local facing = side > 0 and V3(0, 0, 1) or V3(0, 0, -1)
		Kit.signal(folder, CFrame.lookAt(V3(LINE_X + side * (TRACK + 7.5), RAIL + 1.6, z), V3(LINE_X + side * (TRACK + 7.5), RAIL + 1.6, z) + facing), station.name, side > 0 and "N" or "S")
	end

	-- Ticket hall, passages and street entrances (StationKit).
	local gaps = { [-1] = {}, [1] = {} }
	local north = {}
	for _, e in ipairs(entrances) do
		if e.route == "inside" then
			table.insert(gaps[e.sd], { e.passZ - 10, e.passZ + 10 })
		elseif e.route == "spine" then
			table.insert(gaps[e.sd], { e.hallZ - 10, e.hallZ + 10 })
		else
			table.insert(north, { LINE_X - 10, LINE_X + 10 })
		end
	end
	local names = {}
	for _, s in ipairs(STATIONS) do
		table.insert(names, s.name)
	end
	Kit.concourse(folder, station, {
		x = LINE_X,
		floor = CONCOURSE,
		top = CONCOURSE_TOP,
		passageTop = PASSAGE_TOP,
		z0 = cz0,
		z1 = cz1,
		fareZ = cz0 + FARE_AT,
		stair0 = stairZ0,
		stair1 = stairZ1,
		platformTop = platformTop,
		half = HALL_HALF,
		gapsWest = gaps[-1],
		gapsEast = gaps[1],
		gapsNorth = north,
		stations = names,
	}, rng)

	for _, e in ipairs(entrances) do
		Kit.entrance(folder, e, station, { floor = CONCOURSE, passageTop = PASSAGE_TOP, ceilingTop = -1.5 }, rng)
		if e.route == "inside" then
			Kit.passage(folder, true, e.xa, e.xb, e.passZ, 10, CONCOURSE, PASSAGE_TOP, station.tile, {}, false, false, rng)
		elseif e.route == "spine" then
			-- Along x to the side passage, along it beside the hall, in through a side door.
			Kit.passage(folder, true, e.xa, e.xb, e.passZ, 10, CONCOURSE, PASSAGE_TOP, station.tile, {}, false, false, rng)
			local outer = { { e.passZ - 10, e.passZ + 10 } }
			local inner = { { e.hallZ - 10, e.hallZ + 10 } }
			local spineGaps = e.sd > 0 and { minus = inner, plus = outer } or { minus = outer, plus = inner }
			Kit.passage(folder, false, math.min(e.passZ, e.hallZ) - 10, math.max(e.passZ, e.hallZ) + 10, e.spineX, 10, CONCOURSE, PASSAGE_TOP, station.tile, spineGaps, true, true, rng)
			-- Floor and ceiling through the doorway between the two walls.
			Util.solid(folder, V3(2.4, 1, 20), CFrame.new(LINE_X + e.sd * (HALL_HALF + 1), CONCOURSE - 0.5, e.hallZ), Color3.fromRGB(176, 174, 168), M.Granite)
			Util.deco(folder, V3(2.4, 0.5, 20), CFrame.new(LINE_X + e.sd * (HALL_HALF + 1), PASSAGE_TOP + 0.25, e.hallZ), Color3.fromRGB(214, 214, 210), M.SmoothPlastic)
		else
			-- Along x past the line, then along the line into the hall's north wall.
			local towardHall = { { LINE_X - 10, LINE_X + 10 } }
			local closeA, closeB = false, true -- open at the lobby, closed past the line
			Kit.passage(folder, true, e.xa, e.xb, e.passZ, 10, CONCOURSE, PASSAGE_TOP, station.tile, { minus = {}, plus = towardHall }, closeA, closeB, rng)
			Kit.passage(folder, false, e.passZ + 10, cz0 - 1, LINE_X, 10, CONCOURSE, PASSAGE_TOP, station.tile, {}, false, false, rng)
		end
	end
end

---------------------------------------------------------------------------
-- Elevated terminal
---------------------------------------------------------------------------
local function buildElevatedStation(folder, station)
	local zc = station.z
	local platformTop = ELEVATED + FLOOR_UP
	local L = PORT_HALF * 2 - 2
	local rng = Random.new(math.floor(zc) + 11)
	Util.solid(folder, V3(PLAT_HALF * 2, FLOOR_UP + 1, L), CFrame.new(LINE_X, ELEVATED + (FLOOR_UP - 1) / 2, zc), Color3.fromRGB(176, 174, 168), M.Granite)
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(1, 0.08, L), CFrame.new(LINE_X + side * (PLAT_HALF - 0.5), platformTop + 0.04, zc), Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
		Util.deco(folder, V3(2.6, 0.08, L), CFrame.new(LINE_X + side * (PLAT_HALF - 2.3), platformTop + 0.04, zc), Color3.fromRGB(250, 204, 30), M.Pebble)
	end
	-- Canopy on two rows of columns.
	for k = -3, 3 do
		for _, side in ipairs({ -1, 1 }) do
			Util.solid(folder, V3(1.6, 15, 1.6), CFrame.new(LINE_X + side * 8.5, platformTop + 7.5, zc + k * 28), DARK, M.Metal)
		end
	end
	local canopy = Util.solid(folder, V3(HALF * 2 + 4, 0.8, PORT_HALF * 2), CFrame.new(LINE_X, platformTop + 15.4, zc), Color3.fromRGB(200, 214, 220), M.Glass)
	canopy.Transparency = 0.35
	for k = -2, 2 do
		for _, side in ipairs({ -1, 1 }) do
			local strip = Util.deco(folder, V3(1.2, 0.2, 14), CFrame.new(LINE_X + side * 11, platformTop + 14.8, zc + k * 36), Color3.fromRGB(250, 250, 255), M.Neon)
			if k % 2 == 0 then
				light(strip, Enum.NormalId.Bottom, 16, 1)
			end
		end
	end
	for _, z in ipairs({ zc - 60, zc, zc + 60 }) do
		nameSign(folder, CFrame.new(LINE_X, platformTop + 11, z), V3(16, 2.6, 0.3), station.name, TTC_RED)
		for _, side in ipairs({ -1, 1 }) do
			local p = V3(LINE_X + side * 1.4, platformTop, z + 10)
			Kit.bench(folder, CFrame.lookAt(p, p + V3(side, 0, 0)))
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		Kit.departureBoard(folder, CFrame.new(LINE_X + side * 11, platformTop + 10.5, zc - 20), station.name, side > 0 and "N" or "S", platformTop + 15)
		local ap = V3(LINE_X + side * 8.5 - side * 0.85, platformTop + 6, zc + 28)
		Kit.adPanel(folder, CFrame.lookAt(ap, ap - V3(side, 0, 0)), 1.5, 5.2, rng)
	end
	-- Stairs from the platform's south end down to the street.
	local top = V3(LINE_X, platformTop, zc + PORT_HALF - 1)
	local bottom = V3(LINE_X, Util.WALK_TOP, zc + PORT_HALF + 21)
	stairs(folder, top, bottom, 8)
	for _, side in ipairs({ -1, 1 }) do
		span(folder, top + V3(side * 4.6, -4, 0), bottom + V3(side * 4.6, 0, 0), 0.8, 8, 0, CONCRETE, M.Concrete, true)
	end
	-- The platform end: railings either side of the stairs.
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(PLAT_HALF - 4.4, 4.4, 0.3), CFrame.new(LINE_X + side * (4.4 + (PLAT_HALF - 4.4) / 2), platformTop + 2.2, zc + PORT_HALF - 1.2), Color3.fromRGB(230, 190, 40), M.Metal)
	end
	-- Fare gates at the top of the stairs (the platform is the paid side), with
	-- glass from the gates to the end railings so you can't walk round them.
	local gz = zc + PORT_HALF - 5
	local gEnd = Kit.fareGates(folder, LINE_X - 4.45, gz, platformTop, -1, station.name, { { w = 2.8, entry = true }, { w = 2.8, entry = false } })
	for _, gx in ipairs({ LINE_X - 4.45, gEnd }) do
		local g = Util.solid(folder, V3(0.3, 4.4, 3.8), CFrame.new(gx, platformTop + 2.2, gz + 1.9), Color3.fromRGB(200, 220, 228), M.Glass)
		g.Transparency = 0.5
	end
	Util.solid(folder, V3(PLAT_HALF * 2, 4.4, 0.3), CFrame.new(LINE_X, platformTop + 2.2, zc - PORT_HALF + 1.2), Color3.fromRGB(230, 190, 40), M.Metal)
	local streetSign = nameSign(folder, CFrame.new(LINE_X, Util.WALK_TOP + 9, zc + PORT_HALF + 24) * CFrame.Angles(0, math.rad(180), 0), V3(10, 2.4, 0.3), "SUBWAY", TTC_RED)
	marker(streetSign, "🚇 " .. station.name, TTC_RED)
end

---------------------------------------------------------------------------
-- Vehicles
---------------------------------------------------------------------------
local CAR_LEN, CAR_W = 44, 9 -- streetcars and buses

-- Builds a car model around the origin (floor top at y = 0, forward = -Z).
-- Door panels are named "Door" with attributes Side (+1/-1 = local x side) and
-- Slide (studs along local z to open).
-- kind: "subway", "streetcar" or "bus"; dest is the destination sign text.
local function makeCar(parent, name, kind, dest)
	local model = Instance.new("Model")
	model.Name = name
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	local subway = kind == "subway"
	local bus = kind == "bus"
	local silver = Color3.fromRGB(196, 198, 202)
	local white = Color3.fromRGB(240, 240, 236)
	local body = subway and silver or (bus and white or TTC_RED)
	local upper = subway and silver or white
	local stripe = (subway or bus) and TTC_RED or white
	local h = subway and 9.5 or (bus and 9 or 8.5)
	local half = CAR_LEN / 2
	local function part(size, pos, colour, material, collide)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = CFrame.new(pos)
		p.Color = colour
		p.Material = material or M.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = collide ~= false
		p.Parent = model
		Util.tick()
		return p
	end
	part(V3(CAR_W, 1, CAR_LEN), V3(0, -0.5, 0), Color3.fromRGB(80, 80, 84), M.Rubber)
	part(V3(CAR_W - 0.6, subway and 3 or 1.2, CAR_LEN - 4), V3(0, subway and -2.5 or -1.6, 0), DARK, M.Metal, false)
	part(V3(CAR_W, 0.8, CAR_LEN), V3(0, h + 0.4, 0), upper, M.Metal)
	local lightStrip = part(V3(1.2, 0.2, CAR_LEN - 6), V3(0, h - 0.15, 0), Color3.fromRGB(250, 250, 245), M.Neon, false)
	local lamp = Instance.new("PointLight")
	lamp.Range = 14
	lamp.Brightness = 0.8
	lamp.Parent = lightStrip

	local doorsZ = { -14, 0, 14 }
	local doorW = 5.2
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (CAR_W / 2 - 0.2)
		-- Wall segments between the doors: lower panel, windows, upper band, stripe.
		local edges = { -half }
		for _, dz in ipairs(doorsZ) do
			table.insert(edges, dz - doorW / 2)
			table.insert(edges, dz + doorW / 2)
		end
		table.insert(edges, half)
		for k = 1, #edges, 2 do
			local za, zb = edges[k], edges[k + 1]
			local len = zb - za
			local mid = (za + zb) / 2
			part(V3(0.4, 3.6, len), V3(x, 1.8, mid), body, M.Metal)
			local window = part(V3(0.3, 3.8, len), V3(x, 5.5, mid), Color3.fromRGB(30, 36, 44), M.Glass)
			window.Transparency = 0.35
			part(V3(0.4, h - 7.4, len), V3(x, (7.4 + h) / 2, mid), upper, M.Metal)
			part(V3(0.45, 0.6, len), V3(x, 3.7, mid), stripe, M.SmoothPlastic, false)
		end
		for _, dz in ipairs(doorsZ) do
			part(V3(0.4, h - 8, doorW), V3(x, (8 + h) / 2, dz), upper, M.Metal)
			if subway then
				for _, s in ipairs({ -1, 1 }) do
					local panel = part(V3(0.3, 8, doorW / 2), V3(x, 4, dz + s * doorW / 4), body, M.Metal)
					panel.Name = "Door"
					panel:SetAttribute("Side", side)
					panel:SetAttribute("Slide", s * (doorW / 2 - 0.2))
					local pane = part(V3(0.32, 3, doorW / 2 - 0.8), V3(x, 5.6, dz + s * doorW / 4), Color3.fromRGB(30, 36, 44), M.Glass, false)
					pane.Name = "Door"
					pane:SetAttribute("Side", side)
					pane:SetAttribute("Slide", s * (doorW / 2 - 0.2))
				end
			end
		end
		-- Seats along the wall between the doors.
		for _, mid in ipairs({ -7, 7, -19.5, 19.5 }) do
			local seatLen = (math.abs(mid) > 15) and 4 or 8.5
			part(V3(1.8, 1.6, seatLen), V3(side * (CAR_W / 2 - 1.3), 0.8, mid), Color3.fromRGB(40, 60, 120), M.Fabric)
		end
	end
	-- Ends with cab windows, lights and the destination sign.
	for _, s in ipairs({ -1, 1 }) do
		local z = s * (half - 0.2)
		part(V3(CAR_W, h, 0.4), V3(0, h / 2, z), body, M.Metal)
		local glass = part(V3(CAR_W - 2, 3.4, 0.45), V3(0, 5.6, z), Color3.fromRGB(30, 36, 44), M.Glass, false)
		glass.Transparency = 0.2
		part(V3(1, 0.6, 0.5), V3(-3, 2.2, z), Color3.fromRGB(255, 246, 220), M.Neon, false)
		part(V3(1, 0.6, 0.5), V3(3, 2.2, z), Color3.fromRGB(255, 246, 220), M.Neon, false)
		local destSign = part(V3(5, 1, 0.5), V3(0, h - 1, z), Color3.fromRGB(16, 16, 18), M.SmoothPlastic, false)
		Util.sign(destSign, s < 0 and Front or Enum.NormalId.Back, dest or "1  LINE 1", Color3.fromRGB(255, 200, 60), Enum.Font.Code).LightInfluence = 0
	end
	-- Grab poles.
	for _, z in ipairs({ -7, 7 }) do
		local pole = Instance.new("Part")
		pole.Anchored = true
		pole.Shape = Enum.PartType.Cylinder
		pole.Size = V3(h, 0.3, 0.3)
		pole.CFrame = CFrame.new(0, h / 2, z) * CFrame.Angles(0, 0, math.rad(90))
		pole.Color = Color3.fromRGB(230, 200, 40)
		pole.Material = M.Metal
		pole.Parent = model
	end
	if bus then
		-- Wheels and a roof pod.
		for _, z in ipairs({ -14, 14 }) do
			for _, x in ipairs({ -CAR_W / 2 + 0.6, CAR_W / 2 - 0.6 }) do
				local wheel = Instance.new("Part")
				wheel.Anchored = true
				wheel.CanCollide = false
				wheel.Shape = Enum.PartType.Cylinder
				wheel.Size = V3(1.2, 3, 3)
				wheel.CFrame = CFrame.new(x, -0.3, z)
				wheel.Color = Color3.fromRGB(24, 24, 24)
				wheel.Material = M.Rubber
				wheel.Parent = model
			end
		end
		part(V3(CAR_W - 3, 1.4, 12), V3(0, h + 1.5, 6), white, M.Metal, false)
	end
	if kind == "streetcar" then
		local a = V3(0, h + 0.8, 4)
		local b = V3(0, h + 6.5, -4)
		local arm = Instance.new("Part")
		arm.Anchored = true
		arm.CanCollide = false
		arm.Size = V3(0.3, 0.3, (b - a).Magnitude)
		arm.CFrame = CFrame.lookAt((a + b) / 2, b)
		arm.Color = DARK
		arm.Parent = model
	end
	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	model:PivotTo(CFrame.new(0, PARK_Y, 0))
	model.Parent = parent
	return model
end

---------------------------------------------------------------------------
-- Routes
---------------------------------------------------------------------------
local function encodePoints(points)
	local out = {}
	for _, p in ipairs(points) do
		table.insert(out, { p.X, p.Y, p.Z })
	end
	return out
end

local function lengths(points)
	local s = { 0 }
	for i = 2, #points do
		s[i] = s[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return s
end

---------------------------------------------------------------------------
-- Subway car (TTC style): stainless body with a red stripe, three double doors a
-- side, longitudinal seats, poles and overhead rails, ads above the windows,
-- line maps over the doors, next-stop screens at the ends, and lights at both
-- ends (the client switches headlights/tail lights with the direction).
-- Built around the origin with the floor top at y = 0, facing -Z (north).
---------------------------------------------------------------------------
local SUB_LEN, SUB_W, SUB_H, SUB_GAP = 48, 11.5, 12, 1.5
local SUB_DOORS, SUB_DOOR_W, SUB_DOOR_H = { -16, 0, 16 }, 6.5, 10
local LINE_TEXT = "LINE 1 YONGE  ·  FINCH ◀▶ UNION ◀▶ PORTLANDS"

local function makeSubwayCar(parent, name, rng)
	local model = Instance.new("Model")
	model.Name = name
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	local L, W, H = SUB_LEN, SUB_W, SUB_H
	local half = L / 2
	local silver = Color3.fromRGB(198, 200, 204)
	local glassColour = Color3.fromRGB(30, 36, 44)
	local function part(size, cf, colour, material, collide)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = typeof(cf) == "CFrame" and cf or CFrame.new(cf)
		p.Color = colour
		p.Material = material or M.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = collide ~= false
		p.CastShadow = collide ~= false
		p.Parent = model
		Util.tick()
		return p
	end
	local function cylinder(len, dia, cf, colour)
		local p = part(V3(len, dia, dia), cf, colour, M.Metal, false)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	-- Floor, underframe, bogies, roof.
	part(V3(W, 1, L), V3(0, -0.5, 0), Color3.fromRGB(70, 72, 78), M.Rubber)
	part(V3(W - 0.8, 3.4, L - 6), V3(0, -2.7, 0), DARK, M.Metal, false)
	for _, z in ipairs({ -16, 16 }) do
		part(V3(W - 2.5, 2.4, 9), V3(0, -3.6, z), Color3.fromRGB(28, 28, 30), M.Metal, false)
	end
	part(V3(W, 1, L), V3(0, H + 0.5, 0), silver, M.Metal)
	part(V3(W - 4, 1, 10), V3(0, H + 1.5, 10), Color3.fromRGB(150, 152, 156), M.Metal, false)
	-- Ceiling lights.
	for _, x in ipairs({ -2.6, 2.6 }) do
		local strip = part(V3(1, 0.2, L - 8), V3(x, H - 0.15, 0), Color3.fromRGB(252, 250, 244), M.Neon, false)
		if x < 0 then
			local lamp = Instance.new("PointLight")
			lamp.Range = 18
			lamp.Brightness = 0.9
			lamp.Color = Color3.fromRGB(255, 248, 236)
			lamp.Parent = strip
		end
	end

	-- Sides: wall panels between doors (lower, windows, upper, red stripe),
	-- door leaves, seats, ads and line maps.
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (W / 2 - 0.2)
		local inner = side * (W / 2 - 0.45)
		local edges = { -half }
		for _, dz in ipairs(SUB_DOORS) do
			table.insert(edges, dz - SUB_DOOR_W / 2)
			table.insert(edges, dz + SUB_DOOR_W / 2)
		end
		table.insert(edges, half)
		for k = 1, #edges, 2 do
			local za, zb = edges[k], edges[k + 1]
			local len = zb - za
			local mid = (za + zb) / 2
			part(V3(0.4, 4.6, len), V3(x, 2.3, mid), silver, M.Metal)
			local window = part(V3(0.3, 5, len), V3(x, 7.1, mid), glassColour, M.Glass)
			window.Transparency = 0.35
			part(V3(0.4, H - 9.6, len), V3(x, (9.6 + H) / 2, mid), silver, M.Metal)
			part(V3(0.45, 0.9, len), V3(x + side * 0.02, 4.4, mid), TTC_RED, M.SmoothPlastic, false)
			-- Seats (seat and back) along this stretch of wall.
			local seatLen = len - 0.8
			if seatLen > 2 then
				part(V3(2.2, 2.2, seatLen), V3(side * (W / 2 - 1.5), 1.1, mid), Color3.fromRGB(52, 66, 122), M.Fabric)
				part(V3(0.5, 2.6, seatLen), V3(side * (W / 2 - 0.7), 3.4, mid), Color3.fromRGB(52, 66, 122), M.Fabric)
			end
			-- Ads above the windows in the two long stretches.
			if len > 8 then
				local ad = part(V3(0.1, 1.5, len - 1), CFrame.lookAt(V3(inner, H - 1.6, mid), V3(inner - side, H - 1.6, mid)), Color3.fromRGB(240, 240, 240), M.SmoothPlastic, false)
				Billboards.face(ad, Front, Billboards.pick(rng), false)
				ad.Name = "Ad"
			end
		end
		for _, dz in ipairs(SUB_DOORS) do
			part(V3(0.4, H - SUB_DOOR_H, SUB_DOOR_W), V3(x, (SUB_DOOR_H + H) / 2, dz), silver, M.Metal)
			for _, s in ipairs({ -1, 1 }) do
				local leafZ = dz + s * SUB_DOOR_W / 4
				local leaf = part(V3(0.3, SUB_DOOR_H, SUB_DOOR_W / 2), V3(x, SUB_DOOR_H / 2, leafZ), silver, M.Metal)
				leaf.Name = "Door"
				leaf:SetAttribute("Side", side)
				leaf:SetAttribute("Slide", s * (SUB_DOOR_W / 2 - 0.2))
				local pane = part(V3(0.32, 4.2, SUB_DOOR_W / 2 - 1), V3(x, 7, leafZ), glassColour, M.Glass, false)
				pane.Transparency = 0.3
				pane.Name = "Door"
				pane:SetAttribute("Side", side)
				pane:SetAttribute("Slide", s * (SUB_DOOR_W / 2 - 0.2))
			end
			-- Line map over the door, inside.
			local map = part(V3(0.1, 1, SUB_DOOR_W), CFrame.lookAt(V3(inner, SUB_DOOR_H + 0.7, dz), V3(inner - side, SUB_DOOR_H + 0.7, dz)), Color3.fromRGB(245, 245, 242), M.SmoothPlastic, false)
			Util.sign(map, Front, LINE_TEXT, Color3.fromRGB(30, 30, 34), Enum.Font.GothamBold).LightInfluence = 0.3
		end
	end

	-- Poles: vertical ones at the door areas, overhead rails along the car.
	for _, z in ipairs({ -16, 0, 16 }) do
		cylinder(H, 0.35, CFrame.new(0, H / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(232, 200, 40))
	end
	for _, x in ipairs({ -3, 3 }) do
		cylinder(L - 4, 0.3, CFrame.new(x, H - 1.4, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 200, 206))
	end

	-- Ends: end wall, cab glass, lights (named Head, attribute End), the
	-- destination sign outside (Dest) and the next-stop screen inside (Screen).
	for _, s in ipairs({ -1, 1 }) do
		local z = s * (half - 0.2)
		part(V3(W, H, 0.4), V3(0, H / 2, z), silver, M.Metal)
		local glass = part(V3(W - 3, 4, 0.45), V3(0, 7.2, z), glassColour, M.Glass, false)
		glass.Transparency = 0.25
		for _, hx in ipairs({ -3.6, 3.6 }) do
			local head = part(V3(1.4, 0.8, 0.5), V3(hx, 2.8, z + s * 0.05), Color3.fromRGB(60, 60, 64), M.SmoothPlastic, false)
			head.Name = "Head"
			head:SetAttribute("End", s)
		end
		local beam = part(V3(0.5, 0.5, 0.2), V3(0, 2.8, z + s * 0.3), Color3.new(1, 1, 1), M.SmoothPlastic, false)
		beam.Transparency = 1
		beam.Name = "Beam"
		beam:SetAttribute("End", s)
		local spot = Instance.new("SpotLight")
		spot.Face = s < 0 and Front or Enum.NormalId.Back
		spot.Range = 60
		spot.Angle = 50
		spot.Brightness = 3
		spot.Color = Color3.fromRGB(255, 246, 222)
		spot.Enabled = false
		spot.Parent = beam
		local dest = part(V3(6, 1.2, 0.5), V3(0, H - 1.3, z + s * 0.05), Color3.fromRGB(16, 16, 18), M.SmoothPlastic, false)
		dest.Name = "Dest"
		local dg = Util.sign(dest, s < 0 and Front or Enum.NormalId.Back, "1  LINE 1", Color3.fromRGB(255, 200, 60), Enum.Font.Code)
		dg.LightInfluence = 0
		local screen = part(V3(5, 1.3, 0.1), V3(0, H - 2.2, z - s * 0.3), Color3.fromRGB(10, 10, 12), M.SmoothPlastic, false)
		screen.Name = "Screen"
		local sg = Util.sign(screen, s < 0 and Enum.NormalId.Back or Front, "LINE 1 YONGE", Color3.fromRGB(255, 190, 40), Enum.Font.Code)
		sg.LightInfluence = 0
		-- Rubber gangway filling the gap to the next car.
		if s > 0 then
			part(V3(W - 2, H - 1, SUB_GAP + 0.2), V3(0, (H - 1) / 2, half + SUB_GAP / 2), Color3.fromRGB(26, 26, 28), M.Rubber, false)
		end
	end

	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	model:PivotTo(CFrame.new(0, PARK_Y, 0))
	model.Parent = parent
	return model
end

-- Time to cover d from rest to rest (same profile as the client).
local function hopTime(d, v, a)
	if d <= v * v / a then
		return 2 * math.sqrt(d / a)
	end
	return d / v + v / a
end

-- Line 1 service. Trains always face north; car 1 is the south end.
-- Path 1 (northbound): Portlands on the east track, north through every station,
-- crossing to the west track south of Finch so it arrives at Finch's west side.
-- Path 2 (southbound): from Finch's west track south, crossing to the east track
-- before Portlands. A train runs path 1 then path 2 and so on; at each terminal
-- it reverses in place (path 1 ends where path 2 starts).
local function subwayRoutes(vehicles)
	local railAt = state.railAt
	local settings = Config.Transit
	local north, south = {}, {}
	local z = LINE_END - 4
	while z >= LINE_START + 4 do
		table.insert(north, V3(crossoverX(z, state.finchCross), railAt(z) + FLOOR_UP, z))
		z = z - 6
	end
	z = LINE_START + 4
	while z <= LINE_END - 4 do
		table.insert(south, V3(crossoverX(z, state.portCross), railAt(z) + FLOOR_UP, z))
		z = z + 6
	end
	local function stopsOn(points, order)
		local s = lengths(points)
		local list, names = {}, {}
		for _, station in ipairs(order) do
			-- Interpolate to the station's exact z, so both paths agree on where a
			-- train stands at a terminal (the reversal is seamless).
			local at = s[#s]
			for i = 1, #points - 1 do
				local a, b = points[i], points[i + 1]
				if (station.z - a.Z) * (station.z - b.Z) <= 0 and a.Z ~= b.Z then
					at = s[i] + (s[i + 1] - s[i]) * (station.z - a.Z) / (b.Z - a.Z)
					break
				end
			end
			table.insert(list, at)
			table.insert(names, station.name)
		end
		return list, names
	end
	local reversed = {}
	for i = #STATIONS, 1, -1 do
		table.insert(reversed, STATIONS[i])
	end
	local northStops, northNames = stopsOn(north, reversed)
	local stationList = {}
	for _, st in ipairs(STATIONS) do
		table.insert(stationList, { name = st.name, z = st.z, elevated = st.elevated == true })
	end
	local southStops, southNames = stopsOn(south, STATIONS)

	-- Cycle time, then as many trains as give about the target headway.
	local cycle = 0
	for _, stops in ipairs({ northStops, southStops }) do
		cycle = cycle + settings.TerminalDwell
		for i = 1, #stops - 1 do
			cycle = cycle + hopTime(math.abs(stops[i + 1] - stops[i]), settings.Speed, settings.Accel)
			if i + 1 < #stops then
				cycle = cycle + settings.Dwell
			end
		end
	end
	local count = math.max(1, math.floor(cycle / settings.Headway + 0.5))
	local rng = Random.new(1986)
	local trains = {}
	for t = 1, count do
		local cars = {}
		for c = 1, settings.Cars do
			table.insert(cars, makeSubwayCar(vehicles, string.format("Line1_T%d_Car%d", t, c), rng).Name)
		end
		table.insert(trains, cars)
	end
	print(string.format("[Transit] Line 1: %d trains of %d cars, a train every %.0f s (round trip %.0f s)", count, settings.Cars, cycle / count, cycle))
	return {
		{
			name = "Line1",
			kind = "subway",
			paths = { encodePoints(north), encodePoints(south) },
			signs = { 1, -1 }, -- car order / facing along each path (trains always face north)
			dests = { "FINCH", "PORTLANDS" },
			stops = { northStops, southStops },
			stopNames = { northNames, southNames },
			trains = trains,
			carLength = SUB_LEN,
			carGap = SUB_GAP,
			carWidth = SUB_W,
			carHeight = SUB_H,
			speed = settings.Speed,
			accel = settings.Accel,
			dwell = settings.Dwell,
			terminalDwell = settings.TerminalDwell,
			headway = cycle / count,
			platformX = LINE_X,
			stations = stationList,
		},
	}
end

-- King St: eastbound in one inner lane, westbound in the other, with U-turns.
-- A vehicle loop along a road: out in one lane, U-turn, back in the other lane,
-- U-turn. spec = { name, kind, lane (offset from the centre line), stopEvery,
-- signText, markerText, markerColour, count, speed, accel, dwell, dest, shelters }
local function roadLoopRoute(vehicles, folder, road, spec)
	local lane = spec.lane
	local y = Util.ROAD_TOP + 1.2
	local pts = road.points
	local loop = {}
	local function offsetPoint(i, side)
		local a = pts[math.max(1, i - 1)]
		local b = pts[math.min(#pts, i + 1)]
		local d = (b - a).Unit
		local normal = Vector2.new(-d.Y, d.X)
		local p = pts[i] + normal * side * lane
		return V3(p.X, y, p.Y), d
	end
	for i = 1, #pts do
		table.insert(loop, (offsetPoint(i, 1)))
	end
	local function uturn(i, fromSide)
		local centre = pts[i]
		local _, d = offsetPoint(i, 1)
		local normal = Vector2.new(-d.Y, d.X)
		for k = 1, 7 do
			local a = math.pi * k / 8
			local off = normal * (fromSide * math.cos(a) * lane) + d * (math.sin(a) * lane * (i == #pts and 1 or -1))
			local p = centre + off
			table.insert(loop, V3(p.X, y, p.Y))
		end
	end
	uturn(#pts, 1)
	for i = #pts, 1, -1 do
		table.insert(loop, (offsetPoint(i, -1)))
	end
	uturn(1, -1)
	table.insert(loop, loop[1])

	local s = lengths(loop)
	local total = s[#s]
	local stops = {}
	for d = spec.stopEvery * 0.5, total - 60, spec.stopEvery do
		table.insert(stops, d)
	end
	-- A stop pole (and maybe a shelter) on the kerb next to each stop.
	local labelSpots = {}
	for _, stop in ipairs(stops) do
		for i = 1, #loop - 1 do
			if s[i] <= stop and s[i + 1] >= stop then
				local a, b = loop[i], loop[i + 1]
				local p = a:Lerp(b, (stop - s[i]) / math.max(s[i + 1] - s[i], 1e-3))
				local dir = (b - a).Unit
				local right = V3(-dir.Z, 0, dir.X)
				local kerb = p + right * (road.width / 2 - lane + 2)
				Util.cylinder(folder, 9, 0.3, CFrame.new(kerb.X, Util.WALK_TOP + 4.5, kerb.Z), Color3.fromRGB(220, 220, 220), M.Metal, true)
				local flag = Util.deco(folder, V3(0.15, 1.8, 2.4), CFrame.new(kerb.X, Util.WALK_TOP + 8.2, kerb.Z), TTC_RED, M.SmoothPlastic)
				for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
					Util.sign(flag, face, spec.signText, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
				end
				-- Stops come in pairs (one each direction): one map label per pair.
				local labelled = false
				for _, q in ipairs(labelSpots) do
					if (q - kerb).Magnitude < 90 then
						labelled = true
					end
				end
				if not labelled then
					table.insert(labelSpots, kerb)
					marker(flag, spec.markerText, spec.markerColour, 420)
				end
				if spec.shelters then
					-- Shelter a little further from the kerb, its open side to the road.
					local shelterAt = p + right * (road.width / 2 - lane + road.walk * 0.6)
					if Util.get(shelterAt.X, shelterAt.Z) == Util.WALK then
						local towardRoad = Vector2.new(-right.X, -right.Z)
						local base = Util.groundCF(Vector2.new(shelterAt.X, shelterAt.Z), towardRoad, Util.WALK_TOP)
						Util.deco(folder, V3(10, 0.3, 4), base * CFrame.new(0, 8, 0), Color3.fromRGB(50, 50, 52), M.Metal)
						local back = Util.solid(folder, V3(10, 7.5, 0.2), base * CFrame.new(0, 4, 1.9), Color3.fromRGB(180, 200, 205), M.Glass)
						back.Transparency = 0.6
						Util.solid(folder, V3(7, 0.4, 1.4), base * CFrame.new(0, 2, 1.1), Color3.fromRGB(60, 60, 62), M.Metal)
						for _, x in ipairs({ -4.9, 4.9 }) do
							Util.deco(folder, V3(0.3, 8, 0.3), base * CFrame.new(x, 4, 1.8), Color3.fromRGB(50, 50, 52), M.Metal)
						end
					end
				end
				break
			end
		end
	end
	local cars = {}
	for c = 1, spec.count do
		table.insert(cars, makeCar(vehicles, spec.name .. "_" .. c, spec.kind, spec.dest).Name)
	end
	return {
		name = spec.name,
		kind = spec.kind,
		loop = true,
		points = encodePoints(loop),
		stops = stops,
		cars = cars,
		carLength = CAR_LEN,
		carGap = 0,
		singleCars = true, -- each vehicle runs on its own, spread evenly round the loop
		speed = spec.speed,
		accel = spec.accel,
		dwell = spec.dwell,
		offset = 0,
	}
end

local function findRoad(test)
	for _, road in ipairs(Roads.list) do
		if test(road) then
			return road
		end
	end
	return nil
end

-- King St streetcar and the bus routes.
local function surfaceRoutes(vehicles, folder)
	local routes = {}
	local king = findRoad(function(road)
		return road.name == "King St"
	end)
	if king then
		table.insert(routes, roadLoopRoute(vehicles, folder, king, {
			name = "King504", kind = "streetcar", lane = king.width / 8, stopEvery = 260,
			signText = "TTC 504", markerText = "🚋 504 KING", markerColour = Color3.fromRGB(150, 20, 30),
			count = 2, speed = 34, accel = 6, dwell = 7, dest = "504 KING",
		}))
	end
	-- Buses run in the lane next to the centre line, clear of cars parked at the kerb.
	local bay = findRoad(function(road)
		return road.name == "Bay St"
	end)
	if bay then
		table.insert(routes, roadLoopRoute(vehicles, folder, bay, {
			name = "Bus6", kind = "bus", lane = bay.width / 8, stopEvery = 230,
			signText = "TTC 6 BAY", markerText = "🚌 6 BAY", markerColour = Color3.fromRGB(190, 40, 40),
			count = 3, speed = 40, accel = 7, dwell = 6, dest = "6 BAY", shelters = true,
		}))
	end
	local yonge = findRoad(function(road)
		return road.name == "Yonge St North"
	end)
	if yonge then
		table.insert(routes, roadLoopRoute(vehicles, folder, yonge, {
			name = "Bus97", kind = "bus", lane = yonge.width / 8, stopEvery = 240,
			signText = "TTC 97 YONGE", markerText = "🚌 97 YONGE", markerColour = Color3.fromRGB(190, 40, 40),
			count = 2, speed = 40, accel = 7, dwell = 6, dest = "97 YONGE", shelters = true,
		}))
	end
	local ocean = findRoad(function(road)
		return road.kind == "boulevard"
	end)
	if ocean then
		table.insert(routes, roadLoopRoute(vehicles, folder, ocean, {
			name = "BusBeach", kind = "bus", lane = ocean.width / 4, stopEvery = 220,
			signText = "BEACH SHUTTLE", markerText = "🚌 BEACH", markerColour = Color3.fromRGB(230, 100, 140),
			count = 2, speed = 36, accel = 7, dwell = 6, dest = "C BEACH", shelters = true,
		}))
	end
	return routes
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function Transit.build(folder)
	local line = Instance.new("Folder")
	line.Name = "Line1"
	line.Parent = folder
	buildLine(line)
	for _, station in ipairs(STATIONS) do
		local f = Instance.new("Folder")
		f.Name = station.name
		f.Parent = folder
		if station.elevated then
			buildElevatedStation(f, station)
		else
			buildStation(f, station, state.entrances[station] or {})
		end
	end

	local vehicles = Instance.new("Folder")
	vehicles.Name = "Vehicles"
	vehicles.Parent = folder
	local routes = subwayRoutes(vehicles)
	local stops = Instance.new("Folder")
	stops.Name = "SurfaceStops"
	stops.Parent = folder
	for _, route in ipairs(surfaceRoutes(vehicles, stops)) do
		table.insert(routes, route)
	end
	-- Street entrances (where you step onto the top stair), for the HUD guide.
	local entranceList = {}
	for _, station in ipairs(STATIONS) do
		for _, e in ipairs(state.entrances[station] or {}) do
			table.insert(entranceList, { name = station.name, x = e.spot.X, y = Util.WALK_TOP, z = e.spot.Y - 20 * e.sz })
		end
		if station.elevated then
			table.insert(entranceList, { name = station.name, x = LINE_X, y = Util.WALK_TOP, z = station.z + PORT_HALF + 21 })
		end
	end
	local entranceData = Instance.new("StringValue")
	entranceData.Name = "SubwayEntrances"
	entranceData.Value = HttpService:JSONEncode(entranceList)
	entranceData.Parent = ReplicatedStorage

	-- Service clock: the server decides when Line 1 is delayed. Clients run the
	-- trains on "service time" = server time minus the delay so far, so every train
	-- slows to a stop together, holds, and moves off again (they never bunch up or
	-- overlap), and the boards and announcements all read the same numbers.
	-- Published as JSON: { offset = delay from events already folded in,
	-- events = { { t0, ramp, hold, kind } } }.
	do
		local delays = Config.Transit.Delays
		local clockValue = Instance.new("StringValue")
		clockValue.Name = "TransitClock"
		local clock = { offset = 0, events = {} }
		clockValue.Value = HttpService:JSONEncode(clock)
		clockValue.Parent = ReplicatedStorage
		local rng = Random.new()
		task.spawn(function()
			while true do
				task.wait(delays.CheckEvery)
				local now = Workspace:GetServerTimeNow()
				local keep, active = {}, false
				for _, e in ipairs(clock.events) do
					local finish = e.t0 + 2 * e.ramp + e.hold
					if now > finish + 60 then
						clock.offset = clock.offset + e.ramp + e.hold
					else
						table.insert(keep, e)
						if now < finish then
							active = true
						end
					end
				end
				clock.events = keep
				if not active then
					local roll, acc = rng:NextNumber(), 0
					for _, kind in ipairs(delays.Kinds) do
						acc = acc + kind.Chance
						if roll < acc then
							local length = rng:NextNumber(kind.Min, kind.Max)
							local ramp = delays.Ramp
							table.insert(clock.events, { t0 = now + 4, ramp = ramp, hold = math.max(0, length - ramp), kind = kind.Name })
							print(string.format("[Transit] %s: Line 1 held for %.0f s", kind.Name, length))
							break
						end
					end
				end
				clockValue.Value = HttpService:JSONEncode(clock)
			end
		end)
	end

	local data = Instance.new("StringValue")
	data.Name = "TransitRoutes"
	data.Value = HttpService:JSONEncode(routes)
	data.Parent = ReplicatedStorage

	-- Startup self-check: can a player walk from each street entrance down to the
	-- platform? Prints one line per entrance in Output.
	task.delay(6, function()
		local PathfindingService = game:GetService("PathfindingService")
		for _, station in ipairs(STATIONS) do
			for i, e in ipairs(state.entrances[station] or {}) do
				local from = V3(e.spot.X, Util.WALK_TOP + 3, e.spot.Y - 18.5 * e.sz)
				local to = V3(LINE_X + 3, RAIL + FLOOR_UP + 3, station.z)
				local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
				local ok, err = pcall(function()
					path:ComputeAsync(from, to)
				end)
				local status = ok and path.Status.Name or ("error: " .. tostring(err))
				print(string.format("[Transit] path check %s entrance %d -> platform: %s", station.name, i, status))
			end
		end
	end)

	-- Spaces underground where players are allowed (not "in the water").
	local zones = {}
	for _, h in ipairs(state.holes) do
		table.insert(zones, { min = h.min - V3(2, 2, 2), max = h.max + V3(2, 6, 2) })
	end
	return { safeZones = zones }
end

return Transit
