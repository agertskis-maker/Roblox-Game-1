--!strict
-- LiveData: where Lane 3 screens read the player's real economy state, and how they ask the server to change it (Round 5,
-- L-01 to L-06). Read only: every value is a Player or plot attribute that the SERVER writes; the client never computes Cash
-- or an outcome. Today the writer is the beta stand-in server (src/server/Beta, decision 0039); Brian L's real server keeps
-- the same names, or this file changes in one place. With no live server (the HUD playground, Studio previews) `active()`
-- is false and every screen keeps its labelled PREVIEW fixture.
--
--   LiveData.active() -> boolean                 the live server's remote folder exists
--   LiveData.cash(player?) -> number?            LiveData.cars(player?) -> { [id]: { Edition, Copies } }
--   LiveData.lineup(player?) -> { string }       LiveData.worlds(player?) -> { [world]: true }
--   LiveData.remote(name) -> RemoteEvent?        LiveData.onResult(fn(what, ok, reason?, missing?)) -> RBXScriptConnection?
--   LiveData.changed(player, key, fn) -> RBXScriptConnection   key: "cash" | "cars" | "lineup" | "worlds"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveData = {}

LiveData.NetName = "CarHopBetaNet"
LiveData.Attributes = table.freeze({
	cash = "BetaCash",
	cars = "BetaCars",
	lineup = "BetaLineup",
	worlds = "BetaWorldsUnlocked",
	welcomeAmount = "BetaWelcomeAmount",
	welcomeSeconds = "BetaWelcomeSeconds",
	homePlot = "HomePlot",
	noPlot = "BetaNoPlot",
	lapEpoch = "BetaLapEpoch", -- plot
	lapSeconds = "BetaLapSeconds", -- plot
	tutorialDone = "TutorialDone",
})
LiveData.Remotes = table.freeze({
	SetLineupSlot = "SetLineupSlot",
	BuyRacewayLevel = "BuyRacewayLevel",
	BuyParkingSpot = "BuyParkingSpot",
	UnlockWorld = "UnlockWorld",
	Result = "BetaResult",
	LapPaid = "BetaLapPaid",
	RunGranted = "BetaRunGranted",
	RunResults = "BetaRunResults",
})

function LiveData.active(): boolean
	return ReplicatedStorage:FindFirstChild(LiveData.NetName) ~= nil
end

local function who(player: Player?): Player
	return player or Players.LocalPlayer
end

function LiveData.cash(player: Player?): number?
	local v = who(player):GetAttribute(LiveData.Attributes.cash)
	return if type(v) == "number" then v else nil
end

function LiveData.cars(player: Player?): { [string]: { Edition: number, Copies: number } }
	local out = {}
	local text = who(player):GetAttribute(LiveData.Attributes.cars)
	if type(text) == "string" then
		for id, edition, copies in string.gmatch(text, "([^:,]+):(%d+):(%d+)") do
			out[id] = { Edition = tonumber(edition) :: number, Copies = tonumber(copies) :: number }
		end
	end
	return out
end

function LiveData.hasCars(player: Player?): boolean
	return type(who(player):GetAttribute(LiveData.Attributes.cars)) == "string"
end

function LiveData.lineup(player: Player?): { string }
	local out = {}
	local text = who(player):GetAttribute(LiveData.Attributes.lineup)
	if type(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			table.insert(out, id)
		end
	end
	return out
end

function LiveData.worlds(player: Player?): { [string]: boolean }
	local out = {}
	local text = who(player):GetAttribute(LiveData.Attributes.worlds)
	if type(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			out[id] = true
		end
	end
	return out
end

function LiveData.hasWorlds(player: Player?): boolean
	return type(who(player):GetAttribute(LiveData.Attributes.worlds)) == "string"
end

function LiveData.remote(name: string): RemoteEvent?
	local net = ReplicatedStorage:FindFirstChild(LiveData.NetName)
	local r = net and net:FindFirstChild(name)
	return if r and r:IsA("RemoteEvent") then r else nil
end

function LiveData.onResult(fn: (string, boolean, string?, number?) -> ()): RBXScriptConnection?
	local r = LiveData.remote(LiveData.Remotes.Result)
	return if r then r.OnClientEvent:Connect(fn) else nil
end

function LiveData.changed(player: Player, key: string, fn: () -> ()): RBXScriptConnection
	local name = (LiveData.Attributes :: any)[key] or key
	return player:GetAttributeChangedSignal(name):Connect(fn)
end

return LiveData
