-- Jobs app: find work, apply, follow your applications (interviews and offers),
-- and see your job: pay, promotion progress, deliveries, history.
local UI = require(script.Parent.Parent.PhoneUI)

local C = Color3.fromRGB
local STATUS = {
	submitted = { "Sent", C(120, 130, 150) },
	review = { "Under review", C(70, 130, 220) },
	interview = { "Interview", C(230, 160, 40) },
	accepted = { "Offer!", C(40, 170, 90) },
	rejected = { "Not selected", C(200, 70, 70) },
	withdrawn = { "Withdrawn", C(120, 120, 126) },
	hired = { "Hired", C(40, 170, 90) },
	expired = { "Offer expired", C(120, 120, 126) },
}
local FIT = { strong = { "Strong fit", C(40, 170, 90) }, possible = { "Possible fit", C(70, 130, 220) }, ["not yet"] = { "Needs experience", C(200, 120, 60) } }
local TYPE = { full = "Full-time", part = "Part-time", gig = "Flexible gig" }

local function pill(parent, text, colour)
	local p = UI.text(parent, text, 11, C(255, 255, 255), {
		Font = Enum.Font.GothamBold, BackgroundTransparency = 0, BackgroundColor3 = colour,
		Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
	})
	UI.corner(p, 9)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = p
	return p
end

return {
	id = "jobs",
	name = "Jobs",
	icon = "💼",
	colour = C(40, 110, 200),
	build = function(page, api)
		local theme = api.theme()
		local tab = "find"
		local filters = { industry = "all", type = "all" }
		local detail = nil -- listing id open in detail view
		local answers = {}

		local tabs = UI.frame(page, { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 0) })
		UI.list(tabs, 6, true)
		local body = UI.frame(page, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36) })
		local scroll = UI.scroll(body, theme)
		local render

		local tabButtons = {}
		for i, info in ipairs({ { "find", "Find" }, { "applied", "Applied" }, { "mine", "My job" } }) do
			local b = UI.button(tabs, info[2], theme.card, theme.text, { Size = UDim2.new(1 / 3, -4, 1, 0), LayoutOrder = i, TextSize = 13 })
			tabButtons[info[1]] = b
			b.Activated:Connect(function()
				tab = info[1]
				detail = nil
				render()
			end)
		end

		local function clear()
			for _, child in ipairs(scroll:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
		end

		local function chips(options, key, order)
			local row = UI.frame(scroll, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = order })
			UI.list(row, 6, true)
			for i, o in ipairs(options) do
				local on = filters[key] == o[1]
				local b = UI.button(row, o[2], on and theme.accent or theme.card, on and C(255, 255, 255) or theme.text, { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, LayoutOrder = i })
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 10)
				pad.PaddingRight = UDim.new(0, 10)
				pad.Parent = b
				b.Activated:Connect(function()
					filters[key] = o[1]
					render()
				end)
			end
		end

		-- Find: filters and job cards; tap a card for the full listing.
		local function renderFind()
			local r = api.request("jobs.list")
			if not r.ok then
				UI.text(scroll, r.error or "Couldn't load jobs", 13, theme.muted)
				return
			end
			if detail then
				local l
				for _, x in ipairs(r.listings) do
					if x.id == detail then
						l = x
					end
				end
				if not l then
					detail = nil
					return renderFind()
				end
				local back = UI.button(scroll, "‹ All jobs", theme.card, theme.accent, { LayoutOrder = 0, Size = UDim2.new(0, 110, 0, 30) })
				back.Activated:Connect(function()
					detail = nil
					render()
				end)
				local card = UI.card(scroll, theme, 1)
				UI.text(card, l.title, 18, theme.text, { Font = Enum.Font.GothamBlack, AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(card, l.employerName .. "  ·  " .. l.industryName, 13, theme.muted)
				UI.text(card, l.perTrip or string.format("$%d an hour  ·  %s", l.wage or 0, TYPE[l.type] or l.type), 15, theme.good, { Font = Enum.Font.GothamBold })
				UI.text(card, "📍 " .. l.where, 12, theme.muted, { AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(card, string.format("🕒 Open %d:00–%d:00 (city time)", l.hours[1], l.hours[2]), 12, theme.muted)
				local d = UI.card(scroll, theme, 2)
				UI.text(d, l.description, 13, theme.text, { AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(d, l.about, 12, theme.muted, { AutomaticSize = Enum.AutomaticSize.Y })
				local req = UI.card(scroll, theme, 3)
				UI.text(req, "Requirements", 14, theme.text, { Font = Enum.Font.GothamBold })
				local met = l.haveShifts >= l.needsShifts
				UI.text(req, (met and "✓ " or "✗ ") .. (l.needsShifts > 0 and string.format("%d shifts of experience (you have %d)", l.needsShifts, l.haveShifts) or "No experience needed"), 13, met and theme.good or theme.bad, { AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(req, "✓ No degree needed", 13, theme.good)
				local fit = FIT[l.fit]
				pill(req, fit[1], fit[2])
				local actions = UI.card(scroll, theme, 4)
				if l.current then
					UI.text(actions, "This is your job.", 13, theme.muted)
				elseif l.status and l.status ~= "rejected" then
					UI.text(actions, "Applied · " .. (STATUS[l.status] and STATUS[l.status][1] or l.status), 13, theme.muted)
				else
					local apply = UI.button(actions, l.status == "rejected" and "Apply again" or "Apply", theme.accent)
					apply.Activated:Connect(function()
						local res = api.request("jobs.apply", { id = l.id })
						api.toast(res.ok and "Application sent" or (res.error or "Couldn't apply"))
						render()
					end)
				end
				local save = UI.button(actions, l.saved and "★ Saved" or "☆ Save", theme.bg, theme.text)
				save.Activated:Connect(function()
					api.request("jobs.save", { id = l.id })
					render()
				end)
				return
			end
			chips({ { "all", "All" }, { "food", "Food" }, { "retail", "Retail" }, { "delivery", "Delivery" } }, "industry", 1)
			chips({ { "all", "Any" }, { "full", "Full" }, { "part", "Part" }, { "gig", "Gig" } }, "type", 2)
			local listings = {}
			for _, l in ipairs(r.listings) do
				if (filters.industry == "all" or l.industry == filters.industry) and (filters.type == "all" or l.type == filters.type) then
					table.insert(listings, l)
				end
			end
			table.sort(listings, function(a, b)
				return (a.wage or 0) > (b.wage or 0)
			end)
			UI.text(scroll, #listings .. " job" .. (#listings == 1 and "" or "s") .. " · police, office and entertainment jobs open soon", 12, theme.muted, { LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.Y })
			for i, l in ipairs(listings) do
				-- The whole card is a button.
				local card = Instance.new("TextButton")
				card.AutoButtonColor = true
				card.Text = ""
				card.BorderSizePixel = 0
				card.BackgroundColor3 = theme.card
				card.Size = UDim2.new(1, 0, 0, 0)
				card.AutomaticSize = Enum.AutomaticSize.Y
				card.LayoutOrder = 10 + i
				card.Parent = scroll
				UI.corner(card, 14)
				UI.pad(card, 12)
				UI.list(card, 6)
				local tap = card
				UI.text(card, (l.saved and "★ " or "") .. l.title, 15, theme.text, { Font = Enum.Font.GothamBold, AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(card, l.employerName .. "  ·  " .. (TYPE[l.type] or l.type), 12, theme.muted)
				UI.text(card, l.perTrip or string.format("$%d / hour", l.wage or 0), 13, theme.good, { Font = Enum.Font.GothamBold })
				local row = UI.frame(card, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18) })
				UI.list(row, 6, true)
				if l.current then
					pill(row, "Your job", C(40, 170, 90))
				elseif l.status then
					local st = STATUS[l.status]
					pill(row, st[1], st[2])
				else
					local fit = FIT[l.fit]
					pill(row, fit[1], fit[2])
				end
				tap.Activated:Connect(function()
					detail = l.id
					render()
				end)
			end
		end

		-- Applied: every application with its status and the reasons.
		local function renderApplied()
			local r = api.request("jobs.applications")
			if not r.ok then
				UI.text(scroll, r.error or "Couldn't load", 13, theme.muted)
				return
			end
			if #r.applications == 0 then
				UI.text(scroll, "No applications yet. Find a job and apply.", 13, theme.muted)
			end
			for i, a in ipairs(r.applications) do
				local card = UI.card(scroll, theme, i)
				UI.text(card, a.title, 15, theme.text, { Font = Enum.Font.GothamBold, AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(card, a.employerName .. "  ·  " .. UI.ago(a.t), 12, theme.muted)
				local st = STATUS[a.status] or { a.status, theme.muted }
				pill(card, st[1], st[2])
				if a.reason then
					UI.text(card, a.reason, 12, theme.text, { AutomaticSize = Enum.AutomaticSize.Y })
				end
				if a.lines and (a.status == "rejected" or a.status == "accepted") then
					for _, line in ipairs(a.lines) do
						UI.text(card, string.format("%s  %d/%d  ·  %s", line.label, line.points, line.max, line.note), 11, theme.muted, { AutomaticSize = Enum.AutomaticSize.Y })
					end
					UI.text(card, string.format("Score %d · needed %d", math.floor(a.score * 100 + 0.5), math.floor(a.threshold * 100 + 0.5)), 11, theme.muted)
				end
				if a.status == "interview" and a.questions then
					answers[a.id] = answers[a.id] or {}
					for qi, q in ipairs(a.questions) do
						UI.text(card, qi .. ". " .. q.q, 13, theme.text, { Font = Enum.Font.GothamBold, AutomaticSize = Enum.AutomaticSize.Y })
						for oi, option in ipairs(q.options) do
							local chosen = answers[a.id][qi] == oi
							local b = UI.button(card, option, chosen and theme.accent or theme.bg, chosen and C(255, 255, 255) or theme.text, { TextWrapped = true, TextSize = 12, Size = UDim2.new(1, 0, 0, 34) })
							b.Activated:Connect(function()
								answers[a.id][qi] = oi
								render()
							end)
						end
					end
					local send = UI.button(card, "Send answers", theme.accent)
					send.Activated:Connect(function()
						local res = api.request("jobs.interview", { id = a.id, answers = answers[a.id] })
						api.toast(res.ok and "Answers sent" or (res.error or "Couldn't send"))
						render()
					end)
				elseif a.status == "accepted" then
					if a.offerExpires then
						UI.text(card, "Offer open for " .. math.max(0, math.floor((a.offerExpires - os.time()) / 60)) .. " more min", 12, theme.muted)
					end
					local accept = UI.button(card, "Accept offer", theme.good)
					accept.Activated:Connect(function()
						local res = api.request("jobs.accept", { id = a.id })
						api.toast(res.ok and "You're hired!" or (res.error or "Couldn't accept"))
						tab = res.ok and "mine" or tab
						render()
					end)
					local decline = UI.button(card, "Decline", theme.bg, theme.text)
					decline.Activated:Connect(function()
						api.request("jobs.decline", { id = a.id })
						render()
					end)
				elseif a.status == "submitted" or a.status == "review" then
					local withdraw = UI.button(card, "Withdraw", theme.bg, theme.text)
					withdraw.Activated:Connect(function()
						api.request("jobs.withdraw", { id = a.id })
						render()
					end)
				end
			end
		end

		-- My job: what you do, pay, promotion progress, actions, history.
		local quitArmed = false
		local function renderMine()
			local r = api.request("jobs.mine")
			if not r.ok then
				UI.text(scroll, r.error or "Couldn't load", 13, theme.muted)
				return
			end
			local j = r.job
			if not j then
				local card = UI.card(scroll, theme, 1)
				UI.text(card, "You're not working yet", 16, theme.text, { Font = Enum.Font.GothamBold })
				UI.text(card, "Entry-level jobs need no experience. Try Grind Coffee, Metro Threads or Quickdrop.", 13, theme.muted, { AutomaticSize = Enum.AutomaticSize.Y })
				local find = UI.button(card, "Find a job", theme.accent)
				find.Activated:Connect(function()
					tab = "find"
					render()
				end)
			else
				local card = UI.card(scroll, theme, 1)
				UI.text(card, j.title, 18, theme.text, { Font = Enum.Font.GothamBlack, AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(card, j.employerName .. "  ·  " .. (TYPE[j.type] or j.type), 13, theme.muted)
				UI.text(card, j.wage and string.format("$%d an hour", j.wage) or "Paid per delivery", 15, theme.good, { Font = Enum.Font.GothamBold })
				UI.text(card, "📍 " .. j.where, 12, theme.muted, { AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(card, string.format("🕒 Clock in %d:00–%d:00 city time", j.hours[1], j.hours[2]), 12, theme.muted)
				local how = j.workplace and "Clock in at the time clock at work, then follow the work panel." or "Start a delivery run here, then follow the markers."
				UI.text(card, how, 12, theme.text, { AutomaticSize = Enum.AutomaticSize.Y })
				if not j.workplace then
					local start = UI.button(card, "Start deliveries", theme.accent)
					start.Activated:Connect(function()
						local res = api.request("work.startDelivery")
						api.toast(res.ok and "Delivery run started" or (res.error or "Couldn't start"))
					end)
				end
				local stop = UI.button(card, "End shift", theme.bg, theme.text)
				stop.Activated:Connect(function()
					local res = api.request("work.end")
					api.toast(res.ok and "Shift ended" or (res.error or ""))
				end)

				local promo = UI.card(scroll, theme, 2)
				UI.text(promo, "Next promotion", 14, theme.text, { Font = Enum.Font.GothamBold })
				if j.nextTitle then
					UI.text(promo, string.format("%s%s", j.nextTitle, j.nextWage and string.format(" · $%d an hour", j.nextWage) or ""), 13, theme.text)
					UI.text(promo, string.format("Shifts at this level: %d / %d", j.shiftsAtLevel, j.shiftsNeeded), 13, j.shiftsAtLevel >= j.shiftsNeeded and theme.good or theme.text)
					UI.text(promo, string.format("Average performance: %s (needs %d%%)", j.performance and (math.floor(j.performance * 100 + 0.5) .. "%") or "—", math.floor(j.performanceNeeded * 100)), 13, (j.performance or 0) >= j.performanceNeeded and theme.good or theme.text)
				else
					UI.text(promo, "You're at the top of this ladder.", 13, theme.muted)
				end

				local quit = UI.button(scroll, quitArmed and "Tap again to quit" or "Quit job", quitArmed and theme.bad or theme.card, quitArmed and C(255, 255, 255) or theme.bad, { LayoutOrder = 5 })
				quit.Activated:Connect(function()
					if not quitArmed then
						quitArmed = true
						render()
						return
					end
					quitArmed = false
					local res = api.request("jobs.quit")
					api.toast(res.ok and "You quit" or (res.error or ""))
					render()
				end)
			end
			local exp = UI.card(scroll, theme, 3)
			UI.text(exp, "Experience", 14, theme.text, { Font = Enum.Font.GothamBold })
			local any = false
			for industry, n in pairs(r.experience) do
				any = true
				UI.text(exp, string.format("%s: %d shift%s", industry:sub(1, 1):upper() .. industry:sub(2), n, n == 1 and "" or "s"), 13, theme.text)
			end
			if not any then
				UI.text(exp, "No shifts yet", 13, theme.muted)
			end
			if #r.history > 0 then
				local hist = UI.card(scroll, theme, 4)
				UI.text(hist, "History", 14, theme.text, { Font = Enum.Font.GothamBold })
				for _, h in ipairs(r.history) do
					UI.text(hist, string.format("%s, %s · %s", h.title, h.employerName, h.reason), 12, theme.muted, { AutomaticSize = Enum.AutomaticSize.Y })
				end
			end
		end

		function render()
			clear()
			for key, b in pairs(tabButtons) do
				b.BackgroundColor3 = key == tab and theme.accent or theme.card
				b.TextColor3 = key == tab and C(255, 255, 255) or theme.text
			end
			if tab == "find" then
				renderFind()
			elseif tab == "applied" then
				renderApplied()
			else
				renderMine()
			end
		end

		api.onPush("notify", function(msg)
			if page.Visible and msg.item and msg.item.category == "jobs" then
				render()
			end
		end)
		return { refresh = render }
	end,
}
