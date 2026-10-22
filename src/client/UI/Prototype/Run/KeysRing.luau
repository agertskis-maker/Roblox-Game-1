--!strict
-- Keys progress ring for the run view (Lane 3 preview, worker H3). Display only: it shows
-- store.run.keys = { target, progress 0..1, status } exactly as supplied. Lane 1 decides
-- progress; the owning lane (Brian L) confirms a claim. This ring never decides a capture.
--
--   Holding    gold ring fills with progress, key icon, percentage, "HOLD ON" cue
--   Pending    progress as supplied (usually 100%) with "CONFIRMING..." - NOT ownership:
--              100% alone never shows a check or "got it"
--   Confirmed  the key turns into a check briefly, then the ring fades (the celebration itself
--              is CaptureCelebration, on the explicit "KeysConfirmed" event)
--   Lost       hides gently (short fade), nothing else
--   nil        hidden
--
-- Placement: lower third beside the landing band and the Heat panel, outside the reserved
-- LANDING VIEW (RunLayout: the middle 40% width x 45% height band), the Hop button and the
-- reserved touch zones; RunLayout.keysRect falls back to the right column when the lower third
-- is full (phones, tablet). getDebugState reports any leftover conflict.
--
-- Ring: an Arc (two half-masks with stepped UIGradients) over a navy track, cream centre.
--
--   local keys = KeysRing.new(ctx)
--   keys:layout(), keys:setVisible(on), keys:destroy(), keys:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arc = require(script.Parent.Arc)
local Gloss = require(script.Parent.Parent.Gloss)
local Icons = require(script.Parent.Parent.Icons)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

local RING = PreviewTokens.Size.KeysRing -- 64
local INNER = 44

local KeysRing = {}
KeysRing.__index = KeysRing

KeysRing.Cues = table.freeze({
	Holding = "HOLD ON",
	Pending = "CONFIRMING…",
	Confirmed = "",
	Lost = "",
})

function KeysRing.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, KeysRing)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._status = nil :: string?
	self._targetId = nil :: string?
	self._progress = 0
	self._shownProgress = 0
	self._lastQuarter = 0
	self._ticks = 0
	self._showing = false
	self._rect = nil :: RunLayout.Rect?
	self._conflict = nil :: string?
	self._hideToken = 0

	local root = self._trove:Add(RunLayout.canvas(ctx, "KeysRing"))
	self.root = root
	local group = make("CanvasGroup", {
		Name = "Keys",
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Size = UDim2.fromOffset(RunLayout.KeysSize.X, RunLayout.KeysSize.Y),
		Parent = root,
	})
	group.Active = false
	self._group = group

	local ring = make("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(RING, RING),
		BackgroundTransparency = 1,
		Parent = group,
	})
	self._ring = ring
	local track = make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING, RING),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = ring,
	})
	Gloss.corner(track, RING / 2)
	Gloss.stroke(track, 3, C.Ink)
	local arc = Arc.new(ring, RING, C.KeysLight, 0, 3)
	self._arc = arc
	local inner = make("Frame", {
		Name = "Centre",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(INNER, INNER),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = ring,
	})
	Gloss.corner(inner, INNER / 2)
	Gloss.stroke(inner, 2.5, C.Ink)
	local keyIcon = make("Frame", {
		Name = "KeyIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = inner,
	})
	Icons.draw(keyIcon, "Key", C.KeysDeep)
	local checkIcon = make("Frame", {
		Name = "CheckIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = inner,
	})
	Icons.draw(checkIcon, "Check", C.Success)
	self._keyIcon = keyIcon
	self._checkIcon = checkIcon

	local badge = make("Frame", {
		Name = "Percent",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.86, 0.86),
		Size = UDim2.fromOffset(44, 22),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = ring,
	})
	Gloss.corner(badge, 11)
	Gloss.stroke(badge, 2, C.KeysLight)
	self._percent = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Tokens.font(),
		Text = "0%",
		TextSize = Tokens.TextSize.Minimum,
		TextColor3 = C.White,
		ZIndex = 9,
		Parent = badge,
	})
	local cue = make("TextLabel", {
		Name = "Cue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		FontFace = Tokens.font(),
		Text = "",
		TextSize = Tokens.TextSize.Label,
		TextColor3 = C.KeysLight,
		ZIndex = 8,
		Parent = group,
	})
	Gloss.stroke(cue, 2.5, C.Ink, Enum.ApplyStrokeMode.Contextual)
	self._cue = cue

	local value = self._trove:Add(Instance.new("NumberValue"))
	self._value = value
	self._trove:Connect(value.Changed, function(v: number)
		self._shownProgress = v
		arc:set(v)
	end)
	self._trove:Add(function()
		Motion.cancelAll(value)
		Motion.cancelAll(group)
	end)

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(RunLayout.topChanged(ctx.screen), function()
		self:layout()
	end)
	self._trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced then
			Motion.cancelAll(value)
			value.Value = self._progress
		end
	end))
	self:layout()
	self:_apply()
	return self
end

export type KeysRing = typeof(KeysRing.new((nil :: any) :: RunLayout.Ctx))

function KeysRing._fadeTo(self: KeysRing, show: boolean)
	local group = self._group
	self._hideToken += 1
	local token = self._hideToken
	local reduced = Motion.reduced()
	if show then
		group.Visible = true
		if reduced then
			Motion.cancelAll(group)
			group.GroupTransparency = 0
		else
			Motion.tween(group, "fade", Motion.info(0.15), { GroupTransparency = 0 })
		end
		self._showing = true
		return
	end
	self._showing = false
	local t = Motion.tween(group, "fade", Motion.info(if reduced then 0.12 else 0.35), { GroupTransparency = 1 })
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and token == self._hideToken then
			group.Visible = false
		end
	end)
end

function KeysRing._setProgress(self: KeysRing, p: number, instant: boolean)
	self._progress = p
	self._percent.Text = string.format("%d%%", math.floor(p * 100 + 1e-6))
	if instant or Motion.reduced() then
		Motion.cancelAll(self._value)
		self._value.Value = p
		self._arc:set(p)
		self._shownProgress = p
	else
		Motion.tween(self._value, "progress", Motion.info(0.15, Enum.EasingStyle.Linear), { Value = p })
	end
end

function KeysRing._apply(self: KeysRing)
	local run = self._ctx.store:get().run
	local keys: Store.KeysState? = if run then run.keys else nil
	if not keys then
		if self._showing then
			self:_fadeTo(false)
		end
		self._status = nil
		self._targetId = nil
		return
	end
	local k = keys :: Store.KeysState
	local p = math.clamp(if k.progress ~= k.progress then 0 else k.progress, 0, 1)
	local newTarget = k.target.id ~= self._targetId
	local previous = self._status
	self._targetId = k.target.id
	self._status = k.status
	self._cue.Text = KeysRing.Cues[k.status] or ""
	if k.status == "Lost" then
		self:_setProgress(p, false)
		self:_fadeTo(false)
		return
	end
	if k.status == "Confirmed" then
		self:_setProgress(p, false)
		self._keyIcon.Visible = false
		self._checkIcon.Visible = true
		if previous ~= "Confirmed" then
			if not self._showing then
				self:_fadeTo(true)
			end
			local token = self._hideToken
			task.delay(if Motion.reduced() then 0.4 else 0.6, function()
				if token == self._hideToken and self._status == "Confirmed" then
					self:_fadeTo(false)
				end
			end)
		end
		return
	end
	-- Holding or Pending
	self._keyIcon.Visible = true
	self._checkIcon.Visible = false
	if newTarget or previous == "Lost" or previous == "Confirmed" or previous == nil then
		self._lastQuarter = math.floor(p * 4)
		self:_setProgress(p, true)
	else
		local quarter = math.floor(p * 4)
		if quarter > self._lastQuarter and k.status == "Holding" then
			self._ticks += 1
			Sounds.play("KeysTick")
		end
		self._lastQuarter = quarter
		self:_setProgress(p, false)
	end
	if not self._showing then
		self:_fadeTo(true)
	end
end

function KeysRing.layout(self: KeysRing)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect, conflict = RunLayout.keysRect(ctx)
	self._rect = rect
	self._conflict = conflict
	RunLayout.place(self._group, rect)
end

function KeysRing.setVisible(self: KeysRing, on: boolean)
	self._visible = on
	self.root.Visible = on
end

function KeysRing.getDebugState(self: KeysRing): { [string]: any }
	local rect = self._rect
	local band = RunLayout.landingBand(self._ctx)
	return {
		visible = self._visible,
		showing = self._showing,
		status = self._status,
		target = self._targetId,
		progress = self._progress,
		shownProgress = self._shownProgress,
		arc = self._arc:get(),
		percentText = self._percent.Text,
		cue = self._cue.Text,
		cueFits = self._cue.TextFits,
		checkShown = self._checkIcon.Visible,
		ownershipShown = self._checkIcon.Visible and self._status == "Confirmed",
		ticks = self._ticks,
		box = rect and RunLayout.describe(rect),
		landingView = RunLayout.describe(band),
		overlapsLandingView = rect ~= nil and RunLayout.overlaps(rect, band),
		conflict = self._conflict,
	}
end

function KeysRing.destroy(self: KeysRing)
	self._hideToken += 1
	self._trove:Destroy()
end

return KeysRing
