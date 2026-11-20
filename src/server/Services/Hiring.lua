-- Bot hiring managers: score an application against a listing with the employer's
-- weights, and explain the result. The same profile and listing always give the
-- same score (no dice rolls), so players can see what to improve.
--
--   Hiring.evaluate(data, listing, interviewScore?) -> report
--   report = { score, threshold, pass, interview, hardFail?, lines = { { label, factor, weight, note } }, tips = { ... } }
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Economy).Employment
local Jobs = require(ReplicatedStorage.Shared.Catalog.Jobs)

local Hiring = {}

local INDUSTRY_WORD = { food = "café or restaurant", retail = "retail", delivery = "delivery" }

function Hiring.evaluate(data, listing, interviewScore)
	local employer = Jobs.EMPLOYERS[listing.employer]
	local industry = employer.industry
	local w = employer.weights
	local emp = data.employment
	local need = listing.needs.shifts or 0
	local relevant = emp.experience[industry] or 0
	local skill = emp.skills[industry] or 0
	local total = emp.totalShifts or 0
	local degrees = #data.education.degrees

	local lines, tips = {}, {}
	local function add(label, factor, weight, note)
		factor = math.clamp(factor, 0, 1)
		table.insert(lines, { label = label, factor = factor, weight = weight, points = math.floor(factor * weight * 100 + 0.5), max = math.floor(weight * 100 + 0.5), note = note })
		return factor * weight
	end

	local score = 0
	-- Degree: never required for these jobs; any degree helps a little.
	score += add("Education", degrees > 0 and 1 or 0.5, w.degree, degrees > 0 and "Degree on file" or "No degree (not required)")
	-- Experience in this industry.
	local expFactor = need == 0 and math.min(1, 0.5 + relevant / 10) or relevant / (need * 1.25)
	score += add("Experience", expFactor, w.experience, string.format("%d %s shift%s%s", relevant, INDUSTRY_WORD[industry] or industry, relevant == 1 and "" or "s", need > 0 and (" (asks for " .. need .. ")") or ""))
	if need > 0 and relevant < need then
		table.insert(tips, string.format("Work %d more %s shift%s", need - relevant, INDUSTRY_WORD[industry] or industry, need - relevant == 1 and "" or "s"))
	end
	-- Skills: tasks completed in this industry.
	local target = 10 + need * 6
	local skillFactor = need == 0 and math.min(1, 0.5 + skill / 20) or skill / target
	score += add("Skills", skillFactor, w.skills, string.format("%d tasks done on the job", skill))
	if skillFactor < 1 and need > 0 then
		table.insert(tips, "Complete more tasks during shifts to build skills")
	end
	-- Any previous employment.
	score += add("Work history", total / (need * 1.5 + 4), w.previous, string.format("%d shift%s worked in total", total, total == 1 and "" or "s"))
	-- Suitability: the interview, or a fair default for entry-level roles.
	local suit = interviewScore or (need == 0 and 0.8 or 0.5)
	score += add("Suitability", suit, w.suitability, interviewScore and string.format("Interview %d%%", math.floor(interviewScore * 100 + 0.5)) or (need == 0 and "Good fit for an entry-level role" or "Decided at interview"))

	local threshold = Settings.HireThreshold[math.clamp(listing.level, 1, #Settings.HireThreshold)]
	local report = { score = score, threshold = threshold, lines = lines, tips = tips }
	-- Hard requirement: at least half the experience asked for.
	if need > 0 and relevant < math.ceil(need / 2) then
		report.hardFail = string.format("This role needs %d %s shifts; you have %d.", need, INDUSTRY_WORD[industry] or industry, relevant)
		report.pass = false
		return report
	end
	report.pass = score >= threshold
	report.interview = interviewScore == nil and (listing.level >= 3 or (score < threshold and score >= threshold - Settings.InterviewBand))
	return report
end

-- Interview score (0..1) from answers: answers[i] = chosen option index.
function Hiring.scoreInterview(industry, answers)
	local questions = Jobs.INTERVIEWS[industry]
	if not questions or type(answers) ~= "table" then
		return nil
	end
	local total = 0
	for i, q in ipairs(questions) do
		local pick = answers[i]
		if type(pick) ~= "number" or not q.a[pick] then
			return nil
		end
		total += q.a[pick][2]
	end
	return total / #questions
end

return Hiring
