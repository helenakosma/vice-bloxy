-- Things you can buy in shops. Data only: the server (Services/Shopping) and the
-- client (basket, receipts) both read it. Prices are tiers in Shared/Economy.lua
-- (Shopping.Prices), so the whole price list is balanced in one place.
--
--   id = { name, tier, kind, colour? }
--   kind: what it is in your hands and your inventory
--     wear      clothing and shoes (kept in your inventory)
--     carry     things you carry home (devices, books, beauty, accessories)
--     treat     food and drink (you hold it for a while, then it's gone)
local C = Color3.fromRGB

local Products = {}

Products.items = {
	-- Clothing
	tee = { name = "T-shirt", tier = "small", kind = "wear" },
	shirt = { name = "Button-up shirt", tier = "medium", kind = "wear" },
	hoodie = { name = "Hoodie", tier = "medium", kind = "wear" },
	jeans = { name = "Jeans", tier = "medium", kind = "wear" },
	dress = { name = "Dress", tier = "medium", kind = "wear" },
	jacket = { name = "Jacket", tier = "large", kind = "wear" },
	parka = { name = "Winter parka", tier = "premium", kind = "wear" },
	suit = { name = "Tailored suit", tier = "premium", kind = "wear" },
	tie = { name = "Silk tie", tier = "small", kind = "wear" },
	leggings = { name = "Leggings", tier = "medium", kind = "wear" },
	lingerie = { name = "Lingerie set", tier = "medium", kind = "wear" },
	cap = { name = "Cap", tier = "small", kind = "wear" },
	sneakers = { name = "Sneakers", tier = "large", kind = "wear" },
	boots = { name = "Boots", tier = "large", kind = "wear" },
	heels = { name = "Heels", tier = "large", kind = "wear" },
	-- Accessories
	handbag = { name = "Handbag", tier = "premium", kind = "carry" },
	backpack = { name = "Backpack", tier = "large", kind = "carry" },
	suitcase = { name = "Suitcase", tier = "premium", kind = "carry" },
	watch = { name = "Watch", tier = "premium", kind = "wear" },
	ring = { name = "Ring", tier = "luxury", kind = "wear" },
	necklace = { name = "Necklace", tier = "luxury", kind = "wear" },
	charm = { name = "Bracelet charm", tier = "medium", kind = "wear" },
	sunglasses = { name = "Sunglasses", tier = "large", kind = "wear" },
	glasses = { name = "Glasses", tier = "large", kind = "wear" },
	-- Tech
	phone = { name = "Smartphone", tier = "luxury", kind = "carry" },
	laptop = { name = "Laptop", tier = "luxury", kind = "carry" },
	tablet = { name = "Tablet", tier = "premium", kind = "carry" },
	earbuds = { name = "Wireless earbuds", tier = "large", kind = "carry" },
	phonecase = { name = "Phone case", tier = "small", kind = "carry" },
	charger = { name = "Charger", tier = "small", kind = "carry" },
	-- Beauty
	lipstick = { name = "Lipstick", tier = "small", kind = "carry" },
	perfume = { name = "Perfume", tier = "large", kind = "carry" },
	skincare = { name = "Skincare set", tier = "medium", kind = "carry" },
	soap = { name = "Handmade soap", tier = "tiny", kind = "carry" },
	candle = { name = "Scented candle", tier = "small", kind = "carry" },
	-- Books, toys, music
	book = { name = "Book", tier = "small", kind = "carry" },
	notebook = { name = "Notebook", tier = "tiny", kind = "carry" },
	toy = { name = "Toy", tier = "small", kind = "carry" },
	blindbox = { name = "Blind box figure", tier = "small", kind = "carry" },
	plush = { name = "Plush toy", tier = "small", kind = "carry" },
	vinyl = { name = "Vinyl record", tier = "small", kind = "carry" },
	-- Pharmacy and services
	vitamins = { name = "Vitamins", tier = "small", kind = "carry" },
	snacks = { name = "Snacks", tier = "tiny", kind = "treat" },
	water = { name = "Bottled water", tier = "tiny", kind = "treat" },
	-- Food and drink
	coffee = { name = "Coffee", tier = "tiny", kind = "treat", colour = C(120, 80, 50) },
	latte = { name = "Latte", tier = "tiny", kind = "treat", colour = C(200, 170, 130) },
	bubbletea = { name = "Bubble tea", tier = "tiny", kind = "treat", colour = C(214, 180, 140) },
	pastry = { name = "Pastry", tier = "tiny", kind = "treat", colour = C(214, 160, 90) },
	cookie = { name = "Cookie", tier = "tiny", kind = "treat", colour = C(190, 140, 80) },
	chocolate = { name = "Chocolates", tier = "small", kind = "treat", colour = C(80, 46, 30) },
	gelato = { name = "Gelato", tier = "tiny", kind = "treat", colour = C(240, 200, 210) },
	juice = { name = "Fresh juice", tier = "tiny", kind = "treat", colour = C(240, 150, 50) },
	popcorn = { name = "Popcorn", tier = "tiny", kind = "treat", colour = C(250, 220, 140) },
	pretzel = { name = "Pretzel", tier = "tiny", kind = "treat", colour = C(170, 110, 60) },
	meal = { name = "Meal", tier = "small", kind = "treat", colour = C(200, 120, 60) },
	burger = { name = "Burger combo", tier = "small", kind = "treat", colour = C(170, 100, 50) },
	pizza = { name = "Pizza slice", tier = "tiny", kind = "treat", colour = C(230, 170, 80) },
	sushi = { name = "Sushi box", tier = "small", kind = "treat", colour = C(240, 240, 236) },
	noodles = { name = "Ramen", tier = "small", kind = "treat", colour = C(230, 190, 120) },
}

function Products.get(id)
	return Products.items[id]
end

return Products
