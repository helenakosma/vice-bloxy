-- The galleria's finishes, from the reference photos:
--   * officeFacade: the multi-storey office glazing above the shops under the
--     vault (white piers and floor bands, dark reflective glass, office lights
--     behind some panes, the odd projecting glass balcony).
--   * balcony: the deep silver band along each floor's edge, a light line under
--     it, downlights in the soffit, and a dark grey stripe on the floor parallel
--     to the edge (the walkway border in the photos).
--   * medallions: the concentric ring inlays on Level 1 at the courts.
--   * anchorFronts: the big fronts round the Yonge & Dundas entrance: the
--     Uniqlo stand-in (grey panels, red squares, recessed lit opening, a lit
--     display window on the floor above), the Simons stand-in (dark band, green
--     lettering) and the H&M stand-in (white band, red lettering). Names are
--     the made-up ones from Catalog/EatonTenants; no logos.
local Util = require(script.Parent.Parent.Util)
local Billboards = require(script.Parent.Parent.Billboards)

local Galleria = {}

local V3 = Vector3.new
local CF = CFrame.new
local M = Enum.Material
local C = Color3.fromRGB

local PIER = C(200, 204, 208) -- light grey frames, as in the photos (not white)
local OFFICE_GLASS = C(62, 76, 90)
local BAND = C(172, 177, 183) -- balcony fascia: brushed silver-grey (photos)
local REVEAL = C(70, 72, 78)
local STRIPE = C(92, 94, 100)
local GLOW_WARM = C(255, 236, 206)
local PANEL_GREY = C(186, 196, 202)
local JOINT = C(150, 154, 160)

-- Light sources: long strips and panels are matte (a lit diffuser, no bloom);
-- only small bulbs and lenses are neon, and toned down, so the mall doesn't glow.
local function softLight(p, colour)
	local s = p.Size
	if math.max(s.X, s.Y, s.Z) >= 2.5 then
		p.Material = Enum.Material.SmoothPlastic
		p.Color = colour
	else
		p.Material = Enum.Material.Neon
		p.Color = colour:Lerp(Color3.fromRGB(128, 118, 108), 0.35)
	end
	p.CastShadow = false
	return p
end
local function glow(parent, size, cf, colour)
	return softLight(Util.deco(parent, size, cf, colour or GLOW_WARM, M.Neon), colour or GLOW_WARM)
end

---------------------------------------------------------------------------
-- Office glazing on a clerestory wall part (local X = across, +inward faces
-- the galleria, Y up, Z along).
---------------------------------------------------------------------------
function Galleria.officeFacade(parent, w, inward, rng)
	local H, len = w.Size.Y, w.Size.Z
	-- Opaque, not Glass: Roblox glass shows the sky through it, which made the
	-- piers and bands look like frames floating in mid-air at night.
	w.Color = OFFICE_GLASS
	w.Material = M.SmoothPlastic
	w.Reflectance = 0.18
	local rows = math.max(1, math.floor(H / 9 + 0.5))
	local rowH = H / rows
	-- Floor bands (spandrels) at each floor line, top and bottom.
	for k = 0, rows do
		local yy = -H / 2 + k * rowH
		yy = math.clamp(yy, -H / 2 + 0.8, H / 2 - 0.8)
		Util.deco(parent, V3(1.1, 1.6, len), w.CFrame * CF(inward * 0.75, yy, 0), PIER, M.SmoothPlastic)
	end
	-- Piers, and per bay: a mullion, office ceiling lights behind some panes, and
	-- now and then a glass balcony projecting from the upper row.
	local bays = math.max(1, math.floor(len / 9))
	local bayW = len / bays
	for j = 0, bays do
		local z = -len / 2 + j * bayW
		Util.deco(parent, V3(1.5, H, 1.2), w.CFrame * CF(inward * 0.95, 0, z), PIER, M.SmoothPlastic)
		if j < bays then
			local zc = z + bayW / 2
			Util.deco(parent, V3(0.6, H - 1, 0.25), w.CFrame * CF(inward * 0.55, 0, zc), C(46, 50, 56), M.Metal)
			for k = 0, rows - 1 do
				if rng:NextNumber() < 0.4 then
					local top = -H / 2 + (k + 1) * rowH - 2
					glow(parent, V3(0.1, 0.22, bayW - 2.4), w.CFrame * CF(inward * 0.45, top, zc), C(236, 242, 252))
				end
			end
			-- now and then a big lit ad panel across two bays (as on the real upper
			-- walls), hung off the piers
			if j % 7 == 4 and j + 1 < bays and rows >= 2 then
				local adH = math.min(H - 3, rowH * 1.7)
				local ad = Util.deco(parent, V3(0.4, adH, bayW * 2 - 1.2), w.CFrame * CF(inward * 1.9, 0, z + bayW), C(20, 20, 24), M.SmoothPlastic)
				ad.Name = "WallAd"
				Util.deco(parent, V3(0.5, adH + 0.6, bayW * 2 - 0.6), w.CFrame * CF(inward * 1.75, 0, z + bayW), C(40, 42, 46), M.Metal)
				pcall(function()
					Billboards.face(ad, inward > 0 and Enum.NormalId.Right or Enum.NormalId.Left, Billboards.pick(rng), true)
				end)
			elseif rows >= 2 and j % 4 == 2 then
				local yb = -H / 2 + rowH
				Util.deco(parent, V3(3, 0.45, bayW - 1.6), w.CFrame * CF(inward * 2.2, yb, zc), PIER, M.SmoothPlastic)
				local g = Util.deco(parent, V3(0.15, 3.2, bayW - 1.6), w.CFrame * CF(inward * 3.6, yb + 1.8, zc), C(200, 222, 232), M.Glass)
				g.Transparency = 0.5
				Util.deco(parent, V3(0.25, 0.2, bayW - 1.6), w.CFrame * CF(inward * 3.6, yb + 3.45, zc), C(200, 202, 206), M.Metal)
			end
		end
	end
end

---------------------------------------------------------------------------
-- A floor's edge along a balustrade r = {u0, v0, u1, v1} on level `idx`.
--   ctx: { P, S, onSlab, lights = { n = 0, max = 110 } }
---------------------------------------------------------------------------
function Galleria.balcony(parent, ctx, idx, r, y, slab)
	local P, S = ctx.P, ctx.S
	local du, dv = r[3] - r[1], r[4] - r[2]
	local L = math.sqrt(du * du + dv * dv)
	if L < 1 then
		return
	end
	local nu, nv = -dv / L, du / L
	local mu, mv = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	local s = 1
	if not ctx.onSlab(idx, mu + nu * 4, mv + nv * 4) then
		s = -1
		if not ctx.onSlab(idx, mu - nu * 4, mv - nv * 4) then
			s = 0 -- a thin strip of floor: band only
		end
	end
	local pa, pb = P(r[1], r[2], 0), P(r[3], r[4], 0)
	local along = (pb - pa)
	local len = along.Magnitude
	local mid = (pa + pb) / 2
	local into = s ~= 0 and (P(mu + nu * s, mv + nv * s, 0) - P(mu, mv, 0)).Unit or V3()
	local function at(yy, off)
		local p = mid + V3(0, yy, 0) + into * off
		return CFrame.lookAt(p, p + along) -- local Z along the edge, X across
	end
	-- The deep band, a dark reveal at its foot, a light line under the soffit.
	local bandTop, bandH = y, slab + 2.6
	Util.deco(parent, V3(0.9, bandH, len + 0.3), at(bandTop - bandH / 2, -0.2), BAND, M.Metal).Name = "BalconyFascia"
	Util.deco(parent, V3(0.6, 0.3, len + 0.3), at(bandTop - bandH - 0.15, 0), REVEAL, M.Metal)
	if s ~= 0 and len >= 3 then
		glow(parent, V3(0.35, 0.08, len - 0.6), at(y - slab - 0.3, 0.9))
		-- A tall palm planter midway along longer edges.
		ctx.planters = ctx.planters or { n = 0, max = 60, rng = Random.new(31) }
		if len >= 30 and ctx.planters.n < ctx.planters.max then
			ctx.planters.n += 1
			Galleria.tallPlanter(parent, at(y, 2.3 * S), ctx.planters.rng)
		end
		-- Floor border stripe, 4 ft in from the edge.
		local stripe = Util.deco(parent, V3(1.0 * S, 0.05, math.max(0.5, len - 3)), at(y + 0.03, 4 * S), STRIPE, M.Slate)
		stripe.Name = "FloorStripe"
		-- Downlights in the soffit.
		local n = math.floor(len / 10)
		for k = 1, n do
			local t = (k - 0.5) / n - 0.5
			local cf = at(y - slab - 0.27, 3.5 * S) * CF(0, 0, t * len)
			local disc = glow(parent, V3(0.06, 0.9, 0.9), cf * CFrame.Angles(0, 0, math.rad(90)), C(255, 244, 226))
			disc.Shape = Enum.PartType.Cylinder
			if ctx.lights.n < ctx.lights.max and k % 3 == 2 then
				ctx.lights.n += 1
				local l = Instance.new("SpotLight")
				l.Face = Enum.NormalId.Left -- the cylinder's axis turned down: Left = -Y after the turn
				l.Angle = 100
				l.Range = 20
				l.Brightness = 0.7
				l.Color = C(255, 232, 200)
				l.Shadows = false
				l.Parent = disc
			end
		end
	end
end


---------------------------------------------------------------------------
-- Planters (photos): tall grey cylinders with spiky palms on the bridges and
-- balconies; low round white planters of flowers round the courts below.
---------------------------------------------------------------------------
local function cyl(parent, h, dia, cf, colour, material, collide)
	return Util.cylinder(parent, h, dia, cf, colour, material, collide)
end

function Galleria.tallPlanter(parent, cf, rng)
	cyl(parent, 3.4, 2.8, cf * CF(0, 1.7, 0), C(150, 156, 160), M.Concrete, true)
	cyl(parent, 0.1, 2.5, cf * CF(0, 3.42, 0), C(60, 46, 36), M.Ground, false)
	local trunk = cyl(parent, 2.4, 0.35, cf * CF(0, 4.6, 0), C(110, 90, 64), M.Wood, false)
	trunk.CastShadow = false
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + rng:NextNumber(0, 0.3)
		local tilt = math.rad(35 + (k % 3) * 15)
		local leaf = Util.deco(parent, V3(0.12, 2.8, 0.45), cf * CF(0, 5.8, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(tilt, 0, 0) * CF(0, 1.3, 0), C(64, 110, 60):Lerp(C(110, 150, 80), rng:NextNumber()), M.Grass)
		leaf.CastShadow = false
	end
end

function Galleria.flowerPlanter(parent, cf, rng)
	cyl(parent, 1.8, 5, cf * CF(0, 0.9, 0), C(226, 224, 220), M.Concrete, true)
	cyl(parent, 0.1, 4.6, cf * CF(0, 1.82, 0), C(60, 46, 36), M.Ground, false)
	local shrub = Util.deco(parent, V3(2.2, 1.8, 2.2), cf * CF(0, 2.6, 0), C(70, 112, 60), M.Grass)
	shrub.Shape = Enum.PartType.Ball
	local tones = { C(214, 40, 70), C(240, 200, 60), C(240, 240, 236), C(200, 90, 160), C(230, 120, 60) }
	local tone = tones[rng:NextInteger(1, #tones)]
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local fl = Util.deco(parent, V3(0.6, 0.6, 0.6), cf * CF(math.cos(a) * 1.75, 2.05 + (k % 2) * 0.2, math.sin(a) * 1.75), k % 3 == 0 and C(70, 112, 60) or tone, M.Fabric)
		fl.Shape = Enum.PartType.Ball
		fl.CastShadow = false
	end
end


---------------------------------------------------------------------------
-- A hallway kiosk (plan units Z...): a waist-high counter round a small
-- island, glass display tops, a slim canopy on four posts with the name on
-- both long sides, stock on the shelves, a stool for the attendant. ATMs get
-- a pair of machines in a branded surround instead. Sized well inside the
-- plan's box, so the corridor stays wide.
---------------------------------------------------------------------------
function Galleria.kiosk(parent, P, y, u, tenant, design)
	local f = Instance.new("Model")
	f.Name = "Kiosk_" .. u.unit
	f.Parent = parent
	local pal = design.pal
	local accent = pal.accent
	local cu, cv = (u.umin + u.umax) / 2, (u.vmin + u.vmax) / 2
	local du, dv = (u.umax - u.umin), (u.vmax - u.vmin)
	local centre = P(cu, cv, y)
	-- long axis along the corridor's longer plan direction
	local alongU = du >= dv
	local L = math.max(5, math.min(9, (alongU and du or dv) - 3))
	local W = math.max(3.5, math.min(5.5, (alongU and dv or du) - 3))
	local dir = alongU and (P(cu + 1, cv, y) - P(cu, cv, y)).Unit or (P(cu, cv + 1, y) - P(cu, cv, y)).Unit
	local cf = CFrame.lookAt(centre, centre + V3(-dir.Z, 0, dir.X)) * CFrame.Angles(0, 0, 0) -- X along the long side
	local real = string.lower(tenant.real or "")
	if real:find("atm", 1, true) then
		-- two ATMs back to back in a slim branded pod
		Util.solid(f, V3(3.2, 7, 2.6), cf * CF(0, 3.5, 0), accent:Lerp(C(30, 30, 32), 0.2), M.SmoothPlastic)
		for _, s in ipairs({ -1, 1 }) do
			local face = cf * CFrame.Angles(0, s > 0 and 0 or math.pi, 0)
			Util.deco(f, V3(2.4, 3.2, 0.5), face * CF(0, 3.4, -1.45), C(48, 50, 56), M.Metal)
			local scr = Util.deco(f, V3(1.2, 0.9, 0.05), face * CF(0, 4.3, -1.72), C(60, 140, 200), M.Neon)
			scr.Color = C(70, 120, 160)
			Util.deco(f, V3(1.4, 0.6, 0.4), face * CF(0, 3.2, -1.85), C(40, 40, 44), M.Metal)
		end
		local top = Util.deco(f, V3(3.4, 1, 2.8), cf * CF(0, 7.5, 0), accent, M.SmoothPlastic)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local g = Util.sign(top, face, tenant.name, C(255, 255, 255), Enum.Font.GothamBold)
			g.LightInfluence = 0
		end
		return f
	end
	local body = pal.fixture
	-- counter: a ring of four sides with a gap at one end for the attendant
	local h = 3.4
	Util.solid(f, V3(L, h, 0.8), cf * CF(0, h / 2, -W / 2 + 0.4), body, M.SmoothPlastic)
	Util.solid(f, V3(L, h, 0.8), cf * CF(0, h / 2, W / 2 - 0.4), body, M.SmoothPlastic)
	Util.solid(f, V3(0.8, h, W - 1.6), cf * CF(-L / 2 + 0.4, h / 2, 0), body, M.SmoothPlastic)
	Util.solid(f, V3(0.8, h, W / 2 - 1.2), cf * CF(L / 2 - 0.4, h / 2, -W / 4 - 0.2), body, M.SmoothPlastic)
	-- accent kick strip and glass display tops with stock under the glass
	for _, z in ipairs({ -W / 2 + 0.4, W / 2 - 0.4 }) do
		Util.deco(f, V3(L + 0.05, 0.35, 0.85), cf * CF(0, 0.18, z), accent, M.SmoothPlastic)
		local g = Util.deco(f, V3(L - 0.4, 0.5, 0.7), cf * CF(0, h + 0.25, z), C(210, 226, 234), M.Glass)
		g.Transparency = 0.6
		for x = -L / 2 + 0.8, L / 2 - 0.8, 0.9 do
			Util.deco(f, V3(0.4, 0.15, 0.25), cf * CF(x, h + 0.08, z), (math.floor(x * 3) % 2 == 0) and C(30, 30, 34) or accent:Lerp(C(255, 255, 255), 0.4), M.SmoothPlastic)
		end
	end
	-- posts and canopy with the name on both long sides
	local ch = 8.6
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			Util.deco(f, V3(0.18, ch - h, 0.18), cf * CF(sx * (L / 2 - 0.3), h + (ch - h) / 2, sz * (W / 2 - 0.3)), C(60, 62, 68), M.Metal)
		end
	end
	local canopy = Util.deco(f, V3(L + 0.4, 1.2, W + 0.4), cf * CF(0, ch + 0.6, 0), accent, M.SmoothPlastic)
	canopy.Name = "KioskCanopy"
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Util.sign(canopy, face, string.upper(tenant.name), C(255, 255, 255), Enum.Font.GothamBold)
		g.LightInfluence = 0
	end
	glow(f, V3(L - 0.4, 0.08, W - 0.6), cf * CF(0, ch - 0.02, 0), C(255, 244, 228))
	-- a slatwall of stock in the middle, a stool, a card reader
	Util.deco(f, V3(L * 0.5, 3.4, 0.25), cf * CF(-L * 0.12, h + 1.7, 0), body:Lerp(C(0, 0, 0), 0.08), M.SmoothPlastic)
	for x = -L * 0.32, L * 0.08, 0.6 do
		for yy = h + 0.6, h + 3, 0.8 do
			Util.deco(f, V3(0.35, 0.5, 0.15), cf * CF(x, yy, 0.2), (math.floor((x + yy) * 2) % 3 == 0) and accent or C(30, 30, 34), M.SmoothPlastic)
		end
	end
	local stool = Util.cylinder(f, 2.4, 1.1, cf * CF(L * 0.25, 1.2, 0), C(40, 40, 44), M.Metal, false)
	stool.Name = "Stool"
	Util.deco(f, V3(0.4, 0.15, 0.6), cf * CF(L * 0.3, h + 0.08, W / 2 - 0.4), C(30, 30, 34), M.Metal)
	return f
end

---------------------------------------------------------------------------
-- Concentric ring inlays: {u, v, radius} at floor height y.
---------------------------------------------------------------------------
function Galleria.medallions(parent, ctx, list, y)
	local P, S = ctx.P, ctx.S
	local DARK, MID, LIGHT = C(132, 124, 114), C(186, 176, 162), C(226, 216, 200)
	for _, m in ipairs(list or {}) do
		local centre = P(m[1], m[2], y)
		local R = m[3] * S
		local f = Instance.new("Model")
		f.Name = "CourtMedallion"
		f.Parent = parent
		local k, rad = 0, R
		while rad >= 1.5 do
			local colour = (k % 2 == 0) and DARK or ((k % 4 == 1) and LIGHT or MID) -- thin dark lines between wide bands
			local ring = Util.deco(f, V3(0.05, rad * 2, rad * 2), CF(centre + V3(0, 0.02 + k * 0.012, 0)) * CFrame.Angles(0, 0, math.rad(90)), colour, M.Marble)
			ring.Shape = Enum.PartType.Cylinder
			ring.Reflectance = 0.06
			k += 1
			rad -= (k % 2 == 1) and 0.8 or 2.6 -- thin dark lines between wide bands
		end
		-- low flower planters round the court, where there's floor
		local prng = Random.new(math.floor(m[1] + m[2]))
		for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local pu, pv = m[1] + o[1] * (m[3] + 6), m[2] + o[2] * (m[3] + 6)
			if ctx.onSlab and ctx.onSlab(1, pu, pv) and ctx.onSlab(1, pu + o[1] * 3, pv + o[2] * 3) then
				Galleria.flowerPlanter(f, CF(P(pu, pv, y)), prng)
			end
		end
		local hub = Util.deco(f, V3(0.05, 2.4, 2.4), CF(centre + V3(0, 0.03 + k * 0.012, 0)) * CFrame.Angles(0, 0, math.rad(90)), C(60, 58, 56), M.Marble)
		hub.Shape = Enum.PartType.Cylinder
	end
end

---------------------------------------------------------------------------
-- The anchor fronts by the Yonge & Dundas entrance.
---------------------------------------------------------------------------
local function frame(ctx, front, y)
	local P = ctx.P
	local pa, pb = P(front[1], front[2], y), P(front[3], front[4], y)
	local mu, mv = (front[1] + front[3]) / 2, (front[2] + front[4]) / 2
	local out = (P(mu + front[5], mv + front[6], 0) - P(mu, mv, 0)).Unit
	local mid = (pa + pb) / 2
	-- Local: X along the front, -Z out to the mall, +Z into the store, Y up.
	local cf = CFrame.lookAt(mid, mid + out)
	return cf, (pb - pa).Magnitude
end

-- Large grey cladding panels with shadow joints, between heights y0..y1.
local function cladding(f, cf, len, y0, y1, d)
	local h = y1 - y0
	if h <= 0.2 then
		return
	end
	Util.deco(f, V3(len, h, 0.3), cf * CF(0, y0 + h / 2, -d + 0.2), JOINT, M.SmoothPlastic)
	local n = math.max(1, math.floor(len / 9 + 0.5))
	local pw = len / n
	local rows = h > 9 and 2 or 1
	local ph = h / rows
	for i = 0, n - 1 do
		for j = 0, rows - 1 do
			Util.deco(f, V3(pw - 0.18, ph - 0.18, 0.4), cf * CF(-len / 2 + (i + 0.5) * pw, y0 + (j + 0.5) * ph, -d), PANEL_GREY, M.SmoothPlastic)
		end
	end
end

-- The recessed ceiling over an open front, with rows of downlights.
local function soffit(f, cf, len, hY, depth)
	Util.deco(f, V3(len, 0.3, depth), cf * CF(0, hY, depth / 2 - 0.8), C(232, 230, 226), M.SmoothPlastic)
	local lit = 0
	for x = -len / 2 + 2.5, len / 2 - 2.5, 4 do
		for _, z in ipairs({ 1, depth - 2.5 }) do
			local d = glow(f, V3(0.06, 0.7, 0.7), cf * CF(x, hY - 0.17, z - 0.8) * CFrame.Angles(0, 0, math.rad(90)), C(255, 246, 230))
			d.Shape = Enum.PartType.Cylinder
			if lit < 4 and math.abs(x) < 1 + lit * len / 8 and z == 1 then
				lit += 1
				local l = Instance.new("PointLight")
				l.Range = 18
				l.Brightness = 0.7
				l.Color = C(255, 238, 214)
				l.Shadows = false
				l.Parent = d
			end
		end
	end
end

local function textOn(part, text, colour, font)
	local gui = Util.sign(part, Enum.NormalId.Front, text, colour, font)
	gui.LightInfluence = 0
	return gui
end

local function splitName(name)
	local words = string.split(string.upper(name), " ")
	return words[1] or "", words[2] or ""
end

local STYLES = {}

-- The Uniqlo stand-in at street level: grey panels, two red squares, a deep
-- lit opening under them.
function STYLES.squares(f, cf, len, top, header, name)
	local d = 0.9
	cladding(f, cf, len, header - 1.5, top - 0.1, d)
	soffit(f, cf, len - 1, header - 1.5, 7)
	for _, s in ipairs({ -1, 1 }) do
		Util.deco(f, V3(2.2, top, 1.6), cf * CF(s * (len / 2 - 1.1), top / 2, -d + 0.3), PANEL_GREY, M.SmoothPlastic)
	end
	local a, b = splitName(name)
	local side = math.min(5.6, top - header - 0.4)
	for k, word in ipairs({ a, b }) do
		if word ~= "" then
			local sq = Util.deco(f, V3(side, side, 0.3), cf * CF((k - 1.5) * (side + 0.8), header - 1.5 + (top - header + 1.5) / 2, -d - 0.4), C(222, 22, 32), M.SmoothPlastic)
			sq.Name = "SquareSign"
			local mid = math.ceil(#word / 2)
			textOn(sq, word:sub(1, mid) .. "\n" .. word:sub(mid + 1), C(255, 255, 255), Enum.Font.GothamBlack)
		end
	end
end

-- The same store's floor above: a long lit display window with figures in it,
-- a red text ticker along its top, grey panels above and below, and a big red
-- square at one end.
function STYLES.display(f, cf, len, top, header, name, isReturn)
	local d = 0.9
	local g0, g1 = 2.5, math.min(header - 0.5, top - 3)
	cladding(f, cf, len, 0, g0, d)
	cladding(f, cf, len, g1 + 0.6, top - 0.1, d)
	local back = Util.deco(f, V3(len - 1, g1 - g0, 0.3), cf * CF(0, (g0 + g1) / 2, 4.5), C(244, 228, 208), M.SmoothPlastic)
	back.Name = "DisplayBack"
	Util.deco(f, V3(len - 1, 0.4, 5.4), cf * CF(0, g0 - 0.2, 1.8), C(236, 234, 230), M.SmoothPlastic)
	local glass = Util.solid(f, V3(len, top, 0.25), cf * CF(0, top / 2, -d + 0.1), C(210, 226, 234), M.Glass)
	glass.Transparency = 0.75
	glass.CastShadow = false
	local ticker = glow(f, V3(len - 1, 0.7, 0.2), cf * CF(0, g1 + 0.25, -d - 0.05), C(230, 30, 40))
	ticker.Name = "Ticker"
	for x = -len / 2 + 3, len / 2 - 3, 1.6 do
		glow(f, V3(0.35, 0.35, 0.35), cf * CF(x, g1 - 0.4, 2), C(255, 238, 210)).Shape = Enum.PartType.Ball
	end
	local fig = 0
	for x = -len / 2 + (isReturn and 3 or 14), len / 2 - 4, 4.5 do
		fig += 1
		local tone = (fig % 3 == 0) and C(40, 40, 44) or ((fig % 3 == 1) and C(236, 232, 226) or C(176, 40, 44))
		Util.deco(f, V3(1.5, 3.4, 0.8), cf * CF(x, g0 + 2.4, 2.4), tone, M.Fabric)
		Util.deco(f, V3(0.9, 1.4, 0.7), cf * CF(x, g0 + 0.5, 2.4), C(50, 52, 58), M.Fabric)
		Util.deco(f, V3(0.8, 0.9, 0.8), cf * CF(x, g0 + 4.6, 2.4), C(238, 236, 232), M.SmoothPlastic).Shape = Enum.PartType.Ball
	end
	local lit = Instance.new("PointLight")
	lit.Range = 22
	lit.Brightness = 0.7
	lit.Color = C(255, 232, 204)
	lit.Shadows = false
	lit.Parent = back
	if isReturn then
		return
	end
	local side = math.min(11, top - 1)
	local sq = Util.deco(f, V3(side, side, 0.3), cf * CF(-len / 2 + side / 2 + 1, top / 2, -d - 0.4), C(222, 22, 32), M.SmoothPlastic)
	local a = splitName(name)
	local mid = math.ceil(#a / 2)
	textOn(sq, a:sub(1, mid) .. "\n" .. a:sub(mid + 1), C(255, 255, 255), Enum.Font.GothamBlack)
end

-- The Simons stand-in: a dark band with glowing green lettering over a wide
-- open front, and above it the store's green glass wall with vertical fins
-- and the name again, large (as in the 2026 photos of the north atrium).
function STYLES.greenband(f, cf, len, top, header, name)
	local d = 0.9
	local y0, y1 = header + 3, top - 0.1
	if y1 - y0 > 1 then
		local h = y1 - y0
		local glass = Util.deco(f, V3(len, h, 0.3), cf * CF(0, y0 + h / 2, -d + 0.2), C(34, 84, 58), M.Glass)
		glass.Reflectance = 0.2
		glass.CastShadow = false
		local n = math.min(90, math.floor(len / 1.3))
		for k = 0, n do
			Util.deco(f, V3(0.15, h, 0.7), cf * CF(-len / 2 + k * len / n, y0 + h / 2, -d - 0.25), C(56, 112, 78), M.Metal).CastShadow = false
		end
		Util.deco(f, V3(len, 0.4, 0.9), cf * CF(0, y1 - 0.2, -d - 0.2), C(40, 70, 52), M.Metal)
		local big = Util.deco(f, V3(math.min(len * 0.5, 34), math.min(h * 0.55, 5), 0.1), cf * CF(-len * 0.12, y0 + h * 0.55, -d - 0.7), C(34, 84, 58), M.SmoothPlastic)
		big.Transparency = 1
		textOn(big, string.lower(name), C(150, 230, 160), Enum.Font.GothamMedium)
	end
	local band = Util.deco(f, V3(len, 4.5, 0.6), cf * CF(0, header + 0.75, -d), C(30, 32, 36), M.SmoothPlastic)
	band.Name = "NameBand"
	local plate = Util.deco(f, V3(math.min(len * 0.45, 30), 2.8, 0.1), cf * CF(-len * 0.18, header + 0.75, -d - 0.35), C(30, 32, 36), M.SmoothPlastic)
	plate.Transparency = 1
	textOn(plate, string.lower(name), C(91, 204, 100), Enum.Font.GothamMedium)
	soffit(f, cf, len - 1, header - 1.5, 8)
end

-- The H&M stand-in: a white band with the name in red.
function STYLES.redword(f, cf, len, top, header, name)
	local d = 0.9
	cladding(f, cf, len, header + 3.5, top - 0.1, d)
	local band = Util.deco(f, V3(len, 5, 0.6), cf * CF(0, header + 1, -d), C(246, 246, 244), M.SmoothPlastic)
	band.Name = "NameBand"
	local plate = Util.deco(f, V3(math.min(len * 0.5, 22), 3.6, 0.1), cf * CF(0, header + 1, -d - 0.35), C(246, 246, 244), M.SmoothPlastic)
	plate.Transparency = 1
	textOn(plate, name, C(214, 20, 30), Enum.Font.Bodoni)
	soffit(f, cf, len - 1, header - 1.5, 6)
end

-- Which store gets which front (matched on the real tenant, never shown).
local function styleFor(real, level)
	real = string.lower(real or "")
	if real == "uniqlo" then
		return level >= 4 and "display" or "squares"
	elseif real == "simons" then
		return "greenband"
	elseif real == "h m" or real == "h & m" then
		return "redword"
	end
	return nil
end

-- ctx: { P, S, levelY, levelData, tenants, header }
function Galleria.anchorFronts(parent, ctx)
	local f = Instance.new("Folder")
	f.Name = "AnchorFronts"
	f.Parent = parent
	local built = 0
	for _, L in ipairs(ctx.levelData) do
		local i = L.idx
		if i >= 1 then
			local y = ctx.levelY(i)
			local top = ctx.levelY(i + 1) - y - (i >= 3 and 0 or 1)
			for _, u in ipairs(L.data.units or {}) do
				local tenant = ctx.tenants[i .. ":" .. u.unit]
				local style = tenant and tenant.name and styleFor(tenant.real, i)
				if style and u.front then
					local cf, len = frame(ctx, u.front, y)
					if len >= 12 then
						local ok, err = pcall(STYLES[style], f, cf, len, top, ctx.header, tenant.name)
						if ok then
							-- The north court display wraps the turn in the L4 leasing outline.
							-- Use the next traced public edge. Service-side walls share this unit ID.
							if style == "display" and u.unit == "C301B" and i == 4 then
								local uEnd, vEnd = u.front[3], u.front[4]
								for _, wall in ipairs(L.data.walls) do
									if wall[5] == 2 and wall[6] == u.unit
										and math.abs(wall[1] - uEnd) < 1 and math.abs(wall[2] - vEnd) < 1 then
										local edge = {wall[1], wall[2], wall[3], wall[4], wall[7], wall[8]}
										local returnFrame, length = frame(ctx, edge, y)
										STYLES.display(f, returnFrame, length, top, ctx.header, tenant.name, true)
										break
									end
								end
							end
							built += 1
						else
							warn("[Galleria] front " .. u.unit .. ": " .. tostring(err))
						end
					end
				end
			end
		end
	end
	return built
end

return Galleria
