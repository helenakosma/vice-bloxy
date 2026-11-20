-- Where everything sits in the world (studs; X west->east, north is -Z).
-- Districts and highways read these so their roads meet up.
local TorontoLayout = require(script.Parent.TorontoLayout)

local Layout = {}

Layout.CHANNEL = { minZ = -800, maxZ = -730 } -- the harbour between downtown and Toronto

Layout.TORONTO = TorontoLayout.BOUNDS -- Toronto: see TorontoLayout.lua for everything inside
Layout.SUBURBS = { minX = -1800, maxX = -700, minZ = -730, maxZ = 1200 }
Layout.INDUSTRIAL = { minX = -700, maxX = 594, minZ = 700, maxZ = 1200 }
Layout.VICE_BEACH = { minX = 1100, maxX = 2300, minZ = -300, maxZ = 1300 }

---------------------------------------------------------------------------
-- Surface roads that several districts need to agree on
---------------------------------------------------------------------------
-- Toronto landmarks the other modules need (TorontoLayout has the full list).
Layout.FINANCIAL = TorontoLayout.FINANCIAL -- bank towers cluster around King & Bay

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

-- Expressway: from Highway 401 (on its deck), down to street level as the Allen
-- Road / Spadina corridor through Toronto -> rises -> over the harbour -> down the
-- west side of downtown -> along the industrial south edge -> the bridge.
local H401 = TorontoLayout.HWY401_Z
Layout.EXPRESSWAY = {
	Vector3.new(EX, 26, H401),
	Vector3.new(EX, 26, H401 + 90),
	Vector3.new(EX, S, H401 + 380),
	Vector3.new(EX, S, -1460),
	Vector3.new(EX, 26, -1180),
	Vector3.new(EX, 26, 960),
	Vector3.new(EX + 12, 26, 1040),
	Vector3.new(EX + 48, 26, 1082),
	Vector3.new(EX + 110, 26, 1100),
	Vector3.new(560, 26, 1100),
}

-- Highway 401: across North York on a deck, down to street level at Toronto's
-- west and east edge roads.
local TX0, TX1 = TorontoLayout.BOUNDS.minX + 50, TorontoLayout.BOUNDS.maxX - 50
Layout.HWY401_WIDTH = 120
Layout.HWY401 = {
	Vector3.new(TX0, S, H401),
	Vector3.new(TX0 + 20, S, H401),
	Vector3.new(TX0 + 240, 26, H401), -- up to full height before the expressway joins
	Vector3.new(TX1 - 240, 26, H401),
	Vector3.new(TX1 - 20, S, H401),
	Vector3.new(TX1, S, H401),
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
		{ at = Vector2.new(EX, H401 + 700), text = "ALLEN RD  ·  DOWNTOWN" },
		{ at = Vector2.new(EX, TorontoLayout.shiftZ(-3054)), text = "BLOOR ST  ·  1 KM" },
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
	Highway401 = {
		{ at = Vector2.new(-200, H401), text = "401  EXPRESS  ·  YONGE ST" },
		{ at = Vector2.new(500, H401), text = "401  ·  BAYVIEW AVE" },
	},
	SuspensionBridge = {
		{ at = Vector2.new(1100, 1100), text = "WELCOME TO VICE BEACH" },
	},
}

return Layout
