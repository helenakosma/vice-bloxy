-- Employers, career ladders, job listings and interview questions. Data only:
-- the server (Services/Employment, Hiring, Work) and the phone both read it.
-- Wages come from Shared/Economy.lua (by career track and level).
local Jobs = {}

-- Career ladders: titles by level. Pay per in-game hour is Economy.Wages[track][level].
Jobs.TRACKS = {
	cafe = { industry = "food", wage = "food", titles = { "Barista", "Senior Barista", "Shift Supervisor", "Assistant Manager", "Café Manager" } },
	retail = { industry = "retail", wage = "retail", titles = { "Sales Associate", "Senior Associate", "Department Supervisor", "Assistant Store Manager", "Store Manager", "District Manager" } },
	courier = { industry = "delivery", wage = nil, titles = { "Courier", "Senior Courier", "Lead Courier" } },
}

Jobs.INDUSTRIES = {
	food = "Food & hospitality",
	retail = "Retail",
	delivery = "Delivery",
	police = "Police",
	corporate = "Corporate",
	entertainment = "Entertainment",
}

-- Hiring weights (they add up to 1). Degree counts from Milestone 3.
local DEFAULT_WEIGHTS = { degree = 0.25, experience = 0.25, skills = 0.2, previous = 0.15, suitability = 0.15 }

Jobs.EMPLOYERS = {
	grind = {
		name = "Grind Coffee",
		industry = "food",
		track = "cafe",
		workplace = "GRIND_EATON",
		where = "Eaton Centre food court, Yonge & Dundas",
		hours = { 6, 24 }, -- open (in-game clock)
		weights = { degree = 0.05, experience = 0.35, skills = 0.25, previous = 0.15, suitability = 0.2 },
		about = "A busy espresso bar in the Eaton Centre food court. Fast, friendly, caffeinated.",
	},
	threads = {
		name = "Metro Threads",
		industry = "retail",
		track = "retail",
		workplace = "THREADS_EATON",
		where = "Eaton Centre, ground floor",
		hours = { 8, 23 },
		weights = { degree = 0.05, experience = 0.35, skills = 0.25, previous = 0.15, suitability = 0.2 },
		about = "Streetwear and basics. Keep the racks full, the tables folded and the line moving.",
	},
	quickdrop = {
		name = "Quickdrop",
		industry = "delivery",
		track = "courier",
		workplace = nil, -- deliveries start from anywhere
		where = "Anywhere in the city",
		hours = { 0, 24 },
		weights = DEFAULT_WEIGHTS,
		about = "On-demand delivery from shops and restaurants across the city. Paid per trip.",
	},
}

-- Listings on the job market. level = the career level you're hired at.
-- needs.shifts = completed shifts in this industry; needs.degree = a degree id (Milestone 3).
Jobs.LISTINGS = {
	{ id = "grind_barista_pt", employer = "grind", level = 1, type = "part", needs = { shifts = 0 },
		description = "Make espresso drinks and serve customers at the counter. No experience needed; we train you on the bar." },
	{ id = "grind_barista_ft", employer = "grind", level = 1, type = "full", needs = { shifts = 0 },
		description = "Full shifts on the espresso bar: take orders, pull shots, steam milk, hand off. No experience needed." },
	{ id = "grind_supervisor", employer = "grind", level = 3, type = "full", needs = { shifts = 8 },
		description = "Run the bar during busy hours and keep orders moving. Needs café or restaurant experience." },
	{ id = "grind_assistant", employer = "grind", level = 4, type = "full", needs = { shifts = 16 },
		description = "Help manage the café: staffing, quality and the morning rush. Needs solid food-service experience." },
	{ id = "threads_associate_pt", employer = "threads", level = 1, type = "part", needs = { shifts = 0 },
		description = "Help customers, ring them up and keep the floor tidy. No experience needed." },
	{ id = "threads_associate_ft", employer = "threads", level = 1, type = "full", needs = { shifts = 0 },
		description = "Full shifts on the sales floor: checkout, restocking from the stockroom and folding displays." },
	{ id = "threads_supervisor", employer = "threads", level = 3, type = "full", needs = { shifts = 8 },
		description = "Lead the floor: stock levels, displays and the checkout line. Needs retail experience." },
	{ id = "threads_manager", employer = "threads", level = 5, type = "full", needs = { shifts = 20 },
		description = "Run the store. Needs a strong retail track record." },
	{ id = "quickdrop_courier", employer = "quickdrop", level = 1, type = "gig", needs = { shifts = 0 },
		description = "Pick up orders from shops and restaurants and drop them off across the city. Walk, take transit or drive. Paid per delivery." },
}

-- Interview questions by industry: pick the best answer. Each option is worth 0, 0.5 or 1.
Jobs.INTERVIEWS = {
	food = {
		{ q = "A customer says their latte is wrong. What do you do?",
			a = { { "Remake it right away and apologise", 1 }, { "Tell them it's how we make it", 0 }, { "Offer a discount on their next visit", 0.5 } } },
		{ q = "Three orders come in at once and you're alone on the bar.",
			a = { { "Work through them in order and keep customers updated", 1 }, { "Make the easiest one first", 0.5 }, { "Ask them all to wait without saying how long", 0 } } },
		{ q = "Your shift ends but the next barista is late.",
			a = { { "Leave on time, it's not your problem", 0 }, { "Let your supervisor know and help until they arrive if you can", 1 }, { "Close the bar", 0 } } },
	},
	retail = {
		{ q = "A customer can't find their size on the rack.",
			a = { { "Check the stockroom and offer to hold it for them", 1 }, { "Tell them it's sold out", 0 }, { "Point them to a similar item", 0.5 } } },
		{ q = "The checkout line is long and the racks are messy.",
			a = { { "Fold displays first", 0 }, { "Open the till and serve the line, then tidy", 1 }, { "Do a bit of both at random", 0.5 } } },
		{ q = "You see a coworker give a friend a discount they shouldn't get.",
			a = { { "Ignore it", 0 }, { "Talk to them and let a manager know if it continues", 1 }, { "Announce it to the whole store", 0 } } },
	},
	delivery = {
		{ q = "The drop-off address is hard to find.",
			a = { { "Leave the order on the nearest corner", 0 }, { "Check the map and message the customer", 1 }, { "Cancel the delivery", 0 } } },
		{ q = "You're running late on a delivery.",
			a = { { "Speed through red lights", 0 }, { "Let the customer know and keep driving safely", 1 }, { "Take a break first", 0 } } },
		{ q = "The restaurant hands you the wrong order.",
			a = { { "Check the receipt before you leave", 1 }, { "Deliver it anyway", 0 }, { "Eat it", 0 } } },
	},
}

function Jobs.listing(id)
	for _, l in ipairs(Jobs.LISTINGS) do
		if l.id == id then
			return l
		end
	end
	return nil
end

-- Title and hourly wage for a career level (couriers are paid per trip).
function Jobs.titleFor(employerId, level)
	local track = Jobs.TRACKS[Jobs.EMPLOYERS[employerId].track]
	return track.titles[math.clamp(level, 1, #track.titles)]
end

function Jobs.wageFor(employerId, level, wages)
	local track = Jobs.TRACKS[Jobs.EMPLOYERS[employerId].track]
	if not track.wage then
		return nil
	end
	local ladder = wages[track.wage]
	return ladder[math.clamp(level, 1, #ladder)]
end

function Jobs.maxLevel(employerId)
	return #Jobs.TRACKS[Jobs.EMPLOYERS[employerId].track].titles
end

return Jobs
