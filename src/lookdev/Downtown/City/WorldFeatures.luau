--!strict
-- WORLD FEATURES (Lane 3 look-dev preview; Dusty Highway and Summit Pass build, decision 0026). The World-specific placement
-- features that WorldPlan.apply runs after the scatter rules, each driven by a table in the World's `v2` data:
--   pins        one-off placements at a fraction of a district (the recurring summit horn, the knoll)
--   chains      pieces laid end to end along the road edge (berms, rails, garlands, rim stones)
--   lake        the Frozen Lake: ice tiles, shore rim, fishing huts, far-shore treeline, on the outside of the curve
--   tunnel      the Glacier Tunnel: portals, 32-stud bays with a seeded pattern of sky windows and gallery openings, flank walls
--   lift        the ski lift line: towers, a static crossing at 64+ studs, cable, fixed chairs; the path for WorldLife
--   companions  parts placed beside a landmark (the lodge wings and annex)
-- Pure data and maths: no instances; scenery only. Everything draws from WorldPlan's per-district streams.

local WorldFeatures = {}

export type Ctx = {
	plan: any,
	catalog: any,
	v2: any,
	h: { frame: (number, number?, number?) -> CFrame, segAt: (number) -> number, spanAt: (number) -> number },
	extras: { any },
	info: {
		notes: { string },
		stats: { [string]: number },
		gorges: { any },
		lift: any?,
		lake: any?,
		motion: any?,
		skiPaths: any?,
	},
	halfRoad: number,
	sizeOf: (any) -> Vector3,
	metaOf: (string?) -> { [string]: any }?, -- a kit mesh's meta table (cable_height, surface_path, ...)
	rngFor: (any, string) -> Random,
	onBridge: (number, number) -> boolean,
	nearHazard: (number, number, number) -> boolean,
	inGorge: (Vector3, number) -> boolean,
}

local function add(ctx: Ctx, e: { [string]: any })
	local station = e.station
	e.segment = ctx.h.segAt(station)
	e.band = e.band or "near"
	e.scale = e.scale or 1
	e.colour = e.colour or Color3.fromRGB(200, 200, 205)
	e.label = e.label or e.kind
	table.insert(ctx.extras, e)
end

-- the side (-1 left, 1 right) on the outside of the first curve of a district span (the lake and the lodge lie there)
local function outsideSide(ctx: Ctx, span: any): number
	for _, seg in ctx.plan.segments do
		if seg.district == span.id and seg.startS >= span.startS and seg.endS <= span.endS + 0.01 and seg.bend ~= 0 then
			return if seg.bend > 0 then -1 else 1
		end
	end
	return 1
end
WorldFeatures.outsideSide = outsideSide

local function sideOf(ctx: Ctx, span: any, side: any): number
	if side == "outside" then
		return outsideSide(ctx, span)
	elseif side == "inside" then
		return -outsideSide(ctx, span)
	end
	return side :: number
end

local function yawOf(mode: any, side: number, rng: Random): number
	if mode == "along" then
		return (if rng:NextNumber() < 0.5 then 1 else -1) * math.pi / 2
	elseif mode == "alongRoad" then
		return side * math.pi / 2 -- long axis along the route, front (-Z) toward the road
	elseif mode == "alongAway" then
		return -side * math.pi / 2
	elseif mode == "road" then
		-- front (-Z) toward the road: the same turn as "alongRoad" (a mesh whose front faces the road has its long axis along it)
		return side * math.pi / 2 + math.rad(rng:NextNumber(-6, 6))
	elseif mode == "quarter" then
		return rng:NextInteger(0, 3) * math.pi / 2
	elseif type(mode) == "number" then
		return math.rad(mode :: number) * side
	end
	return 0
end
WorldFeatures.yawOf = yawOf

-- pins ----------------------------------------------------------------------------------------------------
function WorldFeatures.pins(ctx: Ctx)
	local count = 0
	for _, pin in ctx.v2.pins or {} do
		for _, span in ctx.plan.districts do
			if span.id ~= pin.district then
				continue
			end
			local rng = ctx.rngFor(span, "pin:" .. pin.id)
			local side = sideOf(ctx, span, pin.side or 1)
			local st = span.startS + pin.t * (span.endS - span.startS)
			local size = ctx.sizeOf(pin)
			local sc = pin.scale or 1
			local f = ctx.h.frame(st, side * pin.lateral, pin.y or -1)
			local cf = f * CFrame.Angles(0, yawOf(pin.yaw, side, rng), 0)
			add(ctx, {
				kind = pin.kind or "backdrop",
				module = pin.m,
				label = pin.label or pin.id,
				cframe = cf,
				scale = sc,
				size = size * sc,
				colour = pin.colour,
				band = pin.band or "far",
				station = st,
				side = side,
				district = span.id,
			})
			count += 1
		end
	end
	ctx.info.stats.pins = count
end

-- chains --------------------------------------------------------------------------------------------------
function WorldFeatures.chains(ctx: Ctx)
	local total = 0
	for _, rule in ctx.v2.chains or {} do
		local count = 0
		for _, span in ctx.plan.districts do
			if not rule.districts[span.id] then
				continue
			end
			local rng = ctx.rngFor(span, "chain:" .. rule.id)
			local sides: { number } = if rule.sides == "outside" or rule.sides == "inside"
				then { sideOf(ctx, span, rule.sides) }
				else { -1, 1 }
			for _, side in sides do
				local recent: { string } = {}
				local st = span.startS + (rule.startPad or 0)
				local stop = span.endS - (rule.endPad or 0)
				while st < stop do
					local entry = rule.pool[rng:NextInteger(1, #rule.pool)]
					for _ = 1, 4 do
						if table.find(recent, entry.m) == nil or #rule.pool < 3 then
							break
						end
						entry = rule.pool[rng:NextInteger(1, #rule.pool)]
					end
					local size = ctx.sizeOf(entry)
					local sc = if rule.scale then rng:NextNumber(rule.scale[1], rule.scale[2]) else 1
					local len = math.max(size.X * sc, 4)
					local centre = st + len / 2
					local ok = true
					if centre > stop then
						break
					end
					if ctx.onBridge(centre, len / 2 + (rule.bridgePad or 0)) then
						ok = false
					end
					if
						ok
						and rule.hazardBefore
						and ctx.nearHazard(centre, rule.hazardBefore + len / 2, 10 + len / 2)
					then
						ok = false
					end
					if ok then
						local f = ctx.h.frame(centre, side * rule.lateral, rule.y or -0.3)
						local cf = f * CFrame.Angles(0, yawOf(rule.yaw or "alongRoad", side, rng), 0)
						add(ctx, {
							kind = rule.kind,
							module = entry.m,
							label = entry.label or rule.kind,
							cframe = cf,
							scale = sc,
							size = size * sc,
							colour = rule.colour,
							band = rule.band or "near",
							station = centre,
							side = side,
							district = span.id,
						})
						table.insert(recent, entry.m)
						if #recent > 2 then
							table.remove(recent, 1)
						end
						count += 1
					end
					local gap = if rule.gap then rng:NextNumber(rule.gap[1], rule.gap[2]) else 0
					st += len * (rule.step or 1) + gap
				end
			end
		end
		ctx.info.stats["chain:" .. rule.id] = count
		total += count
	end
	ctx.info.stats.chains = total
end

-- lake ----------------------------------------------------------------------------------------------------
-- The Frozen Lake (plan 7.3): a plane of at least 240 x 360 studs on the outside of the curve, its near edge 90+ studs from
-- the centre line (a 40-stud buffer beyond the road edge), a dark rim and a fence between it and the road, no gap, no ramp.
function WorldFeatures.lake(ctx: Ctx)
	local cfg = ctx.v2.lake
	if not cfg then
		return
	end
	local measured: { { [string]: number } } = {}
	for _, span in ctx.plan.districts do
		if span.id ~= cfg.district then
			continue
		end
		local rng = ctx.rngFor(span, "lake")
		local side = sideOf(ctx, span, cfg.side or "outside")
		local tileAlong = cfg.tileAlong
		local tileAcross = cfg.tileAcross
		local nAlong, nAcross = cfg.along, cfg.across
		local centreS = span.startS + (span.endS - span.startS) * (cfg.t or 0.5)
		local s0 = centreS - nAlong * tileAlong / 2
		for a = 0, nAlong - 1 do
			for c = 0, nAcross - 1 do
				local st = s0 + (a + 0.5) * tileAlong
				local lateral = cfg.nearEdge + (c + 0.5) * tileAcross
				local name = if (a + c) % 2 == 0 then cfg.tiles[1] else cfg.tiles[#cfg.tiles]
				local size = ctx.sizeOf({ m = name })
				local f = ctx.h.frame(st, side * lateral, cfg.y or -0.3)
				local cf = f * CFrame.Angles(0, if cfg.tileAlongX then math.pi / 2 else 0, 0)
				add(ctx, {
					kind = "lake",
					module = name,
					label = "LAKE ICE",
					cframe = cf,
					scale = 1,
					size = size,
					colour = Color3.fromRGB(176, 214, 238),
					band = "near",
					station = st,
					side = side,
					district = span.id,
				})
			end
		end
		table.insert(measured, {
			across = nAcross * tileAcross,
			along = nAlong * tileAlong,
			nearEdge = cfg.nearEdge,
			farEdge = cfg.nearEdge + nAcross * tileAcross,
			side = side,
			station = centreS,
		})
		-- the shore rim along the near edge (dark rocks and frozen reeds), end to end across the plane's length
		if cfg.rim then
			local st = s0
			local k = 0
			while st < s0 + nAlong * tileAlong - 8 do
				local entry = cfg.rim[k % #cfg.rim + 1]
				local size = ctx.sizeOf({ m = entry })
				local len = math.max(size.X, 12)
				local centre = st + len / 2
				local f = ctx.h.frame(centre, side * (cfg.nearEdge - (cfg.rimInset or 2)), -0.5)
				add(ctx, {
					kind = "lake",
					module = entry,
					label = "LAKE RIM",
					cframe = f * CFrame.Angles(0, yawOf("alongRoad", side, rng), 0),
					scale = 1,
					size = size,
					colour = Color3.fromRGB(62, 70, 86),
					band = "near",
					station = centre,
					side = side,
					district = span.id,
				})
				st += len * 0.96
				k += 1
			end
		end
		for i = 1, cfg.huts or 0 do
			local entry = cfg.hutPool[(i - 1) % #cfg.hutPool + 1]
			local size = ctx.sizeOf({ m = entry })
			local st = centreS + rng:NextNumber(-nAlong * tileAlong * 0.32, nAlong * tileAlong * 0.32)
			local lateral = cfg.nearEdge + rng:NextNumber(30, nAcross * tileAcross - 30)
			local f = ctx.h.frame(st, side * lateral, (cfg.y or -0.3) + (cfg.hutLift or 0.8))
			add(ctx, {
				kind = "lake",
				module = entry,
				label = "FISHING HUT",
				cframe = f * CFrame.Angles(0, yawOf("road", side, rng) + math.rad(rng:NextNumber(-20, 20)), 0),
				scale = 1,
				size = size,
				colour = Color3.fromRGB(150, 98, 66),
				band = "near",
				station = st,
				side = side,
				district = span.id,
			})
		end
	end
	ctx.info.stats.lakeTiles = #measured
	ctx.info.lake = measured
end

-- tunnel --------------------------------------------------------------------------------------------------
-- The Glacier Tunnel (plan 7.4): an opaque horseshoe gallery of 32-stud bays along the bridge-style span, a seeded pattern
-- of sky-window and gallery bays (at least three openings in twelve, never three in a row), portals at both ends and flank
-- walls, so the opening is cut into a mass. Kit conventions (kit_summit2.py): the route runs toward -Z and every tunnel
-- piece's FRONT is its +Z face. A bay's pivot is the bottom centre of its START face (it fills z 0 to -32); the portal-in's
-- pivot is its outer face plane (it fills 28 studs on from there, so it stands in front of the span); the portal-out's pivot
-- joins the last bay's end (it fills 28 studs beyond the span); a flank wall is 64 wide with its front plate at z = 0.
function WorldFeatures.tunnel(ctx: Ctx)
	local cfg = ctx.v2.tunnel
	if not cfg then
		return
	end
	local bays = 0
	local openings = 0
	local function put(name: string, label: string, station: number, lateral: number, yaw: number, spanId: string)
		local size = ctx.sizeOf({ m = name })
		add(ctx, {
			kind = "tunnel",
			module = name,
			label = label,
			cframe = ctx.h.frame(station, lateral, cfg.y or 0) * CFrame.Angles(0, yaw, 0),
			scale = 1,
			size = size,
			colour = Color3.fromRGB(150, 190, 220),
			band = "near",
			station = station,
			side = if lateral == 0 then 0 elseif lateral > 0 then 1 else -1,
			district = spanId,
		})
	end
	for _, lm in ctx.plan.landmarks do
		if lm.placement ~= "bridge" or lm.district ~= cfg.district then
			continue
		end
		local span = ctx.plan.districts[ctx.h.spanAt(lm.station)]
		local rng = ctx.rngFor(span, "tunnel")
		local n = math.floor((lm.to - lm.from) / cfg.bayLength + 0.5)
		-- the opening pattern: a seeded variation of the plan's example (bays 2, 5, 6, 9, 11 of 12)
		local open: { [number]: boolean } = {}
		local shift = rng:NextInteger(-1, 1)
		for _, i in cfg.pattern or { 2, 5, 6, 9, 11 } do
			open[math.clamp(i + shift, 1, n - 1)] = true
		end
		for i = 1, n - 2 do
			if open[i] and open[i + 1] and open[i + 2] then
				open[i + 1] = nil
			end
		end
		local nOpen = 0
		for _ in open do
			nOpen += 1
		end
		local flip = rng:NextNumber() < 0.5
		local kOpen = 0
		for i = 1, n do
			local name: string
			local mirrored = false
			if open[i] then
				kOpen += 1
				if kOpen % 2 == 1 then
					name = cfg.sky
				else
					name = cfg.gallery
					flip = not flip
					mirrored = flip
				end
				openings += 1
			else
				name = cfg.bays[(i + rng:NextInteger(0, 2)) % #cfg.bays + 1]
			end
			local start = lm.from + (i - 1) * cfg.bayLength
			-- a mirrored gallery bay is turned half a circle about its far face so it still fills its own 32 studs
			if mirrored then
				put(name, "TUNNEL BAY", start + cfg.bayLength, 0, math.pi, span.id)
			else
				put(name, "TUNNEL BAY", start, 0, 0, span.id)
			end
			bays += 1
		end
		local portalHalf = ctx.sizeOf({ m = cfg.portalIn }).X / 2
		for _, which in { "in", "out" } do
			local name = if which == "in" then cfg.portalIn else cfg.portalOut
			local st = if which == "in" then lm.from - cfg.portalDepth else lm.to
			put(name, if which == "in" then "GLACIER TUNNEL" else "TUNNEL EXIT", st, 0, 0, span.id)
			-- flank walls beside the portal plate: the tall end of each toward the opening
			for _, side in { -1, 1 } do
				local wall = if side < 0 then cfg.wall[1] else cfg.wall[#cfg.wall]
				local half = ctx.sizeOf({ m = wall }).X / 2
				put(wall, "TUNNEL FLANK", st, side * (portalHalf + half - (cfg.wallOverlap or 0)), 0, span.id)
			end
			if which == "in" and cfg.iceFall then
				for _, side in { -1, 1 } do
					put(cfg.iceFall, "ICE FALL", st, side * (cfg.iceFallLateral or 68), 0, span.id)
				end
			end
		end
		ctx.info.stats.tunnelBays = bays
		ctx.info.stats.tunnelOpenings = nOpen
	end
	ctx.info.stats.tunnelOpeningBays = openings
end

-- lift ----------------------------------------------------------------------------------------------------
-- The ski lift line (plan 7.2): from the base station on the frontage, a static crossing at least 64 studs above the deck, then
-- up the far side's glade slope to the top station. Towers stand on the ground (flat nodes) or on the glade's own slope
-- (read from the glade mesh's `surface_path`), the cable is chained straight 24-stud pieces along a sagging curve, chairs
-- are fixed on the crossing; the far-leg path goes to WorldLife, whose moving chairs stay at least 60 studs from the road.
function WorldFeatures.lift(ctx: Ctx)
	local cfg = ctx.v2.lift
	if not cfg then
		return
	end
	local paths: { any } = {}
	for _, span in ctx.plan.districts do
		if span.id ~= cfg.district then
			continue
		end
		local rng = ctx.rngFor(span, "lift")
		local base: any = nil
		for _, lm in ctx.plan.landmarks do
			if lm.id == cfg.baseLandmark and lm.station >= span.startS and lm.station < span.endS then
				base = lm
			end
		end
		local side = if base then base.side else 1
		local far = -side
		local s0 = if base then base.station else span.startS + (span.endS - span.startS) * 0.3
		local routeFrame = ctx.h.frame(s0)
		local function lateralOf(p: Vector3): number
			return routeFrame:PointToObjectSpace(p).X
		end
		-- the far-side glade the line climbs
		local glade: CFrame? = nil
		local meta = ctx.metaOf(cfg.glade)
		if cfg.glade and meta then
			local gst = s0 + (cfg.gladeStation or 18)
			glade = ctx.h.frame(gst, far * cfg.gladeLateral, -1) * CFrame.Angles(0, yawOf("alongRoad", far, rng), 0)
			add(ctx, {
				kind = "backdrop",
				module = cfg.glade,
				label = "SKI GLADE",
				cframe = glade,
				scale = 1,
				size = ctx.sizeOf({ m = cfg.glade }),
				colour = Color3.fromRGB(58, 104, 98),
				band = "near",
				station = gst,
				side = far,
				district = span.id,
			})
		end
		-- node list: { position (ground point), cable height above that ground, tower module or false }
		local nodes: { { any } } = {}
		for _, n in cfg.flat do
			local ground = ctx.h.frame(s0 + (n[4] or 0), side * n[1], -0.3).Position
			table.insert(nodes, { ground, n[2], n[3] })
		end
		if glade and meta and type(meta.surface_path) == "table" then
			local clears = cfg.slopeClear or {}
			for i, pt in meta.surface_path do
				local p: Vector3 = (glade :: CFrame):PointToWorldSpace(Vector3.new(pt[1], pt[2], pt[3]))
				local last = i == #meta.surface_path
				table.insert(nodes, { p, clears[i] or 34, if last then cfg.top else "auto" })
			end
		end
		-- towers
		local points: { Vector3 } = {}
		local lat: { number } = {}
		for i, n in nodes do
			local ground: Vector3, height: number, tower: any = n[1], n[2], n[3]
			table.insert(points, ground + Vector3.new(0, height, 0))
			table.insert(lat, lateralOf(ground))
			if tower then
				local name = tower :: string
				local sc = 1
				if name == "auto" then
					local best = math.huge
					for _, cand in cfg.towers do
						local ch = (ctx.metaOf(cand) or {}).cable_height or 60
						local s = height / ch
						local score = math.abs(math.log(s))
						if s >= 0.75 and s <= 1.35 and score < best then
							best, name, sc = score, cand, s
						end
					end
					if name == "auto" then
						name = cfg.towers[2]
						sc = math.clamp(height / ((ctx.metaOf(name) or {}).cable_height or 60), 0.75, 1.35)
					end
				end
				local isTop = name == cfg.top
				add(ctx, {
					kind = "lift",
					module = name,
					label = if isTop then "LIFT TOP STATION" else "LIFT TOWER",
					cframe = CFrame.new(ground)
						* CFrame.Angles(0, yawOf("alongRoad", if lat[i] >= 0 then 1 else -1, rng), 0),
					scale = sc,
					size = ctx.sizeOf({ m = name }) * sc,
					colour = Color3.fromRGB(110, 124, 146),
					band = "near",
					station = s0,
					side = if lat[i] >= 0 then 1 else -1,
					district = span.id,
				})
			end
		end
		-- the cable: straight pieces along the sagging curve between consecutive nodes (the mesh is long on X)
		local cableMeta = ctx.metaOf(cfg.cable) or {}
		local cableAt = cableMeta.cable_height or 4.2
		local pieceLen = math.max(ctx.sizeOf({ m = cfg.cable }).X, 8)
		local lowest = math.huge
		local crossing: { number } = {}
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local length = (b - a).Magnitude
			local count = math.max(1, math.floor(length / pieceLen + 0.5))
			local sag = (cfg.sag or 5) * length / 100
			local prev = a
			for k = 1, count do
				local u = k / count
				local p = a:Lerp(b, u) - Vector3.new(0, sag * 4 * u * (1 - u), 0)
				local d = p - prev
				local pieceSc = d.Magnitude / pieceLen
				local x = d.Unit
				local z = x:Cross(Vector3.yAxis).Unit
				local y = z:Cross(x)
				local mid = (prev + p) / 2
				add(ctx, {
					kind = "lift",
					module = cfg.cable,
					label = "LIFT CABLE",
					cframe = CFrame.fromMatrix(mid - y * cableAt * pieceSc, x, y, z),
					scale = pieceSc,
					size = Vector3.new(pieceLen * pieceSc, 1, 1),
					colour = Color3.fromRGB(60, 62, 70),
					band = "near",
					station = s0,
					side = side,
					district = span.id,
				})
				if math.abs(lateralOf(p)) < ctx.halfRoad + 2 then
					lowest = math.min(lowest, p.Y)
					table.insert(crossing, i)
				end
				prev = p
			end
		end
		-- fixed chairs on the crossing (static: Option M, moving chairs over the road, is a proposal for Brian R)
		if cfg.chairs and #crossing > 0 then
			local i = crossing[math.ceil(#crossing / 2)]
			local a, b = points[i], points[i + 1]
			for k, u in { 0.3, 0.7 } do
				local p = a:Lerp(b, u) - Vector3.new(0, (cfg.sag or 5) * (b - a).Magnitude / 100 * 4 * u * (1 - u), 0)
				local name = cfg.chairs[k % #cfg.chairs + 1]
				local grip = (ctx.metaOf(name) or {}).grip_height or 6
				add(ctx, {
					kind = "lift",
					module = name,
					label = "CHAIR",
					cframe = CFrame.new(p - Vector3.new(0, grip, 0))
						* CFrame.Angles(0, yawOf("alongRoad", side, rng), 0),
					scale = 1,
					size = ctx.sizeOf({ m = name }),
					colour = Color3.fromRGB(204, 72, 66),
					band = "near",
					station = s0,
					side = side,
					district = span.id,
				})
			end
		end
		-- the far runs where a chair may move: consecutive nodes on one side, every one at least 60 studs beyond the road edge
		local legs: { { Vector3 } } = {}
		local run: { Vector3 } = {}
		local runSign = 0
		for i = 1, #points do
			local sign = if lat[i] >= 0 then 1 else -1
			local ok = math.abs(lat[i]) >= ctx.halfRoad + 60
			if ok and (runSign == 0 or runSign == sign) then
				table.insert(run, points[i])
				runSign = sign
			else
				if #run >= 2 then
					table.insert(legs, run)
				end
				run, runSign = {}, 0
				if ok then
					table.insert(run, points[i])
					runSign = sign
				end
			end
		end
		if #run >= 2 then
			table.insert(legs, run)
		end
		table.insert(paths, {
			points = points,
			legs = legs,
			side = side,
			district = span.id,
			crossingHeight = lowest,
			clearance = cfg.minClearance or 64,
		})
		ctx.info.stats.liftCrossing = if lowest == math.huge then 0 else lowest
		ctx.info.stats.liftNodes = #points
	end
	ctx.info.lift = paths
end

-- skiers --------------------------------------------------------------------------------------------------
-- The centre line of every ski glade the plan placed, in world space (read from the glade mesh's `surface_path`): WorldLife
-- runs up to eight distant skiers down them (120+ studs from the road, never near the carriageway).
function WorldFeatures.skiers(ctx: Ctx)
	local modules = ctx.v2.skiers
	if not modules then
		return
	end
	local paths: { any } = {}
	for _, e in ctx.extras do
		if table.find(modules, e.module) then
			local meta = ctx.metaOf(e.module)
			if meta and type(meta.surface_path) == "table" then
				local points: { Vector3 } = {}
				for _, pt in meta.surface_path do
					table.insert(
						points,
						(e.cframe :: CFrame):PointToWorldSpace(Vector3.new(pt[1], pt[2], pt[3]) * e.scale)
					)
				end
				table.insert(paths, { points = points, station = e.station })
			end
		end
	end
	ctx.info.skiPaths = paths
	ctx.info.stats.skiPaths = #paths
end

-- motion --------------------------------------------------------------------------------------------------
-- Where the approved Dusty motion lives (plan 7, Adam's answer 9): the windmill wheel's hub (0.1 turns per second), at most
-- two pennant strings of eight inside the Diner Strip forecourt area (parallel to the road, 60+ studs from the centre line,
-- never over the road) and one far shimmer strip. WorldLife builds the moving parts from plain Parts; this only places them.
function WorldFeatures.motion(ctx: Ctx)
	local cfg = ctx.v2.motion
	if not cfg then
		return
	end
	local out: { [string]: any } = { windmills = {}, pennants = {}, shimmers = {} }
	if cfg.windmill then
		local size = ctx.sizeOf({ m = cfg.windmill.mesh })
		for _, lm in ctx.plan.landmarks do
			if lm.id == cfg.windmill.landmark then
				-- a lot-frame mesh is centred in its landmark slot: its pivot sits (slot - mesh) / 2 in from the front-left corner
				local pivot: CFrame = lm.pivot * CFrame.new((lm.width - size.X) / 2, 0, (lm.depth - size.Z) / 2)
				local hub: Vector3 = pivot:PointToWorldSpace(cfg.windmill.hub)
				table.insert(
					out.windmills,
					{ hub = hub, normal = pivot.XVector, radius = cfg.windmill.radius, station = lm.station }
				)
			end
		end
	end
	if cfg.pennants then
		local placed = 0
		for _, lm in ctx.plan.landmarks do
			if lm.id == cfg.pennants.landmark and placed < cfg.pennants.count then
				for i = 1, cfg.pennants.count - placed do
					local st = lm.station + lm.width / 2 + 24 + (i - 1) * 40
					if not ctx.onBridge(st, 20) and not ctx.nearHazard(st, 80, 40 + cfg.pennants.length) then
						local a = ctx.h.frame(st, lm.side * cfg.pennants.lateral, cfg.pennants.height).Position
						local b = ctx.h.frame(
							st + cfg.pennants.length,
							lm.side * cfg.pennants.lateral,
							cfg.pennants.height
						).Position
						table.insert(out.pennants, { a = a, b = b, station = st })
						placed += 1
					end
				end
			end
		end
	end
	if cfg.shimmer then
		for _, span in ctx.plan.districts do
			if span.id == cfg.shimmer.district then
				local side = sideOf(ctx, span, cfg.shimmer.side or "outside")
				local st = span.startS + (span.endS - span.startS) * (cfg.shimmer.t or 0.5)
				local f = ctx.h.frame(st, side * cfg.shimmer.lateral, 0.05)
				table.insert(out.shimmers, {
					cframe = f * CFrame.Angles(0, math.pi / 2, 0),
					length = cfg.shimmer.length,
					width = cfg.shimmer.width,
					station = st,
				})
			end
		end
	end
	ctx.info.motion = out
	ctx.info.stats.windmills = #out.windmills
	ctx.info.stats.pennantStrings = #out.pennants
	ctx.info.stats.shimmerStrips = #out.shimmers
end

-- signs ---------------------------------------------------------------------------------------------------
-- Fixed wayfinding boards with words (the district plaque, "SHADE AND SODA AHEAD", "LOOKOUT", "CANYON BRIDGE AHEAD",
-- "LAST FILL, THEN SAND"): part-built boards, never within 80 studs of a hazard, none on a bridge, facing the oncoming cars.
function WorldFeatures.signs(ctx: Ctx)
	local count = 0
	for _, board in ctx.v2.signs or {} do
		for _, span in ctx.plan.districts do
			if span.id ~= board.district then
				continue
			end
			local st = span.startS + board.t * (span.endS - span.startS)
			for _ = 1, 6 do
				if ctx.onBridge(st, 24) or ctx.nearHazard(st, 80, 80) then
					st -= 40
				else
					break
				end
			end
			if st > span.startS and not ctx.onBridge(st, 24) and not ctx.nearHazard(st, 80, 80) then
				local side = sideOf(ctx, span, board.side or 1)
				local f = ctx.h.frame(st, side * board.lateral, 0)
				add(ctx, {
					kind = "sign",
					module = "",
					label = board.text,
					text = board.text,
					cframe = f * CFrame.Angles(0, math.pi + side * math.rad(14), 0),
					scale = 1,
					size = Vector3.new(board.w, board.h, 0.5),
					colour = Color3.fromRGB(250, 244, 228),
					band = "near",
					station = st,
					side = side,
					district = span.id,
				})
				count += 1
			end
		end
	end
	ctx.info.stats.boards = count
end

-- warnings ------------------------------------------------------------------------------------------------
-- The hazard readability kit (plan 6.5; scenery previews, hazards are Brian R's): a warning board `ahead` studs before
-- each hazard on the side of its lane, and a wind-sock marker at a sand drift. Hazard-only look (orange and white).
function WorldFeatures.warnings(ctx: Ctx)
	local cfg = ctx.v2.warnings
	if not cfg then
		return
	end
	local boards, socks = 0, 0
	for _, hz in ctx.plan.hazards do
		local st = hz.station - cfg.ahead
		local span = ctx.plan.districts[ctx.h.spanAt(st)]
		if st > 20 and span and not ctx.onBridge(st, 20) then
			local side = if hz.lane >= 3 then 1 else -1
			local size = ctx.sizeOf({ m = cfg.board })
			add(ctx, {
				kind = "sign",
				module = cfg.board,
				label = "HAZARD BOARD",
				cframe = ctx.h.frame(st, side * cfg.lateral, 0) * CFrame.Angles(0, math.pi + side * math.rad(12), 0),
				scale = 1,
				size = size,
				colour = Color3.fromRGB(240, 120, 30),
				band = "near",
				station = st,
				side = side,
				district = span.id,
			})
			boards += 1
			if cfg.sock and hz.kind == cfg.sockKind then
				local ss = hz.station - 14
				local sockSize = ctx.sizeOf({ m = cfg.sock })
				add(ctx, {
					kind = "sign",
					module = cfg.sock,
					label = "WIND SOCK",
					cframe = ctx.h.frame(ss, side * (cfg.lateral - 2), 0),
					scale = 1,
					size = sockSize,
					colour = Color3.fromRGB(240, 120, 30),
					band = "near",
					station = ss,
					side = side,
					district = span.id,
				})
				socks += 1
			end
		end
	end
	ctx.info.stats.hazardBoards = boards
	ctx.info.stats.windSocks = socks
end

-- companions ----------------------------------------------------------------------------------------------
-- Parts placed beside a landmark in its own frame (front-left corner pivot, facade toward the road): the lodge's two wings
-- and annex. `x` may be a number, "leftOf" or "rightOf" (relative to the landmark's own mesh, centred in its slot).
function WorldFeatures.companions(ctx: Ctx)
	local count = 0
	for _, comp in ctx.v2.companions or {} do
		for _, lm in ctx.plan.landmarks do
			if lm.id ~= comp.landmark then
				continue
			end
			local hall = ctx.sizeOf({ m = comp.hall })
			for _, part in comp.parts do
				local size = ctx.sizeOf(part)
				local x: number
				if part.x == "leftOf" then
					x = (lm.width - hall.X) / 2 - size.X - (part.gap or 0)
				elseif part.x == "rightOf" then
					x = (lm.width + hall.X) / 2 + (part.gap or 0)
				else
					x = part.x :: number
				end
				local cf = (lm.pivot :: CFrame) * CFrame.new(x, 0, part.z or 0)
				add(ctx, {
					kind = "mass",
					module = part.m,
					label = part.label or "WING",
					cframe = cf,
					scale = 1,
					size = size,
					colour = Color3.fromRGB(150, 98, 66),
					band = "near",
					station = lm.station + (x + size.X / 2 - lm.width / 2),
					side = lm.side,
					district = lm.district,
				})
				count += 1
			end
		end
	end
	ctx.info.stats.companions = count
end

return WorldFeatures
