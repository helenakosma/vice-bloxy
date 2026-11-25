-- The Eaton Centre's Yonge & Dundas corner. The building's outline on every
-- level is the leasing plan's own (walls, floors and openings stay exactly as
-- drawn); this module dresses that outline as the corner looks from the street
-- and adds the subway entrance inside the atrium. Store names are made up.
--
-- From the 2023 leasing plans:
--   * Level 1: the corner is the public entrance, a diagonal glass front with six
--     doors marked "Public Transit Entry" (u ~1381-1404, v 0-61). Behind it is
--     the atrium, with kiosks and the escalator up. A small door vestibule opens
--     from Yonge at u 1304-1314, and shops line Yonge between the two.
--   * Level 2 projects over the Level 1 entrance (to u ~1415): the fashion
--     anchor's block, which Street View shows panelled, with big screens and a
--     rounded corner carrying the store's logo.
--   * Level 3 curves out over Yonge at u 1278-1338: the "Toronto Eaton Centre"
--     drum (Street View: two glazed storeys over the entrance canopy, a dark name
--     band, a billboard on a steel frame above).
-- TTC: TMU station's Eaton Centre entrance is inside the atrium at the SW corner
-- of Yonge and Dundas (escalator, stairs and lift down). Here it is a well in
-- the atrium floor down to the passage that runs north to the station.
local Util = require(script.Parent.Parent.Util)
local Billboards = require(script.Parent.Parent.Billboards)
local TorontoLayout = require(script.Parent.Parent.TorontoLayout)

local Exterior = {}

local V3 = Vector3.new
local M = Enum.Material
local C = Color3.fromRGB

local NAVY = C(36, 40, 56)
local WHITE = C(238, 238, 234)
local STONE = C(222, 210, 186)
local PANEL = C(226, 230, 232)
local JOINT = C(196, 202, 208)
local FRAME = C(34, 36, 40)
local STEEL = C(120, 124, 130)
local LOGO_RED = C(214, 20, 30)
local GLASS = C(176, 200, 214)

-- The drum: an arc over Yonge between its ends on v = -1, bulging 4 ft out.
local DRUM_U0, DRUM_U1, DRUM_V, DRUM_OUT = 1278, 1338, -1, -5
local DCU = (DRUM_U0 + DRUM_U1) / 2
local DHALF = (DRUM_U1 - DRUM_U0) / 2
local DSAG = DRUM_V - DRUM_OUT
local DR = (DHALF * DHALF + DSAG * DSAG) / (2 * DSAG)
local DCV = DRUM_OUT + DR
local DTH = math.asin((DCV - DRUM_V) / DR) -- north end; the south end is pi - DTH
local function drumPoint(t)
	return DCU + DR * math.cos(t), DCV - DR * math.sin(t)
end

-- The anchor's block, over Level 1 (plan feet). Yonge face at v = -7.5 (the
-- plan's Level 2 bays), rounded corner, short Dundas face at u = 1414.5 (the
-- Level 2 projection), then back to the Dundas wall line for its long face.
local BOX_U0 = DRUM_U1 -- Yonge face runs north from the drum
local BOX_YV = -7.5
local KCU, KCV, KR = 1388, 19, 26.5 -- rounded corner centre and radius
local BOX_DU = KCU + KR -- 1414.5
local BOX_STEP_V = 55 -- where the projection steps back to the Dundas wall
local DUNDAS_FACE = 1393.5
local DUNDAS_V1 = 200

-- The TMU well in the atrium floor: escalators and stairs down to the passage.
local link = TorontoLayout.EATON_LINK
local WELL = link and link.well
Exterior.WELL = WELL

-- Openings through the plan's Level 1 walls (none: see the step 1 notes).
Exterior.DOORS = {}

-- How the builder treats a plan wall a->b of this kind on this level:
--   nil (as drawn), "skip" (a facade built here replaces it), "rail" (a glass
--   balustrade instead: the drum's void), "door" (glass doors), "window" (a
--   shop window to the street), "glass" (a full-height glass wall), "closed"
--   (entrance doors that don't open yet).
function Exterior.wallMode(kind, a, b, level)
	if kind ~= 3 and kind ~= 4 then
		return nil
	end
	local u, v = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
	local umin, vmin = math.min(a[1], b[1]), math.min(a[2], b[2])
	if level <= 2 then
		-- Below the street: transit links. The TMU doors at Level 2's corner open
		-- on to the passage to the station; the rest wait for their tunnels.
		if kind == 4 then
			if level == 2 and link and math.abs(u - link.u) < 0.5 and math.abs(v - link.v) < 5 then
				return "door"
			end
			return "closed"
		end
		return nil
	elseif level == 3 then
		if umin > DRUM_U0 - 2 and vmin < 62 then
			return "skip" -- the drum and the anchor's block make the street face
		end
		if u > 1230 and u <= DRUM_U0 and v < 22 then
			return "skip" -- the white block's recess
		end
	elseif level == 4 then
		if u > 1270 and v < 62 and kind == 3 then
			return "glass" -- the corner atrium's upper wall, over the drum and block
		end
	end
	return nil
end

-- Floor rectangles {u0, v0, u1, v1}: the well is cut out of Level 1.
function Exterior.clipSlab(r, level)
	if level ~= 1 or not WELL then
		return { r }
	end
	local h = { WELL.u0, WELL.v0, WELL.u1, WELL.v1 }
	if r[3] <= h[1] or r[1] >= h[3] or r[4] <= h[2] or r[2] >= h[4] then
		return { r }
	end
	local out = {}
	if r[1] < h[1] then
		table.insert(out, { r[1], r[2], h[1], r[4] })
	end
	if r[3] > h[3] then
		table.insert(out, { h[3], r[2], r[3], r[4] })
	end
	local a, b = math.max(r[1], h[1]), math.min(r[3], h[3])
	if r[2] < h[2] then
		table.insert(out, { a, r[2], b, h[2] })
	end
	if r[4] > h[4] then
		table.insert(out, { a, h[4], b, r[4] })
	end
	return out
end

-- Join each bay of the street-level drum to the nearest traced floor edge.
function Exterior.fill(level, slabs)
	local out = {}
	if level ~= 3 then
		return out
	end
	for u = DRUM_U0, DRUM_U1 - 2, 2 do
		local d = math.max(math.abs(u - DCU), math.abs(u + 2 - DCU))
		local vmin = DCV - math.sqrt(math.max(0, DR * DR - d * d))
		local edge = math.huge
		for _, r in ipairs(slabs) do
			if r[1] <= u and r[3] >= u + 2 then
				edge = math.min(edge, r[2])
			end
		end
		if edge < math.huge and edge > vmin then
			table.insert(out, { u, vmin, u + 2, edge })
		end
	end
	return out
end

-- Kept for the builder's loops: nothing of the plan lies outside the corner.
function Exterior.outside()
	return false
end

-- Escalators down the TMU well (from the concourse/passage level, 0, to Level 1).
function Exterior.escalators()
	if not WELL then
		return {}
	end
	local v = (WELL.v0 + WELL.v1) / 2 - 3.5
	return { { from = 0, to = 1, top = { WELL.u0, v }, bottom = { WELL.u0 + 31, v } } }
end

-- The TMU lift: Level 1 atrium to the passage.
function Exterior.lift()
	if not WELL then
		return nil
	end
	return { u = WELL.u0 - 4, v = WELL.v1 - 3.5, w = 6, d = 6, stops = { [0] = true, [1] = true }, labels = { [0] = "TMU station", [1] = "Level 1" } }
end

function Exterior.build(folder, P, S, base, levelY, rng, names)
	names = names or {}
	local roofY = levelY(5) + 20 -- the drum and the white block's lower roof line
	local f = Instance.new("Folder")
	f.Name = "YongeDundasCorner"
	f.Parent = folder

	local function panelAt(a, b, y, h, thick, colour, material, collide)
		local pa, pb = P(a[1], a[2], 0), P(b[1], b[2], 0)
		local len = (pb - pa).Magnitude
		if len < 0.05 then
			return nil
		end
		local mid = (pa + pb) / 2 + V3(0, y + h / 2, 0)
		local cf = CFrame.lookAt(mid, mid + (pb - pa))
		local size = V3(thick, h, len + 0.05)
		if collide == false then
			return Util.deco(f, size, cf, colour, material), cf
		end
		return Util.solid(f, size, cf, colour, material), cf
	end
	local function glass(a, b, y, h, colour, transparency, collide)
		local g = panelAt(a, b, y, h, 0.3, colour or GLASS, M.Glass, collide)
		g.Transparency = transparency or 0.5
		g.CastShadow = false
		return g
	end
	local function facing(u, v, y, w, h, out, colour)
		local p = P(u, v, y) + out * 0.9
		return Util.deco(f, V3(w, h, 0.3), CFrame.lookAt(p, p + out), colour or C(10, 10, 12), M.SmoothPlastic)
	end
	local function logo(part, text)
		part.Transparency = 1
		Util.sign(part, Enum.NormalId.Front, text, LOGO_RED, Enum.Font.GothamBlack).LightInfluence = 0
	end
	local function screen(part)
		part.CastShadow = false
		Billboards.face(part, Enum.NormalId.Front, Billboards.pick(rng), true)
		return part
	end
	local EAST, NORTH = V3(1, 0, 0), V3(0, 0, -1)
	local l2 = levelY(4) -- the first floor above the street
	local skinY = l2 - 2 -- facades above the Level 1 canopy line
	local top = roofY + 1

	-----------------------------------------------------------------------
	-- The drum, over Levels 2-3.
	-----------------------------------------------------------------------
	do
		local N = 22
		local LETTERS = "Toronto Eaton Centre"
		local function outward(t)
			local u, v = drumPoint(t)
			return (P(u, v, 0) - P(DCU, DCV, 0)).Unit
		end
		for k = 0, N - 1 do
			local t0 = DTH + k / N * (math.pi - 2 * DTH)
			local t1 = DTH + (k + 1) / N * (math.pi - 2 * DTH)
			local a, b = { drumPoint(t0) }, { drumPoint(t1) }
			local o = outward((t0 + t1) / 2)
			-- Canopy over the street-level doors, the glazed storeys, the band.
			local pa, pb = P(a[1], a[2], 0), P(b[1], b[2], 0)
			if k >= 6 and k <= 15 then
				local leaf = glass(a, b, base, 12, C(200, 220, 230), 0.7, false)
				leaf.Name = "Door"
				-- Keep a clear swinging-door lane beside each revolving bay.
				if k == 8 or k == 13 then
					local mid = (pa + pb) / 2 - o * 3 + V3(0, base + 4.25, 0)
					local revolving = Util.cylinder(f, 8.5, 5.5, CFrame.new(mid), C(200, 220, 230), M.Glass, false)
					revolving.Transparency = 0.65
				end
			else
				glass(a, b, base, 12, C(176, 200, 214), 0.4).Name = "ShopWindow"
			end
			panelAt(a, b, base + 12, skinY - (base + 12), 0.8, FRAME, M.Metal)
			if k < 6 or k > 15 or k % 2 == 0 then
				Util.deco(f, V3(0.5, 12, 0.5), CFrame.new(pa + V3(0, base + 6, 0)), FRAME, M.Metal)
			end
			local cm = (pa + pb) / 2 + o * 3 + V3(0, skinY - 0.4, 0)
			Util.deco(f, V3((pb - pa).Magnitude + 0.5, 0.8, 7), CFrame.lookAt(cm, cm + o), WHITE, M.SmoothPlastic)
			glass(a, b, skinY, l2 + 12 - skinY, C(150, 180, 205), 0.35).Reflectance = 0.25
			panelAt(a, b, l2 + 12, 1.6, 0.9, STONE, M.SmoothPlastic)
			glass(a, b, l2 + 13.6, roofY - 9 - (l2 + 13.6), C(150, 180, 205), 0.35).Reflectance = 0.25
			local pv = P(a[1], a[2], 0)
			Util.deco(f, V3(0.4, roofY - 9 - skinY, 0.4), CFrame.new(pv + V3(0, (skinY + roofY - 9) / 2, 0)), WHITE, M.SmoothPlastic)
			local band, bandCF = panelAt(a, b, roofY - 9, 7, 1, NAVY, M.SmoothPlastic)
			if k >= 1 and k <= 20 then
				local ch = string.sub(LETTERS, 21 - k, 21 - k)
				if ch ~= " " then
					local face = bandCF.RightVector:Dot(o) > 0 and Enum.NormalId.Right or Enum.NormalId.Left
					Util.sign(band, face, ch, C(244, 244, 248), Enum.Font.GothamMedium).LightInfluence = 0
				end
			end
			panelAt(a, b, roofY - 2, top + 1 - (roofY - 2), 1.2, WHITE, M.SmoothPlastic)
			local rc = (pa + pb) / 2 + o * 1.8 + V3(0, top + 0.6, 0)
			Util.deco(f, V3((pb - pa).Magnitude + 0.6, 1.2, 4.2), CFrame.lookAt(rc, rc + o), WHITE, M.SmoothPlastic)
		end
		-- Roof over the drum and the void behind it (Level 3 is set back there).
		local a, b = P(DRUM_U0, DRUM_OUT, 0), P(DRUM_U1, 22, 0)
		Util.solid(f, V3(math.abs(b.X - a.X), 1, math.abs(b.Z - a.Z)), CFrame.new((a + b) / 2 + V3(0, top + 0.5, 0)), C(80, 84, 90), M.Concrete)
	end

	-----------------------------------------------------------------------
	-- The billboard over the drum, on its steel frame, facing the intersection.
	-----------------------------------------------------------------------
	do
		local o = (P(math.sin(math.rad(30)), -math.cos(math.rad(30)), 0) - P(0, 0, 0)).Unit
		local c = P(DCU + 2, 10, 0)
		local w, h, lift = 44, 30, 18
		local y0 = top + 1
		local face = CFrame.lookAt(c + V3(0, y0 + lift + h / 2, 0), c + V3(0, y0 + lift + h / 2, 0) + o)
		Util.solid(f, V3(w + 1, h + 1, 1.5), face * CFrame.new(0, 0, 1), C(28, 28, 32), M.Metal)
		screen(Util.deco(f, V3(w, h, 0.4), face * CFrame.new(0, 0, -0.1), C(10, 10, 12), M.SmoothPlastic))
		local base0 = CFrame.lookAt(c + V3(0, y0, 0), c + V3(0, y0, 0) + o)
		local function at(lx, lz, yy)
			return (base0 * CFrame.new(lx, yy, lz)).Position
		end
		local L, Rr = -w / 2 + 1, w / 2 - 1
		for _, lx in ipairs({ L, 0, Rr }) do
			for _, lz in ipairs({ 1.5, 8 }) do
				Util.beam(f, at(lx, lz, 0), at(lx, lz, lift + h), 0.8, STEEL, M.Metal)
			end
		end
		local step = 6
		for y = 0, lift + h - step, step do
			local flip = math.floor(y / step + 0.5) % 2 == 0
			local ya, yb = flip and y or y + step, flip and y + step or y
			for _, lx in ipairs({ L, Rr }) do
				Util.beam(f, at(lx, 1.5, ya), at(lx, 8, yb), 0.35, STEEL, M.Metal)
			end
			Util.beam(f, at(L, 8, ya), at(0, 8, yb), 0.35, STEEL, M.Metal)
			Util.beam(f, at(0, 8, yb), at(Rr, 8, ya), 0.35, STEEL, M.Metal)
			if y < lift then
				Util.beam(f, at(L, 1.5, yb), at(0, 1.5, ya), 0.35, STEEL, M.Metal)
				Util.beam(f, at(0, 1.5, ya), at(Rr, 1.5, yb), 0.35, STEEL, M.Metal)
			end
		end
		Util.deco(f, V3(w + 2, 0.4, 4), face * CFrame.new(0, -h / 2 - 0.8, -1.5), STEEL, M.DiamondPlate)
	end

	-----------------------------------------------------------------------
	-- The anchor's block over the corner entrance (Levels 2-3).
	-----------------------------------------------------------------------
	local boxTop = levelY(5) + 4 -- the anchor's block, lower than the drum
	local hPanel = boxTop - skinY
	local function cladding(a, b)
		panelAt(a, b, skinY, hPanel, 1.2, PANEL, M.SmoothPlastic)
	end
	-- Street level of the block, flush with the panels above: shop windows with
	-- light frames and a panel band up to the cladding, or the store's doors.
	local SILVER = C(200, 202, 206)
	local function groundFace(a, b, doors)
		local pa = P(a[1], a[2], 0)
		if doors then
			local leaf = glass(a, b, base, 12, C(200, 220, 230), 0.7, false)
			leaf.Name = "Door"
			panelAt(a, b, base + 12, 2.5, 0.6, C(232, 228, 216), M.Glass, false).Transparency = 0.4
		else
			local g = glass(a, b, base, 14.5, C(238, 232, 222), 0.3)
			g.Name = "ShopWindow"
		end
		Util.deco(f, V3(0.7, 14.5, 0.7), CFrame.new(pa + V3(0, base + 7.25, 0)), SILVER, M.Metal)
		panelAt(a, b, base + 14.5, skinY - (base + 14.5), 1.2, PANEL, M.SmoothPlastic)
	end
	local function groundRun(a, b, bay)
		local du, dv = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(du * du + dv * dv)
		local n = math.max(1, math.floor(len / bay + 0.5))
		for k = 0, n - 1 do
			groundFace({ a[1] + du * k / n, a[2] + dv * k / n }, { a[1] + du * (k + 1) / n, a[2] + dv * (k + 1) / n }, false)
		end
	end
	-- Return from the drum's end out to the block's Yonge face, full height.
	panelAt({ BOX_U0, DRUM_V }, { BOX_U0, BOX_YV }, base, top - base, 1.2, PANEL, M.SmoothPlastic)
	groundRun({ BOX_U0, BOX_YV }, { KCU, BOX_YV }, 10)
	-- Yonge face.
	cladding({ KCU, BOX_YV }, { BOX_U0, BOX_YV })
	for u = BOX_U0 + 8, KCU - 1, 8 do
		Util.deco(f, V3(0.25, hPanel, 0.3), CFrame.new(P(u, BOX_YV - 0.65, skinY + hPanel / 2)), JOINT, M.SmoothPlastic)
	end
	do
		local mid = (BOX_U0 + KCU) / 2
		local scr = screen(facing(mid, BOX_YV - 0.6, l2 + 14, KCU - BOX_U0 - 6, 22, EAST))
		Util.deco(f, V3(scr.Size.X + 1, scr.Size.Y + 1, 0.4), scr.CFrame * CFrame.new(0, 0, 0.4), FRAME, M.Metal)
	end
	-- Rounded corner, the store's logo on it.
	do
		local SEG = 8
		local function cp(t) -- t 0 = the Yonge end, 1 = the Dundas end
			local th = math.pi / 2 * (1 - t)
			return KCU + KR * math.cos(th), KCV - KR * math.sin(th)
		end
		for k = 0, SEG - 1 do
			cladding({ cp(k / SEG) }, { cp((k + 1) / SEG) })
			if k == 0 or k == SEG - 1 then
				groundFace({ cp(k / SEG) }, { cp((k + 1) / SEG) }, false)
			end
		end
		-- The upper sign wraps the corner above a recessed bank facing the crossing.
		local au, av = cp(1 / SEG)
		local bu, bv = cp(1 - 1 / SEG)
		for bay = 0, 3 do
			local function jamb(t)
				return { au + (bu - au) * t, av + (bv - av) * t }
			end
			groundFace(jamb(bay / 4), jamb((bay + 1) / 4), bay == 1 or bay == 2)
		end
		local diag = (P(1, -1, 0) - P(0, 0, 0)).Unit
		if names.dundas then
			local cu, cv = cp(0.5)
			-- The store's logo over its corner doors, and again high on the corner.
			logo(facing(cu, cv, base + 16.5, 12, 4, diag), names.dundas)
			logo(facing(cu, cv, l2 + 6, 16, 6, diag), names.dundas)
		end
	end
	-- Short Dundas face of the projection, its portrait screen, then the step back.
	cladding({ BOX_DU, KCV }, { BOX_DU, BOX_STEP_V })
	groundRun({ BOX_DU, KCV }, { BOX_DU, BOX_STEP_V }, 10)
	do
		local scr = screen(facing(BOX_DU, (KCV + BOX_STEP_V) / 2, l2 + 16, 24, 32, NORTH))
		Util.deco(f, V3(25, 33, 0.4), scr.CFrame * CFrame.new(0, 0, 0.4), FRAME, M.Metal)
	end
	cladding({ BOX_DU, BOX_STEP_V }, { DUNDAS_FACE, BOX_STEP_V + 6 })
	groundRun({ BOX_DU, BOX_STEP_V }, { DUNDAS_FACE, BOX_STEP_V + 6 }, 30)
	-- Long Dundas face: panels over the plan's Dundas wall, a wide screen, logo.
	cladding({ DUNDAS_FACE, BOX_STEP_V + 6 }, { DUNDAS_FACE, DUNDAS_V1 })
	groundRun({ DUNDAS_FACE, BOX_STEP_V + 6 }, { DUNDAS_FACE, DUNDAS_V1 }, 12)
	for v = BOX_STEP_V + 14, DUNDAS_V1 - 1, 8 do
		Util.deco(f, V3(0.3, hPanel, 0.25), CFrame.new(P(DUNDAS_FACE + 0.65, v, skinY + hPanel / 2)), JOINT, M.SmoothPlastic)
	end
	panelAt({ DUNDAS_FACE, DUNDAS_V1 }, { 1389, DUNDAS_V1 }, base, boxTop - base, 1.2, PANEL, M.SmoothPlastic)
	do
		local scr = screen(facing(DUNDAS_FACE, 150, l2 + 14, 52, 24, NORTH))
		Util.deco(f, V3(53, 25, 0.4), scr.CFrame * CFrame.new(0, 0, 0.4), FRAME, M.Metal)
		if names.dundas then
			logo(facing(DUNDAS_FACE, 95, l2 + 16, 20, 6, NORTH), names.dundas)
		end
	end
	-- Roof over the projection (beyond the plan's own roof).
	do
		local a, b = P(1376, -8, 0), P(BOX_DU, BOX_STEP_V, 0)
		Util.solid(f, V3(math.abs(b.X - a.X), 1, math.abs(b.Z - a.Z)), CFrame.new((a + b) / 2 + V3(0, boxTop + 0.5, 0)), C(80, 84, 90), M.Concrete)
		local c, d = P(1386, BOX_STEP_V, 0), P(DUNDAS_FACE, DUNDAS_V1, 0)
		Util.solid(f, V3(math.abs(d.X - c.X), 1, math.abs(d.Z - c.Z)), CFrame.new((c + d) / 2 + V3(0, boxTop + 0.5, 0)), C(80, 84, 90), M.Concrete)
		local e, g = P(BOX_U0, BOX_YV, 0), P(1376, 22, 0)
		Util.solid(f, V3(math.abs(g.X - e.X), 1, math.abs(g.Z - e.Z)), CFrame.new((e + g) / 2 + V3(0, boxTop + 0.5, 0)), C(80, 84, 90), M.Concrete)
	end

	-----------------------------------------------------------------------
	-- The curved blue-glass office tower, set back behind the anchor's Dundas
	-- face (clear of the galleria skylight, which reaches the corner atrium).
	-----------------------------------------------------------------------
	do
		local tu, tv, au, av = 1362, 168, 26, 34
		local h = 240
		local y0 = levelY(5) + 1
		local SEG = 28
		local BLUE = C(84, 124, 170)
		local function pt(k)
			local t = k / SEG * 2 * math.pi
			return P(tu + au * math.cos(t), tv + av * math.sin(t), 0)
		end
		local centre = P(tu, tv, 0)
		local towardCorner = (P(1, -1, 0) - P(0, 0, 0)).Unit
		for k = 0, SEG - 1 do
			local a, b = pt(k), pt(k + 1)
			local mid = (a + b) / 2
			local cf = CFrame.lookAt(mid + V3(0, y0 + h / 2, 0), mid + V3(0, y0 + h / 2, 0) + (b - a))
			local seg = Util.deco(f, V3(1, h, (b - a).Magnitude + 0.3), cf, BLUE, M.SmoothPlastic)
			seg.Reflectance = 0.3
			Util.nightWindow(seg, 0.5)
			local o = V3(mid.X - centre.X, 0, mid.Z - centre.Z).Unit
			if o:Dot(towardCorner) > -0.3 then
				for y = 12, h - 6, 12 do
					Util.deco(f, V3(1.3, 0.8, (b - a).Magnitude + 0.3), cf * CFrame.new(0, -h / 2 + y, 0), C(214, 222, 230), M.SmoothPlastic)
				end
			end
		end
		Util.deco(f, V3(av * 1.5, 2, au * 1.5), CFrame.new(centre + V3(0, y0 + h - 1, 0)), C(60, 64, 70), M.Concrete)
		Util.deco(f, V3(av * 0.8, 12, au * 0.8), CFrame.new(centre + V3(0, y0 + h + 6, 0)), C(70, 74, 80), M.Concrete)
		if names.dundas then
			local p = centre + towardCorner * (math.min(au, av) * 1.1) + V3(0, y0 + 22, 0)
			logo(Util.deco(f, V3(24, 8, 0.3), CFrame.lookAt(p, p + towardCorner), WHITE, M.SmoothPlastic), names.dundas)
		end
	end

	-----------------------------------------------------------------------
	-- Yonge, south of the drum: the taller plain white block.
	-----------------------------------------------------------------------
	do
		local v, u0, u1 = -1.6, 1236, DRUM_U0
		local hTop = roofY + 34
		panelAt({ u0, v }, { u1, v }, skinY, hTop - skinY, 1.2, WHITE, M.SmoothPlastic)
		panelAt({ u0, v }, { u0 + 3, v }, base, skinY - base, 1.2, WHITE, M.SmoothPlastic)
		panelAt({ u1 - 3, v }, { u1, v }, base, skinY - base, 1.2, WHITE, M.SmoothPlastic)
		local r5 = levelY(5)
		local a, b = P(u0, v, 0), P(u1, 22, 0)
		Util.solid(f, V3(math.abs(b.X - a.X), hTop - r5, math.abs(b.Z - a.Z)), CFrame.new((a + b) / 2 + V3(0, (r5 + hTop) / 2, 0)), WHITE, M.SmoothPlastic)
		panelAt({ u1, v }, { u1, 22 }, base, hTop - base, 1.2, WHITE, M.SmoothPlastic)
		panelAt({ u0, v }, { u0, 22 }, base, r5 - base, 1.2, WHITE, M.SmoothPlastic)
		-- Its street front: dark glass with a black frame, as in Street View.
		local g = glass({ u0 + 3, v - 0.4 }, { u1 - 3, v - 0.4 }, base, 15, C(60, 66, 74), 0.3)
		g.Name = "ShopWindow"
		for u = u0 + 3, u1 - 3, 9 do
			Util.deco(f, V3(0.5, 15, 0.5), CFrame.new(P(u, v - 0.6, base + 7.5)), FRAME, M.Metal)
		end
		panelAt({ u0, v }, { u1, v }, base + 15, skinY - (base + 15), 1.2, FRAME, M.Metal)
		for u = u0 + 12, u1 - 1, 12 do
			Util.deco(f, V3(0.2, hTop - skinY, 0.2), CFrame.new(P(u, v - 0.65, (skinY + hTop) / 2)), C(222, 222, 218), M.SmoothPlastic)
		end
		if names.yonge then
			local plate = facing(u1 - 12, v - 0.4, hTop - 12, 14, 14, EAST, C(222, 24, 32))
			local words = string.split(string.upper(names.yonge), " ")
			Util.sign(plate, Enum.NormalId.Front, table.concat(words, string.char(10)), C(255, 255, 255), Enum.Font.GothamBlack).LightInfluence = 0
		end
		if names.dept then
			local blade = facing(u0 + 3, v - 0.5, l2 + 18, 4.5, 36, EAST, C(26, 26, 30))
			local letters = {}
			for ch in string.gmatch(string.upper(names.dept), ".") do
				table.insert(letters, ch)
			end
			Util.sign(blade, Enum.NormalId.Front, table.concat(letters, string.char(10)), C(255, 255, 255), Enum.Font.GothamMedium).LightInfluence = 0
		end
	end
	return f
end

-- The TMU well's dressing: stairs beside the escalators, balustrades round the
-- opening, the station sign over its top.
function Exterior.buildWell(folder, P, levelY, stationName)
	if not WELL then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "TMU_Entrance"
	f.Parent = folder
	local y0, y1 = levelY(0), levelY(1)
	-- Stairs along the well's west side, top at the south end like the escalators.
	local sv = WELL.v1 - 3
	local run = 26
	local n = 22
	local rise = (y1 - y0) / n
	for k = 0, n - 1 do
		local u = WELL.u0 + run * (k + 0.5) / n
		local yTop = y1 - rise * k
		local p = P(u, sv, yTop - rise / 2)
		Util.solid(f, V3(4.6, rise, run / n + 0.05), CFrame.new(p), C(176, 174, 168), M.Granite)
	end
	local landing = P(WELL.u0 + run + (WELL.u1 - WELL.u0 - run) / 2, sv, y0 - 0.5)
	Util.solid(f, V3(4.6, 1, WELL.u1 - WELL.u0 - run), CFrame.new(landing), C(176, 174, 168), M.Granite)
	-- Stair handrail on its open side.
	Util.beam(f, P(WELL.u0, sv - 2.6, y1 + 3), P(WELL.u0 + run, sv - 2.6, y0 + 3), 0.3, STEEL, M.Metal)
	-- Balustrades round the opening (open at the south end, where you step on).
	local function rail(a, b)
		local pa, pb = P(a[1], a[2], y1), P(b[1], b[2], y1)
		local mid = (pa + pb) / 2 + V3(0, 1.8, 0)
		local cf = CFrame.lookAt(mid, mid + (pb - pa))
		local g = Util.solid(f, V3(0.25, 3.6, (pb - pa).Magnitude), cf, C(200, 220, 230), M.Glass)
		g.Transparency = 0.55
		Util.deco(f, V3(0.4, 0.3, (pb - pa).Magnitude), cf * CFrame.new(0, 1.95, 0), STEEL, M.Metal)
	end
	rail({ WELL.u0, WELL.v0 }, { WELL.u1, WELL.v0 })
	rail({ WELL.u0, WELL.v1 }, { WELL.u1, WELL.v1 })
	rail({ WELL.u1, WELL.v0 }, { WELL.u1, WELL.v1 })
	-- The station sign over the top of the well, facing the atrium.
	local p = P(WELL.u0 - 1, (WELL.v0 + WELL.v1) / 2, y1 + 11)
	local plate = Util.deco(f, V3(WELL.v1 - WELL.v0 - 2, 2.6, 0.4), CFrame.lookAt(p, p + V3(0, 0, 1)), C(206, 30, 40), M.SmoothPlastic)
	Util.sign(plate, Enum.NormalId.Front, stationName .. " STATION  ·  LINE 1", C(255, 255, 255), Enum.Font.GothamBlack).LightInfluence = 0
	return f
end

return Exterior
