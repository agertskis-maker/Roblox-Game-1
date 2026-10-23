--!strict
-- Route line maths (Lane 3 preview, Round 2, R2-R1 and R2-R2). Pure: no instances, no store access,
-- so the route line, the district banner and the self-test all use the same answers.
--
-- A route is a plan of districts with EXPLICIT lengths in metres (never equal spans invented here).
-- Distance is the TOTAL run distance and never drops. A repeating plan starts a new cycle after the last
-- district; only the local progress inside the cycle resets. A route cycle is a district-route cycle: it
-- is NOT a Speedway income lap.
--
-- The line is schematic like a subway map: station i sits at visual position (i - 1) / N and the line
-- ends at 1.0 (where the record badge is), so each district owns one equal visual stretch while its
-- real length (unequal) decides how fast the marker crosses it.
--
--   RouteMath.locate(plan, distance) -> Location?
--   RouteMath.visualT(plan, within) -> number            -- 0..1 along the line for a metre offset in the cycle
--   RouteMath.remaining(plan, loc) -> number             -- metres to the end of the current district
--   RouteMath.upcoming(plan, loc) -> (District?, number) -- the next district and its cycle
--   RouteMath.record(plan, recordM, distance) -> Record  -- where the record sits relative to the shown cycle
--   RouteMath.crossed(previous, distance, recordM) -> boolean  -- the NEW BEST edge (pure; the caller dedupes)

local Store = require(script.Parent.Parent.Store)

local RouteMath = {}

export type Location = {
	index: number, -- district index in the plan (1-based)
	cycle: number, -- 1 = first pass
	fraction: number, -- 0..1 through the district
	start: number, -- metres from the cycle start to the start of this district
	within: number, -- metres from the cycle start
	total: number, -- the cycle length in metres
	cycleStart: number, -- total distance at which this cycle began
	t: number, -- 0..1 along the line (see above)
}

export type Record = {
	kind: "None" | "Inside" | "Ahead" | "Behind",
	t: number?, -- 0..1 along the shown cycle, only when Inside
	delta: number, -- recordM - distance (positive = the record is still ahead)
}

local function clean(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return value
end

function RouteMath.total(plan: Store.DistrictPlan): number
	local total = 0
	for _, d in plan.districts do
		total += math.max(clean(d.length), 0)
	end
	return total
end

function RouteMath.visualT(plan: Store.DistrictPlan, within: number): number
	local list = plan.districts
	local n = #list
	if n == 0 then
		return 0
	end
	local w = math.max(clean(within), 0)
	local start = 0
	for i, d in list do
		local len = math.max(clean(d.length), 0)
		if w < start + len or i == n then
			local f = if len > 0 then math.clamp((w - start) / len, 0, 1) else 0
			return (i - 1 + f) / n
		end
		start += len
	end
	return 1
end

function RouteMath.locate(plan: Store.DistrictPlan, distance: number): Location?
	local list = plan.districts
	local n = #list
	if n == 0 then
		return nil
	end
	local total = RouteMath.total(plan)
	if total <= 0 then
		return { index = 1, cycle = 1, fraction = 0, start = 0, within = 0, total = 0, cycleStart = 0, t = 0 }
	end
	local dist = math.max(clean(distance), 0)
	local cycle = 1
	local within = dist
	if plan.repeats then
		cycle = math.floor(dist / total) + 1
		within = dist - (cycle - 1) * total
	elseif within >= total then
		local last = list[n]
		return {
			index = n,
			cycle = 1,
			fraction = 1,
			start = total - math.max(clean(last.length), 0),
			within = total,
			total = total,
			cycleStart = 0,
			t = 1,
		}
	end
	local start = 0
	for i, d in list do
		local len = math.max(clean(d.length), 0)
		if within < start + len or i == n then
			local f = if len > 0 then math.clamp((within - start) / len, 0, 1) else 0
			return {
				index = i,
				cycle = cycle,
				fraction = f,
				start = start,
				within = within,
				total = total,
				cycleStart = (cycle - 1) * total,
				t = (i - 1 + f) / n,
			}
		end
		start += len
	end
	return nil
end

function RouteMath.remaining(plan: Store.DistrictPlan, loc: Location): number
	local d = plan.districts[loc.index]
	if not d then
		return 0
	end
	return math.max(0, loc.start + math.max(clean(d.length), 0) - loc.within)
end

-- The district after the current one and the cycle it belongs to; nil at the end of a plan that does not
-- repeat (no "finish" is implied for a repeating one).
function RouteMath.upcoming(plan: Store.DistrictPlan, loc: Location): (Store.District?, number)
	local n = #plan.districts
	if loc.index < n then
		return plan.districts[loc.index + 1], loc.cycle
	end
	if plan.repeats then
		return plan.districts[1], loc.cycle + 1
	end
	return nil, loc.cycle
end

-- Where the supplied personal best lies relative to the cycle being shown. Only a record INSIDE the shown
-- cycle gets a marker at its mathematically correct place; otherwise the label says ahead or behind.
function RouteMath.record(plan: Store.DistrictPlan, recordM: number?, distance: number): Record
	if recordM == nil or clean(recordM) <= 0 then
		return { kind = "None", delta = 0 }
	end
	local record = clean(recordM)
	local loc = RouteMath.locate(plan, distance)
	local delta = record - math.max(clean(distance), 0)
	if not loc or loc.total <= 0 then
		return { kind = if delta >= 0 then "Ahead" else "Behind", delta = delta }
	end
	local cycleEnd = loc.cycleStart + loc.total
	if record >= loc.cycleStart and record <= cycleEnd then
		return { kind = "Inside", t = RouteMath.visualT(plan, record - loc.cycleStart), delta = delta }
	end
	return { kind = if record > cycleEnd then "Ahead" else "Behind", delta = delta }
end

-- True on the update where the run distance reaches the pre-run record from below. The caller keeps the
-- "already fired for this run" state, so a later update or a reordered one can never fire it again.
function RouteMath.crossed(previous: number, distance: number, recordM: number?): boolean
	if recordM == nil or clean(recordM) <= 0 then
		return false
	end
	local record = clean(recordM)
	return clean(previous) < record and clean(distance) >= record
end

return RouteMath
