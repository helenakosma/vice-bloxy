-- Calendar: what's on today. Your next shift window, interviews and offers
-- waiting for you, when each workplace is open, and your recent shifts.
local Lighting = game:GetService("Lighting")

local UI = require(script.Parent.Parent.PhoneUI)

local C = Color3.fromRGB

local function isOpen(hours, h)
	if hours[1] == 0 and hours[2] >= 24 then
		return true
	end
	return h >= hours[1] and h < hours[2]
end

local function clockText(h)
	return string.format("%02d:%02d", math.floor(h) % 24, math.floor((h % 1) * 60))
end

return {
	id = "calendar",
	name = "Calendar",
	icon = "📅",
	colour = C(230, 80, 70),
	build = function(page, api)
		local theme = api.theme()
		local scroll = UI.scroll(page, theme)

		local function render()
			for _, child in ipairs(scroll:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local r = api.request("calendar.get")
			if not r.ok then
				UI.text(scroll, r.error or "Couldn't load", 13, theme.muted)
				return
			end
			local h = Lighting.ClockTime

			local today = UI.card(scroll, theme, 1)
			UI.text(today, "City time " .. clockText(h), 18, theme.text, { Font = Enum.Font.GothamBlack })
			UI.text(today, "1 city hour = 1 real minute", 12, theme.muted)
			if r.job then
				local open = isOpen(r.job.hours, h)
				local line
				if not r.job.workplace then
					line = "Quickdrop runs around the clock: start deliveries from the Jobs app."
				elseif open then
					line = string.format("%s is open now until %d:00. Head to the time clock to start a shift.", r.job.employerName, r.job.hours[2])
				else
					local wait = (r.job.hours[1] - h) % 24
					line = string.format("%s opens at %d:00 (in about %d real min).", r.job.employerName, r.job.hours[1], math.ceil(wait))
				end
				UI.text(today, line, 13, open and theme.good or theme.text, { AutomaticSize = Enum.AutomaticSize.Y })
			else
				UI.text(today, "No job yet: the Jobs app has entry-level openings.", 13, theme.muted, { AutomaticSize = Enum.AutomaticSize.Y })
			end

			if #r.pending > 0 then
				local card = UI.card(scroll, theme, 2)
				UI.text(card, "Waiting for you", 14, theme.text, { Font = Enum.Font.GothamBold })
				for _, a in ipairs(r.pending) do
					local what = a.status == "interview" and "🗣 Interview" or "✉ Job offer"
					local extra = ""
					if a.status == "accepted" and a.offerExpires then
						extra = string.format(" · %d min left", math.max(0, math.floor((a.offerExpires - os.time()) / 60)))
					end
					local b = UI.button(card, string.format("%s · %s, %s%s", what, a.title, a.employerName, extra), theme.bg, theme.text, { TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
					UI.pad(b, 8)
					b.Activated:Connect(function()
						api.open("jobs")
					end)
				end
			end

			local places = UI.card(scroll, theme, 3)
			UI.text(places, "Opening hours", 14, theme.text, { Font = Enum.Font.GothamBold })
			for _, p in ipairs(r.places) do
				local open = isOpen(p.hours, h)
				local hours = (p.hours[1] == 0 and p.hours[2] >= 24) and "24 hours" or string.format("%d:00–%d:00", p.hours[1], p.hours[2])
				UI.text(places, string.format("%s%s · %s · %s", p.mine and "★ " or "", p.name, hours, open and "open" or "closed"), 13, open and theme.text or theme.muted, { AutomaticSize = Enum.AutomaticSize.Y })
			end

			local log = UI.card(scroll, theme, 4)
			UI.text(log, "Recent shifts", 14, theme.text, { Font = Enum.Font.GothamBold })
			if #r.shifts == 0 then
				UI.text(log, "No shifts yet", 13, theme.muted)
			end
			for _, s in ipairs(r.shifts) do
				UI.text(log, string.format("%s · %s, %s", UI.ago(s.t), s.title, s.employer), 13, theme.text, { AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(log, string.format("%d min · %d task%s · %s%s", s.minutes, s.tasks, s.tasks == 1 and "" or "s", UI.money(s.pay), s.performance and string.format(" · %d%%", math.floor(s.performance * 100 + 0.5)) or ""), 12, theme.muted)
			end
		end

		return { refresh = render }
	end,
}
