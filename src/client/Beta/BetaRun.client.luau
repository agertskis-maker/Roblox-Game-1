--!strict
-- CAR HOP BETA 1: walking into an open World portal on the island starts Brian R's run (Lane 1,
-- Client.Run.RunController, the "Circuit" profile he plays), which drives Lane 3's RunHud. When the
-- run ends (the results screen's Retry), the player is put back on the island just in front of the
-- portal they used. While a run is on, the takeover attribute MovementSpeedOwner = "CarHopBetaRun"
-- tells the island walking speed to stand aside (vault/design/specs/walk-boost.md).
-- Missing in Beta 1, by design (decision 0030): the run's road is Brian R's test canyon in every
-- World (the Downtown, Dusty Highway and Summit Pass scenery is not under the road yet), nothing
-- from a run is saved, and the cars are his placeholder families.
-- Off unless ReplicatedStorage.CarHopBeta exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end

local RunConfig = require(ReplicatedStorage.Shared:WaitForChild("Run"):WaitForChild("RunConfig"))
local RunController = require(script.Parent.Parent:WaitForChild("Run"):WaitForChild("RunController"))
local PortalPreviewState =
	require(script.Parent.Parent:WaitForChild("Home"):WaitForChild("Island"):WaitForChild("PortalPreviewState"))

local player = Players.LocalPlayer
local OWNER = "CarHopBetaRun"
local ENTER = 3 -- studs from a field's plane
local BACK = 14 -- studs in front of the portal where the player comes back
local REARM = 3 -- seconds after coming back before a portal can start another run

-- one play session's run state (what was claimed, Rider Level, free revives); not saved in Beta 1
local session: RunController.Session = {
	owned = {},
	level = RunConfig.START_RIDER_LEVEL,
	revives = RunConfig.FREE_REVIVES,
}

local current: RunController.RunController? = nil
local returnTo: CFrame? = nil
local quietUntil = 0

local function root(): BasePart?
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function finish()
	local run = current
	current = nil
	if run then
		run:destroy()
	end
	if player:GetAttribute("MovementSpeedOwner") == OWNER then
		player:SetAttribute("MovementSpeedOwner", nil)
	end
	local r = root()
	if r and returnTo then
		r.AssemblyLinearVelocity = Vector3.zero
		r.Parent:PivotTo(returnTo)
	end
	quietUntil = os.clock() + REARM
end

local function start(world: string, field: BasePart)
	if current then
		return
	end
	-- back on the island side of the field, facing the portal
	local front = field.CFrame * CFrame.new(0, 0, -BACK)
	local side = if (front.Position - field.Position):Dot((root() :: BasePart).Position - field.Position) >= 0
		then front
		else field.CFrame * CFrame.new(0, 0, BACK)
	local ground = side.Position - Vector3.new(0, field.Size.Y / 2 - 3, 0)
	returnTo = CFrame.lookAt(ground, Vector3.new(field.Position.X, ground.Y, field.Position.Z))
	player:SetAttribute("MovementSpeedOwner", OWNER)
	local run = RunController.new({ session = session, profile = "Circuit" })
	current = run
	run.Ended:Connect(function()
		task.defer(finish)
	end)
	run:start()
	print(string.format("[CarHopBeta] %s run started (seed %d)", world, run.seed))
end

player.CharacterAdded:Connect(function()
	if current then
		finish()
	end
end)

local last = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if current or now < quietUntil or now - last < 0.1 then
		return
	end
	last = now
	local r = root()
	local fields = Workspace:FindFirstChild("Lane3_PortalFields")
	if not (r and fields) then
		return
	end
	for _, carrier in fields:GetChildren() do
		-- the middle carrier of each field is named "<World>Field"
		if carrier:IsA("BasePart") and string.sub(carrier.Name, -5) == "Field" then
			local world = string.sub(carrier.Name, 1, -6)
			local p = carrier.CFrame:PointToObjectSpace(r.Position)
			local half = carrier.Size / 2
			if
				math.abs(p.X) < half.X
				and math.abs(p.Y) < half.Y + 3
				and math.abs(p.Z) < ENTER
				and not PortalPreviewState.isLocked(world)
			then
				start(world, carrier)
				return
			end
		end
	end
end)
