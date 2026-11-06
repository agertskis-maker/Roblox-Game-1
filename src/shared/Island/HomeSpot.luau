--!strict
-- Round 7 (A-01, decision 0042 item 4): home is your Raceway. Where a player stands when they join and after every run: their own
-- plot's entrance (the plot's GateSpawn marker), on the real ground there, facing their Raceway. Shared, so the server (join and
-- respawn) and the client (Launch Pad HOME, End Run, a wreck) put the player on the same spot. The plot is looked up when the
-- player is moved, never cached, so a plot that changed hands is never used.
--
--   HomeSpot.plot(index) -> Model?        HomeSpot.cframe(index) -> CFrame?        HomeSpot.WAITING (before a plot is given)

local Workspace = game:GetService("Workspace")

local HomeSpot = {}

-- By the island centre, in front of the fountain, facing it (the spawn pad's spot): where a player waits for a plot.
HomeSpot.WAITING = CFrame.lookAt(Vector3.new(0, 4, -30), Vector3.new(0, 4, 0))
HomeSpot.ROOT_LIFT = 3.2 -- HumanoidRootPart above the ground for a standard R15 character

function HomeSpot.plot(index: any): Model?
	if type(index) ~= "number" then
		return nil
	end
	local root = Workspace:FindFirstChild("Lane3_IslandPreview")
	local island = root and root:FindFirstChild("Island")
	local plots = island and island:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(string.format("Plot%02d", index))
	return if plot and plot:IsA("Model") then plot else nil
end

-- The ground under a point (anything that collides, characters excluded), or nil.
local function groundAt(at: Vector3, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -90, 0), params)
	return if hit then hit.Position.Y else nil
end

-- The root CFrame at a plot's entrance, facing its Raceway (the Raceway runs out from the entrance, away from the island centre).
function HomeSpot.cframe(index: any, ignore: { Instance }?): CFrame?
	local plot = HomeSpot.plot(index)
	local markers = plot and plot:FindFirstChild("Markers")
	if not (markers and markers:IsA("BasePart")) then
		return nil
	end
	local gate = markers:FindFirstChild("GateSpawn")
	local at = if gate and gate:IsA("Attachment") then gate.WorldPosition else markers.Position
	local out = Vector3.new(at.X, 0, at.Z).Unit -- away from the island centre: toward the Raceway
	if out ~= out then
		out = -markers.CFrame.LookVector
	end
	local y = groundAt(at, ignore or {}) or at.Y
	local pos = Vector3.new(at.X, y + HomeSpot.ROOT_LIFT, at.Z)
	return CFrame.lookAt(pos, pos + out)
end

return HomeSpot
