--!strict
-- PLAYGROUND ONLY (Lane 3 Round 2, R2-R1). FIXTURE routes for the three Worlds: five stations each, with
-- explicit, UNEQUAL district lengths in metres. They are proposals for Lane 1 (the production route plan and
-- the stud-to-metre conversion are Brian R's), never equal spans invented by the HUD, and they are shown only
-- through the route line. District ids are Icons2 "District_<id>" art names; names and phone labels are
-- the presentation labels from the outline (v2) World table.
--
--   WorldRoutes.ids                      -- { "Downtown", "DustyHighway", "SummitPass" }
--   WorldRoutes.plan(id) -> DistrictPlan -- a fresh table each call (the store may keep it)
--   WorldRoutes.worlds[id] -> WorldInfo  -- id, name and the colour of the travelled line

local WorldRoutes = {}

WorldRoutes.ids = table.freeze({ "Downtown", "DustyHighway", "SummitPass" })

WorldRoutes.worlds = table.freeze({
	Downtown = table.freeze({ id = "Downtown", name = "Downtown", colour = Color3.fromRGB(52, 168, 255) }),
	DustyHighway = table.freeze({ id = "DustyHighway", name = "Dusty Highway", colour = Color3.fromRGB(255, 138, 36) }),
	SummitPass = table.freeze({ id = "SummitPass", name = "Summit Pass", colour = Color3.fromRGB(150, 130, 255) }),
})

local DISTRICTS: { [string]: { { id: string, name: string, short: string, length: number } } } = {
	Downtown = {
		{ id = "MainStreet", name = "Main Street", short = "Main St", length = 170 },
		{ id = "CityHall", name = "City Hall", short = "Hall", length = 150 },
		{ id = "HarborBridge", name = "Harbor Bridge", short = "Harbor", length = 135 },
		{ id = "Midtown", name = "Midtown", short = "Midtown", length = 190 },
		{ id = "SkylinePark", name = "Skyline Park", short = "Park", length = 160 },
	},
	DustyHighway = {
		{ id = "CactusFlats", name = "Cactus Flats", short = "Cactus", length = 165 },
		{ id = "DinerStrip", name = "Diner Strip", short = "Diner", length = 140 },
		{ id = "RedRockArches", name = "Red Rock Arches", short = "Arches", length = 185 },
		{ id = "CanyonBridge", name = "Canyon Bridge", short = "Canyon", length = 150 },
		{ id = "MirageDunes", name = "Mirage Dunes", short = "Dunes", length = 175 },
	},
	SummitPass = {
		{ id = "PineVillage", name = "Pine Village", short = "Pines", length = 150 },
		{ id = "SkiLiftRidge", name = "Ski Lift Ridge", short = "Lift", length = 195 },
		{ id = "FrozenLake", name = "Frozen Lake", short = "Lake", length = 135 },
		{ id = "GlacierTunnel", name = "Glacier Tunnel", short = "Glacier", length = 165 },
		{ id = "SummitLodge", name = "Summit Lodge", short = "Lodge", length = 180 },
	},
}

function WorldRoutes.plan(id: string): any
	local list = DISTRICTS[id] or DISTRICTS.Downtown
	local districts = {}
	for _, d in list do
		table.insert(districts, { id = d.id, name = d.name, short = d.short, length = d.length })
	end
	return {
		repeats = true,
		world = WorldRoutes.worlds[id] or WorldRoutes.worlds.Downtown,
		districts = districts,
	}
end

return WorldRoutes
