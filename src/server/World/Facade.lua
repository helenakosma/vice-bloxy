-- Facade kit: building fronts with real depth.
--
-- Windows are actual openings: the wall in front is built from piers (between
-- window columns) and spandrels (between window rows), with the glass set back
-- behind them, so you see reveals, sills and lintels instead of a flat band.
-- The ground floor is either a storefront (recessed glazing, mullions, kick
-- plate, transom, lit sign band, entry vestibule) or a residential/office entrance.
--
-- All functions work in building-local space: cf is the ground centre of the
-- footprint and the street front faces local -Z.
local Util = require(script.Parent.Util)

local Facade = {}

local V3 = Vector3.new
local M = Enum.Material
local Front = Enum.NormalId.Front

local METAL_DARK = Color3.fromRGB(34, 34, 36)
local GLASS = Color3.fromRGB(70, 84, 94)
local WINDOWS = { "window_curtains", "window_blinds", "window_dark", "window_room", "window_dark" }

local function wallPart(folder, size, cf, wall)
	local p = Util.solid(folder, size, cf, wall.color, wall.material)
	if wall.texture then
		Util.texture(p, Front, wall.texture, wall.tile, wall.tile)
		Util.texture(p, Enum.NormalId.Left, wall.texture, wall.tile, wall.tile)
		Util.texture(p, Enum.NormalId.Right, wall.texture, wall.tile, wall.tile)
	end
	return p
end

local function trimPart(folder, size, cf, trim)
	return Util.deco(folder, size, cf, trim.color, trim.material or M.Concrete)
end

---------------------------------------------------------------------------
-- Upper floors
---------------------------------------------------------------------------
-- spec = {
--   floors, floorH, y0 (where the upper floors start),
--   wall = { color, material, texture, tile }, trim = { color, material },
--   windowW, windowH, sillH, recess, lintels, ac (chance), lit (chance of a lit room)
-- }
function Facade.upper(folder, cf, w, d, spec, rng)
	local floors, floorH, y0 = spec.floors, spec.floorH, spec.y0
	local recess = spec.recess or 0.8
	local windowW, windowH = spec.windowW or 4, spec.windowH or 6
	local sillH = spec.sillH or 2.2
	local front = -d / 2
	local height = floors * floorH
	local y1 = y0 + height

	-- How many window columns fit, keeping piers at least 2 studs wide.
	local bays = math.max(1, math.floor((w - 2) / (windowW + 2)))
	local pierW = (w - bays * windowW) / (bays + 1)

	-- Piers run the full height of the upper floors.
	for j = 0, bays do
		local x = -w / 2 + pierW / 2 + j * (pierW + windowW)
		wallPart(folder, V3(pierW, height, recess), cf * CFrame.new(x, y0 + height / 2, front + recess / 2), spec.wall)
	end
	-- Spandrels fill between window rows (and above the top row).
	for k = 0, floors do
		local bottom = (k == 0) and y0 or (y0 + (k - 1) * floorH + sillH + windowH)
		local top = (k == floors) and y1 or (y0 + k * floorH + sillH)
		if top - bottom > 0.05 then
			wallPart(folder, V3(w - 0.02, top - bottom, recess - 0.02), cf * CFrame.new(0, (bottom + top) / 2, front + recess / 2 + 0.01), spec.wall)
		end
	end

	-- Glass, sills, lintels and the odd window AC unit.
	for f = 0, floors - 1 do
		local sillY = y0 + f * floorH + sillH
		for j = 0, bays - 1 do
			local x = -w / 2 + pierW + windowW / 2 + j * (pierW + windowW)
			local glass = Util.deco(folder, V3(windowW, windowH, 0.2), cf * CFrame.new(x, sillY + windowH / 2, front + recess - 0.1), GLASS, M.Glass)
			glass.Reflectance = 0.15
			local pick = WINDOWS[rng:NextInteger(1, #WINDOWS)]
			if spec.lit and rng:NextNumber() < spec.lit then
				pick = rng:NextNumber() < 0.5 and "window_curtains" or "window_room"
			end
			if Util.decal(glass, Front, pick) then
				glass.Material = M.SmoothPlastic
				glass.Color = Color3.new(1, 1, 1)
			end
			trimPart(folder, V3(windowW + 0.8, 0.35, recess + 0.6), cf * CFrame.new(x, sillY - 0.175, front + recess / 2 - 0.3), spec.trim)
			if spec.lintels then
				trimPart(folder, V3(windowW + 0.9, 0.7, 0.3), cf * CFrame.new(x, sillY + windowH + 0.35, front - 0.14), spec.trim)
			end
			if spec.ac and rng:NextNumber() < spec.ac then
				Util.deco(folder, V3(windowW * 0.6, 1.5, 2), cf * CFrame.new(x, sillY + 0.75, front - 0.4), Color3.fromRGB(196, 194, 188), M.Metal)
				Util.deco(folder, V3(windowW * 0.55, 1.1, 0.1), cf * CFrame.new(x, sillY + 0.75, front - 1.42), Color3.fromRGB(110, 110, 108), M.DiamondPlate)
			end
		end
	end

	-- Belt courses (thin projecting bands) every few floors.
	if spec.beltEvery then
		for f = spec.beltEvery, floors - 1, spec.beltEvery do
			trimPart(folder, V3(w + 0.4, 0.6, 0.6), cf * CFrame.new(0, y0 + f * floorH + 0.3, front - 0.3), spec.trim)
		end
	end
	return y1
end

-- Classic stepped cornice and a parapet along the street front.
function Facade.cornice(folder, cf, w, d, y, trim, wall)
	local front = -d / 2
	trimPart(folder, V3(w + 0.6, 1, 1.4), cf * CFrame.new(0, y + 0.5, front - 0.3), trim)
	trimPart(folder, V3(w + 1.4, 0.8, 2.4), cf * CFrame.new(0, y + 1.4, front - 0.6), trim)
	trimPart(folder, V3(w + 2, 0.5, 3), cf * CFrame.new(0, y + 2.05, front - 0.8), trim)
	-- Dentil-like shadow band.
	Util.deco(folder, V3(w + 0.8, 0.4, 0.2), cf * CFrame.new(0, y + 0.95, front - 1.05), Util.shade(trim.color, 0.7), M.Concrete)
	wallPart(folder, V3(w, 3, 0.8), cf * CFrame.new(0, y + 1.5, front + 0.6), wall)
end

-- Dirt and rain streaks over the upper front, from y0 to y1 (a transparent sheet
-- with a decal), so shop windows at street level stay clean.
function Facade.grime(folder, cf, w, d, y0, y1)
	local h = y1 - y0
	local sheet = Util.deco(folder, V3(w, h, 0.05), cf * CFrame.new(0, y0 + h / 2, -d / 2 - 0.03), Color3.new(), M.SmoothPlastic)
	sheet.Transparency = 1
	sheet.CastShadow = false
	if not Util.decal(sheet, Front, "grime_streaks", 0.35) then
		sheet:Destroy()
	end
end

---------------------------------------------------------------------------
-- Ground floor: storefront
---------------------------------------------------------------------------
-- spec = { groundH, wall, trim, name, signColor, textColor, doorX, interior ("deli"/"boutique"/nil),
--          enterable (true: an open vestibule with sliding doors; the caller builds the room),
--          awning (Color3 or nil), gate (true: roll-down gate housing) }
-- Returns the z of the shopfront glass line (interiors start behind it).
function Facade.storefront(folder, cf, w, d, spec, rng)
	local gh = spec.groundH
	local front = -d / 2
	local inset = 2 -- glazing sits this far behind the building line
	local glassZ = front + inset
	local kerb = Util.WALK_TOP
	local fasciaH = 3
	local transomY = gh - fasciaH - 2.2

	-- End piers (wall material) framing the shop.
	for _, side in ipairs({ -1, 1 }) do
		wallPart(folder, V3(1.6, gh, inset + 0.8), cf * CFrame.new(side * (w / 2 - 0.8), gh / 2, front + (inset + 0.8) / 2), spec.wall)
	end
	-- Sign band with the shop name, lit from above.
	local fascia = Util.solid(folder, V3(w, fasciaH, inset + 0.8), cf * CFrame.new(0, gh - fasciaH / 2, front + (inset + 0.8) / 2), spec.signColor or Color3.fromRGB(28, 30, 32), M.SmoothPlastic)
	if spec.name then
		local gui = Util.sign(fascia, Front, spec.name, spec.textColor or Color3.fromRGB(245, 236, 210), Enum.Font.GothamBold)
		gui.LightInfluence = 0.15
	end
	for _, x in ipairs({ -w / 3, 0, w / 3 }) do
		Util.deco(folder, V3(0.3, 0.3, 1.6), cf * CFrame.new(x, gh + 0.2, front - 0.6), METAL_DARK, M.Metal)
		local lamp = Util.deco(folder, V3(0.9, 0.4, 0.9), cf * CFrame.new(x, gh + 0.05, front - 1.3), Color3.fromRGB(255, 230, 190), M.Neon)
		lamp.CastShadow = false
	end
	-- Soffit over the recess with downlights.
	local soffit = Util.deco(folder, V3(w - 3.2, 0.3, inset), cf * CFrame.new(0, gh - fasciaH - 0.15, front + inset / 2), Color3.fromRGB(60, 58, 56), M.SmoothPlastic)
	local downlight = Instance.new("SurfaceLight")
	downlight.Face = Enum.NormalId.Bottom
	downlight.Range = 10
	downlight.Brightness = 0.9
	downlight.Color = Color3.fromRGB(255, 226, 180)
	downlight.Parent = soffit

	-- Shopfront: glazing split around a door opening.
	local doorW = 6
	local doorX = spec.doorX or 0
	local inner = w / 2 - 1.6
	local segments = { { -inner, doorX - doorW / 2 }, { doorX + doorW / 2, inner } }
	for _, seg in ipairs(segments) do
		local x0, x1 = seg[1], seg[2]
		local segW = x1 - x0
		if segW > 0.5 then
			local cx = (x0 + x1) / 2
			Util.solid(folder, V3(segW, 1.6, 0.4), cf * CFrame.new(cx, kerb + 0.8, glassZ), METAL_DARK, M.Metal) -- kick plate
			local glassH = transomY - kerb - 1.6
			local glass = Util.solid(folder, V3(segW, glassH, 0.2), cf * CFrame.new(cx, kerb + 1.6 + glassH / 2, glassZ), Color3.fromRGB(170, 186, 192), M.Glass)
			glass.Transparency = 0.55
			glass.Reflectance = 0.2
			-- Mullions every ~5 studs.
			local n = math.max(1, math.floor(segW / 5))
			for k = 0, n do
				local mx = x0 + segW * k / n
				Util.deco(folder, V3(0.35, transomY - kerb, 0.5), cf * CFrame.new(mx, (kerb + transomY) / 2, glassZ), METAL_DARK, M.Metal)
			end
		end
	end
	-- Transom bar and transom glass across the whole front.
	Util.deco(folder, V3(inner * 2, 0.45, 0.5), cf * CFrame.new(0, transomY, glassZ), METAL_DARK, M.Metal)
	local transom = Util.solid(folder, V3(inner * 2, gh - fasciaH - transomY - 0.2, 0.2), cf * CFrame.new(0, (transomY + gh - fasciaH) / 2, glassZ), Color3.fromRGB(150, 166, 172), M.Glass)
	transom.Transparency = 0.5

	-- Door: a recessed vestibule with glass sides.
	local vestibule = 2.5
	for _, side in ipairs({ -1, 1 }) do
		local side_ = Util.solid(folder, V3(0.3, transomY - kerb, vestibule), cf * CFrame.new(doorX + side * doorW / 2, (kerb + transomY) / 2, glassZ + vestibule / 2), Color3.fromRGB(170, 186, 192), M.Glass)
		side_.Transparency = 0.5
	end
	Util.deco(folder, V3(doorW, 0.1, vestibule + 0.4), cf * CFrame.new(doorX, kerb + 0.05, glassZ + vestibule / 2), Color3.fromRGB(120, 116, 110), M.Slate)
	local doorZ = glassZ + vestibule
	local doors = {}
	if spec.enterable then
		-- Two sliding panels, opened by the client door script when someone is near.
		for _, side in ipairs({ -1, 1 }) do
			local panel = Util.solid(folder, V3(doorW / 2, transomY - kerb, 0.25), cf * CFrame.new(doorX + side * doorW / 4, (kerb + transomY) / 2, doorZ), Color3.fromRGB(176, 196, 204), M.Glass)
			panel.Transparency = 0.45
			panel.Name = "AutoDoor"
			panel:SetAttribute("SlideX", side * (doorW / 2 - 0.2))
			game:GetService("CollectionService"):AddTag(panel, "AutoDoor")
			table.insert(doors, panel)
		end
	else
		local door = Util.solid(folder, V3(doorW - 1, transomY - kerb, 0.25), cf * CFrame.new(doorX, (kerb + transomY) / 2, doorZ), Color3.fromRGB(150, 168, 176), M.Glass)
		door.Transparency = 0.35
		Util.deco(folder, V3(doorW - 2, 0.3, 0.4), cf * CFrame.new(doorX, kerb + 4, doorZ - 0.3), Color3.fromRGB(190, 190, 186), M.Metal)
	end
	Util.deco(folder, V3(doorW + 0.6, 0.5, 0.6), cf * CFrame.new(doorX, transomY, doorZ), METAL_DARK, M.Metal)

	-- What you see through the glass when the shop isn't enterable.
	if not spec.enterable then
		local back = Util.deco(folder, V3(w - 3.4, gh - fasciaH - kerb, 0.2), cf * CFrame.new(0, kerb + (gh - fasciaH - kerb) / 2, glassZ + 6), Color3.fromRGB(196, 176, 140), M.SmoothPlastic)
		if not Util.decal(back, Front, spec.interior == "boutique" and "storefront_boutique" or "storefront_deli") then
			back.Material = M.Plaster
		end
		local glow = Instance.new("SurfaceLight")
		glow.Face = Front
		glow.Range = 8
		glow.Brightness = 0.7
		glow.Color = Color3.fromRGB(255, 230, 190)
		glow.Parent = back
		Util.deco(folder, V3(w - 3.4, 0.2, 6), cf * CFrame.new(0, kerb + 0.1, glassZ + 3), Color3.fromRGB(150, 142, 130), M.Marble)
		Util.deco(folder, V3(w - 3.4, 0.2, 6), cf * CFrame.new(0, gh - fasciaH - 0.1, glassZ + 3), Color3.fromRGB(230, 226, 218), M.SmoothPlastic)
	end

	-- Awning and/or roll-down gate housing.
	if spec.awning then
		Util.deco(folder, V3(w - 2.4, 0.25, 4.5), cf * CFrame.new(0, gh - fasciaH - 0.8, front - 2) * CFrame.Angles(math.rad(-16), 0, 0), spec.awning, M.Fabric)
		Util.deco(folder, V3(w - 2.4, 1, 0.15), cf * CFrame.new(0, gh - fasciaH - 1.9, front - 4.15), spec.awning, M.Fabric)
	end
	if spec.gate then
		Util.deco(folder, V3(w - 3.2, 0.9, 0.9), cf * CFrame.new(0, gh - fasciaH - 0.45, front + 0.45), Color3.fromRGB(120, 122, 124), M.CorrodedMetal)
	end
	return glassZ, doors
end

---------------------------------------------------------------------------
-- Ground floor: residential or office entrance
---------------------------------------------------------------------------
-- spec = { groundH, wall, trim, base (wall table for the rusticated base),
--          style = "stoop" | "lobby", address (string) }
function Facade.entrance(folder, cf, w, d, spec, rng)
	local gh = spec.groundH
	local front = -d / 2
	local base = spec.base or spec.wall
	local kerb = Util.WALK_TOP
	local doorW, doorH = 7, 10.5

	-- Base wall in three pieces around the door opening, with two small windows.
	local sideW = (w - doorW - 3) / 2
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (doorW / 2 + 1.5 + sideW / 2)
		wallPart(folder, V3(sideW, gh, 1.2), cf * CFrame.new(x, gh / 2, front + 0.6), base)
		if sideW > 6 then
			local glass = Util.deco(folder, V3(math.min(5, sideW - 3), 5.5, 0.2), cf * CFrame.new(x, kerb + 5, front - 0.05), GLASS, M.Glass)
			glass.Reflectance = 0.2
			Util.decal(glass, Front, rng:NextNumber() < 0.5 and "window_blinds" or "window_dark")
			for k = -2, 2 do -- window guard bars
				Util.deco(folder, V3(0.15, 5.6, 0.15), cf * CFrame.new(x + k * 1.05, kerb + 5, front - 0.4), METAL_DARK, M.Metal)
			end
		end
	end
	wallPart(folder, V3(doorW + 3, gh - doorH - kerb, 1.2), cf * CFrame.new(0, kerb + doorH + (gh - doorH - kerb) / 2, front + 0.6), base)
	-- Door surround: pilasters, entablature and lamps.
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (doorW / 2 + 0.75)
		trimPart(folder, V3(1.5, doorH + 1, 1.6), cf * CFrame.new(x, kerb + (doorH + 1) / 2, front - 0.2), spec.trim)
		local lamp = Util.deco(folder, V3(0.7, 1.1, 0.7), cf * CFrame.new(x, kerb + doorH - 2, front - 1.4), Color3.fromRGB(255, 220, 160), M.Neon)
		lamp.CastShadow = false
	end
	trimPart(folder, V3(doorW + 4, 1.4, 2), cf * CFrame.new(0, kerb + doorH + 0.9, front - 0.4), spec.trim)
	-- The door itself, set into the opening, with a glass light above.
	local doorColor = Util.pick(rng, { Color3.fromRGB(40, 28, 20), Color3.fromRGB(20, 40, 30), Color3.fromRGB(24, 24, 28), Color3.fromRGB(90, 30, 30) })
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(doorW / 2 - 0.1, doorH - 2.5, 0.3), cf * CFrame.new(side * doorW / 4, kerb + (doorH - 2.5) / 2, front + 1.0), doorColor, M.Wood)
		local pane = Util.deco(folder, V3(doorW / 2 - 1.2, 3.6, 0.1), cf * CFrame.new(side * doorW / 4, kerb + 5.5, front + 0.82), GLASS, M.Glass)
		pane.Reflectance = 0.2
	end
	local fan = Util.deco(folder, V3(doorW - 0.4, 2.2, 0.2), cf * CFrame.new(0, kerb + doorH - 1.2, front + 1.0), Color3.fromRGB(255, 222, 170), M.Glass)
	fan.Transparency = 0.2
	-- Step and address number.
	Util.solid(folder, V3(doorW + 4, 0.5, 2.4), cf * CFrame.new(0, kerb + 0.25, front - 0.9), Util.shade(base.color, 0.9), M.Concrete)
	if spec.address then
		local plate = Util.deco(folder, V3(2.2, 1, 0.1), cf * CFrame.new(doorW / 2 + 0.75, kerb + 7, front - 1.06), Color3.fromRGB(30, 30, 30), M.Metal)
		Util.sign(plate, Front, spec.address, Color3.fromRGB(230, 200, 120), Enum.Font.Merriweather)
	end
	-- Lobby glow behind the door.
	local glow = Util.deco(folder, V3(doorW, doorH, 0.2), cf * CFrame.new(0, kerb + doorH / 2, front + 1.4), Color3.fromRGB(230, 200, 150), M.SmoothPlastic)
	glow.CastShadow = false
end

---------------------------------------------------------------------------
-- Fire escape on the street front
---------------------------------------------------------------------------
function Facade.fireEscape(folder, cf, w, d, y0, floors, floorH)
	local width = math.min(14, w * 0.5)
	local fz = -d / 2 - 2
	local steel = Color3.fromRGB(30, 30, 32)
	for f = 0, floors - 1 do
		local y = y0 + f * floorH + 0.2
		Util.deco(folder, V3(width, 0.25, 3.4), cf * CFrame.new(0, y, fz), steel, M.DiamondPlate)
		Util.deco(folder, V3(width, 0.15, 0.15), cf * CFrame.new(0, y + 3, fz - 1.65), steel, M.Metal)
		Util.deco(folder, V3(width, 0.15, 0.15), cf * CFrame.new(0, y + 1.5, fz - 1.65), steel, M.Metal)
		for k = 0, math.floor(width / 2.5) do
			Util.deco(folder, V3(0.12, 3, 0.12), cf * CFrame.new(-width / 2 + k * 2.5, y + 1.5, fz - 1.65), steel, M.Metal)
		end
		if f < floors - 1 then
			local a = (cf * CFrame.new(-width / 2 + 1.2, y + 0.2, fz + 0.5)).Position
			local b = (cf * CFrame.new(width / 2 - 2.5, y + floorH, fz + 0.5)).Position
			Util.beam(folder, a, b, 0.9, steel, M.Metal)
		end
	end
	-- Drop ladder down toward the sidewalk.
	Util.deco(folder, V3(1.4, 7, 0.15), cf * CFrame.new(width / 2 - 1, y0 - 3.5, fz - 1.2), steel, M.Metal)
end

return Facade
