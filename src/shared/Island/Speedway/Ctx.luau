--!strict
-- The build context for one plot's Speedway pieces (Lane 3, presentation only): where the plot
-- is, its level, and plot-frame placement helpers. Plot frame as Hub/Layout: x to the right facing
-- outward, u outward from the fountain, y up from the island surface (Layout.SurfaceY = 0).

local Kit = require(script.Parent.Kit)
local Path = require(script.Parent.Path)

local Ctx = {}

export type Ctx = {
	plot: Model,
	index: number,
	bearing: number,
	frame: CFrame,
	level: number,
	owner: string, -- the owner's display name, or "" (the signs then read YOUR SPEEDWAY)
}

function Ctx.new(plot: Model, index: number, bearing: number, level: number, owner: string): Ctx
	return {
		plot = plot,
		index = index,
		bearing = bearing,
		frame = Path.plotFrame(bearing),
		level = level,
		owner = owner,
	}
end

-- World point of plot-frame (x, u) at height y.
function Ctx.at(ctx: Ctx, x: number, u: number, y: number?): Vector3
	return ctx.frame * Vector3.new(x, y or 0, -u)
end

-- World direction of a plot-frame plan direction.
function Ctx.dir(ctx: Ctx, d: Vector2): Vector3
	return ctx.frame:VectorToWorldSpace(Vector3.new(d.X, 0, -d.Y)).Unit
end

-- A world point from a path-local position (Path.sample).
function Ctx.world(ctx: Ctx, p: Vector3): Vector3
	return ctx.frame * p
end

function Ctx.vector(ctx: Ctx, v: Vector3): Vector3
	return ctx.frame:VectorToWorldSpace(v)
end

-- A mesh base at (x, u, y) with the mesh's front facing plan direction `facing`.
function Ctx.face(ctx: Ctx, x: number, u: number, facing: Vector2, y: number?): CFrame
	local at = Ctx.at(ctx, x, u, y)
	return CFrame.lookAt(at, at - Ctx.dir(ctx, facing))
end

-- A kit mesh placed in `parent` (nil when the mesh is not available in this place).
function Ctx.place(
	ctx: Ctx,
	parent: Instance,
	name: string,
	x: number,
	u: number,
	facing: Vector2,
	y: number?,
	scale: (number | Vector3)?
): MeshPart?
	local part = Kit.place(name, Ctx.face(ctx, x, u, facing, y), scale)
	if part then
		part.Parent = parent
	end
	return part
end

-- World CFrame at path distance s: position on the road centre (plus `offset` to the right of
-- travel and `rise` up off the road), looking along travel, up off the road.
function Ctx.onPath(ctx: Ctx, path: Path.LapPath, s: number, offset: number?, rise: number?): CFrame
	local pos, look, up = Path.sample(path, s)
	local right = look:Cross(up).Unit
	local p = pos + right * (offset or 0) + up * (rise or 0)
	local wp = ctx.frame * p
	return CFrame.lookAt(wp, wp + ctx.frame:VectorToWorldSpace(look), ctx.frame:VectorToWorldSpace(up))
end

return Ctx
