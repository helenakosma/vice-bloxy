-- Toronto master layout (Phase 5): where everything in Toronto goes, built on
-- Yonge Street and TTC Line 1. Every other Toronto module reads from here.
--
-- Scale convention
--   * Anything at human level is about 0.3 m per stud (people, streets, buildings,
--     cars; storeys are 10 studs).
--   * Distances between places are compressed by zone, so the line stays rideable:
--       downtown (Union..Bloor)   700 studs per real km
--       midtown  (Bloor..Eglinton) 450 studs per km
--       north    (Eglinton..Finch) 350 studs per km
--     Station positions come from OpenStreetMap coordinates measured along Yonge.
--   * North is -Z. Yonge Street runs straight north-south at x = YONGE_X, with
--     Line 1 directly underneath. Union sits on the harbour at z = -1000.
local T = {}

T.YONGE_X = 100
T.BOUNDS = { minX = -1150, maxX = 1150, minZ = -8300, maxZ = -800 }
T.WATERFRONT_Z = -836 -- Queens Quay, along the harbour
T.FRONT_Z = -1040 -- Front St (Union Station's street)

-- Line 1, north to south (z from OpenStreetMap, scaled by zone).
-- tier: "major" (two entrances), "standard", "minor" (one entrance).
local C = Color3.fromRGB
T.STATIONS = {
	{ name = "FINCH", z = -7864, tier = "major", tile = C(210, 196, 120) },
	{ name = "NORTH YORK CENTRE", z = -7364, tier = "major", tile = C(170, 190, 210) },
	{ name = "SHEPPARD-YONGE", z = -7078, tier = "major", tile = C(220, 180, 70) },
	{ name = "YORK MILLS", z = -6387, tier = "standard", tile = C(150, 180, 140) },
	{ name = "LAWRENCE", z = -5691, tier = "standard", tile = C(200, 150, 120) },
	{ name = "EGLINTON", z = -4921, tier = "major", tile = C(120, 140, 200) },
	{ name = "DAVISVILLE", z = -4477, tier = "minor", tile = C(200, 200, 190) },
	{ name = "ST CLAIR", z = -3960, tier = "standard", tile = C(110, 170, 160) },
	{ name = "SUMMERHILL", z = -3626, tier = "minor", tile = C(190, 170, 140) },
	{ name = "ROSEDALE", z = -3354, tier = "minor", tile = C(150, 170, 120) },
	{ name = "BLOOR-YONGE", z = -3054, tier = "major", tile = C(230, 210, 120) },
	{ name = "WELLESLEY", z = -2630, tier = "standard", tile = C(210, 140, 160) },
	{ name = "COLLEGE", z = -2247, tier = "standard", tile = C(150, 120, 170) },
	{ name = "DUNDAS", z = -1911, tier = "major", tile = C(230, 150, 70) },
	{ name = "QUEEN", z = -1616, tier = "major", tile = C(120, 160, 200) },
	{ name = "KING", z = -1293, tier = "major", tile = C(180, 120, 110) },
	{ name = "UNION", z = -1000, tier = "major", tile = C(200, 120, 90) },
}

-- Zone boundaries: halfway between the stations either side.
T.MIDTOWN_FROM_Z = -5306 -- Lawrence / Eglinton
T.DOWNTOWN_FROM_Z = -3204 -- Rosedale / Bloor

function T.zoneAt(z)
	if z > T.DOWNTOWN_FROM_Z then
		return "downtown"
	elseif z > T.MIDTOWN_FROM_Z then
		return "midtown"
	end
	return "north"
end

---------------------------------------------------------------------------
-- Streets
---------------------------------------------------------------------------
-- East-west streets crossing Yonge: { name, z, kind, x0, x1 }.
local W, E = T.BOUNDS.minX + 40, T.BOUNDS.maxX - 40
T.EAST_WEST = {
	{ "Steeles Ave", -8240, "arterial", W, E },
	{ "Finch Ave", -7864, "arterial", W, E },
	{ "Park Home Ave", -7364, "street", -650, 850 },
	{ "Sheppard Ave", -7078, "arterial", W, E },
	{ "York Mills Rd", -6387, "arterial", W, E },
	{ "Lawrence Ave", -5691, "arterial", W, E },
	{ "Eglinton Ave", -4921, "arterial", W, E },
	{ "Davisville Ave", -4477, "street", -650, 850 },
	{ "St Clair Ave", -3960, "arterial", W, E },
	{ "Summerhill Ave", -3626, "street", -650, 850 },
	{ "Crescent Rd", -3354, "street", -650, 850 },
	{ "Bloor St", -3054, "arterial", W, E },
	{ "Wellesley St", -2630, "street", -650, 1060 },
	{ "College St", -2247, "arterial", W, E },
	{ "Gerrard St", -2080, "street", -650, 1060 },
	{ "Dundas St", -1911, "arterial", W, E },
	{ "Shuter St", -1760, "street", 140, 1060 }, -- starts at Yonge, east only
	{ "Queen St", -1616, "arterial", W, E },
	{ "Richmond St", -1508, "street", -650, 1060 },
	{ "Adelaide St", -1400, "street", -650, 1060 },
	{ "King St", -1293, "arterial", W, E },
	{ "Wellington St", -1165, "street", -650, 1060 },
	{ "Front St", T.FRONT_Z, "arterial", W, E },
	{ "Queens Quay", T.WATERFRONT_Z, "arterial", W, E },
}

-- North-south streets: { name, kind, points = { {x, z}, ... } } (south to north).
T.NORTH_SOUTH = {
	{ "Yonge St", "yonge", { { T.YONGE_X, T.WATERFRONT_Z }, { T.YONGE_X, T.MIDTOWN_FROM_Z } } },
	{ "Yonge St North", "yongeNorth", { { T.YONGE_X, T.MIDTOWN_FROM_Z }, { T.YONGE_X, -8240 } } },
	{ "University Ave", "arterial", { { -404, T.FRONT_Z }, { -404, -3054 } } },
	{ "Avenue Rd", "avenue", { { -404, -3054 }, { -185, -3960 }, { -170, -4921 }, { -200, -5691 }, { -230, -6387 } } },
	{ "Bay St", "avenue", { { -131, T.WATERFRONT_Z }, { -131, -3054 } } },
	{ "Church St", "street", { { 303, T.WATERFRONT_Z }, { 303, -3054 } } },
	{ "Jarvis St", "street", { { 464, T.WATERFRONT_Z }, { 464, -3054 } } },
	{ "Mount Pleasant Rd", "avenue", { { 464, -3054 }, { 430, -3960 }, { 420, -4921 }, { 420, -5691 } } },
	{ "Sherbourne St", "street", { { 650, T.WATERFRONT_Z }, { 650, -3054 } } },
	{ "Parliament St", "street", { { 900, T.WATERFRONT_Z }, { 900, -3054 } } },
	{ "Bathurst St", "arterial", { { -650, T.FRONT_Z }, { -650, -8240 } } },
	{ "Bayview Ave", "arterial", { { 850, -3354 }, { 850, -8240 } } },
	{ "Beecroft Rd", "street", { { -160, -7078 }, { -160, -7864 } } },
	{ "Doris Ave", "street", { { 300, -7078 }, { 300, -7864 } } },
	{ "West Edge Rd", "arterial", { { T.BOUNDS.minX + 50, T.WATERFRONT_Z }, { T.BOUNDS.minX + 50, -8240 } } },
	{ "East Edge Rd", "arterial", { { T.BOUNDS.maxX - 50, T.WATERFRONT_Z }, { T.BOUNDS.maxX - 50, -8240 } } },
}

-- Highway 401 crosses between Sheppard-Yonge and York Mills (on a deck); the
-- expressway (Allen Road / Spadina corridor) joins it from the south.
T.HWY401_Z = -6900

---------------------------------------------------------------------------
-- Landmark sites (centres are Vector2 x, z; rects are min/max)
---------------------------------------------------------------------------
T.NEEDLE = Vector2.new(-560, -935) -- CN Tower, between Front and the waterfront
T.DOME = Vector2.new(-680, -938) -- Rogers Centre beside it
T.UNION = Vector2.new(-260, -935) -- Union Station on Front St, between Bay and University
T.FINANCIAL = Vector2.new(-131, -1293) -- King & Bay
T.CITY_HALL = { minX = -352, maxX = -181, minZ = -1860, maxZ = -1668 } -- Queen & Bay, north-west
T.EATON = { minX = -88, maxX = 57, minZ = -1866, maxZ = -1661 } -- Yonge, Queen to Dundas, back to Bay
T.SANKOFA = { minX = 142, maxX = 258, minZ = -1866, maxZ = -1787 } -- south-east corner of Yonge & Dundas
-- The billboard buildings round Yonge & Dundas (with the Eaton Centre's corner).
T.DUNDAS_NE = { minX = 144, maxX = 262, minZ = -2052, maxZ = -1957 } -- "10 Dundas East" screens
T.DUNDAS_NW = { minX = -88, maxX = 57, minZ = -2052, maxZ = -1957 } -- screens facing the square
-- Toronto Metropolitan University: the glass learning centre on Yonge, the Kerr
-- Hall quad east of Church, and a tower south of Gerrard.
T.TMU_SLC = { minX = 144, maxX = 262, minZ = -2200, maxZ = -2108 }
T.TMU_KERR = { minX = 330, maxX = 436, minZ = -2200, maxZ = -2108 }
T.TMU_SOUTH = { minX = 330, maxX = 436, minZ = -2052, maxZ = -1957 }
-- University of Toronto, between Bathurst and University Ave, College to Bloor:
-- King's College Circle, University College and Convocation Hall to the south,
-- Hart House and Robarts Library to the north.
T.UOFT_SOUTH = { minX = -604, maxX = -450, minZ = -2600, maxZ = -2295 }
T.UOFT_NORTH = { minX = -604, maxX = -450, minZ = -3006, maxZ = -2660 }
T.ROM = Vector2.new(-480, -3150) -- Bloor & Avenue Rd
T.YONGE_EGLINTON_CENTRE = Vector2.new(258, -5040) -- walkable mall, north-east of Yonge & Eglinton
T.MEL_LASTMAN = { minX = -130, maxX = 38, minZ = -7335, maxZ = -7125 } -- civic square, west of Yonge
T.NY_TOWERS = { Vector2.new(360, -7240), Vector2.new(420, -7180) } -- twisting condo pair
T.MOUNT_PLEASANT_CEMETERY = { minX = 150, maxX = 800, minZ = -4430, maxZ = -4010 }

---------------------------------------------------------------------------
-- Building height by place: high at King, Bloor, Eglinton and North York Centre,
-- low in York Mills, Lawrence, Summerhill and Rosedale; falls off away from Yonge.
---------------------------------------------------------------------------
local PROFILE = {
	{ -8300, 0.9 }, { -7864, 1.6 }, { -7364, 2.1 }, { -7078, 1.8 }, { -6800, 0.7 },
	{ -6387, 0.5 }, { -6050, 0.3 }, { -5691, 0.5 }, { -5300, 0.7 }, { -4921, 1.8 },
	{ -4477, 0.9 }, { -3960, 1.0 }, { -3626, 0.35 }, { -3354, 0.35 }, { -3054, 2.0 },
	{ -2630, 1.5 }, { -2247, 1.4 }, { -1911, 1.4 }, { -1616, 1.6 }, { -1293, 2.4 },
	{ -1040, 2.0 }, { -800, 1.4 },
}

function T.heightFactor(p)
	local z = p.Y
	local f = PROFILE[1][2]
	for i = 1, #PROFILE - 1 do
		local a, b = PROFILE[i], PROFILE[i + 1]
		if z >= a[1] and z <= b[1] then
			local t = (z - a[1]) / (b[1] - a[1])
			t = t * t * (3 - 2 * t)
			f = a[2] + (b[2] - a[2]) * t
			break
		end
	end
	if z > PROFILE[#PROFILE][1] then
		f = PROFILE[#PROFILE][2]
	end
	local off = math.min(1, math.abs(p.X - T.YONGE_X) / 900)
	return f * (1 - 0.55 * off)
end

-- True near a station on Yonge (where the street gets its detailed buildings).
function T.nearStation(p, radius)
	if math.abs(p.X - T.YONGE_X) > (radius or 160) + 60 then
		return false
	end
	for _, s in ipairs(T.STATIONS) do
		if math.abs(p.Y - s.z) < (radius or 160) then
			return true
		end
	end
	return false
end

return T
