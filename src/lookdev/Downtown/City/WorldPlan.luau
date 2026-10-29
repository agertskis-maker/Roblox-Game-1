--!strict
-- WORLD PLAN V2 (Lane 3 look-dev preview; Dusty Highway and Summit Pass build, decision 0026, Adam's approvals 2026-10-28).
-- Runs once, at the end of Sequencer.plan, ONLY for a World whose data has a `v2` table. It adds the layers the base planner
-- does not make (backdrop massifs, ridges, gorge walls, ground patches, edge pieces, groves, signs boards) as `plan.extras`,
-- and adjusts the base plan in the few places the approved plans ask for (frontage occupancy, an irregular pole rhythm, a
-- landmark's set-back and yaw, the later-lap welcome text). Everything is deterministic: each feature draws from its own
-- Random stream seeded by hash(seed, cycle, district order, feature salt), so a second cycle of a district is not a replay
-- of the first, the same seed still gives the same plan, and changing one feature never reshuffles another.
--
-- Pure maths and data: no instances. Scenery only: nothing here changes a road piece, a lane, a hazard or any gameplay
-- (a hazard is only READ, to keep scenery clear of it). Every number lives in the World's `v2` table, not here.
--
-- v2 table (all optional):
--   salt             number       mixed into every stream
--   subSeeds         boolean      the base planner's lot phase also uses per-district streams (Sequencer reads it)
--   replaceMasses    boolean      drop the base planner's midground and skyline masses (the rules below replace them)
--   occupancy        { [districtId]: number | { {t, v} } }   share of building lots kept (the rest become open ground)
--   poles            { [districtId]: { spacing = {min,max}, oneSide = boolean, every = number } }  replaces lamps + furniture
--   rules            { Rule }     scatter rules (see Rule)
--   gorge            Gorge        the true gorge under the bridge landmark
--   landmarks        { [id]: { setback = number, yaw = number } }
--   welcomeLater     string       text of the welcome span on cycles after the first
--   sizes            { [mesh]: Vector3 }  nominal sizes, used until the kit's own bounds are known (Catalog.sizes)

local Features = require(script.Parent.WorldFeatures)

local WorldPlan = {}

type Helpers = {
	frame: (number, number?, number?) -> CFrame,
	segAt: (number) -> number,
	spanAt: (number) -> number,
}

export type PoolEntry = { m: string, size: Vector3?, label: string?, class: string? }
export type Rule = {
	id: string, -- also the stream salt (a string, hashed)
	kind: string,
	band: string, -- "near" | "far"
	pool: { PoolEntry },
	density: { [string]: number }, -- per district: pieces per 100 studs of route, both sides together
	lateral: { number }, -- { min, max } offset of the pivot from the centre line
	scale: { number }?, -- { min, max } uniform scale (default 1, 1)
	yaw: string?, -- "quarter" (0/90/180/270) | "along" (long axis along the route) | "road" (faces the road)
	y: number?, -- pivot height (default -1: sunk a little into the ground slab, top -0.3)
	need: number?, -- clear distance from the route (default half road + 50)
	ignoreRoute: boolean?, -- skip the route-clearance test (flat ground patches, verge markers at a fixed offset)
	gap: number?, -- minimum studs between two pieces of this rule on one side
	recent: number?, -- a module is not repeated within this many picks on a side (default 2)
	reuseGap: number?, -- the same module is not used again within this many studs on a side
	hazardClear: boolean?, -- keep out of the 60 studs before and 10 after a hazard when the pivot is within 120 of the line
	hazardBefore: number?, -- studs before a hazard to keep clear instead of 60 (Summit's calm zone is 120)
	skipBridge: boolean?, -- never on a bridge deck span or inside the gorge (default true)
	colour: Color3?, -- proxy colour
	sides: string?, -- "both" (default) | "alternate" (one side per piece)
}
export type Gorge = {
	district: string,
	halfWidth: number,
	floorDepth: number,
	endPad: number,
	wall: { string },
	wallEnd: string?,
	pylon: string?,
	pylonEvery: number?,
}

-- hash(seed, cycle, district order, salt) -> a Random seed: the per-district sub-seed of the approved plans
local function seedFor(seed: number, cycle: number, order: number, salt: string | number): number
	local s = (seed * 2654435761 + cycle * 40503 + order * 9973) % 2147483647
	local text = tostring(salt)
	for i = 1, #text do
		s = (s * 31 + string.byte(text, i)) % 2147483647
	end
	return Random.new(s):NextInteger(1, 2147483646)
end
WorldPlan.seedFor = seedFor

local function curveAt(curve: any, t: number): number
	if type(curve) == "number" then
		return curve
	end
	local list = curve :: { { number } }
	if t <= list[1][1] then
		return list[1][2]
	end
	for i = 2, #list do
		if t <= list[i][1] then
			local a, b = list[i - 1], list[i]
			local k = (t - a[1]) / math.max(b[1] - a[1], 1e-6)
			return a[2] + (b[2] - a[2]) * k
		end
	end
	return list[#list][2]
end

local OUTWARD_FURNITURE =
	{ lamp = true, cactus = true, rock = true, barrel = true, fencePost = true, tree = true, bin = true, bench = true }

function WorldPlan.apply(plan: any, catalog: any, seed: number, h: Helpers)
	local world = catalog.world
	local v2 = world.v2
	local notes: { string } = {}
	local stats: { [string]: number } = {}
	local info: any = { notes = notes, stats = stats, gorges = {} :: { { [string]: any } } }
	plan.world = info
	local extras = plan.extras
	local halfRoad = plan.halfRoad
	local salt = v2.salt or 0
	local sizes: { [string]: Vector3 } = catalog.sizes or {}
	local nominal: { [string]: Vector3 } = v2.sizes or {}

	local function sizeOf(entry: PoolEntry): Vector3
		return sizes[entry.m] or nominal[entry.m] or entry.size or Vector3.new(30, 30, 30)
	end
	local function rngFor(span: any, feature: string): Random
		return Random.new(seedFor(seed, span.cycle, span.order, feature .. "#" .. salt))
	end

	-- route samples, hazards, landmarks, bridges ------------------------------------------------------
	local samples: { Vector3 } = {}
	do
		local st = -200
		while st <= plan.length + 200 do
			local p = h.frame(st).Position
			table.insert(samples, Vector3.new(p.X, 0, p.Z))
			st += 24
		end
	end
	local function clearOfRoute(position: Vector3, radius: number, need: number): boolean
		local flat = Vector3.new(position.X, 0, position.Z)
		for _, p in samples do
			if (p - flat).Magnitude < need + radius then
				return false
			end
		end
		return true
	end
	local function nearHazard(station: number, before: number, after: number): boolean
		for _, hz in plan.hazards do
			if station > hz.station - before and station < hz.station + hz.length + after then
				return true
			end
		end
		return false
	end
	local bridgeSpans: { { number } } = {}
	for _, seg in plan.segments do
		if seg.kind == "BridgeDeck" then
			local last = bridgeSpans[#bridgeSpans]
			if last and math.abs(last[2] - seg.startS) < 0.01 then
				last[2] = seg.endS
			else
				table.insert(bridgeSpans, { seg.startS, seg.endS })
			end
		end
	end

	-- 1. the gorge (computed first: every later rule keeps out of it) ----------------------------------
	local gorge: Gorge? = v2.gorge
	if gorge then
		for _, lm in plan.landmarks do
			if lm.placement == "bridge" and lm.district == gorge.district then
				local s0, s1 = lm.from - gorge.endPad, lm.to + gorge.endPad
				local mid = (s0 + s1) / 2
				local centre = h.frame(mid)
				local entry = {
					district = gorge.district,
					from = s0,
					to = s1,
					centre = centre,
					halfLength = (s1 - s0) / 2,
					halfWidth = gorge.halfWidth,
					floorY = -gorge.floorDepth,
				}
				table.insert(info.gorges, entry)
				-- the gorge walls: pieces chained along both edges, standing on the floor, tops at the rim
				for _, side in { -1, 1 } do
					local st = s0
					local k = 0
					while st < s1 - 8 do
						local name = gorge.wall[(k + (if side > 0 then 1 else 0)) % #gorge.wall + 1]
						local size = sizeOf({ m = name })
						local len = math.max(size.X, 24)
						local c = math.min(st + len / 2, s1 - 4)
						local sc = math.clamp((gorge.floorDepth + 1.5) / math.max(size.Y, 1), 0.8, 1.5)
						-- flush with the hole's edge: the pivot sits half the wall's depth beyond it
						local base = h.frame(c, side * (gorge.halfWidth + size.Z * sc / 2), -gorge.floorDepth - 0.5)
						-- the piece's long axis runs along the route; its front (local -Z) faces the gorge
						local cf = base * CFrame.Angles(0, if side > 0 then math.pi / 2 else -math.pi / 2, 0)
						table.insert(extras, {
							kind = "gorge",
							module = name,
							label = "GORGE WALL",
							cframe = cf,
							scale = sc,
							size = size * sc,
							colour = Color3.fromRGB(150, 76, 56),
							band = "near",
							segment = h.segAt(c),
							station = c,
							side = side,
							district = gorge.district,
						})
						st += len * 0.96
						k += 1
					end
				end
				if gorge.wallEnd then
					local size = sizeOf({ m = gorge.wallEnd })
					for _, end_ in { s0, s1 } do
						local sc = math.clamp((gorge.floorDepth + 1.5) / math.max(size.Y, 1), 0.8, 1.5)
						-- the end piece closes the gorge across its width; its front faces back into the gorge
						local back = if end_ == s0 then -1 else 1
						local base = h.frame(end_ + back * size.Z * sc / 2, 0, -gorge.floorDepth - 0.5)
						local cf = base * CFrame.Angles(0, if end_ == s0 then 0 else math.pi, 0)
						table.insert(extras, {
							kind = "gorge",
							module = gorge.wallEnd,
							label = "GORGE END",
							cframe = cf,
							scale = sc,
							size = size * sc,
							colour = Color3.fromRGB(150, 76, 56),
							band = "near",
							segment = h.segAt(end_),
							station = end_,
							side = 0,
							district = gorge.district,
						})
					end
				end
				if gorge.pylon then
					local size = sizeOf({ m = gorge.pylon })
					local every = gorge.pylonEvery or 96
					local st = s0 + 48
					while st < s1 - 24 do
						for _, side in { -1, 1 } do
							local cf = h.frame(st, side * (halfRoad + 1.6), -gorge.floorDepth - 0.5)
							table.insert(extras, {
								kind = "gorge",
								module = gorge.pylon,
								label = "BRIDGE PYLON",
								cframe = cf,
								scale = 1,
								size = size,
								colour = Color3.fromRGB(120, 110, 104),
								band = "near",
								segment = h.segAt(st),
								station = st,
								side = side,
								district = gorge.district,
							})
						end
						st += every
					end
				end
				stats.gorgeLength = s1 - s0
				stats.gorgeFloor = -gorge.floorDepth
				break
			end
		end
		if #info.gorges == 0 then
			table.insert(notes, "gorge: no bridge landmark planned in " .. gorge.district)
		end
	end
	local function inGorge(position: Vector3, margin: number): boolean
		for _, g in info.gorges do
			local rel = (g.centre :: CFrame):PointToObjectSpace(position)
			if math.abs(rel.X) <= g.halfWidth + margin and math.abs(rel.Z) <= g.halfLength + margin then
				return true
			end
		end
		return false
	end
	local function onBridge(station: number, pad: number): boolean
		for _, b in bridgeSpans do
			if station > b[1] - pad and station < b[2] + pad then
				return true
			end
		end
		return false
	end

	local ctx: Features.Ctx = {
		plan = plan,
		catalog = catalog,
		v2 = v2,
		h = h,
		extras = extras,
		info = info,
		halfRoad = halfRoad,
		sizeOf = function(entry: any): Vector3
			return sizeOf(entry :: PoolEntry)
		end,
		rngFor = rngFor,
		onBridge = onBridge,
		nearHazard = nearHazard,
		inGorge = inGorge,
	}

	-- 2. the base planner's masses are replaced by the scatter rules ---------------------------------
	if v2.replaceMasses then
		stats.massesDropped = #plan.masses
		plan.masses = {}
	end

	-- 3. frontage occupancy: a share of the building lots becomes open ground --------------------------
	if v2.occupancy then
		local converted = 0
		for _, span in plan.districts do
			local curve = v2.occupancy[span.id]
			if curve == nil then
				continue
			end
			local rng = rngFor(span, "occupancy")
			local run = { [-1] = 0, [1] = 0 }
			for _, lot in plan.lots do
				if lot.district ~= span.id or lot.station < span.startS or lot.station >= span.endS then
					continue
				end
				if lot.kind ~= "building" or lot.module == "GAP" then
					continue
				end
				local t = (lot.station - span.startS) / math.max(span.endS - span.startS, 1)
				local keep = curveAt(curve, t)
				-- never more than three open lots in a row on one side, so the openness has edges
				if rng:NextNumber() > keep and run[lot.side] < 3 then
					lot.module = "GAP"
					lot.kind = "gap"
					lot.sign = nil
					lot.signStyle = nil
					lot.shop = false
					lot.height = 0
					lot.finish = ""
					run[lot.side] += 1
					converted += 1
				else
					run[lot.side] = 0
				end
			end
		end
		-- the sign list follows the lots that kept their signs
		local keptSigns = {}
		for _, sg in plan.signs do
			local lot = plan.lots[sg.lot]
			if lot and lot.sign then
				table.insert(keptSigns, sg)
			end
		end
		plan.signs = keptSigns
		stats.lotsOpened = converted
	end

	-- 4. an irregular pole rhythm replaces the lamp-and-furniture metronome ---------------------------
	if v2.poles then
		local kept: { any } = {}
		for _, p in plan.props do
			local cfg = v2.poles[plan.districts[h.spanAt(p.station)].id]
			if cfg and OUTWARD_FURNITURE[p.kind] then
				continue
			end
			table.insert(kept, p)
		end
		local placed = 0
		for _, span in plan.districts do
			local cfg = v2.poles[span.id]
			if not cfg then
				continue
			end
			local rng = rngFor(span, "poles")
			local lampModule = catalog.props.lamp
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local st = span.startS + rng:NextNumber(cfg.spacing[1] * 0.4, cfg.spacing[1])
			local sinceFlip = 0
			while st < span.endS - 6 do
				local seg = plan.segments[h.segAt(st)]
				if seg.kind ~= "BridgeDeck" and not onBridge(st, 4) and not nearHazard(st, 40, 8) then
					local sides = if cfg.oneSide then { side } else { -1, 1 }
					for _, sd in sides do
						local at = h.frame(st, sd * (halfRoad + plan.kerb + 1.4))
						table.insert(kept, {
							kind = "lamp",
							module = lampModule,
							station = st,
							side = sd,
							cframe = CFrame.lookAt(at.Position, at.Position - sd * at.RightVector),
							segment = seg.index,
						})
						placed += 1
					end
				end
				local step = rng:NextNumber(cfg.spacing[1], cfg.spacing[2])
				st += step
				sinceFlip += step
				if cfg.every and sinceFlip >= cfg.every then
					side = -side
					sinceFlip = 0
				end
			end
		end
		table.sort(kept, function(a, b)
			return a.station < b.station
		end)
		plan.props = kept
		stats.poles = placed
	end

	-- 5. landmarks: a set-back and a yaw (the thick arch stands off the road, turned toward oncoming cars) -------
	if v2.landmarks then
		for _, lm in plan.landmarks do
			local cfg = v2.landmarks[lm.id]
			if cfg and lm.side ~= 0 and lm.placement == "frontage" then
				local pivot: CFrame = lm.pivot
				if cfg.setback and cfg.setback > 0 then
					pivot = pivot * CFrame.new(0, 0, cfg.setback)
				end
				if cfg.yaw and cfg.yaw ~= 0 then
					local centre = pivot * CFrame.new(lm.width / 2, 0, lm.depth / 2)
					pivot = centre
						* CFrame.Angles(0, math.rad(cfg.yaw) * lm.side, 0)
						* CFrame.new(-lm.width / 2, 0, -lm.depth / 2)
				end
				lm.pivot = pivot
			end
		end
	end

	-- 6. the scatter rules ------------------------------------------------------------------------------
	local function pick(
		rule: Rule,
		rng: Random,
		recent: { string },
		lastStation: { [string]: number },
		st: number
	): PoolEntry?
		local n = #rule.pool
		if n == 0 then
			return nil
		end
		local keep = rule.recent or 2
		for _ = 1, 8 do
			local entry = rule.pool[rng:NextInteger(1, n)]
			local last = lastStation[entry.m]
			local blocked = table.find(recent, entry.m) ~= nil and n > keep
			if rule.reuseGap and last and st - last < rule.reuseGap and n > 1 then
				blocked = true
			end
			if not blocked then
				return entry
			end
		end
		return rule.pool[rng:NextInteger(1, n)]
	end

	local placedBy: { [string]: number } = {}
	for _, rule in v2.rules or {} do
		local count = 0
		for _, span in plan.districts do
			local density = rule.density[span.id]
			if not density or density <= 0 then
				continue
			end
			local rng = rngFor(span, rule.id)
			local single = rule.sides == "alternate" or rule.sides == "outside" or rule.sides == "inside"
			local sideList: { number } = if rule.sides == "alternate"
				then { 0 }
				elseif rule.sides == "outside" then { Features.outsideSide(ctx, span) }
				elseif rule.sides == "inside" then { -Features.outsideSide(ctx, span) }
				else { -1, 1 }
			local perSide = density / (if single then 100 else 200) -- pieces per stud on one side
			local flip = if rng:NextNumber() < 0.5 then -1 else 1
			for _, sd in sideList do
				local recent: { string } = {}
				local lastStation: { [string]: number } = {}
				local lastPlaced = -math.huge
				local st = span.startS + rng:NextNumber(0, 1 / perSide)
				while st < span.endS do
					local side = if sd == 0 then flip else sd
					if sd == 0 then
						flip = -flip
					end
					local step = (1 / perSide) * rng:NextNumber(0.65, 1.35)
					local entry = pick(rule, rng, recent, lastStation, st)
					if entry then
						local size = sizeOf(entry)
						local sc = 1
						if rule.scale then
							sc = rng:NextNumber(rule.scale[1], rule.scale[2])
						end
						local lateral = rng:NextNumber(rule.lateral[1], rule.lateral[2])
						local station = st
						local f = h.frame(station, side * lateral, rule.y or -1)
						local yawRad = 0
						if rule.yaw == "quarter" then
							yawRad = rng:NextInteger(0, 3) * math.pi / 2
						elseif rule.yaw == "along" then
							yawRad = (if rng:NextNumber() < 0.5 then 1 else -1) * math.pi / 2
								+ math.rad(rng:NextNumber(-6, 6))
						elseif rule.yaw == "road" then
							yawRad = (if side > 0 then -math.pi / 2 else math.pi / 2)
								+ math.rad(rng:NextNumber(-10, 10))
						end
						local cf = f * CFrame.Angles(0, yawRad, 0)
						local radius = math.max(size.X, size.Z) * sc / 2
						local need = rule.need or (halfRoad + 50)
						local ok = rule.ignoreRoute == true or clearOfRoute(f.Position, radius, need)
						if
							ok
							and rule.skipBridge ~= false
							and (onBridge(station, radius) or inGorge(f.Position, radius + 16))
						then
							ok = false
						end
						if
							ok
							and rule.hazardClear
							and lateral < 120
							and nearHazard(station, (rule.hazardBefore or 60) + radius, 10 + radius)
						then
							ok = false
						end
						if ok and rule.gap and station - lastPlaced < rule.gap then
							ok = false
						end
						if ok then
							-- keep out of landmark footprints on the same side (within the near layers)
							for _, lm in plan.landmarks do
								if
									lm.side == side
									and lateral < 160
									and math.abs(station - lm.station) < lm.width / 2 + radius
								then
									ok = false
									break
								end
							end
						end
						if ok then
							table.insert(extras, {
								kind = rule.kind,
								module = entry.m,
								label = entry.label or rule.kind,
								cframe = cf,
								scale = sc,
								size = size * sc,
								colour = rule.colour or Color3.fromRGB(190, 120, 80),
								band = rule.band,
								segment = h.segAt(station),
								station = station,
								side = side,
								district = span.id,
							})
							lastPlaced = station
							lastStation[entry.m] = station
							table.insert(recent, entry.m)
							if #recent > (rule.recent or 2) then
								table.remove(recent, 1)
							end
							count += 1
						end
					end
					st += step
				end
			end
		end
		placedBy[rule.id] = count
		stats["rule:" .. rule.id] = count
	end

	-- 6b. the placement features: pins, chains, lake, tunnel, lift, companions (see WorldFeatures) -----------------
	Features.pins(ctx)
	Features.chains(ctx)
	Features.lake(ctx)
	Features.tunnel(ctx)
	Features.lift(ctx)
	Features.companions(ctx)

	-- 7. later laps carry a different welcome span (Summit Pass: "KEEP CLIMBING!") --------------------------
	if v2.welcomeLater then
		for _, sp in plan.spans do
			if sp.kind == "welcome" then
				local span = plan.districts[h.spanAt(sp.station)]
				if span and span.cycle > 1 then
					sp.text = v2.welcomeLater
				end
			end
		end
	end

	stats.extras = #extras
	table.sort(extras, function(a, b)
		return a.station < b.station
	end)
end

return WorldPlan
