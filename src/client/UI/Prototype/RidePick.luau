--!strict
-- RidePick (Lane 3 Round 8, C-03): choosing the car a run starts on. The client only ASKS: ask(carId) fires PickRideCar with one car id;
-- the server (src/server/Beta/BetaRide) checks the caller owns that car, saves it as RideCar and publishes it as the Player attribute
-- BetaRideCar. follow() keeps StyleState.car() (the launch card's car) equal to that saved pick, and puts the old pick back if the
-- server says no. With no beta server (the Studio UI playgrounds) ask() does nothing and StyleState.car() stays a local choice.
--
--   RidePick.ask(carId) -> boolean      true when there was a server to ask
--   RidePick.saved() -> string?         the server's saved pick
--   RidePick.follow() -> () -> ()       call once; the returned function stops following

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local LiveData = require(ReplicatedStorage.Shared.UI.LiveData)
local StyleState = require(script.Parent.StyleState)

local RidePick = {}

RidePick.Attribute = "BetaRideCar"

function RidePick.ask(carId: string): boolean
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
	local remote = net and net:FindFirstChild(BetaConfig.Remotes.PickRideCar)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(carId)
		return true
	end
	return false
end

function RidePick.saved(): string?
	local player = Players.LocalPlayer
	local value = player and player:GetAttribute(RidePick.Attribute)
	return if type(value) == "string" and #value > 0 then value else nil
end

function RidePick.follow(): () -> ()
	local player = Players.LocalPlayer
	if not player then
		return function() end
	end
	local function apply()
		local saved = RidePick.saved()
		if saved and saved ~= StyleState.car() then
			StyleState.setCar(saved)
		end
	end
	local changed = player:GetAttributeChangedSignal(RidePick.Attribute):Connect(apply)
	local result = LiveData.onResult(function(what: string, ok: boolean, _reason: string?, _missing: number?)
		-- a refused pick: the card shows the car the server still has
		if what == "PickRideCar" and not ok then
			apply()
		end
	end)
	task.defer(apply)
	return function()
		changed:Disconnect()
		if result then
			result:Disconnect()
		end
	end
end

return RidePick
