--!strict
-- StyleState: what this player owns and wears this session (Lane 3, Round 3 N4). One shared table, so the Shop's Style page, the
-- Stunt customization screen, the Launch Pad stalls and the launch card can never disagree. PREVIEW: a fixture, nothing is saved,
-- and no purchase here is real. Brian L's real ownership replaces this module's data, not its callers.
--
--   StyleState.get() -> State           StyleState.Changed (Signal)
--   StyleState.equip(tab, id)           StyleState.own(id)
--   StyleState.item(tab) -> Item?       the worn item of a tab
--   StyleState.car() -> string          the picked car's model name   StyleState.setCar(name)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local Signal = require(ReplicatedStorage.Packages.Signal)

local StyleState = {}

export type State = { ownership: Catalog.Ownership, equipped: Catalog.Equipped, car: string }

local state: State = {
	ownership = Catalog.defaultOwnership(),
	equipped = Catalog.defaultEquipped(),
	car = "Commuter",
}

StyleState.Changed = Signal.new()

function StyleState.get(): State
	return state
end

function StyleState.equip(tab: string, id: string)
	(state.equipped :: any)[tab] = id
	StyleState.Changed:Fire(tab, id)
end

function StyleState.own(id: string)
	state.ownership.owned[id] = true
	StyleState.Changed:Fire("owned", id)
end

function StyleState.car(): string
	return state.car
end

function StyleState.setCar(name: string)
	state.car = name
	StyleState.Changed:Fire("car", name)
end

function StyleState.item(tab: string): Catalog.Item?
	return Catalog.byId(tab :: any, (state.equipped :: any)[tab])
end

return StyleState
