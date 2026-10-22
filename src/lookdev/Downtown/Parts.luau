--!strict
-- Small part-building helpers for the Downtown look-dev proxies (Lane 3 preview). Every part is
-- anchored, smooth and non-colliding: these are visual stand-ins, never gameplay geometry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))

local Parts = {}

function Parts.block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Parent = parent
	return p
end

-- A flat disc lying on `cf`'s XZ plane (a cylinder turned so its axis points up), its top at
-- cf.Y + thickness / 2.
function Parts.disc(
	parent: Instance,
	name: string,
	diameter: number,
	thickness: number,
	cf: CFrame,
	colour: Color3
): Part
	local p = Parts.block(
		parent,
		name,
		Vector3.new(thickness, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.pi / 2),
		colour,
		Enum.PartType.Cylinder
	)
	p.CastShadow = false
	return p
end

-- A label for proxies and missing meshes, shown above `adornee`.
function Parts.label(adornee: BasePart, text: string, offsetY: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 180
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundColor3 = Color3.fromRGB(30, 42, 74)
	textLabel.BackgroundTransparency = 0.15
	textLabel.TextColor3 = Color3.fromRGB(255, 244, 220)
	textLabel.TextScaled = true
	textLabel.FontFace = Tokens.font()
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = adornee
	return gui
end

return Parts
