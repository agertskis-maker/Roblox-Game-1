--!strict
-- Anchors.PaintParts (Round 8, C-04): per-car data keyed by the car model name under ReplicatedStorage.Cars (Normal edition name;
-- Gold, Diamond and Rainbow editions share it unless a key of their own exists). Shape frozen in
-- vault/design/specs/lane3-round8-contracts.md; only the owning workstream edits this file.
--
-- Every showroom car is one body mesh (`body_geom`: panels, windows, lights and chrome share its single texture) plus four wheel
-- meshes; the Pizza Runner also has a roof rack and two pizza-sign boards. Only `body_geom` takes paint, and only where its mask says
-- "body" (BodyPaint + PaintMasks: windows, windshield, rear window, lights, tyres, rims, grille, chrome, interior, plate stay
-- unpainted). Every other mesh is listed under `never` and is never touched: wheels (tyres and rims), the roof rack, the pizza sign.
-- `mask` is the PaintMasks key. Gold and Diamond use the Normal car's mask (same mesh); each Rainbow edition has its own mask
-- (its own mesh and texture), so its entry names it.
local Types = require(script.Parent.Types)

local CARS = {
	"Apex",
	"Beach Bug",
	"Bolt",
	"Brawler",
	"Commuter",
	"Cruiser",
	"Desert King",
	"Executive",
	"Family Hauler",
	"Minnow",
	"Monarch",
	"Night Rider",
	"Old Faithful",
	"Phantom",
	"Pizza Runner",
	"Putter",
	"Rally Dog",
	"Rustbucket",
	"Street Kid",
	"Sunny Camper",
	"Surf Wagon",
	"Thunder",
	"Trailblazer",
	"Velvet",
	"Viper Strike",
	"Workhorse",
	"Zip",
}

local WHEELS = { "front left wheel_geom", "front right wheel_geom", "rear left wheel_geom", "rear right wheel_geom" }
local PIZZA_TRUCK_EXTRAS = { "roof_rack", "pizza", "pizza_back" }

local function entry(mask: string, extras: { string }?): Types.PaintParts
	local never = table.clone(WHEELS)
	for _, name in extras or {} do
		table.insert(never, name)
	end
	return table.freeze({ body = table.freeze({ "body_geom" }), never = table.freeze(never), mask = mask })
end

local data: { [string]: Types.PaintParts } = {}
for _, name in CARS do
	local extras = if name == "Pizza Runner" then PIZZA_TRUCK_EXTRAS else nil
	data[name] = entry(name, extras)
	data["Rainbow " .. name] = entry("Rainbow " .. name, extras)
end

return table.freeze(data)
