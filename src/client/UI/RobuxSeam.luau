--!strict
-- RobuxSeam: the ONE client module every Robux button calls (Round 6, R-03): the Shop, the Results respawn, the Garage's
-- Robux trails, the HUD VIP button and the parking card's GET MORE SPOTS.
--
-- With no provider (the team's game, the HUD playground, Studio previews) every button keeps its Round 5 behaviour: the
-- state is ComingSoon and nothing is ever prompted. The beta sets a provider (src/client/Beta/BetaPurchaseClient) that
-- checks, in this order: ownership (OWNED), the player's restriction (PolicyService: "Not available for your account",
-- shown, never hidden), whether prompts are on (BetaConfig.RealPurchases; always on in Studio, where purchases are test
-- purchases), and whether the product exists yet. A prompt opens only from a button the player pressed.
--
--   RobuxSeam.setProvider(provider)               the beta's purchase flow
--   RobuxSeam.state(id) -> State                   ComingSoon | Available | Owned | Unavailable | NotCreated | Error
--   RobuxSeam.price(id, preview) -> (number, boolean)   the product's own Robux price, or the PREVIEW number (true = PREVIEW)
--   RobuxSeam.priceText(id, preview) -> string     "199 Robux", or "PREVIEW · 199 Robux"
--   RobuxSeam.buy(id, done)                        prompts when Available; done(result) is called exactly once
--   RobuxSeam.stateText(state) -> string?          the words a button shows for a state that is not a price
--   RobuxSeam.adapterOptions() -> options          for ShopPurchaseAdapter.new (backend, ownership, availability)
--   RobuxSeam.Changed                              fires when any state may have changed (ownership, policy, prices)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local RobuxSeam = {}

export type State = "ComingSoon" | "Available" | "Owned" | "Unavailable" | "NotCreated" | "Error"
export type Status = "ComingSoon" | "Owned" | "Unavailable" | "Error" | "NotCreated" | "Purchased" | "Cancelled"
export type Result = { status: Status, offerId: string, message: string?, summary: { [string]: any }? }
export type Provider = {
	state: (id: string) -> State,
	price: (id: string) -> number?, -- the product's own price for this player (regional pricing), nil = not known
	buy: (id: string, done: (Result) -> ()) -> (() -> ())?,
}

RobuxSeam.Changed = Signal.new()

local provider: Provider? = nil

function RobuxSeam.setProvider(p: Provider?)
	provider = p
	RobuxSeam.Changed:Fire()
end

function RobuxSeam.hasProvider(): boolean
	return provider ~= nil
end

function RobuxSeam.state(id: string): State
	local p = provider
	if not p then
		return "ComingSoon"
	end
	local ok, state = pcall(p.state, id)
	return if ok then state else "Error"
end

function RobuxSeam.price(id: string, preview: number): (number, boolean)
	local p = provider
	local real = if p then p.price(id) else nil
	if real then
		return real, false
	end
	return preview, true
end

function RobuxSeam.priceText(id: string, preview: number): string
	local amount, isPreview = RobuxSeam.price(id, preview)
	return (if isPreview then "PREVIEW · " else "") .. string.format("%d Robux", amount)
end

-- The words a button shows instead of its price (nil when it shows the price).
function RobuxSeam.stateText(state: State): string?
	if state == "Owned" then
		return "OWNED"
	elseif state == "Unavailable" then
		return "Not available for your account"
	elseif state == "Error" then
		return "Try later"
	end
	return nil
end

function RobuxSeam.buy(id: string, done: (Result) -> ()): (() -> ())?
	local settled = false
	local function finish(result: Result)
		if not settled then
			settled = true
			done(result)
		end
	end
	local p = provider
	local state = RobuxSeam.state(id)
	if not p or state == "ComingSoon" then
		task.delay(0.4, finish, { status = "ComingSoon", offerId = id } :: Result)
		return nil
	elseif state ~= "Available" then
		finish({ status = state :: any, offerId = id })
		return nil
	end
	return p.buy(id, finish)
end

-- ShopPurchaseAdapter options (its "WHERE BRIAN L'S REAL FLOW PLUGS IN" seam), or nil with no provider so the Shop
-- keeps its preview backend.
function RobuxSeam.adapterOptions(): { [string]: any }?
	if not provider then
		return nil
	end
	return {
		backend = function(id: string, done: (any) -> ()): (() -> ())?
			return RobuxSeam.buy(id, done)
		end,
		ownership = function(id: string): boolean
			return RobuxSeam.state(id) == "Owned"
		end,
		availability = function(id: string): string
			local s = RobuxSeam.state(id)
			return if s == "Unavailable" then "Unavailable" elseif s == "Error" then "Error" else "Available"
		end,
	}
end

return RobuxSeam
