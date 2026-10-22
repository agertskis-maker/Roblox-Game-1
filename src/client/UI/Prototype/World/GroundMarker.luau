--!strict
-- Ground interaction marker (Lane 3 preview, HUD rebuild 2026-10-22, worker HW; ledger W-02):
-- a solid coloured centre disc inside a crisp white ring with a thin dark edge, lying on the
-- ground where a walk-in interaction happens. Test fixtures only; adoptable later (W-04).
--
--   * grounded: three flat cylinders, all bottoms 0.05 studs above the surface (found with a
--     short downward ray from `position`, or exactly at `position.Y` with snap = false); their
--     top faces sit at different heights (edge 0.07, ring 0.11, centre 0.17 above the surface),
--     so no two faces are coplanar and nothing z-fights; Anchored, CanCollide / CanQuery /
--     CanTouch off, CastShadow off;
--   * sized to the real interaction area: `diameter` (studs) is the area's diameter;
--   * active: full colour; at most a subtle breathing of the centre (transparency 0 -> 0.18 over
--     2.4 s, engine tween); reduced motion: steady;
--   * inactive: quiet: the centre disappears and the ring turns a desaturated grey-white
--     (ring only), no motion;
--   * distinct from the Hop ring: solid filled disc + continuous white ring (the Hop ring is a
--     dashed teal/white outline around a car with no fill).
--
--   local marker = GroundMarker.new(ctx, { position = Vector3, diameter = 10, colour = Color3?,
--       snap = true?, active = true? })
--   marker:setActive(on)  marker:moveTo(position)
--   marker:layout(), marker:setVisible(on), marker:destroy(), marker:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local INK = PreviewTokens.Arcade.Ink
local WHITE = Color3.new(1, 1, 1)
local QUIET = Color3.fromRGB(200, 204, 212) -- TOKEN CANDIDATE: inactive ring
local DEFAULT_COLOUR = Color3.fromRGB(255, 206, 40) -- TOKEN CANDIDATE: marker centre (gold)
local LIFT = 0.05
local BREATH_SECONDS = 2.4

export type Options = {
	position: Vector3,
	diameter: number,
	colour: Color3?,
	snap: boolean?,
	active: boolean?,
	ringWidth: number?,
}

local GroundMarker = {}
GroundMarker.__index = GroundMarker

local function disc(parent: Instance, name: string, d: number, h: number, colour: Color3): Part
	local p = WorldKit.part(parent, name, Vector3.new(h, d, d), CFrame.new(), colour)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function GroundMarker.new(ctx: WorldKit.Ctx, options: Options)
	local self = setmetatable({}, GroundMarker)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._active = options.active ~= false
	self._colour = options.colour or DEFAULT_COLOUR
	self._snap = options.snap ~= false
	local d = math.max(options.diameter, 2)
	self._diameter = d
	local ring = options.ringWidth or math.max(0.6, d * 0.08)
	self._ringWidth = ring
	self._surface = options.position.Y

	local folder = self._trove:Add(Instance.new("Folder"))
	folder.Name = "GroundMarker"
	folder.Parent = ctx.world
	self._folder = folder
	-- heights are the cylinders' lengths along their axis (X), laid flat below
	self._edge = disc(folder, "Edge", d + 0.5, 0.02, INK)
	self._ring = disc(folder, "Ring", d, 0.06, WHITE)
	self._centre = disc(folder, "Centre", d - 2 * ring, 0.12, self._colour)
	self._trove:Add(function()
		Motion.cancelAll(self._centre)
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_apply()
	end))
	self:moveTo(options.position)
	return self
end

export type GroundMarker = typeof(GroundMarker.new((nil :: any) :: WorldKit.Ctx, {
	position = Vector3.zero,
	diameter = 1,
}))

function GroundMarker.moveTo(self: GroundMarker, position: Vector3)
	local y = position.Y
	if self._snap then
		y = WorldKit.groundY(position + Vector3.new(0, 2, 0), { self._ctx.world }, 12) or position.Y
	end
	self._surface = y
	local flat = CFrame.new(position.X, y, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	-- a cylinder's axis is X; rotated 90 degrees about Z it stands up, so "X offset" = height
	local function place(p: Part)
		local h = p.Size.X
		p.CFrame = flat * CFrame.new(LIFT + h / 2, 0, 0)
	end
	place(self._edge)
	place(self._ring)
	place(self._centre)
	self:_apply()
end

function GroundMarker._apply(self: GroundMarker)
	Motion.cancelAll(self._centre)
	self._folder.Parent = if self._visible then self._ctx.world else nil
	if self._active then
		self._ring.Color = WHITE
		self._ring.Transparency = 0
		self._edge.Transparency = 0
		self._centre.Color = self._colour
		self._centre.Transparency = 0
		if not Motion.reduced() and self._visible then
			local info = TweenInfo.new(BREATH_SECONDS / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			Motion.tween(self._centre, "breath", info, { Transparency = 0.18 })
		end
	else
		self._ring.Color = QUIET
		self._ring.Transparency = 0.35
		self._edge.Transparency = 0.6
		self._centre.Transparency = 1
	end
end

function GroundMarker.setActive(self: GroundMarker, on: boolean)
	self._active = on
	self:_apply()
end

function GroundMarker.layout(_self: GroundMarker) end

function GroundMarker.setVisible(self: GroundMarker, on: boolean)
	self._visible = on
	self:_apply()
end

function GroundMarker.getDebugState(self: GroundMarker): { [string]: any }
	return {
		active = self._active,
		visible = self._visible,
		diameter = self._diameter,
		ringWidth = self._ringWidth,
		surfaceY = self._surface,
		bottomAboveSurface = LIFT,
		breathing = self._active and not Motion.reduced(),
		parts = #self._folder:GetChildren(),
	}
end

function GroundMarker.destroy(self: GroundMarker)
	self._trove:Destroy()
end

return GroundMarker
