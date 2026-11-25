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

local Galleria = {}

local V3 = Vector3.new
local CF = CFrame.new
local M = Enum.Material
local C = Color3.fromRGB

local PIER = C(234, 232, 227)
local OFFICE_GLASS = C(62, 76, 90)
local BAND = C(196, 199, 204) -- balcony fascia: brushed silver-grey
local REVEAL = C(70, 72, 78)
local STRIPE = C(92, 94, 100)
local GLOW_WARM = C(255, 236, 206)
local PANEL_GREY = C(186, 196, 202)
local JOINT = C(150, 154, 160)

local function glow(parent, size, cf, colour)
	local p = Util.deco(parent, size, cf, colour or GLOW_WARM, M.Neon)
	p.CastShadow = false
	return p
end

---------------------------------------------------------------------------
-- Office glazing on a clerestory wall part (local X = across, +inward faces
-- the galleria, Y up, Z along).
---------------------------------------------------------------------------
function Galleria.officeFacade(parent, w, inward, rng)
	local H, len = w.Size.Y, w.Size.Z
	w.Color = OFFICE_GLASS
	w.Material = M.Glass
	w.Reflectance = 0.35
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
			if rows >= 2 and j % 4 == 2 then
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
				l.Brightness = 1.4
				l.Color = C(255, 232, 200)
				l.Shadows = false
				l.Parent = disc
			end
		end
	end
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
				l.Brightness = 1.2
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
	lit.Brightness = 1.2
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
-- open front, grey panels above.
function STYLES.greenband(f, cf, len, top, header, name)
	local d = 0.9
	cladding(f, cf, len, header + 3, top - 0.1, d)
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
