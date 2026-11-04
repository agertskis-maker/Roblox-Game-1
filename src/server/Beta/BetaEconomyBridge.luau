--!strict
-- CAR HOP BETA 3: runs instead of the beta's own server when Brian L's economy PREVIEW is switched on (Workspace attribute
-- Lane2EconomyPreview = true, src/server/EconomyPreview). The preview is then the only owner of saves, plots and purchases,
-- and its BetaCompat makes ReplicatedStorage.CarHopBetaNet with the two Raceway purchases. This adds the two beta remotes
-- the preview does not answer, so Lane 3's screens keep working:
--   TutorialDone   no arguments. Session only: the preview saves to ProfileStore.Mock, so every Studio server is a first
--                  join anyway; nothing is saved here.
--   SetLineupSlot  (slot, carId), passed to the preview's own Economy.setLineupSlot, which checks ownership and range. The
--                  Lineup is mirrored read-only into the player attribute BetaLineup, which Lane 3's screens read.
-- Nothing here computes a price or an amount.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)

local BetaEconomyBridge = {}

local COOLDOWN = 0.3

function BetaEconomyBridge.start()
	local preview = script.Parent.Parent:FindFirstChild("EconomyPreview")
	if not preview then
		warn("[CarHopBeta] Lane2EconomyPreview is on but Server.EconomyPreview is missing")
		return
	end
	local Data = require(preview:FindFirstChild("Data") :: ModuleScript) :: any
	local Economy = require(preview:FindFirstChild("Economy") :: ModuleScript) :: any

	-- BetaCompat creates the folder; making it here first would stop it adding the purchases.
	local net = ReplicatedStorage:WaitForChild(BetaConfig.NetName, 30)
	if not net then
		warn("[CarHopBeta] CarHopBetaNet never appeared; the economy preview did not start")
		return
	end

	local function publishLineup(player: Player)
		local data = Data.get(player)
		if data then
			player:SetAttribute(BetaConfig.LineupAttribute, table.concat(data.Lineup, ","))
		end
	end

	local tutorialDone = Instance.new("RemoteEvent")
	tutorialDone.Name = BetaConfig.Remotes.TutorialDone
	tutorialDone.OnServerEvent:Connect(function(player: Player)
		player:SetAttribute(BetaConfig.TutorialDoneAttribute, true)
	end)
	tutorialDone.Parent = net

	local lastSet: { [Player]: number } = {}
	local setSlot = Instance.new("RemoteEvent")
	setSlot.Name = BetaConfig.Remotes.SetLineupSlot
	setSlot.OnServerEvent:Connect(function(player: Player, slot: unknown, carId: unknown)
		local now = os.clock()
		if now - (lastSet[player] or -math.huge) < COOLDOWN then
			return
		end
		lastSet[player] = now
		-- The preview has no "take the car out" yet, so a nil carId is refused.
		if typeof(slot) ~= "number" or slot ~= slot or typeof(carId) ~= "string" or #carId > 64 then
			return
		end
		if Economy.setLineupSlot(player, slot, carId) then
			publishLineup(player)
		end
	end)
	setSlot.Parent = net

	Data.Loaded:Connect(function(player: Player)
		player:SetAttribute(BetaConfig.TutorialDoneAttribute, false)
		-- after the preview's own Loaded handler has built the Lineup
		task.defer(publishLineup, player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSet[player] = nil
	end)
end

return BetaEconomyBridge
