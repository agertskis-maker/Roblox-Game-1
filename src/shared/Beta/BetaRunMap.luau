--!strict
-- BETA-ONLY STAND-IN for Brian L's Catalog link between a run's traffic and the showroom cars.
-- Same contract: one spawn of Brian R's RunSequence always names the same car.
-- Delete when his real module lands.
--
-- Brian R's run draws placeholder families ("Family_Rarity" models, src/shared/Run/RunSequence); the save holds the 27
-- showroom cars (src/shared/UI/RosterFixtures). Until the run spawns real cars, this maps a spawn to one car of the run's
-- World, by rarity and family, the same way on the client and the server (pure: no services, no randomness).
--   Brian R's rarities are Common, Rare, Epic and Legendary. Common spawns split between the World's Common and Uncommon
--   cars, so Uncommon cars can be caught; a rarity the World has no car of falls back one step down. The Loaner is never
--   a catch (every save starts with it).
--
--   BetaRunMap.carFor(world, family, rarity) -> string?   the RosterFixtures id, or nil for an unknown World

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local BetaRunMap = {}

local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local function hash(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 1000003
	end
	return h
end

-- The World's Loaner is given, not caught (every save starts with it): it is left out, so a catch is a car to collect.
local function poolFor(world: string, rarity: string): { RosterFixtures.Car }
	local pool = {}
	for _, car in RosterFixtures.inWorld(world :: any) do
		if car.rarity == rarity and not car.loaner then
			table.insert(pool, car)
		end
	end
	return pool
end

function BetaRunMap.carFor(world: string, family: string, rarity: string): string?
	if RosterFixtures.WorldNames[world] == nil then
		return nil
	end
	local pool: { RosterFixtures.Car }
	if rarity == "Common" then
		pool = poolFor(world, "Common")
		for _, car in poolFor(world, "Uncommon") do
			table.insert(pool, car)
		end
	else
		local at = table.find(ORDER, rarity) or 1
		pool = {}
		while at >= 1 and #pool == 0 do
			pool = poolFor(world, ORDER[at])
			at -= 1
		end
	end
	if #pool == 0 then
		return nil
	end
	table.sort(pool, function(a, b)
		return a.id < b.id
	end)
	return pool[hash(family .. "/" .. rarity) % #pool + 1].id
end

return BetaRunMap
