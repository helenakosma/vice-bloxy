-- Transit: subway Line 1 and the King St streetcar.
--
-- Line 1 runs straight along x = LINE_X from Finch (North York) south through
-- Queen and Union, under the channel, through downtown (Harbour, Central), then
-- climbs out through an open cut onto a viaduct to the elevated Portlands terminal
-- in the industrial district. Underground stations have a street pavilion, stairs
-- down to a ticket concourse just under the street, and stairs to an island
-- platform between the two tracks.
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
local STATION_TOP = -12 -- station ceiling
local STATION_HALF = 75 -- underground station half-length
local CONCOURSE = -10 -- concourse floor
local CONCOURSE_TOP = -2.5
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
local function findPavilionSpot(station)
	-- A free lot close to the north end of the station (the concourse end).
	local target = Vector2.new(LINE_X, station.z - STATION_HALF + 20)
	local fwd, right = Vector2.new(0, -1), Vector2.new(1, 0)
	local best = nil
	for r = 0, 160, 8 do
		for _, dx in ipairs({ r, -r }) do
			for dz = -r, r, 8 do
				local c = target + Vector2.new(dx, dz)
				if (not best) and Util.rectFree(c, fwd, right, 28, 34) then
					best = c
				end
			end
		end
		if best then
			break
		end
	end
	return best
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

	state.pavilions = {}
	for _, station in ipairs(STATIONS) do
		if not station.elevated then
			local zc = station.z
			hole(V3(LINE_X - HALF - 1, RAIL - 2, zc - STATION_HALF - 1), V3(LINE_X + HALF + 1, STATION_TOP + 1, zc + STATION_HALF + 1))
			-- Concourse over the north end, and the stairwell down to the platform.
			local cz0, cz1 = zc - STATION_HALF, zc - STATION_HALF + 44
			hole(V3(LINE_X - 13, CONCOURSE - 1, cz0), V3(LINE_X + 13, CONCOURSE_TOP + 0.5, cz1))
			hole(V3(LINE_X - 4, RAIL - 2, zc - STATION_HALF + 2), V3(LINE_X + 4, CONCOURSE_TOP + 0.5, zc - STATION_HALF + 22))
			-- Street pavilion, its stair shaft, and the passage to the concourse.
			local spot = findPavilionSpot(station)
			if spot then
				Util.rectMark(spot, Vector2.new(0, -1), Vector2.new(1, 0), 28, 34, Util.BUILT)
				hole(V3(spot.X - 6, CONCOURSE - 1, spot.Y - 15), V3(spot.X + 6, 2, spot.Y + 15))
				local passZ = spot.Y + 12
				local x0, x1 = math.min(spot.X, LINE_X), math.max(spot.X, LINE_X)
				hole(V3(x0 - 5, CONCOURSE - 1, passZ - 5), V3(x1 + 5, CONCOURSE_TOP + 0.5, passZ + 5))
				local z0, z1 = math.min(passZ, cz0 + 20), math.max(passZ, cz0 + 20)
				hole(V3(LINE_X - 5, CONCOURSE - 1, z0 - 5), V3(LINE_X + 5, CONCOURSE_TOP + 0.5, z1 + 5))
				table.insert(state.pavilions, { station = station, spot = spot, passZ = passZ })
			else
				warn("[Transit] no space for a street entrance at " .. station.name)
			end
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
-- A box from a to b (3D centre line), wide x thick, raised by lift.
local function span(folder, a, b, wide, thick, lift, colour, material, solid)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return nil
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, lift, 0)
	local size = V3(wide, thick, length + 0.2)
	if solid then
		return Util.solid(folder, size, cf, colour, material)
	end
	return Util.deco(folder, size, cf, colour, material)
end

-- Straight flight of steps from top (Vector3) to bottom, `width` wide.
local function stairs(folder, top, bottom, width, colour)
	local drop = top.Y - bottom.Y
	local steps = math.max(2, math.ceil(drop / 1.1))
	local flat = Vector3.new(bottom.X - top.X, 0, bottom.Z - top.Z)
	local dir = flat.Unit
	local run = flat.Magnitude / steps
	local rise = drop / steps
	for i = 0, steps - 1 do
		local y = top.Y - rise * (i + 1)
		local pos = Vector3.new(top.X, 0, top.Z) + dir * (run * (i + 0.5))
		Util.solid(folder, V3(width, rise + 0.1, run + 0.05), CFrame.lookAt(V3(pos.X, y + rise / 2, pos.Z), V3(pos.X + dir.X, y + rise / 2, pos.Z + dir.Z)) * CFrame.new(0, -rise / 2 + (rise + 0.1) / 2, 0), colour or CONCRETE, M.Concrete)
	end
	-- Handrails.
	for _, side in ipairs({ -1, 1 }) do
		local right = V3(-dir.Z, 0, dir.X) * side * (width / 2 - 0.2)
		span(folder, top + right + V3(0, 3, 0), bottom + right + V3(0, 3, 0), 0.2, 0.2, 0, DARK, M.Metal, false)
	end
end

local function light(part, face, range, brightness, colour)
	local l = Instance.new("SurfaceLight")
	l.Face = face or Enum.NormalId.Bottom
	l.Range = range or 14
	l.Brightness = brightness or 1
	l.Color = colour or Color3.fromRGB(240, 244, 255)
	l.Angle = 120
	l.Parent = part
	return l
end

local function nameSign(folder, cf, size, text, colour, textColour)
	local plate = Util.deco(folder, size, cf, colour, M.SmoothPlastic)
	local gui = Util.sign(plate, Front, text, textColour or Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
	gui.LightInfluence = 0.2
	return plate
end

-- A wall along x (alongX) or z between a and b at fixed other coordinate, from y0
-- to y1, leaving openings: gaps = list of { from, to } along the wall.
local function wallWithGaps(folder, alongX, from, to, fixed, y0, y1, gaps, colour, material)
	table.sort(gaps, function(a, b)
		return a[1] < b[1]
	end)
	local pieces = {}
	local cursor = from
	for _, g in ipairs(gaps) do
		if g[1] > cursor then
			table.insert(pieces, { cursor, math.min(g[1], to) })
		end
		cursor = math.max(cursor, g[2])
	end
	if cursor < to then
		table.insert(pieces, { cursor, to })
	end
	for _, p in ipairs(pieces) do
		local len = p[2] - p[1]
		if len > 0.3 then
			local mid = (p[1] + p[2]) / 2
			local size = alongX and V3(len, y1 - y0, 1) or V3(1, y1 - y0, len)
			local pos = alongX and V3(mid, (y0 + y1) / 2, fixed) or V3(fixed, (y0 + y1) / 2, mid)
			Util.solid(folder, size, CFrame.new(pos), colour, material)
		end
	end
end

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
local function buildStation(folder, station, pavilion)
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
	-- Ceiling with light strips (opening over the stairs at the north end).
	local stairZ0, stairZ1 = z0 + 2, z0 + 22
	local ceilY = STATION_TOP + 0.5
	Util.solid(folder, V3(HALF * 2 + 2, 1, z1 - stairZ1), CFrame.new(LINE_X, ceilY, (stairZ1 + z1) / 2), Color3.fromRGB(230, 230, 226), M.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(HALF - 4, 1, stairZ1 - z0), CFrame.new(LINE_X + side * (4 + (HALF - 4) / 2 + 0.5), ceilY, (z0 + stairZ1) / 2), Color3.fromRGB(230, 230, 226), M.SmoothPlastic)
	end
	for k = -3, 3 do
		for _, x in ipairs({ -TRACK, 0, TRACK }) do
			local strip = Util.deco(folder, V3(1.2, 0.2, 14), CFrame.new(LINE_X + x, STATION_TOP - 0.15, zc + k * 20), Color3.fromRGB(250, 250, 255), M.Neon)
			strip.CastShadow = false
			if x == 0 and k % 2 == 0 then
				light(strip, Enum.NormalId.Bottom, 18, 1.1)
			end
		end
	end
	-- Island platform with a yellow edge, columns, benches and signs.
	Util.solid(folder, V3(12, platformTop - RAIL + 1, STATION_HALF * 2 - 4), CFrame.new(LINE_X, (RAIL - 1 + platformTop) / 2, zc), Color3.fromRGB(190, 186, 178), M.Concrete)
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(1, 0.05, STATION_HALF * 2 - 4), CFrame.new(LINE_X + side * 5.5, platformTop + 0.03, zc), Color3.fromRGB(250, 210, 30), M.SmoothPlastic)
	end
	for k = -3, 3 do
		Util.solid(folder, V3(1.6, STATION_TOP - platformTop, 1.6), CFrame.new(LINE_X, (platformTop + STATION_TOP) / 2, zc + k * 18 + 9), Util.shade(tile, 0.85), M.CeramicTiles)
		if k % 2 == 0 then
			Util.solid(folder, V3(1.6, 1.6, 6), CFrame.new(LINE_X + 2.6, platformTop + 0.8, zc + k * 18), Color3.fromRGB(120, 86, 56), M.Wood)
		end
	end
	for _, z in ipairs({ zc - 30, zc + 30 }) do
		local hang = nameSign(folder, CFrame.new(LINE_X, STATION_TOP - 2.2, z), V3(10, 1.6, 0.2), "▲ FINCH   ·   PORTLANDS ▼", Color3.fromRGB(20, 20, 24), Color3.fromRGB(255, 255, 255))
		Util.sign(hang, Enum.NormalId.Back, "▲ FINCH   ·   PORTLANDS ▼", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack).LightInfluence = 0.2
	end

	-- Stairs from the concourse down onto the platform's north end.
	stairs(folder, V3(LINE_X, CONCOURSE, stairZ0), V3(LINE_X, platformTop, stairZ1), 6.5)

	-- Concourse: floor (open over the stairs), walls, ceiling, fare gates and a booth.
	local cz0, cz1 = z0, z0 + 44
	local floorY = CONCOURSE - 0.5
	Util.solid(folder, V3(26, 1, cz1 - stairZ1), CFrame.new(LINE_X, floorY, (stairZ1 + cz1) / 2), Color3.fromRGB(210, 206, 198), M.CeramicTiles)
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(9, 1, stairZ1 - cz0), CFrame.new(LINE_X + side * 8.5, floorY, (cz0 + stairZ1) / 2), Color3.fromRGB(210, 206, 198), M.CeramicTiles)
		local glass = Util.solid(folder, V3(0.2, 3.4, stairZ1 - stairZ0), CFrame.new(LINE_X + side * 3.6, CONCOURSE + 1.7, (stairZ0 + stairZ1) / 2), Color3.fromRGB(200, 220, 228), M.Glass)
		glass.Transparency = 0.5
	end
	local ceiling = Util.deco(folder, V3(26, 0.4, 44), CFrame.new(LINE_X, CONCOURSE_TOP - 0.2, (cz0 + cz1) / 2), Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
	light(ceiling, Enum.NormalId.Bottom, 16, 1.2)
	-- Walls, with openings where the passage from the street comes in.
	local sideGaps = { [-1] = {}, [1] = {} }
	local northGaps, southGaps = {}, {}
	if pavilion then
		local passZ = pavilion.passZ
		local fromSide = pavilion.spot.X < LINE_X and -1 or 1
		if passZ > cz0 and passZ < cz1 and math.abs(pavilion.spot.X - LINE_X) > 1 then
			table.insert(sideGaps[fromSide], { passZ - 5, passZ + 5 })
		elseif passZ <= cz0 then
			table.insert(northGaps, { LINE_X - 5, LINE_X + 5 })
		else
			table.insert(southGaps, { LINE_X - 5, LINE_X + 5 })
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		wallWithGaps(folder, false, cz0, cz1, LINE_X + side * 13.5, CONCOURSE, CONCOURSE_TOP, sideGaps[side], tile, M.CeramicTiles)
	end
	wallWithGaps(folder, true, LINE_X - 14, LINE_X + 14, cz0 - 0.5, CONCOURSE, CONCOURSE_TOP, northGaps, tile, M.CeramicTiles)
	wallWithGaps(folder, true, LINE_X - 14, LINE_X + 14, cz1 + 0.5, CONCOURSE, CONCOURSE_TOP, southGaps, tile, M.CeramicTiles)
	for k = -2, 2 do
		local gx = LINE_X + k * 3
		Util.deco(folder, V3(0.8, 3.2, 3), CFrame.new(gx, CONCOURSE + 1.6, cz0 + 30), Color3.fromRGB(180, 180, 186), M.Metal)
		Util.deco(folder, V3(0.5, 0.3, 0.3), CFrame.new(gx, CONCOURSE + 3.3, cz0 + 28.6), Color3.fromRGB(60, 220, 100), M.Neon)
	end
	local booth = Util.solid(folder, V3(6, 7, 5), CFrame.new(LINE_X - 9, CONCOURSE + 3.5, cz0 + 36), Color3.fromRGB(190, 210, 216), M.Glass)
	booth.Transparency = 0.4
	nameSign(folder, CFrame.new(LINE_X, CONCOURSE_TOP - 1.4, cz0 + 32), V3(14, 1.6, 0.2), station.name .. " STATION", TTC_RED)

	-- Passage from the street pavilion, and the pavilion itself.
	if pavilion then
		local spot, passZ = pavilion.spot, pavilion.passZ
		local function corridor(a, b, alongX)
			local length = alongX and math.abs(b.X - a.X) or math.abs(b.Z - a.Z)
			local mid = (a + b) / 2
			if length < 1 then
				return
			end
			local size = alongX and V3(length + 10, 1, 10) or V3(10, 1, length + 10)
			Util.solid(folder, size, CFrame.new(mid.X, CONCOURSE - 0.5, mid.Z), Color3.fromRGB(210, 206, 198), M.CeramicTiles)
			local roof = Util.deco(folder, alongX and V3(length + 10, 0.4, 10) or V3(10, 0.4, length + 10), CFrame.new(mid.X, CONCOURSE_TOP - 0.2, mid.Z), Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
			light(roof, Enum.NormalId.Bottom, 12, 0.9)
			-- Side walls stop short of both ends so the corners stay open.
			local wallLen = length - 11
			if wallLen > 0.5 then
				for _, side in ipairs({ -1, 1 }) do
					local off = alongX and V3(0, 0, side * 5.5) or V3(side * 5.5, 0, 0)
					local wsize = alongX and V3(wallLen, CONCOURSE_TOP - CONCOURSE, 1) or V3(1, CONCOURSE_TOP - CONCOURSE, wallLen)
					Util.solid(folder, wsize, CFrame.new(mid.X + off.X, (CONCOURSE + CONCOURSE_TOP) / 2, mid.Z + off.Z), tile, M.CeramicTiles)
				end
			end
		end
		corridor(V3(spot.X, 0, passZ), V3(LINE_X, 0, passZ), true)
		corridor(V3(LINE_X, 0, passZ), V3(LINE_X, 0, cz0 + 20), false)

		-- Pavilion: glass walls on a stone base, a flat roof with the SUBWAY sign,
		-- and the stair shaft inside going down toward the passage.
		local kerb = Util.WALK_TOP
		Util.solid(folder, V3(28, 1, 4), CFrame.new(spot.X, kerb - 0.5, spot.Y - 16), CONCRETE, M.Concrete)
		for _, side in ipairs({ -1, 1 }) do
			local wall = Util.solid(folder, V3(1, 12, 30), CFrame.new(spot.X + side * 6.5, kerb + 6, spot.Y), Color3.fromRGB(200, 220, 228), M.Glass)
			wall.Transparency = 0.45
			Util.solid(folder, V3(1.2, 12, 1.2), CFrame.new(spot.X + side * 6.5, kerb + 6, spot.Y - 15), DARK, M.Metal)
			-- Walls of the shaft below ground, open toward the passage.
			local towardLine = (LINE_X - spot.X) * side > 0 and math.abs(LINE_X - spot.X) > 1
			local gaps = towardLine and { { passZ - 5, passZ + 5 } } or {}
			wallWithGaps(folder, false, spot.Y - 15, spot.Y + 15, spot.X + side * 6.5, CONCOURSE, kerb, gaps, tile, M.CeramicTiles)
		end
		Util.solid(folder, V3(12, 1, 3), CFrame.new(spot.X, kerb - 0.5, spot.Y - 14), CONCRETE, M.Concrete)
		Util.solid(folder, V3(14, 12, 1), CFrame.new(spot.X, kerb + 6, spot.Y + 15.5), Color3.fromRGB(200, 220, 228), M.Glass).Transparency = 0.45
		local roof = Util.solid(folder, V3(16, 1, 32), CFrame.new(spot.X, kerb + 12.5, spot.Y), DARK, M.Metal)
		light(roof, Enum.NormalId.Bottom, 14, 1)
		local sign = nameSign(folder, CFrame.new(spot.X, kerb + 14.5, spot.Y - 16), V3(14, 2.6, 0.4), "SUBWAY", TTC_RED)
		sign.CastShadow = false
		nameSign(folder, CFrame.new(spot.X, kerb + 10.5, spot.Y - 15.6), V3(10, 1.4, 0.2), station.name, Color3.fromRGB(20, 20, 24))
		stairs(folder, V3(spot.X, kerb, spot.Y - 13), V3(spot.X, CONCOURSE, spot.Y + 2), 11)
		Util.solid(folder, V3(12, 1, 12), CFrame.new(spot.X, CONCOURSE - 0.5, spot.Y + 9), Color3.fromRGB(210, 206, 198), M.CeramicTiles)
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
		Util.deco(folder, V3(1, 0.05, PORT_HALF * 2 - 2), CFrame.new(LINE_X + side * 5.5, platformTop + 0.03, zc), Color3.fromRGB(250, 210, 30), M.SmoothPlastic)
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
	nameSign(folder, CFrame.new(LINE_X, Util.WALK_TOP + 9, zc + PORT_HALF + 24) * CFrame.Angles(0, math.rad(180), 0), V3(10, 2.4, 0.3), "SUBWAY", TTC_RED)
end

---------------------------------------------------------------------------
-- Vehicles
---------------------------------------------------------------------------
local CAR_LEN, CAR_W, CAR_GAP = 44, 9, 2

-- Builds a car model around the origin (floor top at y = 0, forward = -Z).
-- Door panels are named "Door" with attributes Side (+1/-1 = local x side) and
-- Slide (studs along local z to open).
local function makeCar(parent, name, kind)
	local model = Instance.new("Model")
	model.Name = name
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	local subway = kind == "subway"
	local body = subway and Color3.fromRGB(196, 198, 202) or TTC_RED
	local upper = subway and Color3.fromRGB(196, 198, 202) or Color3.fromRGB(236, 236, 230)
	local h = subway and 9.5 or 8.5
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
			part(V3(0.45, 0.6, len), V3(x, 3.7, mid), subway and TTC_RED or Color3.fromRGB(236, 236, 230), M.SmoothPlastic, false)
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
		local dest = part(V3(5, 1, 0.5), V3(0, h - 1, z), Color3.fromRGB(16, 16, 18), M.SmoothPlastic, false)
		Util.sign(dest, s < 0 and Front or Enum.NormalId.Back, subway and "1  LINE 1" or "504 KING", Color3.fromRGB(255, 200, 60), Enum.Font.Code).LightInfluence = 0
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
	if not subway then
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
local function streetcarRoute(vehicles, folder)
	local king = nil
	for _, road in ipairs(Roads.list) do
		if road.kind == "arterial" and math.abs(road.points[1].Y - Layout.NY_CROSS_Z[1]) < 1 then
			king = road
		end
	end
	if not king then
		return nil
	end
	local lane = king.width / 8
	local y = Util.ROAD_TOP + 1.2
	local pts = king.points
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
	-- U-turn at the east end, then back west in the other lane, U-turn at the west end.
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
	for d = 140, total - 60, 260 do
		table.insert(stops, d)
	end
	-- TTC stop poles at the kerb next to each stop.
	for _, stop in ipairs(stops) do
		for i = 1, #loop - 1 do
			if s[i] <= stop and s[i + 1] >= stop then
				local a, b = loop[i], loop[i + 1]
				local p = a:Lerp(b, (stop - s[i]) / math.max(s[i + 1] - s[i], 1e-3))
				local dir = (b - a).Unit
				local right = V3(-dir.Z, 0, dir.X)
				local kerb = p + right * (king.width / 2 - lane + 2)
				Util.cylinder(folder, 9, 0.3, CFrame.new(kerb.X, Util.WALK_TOP + 4.5, kerb.Z), Color3.fromRGB(220, 220, 220), M.Metal, true)
				local flag = Util.deco(folder, V3(0.15, 1.8, 2.4), CFrame.new(kerb.X, Util.WALK_TOP + 8.2, kerb.Z), TTC_RED, M.SmoothPlastic)
				for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
					Util.sign(flag, face, "TTC 504", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
				end
				break
			end
		end
	end
	local cars = {}
	for c = 1, 2 do
		table.insert(cars, makeCar(vehicles, "Streetcar_" .. c, "streetcar").Name)
	end
	return {
		name = "King504",
		kind = "streetcar",
		loop = true,
		points = encodePoints(loop),
		stops = stops,
		cars = cars,
		carLength = CAR_LEN,
		carGap = 0,
		singleCars = true, -- each car runs on its own, half a cycle apart
		speed = 34,
		accel = 6,
		dwell = 7,
		offset = 0,
	}
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function Transit.build(folder)
	local line = Instance.new("Folder")
	line.Name = "Line1"
	line.Parent = folder
	buildLine(line)
	local pavilionFor = {}
	for _, p in ipairs(state.pavilions) do
		pavilionFor[p.station] = p
	end
	for _, station in ipairs(STATIONS) do
		local f = Instance.new("Folder")
		f.Name = station.name
		f.Parent = folder
		if station.elevated then
			buildElevatedStation(f, station)
		else
			buildStation(f, station, pavilionFor[station])
		end
	end

	local vehicles = Instance.new("Folder")
	vehicles.Name = "Vehicles"
	vehicles.Parent = folder
	local routes = subwayRoutes(vehicles)
	local stops = Instance.new("Folder")
	stops.Name = "StreetcarStops"
	stops.Parent = folder
	local king = streetcarRoute(vehicles, stops)
	if king then
		table.insert(routes, king)
	end
	local data = Instance.new("StringValue")
	data.Name = "TransitRoutes"
	data.Value = HttpService:JSONEncode(routes)
	data.Parent = ReplicatedStorage

	-- Spaces underground where players are allowed (not "in the water").
	local zones = {}
	for _, h in ipairs(state.holes) do
		table.insert(zones, { min = h.min - V3(2, 2, 2), max = h.max + V3(2, 6, 2) })
	end
	return { safeZones = zones }
end

return Transit
