-- North York building styles (Toronto-inspired): slim glass condo towers on
-- podiums with white balcony bands, brick-and-glass mid-rises, and suburban strip
-- plazas set back behind their parking lots. Each style is (folder, cf, w, d, ctx);
-- the front faces local -Z.
local Util = require(script.Parent.Util)
local Stores = require(script.Parent.Stores)
local Buildings = require(script.Parent.Buildings)

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

for name, fn in pairs(TorontoStyles) do
	Buildings.Styles[name] = fn
end

function TorontoStyles.choose(rng, road, center, heightFactor)
	local r = rng:NextNumber()
	local hf = heightFactor(center)
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
