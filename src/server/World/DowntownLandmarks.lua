-- Downtown Toronto landmarks around Yonge & Dundas, plus the two universities:
--
-- (The Eaton Centre is built from its real plans in World/EatonCentre.)
--   sankofaSquare  the open square on the south-east corner of Yonge & Dundas:
--                  granite paving, fountain jets, a stage, canopies, seating.
--   screenBuilding the buildings that wall in the intersection with giant
--                  screens (the "billboard canyon"). Screens rotate their ads.
--   tmu            Toronto Metropolitan University: the glass learning centre
--                  on Yonge, the Kerr Hall quad, a tower south of Gerrard.
--   uoft           University of Toronto: King's College Circle, University
--                  College, Convocation Hall, Hart House, Robarts Library.
--
-- All brands and shop names are made up.
local CollectionService = game:GetService("CollectionService")

local Util = require(script.Parent.Util)
local Billboards = require(script.Parent.Billboards)
local Props = require(script.Parent.Props)
local Kit = require(script.Parent.StationKit)

local Landmarks = {}

local V3 = Vector3.new
local M = Enum.Material
local C = Color3.fromRGB
local Front = Enum.NormalId.Front
local KERB = Util.WALK_TOP

local function solid(folder, size, cf, colour, material)
	return Util.solid(folder, size, typeof(cf) == "CFrame" and cf or CFrame.new(cf), colour, material or M.SmoothPlastic)
end
local function deco(folder, size, cf, colour, material)
	return Util.deco(folder, size, typeof(cf) == "CFrame" and cf or CFrame.new(cf), colour, material or M.SmoothPlastic)
end
local function glass(folder, size, cf, colour, transparency)
	local g = solid(folder, size, cf, colour or C(180, 206, 218), M.Glass)
	g.Transparency = transparency or 0.45
	return g
end

-- Big LED screen on a facade: cf at the screen centre, Front facing out.
-- The face rotates with the city's ads; a coloured glow spills onto the street.
local function screen(folder, cf, w, h, rng)
	deco(folder, V3(w + 1.2, h + 1.2, 0.8), cf * CFrame.new(0, 0, 0.4), C(18, 18, 20), M.Metal)
	local panel = deco(folder, V3(w, h, 0.3), cf * CFrame.new(0, 0, -0.1), C(10, 10, 12))
	panel.CastShadow = false
	local gui = Billboards.face(panel, Front, Billboards.pick(rng), true)
	gui.Brightness = 2.2
	gui.PixelsPerStud = 10
	local glow = Instance.new("SurfaceLight")
	glow.Face = Front
	glow.Range = math.clamp(w, 20, 40)
	glow.Angle = 110
	glow.Brightness = 1.4
	glow.Color = Util.pick(rng, { C(255, 120, 200), C(120, 200, 255), C(255, 220, 140), C(255, 255, 255) })
	glow.Parent = panel
	return panel
end

-- Text sign with no lighting influence (glows at night).
local function sign(folder, cf, size, text, bg, fg, font)
	local p = deco(folder, size, cf, bg)
	p.CastShadow = false
	Util.sign(p, Front, text, fg, font or Enum.Font.GothamBlack).LightInfluence = 0
	return p
end

---------------------------------------------------------------------------
-- Sankofa Square
---------------------------------------------------------------------------
function Landmarks.sankofaSquare(folder, rect, rng)
	local x0, x1, z0, z1 = rect.minX, rect.maxX, rect.minZ, rect.maxZ
	local W, L = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	-- Granite paving with a darker grid.
	solid(folder, V3(W, 1, L), V3(cx, KERB - 0.5, cz), C(186, 182, 176), M.Granite)
	for x = x0 + 10, x1 - 10, 10 do
		deco(folder, V3(0.5, 0.05, L), V3(x, KERB + 0.03, cz), C(120, 116, 112), M.Granite).CastShadow = false
	end
	for z = z0 + 10, z1 - 10, 10 do
		deco(folder, V3(W, 0.05, 0.5), V3(cx, KERB + 0.03, z), C(120, 116, 112), M.Granite).CastShadow = false
	end
	-- Fountain jets in the middle (water shooting up from the paving).
	local jx0, jx1 = x0 + 26, x1 - 40
	for jx = jx0, jx1, 9 do
		for jz = z0 + 18, z1 - 22, 11 do
			local jet = deco(folder, V3(1.2, 0.1, 1.2), V3(jx, KERB + 0.06, jz), C(120, 200, 230), M.Neon)
			jet.CastShadow = false
			local water = Instance.new("ParticleEmitter")
			water.Rate = 30
			water.Lifetime = NumberRange.new(0.9, 1.2)
			water.Speed = NumberRange.new(16, 20)
			water.SpreadAngle = Vector2.new(4, 4)
			water.Acceleration = V3(0, -30, 0)
			water.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.2) })
			water.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
			water.Color = ColorSequence.new(C(220, 240, 255))
			water.LightInfluence = 0.6
			water.EmissionDirection = Enum.NormalId.Top
			water.Parent = jet
		end
	end
	-- Stage at the east end: platform, truss, roof, screen behind, speakers.
	local sx0 = x1 - 28
	local stageCX = (sx0 + x1) / 2
	solid(folder, V3(26, 2.4, L - 16), V3(stageCX, KERB + 1.2, cz), C(40, 40, 44), M.Wood)
	for _, z in ipairs({ z0 + 9, z1 - 9 }) do
		solid(folder, V3(1.4, 22, 1.4), V3(sx0 + 2, KERB + 11, z), C(60, 62, 66), M.DiamondPlate)
		solid(folder, V3(1.4, 22, 1.4), V3(x1 - 2, KERB + 11, z), C(60, 62, 66), M.DiamondPlate)
		solid(folder, V3(4, 8, 4), V3(sx0 + 4, KERB + 6.4, z + (z < cz and 4 or -4)), C(16, 16, 18))
	end
	deco(folder, V3(28, 1, L - 14), V3(stageCX, KERB + 22.5, cz), C(30, 30, 34), M.Metal)
	screen(folder, CFrame.lookAt(V3(x1 - 1.5, KERB + 12, cz), V3(x1 - 10, KERB + 12, cz)), L - 26, 14, rng)
	for _, z in ipairs({ z0 + 16, cz, z1 - 16 }) do
		local spot = deco(folder, V3(1.4, 1.4, 1.4), V3(sx0 + 3, KERB + 21.6, z), C(255, 240, 210), M.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Left
		light.Range = 30
		light.Angle = 70
		light.Brightness = 2
		light.Parent = spot
	end
	-- Steel and glass canopies along the Yonge edge.
	for _, z in ipairs({ z0 + 18, z1 - 18 }) do
		for _, x in ipairs({ x0 + 4, x0 + 22 }) do
			solid(folder, V3(0.8, 14, 0.8), V3(x, KERB + 7, z), C(190, 192, 196), M.Metal)
		end
		local roof = glass(folder, V3(24, 0.5, 14), CFrame.new(x0 + 13, KERB + 14.6, z) * CFrame.Angles(0, 0, math.rad(-8)), C(210, 228, 236), 0.4)
		roof.CastShadow = false
	end
	-- Seating steps along the Shuter (south) edge, benches, trees, the name.
	for k = 0, 2 do
		solid(folder, V3(W - 50, 1.4 + k * 1.4, 2.6), V3(x0 + (W - 50) / 2 + 22, KERB + (1.4 + k * 1.4) / 2, z1 - 1.3 - k * 2.6), C(170, 164, 156), M.Granite)
	end
	for _, z in ipairs({ z0 + 6, z1 - 12 }) do
		local p = V3(x0 + 40, KERB, z)
		Kit.bench(folder, CFrame.lookAt(p, p + V3(0, 0, z < cz and 1 or -1)))
	end
	for _, p in ipairs({ Vector2.new(x0 + 8, z0 + 8), Vector2.new(x0 + 8, z1 - 30), Vector2.new(x1 - 34, z0 + 6) }) do
		solid(folder, V3(6, 2, 6), V3(p.X, KERB + 1, p.Y), C(150, 144, 136), M.Granite)
		Props.tree(folder, p, rng, 1)
	end
	sign(folder, CFrame.lookAt(V3(x0 + 13, KERB + 2.2, z0 + 1.5), V3(x0 + 13, KERB + 2.2, z0 - 4)), V3(22, 3, 0.6), "SANKOFA SQUARE", C(250, 200, 40), C(20, 20, 24))
	-- Light poles.
	for _, p in ipairs({ V3(x0 + 2, 0, z0 + 2), V3(x0 + 2, 0, z1 - 2), V3(sx0 - 4, 0, z0 + 2), V3(sx0 - 4, 0, z1 - 2) }) do
		solid(folder, V3(0.8, 20, 0.8), V3(p.X, KERB + 10, p.Z), C(60, 62, 66), M.Metal)
		local head = deco(folder, V3(2, 0.8, 2), V3(p.X, KERB + 20.4, p.Z), C(255, 246, 228), M.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 40
		light.Angle = 120
		light.Brightness = 1.6
		light.Parent = head
	end
end

---------------------------------------------------------------------------
-- Billboard canyon buildings
---------------------------------------------------------------------------
-- A commercial block whose `faces` ("north", "south", "east", "west") are covered
-- in giant screens above lit shopfronts.
function Landmarks.screenBuilding(folder, rect, height, faces, name, rng, corner)
	local x0, x1, z0, z1 = rect.minX, rect.maxX, rect.minZ, rect.maxZ
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local W, L = x1 - x0 - 2, z1 - z0 - 2
	solid(folder, V3(W, height, L), V3(cx, height / 2, cz), C(40, 42, 48), M.Concrete)
	deco(folder, V3(W + 1, 1.2, L + 1), V3(cx, height + 0.6, cz), C(24, 24, 28), M.Metal)
	local names = { "CITY CINEMAS", "BURGER BAR", "SNEAKER VAULT", "NOVA X", "PIZZA PALACE", "ARCADE 6IX", "TACO TUNNEL", "SOUND LAB" }
	for _, f in ipairs(faces) do
		local dir, along, len
		if f == "south" then
			dir, along, len = V3(0, 0, 1), V3(1, 0, 0), W
		elseif f == "north" then
			dir, along, len = V3(0, 0, -1), V3(1, 0, 0), W
		elseif f == "east" then
			dir, along, len = V3(1, 0, 0), V3(0, 0, 1), L
		else
			dir, along, len = V3(-1, 0, 0), V3(0, 0, 1), L
		end
		local half = (dir.X ~= 0) and W / 2 or L / 2
		local base = V3(cx, 0, cz) + dir * (half + 0.2)
		local function at(u, y)
			local p = base + along * u + V3(0, y, 0)
			return CFrame.lookAt(p, p + dir)
		end
		-- Shopfronts: glowing glass with names.
		local shopsN = math.max(2, math.floor(len / 24))
		for k = 0, shopsN - 1 do
			local u = -len / 2 + (k + 0.5) * len / shopsN
			-- Leave out the shops the corner restaurant covers (sw corner: the west
			-- end of the south face, the south end of the west face).
			if corner and ((f == "south" and u < -len / 2 + 36) or (f == "west" and u > len / 2 - 32)) then
				continue
			end
			local front = deco(folder, V3(len / shopsN - 2, 10, 0.3), at(u, KERB + 5.5) * CFrame.new(0, 0, -0.2), C(255, 236, 200), M.Glass)
			front.Transparency = 0.2
			Util.nightWindow(front, 0.6)
			sign(folder, at(u, KERB + 12.5) * CFrame.new(0, 0, -0.4), V3(len / shopsN - 3, 2.2, 0.3), Util.pick(rng, names), C(16, 16, 18), Util.pick(rng, { C(255, 214, 90), C(255, 255, 255), C(120, 230, 255), C(255, 120, 200) }))
		end
		-- Screens: one huge one, a tall one at the corner end, a ticker band.
		local big = math.min(len - 20, 64)
		screen(folder, at(-len / 2 + 6 + big / 2, KERB + 18 + (height - 26) / 2) * CFrame.new(0, 0, -0.6), big, math.min(height - 28, 34), rng)
		screen(folder, at(len / 2 - 9, KERB + 18 + (height - 26) / 2) * CFrame.new(0, 0, -0.6), 12, math.min(height - 24, 40), rng)
		local ticker = deco(folder, V3(len - 2, 2.4, 0.3), at(0, KERB + 16, 0) * CFrame.new(0, 0, -0.5), C(10, 10, 12), M.SmoothPlastic)
		ticker.CastShadow = false
		Util.sign(ticker, Front, "LIVE AT YONGE & DUNDAS  ·  NEW SEASON SALE  ·  CONCERT TONIGHT  ·  ", C(255, 80, 60), Enum.Font.Code).LightInfluence = 0
	end
	if name then
		sign(folder, CFrame.lookAt(V3(cx, height + 6, z1 - 6), V3(cx, height + 6, z1 + 4)), V3(math.min(W - 10, 60), 6, 0.6), name, C(20, 20, 24), C(255, 255, 255))
	end
	-- A corner restaurant: a two-storey glass box wrapping the corner that faces
	-- the intersection (corner = { name, side = "sw" | "se" }).
	if corner then
		local sx = corner.side == "se" and 1 or -1
		local ex = sx > 0 and x1 - 1 or x0 + 1 -- the building's outer edge (x)
		local ez = z1 - 1 -- south face
		local w, d, h = 34, 30, 24
		local bx, bz = ex - sx * w / 2, ez - d / 2
		-- Warm-lit glazing (plastic reads better than Glass at night) with black
		-- mullions every 5 studs on both street faces.
		local shell = deco(folder, V3(w + 1.2, h, d + 1.2), V3(bx, KERB + h / 2, bz), C(255, 226, 178), M.SmoothPlastic)
		shell.Transparency = 0.12
		shell.CastShadow = false
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 1.2
		light.Color = C(255, 214, 160)
		light.Parent = shell
		for t = 5, w - 1, 5 do
			deco(folder, V3(0.5, h, 0.4), V3(ex - sx * t, KERB + h / 2, ez + 0.9), C(22, 22, 24), M.Metal)
		end
		for t = 5, d - 1, 5 do
			deco(folder, V3(0.4, h, 0.5), V3(ex + sx * 0.9, KERB + h / 2, ez - t), C(22, 22, 24), M.Metal)
		end
		-- Black frame: corner post, floor band, cornice.
		deco(folder, V3(1.4, h + 2, 1.4), V3(ex + sx * 0.7, KERB + (h + 2) / 2, ez + 0.7), C(22, 22, 24), M.Metal)
		deco(folder, V3(w + 1.6, 1, d + 1.6), V3(bx, KERB + 12, bz), C(22, 22, 24), M.Metal)
		deco(folder, V3(w + 2, 2, d + 2), V3(bx, KERB + h + 1, bz), C(22, 22, 24), M.Metal)
		-- Name signs on both street faces, lit.
		local red = C(196, 44, 36)
		sign(folder, CFrame.lookAt(V3(bx, KERB + h - 4, ez + 1.2), V3(bx, KERB + h - 4, ez + 10)), V3(w - 6, 4, 0.4), corner.name, red, C(255, 248, 232))
		local fx = ex + sx * 1.2
		sign(folder, CFrame.lookAt(V3(fx, KERB + h - 4, bz), V3(fx + sx * 10, KERB + h - 4, bz)), V3(d - 6, 4, 0.4), corner.name, red, C(255, 248, 232))
		-- Awning over the corner door.
		deco(folder, V3(10, 0.5, 4), V3(ex - sx * 6, KERB + 10.5, ez + 2.6), red, M.Fabric)
	end
	CollectionService:AddTag(folder, "BillboardCanyon")
end

---------------------------------------------------------------------------
-- Toronto Metropolitan University
---------------------------------------------------------------------------
local TMU_BLUE, TMU_GOLD = C(0, 76, 155), C(255, 220, 0)

function Landmarks.tmu(folder, slc, kerr, south, rng)
	-- Student learning centre: a glass block on Yonge with white floor bands.
	do
		local cx, cz = (slc.minX + slc.maxX) / 2, (slc.minZ + slc.maxZ) / 2
		local w, d, h = slc.maxX - slc.minX - 4, slc.maxZ - slc.minZ - 4, 84
		local body = solid(folder, V3(w, h, d), V3(cx, h / 2, cz), C(110, 150, 190), M.Glass)
		body.Reflectance = 0.2
		Util.nightWindow(body, 0.5)
		for y = 12, h - 4, 10 do
			deco(folder, V3(w + 0.6, 1.2, d + 0.6), V3(cx, y, cz), C(236, 240, 244), M.SmoothPlastic)
		end
		-- Big angled entrance canopy on Yonge (west face), the TMU sign.
		deco(folder, V3(10, 1, 40), CFrame.new(slc.minX - 2, 16, cz) * CFrame.Angles(0, 0, math.rad(-12)), C(240, 240, 240), M.Metal)
		sign(folder, CFrame.lookAt(V3(slc.minX + 1.6, 70, cz), V3(slc.minX - 4, 70, cz)), V3(30, 10, 0.4), "TMU", TMU_BLUE, TMU_GOLD)
		sign(folder, CFrame.lookAt(V3(slc.minX + 1.6, 26, cz), V3(slc.minX - 4, 26, cz)), V3(46, 3, 0.4), "STUDENT LEARNING CENTRE", C(20, 20, 24), C(255, 255, 255))
	end
	-- Kerr Hall: four-storey stone quad round a courtyard, arched gate on the south.
	do
		local x0, x1, z0, z1 = kerr.minX + 2, kerr.maxX - 2, kerr.minZ + 2, kerr.maxZ - 2
		local t, h = 14, 42
		local stone = C(170, 156, 136)
		local lawn = solid(folder, V3(x1 - x0, 1, z1 - z0), V3((x0 + x1) / 2, KERB - 0.5, (z0 + z1) / 2), C(90, 116, 66), M.Grass)
		lawn.CastShadow = false
		solid(folder, V3(x1 - x0, h, t), V3((x0 + x1) / 2, h / 2, z0 + t / 2), stone, M.Brick)
		solid(folder, V3(t, h, z1 - z0), V3(x0 + t / 2, h / 2, (z0 + z1) / 2), stone, M.Brick)
		solid(folder, V3(t, h, z1 - z0), V3(x1 - t / 2, h / 2, (z0 + z1) / 2), stone, M.Brick)
		local gate = 14
		local mid = (x0 + x1) / 2
		for _, s in ipairs({ -1, 1 }) do
			local segW = (x1 - x0 - gate) / 2
			solid(folder, V3(segW, h, t), V3(mid + s * (gate / 2 + segW / 2), h / 2, z1 - t / 2), stone, M.Brick)
		end
		solid(folder, V3(gate, h - 16, t), V3(mid, 16 + (h - 16) / 2, z1 - t / 2), stone, M.Brick)
		for y = 8, h - 6, 10 do
			for _, info in ipairs({ { V3(mid, y, z1 + 0.2), V3(x1 - x0 - 4, 4, 0.3) }, { V3(mid, y, z0 - 0.2), V3(x1 - x0 - 4, 4, 0.3) } }) do
				local band = deco(folder, info[2], info[1], C(50, 56, 62), M.Glass)
				Util.nightWindow(band, 0.4)
			end
		end
		for _ = 1, 5 do
			Props.tree(folder, Vector2.new(rng:NextNumber(x0 + t + 6, x1 - t - 6), rng:NextNumber(z0 + t + 6, z1 - t - 6)), rng, 1.1)
		end
		sign(folder, CFrame.lookAt(V3(mid, 18.5, z1 + 0.4), V3(mid, 18.5, z1 + 4)), V3(16, 2.4, 0.3), "KERR HALL · TMU", TMU_BLUE, TMU_GOLD)
	end
	-- South: a glass residence tower on a podium.
	do
		local cx, cz = (south.minX + south.maxX) / 2, (south.minZ + south.maxZ) / 2
		local w, d = south.maxX - south.minX - 4, south.maxZ - south.minZ - 4
		solid(folder, V3(w, 22, d), V3(cx, 11, cz), C(60, 66, 74), M.Concrete)
		local tower = solid(folder, V3(w * 0.55, 150, d * 0.6), V3(cx, 22 + 75, cz), C(90, 120, 150), M.Glass)
		Util.nightWindow(tower, 0.5)
		for y = 32, 168, 14 do
			deco(folder, V3(w * 0.55 + 0.6, 1, d * 0.6 + 0.6), V3(cx, y, cz), C(236, 240, 244), M.SmoothPlastic)
		end
		sign(folder, CFrame.lookAt(V3(cx, 16, south.maxZ - 1.4), V3(cx, 16, south.maxZ + 4)), V3(36, 4, 0.3), "TORONTO METROPOLITAN UNIVERSITY", TMU_BLUE, TMU_GOLD)
	end
end

---------------------------------------------------------------------------
-- University of Toronto
---------------------------------------------------------------------------
local SANDSTONE = C(184, 160, 124)
local GOTHIC = C(176, 166, 146)

-- Stone tower with a pyramid roof.
local function tower(folder, x, z, w, h, colour)
	solid(folder, V3(w, h, w), V3(x, h / 2, z), colour, M.Sandstone)
	for k = 0, 3 do
		local s = w * (1 - k / 4) + 0.6
		solid(folder, V3(s, 3, s), V3(x, h + 1.5 + k * 3, z), C(70, 74, 72), M.Slate)
	end
end

function Landmarks.uoft(folder, southRect, northRect, rng)
	for _, rect in ipairs({ southRect, northRect }) do
		local g = solid(folder, V3(rect.maxX - rect.minX, 1, rect.maxZ - rect.minZ), V3((rect.minX + rect.maxX) / 2, KERB - 0.6, (rect.minZ + rect.maxZ) / 2), C(92, 118, 68), M.Grass)
		g.CastShadow = false
	end
	-- South block: King's College Circle (oval lawn and path), University College
	-- to the north of it, Convocation Hall to the south.
	local x0, x1, z0, z1 = southRect.minX, southRect.maxX, southRect.minZ, southRect.maxZ
	local cx = (x0 + x1) / 2
	local circleZ = (z0 + z1) / 2 + 10
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		local p = V3(cx + math.cos(a) * 52, KERB + 0.05, circleZ + math.sin(a) * 70)
		local nextA = (k + 1) / 24 * math.pi * 2
		local q = V3(cx + math.cos(nextA) * 52, KERB + 0.05, circleZ + math.sin(nextA) * 70)
		deco(folder, V3(6, 0.1, (q - p).Magnitude + 1), CFrame.lookAt((p + q) / 2, q), C(176, 168, 150), M.Pavement).CastShadow = false
	end
	-- University College: Romanesque stone, steep roofs, a central tower.
	do
		local w, d, h = x1 - x0 - 16, 46, 30
		local zc = z0 + 10 + d / 2
		local body = solid(folder, V3(w, h, d), V3(cx, h / 2, zc), SANDSTONE, M.Sandstone)
		Util.texture(body, Enum.NormalId.Back, "limestone", 12, 12)
		local pitch = math.rad(40)
		local slope = (d / 2 + 1) / math.cos(pitch)
		local rise = (d / 2) * math.tan(pitch)
		for _, s in ipairs({ -1, 1 }) do
			solid(folder, V3(w + 1, 0.8, slope), CFrame.new(cx, h + rise / 2, zc + s * d / 4) * CFrame.Angles(s * pitch, 0, 0), C(64, 70, 68), M.Slate)
		end
		tower(folder, cx, zc + d / 2 - 6, 16, h + 26, SANDSTONE)
		for k = -5, 5 do
			if k ~= 0 then
				deco(folder, V3(4, 10, 0.3), V3(cx + k * (w / 12), 14, zc + d / 2 + 0.2), C(50, 56, 60), M.Glass)
			end
		end
		sign(folder, CFrame.lookAt(V3(cx, 8, zc + d / 2 + 0.6), V3(cx, 8, zc + d / 2 + 4)), V3(26, 2.4, 0.3), "UNIVERSITY COLLEGE", SANDSTONE, C(40, 34, 28))
	end
	-- Convocation Hall: round, domed, with a columned portico facing the circle.
	do
		local hx, hz, r, h = cx, z1 - 40, 30, 28
		local panels = 20
		for k = 0, panels - 1 do
			local a = k / panels * math.pi * 2
			local pos = V3(hx + math.cos(a) * r, h / 2, hz + math.sin(a) * r)
			solid(folder, V3(2 * math.pi * r / panels + 0.6, h, 3), CFrame.lookAt(pos, V3(hx, h / 2, hz)), C(196, 184, 160), M.Limestone)
		end
		for i, ring in ipairs({ { r + 1, h }, { r * 0.85, h + 6 }, { r * 0.62, h + 10.5 }, { r * 0.36, h + 13 } }) do
			Util.cylinder(folder, 3, ring[1] * 2, CFrame.new(hx, ring[2] + 1.5, hz), i % 2 == 1 and C(150, 170, 160) or C(130, 150, 140), M.Metal, true)
		end
		local front = hz - r - 6
		for k = -3, 3 do
			Util.cylinder(folder, 22, 2.4, CFrame.new(hx + k * 6, KERB + 11, front), C(220, 214, 200), M.Limestone, true)
		end
		solid(folder, V3(46, 4, 10), V3(hx, KERB + 24, front + 2), C(220, 214, 200), M.Limestone)
		sign(folder, CFrame.lookAt(V3(hx, KERB + 24, front - 3.1), V3(hx, KERB + 24, front - 8)), V3(30, 2.4, 0.2), "CONVOCATION HALL", C(220, 214, 200), C(60, 50, 40))
	end
	sign(folder, CFrame.lookAt(V3(cx, KERB + 3, z1 - 3), V3(cx, KERB + 3, z1 + 4)), V3(40, 4, 1.6), "UNIVERSITY OF TORONTO", C(0, 42, 92), C(255, 255, 255))
	for _ = 1, 12 do
		local p = Vector2.new(rng:NextNumber(x0 + 6, x1 - 6), rng:NextNumber(circleZ - 60, circleZ + 40))
		if math.abs(p.X - cx) > 12 then
			Props.tree(folder, p, rng, 1.2)
		end
	end

	-- North block: Hart House (Gothic, with its tower) and Robarts Library.
	x0, x1, z0, z1 = northRect.minX, northRect.maxX, northRect.minZ, northRect.maxZ
	cx = (x0 + x1) / 2
	do
		local w, d, h = x1 - x0 - 24, 64, 32
		local zc = z1 - 10 - d / 2
		solid(folder, V3(w, h, d), V3(cx, h / 2, zc), GOTHIC, M.Sandstone)
		for x = cx - w / 2 + 2, cx + w / 2 - 2, 4 do
			solid(folder, V3(2, 3, d + 0.4), V3(x, h + 1.5, zc), GOTHIC, M.Sandstone)
		end
		tower(folder, cx + w / 2 - 10, zc - d / 2 + 10, 18, h + 34, GOTHIC)
		for k = -4, 4 do
			deco(folder, V3(3, 12, 0.3), V3(cx + k * (w / 10), 16, zc + d / 2 + 0.2), C(50, 56, 60), M.Glass)
		end
		sign(folder, CFrame.lookAt(V3(cx, 7, zc + d / 2 + 0.6), V3(cx, 7, zc + d / 2 + 4)), V3(18, 2.4, 0.3), "HART HOUSE", GOTHIC, C(40, 34, 28))
	end
	do
		-- Robarts Library: a concrete podium and a tower turned on the diagonal
		-- that widens toward the top, with deep vertical fins.
		local zc = z0 + 80
		local concrete = C(156, 150, 140)
		solid(folder, V3(x1 - x0 - 20, 16, 110), V3(cx, 8, zc), concrete, M.Concrete)
		local base = CFrame.new(cx, 16, zc) * CFrame.Angles(0, math.rad(45), 0)
		local tiers = { { 54, 30 }, { 62, 22 }, { 70, 22 } }
		local y = 0
		for _, tier in ipairs(tiers) do
			solid(folder, V3(tier[1], tier[2], tier[1]), base * CFrame.new(0, y + tier[2] / 2, 0), concrete, M.Concrete)
			for k = -2, 2 do
				for _, s in ipairs({ -1, 1 }) do
					deco(folder, V3(1.6, tier[2] - 2, 3), base * CFrame.new(k * tier[1] / 5, y + tier[2] / 2, s * (tier[1] / 2 + 1)), Util.shade(concrete, 0.85), M.Concrete)
				end
			end
			y = y + tier[2]
		end
		sign(folder, CFrame.lookAt(V3(cx, 12, zc + 55.6), V3(cx, 12, zc + 60)), V3(26, 3, 0.3), "ROBARTS LIBRARY", C(60, 58, 54), C(240, 240, 236))
	end
end

return Landmarks
