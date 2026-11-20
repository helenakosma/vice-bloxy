-- Jobs: the market, applications, hiring decisions, contracts, promotions and
-- employment history. The phone's Jobs app talks to this through the Router.
--
-- Application statuses: submitted -> review -> (interview ->) accepted (an offer)
-- / rejected; withdrawn; hired (offer accepted); expired (offer not taken up).
-- Decisions come from Services/Hiring and always say why.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Settings = Economy.Employment
local Jobs = require(ReplicatedStorage.Shared.Catalog.Jobs)
local PlayerData = require(script.Parent.PlayerData)
local Router = require(script.Parent.Router)
local Notify = require(script.Parent.Notify)
local Hiring = require(script.Parent.Hiring)

local Employment = {}

-- Set by Work (to end a shift when someone changes or quits a job).
Employment.onJobChanged = nil

local OPEN = { submitted = true, review = true, interview = true, accepted = true }

local function openCount(apps)
	local n = 0
	for _, a in pairs(apps) do
		if OPEN[a.status] then
			n += 1
		end
	end
	return n
end

local function currentSummary(data)
	local c = data.employment.current
	if not c then
		return nil
	end
	local employer = Jobs.EMPLOYERS[c.employer]
	local maxLevel = Jobs.maxLevel(c.employer)
	local need = Settings.PromotionShifts[math.clamp(c.level, 1, #Settings.PromotionShifts)]
	return {
		employer = c.employer,
		employerName = employer.name,
		industry = employer.industry,
		title = c.title,
		level = c.level,
		maxLevel = maxLevel,
		wage = c.wage,
		type = c.type,
		since = c.since,
		where = employer.where,
		hours = employer.hours,
		workplace = employer.workplace,
		shiftsAtLevel = c.shiftsAtLevel,
		shiftsNeeded = need,
		performance = c.perfCount > 0 and c.perfSum / c.perfCount or nil,
		performanceNeeded = Settings.PromotionPerformance,
		nextTitle = c.level < maxLevel and Jobs.titleFor(c.employer, c.level + 1) or nil,
		nextWage = c.level < maxLevel and Jobs.wageFor(c.employer, c.level + 1, Economy.Wages) or nil,
	}
end

local function hire(player, data, listing)
	local emp = data.employment
	local employer = Jobs.EMPLOYERS[listing.employer]
	if emp.current then
		table.insert(emp.history, { employer = emp.current.employer, title = emp.current.title, from = emp.current.since, to = os.time(), reason = "Left for " .. employer.name })
	end
	emp.current = {
		employer = listing.employer,
		listing = listing.id,
		level = listing.level,
		title = Jobs.titleFor(listing.employer, listing.level),
		wage = Jobs.wageFor(listing.employer, listing.level, Economy.Wages),
		type = listing.type,
		since = os.time(),
		shiftsAtLevel = 0,
		perfSum = 0,
		perfCount = 0,
	}
	if not data.achievements.firstJob then
		data.achievements.firstJob = os.time()
	end
	if Employment.onJobChanged then
		Employment.onJobChanged(player)
	end
end

-- Decide an application (after the review delay, or after the interview).
local function decide(player, data, app, interviewScore)
	local listing = Jobs.listing(app.listing)
	local employer = Jobs.EMPLOYERS[listing.employer]
	local report = Hiring.evaluate(data, listing, interviewScore)
	app.score, app.threshold, app.lines, app.tips = report.score, report.threshold, report.lines, report.tips
	if report.hardFail then
		app.status, app.reason = "rejected", report.hardFail
	elseif report.interview then
		app.status = "interview"
		app.reason = "The hiring manager would like to ask you a few questions."
		Notify.send(player, { title = employer.name .. ": interview", body = "Answer three quick questions in the Jobs app.", app = "jobs", category = "jobs" })
		return
	elseif report.pass then
		app.status = "accepted"
		app.offerExpires = os.time() + Settings.OfferValidSeconds
		app.reason = string.format("Offer: %s at %s.", Jobs.titleFor(listing.employer, listing.level), employer.name)
	else
		local short = math.ceil((report.threshold - report.score) * 100)
		app.status = "rejected"
		app.reason = string.format("Not this time: %d point%s short.", short, short == 1 and "" or "s") .. (#report.tips > 0 and (" " .. table.concat(report.tips, "; ") .. ".") or "")
		app.rejectedAt = os.time()
	end
	Notify.send(player, {
		title = employer.name .. (app.status == "accepted" and ": job offer!" or ": application update"),
		body = app.reason,
		app = "jobs",
		category = "jobs",
	})
end

-- Move pending applications along; expire old offers. Runs every couple of seconds.
local function tick()
	local now = os.time()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.get(player)
		if data then
			for _, app in pairs(data.employment.applications) do
				if app.status == "submitted" and now >= app.reviewAt then
					app.status = "review"
				elseif app.status == "review" and now >= app.decideAt then
					decide(player, data, app, nil)
				elseif app.status == "accepted" and app.offerExpires and now > app.offerExpires then
					app.status = "expired"
				end
			end
		end
	end
end

local function listingView(data, l)
	local employer = Jobs.EMPLOYERS[l.employer]
	local report = Hiring.evaluate(data, l, nil)
	local status = nil
	for _, a in pairs(data.employment.applications) do
		if a.listing == l.id and (OPEN[a.status] or a.status == "rejected") then
			status = a.status
		end
	end
	local c = data.employment.current
	return {
		id = l.id,
		employer = l.employer,
		employerName = employer.name,
		industry = employer.industry,
		industryName = Jobs.INDUSTRIES[employer.industry],
		title = Jobs.titleFor(l.employer, l.level),
		level = l.level,
		wage = Jobs.wageFor(l.employer, l.level, Economy.Wages),
		perTrip = employer.industry == "delivery" and string.format("$%d–%d per delivery", Economy.DeliveryPerTrip.min, Economy.DeliveryPerTrip.max) or nil,
		type = l.type,
		where = employer.where,
		hours = employer.hours,
		about = employer.about,
		description = l.description,
		needsShifts = l.needs.shifts or 0,
		haveShifts = data.employment.experience[employer.industry] or 0,
		degreeRequired = l.needs.degree ~= nil,
		saved = table.find(data.employment.saved, l.id) ~= nil,
		status = status,
		current = c ~= nil and c.employer == l.employer and c.level >= l.level,
		fit = report.hardFail and "not yet" or (report.score >= report.threshold and "strong" or "possible"),
	}
end

local function appView(app)
	local listing = Jobs.listing(app.listing)
	local employer = Jobs.EMPLOYERS[listing.employer]
	local view = {
		id = app.id,
		listing = app.listing,
		employerName = employer.name,
		title = Jobs.titleFor(listing.employer, listing.level),
		status = app.status,
		t = app.t,
		reason = app.reason,
		lines = app.lines,
		score = app.score,
		threshold = app.threshold,
		offerExpires = app.offerExpires,
	}
	if app.status == "interview" then
		view.questions = {}
		for _, q in ipairs(Jobs.INTERVIEWS[employer.industry]) do
			local options = {}
			for _, a in ipairs(q.a) do
				table.insert(options, a[1])
			end
			table.insert(view.questions, { q = q.q, options = options })
		end
	end
	return view
end

---------------------------------------------------------------------------
-- Called by Work after each shift: experience, skills, promotion.
---------------------------------------------------------------------------
function Employment.recordShift(player, performance, tasks, counts)
	local data = PlayerData.get(player)
	local c = data and data.employment.current
	if not c then
		return
	end
	local emp = data.employment
	local industry = Jobs.EMPLOYERS[c.employer].industry
	emp.skills[industry] = (emp.skills[industry] or 0) + tasks
	if not counts then
		return -- too short to count as a shift
	end
	emp.experience[industry] = (emp.experience[industry] or 0) + 1
	emp.totalShifts = (emp.totalShifts or 0) + 1
	c.shiftsAtLevel += 1
	c.perfSum += performance
	c.perfCount += 1
	-- Promotion review.
	local need = Settings.PromotionShifts[math.clamp(c.level, 1, #Settings.PromotionShifts)]
	local avg = c.perfSum / c.perfCount
	if c.level < Jobs.maxLevel(c.employer) and c.shiftsAtLevel >= need and avg >= Settings.PromotionPerformance then
		table.insert(emp.history, { employer = c.employer, title = c.title, from = c.since, to = os.time(), reason = "Promoted" })
		c.level += 1
		c.title = Jobs.titleFor(c.employer, c.level)
		c.wage = Jobs.wageFor(c.employer, c.level, Economy.Wages)
		c.since = os.time()
		c.shiftsAtLevel, c.perfSum, c.perfCount = 0, 0, 0
		if not data.achievements.firstPromotion then
			data.achievements.firstPromotion = os.time()
		end
		Notify.send(player, {
			title = "Promoted: " .. c.title,
			body = string.format("%s promoted you to %s%s.", Jobs.EMPLOYERS[c.employer].name, c.title, c.wage and string.format(" at $%d an hour", c.wage) or ""),
			app = "jobs",
			category = "jobs",
		})
	end
end

function Employment.current(player)
	local data = PlayerData.get(player)
	return data and data.employment.current
end

---------------------------------------------------------------------------
-- Phone requests
---------------------------------------------------------------------------
function Employment.start()
	Router.on("jobs.list", function(player)
		local data = PlayerData.get(player)
		local out = {}
		for _, l in ipairs(Jobs.LISTINGS) do
			table.insert(out, listingView(data, l))
		end
		return { listings = out, industries = Jobs.INDUSTRIES }
	end)

	Router.on("jobs.save", function(player, args)
		local data = PlayerData.get(player)
		if not Jobs.listing(args.id) then
			return nil, "No such job"
		end
		local saved = data.employment.saved
		local i = table.find(saved, args.id)
		if i then
			table.remove(saved, i)
		else
			table.insert(saved, args.id)
		end
		return { saved = i == nil }
	end)

	Router.on("jobs.apply", function(player, args)
		local data = PlayerData.get(player)
		local listing = Jobs.listing(args.id)
		if not listing then
			return nil, "No such job"
		end
		local emp = data.employment
		local c = emp.current
		if c and c.employer == listing.employer and c.level >= listing.level then
			return nil, "You already have this job (or a higher one) there"
		end
		if openCount(emp.applications) >= Settings.MaxOpenApplications then
			return nil, "You have " .. Settings.MaxOpenApplications .. " open applications. Withdraw one or wait for answers."
		end
		for _, a in pairs(emp.applications) do
			if a.listing == listing.id then
				if OPEN[a.status] then
					return nil, "You've already applied for this job"
				end
				if a.status == "rejected" and os.time() - (a.rejectedAt or 0) < Settings.ReapplyAfterSeconds then
					return nil, string.format("You can reapply in %d min", math.ceil((Settings.ReapplyAfterSeconds - (os.time() - a.rejectedAt)) / 60))
				end
			end
		end
		-- Drop old closed applications for this listing; keep the record small.
		for id, a in pairs(emp.applications) do
			if a.listing == listing.id and not OPEN[a.status] then
				emp.applications[id] = nil
			end
		end
		local now = os.time()
		local review = math.random(Settings.ReviewSeconds[1], Settings.ReviewSeconds[2])
		local app = {
			id = HttpService:GenerateGUID(false),
			listing = listing.id,
			status = "submitted",
			t = now,
			reviewAt = now + math.floor(review / 2),
			decideAt = now + review,
		}
		emp.applications[app.id] = app
		Notify.send(player, { title = "Application sent", body = Jobs.titleFor(listing.employer, listing.level) .. " at " .. Jobs.EMPLOYERS[listing.employer].name .. ". You'll hear back shortly.", app = "jobs", category = "jobs" })
		return { application = appView(app) }
	end)

	Router.on("jobs.applications", function(player)
		local data = PlayerData.get(player)
		local out = {}
		for _, a in pairs(data.employment.applications) do
			table.insert(out, appView(a))
		end
		table.sort(out, function(a, b)
			return a.t > b.t
		end)
		return { applications = out }
	end)

	Router.on("jobs.withdraw", function(player, args)
		local app = PlayerData.get(player).employment.applications[args.id]
		if not app or not OPEN[app.status] then
			return nil, "Nothing to withdraw"
		end
		app.status = "withdrawn"
		return {}
	end)

	Router.on("jobs.interview", function(player, args)
		local data = PlayerData.get(player)
		local app = data.employment.applications[args.id]
		if not app or app.status ~= "interview" then
			return nil, "No interview waiting"
		end
		local listing = Jobs.listing(app.listing)
		local score = Hiring.scoreInterview(Jobs.EMPLOYERS[listing.employer].industry, args.answers)
		if not score then
			return nil, "Answer every question"
		end
		decide(player, data, app, score)
		return { application = appView(app) }
	end)

	Router.on("jobs.accept", function(player, args)
		local data = PlayerData.get(player)
		local app = data.employment.applications[args.id]
		if not app or app.status ~= "accepted" then
			return nil, "No offer to accept"
		end
		if app.offerExpires and os.time() > app.offerExpires then
			app.status = "expired"
			return nil, "This offer has expired"
		end
		app.status = "hired"
		hire(player, data, Jobs.listing(app.listing))
		return { job = currentSummary(data) }
	end)

	Router.on("jobs.decline", function(player, args)
		local app = PlayerData.get(player).employment.applications[args.id]
		if not app or app.status ~= "accepted" then
			return nil, "No offer to decline"
		end
		app.status = "withdrawn"
		return {}
	end)

	Router.on("jobs.mine", function(player)
		local data = PlayerData.get(player)
		local history = {}
		for i = #data.employment.history, math.max(1, #data.employment.history - 9), -1 do
			local h = data.employment.history[i]
			table.insert(history, { employerName = Jobs.EMPLOYERS[h.employer] and Jobs.EMPLOYERS[h.employer].name or h.employer, title = h.title, from = h.from, to = h.to, reason = h.reason })
		end
		return { job = currentSummary(data), history = history, experience = data.employment.experience, totalShifts = data.employment.totalShifts }
	end)

	Router.on("jobs.quit", function(player)
		local data = PlayerData.get(player)
		local c = data.employment.current
		if not c then
			return nil, "You don't have a job"
		end
		if Employment.onJobChanged then
			Employment.onJobChanged(player)
		end
		table.insert(data.employment.history, { employer = c.employer, title = c.title, from = c.since, to = os.time(), reason = "Resigned" })
		data.employment.current = nil
		return {}
	end)

	-- Calendar: workplace hours, interviews and offers waiting, recent shifts.
	Router.on("calendar.get", function(player)
		local data = PlayerData.get(player)
		local places = {}
		for id, e in pairs(Jobs.EMPLOYERS) do
			table.insert(places, { id = id, name = e.name, where = e.where, hours = e.hours, mine = data.employment.current ~= nil and data.employment.current.employer == id })
		end
		table.sort(places, function(a, b)
			return a.mine and not b.mine or (a.mine == b.mine and a.name < b.name)
		end)
		local pending = {}
		for _, a in pairs(data.employment.applications) do
			if a.status == "interview" or a.status == "accepted" then
				table.insert(pending, appView(a))
			end
		end
		table.sort(pending, function(a, b)
			return a.t > b.t
		end)
		return { places = places, pending = pending, shifts = data.employment.shiftLog or {}, job = currentSummary(data) }
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			tick()
		end
	end)
end

return Employment
