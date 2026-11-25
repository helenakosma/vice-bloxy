-- Places gameplay refers to, by stable id. Data only: services and the phone use
-- these ids (a job's workplace, where new players arrive, where to navigate) and
-- never coordinates. The server's Locations service turns an id into a position.
--
-- Where a place is, in order of preference:
--   1. An anchor the map team tagged in the world: a part with the CollectionService
--      tag "Location" and a "LocationId" attribute equal to the id (optional
--      "Radius" attribute). This always wins, so the map can move a place without
--      any gameplay change.
--   2. Otherwise `source` below:
--        workplace = "<id>"  a workplace registered by World/Workplaces
--        landmark  = "<KEY>" a named point in TorontoLayout (a Vector2), with the
--                            way its front faces and how far in front to stand
--        station   = "<NAME>" a Line 1 station (TorontoLayout.STATIONS), at street
--                            level on Yonge St
--        rect      = "<KEY>" a named area in TorontoLayout ({ minX, maxX, minZ,
--                            maxZ }): its centre, moved toward `facing` to `inset`
--                            studs from that edge
-- Every Line 1 station is also available as "station.<name>" (lower case) without
-- being listed here.
local Locations = {}

-- Where new players arrive. Decided 2026-11-25 as Union Station; moved to Yonge &
-- Dundas (Sankofa Square, facing the Eaton Centre) for now at the user's request.
Locations.ARRIVAL = "yonge.dundas"

Locations.list = {
	["union.station"] = {
		name = "Union Station",
		kind = "station",
		area = "Front St",
		source = { landmark = "UNION", facing = { 0, -1 }, forward = 28 },
	},
	["yonge.dundas"] = {
		name = "Yonge & Dundas",
		kind = "plaza",
		area = "Sankofa Square",
		source = { rect = "SANKOFA", facing = { -1, 0 }, inset = 18 },
	},
	["eaton.grind"] = {
		name = "Grind Coffee",
		kind = "workplace",
		area = "Eaton Centre",
		source = { workplace = "GRIND_EATON" },
	},
	["eaton.threads"] = {
		name = "Metro Threads",
		kind = "workplace",
		area = "Eaton Centre",
		source = { workplace = "THREADS_EATON" },
	},
}

return Locations
