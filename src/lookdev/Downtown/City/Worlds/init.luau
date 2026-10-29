--!strict
-- WORLDS (Lane 3 preview, Round 2, R2-W1): data for the three Worlds that share ONE city method. A World is data, not a fork
-- of the planner: the same road template (4 lanes x 17, shoulders, the same road meshes and joins), the same deterministic
-- Sequencer and Assembler, the same validators. What a World supplies:
--   districts   five named stations (ids are Icons2 "District_<id>" art names) with explicit, unequal fixture lengths
--   lots        roadside set-pieces (for Dusty Highway and Summit Pass: rock masses, cactus groups, chalets, pines...); they
--               are ordinary frontage modules, so the planner's bags, repeat rules, treatments and sign spacing apply
--   landmarks   tier A (must appear in a chase) and tier B (kit gallery only), original and fictional
--   props, signs, masses (midground and skyline kit meshes), hazard meshes, the ground and the light
-- Downtown keeps its own built-in catalogue (Catalog.load); Worlds.get("Downtown") only carries its identity.
--
--   Worlds.ids -> { "Downtown", "DustyHighway", "SummitPass" }
--   Worlds.get(id) -> WorldDef?                  Worlds.catalog(id, options?) -> Catalog
--   Worlds.sequencerOptions(id, options?)        -- the planner options a World wants (route length, landmark spacing)
--   Worlds.check(plan, def) -> WorldChecks       -- coverage, sign spacing, joins, length, hazard classification

local Catalog = require(script.Parent.Catalog)

local Worlds = {}

export type Lighting = {
	props: { [string]: any }, -- Lighting properties (same keys as Assembler's daylight)
	atmosphere: { density: number, offset: number, colour: Color3, decay: Color3, haze: number },
	grade: { brightness: number, contrast: number, saturation: number, tint: Color3 },
}

export type WorldDef = {
	id: string,
	name: string,
	colour: Color3, -- the route line colour on the HUD
	prefix: string, -- kit mesh name prefix
	paletteColumn: string, -- swatches column for this World's meshes
	ground: Color3,
	lighting: Lighting?,
	districts: { Catalog.District },
	lots: { Catalog.LotModule },
	landmarks: { Catalog.Landmark },
	props: { [string]: string },
	signs: { string },
	midMeshes: { [string]: { string } },
	skyMeshes: { string },
	hazardMeshes: { [string]: string },
	under: { name: string, colour: Color3 }?, -- the flat floor strip under a bridge landmark (a canyon wash, an ice crevasse)
	tierA: { string }, -- landmark ids that a chase must show
	tierB: { string }, -- landmark ids kept as a labelled kit gallery
	landmarkSpacing: { number },
	length: number, -- route length asked of the planner (studs)
}

local modules: { [string]: string } = { DustyHighway = "DustyHighway", SummitPass = "SummitPass" }

Worlds.ids = table.freeze({ "Downtown", "DustyHighway", "SummitPass" })

local DOWNTOWN: { id: string, name: string, colour: Color3 } = {
	id = "Downtown",
	name = "Downtown",
	colour = Color3.fromRGB(52, 168, 255),
}

function Worlds.get(id: string): WorldDef?
	if id == "Downtown" then
		return nil -- Downtown uses the built-in catalogue; see Worlds.identity
	end
	local name = modules[id]
	if not name then
		return nil
	end
	local module = script:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	return (require :: any)(module) :: WorldDef
end

function Worlds.identity(id: string): { id: string, name: string, colour: Color3 }?
	if id == "Downtown" then
		return DOWNTOWN
	end
	local def = Worlds.get(id)
	if def then
		return { id = def.id, name = def.name, colour = def.colour }
	end
	return nil
end

function Worlds.catalog(id: string, options: Catalog.LoadOptions?): Catalog.Catalog
	local def = Worlds.get(id)
	if def then
		return Catalog.forWorld(def, options)
	end
	return Catalog.load(options)
end

function Worlds.sequencerOptions(id: string, options: { [string]: any }?): any
	local out: { [string]: any } = if options then table.clone(options) else {}
	local def = Worlds.get(id)
	if def then
		out.length = out.length or def.length
		out.landmarkSpacing = out.landmarkSpacing or def.landmarkSpacing
	end
	return out
end

-- Pure checks of a planned World (R2-W1, R2-W2, R2-DH1, R2-SP1): all five districts present, every tier A landmark planned
-- at least once, no sign name twice inside the sign gap, the route at least 3,000 studs, segment joins exact, and no
-- Gap hazard in the main route (gaps belong to a marked test area only).
export type WorldChecks = {
	passed: boolean,
	routeLength: number,
	atLeast3000: boolean,
	districtsPresent: { string },
	allDistrictsPresent: boolean,
	tierACoverage: { [string]: number },
	missingTierA: { string },
	signGapMin: number,
	signRepeatsInGap: number,
	segmentJoinError: number,
	hazardKinds: { string },
	gapsInRoute: number,
	notes: { string },
}

function Worlds.check(plan: any, def: WorldDef, signGap: number): WorldChecks
	local notes: { string } = {}
	local present: { [string]: boolean } = {}
	for _, d in plan.districts do
		present[d.id] = true
	end
	local ids: { string } = {}
	local all = true
	for _, d in def.districts do
		if present[d.id] then
			table.insert(ids, d.id)
		else
			all = false
			table.insert(notes, "district not planned: " .. d.id)
		end
	end
	local coverage: { [string]: number } = {}
	for _, id in def.tierA do
		coverage[id] = 0
	end
	for _, lm in plan.landmarks do
		if coverage[lm.id] ~= nil then
			coverage[lm.id] += 1
		end
	end
	local missing: { string } = {}
	for _, id in def.tierA do
		if coverage[id] == 0 then
			table.insert(missing, id)
		end
	end
	local minGap = math.huge
	local repeats = 0
	local signs = plan.signs
	for i = 1, #signs do
		for j = i + 1, #signs do
			local a, b = signs[i], signs[j]
			local gap = math.abs(a.station - b.station)
			if a.text == b.text then
				minGap = math.min(minGap, gap)
				if gap < signGap then
					repeats += 1
				end
			end
		end
	end
	local kinds: { string } = {}
	local seen: { [string]: boolean } = {}
	local gaps = 0
	for _, h in plan.hazards do
		if not seen[h.kind] then
			seen[h.kind] = true
			table.insert(kinds, h.kind)
		end
		if h.kind == "gap" then
			gaps += 1
		end
	end
	table.sort(kinds)
	local joins = plan.checks.segmentJoinError
	local passed = plan.length >= 3000 and all and #missing == 0 and repeats == 0 and joins < 0.01 and gaps == 0
	return {
		passed = passed,
		routeLength = plan.length,
		atLeast3000 = plan.length >= 3000,
		districtsPresent = ids,
		allDistrictsPresent = all,
		tierACoverage = coverage,
		missingTierA = missing,
		signGapMin = if minGap == math.huge then -1 else minGap,
		signRepeatsInGap = repeats,
		segmentJoinError = joins,
		hazardKinds = kinds,
		gapsInRoute = gaps,
		notes = notes,
	}
end

return Worlds
