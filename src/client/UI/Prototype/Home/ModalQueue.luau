--!strict
-- The one home modal coordinator (Lane 3, Round 2 N13-01b): at most one blocking panel at a time, and a
-- short ordered queue of what waits. It is separate from Priority, whose Center/Upper/Side slots rank the
-- light notifications; those never block input.
--
--   local q = ModalQueue.new({ now = os.clock })
--   q:push({ key = "Update", version = "b2", class = "info", open = function(done) ...; done() end })
--   q:block("tutorial")      q:unblock("tutorial")
--   q:userOpen({ key = "Shop", open = ... })   -- a player's tap: never queued behind an offer
--
-- Order: result (a run's results), user, dialogue, info, promo. Local presentation limits, nothing saved:
-- four pending at most; two automatic info cards per session; one promotion per session, only after 30 s
-- of free home time; nothing automatic while a block is on (tutorial, run, transition, loading). A key
-- that was dismissed, or that is waiting already, is not queued again in the session. When full, the
-- oldest entry of the lowest class goes, and the reason is logged. Every entry rechecks `eligible` just
-- before it opens, and a stale one is discarded.

local ModalQueue = {}
ModalQueue.__index = ModalQueue

export type Class = "result" | "user" | "dialogue" | "info" | "promo"
export type Entry = {
	key: string,
	version: string?,
	class: Class,
	open: (done: () -> ()) -> (),
	eligible: (() -> boolean)?,
}
export type Options = {
	now: (() -> number)?,
	promoWait: number?,
	maxPending: number?,
	maxInfo: number?,
	onLog: ((string) -> ())?,
}

local RANK: { [Class]: number } = { result = 1, user = 2, dialogue = 3, info = 4, promo = 5 }
local PROMO_WAIT = 30
local MAX_PENDING = 4
local MAX_INFO = 2

export type Queue = typeof(setmetatable(
	{} :: {
		pending: { Entry },
		active: Entry?,
		blocks: { [string]: boolean },
		seen: { [string]: boolean },
		infoShown: number,
		promoShown: number,
		freeSince: number,
		now: () -> number,
		promoWait: number,
		maxPending: number,
		maxInfo: number,
		log: { string },
		onLog: ((string) -> ())?,
		destroyed: boolean,
	},
	ModalQueue
))

function ModalQueue.new(options: Options?): Queue
	local o = options or {}
	local now = o.now or os.clock
	return setmetatable({
		pending = {},
		active = nil,
		blocks = {},
		seen = {},
		infoShown = 0,
		promoShown = 0,
		freeSince = now(),
		now = now,
		promoWait = o.promoWait or PROMO_WAIT,
		maxPending = o.maxPending or MAX_PENDING,
		maxInfo = o.maxInfo or MAX_INFO,
		log = {},
		onLog = o.onLog,
		destroyed = false,
	}, ModalQueue) :: any
end

local function note(self: Queue, text: string)
	table.insert(self.log, text)
	if self.onLog then
		self.onLog(text)
	end
end

local function id(e: Entry): string
	return e.key .. "#" .. (e.version or "")
end

local function blocked(self: Queue): boolean
	return next(self.blocks) ~= nil
end

function ModalQueue.depth(self: Queue): number
	return #self.pending
end

function ModalQueue.busy(self: Queue): boolean
	return self.active ~= nil
end

local function allowed(self: Queue, e: Entry): boolean
	if e.class == "user" or e.class == "result" then
		return true
	end
	if blocked(self) then
		return false
	end
	if e.class == "info" and self.infoShown >= self.maxInfo then
		return false
	end
	if e.class == "promo" then
		if self.promoShown >= 1 or self.now() - self.freeSince < self.promoWait then
			return false
		end
	end
	return true
end

-- Opens the next entry that may open now, if nothing is open.
function ModalQueue.pump(self: Queue)
	if self.destroyed or self.active then
		return
	end
	table.sort(self.pending, function(a, b)
		return RANK[a.class] < RANK[b.class]
	end)
	for i, e in self.pending do
		if allowed(self, e) then
			table.remove(self.pending, i)
			if e.eligible and not e.eligible() then
				note(self, "stale " .. id(e))
				return self:pump()
			end
			self.active = e
			if e.class == "info" then
				self.infoShown += 1
			elseif e.class == "promo" then
				self.promoShown += 1
			end
			note(self, "open " .. id(e))
			local finished = false
			e.open(function()
				if finished then
					return
				end
				finished = true
				self:finish(e)
			end)
			return
		end
	end
end

function ModalQueue.finish(self: Queue, e: Entry)
	if self.active ~= e then
		return
	end
	self.active = nil
	self.seen[id(e)] = true
	self.freeSince = self.now()
	note(self, "closed " .. id(e))
	self:pump()
end

-- Queues an automatic entry. False when it is a duplicate or was dismissed already.
function ModalQueue.push(self: Queue, e: Entry): boolean
	local key = id(e)
	if self.seen[key] then
		note(self, "dismissed already " .. key)
		return false
	end
	if self.active and id(self.active) == key then
		return false
	end
	for _, p in self.pending do
		if id(p) == key then
			return false
		end
	end
	if #self.pending >= self.maxPending then
		-- drop the oldest entry of the lowest class waiting
		local worst, rank = 0, 0
		for i, p in self.pending do
			if RANK[p.class] > rank then
				worst, rank = i, RANK[p.class]
			end
		end
		if rank < RANK[e.class] then
			note(self, "full, dropped " .. key)
			return false
		end
		note(self, "full, dropped " .. id(self.pending[worst]))
		table.remove(self.pending, worst)
	end
	table.insert(self.pending, e)
	note(self, "queued " .. key)
	self:pump()
	return true
end

-- A player's own tap. It waits for a result, and otherwise closes nothing: while a card is open the tap
-- is held as the next thing. A blocking tutorial does not stop it: the tutorial itself asks for the Shop.
function ModalQueue.userOpen(self: Queue, e: Entry)
	e.class = "user"
	self.seen[id(e)] = nil -- a player may open the same panel again
	for i, p in self.pending do
		if id(p) == id(e) then
			table.remove(self.pending, i)
			break
		end
	end
	table.insert(self.pending, e)
	self:pump()
end

function ModalQueue.block(self: Queue, reason: string)
	self.blocks[reason] = true
end

function ModalQueue.unblock(self: Queue, reason: string)
	self.blocks[reason] = nil
	self.freeSince = self.now()
	self:pump()
end

-- A run started: home prompts and offers waiting for the player are stale now.
function ModalQueue.clearHome(self: Queue, reason: string)
	for i = #self.pending, 1, -1 do
		local c = self.pending[i].class
		if c == "promo" or c == "dialogue" then
			note(self, "cleared " .. id(self.pending[i]) .. " (" .. reason .. ")")
			table.remove(self.pending, i)
		end
	end
end

function ModalQueue.destroy(self: Queue)
	self.destroyed = true
	table.clear(self.pending)
	self.active = nil
end

-- The join matrix's queue rules on a fake clock: returns failures, empty when all hold.
function ModalQueue.selfTest(): { string }
	local fails: { string } = {}
	local function expect(ok: boolean, text: string)
		if not ok then
			table.insert(fails, text)
		end
	end
	local t = 0
	local q = ModalQueue.new({
		now = function()
			return t
		end,
	})
	local opened: { string } = {}
	local closers: { [string]: () -> () } = {}
	local function entry(key: string, class: Class, eligible: (() -> boolean)?): Entry
		return {
			key = key,
			class = class,
			eligible = eligible,
			open = function(done)
				table.insert(opened, key)
				closers[key] = done
			end,
		}
	end
	-- one at a time, in class order
	q:block("loading")
	q:push(entry("Promo", "promo"))
	q:push(entry("Update", "info"))
	q:push(entry("Welcome", "info"))
	expect(#opened == 0, "nothing opens while blocked")
	q:unblock("loading")
	expect(opened[1] == "Update" and #opened == 1, "first info opens alone")
	closers.Update()
	expect(opened[2] == "Welcome", "second info after the first")
	closers.Welcome()
	expect(#opened == 2, "the promotion waits for quiet time")
	t += 31
	q:pump()
	expect(opened[3] == "Promo", "the promotion after 30 s")
	closers.Promo()
	-- no second promotion, no third info card, no reopening
	q:push(entry("Group", "promo"))
	t += 40
	q:pump()
	expect(#opened == 3, "one promotion a session")
	q:push(entry("Update", "info"))
	expect(#opened == 3 and q:depth() == 1, "a dismissed card stays closed")
	-- a stale entry is dropped; a run clears home offers
	local q2 = ModalQueue.new({
		now = function()
			return t
		end,
		promoWait = 0,
	})
	q2:push(entry("Stale", "info", function()
		return false
	end))
	expect(not q2:busy(), "stale entries never open")
	q2:block("run")
	q2:push(entry("Offer", "promo"))
	q2:push(entry("Portal", "dialogue"))
	q2:clearHome("run")
	expect(q2:depth() == 0, "a run clears home prompts")
	-- capacity
	local q3 = ModalQueue.new({
		now = function()
			return t
		end,
	})
	q3:block("x")
	for i = 1, 4 do
		q3:push(entry("P" .. i, "promo"))
	end
	q3:push(entry("I", "info"))
	expect(q3:depth() == 4 and q3.pending[1].key ~= "P1", "full: the oldest lowest entry goes")
	-- the player's tap waits its turn and opens
	local q4 = ModalQueue.new({
		now = function()
			return t
		end,
	})
	q4:push(entry("Card", "info"))
	q4:userOpen(entry("Shop", "user"))
	expect(opened[#opened] == "Card", "a tap never stacks a second layer")
	closers.Card()
	expect(opened[#opened] == "Shop", "the tap opens when the card closes")
	return fails
end

return ModalQueue
