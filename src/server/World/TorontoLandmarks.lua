-- Toronto-inspired landmarks for North York: City Hall's two curved towers around
-- the council "saucer" with the square, arches and a 3D TORONTO sign; a Union
-- Station-style colonnade; a museum with an angular crystal; Mississauga's
-- twisting "Marilyn" towers; and a red streetcar line with overhead wires.
-- All names are fictional stand-ins for the real places.
local Util = require(script.Parent.Util)

local TorontoLandmarks = {}

local V3 = Vector3.new
local M = Enum.Material
local Front = Enum.NormalId.Front
local CONCRETE = Color3.fromRGB(196, 194, 188)
local STONE = Color3.fromRGB(214, 204, 182)

---------------------------------------------------------------------------
-- City Hall and the square
---------------------------------------------------------------------------
-- Block letters built from bars on a 5 x 7 grid (x, y, w, h in cells).
local LETTERS = {
	T = { { 0, 6, 5, 1 }, { 2, 0, 1, 6 } },
	O = { { 0, 0, 1, 7 }, { 4, 0, 1, 7 }, { 1, 0, 3, 1 }, { 1, 6, 3, 1 } },
	R = { { 0, 0, 1, 7 }, { 1, 6, 3, 1 }, { 1, 3, 3, 1 }, { 4, 4, 1, 2 } },
	N = { { 0, 0, 1, 7 }, { 4, 0, 1, 7 } },
}
local SIGN_COLOURS = {
	Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 160, 40), Color3.fromRGB(250, 230, 70),
	Color3.fromRGB(80, 220, 120), Color3.fromRGB(60, 190, 255), Color3.fromRGB(150, 100, 255), Color3.fromRGB(255, 90, 200),
}

local function torontoSign(folder, centre, facing)
	local word = "TORONTO"
	local cell = 1.6
	local letterW = 5 * cell + 2
	local total = #word * letterW
	local base = Util.groundCF(centre, facing, Util.WALK_TOP)
	for i = 1, #word do
		local ch = string.sub(word, i, i)
		local colour = SIGN_COLOURS[(i - 1) % #SIGN_COLOURS + 1]
		local ox = -total / 2 + (i - 1) * letterW + 1
		for _, bar in ipairs(LETTERS[ch]) do
			local x = ox + (bar[1] + bar[3] / 2) * cell
			local y = (bar[2] + bar[4] / 2) * cell
			-- Letters face the viewer: mirror x because the base faces the square.
			Util.solid(folder, V3(bar[3] * cell, bar[4] * cell, 1.6), base * CFrame.new(-x, y, 0), colour, M.Neon)
		end
		if ch == "R" then
			local a = (base * CFrame.new(-(ox + 2 * cell), 3 * cell, 0)).Position
			local b = (base * CFrame.new(-(ox + 4.6 * cell), 0.3, 0)).Position
			Util.beam(folder, a, b, cell, colour, M.Neon)
		elseif ch == "N" then
			local a = (base * CFrame.new(-(ox + 1 * cell), 6.6 * cell, 0)).Position
			local b = (base * CFrame.new(-(ox + 4 * cell), 0.4 * cell, 0)).Position
			Util.beam(folder, a, b, cell, colour, M.Neon)
		end
	end
	Util.solid(folder, V3(total + 2, 0.6, 3), base * CFrame.new(0, -0.1, 0), Color3.fromRGB(60, 60, 64), M.Concrete)
end

local function flag(folder, pos)
	Util.cylinder(folder, 22, 0.4, CFrame.new(pos.X, Util.WALK_TOP + 11, pos.Y), Color3.fromRGB(220, 220, 220), M.Metal, true)
	local top = Util.WALK_TOP + 20
	local red = Color3.fromRGB(210, 30, 36)
	Util.deco(folder, V3(0.1, 4, 2), CFrame.new(pos.X + 0.2, top, pos.Y + 1.2), red, M.Fabric)
	Util.deco(folder, V3(0.1, 4, 4), CFrame.new(pos.X + 0.2, top, pos.Y + 4.2), Color3.fromRGB(245, 245, 245), M.Fabric)
	Util.deco(folder, V3(0.1, 4, 2), CFrame.new(pos.X + 0.2, top, pos.Y + 7.2), red, M.Fabric)
	Util.deco(folder, V3(0.12, 1.6, 1.6), CFrame.new(pos.X + 0.2, top, pos.Y + 4.2) * CFrame.Angles(math.rad(45), 0, 0), red, M.Fabric)
end

function TorontoLandmarks.cityHall(folder, rect)
	local cx = (rect.minX + rect.maxX) / 2
	local splitZ = rect.minZ + (rect.maxZ - rect.minZ) * 0.52 -- towers north, square south
	local hallZ = (rect.minZ + splitZ) / 2

	-- Podium.
	local podiumW = (rect.maxX - rect.minX) * 0.8
	Util.solid(folder, V3(podiumW, 10, splitZ - rect.minZ - 16), CFrame.new(cx, 5, hallZ), CONCRETE, M.Concrete)
	local band = Util.deco(folder, V3(podiumW + 0.3, 3.5, splitZ - rect.minZ - 15.7), CFrame.new(cx, 6, hallZ), Color3.fromRGB(40, 48, 56), M.Glass)
	band.Reflectance = 0.25
	Util.nightWindow(band, 1)

	-- The two curved towers: arcs of slabs with concrete backs and glass fronts
	-- facing each other across the saucer.
	for _, info in ipairs({ { 1, 116 }, { -1, 90 } }) do
		local side, height = info[1], info[2]
		local arcCentre = V3(cx - side * 26, 0, hallZ)
		local radius = 70
		local slabs = 9
		for k = 0, slabs - 1 do
			local a = math.rad(-58 + 116 * (k + 0.5) / slabs)
			local dir = V3(math.cos(a) * side, 0, math.sin(a))
			local pos = arcCentre + dir * radius
			local width = 2 * radius * math.sin(math.rad(116 / slabs / 2)) + 0.6
			local cf = CFrame.lookAt(V3(pos.X, height / 2, pos.Z), V3(arcCentre.X, height / 2, arcCentre.Z))
			local body = Util.solid(folder, V3(width, height, 12), cf, CONCRETE, M.Concrete)
			Util.texture(body, Enum.NormalId.Back, "concrete_stained", 14, 14)
			local glass = Util.deco(folder, V3(width - 0.2, height - 6, 0.3), cf * CFrame.new(0, -2, -6.1), Color3.fromRGB(70, 90, 104), M.Glass)
			glass.Reflectance = 0.35
			Util.nightWindow(glass, 0.5)
			-- Vertical ribs on the curved back.
			Util.deco(folder, V3(0.8, height, 1), cf * CFrame.new(width / 2 - 0.4, 0, 6.3), Util.shade(CONCRETE, 0.85), M.Concrete)
		end
	end

	-- The council chamber "saucer" on its column.
	local saucer = CFrame.new(cx, 0, hallZ)
	Util.cylinder(folder, 12, 10, saucer * CFrame.new(0, 16, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 4, 46, saucer * CFrame.new(0, 22, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 3, 54, saucer * CFrame.new(0, 25, 0), Color3.fromRGB(226, 224, 218), M.Concrete, true)
	Util.cylinder(folder, 3, 40, saucer * CFrame.new(0, 28, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 2, 22, saucer * CFrame.new(0, 30.5, 0), Color3.fromRGB(226, 224, 218), M.Concrete, true)
	Util.cylinder(folder, 0.5, 54.4, saucer * CFrame.new(0, 23.8, 0), Color3.fromRGB(255, 226, 170), M.Neon, false)

	-- The square: paving, reflecting pool, three arches and the TORONTO sign.
	local squareZ = (splitZ + rect.maxZ) / 2
	local squareD = rect.maxZ - splitZ
	local squareW = rect.maxX - rect.minX
	Util.solid(folder, V3(squareW, 1, squareD), CFrame.new(cx, Util.WALK_TOP - 0.5, squareZ), Color3.fromRGB(176, 170, 160), M.Pavement)
	local poolW, poolD = 74, 26
	local poolZ = squareZ + 4
	Util.solid(folder, V3(poolW + 2, 1.2, poolD + 2), CFrame.new(cx, Util.WALK_TOP + 0.1, poolZ), Color3.fromRGB(150, 150, 146), M.Concrete)
	local water = Util.deco(folder, V3(poolW, 0.3, poolD), CFrame.new(cx, Util.WALK_TOP + 0.6, poolZ), Color3.fromRGB(70, 110, 130), M.Glass)
	water.Reflectance = 0.45
	for i = -1, 1 do
		local ax = cx + i * 24
		local r = 12
		local prev = nil
		for s = 0, 10 do
			local t = math.pi * s / 10
			local p = V3(ax, Util.WALK_TOP + math.sin(t) * r * 1.4, poolZ - math.cos(t) * r)
			if prev then
				Util.beam(folder, prev, p, 1.6, Color3.fromRGB(226, 224, 218), M.Concrete)
			end
			prev = p
		end
	end
	torontoSign(folder, Vector2.new(cx, poolZ - poolD / 2 - 8), Vector2.new(0, 1))
	for _, x in ipairs({ rect.minX + 12, rect.maxX - 12 }) do
		flag(folder, Vector2.new(x, rect.maxZ - 10))
	end
end

---------------------------------------------------------------------------
-- Union Station
---------------------------------------------------------------------------
function TorontoLandmarks.union(folder, centre)
	local w, d, h = 100, 42, 26
	local base = Util.groundCF(centre, Vector2.new(0, 1), 0) -- faces the lakeshore (south)
	local body = Util.solid(folder, V3(w, h, d), base * CFrame.new(0, h / 2, 6), STONE, M.Limestone)
	Util.texture(body, Front, "limestone", 12, 12)
	-- Recessed portico with a row of tall columns.
	local colH = 18
	Util.deco(folder, V3(w - 20, colH, 0.4), base * CFrame.new(0, Util.WALK_TOP + colH / 2, -15.2), Color3.fromRGB(70, 66, 60), M.Slate)
	for k = 0, 11 do
		local x = -w / 2 + 12 + k * (w - 24) / 11
		Util.cylinder(folder, colH, 2.6, base * CFrame.new(x, Util.WALK_TOP + colH / 2, -18), STONE, M.Limestone, true)
	end
	Util.solid(folder, V3(w - 16, 3, 10), base * CFrame.new(0, Util.WALK_TOP + colH + 1.5, -17), STONE, M.Limestone)
	Util.solid(folder, V3(w - 20, 5, 2), base * CFrame.new(0, Util.WALK_TOP + colH + 5.5, -21), STONE, M.Limestone)
	local name = Util.deco(folder, V3(w * 0.5, 3, 0.2), base * CFrame.new(0, Util.WALK_TOP + colH + 5.5, -22.1), STONE, M.Limestone)
	Util.sign(name, Front, "UNION STATION", Color3.fromRGB(60, 54, 46), Enum.Font.Merriweather)
	Util.solid(folder, V3(w + 2, 3, d + 2), base * CFrame.new(0, h + 1.5, 6), Util.shade(STONE, 0.9), M.Limestone)
	-- Windows between the columns' backdrop and big lit doors.
	for k = -2, 2 do
		local door = Util.deco(folder, V3(4, 9, 0.2), base * CFrame.new(k * 12, Util.WALK_TOP + 4.5, -15.4), Color3.fromRGB(255, 214, 160), M.Glass)
		Util.nightWindow(door, 1)
	end
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(14, h + 6, d + 4), base * CFrame.new(side * (w / 2 - 7), (h + 6) / 2, 6), STONE, M.Limestone)
	end
end

---------------------------------------------------------------------------
-- Museum with a crystal
---------------------------------------------------------------------------
function TorontoLandmarks.museum(folder, centre)
	local base = Util.groundCF(centre, Vector2.new(1, 0), 0) -- faces east toward the street
	local brick = Color3.fromRGB(150, 104, 76)
	local body = Util.solid(folder, V3(80, 26, 44), base * CFrame.new(0, 13, 6), brick, M.Brick)
	Util.texture(body, Front, "brick_brown", 5, 5)
	-- Arched windows: tall glass with stone heads.
	for k = -3, 3 do
		Util.deco(folder, V3(4, 9, 0.3), base * CFrame.new(k * 10, 14, -16.1), Color3.fromRGB(50, 56, 60), M.Glass)
		Util.cylinder(folder, 0.6, 4.4, base * CFrame.new(k * 10, 18.5, -16.2) * CFrame.Angles(0, math.rad(90), 0), STONE, M.Limestone, false)
	end
	Util.solid(folder, V3(82, 2, 46), base * CFrame.new(0, 27, 6), STONE, M.Limestone)
	-- The crystal: aluminium-clad shards bursting out at angles, with glass slits.
	local shards = {
		{ V3(0, 22, -26), V3(30, 34, 22), { 18, -10, 8 } },
		{ V3(-16, 30, -20), V3(20, 40, 16), { -14, 20, -6 } },
		{ V3(16, 26, -22), V3(22, 30, 18), { 10, -28, 16 } },
		{ V3(4, 44, -14), V3(16, 26, 12), { -24, 6, -12 } },
	}
	for _, s in ipairs(shards) do
		local cf = base * CFrame.new(s[1]) * CFrame.Angles(math.rad(s[3][1]), math.rad(s[3][2]), math.rad(s[3][3]))
		local shard = Util.solid(folder, s[2], cf, Color3.fromRGB(196, 200, 206), M.Foil)
		shard.Reflectance = 0.25
		local slit = Util.deco(folder, V3(s[2].X * 0.12, s[2].Y * 0.8, s[2].Z + 0.2), cf * CFrame.new(s[2].X * 0.2, 0, 0), Color3.fromRGB(40, 50, 60), M.Glass)
		Util.nightWindow(slit, 1)
	end
	local sign = Util.deco(folder, V3(30, 3, 0.2), base * CFrame.new(0, 7, -16.2), Color3.fromRGB(30, 30, 30), M.SmoothPlastic)
	Util.sign(sign, Front, "ROYAL MUSEUM", Color3.fromRGB(240, 236, 220), Enum.Font.Merriweather)
end

---------------------------------------------------------------------------
-- Twisting towers (Mississauga's "Marilyn" pair)
---------------------------------------------------------------------------
local function roundedSlab(folder, cf, length, width, thickness, colour, material, solid)
	local core = length - width
	local make = solid and Util.solid or Util.deco
	local mid = make(folder, V3(core, thickness, width), cf, colour, material)
	for _, side in ipairs({ -1, 1 }) do
		Util.cylinder(folder, thickness, width, cf * CFrame.new(side * core / 2, 0, 0), colour, material, solid)
	end
	return mid
end

function TorontoLandmarks.twistingTower(folder, centre, floors, phase)
	local floorH = 5
	local twist = 0
	for f = 0, floors - 1 do
		local t = f / floors
		-- The twist speeds up and slows down along the height, and the waist narrows.
		twist = twist + math.rad(4 + 4 * math.sin(t * math.pi * 2 + phase))
		local squeeze = 1 - 0.12 * math.sin(t * math.pi)
		local length, width = 36 * squeeze, 22 * squeeze
		local y = 1 + f * floorH
		local cf = CFrame.new(centre.X, y, centre.Y) * CFrame.Angles(0, twist + phase, 0)
		roundedSlab(folder, cf, length + 3, width + 3, 0.7, Color3.fromRGB(244, 244, 240), M.SmoothPlastic, true)
		local glass = Util.solid(folder, V3(length - width, floorH - 0.7, width - 1), cf * CFrame.new(0, floorH / 2, 0), Color3.fromRGB(110, 140, 156), M.Glass)
		glass.Reflectance = 0.35
		Util.nightWindow(glass, 0.35)
	end
	Util.deco(folder, V3(10, 6, 8), CFrame.new(centre.X, 1 + floors * floorH + 3, centre.Y), Color3.fromRGB(200, 200, 200), M.Metal)
end

---------------------------------------------------------------------------
-- Streetcar line
---------------------------------------------------------------------------
local RED = Color3.fromRGB(200, 30, 36)

local function streetcar(folder, pos, dir)
	local base = Util.groundCF(pos, dir, Util.ROAD_TOP)
	Util.solid(folder, V3(8, 4.5, 44), base * CFrame.new(0, 3, 0), RED, M.SmoothPlastic)
	Util.solid(folder, V3(8, 4, 44), base * CFrame.new(0, 7.2, 0), Color3.fromRGB(236, 236, 230), M.SmoothPlastic)
	local windows = Util.deco(folder, V3(8.1, 2.6, 40), base * CFrame.new(0, 7.4, 0), Color3.fromRGB(34, 40, 48), M.Glass)
	windows.Reflectance = 0.3
	Util.nightWindow(windows, 1)
	Util.deco(folder, V3(7.6, 0.6, 43), base * CFrame.new(0, 9.5, 0), Color3.fromRGB(80, 80, 80), M.Metal)
	Util.deco(folder, V3(3, 1, 6), base * CFrame.new(0, 10.3, 2), Color3.fromRGB(60, 60, 60), M.Metal)
	local a = (base * CFrame.new(0, 10.8, 2)).Position
	local b = (base * CFrame.new(0, 16.2, -6)).Position
	Util.beam(folder, a, b, 0.25, Color3.fromRGB(30, 30, 30), M.Metal)
	for _, z in ipairs({ -22.1, 22.1 }) do
		local front = Util.deco(folder, V3(5, 1, 0.2), base * CFrame.new(0, 9.1, z), Color3.fromRGB(20, 20, 20), M.SmoothPlastic)
		Util.sign(front, z < 0 and Front or Enum.NormalId.Back, "504 KING", Color3.fromRGB(255, 200, 60), Enum.Font.Code).LightInfluence = 0
		Util.deco(folder, V3(1, 0.6, 0.2), base * CFrame.new(-2.8, 3.4, z), Color3.fromRGB(255, 246, 220), M.Neon)
		Util.deco(folder, V3(1, 0.6, 0.2), base * CFrame.new(2.8, 3.4, z), Color3.fromRGB(255, 246, 220), M.Neon)
	end
end

-- Tracks, overhead wires and a few streetcars along a road (in its inner lanes).
function TorontoLandmarks.streetcarLine(folder, road, rng)
	local laneOffset = road.width / 8
	local steel = Color3.fromRGB(140, 140, 146)
	local placed = 0
	for i = 1, #road.points - 1 do
		local a, b = road.points[i], road.points[i + 1]
		local delta = b - a
		local length = delta.Magnitude
		if length > 1 then
			local dir = delta.Unit
			local normal = Vector2.new(-dir.Y, dir.X)
			local mid = (a + b) / 2
			for _, lane in ipairs({ -1, 1 }) do
				local centre = mid + normal * lane * laneOffset
				for _, rail in ipairs({ -2.4, 2.4 }) do
					Util.deco(folder, V3(0.35, 0.1, length + 2), Util.groundCF(centre + normal * rail, dir, Util.ROAD_TOP + 0.05), steel, M.Metal)
				end
				Util.deco(folder, V3(0.12, 0.12, length + 2), Util.groundCF(centre, dir, 17), Color3.fromRGB(20, 20, 20), M.Metal)
			end
			-- Span-wire poles at the kerbs.
			for _, side in ipairs({ -1, 1 }) do
				local pole = mid + normal * side * (road.width / 2 + 1.2)
				if Util.get(pole.X, pole.Y) == Util.WALK then
					Util.cylinder(folder, 19, 0.6, CFrame.new(pole.X, Util.WALK_TOP + 9.5, pole.Y), Color3.fromRGB(50, 52, 50), M.Metal, true)
				end
			end
			local span1 = mid - normal * (road.width / 2 + 1.2)
			local span2 = mid + normal * (road.width / 2 + 1.2)
			Util.beam(folder, V3(span1.X, 17.6, span1.Y), V3(span2.X, 17.6, span2.Y), 0.12, Color3.fromRGB(20, 20, 20), M.Metal)
			-- Streetcars on some segments, away from intersections.
			if placed < 4 and length > 70 and rng:NextNumber() < 0.35 then
				local lane = rng:NextNumber() < 0.5 and -1 or 1
				local p = mid + normal * lane * laneOffset
				if not Util.isJunction(p.X, p.Y) then
					streetcar(folder, p, lane == 1 and dir or -dir)
					placed = placed + 1
				end
			end
		end
	end
end

return TorontoLandmarks
