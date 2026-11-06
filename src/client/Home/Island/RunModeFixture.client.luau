--!strict
-- STUDIO PREVIEW FIXTURE (Lane 3, Raceway round 2, 2026-10-29). Not a run, not a contract.
-- There is no agreed signal yet for "this player has entered a run" (Lane 1, Brian R). To show that
-- the island walking speed hands over and comes back, this fixture stands in for one: while the
-- local player is inside a World portal's field (the client's Lane3_PortalFields carriers, within
-- 3 studs of the field plane), it sets the LocalPlayer attribute "MovementSpeedOwner" (the existing
-- takeover contract, vault/design/specs/walk-boost.md) to "Lane3RunFixture"; once the player is 8
-- studs clear of every field it removes it again, so the island base 32 comes back. The real signal
-- is Brian R's to send (vault/design/specs/island-walking-for-brian-r.md).
-- Studio only; off with the LocalPlayer attribute Lane3RunFixture = false. It never sets the
-- attribute while another system owns speed, and only ever clears its own value.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- off in Car Hop Beta 1, where the run portals (Beta/BetaRun) own the takeover
if not RunService:IsStudio() or game:GetService("ReplicatedStorage"):FindFirstChild("CarHopBeta") then
	return
end

local player = Players.LocalPlayer
local OWNER = "Lane3RunFixture"
local ENTER, LEAVE = 3, 8 -- studs from the field plane (enter / leave, so it never flickers)

local last = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - last < 0.1 then
		return
	end
	last = now
	local mine = player:GetAttribute("MovementSpeedOwner") == OWNER
	if player:GetAttribute("Lane3RunFixture") == false then
		if mine then
			player:SetAttribute("MovementSpeedOwner", nil)
		end
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local fields = Workspace:FindFirstChild("Lane3_PortalFields")
	if not (root and root:IsA("BasePart") and fields) then
		return
	end
	local nearest = math.huge
	for _, carrier in fields:GetChildren() do
		-- the middle carrier of each field ("<World>Field"), sized to the field plus its margin
		if carrier:IsA("BasePart") and string.sub(carrier.Name, -5) == "Field" then
			local p = carrier.CFrame:PointToObjectSpace(root.Position)
			local half = carrier.Size / 2
			if math.abs(p.X) < half.X and math.abs(p.Y) < half.Y + 3 then
				nearest = math.min(nearest, math.abs(p.Z))
			end
		end
	end
	local owner = player:GetAttribute("MovementSpeedOwner")
	if nearest < ENTER and owner == nil then
		player:SetAttribute("MovementSpeedOwner", OWNER)
	elseif mine and nearest > LEAVE then
		player:SetAttribute("MovementSpeedOwner", nil)
	end
end)
