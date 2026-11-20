-- Bank app: balance, this week's money in and out, the Transit Card, and every
-- transaction (newest first). Updates live when money moves.
local UI = require(script.Parent.Parent.PhoneUI)

local ICONS = { shopping = "🛍", transit = "🚇", salary = "💼", rent = "🏠", tuition = "🎓", other = "💳" }

return {
	id = "bank",
	name = "Bank",
	icon = "🏦",
	colour = Color3.fromRGB(30, 140, 90),
	build = function(page, api)
		local theme = api.theme()
		local scroll = UI.scroll(page, theme)
		local top = UI.card(scroll, theme, 1)
		top.BackgroundColor3 = Color3.fromRGB(26, 120, 78)
		UI.text(top, "CITY CREDIT UNION · CHEQUING", 11, Color3.fromRGB(200, 240, 220), { Font = Enum.Font.GothamBold })
		local balance = UI.text(top, "…", 34, Color3.fromRGB(255, 255, 255), { Font = Enum.Font.GothamBlack, Size = UDim2.new(1, 0, 0, 40) })
		local week = UI.text(top, "", 13, Color3.fromRGB(220, 245, 232))
		local card = UI.text(top, "", 13, Color3.fromRGB(220, 245, 232))
		UI.text(scroll, "Transactions", 15, theme.text, { Font = Enum.Font.GothamBold, LayoutOrder = 2 })
		local list = UI.frame(scroll, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 })
		UI.list(list, 6)

		local function row(e, order)
			local r = UI.frame(list, { BackgroundColor3 = theme.card, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order })
			UI.corner(r, 12)
			UI.text(r, ICONS[e.k] or ICONS.other, 20, theme.text, { Size = UDim2.fromOffset(30, 52), Position = UDim2.fromOffset(8, 0), TextXAlignment = Enum.TextXAlignment.Center })
			UI.text(r, e.m ~= "" and e.m or e.k, 13, theme.text, { Font = Enum.Font.GothamBold, Size = UDim2.new(1, -130, 0, 18), Position = UDim2.fromOffset(42, 8), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
			UI.text(r, UI.ago(e.t), 11, theme.muted, { Size = UDim2.new(1, -130, 0, 14), Position = UDim2.fromOffset(42, 28) })
			UI.text(r, (e.a > 0 and "+" or "") .. UI.money(e.a), 14, e.a > 0 and theme.good or theme.text, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(80, 52), Position = UDim2.new(1, -88, 0, 0), TextXAlignment = Enum.TextXAlignment.Right })
		end

		local function refresh()
			local r = api.request("bank.get")
			if not r.ok then
				balance.Text = "—"
				week.Text = r.error or ""
				return
			end
			balance.Text = UI.money(r.balance)
			week.Text = string.format("This week  ·  in %s  ·  out %s", UI.money(r.income), UI.money(r.spent))
			card.Text = r.card and ("Transit Card  ·  " .. UI.money(r.card)) or "No Transit Card yet · ticket machines in any station"
			for _, child in ipairs(list:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			if #r.ledger == 0 then
				UI.text(list, "No transactions yet.", 13, theme.muted)
			end
			for i, e in ipairs(r.ledger) do
				if i > 50 then
					break
				end
				row(e, i)
			end
		end
		api.onPush("bank", function()
			if page.Visible then
				refresh()
			end
		end)
		return { refresh = refresh }
	end,
}
