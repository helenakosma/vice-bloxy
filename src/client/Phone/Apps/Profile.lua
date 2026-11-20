-- Profile app: who you are in the city. Avatar, names, when you joined, where you
-- are, and your job, education, home and Transit Card (filled in by later
-- milestones). Edit your bio (filtered by Roblox before anyone sees it) and choose
-- what others can see. No real-world personal information is asked for.
local Players = game:GetService("Players")

local UI = require(script.Parent.Parent.PhoneUI)

local VISIBILITY = { "public", "connections", "private" }
local VIS_LABEL = { public = "Everyone", connections = "Connections only", private = "Only me" }

return {
	id = "profile",
	name = "Profile",
	icon = "👤",
	colour = Color3.fromRGB(80, 90, 200),
	build = function(page, api)
		local theme = api.theme()
		local scroll = UI.scroll(page, theme)

		local head = UI.card(scroll, theme, 1)
		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.fromOffset(72, 72)
		avatar.BackgroundColor3 = theme.line
		avatar.Parent = head
		UI.corner(avatar, 36)
		local display = UI.text(head, "", 20, theme.text, { Font = Enum.Font.GothamBlack })
		local handle = UI.text(head, "", 13, theme.muted)
		local joined = UI.text(head, "", 12, theme.muted)

		local facts = UI.card(scroll, theme, 2)
		local function fact(label)
			local r = UI.frame(facts, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22) })
			UI.text(r, label, 13, theme.muted, { Size = UDim2.new(0.42, 0, 1, 0) })
			return UI.text(r, "", 13, theme.text, { Font = Enum.Font.GothamBold, Size = UDim2.new(0.58, 0, 1, 0), Position = UDim2.fromScale(0.42, 0), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
		end
		local where, job, school, home, cardLine = fact("Neighbourhood"), fact("Occupation"), fact("Education"), fact("Home"), fact("Transit Card")

		local bioCard = UI.card(scroll, theme, 3)
		UI.text(bioCard, "Bio", 14, theme.text, { Font = Enum.Font.GothamBold })
		local bio = Instance.new("TextBox")
		bio.Size = UDim2.new(1, 0, 0, 60)
		bio.BackgroundColor3 = theme.bg
		bio.TextColor3 = theme.text
		bio.PlaceholderText = "A line about you (no personal info)"
		bio.PlaceholderColor3 = theme.muted
		bio.Font = Enum.Font.Gotham
		bio.TextSize = 13
		bio.TextWrapped = true
		bio.ClearTextOnFocus = false
		bio.TextXAlignment = Enum.TextXAlignment.Left
		bio.TextYAlignment = Enum.TextYAlignment.Top
		bio.Text = ""
		bio.Parent = bioCard
		UI.corner(bio, 8)
		UI.pad(bio, 6)
		local save = UI.button(bioCard, "Save bio", theme.accent)
		save.Activated:Connect(function()
			save.Text = "Saving…"
			local r = api.request("profile.setBio", { bio = bio.Text })
			save.Text = "Save bio"
			if r.ok then
				bio.Text = r.bio
				api.toast("Bio saved")
			else
				api.toast(r.error or "Couldn't save")
			end
		end)

		local privacyCard = UI.card(scroll, theme, 4)
		UI.text(privacyCard, "Who can see your profile", 14, theme.text, { Font = Enum.Font.GothamBold })
		local visibility = UI.button(privacyCard, "", theme.bg, theme.text)
		local toggles = {}
		for _, field in ipairs({ "job", "home", "education" }) do
			toggles[field] = UI.button(privacyCard, "", theme.bg, theme.text)
		end
		local privacy = {}
		local function paint()
			visibility.Text = "Profile: " .. (VIS_LABEL[privacy.profile] or "Everyone")
			for field, b in pairs(toggles) do
				local label = field == "job" and "Show my job" or (field == "home" and "Show my home" or "Show my education")
				b.Text = label .. ":  " .. (privacy[field] and "On" or "Off")
			end
		end
		visibility.Activated:Connect(function()
			local i = table.find(VISIBILITY, privacy.profile) or 1
			local r = api.request("profile.setPrivacy", { field = "profile", value = VISIBILITY[i % #VISIBILITY + 1] })
			if r.ok then
				privacy = r.privacy
				paint()
			end
		end)
		for field, b in pairs(toggles) do
			b.Activated:Connect(function()
				local r = api.request("profile.setPrivacy", { field = field, value = not privacy[field] })
				if r.ok then
					privacy = r.privacy
					paint()
				end
			end)
		end

		local function refresh()
			local r = api.request("profile.get")
			if not r.ok then
				display.Text = r.error or "Couldn't load"
				return
			end
			display.Text = r.displayName
			handle.Text = "@" .. r.username
			joined.Text = "In the city since " .. os.date("%b %Y", r.joined)
			where.Text = r.neighbourhood
			job.Text = r.occupation
			school.Text = r.education
			home.Text = r.home
			cardLine.Text = r.transitCard and UI.money(r.transitCard) or "None"
			bio.Text = r.bio
			privacy = r.privacy
			paint()
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(r.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				if ok then
					avatar.Image = image
				end
			end)
		end
		return { refresh = refresh }
	end,
}
