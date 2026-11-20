-- Settings app: wallpaper, light or dark apps, which notifications pop up, and
-- whether your progress is saving.
local UI = require(script.Parent.Parent.PhoneUI)

local CATEGORIES = { { "bank", "Bank and payments" }, { "jobs", "Jobs and shifts" }, { "system", "City and phone" } }

return {
	id = "settings",
	name = "Settings",
	icon = "⚙",
	colour = Color3.fromRGB(110, 114, 126),
	build = function(page, api)
		local theme = api.theme()
		local scroll = UI.scroll(page, theme)

		local wallCard = UI.card(scroll, theme, 1)
		UI.text(wallCard, "Wallpaper", 14, theme.text, { Font = Enum.Font.GothamBold })
		local row = UI.frame(wallCard, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64) })
		UI.list(row, 8, true)
		for i, colours in ipairs(UI.WALLPAPERS) do
			local swatch = Instance.new("TextButton")
			swatch.Text = ""
			swatch.Size = UDim2.fromOffset(34, 60)
			swatch.BackgroundColor3 = Color3.new(1, 1, 1)
			swatch.LayoutOrder = i
			swatch.Parent = row
			UI.corner(swatch, 8)
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(colours[1], colours[2])
			g.Rotation = 90
			g.Parent = swatch
			swatch.Activated:Connect(function()
				local r = api.request("settings.set", { wallpaper = i })
				if r.ok then
					api.setWallpaper(i)
				end
			end)
		end

		local themeCard = UI.card(scroll, theme, 2)
		UI.text(themeCard, "Appearance", 14, theme.text, { Font = Enum.Font.GothamBold })
		local themeButton = UI.button(themeCard, "", theme.bg, theme.text)
		themeButton.Activated:Connect(function()
			local nextTheme = api.themeName() == "dark" and "light" or "dark"
			local r = api.request("settings.set", { theme = nextTheme })
			if r.ok then
				api.setTheme(nextTheme)
			end
		end)

		local notifyCard = UI.card(scroll, theme, 3)
		UI.text(notifyCard, "Pop-up notifications", 14, theme.text, { Font = Enum.Font.GothamBold })
		UI.text(notifyCard, "Muted ones still arrive in Notifications.", 12, theme.muted)
		local notify = {}
		local buttons = {}
		for _, c in ipairs(CATEGORIES) do
			local b = UI.button(notifyCard, "", theme.bg, theme.text)
			buttons[c[1]] = { button = b, label = c[2] }
			b.Activated:Connect(function()
				local r = api.request("settings.set", { notify = { [c[1]] = not notify[c[1]] } })
				if r.ok then
					notify = r.phone.notify
					for key, info in pairs(buttons) do
						info.button.Text = info.label .. ":  " .. (notify[key] and "On" or "Muted")
					end
				end
			end)
		end

		local saveCard = UI.card(scroll, theme, 4)
		UI.text(saveCard, "Saving", 14, theme.text, { Font = Enum.Font.GothamBold })
		local saveLine = UI.text(saveCard, "", 13, theme.muted)

		local function refresh()
			themeButton.Text = "Apps:  " .. (api.themeName() == "dark" and "Dark" or "Light")
			local r = api.request("settings.set", {}) -- returns the current settings
			if r.ok then
				notify = r.phone.notify
				for key, info in pairs(buttons) do
					info.button.Text = info.label .. ":  " .. (notify[key] and "On" or "Muted")
				end
			end
			local home = api.request("home.get")
			if home.ok then
				saveLine.Text = home.savingOff and "Off: this server can't reach Roblox's saving service, so progress here won't be kept." or "On: your money, profile and settings save automatically."
			end
		end
		return { refresh = refresh }
	end,
}
