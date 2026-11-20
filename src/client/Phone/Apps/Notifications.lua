-- Notifications app: everything the city has told you, newest first.
local UI = require(script.Parent.Parent.PhoneUI)

return {
	id = "notifications",
	name = "Alerts",
	icon = "🔔",
	colour = Color3.fromRGB(220, 80, 70),
	build = function(page, api)
		local theme = api.theme()
		local scroll = UI.scroll(page, theme)
		local clear = UI.button(scroll, "Clear all", theme.card, theme.text, { LayoutOrder = 0 })
		local list = UI.frame(scroll, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
		UI.list(list, 8)

		local function refresh()
			local r = api.request("notify.list")
			for _, child in ipairs(list:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			if not r.ok then
				return
			end
			if #r.inbox == 0 then
				UI.text(list, "Nothing yet.", 13, theme.muted)
			end
			for i, item in ipairs(r.inbox) do
				local card = UI.card(list, theme, i)
				UI.text(card, item.title, 14, theme.text, { Font = Enum.Font.GothamBold, AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(card, item.body, 13, theme.text, { AutomaticSize = Enum.AutomaticSize.Y })
				UI.text(card, UI.ago(item.t), 11, theme.muted)
				if item.app then
					local open = UI.button(card, "Open", theme.accent)
					open.Activated:Connect(function()
						api.open(item.app)
					end)
				end
			end
			api.request("notify.readAll")
			api.setUnread(0)
		end
		clear.Activated:Connect(function()
			if api.request("notify.clear").ok then
				refresh()
			end
		end)
		api.onPush("notify", function()
			if page.Visible then
				refresh()
			end
		end)
		return { refresh = refresh }
	end,
}
