--!strict
-- World-space Hop target ring (Lane 3 preview, worker H3). An original teal/white treatment drawn
-- around a target car that the preview adapter supplies. It is driven ONLY by setState(state):
-- the HUD never picks a target or judges a landing (Lane 1, Brian R).
--
--   Available    soft teal ring (solid) + a thin white inner ring + two subtle upward chevrons
--                above the car (drifting upward; static in reduced motion)
--   Unavailable  a thin grey dashed ring (every other segment), no chevrons
--   Timing       a bright white + teal double ring tightening toward the car, repeating
--                (static, tight and thicker in reduced motion)
--   Hidden       nothing
-- The states differ in shape (solid / dashed / double, chevrons), not colour alone.
--
-- Built from Beams between Attachments on one invisible, anchored, non-colliding, non-queryable
-- carrier Part under ctx.world (no images, nothing attached to the car itself), plus one
-- BillboardGui of Frames for the chevrons. The carrier follows the target's pivot on Heartbeat
-- only while the ring is shown; idle and Hidden states run nothing per frame.
--
--   local ring = HopRing.new(ctx)
--   ring:setTarget(modelOrPart?)   -- the car to mark (Model or BasePart), nil clears
--   ring:setState("Available" | "Unavailable" | "Timing" | "Hidden")
--   ring:layout() (UI scale for the chevrons), ring:setVisible(on), ring:destroy(),
--   ring:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gloss = require(script.Parent.Parent.Gloss)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

export type HopRingState = "Available" | "Unavailable" | "Timing" | "Hidden"

local SEGMENTS = 24
local TIGHTEN_SECONDS = 0.9 -- one tightening cycle (about 1.1 per second, no flashing)
local CHEVRON_SECONDS = 1.2

local HopRing = {}
HopRing.__index = HopRing

local function setBeam(beam: Beam, colour: Color3, width: number, transparency: number, enabled: boolean)
	beam.Color = ColorSequence.new(colour)
	beam.Width0 = width
	beam.Width1 = width
	beam.Transparency = NumberSequence.new(transparency)
	beam.Enabled = enabled
end

function HopRing.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, HopRing)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._state = "Hidden" :: HopRingState
	self._target = nil :: Instance?
	self._radius = 6
	self._height = 0
	self._phase = 0
	self._stepConn = nil :: RBXScriptConnection?
	self._lastPivot = nil :: CFrame?
	self._frames = 0

	local carrier = self._trove:Add(make("Part", {
		Name = "HopRingCarrier",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		Parent = ctx.world,
	}))
	self._carrier = carrier

	-- two rings: outer (teal / grey) and inner (white)
	self._outer = {} :: { Attachment }
	self._inner = {} :: { Attachment }
	self._outerBeams = {} :: { Beam }
	self._innerBeams = {} :: { Beam }
	for i = 1, SEGMENTS do
		local a = make("Attachment", { Name = "O" .. i, Parent = carrier })
		local b = make("Attachment", { Name = "I" .. i, Parent = carrier })
		table.insert(self._outer, a)
		table.insert(self._inner, b)
	end
	for i = 1, SEGMENTS do
		local nextI = i % SEGMENTS + 1
		local ob = make("Beam", {
			Name = "Outer" .. i,
			Attachment0 = self._outer[i],
			Attachment1 = self._outer[nextI],
			FaceCamera = true,
			LightEmission = 0.6,
			LightInfluence = 0,
			Segments = 1,
			Enabled = false,
			Parent = carrier,
		})
		local ib = make("Beam", {
			Name = "Inner" .. i,
			Attachment0 = self._inner[i],
			Attachment1 = self._inner[nextI],
			FaceCamera = true,
			LightEmission = 0.8,
			LightInfluence = 0,
			Segments = 1,
			Enabled = false,
			Parent = carrier,
		})
		table.insert(self._outerBeams, ob)
		table.insert(self._innerBeams, ib)
	end

	-- chevrons: a BillboardGui of rotated Frames (original shapes, no images)
	local board = make("BillboardGui", {
		Name = "HopChevrons",
		Adornee = carrier,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = 250,
		Size = UDim2.fromOffset(60, 70),
		StudsOffsetWorldSpace = Vector3.new(0, 4, 0),
		Enabled = false,
		Parent = carrier,
	})
	self._board = board
	local chevrons = make("Frame", {
		Name = "Chevrons",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(60, 70),
		Parent = board,
	})
	make("UIScale", { Name = "HudScale", Scale = 1, Parent = chevrons })
	self._chevronHolder = chevrons
	self._chevrons = {} :: { Frame }
	for i = 1, 2 do
		local chevron = make("Frame", {
			Name = "Chevron" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 22 + (i - 1) * 22),
			Size = UDim2.fromOffset(44, 20),
			BackgroundTransparency = 1,
			Parent = chevrons,
		})
		for side = -1, 1, 2 do
			local arm = make("Frame", {
				Name = if side < 0 then "Left" else "Right",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, side * 10, 0.5, 0),
				Size = UDim2.fromOffset(26, 8),
				Rotation = side * 35,
				BackgroundColor3 = C.HopLight,
				BorderSizePixel = 0,
				Parent = chevron,
			})
			Gloss.corner(arm, 4)
			Gloss.stroke(arm, 2, C.Ink)
		end
		table.insert(self._chevrons, chevron)
	end

	self._trove:Add(function()
		self:_stopStep()
		for _, c in self._chevrons do
			Motion.cancelAll(c)
		end
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_apply()
	end))
	self:layout()
	return self
end

export type HopRing = typeof(HopRing.new((nil :: any) :: RunLayout.Ctx))

function HopRing._pivot(self: HopRing): CFrame?
	local t = self._target
	if not t or not t.Parent then
		return nil
	end
	if t:IsA("Model") then
		return (t :: Model):GetPivot()
	elseif t:IsA("BasePart") then
		return (t :: BasePart).CFrame
	end
	return nil
end

function HopRing._measure(self: HopRing)
	local t = self._target
	local size = Vector3.new(6, 4, 12)
	local centreY = 0 -- bounding-box centre height relative to the pivot
	if t and t:IsA("Model") then
		local model = t :: Model
		local box, s = model:GetBoundingBox()
		size = s
		centreY = box.Position.Y - model:GetPivot().Position.Y
	elseif t and t:IsA("BasePart") then
		size = (t :: BasePart).Size
	end
	self._radius = math.max(size.X, size.Z) / 2 + 1.5
	-- the ring sits a little above the bottom of the car, relative to the pivot
	self._height = centreY - size.Y / 2 + 0.3
	self._board.StudsOffsetWorldSpace = Vector3.new(0, centreY + size.Y / 2 + 2.5, 0)
end

-- Places the ring attachments for radius scale k (1 = resting radius).
function HopRing._shape(self: HopRing, outerK: number, innerK: number)
	for i = 1, SEGMENTS do
		local angle = (i - 1) / SEGMENTS * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		self._outer[i].Position = dir * self._radius * outerK + Vector3.new(0, self._height, 0)
		self._inner[i].Position = dir * self._radius * innerK + Vector3.new(0, self._height + 0.05, 0)
	end
end

function HopRing._follow(self: HopRing): boolean
	local pivot = self:_pivot()
	if not pivot then
		return false
	end
	-- keep the ring level (yaw only) so it reads as a ground ring even if the car pitches
	local look = pivot.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local cf = if flat.Magnitude > 1e-3
		then CFrame.lookAt(pivot.Position, pivot.Position + flat)
		else CFrame.new(pivot.Position)
	if cf ~= self._lastPivot then
		self._lastPivot = cf
		self._carrier.CFrame = cf
	end
	return true
end

function HopRing._stopStep(self: HopRing)
	local c = self._stepConn
	if c then
		c:Disconnect()
		self._stepConn = nil
	end
end

function HopRing._startStep(self: HopRing)
	if self._stepConn then
		return
	end
	self._stepConn = RunService.Heartbeat:Connect(function(dt: number)
		self._frames += 1
		if not self:_follow() then
			return
		end
		if self._state == "Timing" and not Motion.reduced() then
			self._phase = (self._phase + dt / TIGHTEN_SECONDS) % 1
			-- tighten from 1.35x to 1.0x, then restart (ease-out)
			local e = 1 - (1 - self._phase) ^ 2
			self:_shape(1.35 - 0.35 * e, 0.8)
		end
	end)
end

function HopRing._apply(self: HopRing)
	local state = self._state
	local shown = self._visible and state ~= "Hidden" and self:_pivot() ~= nil
	local reduced = Motion.reduced()
	for _, c in self._chevrons do
		Motion.cancelAll(c)
	end
	if not shown then
		self:_stopStep()
		for i = 1, SEGMENTS do
			self._outerBeams[i].Enabled = false
			self._innerBeams[i].Enabled = false
		end
		self._board.Enabled = false
		return
	end
	self:_measure()
	self:_follow()
	if state == "Available" then
		self:_shape(1, 0.86)
		for i = 1, SEGMENTS do
			setBeam(self._outerBeams[i], C.HopLight, 0.55, 0.15, true)
			setBeam(self._innerBeams[i], C.White, 0.18, 0.35, true)
		end
		self._board.Enabled = true
		for i, c in self._chevrons do
			local rest = UDim2.new(0.5, 0, 0, 22 + (i - 1) * 22)
			c.Position = rest
			if not reduced then
				local info = TweenInfo.new(CHEVRON_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				Motion.tween(c, "drift", info, { Position = rest - UDim2.fromOffset(0, 6) })
			end
		end
	elseif state == "Unavailable" then
		self:_shape(1, 0.86)
		for i = 1, SEGMENTS do
			-- dashed: every other segment
			setBeam(self._outerBeams[i], Color3.fromRGB(170, 176, 190), 0.22, 0.35, i % 2 == 1)
			self._innerBeams[i].Enabled = false
		end
		self._board.Enabled = false
	else -- Timing
		self._phase = 0
		self:_shape(if reduced then 1 else 1.35, 0.8)
		for i = 1, SEGMENTS do
			setBeam(self._outerBeams[i], C.White, if reduced then 0.75 else 0.6, 0.05, true)
			setBeam(self._innerBeams[i], C.HopLight, 0.4, 0.1, true)
		end
		self._board.Enabled = true
		for i, c in self._chevrons do
			c.Position = UDim2.new(0.5, 0, 0, 22 + (i - 1) * 22)
		end
	end
	self:_startStep()
end

function HopRing.setTarget(self: HopRing, target: Instance?)
	if target and not (target:IsA("Model") or target:IsA("BasePart")) then
		target = nil
	end
	self._target = target
	self._lastPivot = nil
	self:_apply()
end

function HopRing.setState(self: HopRing, state: HopRingState)
	if state ~= "Available" and state ~= "Unavailable" and state ~= "Timing" and state ~= "Hidden" then
		return
	end
	self._state = state
	self:_apply()
end

function HopRing.layout(self: HopRing)
	local hud = self._chevronHolder:FindFirstChild("HudScale") :: UIScale
	hud.Scale = self._ctx.screen:uiScale() * self._ctx.screen:fitScale()
	local s = hud.Scale
	self._board.Size = UDim2.fromOffset(60 * s, 70 * s)
end

function HopRing.setVisible(self: HopRing, on: boolean)
	self._visible = on
	self:_apply()
end

function HopRing.getDebugState(self: HopRing): { [string]: any }
	local outerOn, innerOn = 0, 0
	for i = 1, SEGMENTS do
		if self._outerBeams[i].Enabled then
			outerOn += 1
		end
		if self._innerBeams[i].Enabled then
			innerOn += 1
		end
	end
	return {
		state = self._state,
		visible = self._visible,
		target = self._target and self._target:GetFullName(),
		radius = self._radius,
		outerSegments = outerOn,
		innerSegments = innerOn,
		dashed = outerOn > 0 and outerOn < SEGMENTS,
		chevrons = self._board.Enabled,
		stepping = self._stepConn ~= nil,
		heartbeatFrames = self._frames,
		outerRadiusNow = (self._outer[1].Position - Vector3.new(0, self._height, 0)).Magnitude,
		reducedMotion = Motion.reduced(),
		carrierParent = self._carrier.Parent and self._carrier.Parent:GetFullName(),
	}
end

function HopRing.destroy(self: HopRing)
	self._trove:Destroy()
end

return HopRing
