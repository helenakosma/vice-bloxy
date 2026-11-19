-- Image asset IDs for the textures in assets/textures/ (made by tools/make_textures.py).
-- Import the PNGs with Studio's Asset Manager (Bulk Import), then paste each image's
-- ID here. 0 means "not imported yet": the game still works, those surfaces just
-- fall back to plain Roblox materials.
local IDS = {
	-- Walls and ground (tiling)
	brick_red = 70966059680467,
	brick_brown = 111604452120576,
	limestone = 82749085056632,
	concrete_stained = 137317764653561,
	sidewalk_slabs = 98766175641347,
	grime_streaks = 99887543194801,
	-- Windows
	window_curtains = 112604612872880,
	window_blinds = 90546844493505,
	window_dark = 81182553672568,
	window_room = 107312652903053,
	-- Shops and interiors
	shop_shelves = 79222171774814,
	shop_fridge = 104735715431864,
	storefront_deli = 133872506806806,
	storefront_boutique = 75945058953598,
	menu_board = 111461983222793,
	poster_cola = 82915596131830,
	poster_radio = 111016253066339,
	-- Road and street
	manhole = 78766887763886,
	drain_grate = 121089446074384,
	arrow_straight = 135096451964861,
	arrow_left = 80509127660169,
	arrow_right = 91731584429114,
	stop_sign = 135912795634322,
	-- Billboards
	billboard_phone = 118486983548512,
	billboard_burger = 91739838983443,
	-- Night
	night_windows = 88258553581733,
}

local Assets = {}

-- Every imported texture as { name, "rbxassetid://..." } (used to check they load).
function Assets.all()
	local out = {}
	for name, id in pairs(IDS) do
		if id ~= 0 then
			table.insert(out, { name, "rbxassetid://" .. tostring(id) })
		end
	end
	return out
end

-- "rbxassetid://..." for a texture name, or nil if it hasn't been imported.
function Assets.get(name)
	local id = IDS[name]
	if id and id ~= 0 then
		return "rbxassetid://" .. tostring(id)
	end
	return nil
end

return Assets
