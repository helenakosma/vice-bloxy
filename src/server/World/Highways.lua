-- Freeways, connector ramps, the frontage road and the suspension bridge.
--
-- Each highway is a list of control points (Y = deck height). The route is smoothed
-- with a Catmull-Rom spline and the height with a monotone curve, so ramps ease in
-- and out without bumps. The deck is drawn as strips across its width whose ends
-- follow the curve, and barriers are joined end to end, so bends have no gaps or
-- jagged edges. A barrier is left out wherever it would stand on another highway's
-- deck, which is what opens up the merges.
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
local YELLOW = Color3.fromRGB(214, 170, 40)
local LAMP = Color3.fromRGB(255, 200, 140)
local SIGN_GREEN = Color3.fromRGB(0, 104, 62)
local GRAVEL = Color3.fromRGB(88, 84, 78)

local STEP = 14 -- studs between curve samples
local ELEVATED = 2.5 -- above this a section gets barriers
local EMBANKMENT = 9 -- below this an elevated section sits on a solid embankment
local SHOULDER = 4
local MEDIAN = 1.5

local list = {}
local byName = {}

-- Every highway (name, width, sampled points), e.g. for the minimap.
function Highways.list()
	return list
end

local function flat(v)
	return Vector2.new(v.X, v.Z)
end

---------------------------------------------------------------------------
-- Curves
---------------------------------------------------------------------------
-- Hermite curve from p1 to p2. Tangents are scaled by the neighbouring segment
-- lengths, so a short segment next to a long one can't loop back on itself.
local function curvePoint(p0, p1, p2, p3, t)
	local d0 = (p1 - p0).Magnitude
	local d1 = (p2 - p1).Magnitude
	local d2 = (p3 - p2).Magnitude
	local m1 = (p2 - p0) * (d1 / math.max(d0 + d1, 1e-3))
	local m2 = (p3 - p1) * (d1 / math.max(d1 + d2, 1e-3))
	local t2, t3 = t * t, t * t * t
	return (2 * t3 - 3 * t2 + 1) * p1 + (t3 - 2 * t2 + t) * m1 + (-2 * t3 + 3 * t2) * p2 + (t3 - t2) * m2
end

-- Monotone cubic (Fritsch-Carlson) through (xs[i], ys[i]): smooth, never overshoots.
local function monotone(xs, ys)
	local n = #xs
	local d, m = {}, {}
	for i = 1, n - 1 do
		d[i] = (ys[i + 1] - ys[i]) / math.max(xs[i + 1] - xs[i], 1e-3)
	end
	m[1], m[n] = d[1] or 0, d[n - 1] or 0
	for i = 2, n - 1 do
		if d[i - 1] * d[i] <= 0 then
			m[i] = 0
		else
			m[i] = (d[i - 1] + d[i]) / 2
		end
	end
	for i = 1, n - 1 do
		if d[i] == 0 then
			m[i], m[i + 1] = 0, 0
		else
			local a, b = m[i] / d[i], m[i + 1] / d[i]
			local h = a * a + b * b
			if h > 9 then
				local t = 3 / math.sqrt(h)
				m[i] = t * a * d[i]
				m[i + 1] = t * b * d[i]
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

local function sample(control)
	local n = #control
	local flats, heights, dist = {}, {}, { 0 }
	for i = 1, n do
		flats[i] = flat(control[i])
		heights[i] = control[i].Y
	end
	for i = 2, n do
		dist[i] = dist[i - 1] + (flats[i] - flats[i - 1]).Magnitude
	end
	local heightAt = monotone(dist, heights)

	local points = {}
	for i = 1, n - 1 do
		local p0 = flats[math.max(1, i - 1)]
		local p1, p2 = flats[i], flats[i + 1]
		local p3 = flats[math.min(n, i + 2)]
		local chord = dist[i + 1] - dist[i]
		local steps = math.max(1, math.ceil(chord / STEP))
		for k = 0, steps - 1 do
			local t = k / steps
			local xz = curvePoint(p0, p1, p2, p3, t)
			table.insert(points, V3(xz.X, heightAt(dist[i] + chord * t), xz.Y))
		end
	end
	table.insert(points, control[n])
	return points
end

-- Horizontal "right" vector at each sample, from the averaged direction.
local function rights(points)
	local out = {}
	local n = #points
	for i = 1, n do
		local a = points[math.max(1, i - 1)]
		local b = points[math.min(n, i + 1)]
		local d = flat(b - a)
		if d.Magnitude < 1e-3 then
			d = Vector2.new(0, 1)
		end
		d = d.Unit
		out[i] = V3(-d.Y, 0, d.X)
	end
	return out
end

local function add(def)
	def.id = Roads.allocateId()
	def.points = sample(def.control)
	def.rights = rights(def.points)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(def.points) do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local pad = def.width / 2 + 4
	def.box = { minX = minX - pad, maxX = maxX + pad, minZ = minZ - pad, maxZ = maxZ + pad }
	table.insert(list, def)
	byName[def.name] = def
	return def
end

-- Deck height of `hw` under point p (Vector3), or nil if p isn't over its deck.
local function deckHeightAt(hw, p)
	local b = hw.box
	if p.X < b.minX or p.X > b.maxX or p.Z < b.minZ or p.Z > b.maxZ then
		return nil
	end
	local best, bestY = math.huge, nil
	local pts = hw.points
	for i = 1, #pts - 1 do
		local a, c = pts[i], pts[i + 1]
		local dx, dz = c.X - a.X, c.Z - a.Z
		local len2 = dx * dx + dz * dz
		local t = 0
		if len2 > 0 then
			t = math.clamp(((p.X - a.X) * dx + (p.Z - a.Z) * dz) / len2, 0, 1)
		end
		local qx, qz = a.X + dx * t - p.X, a.Z + dz * t - p.Z
		local d2 = qx * qx + qz * qz
		if d2 < best then
			best = d2
			bestY = a.Y + (c.Y - a.Y) * t
		end
	end
	if math.sqrt(best) < hw.width / 2 - 0.3 then
		return bestY
	end
	return nil
end

-- True if p sits on some other highway's deck at about the same height.
local function onOtherDeck(self, p)
	for _, other in ipairs(list) do
		if other ~= self then
			local y = deckHeightAt(other, p)
			if y and math.abs(y - p.Y) < 5 then
				return true
			end
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
-- West-reaching downtown cross streets (they carry on into the suburbs).
local function westStreetZs(downtownRoads)
	local zs = {}
	for _, road in ipairs(downtownRoads or {}) do
		local first = road.points[1]
		if road.kind == "street" and math.abs(first.X - Util.MIN_X) < 1 then
			table.insert(zs, first.Y)
		end
	end
	table.sort(zs)
	return zs
end

-- Picks where the frontage road touches down (zA) and lifts off (zB): each ramp
-- needs a long stretch with no cross street underneath it.
local function frontageControl(downtownRoads)
	local zs = westStreetZs(downtownRoads)
	local maxLen, minLen = 300, 170
	local best = nil
	for i = 1, #zs do
		for j = i + 1, #zs do
			local zA, zB = zs[i], zs[j]
			local before = zs[i - 1] and (zA - zs[i - 1] - 30) or maxLen
			local after = zs[j + 1] and (zs[j + 1] - zB - 30) or maxLen
			local lenA, lenB = math.min(before, maxLen), math.min(after, maxLen)
			local startZ = zA - lenA - 180
			local endZ = zB + lenB + 180
			if lenA >= minLen and lenB >= minLen and zB - zA >= 150 and startZ > -440 and endZ < 940 then
				local score = lenA + lenB + (zB - zA) * 0.5
				if not best or score > best.score then
					best = { zA = zA, zB = zB, lenA = lenA, lenB = lenB, score = score }
				end
			end
		end
	end
	if not best then
		warn("[Highways] no clean spot for the frontage road; using a default")
		best = { zA = 100, zB = 420, lenA = 260, lenB = 260 }
	end
	return Layout.frontage(best.zA, best.zB, best.lenA, best.lenB)
end

function Highways.layout(shared)
	local W = Layout.RAMP_WIDTH
	-- Without Vice Beach the expressway and the Harbor Freeway end where they
	-- used to run on to the suspension bridge: closed off with a barrier.
	local bridge = Layout.VICE_BEACH_ACTIVE
	add({ name = "Expressway", width = Layout.EXPRESSWAY_WIDTH, lanes = 3, control = Layout.EXPRESSWAY, median = true, pillarsInWater = true, closedEnd = not bridge })
	add({ name = "HarborFreeway", width = Layout.HARBOR_WIDTH, lanes = 2, control = Layout.HARBOR, median = true, pillarsInWater = true, lift = 0.03, closedEnd = not bridge })
	add({ name = "Highway401", width = Layout.HWY401_WIDTH, lanes = 4, control = Layout.HWY401, median = true })
	if bridge then
		add({ name = "SuspensionBridge", width = Layout.EXPRESSWAY_WIDTH, lanes = 3, control = Layout.BRIDGE, median = true, towersX = Layout.BRIDGE_TOWERS_X })
	end
	for _, name in ipairs({ "NorthConnector", "SouthConnector", "Industrial" }) do
		add({ name = name .. "Ramp", width = W, lanes = 1, control = Layout.RAMPS[name], pillarsInWater = true, lift = 0.05 })
	end
	add({ name = "FrontageRoad", width = W, lanes = 1, control = frontageControl(shared and shared.downtownRoads), lift = 0.05 })

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

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
-- A box spanning a -> b (3D), `thick` tall and `wide` across, raised by `lift`.
local function span(folder, a, b, wide, thick, lift, color, material, solid)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return nil
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, lift, 0)
	local size = V3(wide, thick, length + 0.35)
	if solid then
		return Util.solid(folder, size, cf, color, material)
	end
	return Util.deco(folder, size, cf, color, material)
end

local function cellAt(p)
	return Util.get(p.X, p.Z)
end

local function pillar(folder, hw, i)
	local p = hw.points[i]
	local right = hw.rights[i]
	local top = p.Y - 1.6
	for _, side in ipairs({ -1, 1 }) do
		local foot = p + right * side * hw.width * 0.25
		local cell = cellAt(foot)
		local inWater = cell == Util.WATER or cell == -1
		local blocked = cell == Util.ROAD or cell == Util.WALK or (inWater and not hw.pillarsInWater)
		local bottom = inWater and -14 or 0
		local height = top - bottom
		if not blocked and height > 3 and not onOtherDeck(hw, V3(foot.X, top, foot.Z)) then
			Util.solid(folder, V3(5, height, 5), CFrame.new(foot.X, bottom + height / 2, foot.Z), CONCRETE, M.Concrete)
		end
	end
	local forward = V3(right.Z, 0, -right.X)
	local beamPos = V3(p.X, top - 1.5, p.Z)
	Util.deco(folder, V3(hw.width * 0.8, 3, 5), CFrame.lookAt(beamPos, beamPos + forward), CONCRETE, M.Concrete)
end

-- Solid retaining-wall embankment under a low section (on land, not over a road).
local function embankment(folder, hw, a, b)
	local mid = (a + b) / 2
	local cell = cellAt(mid)
	if cell == Util.ROAD or cell == Util.WALK or cell == Util.WATER or cell == -1 then
		return
	end
	local height = math.min(a.Y, b.Y) - 1.4
	if height < 0.5 then
		return
	end
	local base = V3(mid.X, height / 2, mid.Z)
	local ahead = V3(b.X, height / 2, b.Z)
	if (ahead - base).Magnitude < 0.05 then
		return
	end
	Util.solid(folder, V3(hw.width - 0.4, height, (b - a).Magnitude + 0.4), CFrame.lookAt(base, ahead), CONCRETE, M.Concrete)
end

local function gantry(folder, hw, i, text)
	local p, right = hw.points[i], hw.rights[i]
	local half = hw.width / 2 - 0.8
	for _, side in ipairs({ -1, 1 }) do
		local foot = p + right * side * half
		Util.solid(folder, V3(1.2, 22, 1.2), CFrame.new(foot.X, p.Y + 11, foot.Z), Color3.fromRGB(110, 112, 114), M.Metal)
	end
	local beamA = p - right * half + V3(0, 20, 0)
	local beamB = p + right * half + V3(0, 20, 0)
	span(folder, beamA, beamB, 1.2, 1.2, 0, Color3.fromRGB(110, 112, 114), M.Metal, false)
	local forward = V3(right.Z, 0, -right.X)
	local centre = p + V3(0, 16.5, 0)
	local panel = Util.deco(folder, V3(math.min(hw.width * 0.6, 46), 6.5, 0.4), CFrame.lookAt(centre, centre + forward), SIGN_GREEN, M.SmoothPlastic)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Util.sign(panel, face, text, Color3.fromRGB(245, 245, 240), Enum.Font.GothamBold)
		gui.LightInfluence = 0.3
	end
end

local function tower(folder, hw, i)
	local p = hw.points[i]
	local right = hw.rights[i]
	local top = p.Y + 110
	local bottom = -14
	for _, side in ipairs({ -1, 1 }) do
		local leg = p + right * side * (hw.width / 2 + 5)
		Util.solid(folder, V3(7, top - bottom, 7), CFrame.new(leg.X, (top + bottom) / 2, leg.Z), STEEL, M.Metal)
	end
	for _, y in ipairs({ p.Y - 4, p.Y + 45, top - 4 }) do
		local a = V3(p.X, y, p.Z) - right * (hw.width / 2 + 8)
		local b = V3(p.X, y, p.Z) + right * (hw.width / 2 + 8)
		span(folder, a, b, 6, 6, 0, STEEL, M.Metal, false)
	end
	return { index = i, top = top }
end

local function cables(folder, hw, towers)
	local n = #hw.points
	local first, last = hw.points[1], hw.points[n]
	local t1, t2 = towers[1], towers[2]
	local p1, p2 = hw.points[t1.index], hw.points[t2.index]
	for _, side in ipairs({ -1, 1 }) do
		local function offset(p, i, y)
			local q = p + hw.rights[i] * side * (hw.width / 2 + 5)
			return V3(q.X, y, q.Z)
		end
		local anchorA = offset(first, 1, first.Y + 2)
		local anchorB = offset(last, n, last.Y + 2)
		local top1 = offset(p1, t1.index, t1.top)
		local top2 = offset(p2, t2.index, t2.top)
		Util.beam(folder, anchorA, top1, 1.4, STEEL, M.Metal)
		Util.beam(folder, top2, anchorB, 1.4, STEEL, M.Metal)
		local deckY = p1.Y
		local steps = 16
		local prev = top1
		for k = 1, steps do
			local u = k / steps
			local p = top1:Lerp(top2, u)
			local sag = 4 * u * (1 - u) * (t1.top - deckY - 8)
			local point = V3(p.X, p.Y - sag, p.Z)
			Util.beam(folder, prev, point, 1.4, STEEL, M.Metal)
			if k < steps then
				Util.beam(folder, point, V3(point.X, deckY + 1, point.Z), 0.4, STEEL, M.Metal)
			end
			prev = point
		end
	end
end

local function render(folder, hw)
	local pts, rs = hw.points, hw.rights
	local n = #pts
	local strips = math.max(2, math.ceil(hw.width / 16))
	local stripW = hw.width / strips
	local inner = hw.median and MEDIAN or 0
	local laneW = (hw.width / 2 - SHOULDER - inner) / hw.lanes
	local lift = hw.lift or 0

	for i = 1, n - 1 do
		local a, b = pts[i], pts[i + 1]
		local ra, rb = rs[i], rs[i + 1]
		local low = math.min(a.Y, b.Y)
		local elevated = low > ELEVATED

		-- Deck strips: each strip's ends follow the curve, so bends have no gaps.
		for s = 1, strips do
			local u = -hw.width / 2 + stripW * (s - 0.5)
			span(folder, a + ra * u, b + rb * u, stripW + 0.25, 1.6, -0.8 + lift, DECK, M.Asphalt, true)
		end

		-- Edge lines, lane dashes, and a yellow centre line on two-way ramps.
		for _, side in ipairs({ -1, 1 }) do
			local e = side * (hw.width / 2 - SHOULDER)
			span(folder, a + ra * e, b + rb * e, 0.45, 0.05, 0.03 + lift, WHITE, M.SmoothPlastic, false)
			if i % 2 == 0 then
				for k = 1, hw.lanes - 1 do
					local o = side * (inner + laneW * k)
					local mid = (a + b) / 2 + (ra + rb) / 2 * o
					local dir = (b - a).Unit
					span(folder, mid - dir * 4, mid + dir * 4, 0.45, 0.05, 0.03 + lift, WHITE, M.SmoothPlastic, false)
				end
			end
		end
		if not hw.median then
			span(folder, a + ra * 0.3, b + rb * 0.3, 0.35, 0.05, 0.03 + lift, YELLOW, M.SmoothPlastic, false)
			span(folder, a - ra * 0.3, b - rb * 0.3, 0.35, 0.05, 0.03 + lift, YELLOW, M.SmoothPlastic, false)
		end

		if elevated then
			-- Side barriers, left out where they would stand on another deck.
			for _, side in ipairs({ -1, 1 }) do
				local e = side * (hw.width / 2 - 0.6)
				local pa, pb = a + ra * e, b + rb * e
				if not onOtherDeck(hw, (pa + pb) / 2) then
					span(folder, pa, pb, 1.2, 2.8, 1.4, CONCRETE, M.Concrete, true)
				end
			end
			-- The median also stops where this road runs onto another deck (merges).
			if hw.median and not onOtherDeck(hw, (a + b) / 2) then
				span(folder, a, b, MEDIAN * 2 - 0.4, 2.4, 1.2, CONCRETE, M.Concrete, true)
				if i % 5 == 0 then
					local pole = CFrame.lookAt(a, b)
					Util.deco(folder, V3(0.6, 16, 0.6), pole * CFrame.new(0, 8, 0), Color3.fromRGB(70, 72, 74), M.Metal)
					for _, side in ipairs({ -1, 1 }) do
						Util.deco(folder, V3(7, 0.4, 0.5), pole * CFrame.new(side * 3.5, 15.8, 0), Color3.fromRGB(70, 72, 74), M.Metal)
						Util.deco(folder, V3(1.6, 0.3, 1.2), pole * CFrame.new(side * 7, 15.5, 0), LAMP, M.Neon)
					end
				end
			end

			-- Support: an embankment when low, pillars when high (not on bridges).
			if low < EMBANKMENT then
				embankment(folder, hw, a, b)
			elseif i % 3 == 0 and not hw.towersX then
				pillar(folder, hw, i)
			end
			-- Gravel ground under high sections on land.
			if low >= EMBANKMENT and i % 2 == 0 then
				local mid = (a + b) / 2
				local cell = cellAt(mid)
				if cell == Util.RESERVED or cell == Util.FREE then
					local g0 = V3(a.X, 0.06, a.Z)
					local g1 = V3(b.X + (b.X - a.X), 0.06, b.Z + (b.Z - a.Z))
					local ground = span(folder, g0, g1, hw.width + 4, 0.1, 0, GRAVEL, M.Ground, false)
					if ground then
						ground.CastShadow = false
					end
				end
			end
		end
	end

	-- Suspension bridge: towers at the samples nearest the given x positions,
	-- pillars only on land.
	if hw.towersX then
		local towers = {}
		for t, x in ipairs(hw.towersX) do
			local best, bestD = 1, math.huge
			for i = 1, n do
				local d = math.abs(pts[i].X - x)
				if d < bestD then
					best, bestD = i, d
				end
			end
			towers[t] = tower(folder, hw, best)
		end
		for i = 3, n - 1, 3 do
			if pts[i].Y >= EMBANKMENT then
				pillar(folder, hw, i)
			end
		end
		if #towers == 2 then
			cables(folder, hw, towers)
		end
	end

	-- Overhead signs.
	for _, sign in ipairs(Layout.SIGNS[hw.name] or {}) do
		local best, bestD = 1, math.huge
		for i = 1, n do
			local d = (flat(pts[i]) - sign.at).Magnitude
			if d < bestD then
				best, bestD = i, d
			end
		end
		gantry(folder, hw, best, sign.text)
	end
end

-- A closed end: a concrete barrier across the deck with a "ROAD CLOSED" board.
local function closeEnd(f, hw)
	local pts = hw.points
	local p, q = pts[#pts], pts[#pts - 1]
	if not (p and q) then
		return
	end
	local dir = Vector3.new(p.X - q.X, 0, p.Z - q.Z)
	if dir.Magnitude < 0.01 then
		return
	end
	dir = dir.Unit
	local at = p - dir * 3 + V3(0, 2, 0)
	local cf = CFrame.lookAt(at, at + dir)
	local barrier = Util.solid(f, V3(hw.width + 2, 4, 2), cf, CONCRETE, M.Concrete)
	barrier.Name = "RoadClosed"
	for k = -2, 2 do
		Util.deco(f, V3(hw.width / 6, 1, 0.2), cf * CFrame.new(k * hw.width / 5, 0.5, -1.05), k % 2 == 0 and YELLOW or Color3.fromRGB(30, 30, 30), M.SmoothPlastic)
	end
	local board = Util.deco(f, V3(18, 4, 0.4), cf * CFrame.new(0, 5, -0.6), WHITE, M.SmoothPlastic)
	Util.sign(board, Enum.NormalId.Back, "ROAD CLOSED", Color3.fromRGB(200, 30, 30), Enum.Font.GothamBlack)
end

function Highways.build(folder)
	for _, hw in ipairs(list) do
		local f = Instance.new("Folder")
		f.Name = hw.name
		f.Parent = folder
		render(f, hw)
		if hw.closedEnd then
			closeEnd(f, hw)
		end
	end
end

Highways.byName = byName
Highways.sample = sample

return Highways
