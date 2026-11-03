--!strict
-- PREVIEW fixtures for the dialogue card (Round 2 N11-01). Every requirement, count and line here is made up for review. The
-- unlock rules belong to the game (Brian L); the card only shows what it is given, and Lane 3 never changes an unlock rule.
--
-- THE SEAM FOR THE REAL DATA: a locked portal needs { worldName, requirementName, current, target } in the same unit, e.g.
-- "Downtown cars" 1 of 3. The card computes remaining = max(0, target - current) itself; nothing is sent back.
-- ONE FIXTURE SOURCE: the locked cards read PortalFixtures.Locks (the portal card's own numbers), so the dialogue, the portal
-- card and the Home HUD demo's goal pill all say the same thing about a locked Dusty Highway.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.UI.Format)
local PortalFixtures = require(script.Parent.PortalFixtures)

local DialogueFixtures = {}

DialogueFixtures.Source =
	"PREVIEW fixture: requirements, progress and copy are made up (the unlock rules are the game's)"
DialogueFixtures.Portrait = "Coach Roxy" -- a reversible local name proposal, not an approved lore character

-- "Collect 2 more Downtown cars to unlock Dusty Highway." One car reads "1 more Downtown car".
function DialogueFixtures.lockedText(remaining: number, requirement: string, worldName: string): string
	local noun = if remaining == 1 then "car" else "cars"
	return string.format("Collect %d more %s %s to unlock %s.", remaining, requirement, noun, worldName)
end

export type Preset = { [string]: any }

local function locked(worldName: string, requirement: string, current: number, target: number): Preset
	return {
		key = "portal:" .. worldName,
		title = string.upper(worldName),
		icon = "Lock",
		portraitName = DialogueFixtures.Portrait,
		text = function(remaining: number): string
			return DialogueFixtures.lockedText(remaining, requirement, worldName)
		end,
		progress = { label = string.upper(requirement) .. " CARS", current = current, target = target },
		primary = { label = "GOT IT!" },
		-- once the requirement is met while the card is open, the card shows Ready and offers the EXISTING travel action
		ready = {
			text = string.format("You did it! %s is open now.", worldName),
			primary = { label = "GO!" },
		},
	}
end

-- Round 4: a World needs cars from the World before AND Cash (economy v1). The card asks for the cars while they are short,
-- then for the Cash, so it never says "open" while the other requirement is still missing.
local function lockedFor(worldName: string, lock: PortalFixtures.Lock): Preset
	if lock.cars < lock.carsNeed then
		return locked(worldName, lock.previous, lock.cars, lock.carsNeed)
	end
	local spec = locked(worldName, lock.previous, lock.cars, lock.carsNeed)
	spec.text = function(remaining: number): string
		return string.format("Save up %s more Cash to unlock %s.", Format.cash(remaining), worldName)
	end
	spec.progress = { label = "CASH", current = lock.cash, target = lock.cashNeed, cash = true }
	return spec
end

DialogueFixtures.PresetNames = table.freeze({ "DustyLocked", "SummitLocked", "Shopkeeper", "Unknown", "Tutorial" })

local presets: { [string]: () -> Preset } = {
	DustyLocked = function(): Preset
		return lockedFor("Dusty Highway", PortalFixtures.Locks.DustyHighway)
	end,
	SummitLocked = function(): Preset
		return lockedFor("Summit Pass", PortalFixtures.Locks.SummitPass)
	end,
	-- the Raceway shopkeeper points to the EXISTING upgrade panel; nothing is bought from here
	Shopkeeper = function(): Preset
		return {
			key = "shop:raceway",
			title = "RACEWAY SHOP",
			icon = "Raceway",
			portraitName = DialogueFixtures.Portrait,
			text = "Welcome to the Raceway! Your upgrades are in the Upgrade panel. Take a look whenever you like.",
			primary = { label = "GOT IT!" },
		}
	end,
	-- the requirement is not known: say so, never invent one
	Unknown = function(): Preset
		return {
			key = "portal:unknown",
			title = "LOCKED ROAD",
			icon = "Lock",
			portraitName = DialogueFixtures.Portrait,
			text = "Unlock details aren't available yet.",
			primary = { label = "GOT IT!" },
		}
	end,
	Tutorial = function(): Preset
		return {
			key = "tutorial:hop",
			title = "COACH ROXY SAYS",
			icon = "Info",
			portraitName = DialogueFixtures.Portrait,
			text = "Tap HOP when the ring turns teal to jump onto a car!",
			primary = { label = "GOT IT!" },
		}
	end,
}

function DialogueFixtures.preset(name: string): Preset?
	local make = presets[name]
	if not make then
		return nil
	end
	return make()
end

return DialogueFixtures
