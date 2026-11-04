--!strict
-- ShopPurchaseAdapter: the ONE seam between the Shop UI and any purchase flow (Lane 3, BRIEF M10-09, 2026-11-01).
--
-- In this build the preview backend never leaves this file: it waits PendingSeconds (about 0.4 s) and answers
-- "ComingSoon". There is no MarketplaceService call, no product id, no pass id and no grant anywhere in the Shop.
-- The adapter counts every request, completion and cancel, plus `marketplaceCalls` and `grants`, which stay 0 in
-- this build by construction, so a test can prove zero Marketplace calls with `adapter:stats()`.
--
--   local adapter = ShopPurchaseAdapter.new(options?)
--   adapter:request(offerId, onResult) -> Handle        -- Handle:cancel() / Handle:isPending()
--   adapter:ownership(offerId) -> boolean               -- who owns what (preview: fixture only)
--   adapter:availability(offerId) -> "Available" | "Unavailable" | "Error"
--   adapter:stats() -> Stats                            -- requests, completed, cancelled, marketplaceCalls, grants
--   adapter.Changed                                     -- Signal fired when a fixture changes (the Shop re-renders)
--   adapter:destroy()
--
-- FIXTURES (preview only; the Shop's fixture API calls these):
--   adapter:setOwned(id, on)  adapter:setUnavailable(id or "*", on)  adapter:setError(id or "*", on)
--   adapter:holdPending(on)   -- requests never settle until released: exercises the pending state and close-during-pending
--   adapter:clearFixtures()
--
-- WHERE BRIAN L'S REAL FLOW PLUGS IN (a later round; nothing below is wired now):
--   * `options.backend`: a function (offerId, done) that starts the real purchase prompt and calls `done(result)`
--     exactly once, returning an optional canceller. It must call `adapter:recordMarketplaceCall()` for every real
--     Marketplace call it makes, so the spy counter stays honest.
--   * `options.ownership`: a function (offerId) -> boolean replacing the fixture lookup (server-confirmed ownership).
--   * `options.availability`: a function (offerId) -> "Available" | "Unavailable" | "Error". Per BRIEF M10-09b, a
--     policy or lookup failure is "Error" (unknown), never "Available", and eligibility is never inferred from age
--     or location.
-- Bundles never grant three passes automatically and never sell a duplicate entitlement; both rules live in the
-- real backend, not here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ShopPurchaseAdapter = {}
ShopPurchaseAdapter.__index = ShopPurchaseAdapter

export type Status = "ComingSoon" | "Owned" | "Unavailable" | "Error"
export type Result = { status: Status, offerId: string, message: string? }
export type Availability = "Available" | "Unavailable" | "Error"

export type Handle = {
	cancel: (self: Handle) -> (),
	isPending: (self: Handle) -> boolean,
}

export type Stats = {
	requests: number,
	completed: number,
	cancelled: number,
	pending: number,
	marketplaceCalls: number, -- 0 in this build, always
	grants: number, -- 0 in this build, always
}

export type Backend = (offerId: string, done: (Result) -> ()) -> (() -> ())?

export type Options = {
	pendingSeconds: number?,
	backend: Backend?,
	ownership: ((offerId: string) -> boolean)?,
	availability: ((offerId: string) -> Availability)?,
}

ShopPurchaseAdapter.PendingSeconds = 0.4

function ShopPurchaseAdapter.new(options: Options?)
	local opts: Options = options or {}
	local self = setmetatable({}, ShopPurchaseAdapter)
	self._trove = Trove.new()
	self.Changed = self._trove:Add(Signal.new())
	self._pendingSeconds = opts.pendingSeconds or ShopPurchaseAdapter.PendingSeconds
	self._backend = opts.backend
	self._ownership = opts.ownership
	self._availability = opts.availability
	self._owned = {} :: { [string]: boolean }
	self._unavailable = {} :: { [string]: boolean }
	self._errors = {} :: { [string]: boolean }
	self._hold = false
	self._live = {} :: { [any]: boolean }
	self._stats = { requests = 0, completed = 0, cancelled = 0, marketplaceCalls = 0, grants = 0 }
	self._destroyed = false
	return self
end

export type Adapter = typeof(ShopPurchaseAdapter.new())

-- The preview backend: a short wait, then ComingSoon. It makes no call of any kind.
local function previewBackend(self: Adapter, offerId: string, done: (Result) -> ()): (() -> ())?
	if self._hold then
		return nil -- held: stays pending until the request is cancelled
	end
	local thread = task.delay(self._pendingSeconds, function()
		done({ status = "ComingSoon", offerId = offerId })
	end)
	return function()
		pcall(task.cancel, thread)
	end
end

function ShopPurchaseAdapter.request(self: Adapter, offerId: string, onResult: (Result) -> ()): Handle
	self._stats.requests += 1
	local settled = false
	local cancelBackend: (() -> ())? = nil
	local handle: Handle
	handle = {
		cancel = function(_h: Handle)
			if settled then
				return
			end
			settled = true
			self._stats.cancelled += 1
			self._live[handle] = nil
			local cancel = cancelBackend
			if cancel then
				cancelBackend = nil
				cancel()
			end
		end,
		isPending = function(_h: Handle): boolean
			return not settled
		end,
	}
	self._live[handle] = true
	local function done(result: Result)
		if settled or self._destroyed then
			return -- cancelled or destroyed: a late answer is dropped, never shown
		end
		settled = true
		self._live[handle] = nil
		self._stats.completed += 1
		onResult(result)
	end
	local backend = self._backend
	if backend then
		cancelBackend = backend(offerId, done)
	else
		cancelBackend = previewBackend(self, offerId, done)
	end
	return handle
end

function ShopPurchaseAdapter.ownership(self: Adapter, offerId: string): boolean
	local lookup = self._ownership
	if lookup then
		return lookup(offerId)
	end
	return self._owned[offerId] == true
end

function ShopPurchaseAdapter.availability(self: Adapter, offerId: string): Availability
	local lookup = self._availability
	if lookup then
		return lookup(offerId)
	end
	if self._errors[offerId] or self._errors["*"] then
		return "Error"
	end
	if self._unavailable[offerId] or self._unavailable["*"] then
		return "Unavailable"
	end
	return "Available"
end

function ShopPurchaseAdapter.stats(self: Adapter): Stats
	local pending = 0
	for _ in self._live do
		pending += 1
	end
	local s = self._stats
	return {
		requests = s.requests,
		completed = s.completed,
		cancelled = s.cancelled,
		pending = pending,
		marketplaceCalls = s.marketplaceCalls,
		grants = s.grants,
	}
end

-- A real backend calls this for every real Marketplace call it makes (never called in this build).
function ShopPurchaseAdapter.recordMarketplaceCall(self: Adapter)
	self._stats.marketplaceCalls += 1
end

-- A real backend calls this for every entitlement it grants (never called in this build).
function ShopPurchaseAdapter.recordGrant(self: Adapter)
	self._stats.grants += 1
end

-- FIXTURES ------------------------------------------------------------------------------------------------------

function ShopPurchaseAdapter.setOwned(self: Adapter, offerId: string, on: boolean)
	self._owned[offerId] = if on then true else nil
	self.Changed:Fire()
end

function ShopPurchaseAdapter.setUnavailable(self: Adapter, offerId: string, on: boolean)
	self._unavailable[offerId] = if on then true else nil
	self.Changed:Fire()
end

function ShopPurchaseAdapter.setError(self: Adapter, offerId: string, on: boolean)
	self._errors[offerId] = if on then true else nil
	self.Changed:Fire()
end

function ShopPurchaseAdapter.holdPending(self: Adapter, on: boolean)
	self._hold = on
end

function ShopPurchaseAdapter.isHolding(self: Adapter): boolean
	return self._hold
end

function ShopPurchaseAdapter.clearFixtures(self: Adapter)
	table.clear(self._owned)
	table.clear(self._unavailable)
	table.clear(self._errors)
	self._hold = false
	self.Changed:Fire()
end

-- Cancels every live request (the Shop was closed) without answering any of them.
function ShopPurchaseAdapter.cancelAll(self: Adapter)
	for handle in table.clone(self._live) do
		(handle :: Handle):cancel()
	end
end

function ShopPurchaseAdapter.destroy(self: Adapter)
	if self._destroyed then
		return
	end
	self:cancelAll()
	self._destroyed = true
	self._trove:Destroy()
end

return ShopPurchaseAdapter
