-- Elevated expressway and the suspension bridge. Each highway is a 3D polyline:
-- control points are smoothed into short segments, with eased ramps between levels.
local Util = require(script.Parent.Util)
local Roads = require(script.Parent.Roads)
local Layout = require(script.Parent.Layout)

local Highways = {}

local V3 = Vector3.new
local M = Enum.Material
local DECK = Color3.fromRGB(64, 64, 66)
local CONCRETE = Color3.fromRGB(150, 146, 138)
local STEEL = Color3.fromRGB(176, 72, 52) -- rust-red bridge steel
local WHITE = Color3.fromRGB(222, 222, 218)
local SEGMENT = 25 -- studs per deck segment
local ELEVATED = 2.5 -- above this height a segment gets barriers and pillars

local list = {}

-- Densifies control points; elevation eases in and out between control points.
local function densify(control)
	local points = {}
	for i = 1, #control - 1 do
		local a, b = control[i], control[i + 1]
		local flat = Vector2.new(b.X - a.X, b.Z - a.Z).Magnitude
		local n = math.max(1, math.ceil(flat / SEGMENT))
		for k = 0, n - 1 do
			local t = k / n
			local s = t * t * (3 - 2 * t)
			table.insert(points, V3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * s, a.Z + (b.Z - a.Z) * t))
		end
	end
	table.insert(points, control[#control])
	return points
end

local function flat(v)
	return Vector2.new(v.X, v.Z)
end

local function add(def)
	def.id = Roads.allocateId()
	def.points = densify(def.control)
	table.insert(list, def)
	return def
end

-- Claims the ground under each highway: at-grade parts count as road (so crossing
-- streets form junctions); elevated parts keep buildings out from underneath.
function Highways.layout()
	add({ name = "Expressway", width = 44, control = Layout.EXPRESSWAY, median = true, pillarsInWater = true })
	add({ name = "SuspensionBridge", width = 40, control = Layout.BRIDGE, median = true, towersX = Layout.BRIDGE_TOWERS_X })

	for _, hw in ipairs(list) do
		for i = 1, #hw.points - 1 do
			local a, b = hw.points[i], hw.points[i + 1]
			if math.max(a.Y, b.Y) < ELEVATED then
				Util.markSegment(flat(a), flat(b), hw.width / 2, Util.ROAD, hw.id, false)
			else
				Util.markSegment(flat(a), flat(b), hw.width / 2 + 3, Util.RESERVED, nil, true)
			end
		end
	end
end

local function pillar(folder, hw, a, b)
	local mid = (a + b) / 2
	local cell = Util.get(mid.X, mid.Z)
	if cell == Util.ROAD or cell == Util.WALK then
		return -- a street runs underneath here
	end
	local inWater = cell == Util.WATER or cell == -1
	if inWater and not hw.pillarsInWater then
		return
	end
	local bottom = inWater and -14 or 0
	local top = mid.Y - 1.6
	local height = top - bottom
	if height < 2 then
		return
	end
	local yaw = Util.groundCF(flat(mid), flat(b - a).Unit, 0)
	for _, side in ipairs({ -1, 1 }) do
		local foot = yaw * CFrame.new(side * hw.width * 0.25, 0, 0)
		Util.solid(folder, V3(4.5, height, 4.5), CFrame.new(foot.Position.X, bottom + height / 2, foot.Position.Z), CONCRETE, M.Concrete)
	end
	Util.deco(folder, V3(hw.width * 0.85, 3, 5), yaw + V3(0, top - 1.5, 0), CONCRETE, M.Concrete)
end

local function tower(folder, hw, at, dir)
	local cf = Util.groundCF(flat(at), dir, 0)
	local deck = at.Y
	local top = deck + 95
	local bottom = -14
	for _, side in ipairs({ -1, 1 }) do
		local leg = cf * CFrame.new(side * (hw.width / 2 + 4), 0, 0)
		Util.solid(folder, V3(6, top - bottom, 6), CFrame.new(leg.Position.X, (top + bottom) / 2, leg.Position.Z), STEEL, M.Metal)
	end
	for _, y in ipairs({ deck - 4, deck + 40, top - 4 }) do
		Util.deco(folder, V3(hw.width + 14, 5, 5), cf + V3(0, y, 0), STEEL, M.Metal)
	end
	return top
end

-- Main cables: anchor -> tower -> sagging span -> tower -> anchor, with hangers.
local function cables(folder, hw, towerTops)
	local first, last = hw.points[1], hw.points[#hw.points]
	local dir = flat(last - first).Unit
	local normal = Vector2.new(-dir.Y, dir.X)
	local t1, t2 = towerTops[1], towerTops[2]
	for _, side in ipairs({ -1, 1 }) do
		local off = normal * side * (hw.width / 2 + 4)
		local function at(p, y)
			return V3(p.X + off.X, y, p.Z + off.Y)
		end
		local a = at(first, first.Y + 2)
		local top1 = at(t1.position, t1.top)
		local top2 = at(t2.position, t2.top)
		local b = at(last, last.Y + 2)
		Util.beam(folder, a, top1, 1.2, STEEL, M.Metal)
		Util.beam(folder, top2, b, 1.2, STEEL, M.Metal)
		local deckY = t1.position.Y
		local steps = 14
		local prev = top1
		for k = 1, steps do
			local u = k / steps
			local p = top1:Lerp(top2, u)
			local sag = 4 * u * (1 - u) * (t1.top - deckY - 8)
			local point = V3(p.X, p.Y - sag, p.Z)
			Util.beam(folder, prev, point, 1.2, STEEL, M.Metal)
			if k < steps then
				Util.beam(folder, point, V3(point.X, deckY + 1, point.Z), 0.35, STEEL, M.Metal)
			end
			prev = point
		end
	end
end

local function render(folder, hw)
	local nearestToTower = {}
	for i = 1, #hw.points - 1 do
		local a, b = hw.points[i], hw.points[i + 1]
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt(mid, b)
		local elevated = math.min(a.Y, b.Y) > ELEVATED

		Util.solid(folder, V3(hw.width, 1.6, length + 1.2), cf * CFrame.new(0, -0.8, 0), DECK, M.Asphalt)
		-- Lane dashes and edge lines.
		for _, x in ipairs({ -hw.width / 4, hw.width / 4 }) do
			Util.deco(folder, V3(0.4, 0.05, 8), cf * CFrame.new(x, 0.03, 0), WHITE, M.SmoothPlastic)
		end
		for _, x in ipairs({ -hw.width / 2 + 2.5, hw.width / 2 - 2.5 }) do
			Util.deco(folder, V3(0.4, 0.05, length), cf * CFrame.new(x, 0.03, 0), WHITE, M.SmoothPlastic)
		end

		if elevated then
			for _, side in ipairs({ -1, 1 }) do
				Util.solid(folder, V3(1.2, 2.8, length + 1.2), cf * CFrame.new(side * (hw.width / 2 - 0.6), 1.4, 0), CONCRETE, M.Concrete)
			end
			if hw.median then
				Util.solid(folder, V3(1.4, 2.4, length + 1.2), cf * CFrame.new(0, 1.2, 0), CONCRETE, M.Concrete)
			end
			if i % 2 == 0 then
				pillar(folder, hw, a, b)
			end
			-- Lamps on the median every few segments.
			if hw.median and i % 4 == 0 then
				local pole = cf * CFrame.new(0, 0, 0)
				Util.deco(folder, V3(0.5, 14, 0.5), pole * CFrame.new(0, 7, 0), Color3.fromRGB(70, 72, 74), M.Metal)
				for _, side in ipairs({ -1, 1 }) do
					Util.deco(folder, V3(5, 0.4, 0.5), pole * CFrame.new(side * 2.5, 13.8, 0), Color3.fromRGB(70, 72, 74), M.Metal)
					Util.deco(folder, V3(1.4, 0.3, 1), pole * CFrame.new(side * 5, 13.5, 0), Color3.fromRGB(255, 200, 140), M.Neon)
				end
			end
		end

		if hw.towersX then
			for t, x in ipairs(hw.towersX) do
				local d = math.abs(mid.X - x)
				if not nearestToTower[t] or d < nearestToTower[t].d then
					nearestToTower[t] = { d = d, at = mid, dir = flat(b - a).Unit }
				end
			end
		end
	end

	if hw.towersX then
		local tops = {}
		for t, info in ipairs(nearestToTower) do
			tops[t] = { position = info.at, top = tower(folder, hw, info.at, info.dir) }
		end
		if #tops == 2 then
			cables(folder, hw, tops)
		end
	end
end

function Highways.build(folder)
	for _, hw in ipairs(list) do
		local f = Instance.new("Folder")
		f.Name = hw.name
		f.Parent = folder
		render(f, hw)
	end
end

return Highways
