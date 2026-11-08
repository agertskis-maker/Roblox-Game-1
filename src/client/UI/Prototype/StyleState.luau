--!strict
-- StyleState: what this player owns and wears (Lane 3, Round 3 N4). One shared table, so the Style Shop, the Launch Pad, the
-- launch card, the Garage, the Raceway and the run car can never disagree.
--
-- Round 7 (C-07, C-08): in the beta the server owns it. The Player attribute BetaStyle (JSON, written by BetaStyle on the server)
-- says what is owned and worn, and StyleState follows it; equip() and buy() only ask the server (EquipStyle, BuyStyle) and the
-- answer comes back through that attribute. Where there is no beta server (the Studio UI playgrounds), equip() and own() change
-- this table directly, as before. The picked car is the launch card's choice; Round 8 (C-06): when the server publishes the
-- player's RIDE car (Player attribute BetaRideCar, WS-1's PickRideCar) the picked car follows it, so the Style Shop shows the
-- car the player will start the run in.
--
--   StyleState.get() -> State           StyleState.Changed (Signal)
--   StyleState.equip(tab, id)           StyleState.buy(tab, id)        StyleState.own(id)
--   StyleState.item(tab) -> Item?       the worn item of a tab
--   StyleState.car() -> string          the picked car's model name   StyleState.setCar(name)
--   StyleState.look() -> CarLook.Look   the player's whole look on the picked car (Round 8, C-01)
--   StyleState.live() -> boolean        true when the server's style is being followed

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local CarLook = require(ReplicatedStorage.Shared.Style.CarLook)
local Signal = require(ReplicatedStorage.Packages.Signal)

local StyleState = {}

export type State = { ownership: Catalog.Ownership, equipped: Catalog.Equipped, car: string }

local state: State = {
	ownership = Catalog.defaultOwnership(),
	equipped = Catalog.defaultEquipped(),
	car = "Putter", -- Round 4: the Downtown Loaner (the first World's starting car)
}
local following = false
local RIDE_ATTRIBUTE = "BetaRideCar" -- Player: the saved ride car (the contract in vault/design/specs/lane3-round8-contracts.md)

StyleState.Changed = Signal.new()

function StyleState.get(): State
	return state
end

function StyleState.live(): boolean
	return following
end

local function remote(name: string): RemoteEvent?
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
	local r = net and net:FindFirstChild(name)
	return if r and r:IsA("RemoteEvent") then r else nil
end

function StyleState.equip(tab: string, id: string)
	if following then
		local r = remote(BetaConfig.Remotes.EquipStyle)
		if r then
			r:FireServer(tab, id)
		end
		return
	end
	(state.equipped :: any)[tab] = id
	StyleState.Changed:Fire(tab, id)
end

-- Asks the server to buy an item with Cash; the answer is a BetaResult ("BuyStyle") and, on success, the BetaStyle attribute.
-- Returns false when there is no server to ask.
function StyleState.buy(tab: string, id: string): boolean
	local r = following and remote(BetaConfig.Remotes.BuyStyle)
	if r then
		r:FireServer(tab, id)
		return true
	end
	return false
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

-- The player's whole look on the picked car: the one value every place that shows the car hands to CarLookApplier.
function StyleState.look(): CarLook.Look
	return CarLook.fromEquipped(state.car, state.equipped :: any)
end

function StyleState.item(tab: string): Catalog.Item?
	return Catalog.byId(tab :: any, (state.equipped :: any)[tab])
end

-- Follow the server's style (the beta). Runs on the client only.
local player = Players.LocalPlayer
if player then
	local function read()
		local text = player:GetAttribute(BetaConfig.StyleAttribute)
		if type(text) ~= "string" then
			return
		end
		local ok, data = pcall(function()
			return HttpService:JSONDecode(text)
		end)
		if not ok or type(data) ~= "table" then
			return
		end
		following = true
		local owned = {}
		for _, id in (if type(data.o) == "table" then data.o else {}) :: { any } do
			if type(id) == "string" then
				owned[id] = true
			end
		end
		state.ownership.owned = owned
		if type(data.e) == "table" then
			for _, tab in Catalog.Tabs do
				local id = data.e[tab]
				if type(id) == "string" and Catalog.byId(tab, id) then
					(state.equipped :: any)[tab] = id
				end
			end
		end
		StyleState.Changed:Fire("server", nil)
	end
	player:GetAttributeChangedSignal(BetaConfig.StyleAttribute):Connect(read)
	task.defer(read)
	-- Round 8: the ride car the server saved (BetaRide publishes it; a car id is the car's model name)
	local function readRide()
		local id = player:GetAttribute(RIDE_ATTRIBUTE)
		if type(id) == "string" and id ~= "" and id ~= state.car then
			state.car = id
			StyleState.Changed:Fire("car", id)
		end
	end
	player:GetAttributeChangedSignal(RIDE_ATTRIBUTE):Connect(readRide)
	task.defer(readRide)
end

return StyleState
