--!strict
-- Lets the economy PREVIEW stand in for Car Hop Beta's free-purchase glue (Lane 2, PREVIEW). Only
-- used in a place that has the beta's ReplicatedStorage.CarHopBeta marker. In that place the beta's
-- own server (ServerScriptService.Server.Beta.BetaServer) must be switched off so there is one
-- profile owner and one plot owner. This makes the remotes the beta's Raceway shop and parking sign
-- already fire (ReplicatedStorage.CarHopBetaNet, no arguments) charge real preview prices, and adds
-- the spawn pad the beta's server used to make, so players do not appear inside the fountain.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shop = require(script.Parent.Shop)

local BetaCompat = {}

function BetaCompat.isBetaPlace(): boolean
	return ReplicatedStorage:FindFirstChild("CarHopBeta") ~= nil
end

local function spawnPad()
	if Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		return
	end
	local pad = Instance.new("SpawnLocation")
	pad.Name = "EconomyPreviewSpawn"
	pad.Size = Vector3.new(10, 0.2, 10)
	pad.CFrame = CFrame.lookAt(Vector3.new(0, 0.1, -30), Vector3.new(0, 0.1, 0))
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanTouch = false
	pad.CanQuery = false
	pad.Transparency = 1
	pad.Neutral = true
	pad.Duration = 0
	local decal = pad:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	pad.Parent = Workspace
end

function BetaCompat.start()
	if not BetaCompat.isBetaPlace() then
		return
	end
	local server = script.Parent.Parent
	local beta = server:FindFirstChild("Beta")
	local betaServer = beta and beta:FindFirstChild("BetaServer")
	if betaServer and betaServer:IsA("Script") and not betaServer.Disabled then
		warn("[EconomyPreview] the beta's own server is still on; switch off Server.Beta.BetaServer in this copy")
	end
	if ReplicatedStorage:FindFirstChild("CarHopBetaNet") then
		return
	end
	local net = Instance.new("Folder")
	net.Name = "CarHopBetaNet"
	local level = Instance.new("RemoteEvent")
	level.Name = "BuyRacewayLevel"
	level.Parent = net
	local spot = Instance.new("RemoteEvent")
	spot.Name = "BuyParkingSpot"
	spot.Parent = net
	-- No arguments are read: the server decides the price and the result.
	level.OnServerEvent:Connect(function(player: Player)
		Shop.buyRacewayLevel(player)
	end)
	spot.OnServerEvent:Connect(function(player: Player)
		Shop.buyParkingSpot(player)
	end)
	net.Parent = ReplicatedStorage
	spawnPad()
end

return BetaCompat
