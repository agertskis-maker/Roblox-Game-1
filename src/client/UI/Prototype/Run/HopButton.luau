--!strict
-- Hop control for the run view (Lane 3 preview, worker H3). Presentation only: it shows the
-- supplied store.run.hop state and store.run.hopCooldown01, and pressing it only calls the
-- preview intent callback. It never hops, picks a target or judges a landing (Lane 1, Brian R).
--
-- Phones and tablets (profile.touch): a large reachable 96 design px round button at the bottom
-- right, beside (left of) the Roblox Jump zone, else above it (RunLayout.hopRect), never
-- overlapping a reserved zone (checked again with ctx.screen:overlapsReserved in device px), the
-- landing view or the Heat panel.
--   Available    teal glossy button, Hop icon, "HOP"
--   Unavailable  grey (Gloss disabled) + a lock badge, dimmed; not pressable
--   Timing       a pulsing white ring around it (static ring in reduced motion)
--   cooldown     a navy radial wipe over the button shrinking from hopCooldown01 to 0 (Arc)
-- Desktop: a small "SPACE: HOP" key hint instead (bottom right), with the same lock / ring cues.
-- The placement must be agreed with Brian R (proposed, not agreed).
--
--   local hop = HopButton.new(ctx)
--   hop:setHopIntent(fn)    -- preview: called on press; no gameplay
--   hop:layout(), hop:setVisible(on), hop:destroy(), hop:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arc = require(script.Parent.Arc)
local Gloss = require(script.Parent.Parent.Gloss)
local Icons = require(script.Parent.Parent.Icons)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.RunLayout)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

local SIZE = PreviewTokens.Size.HopButton -- 96

local HopButton = {}
HopButton.__index = HopButton

function HopButton.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, HopButton)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._state = "Unavailable" :: string
	self._cooldown = 0
	self._intents = 0
	self._onIntent = nil :: (() -> ())?
	self._rect = nil :: RunLayout.Rect?
	self._conflict = nil :: string?
	self._reservedHit = nil :: string?

	local root = self._trove:Add(RunLayout.canvas(ctx, "HopButton"))
	self.root = root

	-- Touch button
	local button = Gloss.button(root, {
		name = "Hop",
		size = Vector2.new(SIZE, SIZE),
		light = C.HopLight,
		deep = C.HopDeep,
		radius = SIZE / 2,
		text = "HOP",
		textSize = Tokens.TextSize.Value,
		icon = function(holder: Frame)
			Icons.draw(holder, "Hop", C.White)
		end,
		iconSize = 40,
		sound = "Hop",
		cooldown = 0.25,
		onActivate = function()
			self:_intent()
		end,
	})
	self._trove:Add(button.trove)
	self._button = button
	local sweep = Arc.new(button.body, SIZE, C.Ink, 0.45, 4)
	self._sweep = sweep
	local lock = make("Frame", {
		Name = "LockBadge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.86, 0.14),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		ZIndex = 9,
		Visible = false,
		Parent = button.body,
	})
	Gloss.corner(lock, 16)
	Gloss.stroke(lock, 2, C.White)
	local lockIcon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = lock,
	})
	Icons.draw(lockIcon, "Lock", C.White)
	self._lock = lock
	local ring = make("Frame", {
		Name = "TimingRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIZE + 18, SIZE + 18),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = button.root,
	})
	Gloss.corner(ring, (SIZE + 18) / 2)
	local ringStroke = Gloss.stroke(ring, 4, C.White)
	local ringScale = make("UIScale", { Name = "Pulse", Scale = 1, Parent = ring })
	self._ring = ring
	self._ringStroke = ringStroke
	self._ringScale = ringScale

	-- Desktop key hint
	local hint = make("Frame", {
		Name = "KeyHint",
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(RunLayout.HintSize.X, RunLayout.HintSize.Y),
		Visible = false,
		Parent = root,
	})
	Gloss.corner(hint, 12)
	local hintStroke = Gloss.stroke(hint, 2.5, C.HopLight)
	local hintText = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Tokens.font(),
		Text = "SPACE: HOP",
		TextSize = Tokens.TextSize.Label,
		TextColor3 = C.White,
		ZIndex = 2,
		Parent = hint,
	})
	local hintLock = make("Frame", {
		Name = "Lock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		ZIndex = 4,
		Visible = false,
		Parent = hint,
	})
	Gloss.corner(hintLock, 12)
	Gloss.stroke(hintLock, 2, C.White)
	local hintLockIcon = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = hintLock,
	})
	Icons.draw(hintLockIcon, "Lock", C.White)
	self._hint = hint
	self._hintStroke = hintStroke
	self._hintText = hintText
	self._hintLock = hintLock

	self._trove:Add(function()
		Motion.cancelAll(ringScale)
		Motion.cancelAll(ringStroke)
	end)
	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(RunLayout.topChanged(ctx.screen), function()
		self:layout()
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_applyRing()
	end))
	self:layout()
	self:_apply()
	return self
end

export type HopButton = typeof(HopButton.new((nil :: any) :: RunLayout.Ctx))

function HopButton._intent(self: HopButton)
	if self._state == "Unavailable" then
		return
	end
	self._intents += 1
	local fn = self._onIntent
	if fn then
		fn()
	end
end

function HopButton._applyRing(self: HopButton)
	local timing = self._state == "Timing"
	local ring, scale, stroke = self._ring, self._ringScale, self._ringStroke
	Motion.cancelAll(scale)
	Motion.cancelAll(stroke)
	ring.Visible = timing
	scale.Scale = 1
	stroke.Transparency = 0
	if timing and not Motion.reduced() and self._visible then
		-- a gentle pulse (about 1.1 per second, well under the 2.5 flashes per second ceiling)
		local info = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, true)
		Motion.tween(scale, "pulse", info, { Scale = 1.1 })
		Motion.tween(stroke, "pulse", info, { Transparency = 0.5 })
	end
	self._hintStroke.Thickness = if timing then 4 else 2.5
	self._hintStroke.Color = if timing then C.White else C.HopLight
end

function HopButton._apply(self: HopButton)
	local run = self._ctx.store:get().run
	local state = if run then run.hop else "Unavailable"
	local cooldown = if run then math.clamp(run.hopCooldown01, 0, 1) else 0
	self._cooldown = cooldown
	self._sweep:set(cooldown)
	local changed = state ~= self._state
	self._state = state
	local available = state ~= "Unavailable"
	self._button.setEnabled(available)
	self._lock.Visible = not available
	self._button.body.BackgroundTransparency = if available then 0 else 0.25
	self._hintLock.Visible = not available
	self._hintText.TextTransparency = if available then 0 else 0.4
	if changed then
		self:_applyRing()
	end
end

function HopButton.layout(self: HopButton)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local touch = ctx.screen:profile().touch
	self._button.root.Visible = touch
	self._hint.Visible = not touch
	if touch then
		local rect, conflict = RunLayout.hopRect(ctx)
		self._rect = rect
		self._conflict = conflict
		self._button.root.AnchorPoint = Vector2.zero
		self._button.root.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
		local pos, size = RunLayout.toDevice(ctx, rect)
		self._reservedHit = ctx.screen:overlapsReserved(pos, size)
	else
		local rect = RunLayout.hintRect(ctx)
		self._rect = rect
		self._conflict = nil
		self._reservedHit = nil
		self._hint.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
	end
	self:_applyRing()
end

function HopButton.setHopIntent(self: HopButton, fn: (() -> ())?)
	self._onIntent = fn
end

function HopButton.setVisible(self: HopButton, on: boolean)
	self._visible = on
	self.root.Visible = on
	self:_applyRing()
end

function HopButton.getDebugState(self: HopButton): { [string]: any }
	local rect = self._rect
	return {
		visible = self._visible,
		touch = self._ctx.screen:profile().touch,
		state = self._state,
		cooldown01 = self._cooldown,
		sweep = self._sweep:get(),
		lockShown = self._lock.Visible or self._hintLock.Visible,
		ringShown = self._ring.Visible,
		ringPulsing = self._ring.Visible and not Motion.reduced(),
		intents = self._intents,
		buttonSize = self._button.body.Size.X.Offset,
		box = rect and RunLayout.describe(rect),
		conflict = self._conflict,
		overlapsReserved = self._reservedHit,
		hintText = self._hintText.Text,
	}
end

function HopButton.destroy(self: HopButton)
	self._trove:Destroy()
end

return HopButton
