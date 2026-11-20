-- Every number the society's economy runs on, in one place. Balance the game here,
-- not in the services. Values are whole dollars (one currency, shown as $).
--
-- Time scale: one in-game hour is one real minute (the 24-minute day/night cycle),
-- so a full 8-hour shift is 8 real minutes. Weekly costs (rent) come due once per
-- in-game week of a player's own time online.
return {
	-- New players.
	StartingBalance = 500,

	-- Bank: how much history each player keeps, and how many transaction ids are
	-- remembered so a retried payment can't be applied twice.
	LedgerSize = 100,
	RememberTransactions = 60,

	-- Saving.
	SaveEverySeconds = 120,
	SessionLockSeconds = 300, -- a lock older than this is treated as abandoned

	-- Phone.
	InboxSize = 40, -- notifications kept
	BioMaxLength = 140,

	-- Requests from the phone: at most this many per window per player.
	RequestBurst = 25,
	RequestWindowSeconds = 5,

	-- Wages per in-game hour by career level (used from Milestone 2).
	Wages = {
		retail = { 18, 20, 24, 30, 36, 44 },
		food = { 19, 20, 22, 26, 32, 42 },
		police = { 24, 30, 36, 42, 48, 54, 58 },
		corporate = { 23, 28, 34, 40, 50, 60, 72, 85 },
		entertainment = { 18, 22, 28, 36, 45 },
	},
	ShiftHours = { full = 8, part = 4 },
	DeliveryPerTrip = { min = 18, max = 24 },

	-- Weekly rent by home type (Milestone 4).
	RentPerWeek = {
		dorm = 90,
		sharedRoom = 125,
		budgetStudio = 225,
		standard = 350,
		premium = 550,
		luxury = 875,
		penthouse = 1600,
	},
	RentGraceWeeks = 3,

	-- Education (Milestone 3).
	TuitionPerCourse = 120,
	CoursesPerDegree = 24,
}
