--!strict
-- How each car family drives in a run (outline section 07). PROTOTYPE values for Stage 1: the
-- car catalog (Lane 2, src/shared/Catalog) will own the final per-car numbers once it exists;
-- these stay as the family defaults the run falls back to. Sizes are scale-proxy sizes in studs
-- (the Puglet reference is about 12.5 long), not finished cars, which Brian L owns.

local RunConfig = require(script.Parent.RunConfig)

export type FamilyName = "Compact" | "Sedan" | "Pickup" | "Van" | "Sports" | "Motorcycle" | "Truck" | "Special"

export type Family = {
	name: FamilyName,
	quirk: string,
	heatCapacity: number, -- seconds from 0 to 100% Heat while ridden
	steerSpeed: number, -- sideways studs per second at full steer
	speedMultiplier: number, -- times the run speed while ridden
	hopRange: number, -- studs
	length: number,
	width: number,
	height: number,
	ignoresPotholes: boolean,
	smashesConstruction: boolean,
	bumpHeatMultiplier: number,
	openTop: boolean, -- the rider stays visible
	weight: number, -- relative spawn weight in traffic
}

local Families = {}

local LIST: { Family } = {
	{
		name = "Compact",
		quirk = "Nimble",
		heatCapacity = 7,
		steerSpeed = 36,
		speedMultiplier = 1,
		hopRange = 30,
		length = 11,
		width = 5.4,
		height = 4.6,
		ignoresPotholes = false,
		smashesConstruction = false,
		bumpHeatMultiplier = 1,
		openTop = false,
		weight = 5,
	},
	{
		name = "Sedan",
		quirk = "Steady",
		heatCapacity = 9,
		steerSpeed = 30,
		speedMultiplier = 1,
		hopRange = 30,
		length = 13,
		width = 5.8,
		height = 4.4,
		ignoresPotholes = false,
		smashesConstruction = false,
		bumpHeatMultiplier = 1,
		openTop = false,
		weight = 6,
	},
	{
		name = "Pickup",
		quirk = "Rugged",
		heatCapacity = 9,
		steerSpeed = 24,
		speedMultiplier = 0.97,
		hopRange = 30,
		length = 14,
		width = 6.2,
		height = 5.2,
		ignoresPotholes = true,
		smashesConstruction = false,
		bumpHeatMultiplier = 1,
		openTop = false,
		weight = 4,
	},
	{
		name = "Van",
		quirk = "Cool Runner",
		heatCapacity = 13,
		steerSpeed = 19,
		speedMultiplier = 0.95,
		hopRange = 30,
		length = 15,
		width = 6.4,
		height = 7,
		ignoresPotholes = false,
		smashesConstruction = false,
		bumpHeatMultiplier = 1,
		openTop = false,
		weight = 3,
	},
	{
		name = "Sports",
		quirk = "Long Jump",
		heatCapacity = 8,
		steerSpeed = 32,
		speedMultiplier = 1.06,
		hopRange = 45,
		length = 13,
		width = 6,
		height = 3.6,
		ignoresPotholes = false,
		smashesConstruction = false,
		bumpHeatMultiplier = 1,
		openTop = false,
		weight = 3,
	},
	{
		name = "Motorcycle",
		quirk = "Slipstream",
		heatCapacity = 8,
		steerSpeed = 34,
		speedMultiplier = 1.04,
		hopRange = 30,
		length = 6.5,
		width = 2.4,
		height = 4.4,
		ignoresPotholes = false,
		smashesConstruction = false,
		bumpHeatMultiplier = 1.5,
		openTop = true,
		weight = 2,
	},
	{
		name = "Truck",
		quirk = "Plow",
		heatCapacity = 11,
		steerSpeed = 16,
		speedMultiplier = 0.92,
		hopRange = 24,
		length = 22,
		width = 7.2,
		height = 8.5,
		ignoresPotholes = false,
		smashesConstruction = true,
		bumpHeatMultiplier = 1,
		openTop = false,
		weight = 2,
	},
	{
		name = "Special",
		quirk = "Magnet",
		heatCapacity = 10,
		steerSpeed = 30,
		speedMultiplier = 1,
		hopRange = 30,
		length = 13,
		width = 6,
		height = 4.4,
		ignoresPotholes = false,
		smashesConstruction = false,
		bumpHeatMultiplier = 1,
		openTop = false,
		weight = 1,
	},
}

local BY_NAME: { [string]: Family } = {}
for _, family in LIST do
	BY_NAME[family.name] = table.freeze(family)
end

Families.LIST = table.freeze(LIST)
Families.LOANER = "Compact"
-- Legendaries live in the Special slot (decision 0010 answers).
Families.LEGENDARY_FAMILY = "Special"

function Families.get(name: string): Family
	local family = BY_NAME[name]
	assert(family, "unknown car family " .. name)
	return family
end

-- True when a car of this family and rarity can always be claimed with Heat to spare.
function Families.allows(family: Family, rarity: RunConfig.Rarity): boolean
	if rarity == "Legendary" then
		return family.name == Families.LEGENDARY_FAMILY
	end
	return RunConfig.KEYS_TIME[rarity] + RunConfig.HEAT_TO_SPARE <= family.heatCapacity
end

return table.freeze(Families)
