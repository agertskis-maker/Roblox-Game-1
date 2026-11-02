--!strict
-- Part primitives and the palette for the Stunt Circuit recipe (Lane 3, M17-01). Every part is anchored, smooth and made
-- light: decoration never collides, is never queried or touched, and casts no shadow unless it is a big structure. The
-- road surface is the only thing a test car or character can stand on.
--
--   Parts.box(parent, name, size, cf, colour, opts?)      Parts.cylinder(parent, name, diameter, thickness, cf, colour, opts?)
--   Parts.wedge(parent, name, size, cf, colour, opts?)    Parts.along(...)   Parts.folder(parent, name)
--
-- Wedge geometry (checked by raycast in OverlapScan.selfTest): the low edge is at local -Z and the tall back wall is at
-- local +Z, so a ramp that rises along travel has its +Z toward the direction of travel.

local Parts = {}

local rgb = Color3.fromRGB

Parts.Palette = table.freeze({
	Asphalt = rgb(72, 78, 98),
	AsphaltDark = rgb(52, 56, 74),
	LineWhite = rgb(246, 246, 240),
	Gold = rgb(247, 200, 58),
	Navy = rgb(30, 50, 104),
	Ink = rgb(26, 34, 56),
	Ivory = rgb(255, 246, 224),
	Orange = rgb(255, 122, 26),
	White = rgb(246, 244, 238),
	Concrete = rgb(184, 190, 204),
	ConcreteDark = rgb(150, 158, 176),
	Ground = rgb(176, 184, 198),
	Grass = rgb(112, 184, 98),
	Water = rgb(64, 160, 222),
	Steel = rgb(96, 102, 116),
	Lamp = rgb(255, 244, 200),
	NeonCyan = rgb(150, 232, 255),
	Red = rgb(226, 72, 70),
	Teal = rgb(34, 138, 146),
	PitFloor = rgb(24, 28, 44),
})

export type Opts = {
	material: Enum.Material?,
	collide: boolean?, -- the road surface only
	shadow: boolean?, -- big structures only
	transparency: number?,
	reflectance: number?,
	attributes: { [string]: any }?,
}

local function style(p: BasePart, name: string, size: Vector3, cf: CFrame, colour: Color3, opts: Opts?)
	p.Name = name
	p.Anchored = true
	local collide = opts ~= nil and opts.collide == true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.CastShadow = opts ~= nil and opts.shadow == true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = (opts and opts.material) or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then
		if opts.transparency then
			p.Transparency = opts.transparency
		end
		if opts.reflectance then
			p.Reflectance = opts.reflectance
		end
		if opts.attributes then
			for k, v in opts.attributes do
				p:SetAttribute(k, v)
			end
		end
	end
end

function Parts.box(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, opts: Opts?): Part
	local p = Instance.new("Part")
	style(p, name, size, cf, colour, opts)
	p.Parent = parent
	return p
end

-- A round disc or post. Roblox cylinders run along local X, so a disc lying flat uses `cf * CFrame.Angles(0, 0, pi / 2)`; the
-- caller passes the final cf. `diameter` is across the round face, `thickness` along the axis.
function Parts.cylinder(
	parent: Instance,
	name: string,
	diameter: number,
	thickness: number,
	cf: CFrame,
	colour: Color3,
	opts: Opts?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	style(p, name, Vector3.new(thickness, diameter, diameter), cf, colour, opts)
	p.Parent = parent
	return p
end

-- A disc lying flat, its top at `topY`, centred on the horizontal position of `at`.
function Parts.disc(
	parent: Instance,
	name: string,
	diameter: number,
	thickness: number,
	at: Vector3,
	topY: number,
	colour: Color3,
	opts: Opts?
): Part
	return Parts.cylinder(
		parent,
		name,
		diameter,
		thickness,
		CFrame.new(at.X, topY - thickness / 2, at.Z) * CFrame.Angles(0, 0, math.pi / 2),
		colour,
		opts
	)
end

function Parts.wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, opts: Opts?): WedgePart
	local p = Instance.new("WedgePart")
	style(p, name, size, cf, colour, opts)
	p.Parent = parent
	return p
end

function Parts.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Parts.model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- A box that lies along a straight leg: `along0..along1` measured from the leg origin in its heading, `lat0..lat1` across
-- (+ right of travel), `y0..y1` up. This is how every road piece, barrier and paint line is made, so they all share one
-- frame and cannot drift apart.
function Parts.along(
	parent: Instance,
	name: string,
	origin: Vector3,
	heading: Vector3,
	along0: number,
	along1: number,
	lat0: number,
	lat1: number,
	y0: number,
	y1: number,
	colour: Color3,
	opts: Opts?
): Part
	local mid = origin + heading * ((along0 + along1) / 2)
	local base = CFrame.lookAt(mid, mid + heading) * CFrame.new((lat0 + lat1) / 2, (y0 + y1) / 2, 0)
	return Parts.box(parent, name, Vector3.new(lat1 - lat0, y1 - y0, along1 - along0), base, colour, opts)
end

-- Tags a group as scenery that is not gameplay.
function Parts.flagVisualOnly(instance: Instance, id: string, note: string?)
	instance:SetAttribute("VisualOnly", true)
	instance:SetAttribute("NonColliding", true)
	instance:SetAttribute("ObstacleId", id)
	if note then
		instance:SetAttribute("Note", note)
	end
end

return Parts
