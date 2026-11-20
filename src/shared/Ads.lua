-- The city's advertising: made-up brands for billboards, station screens and train
-- ads. Shared so the server can build ad faces and every client can rotate them
-- in sync (see client/AdRotator.client.lua).
--
-- Each ad: { headline, tagline, background, text colour, accent }
local C = Color3.fromRGB

local Ads = {}

Ads.list = {
	-- Food and drink
	{ "BLOXY COLA", "TASTE THE CITY", C(200, 24, 34), C(255, 255, 255), C(255, 214, 80) },
	{ "CLUCK HOUSE", "24 PIECE BUCKET  $9.99", C(250, 196, 40), C(150, 30, 20), C(150, 30, 20) },
	{ "GRIND COFFEE", "FUEL FOR THE COMMUTE", C(70, 44, 30), C(250, 230, 200), C(220, 160, 90) },
	{ "FROSTY'S", "SOFT SERVE · OPEN LATE", C(120, 210, 230), C(220, 30, 120), C(255, 255, 255) },
	{ "PHO KING ST.", "NOODLES · KING & SPADINA", C(30, 110, 90), C(255, 240, 200), C(250, 200, 60) },
	{ "NONNA'S", "FRESH PASTA DAILY · LITTLE ITALY", C(240, 230, 210), C(150, 30, 30), C(40, 120, 60) },
	{ "TACO TUNNEL", "$2 TUESDAYS", C(250, 120, 30), C(40, 20, 10), C(255, 240, 200) },
	-- Shopping
	{ "METRO THREADS", "NEW SEASON · NOW IN STORE", C(20, 20, 24), C(255, 255, 255), C(230, 60, 120) },
	{ "NORTHSTAR OUTFITTERS", "BUILT FOR WINTER", C(40, 60, 90), C(255, 255, 255), C(200, 220, 255) },
	{ "NOVA X", "THE PHONE THAT GETS YOU", C(18, 24, 48), C(120, 220, 255), C(255, 255, 255) },
	-- Places and services
	{ "MAPLE TRUST", "BANKING THAT GROWS", C(20, 110, 70), C(255, 255, 255), C(200, 240, 200) },
	{ "SUNSET TOWERS", "NOW LEASING · FROM $1,899", C(255, 140, 90), C(40, 20, 60), C(255, 255, 255) },
	{ "HARBOURVIEW LOFTS", "2 BED FROM $2,450 · BOOK A TOUR", C(30, 50, 80), C(255, 255, 255), C(250, 190, 90) },
	{ "VICE CITY U", "APPLY FOR FALL · FIND YOUR FUTURE", C(90, 20, 40), C(255, 255, 255), C(250, 200, 60) },
	{ "QUICKDROP", "DELIVERY IN 20 MIN OR IT'S FREE", C(255, 210, 20), C(20, 20, 20), C(20, 20, 20) },
	{ "LIBERTY TAXI", "ONE TAP. ANYWHERE.", C(255, 210, 20), C(20, 20, 20), C(20, 20, 20) },
	{ "VELOCITY MOTORS", "0-60 IN 2.9", C(16, 16, 18), C(255, 70, 50), C(240, 240, 240) },
	{ "BLOX BET? NO.", "SAVE YOUR CASH · CITY CREDIT UNION", C(240, 240, 236), C(30, 60, 140), C(200, 30, 40) },
	-- Nights out
	{ "NEON NIGHTS", "LIVE  ·  FRI & SAT", C(30, 10, 40), C(255, 60, 200), C(80, 240, 255) },
	{ "CLUB AFTERGLOW", "DOORS 10PM · NO COVER BEFORE 11", C(10, 10, 20), C(255, 120, 230), C(120, 240, 255) },
	{ "RADIO 6IX  99.1", "THE CITY'S HITS", C(110, 30, 160), C(255, 255, 255), C(255, 120, 220) },
	{ "SUMMER JAM", "WATERFRONT STAGE · AUG 14", C(255, 90, 60), C(255, 255, 255), C(255, 230, 120) },
	{ "THE GRAND", "NOW PLAYING · MIDNIGHT HEIST", C(20, 16, 14), C(240, 200, 120), C(200, 40, 40) },
	{ "STADIUM 6", "GAME NIGHT · TICKETS ON SALE", C(20, 40, 120), C(255, 255, 255), C(250, 70, 60) },
}

-- The ad a panel shows at server time `t`: everyone sees the same one, and it
-- changes every `interval` seconds. `seed` keeps neighbouring panels different.
function Ads.at(seed, t, interval)
	local index = (seed + math.floor(t / interval)) % #Ads.list + 1
	return Ads.list[index], index
end

return Ads
