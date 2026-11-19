-- Where everything sits in the world (studs; X west->east, north is -Z).
-- Districts and highways read these so their roads meet up.
local Layout = {}

Layout.CHANNEL = { minZ = -800, maxZ = -730 } -- water between downtown and North York

Layout.NORTH_YORK = { minX = -1200, maxX = 700, minZ = -2000, maxZ = -800 }
Layout.SUBURBS = { minX = -1800, maxX = -700, minZ = -730, maxZ = 1200 }
Layout.INDUSTRIAL = { minX = -700, maxX = 594, minZ = 700, maxZ = 1200 }
Layout.VICE_BEACH = { minX = 1100, maxX = 2300, minZ = -300, maxZ = 1300 }

---------------------------------------------------------------------------
-- Surface roads that several districts need to agree on
---------------------------------------------------------------------------
-- North York: perimeter roads, cross arterials and side streets. The expressway is
-- at street level north of -1460, so -1500 meets it at a junction; -1020 passes under.
Layout.NY_NORTH_Z = -1960
Layout.NY_SOUTH_Z = -836
Layout.NY_WEST_X = -1150
Layout.NY_EAST_X = 640
Layout.NY_CROSS_Z = { -1020, -1500 }
Layout.NY_SIDE_STREETS_Z = { -1240, -1740 }
Layout.NY_SIDE_STREETS_X = { -560, 220 }
Layout.NY_BRIDGE_AVENUES = { -360, 20, 400 } -- downtown avenues that cross the channel
Layout.NEEDLE = Vector2.new(-170, -930) -- CN Tower-inspired landmark
Layout.DOME = Vector2.new(533, -1140) -- stadium
Layout.MALL = Vector2.new(-985, -1370) -- shopping centre
Layout.NY_PARK = { minX = -1085, maxX = -865, minZ = -1700, maxZ = -1550 }

-- Vice Causeway: a street-level bridge from downtown's waterfront drive straight
-- across the river to Vice Beach (passes under the Harbor Freeway).
Layout.CAUSEWAY_Z = 150

-- Downtown's north-shore road runs underneath the Harbor Freeway.
Layout.DOWNTOWN_SHORE_Z = -712

-- Industrial east-west roads.
Layout.INDUSTRIAL_NORTH_Z = 860
Layout.INDUSTRIAL_MAIN_Z = 1030
Layout.INDUSTRIAL_SOUTH_Z = 1172
Layout.INDUSTRIAL_EAST_X = 560

-- Suburbs: north shore road (where the Harbor Freeway comes down) and three
-- winding north-south collectors.
Layout.SUBURB_SHORE_Z = -700
Layout.SUBURB_COLLECTORS = { -1250, -1500, -1720 }
function Layout.suburbCollectorX(i, z)
	return Layout.SUBURB_COLLECTORS[i] + 40 * math.sin(z / 260 + i * 1.7)
end

---------------------------------------------------------------------------
-- Highways (Y = deck height). Control points are smoothed into curves.
-- Lanes are 15 studs: the expressway and bridge have 3 each way, the Harbor
-- Freeway 2 each way, ramps 1 each way.
---------------------------------------------------------------------------
local S = 0.35 -- street level
Layout.STREET = S
Layout.EXPRESSWAY_X = -800
Layout.EXPRESSWAY_WIDTH = 100
Layout.HARBOR_WIDTH = 72
Layout.RAMP_WIDTH = 38
local EX = Layout.EXPRESSWAY_X
local EAST_LANES = EX + 25 -- centre of the expressway's east-side lanes

-- Expressway: North York (street level) -> rises -> over the channel -> down the
-- west side of downtown -> along the industrial south edge -> the bridge.
Layout.EXPRESSWAY = {
	Vector3.new(EX, S, Layout.NY_NORTH_Z),
	Vector3.new(EX, S, -1460),
	Vector3.new(EX, 26, -1180),
	Vector3.new(EX, 26, 960),
	Vector3.new(EX + 12, 26, 1040),
	Vector3.new(EX + 48, 26, 1082),
	Vector3.new(EX + 110, 26, 1100),
	Vector3.new(560, 26, 1100),
}

-- Suspension bridge to Vice Beach (continues the expressway).
Layout.BRIDGE = {
	Vector3.new(560, 26, 1100),
	Vector3.new(1000, 26, 1100),
	Vector3.new(1240, S, 1100),
	Vector3.new(1262, S, 1100),
}
Layout.BRIDGE_TOWERS_X = { 820, 980 }

-- Harbor Freeway: comes up from the suburbs, flies over the expressway, runs along
-- downtown's north shore and down the east river, then merges onto the bridge.
Layout.HARBOR = {
	Vector3.new(-1310, S, -700),
	Vector3.new(-1260, S, -702),
	Vector3.new(-870, 44, -739),
	Vector3.new(-705, 44, -745),
	Vector3.new(-570, 30, -745),
	Vector3.new(480, 30, -745),
	Vector3.new(545, 30, -735),
	Vector3.new(600, 30, -700),
	Vector3.new(628, 30, -640),
	Vector3.new(637, 30, -560),
	Vector3.new(637, 30, 760),
	Vector3.new(637, 26, 940),
	Vector3.new(645, 26, 1010),
	Vector3.new(672, 26, 1060),
	Vector3.new(715, 26, 1084),
	Vector3.new(760, 26, 1090),
}

-- Connector ramps (two-way). Each starts on one freeway's outer lanes and merges
-- onto another; barriers are left out wherever two decks overlap.
Layout.RAMPS = {
	-- Expressway (North York side) <-> Harbor Freeway, north-east of the stack.
	NorthConnector = {
		Vector3.new(EAST_LANES, 26, -1040),
		Vector3.new(EAST_LANES, 26, -980),
		Vector3.new(EAST_LANES + 20, 27, -920),
		Vector3.new(-715, 29, -865),
		Vector3.new(-660, 30, -825),
		Vector3.new(-600, 30, -795),
		Vector3.new(-540, 30, -770),
		Vector3.new(-470, 30, -763),
	},
	-- Expressway (downtown side) <-> Harbor Freeway, south-east of the stack.
	SouthConnector = {
		Vector3.new(EAST_LANES, 26, -470),
		Vector3.new(EAST_LANES, 26, -520),
		Vector3.new(EAST_LANES + 15, 27, -580),
		Vector3.new(-735, 28, -630),
		Vector3.new(-695, 29, -668),
		Vector3.new(-640, 30, -684),
		Vector3.new(-570, 30, -705),
		Vector3.new(-520, 30, -727),
		Vector3.new(-470, 30, -727),
	},
	-- Expressway <-> industrial main road: peels off north at full height, crosses
	-- over the main road, then comes down beside it and joins at street level.
	Industrial = {
		Vector3.new(40, 26, 1072),
		Vector3.new(110, 26, 1068),
		Vector3.new(170, 26, 1035),
		Vector3.new(230, 25, 1000),
		Vector3.new(330, 12, 990),
		Vector3.new(430, S, 992),
		Vector3.new(480, S, 1010),
		Vector3.new(505, S, 1030),
	},
}

-- Texas-style frontage road: leaves the expressway at full height, moves clear of
-- it, comes down beside downtown's west edge (meeting its cross streets at street
-- level between zA and zB) and climbs back up. lenA/lenB are the ramp lengths,
-- chosen so no street passes under a ramp while it is low.
Layout.FRONTAGE_X = -728
function Layout.frontage(zA, zB, lenA, lenB)
	local FX = Layout.FRONTAGE_X
	return {
		Vector3.new(EAST_LANES, 26, zA - lenA - 180),
		Vector3.new(EAST_LANES, 26, zA - lenA - 130),
		Vector3.new(FX, 26, zA - lenA),
		Vector3.new(FX, S, zA),
		Vector3.new(FX, S, zB),
		Vector3.new(FX, 26, zB + lenB),
		Vector3.new(EAST_LANES, 26, zB + lenB + 130),
		Vector3.new(EAST_LANES, 26, zB + lenB + 180),
	}
end

-- Overhead gantry signs: placed at the highway sample nearest to `at`.
Layout.SIGNS = {
	Expressway = {
		{ at = Vector2.new(EX, -1300), text = "DOWNTOWN  ·  HARBOR FWY" },
		{ at = Vector2.new(EX, -200), text = "DOWNTOWN  EXIT" },
		{ at = Vector2.new(EX, 760), text = "INDUSTRIAL  ·  VICE BEACH" },
		{ at = Vector2.new(-100, 1100), text = "VICE BEACH  ·  BRIDGE" },
	},
	HarborFreeway = {
		{ at = Vector2.new(-1000, -725), text = "DOWNTOWN  ·  EXPRESSWAY" },
		{ at = Vector2.new(0, -745), text = "HARBOR FWY  EAST" },
		{ at = Vector2.new(637, 300), text = "VICE BEACH" },
	},
	SuspensionBridge = {
		{ at = Vector2.new(1100, 1100), text = "WELCOME TO VICE BEACH" },
	},
}

return Layout
