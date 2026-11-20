-- The phone: press P (or tap the phone button, bottom right) to slide it up.
-- Home screen with the time, your balance and app icons; each app is a module in
-- Apps/ and only talks to the server through `api.request` (Remotes.Request).
-- The server pushes changes (money, notifications) through Remotes.Push, which
-- also shows a banner at the top of the screen.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent.PhoneUI)
local APPS = {
	require(script.Parent.Apps.Bank),
	require(script.Parent.Apps.Profile),
	require(script.Parent.Apps.Notifications),
	require(script.Parent.Apps.Settings),
}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = remotes:WaitForChild("Request")
local Push = remotes:WaitForChild("Push")

local C = Color3.fromRGB
local W, H = 300, 600

local state = { open = false, theme = "dark", wallpaper = 1, unread = 0, balance = nil, current = nil }
local pushListeners = {}
local apps = {} -- id -> { def, page, handle, button }

---------------------------------------------------------------------------
-- Device
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Phone"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10

local openButton = Instance.new("TextButton")
openButton.AnchorPoint = Vector2.new(1, 1)
openButton.Position = UDim2.new(1, -20, 1, -20)
openButton.Size = UDim2.fromOffset(54, 54)
openButton.BackgroundColor3 = C(16, 16, 20)
openButton.Text = "📱"
openButton.TextSize = 26
openButton.Font = Enum.Font.GothamBold
openButton.Parent = gui
UI.corner(openButton, 27)
local buttonBadge = UI.text(openButton, "", 12, C(255, 255, 255), {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.85, 0.15), Size = UDim2.fromOffset(20, 20),
	BackgroundTransparency = 0, BackgroundColor3 = C(230, 50, 50), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
})
UI.corner(buttonBadge, 10)

local phone = UI.frame(gui, {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, H + 40), Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = C(12, 12, 14), Visible = false,
})
UI.corner(phone, 42)
local bezel = Instance.new("UIStroke")
bezel.Color = C(70, 72, 80)
bezel.Thickness = 2
bezel.Parent = phone
local fit = Instance.new("UIScale")
fit.Parent = phone

local screen = UI.frame(phone, { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), BackgroundColor3 = C(255, 255, 255), ClipsDescendants = true })
UI.corner(screen, 34)
local wallpaper = Instance.new("UIGradient")
wallpaper.Rotation = 90
wallpaper.Parent = screen

-- Status bar: time, notch, signal and battery.
local status = UI.frame(screen, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), ZIndex = 5 })
local clock = UI.text(status, "", 13, C(255, 255, 255), { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(22, 6), Size = UDim2.fromOffset(60, 18) })
UI.frame(status, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(86, 20), BackgroundColor3 = C(0, 0, 0) }).Name = "Notch"
UI.corner(status.Notch, 10)
local signal = UI.text(status, "▂▄▆  86%", 12, C(255, 255, 255), { Font = Enum.Font.GothamBold, Position = UDim2.new(1, -86, 0, 6), Size = UDim2.fromOffset(70, 18), TextXAlignment = Enum.TextXAlignment.Right })

-- Home screen: big clock, balance, app grid.
local home = UI.frame(screen, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -54) })
local bigClock = UI.text(home, "", 52, C(255, 255, 255), { Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 56), TextXAlignment = Enum.TextXAlignment.Center })
local homeLine = UI.text(home, "", 14, C(240, 240, 244), { Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
local grid = UI.frame(home, { BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 124), Size = UDim2.new(1, -36, 1, -140) })
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(56, 76)
gridLayout.CellPadding = UDim2.fromOffset(9, 12)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

-- App area (over the home screen) with a header.
local appArea = UI.frame(screen, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -54), Visible = false })
local header = UI.frame(appArea, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) })
local back = Instance.new("TextButton")
back.BackgroundTransparency = 1
back.Size = UDim2.fromOffset(80, 40)
back.Position = UDim2.fromOffset(8, 0)
back.Font = Enum.Font.GothamBold
back.TextSize = 15
back.Text = "‹ Home"
back.TextXAlignment = Enum.TextXAlignment.Left
back.Parent = header
local title = UI.text(header, "", 16, C(0, 0, 0), { Font = Enum.Font.GothamBlack, Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
local pages = UI.frame(appArea, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40) })

-- Home indicator.
local indicator = Instance.new("TextButton")
indicator.Text = ""
indicator.AnchorPoint = Vector2.new(0.5, 1)
indicator.Position = UDim2.new(0.5, 0, 1, -8)
indicator.Size = UDim2.fromOffset(120, 6)
indicator.BackgroundColor3 = C(255, 255, 255)
indicator.ZIndex = 6
indicator.Parent = screen
UI.corner(indicator, 3)

-- Banner notifications at the top of the screen.
local banner = UI.frame(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -90), Size = UDim2.fromOffset(360, 66), BackgroundColor3 = C(28, 30, 36), Visible = false })
UI.corner(banner, 16)
local bannerIcon = UI.text(banner, "", 24, C(255, 255, 255), { Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(36, 66), TextXAlignment = Enum.TextXAlignment.Center })
local bannerTitle = UI.text(banner, "", 14, C(255, 255, 255), { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(56, 10), Size = UDim2.new(1, -66, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
local bannerBody = UI.text(banner, "", 12, C(210, 212, 220), { Position = UDim2.fromOffset(56, 30), Size = UDim2.new(1, -66, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd })
local bannerTap = Instance.new("TextButton")
bannerTap.BackgroundTransparency = 1
bannerTap.Text = ""
bannerTap.Size = UDim2.fromScale(1, 1)
bannerTap.Parent = banner

gui.Parent = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------------
-- API given to every app
---------------------------------------------------------------------------
local api = {}

function api.request(action, args)
	local ok, result = pcall(function()
		return Request:InvokeServer(action, args)
	end)
	if not ok or type(result) ~= "table" then
		return { ok = false, error = "No signal, try again" }
	end
	return result
end

function api.theme()
	return UI.THEMES[state.theme]
end

function api.themeName()
	return state.theme
end

function api.onPush(kind, fn)
	pushListeners[kind] = pushListeners[kind] or {}
	table.insert(pushListeners[kind], fn)
end

function api.toast(text)
	local t = UI.text(screen, text, 13, C(255, 255, 255), {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(1, -40, 0, 30),
		BackgroundTransparency = 0.1, BackgroundColor3 = C(20, 20, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8,
	})
	UI.corner(t, 10)
	task.delay(2.2, function()
		t:Destroy()
	end)
end

function api.setUnread(n)
	state.unread = n
	buttonBadge.Visible = n > 0
	buttonBadge.Text = tostring(math.min(n, 99))
	local a = apps.notifications
	if a and a.badge then
		a.badge.Visible = n > 0
		a.badge.Text = tostring(math.min(n, 99))
	end
end

local function paintChrome()
	local theme = UI.THEMES[state.theme]
	local wp = UI.WALLPAPERS[state.wallpaper] or UI.WALLPAPERS[1]
	wallpaper.Color = ColorSequence.new(wp[1], wp[2])
	appArea.BackgroundColor3 = theme.bg
	back.TextColor3 = theme.accent
	title.TextColor3 = theme.text
	local dark = state.theme == "dark"
	clock.TextColor3 = (appArea.Visible and not dark) and C(20, 20, 24) or C(255, 255, 255)
	signal.TextColor3 = clock.TextColor3
	indicator.BackgroundColor3 = (appArea.Visible and not dark) and C(20, 20, 24) or C(255, 255, 255)
end

function api.setWallpaper(i)
	state.wallpaper = i
	paintChrome()
end

local function goHome()
	appArea.Visible = false
	for _, a in pairs(apps) do
		if a.page then
			a.page.Visible = false
		end
	end
	state.current = nil
	paintChrome()
end

function api.open(id)
	local a = apps[id]
	if not a then
		return
	end
	if not a.page then
		a.page = UI.frame(pages, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
		a.handle = a.def.build(a.page, api) or {}
	end
	for _, other in pairs(apps) do
		if other.page then
			other.page.Visible = other == a
		end
	end
	title.Text = a.def.name
	appArea.Visible = true
	state.current = id
	paintChrome()
	if a.handle.refresh then
		task.spawn(a.handle.refresh)
	end
end

-- Theme change: rebuild app pages in the new colours.
function api.setTheme(name)
	state.theme = name
	local current = state.current
	for _, a in pairs(apps) do
		if a.page then
			a.page:Destroy()
			a.page, a.handle = nil, nil
		end
	end
	paintChrome()
	if current then
		api.open(current)
	end
end

---------------------------------------------------------------------------
-- Home screen icons
---------------------------------------------------------------------------
for i, def in ipairs(APPS) do
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.Text = ""
	b.LayoutOrder = i
	b.Parent = grid
	local tile = UI.frame(b, { Size = UDim2.fromOffset(56, 56), BackgroundColor3 = def.colour })
	UI.corner(tile, 15)
	UI.text(tile, def.icon, 28, C(255, 255, 255), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	UI.text(b, def.name, 11, C(255, 255, 255), { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(-6, 58), Size = UDim2.fromOffset(68, 16), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5 })
	local badge = UI.text(tile, "", 11, C(255, 255, 255), {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 0, BackgroundColor3 = C(230, 50, 50), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
	})
	UI.corner(badge, 10)
	apps[def.id] = { def = def, button = b, badge = badge }
	b.Activated:Connect(function()
		api.open(def.id)
	end)
end

---------------------------------------------------------------------------
-- Open, close, keys
---------------------------------------------------------------------------
local function refreshHome()
	local r = api.request("home.get")
	if r.ok then
		state.balance = r.balance
		homeLine.Text = "Balance  " .. UI.money(r.balance) .. (r.savingOff and "   ·   saving off" or "")
		api.setUnread(r.unread)
	end
	return r
end

local function setOpen(open)
	state.open = open
	local viewport = Workspace.CurrentCamera.ViewportSize
	fit.Scale = math.clamp((viewport.Y - 110) / H, 0.55, 1)
	if open then
		phone.Visible = true
		TweenService:Create(phone, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(1, -20, 1, -84) }):Play()
		task.spawn(refreshHome)
		if state.current then
			api.open(state.current)
		end
	else
		local tween = TweenService:Create(phone, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.new(1, -20, 1, H + 40) })
		tween:Play()
		tween.Completed:Connect(function()
			if not state.open then
				phone.Visible = false
			end
		end)
	end
end

openButton.Activated:Connect(function()
	setOpen(not state.open)
end)
back.Activated:Connect(goHome)
indicator.Activated:Connect(goHome)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.P then
		setOpen(not state.open)
	end
end)

---------------------------------------------------------------------------
-- Pushes from the server
---------------------------------------------------------------------------
local bannerToken = 0
local bannerItem = nil
bannerTap.Activated:Connect(function()
	if bannerItem and bannerItem.app then
		setOpen(true)
		api.open(bannerItem.app)
	end
end)
local function showBanner(item)
	bannerToken += 1
	local token = bannerToken
	local def = item.app and apps[item.app] and apps[item.app].def
	bannerIcon.Text = def and def.icon or "🔔"
	bannerTitle.Text = item.title
	bannerBody.Text = item.body
	banner.Visible = true
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 0, 56) }):Play()
	bannerItem = item
	task.delay(4.5, function()
		if token == bannerToken then
			local t = TweenService:Create(banner, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 0, -90) })
			t:Play()
		end
	end)
end

Push.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then
		return
	end
	if msg.type == "bank" then
		state.balance = msg.balance
		homeLine.Text = "Balance  " .. UI.money(msg.balance)
	elseif msg.type == "notify" then
		if not (state.open and state.current == "notifications") then
			api.setUnread(state.unread + 1)
		end
		if not msg.silent then
			showBanner(msg.item)
		end
	elseif msg.type == "open" then
		setOpen(true)
		api.open(msg.app)
	end
	for _, fn in ipairs(pushListeners[msg.type] or {}) do
		task.spawn(fn, msg)
	end
end)

---------------------------------------------------------------------------
-- Clock, and first load of settings
---------------------------------------------------------------------------
task.spawn(function()
	while true do
		local h = Lighting.ClockTime
		local text = string.format("%02d:%02d", math.floor(h), math.floor((h % 1) * 60))
		clock.Text = text
		bigClock.Text = text
		task.wait(0.5)
	end
end)

task.spawn(function()
	for _ = 1, 30 do
		local r = refreshHome()
		if r.ok then
			state.theme = r.theme == "light" and "light" or "dark"
			state.wallpaper = r.wallpaper or 1
			break
		end
		task.wait(2)
	end
	paintChrome()
end)
paintChrome()
