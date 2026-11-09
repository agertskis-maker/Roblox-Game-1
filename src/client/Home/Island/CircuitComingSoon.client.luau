--!strict
-- The Stunt Circuit is "Coming soon" (Round 7 A-03, decision 0042 item 5; Round 8 H-04).
--
-- Round 7 closed the Circuit's gate with a dressed set on the OUTSIDE: a red and white barrier arm, cones, a chequered banner
-- and a big COMING SOON / STUNT CIRCUIT sign. Adam (2026-11-08): the sign and the cones on the outside are not needed, the
-- Circuit already has its own Coming soon preview sign inside (the "ComingSoon" face on the StuntGate model, built by
-- src/island/Hub/Environment/Destinations.luau). So Round 8 deletes the whole outer set: no sign, no banner, no barrier arm,
-- no cones, no posts. Nothing visible is built here any more.
--
-- What stays is ONE invisible wall across the entrance, where the barrier used to stand, so nobody can walk in. The server
-- refuses every Circuit event while BetaConfig.CircuitOpen is false (BetaCircuit), and StuntCircuit adds no Race prompt, so the
-- Circuit is closed three ways. The wall is the only thing this script makes: it is invisible (Transparency 1), casts no shadow
-- and is not hit by raycasts or the camera (CanQuery false), so it is never seen and never blocks the view; it only blocks the
-- walking character (CanCollide true). It is built on the client from the gate's own position, so the baked island is not
-- edited. Off when BetaConfig.CircuitOpen is true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if BetaConfig.CircuitOpen then
	return
end

local env = Workspace:WaitForChild("Lane3_IslandEnvironment", 60)
local destinations = env and env:WaitForChild("Destinations", 30)
local gate = destinations and destinations:WaitForChild("StuntGate", 30)
if not (gate and gate:IsA("Model")) then
	return
end

local box, size = gate:GetBoundingBox()
-- the entrance faces the island centre
local centre = box.Position
local toPlaza = Vector3.new(-centre.X, 0, -centre.Z).Unit
local ground = centre.Y - size.Y / 2
local front = Vector3.new(centre.X, ground, centre.Z) + toPlaza * (size.Z / 2 + 4)
local frame = CFrame.lookAt(front, front + toPlaza) -- looks toward the plaza; X runs across the entrance
local width = math.max(size.X, size.Z) * 0.85

local folder = Instance.new("Folder")
folder.Name = "Lane3_CircuitComingSoon"

-- the invisible wall: the whole entrance, tall enough that nobody hops over it
local wall = Instance.new("Part")
wall.Name = "Wall"
wall.Anchored = true
wall.Size = Vector3.new(width + 8, 30, 2)
wall.CFrame = frame * CFrame.new(0, 15, 2)
wall.Transparency = 1
wall.CanCollide = true
wall.CanQuery = false
wall.CanTouch = false
wall.CastShadow = false
wall.Material = Enum.Material.SmoothPlastic
wall:SetAttribute("Purpose", "Stunt Circuit is Coming soon: invisible wall at the entrance (Round 8 H-04)")
wall.Parent = folder

folder.Parent = Workspace
