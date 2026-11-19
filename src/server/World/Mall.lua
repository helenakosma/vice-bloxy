-- Yorkgate Centre: a walk-in two-level shopping mall.
--
-- A glass-roofed galleria runs the length of the building with shops on both sides
-- on both levels, upper walkways with glass railings and two bridges, two pairs of
-- escalators, a fountain, kiosks and a food court. Sliding doors at each end and
-- on the parking-lot side. Food counters use the shared purchase system.
local Util = require(script.Parent.Util)
local Facade = require(script.Parent.Facade)
local Stores = require(script.Parent.Stores)

local Mall = {}

local V3 = Vector3.new
local M = Enum.Material
local Front = Enum.NormalId.Front

local LENGTH, DEPTH = 176, 88 -- building footprint (x by z)
local LEVEL = 17 -- height of the upper floor
local ROOF = 34
local CORRIDOR = 28 -- galleria width
local VOID = 16 -- open well in the upper floor over the galleria
local UNIT = 22 -- shop width
local ESCALATOR_X = 34 -- escalator pairs sit this far either side of the fountain
local BRIDGE_X = 52.6 -- bridges across the well, at the escalators' top ends
local WHITE = Color3.fromRGB(238, 236, 230)
local FLOOR = Color3.fromRGB(226, 222, 214)
local WALL = { color = WHITE, material = M.Plaster }
local TRIM = { color = Color3.fromRGB(200, 198, 192), material = M.Concrete }

local SHOPS = {
	"URBAN THREADS", "PIXEL GAMES", "SOLE SHOP", "NORTH OUTFITTERS", "GLOW BEAUTY", "MAPLE BOOKS",
	"VOLT ELECTRONICS", "SUNGLASS STOP", "TEA HOUSE", "PETAL & CO", "KIDZONE", "DENIM BAR",
	"BEAN STREET COFFEE", "WATCH WORKS", "LUXE JEWELLERS", "SPORT CHECKPOINT",
}

local function kerb()
	return Util.WALK_TOP
end

-- Simple upper-level shopfront: glass, sign band and a lit interior picture.
local function upperShop(folder, cf, name, rng)
	local y0 = LEVEL + 0.6
	local h = ROOF - LEVEL - 3
	Util.deco(folder, V3(UNIT - 2, 2.6, 0.6), cf * CFrame.new(0, y0 + h - 1.3, 0), Color3.fromRGB(30, 32, 34), M.SmoothPlastic)
	local sign = Util.deco(folder, V3(UNIT - 4, 2, 0.1), cf * CFrame.new(0, y0 + h - 1.3, -0.35), Color3.fromRGB(30, 32, 34), M.SmoothPlastic)
	Util.sign(sign, Front, name, Color3.fromRGB(245, 240, 225), Enum.Font.GothamBold).LightInfluence = 0.2
	local glass = Util.solid(folder, V3(UNIT - 2, h - 2.6, 0.2), cf * CFrame.new(0, y0 + (h - 2.6) / 2, 0), Color3.fromRGB(176, 190, 196), M.Glass)
	glass.Transparency = 0.55
	local back = Util.deco(folder, V3(UNIT - 2, h - 2.6, 0.2), cf * CFrame.new(0, y0 + (h - 2.6) / 2, 6), Color3.fromRGB(200, 180, 150), M.SmoothPlastic)
	Util.decal(back, Front, rng:NextNumber() < 0.5 and "storefront_boutique" or "storefront_deli")
	local light = Instance.new("SurfaceLight")
	light.Face = Front
	light.Range = 8
	light.Brightness = 0.8
	light.Parent = back
	Util.deco(folder, V3(UNIT - 2, 0.2, 6), cf * CFrame.new(0, y0 + 0.1, 3), Color3.fromRGB(180, 170, 156), M.Marble)
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(0.6, h, 6.4), cf * CFrame.new(side * (UNIT / 2 - 0.3), y0 + h / 2, 3), WHITE, M.Plaster)
	end
end

-- Food-court counter unit with a menu, counter and a purchase prompt.
local function foodCounter(folder, cf, name, kind, colour)
	local k = kerb()
	Util.solid(folder, V3(UNIT - 1, LEVEL - k, 0.6), cf * CFrame.new(0, k + (LEVEL - k) / 2, 9), colour, M.SmoothPlastic)
	local counter = Util.solid(folder, V3(UNIT - 4, 3.6, 2.6), cf * CFrame.new(0, k + 1.8, 2), Color3.fromRGB(60, 60, 64), M.Metal)
	Util.deco(folder, V3(UNIT - 3.6, 0.2, 2.9), cf * CFrame.new(0, k + 3.7, 2), Color3.fromRGB(230, 226, 220), M.Marble)
	Stores.attachPurchase(counter, kind, name)
	local menu = Util.deco(folder, V3(12, 4.5, 0.2), cf * CFrame.new(0, k + 9, 8.6), Color3.fromRGB(30, 30, 30), M.SmoothPlastic)
	if not Util.decal(menu, Front, "menu_board") then
		Util.sign(menu, Front, name, Color3.fromRGB(240, 230, 200), Enum.Font.GothamBold)
	end
	local sign = Util.deco(folder, V3(UNIT - 3, 2.4, 0.4), cf * CFrame.new(0, k + 13.5, 0), colour, M.SmoothPlastic)
	Util.sign(sign, Front, name, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack).LightInfluence = 0
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(0.6, LEVEL - k, 10), cf * CFrame.new(side * (UNIT / 2 - 0.3), k + (LEVEL - k) / 2, 4), WHITE, M.Plaster)
	end
end

local function escalator(folder, from, to, width, up)
	local length = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	Util.solid(folder, V3(width, 0.6, length), cf, Color3.fromRGB(110, 112, 116), M.DiamondPlate)
	for _, side in ipairs({ -1, 1 }) do
		local glass = Util.solid(folder, V3(0.2, 3, length), cf * CFrame.new(side * (width / 2 + 0.1), 1.8, 0), Color3.fromRGB(200, 220, 228), M.Glass)
		glass.Transparency = 0.5
		Util.deco(folder, V3(0.5, 0.4, length), cf * CFrame.new(side * (width / 2 + 0.1), 3.4, 0), Color3.fromRGB(20, 20, 22), M.Rubber)
		Util.solid(folder, V3(1, (to.Y - from.Y) * 0.5 + 2, length * 0.9), cf * CFrame.new(side * (width / 2 + 0.6), -2.5, 0), Color3.fromRGB(190, 192, 196), M.Metal)
	end
	local arrow = Util.deco(folder, V3(1, 0.6, 0.1), cf * CFrame.new(0, 3.6, -length / 2 + 0.5), up and Color3.fromRGB(60, 220, 100) or Color3.fromRGB(240, 60, 60), M.Neon)
	arrow.CastShadow = false
end

local function fountain(folder, pos)
	Util.cylinder(folder, 1.8, 16, CFrame.new(pos.X, kerb() + 0.9, pos.Z), Color3.fromRGB(200, 196, 188), M.Marble, true)
	local water = Util.cylinder(folder, 0.3, 14.6, CFrame.new(pos.X, kerb() + 1.6, pos.Z), Color3.fromRGB(80, 150, 190), M.Glass, false)
	water.Reflectance = 0.4
	water.Transparency = 0.2
	Util.cylinder(folder, 4, 2, CFrame.new(pos.X, kerb() + 3, pos.Z), Color3.fromRGB(200, 196, 188), M.Marble, true)
	local jet = Util.deco(folder, V3(1, 0.2, 1), CFrame.new(pos.X, kerb() + 5.1, pos.Z), Color3.new(1, 1, 1), M.SmoothPlastic)
	jet.Transparency = 1
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 60
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Speed = NumberRange.new(14, 18)
	spray.SpreadAngle = Vector2.new(10, 10)
	spray.Acceleration = V3(0, -40, 0)
	spray.Size = NumberSequence.new(0.35)
	spray.Transparency = NumberSequence.new(0.3)
	spray.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	spray.Parent = jet
end

local function kiosk(folder, pos, name, colour)
	local base = CFrame.new(pos.X, kerb(), pos.Z)
	Util.solid(folder, V3(8, 3.6, 5), base * CFrame.new(0, 1.8, 0), colour, M.SmoothPlastic)
	Util.deco(folder, V3(8.6, 0.3, 5.6), base * CFrame.new(0, 3.75, 0), WHITE, M.Marble)
	for _, x in ipairs({ -3.8, 3.8 }) do
		Util.deco(folder, V3(0.3, 5, 0.3), base * CFrame.new(x, 6.3, 0), Color3.fromRGB(40, 40, 40), M.Metal)
	end
	local top = Util.deco(folder, V3(9, 1.6, 6), base * CFrame.new(0, 9.4, 0), colour, M.SmoothPlastic)
	Util.sign(top, Front, name, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold).LightInfluence = 0
	Util.sign(top, Enum.NormalId.Back, name, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold).LightInfluence = 0
end

local function bench(folder, pos, yaw)
	local base = CFrame.new(pos.X, kerb(), pos.Z) * CFrame.Angles(0, yaw, 0)
	Util.solid(folder, V3(7, 1.6, 2.2), base * CFrame.new(0, 0.8, 0), Color3.fromRGB(120, 86, 56), M.Wood)
end

local function planter(folder, pos)
	Util.solid(folder, V3(5, 2.4, 5), CFrame.new(pos.X, kerb() + 1.2, pos.Z), Color3.fromRGB(70, 70, 74), M.Concrete)
	local leaves = Util.deco(folder, V3(6, 6, 6), CFrame.new(pos.X, kerb() + 5, pos.Z), Color3.fromRGB(60, 120, 64), M.LeafyGrass, Enum.PartType.Ball)
	leaves.CastShadow = false
end

-- Entrance vestibule with sliding doors in an outer wall. cf faces outward.
local function entrance(folder, cf, width)
	local k = kerb()
	local h = 12
	for _, side in ipairs({ -1, 1 }) do
		local panel = Util.solid(folder, V3(width / 2, h - 1, 0.3), cf * CFrame.new(side * width / 4, k + (h - 1) / 2, 0), Color3.fromRGB(176, 196, 204), M.Glass)
		panel.Transparency = 0.45
		panel:SetAttribute("SlideX", side * (width / 2 - 0.3))
		panel:AddTag("AutoDoor")
	end
	Util.deco(folder, V3(width + 1, 1, 0.8), cf * CFrame.new(0, k + h, 0), Color3.fromRGB(60, 60, 64), M.Metal)
	local canopy = Util.deco(folder, V3(width + 8, 0.8, 8), cf * CFrame.new(0, k + h + 3, -4), Color3.fromRGB(60, 60, 64), M.Metal)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 12
	light.Brightness = 1
	light.Color = Color3.fromRGB(255, 232, 196)
	light.Parent = canopy
end

-- Outer wall along one side, with an opening of `gap` studs centred at `gapAt`.
local function wallWithGap(folder, a, b, height, gapAt, gap)
	local dir = (b - a).Unit
	local length = (b - a).Magnitude
	local pieces = { { 0, length } }
	if gapAt then
		pieces = { { 0, gapAt - gap / 2 }, { gapAt + gap / 2, length } }
	end
	for _, piece in ipairs(pieces) do
		local l = piece[2] - piece[1]
		if l > 0.5 then
			local mid = a + dir * ((piece[1] + piece[2]) / 2)
			local cf = CFrame.lookAt(V3(mid.X, height / 2, mid.Z), V3(mid.X + dir.Z, height / 2, mid.Z - dir.X))
			local wall = Util.solid(folder, V3(l, height, 2), cf, Color3.fromRGB(206, 198, 186), M.Concrete)
			Util.texture(wall, Front, "concrete_stained", 14, 14)
			Util.texture(wall, Enum.NormalId.Back, "concrete_stained", 14, 14)
		end
	end
end

function Mall.build(folder, centre, rng)
	local cx, cz = centre.X, centre.Y - 20 -- building sits toward the back of the lot
	local x0, x1 = cx - LENGTH / 2, cx + LENGTH / 2
	local zN, zS = cz - DEPTH / 2, cz + DEPTH / 2 -- north (back) and south (parking) walls
	local corridorZ = cz -- galleria runs along x through the middle
	local k = kerb()

	-- Floor, roof and outer walls (openings for the three entrances).
	Util.solid(folder, V3(LENGTH, 1, DEPTH), CFrame.new(cx, k - 0.5, cz), FLOOR, M.Marble)
	local doorW = 12
	wallWithGap(folder, V3(x0, 0, zN), V3(x1, 0, zN), ROOF, nil, 0)
	wallWithGap(folder, V3(x0, 0, zS), V3(x1, 0, zS), ROOF, LENGTH / 2, doorW + 2)
	wallWithGap(folder, V3(x0, 0, zN), V3(x0, 0, zS), ROOF, DEPTH / 2, doorW + 2)
	wallWithGap(folder, V3(x1, 0, zN), V3(x1, 0, zS), ROOF, DEPTH / 2, doorW + 2)
	for _, info in ipairs({
		{ V3(cx, 0, zS), V3(0, 0, 1) },
		{ V3(x0, 0, corridorZ), V3(-1, 0, 0) },
		{ V3(x1, 0, corridorZ), V3(1, 0, 0) },
	}) do
		local pos, out = info[1], info[2]
		entrance(folder, CFrame.lookAt(pos, pos + out), doorW)
		Util.solid(folder, V3(doorW + 2, ROOF - k - 13, 2), CFrame.lookAt(pos, pos + out) * CFrame.new(0, k + 13 + (ROOF - k - 13) / 2, 0), Color3.fromRGB(206, 198, 186), M.Concrete)
	end
	-- Solid roof over the shops, glass vault over the galleria.
	local shopDepth = (DEPTH - CORRIDOR) / 2
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(LENGTH, 2, shopDepth), CFrame.new(cx, ROOF + 1, corridorZ + side * (CORRIDOR / 2 + shopDepth / 2)), Color3.fromRGB(150, 146, 140), M.Concrete)
		local pane = Util.solid(folder, V3(LENGTH, 0.4, CORRIDOR / 2 + 1), CFrame.new(cx, ROOF + 3.5, corridorZ + side * CORRIDOR / 4) * CFrame.Angles(math.rad(side * 18), 0, 0), Color3.fromRGB(190, 214, 226), M.Glass)
		pane.Transparency = 0.45
		pane.CastShadow = false
	end
	for x = x0 + 8, x1 - 8, 12 do
		for _, side in ipairs({ -1, 1 }) do
			local a = V3(x, ROOF + 0.6, corridorZ + side * CORRIDOR / 2)
			local b = V3(x, ROOF + 6.6, corridorZ)
			Util.beam(folder, a, b, 0.6, Color3.fromRGB(240, 240, 240), M.Metal)
		end
	end

	-- Upper floor: slabs over the shops plus walkways, leaving the central well open.
	local walkway = (CORRIDOR - VOID) / 2
	for _, side in ipairs({ -1, 1 }) do
		local slabD = shopDepth + walkway
		local slabZ = corridorZ + side * (VOID / 2 + slabD / 2)
		local slab = Util.solid(folder, V3(LENGTH, 1.2, slabD), CFrame.new(cx, LEVEL, slabZ), FLOOR, M.Marble)
		for _, x in ipairs({ x0 + 30, cx, x1 - 30 }) do
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = 16
			light.Brightness = 1.1
			light.Color = Color3.fromRGB(255, 244, 228)
			local holder = Util.deco(folder, V3(4, 0.2, 2), CFrame.new(x, LEVEL - 0.7, slabZ), Color3.fromRGB(255, 252, 240), M.Neon)
			light.Parent = holder
		end
		slab.Name = "UpperFloor"
		-- Glass railing along the well, open where the bridges cross.
		local edgeZ = corridorZ + side * VOID / 2
		local last = x0
		local gaps = { cx - BRIDGE_X - 4, cx + BRIDGE_X - 4 }
		table.insert(gaps, x1)
		for _, gapStart in ipairs(gaps) do
			local l = gapStart - last
			if l > 0.5 then
				local mx = (last + gapStart) / 2
				local rail = Util.solid(folder, V3(l, 3.4, 0.25), CFrame.new(mx, LEVEL + 2.3, edgeZ), Color3.fromRGB(200, 220, 228), M.Glass)
				rail.Transparency = 0.5
				Util.deco(folder, V3(l, 0.3, 0.6), CFrame.new(mx, LEVEL + 4.1, edgeZ), Color3.fromRGB(200, 200, 204), M.Metal)
			end
			last = gapStart + 8
		end
	end
	-- Bridges across the well (also the escalators' top landings).
	for _, bx in ipairs({ cx - BRIDGE_X, cx + BRIDGE_X }) do
		Util.solid(folder, V3(8, 1.2, VOID), CFrame.new(bx, LEVEL, corridorZ), FLOOR, M.Marble)
		for _, side in ipairs({ -1, 1 }) do
			local rail = Util.solid(folder, V3(0.25, 3.4, VOID), CFrame.new(bx + side * 4, LEVEL + 2.3, corridorZ), Color3.fromRGB(200, 220, 228), M.Glass)
			rail.Transparency = 0.5
		end
	end

	-- Shops along both sides on both levels. The west end of the south side is the
	-- food court.
	local units = math.floor((LENGTH - 16) / UNIT)
	local startX = cx - units * UNIT / 2 + UNIT / 2
	local nameIndex = rng:NextInteger(1, #SHOPS)
	local function nextName()
		nameIndex = nameIndex % #SHOPS + 1
		return SHOPS[nameIndex]
	end
	local food = {
		{ "SLICE OF ROME", "pizza", Color3.fromRGB(180, 40, 36) },
		{ "BEAN STREET", "coffee", Color3.fromRGB(40, 70, 60) },
		{ "DELI EXPRESS", "bodega", Color3.fromRGB(200, 140, 30) },
	}
	for _, side in ipairs({ -1, 1 }) do
		local frontZ = corridorZ + side * CORRIDOR / 2
		local facing = Vector2.new(0, -side) -- shops face the galleria
		for u = 0, units - 1 do
			local x = startX + u * UNIT
			local shopCentre = Vector2.new(x, frontZ + side * shopDepth / 2)
			local cf = Util.groundCF(shopCentre, facing, 0)
			if side == 1 and u < #food then
				local f = food[u + 1]
				foodCounter(folder, Util.groundCF(Vector2.new(x, frontZ + side * 3), facing, 0) * CFrame.new(0, 0, 0), f[1], f[2], f[3])
			else
				Facade.storefront(folder, cf, UNIT, shopDepth, {
					groundH = LEVEL - 0.6,
					wall = WALL,
					trim = TRIM,
					name = nextName(),
					signColor = Util.pick(rng, { Color3.fromRGB(28, 30, 32), Color3.fromRGB(240, 238, 232), Color3.fromRGB(20, 40, 70), Color3.fromRGB(110, 24, 30) }),
					textColor = Color3.fromRGB(250, 246, 236),
					interior = rng:NextNumber() < 0.5 and "deli" or "boutique",
				}, rng)
				-- Close the shop at the back so it reads as a room.
				Util.solid(folder, V3(UNIT, LEVEL - 0.6, 1), cf * CFrame.new(0, (LEVEL - 0.6) / 2, shopDepth / 2 - 0.5), WHITE, M.Plaster)
			end
			-- Upper-level shop, set back behind the walkway.
			local upperCF = Util.groundCF(Vector2.new(x, frontZ + side * 0.1), facing, 0)
			upperShop(folder, upperCF, nextName(), rng)
		end
	end

	-- Galleria: escalators, fountain, kiosks, food-court seating, benches, plants.
	local rise = LEVEL + 0.6 - k
	local run = rise / math.tan(math.rad(30))
	for _, info in ipairs({ { cx - ESCALATOR_X, -1 }, { cx + ESCALATOR_X, 1 } }) do
		local ex, dirX = info[1], info[2]
		local zA, zB = corridorZ - 3.4, corridorZ + 3.4
		escalator(folder, V3(ex - dirX * run / 2, k + 0.3, zA), V3(ex + dirX * run / 2, LEVEL + 0.6, zA), 5, true)
		escalator(folder, V3(ex + dirX * run / 2, LEVEL + 0.6, zB), V3(ex - dirX * run / 2, k + 0.3, zB), 5, false)
	end
	fountain(folder, V3(cx, 0, corridorZ))
	kiosk(folder, V3(cx + 60, 0, corridorZ), "PHONE CASES", Color3.fromRGB(40, 100, 180))
	kiosk(folder, V3(cx - 64, 0, corridorZ - 3), "PRETZELS", Color3.fromRGB(200, 120, 30))
	for _, x in ipairs({ x0 + 12, x0 + 30, x0 + 48 }) do
		local base = CFrame.new(x, k, corridorZ + 8)
		Util.cylinder(folder, 0.25, 4, base * CFrame.new(0, 3.1, 0), WHITE, M.Marble, true)
		Util.cylinder(folder, 3, 0.4, base * CFrame.new(0, 1.5, 0), Color3.fromRGB(40, 40, 40), M.Metal, false)
		for _, off in ipairs({ -2.6, 2.6 }) do
			Util.solid(folder, V3(1.6, 2.2, 1.6), base * CFrame.new(off, 1.1, 0), Color3.fromRGB(200, 60, 50), M.SmoothPlastic)
		end
	end
	for _, x in ipairs({ cx - 36, cx + 34, cx + 76 }) do
		bench(folder, V3(x, 0, corridorZ - 9), 0)
	end
	for _, x in ipairs({ x0 + 6, x1 - 6 }) do
		planter(folder, V3(x, 0, corridorZ - 10))
		planter(folder, V3(x, 0, corridorZ + 10))
	end
	-- Hanging banners in the well.
	for _, x in ipairs({ cx - 70, cx + 70 }) do
		local banner = Util.deco(folder, V3(0.2, 10, 5), CFrame.new(x, ROOF - 6, corridorZ), Color3.fromRGB(150, 30, 40), M.Fabric)
		Util.sign(banner, Enum.NormalId.Left, "YORKGATE", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
		Util.sign(banner, Enum.NormalId.Right, "YORKGATE", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
	end

	-- Outside: big sign over the main entrance.
	local sign = Util.deco(folder, V3(56, 7, 0.6), CFrame.new(cx, ROOF - 6, zS + 1.4), Color3.fromRGB(240, 238, 232), M.SmoothPlastic)
	Util.sign(sign, Enum.NormalId.Back, "YORKGATE CENTRE", Color3.fromRGB(150, 30, 40), Enum.Font.GothamBlack).LightInfluence = 0
	return { southWallZ = zS }
end

return Mall
