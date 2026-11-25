-- The Eaton Centre's corner at Yonge & Dundas, as it looks from the street:
--   * a rounded glass pavilion on the corner: shop windows and doors at street
--     level, a canopy, the curved dark-blue "Toronto Eaton Centre" band, a glass
--     curtain wall above, a white cornice;
--   * a giant vertical LED screen rising above the corner;
--   * along Yonge, the white-panelled block with big screens and a two-storey
--     glass shopfront (the corner anchor store);
--   * along Dundas, the tall windowless white block (the anchor on Level 3) with
--     a glass box entrance at street level.
-- Plan feet in, studs out through P(u, v, y) (u north of Queen St, v west of
-- Yonge St). The pavilion is centred on the plan's corner entrance.
local Util = require(script.Parent.Parent.Util)
local Billboards = require(script.Parent.Parent.Billboards)

local Exterior = {}

local V3 = Vector3.new
local M = Enum.Material
local C = Color3.fromRGB

local GLASS_BLUE = C(120, 150, 180)
local NAVY = C(28, 36, 72)
local WHITE = C(236, 236, 232)
local PANEL = C(222, 224, 226)

-- The corner pavilion: an arc round (u0, v0) of radius R, from facing Dundas
-- (north, +u) to facing Yonge (east, -v).
local CU, CV, R = 1368, 46, 46
Exterior.CORNER = { u = CU, v = CV, r = R }

-- Default exterior walls the corner replaces (by their midpoint, plan feet).
function Exterior.replaces(u, v, level)
	if u > CU - 6 and v < CV + 18 then
		return true -- the corner itself
	end
	if level == 1 and u > 1238 and u < CU and v < 4 then
		return true -- the H&M shopfront along Yonge, Level 1
	end
	return false
end

local function arcPoint(theta)
	-- theta 0 = north (Dundas side), pi/2 = east (Yonge side)
	return CU + R * math.cos(theta), CV - R * math.sin(theta)
end

function Exterior.build(folder, P, S, base, roofY, rng, names)
	local f = Instance.new("Folder")
	f.Name = "YongeDundasCorner"
	f.Parent = folder

	local function panelAt(a, b, y, h, thick, colour, material, collide)
		local pa, pb = P(a[1], a[2], 0), P(b[1], b[2], 0)
		local len = (pb - pa).Magnitude
		local mid = (pa + pb) / 2 + V3(0, y + h / 2, 0)
		local cf = CFrame.lookAt(mid, mid + (pb - pa))
		local size = V3(thick, h, len + 0.05)
		if collide == false then
			return Util.deco(f, size, cf, colour, material), cf
		end
		return Util.solid(f, size, cf, colour, material), cf
	end

	-- Which way is out from the arc at angle t (world vector).
	local function outward(t)
		local u, v = arcPoint(t)
		local c = P(CU, CV, 0)
		local p = P(u, v, 0)
		return (p - c).Unit
	end

	-----------------------------------------------------------------------
	-- The rounded pavilion.
	-----------------------------------------------------------------------
	local N = 20
	local LETTERS = "TORONTO EATON CENTRE"
	local top = roofY - base
	for k = 0, N - 1 do
		local t0, t1 = k / N * math.pi / 2, (k + 1) / N * math.pi / 2
		local a = { arcPoint(t0) }
		local b = { arcPoint(t1) }
		local door = k >= 7 and k <= 12 -- doors in the middle of the curve
		-- Street level: shop windows, or an open doorway with revolving doors.
		if not door then
			local g = panelAt(a, b, base, 13, 0.3, C(190, 214, 226), M.Glass)
			g.Transparency = 0.55
		else
			local pa, pb = P(a[1], a[2], base), P(b[1], b[2], base)
			local mid = (pa + pb) / 2
			if k % 2 == 0 then
				local drum = Util.cylinder(f, 8, 6.5, CFrame.new(mid + V3(0, 4, 0)), C(200, 220, 230), M.Glass, false)
				drum.Transparency = 0.6
				Util.cylinder(f, 0.4, 6.8, CFrame.new(mid + V3(0, 8.2, 0)), C(150, 152, 158), M.Metal, false)
			end
		end
		-- Door frame / lintel all the way round.
		panelAt(a, b, base + 13, 1, 0.8, C(170, 172, 178), M.Metal)
		-- Canopy projecting over the sidewalk.
		local o = outward((t0 + t1) / 2)
		local pa, pb = P(a[1], a[2], 0), P(b[1], b[2], 0)
		local mid = (pa + pb) / 2 + o * 3 + V3(0, base + 14.6, 0)
		Util.deco(f, V3(((pb - pa).Magnitude) + 0.6, 0.6, 6), CFrame.lookAt(mid, mid + o), C(236, 236, 232), M.SmoothPlastic)
		-- The curved name band: one letter per segment.
		local band, bandCF = panelAt(a, b, base + 16, 6, 0.8, NAVY, M.SmoothPlastic)
		local ch = string.sub(LETTERS, N - k, N - k)
		if ch ~= "" and ch ~= " " then
			local face = bandCF.RightVector:Dot(o) > 0 and Enum.NormalId.Right or Enum.NormalId.Left
			Util.sign(band, face, ch, C(240, 240, 244), Enum.Font.Gotham).LightInfluence = 0
		end
		-- Curtain wall above, with a white mullion at each joint and cornice.
		local cw = panelAt(a, b, base + 22, top - 25, 0.4, GLASS_BLUE, M.Glass)
		cw.Transparency = 0.15
		cw.Reflectance = 0.35
		local pv = P(a[1], a[2], 0)
		Util.deco(f, V3(0.5, top - 25, 0.5), CFrame.new(pv + V3(0, base + 22 + (top - 25) / 2, 0)), WHITE, M.SmoothPlastic)
		for _, hy in ipairs({ base + 34, base + 46 }) do
			panelAt(a, b, hy, 0.4, 0.6, WHITE, M.SmoothPlastic, false)
		end
		panelAt(a, b, roofY - 3, 4, 1, WHITE, M.SmoothPlastic)
	end
	-- Close the pavilion back to the Dundas facade.
	local nu, nv = arcPoint(0)
	panelAt({ nu, nv }, { nu, CV + 18 }, base, top + 1, 1.2, WHITE, M.SmoothPlastic)
	panelAt({ nu, CV + 18 }, { 1391, CV + 18 }, base, top + 1, 1.2, WHITE, M.SmoothPlastic)

	-- The giant screen above the corner, facing the intersection.
	do
		local o = outward(math.pi / 4)
		local cu, cv = CU + (R - 18) * math.cos(math.pi / 4), CV - (R - 18) * math.sin(math.pi / 4)
		local c = P(cu, cv, 0)
		local h = 72
		local cf = CFrame.lookAt(c + V3(0, roofY + 2 + h / 2, 0), c + V3(0, roofY + 2 + h / 2, 0) + o)
		Util.solid(f, V3(36, h, 6), cf * CFrame.new(0, 0, 3.2), C(30, 30, 34), M.Metal)
		local screen = Util.deco(f, V3(34, h - 2, 0.4), cf, C(10, 10, 12), M.SmoothPlastic)
		screen.CastShadow = false
		Billboards.face(screen, Enum.NormalId.Front, Billboards.pick(rng), true)
		Util.solid(f, V3(10, 4, 10), CFrame.new(c + V3(0, roofY + 2, 0)), C(60, 62, 68), M.Metal)
	end

	-- A subway sign by the corner doors (Dundas station).
	do
		local su, sv = arcPoint(math.pi / 2 * 0.62)
		local p = P(su + 8, sv - 8, base)
		Util.cylinder(f, 12, 0.5, CFrame.new(p + V3(0, 6, 0)), C(40, 40, 44), M.Metal, true)
		local plate = Util.deco(f, V3(4.5, 3, 0.5), CFrame.new(p + V3(0, 12.5, 0)) * CFrame.Angles(0, math.rad(45), 0), C(206, 30, 40), M.SmoothPlastic)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			Util.sign(plate, face, "SUBWAY", C(255, 255, 255), Enum.Font.GothamBlack).LightInfluence = 0
		end
	end

	-----------------------------------------------------------------------
	-- Along Yonge: the white panelled block with screens; glass shopfront.
	-----------------------------------------------------------------------
	local y0, y1 = 1240, CU - 2
	local c1 = CU - 14 -- the panel cladding stops here, clear of the curve
	-- Two-storey glass shopfront at street level (Level 1).
	for u = y0, y1 - 1, 12 do
		local g = panelAt({ u, -1 }, { math.min(u + 12, y1), -1 }, base, 14, 0.3, C(214, 226, 232), M.Glass)
		g.Transparency = 0.5
		Util.deco(f, V3(0.6, 14, 0.6), CFrame.new(P(u, -1, base + 7)), C(60, 62, 68), M.Metal)
	end
	-- White panel cladding above, just outside the facade, with joints.
	panelAt({ y0, -8.5 }, { c1, -8.5 }, base + 14, top - 14, 0.8, PANEL, M.SmoothPlastic)
	panelAt({ c1, -8.5 }, { c1, 0 }, base + 14, top - 14, 0.8, PANEL, M.SmoothPlastic)
	for u = y0, c1, 10 do
		Util.deco(f, V3(0.2, top - 14, 0.3), CFrame.new(P(u, -9, base + 14 + (top - 14) / 2)), C(196, 198, 202), M.SmoothPlastic)
	end
	for _, hy in ipairs({ base + 28, base + 42 }) do
		panelAt({ y0, -9 }, { c1, -9 }, hy, 0.25, 0.3, C(196, 198, 202), M.SmoothPlastic, false)
	end
	-- Two big screens on the Yonge face.
	for _, info in ipairs({ { 1325, 30, 18 }, { 1268, 26, 15 } }) do
		local u, w, h = info[1], info[2], info[3]
		local p = P(u, -9.6, base + 30)
		local cf = CFrame.lookAt(p, p + V3(1, 0, 0))
		local scr = Util.deco(f, V3(w, h, 0.4), cf, C(10, 10, 12), M.SmoothPlastic)
		scr.CastShadow = false
		Billboards.face(scr, Enum.NormalId.Front, Billboards.pick(rng), true)
	end
	-- The anchor's name high on the Yonge face.
	if names and names.yonge then
		local p = P(c1 - 14, -9.6, roofY - 9)
		local sign = Util.deco(f, V3(20, 4, 0.3), CFrame.lookAt(p, p + V3(1, 0, 0)), PANEL, M.SmoothPlastic)
		Util.sign(sign, Enum.NormalId.Front, string.upper(names.yonge), C(200, 20, 30), Enum.Font.GothamBlack).LightInfluence = 0
	end

	-----------------------------------------------------------------------
	-- Along Dundas: the tall white block, and its glass box entrance.
	-----------------------------------------------------------------------
	local d0, d1 = 96, 300
	local h2 = 44
	do
		local a, b = P(1352, d0, 0), P(1392, d1, 0)
		local mid = (a + b) / 2
		local size = V3(math.abs(b.X - a.X), h2, math.abs(b.Z - a.Z))
		Util.solid(f, size, CFrame.new(mid + V3(0, roofY + h2 / 2, 0)), WHITE, M.Concrete)
		-- The Dundas face continues the white down to the street above the doors.
		panelAt({ 1393, d0 }, { 1393, d1 }, base + 16, top - 16, 0.8, WHITE, M.Concrete)
		if names and names.dundas then
			local p = P(1393.6, (d0 + d1) / 2 + 30, roofY + h2 / 2)
			local logo = Util.deco(f, V3(18, 18, 0.4), CFrame.lookAt(p, p + V3(0, 0, -1)), C(220, 30, 40), M.SmoothPlastic)
			Util.sign(logo, Enum.NormalId.Front, string.upper(names.dundas), C(255, 255, 255), Enum.Font.GothamBlack).LightInfluence = 0
		end
	end
	-- Glass box entrance in front of the Dundas face.
	do
		local u0, u1, v0, v1 = 1392, 1412, 186, 214
		local corners = { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } }
		for i = 1, 3 do
			local g = panelAt(corners[i], corners[i + 1], base, 24, 0.4, C(170, 196, 210), M.Glass, i ~= 2)
			g.Transparency = 0.45
		end
		local a, b = P(u0, v0, 0), P(u1, v1, 0)
		local mid = (a + b) / 2
		Util.solid(f, V3(math.abs(b.X - a.X) + 1, 1, math.abs(b.Z - a.Z) + 1), CFrame.new(mid + V3(0, base + 24.5, 0)), C(40, 42, 48), M.Metal)
		Util.solid(f, V3(math.abs(b.X - a.X), 1, math.abs(b.Z - a.Z)), CFrame.new(mid + V3(0, base - 0.5, 0)), C(200, 196, 188), M.SmoothPlastic)
	end
	return f
end

return Exterior
