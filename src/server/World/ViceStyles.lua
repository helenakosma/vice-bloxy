-- Vice Beach building styles (Miami-inspired): pastel Art Deco hotels on Ocean
-- Drive, white condo towers, pastel walk-ups and neon nightclubs.
-- Each style is (folder, cf, w, d, ctx); the front faces local -Z.
local Util = require(script.Parent.Util)
local Stores = require(script.Parent.Stores)
local Buildings = require(script.Parent.Buildings)

local ViceStyles = {}

local V3 = Vector3.new
local M = Enum.Material

local PASTELS = {
	Color3.fromRGB(240, 140, 120), -- coral
	Color3.fromRGB(244, 170, 194), -- pink
	Color3.fromRGB(160, 222, 196), -- mint
	Color3.fromRGB(128, 208, 214), -- aqua
	Color3.fromRGB(200, 176, 228), -- lavender
	Color3.fromRGB(250, 200, 156), -- peach
	Color3.fromRGB(248, 228, 168), -- butter
	Color3.fromRGB(160, 202, 236), -- sky
}
local NEON = {
	Color3.fromRGB(255, 70, 170),
	Color3.fromRGB(60, 230, 255),
	Color3.fromRGB(170, 90, 255),
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(110, 255, 150),
}
local WHITE = Color3.fromRGB(245, 242, 235)
local GLASS = Color3.fromRGB(86, 150, 160)

local HOTEL_NAMES = {
	"FLAMINGO", "STARLITE", "CORAL PALMS", "SEABREEZE", "THE SAVOY", "MOONGLOW",
	"PARADISE", "LA PLAYA", "NEPTUNE", "THE AVALON", "SUNSET", "BEACHCOMBER",
	"THE CARLYLE", "TROPICANA", "MERMAID", "THE BRETTON",
}
local CLUB_NAMES = { "PULSE", "NEON ROOM", "VELVET", "CLUB VICE", "AFTERGLOW", "STARDUST", "MIRAGE" }

local function letters(text)
	-- Vertical sign text: one letter per line.
	return (string.gsub(text, " ", "")):gsub(".", "%0\n")
end

-- Main body; with an interior shop it starts above the ground floor.
local function body(folder, cf, w, d, h, color, ctx, groundH)
	local bottom = ctx.shop == "interior" and groundH or 0
	Util.solid(folder, V3(w, h - bottom, d), cf * CFrame.new(0, bottom + (h - bottom) / 2, 0), color, M.Plaster)
end

local function groundFloor(folder, cf, w, d, groundH, ctx, kinds)
	if ctx.shop == "interior" then
		Stores.interior(folder, cf, w, d, groundH, ctx.rng, kinds)
	elseif ctx.shop == "facade" then
		Stores.facade(folder, cf, w, d, groundH, ctx.rng)
	else
		Util.deco(folder, V3(6, 9, 0.4), cf * CFrame.new(0, 4.5, -d / 2 - 0.2), Color3.fromRGB(60, 110, 120), M.Glass)
	end
end

local function cafeTables(folder, cf, w, d, rng)
	local count = math.clamp(math.floor(w / 10), 1, 4)
	local umbrella = Util.pick(rng, { Color3.fromRGB(240, 240, 235), Color3.fromRGB(230, 90, 110), Color3.fromRGB(60, 170, 190) })
	for i = 1, count do
		local x = -w / 2 + w * (i - 0.5) / count
		local base = cf * CFrame.new(x, 0.25, -d / 2 - 5)
		Util.cylinder(folder, 0.3, 3.2, base * CFrame.new(0, 3, 0), WHITE, M.Metal, true)
		Util.cylinder(folder, 7.5, 0.25, base * CFrame.new(0, 3.75, 0), Color3.fromRGB(60, 60, 60), M.Metal, false)
		Util.cylinder(folder, 0.4, 8, base * CFrame.new(0, 7.4, 0), umbrella, M.Fabric, false)
	end
end

-- Pastel Art Deco hotel: eyebrow ledges over the windows, a white fin with a
-- vertical neon name, sometimes a rounded corner and a sidewalk cafe.
function ViceStyles.decoHotel(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH, groundH = 11, 13
	local floors = rng:NextInteger(3, 6)
	local h = groundH + floors * floorH
	local color = Util.pick(rng, PASTELS)
	local neon = Util.pick(rng, NEON)

	body(folder, cf, w, d, h, color, ctx, groundH)
	groundFloor(folder, cf, w, d, groundH, ctx, { "bar", "coffee", "clothes", "pizza" })

	for f = 0, floors - 1 do
		local y = groundH + f * floorH
		local band = Util.deco(folder, V3(w * 0.78, floorH * 0.45, 0.3), cf * CFrame.new(0, y + floorH * 0.5, -d / 2 - 0.1), GLASS, M.Glass)
		band.Reflectance = 0.25
		Util.deco(folder, V3(w + 0.6, 0.5, 2.2), cf * CFrame.new(0, y + floorH * 0.82, -d / 2 - 1), WHITE, M.Concrete)
	end
	Util.deco(folder, V3(w, 0.35, 0.35), cf * CFrame.new(0, groundH - 0.4, -d / 2 - 2.2), neon, M.Neon)

	if rng:NextNumber() < 0.5 then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		Util.cylinder(folder, h, 9, cf * CFrame.new(side * (w / 2 - 1), h / 2, -d / 2 + 3.5), color, M.Plaster, true)
	end

	-- Fin with a vertical sign rising above the roof.
	local finX = rng:NextNumber(-w / 4, w / 4)
	local finH = h + 14
	Util.deco(folder, V3(4.5, finH, 3), cf * CFrame.new(finX, finH / 2, -d / 2 - 1.2), WHITE, M.Concrete)
	local name = Util.pick(rng, HOTEL_NAMES)
	local signH = math.min(finH - 10, #name * 3 + 4)
	local sign = Util.deco(folder, V3(3.6, signH, 0.4), cf * CFrame.new(finX, finH - signH / 2 - 2, -d / 2 - 2.9), Color3.fromRGB(26, 30, 46), M.SmoothPlastic)
	local gui = Util.sign(sign, Enum.NormalId.Front, letters(name), neon, Enum.Font.GothamBlack)
	gui.LightInfluence = 0
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(0.3, signH, 0.3), cf * CFrame.new(finX + side * 1.95, finH - signH / 2 - 2, -d / 2 - 3.1), neon, M.Neon)
	end

	-- Stepped parapet.
	Util.deco(folder, V3(w + 0.6, 2, d + 0.6), cf * CFrame.new(0, h + 1, 0), WHITE, M.Concrete)
	Util.deco(folder, V3(w * 0.45, 3.5, d * 0.35), cf * CFrame.new(-finX * 0.5, h + 3.5, 0), color, M.Plaster)

	if ctx.shop and rng:NextNumber() < 0.7 then
		cafeTables(folder, cf, w, d, rng)
	end
end

-- White condo tower with wrap-around balconies and a glass core.
function ViceStyles.condo(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH, groundH = 11, 16
	local floors = rng:NextInteger(12, 26)
	local h = groundH + floors * floorH
	local glass = Util.pick(rng, { Color3.fromRGB(96, 168, 176), Color3.fromRGB(120, 150, 170), Color3.fromRGB(150, 190, 190) })

	if ctx.shop == "interior" then
		Stores.interior(folder, cf, w, d, groundH, rng, { "coffee", "clothes", "bank", "pharmacy" })
	else
		Util.solid(folder, V3(w, groundH, d), cf * CFrame.new(0, groundH / 2, 0), WHITE, M.Concrete)
		if ctx.shop == "facade" then
			Stores.facade(folder, cf, w, d, groundH, rng)
		end
	end
	local tower = Util.solid(folder, V3(w - 4, h - groundH, d - 4), cf * CFrame.new(0, groundH + (h - groundH) / 2, 0), glass, M.Glass)
	tower.Reflectance = 0.35
	for f = 1, floors do
		Util.deco(folder, V3(w + 2, 0.7, d + 2), cf * CFrame.new(0, groundH + f * floorH - 0.35, 0), WHITE, M.Concrete)
	end
	-- Rounded white ends on taller towers.
	if floors > 18 then
		for _, side in ipairs({ -1, 1 }) do
			Util.cylinder(folder, h - groundH, 8, cf * CFrame.new(side * (w / 2 - 2), groundH + (h - groundH) / 2, 0), WHITE, M.Concrete, true)
		end
	end
	Util.deco(folder, V3(w * 0.6, 8, d * 0.6), cf * CFrame.new(0, h + 4, 0), WHITE, M.Concrete)
	Util.deco(folder, V3(w * 0.6 + 0.4, 0.4, d * 0.6 + 0.4), cf * CFrame.new(0, h + 7.6, 0), Util.pick(rng, NEON), M.Neon)
end

-- Small pastel apartment block with ribbon windows.
function ViceStyles.pastelLowrise(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH, groundH = 10, 11
	local floors = rng:NextInteger(2, 4)
	local h = groundH + floors * floorH
	local color = Util.pick(rng, PASTELS)
	body(folder, cf, w, d, h, color, ctx, groundH)
	groundFloor(folder, cf, w, d, groundH, ctx)
	for f = 0, floors - 1 do
		local band = Util.deco(folder, V3(w + 0.3, floorH * 0.42, d + 0.3), cf * CFrame.new(0, groundH + f * floorH + floorH * 0.5, 0), GLASS, M.Glass)
		band.Reflectance = 0.2
	end
	Util.deco(folder, V3(w + 0.8, 1.4, d + 0.8), cf * CFrame.new(0, h + 0.7, 0), WHITE, M.Concrete)
	if rng:NextNumber() < 0.35 then
		Util.deco(folder, V3(w + 0.9, 0.3, d + 0.9), cf * CFrame.new(0, h + 1.5, 0), Util.pick(rng, NEON), M.Neon)
	end
end

-- Nightclub: dark box outlined in neon with a big sign and a roped-off entrance.
function ViceStyles.club(folder, cf, w, d, ctx)
	local rng = ctx.rng
	local floorH, groundH = 12, 14
	local floors = rng:NextInteger(1, 3)
	local h = groundH + floors * floorH
	local color = Util.pick(rng, { Color3.fromRGB(34, 28, 44), Color3.fromRGB(24, 24, 28), Color3.fromRGB(48, 30, 56) })
	local neon = Util.pick(rng, NEON)
	local accent = Util.pick(rng, NEON)
	if ctx.shop == "interior" then
		Stores.interior(folder, cf, w, d, groundH, rng, { "bar" })
	end
	body(folder, cf, w, d, h, color, ctx, groundH)

	local fz = -d / 2 - 0.3
	for _, side in ipairs({ -1, 1 }) do
		Util.deco(folder, V3(0.5, h, 0.5), cf * CFrame.new(side * (w / 2 - 0.25), h / 2, fz), neon, M.Neon)
	end
	Util.deco(folder, V3(w, 0.5, 0.5), cf * CFrame.new(0, h - 0.25, fz), neon, M.Neon)
	Util.deco(folder, V3(w, 0.4, 0.5), cf * CFrame.new(0, groundH, fz), accent, M.Neon)

	local sign = Util.deco(folder, V3(math.min(w - 6, 26), 5, 0.4), cf * CFrame.new(0, h - 5, fz - 0.3), Color3.fromRGB(16, 14, 20), M.SmoothPlastic)
	local gui = Util.sign(sign, Enum.NormalId.Front, Util.pick(rng, CLUB_NAMES), accent, Enum.Font.GothamBlack)
	gui.LightInfluence = 0

	if ctx.shop ~= "interior" then
		Util.deco(folder, V3(7, 10, 0.4), cf * CFrame.new(0, 5, fz), Color3.fromRGB(10, 10, 12), M.Glass)
	end
	-- Canopy and velvet rope.
	Util.deco(folder, V3(10, 0.4, 5), cf * CFrame.new(0, 11, fz - 2.5), Color3.fromRGB(20, 20, 24), M.Metal)
	Util.deco(folder, V3(10, 0.2, 0.2), cf * CFrame.new(0, 10.8, fz - 5), accent, M.Neon)
	for _, x in ipairs({ -5, 5 }) do
		Util.cylinder(folder, 3, 0.4, cf * CFrame.new(x, 1.75, fz - 4), Color3.fromRGB(200, 170, 80), M.Metal, false)
	end
	Util.deco(folder, V3(10, 0.25, 0.25), cf * CFrame.new(0, 2.8, fz - 4), Color3.fromRGB(150, 20, 40), M.Fabric)
end

for name, fn in pairs(ViceStyles) do
	Buildings.Styles[name] = fn
end

-- Picks a style for a building on a Vice Beach road.
function ViceStyles.choose(rng, road)
	local r = rng:NextNumber()
	if road.kind == "boulevard" then
		return r < 0.88 and "decoHotel" or "club"
	elseif road.kind == "avenue" then
		if r < 0.45 then
			return "condo"
		elseif r < 0.65 then
			return "club"
		elseif r < 0.85 then
			return "decoHotel"
		end
		return "pastelLowrise"
	end
	return r < 0.75 and "pastelLowrise" or "decoHotel"
end

return ViceStyles
