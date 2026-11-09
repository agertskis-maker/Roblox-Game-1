--!strict
-- RidePick (Lane 3 Round 8, C-03): choosing the car a run starts on. The client only ASKS: ask(carId) fires PickRideCar with one car id;
-- the server (src/server/Beta/BetaRide) checks the caller owns that car, saves it as RideCar and publishes it as the Player attribute
-- BetaRideCar. follow() keeps StyleState.car() (the launch card's car) equal to that saved pick, and puts the old pick back if the
-- server says no. With no beta server (the Studio UI playgrounds) ask() answers yes at once and StyleState.car() stays a local choice.
--
-- Round 8 fix (r8-fix1, review D8): a confirmation ("READY TO RIDE", the green check) waits for the server's answer
-- BetaResult("PickRideCar", ok, reason). Every ask gets exactly one answer, through its own callback and through RidePick.Answered:
-- the server's yes or no, a local "one moment" when asked again within the server's cooldown (so the server never has to drop a
-- request a real player made), or "no answer" after TIMEOUT seconds.
--
--   RidePick.ask(carId, onAnswer?) -> boolean   true when there was a server to ask; onAnswer(ok, reason?) is called once
--   RidePick.Answered (Signal: carId, ok, reason?)
--   RidePick.saved() -> string?                 the server's saved pick
--   RidePick.follow() -> () -> ()               call once; the returned function stops following

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local LiveData = require(ReplicatedStorage.Shared.UI.LiveData)
local Signal = require(ReplicatedStorage.Packages.Signal)
local StyleState = require(script.Parent.StyleState)

local RidePick = {}

RidePick.Attribute = "BetaRideCar"
RidePick.Answered = Signal.new()

local COOLDOWN = 0.45 -- a little over the server's 0.4 s, so an honest player's ask is never dropped there
local TIMEOUT = 4
local BUSY = "One moment, try again."
local NO_ANSWER = "No answer yet. Try again."

type Ask = { carId: string, onAnswer: ((boolean, string?) -> ())?, serial: number }

local queue: { Ask } = {} -- asks the server has not answered yet, oldest first (the server answers in order)
local serial = 0
local lastAsk = -math.huge
local listening: RBXScriptConnection? = nil

local function answer(ask: Ask, ok: boolean, reason: string?)
	RidePick.Answered:Fire(ask.carId, ok, reason)
	if ask.onAnswer then
		local done, err = pcall(ask.onAnswer, ok, reason)
		if not done then
			warn("[RidePick] an answer handler failed: " .. tostring(err))
		end
	end
end

local function listen()
	if listening then
		return
	end
	listening = LiveData.onResult(function(what: string, ok: boolean, reason: string?, _missing: number?)
		if what ~= "PickRideCar" then
			return
		end
		local ask = table.remove(queue, 1)
		if ask then
			answer(ask, ok, reason)
		end
	end)
end

function RidePick.ask(carId: string, onAnswer: ((boolean, string?) -> ())?): boolean
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
	local remote = net and net:FindFirstChild(BetaConfig.Remotes.PickRideCar)
	serial += 1
	local ask: Ask = { carId = carId, onAnswer = onAnswer, serial = serial }
	if not (remote and remote:IsA("RemoteEvent")) then
		task.defer(answer, ask, true, nil) -- no server: the local choice stands
		return false
	end
	local now = os.clock()
	if now - lastAsk < COOLDOWN then
		task.defer(answer, ask, false, BUSY)
		return true
	end
	lastAsk = now
	listen()
	table.insert(queue, ask)
	remote:FireServer(carId)
	task.delay(TIMEOUT, function()
		local at = table.find(queue, ask)
		if at then
			table.remove(queue, at)
			answer(ask, false, NO_ANSWER)
		end
	end)
	return true
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
	-- a refused pick (or one with no answer): the card shows the car the server still has
	local result = RidePick.Answered:Connect(function(_carId: string, ok: boolean)
		if not ok then
			apply()
		end
	end)
	task.defer(apply)
	return function()
		changed:Disconnect()
		result:Disconnect()
	end
end

return RidePick
