--!strict
-- Small part-making helpers shared by the island recipes (Lane 3, build-time only).

local Kit = {}

export type PartOptions = {
	name: string?,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
	shape: Enum.PartType?,
	castShadow: boolean?,
}

-- Every island part is anchored. Decoration and helpers do not collide, query or touch.
function Kit.part(parent: Instance, size: Vector3, cframe: CFrame, options: PartOptions?): Part
	local o: PartOptions = options or {}
	local p = Instance.new("Part")
	p.Name = o.name or "Part"
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = o.color or Color3.fromRGB(200, 200, 200)
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = if o.castShadow == nil then true else o.castShadow
	if o.shape then
		p.Shape = o.shape
	end
	local collide = o.collide == true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- A flat strip on top of a surface from a to b (world points at the same height).
function Kit.strip(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	width: number,
	thickness: number,
	topY: number,
	options: PartOptions?,
	overlap: number?
): Part?
	local flatA = Vector3.new(a.X, 0, a.Z)
	local flatB = Vector3.new(b.X, 0, b.Z)
	local length = (flatB - flatA).Magnitude
	if length < 1e-3 then
		return nil
	end
	local mid = (flatA + flatB) / 2
	local center = Vector3.new(mid.X, topY - thickness / 2, mid.Z)
	local look = Vector3.new(flatB.X, center.Y, flatB.Z)
	return Kit.part(
		parent,
		Vector3.new(width, thickness, length + (overlap or 0)),
		CFrame.lookAt(center, look),
		options
	)
end

-- A raised wall segment standing on the surface from a to b.
function Kit.wall(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	thickness: number,
	height: number,
	baseY: number,
	options: PartOptions?
): Part?
	return Kit.strip(parent, a, b, thickness, height, baseY + height, options, 0)
end

-- A sloped walkable slab from a ground point to a raised point; its top surface runs from a to b.
function Kit.ramp(parent: Instance, a: Vector3, b: Vector3, width: number, options: PartOptions?): Part
	local thickness = 1
	local dir = (b - a).Unit
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + dir)
	cf = cf * CFrame.new(0, -thickness / 2, 0)
	return Kit.part(parent, Vector3.new(width, thickness, (b - a).Magnitude + 0.5), cf, options)
end

-- A flat disc (cylinder lying down) with its top at topY.
function Kit.disc(
	parent: Instance,
	center: Vector3,
	diameter: number,
	thickness: number,
	topY: number,
	options: PartOptions?
): Part
	local o: PartOptions = table.clone(options or {})
	o.shape = Enum.PartType.Cylinder
	return Kit.part(
		parent,
		Vector3.new(thickness, diameter, diameter),
		CFrame.new(center.X, topY - thickness / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		o
	)
end

-- A floating text label (development helper).
function Kit.label(parent: Instance, position: Vector3, text: string, size: number?, color: Color3?): Part
	local anchor = Kit.part(parent, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), {
		name = "Label",
		transparency = 1,
		castShadow = false,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(math.max(120, #text * (size or 18) * 0.6), (size or 18) + 12)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 2000
	gui.LightInfluence = 0
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 0.25
	textLabel.BackgroundColor3 = Color3.fromRGB(255, 244, 220)
	textLabel.TextColor3 = color or Color3.fromRGB(30, 42, 74)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = size or 18
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = anchor
	return anchor
end

return Kit
