--!strict
-- Downtown B CITY SEQUENCER (Lane 3 preview). A pure, deterministic planner: the same seed,
-- options and catalogue always give the same Plan. It creates no instances and keeps no state;
-- every random choice comes from one Random.new(seed) stream used strictly in route order.
--
-- What it plans (all PREVIEW values, for Brian R to accept or change; not Lane 1's road):
--   segments   reused road pieces (Straight 96/192, CurveL/CurveR R 360 16 deg, Intersection,
--              BridgeDeck, Transition) chained socket to socket, heading kept within +-32 deg
--   districts  Main Street -> City Hall -> Harbor Bridge -> Midtown -> Skyline Park, repeating;
--              explicit fixture targets 528 / 576 / 528 / 624 / 672 studs (unequal); the
--              realised boundary table (Plan.districts) is what a HUD district strip reads
--   lots       frontage modules per side, packed along each side's own frontage line; shuffle
--              bags per district and side; no immediate repeat of a module on a side; never the
--              same module facing itself across the road; corner lots only in the orientation
--              family their corner needs (mirroring = picking the mirrored variant); courtyards
--              and pocket parks every few lots; palettes only from the lot's district set;
--              district transitions blend over about 2-3 lots per side (50/50 at the boundary)
--   landmarks  one every 500-700 studs, alternating sides, never within 60 of a hazard, never
--              at an intersection mouth (+12), never on the bridge deck except the bridge itself
--   signs, props (lamps, furniture, one bus stop per district), spans (WELCOME TO DOWNTOWN at
--   each Main Street start, at most one bunting per district, clearance 26), hazards (scenery
--   previews only), midground and skyline masses, street-life spots.
--
-- Sequencer.plan(seed, options) -> Plan; Sequencer.describe(plan) -> printable summary.

local Catalog = require(script.Parent.Catalog)
local Route = require(script.Parent.Route)
local WorldPlan = require(script.Parent.WorldPlan)

local Sequencer = {}

Sequencer.VERSION = "city-b2-1"
Sequencer.DEFAULT_SEED = 2207
-- studs within which a shop name never repeats, on either side (about two blocks)
Sequencer.SIGN_GAP = 400
-- studs of frontage left open in front of a skyline landmark (the stadium), so it can be seen
Sequencer.SKYLINE_VIEW_GAP = 144
-- how far behind the frontage line a skyline landmark starts (was 300: the stadium sat 565 studs
-- out, never in a forward camera view)
Sequencer.SKYLINE_SETBACK = 90
Sequencer.DEFAULT_LENGTH = 3000 -- Round 2: the evidence route is at least 3,000 studs, like the other Worlds
Sequencer.LANE_WIDTH = 17 -- PREVIEW (reversible; see RoadWidthStudy)
Sequencer.LANES = 4
Sequencer.SHOULDER = 4
Sequencer.SIDEWALK = 12 -- includes the 0.8 kerb (contract: sidewalk 12 from the road edge)
Sequencer.KERB = 0.8
Sequencer.SPAN_CLEARANCE = 26 -- PREVIEW: underside of WELCOME / bunting spans
Sequencer.BLEND = 84 -- studs either side of a district boundary (about 2-3 lots)
Sequencer.STUDS_TO_METRES = 0.28 -- PROVISIONAL (cars README); studs are not metres

local HAZE = Color3.fromRGB(205, 224, 238)

export type Options = {
	length: number?, -- minimum route length in studs (default 3000)
	completeDistrict: boolean?, -- end at the first district boundary >= length (default true)
	laneWidth: number?,
	lanes: number?,
	shoulder: number?,
	catalog: Catalog.Catalog?, -- default Catalog.load()
	landmarkSpacing: { number }?, -- { min, max } (default 500, 700)
	districtTargets: { [string]: number }?,
	hazards: boolean?, -- default true
}

export type DistrictSpan = {
	order: number,
	cycle: number,
	id: string,
	name: string,
	startS: number,
	endS: number,
	length: number,
	target: number,
	truncated: boolean,
	landmark: string,
}

export type LotPlan = {
	id: number,
	side: number,
	from: number, -- centre-line stations covered by the frontage
	to: number,
	station: number, -- centre station
	width: number,
	depth: number,
	height: number,
	module: string,
	kind: string, -- building | courtyard | park | corner | corner-plaza | gap | transition-park
	orientation: string,
	required: string, -- orientation the slot needs
	palette: string,
	district: string,
	blend: number, -- 0 = pure district, 0.5 = at a boundary
	setback: number,
	pivot: CFrame, -- front-left corner of the footprint, facade (local -Z) facing the road
	segment: number,
	sign: string?,
	signStyle: string?,
	shop: boolean,
	finish: string,
}

export type LandmarkPlan = {
	id: string,
	module: string,
	label: string,
	station: number,
	from: number,
	to: number,
	side: number,
	width: number,
	depth: number,
	height: number,
	district: string,
	placement: string,
	pivot: CFrame,
	segment: number,
	palette: string,
}

export type SignPlan = { text: string, style: string, lot: number, station: number, side: number }
export type PropPlan = { kind: string, module: string, station: number, side: number, cframe: CFrame, segment: number }
export type SpanPlan = {
	kind: string,
	text: string,
	station: number,
	cframe: CFrame,
	width: number,
	clearance: number,
	segment: number,
	district: string,
}
export type HazardPlan = {
	kind: string,
	station: number,
	lane: number,
	length: number,
	cframe: CFrame,
	segment: number,
}
export type MassPlan = {
	band: string,
	station: number,
	side: number,
	cframe: CFrame,
	size: Vector3,
	colour: Color3,
	district: string,
	segment: number,
	roofTank: boolean,
}
export type LifeSpot = { kind: string, station: number, side: number, cframe: CFrame, segment: number }

-- World build V2 (Dusty Highway / Summit Pass, decision 0026): a placed kit piece that is not a lot, landmark, prop or
-- mass of the base planner (backdrop massifs, gorge walls, ground patches, lake tiles, tunnel bays, lift cable, garlands).
-- Made by WorldPlan.apply after the base plan, from the World's `v2` table, with its own per-district sub-seeds; empty for
-- Downtown and for a World without `v2`.
export type Extra = {
	kind: string, -- backdrop | mass | ground | edge | fol | sign | gorge | lake | tunnel | lift | garland | warning | yard ...
	module: string, -- kit mesh name
	label: string, -- shown on the proxy when the mesh is missing
	cframe: CFrame, -- the mesh's pivot frame (bottom centre for authored meshes)
	scale: number, -- uniform scale, 1 = authored size
	size: Vector3, -- proxy size, used when the mesh is missing (a board's width and height when `text` is set)
	colour: Color3, -- proxy colour
	text: string?, -- a wayfinding board's words (drawn on a part-built board, never baked into a mesh)
	band: string, -- "near" (the lot window) | "far" (the skyline window)
	segment: number,
	station: number,
	side: number,
	district: string,
}
export type WorldInfo = {
	notes: { string },
	stats: { [string]: number },
	gorges: { { [string]: any } },
	lift: any?, -- the ski lift path(s) for WorldLife
	lake: any?, -- the measured lake plane(s)
	checks: { { id: string, ok: boolean, detail: string } }?, -- WorldPlan's measured proofs of the approved rules
	motion: any?, -- windmill hubs, pennant strings and shimmer strips for WorldLife (Dusty)
	chimneys: { Vector3 }?, -- smoke origins in world space (Summit): every chimney lot and landmark of the plan
	skiPaths: any?, -- the ski glades' centre lines in world space (Summit): paths for the distant skiers
}

export type Checks = {
	passed: boolean,
	routeLength: number,
	atLeast2000: boolean,
	districtLengths: { number },
	districtLengthsOk: boolean,
	immediateLotRepeats: number,
	immediatePaletteRepeats: number,
	identicalPairs: number,
	signRepeats: number,
	landmarkRepeats: number,
	landmarkSpacing: { number },
	landmarkSpacingMin: number,
	landmarkSpacingMax: number,
	landmarkConflicts: number,
	paletteViolations: number,
	orientationViolations: number,
	districtsWithoutSignature: { string },
	requiredMissing: { string }, -- a landmark a district lists as required that the plan did not place (Worlds)
	segmentJoinError: number,
	spans: number,
	notes: { string },
}

export type Plan = {
	version: string,
	seed: number,
	requested: number,
	length: number,
	laneWidth: number,
	lanes: number,
	shoulder: number,
	halfRoad: number,
	kerb: number,
	sidewalk: number,
	frontage: number,
	catalogSource: string,
	palettes: { [string]: Catalog.Palette },
	segments: { Route.Segment },
	districts: { DistrictSpan },
	lots: { LotPlan },
	landmarks: { LandmarkPlan },
	signs: { SignPlan },
	props: { PropPlan },
	spans: { SpanPlan },
	hazards: { HazardPlan },
	masses: { MassPlan },
	life: { LifeSpot },
	extras: { Extra },
	world: WorldInfo?, -- WorldPlan's notes, counts and gorge rectangles (nil without a World `v2` table)
	checks: Checks,
}

-- Shuffle bag -----------------------------------------------------------------------------------

type Bag = { items: { string }, remaining: { string } }

local function newBag(items: { string }): Bag
	return { items = table.clone(items), remaining = table.clone(items) }
end

-- Draws an accepted item. Items left in the bag are tried in a random cyclic order; if none is
-- accepted the bag refills and tries again; nil if nothing in the whole bag is acceptable.
local function draw(bag: Bag, rng: Random, accept: ((string) -> boolean)?): string?
	if #bag.items == 0 then
		return nil
	end
	for _ = 1, 2 do
		if #bag.remaining == 0 then
			bag.remaining = table.clone(bag.items)
		end
		local n = #bag.remaining
		local start = rng:NextInteger(1, n)
		for k = 0, n - 1 do
			local i = (start + k - 1) % n + 1
			local item = bag.remaining[i]
			if not accept or accept(item) then
				bag.remaining[i] = bag.remaining[n]
				bag.remaining[n] = nil
				return item
			end
		end
		bag.remaining = table.clone(bag.items)
	end
	return nil
end

local function shuffle<T>(list: { T }, rng: Random)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function round(x: number, step: number?): number
	local q = step or 0.01
	return math.floor(x / q + 0.5) * q
end

-- Plan ------------------------------------------------------------------------------------------

type Interval = { from: number, to: number, kind: string }

local function overlaps(a0: number, a1: number, b0: number, b1: number): boolean
	return a0 < b1 and b0 < a1
end

function Sequencer.plan(seed: number?, options: Options?): Plan
	local opts = options or {}
	local seedValue = math.floor(seed or Sequencer.DEFAULT_SEED)
	local rng = Random.new(seedValue)
	local catalog = opts.catalog or Catalog.load()
	local requested = opts.length or Sequencer.DEFAULT_LENGTH
	local completeDistrict = opts.completeDistrict ~= false
	local lanes = opts.lanes or Sequencer.LANES
	local laneWidth = opts.laneWidth or Sequencer.LANE_WIDTH
	local shoulder = opts.shoulder or Sequencer.SHOULDER
	local halfRoad = lanes * laneWidth / 2 + shoulder
	local frontage = halfRoad + Sequencer.SIDEWALK
	local spacing = opts.landmarkSpacing or { 500, 700 }
	local notes: { string } = {}

	local palettes: { [string]: Catalog.Palette } = {}
	for _, d in catalog.districts do
		for _, p in d.palettes do
			palettes[p.id] = p
		end
	end

	-- 1. Segments and district spans ---------------------------------------------------------
	local segments: { Route.Segment } = {}
	local spans: { DistrictSpan } = {}
	local s = 0
	local cf = CFrame.identity
	local heading = 0
	local function push(kind: Route.Kind, length: number, district: Catalog.District, spanIndex: number, cycle: number)
		local bend = Route.bendOf(kind)
		local seg: Route.Segment = {
			index = #segments + 1,
			kind = kind,
			length = length,
			startS = s,
			endS = s + length,
			start = cf,
			finish = cf * Route.localFrame(bend, Route.RADIUS, length, 0, 0),
			bend = bend,
			radius = Route.RADIUS,
			heading = heading,
			district = district.id,
			span = spanIndex,
			cycle = cycle,
			mesh = Catalog.roadName(kind, length, lanes, laneWidth),
			crossAt = if kind == "Intersection" then length / 2 else nil,
		}
		table.insert(segments, seg)
		s += length
		cf = seg.finish
		heading += bend * Route.CURVE_DEGREES
	end

	local order = catalog.districts
	local k, cycle = 1, 1
	local guard = 0
	while guard < 200 do
		guard += 1
		local d = order[k]
		local target = (opts.districtTargets and opts.districtTargets[d.id]) or d.target
		local spanIndex = #spans + 1
		local first = spanIndex == 1
		local startS = s
		local truncated = false
		-- the piece list: features (intersections, curves, the bridge run) separated by straights
		local list: { string } = {}
		if not first then
			table.insert(list, "Transition")
		end
		if d.bridge then
			table.insert(list, "Straight96")
			table.insert(list, "BridgeDeck")
			table.insert(list, "BridgeDeck")
		else
			local features: { string } = {}
			for _ = 1, d.intersections do
				table.insert(features, "Intersection")
			end
			for _ = 1, d.curves do
				table.insert(features, "Curve")
			end
			shuffle(features, rng)
			if first then
				table.insert(list, "Straight96") -- the route opens on a straight (WELCOME span at s 60)
			end
			for _, f in features do
				table.insert(list, f)
				table.insert(list, "StraightAfter")
			end
		end
		-- realise lengths: a straight after a feature is 192 only when the rest still fits
		local function pieceLength(piece: string): number
			if piece == "Curve" then
				return Route.CURVE_LENGTH
			elseif piece == "Straight192" or piece == "BridgeDeck" then
				return 192
			end
			return 96
		end
		local total = 0
		for _, piece in list do
			total += pieceLength(piece)
		end
		for i, piece in list do
			if piece == "StraightAfter" then
				if total + 96 <= target + 24 and rng:NextNumber() < 0.6 then
					list[i] = "Straight192"
					total += 96
				else
					list[i] = "Straight96"
				end
			end
		end
		while target - total >= 72 do
			if target - total >= 216 then
				table.insert(list, "Straight192")
				total += 192
			else
				table.insert(list, "Straight96")
				total += 96
			end
		end
		for _, piece in list do
			if not completeDistrict and s >= requested then
				truncated = true
				break
			end
			if piece == "Curve" then
				local dir = if rng:NextNumber() < 0.5 then -1 else 1
				if heading + dir * Route.CURVE_DEGREES > 32 or heading + dir * Route.CURVE_DEGREES < -32 then
					dir = -dir
				end
				push(if dir > 0 then "CurveR" else "CurveL", Route.CURVE_LENGTH, d, spanIndex, cycle)
			elseif piece == "Intersection" then
				push("Intersection", Route.INTERSECTION_LENGTH, d, spanIndex, cycle)
			elseif piece == "Transition" then
				push("Transition", Route.TRANSITION_LENGTH, d, spanIndex, cycle)
			elseif piece == "BridgeDeck" then
				push("BridgeDeck", Route.BRIDGE_LENGTH, d, spanIndex, cycle)
			else
				push("Straight", pieceLength(piece), d, spanIndex, cycle)
			end
		end
		table.insert(spans, {
			order = d.order,
			cycle = cycle,
			id = d.id,
			name = d.name,
			startS = startS,
			endS = s,
			length = round(s - startS),
			target = target,
			truncated = truncated,
			landmark = d.signature,
		})
		if s >= requested then
			break
		end
		k += 1
		if k > #order then
			k = 1
			cycle += 1
		end
	end
	local length = s

	local function spanAt(station: number): number
		for i, span in spans do
			if station < span.endS then
				return i
			end
		end
		return #spans
	end
	local function frame(station: number, d: number?, y: number?): CFrame
		return Route.frame(segments, station, d, y)
	end
	local function segAt(station: number): number
		return Route.find(segments, station)
	end
	local function laneCentre(lane: number): number
		return -lanes * laneWidth / 2 + laneWidth * (lane - 0.5)
	end

	-- 2. Zones -------------------------------------------------------------------------------
	local mouths: { Interval } = {}
	local bridges: { Interval } = {}
	for _, seg in segments do
		if seg.kind == "Intersection" then
			local c = seg.startS + (seg.crossAt or seg.length / 2)
			table.insert(mouths, { from = c - Route.MOUTH, to = c + Route.MOUTH, kind = "intersection" })
		elseif seg.kind == "BridgeDeck" then
			local last = bridges[#bridges]
			if last and math.abs(last.to - seg.startS) < 0.01 then
				last.to = seg.endS
			else
				table.insert(bridges, { from = seg.startS, to = seg.endS, kind = "bridge" })
			end
		end
	end

	-- 3. Hazards (scenery previews only; positions Lane 1 would own) --------------------------
	local hazards: { HazardPlan } = {}
	if opts.hazards ~= false then
		local bag = newBag({ "construction", "pothole", "oil" })
		local lastStation, lastKind = -math.huge, ""
		for _, seg in segments do
			if seg.kind == "Straight" and seg.startS >= 150 then
				local u = rng:NextNumber(24, seg.length - 48)
				local st = seg.startS + u
				if st - lastStation >= 260 and rng:NextNumber() < 0.6 then
					local kind = draw(bag, rng, function(x)
						return x ~= lastKind
					end) or "pothole"
					local lane = if kind == "construction" then lanes elseif kind == "oil" then 3 else 2
					local len = if kind == "construction" then 25 elseif kind == "oil" then 4 else 3.5
					table.insert(hazards, {
						kind = kind,
						station = st,
						lane = lane,
						length = len,
						cframe = frame(st + len / 2, laneCentre(math.min(lane, lanes))),
						segment = seg.index,
					})
					lastStation, lastKind = st, kind
				end
			end
		end
	end

	-- side maps (lots are packed along each side's own frontage line)
	local maps = {
		[-1] = Route.sideMap(segments, -1, -frontage),
		[1] = Route.sideMap(segments, 1, frontage),
	}
	local function pivotFor(station: number, side: number, setback: number, width: number): CFrame
		local f = frame(station, side * (frontage + setback), 0)
		local look = -side * f.RightVector
		local front = CFrame.lookAt(f.Position, f.Position + look)
		return front * CFrame.new(-width / 2, 0, 0)
	end
	-- the centre-line stations a width-w frontage centred at `station` covers on a side
	local function footprint(station: number, side: number, width: number): (number, number)
		local map = maps[side]
		local t = Route.sToT(map, station)
		return Route.tToS(map, t - width / 2), Route.tToS(map, t + width / 2)
	end

	-- 4. Landmarks -----------------------------------------------------------------------------
	local landmarks: { LandmarkPlan } = {}
	local function landmarkFree(from: number, to: number, side: number): boolean
		if from < 30 or to > length - 30 then
			return false
		end
		for _, m in mouths do
			if overlaps(from, to, m.from - 12, m.to + 12) then
				return false
			end
		end
		for _, b in bridges do
			if overlaps(from, to, b.from, b.to) then
				return false
			end
		end
		for _, h in hazards do
			if overlaps(from, to, h.station - 60, h.station + h.length + 60) then
				return false
			end
		end
		for _, lm in landmarks do
			if lm.side == side and overlaps(from, to, lm.from - 12, lm.to + 12) then
				return false
			end
		end
		return true
	end
	local lmBags: { [string]: Bag } = {}
	local usedSignature: { [number]: boolean } = {}
	local lmSide = 1
	local lastId = ""
	local targetS = rng:NextInteger(220, 320)
	local lmGuard = 0
	local function makeIn(
		span: DistrictSpan,
		def: Catalog.Landmark,
		station: number,
		side: number,
		from: number,
		to: number
	): LandmarkPlan
		local district = catalog.districtById[span.id]
		local pal = district.palettes[rng:NextInteger(1, #district.palettes)]
		local pivot: CFrame
		if def.placement == "bridge" then
			pivot = frame(station)
		elseif def.placement == "skyline" then
			pivot = pivotFor(station, side, Sequencer.SKYLINE_SETBACK + def.depth / 2 - Sequencer.SIDEWALK, def.width)
		else
			pivot = pivotFor(station, side, 0, def.width)
		end
		return {
			id = def.id,
			module = def.name,
			label = def.label,
			station = station,
			from = from,
			to = to,
			side = if def.placement == "bridge" then 0 else side,
			width = def.width,
			depth = def.depth,
			height = def.height,
			district = span.id,
			placement = def.placement,
			pivot = pivot,
			segment = segAt(station),
			palette = pal.id,
		}
	end
	-- the bridge district's signature is the bridge itself, at its deck centre: placed first, so
	-- the frontage sweep below cannot step past it (seed 2207 had no arch: the sweep's station
	-- landed 310 studs from the deck centre)
	for spanIndex, span in spans do
		local district = catalog.districtById[span.id]
		local def = catalog.landmarkById[district.signature]
		if district.bridge and def and def.placement == "bridge" then
			for _, b in bridges do
				if b.from >= span.startS and b.to <= span.endS + 0.01 and not usedSignature[spanIndex] then
					table.insert(landmarks, makeIn(span, def, (b.from + b.to) / 2, 0, b.from, b.to))
					usedSignature[spanIndex] = true
				end
			end
		end
	end
	while targetS < length - 48 and lmGuard < 400 do
		lmGuard += 1
		local spanIndex = spanAt(targetS)
		local span = spans[spanIndex]
		local district = catalog.districtById[span.id]
		local placed: LandmarkPlan? = nil
		local function make(
			def: Catalog.Landmark,
			station: number,
			side: number,
			from: number,
			to: number
		): LandmarkPlan
			return makeIn(span, def, station, side, from, to)
		end
		if not placed then
			local bag = lmBags[district.id]
			if not bag then
				local ids = {}
				for _, id in district.landmarks do
					local def = catalog.landmarkById[id]
					if def and def.placement ~= "bridge" then
						table.insert(ids, id)
					end
				end
				bag = newBag(ids)
				lmBags[district.id] = bag
			end
			local candidates: { string } = {}
			local sig = catalog.landmarkById[district.signature]
			if not usedSignature[spanIndex] and sig and sig.placement ~= "bridge" and sig.id ~= lastId then
				table.insert(candidates, sig.id)
			end
			for _ = 1, 3 do
				local id = draw(bag, rng, function(x)
					return x ~= lastId and not table.find(candidates, x)
				end)
				if id then
					table.insert(candidates, id)
				end
			end
			-- World build V2: a district may fix the ORDER its landmarks appear in (Summit Lodge: the observatory, then the
			-- snowmen, then the lodge). Only the next one not yet placed in this span is a candidate.
			local landmarkOrder = (district :: any).landmarkOrder
			if landmarkOrder then
				candidates = {}
				for _, wanted in landmarkOrder do
					local placedHere = false
					for _, lm in landmarks do
						if lm.id == wanted and lm.station >= span.startS and lm.station < span.endS then
							placedHere = true
							break
						end
					end
					if not placedHere then
						table.insert(candidates, wanted)
						break
					end
				end
			end
			for _, id in candidates do
				local def = catalog.landmarkById[id]
				if def.placement == "skyline" then
					placed = make(def, targetS, lmSide, targetS, targetS)
					break
				end
				for _, side in { lmSide, -lmSide } do
					for _, off in { 0, 24, -24, 48, -48, 72, -72, 96, -96, 120, -120, 144, -144 } do
						local c = targetS + off
						local from, to = footprint(c, side, def.width)
						if landmarkFree(from, to, side) then
							placed = make(def, c, side, from, to)
							break
						end
					end
					if placed then
						break
					end
				end
				if placed then
					break
				end
			end
		end
		if placed then
			table.insert(landmarks, placed)
			if placed.id == district.signature then
				usedSignature[spanIndex] = true
			end
			lastId = placed.id
			if placed.side ~= 0 then
				lmSide = -placed.side
			end
			targetS = placed.station + rng:NextInteger(spacing[1], spacing[2])
		else
			targetS += 96
		end
	end
	-- every district span shows its signature landmark (seed 2207 ended Skyline Park with the car
	-- wash and no fountain): a missing one goes to the free frontage nearest the span centre
	for spanIndex, span in spans do
		local district = catalog.districtById[span.id]
		local def = catalog.landmarkById[district.signature]
		if usedSignature[spanIndex] or not def or def.placement == "bridge" then
			continue
		end
		local centre = (span.startS + span.endS) / 2
		local placed: LandmarkPlan? = nil
		if def.placement == "skyline" then
			placed = makeIn(span, def, centre, lmSide, centre, centre)
		else
			local reach = (span.endS - span.startS) / 2
			for off = 0, reach, 12 do
				for _, c in { centre + off, centre - off } do
					for _, side in { 1, -1 } do
						local from, to = footprint(c, side, def.width)
						if not placed and from >= span.startS and to <= span.endS and landmarkFree(from, to, side) then
							placed = makeIn(span, def, c, side, from, to)
						end
					end
				end
				if placed then
					break
				end
			end
		end
		if placed then
			table.insert(landmarks, placed)
			usedSignature[spanIndex] = true
		end
	end
	-- Round 2 (Worlds): a district may list more landmarks it must show once per span (the diner's old pump garage);
	-- a missing one goes to the free frontage nearest the span centre, as the signature does above. Downtown lists none.
	for _, span in spans do
		local district = catalog.districtById[span.id]
		for _, wanted in district.required or {} do
			local def = catalog.landmarkById[wanted]
			if not def or def.placement ~= "frontage" then
				continue
			end
			local have = false
			for _, lm in landmarks do
				if lm.id == wanted and lm.station >= span.startS and lm.station < span.endS then
					have = true
					break
				end
			end
			if have then
				continue
			end
			local centre = (span.startS + span.endS) / 2
			local reach = (span.endS - span.startS) / 2
			local placed: LandmarkPlan? = nil
			for off = 0, reach, 12 do
				for _, c in { centre + off, centre - off } do
					for _, side in { 1, -1 } do
						local from, to = footprint(c, side, def.width)
						if not placed and from >= span.startS and to <= span.endS and landmarkFree(from, to, side) then
							placed = makeIn(span, def, c, side, from, to)
						end
					end
				end
				if placed then
					break
				end
			end
			if placed then
				table.insert(landmarks, placed)
			end
		end
	end
	table.sort(landmarks, function(a, b)
		return a.station < b.station
	end)

	-- 5. Lots ----------------------------------------------------------------------------------
	type SideState = {
		side: number,
		intervals: { { from: number, to: number, startMouth: boolean, endMouth: boolean, endDone: boolean } },
		ii: number,
		cursor: number,
		lots: { LotPlan },
		lastModule: string,
		lastPalette: string,
		lastSign: string,
		since: number,
		nextTreatment: number,
		transitionsDone: { [number]: boolean },
	}
	local lots: { LotPlan } = {}
	local signs: { SignPlan } = {}
	local recentSigns: { string } = {}
	local buildingBags: { [string]: Bag } = {}
	local paletteBags: { [string]: Bag } = {}
	local signBag = newBag(catalog.signs)
	local styleBags = { [-1] = newBag({ "band", "band", "blade" }), [1] = newBag({ "band", "blade", "band" }) }

	local function freeIntervals(side: number): { any }
		local map = maps[side]
		local blocks: { Interval } = {}
		for _, m in mouths do
			table.insert(blocks, m)
		end
		for _, b in bridges do
			table.insert(blocks, b)
		end
		for _, lm in landmarks do
			if lm.side == side and lm.placement == "frontage" then
				table.insert(blocks, { from = lm.from, to = lm.to, kind = "landmark" })
			elseif lm.side == side and lm.placement == "skyline" then
				-- a view gap in the frontage: the stadium sat behind the Midtown towers, invisible from
				-- the road (reviewer, 2026-10-23)
				local half = math.min(lm.width, Sequencer.SKYLINE_VIEW_GAP) / 2
				table.insert(blocks, { from = lm.station - half, to = lm.station + half, kind = "landmark" })
			end
		end
		table.sort(blocks, function(a, b)
			return a.from < b.from
		end)
		local out = {}
		local cursor, cursorMouth = 0, false
		for _, b in blocks do
			if b.from > cursor then
				table.insert(out, {
					from = Route.sToT(map, cursor),
					to = Route.sToT(map, b.from),
					startMouth = cursorMouth,
					endMouth = b.kind == "intersection",
					endDone = false,
				})
			end
			if b.to > cursor then
				cursor = b.to
				cursorMouth = b.kind == "intersection"
			end
		end
		if length > cursor then
			table.insert(out, {
				from = Route.sToT(map, cursor),
				to = Route.sToT(map, length),
				startMouth = cursorMouth,
				endMouth = false,
				endDone = false,
			})
		end
		return out
	end

	local states: { [number]: SideState } = {}
	for _, side in { -1, 1 } do
		states[side] = {
			side = side,
			intervals = freeIntervals(side),
			ii = 1,
			cursor = 0,
			lots = {},
			lastModule = "",
			lastPalette = "",
			lastSign = "",
			since = 0,
			nextTreatment = 6,
			transitionsDone = {},
		}
	end

	-- the district a lot draws from (blends near boundaries)
	local function lotDistrict(station: number): (Catalog.District, number)
		local i = spanAt(station)
		local span = spans[i]
		local roll = rng:NextNumber()
		local B = Sequencer.BLEND
		if i > 1 and station - span.startS < B then
			local p = 0.5 - (station - span.startS) / (2 * B)
			if roll < p then
				return catalog.districtById[spans[i - 1].id], p
			end
			return catalog.districtById[span.id], p
		elseif i < #spans and span.endS - station < B then
			local p = 0.5 - (span.endS - station) / (2 * B)
			if roll < p then
				return catalog.districtById[spans[i + 1].id], p
			end
			return catalog.districtById[span.id], p
		end
		return catalog.districtById[span.id], 0
	end

	local function opposite(side: number, from: number, to: number): { LotPlan }
		local out = {}
		local other = states[-side].lots
		for i = #other, math.max(1, #other - 8), -1 do
			local l = other[i]
			if overlaps(from, to, l.from, l.to) then
				table.insert(out, l)
			end
		end
		return out
	end

	local function sameAcross(side: number, from: number, to: number, module: string): boolean
		for _, l in opposite(side, from, to) do
			if l.module == module then
				return true
			end
		end
		return false
	end

	local function buildingBag(district: Catalog.District, side: number): Bag
		local key = district.id .. "|" .. side
		local bag = buildingBags[key]
		if bag then
			return bag
		end
		local items = {}
		for _, lot in catalog.lots do
			if lot.kind == "building" and table.find(lot.districts, district.id) then
				local w = (district.heights :: any)[lot.heightClass] or 0
				for _ = 1, w do
					table.insert(items, lot.name)
				end
			end
		end
		bag = newBag(items)
		buildingBags[key] = bag
		return bag
	end

	local function pickPalette(state: SideState, district: Catalog.District): string
		local key = district.id .. "|" .. state.side
		local bag = paletteBags[key]
		if not bag then
			local ids = {}
			for _, p in district.palettes do
				table.insert(ids, p.id)
			end
			bag = newBag(ids)
			paletteBags[key] = bag
		end
		return draw(bag, rng, function(x)
			return x ~= state.lastPalette
		end) or district.palettes[1].id
	end

	local function addLot(
		state: SideState,
		t0: number,
		width: number,
		module: Catalog.LotModule?,
		kind: string,
		district: Catalog.District,
		blend: number,
		required: string
	)
		local map = maps[state.side]
		local from, to = Route.tToS(map, t0), Route.tToS(map, t0 + width)
		local station = Route.tToS(map, t0 + width / 2)
		local setback = 0
		if kind == "courtyard" then
			setback = ({ 8, 12, 16 })[rng:NextInteger(1, 3)]
		end
		local paletteId = if module and module.kind ~= "park" then pickPalette(state, district) else ""
		local lot: LotPlan = {
			id = #lots + 1,
			side = state.side,
			from = from,
			to = to,
			station = station,
			width = width,
			depth = if module then module.depth else 12,
			height = if module then module.height else 0,
			module = if module then module.name else "GAP",
			kind = kind,
			orientation = if module then module.orientation else "front",
			required = required,
			palette = paletteId,
			district = district.id,
			blend = round(blend),
			setback = setback,
			pivot = pivotFor(station, state.side, setback, width),
			segment = segAt(station),
			sign = nil,
			signStyle = nil,
			shop = module ~= nil and module.shop,
			finish = if module then module.finish else "",
		}
		if lot.shop and district.signs and rng:NextNumber() < 0.8 then
			local across: { [string]: boolean } = {}
			for _, l in opposite(state.side, from, to) do
				if l.sign then
					across[l.sign] = true
				end
			end
			-- no name twice within SIGN_GAP studs on either side (reviewer, 2026-10-23: the same
			-- shop twice inside Main Street while the old same-side check said 0)
			local near: { [string]: boolean } = {}
			for _, sg in signs do
				if math.abs(sg.station - station) < Sequencer.SIGN_GAP then
					near[sg.text] = true
				end
			end
			local text = draw(signBag, rng, function(x)
				return x ~= state.lastSign and not across[x] and not near[x] and not table.find(recentSigns, x)
			end)
			if text then
				lot.sign = text
				lot.signStyle = draw(styleBags[state.side], rng) or "band"
				state.lastSign = text
				table.insert(recentSigns, text)
				if #recentSigns > 3 then
					table.remove(recentSigns, 1)
				end
				table.insert(signs, {
					text = text,
					style = lot.signStyle :: string,
					lot = lot.id,
					station = station,
					side = state.side,
				})
			end
		end
		table.insert(lots, lot)
		table.insert(state.lots, lot)
		if module then
			state.lastModule = module.name
		end
		if paletteId ~= "" then
			state.lastPalette = paletteId
		end
		state.cursor = t0 + width
	end

	local function cornerModule(
		state: SideState,
		district: Catalog.District,
		needed: string,
		t0: number
	): Catalog.LotModule?
		local map = maps[state.side]
		local from, to = Route.tToS(map, t0), Route.tToS(map, t0 + 24)
		local choices = {}
		for _, lot in catalog.lots do
			if
				lot.kind == "corner"
				and lot.orientation == needed
				and lot.width == 24
				and table.find(lot.districts, district.id)
				and lot.name ~= state.lastModule
				and not sameAcross(state.side, from, to, lot.name)
			then
				table.insert(choices, lot)
			end
		end
		if #choices == 0 then
			return nil
		end
		return choices[rng:NextInteger(1, #choices)]
	end

	local function parkModule(width: number): Catalog.LotModule?
		for _, lot in catalog.lots do
			if lot.kind == "park" and lot.width == width then
				return lot
			end
		end
		for _, lot in catalog.lots do
			if lot.kind == "park" and lot.width <= width then
				return lot
			end
		end
		return nil
	end

	local function courtModule(state: SideState, district: Catalog.District, avail: number): Catalog.LotModule?
		local map = maps[state.side]
		local choices = {}
		for _, lot in catalog.lots do
			if
				lot.kind == "courtyard"
				and lot.width <= avail
				and table.find(lot.districts, district.id)
				and lot.name ~= state.lastModule
				and not sameAcross(
					state.side,
					Route.tToS(map, state.cursor),
					Route.tToS(map, state.cursor + lot.width),
					lot.name
				)
			then
				table.insert(choices, lot)
			end
		end
		if #choices == 0 then
			return nil
		end
		return choices[rng:NextInteger(1, #choices)]
	end

	-- World build V2: with `v2.subSeeds` the lot phase draws from one stream per district span, seeded by
	-- hash(seed, cycle, district), so cycle 2 of a district is not a replay of cycle 1 and one district's lots never shift
	-- another's (the later phases go back to the main stream)
	local mainRng = rng
	local subSeeds = catalog.world ~= nil and catalog.world.v2 ~= nil and catalog.world.v2.subSeeds == true
	local spanRngs: { [number]: Random } = {}
	local function spanRng(spanIndex: number): Random
		local r = spanRngs[spanIndex]
		if not r then
			local sp = spans[spanIndex]
			r = Random.new(WorldPlan.seedFor(seedValue, sp.cycle, sp.order, "lots"))
			spanRngs[spanIndex] = r
		end
		return r :: Random
	end

	local function stepSide(state: SideState): boolean
		local iv = state.intervals[state.ii]
		if not iv then
			return false
		end
		if subSeeds then
			rng = spanRng(spanAt(Route.tToS(maps[state.side], math.max(state.cursor, iv.from)) + 12))
		end
		if state.cursor < iv.from then
			state.cursor = iv.from
		end
		local map = maps[state.side]
		local side = state.side
		local atStart = state.cursor <= iv.from + 0.001
		local district, blend = lotDistrict(Route.tToS(map, state.cursor + 12))
		-- a pocket park that neither repeats the previous lot nor faces an identical one
		local function parkFor(width: number, t0: number): Catalog.LotModule?
			local park = parkModule(width)
			if not park or park.name == state.lastModule then
				return nil
			end
			if sameAcross(side, Route.tToS(map, t0), Route.tToS(map, t0 + park.width), park.name) then
				return nil
			end
			return park
		end
		local function corner(t0: number, needed: string)
			local m = if rng:NextNumber() < 0.75 then cornerModule(state, district, needed, t0) else nil
			if m then
				addLot(state, t0, 24, m, "corner", district, blend, needed)
			else
				-- corner treatment: a small plaza (a pocket park, or paving when a park would repeat)
				addLot(state, t0, 24, parkFor(24, t0), "corner-plaza", district, blend, needed)
			end
		end
		-- corner at the interval start (an intersection behind)
		if atStart and iv.startMouth and iv.to - state.cursor >= 24 then
			corner(state.cursor, if side < 0 then "corner-R" else "corner-L")
			return true
		end
		local reserveEnd = if iv.endMouth and not iv.endDone then 24 else 0
		local avail = iv.to - state.cursor - reserveEnd
		if avail < 24 then
			if avail > 0.5 then
				addLot(state, state.cursor, avail, nil, "gap", district, blend, "front")
			end
			if reserveEnd > 0 then
				if iv.to - state.cursor >= 24 - 0.001 then
					-- corner before the intersection ahead
					corner(iv.to - 24, if side < 0 then "corner-L" else "corner-R")
				elseif iv.to - state.cursor > 0.5 then
					addLot(state, state.cursor, iv.to - state.cursor, nil, "gap", district, blend, "front")
				end
				iv.endDone = true
			end
			state.ii += 1
			return true
		end
		-- transition glue: one pocket park per district boundary, on alternating sides
		local station = Route.tToS(map, state.cursor + 12)
		local seg = segments[segAt(station)]
		if
			seg.kind == "Transition"
			and not state.transitionsDone[seg.index]
			and (seg.span % 2 == 0) == (side > 0)
			and avail >= 36
		then
			state.transitionsDone[seg.index] = true
			local width = if avail - 36 == 0 or avail - 36 >= 24 then 36 else 24
			local park = parkFor(width, state.cursor)
			if park then
				addLot(state, state.cursor, park.width, park, "transition-park", district, blend, "front")
				state.since = 0
				return true
			end
		end
		-- courtyard / pocket park treatment
		state.since += 1
		if state.since >= state.nextTreatment then
			state.since = 0
			state.nextTreatment = rng:NextInteger(district.treatmentEvery[1], district.treatmentEvery[2])
			if rng:NextNumber() < district.parkBias then
				local width = if avail >= 36 and (avail - 36 == 0 or avail - 36 >= 24) then 36 else 24
				local park = parkFor(width, state.cursor)
				if park then
					addLot(state, state.cursor, park.width, park, "park", district, blend, "front")
					return true
				end
			else
				local court = courtModule(state, district, avail)
				if court and (avail - court.width == 0 or avail - court.width >= 24) then
					addLot(state, state.cursor, court.width, court, "courtyard", district, blend, "front")
					return true
				end
			end
		end
		-- an ordinary building from the district's bag
		local bag = buildingBag(district, side)
		local t0 = state.cursor
		local function accept(strict: boolean): (string) -> boolean
			return function(name: string): boolean
				local lot = catalog.lotByName[name]
				if not lot or lot.width > avail + 0.001 then
					return false
				end
				local left = avail - lot.width
				if strict and left > 0.001 and left < 24 then
					return false
				end
				if name == state.lastModule then
					return false
				end
				local from, to = Route.tToS(map, t0), Route.tToS(map, t0 + lot.width)
				return not sameAcross(side, from, to, name)
			end
		end
		local name = draw(bag, rng, accept(true)) or draw(bag, rng, accept(false))
		local lot = name and catalog.lotByName[name]
		if lot then
			addLot(state, t0, lot.width, lot, "building", district, blend, "front")
		else
			-- nothing fits (an empty bag or a short run): a narrow gap, then move on
			local width = math.min(avail, 24)
			addLot(state, t0, width, nil, "gap", district, blend, "front")
		end
		return true
	end

	local lotGuard = 0
	while lotGuard < 20000 do
		lotGuard += 1
		local l, r = states[-1], states[1]
		local lDone = l.intervals[l.ii] == nil
		local rDone = r.intervals[r.ii] == nil
		if lDone and rDone then
			break
		end
		local pick: SideState
		if lDone then
			pick = r
		elseif rDone then
			pick = l
		else
			local ls = Route.tToS(maps[-1], math.max(l.cursor, l.intervals[l.ii].from))
			local rs = Route.tToS(maps[1], math.max(r.cursor, r.intervals[r.ii].from))
			pick = if ls <= rs then l else r
		end
		stepSide(pick)
	end
	rng = mainRng

	-- 6. Spans (sparse) -------------------------------------------------------------------------
	local spanPlans: { SpanPlan } = {}
	local spanWidth = 2 * (halfRoad + 1.6)
	local function spanOk(station: number): boolean
		local seg = segments[segAt(station)]
		if seg.kind ~= "Straight" and seg.kind ~= "Transition" then
			return false
		end
		if station - seg.startS < 6 or seg.endS - station < 6 then
			return false
		end
		for _, sp in spanPlans do
			if math.abs(sp.station - station) < 200 then
				return false
			end
		end
		for _, lm in landmarks do
			if math.abs(lm.station - station) < 60 then
				return false
			end
		end
		for _, h in hazards do
			if station > h.station - 30 and station < h.station + h.length + 30 then
				return false
			end
		end
		return true
	end
	for _, span in spans do
		local district = catalog.districtById[span.id]
		if district.welcome then
			local st = span.startS + (if span.startS == 0 then 60 else 48)
			if spanOk(st) then
				table.insert(spanPlans, {
					kind = "welcome",
					text = district.welcome,
					station = st,
					cframe = frame(st),
					width = spanWidth,
					clearance = Sequencer.SPAN_CLEARANCE,
					segment = segAt(st),
					district = span.id,
				})
			end
		end
		if district.bunting then
			for _, off in { 0.55, 0.4, 0.7, 0.3, 0.8 } do
				local st = round(span.startS + (span.endS - span.startS) * off, 1)
				if spanOk(st) then
					table.insert(spanPlans, {
						kind = "bunting",
						text = "",
						station = st,
						cframe = frame(st),
						width = spanWidth,
						clearance = Sequencer.SPAN_CLEARANCE,
						segment = segAt(st),
						district = span.id,
					})
					break
				end
			end
		end
	end
	table.sort(spanPlans, function(a, b)
		return a.station < b.station
	end)

	-- 7. Street-life spots -----------------------------------------------------------------------
	local life: { LifeSpot } = {}
	local function inMouthOrBridge(station: number, pad: number): boolean
		for _, m in mouths do
			if station > m.from - pad and station < m.to + pad then
				return true
			end
		end
		for _, b in bridges do
			if station > b.from - pad and station < b.to + pad then
				return true
			end
		end
		return false
	end
	local walkD = halfRoad + Sequencer.KERB + 6
	do
		local st = rng:NextNumber(90, 160)
		local side = -1
		while st < length - 40 do
			if not inMouthOrBridge(st, 6) then
				table.insert(life, {
					kind = "pigeons",
					station = st,
					side = side,
					cframe = frame(st, side * walkD, Sequencer.KERB - 0.2),
					segment = segAt(st),
				})
				side = -side
			end
			st += rng:NextNumber(180, 260)
		end
	end
	for _, span in spans do
		if (catalog.districtById[span.id] :: Catalog.District).cart ~= false then
			local candidates = {}
			for _, lot in lots do
				if
					lot.district == span.id
					and (lot.kind == "park" or lot.kind == "courtyard" or lot.kind == "transition-park")
					and lot.station > span.startS
					and lot.station < span.endS
				then
					table.insert(candidates, lot)
				end
			end
			local st, side
			if #candidates > 0 then
				local lot = candidates[rng:NextInteger(1, #candidates)]
				st, side = lot.station, lot.side
			else
				st, side = (span.startS + span.endS) / 2, if span.order % 2 == 0 then 1 else -1
			end
			if not inMouthOrBridge(st, 4) then
				table.insert(life, {
					kind = "cart",
					station = st,
					side = side,
					cframe = frame(st, side * (halfRoad + 8), Sequencer.KERB - 0.2)
						* CFrame.Angles(0, if side > 0 then math.pi / 2 else -math.pi / 2, 0),
					segment = segAt(st),
				})
			end
		end
	end
	for _, lm in landmarks do
		if lm.id == "CityHall" then
			for i = -1, 1 do
				local st = lm.station + i * 12
				table.insert(life, {
					kind = "flag",
					station = st,
					side = lm.side,
					cframe = frame(st, lm.side * (frontage + 4), 0),
					segment = segAt(st),
				})
			end
		elseif lm.id == "HarborBridge" then
			for _, side in { -1, 1 } do
				local st = lm.from + 30
				table.insert(life, {
					kind = "flag",
					station = st,
					side = side,
					cframe = frame(st, side * (halfRoad + 10), 0),
					segment = segAt(st),
				})
			end
		end
	end
	for _, seg in segments do
		if seg.kind == "Transition" then
			local side = if seg.span % 2 == 0 then -1 else 1
			local st = seg.startS + 20
			table.insert(life, {
				kind = "flag",
				station = st,
				side = side,
				cframe = frame(st, side * (frontage - 2), 0),
				segment = seg.index,
			})
		end
	end
	table.sort(life, function(a, b)
		return a.station < b.station
	end)

	-- 8. Street furniture -------------------------------------------------------------------------
	local props: { PropPlan } = {}
	local furnitureBags: { [string]: Bag } = {}
	local lastFurniture = { [-1] = "", [1] = "" }
	local furnitureSlot = { [-1] = 0, [1] = 1 } -- the right side starts one slot on, so trees alternate sides
	local busStop: { [number]: boolean } = {}
	-- a hazard needs a clear approach: no tree or bus shelter in the 40 studs before it or just past it
	local function nearHazard(station: number): boolean
		for _, h in hazards do
			if station > h.station - 40 and station < h.station + h.length + 8 then
				return true
			end
		end
		return false
	end
	local function clearOf(station: number, side: number): boolean
		for _, sp in spanPlans do
			if math.abs(sp.station - station) < 6 then
				return false
			end
		end
		for _, spot in life do
			if spot.side == side and math.abs(spot.station - station) < 6 then
				return false
			end
		end
		return true
	end
	for _, seg in segments do
		for _, side in { -1, 1 } do
			local u = if side < 0 then 12 else 36
			while u < seg.length - 2 do
				local st = seg.startS + u
				if seg.kind == "BridgeDeck" then
					table.insert(props, {
						kind = "bridgeLamp",
						module = catalog.props.bridgeLamp,
						station = st,
						side = side,
						cframe = CFrame.lookAt(
							frame(st, side * (halfRoad + 11)).Position,
							frame(st, side * (halfRoad + 11)).Position - side * frame(st).RightVector
						),
						segment = seg.index,
					})
				elseif not inMouthOrBridge(st, 2) and clearOf(st, side) then
					local at = frame(st, side * (halfRoad + Sequencer.KERB + 1.4))
					table.insert(props, {
						kind = "lamp",
						module = catalog.props.lamp,
						station = st,
						side = side,
						cframe = CFrame.lookAt(at.Position, at.Position - side * at.RightVector),
						segment = seg.index,
					})
				end
				-- furniture between lamps
				local fs = st + 24
				if
					fs < seg.endS - 2
					and seg.kind ~= "BridgeDeck"
					and not inMouthOrBridge(fs, 2)
					and clearOf(fs, side)
				then
					local spanIndex = spanAt(fs)
					local district = catalog.districtById[spans[spanIndex].id]
					local blocked = nearHazard(fs)
					local kind: string
					if
						not busStop[spanIndex]
						and seg.kind == "Straight"
						and side > 0
						and fs > spans[spanIndex].startS + 120
						and not blocked
					then
						kind = "busStop"
						busStop[spanIndex] = true
					else
						local bag = furnitureBags[district.id]
						if not bag then
							bag = newBag(district.furniture)
							furnitureBags[district.id] = bag
						end
						kind = draw(bag, rng, function(x)
							return x ~= lastFurniture[side]
						end) or "bin"
						furnitureSlot[side] += 1
						if district.treeEvery and furnitureSlot[side] % district.treeEvery == 0 then
							kind = "tree"
						end
						if blocked and (kind == "tree" or kind == "busStop") then
							kind = "bin"
						end
					end
					lastFurniture[side] = kind
					local inset = if kind == "busStop" then 5 elseif kind == "tree" then 2.6 else 2.2
					local at = frame(fs, side * (halfRoad + Sequencer.KERB + inset))
					table.insert(props, {
						kind = kind,
						module = catalog.props[kind] or ("B2_Furn_" .. kind),
						station = fs,
						side = side,
						cframe = CFrame.lookAt(at.Position, at.Position - side * at.RightVector),
						segment = seg.index,
					})
				end
				u += 48
			end
		end
	end

	-- 9. Midground and skyline masses ---------------------------------------------------------------
	local masses: { MassPlan } = {}
	local samples: { Vector3 } = {}
	do
		local st = -200
		while st <= length + 200 do
			table.insert(samples, frame(st).Position)
			st += 24
		end
	end
	local function clearOfRoute(position: Vector3, radius: number, need: number): boolean
		local flat = Vector3.new(position.X, 0, position.Z)
		for _, p in samples do
			if (Vector3.new(p.X, 0, p.Z) - flat).Magnitude < need + radius then
				return false
			end
		end
		return true
	end
	local function addMass(band: string, seg: Route.Segment, side: number, u: number, edge: number, size: Vector3)
		local st = seg.startS + u
		local district = catalog.districtById[seg.district]
		local pal = district.palettes[rng:NextInteger(1, #district.palettes)]
		local d = side * (halfRoad + edge + size.Z / 2)
		local f = frame(st, d, size.Y / 2)
		local radius = math.max(size.X, size.Z) / 2
		-- keep the view gap in front of a skyline landmark (and the landmark itself) clear
		for _, lm in landmarks do
			if lm.placement == "skyline" and lm.side == side then
				local half = math.max(lm.width, Sequencer.SKYLINE_VIEW_GAP) / 2
				if math.abs(st - lm.station) < half + radius then
					return
				end
			end
		end
		local need = if band == "midground" then halfRoad + 50 else halfRoad + 260
		if clearOfRoute(f.Position, radius, need) then
			table.insert(masses, {
				band = band,
				station = st,
				side = side,
				cframe = f,
				size = size,
				colour = pal.wall:Lerp(HAZE, if band == "midground" then 0.2 else 0.55),
				district = seg.district,
				segment = seg.index,
				roofTank = band == "midground"
					and (catalog.districtById[seg.district] :: Catalog.District).roofTanks == true
					and rng:NextNumber() < 0.6,
			})
		end
	end
	for _, seg in segments do
		local district = catalog.districtById[seg.district]
		for _, side in { -1, 1 } do
			if seg.kind ~= "BridgeDeck" then
				local count = math.max(1, math.floor(seg.length / 80 + 0.5))
				for i = 1, count do
					local u = (i - 0.5) * seg.length / count + rng:NextNumber(-8, 8)
					local size = Vector3.new(
						rng:NextInteger(36, 72),
						rng:NextInteger(district.midHeight[1], district.midHeight[2]),
						rng:NextInteger(28, 40)
					)
					addMass("midground", seg, side, u, 60 + rng:NextNumber(0, 40), size)
				end
			end
			local size = Vector3.new(
				rng:NextInteger(60, 140),
				rng:NextInteger(district.skyHeight[1], district.skyHeight[2]),
				rng:NextInteger(60, 120)
			)
			addMass("skyline", seg, side, seg.length / 2 + rng:NextNumber(-20, 20), 300 + rng:NextNumber(0, 480), size)
		end
	end

	local plan: Plan = {
		version = Sequencer.VERSION,
		seed = seedValue,
		requested = requested,
		length = round(length),
		laneWidth = laneWidth,
		lanes = lanes,
		shoulder = shoulder,
		halfRoad = halfRoad,
		kerb = Sequencer.KERB,
		sidewalk = Sequencer.SIDEWALK,
		frontage = frontage,
		catalogSource = catalog.source,
		palettes = palettes,
		segments = segments,
		districts = spans,
		lots = lots,
		landmarks = landmarks,
		signs = signs,
		props = props,
		spans = spanPlans,
		hazards = hazards,
		masses = masses,
		life = life,
		extras = {},
		world = nil,
		checks = nil :: any,
	}
	-- World build V2: the World's own layered additions (never run for Downtown or a World without a `v2` table)
	local world = catalog.world
	if world and world.v2 then
		WorldPlan.apply(plan, catalog, seedValue, { frame = frame, segAt = segAt, spanAt = spanAt })
	end
	plan.checks = Sequencer.check(plan, catalog, notes)
	return plan
end

-- Repeat / rule checks over a finished plan (reported, never hidden).
function Sequencer.check(plan: Plan, catalog: Catalog.Catalog?, extraNotes: { string }?): Checks
	local cat = catalog or Catalog.builtIn()
	local notes = extraNotes or {}
	local checks: Checks = {
		passed = true,
		routeLength = plan.length,
		atLeast2000 = plan.length >= 2000,
		districtLengths = {},
		districtLengthsOk = true,
		immediateLotRepeats = 0,
		immediatePaletteRepeats = 0,
		identicalPairs = 0,
		signRepeats = 0,
		landmarkRepeats = 0,
		landmarkSpacing = {},
		landmarkSpacingMin = 0,
		landmarkSpacingMax = 0,
		landmarkConflicts = 0,
		paletteViolations = 0,
		orientationViolations = 0,
		districtsWithoutSignature = {},
		requiredMissing = {},
		segmentJoinError = 0,
		spans = #plan.spans,
		notes = notes,
	}
	for _, span in plan.districts do
		table.insert(checks.districtLengths, span.length)
		if not span.truncated and (span.length < 480 or span.length > 720) then
			checks.districtLengthsOk = false
		end
	end
	for i = 2, #plan.segments do
		local a, b = plan.segments[i - 1], plan.segments[i]
		checks.segmentJoinError = math.max(checks.segmentJoinError, (a.finish.Position - b.start.Position).Magnitude)
	end
	-- the same name twice within SIGN_GAP studs, either side
	for i, a in plan.signs do
		for j = i + 1, #plan.signs do
			local b = plan.signs[j]
			if a.text == b.text and math.abs(a.station - b.station) < Sequencer.SIGN_GAP then
				checks.signRepeats += 1
			end
		end
	end
	for _, side in { -1, 1 } do
		local prev: LotPlan? = nil
		local prevSign = ""
		for _, lot in plan.lots do
			if lot.side == side and lot.module ~= "GAP" then
				if prev and prev.module == lot.module then
					checks.immediateLotRepeats += 1
				end
				if prev and lot.palette ~= "" and prev.palette == lot.palette then
					checks.immediatePaletteRepeats += 1
				end
				prev = lot
			end
			if lot.side == side and lot.sign then
				if lot.sign == prevSign then
					checks.signRepeats += 1
				end
				prevSign = lot.sign
			end
		end
	end
	for _, lot in plan.lots do
		if lot.side < 0 and lot.module ~= "GAP" then
			for _, other in plan.lots do
				if
					other.side > 0
					and other.module == lot.module
					and other.palette == lot.palette
					and lot.from < other.to
					and other.from < lot.to
				then
					checks.identicalPairs += 1
				end
			end
		end
		if lot.palette ~= "" then
			local district = cat.districtById[lot.district]
			local ok = false
			if district then
				for _, p in district.palettes do
					if p.id == lot.palette then
						ok = true
					end
				end
			end
			if not ok then
				checks.paletteViolations += 1
			end
		end
		if lot.kind == "corner" and lot.orientation ~= lot.required then
			checks.orientationViolations += 1
		end
		if lot.kind ~= "gap" then
			-- the facade (pivot LookVector) must face the road
			local road = Route.frame(plan.segments, lot.station)
			if lot.pivot.LookVector:Dot(-lot.side * road.RightVector) < 0.95 then
				checks.orientationViolations += 1
			end
		end
	end
	local prevLm: LandmarkPlan? = nil
	for _, lm in plan.landmarks do
		if prevLm then
			table.insert(checks.landmarkSpacing, math.floor(lm.station - prevLm.station + 0.5))
			if prevLm.id == lm.id then
				checks.landmarkRepeats += 1
			end
		end
		prevLm = lm
		if lm.placement == "frontage" then
			for _, h in plan.hazards do
				if lm.from < h.station + h.length + 60 and h.station - 60 < lm.to then
					checks.landmarkConflicts += 1
				end
			end
			for _, seg in plan.segments do
				if seg.kind == "Intersection" then
					local c = seg.startS + (seg.crossAt or 48)
					if lm.from < c + Route.MOUTH + 12 and c - Route.MOUTH - 12 < lm.to then
						checks.landmarkConflicts += 1
					end
				elseif seg.kind == "BridgeDeck" and lm.from < seg.endS and seg.startS < lm.to then
					checks.landmarkConflicts += 1
				end
			end
		end
	end
	if #checks.landmarkSpacing > 0 then
		checks.landmarkSpacingMin = math.huge
		for _, v in checks.landmarkSpacing do
			checks.landmarkSpacingMin = math.min(checks.landmarkSpacingMin, v)
			checks.landmarkSpacingMax = math.max(checks.landmarkSpacingMax, v)
		end
	end
	for i, span in plan.districts do
		local found = false
		for _, lm in plan.landmarks do
			if lm.id == span.landmark and lm.station >= span.startS and lm.station < span.endS then
				found = true
			end
		end
		if not found then
			table.insert(checks.districtsWithoutSignature, span.name .. " #" .. i)
		end
		-- Round 2 review: a required landmark that found no free frontage used to be skipped silently
		local district = cat.districtById[span.id]
		for _, wanted in if district then district.required or {} else {} do
			local have = false
			for _, lm in plan.landmarks do
				if lm.id == wanted and lm.station >= span.startS and lm.station < span.endS then
					have = true
				end
			end
			if not have then
				table.insert(checks.requiredMissing, span.name .. " #" .. i .. ": " .. wanted)
			end
		end
	end
	checks.passed = checks.atLeast2000
		and #checks.districtsWithoutSignature == 0
		and #checks.requiredMissing == 0
		and checks.districtLengthsOk
		and checks.immediateLotRepeats == 0
		and checks.identicalPairs == 0
		and checks.signRepeats == 0
		and checks.landmarkRepeats == 0
		and checks.landmarkConflicts == 0
		and checks.paletteViolations == 0
		and checks.orientationViolations == 0
		and checks.segmentJoinError < 0.01
	return checks
end

local function short(module: string): string
	return (string.gsub(module, "^B2_Lot_", ""))
end

-- A printable summary: seed, district boundaries, segment and module sequences, check results.
function Sequencer.describe(plan: Plan): string
	local lines: { string } = {}
	local function add(s: string)
		table.insert(lines, s)
	end
	local c = plan.checks
	add(string.format("=== Downtown B city plan %s  seed %d ===", plan.version, plan.seed))
	add(
		string.format(
			"route %.1f studs (requested %d; ~%.0f m PROVISIONAL at 1 stud = %.2f m)  lanes %d x %.1f + shoulders %.1f  frontage %.1f from centre",
			plan.length,
			math.floor(plan.requested),
			plan.length * Sequencer.STUDS_TO_METRES,
			Sequencer.STUDS_TO_METRES,
			plan.lanes,
			plan.laneWidth,
			plan.shoulder,
			plan.frontage
		)
	)
	add("catalogue: " .. plan.catalogSource)
	add("districts (explicit boundary table, studs):")
	for i, d in plan.districts do
		add(
			string.format(
				"  %d. %-13s cycle %d  %7.1f -> %7.1f  (%.1f; fixture target %d)%s  tile: %s",
				i,
				d.name,
				d.cycle,
				d.startS,
				d.endS,
				d.length,
				d.target,
				if d.truncated then " TRUNCATED" else "",
				d.landmark
			)
		)
	end
	local kinds = {}
	for _, seg in plan.segments do
		local tag = if seg.kind == "Straight" then "S" .. seg.length else seg.kind
		table.insert(kinds, tag)
	end
	add("segments (" .. #plan.segments .. "): " .. table.concat(kinds, " "))
	for _, side in { -1, 1 } do
		local seq = {}
		for _, lot in plan.lots do
			if lot.side == side then
				if lot.kind == "gap" then
					table.insert(seq, "gap" .. math.floor(lot.width + 0.5))
				else
					table.insert(seq, short(lot.module) .. (if lot.palette ~= "" then "/" .. lot.palette else ""))
				end
			end
		end
		add((if side < 0 then "left" else "right") .. " lots (" .. #seq .. "): " .. table.concat(seq, ", "))
	end
	local lms = {}
	for _, lm in plan.landmarks do
		table.insert(
			lms,
			string.format("%s@%.0f%s", lm.id, lm.station, if lm.side < 0 then "L" elseif lm.side > 0 then "R" else "")
		)
	end
	add("landmarks: " .. table.concat(lms, ", "))
	local sg = {}
	for _, sgn in plan.signs do
		table.insert(sg, string.format("%s(%s,%s)", sgn.text, sgn.style, if sgn.side < 0 then "L" else "R"))
	end
	add("signs (" .. #sg .. "): " .. table.concat(sg, ", "))
	local sp = {}
	for _, span in plan.spans do
		table.insert(sp, string.format("%s@%.0f", span.kind, span.station))
	end
	add("spans: " .. table.concat(sp, ", ") .. "  (clearance " .. Sequencer.SPAN_CLEARANCE .. " studs, PREVIEW)")
	local hz = {}
	for _, h in plan.hazards do
		table.insert(hz, string.format("%s@%.0f lane %d", h.kind, h.station, h.lane))
	end
	add("hazard previews (scenery only): " .. table.concat(hz, ", "))
	add(
		string.format(
			"counts: %d lots, %d props, %d masses, %d street-life spots",
			#plan.lots,
			#plan.props,
			#plan.masses,
			#plan.life
		)
	)
	add(string.format("CHECKS %s", if c.passed then "PASSED" else "FAILED"))
	add(
		string.format(
			"  route >= 2000: %s; district lengths 480-720: %s (%s)",
			tostring(c.atLeast2000),
			tostring(c.districtLengthsOk),
			table.concat(
				(function()
					local t = {}
					for _, v in c.districtLengths do
						table.insert(t, tostring(v))
					end
					return t
				end)(),
				" / "
			)
		)
	)
	add(
		string.format(
			"  immediate lot repeats %d, identical L/R pairs %d, sign repeats %d, landmark repeats %d",
			c.immediateLotRepeats,
			c.identicalPairs,
			c.signRepeats,
			c.landmarkRepeats
		)
	)
	add(
		string.format(
			"  palette repeats (adjacent, same side; allowed but counted) %d, palette violations %d, orientation violations %d",
			c.immediatePaletteRepeats,
			c.paletteViolations,
			c.orientationViolations
		)
	)
	add(
		string.format(
			"  landmark spacing %d..%d studs (target 500-700), conflicts with hazards/intersections/bridge %d",
			c.landmarkSpacingMin,
			c.landmarkSpacingMax,
			c.landmarkConflicts
		)
	)
	if #c.districtsWithoutSignature > 0 then
		add("  districts without their signature landmark: " .. table.concat(c.districtsWithoutSignature, ", "))
	end
	if #c.requiredMissing > 0 then
		add("  required landmarks not placed: " .. table.concat(c.requiredMissing, ", "))
	end
	add(string.format("  segment join error %.4f studs", c.segmentJoinError))
	for _, n in c.notes do
		add("  note: " .. n)
	end
	-- World build V2: WorldPlan's measured proofs of the approved rules
	local world = plan.world
	if world and world.checks then
		add(string.format("World V2 checks (%d extras placed):", #plan.extras))
		for _, ch in world.checks do
			add(string.format("  [%s] %s: %s", if ch.ok then "PASS" else "FAIL", ch.id, ch.detail))
		end
		for _, n in world.notes do
			add("  world note: " .. n)
		end
	end
	return table.concat(lines, "\n")
end

-- The district boundary table in the shape the HUD strip needs (studs, plus PROVISIONAL metres).
function Sequencer.boundaries(plan: Plan): { { [string]: any } }
	local out = {}
	for i, d in plan.districts do
		table.insert(out, {
			index = i,
			id = d.id,
			name = d.name,
			cycle = d.cycle,
			startStuds = d.startS,
			endStuds = d.endS,
			lengthStuds = d.length,
			lengthMetresProvisional = round(d.length * Sequencer.STUDS_TO_METRES, 0.1),
			landmark = d.landmark,
		})
	end
	return out
end

return Sequencer
