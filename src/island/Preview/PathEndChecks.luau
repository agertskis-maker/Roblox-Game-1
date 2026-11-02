--!strict
-- DEVELOPMENT CHECK (Lane 3, big round N1-01 and N1-02). Read-only: lists every path end, every portal
-- apron and every bridge deck end on the island hub, and reports paving that sticks out past where a
-- path should stop. Run it in Studio edit mode:
--
--   local I = game.ServerStorage.Island:Clone(); I.Parent = game.ServerStorage
--   local C = require(I.Preview.PathEndChecks)
--   print(C.selfTest())              -- each check catches a planted fault (path data only, no build needed)
--   local r = C.run()                -- the built island if it is there (Workspace.Lane3_IslandPreview), else the data
--   print(C.text(r))                 -- r.failures is empty when every end is clean; r.checked counts the ends
--   C.run("data")                    -- what Park would build now, from Layout (no island needed)
--   C.run("built")                   -- the placed strips only; errors if the island is not built
--
-- Positions in the text are world (X, Z). Plan y is world -Z.
--
-- Three things are measured, each on the actual strips (the placed parts, or Layout.stripsAlong's):
--   free / tip   a path end with no other paving at its last point, or the tip of a wide path where a
--                narrower one ends: its strip must not run past the last point by more than FLUSH. This
--                is the rectangular stub the garden ring's tails and the promenade's tips used to have.
--   joined       an end that arrives at other paving (the plaza, a path, a pad, a building forecourt): the
--                line across the strip's end must lie on that paving, within STICKS_OUT. A corner outside
--                it is a spike. This is the sharp thing under the side portals.
--   apron        nothing is paved south of the stage walk's south edge under a portal (APRON_DEEP).
--   bridge       each path strip meets its bridge deck end to within DECK_TOLERANCE.
-- A known residual is listed in `notes`, not `failures`, while it stays within its limit.

local Layout = require(script.Parent.Parent.Hub.Layout)

local PathEndChecks = {}

local park = Layout.Data.park

local FLUSH = 0.05 -- studs a free end may run past its last point
local STICKS_OUT = 0.25 -- studs a joined end's line may stand outside the paving it joins
local APRON_DEEP = 0.15
local DECK_TOLERANCE = 0.1
local ON_PAVING = 0.05
local EQUAL_WIDTH = 0.5
local END_SAMPLES = 10 -- points along an end line, corners included
local REACH = 30 -- paving farther than width + this from an end cannot matter

-- Ends that cannot be hidden by a square strip, kept visible here so nobody mistakes them for new faults.
local KNOWN: { [string]: { limit: number, reason: string } } = {
	["ForecourtEast finish"] = {
		limit = 2.5,
		reason = "meets the promenade tip at 73 degrees: a 10-wide square end cannot lie inside the flush tip",
	},
	["ForecourtWest finish"] = {
		limit = 2.5,
		reason = "meets the promenade tip at 73 degrees: a 10-wide square end cannot lie inside the flush tip",
	},
	["SpurSnackCornerEast start"] = {
		limit = 2.5,
		reason = "runs along the pad's front border: the end corner is the spur's own width, not a spike",
	},
	["SpurSnackCornerWest start"] = {
		limit = 2.5,
		reason = "runs along the pad's front border: the end corner is the spur's own width, not a spike",
	},
}

export type Strip = { kind: string, a: Vector2, b: Vector2, width: number }
export type Row = {
	what: string, -- "path end", "apron" or "bridge end"
	name: string,
	class: string, -- free, tip, joined, apron, bridge
	host: string, -- the nearest paving
	point: Vector2,
	run: number, -- past the last point (path end), how deep (apron), past the deck end (bridge)
	gap: number, -- from the last point to the nearest paving
	exposure: number, -- how far the end line stands outside the paving
	ok: boolean,
}
export type Report = {
	source: string,
	checked: number,
	failures: { string },
	notes: { string },
	counts: { [string]: number }, -- failures by class
	rows: { Row },
}

local function at(p: Vector2): string
	return string.format("world (%.1f, %.1f)", p.X, -p.Y)
end

-- What Park builds now, from Layout (the same function the recipe calls, with the same bridge cuts:
-- half the span each side of the deck centre, Bridges.pathCut).
function PathEndChecks.stripsFromData(): { Strip }
	local out: { Strip } = {}
	for _, path in park.paths do
		local cuts: { Layout.Cut } = {}
		for _, b in park.bridges do
			if b.path == path.kind then
				table.insert(cuts, { at = b.at, half = b.span / 2 })
			end
		end
		for _, s in Layout.stripsAlong(path.points, path.width, cuts, Layout.PathEndRuns[path.kind]) do
			table.insert(out, { kind = path.kind, a = s.a, b = s.b, width = path.width })
		end
	end
	return out
end

-- The strips placed in the built island (Workspace.Lane3_IslandPreview.Island.Plaza.Paths), or nil.
function PathEndChecks.stripsFromBuild(): { Strip }?
	local node: Instance? = workspace
	for _, name in { "Lane3_IslandPreview", "Island", "Plaza", "Paths" } do
		node = if node then node:FindFirstChild(name) else nil
	end
	if not node then
		return nil
	end
	local widths: { [string]: boolean } = {}
	for _, path in park.paths do
		widths[path.kind] = true
	end
	local out: { Strip } = {}
	for _, d in node:GetChildren() do
		if d:IsA("BasePart") and widths[d.Name] then
			-- Kit.strip: the part's Z is its length, looking from a toward b
			local half = d.CFrame.LookVector * (d.Size.Z / 2)
			table.insert(out, {
				kind = d.Name,
				a = Layout.worldToPlan(d.Position - half),
				b = Layout.worldToPlan(d.Position + half),
				width = d.Size.X,
			})
		end
	end
	return out
end

local function analyse(strips: { Strip }, source: string): Report
	local report: Report = { source = source, checked = 0, failures = {}, notes = {}, counts = {}, rows = {} }
	local function record(row: Row, failure: string?, note: string?)
		report.checked += 1
		table.insert(report.rows, row)
		if failure then
			table.insert(report.failures, failure)
			report.counts[row.class] = (report.counts[row.class] or 0) + 1
		end
		if note then
			table.insert(report.notes, note)
		end
	end

	-- the paving round `centre` that is not `kind`'s own: the other paths' strips and the structures
	local function pavingNear(centre: Vector2, kind: string?, reach: number): { Layout.Rect }
		local rects: { Layout.Rect } = {}
		for _, s in strips do
			if s.kind ~= kind and Layout.rectGap(centre, s.a, s.b, s.width / 2) < reach then
				table.insert(rects, { id = s.kind, a = s.a, b = s.b, half = s.width / 2 })
			end
		end
		for _, r in Layout.StructureRects do
			if Layout.rectGap(centre, r.a, r.b, r.half) < reach then
				table.insert(rects, r)
			end
		end
		return rects
	end

	-- every path end ----------------------------------------------------------------------------
	for _, path in park.paths do
		local pts = path.points
		for _, atStart in { true, false } do
			local point = if atStart then pts[1] else pts[#pts]
			local inner = if atStart then pts[2] else pts[#pts - 1]
			local d = (point - inner).Unit
			local n = Vector2.new(-d.Y, d.X)
			local w = path.width
			local name = path.kind .. (if atStart then " start" else " finish")

			-- the end of this path's own strips: the strip end furthest along, within a width sideways
			local endAt: Vector2? = nil
			local endStrip: Strip? = nil
			local along = -math.huge
			for _, s in strips do
				if s.kind == path.kind then
					for _, e in { s.a, s.b } do
						local rel = e - point
						local x = rel:Dot(d)
						if math.abs(rel:Dot(n)) <= w and x >= -(w + 12) and x > along then
							along, endAt, endStrip = x, e, s
						end
					end
				end
			end
			if not endAt or not endStrip then
				record({
					what = "path end",
					name = name,
					class = "free",
					host = "",
					point = point,
					run = 0,
					gap = 0,
					exposure = 0,
					ok = false,
				}, string.format("%s: no strip reaches this end (%s)", name, at(point)), nil)
				continue
			end
			local sd = (endStrip.b - endStrip.a).Unit
			local sn = Vector2.new(-sd.Y, sd.X)

			local rects = pavingNear(point, path.kind, w + REACH)
			local gap, host = Layout.gapTo(point, rects, Layout.StructureDiscs)
			local hosted = gap <= ON_PAVING
			-- the tip of a wide path where a narrower one ends has nothing to hide
			local tip = false
			if hosted then
				for _, other in park.paths do
					if other.kind ~= path.kind and other.width < w - EQUAL_WIDTH then
						local op = other.points
						if (op[1] - point).Magnitude <= ON_PAVING or (op[#op] - point).Magnitude <= ON_PAVING then
							tip = true
						end
					end
				end
			end

			-- how far the end line stands outside the paving, and where
			local exposure, worst = 0, endAt
			for k = 0, END_SAMPLES do
				local q = endAt + sn * (-w / 2 + w * k / END_SAMPLES)
				local g = Layout.gapTo(q, rects, Layout.StructureDiscs)
				if g > exposure then
					exposure, worst = g, q
				end
			end

			local class = if not hosted then "free" elseif tip then "tip" else "joined"
			local row: Row = {
				what = "path end",
				name = name,
				class = class,
				host = host,
				point = point,
				run = along,
				gap = gap,
				exposure = exposure,
				ok = true,
			}
			if class ~= "joined" then
				if along > FLUSH then
					row.ok = false
					record(
						row,
						string.format(
							"%s: %s end runs %.2f studs past its last point (%s); nothing should be paved past it",
							name,
							class,
							along,
							at(point)
						),
						nil
					)
				else
					record(row, nil, nil)
				end
			else
				local known = KNOWN[name]
				local limit = if known then math.max(STICKS_OUT, known.limit) else STICKS_OUT
				if exposure > limit then
					row.ok = false
					record(
						row,
						string.format("%s: end line stands %.2f studs out of %s at %s", name, exposure, host, at(worst)),
						nil
					)
				elseif exposure > STICKS_OUT and known then
					record(
						row,
						nil,
						string.format("%s: %.2f studs out of %s, known: %s", name, exposure, host, known.reason)
					)
				else
					record(row, nil, nil)
				end
			end
		end
	end

	-- portal aprons: nothing is paved south of the stage walk under a portal --------------------------
	local walkSouth = math.huge
	for _, path in park.paths do
		if path.kind == "StageWalk" then
			for _, p in path.points do
				walkSouth = math.min(walkSouth, p.Y - path.width / 2)
			end
		end
	end
	local spec = park.portal
	for _, q in park.portals do
		local centre = Vector2.new(q.x, walkSouth - 7)
		local near: { Strip } = {}
		for _, s in strips do
			if Layout.rectGap(centre, s.a, s.b, s.width / 2) < 40 then
				table.insert(near, s)
			end
		end
		local deepest, deepAt = 0, centre
		for x = q.x - spec.width / 2 - 2, q.x + spec.width / 2 + 2, 0.25 do
			for depth = 0.02, 14, 0.25 do
				local p = Vector2.new(x, walkSouth - depth)
				for _, s in near do
					if Layout.rectGap(p, s.a, s.b, s.width / 2) <= 0 then
						if depth > deepest then
							deepest, deepAt = depth, p
						end
						break
					end
				end
			end
		end
		local row: Row = {
			what = "apron",
			name = q.id,
			class = "apron",
			host = "StageWalk",
			point = Vector2.new(q.x, spec.frontY),
			run = deepest,
			gap = 0,
			exposure = deepest,
			ok = deepest <= APRON_DEEP,
		}
		record(
			row,
			if row.ok
				then nil
				else string.format(
					"%s apron: paving runs %.2f studs south of the stage walk's edge at %s",
					q.id,
					deepest,
					at(deepAt)
				),
			nil
		)
	end

	-- bridge deck ends: the path strip stops exactly at the deck -------------------------------------
	for i, b in park.bridges do
		local dir = b.dir.Unit
		for _, s in { -1, 1 } do
			local deckEnd = b.at + dir * (s * b.span / 2)
			local best, off = math.huge, 0
			for _, st in strips do
				if st.kind == b.path then
					for _, e in { st.a, st.b } do
						local dist = (e - deckEnd).Magnitude
						if dist < best then
							best, off = dist, (e - deckEnd):Dot(dir * s)
						end
					end
				end
			end
			local name = string.format("Bridge%02d %s %s", i, b.path, if s < 0 then "start side" else "far side")
			local row: Row = {
				what = "bridge end",
				name = name,
				class = "bridge",
				host = b.path,
				point = deckEnd,
				run = off,
				gap = best,
				exposure = math.abs(off),
				ok = best <= 4 and math.abs(off) <= DECK_TOLERANCE,
			}
			record(
				row,
				if row.ok
					then nil
					else string.format(
						"%s: the path strip ends %.2f studs from the deck end (%s)",
						name,
						off,
						at(deckEnd)
					),
				nil
			)
		end
	end
	return report
end

-- `source` "built" reads the placed parts, "data" what Layout would build; nil takes the built island
-- when it is there.
function PathEndChecks.run(source: string?): Report
	local built = if source ~= "data" then PathEndChecks.stripsFromBuild() else nil
	if source == "built" and not built then
		error("the island is not built: Workspace.Lane3_IslandPreview.Island.Plaza.Paths is missing")
	end
	if built then
		return analyse(built, "built")
	end
	return analyse(PathEndChecks.stripsFromData(), "data")
end

function PathEndChecks.text(report: Report): string
	local lines: { string } = {
		string.format(
			"PathEndChecks (%s): %d checked, %d failures, %d known notes",
			report.source,
			report.checked,
			#report.failures,
			#report.notes
		),
	}
	for _, f in report.failures do
		table.insert(lines, "FAIL " .. f)
	end
	for _, note in report.notes do
		table.insert(lines, "note " .. note)
	end
	table.insert(lines, "ends:")
	for _, r in report.rows do
		table.insert(
			lines,
			string.format(
				"  %s %-30s %-7s run %+6.2f  out %5.2f  at %-22s %s",
				if r.ok then "ok  " else "FAIL",
				r.name,
				r.class,
				r.run,
				r.exposure,
				string.format("(%.1f, %.1f)", r.point.X, -r.point.Y),
				if r.host == "" then "-" else string.format("%s %.2f away", r.host, r.gap)
			)
		)
	end
	return table.concat(lines, "\n")
end

-- Moves the strip end nearest `near` further out along its strip by `by` studs.
local function pushEnd(strips: { Strip }, kind: string, near: Vector2, by: number): { Strip }
	local out: { Strip } = table.clone(strips)
	local index, side, best = 0, 0, math.huge
	for i, s in out do
		if s.kind == kind then
			if (s.a - near).Magnitude < best then
				index, side, best = i, 1, (s.a - near).Magnitude
			end
			if (s.b - near).Magnitude < best then
				index, side, best = i, 2, (s.b - near).Magnitude
			end
		end
	end
	assert(index > 0, "no strip of " .. kind)
	local s = out[index]
	local dir = (s.b - s.a).Unit
	out[index] = if side == 2
		then { kind = s.kind, a = s.a, b = s.b + dir * by, width = s.width }
		else { kind = s.kind, a = s.a - dir * by, b = s.b, width = s.width }
	return out
end

local function lastPoint(kind: string): Vector2
	for _, path in park.paths do
		if path.kind == kind then
			return path.points[#path.points]
		end
	end
	error("no path " .. kind)
end

-- Proves each check catches a known-bad case, on the path data: the clean strips pass, then one fault
-- at a time is planted. Expected: clean 0 and every other count 1 or more.
function PathEndChecks.selfTest(): { [string]: number }
	local base = PathEndChecks.stripsFromData()
	local out: { [string]: number } = {}
	out.clean = #analyse(base, "data").failures
	-- 1: the garden ring's tail runs on past its last point, the old free-end overshoot
	local ring = analyse(pushEnd(base, "GardenRing", lastPoint("GardenRing"), 1.2), "data")
	out.freeOvershootCaught = ring.counts.free or 0
	-- 2: the Dusty Highway approach back to its old square end 6.4 studs further out, past the stage walk
	local spike = analyse(pushEnd(base, "ApproachDustyHighway", lastPoint("ApproachDustyHighway"), 6.4), "data")
	out.spikeCaught = spike.counts.joined or 0
	out.apronCaught = spike.counts.apron or 0
	-- 3: the promenade's tip with its old 3-stud stub (a free end now that the path that ends there is drawn back)
	local tip = analyse(pushEnd(base, "Promenade", lastPoint("Promenade"), 3), "data")
	out.tipStubCaught = (tip.counts.free or 0) + (tip.counts.tip or 0)
	-- 4: a path strip pushed onto its bridge deck
	local bridge = park.bridges[#park.bridges - 1]
	local onto = analyse(pushEnd(base, bridge.path, bridge.at + bridge.dir.Unit * (bridge.span / 2), 1), "data")
	out.deckCaught = onto.counts.bridge or 0
	return out
end

return PathEndChecks
