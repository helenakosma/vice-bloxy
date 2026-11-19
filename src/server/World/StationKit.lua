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
local TILE_H = 4.5 -- height of the tiled band at the bottom of walls

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
			local panel = Util.deco(folder, V3(5, 0.15, 1.6), CFrame.new(x, y - 0.05, z), C(255, 250, 240), M.Neon)
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
-- Fittings. cf: on the floor, Front facing the way the object faces.
---------------------------------------------------------------------------
function Kit.bench(folder, cf)
	Util.solid(folder, V3(6, 0.4, 1.6), cf * CFrame.new(0, 1.6, 0), STEEL, M.Metal)
	Util.deco(folder, V3(6, 1.6, 0.25), cf * CFrame.new(0, 2.6, 0.75), STEEL, M.Metal)
	for _, x in ipairs({ -2.4, 2.4 }) do
		Util.solid(folder, V3(0.3, 1.4, 1.4), cf * CFrame.new(x, 0.7, 0), Kit.DARK, M.Metal)
	end
end

function Kit.bin(folder, cf)
	Util.solid(folder, V3(1.4, 2.8, 1.4), cf * CFrame.new(-0.8, 1.4, 0), C(60, 64, 70), M.Metal)
	Util.solid(folder, V3(1.4, 2.8, 1.4), cf * CFrame.new(0.8, 1.4, 0), C(30, 90, 170), M.Metal)
	Util.deco(folder, V3(3, 0.2, 1.5), cf * CFrame.new(0, 2.9, 0), C(30, 30, 32), M.Metal)
end

-- Ceiling camera: cf at the ceiling, Front facing where it looks.
function Kit.camera(folder, cf)
	Util.deco(folder, V3(0.3, 0.8, 0.3), cf * CFrame.new(0, -0.4, 0), Kit.DARK, M.Metal)
	Util.deco(folder, V3(0.6, 0.6, 1.4), cf * CFrame.new(0, -1, -0.4) * CFrame.Angles(math.rad(-20), 0, 0), C(230, 230, 230), M.SmoothPlastic)
	local led = Util.deco(folder, V3(0.15, 0.15, 0.1), cf * CFrame.new(0.2, -0.85, -1.1), C(255, 40, 40), M.Neon)
	led.CastShadow = false
end

-- Wall clock: cf at the wall face, Front facing the room.
function Kit.clock(folder, cf)
	local face = Instance.new("Part")
	face.Anchored = true
	face.CanCollide = false
	face.Shape = Enum.PartType.Cylinder
	face.Size = V3(0.4, 3, 3)
	face.CFrame = cf * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, math.rad(90), 0)
	face.Color = WHITE
	face.Material = M.SmoothPlastic
	face.Parent = folder
	Util.tick()
	Util.deco(folder, V3(0.18, 1.1, 0.05), cf * CFrame.new(0, 0.45, -0.45), Kit.DARK, M.SmoothPlastic)
	Util.deco(folder, V3(0.8, 0.18, 0.05), cf * CFrame.new(0.35, 0, -0.45), Kit.DARK, M.SmoothPlastic)
end

function Kit.ticketMachine(folder, cf)
	Util.solid(folder, V3(3, 6.4, 1.8), cf * CFrame.new(0, 3.2, 0), C(48, 50, 56), M.Metal)
	Util.deco(folder, V3(3.1, 0.8, 1.9), cf * CFrame.new(0, 6.1, 0), TTC_RED, M.SmoothPlastic)
	local screen = Util.deco(folder, V3(2.2, 1.6, 0.1), cf * CFrame.new(0, 4.2, -0.92), C(40, 120, 200), M.Neon)
	screen.CastShadow = false
	local gui = Util.sign(screen, Front, "TICKETS · TAP OR CARD", WHITE, Enum.Font.GothamBold)
	gui.LightInfluence = 0
	Util.deco(folder, V3(1.2, 0.5, 0.2), cf * CFrame.new(0, 2.8, -0.95), C(20, 20, 20), M.SmoothPlastic)
	Util.deco(folder, V3(0.7, 0.7, 0.1), cf * CFrame.new(0.8, 3.4, -0.95), C(60, 200, 120), M.Neon).CastShadow = false
end

-- Lit, framed advertising panel on a wall. Tagged "AdPanel" for rotation later.
function Kit.adPanel(folder, cf, w, h, rng)
	Util.deco(folder, V3(w + 0.6, h + 0.6, 0.3), cf * CFrame.new(0, 0, 0.15), C(50, 52, 56), M.Metal)
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
	local plate = Util.deco(folder, V3(w, 1.5, 0.3), cf, SIGN_BLACK, M.SmoothPlastic)
	plate.CastShadow = false
	for _, face in ipairs({ Front, Enum.NormalId.Back }) do
		Util.sign(plate, face, text, textColour or WHITE, Enum.Font.GothamBold).LightInfluence = 0
	end
	local top = cf.Position.Y + 0.75
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
	local plate = Util.deco(folder, V3(3.6, 0.9, 0.25), cf, C(20, 120, 60), M.SmoothPlastic)
	plate.CastShadow = false
	for _, face in ipairs({ Front, Enum.NormalId.Back }) do
		Util.sign(plate, face, text or "EXIT", WHITE, Enum.Font.GothamBold).LightInfluence = 0
	end
end

-- Red emergency point (alarm + intercom) on a wall.
function Kit.emergency(folder, cf)
	Util.deco(folder, V3(1.4, 2.2, 0.4), cf * CFrame.new(0, 0, -0.2), C(200, 30, 30), M.SmoothPlastic)
	local label = Util.deco(folder, V3(1.3, 0.5, 0.05), cf * CFrame.new(0, 0.7, -0.42), WHITE, M.SmoothPlastic)
	Util.sign(label, Front, "EMERGENCY", C(200, 30, 30), Enum.Font.GothamBold)
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
	local a = a0 + 12
	local k = 0
	while a < a1 - 12 do
		local side = (k % 2 == 0) and -1 or 1
		local list = side < 0 and gaps.minus or gaps.plus
		if not blocked(list, a, 4) then
			local p = pos(a, side * half, y0 + TILE_H + 2.6)
			local inward = alongX and V3(0, 0, -side) or V3(-side, 0, 0)
			Kit.adPanel(folder, CFrame.lookAt(p + inward * 0.1, p + inward * 2), 7, 4.2, rng)
			if len > 50 and k == 1 then
				local b = pos(a, side * (half - 1.4), y0)
				Kit.bench(folder, CFrame.lookAt(b, b + inward))
			end
		end
		a = a + 16
		k = k + 1
	end
end

---------------------------------------------------------------------------
-- Street entrance building.
-- e = { spot (Vector2), sz (+1: walk in from -z, stairs go down toward +z),
--       toward (+1/-1: the line is toward +x / -x), reach (distance from the spot
--       to the sidewalk), passZ }
-- In entrance coordinates, x runs across and dz along the way in:
--   dz -20..-16 canopy over the apron, -16..-10 landing, -10..15 stairs and
--   escalator going down, 15..31.5 the lobby at concourse level; the building
--   above ground covers dz -16..12.5. Across: stairs x -16.5..0.6, escalator 1..6,
--   divider 6..7, side walkway and elevator 7..16.5.
---------------------------------------------------------------------------
Kit.ENTRANCE = { HALF_W = 16.5, FRONT = -20, BACK = 31.5, LOBBY0 = 15, LOBBY1 = 31.5, HOUSE_BACK = 12.5 }

function Kit.entrance(folder, e, station, geo, rng)
	local spot, sz = e.spot, e.sz
	local kerb = Util.WALK_TOP
	local y0 = geo.floor -- underground floor level
	local accent = station.tile
	local function at(x, y, dz)
		return CFrame.new(spot.X + x, y, spot.Y + dz * sz)
	end
	local function p3(x, y, dz)
		return V3(spot.X + x, y, spot.Y + dz * sz)
	end
	local turn = sz > 0 and CFrame.identity or CFrame.Angles(0, math.pi, 0) -- Front faces the street
	local backTurn = turn * CFrame.Angles(0, math.pi, 0) -- Front faces into the station

	-- Street level: apron to the sidewalk, landing, side walkway.
	local apron = math.max(e.reach - 16, 1)
	Util.solid(folder, V3(34, 1, apron), at(0, kerb - 0.52, -(16 + apron / 2)), C(150, 146, 138), M.Concrete)
	Util.solid(folder, V3(33, 1, 6), at(0, kerb - 0.5, -13), C(176, 172, 164), M.Granite)
	Util.solid(folder, V3(9.5, 1, 22.5), at(11.75, kerb - 0.5, 1.25), C(176, 172, 164), M.Granite)

	-- Stairs (solid underneath) with three handrails.
	Kit.solidStairs(folder, p3(-7.95, kerb, -10), p3(-7.95, y0, 15), 17.1, y0 - 0.5)
	for _, x in ipairs({ -16, -8, 0.3 }) do
		Kit.span(folder, p3(x, kerb + 3, -10), p3(x, y0 + 3, 15), 0.25, 0.25, 0, Kit.DARK, M.Metal, false)
		Kit.span(folder, p3(x, kerb + 1.5, -10), p3(x, y0 + 1.5, 15), 0.12, 3, 0, STEEL, M.Metal, false)
	end

	-- Up escalator: a moving surface (anchored part with a velocity carries you up),
	-- steel balustrades with black handrails.
	local escTop, escBottom = p3(3.5, kerb, -10), p3(3.5, y0, 15)
	local belt = Kit.span(folder, escTop, escBottom, 5, 1, -0.5, C(70, 72, 76), M.DiamondPlate, true)
	if belt then
		belt.AssemblyLinearVelocity = (escTop - escBottom).Unit * 7
		belt.Name = "Escalator"
	end
	for _, x in ipairs({ 0.8 }) do
		Kit.span(folder, p3(x, kerb, -10), p3(x, y0, 15), 0.4, 3.4, 1.7, STEEL, M.Metal, true)
		Kit.span(folder, p3(x, kerb, -10), p3(x, y0, 15), 0.6, 0.3, 3.5, C(15, 15, 15), M.Rubber, false)
	end
	for _, info in ipairs({ { -11, kerb }, { 16, y0 } }) do
		Util.deco(folder, V3(5, 0.1, 2), at(3.5, info[2] + 0.05, info[1]), C(200, 200, 204), M.DiamondPlate)
	end
	local upSign = Util.deco(folder, V3(5, 1, 0.2), at(3.5, y0 + 9, 15.6) * turn, SIGN_BLACK, M.SmoothPlastic)
	Util.sign(upSign, Front, "▲ UP TO STREET", C(120, 255, 140), Enum.Font.GothamBold).LightInfluence = 0

	-- Divider between the escalator and the walkway/elevator: tile below, glass above.
	Util.solid(folder, V3(1, kerb - y0, 25), at(6.5, (kerb + y0) / 2, 2.5), accent, M.CeramicTiles)
	local guard = Util.solid(folder, V3(0.3, 3.6, 22.5), at(6.5, kerb + 1.8, 1.25), C(200, 220, 228), M.Glass)
	guard.Transparency = 0.5
	Util.deco(folder, V3(0.5, 0.25, 22.5), at(6.5, kerb + 3.7, 1.25), STEEL, M.Metal)
	-- Close the space under the walkway behind the lower elevator.
	Util.solid(folder, V3(9.5, kerb - 1 - y0, 1), at(11.75, (kerb - 1 + y0) / 2, 2.5), accent, M.CeramicTiles)

	-- Underground: side walls (opening on the line side), front and end walls,
	-- lobby floor, lower walkway floor, lobby ceiling.
	local L = Kit.ENTRANCE
	for _, side in ipairs({ -1, 1 }) do
		local gaps = {}
		if side == e.toward then
			local g0, g1 = spot.Y + (L.LOBBY0 + 0.25) * sz, spot.Y + (L.LOBBY1 - 0.25) * sz
			table.insert(gaps, { math.min(g0, g1), math.max(g0, g1) })
		end
		local w0, w1 = spot.Y - 16.5 * sz, spot.Y + 32 * sz
		Kit.wall(folder, false, math.min(w0, w1), math.max(w0, w1), spot.X + side * 17, y0, kerb, gaps, accent, geo.passageTop)
	end
	Util.solid(folder, V3(35, kerb - 1 - y0, 1), at(0, (kerb - 1 + y0) / 2, -16.5), accent, M.CeramicTiles)
	Kit.wall(folder, true, spot.X - 17.5, spot.X + 17.5, spot.Y + 32 * sz, y0, geo.ceilingTop, {}, accent, nil)
	Util.solid(folder, V3(33, 1, 18.5), at(0, y0 - 0.5, 22.25), FLOOR, M.Granite) -- from the foot of the stairs
	Util.solid(folder, V3(9.5, 1, 12.5), at(11.75, y0 - 0.5, 8.75), FLOOR, M.Granite)
	local cz0, cz1 = spot.Y + 12.5 * sz, spot.Y + 31.5 * sz
	Kit.ceiling(folder, spot.X - 16.5, spot.X + 16.5, math.min(cz0, cz1), math.max(cz0, cz1), geo.passageTop + 0.25, { spot.X - 8, spot.X + 8 })
	Kit.hangingSign(folder, at(0, geo.passageTop - 1.4, 30.8) * turn, 14, "◀ ▶  TRAINS · LINE 1", geo.passageTop + 0.25)
	Kit.exitSign(folder, at(-8, y0 + 9.5, 15.3) * turn, "EXIT ▲ STREET")
	Kit.bin(folder, at(-13, y0, 30.5) * turn)
	Kit.camera(folder, at(14, geo.passageTop + 0.25, 30) * turn)

	-- Above ground: steel-and-glass building over the stairs, canopy, signs.
	for _, side in ipairs({ -1, 1 }) do
		local glass = Util.solid(folder, V3(0.4, 11, 28.5), at(side * 16.5, kerb + 5.5, -1.75), C(190, 214, 224), M.Glass)
		glass.Transparency = 0.45
		for dz = -16, 12.5, 7.125 do
			Util.solid(folder, V3(0.7, 11, 0.7), at(side * 16.5, kerb + 5.5, dz), Kit.DARK, M.Metal)
		end
		Util.solid(folder, V3(0.8, 11, 0.8), at(side * 16.5, kerb + 5.5, -19.5), Kit.DARK, M.Metal)
	end
	Util.solid(folder, V3(33, kerb + 1.75, 0.8), at(0, (kerb - 1.75) / 2, 12.9), Kit.CONCRETE, M.Concrete)
	local back = Util.solid(folder, V3(33, 11, 0.4), at(0, kerb + 5.5, 12.5), C(190, 214, 224), M.Glass)
	back.Transparency = 0.45
	Util.solid(folder, V3(35, 1, 33), at(0, kerb + 11.5, -3.75), Kit.DARK, M.Metal)
	Util.deco(folder, V3(35.4, 0.4, 33.4), at(0, kerb + 12.1, -3.75), C(120, 122, 126), M.Metal)
	for _, dz in ipairs({ -14, 0 }) do
		local strip = Util.deco(folder, V3(20, 0.15, 1.2), at(0, kerb + 10.95, dz), C(255, 248, 236), M.Neon)
		strip.CastShadow = false
		Kit.light(strip, Enum.NormalId.Bottom, 18, 1.3, C(255, 244, 226))
	end
	-- Fascia sign over the way in: TTC SUBWAY, the station name under it.
	local board = Util.deco(folder, V3(26, 2.6, 0.6), at(0, kerb + 9.7, -19.8) * turn, WHITE, M.SmoothPlastic)
	board.CastShadow = false
	for _, face in ipairs({ Front, Enum.NormalId.Back }) do
		Util.sign(board, face, "TTC   SUBWAY", TTC_RED, Enum.Font.GothamBlack).LightInfluence = 0
	end
	Kit.marker(board, "🚇 " .. station.name, TTC_RED)
	local band = Util.deco(folder, V3(26, 1.4, 0.5), at(0, kerb + 7.75, -19.8) * turn, SIGN_BLACK, M.SmoothPlastic)
	band.CastShadow = false
	for _, face in ipairs({ Front, Enum.NormalId.Back }) do
		Util.sign(band, face, station.name .. " STATION", WHITE, Enum.Font.GothamBold).LightInfluence = 0
	end
	-- Red TTC pylon at the corner of the apron.
	local pylon = Util.solid(folder, V3(1.2, 16, 3), at(-15.5, kerb + 8, -22), TTC_RED, M.SmoothPlastic)
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right, Front, Enum.NormalId.Back }) do
		Util.sign(pylon, face, "TTC", WHITE, Enum.Font.GothamBlack).LightInfluence = 0
	end
	local cap = Util.deco(folder, V3(1.6, 1, 3.4), at(-15.5, kerb + 16.5, -22), C(255, 70, 70), M.Neon)
	cap.CastShadow = false
	-- Information panel on the landing.
	local info = Util.solid(folder, V3(4, 6, 0.5), at(-14, kerb + 3, -12) * turn, SIGN_BLACK, M.Metal)
	Util.sign(info, Front, "LINE 1 YONGE\n◀ STAIRS   ESCALATOR ▲\nELEVATOR ▶", WHITE, Enum.Font.GothamBold).LightInfluence = 0

	-- Elevator: a cab at street level on the walkway and one below; the call
	-- button takes you to the other one.
	local cabs = {}
	for i, info2 in ipairs({ { kerb, 3 }, { y0, 10 } }) do
		local y, doorDz = info2[1], info2[2]
		local backDz = doorDz == 3 and 10 or 3
		for _, x in ipairs({ 8, 15 }) do
			local wall = Util.solid(folder, V3(0.4, 9, 7), at(x, y + 4.5, 6.5), C(190, 214, 224), M.Glass)
			wall.Transparency = 0.35
		end
		Util.solid(folder, V3(7.4, 9, 0.4), at(11.5, y + 4.5, backDz), C(120, 124, 130), M.Metal)
		for _, x in ipairs({ 8.3, 14.7 }) do
			Util.solid(folder, V3(1.4, 9, 0.5), at(x, y + 4.5, doorDz), C(150, 152, 156), M.Metal)
		end
		Util.solid(folder, V3(7.4, 1.2, 0.5), at(11.5, y + 8.4, doorDz), C(150, 152, 156), M.Metal)
		local top = Util.solid(folder, V3(7.4, 0.5, 7.4), at(11.5, y + 9.25, 6.5), C(120, 124, 130), M.Metal)
		Kit.light(top, Enum.NormalId.Bottom, 10, 1)
		local signTurn = doorDz == 3 and turn or backTurn
		local label = Util.deco(folder, V3(5, 0.8, 0.2), at(11.5, y + 8.4, doorDz) * signTurn * CFrame.new(0, 0, -0.3), SIGN_BLACK, M.SmoothPlastic)
		Util.sign(label, Front, i == 1 and "ELEVATOR ▼ TRAINS" or "ELEVATOR ▲ STREET", WHITE, Enum.Font.GothamBold).LightInfluence = 0
		local panel = Util.solid(folder, V3(0.3, 1.6, 0.8), at(14.7, y + 4, 6.5), C(40, 40, 44), M.Metal)
		cabs[i] = { panel = panel, centre = at(11.5, y + 3, 6.5) }
	end
	for i, cab in ipairs(cabs) do
		local other = cabs[3 - i]
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = i == 1 and "Go down to the trains" or "Go up to the street"
		prompt.ObjectText = "Elevator"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = cab.panel
		prompt.Triggered:Connect(function(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - cab.centre.Position).Magnitude < 12 then
				local offset = cab.centre:ToObjectSpace(root.CFrame)
				character:PivotTo(other.centre * offset)
			end
		end)
	end
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
	local accent = station.tile
	local function face(p, dir)
		return CFrame.lookAt(p, p + dir)
	end

	-- Floor with the opening over the platform stairs.
	for _, side in ipairs({ -1, 1 }) do
		Util.solid(folder, V3(H - 4.5, 1, z1 - z0), CFrame.new(X + side * (4.5 + (H - 4.5) / 2), y0 - 0.5, (z0 + z1) / 2), FLOOR, M.Granite)
	end
	Util.solid(folder, V3(9, 1, s0 - z0), CFrame.new(X, y0 - 0.5, (z0 + s0) / 2), FLOOR, M.Granite)
	Util.solid(folder, V3(9, 1, z1 - s1), CFrame.new(X, y0 - 0.5, (s1 + z1) / 2), FLOOR, M.Granite)
	-- Glass balustrade round the opening, tactile strip at the top step.
	for _, side in ipairs({ -1, 1 }) do
		local g = Util.solid(folder, V3(0.3, 3.6, s1 - s0), CFrame.new(X + side * 4.75, y0 + 1.8, (s0 + s1) / 2), C(200, 220, 228), M.Glass)
		g.Transparency = 0.5
		Util.deco(folder, V3(0.5, 0.25, s1 - s0), CFrame.new(X + side * 4.75, y0 + 3.7, (s0 + s1) / 2), STEEL, M.Metal)
	end
	local endGlass = Util.solid(folder, V3(9.8, 3.6, 0.3), CFrame.new(X, y0 + 1.8, s1 + 0.15), C(200, 220, 228), M.Glass)
	endGlass.Transparency = 0.5
	Util.deco(folder, V3(8.5, 0.06, 1.4), CFrame.new(X, y0 + 0.03, s0 - 1.2), C(250, 200, 30), M.SmoothPlastic)
	Kit.stairs(folder, V3(X, y0, s0), V3(X, geo.platformTop, s1), 8.5)

	-- Walls (openings where passages arrive), ceiling, beams, columns.
	Kit.wall(folder, false, z0 - 1, z1 + 1, X - H - 0.5, y0, y1, geo.gapsWest, accent, geo.passageTop)
	Kit.wall(folder, false, z0 - 1, z1 + 1, X + H + 0.5, y0, y1, geo.gapsEast, accent, geo.passageTop)
	Kit.wall(folder, true, X - H - 1, X + H + 1, z0 - 0.5, y0, y1, geo.gapsNorth, accent, geo.passageTop)
	Kit.wall(folder, true, X - H - 1, X + H + 1, z1 + 0.5, y0, y1, {}, accent, nil)
	Kit.ceiling(folder, X - H, X + H, z0, z1, y1 - 0.5, { X - 18, X, X + 18 })
	for z = z0 + 14, z1 - 4, 14 do
		Util.deco(folder, V3(H * 2, 1, 1.2), CFrame.new(X, y1 - 1, z), C(196, 196, 192), M.Concrete)
	end
	for _, x in ipairs({ X - 15, X + 15 }) do
		for _, z in ipairs({ z0 + 14, z0 + 48, z0 + 62 }) do
			Util.solid(folder, V3(2.4, y1 - y0, 2.4), CFrame.new(x, (y0 + y1) / 2, z), STEEL, M.Metal)
			Util.solid(folder, V3(2.8, 1, 2.8), CFrame.new(x, y0 + 0.5, z), accent, M.CeramicTiles)
		end
	end
	-- Station name panels on the south wall and clock above.
	Kit.nameSign(folder, face(V3(X, y0 + TILE_H + 2.2, z1 - 0.05), V3(0, 0, -1)), V3(24, 3, 0.1), station.name, accent, SIGN_BLACK)
	Kit.clock(folder, face(V3(X, y1 - 2.6, z1 - 0.05), V3(0, 0, -1)))
	Kit.emergency(folder, face(V3(X + H - 3, y0 + 4, z1 - 0.05), V3(0, 0, -1)))

	-- Fare line: six gates (three in, three out), a wide accessible gate, glass
	-- barriers either side. The flaps are decoration for now (no fares yet).
	local laneW, cabW = 3.4, 0.8
	local x = X - 13
	for i = 0, 7 do
		Util.solid(folder, V3(cabW, 3.4, 4), CFrame.new(x + cabW / 2, y0 + 1.7, fz), C(56, 58, 64), M.Metal)
		Util.deco(folder, V3(cabW, 0.12, 4), CFrame.new(x + cabW / 2, y0 + 3.46, fz), C(200, 210, 216), M.Glass)
		if i < 7 then
			local width = (i == 6) and 5 or laneW
			local lx = x + cabW + width / 2
			local entry = i < 3 or i == 6
			local reader = Util.deco(folder, V3(0.6, 0.1, 0.6), CFrame.new(x + cabW / 2, y0 + 3.55, fz + (entry and -1.4 or 1.4)), entry and C(60, 220, 110) or C(220, 70, 60), M.Neon)
			reader.CastShadow = false
			for _, s in ipairs({ -1, 1 }) do
				local flap = Util.deco(folder, V3(width / 2 - 0.2, 2, 0.15), CFrame.new(lx + s * (width / 4), y0 + 2, fz), C(200, 220, 228), M.Glass)
				flap.Transparency = 0.4
			end
			local arrow = Util.deco(folder, V3(width - 0.4, 0.05, 1.6), CFrame.new(lx, y0 + 0.03, fz + (entry and -3.2 or 3.2)), entry and C(60, 200, 110) or C(210, 70, 60), M.SmoothPlastic)
			arrow.CastShadow = false
			x = x + cabW + width
		else
			x = x + cabW
		end
	end
	local gateEnd = x
	for _, seg in ipairs({ { X - H, X - 13 }, { gateEnd, X + H } }) do
		if seg[2] - seg[1] > 0.5 then
			local g = Util.solid(folder, V3(seg[2] - seg[1], 3.8, 0.3), CFrame.new((seg[1] + seg[2]) / 2, y0 + 1.9, fz), C(200, 220, 228), M.Glass)
			g.Transparency = 0.5
			Util.deco(folder, V3(seg[2] - seg[1], 0.25, 0.5), CFrame.new((seg[1] + seg[2]) / 2, y0 + 3.9, fz), STEEL, M.Metal)
		end
	end
	Kit.hangingSign(folder, CFrame.new(X - 4, y1 - 3.2, fz - 3), 16, "TAP TO ENTER  ▼  TRAINS", y1 - 0.5)
	Kit.hangingSign(folder, CFrame.new(X - 4, y1 - 3.2, fz + 3), 16, "▲  EXIT · STREET", y1 - 0.5, C(120, 255, 140))

	-- Unpaid side: ticket machines and system maps on the north wall, info booth.
	for _, mx in ipairs({ X - 22.5, X - 19, X + 19, X + 22.5 }) do
		Kit.ticketMachine(folder, face(V3(mx, y0, z0 + 1.2), V3(0, 0, 1)))
	end
	for _, mx in ipairs({ X - 11, X + 11 }) do
		Kit.mapBoard(folder, face(V3(mx, y0 + TILE_H + 2.4, z0 + 0.1), V3(0, 0, 1)), 9, 4.5, "LINE 1 YONGE", geo.stations, station.name)
	end
	local boothX = X + 8
	local booth = Util.solid(folder, V3(8, 7, 6), CFrame.new(boothX, y0 + 3.5, fz - 11), C(190, 214, 224), M.Glass)
	booth.Transparency = 0.4
	Util.solid(folder, V3(8.4, 0.6, 6.4), CFrame.new(boothX, y0 + 7.3, fz - 11), Kit.DARK, M.Metal)
	Util.solid(folder, V3(8, 3, 1), CFrame.new(boothX, y0 + 1.5, fz - 14.5), C(56, 58, 64), M.Metal)
	local boothSign = Util.deco(folder, V3(7, 1, 0.2), CFrame.new(boothX, y0 + 8.2, fz - 14.6), C(30, 90, 170), M.SmoothPlastic)
	Util.sign(boothSign, Front, "i  INFORMATION", WHITE, Enum.Font.GothamBold).LightInfluence = 0
	Kit.bench(folder, face(V3(X - 20, y0, fz - 2.5), V3(0, 0, -1)))
	Kit.bin(folder, face(V3(X - 25, y0, fz - 2), V3(0, 0, -1)))

	-- Paid side: benches and bins along the walls, sign over the stairs.
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ s0 + 2, s1 - 2 }) do
			Kit.bench(folder, face(V3(X + side * (H - 1.6), y0, z), V3(-side, 0, 0)))
		end
		Kit.bin(folder, face(V3(X + side * (H - 1.4), y0, (s0 + s1) / 2), V3(-side, 0, 0)))
	end
	Kit.hangingSign(folder, CFrame.new(X, y1 - 3.2, s0 - 3), 18, "▼ PLATFORM  ·  FINCH ◀▶ PORTLANDS", y1 - 0.5)

	-- Ads on the side walls (clear of the openings), cameras in the corners.
	local function clear(list, z)
		for _, g in ipairs(list) do
			if z + 5 > g[1] - 1 and z - 5 < g[2] + 1 then
				return false
			end
		end
		return true
	end
	for _, side in ipairs({ -1, 1 }) do
		local list = side < 0 and geo.gapsWest or geo.gapsEast
		for z = z0 + 7, z1 - 6, 13 do
			if math.abs(z - fz) > 6 and clear(list, z) then
				local p = V3(X + side * (H - 0.05), y0 + TILE_H + 2.8, z)
				Kit.adPanel(folder, face(p, V3(-side, 0, 0)), 8, 4.6, rng)
			end
		end
		Kit.camera(folder, face(V3(X + side * (H - 1), y1 - 0.5, z0 + 1), V3(-side, 0, 1)))
		Kit.camera(folder, face(V3(X + side * (H - 1), y1 - 0.5, z1 - 1), V3(-side, 0, -1)))
	end
	-- Exit signs over the openings.
	for _, info in ipairs({ { geo.gapsWest, -1 }, { geo.gapsEast, 1 } }) do
		for _, g in ipairs(info[1]) do
			local p = V3(X + info[2] * (H - 0.4), geo.passageTop - 0.8, (g[1] + g[2]) / 2)
			Kit.exitSign(folder, face(p, V3(-info[2], 0, 0)), "EXIT ▶ STREET")
		end
	end
	for _, g in ipairs(geo.gapsNorth) do
		Kit.exitSign(folder, face(V3((g[1] + g[2]) / 2, geo.passageTop - 0.8, z0 + 0.4), V3(0, 0, 1)), "EXIT ▲ STREET")
	end
end

return Kit
