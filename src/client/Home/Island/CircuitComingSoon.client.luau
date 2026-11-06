--!strict
-- Round 7 (A-03, decision 0042 item 5): the Stunt Circuit is "Coming soon". Its gate on the island is closed with a set in the
-- island's style: a red and white barrier arm across the entrance, cones, a chequered banner and a big COMING SOON sign, with an
-- invisible wall behind it so nothing past the gate can be entered. Built on the client from the gate's own position, so the baked
-- island is not edited. Off when BetaConfig.CircuitOpen is true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))
if BetaConfig.CircuitOpen then
	return
end

local RED = Color3.fromRGB(226, 52, 52)
local WHITE = Color3.fromRGB(250, 248, 240)
local NAVY = Color3.fromRGB(24, 36, 72)
local ORANGE = Color3.fromRGB(255, 140, 30)
local YELLOW = Color3.fromRGB(255, 205, 50)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	props: { [string]: any }?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
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
part(folder, "Wall", Vector3.new(width + 8, 30, 2), frame * CFrame.new(0, 15, 2), WHITE, {
	Transparency = 1,
	CanCollide = true,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
})

-- the barrier arm on two posts: red and white stripes
local half = width / 2
for _, x in { -half, half } do
	part(folder, "Post", Vector3.new(1.4, 4.6, 1.4), frame * CFrame.new(x, 2.3, 0), NAVY)
	part(folder, "PostCap", Vector3.new(1.8, 0.6, 1.8), frame * CFrame.new(x, 4.9, 0), YELLOW)
end
local stripes = math.max(6, math.floor(width / 3))
for i = 0, stripes - 1 do
	local w = width / stripes
	part(
		folder,
		"Arm",
		Vector3.new(w, 1, 0.8),
		frame * CFrame.new(-half + w * (i + 0.5), 3.9, 0),
		if i % 2 == 0 then RED else WHITE
	)
end

-- cones in a row in front of the arm
for i = -2, 2 do
	local at = frame * CFrame.new(i * width / 5, 0, -3.5)
	part(folder, "ConeBase", Vector3.new(2.2, 0.3, 2.2), at * CFrame.new(0, 0.15, 0), ORANGE)
	-- a cone from three stacked discs, narrower to the top, with a white band
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	for k, d in { 1.7, 1.25, 0.8 } do
		part(
			folder,
			"Cone",
			Vector3.new(0.9, d, d),
			at * CFrame.new(0, 0.3 + 0.8 * k - 0.35, 0) * upright,
			if k == 2 then WHITE else ORANGE,
			{ Shape = Enum.PartType.Cylinder }
		)
	end
end

-- a chequered banner between two tall poles, and the sign under it
local bannerY = 13
for _, x in { -half - 1, half + 1 } do
	part(folder, "BannerPole", Vector3.new(0.8, bannerY + 2, 0.8), frame * CFrame.new(x, (bannerY + 2) / 2, 1), NAVY)
end
local squares = 16
for i = 0, squares - 1 do
	for row = 0, 1 do
		local w = (width + 2) / squares
		part(
			folder,
			"Chequer",
			Vector3.new(w, 1.2, 0.3),
			frame * CFrame.new(-half - 1 + w * (i + 0.5), bannerY + 0.6 - row * 1.2, 1),
			if (i + row) % 2 == 0 then NAVY else WHITE
		)
	end
end
local board = part(folder, "Sign", Vector3.new(math.min(width, 24), 6, 0.6), frame * CFrame.new(0, 8.6, 1), NAVY)
local stroke =
	part(folder, "SignRim", board.Size + Vector3.new(0.8, 0.8, -0.2), board.CFrame * CFrame.new(0, 0, 0.1), YELLOW)
stroke.CastShadow = false
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Back -- the board's back face looks toward the plaza (the frame looks toward it from the gate)
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 40
gui.LightInfluence = 0
gui.Parent = board
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 0.72)
label.FontFace = FONT
label.TextScaled = true
label.TextColor3 = YELLOW
label.Text = "COMING SOON"
label.Parent = gui
local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.fromScale(0, 0.68)
sub.Size = UDim2.fromScale(1, 0.28)
sub.FontFace = FONT
sub.TextScaled = true
sub.TextColor3 = WHITE
sub.Text = "STUNT CIRCUIT"
sub.Parent = gui

folder.Parent = Workspace
