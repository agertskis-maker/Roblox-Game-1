--!strict
-- Warn, eject, explain (Lane 3 preview, HUD rebuild worker HR; E-01, E-04, E-05 run side).
-- Driven ONLY by explicit inputs, never inferred from a tint or a Heat percentage:
--   WARNING   store.run.warning = { id, reason } or an event { kind = "RunWarning", reason }:
--             one "!" (Icons2 "Warning") and a short reason chip ("TOO HOT!") near the rider,
--             just above the protected road region at the rider's x. Safety level: while it is
--             up, the "Upper" slot is suppressed below Safety (no district banner, no milestone)
--             and the capture ribbon holds back. One entry pop, no strobe; Sounds "Warning" once
--             per warning id (the hook is throttled inside Sounds too).
--   EJECT     { kind = "Dismounted", reason }: the warning chip clears; Sounds "Bonk" once; if
--             the reason maps to a failure the heading shows at once (HW owns the tumble proxy).
--   END       { kind = "RunEnded", reason }: the heading (if not already up), then the hand-off
--             to Results: options.onFinished(reasonCode) and the Finished signal fire ONCE per run
--             after the heading's hold (~1.6 s). The lead's playground switches the mode.
-- Heading: large but brief, from a REASON MAP with a truthful fallback:
--   Overheated / Meltdown / MeltdownExpired / TooHot -> "OVERHEATED!" + "Heat full"
--   Crashed -> "CRASHED!" + "The car crashed";  MissedHop -> "MISSED THE HOP!" + "You landed on
--   the road";  FellOff -> "FELL OFF!" + "You fell off the road";  anything else -> "RUN OVER"
--   with no explanatory line (never a guessed cause). An instant failure (no prior warning) is
--   explained immediately, the same way.
-- Arbitration: requests "Center" at "Safety"; suppresses "Upper" and "Side" below Safety from the
-- heading until the mode leaves Run, so capture fanfare, warning, district banner and Results
-- never stack. Claimed cars stay visible (the ClaimTray is not hidden); a capture confirmed at
-- run end is kept for Results by CaptureRibbon (pendingCards).
-- Reduced motion: fades only (no scale-in), steady colours.
--
--   local runEnd = RunEnd.new(ctx, { onFinished = fn(reasonCode)?, anchor = rideModel? })
--   runEnd.Finished:Connect(fn(reasonCode))
--   runEnd:setAnchor(instance?), runEnd:layout(), runEnd:setVisible(on), runEnd:destroy(),
--   runEnd:getDebugState()
--   RunEnd.headingFor(reason) -> (title, line?)   RunEnd.warningFor(reason) -> text?   (pure)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local HOLD = 1.6
local EVENT_WARNING_SECONDS = 4 -- an event-only warning (no state) clears itself after this
local OWNER = "RunEnd"

local HEADINGS: { [string]: { title: string, line: string? } } = {
	Overheated = { title = "OVERHEATED!", line = "Heat full" },
	Meltdown = { title = "OVERHEATED!", line = "Heat full" },
	MeltdownExpired = { title = "OVERHEATED!", line = "Heat full" },
	TooHot = { title = "OVERHEATED!", line = "Heat full" },
	Crashed = { title = "CRASHED!", line = "The car crashed" },
	MissedHop = { title = "MISSED THE HOP!", line = "You landed on the road" },
	FellOff = { title = "FELL OFF!", line = "You fell off the road" },
}
local FALLBACK = { title = "RUN OVER", line = nil :: string? }

local WARNINGS: { [string]: string } = {
	TooHot = "TOO HOT!",
	Critical = "TOO HOT!",
	Meltdown = "LOSING CONTROL!",
	LosingControl = "LOSING CONTROL!",
}

local RunEnd = {}
RunEnd.__index = RunEnd

function RunEnd.headingFor(reason: string?): (string, string?)
	local h = reason and HEADINGS[reason]
	if h then
		return h.title, h.line
	end
	return FALLBACK.title, FALLBACK.line
end

function RunEnd.isMapped(reason: string?): boolean
	return reason ~= nil and HEADINGS[reason] ~= nil
end

function RunEnd.warningFor(reason: string?): string?
	if not reason then
		return nil
	end
	local w = WARNINGS[reason]
	if w then
		return w
	end
	if string.find(reason, " ", 1, true) then
		return string.upper(reason) -- a supplied sentence is shown as given
	end
	return nil -- unknown code: the "!" alone, never an invented reason
end

export type Options = { onFinished: ((string?) -> ())?, anchor: Instance? }

function RunEnd.new(ctx: RunLayout.Ctx, options: Options?)
	local self = setmetatable({}, RunEnd)
	local opts: Options = options or {}
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._onFinished = opts.onFinished
	self._anchor = opts.anchor
	self.Finished = self._trove:Add(Signal.new())
	self._warningId = nil :: string?
	self._warningSource = nil :: string? -- "State" | "Event"
	self._warningsShown = 0
	self._headingReason = nil :: string?
	self._headingShown = false
	self._headingAt = 0
	self._ended = false
	self._endReason = nil :: string?
	self._finished = false
	self._handle = nil :: any
	self._follow = nil :: RBXScriptConnection?
	self._token = 0
	self._bonks = 0
	self._bonked = false

	local root = self._trove:Add(RunLayout.canvas(ctx, "RunEnd"))
	self.root = root

	-- warning chip: "!" + reason
	local chip = make("CanvasGroup", {
		Name = "Warning",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Size = UDim2.fromOffset(200, 44),
		ZIndex = 5,
		Parent = root,
	})
	RunKit.nonInteractive(chip)
	local chipInner = make("Frame", {
		Name = "Inner",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = chip,
	})
	make("UIScale", { Name = "Pop", Parent = chipInner })
	local band = make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.new(1, -24, 0, 34),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.05,
		ZIndex = 5,
		Parent = chipInner,
	})
	Arcade.corner(band, A.Button.Radius)
	Arcade.outline(band, "Button", A.Badge)
	local bang = make("Frame", {
		Name = "Bang",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = chipInner,
	})
	Arcade.icon(bang, "Warning")
	local reason = Arcade.text(band, { text = "", role = "Label", name = "Reason", size = 20, z = 8 })
	reason.Position = UDim2.fromOffset(22, 0)
	reason.Size = UDim2.new(1, -26, 1, 0)
	reason.TextXAlignment = Enum.TextXAlignment.Left
	self._chip, self._chipInner, self._chipBand, self._chipReason = chip, chipInner, band, reason

	-- heading (Center, Safety)
	local heading = make("CanvasGroup", {
		Name = "Heading",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = root,
	})
	RunKit.nonInteractive(heading)
	local hInner = make("Frame", {
		Name = "Inner",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = heading,
	})
	make("UIScale", { Name = "Pop", Parent = hInner })
	local hBand = make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(1, 0.62),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Rotation = -3,
		ZIndex = 10,
		Parent = hInner,
	})
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.18, 0),
			NumberSequenceKeypoint.new(0.82, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = hBand,
	})
	local title = Arcade.text(hInner, {
		text = "",
		role = "Display",
		name = "Title",
		size = 56,
		face = "Danger",
		italic = false,
		z = 12,
	})
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.38)
	title.Rotation = -3
	local line = Arcade.text(hInner, { text = "", role = "Label", name = "Line", size = 24, z = 12 })
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.fromScale(0.5, 0.72)
	self._heading, self._headingInner, self._title, self._line = heading, hInner, title, line

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_applyWarningState()
	end))
	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		self:_onEvent(event)
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string, from: string?)
		if mode == "Run" and from ~= "Run" then
			self:_resetRun()
		elseif mode ~= "Run" then
			self:_clearWarning(true)
			self:_hideHeading(true)
			self:_unsuppressAll()
		end
	end)
	self._trove:Add(function()
		self._token += 1
		self:_stopFollow()
		Motion.cancelAll(chip)
		Motion.cancelAll(heading)
		self:_unsuppressAll()
		if self._handle then
			RunBus.priority(ctx):release(self._handle)
			self._handle = nil
		end
		RunBus.unregister(ctx, "runEnd", self)
	end)
	RunBus.register(ctx, "runEnd", self)
	self:layout()
	return self
end

export type RunEnd = typeof(RunEnd.new((nil :: any) :: RunLayout.Ctx))

function RunEnd._unsuppressAll(self: RunEnd)
	local ctx = self._ctx
	RunBus.unsuppress(ctx, "Upper", "warning")
	RunBus.unsuppress(ctx, "Upper", OWNER)
	RunBus.unsuppress(ctx, "Side", OWNER)
	local flags = RunBus.flags(ctx)
	flags.warning = false
	flags.ended = false
end

function RunEnd._resetRun(self: RunEnd)
	self._token += 1
	self._bonked = false
	self._ended = false
	self._endReason = nil
	self._finished = false
	self._headingReason = nil
	self._headingShown = false
	self:_clearWarning(true)
	self:_hideHeading(true)
	self:_unsuppressAll()
end

----------------------------------------------------------------------------------------------
-- Warning

function RunEnd._applyWarningState(self: RunEnd)
	local run = self._ctx.store:get().run
	local w: Store.Warning? = if run then run.warning else nil
	if w then
		local warning = w :: Store.Warning
		if warning.id ~= self._warningId then
			self:_showWarning(warning.id, warning.reason, "State")
		end
	elseif self._warningSource == "State" then
		self:_clearWarning(false)
	end
end

function RunEnd._showWarning(self: RunEnd, id: string, reason: string?, source: string)
	if self._ended or self._headingShown or self._ctx.store:get().mode ~= "Run" then
		return
	end
	local first = self._warningId == nil
	self._warningId = id
	self._warningSource = source
	self._warningsShown += 1
	local text = RunEnd.warningFor(reason)
	self._chipReason.Text = text or ""
	self._chipBand.Visible = text ~= nil
	self:layout()
	local ctx = self._ctx
	RunBus.flags(ctx).warning = true
	RunBus.suppress(ctx, "Upper", "Safety", "warning")
	Sounds.play("Warning")
	local chip = self._chip
	chip.Visible = self._visible
	local reduced = Motion.reduced()
	Motion.tween(chip, "fade", Motion.info(if reduced then 0.12 else 0.15), { GroupTransparency = 0 })
	if first and not reduced then
		Motion.pop(self._chipInner, 1.12) -- one entry pop; no strobe, no repeat
	end
	self:_startFollow()
	if source == "Event" then
		local token = self._token
		task.delay(EVENT_WARNING_SECONDS, function()
			if token == self._token and self._warningId == id and self._warningSource == "Event" then
				self:_clearWarning(false)
			end
		end)
	end
end

function RunEnd._clearWarning(self: RunEnd, immediate: boolean)
	if self._warningId == nil and not self._chip.Visible then
		return
	end
	self._warningId = nil
	self._warningSource = nil
	local ctx = self._ctx
	RunBus.flags(ctx).warning = false
	RunBus.unsuppress(ctx, "Upper", "warning")
	local chip = self._chip
	if immediate then
		Motion.cancelAll(chip)
		chip.GroupTransparency = 1
		chip.Visible = false
		self:_stopFollow()
		return
	end
	local t = Motion.tween(chip, "fade", Motion.info(0.2), { GroupTransparency = 1 })
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and self._warningId == nil then
			chip.Visible = false
			self:_stopFollow()
		end
	end)
end

local function anchorPosition(anchor: Instance?): Vector3?
	if not anchor or not anchor.Parent then
		return nil
	end
	if anchor:IsA("BasePart") then
		return anchor.Position + Vector3.new(0, anchor.Size.Y / 2 + 1, 0)
	elseif anchor:IsA("Model") then
		local cf, size = anchor:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2 + 1, 0)
	end
	return nil
end

-- The chip sits just above the protected region, at the rider's x (clamped on screen).
function RunEnd._placeChip(self: RunEnd)
	local ctx = self._ctx
	local d = RunLayout.design(ctx)
	local prot = RunLayout.protected(ctx)
	local w = self._chip.Size.X.Offset
	local x = prot.pos.X + prot.size.X / 2
	local world = anchorPosition(self._anchor)
	if world then
		local p, on = RunLayout.worldToCanvas(ctx, world :: Vector3)
		if on then
			x = p.X
		end
	end
	x = math.clamp(x, w / 2 + 6, d.X - w / 2 - 6)
	local current = self._chip.Position.X.Offset
	if math.abs(current - x) > 1.5 then
		x = current + (x - current) * 0.25 -- gentle follow, no jitter
	else
		x = current
	end
	self._chip.Position = UDim2.fromOffset(x, prot.pos.Y - 6)
end

function RunEnd._startFollow(self: RunEnd)
	if self._follow then
		return
	end
	local ctx = self._ctx
	local prot = RunLayout.protected(ctx)
	self._chip.Position = UDim2.fromOffset(prot.pos.X + prot.size.X / 2, prot.pos.Y - 6)
	self:_placeChip()
	self._follow = RunService.Heartbeat:Connect(function()
		self:_placeChip()
	end)
end

function RunEnd._stopFollow(self: RunEnd)
	if self._follow then
		self._follow:Disconnect()
		self._follow = nil
	end
end

----------------------------------------------------------------------------------------------
-- Heading and hand-off

function RunEnd._onEvent(self: RunEnd, event: Store.Event)
	if self._ctx.store:get().mode ~= "Run" then
		return
	end
	if event.kind == "RunWarning" then
		self:_showWarning(event.id, event.reason, "Event")
	elseif event.kind == "Dismounted" then
		self:_clearWarning(false)
		if not self._bonked then
			self._bonked = true -- one gentle bonk per run
			self._bonks += 1
			Sounds.play("Bonk")
		end
		if RunEnd.isMapped(event.reason) then
			self:_showHeading(event.reason)
		end
	elseif event.kind == "RunEnded" then
		if self._ended then
			return -- duplicate end: one heading, one hand-off
		end
		self._ended = true
		self._endReason = event.reason
		RunBus.flags(self._ctx).ended = true
		self:_clearWarning(false)
		if not self._headingShown then
			self:_showHeading(event.reason)
		end
		local wait = math.max(0, HOLD - (os.clock() - self._headingAt))
		local token = self._token
		task.delay(wait, function()
			if token == self._token then
				self:_finish()
			end
		end)
	end
end

function RunEnd._showHeading(self: RunEnd, reason: string?)
	if self._headingShown then
		return
	end
	self._headingShown = true
	self._headingReason = reason
	self._headingAt = os.clock()
	local ctx = self._ctx
	RunBus.suppress(ctx, "Upper", "Safety", OWNER)
	RunBus.suppress(ctx, "Side", "Safety", OWNER)
	local ribbon = RunBus.get(ctx, "ribbon")
	if ribbon then
		ribbon:dismiss()
	end
	self._handle = RunBus.priority(ctx):request("Center", "Safety", "runend", {
		grant = function() end,
		wait = 0,
	})
	local title, line = RunEnd.headingFor(reason)
	self._title.Text = title
	self._line.Text = line or ""
	self._line.Visible = line ~= nil
	self:layout()
	local heading = self._heading
	heading.Visible = self._visible
	heading.GroupTransparency = 1
	local reduced = Motion.reduced()
	Motion.tween(heading, "fade", Motion.info(if reduced then 0.15 else 0.2), { GroupTransparency = 0 })
	local pop = self._headingInner:FindFirstChild("Pop") :: UIScale
	if reduced then
		pop.Scale = 1
	else
		pop.Scale = 1.25
		Motion.tween(pop, "in", Motion.info(0.22, Enum.EasingStyle.Back), { Scale = 1 })
	end
end

function RunEnd._hideHeading(self: RunEnd, immediate: boolean)
	local heading = self._heading
	if self._handle then
		RunBus.priority(self._ctx):release(self._handle)
		self._handle = nil
	end
	if immediate then
		Motion.cancelAll(heading)
		heading.GroupTransparency = 1
		heading.Visible = false
		return
	end
	local t = Motion.tween(heading, "fade", Motion.info(0.25), { GroupTransparency = 1 })
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			heading.Visible = false
		end
	end)
end

function RunEnd._finish(self: RunEnd)
	if self._finished then
		return
	end
	self._finished = true
	self:_hideHeading(false)
	local reason = self._endReason
	self.Finished:Fire(reason)
	local fn = self._onFinished
	if fn then
		task.spawn(fn, reason)
	end
end

----------------------------------------------------------------------------------------------
-- Component API

function RunEnd.setAnchor(self: RunEnd, anchor: Instance?)
	self._anchor = anchor
end

function RunEnd.layout(self: RunEnd)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local d = RunLayout.design(ctx)
	local compact = RunLayout.compact(ctx)
	-- chip width follows its text (bounded)
	local textW = if self._chipReason.Text == "" then 0 else math.min(#self._chipReason.Text * 12 + 26, 220)
	self._chip.Size = UDim2.fromOffset(44 + textW, 44)
	self._chipBand.Size = UDim2.new(1, -24, 0, 34)
	-- heading: centre slot, in the upper-middle of the screen
	local w = math.min(d.X - 24, 620)
	local h = if compact then 110 else 150
	self._heading.Size = UDim2.fromOffset(w, h)
	self._heading.Position = UDim2.fromOffset(d.X / 2, d.Y * 0.36)
	self._title.TextSize = if compact then 40 else 56
	self._title.Size = UDim2.new(1, -20, 0, (if compact then 40 else 56) + 8)
	self._line.TextSize = if compact then 20 else 24
	self._line.Size = UDim2.new(1, -20, 0, (if compact then 20 else 24) + 6)
	if self._warningId then
		self:_placeChip()
	end
end

function RunEnd.setVisible(self: RunEnd, on: boolean)
	self._visible = on
	self.root.Visible = on
end

function RunEnd.getDebugState(self: RunEnd): { [string]: any }
	return {
		visible = self._visible,
		warningId = self._warningId,
		warningSource = self._warningSource,
		warningText = if self._warningId then self._chipReason.Text else nil,
		warningsShown = self._warningsShown,
		following = self._follow ~= nil,
		headingShown = self._headingShown,
		heading = if self._headingShown then self._title.Text else nil,
		line = if self._headingShown and self._line.Visible then self._line.Text else nil,
		headingReason = self._headingReason,
		ended = self._ended,
		endReason = self._endReason,
		finished = self._finished,
		bonks = self._bonks,
		flags = table.clone(RunBus.flags(self._ctx)),
		suppressors = RunBus.suppressors(self._ctx),
	}
end

function RunEnd.destroy(self: RunEnd)
	self._trove:Destroy()
end

return RunEnd
