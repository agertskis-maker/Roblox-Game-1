--!strict
-- Home HUD: the ground arrows that lead the player (Lane 3, BRIEF M11-03; rebuilt in Round 2 at Adam's request: "they need
-- to move with the character with every step"). Original white chevrons on the ground, each built from two thin anchored
-- Parts forming a flat ">" with a darker backing a hair larger underneath, so a chevron still reads on pale paving. They
-- follow a polyline of Vector3 points supplied by the tutorial (Tutorial/TutorialWaypoints builds it along the real paths;
-- this module does no pathfinding and no raycasts, and it never touches movement).
--
-- EVERY FRAME, not on a timer: the trail starts just ahead of the character, joins the route a little ahead of where the
-- character stands, and runs on from there, so it stays attached with every step. The chevrons themselves flow forward
-- along it toward the target, fading in at the feet and out at the far end, each one turned along the route's own curve.
-- The corners of the route are rounded once, when it arrives. Under reduced motion the trail still follows the character,
-- but the chevrons stand still.
--
-- POOLED: chevron models are reused (only their CFrames change, in one BulkMoveTo). One RenderStepped connection, only while
-- the trail is visible. Parts never collide, cast shadows, or take touches or queries.
--
-- API: TutorialRoute.new(ctx, { spacing: number?, maxChevrons: number? }?) -> TutorialRoute
--   :setRoute(points: { Vector3 }?)   -- nil or fewer than 2 points clears it
--   :layout()  (no-op: world space)  :setVisible(on)  :destroy()  :getDebugState()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Motion = require(script.Parent.Parent.Motion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local ARM_LENGTH = 3
local ARM_WIDTH = 0.7
local ARM_THICK = 0.12
local ARM_ANGLE = math.rad(38)
local BACK_GROW = 0.3 -- the dark backing is this much longer and wider than the white arm
local LIFT = 0.1
local MAX_CHEVRONS = 22
local REACH = 100 -- studs of trail ahead of the character
local START = 3 -- where the trail starts, ahead of the character
local FLOW = 16 -- studs per second the chevrons run along the route
local JOIN_AHEAD = 7 -- the trail meets the route this far past the nearest point, so it leads on instead of cutting square
local FAR_OFF = 60 -- further than this from the route, the trail just shows the route itself
local REST = 0.05 -- transparency at the brightest
local BACK_TRANSPARENCY = 0.5
local TURN_SAMPLE = 2 -- studs either side a chevron looks along the route to find its direction
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

-- The four CFrames of one flat ">" at `pos`, pointing along the horizontal direction `dir`.
local function place(pos: Vector3, dir: Vector3, out: { CFrame }, n: number): number
	local base = CFrame.lookAt(pos, pos + dir)
	local tip = base * CFrame.new(0, 0, -0.75)
	for _, side in { 1, -1 } do
		local cf = tip * CFrame.Angles(0, side * ARM_ANGLE, 0) * CFrame.new(0, 0, ARM_LENGTH / 2 - ARM_WIDTH / 2)
		out[n + 1] = cf
		out[n + 2] = cf * CFrame.new(0, -ARM_THICK * 0.4, 0)
		n += 2
	end
	return n
end

-- Rounds a polyline's corners (two passes of corner cutting), keeping both ends.
local function rounded(points: { Vector3 }): { Vector3 }
	local list = points
	for _ = 1, 2 do
		local out = { list[1] }
		for i = 1, #list - 1 do
			local a, b = list[i], list[i + 1]
			if (b - a).Magnitude > 1 then
				table.insert(out, a:Lerp(b, 0.25))
				table.insert(out, a:Lerp(b, 0.75))
			end
		end
		table.insert(out, list[#list])
		list = out
	end
	return list
end

function TutorialRoute.new(ctx: Types.Ctx, opts: Options?): TutorialRoute
	local self = setmetatable({}, TutorialRoute) :: any
	self._trove = Trove.new()
	self._ctx = ctx
	self._spacing = (opts and opts.spacing) or 5
	self._max = (opts and opts.maxChevrons) or MAX_CHEVRONS
	self._path = {} :: { Vector3 }
	self._lengths = {} :: { number }
	self._pool = {} :: { Chevron }
	self._used = 0
	self._points = 0
	self._visible = true
	self._builds = 0
	self._moves = 0
	self._clock = 0
	self._loop = nil :: RBXScriptConnection?
	self.root = nil
	local folder = Instance.new("Folder")
	folder.Name = "TutorialRoute"
	folder.Parent = ctx.world
	self._folder = self._trove:Add(folder)
	self._trove:Add(function()
		self:_stopLoop()
		for _, c in self._pool do
			c.model:Destroy()
		end
		table.clear(self._pool)
	end)
	return self :: TutorialRoute
end

local function sameRoute(a: { Vector3 }, b: { Vector3 }): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if (a[i] - b[i]).Magnitude > 0.05 then
			return false
		end
	end
	return true
end

function TutorialRoute.setRoute(self: any, points: { Vector3 }?)
	local list = points or {}
	self._points = #list
	if sameRoute(list, self._raw or {}) then
		return
	end
	self._raw = list
	local path = if #list >= 2 then rounded(list) else {}
	local lengths = table.create(#path, 0)
	for i = 2, #path do
		lengths[i] = lengths[i - 1] + (path[i] - path[i - 1]).Magnitude
	end
	self._path, self._lengths = path, lengths
	self._moves += 1
	self:_updateLoop()
end

-- The point `s` studs along the route.
local function along(path: { Vector3 }, lengths: { number }, s: number): Vector3
	if s <= 0 then
		return path[1]
	end
	local lo, hi = 1, #path
	if s >= lengths[hi] then
		return path[hi]
	end
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if lengths[mid] <= s then
			lo = mid
		else
			hi = mid
		end
	end
	local span = lengths[hi] - lengths[lo]
	return if span > 1e-6 then path[lo]:Lerp(path[hi], (s - lengths[lo]) / span) else path[lo]
end

-- The distance along the route of the point nearest p (plan view), and how far off p is.
local function nearest(path: { Vector3 }, lengths: { number }, p: Vector3): (number, number)
	local bestS, bestD = 0, math.huge
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len2 = ab:Dot(ab)
		local t = if len2 > 1e-6 then math.clamp(Vector3.new(p.X - a.X, 0, p.Z - a.Z):Dot(ab) / len2, 0, 1) else 0
		local q = a:Lerp(b, t)
		local d = Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
		if d < bestD then
			bestD = d
			bestS = lengths[i] + (lengths[i + 1] - lengths[i]) * t
		end
	end
	return bestS, bestD
end

local function characterAt(): Vector3?
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

function TutorialRoute._step(self: any, dt: number)
	local path: { Vector3 }, lengths: { number } = self._path, self._lengths
	if #path < 2 then
		return
	end
	local reduced = Motion.reduced()
	if not reduced then
		self._clock += dt
	end
	local spacing: number = self._spacing
	local flow = if reduced then 0 else (self._clock * FLOW) % spacing
	local total = lengths[#lengths]

	-- the live trail: from the character onto the route just ahead, then along the route
	local origin: Vector3? = nil
	local legLength, joinS = 0, 0
	local join = path[1]
	local at = characterAt()
	if at then
		local s, off = nearest(path, lengths, at)
		if off < FAR_OFF then
			joinS = math.min(s + math.min(JOIN_AHEAD, 2 + off), total)
			join = along(path, lengths, joinS)
			origin = Vector3.new(at.X, join.Y, at.Z)
			legLength = (join - (origin :: Vector3)).Magnitude
		end
	end
	local function live(d: number): Vector3
		if origin and d < legLength then
			return (origin :: Vector3):Lerp(join, d / math.max(legLength, 1e-3))
		end
		return along(path, lengths, joinS + d - legLength)
	end
	local length = legLength + total - joinS
	local reach = math.min(length, REACH)

	local pool: { Chevron } = self._pool
	local parts: { BasePart } = table.create(self._max * 4)
	local frames: { CFrame } = table.create(self._max * 4)
	local n, count = 0, 0
	local d = START + flow
	while d <= reach and count < self._max do
		count += 1
		local c = pool[count]
		if not c then
			c = makeChevron()
			c.model.Name = "Chevron" .. count
			pool[count] = c
			self._builds += 1
		end
		if c.model.Parent ~= self._folder then
			c.model.Parent = self._folder
		end
		local pos = live(d)
		local ahead = live(math.min(d + TURN_SAMPLE, reach)) - live(math.max(d - TURN_SAMPLE, 0))
		local flat = Vector3.new(ahead.X, 0, ahead.Z)
		local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
		n = place(pos + Vector3.yAxis * LIFT, dir, frames, n)
		parts[n - 3], parts[n - 2], parts[n - 1], parts[n] = c.arms[1], c.backs[1], c.arms[2], c.backs[2]
		-- fades in at the feet and out at the far end, so a chevron never pops
		local fade = math.min(math.clamp((d - START) / spacing, 0, 1), math.clamp((reach - d) / (2 * spacing), 0, 1))
		if reduced then
			fade = math.min(1, math.clamp((reach - d) / (2 * spacing), 0.3, 1))
		end
		local t = 1 - (1 - REST) * fade
		local back = 1 - (1 - BACK_TRANSPARENCY) * fade
		for i = 1, 2 do
			c.arms[i].Transparency = t
			c.backs[i].Transparency = back
		end
		d += spacing
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	for i = count + 1, self._used do
		pool[i].model.Parent = nil -- parked in the pool, not destroyed
	end
	self._used = count
end

function TutorialRoute._stopLoop(self: any)
	if self._loop then
		self._loop:Disconnect()
		self._loop = nil
	end
end

function TutorialRoute._updateLoop(self: any)
	local want = self._visible and #self._path >= 2
	if not want then
		self:_stopLoop()
		for i = 1, self._used do
			self._pool[i].model.Parent = nil
		end
		self._used = 0
		return
	end
	if not self._loop then
		self._loop = RunService.RenderStepped:Connect(function(dt: number)
			self:_step(dt)
		end)
	end
	self:_step(0)
end

function TutorialRoute.layout(_self: any) end

function TutorialRoute.setVisible(self: any, on: boolean)
	self._visible = on
	self._folder.Parent = if on then self._ctx.world else nil
	self:_updateLoop()
end

function TutorialRoute.getDebugState(self: any): { [string]: any }
	return {
		visible = self._visible,
		points = self._points,
		chevrons = self._used,
		parts = self._used * 4,
		pooled = #self._pool,
		builds = self._builds, -- chevron models ever created
		moves = self._moves, -- times the route changed
		waveRunning = self._loop ~= nil and not Motion.reduced(), -- the chevrons are flowing
		followsCharacter = self._loop ~= nil,
		reduced = Motion.reduced(),
	}
end

function TutorialRoute.destroy(self: any)
	self._trove:Destroy()
end

return TutorialRoute
