--!strict
-- Screen-slot arbiter for the HUD prototype (Lane 3 preview). Feedback components ask for a
-- slot before showing anything large, so three independent components never each decide they
-- deserve the middle of the screen. One holder per slot; a higher level preempts a lower one,
-- an equal or lower request waits in a short queue (or is dropped when it cannot wait).
--
-- Levels (the brief's order, §7): Safety 5 (warnings, OVERHEATED) > Capture 4 (Keys ribbon,
-- confirmation) > District 3 (entry banner) > Reward 2 (milestones, rare reveal, toasts while
-- driving) > Ambient 1.
-- Slots: "Center" (large reason heading, results intro), "Upper" (below the district strip),
-- "Side" (left ribbon column, outside the protected road region).
--
--   local arb = Priority.new()
--   local h = arb:request("Side", "Capture", "keys-7", {
--       grant = function() show() end,          -- called when the slot is granted (now or later)
--       revoke = function() hideQuickly() end,  -- called if a higher level takes the slot
--       wait = 2,                               -- seconds it may queue; 0 = drop if busy
--   })
--   arb:release(h)                            -- when finished (also drops it from the queue)
--   arb:holder("Side") -> (id, level)?        -- for debug and tests
--   arb:suppress("Upper", "Safety")           -- while active, the slot grants nothing below it
--   arb:unsuppress("Upper")
--
-- Duplicate ids: requesting an id that already holds or waits for the slot returns the same
-- handle, so a repeated event cannot show twice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local Priority = {}
Priority.__index = Priority

export type Slot = "Center" | "Upper" | "Side"
export type Level = "Safety" | "Capture" | "District" | "Reward" | "Ambient"

Priority.Rank = table.freeze({ Safety = 5, Capture = 4, District = 3, Reward = 2, Ambient = 1 })

local QUEUE_LIMIT = 4

export type Callbacks = {
	grant: () -> (),
	revoke: (() -> ())?,
	wait: number?, -- default 1.5 s
}

type Entry = {
	slot: Slot,
	level: Level,
	id: string,
	callbacks: Callbacks,
	deadline: number,
	released: boolean,
}

export type Handle = Entry

function Priority.new()
	local self = setmetatable({}, Priority)
	self._holders = {} :: { [string]: Entry? }
	self._queues = {} :: { [string]: { Entry } }
	self._suppressed = {} :: { [string]: number }
	self.Changed = Signal.new() -- (slot)
	return self
end

export type Arbiter = typeof(Priority.new())

local function rank(level: Level): number
	return Priority.Rank[level]
end

local function grant(self: Arbiter, entry: Entry)
	self._holders[entry.slot] = entry
	self.Changed:Fire(entry.slot)
	task.spawn(entry.callbacks.grant)
end

local function allowed(self: Arbiter, slot: Slot, level: Level): boolean
	local floor = self._suppressed[slot]
	return floor == nil or rank(level) >= floor
end

-- Grants the best waiting entry (highest level, then oldest) that has not expired.
local function advance(self: Arbiter, slot: Slot)
	if self._holders[slot] then
		return
	end
	local queue = self._queues[slot]
	if not queue then
		return
	end
	local now = os.clock()
	local best: number? = nil
	for i = #queue, 1, -1 do
		local e = queue[i]
		if e.released or e.deadline < now then
			table.remove(queue, i)
		end
	end
	for i, e in queue do
		if allowed(self, slot, e.level) and (best == nil or rank(e.level) > rank(queue[best :: number].level)) then
			best = i
		end
	end
	if best then
		grant(self, table.remove(queue, best) :: Entry)
	end
end

function Priority.request(self: Arbiter, slot: Slot, level: Level, id: string, callbacks: Callbacks): Handle?
	local holder = self._holders[slot]
	if holder and holder.id == id then
		return holder
	end
	local queue = self._queues[slot]
	if not queue then
		queue = {}
		self._queues[slot] = queue
	end
	for _, e in queue do
		if e.id == id and not e.released then
			return e
		end
	end
	local entry: Entry = {
		slot = slot,
		level = level,
		id = id,
		callbacks = callbacks,
		deadline = os.clock() + (callbacks.wait or 1.5),
		released = false,
	}
	if not allowed(self, slot, level) then
		if (callbacks.wait or 1.5) <= 0 then
			return nil
		end
		table.insert(queue, entry)
		return entry
	end
	if holder == nil then
		grant(self, entry)
		return entry
	end
	if rank(level) > rank(holder.level) then
		-- preempt: the lower holder is revoked and not re-queued (its moment has passed)
		holder.released = true
		self._holders[slot] = nil
		if holder.callbacks.revoke then
			task.spawn(holder.callbacks.revoke)
		end
		grant(self, entry)
		return entry
	end
	if (callbacks.wait or 1.5) <= 0 then
		return nil
	end
	if #queue >= QUEUE_LIMIT then
		-- drop the lowest, oldest waiting entry to keep the queue bounded
		local lowest = 1
		for i, e in queue do
			if rank(e.level) < rank(queue[lowest].level) then
				lowest = i
			end
		end
		if rank(queue[lowest].level) > rank(level) then
			return nil
		end
		table.remove(queue, lowest)
	end
	table.insert(queue, entry)
	-- a queued entry that expires is cleaned when the slot frees up
	task.delay((callbacks.wait or 1.5) + 0.05, function()
		if not entry.released and self._holders[slot] ~= entry then
			entry.released = true
			advance(self, slot)
		end
	end)
	return entry
end

function Priority.release(self: Arbiter, handle: Handle?)
	if not handle or handle.released then
		return
	end
	handle.released = true
	if self._holders[handle.slot] == handle then
		self._holders[handle.slot] = nil
		self.Changed:Fire(handle.slot)
		advance(self, handle.slot)
	end
end

function Priority.holder(self: Arbiter, slot: Slot): (string?, Level?)
	local h = self._holders[slot]
	if h then
		return h.id, h.level
	end
	return nil, nil
end

-- While suppressed, the slot grants nothing below `level`; a current lower holder is revoked.
function Priority.suppress(self: Arbiter, slot: Slot, level: Level)
	self._suppressed[slot] = rank(level)
	local h = self._holders[slot]
	if h and rank(h.level) < rank(level) then
		h.released = true
		self._holders[slot] = nil
		if h.callbacks.revoke then
			task.spawn(h.callbacks.revoke)
		end
		self.Changed:Fire(slot)
	end
end

function Priority.unsuppress(self: Arbiter, slot: Slot)
	self._suppressed[slot] = nil
	advance(self, slot)
end

-- Clears every slot (preview reset); revokes holders.
function Priority.clear(self: Arbiter)
	for slot, h in self._holders do
		if h then
			h.released = true
			if h.callbacks.revoke then
				task.spawn(h.callbacks.revoke)
			end
		end
		self._holders[slot] = nil
	end
	table.clear(self._queues)
	table.clear(self._suppressed)
end

function Priority.getDebugState(self: Arbiter): { [string]: any }
	local out = {}
	for _, slot in { "Center", "Upper", "Side" } do
		local h = self._holders[slot]
		local q = self._queues[slot]
		out[slot] = {
			holder = h and h.id,
			level = h and h.level,
			waiting = q and #q or 0,
			suppressedBelow = self._suppressed[slot],
		}
	end
	return out
end

function Priority.destroy(self: Arbiter)
	self:clear()
	self.Changed:Destroy()
end

return Priority
