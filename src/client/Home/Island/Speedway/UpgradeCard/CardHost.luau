--!strict
-- UpgradeCard.CardHost (Lane 3 Round 8, U-03): helpers both upgrade cards use to talk to the beta server without ever sending an
-- amount: it only LISTENS to the server's BetaResult reply (what, ok, reason, missing).
--
--   CardHost.onResult(what: string, handler: (ok: boolean, reason: string?, missing: number?) -> ()) -> () -> ()
--     Calls `handler` for every BetaResult whose first argument is `what` ("BuyRacewayLevel", "BuyParkingSpot"). Waits (in a
--     task) for the beta's remote to exist, and does nothing when there is no beta server. Returns the function that stops it.
--   CardHost.betaActive() -> boolean          true when the beta server (ReplicatedStorage.CarHopBeta) is present

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))

local CardHost = {}

function CardHost.betaActive(): boolean
	return BetaConfig.enabled()
end

function CardHost.onResult(what: string, handler: (ok: boolean, reason: string?, missing: number?) -> ()): () -> ()
	if not BetaConfig.enabled() then
		return function() end
	end
	local connection: RBXScriptConnection? = nil
	local stopped = false
	local waiter = task.spawn(function()
		local net = ReplicatedStorage:WaitForChild(BetaConfig.NetName, 10)
		local remote = net and net:WaitForChild(BetaConfig.Remotes.Result, 10)
		if stopped or not (remote and remote:IsA("RemoteEvent")) then
			return
		end
		connection = remote.OnClientEvent:Connect(function(name: any, ok: any, reason: any, missing: any)
			if name == what then
				handler(
					ok == true,
					if type(reason) == "string" then reason else nil,
					if type(missing) == "number" then missing else nil
				)
			end
		end)
	end)
	return function()
		stopped = true
		pcall(task.cancel, waiter)
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
end

return CardHost
