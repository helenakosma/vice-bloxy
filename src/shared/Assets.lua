-- Image asset IDs for the textures in assets/textures/ (made by tools/make_textures.py).
-- Import the PNGs with Studio's Asset Manager (Bulk Import), then paste each image's
-- ID here. 0 means "not imported yet": the game still works, those surfaces just
-- fall back to plain Roblox materials.
local IDS = {
	-- Walls and ground (tiling)
	brick_red = 0,
	brick_brown = 0,
	limestone = 0,
	concrete_stained = 0,
	sidewalk_slabs = 0,
	grime_streaks = 0,
	-- Windows
	window_curtains = 0,
	window_blinds = 0,
	window_dark = 0,
	window_room = 0,
	-- Shops and interiors
	shop_shelves = 0,
	shop_fridge = 0,
	storefront_deli = 0,
	storefront_boutique = 0,
	menu_board = 0,
	poster_cola = 0,
	poster_radio = 0,
	-- Road and street
	manhole = 0,
	drain_grate = 0,
	arrow_straight = 0,
	arrow_left = 0,
	arrow_right = 0,
	stop_sign = 0,
	-- Billboards
	billboard_phone = 0,
	billboard_burger = 0,
}

local Assets = {}

-- "rbxassetid://..." for a texture name, or nil if it hasn't been imported.
function Assets.get(name)
	local id = IDS[name]
	if id and id ~= 0 then
		return "rbxassetid://" .. tostring(id)
	end
	return nil
end

return Assets
