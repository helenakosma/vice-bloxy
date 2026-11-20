-- Toronto building styles: slim glass condo towers on
-- podiums with white balcony bands, brick-and-glass mid-rises, and suburban strip
-- plazas set back behind their parking lots. Each style is (folder, cf, w, d, ctx);
-- the front faces local -Z.
local Util = require(script.Parent.Util)
local Stores = require(script.Parent.Stores)
local Buildings = require(script.Parent.Buildings)
local Layout = require(script.Parent.Layout)
local Props = require(script.Parent.Props)

local TorontoStyles = {}

local V3 = Vector3.new
local M = Enum.Material

local CONDO_GLASS = {
	Color3.fromRGB(78, 120, 130), Color3.fromRGB(90, 110, 128), Color3.fromRGB(110, 132, 138),
	Color3.fromRGB(60, 84, 96), Color3.fromRGB(120, 140, 150),
}
local PODIUM = { Color3.fromRGB(176, 172, 164), Color3.fromRGB(120, 118, 114), Color3.fromRGB(150, 140, 126) }
local BRICK = { Color3.fromRGB(150, 96, 70), Color3.fromRGB(120, 76, 58), Color3.fromRGB(176, 150, 120), Color3.fromRGB(98, 92, 88) }
local WHITE = Color3.fromRGB(236, 236, 232)
local WINDOW = Color3.fromRGB(46, 56, 64)
local SHOPS = { "SHAWARMA", "PHO", "BUBBLE TEA", "DRY CLEANING", "PHARMACY", "DOLLAR STORE", "KOREAN BBQ", "NAILS", "CONVENIENCE", "PIZZA", "DENTAL", "SUSHI", "BAKERY", "HAIR SALON" }

local function groundFloor(folder, cf, w, d, groundH, ctx)
	if ctx.shop == "interior" then
		Stores.interior(folder, cf, w, d, groundH, ctx.rng)
	elseif ctx.shop == "facade" then
		Stores.facade(folder, cf, w, d, groundH, ctx.rng)
	else
		local lobby = Util.deco(folder, V3(math.min(w - 4, 14), groundH - 3, 0.4), cf * CFrame.new(0, (groundH - 3) / 2 + 0.3, -d / 2 - 0.2), Color3.fromRGB(150, 140, 120), M.Glass)
		lobby.Transparency = 0.25
	end
end

-- Podium of shops with a slim glass tower on top and white balcony bands.
function TorontoStyles.torontoCondo(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local groundH, floorH = 14, 10
	local podiumFloors = 2
	local podiumH = groundH + podiumFloors * floorH
	local floors = math.floor(rng:NextInteger(16, 34) * ctx.heightFactor)
	local podiumColor = Util.pick(rng, PODIUM)
	local glass = Util.pick(rng, CONDO_GLASS)

	local bottom = ctx.shop == "interior" and groundH or 0
	Util.solid(folder, V3(w, podiumH - bottom, d), cf * CFrame.new(0, bottom + (podiumH - bottom) / 2, 0), podiumColor, M.Concrete)
	groundFloor(folder, cf, w, d, groundH, ctx)
	for f = 0, podiumFloors - 1 do
		local band = Util.deco(folder, V3(w + 0.3, floorH * 0.55, d + 0.3), cf * CFrame.new(0, groundH + f * floorH + floorH * 0.5, 0), WINDOW, M.Glass)
		band.Reflectance = 0.2
		Util.nightWindow(band, 0.35)
	end

	-- Tower set back on the podium, toward the back of the lot.
	local tw, td = math.max(16, w * 0.62), math.max(16, d * 0.6)
	local tz = (d - td) / 2 * 0.6
	local towerH = floors * floorH
	local tower = Util.solid(folder, V3(tw, towerH, td), cf * CFrame.new(0, podiumH + towerH / 2, tz), glass, M.Glass)
	tower.Reflectance = 0.42
	for f = 2, floors, 2 do
		Util.deco(folder, V3(tw + 1.6, 0.6, td + 1.6), cf * CFrame.new(0, podiumH + f * floorH - 0.3, tz), WHITE, M.Concrete)
	end
	-- A solid white spine up one side, like many Toronto condos.
	local side = rng:NextNumber() < 0.5 and -1 or 1
	Util.deco(folder, V3(3, towerH + 4, td + 1.8), cf * CFrame.new(side * (tw / 2 - 1), podiumH + (towerH + 4) / 2, tz), WHITE, M.Concrete)
	-- Crown: mechanical box, sometimes with a slanted glass cap.
	local top = podiumH + towerH
	if rng:NextNumber() < 0.4 then
		local cap = Util.deco(folder, V3(tw, 2, td * 1.05), cf * CFrame.new(0, top + 6, tz) * CFrame.Angles(math.rad(14), 0, 0), glass, M.Glass)
		cap.Reflectance = 0.4
	end
	Util.deco(folder, V3(tw * 0.55, 6, td * 0.5), cf * CFrame.new(0, top + 3, tz), Color3.fromRGB(150, 150, 148), M.Metal)
end

-- Brick and glass mid-rise with shops underneath.
function TorontoStyles.torontoMidrise(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local groundH, floorH = 14, 10
	local floors = rng:NextInteger(5, 9)
	local h = groundH + floors * floorH
	local color = Util.pick(rng, BRICK)
	local bottom = ctx.shop == "interior" and groundH or 0
	Util.solid(folder, V3(w, h - bottom, d), cf * CFrame.new(0, bottom + (h - bottom) / 2, 0), color, M.Brick)
	groundFloor(folder, cf, w, d, groundH, ctx)
	for f = 0, floors - 1 do
		local band = Util.deco(folder, V3(w + 0.3, floorH * 0.5, d + 0.3), cf * CFrame.new(0, groundH + f * floorH + floorH * 0.5, 0), WINDOW, M.Glass)
		band.Reflectance = 0.25
		Util.nightWindow(band, 0.35)
	end
	local n = math.max(2, math.floor(w / 8))
	for j = 0, n do
		local x = -w / 2 + w * j / n
		Util.deco(folder, V3(1.2, floors * floorH, 0.9), cf * CFrame.new(x, groundH + floors * floorH / 2, -d / 2 - 0.3), color, M.Brick)
	end
	Util.deco(folder, V3(w + 1, 1.2, d + 1), cf * CFrame.new(0, h + 0.6, 0), Util.shade(color, 0.7), M.Concrete)
	if rng:NextNumber() < 0.5 then
		local glassTop = Util.deco(folder, V3(w * 0.7, floorH, d * 0.7), cf * CFrame.new(0, h + floorH / 2 + 1.2, d * 0.1), Util.pick(rng, CONDO_GLASS), M.Glass)
		glassTop.Reflectance = 0.35
	end
end

-- Single-storey strip plaza at the back of its lot, with a parking lot and pylon sign.
function TorontoStyles.stripPlaza(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local h = 16
	local bd = math.max(16, d * 0.45)
	local bz = d / 2 - bd / 2
	local fascia = Util.pick(rng, { Color3.fromRGB(196, 186, 168), Color3.fromRGB(170, 160, 150), Color3.fromRGB(140, 120, 100) })
	Util.solid(folder, V3(w, h, bd), cf * CFrame.new(0, h / 2, bz), fascia, M.Concrete)
	local front = bz - bd / 2
	local shops = math.max(1, math.floor(w / 14))
	local shopW = w / shops
	for i = 1, shops do
		local x = -w / 2 + shopW * (i - 0.5)
		local glass = Util.deco(folder, V3(shopW - 2, 9, 0.3), cf * CFrame.new(x, 5, front - 0.2), Color3.fromRGB(150, 165, 170), M.Glass)
		glass.Transparency = 0.35
		local board = Util.deco(folder, V3(shopW - 3, 2.6, 0.4), cf * CFrame.new(x, 12.8, front - 0.3), Util.pick(rng, { Color3.fromRGB(180, 30, 40), Color3.fromRGB(20, 60, 120), Color3.fromRGB(30, 30, 30), Color3.fromRGB(0, 110, 70) }), M.SmoothPlastic)
		Util.sign(board, Enum.NormalId.Front, Util.pick(rng, SHOPS), Color3.fromRGB(250, 248, 240), Enum.Font.GothamBold)
	end
	Util.deco(folder, V3(w, 0.4, 5), cf * CFrame.new(0, 11, front - 2.5), Color3.fromRGB(90, 88, 84), M.Metal)

	-- Parking lot in front with painted stalls.
	local lotDepth = d - bd
	if lotDepth > 10 then
		local lotZ = -d / 2 + lotDepth / 2
		Util.deco(folder, V3(w, 0.06, lotDepth), cf * CFrame.new(0, 0.32, lotZ), Color3.fromRGB(56, 56, 58), M.Asphalt)
		for x = -w / 2 + 4, w / 2 - 4, 9 do
			Util.deco(folder, V3(0.3, 0.05, 12), cf * CFrame.new(x, 0.38, front - 8), Color3.fromRGB(220, 220, 214), M.SmoothPlastic)
		end
		-- Pylon sign by the road.
		local px = -w / 2 + 4
		Util.solid(folder, V3(2, 18, 2), cf * CFrame.new(px, 9, -d / 2 + 3), Color3.fromRGB(120, 120, 118), M.Concrete)
		local pylon = Util.deco(folder, V3(10, 6, 1), cf * CFrame.new(px, 18, -d / 2 + 3), Color3.fromRGB(240, 240, 236), M.SmoothPlastic)
		Util.sign(pylon, Enum.NormalId.Front, "PLAZA", Color3.fromRGB(180, 30, 40), Enum.Font.GothamBlack)
	end
end

-- Financial-district bank tower: black, gold, white or red-granite, with dense
-- vertical fins that make it read tall and sharp from a distance.
local BANKS = {
	{ body = Color3.fromRGB(28, 30, 34), frame = Color3.fromRGB(14, 14, 16), reflect = 0.35, material = M.Glass },
	{ body = Color3.fromRGB(200, 160, 72), frame = Color3.fromRGB(150, 118, 56), reflect = 0.6, material = M.Glass },
	{ body = Color3.fromRGB(120, 130, 140), frame = Color3.fromRGB(238, 238, 234), reflect = 0.25, material = M.Glass },
	{ body = Color3.fromRGB(150, 56, 52), frame = Color3.fromRGB(110, 40, 38), reflect = 0.15, material = M.Granite },
}

function TorontoStyles.bankTower(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local bank = Util.pick(rng, BANKS)
	local lobbyH, floorH = 22, 11
	local floors = math.floor(rng:NextInteger(18, 26) * math.min(1.3, ctx.heightFactor))
	local h = lobbyH + floors * floorH
	-- Granite base with a recessed glass lobby.
	Util.solid(folder, V3(w, lobbyH, d - 6), cf * CFrame.new(0, lobbyH / 2, 3), Color3.fromRGB(40, 40, 42), M.Granite)
	local lobby = Util.deco(folder, V3(w - 4, lobbyH - 4, 0.3), cf * CFrame.new(0, lobbyH / 2, -d / 2 + 5.8), Color3.fromRGB(200, 180, 140), M.Glass)
	lobby.Transparency = 0.25
	Util.nightWindow(lobby, 1)
	local tower = Util.solid(folder, V3(w, h - lobbyH, d), cf * CFrame.new(0, lobbyH + (h - lobbyH) / 2, 0), bank.body, bank.material)
	tower.Reflectance = bank.reflect
	-- Vertical fins on all four faces.
	local shaft = h - lobbyH
	local function fins(length, across, alongX)
		local n = math.max(3, math.floor(length / 4))
		for j = 0, n do
			local u = -length / 2 + length * j / n
			for _, side in ipairs({ -1, 1 }) do
				local pos = alongX and V3(u, lobbyH + shaft / 2, side * (across / 2 + 0.3)) or V3(side * (across / 2 + 0.3), lobbyH + shaft / 2, u)
				Util.deco(folder, V3(0.5, shaft, 0.6), cf * CFrame.new(pos), bank.frame, M.Metal)
			end
		end
	end
	fins(w, d, true)
	fins(d, w, false)
	for f = 3, floors, 3 do
		local line = Util.deco(folder, V3(w + 0.4, 0.5, d + 0.4), cf * CFrame.new(0, lobbyH + f * floorH, 0), bank.frame, M.Metal)
		line.CastShadow = false
	end
	-- Lit floors at night (a band every few floors) and a crown.
	for f = 2, floors, 2 do
		local band = Util.deco(folder, V3(w + 0.1, floorH * 0.5, d + 0.1), cf * CFrame.new(0, lobbyH + f * floorH - floorH * 0.5, 0), bank.body, bank.material)
		band.Transparency = 1
		Util.nightWindow(band, 0.5)
		if band:HasTag("NightWindow") then
			band.Transparency = 0
			band.Reflectance = bank.reflect
		end
	end
	Util.deco(folder, V3(w * 0.7, 8, d * 0.7), cf * CFrame.new(0, h + 4, 0), bank.frame, M.Metal)
	Util.deco(folder, V3(w * 0.72, 0.5, d * 0.72), cf * CFrame.new(0, h + 8.3, 0), Color3.fromRGB(255, 255, 255), M.Neon)
end

-- Detached house on a lawn (York Mills, Lawrence, Rosedale): two storeys of brick
-- under a pitched roof, porch, chimney, driveway and usually a tree out front.
local HOUSE_BRICK = {
	Color3.fromRGB(150, 84, 62), Color3.fromRGB(122, 74, 56), Color3.fromRGB(186, 160, 128),
	Color3.fromRGB(160, 110, 80), Color3.fromRGB(226, 220, 206),
}
local ROOFS = { Color3.fromRGB(56, 56, 60), Color3.fromRGB(84, 64, 56), Color3.fromRGB(70, 76, 84) }
function TorontoStyles.torontoHouse(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local hw = math.clamp(w - 6, 12, rng:NextNumber(18, 26))
	local hd = math.clamp(d - 14, 12, rng:NextNumber(16, 22))
	local front = -d / 2 + rng:NextNumber(7, 11)
	local zc = front + hd / 2
	local h = 20
	local lawn = Util.deco(folder, V3(w - 1, 0.2, d - 1), cf * CFrame.new(0, 0.1, 0), Color3.fromRGB(90, 116, 66), M.Grass)
	lawn.CastShadow = false
	local colour = Util.pick(rng, HOUSE_BRICK)
	Util.solid(folder, V3(hw, h, hd), cf * CFrame.new(0, h / 2, zc), colour, M.Brick)
	-- Gable roof, ridge along the street.
	local pitch = math.rad(32)
	local slope = (hd / 2 + 1) / math.cos(pitch)
	local rise = (hd / 2) * math.tan(pitch)
	local roofColour = Util.pick(rng, ROOFS)
	for _, s in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(hw + 1.6, 0.8, slope), cf * CFrame.new(0, h + rise / 2, zc + s * hd / 4) * CFrame.Angles(s * pitch, 0, 0), roofColour, M.Slate)
	end
	-- Gable ends.
	for _, sx in ipairs({ -1, 1 }) do
		local gable = Instance.new("WedgePart")
		gable.Anchored = true
		gable.Size = V3(0.6, rise, hd / 2)
		gable.Color = colour
		gable.Material = M.Brick
		for _, s in ipairs({ -1, 1 }) do
			local g = gable:Clone()
			g.CFrame = cf * CFrame.new(sx * (hw / 2 - 0.3), h + rise / 2, zc + s * hd / 4) * CFrame.Angles(0, s > 0 and math.pi or 0, 0) -- a wedge's high side is its back (+Z); face it toward the ridge
			g.Parent = folder
			Util.tick()
		end
	end
	Util.solid(folder, V3(2.6, 9, 2.6), cf * CFrame.new(hw / 2 - 3, h + rise * 0.5 + 3, zc + hd / 4), Util.shade(colour, 0.8), M.Brick)
	-- Front: porch, door, windows.
	Util.solid(folder, V3(8, 0.8, 4), cf * CFrame.new(0, 0.6, front - 2), Color3.fromRGB(170, 166, 158), M.Concrete)
	Util.deco(folder, V3(3.4, 7.4, 0.3), cf * CFrame.new(0, 4.4, front - 0.1), Color3.fromRGB(90, 40, 34), M.Wood)
	for _, x in ipairs({ -hw / 3.2, hw / 3.2 }) do
		for _, y in ipairs({ 5.5, 14.5 }) do
			local win = Util.deco(folder, V3(3.6, 4.2, 0.3), cf * CFrame.new(x, y, front - 0.1), Color3.fromRGB(46, 56, 64), M.Glass)
			Util.nightWindow(win, 0.4)
		end
	end
	-- Driveway to the street, and a tree.
	local side = rng:NextNumber() < 0.5 and -1 or 1
	if w - hw > 9 then
		Util.deco(folder, V3(6, 0.25, -front + d / 2 - 0.5), cf * CFrame.new(side * (hw / 2 + 3.5), 0.15, (front - d / 2) / 2), Color3.fromRGB(70, 70, 72), M.Asphalt)
	end
	if rng:NextNumber() < 0.7 then
		local p = (cf * CFrame.new(-side * (hw / 4), 0, -d / 2 + 4)).Position
		Props.tree(folder, Vector2.new(p.X, p.Z), rng, rng:NextNumber(1, 1.3))
	end
end

-- Plain massing block: a placeholder sized by neighbourhood (Stage 2 skeleton).
function TorontoStyles.massing(folder, cf, w, d, ctx)
	local h = math.clamp(ctx.rng:NextNumber(28, 70) * ctx.heightFactor, 14, 360)
	Buildings.filler(folder, cf, math.max(8, w - 2), math.max(8, d - 3), h, ctx.rng, true)
end

for name, fn in pairs(TorontoStyles) do
	Buildings.Styles[name] = fn
end

function TorontoStyles.choose(rng, road, center, heightFactor)
	local r = rng:NextNumber()
	local hf = heightFactor(center)
	if road.main and (center - Layout.FINANCIAL).Magnitude < 240 and r < 0.6 then
		return "bankTower"
	end
	if road.main then
		if r < 0.5 then
			return "torontoCondo"
		elseif r < 0.65 then
			return "glass"
		elseif r < 0.85 or hf > 1.4 then
			return "torontoMidrise"
		end
		return "stripPlaza"
	end
	if r < 0.4 then
		return "torontoMidrise"
	elseif r < 0.7 and hf < 1.5 then
		return "stripPlaza"
	elseif r < 0.85 then
		return "torontoCondo"
	end
	return "walkup"
end

return TorontoStyles
