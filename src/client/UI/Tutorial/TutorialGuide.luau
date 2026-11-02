--!strict
-- TutorialGuide: the pointing visuals of the tutorial (BRIEF M11-03, M11-04, M11-05). One guide per tutorial session.
--
--   GROUND (a world target): a bouncing arrow (the icon family's "ArrowDown" on a BillboardGui floating above the target)
--     and a soft glow disc on the ground at the target's door or portal. The white chevron trail is TutorialRoute, driven
--     by the controller, not here.
--   UI (a GuiObject target): the pointing hand (ShopKit.hand) that TAPS toward the exact button and never presses it, a
--     pulsing ring round the button (ShopKit.pulseRing) and, when asked, a light dim with a cutout round the button. The dim
--     is NON-modal: it is made of plain Frames that are not Active, so it never swallows a tap, a drag or a walk. The hand
--     loops its tap every 1.8 seconds.
--   PULSE (the one timed hint, 8 s): the arrow grows and pulses once and stays a little larger; the UI ring grows. Reduced
--     motion: no bounce, no loop, no pulse tween; the arrow simply becomes larger and the hand holds still.
--
-- WHERE THE UI VISUALS LIVE: a ScreenGui of their own, "Lane3TutorialOverlay" (DisplayOrder 100, no inset, not reset on
-- spawn), so the hand is above every other panel, including another script's (the Raceway card is DisplayOrder 18, Brian R's
-- results card 5). Positions are viewport pixels: a target's rectangle is its AbsolutePosition plus the GUI inset when its
-- own ScreenGui respects the inset (AbsolutePosition does not include it; RunLayout.worldToCanvas found the same), so a
-- target in any ScreenGui lines up. Sizes are design px times the HUD scale times the device-frame fit. If the engine
-- reports AbsolutePosition differently, only a target in a ScreenGui with another inset setting would be off, by the inset.
--
-- Everything is owned by Troves; clear() removes every instance and stops every loop, so nothing is left behind after a step.
-- One Heartbeat connection (30 Hz) drives the bounce, the glow, the dim and the hand, and exists only while something moves.
--
-- API: Guide.new(ctx) -> Guide
--   :setGround(position: Vector3?, options?: { radius: number?, height: number? })   glow disc radius and arrow height, studs
--   :setUi(resolve: (() -> GuiObject?)?, options?: { mask: boolean? })
--   :pulse()  :clear()  :layout()  :getTopLayer() -> Frame  :destroy()  :getDebugState()

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(script.Parent.Parent.Prototype.Arcade)
local IconArt = require(script.Parent.Parent.Prototype.Home.IconArt)
local Motion = require(script.Parent.Parent.Prototype.Motion)
local ShopKit = require(script.Parent.Parent.Prototype.ShopKit)
local Targets = require(script.Parent.TutorialTargets)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Guide = {}
Guide.__index = Guide

local ARROW_HEIGHT = 9 -- studs above the target position (a target can ask for more)
local ARROW_SIZE = 7 -- studs
local BOUNCE_STUDS = 1.2
local BOUNCE_HZ = 1.1
local RING_RADIUS = 9 -- studs
local GOLD = Color3.fromRGB(255, 226, 84)
local HAND_SIZE = 60 -- design px
local TAP_SECONDS = 1.8
local TAP_NEAR = 4
local TAP_FAR = 30
local TICK = 1 / 30
local RESOLVE_EVERY = 0.25
local DIM = 0.62 -- the cutout dim's transparency (a light dim)
local OVERLAY_ORDER = 100

export type Guide = {
	setGround: (self: Guide, position: Vector3?, options: { radius: number?, height: number? }?) -> (),
	setUi: (self: Guide, resolve: (() -> GuiObject?)?, options: { mask: boolean? }?) -> (),
	pulse: (self: Guide) -> (),
	getTopLayer: (self: Guide) -> Frame,
	clear: (self: Guide) -> (),
	layout: (self: Guide) -> (),
	destroy: (self: Guide) -> (),
	getDebugState: (self: Guide) -> { [string]: any },
}

local function ease(t: number): number
	return 1 - (1 - t) * (1 - t)
end

-- A GuiObject's top-left in viewport pixels (see the header: AbsolutePosition plus the inset when its ScreenGui respects it).
local function viewportPos(gui: GuiObject): Vector2
	local sg = gui:FindFirstAncestorWhichIsA("ScreenGui")
	if sg and not sg.IgnoreGuiInset and sg.ScreenInsets ~= Enum.ScreenInsets.None then
		return gui.AbsolutePosition + GuiService:GetGuiInset()
	end
	return gui.AbsolutePosition
end

function Guide.new(ctx: any): Guide
	local self = setmetatable({}, Guide) :: any
	self._trove = Trove.new()
	self._ctx = ctx
	self._ground = self._trove:Extend()
	self._ui = self._trove:Extend()
	self._loop = nil :: RBXScriptConnection?
	self._pulses = 0
	self._groundPos = nil :: Vector3?
	self._groundParts = nil :: { [string]: any }?
	self._resolve = nil :: (() -> GuiObject?)?
	self._wantMask = false
	self._target = nil :: GuiObject?
	self._uiParts = nil :: { [string]: any }?
	self._elapsed = 0
	self._resolveAcc = 0
	self._grow = 1
	self._destroyed = false
	self._gui = nil :: ScreenGui?

	-- the overlay: its own ScreenGui above everything, in viewport pixels
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local top = Instance.new("Frame")
	top.Name = "TutorialTop"
	top.BackgroundTransparency = 1
	top.Size = UDim2.fromScale(1, 1)
	top.Active = false
	if playerGui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "Lane3TutorialOverlay"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
		gui.DisplayOrder = OVERLAY_ORDER
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui
		self._trove:Add(gui)
		self._gui = gui
		top.Parent = gui
	else
		top.ZIndex = 80
		top.Parent = ctx.layer
		self._trove:Add(top)
	end
	self._top = top
	self._trove:Add(Motion.onReducedChanged(function()
		self:_refreshLoop()
		self:_applyGrow()
	end))
	return self :: Guide
end

-- the size of one design px in viewport pixels
function Guide._pxScale(self: any): number
	return self._ctx.screen:uiScale() * self._ctx.screen:fitScale()
end

-- GROUND -----------------------------------------------------------------------------------------------------------

local function anchorPart(world: Instance, position: Vector3): Part
	local p = Instance.new("Part")
	p.Name = "TutorialArrowAnchor"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = position
	p.Parent = world
	return p
end

local function disc(world: Instance, name: string, radius: number, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Transparency = transparency
	p.Size = Vector3.new(0.25, radius * 2, radius * 2) -- a cylinder's axis is X: lay it flat
	p.Parent = world
	return p
end

function Guide.setGround(self: any, position: Vector3?, options: { radius: number?, height: number? }?)
	self._ground:Clean()
	self._groundParts = nil
	self._groundPos = position
	if not position or self._destroyed then
		self:_refreshLoop()
		return
	end
	local world: Instance = self._ctx.world
	local radius = (options and options.radius) or RING_RADIUS
	local height = (options and options.height) or ARROW_HEIGHT
	local trove = self._ground
	local base = Vector3.new(position.X, position.Y, position.Z)

	local anchor = trove:Add(anchorPart(world, base + Vector3.new(0, height, 0)))
	local gui = Instance.new("BillboardGui")
	gui.Name = "TutorialArrow"
	gui.Adornee = anchor
	gui.Size = UDim2.fromScale(ARROW_SIZE, ARROW_SIZE)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 900
	gui.ResetOnSpawn = false
	gui.Active = false
	gui.Parent = anchor
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local grow = Instance.new("UIScale")
	grow.Name = "Grow"
	grow.Parent = holder
	IconArt.draw(holder, { "ArrowDown", "Flag" })

	local outer = trove:Add(disc(world, "TutorialGlowOuter", radius, 0.72))
	local inner = trove:Add(disc(world, "TutorialGlowInner", radius * 0.62, 0.6))
	outer.CFrame = CFrame.new(base.X, base.Y + 0.3, base.Z) * CFrame.Angles(0, 0, math.pi / 2)
	inner.CFrame = CFrame.new(base.X, base.Y + 0.32, base.Z) * CFrame.Angles(0, 0, math.pi / 2)
	trove:Add(function()
		Motion.cancelAll(grow)
	end)
	self._groundParts = { anchor = anchor, grow = grow, outer = outer, inner = inner, base = base, height = height }
	self:_applyGrow()
	self:_refreshLoop()
end

function Guide._applyGrow(self: any)
	local parts = self._groundParts
	if not parts then
		return
	end
	local grow: UIScale = parts.grow
	Motion.cancelAll(grow)
	grow.Scale = self._grow
end

-- UI ---------------------------------------------------------------------------------------------------------------

-- The light dim with one cutout: four plain Frames (not Active) and a white outline on the hole.
local function buildDim(parent: Frame, trove: any): { [string]: Frame }
	local frames: { [string]: Frame } = {}
	for _, name in { "Top", "Bottom", "Left", "Right" } do
		frames[name] = trove:Add(Arcade.make("Frame", {
			Name = "Dim" .. name,
			BackgroundColor3 = Color3.fromRGB(14, 20, 38),
			BackgroundTransparency = DIM,
			BorderSizePixel = 0,
			Active = false,
			ZIndex = 81,
			Parent = parent,
		}))
	end
	local hole = trove:Add(Arcade.make("Frame", {
		Name = "DimHole",
		BackgroundTransparency = 1,
		ZIndex = 82,
		Parent = parent,
	}))
	Arcade.corner(hole, 10)
	Arcade.outline(hole, 3, Color3.new(1, 1, 1))
	frames.Hole = hole
	return frames
end

local function placeDim(
	frames: { [string]: Frame },
	x: number,
	y: number,
	w: number,
	h: number,
	pad: number,
	total: Vector2
)
	local x0, y0 = math.max(x - pad, 0), math.max(y - pad, 0)
	local x1, y1 = math.min(x + w + pad, total.X), math.min(y + h + pad, total.Y)
	frames.Top.Position, frames.Top.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(total.X, y0)
	frames.Bottom.Position, frames.Bottom.Size = UDim2.fromOffset(0, y1), UDim2.fromOffset(total.X, total.Y - y1)
	frames.Left.Position, frames.Left.Size = UDim2.fromOffset(0, y0), UDim2.fromOffset(x0, y1 - y0)
	frames.Right.Position, frames.Right.Size = UDim2.fromOffset(x1, y0), UDim2.fromOffset(total.X - x1, y1 - y0)
	frames.Hole.Position, frames.Hole.Size = UDim2.fromOffset(x0, y0), UDim2.fromOffset(x1 - x0, y1 - y0)
end

function Guide._buildUi(self: any, target: GuiObject)
	local trove = self._ui:Extend()
	local top: Frame = self._top
	local px = self:_pxScale()
	local box = trove:Add(Arcade.make("Frame", {
		Name = "TutorialTargetBox",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 83,
		Parent = top,
	}))
	local ring = ShopKit.pulseRing(box, { padding = 6, radius = 12, z = 84, trove = trove })
	ring.setActive(true)
	local dim: { [string]: Frame }? = nil
	if self._wantMask then
		dim = buildDim(top, trove)
	end
	local hand = ShopKit.hand(top, { size = HAND_SIZE * px, direction = "Up", z = 90, trove = trove })
	self._uiParts = { trove = trove, box = box, ring = ring, dim = dim, hand = hand, dir = "Up" }
	self._target = target
end

function Guide._clearUi(self: any)
	self._ui:Clean()
	self._uiParts = nil
	self._target = nil
end

function Guide.setUi(self: any, resolve: (() -> GuiObject?)?, options: { mask: boolean? }?)
	self:_clearUi()
	self._resolve = resolve
	self._wantMask = options ~= nil and options.mask == true
	self._resolveAcc = RESOLVE_EVERY -- look straight away
	self:_refreshLoop()
end

-- Places the target box, the dim and the hand for this frame. `now` is seconds into the tap loop.
function Guide._placeUi(self: any, now: number)
	local parts = self._uiParts
	local target: GuiObject? = self._target
	if not parts or not target then
		return
	end
	local top: Frame = self._top
	local rel = viewportPos(target) - top.AbsolutePosition
	local size = target.AbsoluteSize
	local total = top.AbsoluteSize
	local box: Frame = parts.box
	box.Position = UDim2.fromOffset(rel.X + size.X / 2, rel.Y + size.Y / 2)
	box.Size = UDim2.fromOffset(size.X, size.Y)
	local px = self:_pxScale()
	if parts.dim then
		placeDim(parts.dim, rel.X, rel.Y, size.X, size.Y, 8 * px, total)
	end

	local handPx = HAND_SIZE * px
	-- the hand sits below the target pointing up, or above it pointing down when there is no room under it
	local below = rel.Y + size.Y + handPx * 0.9 < total.Y
	local dir = if below then "Up" else "Down"
	local hand: ShopKit.Hand = parts.hand
	if parts.dir ~= dir then
		parts.dir = dir
		hand.setDirection(dir :: any)
	end
	-- tap loop: lean in, press, lean out
	local reduced = Motion.reduced()
	local p = (now % TAP_SECONDS) / TAP_SECONDS
	local offset = TAP_NEAR + 6
	local pressed = false
	if not reduced then
		if p < 0.35 then
			offset = TAP_FAR + (TAP_NEAR - TAP_FAR) * ease(p / 0.35)
		elseif p < 0.5 then
			offset = TAP_NEAR
			pressed = true
		elseif p < 0.65 then
			offset = TAP_NEAR + (TAP_FAR - TAP_NEAR) * ((p - 0.5) / 0.15)
		else
			offset = TAP_FAR
		end
	end
	local cx = rel.X + size.X / 2
	local gap = handPx / 2 + offset * px
	local cy = if below then rel.Y + size.Y + gap else rel.Y - gap
	hand.root.Position = UDim2.fromOffset(cx, cy)
	local bob = hand.root:FindFirstChild("Bob") :: Frame?
	if bob then
		local s = if pressed then 0.9 else 1
		bob.Size = UDim2.fromOffset(handPx * s, handPx * s)
	end
end

-- LOOP -------------------------------------------------------------------------------------------------------------

function Guide._refreshLoop(self: any)
	local need = not self._destroyed and (self._groundParts ~= nil or self._resolve ~= nil)
	if need and not self._loop then
		local acc = 0
		self._loop = self._trove:Add(RunService.Heartbeat:Connect(function(dt: number)
			acc += dt
			self._resolveAcc += dt
			if acc < TICK then
				return
			end
			self._elapsed += acc
			acc = 0
			self:_tick()
		end))
	elseif not need and self._loop then
		self._trove:Remove(self._loop)
		self._loop = nil
	end
end

function Guide._tick(self: any)
	local now: number = self._elapsed
	local reduced = Motion.reduced()
	local parts = self._groundParts
	if parts then
		local base: Vector3 = parts.base
		local bounce = if reduced then 0 else math.sin(now * 2 * math.pi * BOUNCE_HZ) * BOUNCE_STUDS
		local anchor: Part = parts.anchor
		anchor.Position = base + Vector3.new(0, (parts.height :: number) + bounce, 0)
		if not reduced then
			local k = 0.5 + 0.5 * math.sin(now * 2 * math.pi * 0.8)
			local outer: Part = parts.outer
			local inner: Part = parts.inner
			outer.Transparency = 0.84 - 0.2 * k
			inner.Transparency = 0.72 - 0.2 * k
		end
	end
	-- the UI target: look for it a few times a second (a panel may open or close at any moment)
	if self._resolve then
		if self._resolveAcc >= RESOLVE_EVERY then
			self._resolveAcc = 0
			local ok, found = pcall(self._resolve :: any)
			local target: GuiObject? = if ok and found and Targets.isShown(found) then found else nil
			if target ~= self._target then
				self:_clearUi()
				if target then
					self:_buildUi(target)
				end
			end
		end
		if self._uiParts and self._target then
			if Targets.isShown(self._target) then
				self:_placeUi(now)
			else
				self:_clearUi()
			end
		end
	end
end

-- THE ONE HINT -----------------------------------------------------------------------------------------------------

-- The arrow grows and pulses once (and stays a little larger); the UI ring grows. Reduced motion: only larger.
function Guide.pulse(self: any)
	self._pulses += 1
	self._grow = 1.3
	local parts = self._groundParts
	if parts then
		local grow: UIScale = parts.grow
		Motion.cancelAll(grow)
		if Motion.reduced() then
			grow.Scale = self._grow
		else
			grow.Scale = 1
			local up = Motion.tween(grow, "pulse", Motion.info(0.22, Enum.EasingStyle.Back), { Scale = 1.7 })
			up.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not self._destroyed then
					Motion.tween(grow, "pulse", Motion.info(0.3), { Scale = self._grow })
				end
			end)
		end
	end
	local ui = self._uiParts
	if ui then
		local box: Frame = ui.box
		local scale = box:FindFirstChild("PulseGrow") :: UIScale?
		if not scale then
			local created = Instance.new("UIScale")
			created.Name = "PulseGrow"
			created.Parent = box
			scale = created
		end
		local s = scale :: UIScale
		Motion.cancelAll(s)
		if Motion.reduced() then
			s.Scale = 1.12
		else
			s.Scale = 1
			local up = Motion.tween(s, "pulse", Motion.info(0.22, Enum.EasingStyle.Back), { Scale = 1.25 })
			up.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not self._destroyed then
					Motion.tween(s, "pulse", Motion.info(0.3), { Scale = 1.1 })
				end
			end)
		end
	end
end

function Guide.getTopLayer(self: any): Frame
	return self._top
end

function Guide.clear(self: any)
	self._ground:Clean()
	self._groundParts = nil
	self._groundPos = nil
	self._resolve = nil
	self._wantMask = false
	self._grow = 1
	self:_clearUi()
	self:_refreshLoop()
end

function Guide.layout(self: any)
	-- a rebuilt hand picks up the new scale; the next tick places everything again from the live rectangles
	if self._uiParts and self._target then
		local target: GuiObject = self._target
		self:_clearUi()
		self:_buildUi(target)
	end
end

function Guide.getDebugState(self: any): { [string]: any }
	local parts = self._groundParts
	local ui = self._uiParts
	local top: Frame = self._top
	local gui: ScreenGui? = self._gui
	return {
		groundVisible = parts ~= nil,
		groundPosition = self._groundPos,
		arrowScale = if parts then (parts.grow :: UIScale).Scale else nil,
		uiTarget = if self._target then self._target:GetFullName() else nil,
		handVisible = ui ~= nil,
		handDirection = if ui then ui.dir else nil,
		maskOn = ui ~= nil and ui.dim ~= nil,
		pulses = self._pulses,
		looping = self._loop ~= nil,
		overlayChildren = #top:GetChildren(),
		overlayDisplayOrder = if gui then gui.DisplayOrder else nil,
		reduced = Motion.reduced(),
	}
end

function Guide.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._loop = nil
	self._trove:Destroy()
end

return Guide
