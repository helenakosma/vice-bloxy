-- Downtown Toronto landmarks around Yonge & Dundas, plus the two universities:
--
--   eatonCentre    Yonge St, Queen to Dundas, back to Bay. Three shopping levels
--                  round a long galleria under a glass barrel vault; balconies,
--                  escalators, an elevator, a food court, and entrances from
--                  Yonge, Queen, Dundas and Bay.
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
local Stores = require(script.Parent.Stores)
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
-- Eaton Centre
---------------------------------------------------------------------------
local EC_SHOPS = {
	{ "NORTHSTAR OUTFITTERS", C(40, 60, 90), "clothes" }, { "METRO THREADS", C(20, 20, 24), "clothes" },
	{ "NOVA X STORE", C(18, 24, 48), "electronics" }, { "MAPLE BOOKS", C(120, 30, 40), nil },
	{ "SNEAKER VAULT", C(230, 90, 40), "clothes" }, { "FROSTY'S", C(120, 210, 230), "coffee" },
	{ "LUXE BEAUTY", C(220, 160, 180), "pharmacy" }, { "PIXEL GAMES", C(60, 30, 120), "electronics" },
	{ "HOME & CO", C(160, 140, 110), nil }, { "THE TOY CHEST", C(250, 200, 40), nil },
	{ "CITY OPTICAL", C(30, 110, 160), "pharmacy" }, { "TEA LEAF", C(60, 120, 70), "coffee" },
	{ "DENIM DEPOT", C(40, 70, 130), "clothes" }, { "AURORA JEWELLERS", C(30, 30, 34), nil },
	{ "BLOXY SPORTS", C(200, 30, 40), "clothes" }, { "CANDY CORNER", C(240, 120, 180), "bodega" },
	{ "SOUND LAB", C(16, 16, 18), "electronics" }, { "GLOW COSMETICS", C(250, 180, 200), "pharmacy" },
	{ "URBAN KICKS", C(90, 90, 96), "clothes" }, { "TECH HUB", C(30, 60, 110), "electronics" },
	{ "GRIND COFFEE", C(70, 44, 30), "coffee" }, { "PET PALACE", C(100, 160, 90), nil },
	{ "MAPLE & MOOSE", C(150, 40, 40), "clothes" }, { "LITTLE TOKYO", C(240, 240, 236), "bodega" },
}

local LEVEL_H = 18
local EC_FLOOR = C(214, 210, 202)
local EC_STONE = C(196, 186, 168)
local EC_DARK = C(52, 54, 58)

-- One shop: front plane at xFront (on level floor y), interior toward `inward`
-- (+1 = +x), from zA to zB. Glass front with a doorway, a lit name band,
-- shelves of goods at the back, a counter (some sell things).
local function ecShop(folder, y, xFront, inward, depth, zA, zB, rng, index)
	local shop = EC_SHOPS[(index - 1) % #EC_SHOPS + 1]
	local w = zB - zA
	local zc = (zA + zB) / 2
	local xBack = xFront + inward * depth
	local function at(dx, dy, z)
		return CFrame.new(xFront + inward * dx, y + dy, z)
	end
	-- Partition on the far side.
	solid(folder, V3(depth, LEVEL_H - 1, 0.6), at(depth / 2, (LEVEL_H - 1) / 2, zB), C(230, 228, 222))
	-- Storefront: glass either side of a 7-wide doorway, header band with the name.
	local door = 7
	local side = (w - door) / 2
	for _, s in ipairs({ -1, 1 }) do
		glass(folder, V3(0.3, 11, side - 0.4), at(0, 5.5, zc + s * (door / 2 + side / 2)), C(200, 220, 228), 0.6)
	end
	solid(folder, V3(0.6, LEVEL_H - 12, w), at(0, 12 + (LEVEL_H - 13) / 2, zc), shop[2])
	local bandPos = V3(xFront - inward * 0.4, y + 14, zc)
	local band = deco(folder, V3(w - 3, 3, 0.2), CFrame.lookAt(bandPos, bandPos - V3(inward, 0, 0)), shop[2])
	band.CastShadow = false
	Util.sign(band, Front, shop[1], C(255, 255, 255), Enum.Font.GothamBlack).LightInfluence = 0
	-- Floor finish, back display, goods, counter.
	deco(folder, V3(depth - 0.6, 0.06, w - 0.6), at(depth / 2, 0.03, zc), Util.shade(shop[2], 1.6), M.SmoothPlastic)
	deco(folder, V3(0.4, 10, w - 1.4), CFrame.new(xBack - inward * 0.4, y + 5.5, zc), Util.shade(shop[2], 1.3))
	local goods = { C(220, 60, 50), C(250, 200, 60), C(60, 140, 220), C(240, 240, 236), C(90, 190, 110), C(30, 30, 30) }
	for _, gy in ipairs({ 3, 6.5 }) do
		deco(folder, V3(1.6, 0.25, w - 2), CFrame.new(xBack - inward * 1.2, y + gy, zc), C(200, 196, 190))
		for k = 1, 3 do
			local gz = zA + w * k / 4
			deco(folder, V3(1.2, rng:NextNumber(1, 2), rng:NextNumber(1.5, 3)), CFrame.new(xBack - inward * 1.2, y + gy + 1, gz), goods[rng:NextInteger(1, #goods)])
		end
	end
	local counter = solid(folder, V3(2, 3.6, 6), CFrame.new(xBack - inward * 7, y + 1.8, zc), C(40, 40, 44))
	if shop[3] and index % 2 == 0 then
		Stores.attachPurchase(counter, shop[3], shop[1])
	end
	if index % 2 == 0 then
		local lamp = deco(folder, V3(depth - 4, 0.15, 2), at(depth / 2, LEVEL_H - 1.3, zc), C(255, 250, 240), M.Neon)
		lamp.CastShadow = false
		Kit.light(lamp, Enum.NormalId.Bottom, 16, 0.9, C(255, 244, 228))
	end
end

-- Shops along one row: free z ranges (avoiding entrances) split into ~14-wide units.
local function ecRow(folder, y, xFront, inward, depth, ranges, rng, counter)
	for _, r in ipairs(ranges) do
		local len = r[2] - r[1]
		local n = math.max(1, math.floor(len / 14))
		local unit = len / n
		-- Closing partition at the start of the range.
		solid(folder, V3(depth, LEVEL_H - 1, 0.6), CFrame.new(xFront + inward * depth / 2, y + (LEVEL_H - 1) / 2, r[1]), C(230, 228, 222))
		for k = 0, n - 1 do
			counter.n = counter.n + 1
			ecShop(folder, y, xFront, inward, depth, r[1] + k * unit, r[1] + (k + 1) * unit, rng, counter.n)
		end
	end
end

-- Escalator: a moving belt from bottom to top (dir: +1 carries up, -1 down),
-- with steel sides and black handrails.
local function escalator(folder, bottom, top, width, dir)
	local belt = Kit.span(folder, bottom, top, width, 1, -0.5, C(150, 152, 158), M.DiamondPlate, true)
	if belt then
		belt.AssemblyLinearVelocity = (top - bottom).Unit * 6 * dir
		belt.Name = "Escalator"
	end
	for _, s in ipairs({ -1, 1 }) do
		local off = V3(s * (width / 2 + 0.3), 0, 0)
		Kit.span(folder, bottom + off, top + off, 0.5, 3.6, 1.8, C(200, 204, 210), M.Glass, true).Transparency = 0.4
		Kit.span(folder, bottom + off, top + off, 0.7, 0.35, 3.8, C(15, 15, 15), M.Rubber, false)
	end
	local s = Util.deco(folder, V3(width, 1, 0.2), CFrame.new(bottom + V3(0, 9, 0)), C(20, 20, 24), M.SmoothPlastic)
	Util.sign(s, Enum.NormalId.Back, dir > 0 and "▲ UP" or "▼ DOWN", C(255, 255, 255), Enum.Font.GothamBold).LightInfluence = 0
end

function Landmarks.eatonCentre(folder, rect, rng)
	local x0, x1, z0, z1 = rect.minX, rect.maxX, rect.minZ, rect.maxZ -- z0 = Dundas (north), z1 = Queen (south)
	local W, L = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local gx = x0 + 63 -- galleria centre line
	local gW, walk = 15, 7 -- galleria half-width, upper-level walkway width
	local wFront, eFront = gx - gW, gx + gW -- shop fronts either side of the galleria
	local wBack, eBack = wFront - 30, eFront + 30
	local vW, vE = wFront + walk, eFront - walk -- the open void above the ground floor
	local ys = { KERB, KERB + LEVEL_H, KERB + 2 * LEVEL_H }
	local roofY = KERB + 3 * LEVEL_H
	local foodEnd = z0 + 42
	local yongeDoors = { z0 + 66, z0 + 146 }
	local bayDoor = z0 + 106
	local liftZ0 = z1 - 16
	local bridge2 = { cz - 13, cz - 3 } -- level 2 bridge across the void (z range)
	local bridge3 = { cz - 53, cz - 43 } -- level 3 bridge

	-- Floors: ground everywhere; levels 2 and 3 everywhere except the void, plus bridges.
	solid(folder, V3(W, 1, L), V3(cx, KERB - 0.5, cz), EC_FLOOR, M.Marble)
	for li = 2, 3 do
		local y = ys[li] - 0.5
		solid(folder, V3(vW - x0, 1, L), V3((x0 + vW) / 2, y, cz), EC_FLOOR, M.Marble)
		solid(folder, V3(x1 - vE, 1, L), V3((vE + x1) / 2, y, cz), EC_FLOOR, M.Marble)
		local b = li == 2 and bridge2 or bridge3
		solid(folder, V3(vE - vW, 1, b[2] - b[1]), V3((vW + vE) / 2, y, (b[1] + b[2]) / 2), EC_FLOOR, M.Marble)
		-- Glass balustrades along the void, open where the bridge joins.
		for _, x in ipairs({ vW, vE }) do
			for _, seg in ipairs({ { z0, b[1] }, { b[2], z1 } }) do
				glass(folder, V3(0.3, 4, seg[2] - seg[1]), V3(x, ys[li] + 2, (seg[1] + seg[2]) / 2), C(200, 220, 228), 0.5)
				deco(folder, V3(0.6, 0.3, seg[2] - seg[1]), V3(x, ys[li] + 4.1, (seg[1] + seg[2]) / 2), C(170, 172, 176), M.Metal)
			end
		end
		-- Lights under the balconies.
		for z = z0 + 12, z1 - 12, 24 do
			for _, x in ipairs({ wFront + walk / 2, eFront - walk / 2 }) do
				local lamp = deco(folder, V3(3, 0.15, 3), V3(x, y - 0.6, z), C(255, 250, 240), M.Neon)
				lamp.CastShadow = false
				if (z // 24) % 2 == 0 then
					Kit.light(lamp, Enum.NormalId.Bottom, 18, 1, C(255, 244, 228))
				end
			end
		end
	end
	-- Roof over the shops; a glass barrel vault over the galleria.
	solid(folder, V3(wFront - x0, 1, L), V3((x0 + wFront) / 2, roofY + 0.5, cz), EC_DARK, M.Metal)
	solid(folder, V3(x1 - eFront, 1, L), V3((eFront + x1) / 2, roofY + 0.5, cz), EC_DARK, M.Metal)
	local R, n = gW, 8
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi
		local chord = 2 * R * math.sin(math.pi / (2 * n)) + 0.3
		local p = V3(gx + R * math.cos(a), roofY + R * math.sin(a), cz)
		local pane = solid(folder, V3(chord, 0.3, L), CFrame.new(p) * CFrame.Angles(0, 0, a - math.pi / 2), C(200, 225, 235), M.Glass)
		pane.Transparency = 0.35
		pane.CastShadow = false
	end
	for z = z0 + 2, z1 - 2, 12 do
		for i = 0, n - 1 do
			local a = (i + 0.5) / n * math.pi
			local chord = 2 * R * math.sin(math.pi / (2 * n)) + 0.4
			local p = V3(gx + (R + 0.3) * math.cos(a), roofY + (R + 0.3) * math.sin(a), z)
			deco(folder, V3(chord, 0.5, 0.5), CFrame.new(p) * CFrame.Angles(0, 0, a - math.pi / 2), C(236, 236, 232), M.Metal)
		end
	end
	-- Vault end walls (glass half-discs approximated by slabs).
	for _, z in ipairs({ z0, z1 }) do
		glass(folder, V3(2 * R, R * 0.9, 0.4), V3(gx, roofY + R * 0.45, z), C(200, 225, 235), 0.4)
	end

	-- Back walls of the shop rows, with the entrance passages cut through on the ground floor.
	local function backWall(x, groundGaps)
		Kit.wallWithGaps(folder, false, z0, z1, x, KERB, KERB + 16, groundGaps, C(236, 234, 228), M.SmoothPlastic)
		solid(folder, V3(1, roofY - KERB - 16, L), V3(x, (KERB + 16 + roofY) / 2, cz), C(236, 234, 228))
	end
	backWall(eBack, { { yongeDoors[1] - 7, yongeDoors[1] + 7 }, { yongeDoors[2] - 7, yongeDoors[2] + 7 } })
	backWall(wBack, { { bayDoor - 7, bayDoor + 7 } })

	-- Shops: three levels each side; the ground floor leaves room for the food
	-- court, the Yonge and Bay passages and the elevator lobby.
	local counter = { n = 0 }
	local function cut(ranges, gaps)
		for _, g in ipairs(gaps) do
			local nextR = {}
			for _, r in ipairs(ranges) do
				if g[2] <= r[1] or g[1] >= r[2] then
					table.insert(nextR, r)
				else
					if g[1] > r[1] then
						table.insert(nextR, { r[1], g[1] })
					end
					if g[2] < r[2] then
						table.insert(nextR, { g[2], r[2] })
					end
				end
			end
			ranges = nextR
		end
		return ranges
	end
	for li = 1, 3 do
		local eastRanges = { { li == 1 and foodEnd or z0, z1 } }
		local westRanges = { { li == 1 and foodEnd or z0, liftZ0 } }
		if li == 1 then
			eastRanges = cut(eastRanges, { { yongeDoors[1] - 7, yongeDoors[1] + 7 }, { yongeDoors[2] - 7, yongeDoors[2] + 7 } })
			westRanges = cut(westRanges, { { bayDoor - 7, bayDoor + 7 } })
		end
		ecRow(folder, ys[li], eFront, 1, 30, eastRanges, rng, counter)
		ecRow(folder, ys[li], wFront, -1, 30, westRanges, rng, counter)
	end
	-- Passages from Yonge and Bay into the galleria (walls either side).
	for _, z in ipairs(yongeDoors) do
		for _, s in ipairs({ -1, 1 }) do
			solid(folder, V3(eBack - eFront, 16, 0.6), V3((eFront + eBack) / 2, KERB + 8, z + s * 7), C(236, 234, 228))
			solid(folder, V3(x1 - eBack, 16, 0.6), V3((eBack + x1) / 2, KERB + 8, z + s * 7), C(236, 234, 228))
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		solid(folder, V3(wFront - x0, 16, 0.6), V3((x0 + wFront) / 2, KERB + 8, bayDoor + s * 7), C(236, 234, 228))
	end

	-- Escalators in the void: ground to level 2 onto the level 2 bridge, level 2
	-- to level 3 onto the level 3 bridge. Each pair has one up and one down.
	local upX, downX = (vW + vE) / 2 - 3.5, (vW + vE) / 2 + 3.5
	escalator(folder, V3(upX, ys[1], bridge2[2] + 30), V3(upX, ys[2], bridge2[2]), 5, 1)
	escalator(folder, V3(downX, ys[1], bridge2[2] + 30), V3(downX, ys[2], bridge2[2]), 5, -1)
	escalator(folder, V3(upX, ys[2], bridge2[1]), V3(upX, ys[3], bridge3[2]), 5, 1)
	escalator(folder, V3(downX, ys[2], bridge2[1]), V3(downX, ys[3], bridge3[2]), 5, -1)

	-- Elevator lobby at the south end of the west row: a glass cab on each level;
	-- buttons take you up or down a level.
	local liftX = (wBack + wFront) / 2
	local cabs = {}
	for li = 1, 3 do
		local y = ys[li]
		-- Glass back and side; the cab opens toward the galleria.
		glass(folder, V3(0.4, 12, 12), V3(wBack + 4, y + 6, liftZ0 + 8), C(200, 220, 228), 0.35)
		glass(folder, V3(wFront - wBack - 8, 12, 0.4), V3(liftX, y + 6, liftZ0 + 2), C(200, 220, 228), 0.35)
		solid(folder, V3(wFront - wBack - 8, 12, 0.4), V3(liftX, y + 6, z1 - 2), C(120, 124, 130), M.Metal)
		local panel = solid(folder, V3(0.3, 2, 1), V3(wFront - 4.4, y + 4.5, liftZ0 + 8), C(40, 40, 44), M.Metal)
		sign(folder, CFrame.lookAt(V3(liftX, y + 13.5, liftZ0 - 0.2), V3(liftX, y + 13.5, liftZ0 - 2)), V3(12, 1.4, 0.2), "ELEVATOR · LEVEL " .. li, C(20, 20, 24), C(255, 255, 255))
		cabs[li] = { panel = panel, centre = CFrame.new(liftX, y + 3, liftZ0 + 8) }
	end
	-- The wall beside the lobby closes off the shop row behind it.
	solid(folder, V3(wFront - wBack, LEVEL_H * 3, 0.6), V3(liftX, KERB + LEVEL_H * 1.5, liftZ0), C(230, 228, 222))
	for li, cab in ipairs(cabs) do
		for _, step in ipairs({ 1, -1 }) do
			local target = cabs[li + step]
			if target then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = step > 0 and ("Up to level " .. (li + 1)) or ("Down to level " .. (li - 1))
				prompt.ObjectText = "Elevator"
				prompt.KeyboardKeyCode = step > 0 and Enum.KeyCode.E or Enum.KeyCode.R
				prompt.HoldDuration = 0.3
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.UIOffset = Vector2.new(0, step > 0 and 0 or 60)
				prompt.Parent = cab.panel
				prompt.Triggered:Connect(function(player)
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - cab.centre.Position).Magnitude < 14 then
						character:PivotTo(target.centre * cab.centre:ToObjectSpace(root.CFrame))
					end
				end)
			end
		end
	end

	-- Food court at the Dundas end of the ground floor: counters on both sides,
	-- tables in the middle.
	for _, info in ipairs({ { wBack, 1 }, { eBack, -1 } }) do
		for k = 0, 1 do
			local z = z0 + 10 + k * 18
			local p = V3(info[1] + info[2] * 0.6, KERB, z)
			Kit.shop(folder, CFrame.lookAt(p, p + V3(info[2], 0, 0)), 16, rng)
		end
	end
	for tx = wBack + 14, eBack - 14, 12 do
		for tz = z0 + 12, foodEnd - 6, 12 do
			if math.abs(tx - gx) > 6 then
				solid(folder, V3(4, 0.4, 4), V3(tx, KERB + 3, tz), C(236, 232, 224))
				solid(folder, V3(0.6, 3, 0.6), V3(tx, KERB + 1.5, tz), C(60, 60, 64), M.Metal)
				for _, o in ipairs({ V3(3.4, 0, 0), V3(-3.4, 0, 0) }) do
					solid(folder, V3(1.8, 2, 1.8), V3(tx + o.X, KERB + 1, tz), C(200, 60, 50))
				end
			end
		end
	end
	sign(folder, CFrame.lookAt(V3(gx, ys[2] - 3, foodEnd + 1), V3(gx, ys[2] - 3, foodEnd + 5)), V3(24, 2.4, 0.3), "FOOD COURT", C(30, 30, 34), C(255, 214, 90))

	-- Galleria furniture: benches, planters with trees down the middle.
	for z = foodEnd + 20, z1 - 20, 36 do
		if z < bridge2[1] - 6 or z > bridge2[2] + 34 then
			local p = V3(gx, KERB, z)
			solid(folder, V3(6, 2.4, 6), V3(gx, KERB + 1.2, z), C(170, 164, 152), M.Granite)
			Props.tree(folder, Vector2.new(gx, z), rng, 0.8)
			Kit.bench(folder, CFrame.lookAt(p + V3(-6, 0, 0), p + V3(-12, 0, 0)))
			Kit.bench(folder, CFrame.lookAt(p + V3(6, 0, 0), p + V3(12, 0, 0)))
		end
	end

	-- Outer walls: storefront glass and entrances at street level, stone and glass
	-- bands above. Entrances: Dundas and Queen on the galleria axis, two on Yonge,
	-- one on Bay.
	local function outer(alongX, from, to, fixed, gaps)
		Kit.wallWithGaps(folder, alongX, from, to, fixed, KERB, KERB + 16, gaps, C(60, 66, 72), M.Glass)
		local mid = (from + to) / 2
		local len = to - from
		local size = alongX and V3(len, roofY + 1 - KERB - 16, 1.2) or V3(1.2, roofY + 1 - KERB - 16, len)
		local pos = alongX and V3(mid, (KERB + 16 + roofY + 1) / 2, fixed) or V3(fixed, (KERB + 16 + roofY + 1) / 2, mid)
		solid(folder, size, CFrame.new(pos), EC_STONE, M.Concrete)
		for _, by in ipairs({ ys[2] + 6, ys[3] + 6 }) do
			local bsize = alongX and V3(len - 4, 5, 1.4) or V3(1.4, 5, len - 4)
			local bpos = alongX and V3(mid, by, fixed) or V3(fixed, by, mid)
			local band = deco(folder, bsize, CFrame.new(bpos), C(46, 56, 64), M.Glass)
			Util.nightWindow(band, 0.3)
		end
	end
	outer(true, x0, x1, z0, { { gx - 12, gx + 12 } })
	outer(true, x0, x1, z1, { { gx - 12, gx + 12 } })
	outer(false, z0, z1, x1, { { yongeDoors[1] - 7, yongeDoors[1] + 7 }, { yongeDoors[2] - 7, yongeDoors[2] + 7 } })
	outer(false, z0, z1, x0, { { bayDoor - 7, bayDoor + 7 } })
	-- Entrance canopies and names.
	local function entrance(p, outward, width)
		local c = CFrame.lookAt(p, p + outward)
		deco(folder, V3(width + 6, 0.6, 6), c * CFrame.new(0, 17, -3), C(40, 42, 46), M.Metal)
		sign(folder, c * CFrame.new(0, 19.4, -5.9), V3(width + 4, 3.4, 0.4), "EATON CENTRE", C(20, 20, 24), C(255, 255, 255))
	end
	entrance(V3(gx, KERB, z1), V3(0, 0, 1), 24)
	entrance(V3(gx, KERB, z0), V3(0, 0, -1), 24)
	for _, z in ipairs(yongeDoors) do
		entrance(V3(x1, KERB, z), V3(1, 0, 0), 14)
	end
	entrance(V3(x0, KERB, bayDoor), V3(-1, 0, 0), 14)
	-- Street displays along Yonge between the doors, and the big name up top.
	for z = z0 + 14, z1 - 14, 22 do
		local nearDoor = math.abs(z - yongeDoors[1]) < 14 or math.abs(z - yongeDoors[2]) < 14
		if not nearDoor then
			local p = V3(x1 + 0.7, KERB, z)
			sign(folder, CFrame.lookAt(p + V3(0, 13.5, 0), p + V3(1, 13.5, 0)), V3(14, 2, 0.3), Util.pick(rng, EC_SHOPS)[1], C(20, 20, 24), C(255, 255, 255))
		end
	end
	sign(folder, CFrame.lookAt(V3(x1 + 0.8, roofY - 6, cz + 30), V3(x1 + 4, roofY - 6, cz + 30)), V3(70, 7, 0.4), "EATON CENTRE", C(30, 30, 34), C(255, 255, 255))

	-- The Yonge & Dundas corner: giant screens facing the intersection.
	screen(folder, CFrame.lookAt(V3(x1 + 1, KERB + 34, z0 + 30), V3(x1 + 5, KERB + 34, z0 + 30)), 44, 22, rng)
	screen(folder, CFrame.lookAt(V3(x1 - 26, KERB + 34, z0 - 1), V3(x1 - 26, KERB + 34, z0 - 5)), 40, 22, rng)
	screen(folder, CFrame.lookAt(V3(x1 + 1, KERB + 26, z0 + 106), V3(x1 + 5, KERB + 26, z0 + 106)), 26, 12, rng)
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
function Landmarks.screenBuilding(folder, rect, height, faces, name, rng)
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
