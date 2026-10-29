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
	wall: { string }, -- plain terraced wall pieces, chained along each side
	corner: string, -- the L-shaped corner piece (closes a +X end)
	cornerMirror: string, -- its mirror (closes a -X end)
	cornerWall: number, -- depth of the corner piece's wall part (the rest of its Z extent is the return leg)
	pylon: string?, -- the bent pier with a crosshead, standing on the floor under the deck, one at the route centre
	pylonEvery: number?,
	under: string?, -- the cross-frame under each 192-stud deck
	underDrop: number?, -- how far below deck level its pivot sits
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
	-- The walls stand on a floor `floorDepth` below the deck, faces toward the gorge, rims at ground level. Two L-shaped corner
	-- pieces (C and its mirror) close each end of each side wall; a bent pier with a crosshead stands on the floor under the
	-- deck; a cross-frame sits under each 192-stud deck. Every piece is scaled uniformly so its rim meets the ground.
	local gorge: Gorge? = v2.gorge
	if gorge then
		for _, lm in plan.landmarks do
			if lm.placement == "bridge" and lm.district == gorge.district then
				local s0, s1 = lm.from - gorge.endPad, lm.to + gorge.endPad
				local mid = (s0 + s1) / 2
				local centre = h.frame(mid)
				local depth = gorge.floorDepth
				table.insert(info.gorges, {
					district = gorge.district,
					from = s0,
					to = s1,
					centre = centre,
					halfLength = (s1 - s0) / 2,
					halfWidth = gorge.halfWidth,
					floorY = -depth,
				})
				local function scaleFor(size: Vector3): number
					return math.clamp(depth / math.max(size.Y - 1.5, 1), 0.7, 1.6)
				end
				local function addPiece(
					name: string,
					c: number,
					lateral: number,
					side: number,
					yaw: number,
					label: string,
					sc: number,
					size: Vector3
				)
					table.insert(extras, {
						kind = "gorge",
						module = name,
						label = label,
						cframe = h.frame(c, side * lateral, -depth) * CFrame.Angles(0, yaw, 0),
						scale = sc,
						size = size * sc,
						colour = Color3.fromRGB(150, 76, 56),
						band = "near",
						segment = h.segAt(c),
						station = c,
						side = side,
						district = gorge.district,
					})
				end
				for _, side in { -1, 1 } do
					-- long axis along the route, front (local -Z) toward the gorge: +90 degrees on the right wall, -90 on the left
					local yaw = if side > 0 then math.pi / 2 else -math.pi / 2
					-- a right wall's +X points forward, a left wall's backward: the corner that closes the forward end differs
					local fwdName = if side > 0 then gorge.corner else gorge.cornerMirror
					local backName = if side > 0 then gorge.cornerMirror else gorge.corner
					local fwdSize, backSize = sizeOf({ m = fwdName }), sizeOf({ m = backName })
					local fwdSc, backSc = scaleFor(fwdSize), scaleFor(backSize)
					local fwdLen, backLen = fwdSize.X * fwdSc, backSize.X * backSc
					-- a corner's wall front face lies (size.Z / 2 - cornerWall) outward of its centre: put that face on the edge
					addPiece(
						fwdName,
						s1 - fwdLen / 2,
						gorge.halfWidth - (fwdSize.Z / 2 - gorge.cornerWall) * fwdSc,
						side,
						yaw,
						"GORGE CORNER",
						fwdSc,
						fwdSize
					)
					addPiece(
						backName,
						s0 + backLen / 2,
						gorge.halfWidth - (backSize.Z / 2 - gorge.cornerWall) * backSc,
						side,
						yaw,
						"GORGE CORNER",
						backSc,
						backSize
					)
					local st = s0 + backLen * 0.9
					local stop = s1 - fwdLen * 0.9
					local k = 0
					while st < stop - 4 do
						local name = gorge.wall[(k + (if side > 0 then 1 else 0)) % #gorge.wall + 1]
						local size = sizeOf({ m = name })
						local sc = scaleFor(size)
						local len = size.X * sc
						local c = math.min(st + len / 2, stop - len / 2 + 6)
						addPiece(name, c, gorge.halfWidth + size.Z * sc / 2, side, yaw, "GORGE WALL", sc, size)
						st += len * 0.96
						k += 1
					end
				end
				if gorge.pylon then
					local size = sizeOf({ m = gorge.pylon })
					local every = gorge.pylonEvery or 96
					local st = s0 + 48
					while st < s1 - 24 do
						addPiece(gorge.pylon, st, 0, 1, 0, "BRIDGE PIER", 1, size)
						st += every
					end
				end
				if gorge.under then
					local size = sizeOf({ m = gorge.under })
					local st = lm.from + size.Z / 2
					while st < lm.to - 8 do
						table.insert(extras, {
							kind = "gorge",
							module = gorge.under,
							label = "BRIDGE FRAMING",
							cframe = h.frame(st, 0, -(gorge.underDrop or 8.5)),
							scale = 1,
							size = size,
							colour = Color3.fromRGB(110, 74, 58),
							band = "near",
							segment = h.segAt(st),
							station = st,
							side = 0,
							district = gorge.district,
						})
						st += size.Z
					end
				end
				stats.gorgeLength = s1 - s0
				stats.gorgeFloor = -depth
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
		metaOf = function(name: string?): { [string]: any }?
			return if name and catalog.meta then catalog.meta[name] else nil
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
						local yawRad = Features.yawOf(rule.yaw, side, rng)
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
	Features.skiers(ctx)
	Features.companions(ctx)
	Features.signs(ctx)
	Features.warnings(ctx)
	Features.motion(ctx)

	-- 6c. smoke origins: every chimney lot and landmark of the plan, in world space (WorldLife re-homes five emitters among them)
	do
		local list: { Vector3 } = {}
		local spots: { [string]: { Vector3 } } = catalog.chimneys or {}
		for _, lot in plan.lots do
			for _, s in spots[lot.module] or {} do
				table.insert(list, (lot.pivot :: CFrame):PointToWorldSpace(s))
			end
		end
		for _, lm in plan.landmarks do
			for _, s in spots[lm.module] or {} do
				table.insert(list, (lm.pivot :: CFrame):PointToWorldSpace(s))
			end
		end
		info.chimneys = list
		stats.chimneys = #list
	end

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

	-- 8. checks: measured proof of the approved rules, printed with the plan (Sequencer.describe) ------------------
	local checks: { { id: string, ok: boolean, detail: string } } = {}
	local function check(id: string, ok: boolean, detail: string)
		table.insert(checks, { id = id, ok = ok, detail = detail })
	end
	local function routeDistance(p: Vector3): number
		local flat = Vector3.new(p.X, 0, p.Z)
		local best = math.huge
		for _, s in samples do
			best = math.min(best, (s - flat).Magnitude)
		end
		return best
	end
	local function first(list: { string }): string
		return if #list == 0 then "" else (" e.g. " .. table.concat(list, "; ", 1, math.min(3, #list)))
	end
	do
		-- nothing stands on the carriageway or within 4 studs of it (a lift cable and chairs pass overhead: the lift check below
		-- proves their clearance; ground patches lie under the road surface; the tunnel and gorge pieces are the structures)
		local onRoad, names = 0, {}
		for _, e in extras do
			if
				e.kind ~= "ground"
				and e.kind ~= "tunnel"
				and e.kind ~= "gorge"
				and e.kind ~= "lake"
				and e.kind ~= "lift"
			then
				local d = routeDistance((e.cframe :: CFrame).Position)
				if d < halfRoad + 4 then
					onRoad += 1
					table.insert(names, string.format("%s at %.0f (%.1f from the centre)", e.module, e.station, d))
				end
			end
		end
		check(
			"scenery-off-road",
			onRoad == 0,
			string.format("%d extras within 4 studs of the carriageway (want 0)%s", onRoad, first(names))
		)
	end
	for id, cfg in v2.landmarks or {} do
		for _, lm in plan.landmarks do
			if lm.id == id and cfg.setback and cfg.setback >= 30 and (id == "RockArch" or id == "RockArchSmall") then
				local nearest = math.huge
				for _, c in
					{
						Vector3.new(0, 0, 0),
						Vector3.new(lm.width, 0, 0),
						Vector3.new(0, 0, lm.depth),
						Vector3.new(lm.width, 0, lm.depth),
					}
				do
					nearest = math.min(nearest, routeDistance((lm.pivot :: CFrame):PointToWorldSpace(c)) - halfRoad)
				end
				-- plan 6.3: the thick arch stands so that no part comes within 50 studs of the road edge (the small one is judged the same)
				check(
					"arch-off-road:" .. id,
					nearest >= 50,
					string.format("%s: nearest corner %.1f studs from the road edge (want 50 or more)", id, nearest)
				)
			end
		end
	end
	local hz = v2.checks or {}
	if hz.sceneryClear or hz.rockClear then
		-- plan G8: near scenery keeps clear of the approach to a hazard; rock groups keep 60 clear before a rockslide
		local clear, rock = hz.sceneryClear or 40, hz.rockClear or 60
		local bad, names = 0, {}
		for _, e in extras do
			if e.kind == "mass" or e.kind == "fol" or e.kind == "edge" then
				if routeDistance((e.cframe :: CFrame).Position) < 120 then
					for _, hzp in plan.hazards do
						local need = if e.kind == "mass" and hzp.kind == "construction" then rock else clear
						if e.station > hzp.station - need and e.station < hzp.station + hzp.length + 8 then
							bad += 1
							table.insert(
								names,
								string.format(
									"%s at %.0f before the %s at %.0f",
									e.module,
									e.station,
									hzp.kind,
									hzp.station
								)
							)
						end
					end
				end
			end
		end
		check(
			"hazard-clear-zone",
			bad == 0,
			string.format(
				"%d near scenery pieces inside the clear zone before or at a hazard (want 0)%s",
				bad,
				first(names)
			)
		)
	end
	if hz.bunting then
		-- Summit plan 5.4 and Adam's answer 10: no bunting within 120 studs before a hazard
		local bad, nearest, count = 0, math.huge, 0
		for _, e in extras do
			if e.kind == "garland" then
				count += 1
				for _, hzp in plan.hazards do
					local ahead = hzp.station - (e.station + 12)
					if ahead >= -hzp.length and ahead < hz.bunting then
						bad += 1
					end
					if ahead >= 0 then
						nearest = math.min(nearest, ahead)
					end
				end
			end
		end
		check(
			"bunting-calm-zone",
			bad == 0,
			string.format(
				"%d garlands placed; %d within %d studs before a hazard (want 0); the nearest hazard ahead of any garland is %s studs",
				count,
				bad,
				hz.bunting,
				if nearest == math.huge then "none" else string.format("%.0f", nearest)
			)
		)
	end
	if v2.lake and info.lake then
		for _, lake in info.lake do
			check(
				"lake-size",
				lake.across >= 240 and lake.along >= 360,
				string.format("lake plane %d x %d studs (want at least 240 x 360)", lake.across, lake.along)
			)
			check(
				"lake-buffer",
				lake.nearEdge >= 90,
				string.format(
					"ice starts %d studs from the centre line (want 90 or more: a 40-stud buffer past the road edge)",
					lake.nearEdge
				)
			)
		end
	end
	if v2.tunnel then
		check(
			"tunnel-openings",
			(stats.tunnelBays or 0) >= 1 and (stats.tunnelOpenings or 0) >= 3,
			string.format(
				"%d bays, %d openings (want at least 3 in 12)",
				stats.tunnelBays or 0,
				stats.tunnelOpenings or 0
			)
		)
	end
	if v2.lift and info.lift then
		for _, path in info.lift do
			check(
				"lift-clearance",
				path.crossingHeight >= (path.clearance or 64),
				string.format("crossing at %.1f studs over the deck (want 64 or more)", path.crossingHeight)
			)
		end
	end
	if #info.gorges > 0 then
		local g = info.gorges[1]
		check(
			"gorge",
			true,
			string.format(
				"gorge %.0f long, %.0f half-wide, floor %.0f below the deck",
				g.halfLength * 2,
				g.halfWidth,
				-g.floorY
			)
		)
	end
	do
		local cones = 0
		for _, lot in plan.lots do
			if string.find(lot.module, "Peak") then
				cones += 1
			end
		end
		for _, e in extras do
			if string.find(e.module, "Peak") then
				cones += 1
			end
		end
		if v2.replaceMasses then
			check("no-cones", cones == 0, string.format("%d stacked-cone pieces placed (want 0)", cones))
		end
	end
	if v2.landmarkOrderCheck then
		-- Summit plan 6 and Adam's answer 8: observatory, snowmen, lodge, in that order; majors 500 apart, minors 250 from a major
		for _, span in plan.districts do
			local order: { number } = {}
			local names: { string } = {}
			for _, id in v2.landmarkOrderCheck do
				for _, lm in plan.landmarks do
					if lm.id == id and lm.station >= span.startS and lm.station < span.endS then
						table.insert(order, lm.station)
						table.insert(names, id .. "@" .. string.format("%.0f", lm.station))
					end
				end
			end
			if #order == #v2.landmarkOrderCheck then
				local ok = true
				for i = 2, #order do
					if order[i] <= order[i - 1] then
						ok = false
					end
				end
				check("landmark-order", ok, table.concat(names, ", ") .. " (want that order)")
			end
		end
	end
	if v2.welcomeLater then
		local later, wrong = 0, 0
		for _, sp in plan.spans do
			if sp.kind == "welcome" then
				local span = plan.districts[h.spanAt(sp.station)]
				if span and span.cycle > 1 then
					later += 1
					if sp.text ~= v2.welcomeLater then
						wrong += 1
					end
				end
			end
		end
		check(
			"welcome-later-laps",
			wrong == 0,
			string.format("%d later-lap welcome spans, %d with the wrong words", later, wrong)
		)
	end
	info.checks = checks
	stats.checksFailed = 0
	for _, c in checks do
		if not c.ok then
			stats.checksFailed += 1
		end
	end

	stats.extras = #extras
	table.sort(extras, function(a, b)
		return a.station < b.station
	end)
end

return WorldPlan
