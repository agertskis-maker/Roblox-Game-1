--!strict
-- Home HUD: tutorial ground guidance (Lane 3 preview). Original white chevrons, each built from
-- two thin anchored Parts forming a flat ">" that points along a FIXTURE route (a list of
-- Vector3 points supplied by the playground). No pathfinding, no raycasts, no change to the
-- movement boost lanes: the chevrons simply follow the given polyline, at the points' own
-- height plus a small lift.
--
-- Rebuilt only when the route actually changes (compared point by point). A gentle sequential
-- brightness wave runs along the chevrons on one Heartbeat connection, throttled to 20 Hz and
-- connected only while the route is visible and motion is allowed; in reduced motion the
-- chevrons are static. Parts never collide, cast shadows, or take touches or queries.
--
-- API: TutorialRoute.new(ctx, { spacing: number? }?) -> TutorialRoute
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
local LIFT = 0.1
local MAX_CHEVRONS = 60
local WAVE_HZ = 20
local WAVE_SPEED = 1.2 -- cycles per second along the route
local WAVE_STEP = 0.12 -- phase offset between neighbouring chevrons
local REST = 0.08 -- transparency at the brightest
local DIM = 0.55 -- transparency at the dimmest

export type Options = { spacing: number? }

export type TutorialRoute = {
	root: GuiObject?,
	setRoute: (self: TutorialRoute, points: { Vector3 }?) -> (),
	layout: (self: TutorialRoute) -> (),
	setVisible: (self: TutorialRoute, on: boolean) -> (),
	destroy: (self: TutorialRoute) -> (),
	getDebugState: (self: TutorialRoute) -> { [string]: any },
}

local TutorialRoute = {}
TutorialRoute.__index = TutorialRoute

local function arm(parent: Instance, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = "Arm"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.new(1, 1, 1)
	p.Transparency = REST
	p.Size = Vector3.new(ARM_WIDTH, ARM_THICK, ARM_LENGTH)
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- One flat ">" at `pos`, pointing along the horizontal direction `dir`.
local function chevron(parent: Instance, pos: Vector3, dir: Vector3): { Part }
	local base = CFrame.lookAt(pos, pos + dir)
	local tip = base * CFrame.new(0, 0, -0.6)
	local parts = {}
	for _, side in { 1, -1 } do
		local cf = tip * CFrame.Angles(0, side * ARM_ANGLE, 0) * CFrame.new(0, 0, ARM_LENGTH / 2 - ARM_WIDTH / 2)
		table.insert(parts, arm(parent, cf))
	end
	return parts
end

function TutorialRoute.new(ctx: Types.Ctx, opts: Options?): TutorialRoute
	local self = setmetatable({}, TutorialRoute) :: any
	self._trove = Trove.new()
	self._ctx = ctx
	self._spacing = (opts and opts.spacing) or 6
	self._points = {} :: { Vector3 }
	self._chevrons = {} :: { { Part } }
	self._visible = true
	self._builds = 0
	self._wave = nil :: RBXScriptConnection?
	self.root = nil
	local folder = Instance.new("Folder")
	folder.Name = "TutorialRoute"
	folder.Parent = ctx.world
	self._folder = self._trove:Add(folder)
	self._trove:Add(function()
		self:_stopWave()
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_updateWave()
	end))
	return self :: TutorialRoute
end

local function sameRoute(a: { Vector3 }, b: { Vector3 }): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if (a[i] - b[i]).Magnitude > 0.01 then
			return false
		end
	end
	return true
end

function TutorialRoute.setRoute(self: any, points: { Vector3 }?)
	local list = if points then table.clone(points) else {}
	if sameRoute(list, self._points) then
		return
	end
	self._points = list
	self._folder:ClearAllChildren()
	table.clear(self._chevrons)
	if #list >= 2 then
		local spacing: number = self._spacing
		local carry = spacing / 2
		for i = 1, #list - 1 do
			local a, b = list[i], list[i + 1]
			local flatDir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local length = (b - a).Magnitude
			if flatDir.Magnitude > 0.05 and length > 0 then
				local dir = flatDir.Unit
				local d = carry
				while d <= length and #self._chevrons < MAX_CHEVRONS do
					local pos = a:Lerp(b, d / length) + Vector3.new(0, LIFT, 0)
					local model = Instance.new("Model")
					model.Name = "Chevron" .. (#self._chevrons + 1)
					local parts = chevron(model, pos, dir)
					model.Parent = self._folder
					table.insert(self._chevrons, parts)
					d += spacing
				end
				carry = d - length
			end
		end
	end
	self._builds += 1
	self:_applyStatic()
	self:_updateWave()
end

function TutorialRoute._applyStatic(self: any)
	for _, parts in self._chevrons do
		for _, p in parts do
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
	local want = self._visible and #self._chevrons > 0 and not Motion.reduced()
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
		for i, parts in self._chevrons do
			-- 0..1 brightness pulse travelling forward along the route
			local phase = (clock * WAVE_SPEED - (i - 1) * WAVE_STEP) % 1
			local bright = math.max(0, math.cos(phase * 2 * math.pi))
			local t = DIM - (DIM - REST) * bright
			for _, p in parts do
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
	local parts = 0
	for _, c in self._chevrons do
		parts += #c
	end
	return {
		visible = self._visible,
		points = #self._points,
		chevrons = #self._chevrons,
		parts = parts,
		builds = self._builds,
		waveRunning = self._wave ~= nil,
		reduced = Motion.reduced(),
	}
end

function TutorialRoute.destroy(self: any)
	self._trove:Destroy()
end

return TutorialRoute
