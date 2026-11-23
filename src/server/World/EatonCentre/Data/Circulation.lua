-- Escalator banks, read off the leasing plans (plan feet: u north of the Queen St
-- wall, v west of the Yonge St wall). Each bank sits in a floor opening of the
-- upper level, as on the plans. Position, direction and length come from the
-- escalator outlines on the plan (pairs of parallel handrail lines, 4-8 ft apart)
-- found by tools/eaton (see the notes); which level each bank serves follows from
-- the sheet it is drawn on. Every bank is built as an up/down pair.
--
--   from, to   level numbers (0 = concourse, 1-3)
--   u, v       centre of the bank
--   axis       {du, dv} direction of travel (either way along it)
--   length     plan length of the escalator outline (ft)
return {
	-- Level 1 -> Level 2 (drawn on the Level 2 sheet)
	{ from = 1, to = 2, u = 148, v = 141, axis = { 0.71, 0.71 }, length = 42, note = "Queen court: diagonal pair, outlines 40-44 ft (L2 sheet)" },
	{ from = 1, to = 2, u = 492, v = 138, axis = { 1, 0 }, length = 40, note = "Centre court: outline 40 ft along the galleria (L2 sheet)" },
	{ from = 1, to = 2, u = 792, v = 172, axis = { 1, 0 }, length = 39, note = "North court: outline 39 ft (L2 sheet)" },
	{ from = 1, to = 2, u = 1334, v = 62, axis = { 0.86, -0.51 }, length = 37, note = "Yonge & Dundas corner: diagonal, outlines 29-37 ft (L2 sheet)" },
	-- Level 2 -> Level 3 (drawn on the Level 3 sheet)
	{ from = 2, to = 3, u = 147, v = 166, axis = { 1, 0 }, length = 34, note = "Queen court: marked UP / DN on the L3 sheet" },
	{ from = 2, to = 3, u = 497, v = 185, axis = { 1, 0 }, length = 37, note = "Centre court: outline 37 ft (L3 sheet)" },
	{ from = 2, to = 3, u = 800, v = 136, axis = { 1, 0 }, length = 40, note = "North court: outline 40 ft (L3 sheet)" },
	{ from = 2, to = 3, u = 1317, v = 52, axis = { 0.85, -0.52 }, length = 37, note = "Yonge & Dundas corner: diagonal, outline 37 ft (L3 sheet)" },
	-- Concourse -> Level 1 (drawn in the Level 1 opening beside the Gap)
	{ from = 0, to = 1, u = 817, v = 118, axis = { 0.71, -0.71 }, length = 24, note = "Opening by the Gap: diagonal outline 22-25 ft (L1 sheet)" },
}
