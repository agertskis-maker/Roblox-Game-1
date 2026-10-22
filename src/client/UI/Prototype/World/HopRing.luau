--!strict
-- World-space Hop target ring (Lane 3 preview; restyled in the HUD rebuild 2026-10-22, worker HW;
-- ledger T-05, T-07). One ring, around ONE selected target that the preview adapter supplies.
-- Driven only by setTarget / setState: the HUD never picks a target or judges a landing
-- (Lane 1, Brian R).
--
-- Shape: a rounded-rectangle ring (superellipse, exponent 4) sized from the target's bounding
-- box with a 1.2–2.2 stud margin, so a compact hatch gets a tight ring and a bus a long one,
-- and the ring always lies OUTSIDE the body and wheels (it never clips into them). A circle
-- would spill into the next lanes for long vehicles; an ellipse cuts the corners of a bus.
-- Grounded: the ring height comes from a short downward ray under the target (re-checked every
-- 0.5 s), 0.03–0.09 studs above the surface — on the road, never hovering, no z-fighting.
-- Built from flat dash Parts (anchored, CanCollide/CanQuery/CanTouch off, no shadow) in a fixed
-- pool, moved together with Workspace:BulkMoveTo only when the target moves.
--
--   Available    dashed: alternating teal (Neon) and white dashes on a dark navy underlay
--                (60% dash, 40% gap); static
--   Timing       the hop window: dashes nearly merge (85%), thicker, brighter; the ring tightens
--                from 1.2x to 1x once per 0.9 s (static in reduced motion)
--   Unavailable  structure AND brightness change: the dashes merge into one thin grey solid ring,
--                no underlay, no pulse — it never looks like a valid jump
--   Hidden       nothing (the folder leaves the world; nothing runs)
-- Retarget: the single ring moves to the new target at once; the previous ring cannot remain.
-- Reduced motion: no tightening; everything else is already static.
--
--   local ring = HopRing.new(ctx, { target = model? })
--   ring:setTarget(modelOrPart?)   ring:setState("Available" | "Unavailable" | "Timing" | "Hidden")
--   ring:centre() -> Vector3?      ring:footprint() -> Vector2 (semi-axes in studs)
--   ring:layout(), ring:setVisible(on), ring:destroy(), ring:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local C = PreviewTokens.Color
local INK = PreviewTokens.Arcade.Ink
local GREY = Color3.fromRGB(170, 176, 190) -- TOKEN CANDIDATE: unavailable ring

export type HopRingState = "Available" | "Unavailable" | "Timing" | "Hidden"

local MAX_DASHES = 28
local SAMPLES = 192
local EXPONENT = 4
local TIGHTEN_SECONDS = 0.9
local GROUND_RECHECK = 0.5

local HopRing = {}
HopRing.__index = HopRing

type Look = {
	duty: number,
	width: number,
	height: number,
	underlay: boolean,
	colours: { Color3 },
	neon: boolean,
	transparency: number,
}

local LOOKS: { [string]: Look } = {
	Available = {
		duty = 0.6,
		width = 0.5,
		height = 0.06,
		underlay = true,
		colours = { C.HopLight, C.White },
		neon = true,
		transparency = 0,
	},
	Timing = {
		duty = 0.85,
		width = 0.7,
		height = 0.06,
		underlay = true,
		colours = { C.HopLight, C.White },
		neon = true,
		transparency = 0,
	},
	Unavailable = {
		duty = 1.04, -- slight overlap: one continuous thin ring
		width = 0.22,
		height = 0.05,
		underlay = false,
		colours = { GREY },
		neon = false,
		transparency = 0.25,
	},
}

function HopRing.new(ctx: WorldKit.Ctx, options: { target: Instance? }?)
	local self = setmetatable({}, HopRing)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._state = "Hidden" :: HopRingState
	self._target = nil :: Instance?
	self._axes = Vector2.new(4, 7)
	self._local = {} :: { CFrame } -- dash CFrames relative to the ring centre (k = 1)
	self._underLocal = {} :: { CFrame }
	self._dashCount = 0
	self._centreOffset = CFrame.new()
	self._groundAt = 0
	self._k = 1
	self._phase = 0
	self._step = nil :: RBXScriptConnection?
	self._lastCentre = nil :: CFrame?
	self._moves = 0
	self._retargets = 0

	local folder = self._trove:Add(Instance.new("Folder"))
	folder.Name = "HopRing"
	self._folder = folder
	self._dashes = {} :: { BasePart }
	self._unders = {} :: { BasePart }
	for i = 1, MAX_DASHES do
		local u = WorldKit.part(folder, "Under" .. i, Vector3.new(0.8, 0.04, 1), CFrame.new(), INK)
		u.Transparency = 1
		table.insert(self._unders, u)
		local d = WorldKit.part(folder, "Dash" .. i, Vector3.new(0.5, 0.06, 1), CFrame.new(), C.HopLight)
		d.Transparency = 1
		table.insert(self._dashes, d)
	end

	self._trove:Add(Motion.onReducedChanged(function()
		self:_apply()
	end))
	self._trove:Add(function()
		self:_stopStep()
	end)
	if options and options.target then
		self:setTarget(options.target)
	end
	self:layout()
	return self
end

export type HopRing = typeof(HopRing.new((nil :: any) :: WorldKit.Ctx))

-- GEOMETRY -----------------------------------------------------------------------------------

local function squircle(a: number, b: number, t: number): Vector3
	local c, s = math.cos(t), math.sin(t)
	local e = 2 / EXPONENT
	local x = a * math.sign(c) * math.abs(c) ^ e
	local z = b * math.sign(s) * math.abs(s) ^ e
	return Vector3.new(x, 0, z)
end

-- Points spaced evenly by arc length around the ring.
local function perimeter(a: number, b: number): ({ Vector3 }, { number }, number)
	local pts, cum = {}, {}
	local total = 0
	local prev = squircle(a, b, 0)
	for i = 0, SAMPLES do
		local p = squircle(a, b, i / SAMPLES * math.pi * 2)
		total += (p - prev).Magnitude
		prev = p
		table.insert(pts, p)
		table.insert(cum, total)
	end
	return pts, cum, total
end

local function pointAt(pts: { Vector3 }, cum: { number }, distance: number): Vector3
	-- binary search the cumulative length
	local lo, hi = 1, #cum
	while lo < hi do
		local mid = (lo + hi) // 2
		if cum[mid] < distance then
			lo = mid + 1
		else
			hi = mid
		end
	end
	if lo <= 1 then
		return pts[1]
	end
	local d0, d1 = cum[lo - 1], cum[lo]
	local f = if d1 > d0 then (distance - d0) / (d1 - d0) else 0
	return pts[lo - 1]:Lerp(pts[lo], f)
end

function HopRing._pivot(self: HopRing): CFrame?
	local t = self._target
	if not t or not t:IsDescendantOf(game) then
		return nil
	end
	if t:IsA("Model") then
		return (t :: Model):GetPivot()
	elseif t:IsA("BasePart") then
		return (t :: BasePart).CFrame
	end
	return nil
end

function HopRing._ground(self: HopRing)
	local t = self._target
	local pivot = self:_pivot()
	if not t or not pivot then
		return
	end
	local box, size = WorldKit.box(t)
	local bottom = box.Position.Y - size.Y / 2
	local y = WorldKit.groundY(box.Position, { t, self._ctx.world }, size.Y / 2 + 12)
	local surface = y or bottom
	local flat = WorldKit.flat(pivot)
	local rel = flat:PointToObjectSpace(Vector3.new(box.Position.X, surface, box.Position.Z))
	self._centreOffset = CFrame.new(rel.X, rel.Y, rel.Z)
	self._groundAt = os.clock()
end

function HopRing._measure(self: HopRing)
	local t = self._target
	if not t then
		return
	end
	local _, size = WorldKit.box(t)
	local margin = math.clamp(0.12 * math.max(size.X, size.Z), 1.2, 2.2)
	local a = math.max(size.X / 2 + margin, 2.6)
	local b = math.max(size.Z / 2 + margin, 2.6)
	self._axes = Vector2.new(a, b)
	self:_ground()
	self:_shape()
end

-- Builds the dash and underlay local CFrames for the current state's look.
function HopRing._shape(self: HopRing)
	local look = LOOKS[self._state]
	if not look then
		return
	end
	local a, b = self._axes.X, self._axes.Y
	local pts, cum, total = perimeter(a, b)
	local count = if look.duty >= 1
		then MAX_DASHES
		else math.clamp(math.floor(total / 2.6 / 2 + 0.5) * 2, 12, MAX_DASHES)
	self._dashCount = count
	table.clear(self._local)
	table.clear(self._underLocal)
	local seg = total / count
	for i = 1, MAX_DASHES do
		if i > count then
			self._dashes[i].Transparency = 1
			self._unders[i].Transparency = 1
			continue
		end
		local s0 = (i - 1) * seg
		local s1 = s0 + seg * look.duty
		local p0 = pointAt(pts, cum, s0)
		-- the solid (Unavailable) ring's last piece wraps past the start point
		local p1 = if s1 > total then pointAt(pts, cum, s1 - total) else pointAt(pts, cum, s1)
		local mid = (p0 + p1) / 2
		local dir = p1 - p0
		local len = math.max(dir.Magnitude, 0.1)
		local cf = CFrame.lookAt(mid, mid + dir.Unit)
		local d = self._dashes[i]
		d.Size = Vector3.new(look.width, look.height, len)
		d.Color = look.colours[(i - 1) % #look.colours + 1]
		d.Material = if look.neon and i % 2 == 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		d.Transparency = look.transparency
		table.insert(self._local, cf + Vector3.new(0, 0.03 + look.height / 2, 0))
		local u = self._unders[i]
		u.Size = Vector3.new(look.width + 0.35, 0.04, len + 0.35)
		u.Transparency = if look.underlay then 0 else 1
		table.insert(self._underLocal, cf + Vector3.new(0, 0.04, 0))
	end
end

-- Moves every dash for the current centre and tighten factor (one BulkMoveTo call).
function HopRing._place(self: HopRing, force: boolean?)
	local pivot = self:_pivot()
	if not pivot then
		return false
	end
	local centre = WorldKit.flat(pivot) * self._centreOffset
	if not force and centre == self._lastCentre and self._k == 1 then
		return true
	end
	self._lastCentre = centre
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	local k = self._k
	for i = 1, self._dashCount do
		local l = self._local[i]
		local u = self._underLocal[i]
		if l then
			table.insert(parts, self._dashes[i])
			table.insert(cfs, centre * (l.Rotation + l.Position * Vector3.new(k, 1, k)))
		end
		if u then
			table.insert(parts, self._unders[i])
			table.insert(cfs, centre * (u.Rotation + u.Position * Vector3.new(k, 1, k)))
		end
	end
	Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	self._moves += 1
	return true
end

-- STATE --------------------------------------------------------------------------------------

function HopRing._stopStep(self: HopRing)
	if self._step then
		self._step:Disconnect()
		self._step = nil
	end
end

function HopRing._startStep(self: HopRing)
	if self._step then
		return
	end
	self._step = RunService.Heartbeat:Connect(function(dt: number)
		if not self:_pivot() then
			-- the target despawned: the ring goes with it
			self._target = nil
			self:_apply()
			return
		end
		if os.clock() - self._groundAt > GROUND_RECHECK then
			self:_ground()
		end
		if self._state == "Timing" and not Motion.reduced() then
			self._phase = (self._phase + dt / TIGHTEN_SECONDS) % 1
			local e = 1 - (1 - self._phase) ^ 2
			self._k = 1.2 - 0.2 * e
			self:_place(true)
		else
			self._k = 1
			self:_place(false)
		end
	end)
end

function HopRing._apply(self: HopRing)
	local shown = self._visible and self._state ~= "Hidden" and self:_pivot() ~= nil
	if not shown then
		self:_stopStep()
		self._folder.Parent = nil
		return
	end
	self._k = 1
	self._phase = 0
	self:_measure()
	self._folder.Parent = self._ctx.world
	self:_place(true)
	self:_startStep()
end

function HopRing.setTarget(self: HopRing, target: Instance?)
	if target and not (target:IsA("Model") or target:IsA("BasePart")) then
		target = nil
	end
	if target ~= self._target then
		self._retargets += 1
	end
	self._target = target
	self._lastCentre = nil
	self:_apply()
end

function HopRing.setState(self: HopRing, state: HopRingState)
	if state ~= "Available" and state ~= "Unavailable" and state ~= "Timing" and state ~= "Hidden" then
		return
	end
	self._state = state
	self:_apply()
end

function HopRing.state(self: HopRing): HopRingState
	return self._state
end

function HopRing.centre(self: HopRing): Vector3?
	local pivot = self:_pivot()
	if not pivot then
		return nil
	end
	return (WorldKit.flat(pivot) * self._centreOffset).Position
end

function HopRing.footprint(self: HopRing): Vector2
	return self._axes
end

function HopRing.layout(_self: HopRing) end

function HopRing.setVisible(self: HopRing, on: boolean)
	self._visible = on
	self:_apply()
end

function HopRing.getDebugState(self: HopRing): { [string]: any }
	local visibleDashes = 0
	for i = 1, self._dashCount do
		if self._dashes[i].Transparency < 1 then
			visibleDashes += 1
		end
	end
	return {
		state = self._state,
		visible = self._visible,
		target = self._target and self._target:GetFullName(),
		semiAxes = { self._axes.X, self._axes.Y },
		dashes = self._dashCount,
		visibleDashes = visibleDashes,
		solid = (LOOKS[self._state] and LOOKS[self._state].duty or 0) >= 1,
		inWorld = self._folder.Parent ~= nil,
		parts = #self._folder:GetChildren(),
		stepping = self._step ~= nil,
		moves = self._moves,
		retargets = self._retargets,
		tighten = self._k,
		groundOffset = self._centreOffset.Position.Y,
		reducedMotion = Motion.reduced(),
	}
end

function HopRing.destroy(self: HopRing)
	self._trove:Destroy()
end

return HopRing
