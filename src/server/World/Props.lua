-- Street furniture and landmarks: streetlights, traffic signals, trees, hydrants,
-- subway entrances, steam stacks, the park, the river and parked cars.
local Util = require(script.Parent.Util)
local Roads = require(script.Parent.Roads)

local Props = {}

local V3 = Vector3.new
local M = Enum.Material
local POLE = Color3.fromRGB(58, 64, 60)
local LAMP_COLOR = Color3.fromRGB(255, 196, 128)

local function onSidewalk(p)
	return Util.get(p.X, p.Y) == Util.WALK
end

local function to3(p, y)
	return V3(p.X, y, p.Y)
end

---------------------------------------------------------------------------
-- Streetlights
---------------------------------------------------------------------------
local lightCount = 0
local function streetlight(folder, p, towardRoad)
	local base = Util.groundCF(p, towardRoad, 0.25)
	Util.cylinder(folder, 17, 0.6, base * CFrame.new(0, 8.5, 0), POLE, M.Metal, true)
	Util.deco(folder, V3(0.35, 0.35, 5), base * CFrame.new(0, 16.6, -2.5), POLE, M.Metal)
	local head = Util.deco(folder, V3(1.4, 0.5, 2.4), base * CFrame.new(0, 16.4, -5), POLE, M.Metal)
	Util.deco(folder, V3(1.1, 0.12, 1.9), base * CFrame.new(0, 16.1, -5), LAMP_COLOR, M.Neon)
	lightCount = lightCount + 1
	if lightCount % 2 == 0 then
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 40
		light.Angle = 110
		light.Brightness = 1.6
		light.Color = LAMP_COLOR
		light.Parent = head
	end
end

local function tree(folder, p, rng, scale)
	scale = scale or 1
	local h = rng:NextNumber(8, 12) * scale
	Util.cylinder(folder, h, 0.9 * scale, CFrame.new(p.X, 0.25 + h / 2, p.Y), Color3.fromRGB(70, 56, 44), M.Wood, true)
	local leaf = Color3.fromRGB(rng:NextInteger(62, 84), rng:NextInteger(86, 104), rng:NextInteger(46, 58))
	local s1 = rng:NextNumber(7, 9) * scale
	local canopy = Util.deco(folder, V3(s1, s1, s1), CFrame.new(p.X, h + s1 * 0.25, p.Y), leaf, M.LeafyGrass, Enum.PartType.Ball)
	canopy.CastShadow = true
	local s2 = s1 * 0.75
	Util.deco(folder, V3(s2, s2, s2), CFrame.new(p.X + rng:NextNumber(-2, 2), h + s1 * 0.55, p.Y + rng:NextNumber(-2, 2)), Util.shade(leaf, 1.1), M.LeafyGrass, Enum.PartType.Ball)
end

local function hydrant(folder, p)
	Util.cylinder(folder, 2.4, 1, CFrame.new(p.X, 1.45, p.Y), Color3.fromRGB(170, 40, 30), M.Metal, true)
	Util.deco(folder, V3(1.6, 0.4, 0.4), CFrame.new(p.X, 2, p.Y), Color3.fromRGB(170, 40, 30), M.Metal)
end

local function trashCan(folder, p)
	Util.cylinder(folder, 3, 1.8, CFrame.new(p.X, 1.75, p.Y), Color3.fromRGB(44, 70, 50), M.DiamondPlate, true)
end

local function newsBox(folder, p, dir, rng)
	local colors = { Color3.fromRGB(30, 60, 140), Color3.fromRGB(180, 40, 40), Color3.fromRGB(220, 200, 40) }
	Util.solid(folder, V3(2, 3.6, 1.8), Util.groundCF(p, dir, 0.25) * CFrame.new(0, 1.8, 0), Util.pick(rng, colors), M.Metal)
end

local function subwayEntrance(folder, p, dir)
	local cf = Util.groundCF(p, dir, 0.25)
	Util.deco(folder, V3(5, 0.3, 9), cf * CFrame.new(0, 0.02, 0), Color3.fromRGB(20, 20, 20), M.Concrete)
	for _, x in ipairs({ -2.7, 2.7 }) do
		Util.solid(folder, V3(0.3, 3.2, 9), cf * CFrame.new(x, 1.6, 0), Color3.fromRGB(40, 70, 50), M.Metal)
		Util.deco(folder, V3(1.1, 1.1, 1.1), cf * CFrame.new(x, 4, -4.3), Color3.fromRGB(70, 220, 110), M.Neon, Enum.PartType.Ball)
	end
	Util.solid(folder, V3(5.6, 3.2, 0.3), cf * CFrame.new(0, 1.6, 4.5), Color3.fromRGB(40, 70, 50), M.Metal)
	local sign = Util.deco(folder, V3(4.6, 1, 0.2), cf * CFrame.new(0, 3.6, -4.5), Color3.fromRGB(20, 20, 20), M.SmoothPlastic)
	Util.sign(sign, Enum.NormalId.Front, "SUBWAY", Color3.fromRGB(255, 255, 255), Enum.Font.Gotham)
end

local function steamStack(folder, p)
	Util.cylinder(folder, 5, 1.6, CFrame.new(p.X, 2.8, p.Y), Color3.fromRGB(230, 110, 30), M.SmoothPlastic, true)
	for i = 0, 1 do
		Util.cylinder(folder, 0.6, 1.65, CFrame.new(p.X, 1.6 + i * 2, p.Y), Color3.fromRGB(240, 240, 240), M.SmoothPlastic, false)
	end
	local emitterPart = Util.deco(folder, V3(1, 0.2, 1), CFrame.new(p.X, 5.4, p.Y), Color3.new(1, 1, 1), M.SmoothPlastic)
	emitterPart.Transparency = 1
	local steam = Instance.new("ParticleEmitter")
	steam.Rate = 14
	steam.Lifetime = NumberRange.new(2, 3.5)
	steam.Speed = NumberRange.new(5, 8)
	steam.SpreadAngle = Vector2.new(12, 12)
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 9) })
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	steam.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	steam.LightInfluence = 1
	steam.Parent = emitterPart
end

local function busStop(folder, p, dir)
	local cf = Util.groundCF(p, dir, 0.25)
	Util.deco(folder, V3(10, 0.3, 4), cf * CFrame.new(0, 8, 0), Color3.fromRGB(50, 50, 52), M.Metal)
	local back = Util.solid(folder, V3(10, 7.5, 0.2), cf * CFrame.new(0, 4, 1.9), Color3.fromRGB(180, 200, 205), M.Glass)
	back.Transparency = 0.6
	local ad = Util.deco(folder, V3(0.2, 6, 3.6), cf * CFrame.new(4.9, 4, 0), Color3.fromRGB(240, 230, 210), M.Neon)
	ad.Transparency = 0.3
	Util.solid(folder, V3(7, 0.4, 1.4), cf * CFrame.new(0, 2, 1.1), Color3.fromRGB(60, 60, 62), M.Metal)
end

---------------------------------------------------------------------------
-- Traffic signals (cycled by a single loop).
---------------------------------------------------------------------------
local signals = {} -- { red, yellow, green }
local SIGNAL_COLORS = {
	red = Color3.fromRGB(255, 40, 30),
	yellow = Color3.fromRGB(255, 180, 20),
	green = Color3.fromRGB(40, 255, 110),
}

local function trafficSignal(folder, pole, armDir, armLength, faceDir)
	Util.cylinder(folder, 19, 0.8, CFrame.new(pole.X, 0.25 + 9.5, pole.Y), Color3.fromRGB(30, 30, 30), M.Metal, true)
	local armMid = pole + armDir * (armLength / 2)
	Util.deco(folder, V3(0.5, 0.5, armLength), Util.groundCF(armMid, armDir, 18.5), Color3.fromRGB(30, 30, 30), M.Metal)
	local headPos = pole + armDir * (armLength - 2)
	local head = Util.groundCF(headPos, faceDir, 16)
	Util.deco(folder, V3(1.6, 4.6, 1.2), head, Color3.fromRGB(196, 160, 30), M.Metal)
	local lamps = {}
	for i, name in ipairs({ "red", "yellow", "green" }) do
		lamps[name] = Util.deco(folder, V3(1, 1, 0.2), head * CFrame.new(0, 1.5 - (i - 1) * 1.5, -0.7), Util.shade(SIGNAL_COLORS[name], 0.25), M.SmoothPlastic)
	end
	table.insert(signals, lamps)
end

local function setSignals(active)
	for _, lamps in ipairs(signals) do
		for name, lamp in pairs(lamps) do
			if name == active then
				lamp.Color = SIGNAL_COLORS[name]
				lamp.Material = M.Neon
			else
				lamp.Color = Util.shade(SIGNAL_COLORS[name], 0.25)
				lamp.Material = M.SmoothPlastic
			end
		end
	end
end

function Props.startSignals()
	task.spawn(function()
		while true do
			setSignals("green")
			task.wait(9)
			setSignals("yellow")
			task.wait(3)
			setSignals("red")
			task.wait(9)
		end
	end)
end

---------------------------------------------------------------------------
-- Placement
---------------------------------------------------------------------------
function Props.placeStreetFurniture(folder, rng)
	local placedSubway = 0
	Roads.eachSegment(function(road, a, _, dir, normal, length)
		if road.kind == "alley" then
			return
		end
		local half = road.width / 2
		for _, side in ipairs({ -1, 1 }) do
			local towardRoad = normal * -side
			-- Streetlights near the kerb.
			local spacing = road.main and 55 or 60
			local t = rng:NextNumber(5, spacing)
			while t < length do
				local p = a + dir * t + normal * side * (half + 1.6)
				if onSidewalk(p) then
					streetlight(folder, p, towardRoad)
				end
				t = t + spacing
			end
			-- Trees on side streets, clutter everywhere.
			t = rng:NextNumber(4, 14)
			while t < length do
				local kerbSide = a + dir * t + normal * side * (half + 2)
				local midWalk = a + dir * t + normal * side * (half + road.walk * 0.55)
				local r = rng:NextNumber()
				if not road.main and r < 0.35 and onSidewalk(midWalk) then
					tree(folder, midWalk, rng)
				elseif r < 0.45 and onSidewalk(kerbSide) then
					hydrant(folder, kerbSide)
				elseif r < 0.58 and onSidewalk(kerbSide) then
					trashCan(folder, kerbSide)
				elseif r < 0.64 and onSidewalk(kerbSide) then
					newsBox(folder, kerbSide, towardRoad, rng)
				elseif road.main and r < 0.67 and placedSubway < 14 and onSidewalk(midWalk) then
					subwayEntrance(folder, midWalk, dir)
					placedSubway = placedSubway + 1
				elseif road.main and r < 0.7 and onSidewalk(midWalk) then
					busStop(folder, midWalk, towardRoad)
				end
				t = t + rng:NextNumber(14, 26)
			end
		end
	end)

	-- Steam stacks in the middle of a few avenues.
	local stacks = 0
	Roads.eachSegment(function(road, a, _, dir, normal, length)
		if road.kind == "avenue" and stacks < 8 and rng:NextNumber() < 0.08 then
			local p = a + dir * (length / 2) + normal * (road.width / 4)
			if not Util.isJunction(p.X, p.Y) then
				steamStack(folder, p)
				stacks = stacks + 1
			end
		end
	end)

	-- One signal per avenue crossing, on a corner, hanging over the avenue.
	for _, x in ipairs(Roads.intersections) do
		local mainDir = x.mainDir
		local mainNormal = Vector2.new(-mainDir.Y, mainDir.X)
		for _, s in ipairs({ { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }) do
			local pole = x.position + mainNormal * s[1] * (x.mainWidth / 2 + 2.5) + mainDir * s[2] * (x.crossWidth / 2 + 2.5)
			if onSidewalk(pole) then
				trafficSignal(folder, pole, mainNormal * -s[1], x.mainWidth / 2 + 1, mainDir * s[2])
				break
			end
		end
	end
end

-- Parked cars along kerbs of side streets.
function Props.placeParkedCars(folder, rng, Cars)
	local count = 0
	Roads.eachSegment(function(road, a, _, dir, normal, length)
		if road.kind ~= "street" then
			return
		end
		local t = rng:NextNumber(10, 30)
		while t < length - 10 and count < 120 do
			if rng:NextNumber() < 0.5 then
				local side = rng:NextNumber() < 0.5 and 1 or -1
				local p = a + dir * t + normal * side * (road.width / 2 - 4)
				local ok = true
				for _, off in ipairs({ -9, 0, 9 }) do
					local q = p + dir * off
					if Util.isJunction(q.X, q.Y) or Util.get(q.X, q.Y) ~= Util.ROAD then
						ok = false
					end
				end
				if ok then
					-- Facing with traffic on that side (drive on the right).
					local facing = side == 1 and dir or dir * -1
					Cars.spawnParked(Util.groundCF(p, facing, 0.3), folder, rng)
					count = count + 1
				end
			end
			t = t + rng:NextNumber(20, 45)
		end
	end)
	return count
end

---------------------------------------------------------------------------
-- Park and river
---------------------------------------------------------------------------
function Props.buildPark(folder, rng)
	local r = Roads.PARK
	local cx, cz = (r.minX + r.maxX) / 2, (r.minZ + r.maxZ) / 2
	local w, d = r.maxX - r.minX, r.maxZ - r.minZ
	Util.solid(folder, V3(w, 1, d), CFrame.new(cx, -0.15, cz), Color3.fromRGB(84, 104, 60), M.Grass)
	-- Low stone wall with gaps for paths.
	local stone = Color3.fromRGB(120, 112, 100)
	for _, sz in ipairs({ -1, 1 }) do
		local z = cz + sz * d / 2
		Util.solid(folder, V3(w / 2 - 6, 2.2, 1.4), CFrame.new(r.minX + (w / 2 - 6) / 2, 1.1, z), stone, M.Cobblestone)
		Util.solid(folder, V3(w / 2 - 6, 2.2, 1.4), CFrame.new(r.maxX - (w / 2 - 6) / 2, 1.1, z), stone, M.Cobblestone)
	end
	for _, sx in ipairs({ -1, 1 }) do
		local x = cx + sx * w / 2
		Util.solid(folder, V3(1.4, 2.2, d / 2 - 6), CFrame.new(x, 1.1, r.minZ + (d / 2 - 6) / 2), stone, M.Cobblestone)
		Util.solid(folder, V3(1.4, 2.2, d / 2 - 6), CFrame.new(x, 1.1, r.maxZ - (d / 2 - 6) / 2), stone, M.Cobblestone)
	end
	-- Paths: a cross through the middle and a loop.
	local path = Color3.fromRGB(150, 140, 125)
	Util.deco(folder, V3(10, 0.2, d), CFrame.new(cx, 0.4, cz), path, M.Pavement)
	Util.deco(folder, V3(w, 0.2, 10), CFrame.new(cx, 0.41, cz), path, M.Pavement)
	-- Pond.
	local pondX, pondZ = cx + w * 0.22, cz - d * 0.22
	local pond = Util.cylinder(folder, 0.3, 60, CFrame.new(pondX, 0.3, pondZ), Color3.fromRGB(60, 84, 88), M.Glass, false)
	pond.Reflectance = 0.35
	-- Trees, benches and lamps.
	for _ = 1, 70 do
		local p = Vector2.new(rng:NextNumber(r.minX + 6, r.maxX - 6), rng:NextNumber(r.minZ + 6, r.maxZ - 6))
		local nearPath = math.abs(p.X - cx) < 9 or math.abs(p.Y - cz) < 9
		local inPond = (p - Vector2.new(pondX, pondZ)).Magnitude < 36
		if not nearPath and not inPond then
			tree(folder, p, rng, rng:NextNumber(1, 1.5))
		end
	end
	for i = -3, 3 do
		if i ~= 0 then
			local p = Vector2.new(cx + 7, cz + i * (d / 8))
			Util.solid(folder, V3(1.6, 1.6, 5), CFrame.new(p.X, 1.1, p.Y), Color3.fromRGB(70, 50, 34), M.Wood)
			streetlight(folder, Vector2.new(cx - 6.5, cz + i * (d / 8) + 6), Vector2.new(1, 0))
		end
	end
end

function Props.buildRiver(folder)
	local water = Util.deco(folder, V3(1000, 1, 2400), CFrame.new(Util.RIVER_X + 500, -2.5, 0), Color3.fromRGB(50, 66, 70), M.Glass)
	water.Reflectance = 0.3
	water.Transparency = 0.15
	Util.solid(folder, V3(1000, 2, 2400), CFrame.new(Util.RIVER_X + 500, -14, 0), Color3.fromRGB(60, 56, 48), M.Mud)
	-- Promenade, railing and an invisible wall so nobody walks into the river.
	Util.solid(folder, V3(10, 1, Util.MAX_Z - Util.MIN_Z), CFrame.new(Util.RIVER_X - 3, -0.25, 0), Color3.fromRGB(150, 144, 134), M.Pavement)
	Util.solid(folder, V3(0.4, 3.4, Util.MAX_Z - Util.MIN_Z), CFrame.new(Util.RIVER_X + 1.6, 1.9, 0), Color3.fromRGB(40, 44, 42), M.Metal)
	local wall = Util.solid(folder, V3(2, 80, Util.MAX_Z - Util.MIN_Z), CFrame.new(Util.RIVER_X + 3, 40, 0), Color3.new(), M.SmoothPlastic)
	wall.Transparency = 1
	Util.solid(folder, V3(40, 6, Util.MAX_Z - Util.MIN_Z), CFrame.new(Util.RIVER_X + 22, -5, 0), Color3.fromRGB(96, 90, 82), M.Concrete) -- embankment
	-- Piers.
	for _, z in ipairs({ -480, -140, 220, 520 }) do
		Util.deco(folder, V3(120, 1, 26), CFrame.new(Util.RIVER_X + 70, 0.2, z), Color3.fromRGB(110, 92, 70), M.WoodPlanks)
		for x = 20, 120, 25 do
			Util.cylinder(folder, 14, 1.2, CFrame.new(Util.RIVER_X + x, -6, z - 12), Color3.fromRGB(70, 60, 50), M.Wood, false)
			Util.cylinder(folder, 14, 1.2, CFrame.new(Util.RIVER_X + x, -6, z + 12), Color3.fromRGB(70, 60, 50), M.Wood, false)
		end
	end
end

return Props
