-- Shared look and building blocks for the phone, so every app reads as one device.
local UI = {}

local C = Color3.fromRGB

UI.THEMES = {
	dark = { bg = C(18, 19, 24), card = C(32, 34, 42), text = C(240, 240, 244), muted = C(150, 154, 166), line = C(48, 50, 60), accent = C(64, 150, 255), good = C(80, 205, 130), bad = C(255, 96, 96) },
	light = { bg = C(242, 243, 247), card = C(255, 255, 255), text = C(22, 24, 30), muted = C(108, 112, 124), line = C(222, 224, 230), accent = C(20, 110, 240), good = C(20, 150, 80), bad = C(210, 50, 50) },
}

-- Wallpapers: two-colour gradients.
UI.WALLPAPERS = {
	{ C(30, 40, 90), C(150, 60, 140) }, -- dusk
	{ C(10, 70, 90), C(40, 170, 140) }, -- lake
	{ C(200, 70, 60), C(250, 180, 90) }, -- sunset
	{ C(20, 20, 26), C(70, 74, 90) }, -- graphite
	{ C(40, 110, 60), C(170, 210, 120) }, -- park
	{ C(206, 30, 40), C(90, 10, 20) }, -- TTC red
}

function UI.corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = parent
	return c
end

function UI.pad(parent, all)
	local p = Instance.new("UIPadding")
	for _, side in ipairs({ "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" }) do
		p[side] = UDim.new(0, all)
	end
	p.Parent = parent
	return p
end

function UI.list(parent, gap, horizontal)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	l.Parent = parent
	return l
end

function UI.frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

function UI.text(parent, str, size, colour, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamMedium
	t.TextSize = size or 14
	t.TextColor3 = colour or C(255, 255, 255)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Text = str
	t.Size = UDim2.new(1, 0, 0, (size or 14) + 6)
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	t.Parent = parent
	return t
end

function UI.button(parent, str, colour, textColour, props)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = colour
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = textColour or C(255, 255, 255)
	b.Text = str
	b.Size = UDim2.new(1, 0, 0, 36)
	UI.corner(b, 10)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Parent = parent
	return b
end

-- A scrolling column that grows with its content.
function UI.scroll(parent, theme)
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = UDim2.fromScale(1, 1)
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollBarThickness = 3
	s.ScrollBarImageColor3 = theme.muted
	s.Parent = parent
	UI.pad(s, 12)
	UI.list(s, 10)
	return s
end

-- Card with rounded corners that sizes to its content.
function UI.card(parent, theme, order)
	local c = UI.frame(parent, { BackgroundColor3 = theme.card, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 0 })
	UI.corner(c, 14)
	UI.pad(c, 12)
	UI.list(c, 6)
	return c
end

function UI.money(n)
	local s = tostring(math.abs(math.floor(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (n < 0 and "-$" or "$") .. out
end

function UI.ago(t)
	local d = math.max(0, os.time() - t)
	if d < 60 then
		return "just now"
	elseif d < 3600 then
		return math.floor(d / 60) .. " min ago"
	elseif d < 86400 then
		return math.floor(d / 3600) .. " h ago"
	end
	return math.floor(d / 86400) .. " d ago"
end

return UI
