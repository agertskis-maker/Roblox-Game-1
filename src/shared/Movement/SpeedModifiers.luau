--!strict
-- Walk speed modifiers (client side). A minimal layer, written by Lane 3 for the island walking
-- boost, that Lane 1 (Brian R) is expected to take over or replace when the real movement system
-- exists. Spec and takeover path: vault/design/specs/walk-boost.md.
--
-- Each humanoid has a base WalkSpeed and any number of named sources, one slot per source.
-- WalkSpeed = base x the LARGEST active multiplier, clamped to [0, MaxMultiplier]. Sources never
-- multiply together and setting a source again replaces its value, so nothing stacks.
--
-- The base is never overwritten for good:
--   - the base is read from the humanoid when the first source becomes active;
--   - while sources are active, a WalkSpeed change made by anyone else (a different value from
--     the one written here) is adopted as the new base, and the multiplier is applied to it;
--   - when the last source is cleared the base is written back exactly (if this module still
--     owns the value) and the humanoid's state is dropped, so an idle humanoid holds nothing.
-- Nothing here is saved or sent to the server; a humanoid's state also ends when it is destroyed.
--
-- Movement modes that own speed outright (a run, a race, driving) should not mix with this: they
-- set the LocalPlayer attribute "MovementSpeedOwner" (see WalkBoost), which makes the island boost
-- clear its source and stand aside.

local SpeedModifiers = {}

SpeedModifiers.MaxMultiplier = 1.5 -- the ceiling from the proposed contract (IRW-84)

local EPSILON = 1e-3 -- WalkSpeed is stored as a float, so read-backs differ slightly

type Entry = {
	base: number,
	written: number?, -- the last value this module wrote, nil when it wrote the base back
	sources: { [string]: number },
	connections: { RBXScriptConnection },
}

local entries: { [Humanoid]: Entry } = {}

-- The combined multiplier of a set of sources: the largest, clamped; 1 when there are none.
function SpeedModifiers.combine(sources: { [string]: number }): number
	local best: number? = nil
	for _, m in sources do
		if best == nil or m > best then
			best = m
		end
	end
	if best == nil then
		return 1
	end
	return math.clamp(best, 0, SpeedModifiers.MaxMultiplier)
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < EPSILON
end

local function drop(humanoid: Humanoid)
	local e = entries[humanoid]
	if not e then
		return
	end
	entries[humanoid] = nil
	for _, c in e.connections do
		c:Disconnect()
	end
	table.clear(e.connections)
end

local function apply(humanoid: Humanoid, e: Entry)
	local m = SpeedModifiers.combine(e.sources)
	if next(e.sources) == nil then
		-- last source gone: write the base back exactly, unless someone else changed it since.
		-- Dropped first, so the change handler does not see this write.
		local written = e.written
		drop(humanoid)
		if written ~= nil and near(humanoid.WalkSpeed, written) then
			humanoid.WalkSpeed = e.base
		end
		return
	end
	local target = e.base * m
	if m == 1 then
		target = e.base -- exact, no float drift
	end
	if humanoid.WalkSpeed ~= target then
		-- recorded before the write: with immediate signals the handler runs inside it
		e.written = target
		humanoid.WalkSpeed = target
	end
	e.written = humanoid.WalkSpeed -- the stored (float) value, so the change check matches
end

local function entryFor(humanoid: Humanoid): Entry
	local e = entries[humanoid]
	if e then
		return e
	end
	local entry: Entry = { base = humanoid.WalkSpeed, written = nil, sources = {}, connections = {} }
	entries[humanoid] = entry
	table.insert(
		entry.connections,
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			-- read the current value, not the event order: deferred events can arrive late
			if entries[humanoid] ~= entry then
				return
			end
			local v = humanoid.WalkSpeed
			local written = entry.written
			if written ~= nil and near(v, written) then
				return
			end
			if written == nil and near(v, entry.base) then
				return
			end
			-- changed by someone else: that is the new base
			entry.base = v
			entry.written = nil
			apply(humanoid, entry)
		end)
	)
	table.insert(
		entry.connections,
		humanoid.Destroying:Connect(function()
			drop(humanoid)
		end)
	)
	return entry
end

-- Sets (or replaces) one source's multiplier on a humanoid.
function SpeedModifiers.set(humanoid: Humanoid, source: string, multiplier: number)
	assert(type(source) == "string" and source ~= "", "source must be a non-empty string")
	assert(type(multiplier) == "number" and multiplier == multiplier, "multiplier must be a number")
	local e = entryFor(humanoid)
	e.sources[source] = multiplier
	apply(humanoid, e)
end

-- Clears one source; when it was the last, the exact base WalkSpeed comes back.
function SpeedModifiers.clear(humanoid: Humanoid, source: string)
	local e = entries[humanoid]
	if not e or e.sources[source] == nil then
		return
	end
	e.sources[source] = nil
	apply(humanoid, e)
end

-- Clears every source on a humanoid (a movement mode taking over, a respawn).
function SpeedModifiers.clearAll(humanoid: Humanoid)
	local e = entries[humanoid]
	if not e then
		return
	end
	table.clear(e.sources)
	apply(humanoid, e)
end

-- The combined multiplier now (1 when the humanoid has no sources).
function SpeedModifiers.multiplier(humanoid: Humanoid): number
	local e = entries[humanoid]
	return if e then SpeedModifiers.combine(e.sources) else 1
end

-- One source's multiplier, or nil.
function SpeedModifiers.get(humanoid: Humanoid, source: string): number?
	local e = entries[humanoid]
	return if e then e.sources[source] else nil
end

-- The base WalkSpeed: tracked while sources are active, otherwise the humanoid's own value.
function SpeedModifiers.base(humanoid: Humanoid): number
	local e = entries[humanoid]
	return if e then e.base else humanoid.WalkSpeed
end

-- Number of humanoids holding state, and of live connections (for leak tests).
function SpeedModifiers.stats(): { humanoids: number, connections: number }
	local h, c = 0, 0
	for _, e in entries do
		h += 1
		c += #e.connections
	end
	return { humanoids = h, connections = c }
end

return SpeedModifiers
