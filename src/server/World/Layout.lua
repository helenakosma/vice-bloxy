-- Where everything sits in the world (studs; X west->east, north is -Z).
-- Districts and highways read these so their roads meet up.
local Layout = {}

Layout.CHANNEL = { minZ = -800, maxZ = -730 } -- water between downtown and North York

Layout.NORTH_YORK = { minX = -1200, maxX = 700, minZ = -2000, maxZ = -800 }
Layout.SUBURBS = { minX = -1800, maxX = -700, minZ = -730, maxZ = 1200 }
Layout.INDUSTRIAL = { minX = -700, maxX = 594, minZ = 700, maxZ = 1200 }
Layout.VICE_BEACH = { minX = 1100, maxX = 2300, minZ = -300, maxZ = 1300 }

-- North York cross arterials. The expressway is at street level north of -1460,
-- so -1500 and -1800 meet it at junctions; -950 passes underneath it.
Layout.NY_CROSS_Z = { -950, -1500, -1800 }
-- Downtown avenues (by approximate x) that continue north over channel bridges.
Layout.NY_BRIDGE_AVENUES = { -360, 20, 400 }

-- Industrial roads: the main east-west road, and where the bridge approach link meets it.
Layout.INDUSTRIAL_NORTH_Z = 860
Layout.INDUSTRIAL_MAIN_Z = 1040
Layout.BRIDGE_LINK_X = 500

-- Expressway: Y is the deck height. It is level with the street at both ends
-- (North York and the bridge approach) and elevated in between.
Layout.HIGHWAY_DECK = 26
Layout.STREET = 0.35
local H, S = Layout.HIGHWAY_DECK, Layout.STREET
Layout.EXPRESSWAY = {
	Vector3.new(-760, S, -1800),
	Vector3.new(-760, S, -1460),
	Vector3.new(-760, H, -1180),
	Vector3.new(-760, H, 960),
	Vector3.new(-745, H, 1035),
	Vector3.new(-705, H, 1078),
	Vector3.new(-640, H, 1100),
	Vector3.new(230, H, 1100),
	Vector3.new(470, S, 1100),
	Vector3.new(520, S, 1100),
}

-- Suspension bridge from the industrial waterfront to Vice Beach.
Layout.BRIDGE_DECK = 16
Layout.BRIDGE = {
	Vector3.new(520, S, 1100),
	Vector3.new(640, Layout.BRIDGE_DECK, 1100),
	Vector3.new(1060, Layout.BRIDGE_DECK, 1100),
	Vector3.new(1180, S, 1100),
}
Layout.BRIDGE_TOWERS_X = { 700, 1000 }

return Layout
