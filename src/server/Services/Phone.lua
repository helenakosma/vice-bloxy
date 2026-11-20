-- Server side of the phone's Milestone 1 apps: home screen, Bank, Profile,
-- Settings and Notifications. Everything here reads or changes the player's own
-- profile; the client only ever asks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Settings = require(ReplicatedStorage.Shared.Economy)
local PlayerData = require(script.Parent.PlayerData)
local Router = require(script.Parent.Router)
local TorontoLayout = require(script.Parent.Parent.World.TorontoLayout)

local Phone = {}

local WALLPAPERS = 6

-- "BLOOR-YONGE" -> "Bloor-Yonge"
local function nice(name)
	return (name:lower():gsub("(%a)([%w']*)", function(a, b)
		return a:upper() .. b
	end))
end

-- Where the player is, as a neighbourhood name.
local function neighbourhood(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return "Unknown"
	end
	local p = root.Position
	if p.Z < -800 and math.abs(p.X - TorontoLayout.YONGE_X) < 1300 then
		local best, bestD = nil, math.huge
		for _, s in ipairs(TorontoLayout.STATIONS) do
			local d = math.abs(p.Z - s.z)
			if d < bestD then
				best, bestD = s.name, d
			end
		end
		return nice(best) .. ", Toronto"
	elseif p.X > 1100 then
		return "Vice Beach"
	elseif p.Z > 700 then
		return "Port Lands"
	elseif p.X < -700 then
		return "The Suburbs"
	end
	return "Downtown"
end

local function unread(data)
	local n = 0
	for _, item in ipairs(data.inbox) do
		if not item.read then
			n += 1
		end
	end
	return n
end

-- Filters free text the player wants to show to others (their bio).
local function filter(player, text)
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if ok then
		return result
	end
	return nil
end

function Phone.start()
	Router.on("home.get", function(player)
		local data = PlayerData.get(player)
		return {
			balance = data.money.balance,
			unread = unread(data),
			wallpaper = data.phone.wallpaper,
			theme = data.phone.theme,
			savingOff = PlayerData.isGuest(player),
		}
	end)

	Router.on("bank.get", function(player)
		local data = PlayerData.get(player)
		-- Totals for the last in-game week (24 real minutes x 7).
		local since = os.time() - 24 * 60 * 7
		local income, spent = 0, 0
		for _, e in ipairs(data.money.ledger) do
			if e.t >= since then
				if e.a > 0 then
					income += e.a
				else
					spent -= e.a
				end
			end
		end
		return {
			balance = data.money.balance,
			ledger = data.money.ledger,
			income = income,
			spent = spent,
			card = data.transit.card and data.transit.balance or nil,
		}
	end)

	Router.on("profile.get", function(player)
		local data = PlayerData.get(player)
		local job = data.employment.current
		local degrees = #data.education.degrees
		return {
			userId = player.UserId,
			username = player.Name,
			displayName = player.DisplayName,
			joined = data.identity.joined,
			bio = data.identity.bio,
			privacy = data.identity.privacy,
			neighbourhood = neighbourhood(player),
			occupation = job and job.title or "Looking for work",
			education = degrees > 0 and (degrees .. " degree" .. (degrees > 1 and "s" or "")) or "No degree yet",
			home = data.housing.lease and data.housing.lease.name or "No home yet",
			transitCard = data.transit.card and data.transit.balance or nil,
			achievements = data.achievements,
		}
	end)

	Router.on("profile.setBio", function(player, args)
		if type(args.bio) ~= "string" then
			return nil, "Bad bio"
		end
		local text = args.bio:sub(1, Settings.BioMaxLength):gsub("[\r\n]+", " ")
		local filtered = filter(player, text)
		if not filtered then
			return nil, "Couldn't check your bio right now, try again"
		end
		PlayerData.get(player).identity.bio = filtered
		return { bio = filtered }
	end)

	Router.on("profile.setPrivacy", function(player, args)
		local privacy = PlayerData.get(player).identity.privacy
		if args.field == "profile" then
			if args.value ~= "public" and args.value ~= "connections" and args.value ~= "private" then
				return nil, "Bad value"
			end
			privacy.profile = args.value
		elseif args.field == "job" or args.field == "home" or args.field == "education" then
			if type(args.value) ~= "boolean" then
				return nil, "Bad value"
			end
			privacy[args.field] = args.value
		else
			return nil, "Unknown setting"
		end
		return { privacy = privacy }
	end)

	Router.on("settings.set", function(player, args)
		local phone = PlayerData.get(player).phone
		if args.wallpaper ~= nil then
			if type(args.wallpaper) ~= "number" or args.wallpaper % 1 ~= 0 or args.wallpaper < 1 or args.wallpaper > WALLPAPERS then
				return nil, "Bad wallpaper"
			end
			phone.wallpaper = args.wallpaper
		end
		if args.theme ~= nil then
			if args.theme ~= "dark" and args.theme ~= "light" then
				return nil, "Bad theme"
			end
			phone.theme = args.theme
		end
		if args.notify ~= nil then
			if type(args.notify) ~= "table" then
				return nil, "Bad setting"
			end
			for category, on in pairs(args.notify) do
				if phone.notify[category] ~= nil and type(on) == "boolean" then
					phone.notify[category] = on
				end
			end
		end
		return { phone = phone }
	end)

	Router.on("notify.list", function(player)
		return { inbox = PlayerData.get(player).inbox }
	end)

	Router.on("notify.readAll", function(player)
		for _, item in ipairs(PlayerData.get(player).inbox) do
			item.read = true
		end
		return {}
	end)

	Router.on("notify.clear", function(player)
		table.clear(PlayerData.get(player).inbox)
		return {}
	end)

	-- Welcome message the first time someone plays.
	PlayerData.onLoaded(function(player, data)
		if not data.achievements.welcome then
			data.achievements.welcome = os.time()
			task.delay(4, function()
				if player.Parent then
					require(script.Parent.Notify).send(player, {
						title = "Welcome to the city",
						body = "Press P to open your phone. Your money, profile and settings now save between visits.",
						app = "bank",
					})
				end
			end)
		end
	end)
end

return Phone
