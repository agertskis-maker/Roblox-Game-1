--!strict
-- Home HUD: tutorial ground guidance (Lane 3, BRIEF M11-03). Original white chevrons on the ground, each built from two
-- thin anchored Parts forming a flat ">" with a darker backing a hair larger underneath, so a chevron still reads on pale
-- paving and with the wave switched off. They follow a polyline of Vector3 points supplied by the tutorial
-- (Tutorial/TutorialWaypoints builds it along the real paths; this module does no pathfinding and no raycasts, and it never
-- touches movement). Each chevron sits at its point's own height plus a small lift.
--
-- POOLED: the trail is re-routed from wherever the player stands, a few times a second, so the chevron models are reused
-- (only their CFrames change) instead of destroyed and rebuilt. setRoute does nothing when the new trail lands on the same
-- chevron positions. A gentle brightness wave runs forward along the trail on ONE Heartbeat connection, throttled to 20 Hz
-- and connected only while the trail is visible and motion is allowed; in reduced motion the chevrons are static. Parts
-- never collide, cast shadows, or take touches or queries.
--
-- API: TutorialRoute.new(ctx, { spacing: number?, maxChevrons: number? }?) -> TutorialRoute
--   :setRoute(points: { Vector3 }?)   -- nil or fewer than 2 points clears it
--   :layout()  (no-op: world space)  :setVisible(on)  :destroy()  :getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Parent.Motion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local ARM_LENGTH = 2.4
local ARM_WIDTH = 0.5
local ARM_THICK = 0.12
local ARM_ANGLE = math.rad(40)
local BACK_GROW = 0.3 -- the dark backing is this much longer and wider than the white arm
local LIFT = 0.1
local MAX_CHEVRONS = 70
local WAVE_HZ = 20
local WAVE_SPEED = 1.2 -- cycles per second along the route
local WAVE_STEP = 0.12 -- phase offset between neighbouring chevrons
local REST = 0.08 -- transparency at the brightest
local DIM = 0.55 -- transparency at the dimmest
local BACK_TRANSPARENCY = 0.5
local INK = Color3.fromRGB(14, 20, 38)

export type Options = { spacing: number?, maxChevrons: number? }

export type TutorialRoute = {
	root: GuiObject?,
	setRoute: (self: TutorialRoute, points: { Vector3 }?) -> (),
	layout: (self: TutorialRoute) -> (),
	setVisible: (self: TutorialRoute, on: boolean) -> (),
	destroy: (self: TutorialRoute) -> (),
	getDebugState: (self: TutorialRoute) -> { [string]: any },
}

type Slot = { pos: Vector3, dir: Vector3 }
type Chevron = { model: Model, arms: { Part }, backs: { Part } }

local TutorialRoute = {}
TutorialRoute.__index = TutorialRoute

local function part(parent: Instance, name: string, size: Vector3, colour: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = colour
	p.Transparency = transparency
	p.Size = size
	p.Parent = parent
	return p
end

local function makeChevron(): Chevron
	local model = Instance.new("Model")
	local arms: { Part } = {}
	local backs: { Part } = {}
	for i = 1, 2 do
		table.insert(
			backs,
			part(
				model,
				"Back" .. i,
				Vector3.new(ARM_WIDTH + BACK_GROW, ARM_THICK * 0.5, ARM_LENGTH + BACK_GROW),
				INK,
				BACK_TRANSPARENCY
			)
		)
		table.insert(
			arms,
			part(model, "Arm" .. i, Vector3.new(ARM_WIDTH, ARM_THICK, ARM_LENGTH), Color3.new(1, 1, 1), REST)
		)
	end
	return { model = model, arms = arms, backs = backs }
end

-- One flat ">" at `pos`, pointing along the horizontal direction `dir`.
local function place(chevron: Chevron, pos: Vector3, dir: Vector3)
	local base = CFrame.lookAt(pos, pos + dir)
	local tip = base * CFrame.new(0, 0, -0.6)
	for i, side in { 1, -1 } do
		local cf = tip * CFrame.Angles(0, side * ARM_ANGLE, 0) * CFrame.new(0, 0, ARM_LENGTH / 2 - ARM_WIDTH / 2)
		chevron.arms[i].CFrame = cf
		chevron.backs[i].CFrame = cf * CFrame.new(0, -ARM_THICK * 0.4, 0)
	end
end

function TutorialRoute.new(ctx: Types.Ctx, opts: Options?): TutorialRoute
	local self = setmetatable({}, TutorialRoute) :: any
	self._trove = Trove.new()
	self._ctx = ctx
	self._spacing = (opts and opts.spacing) or 6
	self._max = (opts and opts.maxChevrons) or MAX_CHEVRONS
	self._slots = {} :: { Slot }
	self._pool = {} :: { Chevron }
	self._used = 0
	self._points = 0
	self._visible = true
	self._builds = 0
	self._moves = 0
	self._wave = nil :: RBXScriptConnection?
	self.root = nil
	local folder = Instance.new("Folder")
	folder.Name = "TutorialRoute"
	folder.Parent = ctx.world
	self._folder = self._trove:Add(folder)
	self._trove:Add(function()
		self:_stopWave()
		for _, c in self._pool do
			c.model:Destroy()
		end
		table.clear(self._pool)
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_updateWave()
	end))
	return self :: TutorialRoute
end

-- The chevron positions along a polyline: the first half a spacing in, then every `spacing` studs, flat directions only.
local function slotsFor(points: { Vector3 }, spacing: number, max: number): { Slot }
	local out: { Slot } = {}
	local carry = spacing / 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flatDir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = (b - a).Magnitude
		if flatDir.Magnitude > 0.05 and length > 0 then
			local dir = flatDir.Unit
			local d = carry
			while d <= length and #out < max do
				table.insert(out, { pos = a:Lerp(b, d / length) + Vector3.new(0, LIFT, 0), dir = dir })
				d += spacing
			end
			carry = d - length
		end
	end
	return out
end

local function sameSlots(a: { Slot }, b: { Slot }): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if (a[i].pos - b[i].pos).Magnitude > 0.05 or a[i].dir:Dot(b[i].dir) < 0.9995 then
			return false
		end
	end
	return true
end

function TutorialRoute.setRoute(self: any, points: { Vector3 }?)
	local list = points or {}
	self._points = #list
	local slots = if #list >= 2 then slotsFor(list, self._spacing, self._max) else {}
	if sameSlots(slots, self._slots) then
		return
	end
	self._slots = slots
	local pool: { Chevron } = self._pool
	for i, slot in slots do
		local c = pool[i]
		if not c then
			c = makeChevron()
			c.model.Name = "Chevron" .. i
			pool[i] = c
			self._builds += 1
		end
		place(c, slot.pos, slot.dir)
		c.model.Parent = self._folder
	end
	for i = #slots + 1, self._used do
		pool[i].model.Parent = nil -- parked in the pool, not destroyed
	end
	self._used = #slots
	self._moves += 1
	self:_applyStatic()
	self:_updateWave()
end

function TutorialRoute._applyStatic(self: any)
	for i = 1, self._used do
		for _, p in self._pool[i].arms do
			p.Transparency = REST
		end
	end
end

function TutorialRoute._stopWave(self: any)
	if self._wave then
		self._wave:Disconnect()
		self._wave = nil
	end
end

function TutorialRoute._updateWave(self: any)
	local want = self._visible and self._used > 0 and not Motion.reduced()
	if not want then
		self:_stopWave()
		self:_applyStatic()
		return
	end
	if self._wave then
		return
	end
	local acc = 0
	local clock = 0
	self._wave = RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		clock += dt
		if acc < 1 / WAVE_HZ then
			return
		end
		acc = 0
		for i = 1, self._used do
			-- 0..1 brightness pulse travelling forward along the route
			local phase = (clock * WAVE_SPEED - (i - 1) * WAVE_STEP) % 1
			local bright = math.max(0, math.cos(phase * 2 * math.pi))
			local t = DIM - (DIM - REST) * bright
			for _, p in self._pool[i].arms do
				p.Transparency = t
			end
		end
	end)
end

function TutorialRoute.layout(_self: any) end

function TutorialRoute.setVisible(self: any, on: boolean)
	self._visible = on
	self._folder.Parent = if on then self._ctx.world else nil
	self:_updateWave()
end

function TutorialRoute.getDebugState(self: any): { [string]: any }
	return {
		visible = self._visible,
		points = self._points,
		chevrons = self._used,
		parts = self._used * 4,
		pooled = #self._pool,
		builds = self._builds, -- chevron models ever created
		moves = self._moves, -- times the trail changed
		waveRunning = self._wave ~= nil,
		reduced = Motion.reduced(),
	}
end

function TutorialRoute.destroy(self: any)
	self._trove:Destroy()
end

return TutorialRoute
