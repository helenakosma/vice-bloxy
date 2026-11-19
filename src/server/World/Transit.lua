-- Transit: subway Line 1 and the King St streetcar.
--
-- Line 1 runs straight along x = LINE_X from Finch (North York) south through
-- Queen and Union, under the channel, through downtown (Harbour, Central), then
-- climbs out through an open cut onto a viaduct to the elevated Portlands terminal
-- in the industrial district. Underground stations have street entrance buildings, passages to a
-- ticket hall just under the street, and stairs to an island platform between
-- the two tracks (see StationKit).
--
-- The server builds the structure and the vehicle models (parked out of sight) and
-- publishes each route (path, stops, timing) as JSON in ReplicatedStorage. Every
-- client moves the vehicles from the shared server clock, so they are smooth and
-- in the same place for everyone (see client/Transit.client.lua).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(script.Parent.Util)
local Roads = require(script.Parent.Roads)
local Layout = require(script.Parent.Layout)
local Kit = require(script.Parent.StationKit)

local Transit = {}

local V3 = Vector3.new
local M = Enum.Material
local Front = Enum.NormalId.Front

local LINE_X = 100
local RAIL = -30 -- track bed underground
local FLOOR_UP = 4 -- train floor above the track bed (= platform height)
local TRACK = 10 -- track centres at LINE_X +- TRACK
local HALF = 16 -- tunnel and station half-width
local TUNNEL_TOP = 15 -- tunnel ceiling above the track bed
local STATION_TOP = -14 -- station ceiling
local STATION_HALF = 75 -- underground station half-length
local CONCOURSE = -13 -- ticket hall, passages and entrance lobbies: floor
local CONCOURSE_TOP = -1.5 -- ticket hall ceiling
local PASSAGE_TOP = -2.5 -- passage and lobby ceiling
local ELEVATED = 16 -- track bed on the viaduct
local PORT_HALF = 60 -- elevated station half-length
local PARK_Y = -300 -- where vehicle models wait on the server

local STATIONS = {
	{ name = "FINCH", z = -1860, tile = Color3.fromRGB(210, 196, 120) },
	{ name = "QUEEN", z = -1300, tile = Color3.fromRGB(120, 160, 200) },
	{ name = "UNION", z = -980, tile = Color3.fromRGB(200, 120, 90) },
	{ name = "HARBOUR", z = -560, tile = Color3.fromRGB(110, 170, 150) },
	{ name = "CENTRAL", z = 0, tile = Color3.fromRGB(190, 160, 200) },
	{ name = "PORTLANDS", z = 925, elevated = true },
}
local LINE_START = STATIONS[1].z - STATION_HALF - 10
local LINE_END = STATIONS[#STATIONS].z + PORT_HALF + 4

local TTC_RED = Color3.fromRGB(206, 30, 40)
local CONCRETE = Color3.fromRGB(150, 148, 142)
local DARK = Color3.fromRGB(40, 40, 44)

local state = {} -- filled by layout, used by build

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
-- In entrance coordinates the whole thing covers dz -20..31.5, x -17..17.
local ENTRANCE_W, ENTRANCE_D, ENTRANCE_MID = 35, 52, 5.75
local LOBBY_MID = 23.25 -- the passage leaves the lobby here (dz)
local HALL_HALF, HALL_LEN, FARE_AT = 30, 70, 30 -- ticket hall: half-width, length, fare line

-- When the side you walk in from touches a sidewalk across the full width, returns
-- how far out the sidewalk starts; otherwise nil.
local function frontsSidewalk(c, sz)
	local reach = 0
	for _, dx in ipairs({ -12, -4, 4, 12 }) do
		local found = nil
		for d = 21, 31, 2 do
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
	for dx = -16, 16, 2 do
		for d = 19, 31, 2 do
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
	for x = target.X - 300, target.X + 300, 4 do
		if math.abs(x - LINE_X) >= HALL_HALF + 22 then
			for z = target.Y - 280, target.Y + 220, 4 do
				for _, sz in ipairs({ 1, -1 }) do
					local passZ = z + LOBBY_MID * sz
					local passOk = passZ <= cz0 - 12 or (passZ >= cz0 + 9 and passZ <= cz0 + FARE_AT - 9)
					if passOk then
						local c = Vector2.new(x, z)
						local side = x < LINE_X and -1 or 1
						local dist = (c - target).Magnitude
						local current = best[side]
						if not current or dist < current.dist then
							local reach = frontsSidewalk(c, sz)
							local centre = c + Vector2.new(0, ENTRANCE_MID * sz)
							if reach and Util.rectFree(centre, fwd, right, ENTRANCE_W, ENTRANCE_D) then
								best[side] = { c = c, sz = sz, dist = dist, reach = reach }
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
		local north = b and (b.c.Y + LOBBY_MID * b.sz) <= cz0
		if b and b.dist < 360 and not (north and northTaken) then
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
	local southZ = STATIONS[5].z + STATION_HALF
	local northRoadZ = Layout.INDUSTRIAL_NORTH_Z
	local lastUnder = southZ + 40
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
				local inside = passZ > cz0
				-- Entrance: open down to the stairs under the building, roofed beyond.
				local a0, a1 = zr(-16.5, 13)
				hole(V3(spot.X - 17.5, CONCOURSE - 1, a0), V3(spot.X + 17.5, 2, a1))
				local b0, b1 = zr(12.5, 32.5)
				hole(V3(spot.X - 17.5, CONCOURSE - 1, b0), V3(spot.X + 17.5, -1.5, b1))
				-- Passage along x from the lobby wall.
				local xa = spot.X + toward * 17.5
				local xb = inside and (LINE_X - toward * (HALL_HALF + 1)) or (LINE_X + toward * 9)
				hole(V3(math.min(xa, xb), CONCOURSE - 1, passZ - 9), V3(math.max(xa, xb), PASSAGE_TOP + 1, passZ + 9))
				if not inside then
					hole(V3(LINE_X - 9, CONCOURSE - 1, passZ), V3(LINE_X + 9, PASSAGE_TOP + 1, cz0))
				end
				table.insert(list, { spot = spot, sz = sz, reach = e.reach, passZ = passZ, toward = toward, inside = inside, xa = xa, xb = xb })
				print(string.format("[Transit] %s station entrance at x=%.0f, z=%.0f", station.name, spot.X, spot.Y))
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

local function buildLine(folder)
	local railAt = state.railAt
	local step = 20
	local z = LINE_START
	local n = 0
	while z < LINE_END - 0.1 do
		local z2 = math.min(z + step, LINE_END)
		local ya, yb = railAt(z), railAt(z2)
		local a, b = V3(LINE_X, ya, z), V3(LINE_X, yb, z2)
		local midZ = (z + z2) / 2
		local midY = (ya + yb) / 2
		local station = inStation(midZ)
		local elevated = math.min(ya, yb) >= 0
		n = n + 1

		-- Track bed, ballast and rails.
		if elevated then
			span(folder, a, b, HALF * 2 + 2, 1.6, -0.8, CONCRETE, M.Concrete, true)
			for _, side in ipairs({ -1, 1 }) do
				span(folder, a + V3(side * (HALF + 0.4), 0, 0), b + V3(side * (HALF + 0.4), 0, 0), 0.8, 3.6, 1.8, CONCRETE, M.Concrete, true)
			end
			-- Columns every few segments, not on roads.
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
		for _, t in ipairs({ -TRACK, TRACK }) do
			span(folder, a + V3(t, 0, 0), b + V3(t, 0, 0), 4.2, 0.3, 0.15, Color3.fromRGB(70, 64, 58), M.Slate, false)
			for _, r in ipairs({ -2.4, 2.4 }) do
				span(folder, a + V3(t + r, 0, 0), b + V3(t + r, 0, 0), 0.35, 0.4, 0.45, Color3.fromRGB(150, 150, 156), M.Metal, false)
			end
		end

		if not elevated and not station then
			local covered = math.max(ya, yb) + TUNNEL_TOP <= -1
			if covered then
				-- Tunnel: walls, ceiling and wall lights.
				for _, side in ipairs({ -1, 1 }) do
					local w = span(folder, a + V3(side * (HALF + 0.5), 0, 0), b + V3(side * (HALF + 0.5), 0, 0), 1, TUNNEL_TOP, TUNNEL_TOP / 2, CONCRETE, M.Concrete, true)
					if w then
						Util.texture(w, side < 0 and Enum.NormalId.Right or Enum.NormalId.Left, "concrete_stained", 14, 14)
					end
					if n % 2 == 0 then
						local lamp = Util.deco(folder, V3(0.4, 0.6, 1.6), CFrame.new(LINE_X + side * HALF, midY + 10, midZ), Color3.fromRGB(255, 236, 200), M.Neon)
						lamp.CastShadow = false
					end
				end
				span(folder, a, b, HALF * 2 + 2, 1, TUNNEL_TOP + 0.5, CONCRETE, M.Concrete, true)
				-- Centre columns between the tracks.
				if n % 2 == 1 then
					Util.solid(folder, V3(1.4, TUNNEL_TOP, 1.4), CFrame.new(LINE_X, midY + TUNNEL_TOP / 2, midZ), CONCRETE, M.Concrete)
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
		end
	end
	-- End walls of the tunnel.
	Util.solid(folder, V3(HALF * 2 + 2, TUNNEL_TOP + 2, 1), CFrame.new(LINE_X, RAIL + TUNNEL_TOP / 2, LINE_START - 1), CONCRETE, M.Concrete)
end

---------------------------------------------------------------------------
-- Underground stations
---------------------------------------------------------------------------
local function buildStation(folder, station, entrances)
	local zc = station.z
	local platformTop = RAIL + FLOOR_UP
	local z0, z1 = zc - STATION_HALF, zc + STATION_HALF
	local tile = station.tile

	-- Walls with the station's tile colour and its name along them.
	for _, side in ipairs({ -1, 1 }) do
		local wall = Util.solid(folder, V3(1, STATION_TOP - RAIL, STATION_HALF * 2), CFrame.new(LINE_X + side * (HALF + 0.5), (RAIL + STATION_TOP) / 2, zc), tile, M.CeramicTiles)
		wall.Name = "StationWall"
		Util.deco(folder, V3(0.2, 1.2, STATION_HALF * 2), CFrame.new(LINE_X + side * HALF, platformTop + 9.5, zc), Util.shade(tile, 0.6), M.CeramicTiles)
		for k = -2, 2 do
			local face = side < 0 and math.rad(-90) or math.rad(90)
			nameSign(folder, CFrame.new(LINE_X + side * (HALF - 0.1), platformTop + 6, zc + k * 28) * CFrame.Angles(0, face, 0), V3(16, 3, 0.1), station.name, Util.shade(tile, 1.1), Color3.fromRGB(20, 20, 24))
			if k ~= 0 then
				local poster = Util.deco(folder, V3(5, 7, 0.1), CFrame.new(LINE_X + side * (HALF - 0.1), platformTop + 4.5, zc + k * 28 + 12) * CFrame.Angles(0, face, 0), Color3.fromRGB(200, 60, 60), M.SmoothPlastic)
				Util.decal(poster, Front, (k % 2 == 0) and "poster_cola" or "poster_radio")
			end
		end
	end
	-- Ceiling with light strips. Under the ticket hall its floor is the roof; a
	-- lower finish layer hides it, open over the stairs up to the hall.
	local cz0, cz1 = z0, z0 + HALL_LEN
	local stairZ0, stairZ1 = z0 + 40, z0 + 64
	local ceilY = STATION_TOP + 0.5
	Util.solid(folder, V3(HALF * 2 + 2, 1, z1 - cz1), CFrame.new(LINE_X, ceilY, (cz1 + z1) / 2), Color3.fromRGB(230, 230, 226), M.SmoothPlastic)
	local finishY = STATION_TOP - 0.3
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(HALF - 4.5, 0.4, cz1 - z0), CFrame.new(LINE_X + side * (4.5 + (HALF - 4.5) / 2), finishY, (z0 + cz1) / 2), Color3.fromRGB(230, 230, 226), M.SmoothPlastic)
	end
	Util.deco(folder, V3(9, 0.4, stairZ0 - z0), CFrame.new(LINE_X, finishY, (z0 + stairZ0) / 2), Color3.fromRGB(230, 230, 226), M.SmoothPlastic)
	Util.deco(folder, V3(9, 0.4, cz1 - stairZ1), CFrame.new(LINE_X, finishY, (stairZ1 + cz1) / 2), Color3.fromRGB(230, 230, 226), M.SmoothPlastic)
	for k = -3, 3 do
		for _, x in ipairs({ -TRACK, 0, TRACK }) do
			local sz = zc + k * 20
			if not (x == 0 and sz + 7 > stairZ0 - 2 and sz - 7 < stairZ1 + 2) then
				local strip = Util.deco(folder, V3(1.2, 0.2, 14), CFrame.new(LINE_X + x, finishY - 0.3, sz), Color3.fromRGB(250, 250, 255), M.Neon)
				strip.CastShadow = false
				if x == 0 and k % 2 == 0 then
					light(strip, Enum.NormalId.Bottom, 18, 1.1)
				end
			end
		end
	end
	-- Island platform with a yellow edge, columns, benches and signs.
	Util.solid(folder, V3(12, platformTop - RAIL + 1, STATION_HALF * 2 - 4), CFrame.new(LINE_X, (RAIL - 1 + platformTop) / 2, zc), Color3.fromRGB(190, 186, 178), M.Concrete)
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(1.8, 0.06, STATION_HALF * 2 - 4), CFrame.new(LINE_X + side * 5.1, platformTop + 0.03, zc), Color3.fromRGB(250, 210, 30), M.SmoothPlastic)
	end
	for k = -3, 3 do
		local cz = zc + k * 18 + 9
		if cz < stairZ0 - 2 or cz > stairZ1 + 4 then -- keep the stairs clear
			Util.solid(folder, V3(1.6, STATION_TOP - platformTop, 1.6), CFrame.new(LINE_X, (platformTop + STATION_TOP) / 2, zc + k * 18 + 9), Util.shade(tile, 0.85), M.CeramicTiles)
		end
		local bz = zc + k * 18
		if k % 2 == 0 and (bz < stairZ0 - 4 or bz > stairZ1 + 4) then
			Util.solid(folder, V3(1.6, 1.6, 6), CFrame.new(LINE_X + 2.6, platformTop + 0.8, bz), Color3.fromRGB(120, 86, 56), M.Wood)
		end
	end
	for _, z in ipairs({ zc - 6, zc + 34 }) do
		local hang = nameSign(folder, CFrame.new(LINE_X, STATION_TOP - 2.2, z), V3(10, 1.6, 0.2), "▲ FINCH   ·   PORTLANDS ▼", Color3.fromRGB(20, 20, 24), Color3.fromRGB(255, 255, 255))
		Util.sign(hang, Enum.NormalId.Back, "▲ FINCH   ·   PORTLANDS ▼", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack).LightInfluence = 0.2
	end

	-- Ticket hall, passages and street entrances (StationKit).
	local rng = Random.new(math.floor(zc) + 7)
	local gaps = { [-1] = {}, [1] = {} }
	local north = {}
	for _, e in ipairs(entrances) do
		if e.inside then
			table.insert(gaps[-e.toward], { e.passZ - 8, e.passZ + 8 })
		else
			table.insert(north, { LINE_X - 8, LINE_X + 8 })
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
		if e.inside then
			Kit.passage(folder, true, e.xa, e.xb, e.passZ, 8, CONCOURSE, PASSAGE_TOP, station.tile, {}, false, false, rng)
		else
			-- Along x past the line, then along the line into the hall's north wall.
			local towardHall = { { LINE_X - 8, LINE_X + 8 } }
			local closeA, closeB = false, true -- open at the lobby, closed past the line
			Kit.passage(folder, true, e.xa, e.xb, e.passZ, 8, CONCOURSE, PASSAGE_TOP, station.tile, { minus = {}, plus = towardHall }, closeA, closeB, rng)
			Kit.passage(folder, false, e.passZ + 8, cz0 - 1, LINE_X, 8, CONCOURSE, PASSAGE_TOP, station.tile, {}, false, false, rng)
		end
	end
end

---------------------------------------------------------------------------
-- Elevated terminal
---------------------------------------------------------------------------
local function buildElevatedStation(folder, station)
	local zc = station.z
	local platformTop = ELEVATED + FLOOR_UP
	Util.solid(folder, V3(12, FLOOR_UP + 1, PORT_HALF * 2 - 2), CFrame.new(LINE_X, ELEVATED + (FLOOR_UP - 1) / 2, zc), Color3.fromRGB(190, 186, 178), M.Concrete)
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(1.8, 0.06, PORT_HALF * 2 - 2), CFrame.new(LINE_X + side * 5.1, platformTop + 0.03, zc), Color3.fromRGB(250, 210, 30), M.SmoothPlastic)
	end
	-- Canopy on columns.
	for k = -3, 3 do
		Util.solid(folder, V3(1.2, 12, 1.2), CFrame.new(LINE_X, platformTop + 6, zc + k * 16), DARK, M.Metal)
	end
	local canopy = Util.solid(folder, V3(HALF * 2 + 4, 0.8, PORT_HALF * 2), CFrame.new(LINE_X, platformTop + 12.4, zc), Color3.fromRGB(200, 214, 220), M.Glass)
	canopy.Transparency = 0.35
	for k = -2, 2 do
		local strip = Util.deco(folder, V3(1, 0.2, 12), CFrame.new(LINE_X, platformTop + 11.8, zc + k * 22), Color3.fromRGB(250, 250, 255), M.Neon)
		light(strip, Enum.NormalId.Bottom, 16, 1)
	end
	for _, z in ipairs({ zc - 40, zc, zc + 40 }) do
		nameSign(folder, CFrame.new(LINE_X, platformTop + 9, z), V3(12, 2, 0.3), station.name, TTC_RED)
		Util.solid(folder, V3(1.6, 1.6, 6), CFrame.new(LINE_X - 2.6, platformTop + 0.8, z + 8), Color3.fromRGB(120, 86, 56), M.Wood)
	end
	-- Stairs from the platform's south end down to the street.
	local top = V3(LINE_X, platformTop, zc + PORT_HALF - 1)
	local bottom = V3(LINE_X, Util.WALK_TOP, zc + PORT_HALF + 21)
	stairs(folder, top, bottom, 6)
	for _, side in ipairs({ -1, 1 }) do
		span(folder, top + V3(side * 3.6, -4, 0), bottom + V3(side * 3.6, 0, 0), 0.8, 8, 0, CONCRETE, M.Concrete, true)
	end
	local streetSign = nameSign(folder, CFrame.new(LINE_X, Util.WALK_TOP + 9, zc + PORT_HALF + 24) * CFrame.Angles(0, math.rad(180), 0), V3(10, 2.4, 0.3), "SUBWAY", TTC_RED)
	marker(streetSign, "🚇 " .. station.name, TTC_RED)
end

---------------------------------------------------------------------------
-- Vehicles
---------------------------------------------------------------------------
local CAR_LEN, CAR_W, CAR_GAP = 44, 9, 2

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

-- Distance along the path of the point nearest to z (subway paths run along z).
local function sAtZ(points, s, z)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		if (z - a.Z) * (z - b.Z) <= 0 then
			local t = (z - a.Z) / (b.Z - a.Z)
			return s[i] + (s[i + 1] - s[i]) * t
		end
	end
	return s[#s]
end

local function subwayRoutes(vehicles)
	local routes = {}
	local railAt = state.railAt
	for index, track in ipairs({ TRACK, -TRACK }) do
		local points = {}
		local z = LINE_START + 4
		while z <= LINE_END - 4 do
			table.insert(points, V3(LINE_X + track, railAt(z) + FLOOR_UP, z))
			z = z + 8
		end
		local s = lengths(points)
		local stops = {}
		for _, station in ipairs(STATIONS) do
			table.insert(stops, sAtZ(points, s, station.z))
		end
		local cars = {}
		for c = 1, 2 do
			table.insert(cars, makeCar(vehicles, string.format("Line1_%d_Car%d", index, c), "subway").Name)
		end
		table.insert(routes, {
			name = "Line1_" .. index,
			kind = "subway",
			loop = false,
			points = encodePoints(points),
			stops = stops,
			cars = cars,
			carLength = CAR_LEN,
			carGap = CAR_GAP,
			speed = 70,
			accel = 10,
			dwell = 12,
			offset = (index - 1) * 0.5, -- fraction of the cycle
			platformX = LINE_X,
		})
	end
	return routes
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
		return road.kind == "arterial" and math.abs(road.points[1].Y - Layout.NY_CROSS_Z[1]) < 1
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
		return road.kind == "avenue" and math.abs(road.points[1].X - 20) < 40 and math.abs(road.points[1].Y - Util.MIN_Z) < 1
	end)
	if bay then
		table.insert(routes, roadLoopRoute(vehicles, folder, bay, {
			name = "Bus6", kind = "bus", lane = bay.width / 8, stopEvery = 230,
			signText = "TTC 6 BAY", markerText = "🚌 6 BAY", markerColour = Color3.fromRGB(190, 40, 40),
			count = 3, speed = 40, accel = 7, dwell = 6, dest = "6 BAY", shelters = true,
		}))
	end
	local yonge = findRoad(function(road)
		return road.kind == "arterial" and math.abs(road.points[1].X - 20) < 45 and math.abs(road.points[1].Y - (Layout.NORTH_YORK.maxZ - 5)) < 1
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
