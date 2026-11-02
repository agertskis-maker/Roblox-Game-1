--!strict
-- Home HUD: the ground arrows that lead the player (Lane 3; rebuilt again in Round 3 at Adam's request: "they follow a certain path.
-- I just want them to lead directly into the portal"). Original glowing chevrons, each built from two thin anchored Parts forming
-- a flat ">" with a darker backing a hair larger underneath, so a chevron still reads on pale paving.
--
-- A STRAIGHT LINE from the character to the target, rebuilt EVERY FRAME, so it stays attached with every step. Each chevron sits on
-- whatever is under it (one ray down per chevron, water included), flows toward the target, and hides when the ground under it is
-- well above the character's feet: it would be inside a wall, a roof or a tree. Under reduced motion the chevrons stand still.
--
-- POOLED: chevron models are reused (only their CFrames change, in one BulkMoveTo). One RenderStepped connection, only while the
-- trail is visible. Parts never collide, cast shadows, or take touches or queries.
--
-- API: TutorialRoute.new(ctx, { spacing: number?, maxChevrons: number? }?) -> TutorialRoute
--   :setRoute(points: { Vector3 }?)   -- the LAST point is the target; nil or fewer than 2 points clears it
--   :layout()  (no-op: world space)  :setVisible(on)  :destroy()  :getDebugState()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Motion = require(script.Parent.Parent.Motion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local ARM_LENGTH = 3.4
local ARM_WIDTH = 0.9
local ARM_THICK = 0.12
local ARM_ANGLE = math.rad(38)
local BACK_GROW = 0.45 -- the dark backing is this much longer and wider than the arm, so an arrow reads on pale paving
local LIFT = 0.1
local MAX_CHEVRONS = 22
local REACH = 110 -- studs of trail ahead of the character
local START = 3 -- where the trail starts, ahead of the character
local FLOW = 16 -- studs per second the chevrons run toward the target
local DROP_FROM = 12 -- each ray starts this far above the feet
local TOO_HIGH = 5 -- ground this far above the feet is a solid thing, not ground
local REST = 0.05 -- transparency at the brightest
local BACK_TRANSPARENCY = 0.15
local GLOW = Color3.fromRGB(255, 214, 40) -- the arrows are warm yellow neon: they must read on pale paving and on grass
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
	p.Material = if colour == GLOW then Enum.Material.Neon else Enum.Material.SmoothPlastic
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
		table.insert(arms, part(model, "Arm" .. i, Vector3.new(ARM_WIDTH, ARM_THICK, ARM_LENGTH), GLOW, REST))
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

function TutorialRoute.new(ctx: Types.Ctx, opts: Options?): TutorialRoute
	local self = setmetatable({}, TutorialRoute) :: any
	self._trove = Trove.new()
	self._ctx = ctx
	self._spacing = (opts and opts.spacing) or 5
	self._max = (opts and opts.maxChevrons) or MAX_CHEVRONS
	self._target = nil :: Vector3?
	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self._rayParams.IgnoreWater = false
	self._rayParams.RespectCanCollide = false
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

function TutorialRoute.setRoute(self: any, points: { Vector3 }?)
	local list = points or {}
	self._points = #list
	local target = if #list >= 2 then list[#list] else nil
	if target ~= self._target then
		self._target = target
		self._moves += 1
		self:_updateLoop()
	end
end

local function characterAt(): (Vector3?, Instance?)
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position, character
	end
	return nil, nil
end

function TutorialRoute._step(self: any, dt: number)
	local target: Vector3? = self._target
	local at, character = characterAt()
	if not (target and at) then
		return
	end
	local reduced = Motion.reduced()
	if not reduced then
		self._clock += dt
	end
	local spacing: number = self._spacing
	local flow = if reduced then 0 else (self._clock * FLOW) % spacing
	local flat = Vector3.new(target.X - at.X, 0, target.Z - at.Z)
	local reach = math.min(flat.Magnitude - 2, REACH)
	local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local feet = at.Y - 3
	local params = self._rayParams
	params.FilterDescendantsInstances = { self._folder, character }

	local pool: { Chevron } = self._pool
	local parts: { BasePart } = table.create(self._max * 4)
	local frames: { CFrame } = table.create(self._max * 4)
	local n, count = 0, 0
	local d = START + flow
	while d <= reach and count < self._max do
		local spot = at + dir * d
		local hit = Workspace:Raycast(
			Vector3.new(spot.X, feet + DROP_FROM, spot.Z),
			Vector3.new(0, -DROP_FROM * 2.5, 0),
			params
		)
		local y = if hit then hit.Position.Y else nil
		-- too far above the feet is the top of a wall, roof or tree: the arrow would be inside it
		if y and y <= feet + TOO_HIGH then
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
			n = place(Vector3.new(spot.X, y + LIFT, spot.Z), dir, frames, n)
			parts[n - 3], parts[n - 2], parts[n - 1], parts[n] = c.arms[1], c.backs[1], c.arms[2], c.backs[2]
			-- fades in at the feet and out at the far end, so a chevron never pops
			local fade =
				math.min(math.clamp((d - START) / spacing, 0, 1), math.clamp((reach - d) / (2 * spacing), 0, 1))
			if reduced then
				fade = math.clamp((reach - d) / (2 * spacing), 0.3, 1)
			end
			local t = 1 - (1 - REST) * fade
			local back = 1 - (1 - BACK_TRANSPARENCY) * fade
			for i = 1, 2 do
				c.arms[i].Transparency = t
				c.backs[i].Transparency = back
			end
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
	local want = self._visible and self._target ~= nil
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
