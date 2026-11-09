--!strict
-- ShopLook (Lane 3 Round 8, C-06 and C-07): what the Style Shop shows is always the player's SELECTED car in the player's look.
-- Pure data helpers over CarLook and StyleState, so every tile, the turntable and the "EQUIPPED ON" line agree.
--
--   ShopLook.baseCar(name) -> string               the Normal model of an edition ("Gold Pizza Runner" -> "Pizza Runner")
--   ShopLook.carTitle(name) -> string              "PIZZA RUNNER" for the line above the buttons
--   ShopLook.current(car, equipped, previewed?) -> Look      the worn look, with any items being tried on top
--   ShopLook.forTile(car, equipped, tab, item) -> Look       the worn look with this one tile's item in its slot
--   ShopLook.signature(car, equipped, tab) -> string         changes when a tile of `tab` would have to be redrawn

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarLook = require(ReplicatedStorage.Shared.Style.CarLook)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)

local ShopLook = {}

local EDITIONS = { "Gold ", "Diamond ", "Rainbow " }

function ShopLook.baseCar(name: string?): string
	local text = name or ""
	for _, prefix in EDITIONS do
		if string.sub(text, 1, #prefix) == prefix then
			return string.sub(text, #prefix + 1)
		end
	end
	return text
end

function ShopLook.carTitle(name: string?): string
	local text = string.upper(name or "")
	return if text == "" then "YOUR CAR" else text
end

local function merged(equipped: { [string]: any }, overrides: { [string]: string? }?): { [string]: any }
	local out: { [string]: any } = table.clone(equipped)
	if overrides then
		for tab, id in overrides do
			out[tab] = id
		end
	end
	return out
end

function ShopLook.current(car: string, equipped: { [string]: any }, previewed: { [string]: string? }?): CarLook.Look
	return CarLook.fromEquipped(ShopLook.baseCar(car), merged(equipped, previewed))
end

-- A tile shows the car in what the player already wears, with the tile's own item in its slot.
function ShopLook.forTile(car: string, equipped: { [string]: any }, tab: string, item: Catalog.Item): CarLook.Look
	return CarLook.fromEquipped(ShopLook.baseCar(car), merged(equipped, { [tab] = item.id }))
end

-- Paint tiles also wear the equipped decal and wheels (and the Decals tiles the equipped paint), so a redraw is only needed
-- when one of those, or the car, changes.
function ShopLook.signature(car: string, equipped: { [string]: any }, tab: string): string
	local look = CarLook.fromEquipped(ShopLook.baseCar(car), equipped)
	if tab == "Paint" then
		look.paint = nil
	elseif tab == "Decals" then
		look.decal = nil
	end
	look.trail = nil -- no tile shows a trail on a car
	return CarLook.key(look) .. "|" .. tab
end

return ShopLook
