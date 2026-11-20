-- Station architecture kit: reusable pieces for subway stations.
--
--   * helpers   – stairs, sloped spans, lights, signs, map markers, walls with gaps
--   * fittings  – benches, bins, cameras, clocks, ticket machines, ad panels, maps
--   * rooms     – two-tone tiled walls, ceilings with light panels, passages
--   * entrance  – a street-level entrance building (stairs, escalator, elevator)
--   * concourse – the ticket hall: fare line, booth, machines, signs, stairs down
--
-- Every station passes its own accent colour, so stations share materials but
-- each has its own identity (like the colour bands of Toronto's Line 1).
local CollectionService = game:GetService("CollectionService")

local Util = require(script.Parent.Util)
local Billboards = require(script.Parent.Billboards)
local Stores = require(script.Parent.Stores)
local Fares = require(script.Parent.Parent.Fares)

local Kit = {}

local V3 = Vector3.new
local M = Enum.Material
local Front = Enum.NormalId.Front
local C = Color3.fromRGB

Kit.TTC_RED = C(206, 30, 40)
Kit.CONCRETE = C(150, 148, 142)
Kit.DARK = C(40, 40, 44)
local STEEL = C(160, 162, 166)
local PAINT = C(226, 224, 218)
local FLOOR = C(176, 174, 168)
local CEILING = C(214, 214, 210)
local SIGN_BLACK = C(22, 22, 26)
local WHITE = C(255, 255, 255)
local TTC_RED = Kit.TTC_RED
local TILE_H = 6 -- height of the tiled band at the bottom of walls

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- A box from a to b (3D centre line), wide x thick, raised by lift.
function Kit.span(folder, a, b, wide, thick, lift, colour, material, solid)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return nil
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, lift, 0)
	local size = V3(wide, thick, length + 0.2)
	if solid then
		return Util.solid(folder, size, cf, colour, material)
	end
	return Util.deco(folder, size, cf, colour, material)
end

-- Straight flight of steps from top (Vector3) to bottom, `width` wide.
function Kit.stairs(folder, top, bottom, width, colour)
	local drop = top.Y - bottom.Y
	local steps = math.max(2, math.ceil(drop / 1.1))
	local flat = Vector3.new(bottom.X - top.X, 0, bottom.Z - top.Z)
	local dir = flat.Unit
	local run = flat.Magnitude / steps
	local rise = drop / steps
	for i = 0, steps - 1 do
		local y = top.Y - rise * (i + 1)
		local pos = Vector3.new(top.X, 0, top.Z) + dir * (run * (i + 0.5))
		Util.solid(folder, V3(width, rise + 0.1, run + 0.05), CFrame.lookAt(V3(pos.X, y + rise / 2, pos.Z), V3(pos.X + dir.X, y + rise / 2, pos.Z + dir.Z)) * CFrame.new(0, -rise / 2 + (rise + 0.1) / 2, 0), colour or Kit.CONCRETE, M.Concrete)
	end
	for _, side in ipairs({ -1, 1 }) do
		local right = V3(-dir.Z, 0, dir.X) * side * (width / 2 - 0.2)
		Kit.span(folder, top + right + V3(0, 3, 0), bottom + right + V3(0, 3, 0), 0.2, 0.2, 0, Kit.DARK, M.Metal, false)
	end
end

-- Steps built as solid blocks down to `floorY` (nothing hollow underneath).
-- top/bottom: Vector3 at the middle of the top and bottom edge.
function Kit.solidStairs(folder, top, bottom, width, floorY)
	local drop = top.Y - bottom.Y
	local steps = math.max(2, math.ceil(drop / 1.0))
	local flat = V3(bottom.X - top.X, 0, bottom.Z - top.Z)
	local dir = flat.Unit
	local run = flat.Magnitude / steps
	local rise = drop / steps
	for i = 1, steps - 1 do
		local tread = top.Y - rise * i
		local pos = V3(top.X, 0, top.Z) + dir * (run * (i - 0.5))
		local h = tread - floorY
		local cf = CFrame.lookAt(V3(pos.X, floorY + h / 2, pos.Z), V3(pos.X + dir.X, floorY + h / 2, pos.Z + dir.Z))
		Util.solid(folder, V3(width, h, run + 0.05), cf, C(168, 166, 160), M.Concrete)
		-- Yellow nosing on the first and last steps.
		if i == 1 or i == steps - 1 then
			Util.deco(folder, V3(width, 0.06, 0.5), cf * CFrame.new(0, h / 2 + 0.03, -run / 2 + 0.25), C(250, 200, 30), M.SmoothPlastic)
		end
	end
end

function Kit.light(part, face, range, brightness, colour)
	local l = Instance.new("SurfaceLight")
	l.Face = face or Enum.NormalId.Bottom
	l.Range = range or 14
	l.Brightness = brightness or 1
	l.Color = colour or C(240, 244, 255)
	l.Angle = 120
	l.Parent = part
	return l
end

function Kit.nameSign(folder, cf, size, text, colour, textColour)
	local plate = Util.deco(folder, size, cf, colour, M.SmoothPlastic)
	local gui = Util.sign(plate, Front, text, textColour or WHITE, Enum.Font.GothamBlack)
	gui.LightInfluence = 0.2
	return plate
end

-- Floating map marker (seen through buildings, like a GTA map icon). Tagged so the
-- client can hide them while the player is underground.
function Kit.marker(part, text, colour, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker"
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance or 1200
	gui.Size = UDim2.fromOffset(170, 34)
	gui.StudsOffset = Vector3.new(0, 10, 0)
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = colour
	label.BackgroundTransparency = 0.1
	label.TextColor3 = WHITE
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = part
	CollectionService:AddTag(gui, "MapMarker")
	return gui
end

-- A wall along x (alongX) or z between `from` and `to` at a fixed other
-- coordinate, from y0 to y1, leaving openings: gaps = list of { from, to }.
function Kit.wallWithGaps(folder, alongX, from, to, fixed, y0, y1, gaps, colour, material)
	local sorted = table.clone(gaps)
	table.sort(sorted, function(a, b)
		return a[1] < b[1]
	end)
	local cursor = from
	local function piece(p0, p1)
		local len = p1 - p0
		if len > 0.3 then
			local mid = (p0 + p1) / 2
			local size = alongX and V3(len, y1 - y0, 1) or V3(1, y1 - y0, len)
			local pos = alongX and V3(mid, (y0 + y1) / 2, fixed) or V3(fixed, (y0 + y1) / 2, mid)
			Util.solid(folder, size, CFrame.new(pos), colour, material)
		end
	end
	for _, g in ipairs(sorted) do
		if g[1] > cursor then
			piece(cursor, math.min(g[1], to))
		end
		cursor = math.max(cursor, g[2])
	end
	if cursor < to then
		piece(cursor, to)
	end
end

-- Station wall: glazed tile in the station's accent colour up to TILE_H, painted
-- above, with a dark trim line. Openings get a lintel above gapTop.
function Kit.wall(folder, alongX, from, to, fixed, y0, y1, gaps, accent, gapTop)
	local split = math.min(y0 + TILE_H, y1)
	Kit.wallWithGaps(folder, alongX, from, to, fixed, y0, split, gaps, accent, M.CeramicTiles)
	if y1 > split then
		Kit.wallWithGaps(folder, alongX, from, to, fixed, split, y1, gaps, PAINT, M.SmoothPlastic)
	end
	if gapTop and gapTop < y1 then
		for _, g in ipairs(gaps) do
			local a, b = math.max(g[1], from), math.min(g[2], to)
			if b - a > 0.3 then
				local mid = (a + b) / 2
				local size = alongX and V3(b - a, y1 - gapTop, 1) or V3(1, y1 - gapTop, b - a)
				local pos = alongX and V3(mid, (gapTop + y1) / 2, fixed) or V3(fixed, (gapTop + y1) / 2, mid)
				Util.solid(folder, size, CFrame.new(pos), PAINT, M.SmoothPlastic)
			end
		end
	end
end

-- Flat ceiling (deco) over a box with recessed light panels in rows; every other
-- panel casts light, which keeps the light count down.
function Kit.ceiling(folder, x0, x1, z0, z1, y, rows)
	local w, d = x1 - x0, z1 - z0
	Util.deco(folder, V3(w, 0.5, d), CFrame.new((x0 + x1) / 2, y + 0.25, (z0 + z1) / 2), CEILING, M.SmoothPlastic)
	rows = rows or { (x0 + x1) / 2 }
	local n = 0
	for _, x in ipairs(rows) do
		local z = z0 + 6
		while z < z1 - 3 do
			local panel = Util.deco(folder, V3(6.5, 0.15, 2), CFrame.new(x, y - 0.05, z), C(255, 250, 240), M.Neon)
			panel.CastShadow = false
			n = n + 1
			if n % 2 == 0 then
				Kit.light(panel, Enum.NormalId.Bottom, 16, 0.9, C(255, 244, 228))
			end
			z = z + 12
		end
	end
end

---------------------------------------------------------------------------
-- Fittings, sized for Roblox characters. cf: on the floor, Front facing the way
-- the object faces.
---------------------------------------------------------------------------
function Kit.bench(folder, cf)
	Util.solid(folder, V3(8, 0.5, 2.2), cf * CFrame.new(0, 2.2, 0), STEEL, M.Metal)
	Util.deco(folder, V3(8, 2.2, 0.3), cf * CFrame.new(0, 3.6, 1.05), STEEL, M.Metal)
	for _, x in ipairs({ -3.2, 3.2 }) do
		Util.solid(folder, V3(0.4, 2, 1.9), cf * CFrame.new(x, 1, 0), Kit.DARK, M.Metal)
	end
end

function Kit.bin(folder, cf)
	Util.solid(folder, V3(1.9, 3.8, 1.9), cf * CFrame.new(-1.05, 1.9, 0), C(60, 64, 70), M.Metal)
	Util.solid(folder, V3(1.9, 3.8, 1.9), cf * CFrame.new(1.05, 1.9, 0), C(30, 90, 170), M.Metal)
	Util.deco(folder, V3(4, 0.25, 2), cf * CFrame.new(0, 3.9, 0), C(30, 30, 32), M.Metal)
end

-- Ceiling camera: cf at the ceiling, Front facing where it looks.
function Kit.camera(folder, cf)
	Util.deco(folder, V3(0.4, 1, 0.4), cf * CFrame.new(0, -0.5, 0), Kit.DARK, M.Metal)
	Util.deco(folder, V3(0.8, 0.8, 1.8), cf * CFrame.new(0, -1.3, -0.5) * CFrame.Angles(math.rad(-20), 0, 0), C(230, 230, 230), M.SmoothPlastic)
	local led = Util.deco(folder, V3(0.2, 0.2, 0.1), cf * CFrame.new(0.25, -1.1, -1.4), C(255, 40, 40), M.Neon)
	led.CastShadow = false
end

-- Wall clock: cf at the wall face, Front facing the room.
function Kit.clock(folder, cf)
	local face = Instance.new("Part")
	face.Anchored = true
	face.CanCollide = false
	face.Shape = Enum.PartType.Cylinder
	face.Size = V3(0.5, 4, 4)
	face.CFrame = cf * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, math.rad(90), 0)
	face.Color = WHITE
	face.Material = M.SmoothPlastic
	face.Parent = folder
	Util.tick()
	Util.deco(folder, V3(0.24, 1.5, 0.05), cf * CFrame.new(0, 0.6, -0.55), Kit.DARK, M.SmoothPlastic)
	Util.deco(folder, V3(1.1, 0.24, 0.05), cf * CFrame.new(0.45, 0, -0.55), Kit.DARK, M.SmoothPlastic)
end

function Kit.ticketMachine(folder, cf)
	local body = Util.solid(folder, V3(4, 8.6, 2.4), cf * CFrame.new(0, 4.3, 0), C(48, 50, 56), M.Metal)
	Fares.attachMachine(body)
	Util.deco(folder, V3(4.1, 1, 2.5), cf * CFrame.new(0, 8.2, 0), TTC_RED, M.SmoothPlastic)
	local screen = Util.deco(folder, V3(3, 2.2, 0.1), cf * CFrame.new(0, 5.6, -1.22), C(40, 120, 200), M.Neon)
	screen.CastShadow = false
	local gui = Util.sign(screen, Front, "TRANSIT CARDS · TOP UP", WHITE, Enum.Font.GothamBold)
	gui.LightInfluence = 0
	Util.deco(folder, V3(1.6, 0.7, 0.2), cf * CFrame.new(0, 3.7, -1.25), C(20, 20, 20), M.SmoothPlastic)
	Util.deco(folder, V3(0.9, 0.9, 0.1), cf * CFrame.new(1.1, 4.5, -1.25), C(60, 200, 120), M.Neon).CastShadow = false
end

-- Lit, framed advertising panel on a wall. Tagged "AdPanel" for rotation later.
function Kit.adPanel(folder, cf, w, h, rng)
	Util.deco(folder, V3(w + 0.8, h + 0.8, 0.3), cf * CFrame.new(0, 0, 0.15), C(50, 52, 56), M.Metal)
	local panel = Util.deco(folder, V3(w, h, 0.2), cf * CFrame.new(0, 0, -0.1), C(240, 240, 240), M.SmoothPlastic)
	panel.CastShadow = false
	Billboards.face(panel, Front, Billboards.pick(rng), true)
	CollectionService:AddTag(panel, "AdPanel")
	return panel
end

-- System map: a line with a dot and the name for every station.
function Kit.mapBoard(folder, cf, w, h, title, stations, here)
	Util.deco(folder, V3(w + 0.6, h + 0.6, 0.3), cf * CFrame.new(0, 0, 0.15), C(50, 52, 56), M.Metal)
	local panel = Util.deco(folder, V3(w, h, 0.2), cf * CFrame.new(0, 0, -0.1), WHITE, M.SmoothPlastic)
	panel.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.3
	local head = Instance.new("TextLabel")
	head.Size = UDim2.fromScale(1, 0.2)
	head.BackgroundColor3 = SIGN_BLACK
	head.BorderSizePixel = 0
	head.TextColor3 = WHITE
	head.Font = Enum.Font.GothamBlack
	head.TextScaled = true
	head.Text = title
	head.Parent = gui
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0.9, 0.05)
	bar.Position = UDim2.fromScale(0.05, 0.5)
	bar.BackgroundColor3 = C(250, 200, 30)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	for i, name in ipairs(stations) do
		local x = 0.05 + 0.9 * (i - 1) / math.max(#stations - 1, 1)
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(x, 0.525)
		dot.Size = UDim2.fromOffset(18, 18)
		dot.BackgroundColor3 = name == here and TTC_RED or WHITE
		dot.BorderSizePixel = 0
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = dot
		dot.Parent = gui
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(x, i % 2 == 0 and 0.62 or 0.3)
		label.Size = UDim2.fromScale(0.22, 0.14)
		label.BackgroundTransparency = 1
		label.TextColor3 = name == here and TTC_RED or SIGN_BLACK
		label.Font = name == here and Enum.Font.GothamBlack or Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = name == here and (name .. " ●") or name
		label.Parent = gui
	end
	gui.Parent = panel
	return panel
end

-- Black hanging sign with white text on both faces, on two rods up to `ceilingY`.
function Kit.hangingSign(folder, cf, w, text, ceilingY, textColour)
	local plate = Util.deco(folder, V3(w, 2, 0.3), cf, SIGN_BLACK, M.SmoothPlastic)
	plate.CastShadow = false
	for _, face in ipairs({ Front, Enum.NormalId.Back }) do
		Util.sign(plate, face, text, textColour or WHITE, Enum.Font.GothamBold).LightInfluence = 0
	end
	local top = cf.Position.Y + 1
	if ceilingY and ceilingY > top + 0.2 then
		for _, x in ipairs({ -w / 3, w / 3 }) do
			local p = cf * CFrame.new(x, 0, 0)
			Util.deco(folder, V3(0.15, ceilingY - top, 0.15), CFrame.new(p.X, (top + ceilingY) / 2, p.Z), Kit.DARK, M.Metal)
		end
	end
	return plate
end

-- Small green EXIT sign: cf at the sign, Front facing the viewer.
function Kit.exitSign(folder, cf, text)
	local plate = Util.deco(folder, V3(4.8, 1.2, 0.25), cf, C(20, 120, 60), M.SmoothPlastic)
	plate.CastShadow = false
	for _, face in ipairs({ Front, Enum.NormalId.Back }) do
		Util.sign(plate, face, text or "EXIT", WHITE, Enum.Font.GothamBold).LightInfluence = 0
	end
end

-- Red emergency point (alarm + intercom) on a wall.
function Kit.emergency(folder, cf)
	Util.deco(folder, V3(1.9, 3, 0.4), cf * CFrame.new(0, 0, -0.2), C(200, 30, 30), M.SmoothPlastic)
	local label = Util.deco(folder, V3(1.8, 0.7, 0.05), cf * CFrame.new(0, 1, -0.42), WHITE, M.SmoothPlastic)
	Util.sign(label, Front, "EMERGENCY", C(200, 30, 30), Enum.Font.GothamBold)
end

-- Hanging departure board (both faces), on rods up to ceilingY. Tagged
-- "DepartureBoard" with Station and Bound ("N"/"S") attributes; the timetable
-- fills its Title / Next / Following / Status labels.
function Kit.departureBoard(folder, cf, stationName, bound, ceilingY)
	local board = Util.deco(folder, V3(8.6, 3.2, 0.5), cf, C(14, 14, 16), M.SmoothPlastic)
	board.Name = "DepartureBoard"
	board.CastShadow = false
	board:SetAttribute("Station", stationName)
	board:SetAttribute("Bound", bound)
	local title = bound == "N" and "LINE 1 · NORTHBOUND · FINCH" or "LINE 1 · SOUTHBOUND · PORTLANDS"
	for _, face in ipairs({ Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		local rows = {
			{ "Title", title, C(255, 190, 40), 0.02, 0.26 },
			{ "Next", "NEXT TRAIN      --:--", C(255, 214, 90), 0.3, 0.22 },
			{ "Following", "FOLLOWING       --:--", C(255, 214, 90), 0.53, 0.2 },
			{ "Status", "STATUS  ON TIME", C(120, 230, 120), 0.76, 0.2 },
		}
		for _, row in ipairs(rows) do
			local label = Instance.new("TextLabel")
			label.Name = row[1]
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(0.04, row[4])
			label.Size = UDim2.fromScale(0.92, row[5])
			label.Font = Enum.Font.Code
			label.TextScaled = true
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = row[3]
			label.Text = row[2]
			label.Parent = gui
		end
		gui.Parent = board
	end
	Util.deco(folder, V3(8.8, 0.3, 0.7), cf * CFrame.new(0, 1.75, 0), C(60, 62, 66), M.Metal)
	local top = cf.Position.Y + 1.9
	if ceilingY > top then
		for _, x in ipairs({ -3.2, 3.2 }) do
			local p = cf * CFrame.new(x, 0, 0)
			Util.deco(folder, V3(0.15, ceilingY - top, 0.15), CFrame.new(p.X, (top + ceilingY) / 2, p.Z), Kit.DARK, M.Metal)
		end
	end
	CollectionService:AddTag(board, "DepartureBoard")
	return board
end

-- Railway signal on a mast: cf at the foot, Front facing approaching trains.
-- Tagged "RailSignal"; shows green until the timetable drives it.
function Kit.signal(folder, cf, stationName, bound)
	Util.solid(folder, V3(0.5, 7, 0.5), cf * CFrame.new(0, 3.5, 0), C(40, 40, 44), M.Metal)
	local head = Util.solid(folder, V3(1.4, 3.4, 1), cf * CFrame.new(0, 7.6, 0), C(20, 20, 22), M.Metal)
	head:SetAttribute("Station", stationName)
	head:SetAttribute("Bound", bound)
	CollectionService:AddTag(head, "RailSignal")
	local lamps = { { "Red", 1, C(90, 20, 18) }, { "Green", -1, C(60, 255, 120) } }
	for _, l in ipairs(lamps) do
		local lamp = Util.deco(folder, V3(0.8, 0.8, 0.2), cf * CFrame.new(0, 7.6 + l[2] * 0.8, -0.55), l[3], l[1] == "Green" and M.Neon or M.SmoothPlastic)
		lamp.Name = l[1]
		lamp.CastShadow = false
		lamp.Parent = head
	end
	Util.deco(folder, V3(1.8, 0.2, 0.6), cf * CFrame.new(0, 9.4, -0.4), C(20, 20, 22), M.Metal)
end

---------------------------------------------------------------------------
-- Station shops: small walk-up stores set against a wall (counter at the front,
-- shelves behind, a lit sign on top). Buying uses the city's store system.
-- cf: on the floor at the wall face, Front facing into the room; w: width.
---------------------------------------------------------------------------
local SHOPS = {
	{ kind = "coffee", name = "GRIND COFFEE", colour = C(70, 44, 30), accent = C(232, 176, 100) },
	{ kind = "bodega", name = "NEWS & SNACKS", colour = C(28, 56, 140), accent = C(255, 214, 80) },
	{ kind = "pizza", name = "SLICE STOP", colour = C(170, 36, 28), accent = C(255, 224, 160) },
	{ kind = "pharmacy", name = "CITY PHARMACY", colour = C(236, 238, 236), accent = C(30, 140, 90) },
	{ kind = "electronics", name = "PHONE FIX", colour = C(20, 24, 40), accent = C(90, 210, 255) },
	{ kind = "coffee", name = "MAPLE DONUTS", colour = C(140, 30, 44), accent = C(255, 236, 220) },
	{ kind = "clothes", name = "METRO SOCKS", colour = C(64, 40, 96), accent = C(255, 160, 220) },
	{ kind = "bodega", name = "FRESH JUICE", colour = C(40, 120, 60), accent = C(255, 230, 90) },
}
local shopCount = 0

function Kit.shop(folder, cf, w, rng)
	shopCount = shopCount + 1
	local shop = SHOPS[(shopCount + rng:NextInteger(0, 2)) % #SHOPS + 1]
	local depth, h = 6, 9.5
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	for _, x in ipairs({ -w / 2 + 0.25, w / 2 - 0.25 }) do
		Util.solid(folder, V3(0.5, h, depth), at(x, h / 2, -depth / 2), shop.colour, M.SmoothPlastic)
	end
	Util.solid(folder, V3(w, 0.6, depth + 0.4), at(0, h + 0.3, -depth / 2 - 0.2), shop.colour, M.SmoothPlastic)
	local header = Util.deco(folder, V3(w, 1.9, 0.4), at(0, h - 0.95, -depth - 0.2), shop.colour, M.SmoothPlastic)
	header.CastShadow = false
	Util.sign(header, Front, shop.name, shop.accent, Enum.Font.GothamBlack).LightInfluence = 0
	local glow = Util.deco(folder, V3(w - 1, 0.15, 0.6), at(0, h - 2.05, -depth + 0.2), C(255, 246, 228), M.Neon)
	glow.CastShadow = false
	Kit.light(glow, Enum.NormalId.Bottom, 12, 1, C(255, 240, 214))
	-- Inside: floor, back panel with shelves and goods.
	Util.deco(folder, V3(w - 1, 0.1, depth), at(0, 0.05, -depth / 2), C(150, 112, 76), M.Wood)
	Util.deco(folder, V3(w - 1, h - 2.4, 0.3), at(0, (h - 2.4) / 2 + 0.2, -0.25), Util.shade(shop.colour, 1.25), M.SmoothPlastic)
	local goods = { C(220, 60, 50), C(250, 200, 60), C(60, 140, 220), C(240, 240, 236), C(90, 190, 110), shop.accent }
	for _, y in ipairs({ 2.6, 4.6, 6.6 }) do
		Util.deco(folder, V3(w - 2, 0.25, 1.3), at(0, y, -1), C(120, 90, 64), M.Wood)
		local x = -w / 2 + 1.8
		while x < w / 2 - 1.8 do
			local size = V3(rng:NextNumber(0.6, 1.1), rng:NextNumber(0.7, 1.4), 0.8)
			Util.deco(folder, size, at(x, y + 0.125 + size.Y / 2, -1), goods[rng:NextInteger(1, #goods)], M.SmoothPlastic)
			x = x + size.X + rng:NextNumber(0.2, 0.6)
		end
	end
	-- Counter across the front (buy from it), register on top.
	Util.solid(folder, V3(w - 1, 3.6, 1.6), at(0, 1.8, -depth + 0.8), shop.colour, M.SmoothPlastic)
	local top = Util.solid(folder, V3(w - 0.8, 0.25, 1.9), at(0, 3.72, -depth + 0.8), C(220, 216, 208), M.Marble)
	Util.deco(folder, V3(1.4, 1, 1), at(w / 2 - 2.2, 4.35, -depth + 0.9), C(40, 40, 44), M.SmoothPlastic)
	Stores.attachPurchase(top, shop.kind, shop.name)
end

---------------------------------------------------------------------------
-- Passage: a straight tiled corridor with a ceiling, lights, ads and benches.
-- alongX: runs along x from a0 to a1 at z = c (else along z at x = c).
-- gaps.minus / gaps.plus: openings in the two long walls (lists of {from, to});
-- closeA / closeB: build an end wall at a0 / a1.
---------------------------------------------------------------------------
function Kit.passage(folder, alongX, a0, a1, c, half, y0, y1, accent, gaps, closeA, closeB, rng)
	if a1 < a0 then
		a0, a1 = a1, a0
		closeA, closeB = closeB, closeA
	end
	local len = a1 - a0
	if len < 1 then
		return
	end
	local mid = (a0 + a1) / 2
	local function pos(a, off, y)
		if alongX then
			return V3(a, y, c + off)
		end
		return V3(c + off, y, a)
	end
	-- Floor, ceiling.
	local floorSize = alongX and V3(len, 1, half * 2) or V3(half * 2, 1, len)
	Util.solid(folder, floorSize, CFrame.new(pos(mid, 0, y0 - 0.5)), FLOOR, M.Granite)
	if alongX then
		Kit.ceiling(folder, a0, a1, c - half, c + half, y1, nil)
	else
		Kit.ceiling(folder, c - half, c + half, a0, a1, y1, nil)
	end
	-- Walls.
	for _, side in ipairs({ -1, 1 }) do
		local g = (side < 0 and gaps.minus or gaps.plus) or {}
		Kit.wall(folder, alongX, a0, a1, c + side * (half + 0.5), y0, y1, g, accent, nil)
	end
	for _, info in ipairs({ { closeA, a0 - 0.5 }, { closeB, a1 + 0.5 } }) do
		if info[1] then
			Kit.wall(folder, not alongX, c - half - 1, c + half + 1, info[2], y0, y1, {}, accent, nil)
		end
	end
	-- Ads along the walls (not in front of openings), a bench in long passages.
	local function blocked(list, a, w)
		for _, g in ipairs(list or {}) do
			if a + w > g[1] - 2 and a - w < g[2] + 2 then
				return true
			end
		end
		return false
	end
	local shopAt = nil
	if len >= 44 then
		local mid2 = (a0 + a1) / 2
		for _, side in ipairs({ -1, 1 }) do
			local list = side < 0 and gaps.minus or gaps.plus
			if not shopAt and not blocked(list, mid2, 8) then
				shopAt = { a = mid2, side = side }
				local p = pos(mid2, side * half, y0)
				local inward = alongX and V3(0, 0, -side) or V3(-side, 0, 0)
				Kit.shop(folder, CFrame.lookAt(p, p + inward), 14, rng)
			end
		end
	end
	local a = a0 + 12
	local k = 0
	while a < a1 - 12 do
		local side = (k % 2 == 0) and -1 or 1
		local list = side < 0 and gaps.minus or gaps.plus
		local nearShop = shopAt and shopAt.side == side and math.abs(a - shopAt.a) < 12
		if not blocked(list, a, 5) and not nearShop then
			local p = pos(a, side * half, y0 + TILE_H + 3.4)
			local inward = alongX and V3(0, 0, -side) or V3(-side, 0, 0)
			Kit.adPanel(folder, CFrame.lookAt(p + inward * 0.1, p + inward * 2), 9, 5.4, rng)
			if len > 50 and k == 1 then
				local b = pos(a, side * (half - 1.8), y0)
				Kit.bench(folder, CFrame.lookAt(b, b + inward))
			end
		end
		a = a + 20
		k = k + 1
	end
end

---------------------------------------------------------------------------
-- Street entrance building.
-- e = { spot (Vector2), sz (+1: walk in from -z, stairs go down toward +z),
--       toward (+1/-1: the line is toward +x / -x), reach (distance from the spot
--       to the sidewalk), passZ }
-- In entrance coordinates, x runs across and dz along the way in:
--   dz -26..-21 canopy over the apron, -21..-13 landing, -13..19 stairs and
--   escalator going down, 19..41.5 the lobby at concourse level; the building
--   above ground covers dz -21..10.5. Across: stairs x -22..1, escalator 2..9,
--   divider 9..10.5, side walkway and elevator 10.5..22.
---------------------------------------------------------------------------
local E = {
	HALF_W = 22,
	CANOPY = -26,
	LAND0 = -21,
	STAIR0 = -13,
	STAIR1 = 19,
	LOBBY1 = 41.5,
	HOUSE_BACK = 10.5,
	HOUSE_H = 14,
	STAIR_X0 = -22, STAIR_X1 = 1,
	ESC_X0 = 2, ESC_X1 = 9,
	DIV_X0 = 9, DIV_X1 = 10.5,
	WALK_X1 = 22,
	CAB_X0 = 12, CAB_X1 = 20.5, CAB_Z0 = 1, CAB_Z1 = 10,
	CAB_H = 11,
}
Kit.ENTRANCE = E

function Kit.entrance(folder, e, station, geo, rng)
	local spot, sz = e.spot, e.sz
	local kerb = Util.WALK_TOP
	local y0 = geo.floor -- underground floor level
	local accent = station.tile
	local HW = E.HALF_W
	local function at(x, y, dz)
		return CFrame.new(spot.X + x, y, spot.Y + dz * sz)
	end
	local function p3(x, y, dz)
		return V3(spot.X + x, y, spot.Y + dz * sz)
	end
	local turn = sz > 0 and CFrame.identity or CFrame.Angles(0, math.pi, 0) -- Front faces the street
	local backTurn = turn * CFrame.Angles(0, math.pi, 0) -- Front faces into the station
	local GRANITE = C(176, 172, 164)
	local width = HW * 2

	-- Street level: apron to the sidewalk, landing, side walkway.
	local apron = math.max(e.reach - (-E.LAND0), 1)
	Util.solid(folder, V3(width + 2, 1, apron), at(0, kerb - 0.52, E.LAND0 - apron / 2), C(150, 146, 138), M.Concrete)
	Util.solid(folder, V3(width, 1, E.STAIR0 - E.LAND0), at(0, kerb - 0.5, (E.LAND0 + E.STAIR0) / 2), GRANITE, M.Granite)
	local walkW = E.WALK_X1 - E.DIV_X1
	local walkX = (E.WALK_X1 + E.DIV_X1) / 2
	Util.solid(folder, V3(walkW, 1, E.HOUSE_BACK - E.STAIR0), at(walkX, kerb - 0.5, (E.STAIR0 + E.HOUSE_BACK) / 2), GRANITE, M.Granite)

	-- Stairs (solid underneath) with handrails.
	local stairW = E.STAIR_X1 - E.STAIR_X0
	local stairX = (E.STAIR_X0 + E.STAIR_X1) / 2
	Kit.solidStairs(folder, p3(stairX, kerb, E.STAIR0), p3(stairX, y0, E.STAIR1), stairW, y0 - 0.5)
	for _, x in ipairs({ E.STAIR_X0 + 0.5, stairX, E.STAIR_X1 - 0.4 }) do
		Kit.span(folder, p3(x, kerb + 3.6, E.STAIR0), p3(x, y0 + 3.6, E.STAIR1), 0.3, 0.3, 0, Kit.DARK, M.Metal, false)
		Kit.span(folder, p3(x, kerb + 1.8, E.STAIR0), p3(x, y0 + 1.8, E.STAIR1), 0.15, 3.6, 0, STEEL, M.Metal, false)
	end

	-- Up escalator: a moving surface (anchored part with a velocity carries you up),
	-- steel balustrades with black handrails.
	local escX = (E.ESC_X0 + E.ESC_X1) / 2
	local escTop, escBottom = p3(escX, kerb, E.STAIR0), p3(escX, y0, E.STAIR1)
	local belt = Kit.span(folder, escTop, escBottom, E.ESC_X1 - E.ESC_X0, 1, -0.5, C(150, 152, 158), M.DiamondPlate, true)
	if belt then
		belt.AssemblyLinearVelocity = (escTop - escBottom).Unit * 6
		belt.Name = "Escalator"
	end
	local balX = (E.STAIR_X1 + E.ESC_X0) / 2
	Kit.span(folder, p3(balX, kerb, E.STAIR0), p3(balX, y0, E.STAIR1), E.ESC_X0 - E.STAIR_X1, 4.2, 2.1, STEEL, M.Metal, true)
	Kit.span(folder, p3(balX, kerb, E.STAIR0), p3(balX, y0, E.STAIR1), 1.2, 0.35, 4.3, C(15, 15, 15), M.Rubber, false)
	for _, info in ipairs({ { E.STAIR0 - 1, kerb }, { E.STAIR1 + 1, y0 } }) do
		Util.deco(folder, V3(E.ESC_X1 - E.ESC_X0, 0.1, 2.4), at(escX, info[2] + 0.05, info[1]), C(200, 200, 204), M.DiamondPlate)
	end
	local upSign = Util.deco(folder, V3(7, 1.4, 0.2), at(escX, y0 + 11, E.STAIR1 + 0.6) * turn, SIGN_BLACK, M.SmoothPlastic)
	Util.sign(upSign, Front, "▲ UP TO STREET", C(120, 255, 140), Enum.Font.GothamBold).LightInfluence = 0

	-- Divider between the escalator and the walkway/elevator: tile below, glass above.
	local divX = (E.DIV_X0 + E.DIV_X1) / 2
	local divW = E.DIV_X1 - E.DIV_X0
	Util.solid(folder, V3(divW, kerb - y0, E.STAIR1 - E.STAIR0), at(divX, (kerb + y0) / 2, (E.STAIR0 + E.STAIR1) / 2), accent, M.CeramicTiles)
	local guard = Util.solid(folder, V3(0.4, 4.2, E.HOUSE_BACK - E.STAIR0), at(divX, kerb + 2.1, (E.STAIR0 + E.HOUSE_BACK) / 2), C(200, 220, 228), M.Glass)
	guard.Transparency = 0.5
	Util.deco(folder, V3(0.7, 0.3, E.HOUSE_BACK - E.STAIR0), at(divX, kerb + 4.3, (E.STAIR0 + E.HOUSE_BACK) / 2), STEEL, M.Metal)
	-- Close the space under the walkway behind the lower elevator.
	Util.solid(folder, V3(walkW, kerb - 1 - y0, 1), at(walkX, (kerb - 1 + y0) / 2, E.CAB_Z0 - 0.5), accent, M.CeramicTiles)

	-- Underground: side walls (opening on the line side), front and end walls,
	-- lobby floor, lower walkway floor, lobby ceiling.
	for _, side in ipairs({ -1, 1 }) do
		local gaps = {}
		if side == e.toward then
			table.insert(gaps, { e.passZ - 10, e.passZ + 10 })
		end
		local w0, w1 = spot.Y + (E.LAND0 - 0.5) * sz, spot.Y + (E.LOBBY1 + 0.5) * sz
		Kit.wall(folder, false, math.min(w0, w1), math.max(w0, w1), spot.X + side * (HW + 0.5), y0, kerb, gaps, accent, geo.passageTop)
	end
	Util.solid(folder, V3(width + 2, kerb - 1 - y0, 1), at(0, (kerb - 1 + y0) / 2, E.LAND0 - 0.5), accent, M.CeramicTiles)
	Kit.wall(folder, true, spot.X - HW - 1, spot.X + HW + 1, spot.Y + (E.LOBBY1 + 0.5) * sz, y0, geo.ceilingTop, {}, accent, nil)
	Util.solid(folder, V3(width, 1, E.LOBBY1 - E.STAIR1 + 2), at(0, y0 - 0.5, (E.STAIR1 - 2 + E.LOBBY1) / 2), FLOOR, M.Granite)
	Util.solid(folder, V3(walkW, 1, E.STAIR1 - E.CAB_Z0 + 0.5), at(walkX, y0 - 0.5, (E.CAB_Z0 - 0.5 + E.STAIR1) / 2), FLOOR, M.Granite)
	local c0, c1 = spot.Y + E.HOUSE_BACK * sz, spot.Y + E.LOBBY1 * sz
	Kit.ceiling(folder, spot.X - HW, spot.X + HW, math.min(c0, c1), math.max(c0, c1), geo.passageTop, { spot.X - 11, spot.X + 11 })
	Kit.hangingSign(folder, at(0, geo.passageTop - 2, E.LOBBY1 - 0.8) * turn, 18, "◀ ▶  TRAINS · LINE 1", geo.passageTop)
	Kit.exitSign(folder, at(stairX, y0 + 12, E.STAIR1 + 0.3) * turn, "EXIT ▲ STREET")
	Kit.bin(folder, at(-HW + 3, y0, E.LOBBY1 - 1.5) * turn)
	Kit.camera(folder, at(HW - 2, geo.passageTop, E.LOBBY1 - 2) * turn)

	-- Above ground: steel-and-glass building over the stairs, canopy, signs.
	local houseLen = E.HOUSE_BACK - E.LAND0
	local houseMid = (E.HOUSE_BACK + E.LAND0) / 2
	for _, side in ipairs({ -1, 1 }) do
		local glass = Util.solid(folder, V3(0.4, E.HOUSE_H, houseLen), at(side * HW, kerb + E.HOUSE_H / 2, houseMid), C(190, 214, 224), M.Glass)
		glass.Transparency = 0.45
		for dz = E.LAND0, E.HOUSE_BACK, houseLen / 4 do
			Util.solid(folder, V3(0.8, E.HOUSE_H, 0.8), at(side * HW, kerb + E.HOUSE_H / 2, dz), Kit.DARK, M.Metal)
		end
		Util.solid(folder, V3(1, E.HOUSE_H, 1), at(side * HW, kerb + E.HOUSE_H / 2, E.CANOPY + 0.5), Kit.DARK, M.Metal)
	end
	Util.solid(folder, V3(width, kerb + 1.75, 0.8), at(0, (kerb - 1.75) / 2, E.HOUSE_BACK + 0.4), Kit.CONCRETE, M.Concrete)
	local back = Util.solid(folder, V3(width, E.HOUSE_H, 0.4), at(0, kerb + E.HOUSE_H / 2, E.HOUSE_BACK), C(190, 214, 224), M.Glass)
	back.Transparency = 0.45
	local roofLen = E.HOUSE_BACK - E.CANOPY
	Util.solid(folder, V3(width + 2, 1, roofLen), at(0, kerb + E.HOUSE_H + 0.5, (E.HOUSE_BACK + E.CANOPY) / 2), Kit.DARK, M.Metal)
	Util.deco(folder, V3(width + 2.4, 0.4, roofLen + 0.4), at(0, kerb + E.HOUSE_H + 1.1, (E.HOUSE_BACK + E.CANOPY) / 2), C(120, 122, 126), M.Metal)
	for _, dz in ipairs({ -17, -3 }) do
		local strip = Util.deco(folder, V3(26, 0.15, 1.4), at(0, kerb + E.HOUSE_H - 0.05, dz), C(255, 248, 236), M.Neon)
		strip.CastShadow = false
		Kit.light(strip, Enum.NormalId.Bottom, 22, 1.3, C(255, 244, 226))
	end
	-- Fascia sign over the way in: TTC SUBWAY, the station name under it.
	local board = Util.deco(folder, V3(34, 3.4, 0.6), at(0, kerb + E.HOUSE_H - 1.9, E.CANOPY + 0.2) * turn, WHITE, M.SmoothPlastic)
	board.CastShadow = false
	for _, face in ipairs({ Front, Enum.NormalId.Back }) do
		Util.sign(board, face, "TTC   SUBWAY", TTC_RED, Enum.Font.GothamBlack).LightInfluence = 0
	end
	Kit.marker(board, "🚇 " .. station.name, TTC_RED)
	local band = Util.deco(folder, V3(34, 1.8, 0.5), at(0, kerb + E.HOUSE_H - 4.5, E.CANOPY + 0.2) * turn, SIGN_BLACK, M.SmoothPlastic)
	band.CastShadow = false
	for _, face in ipairs({ Front, Enum.NormalId.Back }) do
		Util.sign(band, face, station.name .. " STATION", WHITE, Enum.Font.GothamBold).LightInfluence = 0
	end
	-- Red TTC pylon at the corner of the apron.
	local pylon = Util.solid(folder, V3(1.6, 20, 4), at(-HW + 1.5, kerb + 10, E.CANOPY - 2), TTC_RED, M.SmoothPlastic)
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right, Front, Enum.NormalId.Back }) do
		Util.sign(pylon, face, "TTC", WHITE, Enum.Font.GothamBlack).LightInfluence = 0
	end
	local cap = Util.deco(folder, V3(2, 1.2, 4.4), at(-HW + 1.5, kerb + 20.6, E.CANOPY - 2), C(255, 70, 70), M.Neon)
	cap.CastShadow = false
	-- Information panel on the landing.
	local info = Util.solid(folder, V3(5.4, 7.6, 0.6), at(-HW + 3.5, kerb + 3.8, E.LAND0 + 4) * turn, SIGN_BLACK, M.Metal)
	Util.sign(info, Front, "LINE 1 YONGE\n◀ STAIRS   ESCALATOR ▲\nELEVATOR ▶", WHITE, Enum.Font.GothamBold).LightInfluence = 0

	-- Elevator: a cab at street level on the walkway and one below; the call
	-- button takes you to the other one.
	local cabs = {}
	local cabX = (E.CAB_X0 + E.CAB_X1) / 2
	local cabW = E.CAB_X1 - E.CAB_X0
	local cabMid = (E.CAB_Z0 + E.CAB_Z1) / 2
	for i, info2 in ipairs({ { kerb, E.CAB_Z0 }, { y0, E.CAB_Z1 } }) do
		local y, doorDz = info2[1], info2[2]
		local backDz = doorDz == E.CAB_Z0 and E.CAB_Z1 or E.CAB_Z0
		for _, x in ipairs({ E.CAB_X0, E.CAB_X1 }) do
			local wall = Util.solid(folder, V3(0.4, E.CAB_H, E.CAB_Z1 - E.CAB_Z0), at(x, y + E.CAB_H / 2, cabMid), C(190, 214, 224), M.Glass)
			wall.Transparency = 0.35
		end
		Util.solid(folder, V3(cabW + 0.4, E.CAB_H, 0.4), at(cabX, y + E.CAB_H / 2, backDz), C(120, 124, 130), M.Metal)
		for _, x in ipairs({ E.CAB_X0 + 0.8, E.CAB_X1 - 0.8 }) do
			Util.solid(folder, V3(1.6, E.CAB_H, 0.5), at(x, y + E.CAB_H / 2, doorDz), C(150, 152, 156), M.Metal)
		end
		Util.solid(folder, V3(cabW + 0.4, 1.4, 0.5), at(cabX, y + E.CAB_H - 0.7, doorDz), C(150, 152, 156), M.Metal)
		local top = Util.solid(folder, V3(cabW + 0.4, 0.5, E.CAB_Z1 - E.CAB_Z0 + 0.4), at(cabX, y + E.CAB_H + 0.25, cabMid), C(120, 124, 130), M.Metal)
		Kit.light(top, Enum.NormalId.Bottom, 12, 1)
		local signTurn = doorDz == E.CAB_Z0 and turn or backTurn
		local label = Util.deco(folder, V3(7, 1, 0.2), at(cabX, y + E.CAB_H - 0.7, doorDz) * signTurn * CFrame.new(0, 0, -0.3), SIGN_BLACK, M.SmoothPlastic)
		Util.sign(label, Front, i == 1 and "ELEVATOR ▼ TRAINS" or "ELEVATOR ▲ STREET", WHITE, Enum.Font.GothamBold).LightInfluence = 0
		local panel = Util.solid(folder, V3(0.3, 2, 1), at(E.CAB_X1 - 0.4, y + 4.6, cabMid), C(40, 40, 44), M.Metal)
		cabs[i] = { panel = panel, centre = at(cabX, y + 3, cabMid) }
	end
	for i, cab in ipairs(cabs) do
		local other = cabs[3 - i]
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = i == 1 and "Go down to the trains" or "Go up to the street"
		prompt.ObjectText = "Elevator"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = cab.panel
		prompt.Triggered:Connect(function(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - cab.centre.Position).Magnitude < 14 then
				local offset = cab.centre:ToObjectSpace(root.CFrame)
				character:PivotTo(other.centre * offset)
			end
		end)
	end
end

-- A row of fare gates across x from x0 at z, floor y0. paidDir: +1 if the paid
-- side is toward +z. lanes = list of { w = width, entry = true/false }.
-- Flaps are solid; tapping a card at an entry lane's reader opens that lane for
-- you, and exit lanes open by themselves as you walk up from the paid side
-- (client/FareGates.client.lua). Returns the x where the row ends.
local gateCount = 0
function Kit.fareGates(folder, x0, z, y0, paidDir, stationName, lanes)
	local cabW = 1.1
	local x = x0
	local function cabinet()
		Util.solid(folder, V3(cabW, 4.6, 5.4), CFrame.new(x + cabW / 2, y0 + 2.3, z), C(56, 58, 64), M.Metal)
		Util.deco(folder, V3(cabW, 0.15, 5.4), CFrame.new(x + cabW / 2, y0 + 4.68, z), C(200, 210, 216), M.Glass)
	end
	for _, lane in ipairs(lanes) do
		cabinet()
		gateCount = gateCount + 1
		local gateId = stationName .. "_" .. gateCount
		local lx = x + cabW + lane.w / 2
		local entry = lane.entry
		-- Reader on the cabinet, on the side you approach from.
		local approach = entry and -paidDir or paidDir
		local reader = Util.deco(folder, V3(0.9, 0.14, 0.9), CFrame.new(x + cabW / 2, y0 + 4.8, z + approach * 1.9), entry and C(60, 220, 110) or C(220, 70, 60), M.Neon)
		reader.CastShadow = false
		if entry then
			Fares.attachGate(reader, gateId)
		end
		for _, s in ipairs({ -1, 1 }) do
			local flap = Util.solid(folder, V3(lane.w / 2 - 0.25, 2.7, 0.2), CFrame.new(lx + s * (lane.w / 4), y0 + 2.7, z), C(200, 220, 228), M.Glass)
			flap.Transparency = 0.4
			flap.Name = "Flap"
			flap:SetAttribute("GateId", gateId)
			flap:SetAttribute("Entry", entry)
			flap:SetAttribute("PaidDir", paidDir)
			CollectionService:AddTag(flap, "FareGate")
			-- The startup path check should treat the gates as passable.
			local through = Instance.new("PathfindingModifier")
			through.PassThrough = true
			through.Parent = flap
		end
		local arrow = Util.deco(folder, V3(lane.w - 0.5, 0.05, 2.2), CFrame.new(lx, y0 + 0.03, z + approach * 4.2), entry and C(60, 200, 110) or C(210, 70, 60), M.SmoothPlastic)
		arrow.CastShadow = false
		x = x + cabW + lane.w
	end
	cabinet()
	return x + cabW
end

---------------------------------------------------------------------------
-- Ticket hall (concourse) over the north end of the platform.
-- geo = { x (line), floor, top, passageTop, z0, z1, fareZ, stair0, stair1,
--         platformTop, half (half-width), gapsWest, gapsEast, gapsNorth, stations }
---------------------------------------------------------------------------
function Kit.concourse(folder, station, geo, rng)
	local X, y0, y1 = geo.x, geo.floor, geo.top
	local z0, z1, fz = geo.z0, geo.z1, geo.fareZ
	local s0, s1 = geo.stair0, geo.stair1
	local H = geo.half
	local O = 6.25 -- half-width of the platform stairs
	local A = 12 -- half-width of the open atrium over the platform
	local a1 = z1 - 6 -- south end of the atrium
	local accent = station.tile
	local function face(p, dir)
		return CFrame.lookAt(p, p + dir)
	end

	-- Floor round an open atrium over the platform: you look straight down on the
	-- trains, and the stairs go down through it.
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(H - A, 1, z1 - z0), CFrame.new(X + side * (A + (H - A) / 2), y0 - 0.5, (z0 + z1) / 2), FLOOR, M.Granite)
	end
	Util.solid(folder, V3(A * 2, 1, s0 - z0), CFrame.new(X, y0 - 0.5, (z0 + s0) / 2), FLOOR, M.Granite)
	Util.solid(folder, V3(A * 2, 1, z1 - a1), CFrame.new(X, y0 - 0.5, (a1 + z1) / 2), FLOOR, M.Granite)
	local function glass(size, cf)
		local g = Util.solid(folder, size, cf, C(200, 220, 228), M.Glass)
		g.Transparency = 0.5
		return g
	end
	for _, side in ipairs({ -1, 1 }) do
		glass(V3(0.3, 4.4, a1 - s0), CFrame.new(X + side * (A + 0.15), y0 + 2.2, (s0 + a1) / 2))
		Util.deco(folder, V3(0.6, 0.3, a1 - s0), CFrame.new(X + side * (A + 0.15), y0 + 4.5, (s0 + a1) / 2), STEEL, M.Metal)
		-- North edge either side of the stair top.
		glass(V3(A - O, 4.4, 0.3), CFrame.new(X + side * (O + (A - O) / 2), y0 + 2.2, s0 - 0.15))
		-- Glass sides along the stairs.
		Kit.span(folder, V3(X + side * (O + 0.2), y0, s0), V3(X + side * (O + 0.2), geo.platformTop, s1), 0.3, 4, 2, C(200, 220, 228), M.Glass, true).Transparency = 0.5
	end
	glass(V3(A * 2 + 0.6, 4.4, 0.3), CFrame.new(X, y0 + 2.2, a1 + 0.15))
	Util.deco(folder, V3(A * 2 + 0.6, 0.3, 0.6), CFrame.new(X, y0 + 4.5, a1 + 0.15), STEEL, M.Metal)
	Util.deco(folder, V3(O * 2 - 0.5, 0.06, 1.8), CFrame.new(X, y0 + 0.03, s0 - 1.4), C(250, 200, 30), M.SmoothPlastic)
	Kit.stairs(folder, V3(X, y0, s0), V3(X, geo.platformTop, s1), O * 2 - 0.5)

	-- Walls (openings where passages arrive), ceiling, beams, columns.
	Kit.wall(folder, false, z0 - 1, z1 + 1, X - H - 0.5, y0, y1, geo.gapsWest, accent, geo.passageTop)
	Kit.wall(folder, false, z0 - 1, z1 + 1, X + H + 0.5, y0, y1, geo.gapsEast, accent, geo.passageTop)
	Kit.wall(folder, true, X - H - 1, X + H + 1, z0 - 0.5, y0, y1, geo.gapsNorth, accent, geo.passageTop)
	Kit.wall(folder, true, X - H - 1, X + H + 1, z1 + 0.5, y0, y1, {}, accent, nil)
	Kit.ceiling(folder, X - H, X + H, z0, z1, y1 - 0.5, { X - 22, X, X + 22 })
	for z = z0 + 18, z1 - 4, 18 do
		Util.deco(folder, V3(H * 2, 1.4, 1.6), CFrame.new(X, y1 - 1.2, z), C(196, 196, 192), M.Concrete)
	end
	for _, x in ipairs({ X - 20, X + 20 }) do
		for _, z in ipairs({ z0 + 18, z0 + 60, z0 + 80 }) do
			Util.solid(folder, V3(3.2, y1 - y0, 3.2), CFrame.new(x, (y0 + y1) / 2, z), STEEL, M.Metal)
			Util.solid(folder, V3(3.8, 1.4, 3.8), CFrame.new(x, y0 + 0.7, z), accent, M.CeramicTiles)
		end
	end
	-- Station name on the south wall, clock above, emergency point.
	Kit.nameSign(folder, face(V3(X, y0 + TILE_H + 3, z1 - 0.05), V3(0, 0, -1)), V3(32, 4, 0.1), station.name, accent, SIGN_BLACK)
	Kit.clock(folder, face(V3(X, y1 - 3.4, z1 - 0.05), V3(0, 0, -1)))
	Kit.emergency(folder, face(V3(X + H - 4, y0 + 5, z1 - 0.05), V3(0, 0, -1)))

	-- Fare line: three gates in, three out, a wide accessible gate in, glass
	-- barriers either side. Tap a Transit Card to go in; exits open as you walk up.
	local lanes = {}
	for i = 1, 6 do
		table.insert(lanes, { w = 4.6, entry = i <= 3 })
	end
	table.insert(lanes, { w = 6.5, entry = true })
	local gateStart = X - 18
	local gateEnd = Kit.fareGates(folder, gateStart, fz, y0, 1, station.name, lanes)
	for _, seg in ipairs({ { X - H, gateStart }, { gateEnd, X + H } }) do
		if seg[2] - seg[1] > 0.5 then
			local g = Util.solid(folder, V3(seg[2] - seg[1], 4.8, 0.3), CFrame.new((seg[1] + seg[2]) / 2, y0 + 2.4, fz), C(200, 220, 228), M.Glass)
			g.Transparency = 0.5
			Util.deco(folder, V3(seg[2] - seg[1], 0.3, 0.6), CFrame.new((seg[1] + seg[2]) / 2, y0 + 4.95, fz), STEEL, M.Metal)
		end
	end
	local signX = (gateStart + gateEnd) / 2
	Kit.hangingSign(folder, CFrame.new(signX, y1 - 4.4, fz - 4), 22, "TAP TO ENTER  ▼  TRAINS", y1 - 0.5)
	Kit.hangingSign(folder, CFrame.new(signX, y1 - 4.4, fz + 4), 22, "▲  EXIT · STREET", y1 - 0.5, C(120, 255, 140))

	-- Unpaid side: ticket machines and system maps on the north wall, info booth.
	for _, mx in ipairs({ X - 30.5, X - 26, X + 26, X + 30.5 }) do
		Kit.ticketMachine(folder, face(V3(mx, y0, z0 + 1.6), V3(0, 0, 1)))
	end
	for _, mx in ipairs({ X - 16.5, X + 16.5 }) do
		Kit.mapBoard(folder, face(V3(mx, y0 + TILE_H + 3, z0 + 0.1), V3(0, 0, 1)), 11, 5.6, "LINE 1 YONGE", geo.stations, station.name)
	end
	local boothX = X + 11
	local booth = Util.solid(folder, V3(10, 9, 8), CFrame.new(boothX, y0 + 4.5, fz - 15), C(190, 214, 224), M.Glass)
	booth.Transparency = 0.4
	Util.solid(folder, V3(10.4, 0.8, 8.4), CFrame.new(boothX, y0 + 9.4, fz - 15), Kit.DARK, M.Metal)
	Util.solid(folder, V3(10, 3.8, 1.2), CFrame.new(boothX, y0 + 1.9, fz - 19.5), C(56, 58, 64), M.Metal)
	local boothSign = Util.deco(folder, V3(9, 1.4, 0.2), CFrame.new(boothX, y0 + 10.6, fz - 19.6), C(30, 90, 170), M.SmoothPlastic)
	Util.sign(boothSign, Front, "i  INFORMATION", WHITE, Enum.Font.GothamBold).LightInfluence = 0
	Kit.bench(folder, face(V3(X - 26, y0, fz - 3.5), V3(0, 0, -1)))
	Kit.bin(folder, face(V3(X - 32, y0, fz - 2.5), V3(0, 0, -1)))

	-- Paid side: benches looking over the atrium, bins, sign over the stairs.
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ z0 + 56, z0 + 72 }) do
			Kit.bench(folder, face(V3(X + side * (A + 4), y0, z), V3(-side, 0, 0)))
		end
		Kit.bin(folder, face(V3(X + side * (A + 4), y0, z0 + 64), V3(-side, 0, 0)))
	end
	Kit.hangingSign(folder, CFrame.new(X, y1 - 4.4, s0 - 4), 26, "▼ PLATFORM  ·  FINCH ◀▶ PORTLANDS", y1 - 0.5)
	-- Hanging double-sided ad screens just past the gates.
	for _, sx in ipairs({ X - 24, X + 24 }) do
		local base = CFrame.new(sx, y1 - 5.2, fz + 9)
		Kit.adPanel(folder, base, 10, 5.4, rng)
		Kit.adPanel(folder, base * CFrame.Angles(0, math.pi, 0), 10, 5.4, rng)
		for _, rx in ipairs({ -3.5, 3.5 }) do
			local rod = base * CFrame.new(rx, 0, 0)
			Util.deco(folder, V3(0.15, 2.6, 0.15), CFrame.new(rod.X, y1 - 0.5 - 1.3, rod.Z), Kit.DARK, M.Metal)
		end
	end

	-- Shops along both side walls (clear of the openings and the fare line).
	for _, side in ipairs({ -1, 1 }) do
		local list = side < 0 and geo.gapsWest or geo.gapsEast
		for _, z in ipairs({ z0 + 11, z0 + 27, z0 + 47, z0 + 63, z0 + 79 }) do
			local ok = true
			for _, g in ipairs(list) do
				if z + 8 > g[1] and z - 8 < g[2] then
					ok = false
				end
			end
			if ok then
				local p = V3(X + side * (H - 0.05), y0, z)
				Kit.shop(folder, face(p, V3(-side, 0, 0)), 14, rng)
			end
		end
	end

	-- Ads high on the side walls (above the shops), cameras in the corners.
	local function clear(list, z)
		for _, g in ipairs(list) do
			if z + 6 > g[1] - 1 and z - 6 < g[2] + 1 then
				return false
			end
		end
		return true
	end
	for _, side in ipairs({ -1, 1 }) do
		local list = side < 0 and geo.gapsWest or geo.gapsEast
		for z = z0 + 9, z1 - 8, 16 do
			if math.abs(z - fz) > 8 and clear(list, z) then
				local p = V3(X + side * (H - 0.05), y0 + 12.6, z)
				Kit.adPanel(folder, face(p, V3(-side, 0, 0)), 10, 4.4, rng)
			end
		end
		Kit.camera(folder, face(V3(X + side * (H - 1.2), y1 - 0.5, z0 + 1.2), V3(-side, 0, 1)))
		Kit.camera(folder, face(V3(X + side * (H - 1.2), y1 - 0.5, z1 - 1.2), V3(-side, 0, -1)))
	end
	-- Exit signs over the openings.
	for _, info in ipairs({ { geo.gapsWest, -1 }, { geo.gapsEast, 1 } }) do
		for _, g in ipairs(info[1]) do
			local p = V3(X + info[2] * (H - 0.4), geo.passageTop - 1, (g[1] + g[2]) / 2)
			Kit.exitSign(folder, face(p, V3(-info[2], 0, 0)), "EXIT ▶ STREET")
		end
	end
	for _, g in ipairs(geo.gapsNorth) do
		Kit.exitSign(folder, face(V3((g[1] + g[2]) / 2, geo.passageTop - 1, z0 + 0.4), V3(0, 0, 1)), "EXIT ▲ STREET")
	end
end

return Kit
