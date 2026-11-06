--!strict
-- BETA-ONLY STAND-IN for the event feed Brian L's server will raise (Round 6, G-01).
-- Same contract: the server says what really happened to a player, after it happened; nothing here comes from a client.
-- Delete when his real module lands.
--
--   BetaEvents.Fired: Signal (player, kind, info)
--     kind "claim" | "joyride"   info = the run grant (carId, amount, edition, rose, ...)
--     kind "lap"                 info = { carId, amount }            a Lap Pay payout
--     kind "BuyRacewayLevel" | "BuyParkingSpot" | "UnlockWorld" | "BuyStaminaLevel"   info = {}   a purchase that went through
--     kind "runEnded"            info = { world, metres, claims, joyrides, cause, hops, bumps, bestChain }
--     kind "BuyStyle" | "EquipStyle"   info = {}   Round 7: the Style Shop
--     kind "purchase"            info = { item }                    a Robux item granted
-- Missions (BetaMissions) count these; nothing else may grant anything from them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local BetaEvents = {}

BetaEvents.Fired = Signal.new()

function BetaEvents.fire(player: Player, kind: string, info: { [string]: any }?)
	BetaEvents.Fired:Fire(player, kind, info or {})
end

return BetaEvents
