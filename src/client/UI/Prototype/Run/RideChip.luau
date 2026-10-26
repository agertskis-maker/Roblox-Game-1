--!strict
-- Settings button and the transient landing label for the run view (Lane 3 preview, Round 3: R3-L).
-- The permanent RIDING chip is gone. In its place, on a CONFIRMED landing, a small label names the car you landed
-- on and its FULL rarity word (COMMON, UNCOMMON, RARE, EPIC or LEGENDARY) for about 1.5 s, then fades. The module
-- keeps its name and its "ride" registration on RunBus because the Settings button lives here too.
--
-- LANDING (what counts). The Store has no landing event kind, so a typed local adapter (RideChip.adapt) reads the
-- run state: a CHANGE of the ridden car's identity is a landing. The identity is run.rideInstanceId when the source
-- supplies one (the traffic car's instance id), else run.ride.id. The ride a run STARTS with is the baseline, not a
-- landing; the same identity again (the store re-sends the run every tick) is ignored; a ride that goes away and
-- comes back is a new landing. STORE REQUEST (for the Store owner, not made here): an event
-- { kind = "Landed", instanceId, car } and run.rideInstanceId; the adapter then becomes a one-line subscription that
-- calls RideChip:land(instanceId, car), which is already the single entry point.
--
-- ONE AT A TIME. A new landing REPLACES the label at once (new text, the hold restarts, no second label, no queue,
-- no flicker through fully transparent); ten landings in a second leave one label. A repeat of the identity that
-- landed last is ignored. Run end, leaving the Run mode, losing the ride, or a new run clear it.
--
-- NAMEPLATE. The ridden car's nameplate (World/Nameplates) shows only while that car is being CAPTURED (it carries the
-- same car name and rarity word). So the NAMEPLATE WINS: while a capture is in progress (run.keys Holding or Pending),
-- while the SECURED stack shows and after the run ended, this label is not shown, and one that is showing fades out
-- quickly. The two never show the same car at once.
--
-- MOTION. A short fade in with a small pop, a hold, a fade out (the pop is not a flash: nothing turns white).
-- Reduced motion: a steady short fade in and out, no scale. No thread and no per-frame connection: the hold is the
-- delay of the fade-out tween.
--
-- PLACE. RunLayout.landingRect (alias chipRect): right column under Settings, right of the protected road view and
-- of the arrival popup. Names wrap on up to two lines at 16 px (a name that fits one line at 18 px uses 18 px) and
-- are never cut with an ellipsis.
--
-- The options button only calls the callback it is given. It never says "pause" and implies no pause: a
-- multiplayer run keeps going while options are open.
--
--   local chip = RideChip.new(ctx)
--   chip:setOptionsCallback(fn)     -- preview: called on activation (debounced by the button)
--   chip:land(instanceId, car) -> boolean   -- a confirmed landing (false: ignored or not shown, and why in the debug state)
--   chip:refresh()                  -- re-applies the "not while capturing / SECURED" rule (RunBus callers)
--   chip:layout(), chip:setVisible(on), chip:destroy(), chip:getDebugState()
--   RideChip.adapt(run) -> (string?, CarRef?)   -- pure: the ride's identity and car

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local IN = 0.12
local IN_REDUCED = 0.15
local HOLD = 1.5 -- seconds from the landing until the fade starts
local OUT = 0.25
local QUICK = 0.12 -- an early clear (a capture took over, the run ended)
local POP = 1.08
local BIG = A.Text.Label -- 18: a name that fits one line
local SMALL = A.Text.Small -- 16: the minimum, for a name that wraps
local PAD_X = 8
local PAD_Y = 4
local RARITY_H = 20 -- one 16 px line (1.21 x the size)
local LABEL_PAD = 6 -- Arcade.text pads 3 px each side
local NEUTRAL = Color3.fromRGB(214, 220, 230)

local RideChip = {}
RideChip.__index = RideChip

-- THE LANDING ADAPTER ---------------------------------------------------------------------------

-- The identity of what is ridden and its car. `rideInstanceId` is an optional field a real source may add; until
-- then the car's id is the identity (two cars of the same model in a row are not told apart).
function RideChip.adapt(run: Store.RunState?): (string?, Store.CarRef?)
	local car = if run then run.ride else nil
	if not run or not car then
		return nil, nil
	end
	local instance = (run :: any).rideInstanceId
	if type(instance) == "string" and instance ~= "" then
		return instance, car
	end
	return car.id, car
end

local function measureX(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
end

local function measureY(text: string, size: number, width: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(width, 4096)).Y
end

function RideChip.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, RideChip)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._onOptions = nil :: (() -> ())?
	self._presses = 0
	-- landing state
	self._serial = 0
	self._runKey = ""
	self._awaitBaseline = true -- the next run update only records the ride the run starts with
	self._lastKey = nil :: string?
	self._showingKey = nil :: string?
	self._car = nil :: Store.CarRef?
	self._token = 0
	self._fadeIn = nil :: Tween?
	self._fadeOut = nil :: Tween?
	self._popUp = nil :: Tween?
	self._popDown = nil :: Tween?
	self._lines = 0
	self._nameSize = BIG
	self._connections = 0
	-- counters for tests and review
	self._landings = 0
	self._replaced = 0
	self._duplicates = 0
	self._suppressed = 0
	self._cleared = 0

	local root = self._trove:Add(RunLayout.canvas(ctx, "RideChip"))
	self.root = root

	-- HUD rebuild: the same red labelled Settings rectangle as the Home menu (Adam, §1)
	local gear = Arcade.button(root, {
		name = "Options",
		label = "Settings",
		fill = "Settings",
		size = "Small",
		anchor = Vector2.new(1, 0),
		sound = "Open",
		onActivate = function()
			self._presses += 1
			local fn = self._onOptions
			if fn then
				fn()
			end
		end,
	})
	self._trove:Add(gear.trove)
	self._gear = gear

	-- the landing label: ink body with a rarity-coloured rim, the rarity word, the name
	local group = make("CanvasGroup", {
		Name = "Landing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = root,
	})
	RunKit.nonInteractive(group)
	self._group = group
	self._pop = make("UIScale", { Name = "Pop", Parent = group })
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = group,
	})
	Arcade.corner(body, 8)
	self._rim = Arcade.outline(body, 3, NEUTRAL)
	self._rarity = Arcade.text(group, {
		text = "",
		role = "Small",
		name = "Rarity",
		colour = NEUTRAL,
		xAlign = Enum.TextXAlignment.Left,
		z = 8,
	})
	self._name = Arcade.text(group, {
		text = "",
		role = "Label",
		name = "CarName",
		xAlign = Enum.TextXAlignment.Left,
		yAlign = Enum.TextYAlignment.Top,
		z = 8,
	})
	self._name.TextWrapped = true

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._connections += 1
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode == "Run" then
			-- a new run: its first ride is the baseline again. The run state may still be the previous run's when
			-- the mode flips, so the baseline is taken from the next run update, not from this moment.
			self._serial += 1
			self._awaitBaseline = true
			self._runKey = ""
			self._lastKey = nil
			self:_clear(true)
			return
		end
		self:_apply()
	end)
	self._connections += 1
	self._trove:Connect(RunLayout.topChanged(ctx.screen), function()
		self:layout()
	end)
	self._connections += 1
	self._trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced then
			-- the pop is a motion effect: settle it where it is
			if self._popUp then
				self._popUp:Cancel()
			end
			if self._popDown then
				self._popDown:Cancel()
			end
			self._pop.Scale = 1
		end
	end))
	self._connections += 1
	RunBus.register(ctx, "ride", self)
	self:layout()
	self:_apply()
	return self
end

export type RideChip = typeof(RideChip.new((nil :: any) :: RunLayout.Ctx))

-- (registered on RunBus as "ride" in new(); CaptureRibbon asks it to refresh when the SECURED stack comes and goes)

-- THE LABEL ------------------------------------------------------------------------------------

-- Fits the text and the box to the current width; positions the label in the landing place.
function RideChip._place(self: RideChip)
	local rect = RunLayout.landingRect(self._ctx)
	local car = self._car
	local name = if car and car.name ~= "" then car.name else "?"
	local inner = rect.size.X - 2 * PAD_X - LABEL_PAD
	local size = BIG
	local nameH = math.ceil(size * 1.21)
	if measureX(name, BIG) > inner then
		size = SMALL
		nameH = math.ceil(measureY(name, SMALL, inner))
	end
	self._nameSize = size
	self._lines = math.max(1, math.floor(nameH / (size * 1.21) + 0.5))
	local height = PAD_Y + RARITY_H + nameH + PAD_Y
	self._rarity.Position = UDim2.fromOffset(PAD_X, PAD_Y)
	self._rarity.Size = UDim2.fromOffset(rect.size.X - 2 * PAD_X, RARITY_H)
	self._name.TextSize = size
	self._name.Position = UDim2.fromOffset(PAD_X, PAD_Y + RARITY_H)
	self._name.Size = UDim2.fromOffset(rect.size.X - 2 * PAD_X, nameH)
	self._group.Size = UDim2.fromOffset(rect.size.X, height)
	self._group.Position = UDim2.fromOffset(rect.pos.X + rect.size.X / 2, rect.pos.Y + height / 2)
end

function RideChip._show(self: RideChip, key: string, car: Store.CarRef)
	local group = self._group
	if self._showingKey ~= nil and group.Visible then
		self._replaced += 1
	end
	local wasVisible = group.Visible
	self._token += 1
	local token = self._token
	Motion.cancelAll(group)
	Motion.cancelAll(self._pop)
	self._car = car
	self._showingKey = key
	local r = (PreviewTokens.Rarity :: any)[car.rarity]
	local colour: Color3 = if r then r.light else NEUTRAL
	self._rarity.Text = if r then r.label else "?"
	self._rarity.TextColor3 = colour
	self._rim.Color = colour
	self._name.Text = if car.name ~= "" then car.name else "?"
	self:_place()
	local reduced = Motion.reduced()
	if not wasVisible then
		group.GroupTransparency = 1 -- a label that is already showing is never sent back through fully transparent
	end
	group.Visible = true
	self._pop.Scale = 1
	-- fade in, then the fade-out starts after the hold: the hold is that tween's own delay, so there is no timer
	-- thread to cancel and no queue to grow, and a replacement cancels both tweens at once
	local fadeIn = if reduced then IN_REDUCED else IN
	local appear = Motion.tween(group, "in", TweenInfo.new(fadeIn, Enum.EasingStyle.Quad), { GroupTransparency = 0 })
	self._fadeIn = appear
	appear.Completed:Once(function(state: Enum.PlaybackState)
		if state ~= Enum.PlaybackState.Completed or token ~= self._token then
			return
		end
		local out =
			TweenInfo.new(OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, math.max(HOLD - fadeIn, 0))
		local fadeOut = Motion.tween(group, "out", out, { GroupTransparency = 1 })
		self._fadeOut = fadeOut
		fadeOut.Completed:Once(function(done: Enum.PlaybackState)
			if done == Enum.PlaybackState.Completed and token == self._token then
				group.Visible = false
				self._showingKey = nil
				self._car = nil
			end
		end)
	end)
	if not reduced then
		local up = Motion.tween(self._pop, "pop", Motion.info(0.07, Enum.EasingStyle.Back), { Scale = POP })
		self._popUp = up
		up.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and token == self._token then
				self._popDown = Motion.tween(self._pop, "pop", Motion.info(0.1), { Scale = 1 })
			end
		end)
	end
end

-- Takes the label away: at once, or with a quick fade (the car's name is on a nameplate now, the run ended).
function RideChip._clear(self: RideChip, immediate: boolean)
	local group = self._group
	if self._showingKey == nil and not group.Visible then
		return
	end
	self._cleared += 1
	self._token += 1
	local token = self._token
	Motion.cancelAll(group)
	Motion.cancelAll(self._pop)
	self._pop.Scale = 1
	self._showingKey = nil
	self._car = nil
	if immediate or Motion.reduced() then
		group.GroupTransparency = 1
		group.Visible = false
		return
	end
	local quick = Motion.tween(group, "out", Motion.info(QUICK), { GroupTransparency = 1 })
	quick.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and token == self._token then
			group.Visible = false
		end
	end)
end

-- True while the label must not show: the nameplate (or the SECURED stack) names the car, or the run has ended.
function RideChip._held(self: RideChip, run: Store.RunState?): boolean
	local k = run and run.keys
	local capturing = k ~= nil and (k.status == "Holding" or k.status == "Pending")
	local flags = RunBus.flags(self._ctx)
	return capturing or flags.secured or flags.ended
end

-- A confirmed landing. Returns true when the label was shown.
function RideChip.land(self: RideChip, instanceId: string, car: Store.CarRef): boolean
	local state = self._ctx.store:get()
	if not self._visible or state.mode ~= "Run" then
		return false
	end
	if instanceId == self._lastKey then
		self._duplicates += 1 -- the same landing again
		return false
	end
	self._lastKey = instanceId
	if self:_held(state.run) then
		self._suppressed += 1
		self:_clear(false) -- a label for the car before this one is stale now
		return false
	end
	self._landings += 1
	self:_show(instanceId, car)
	return true
end

-- THE STORE UPDATE ----------------------------------------------------------------------------

function RideChip._apply(self: RideChip)
	local state = self._ctx.store:get()
	local run = state.run
	if state.mode ~= "Run" or not run then
		self._runKey = ""
		self._lastKey = nil
		self._awaitBaseline = true
		self:_clear(true)
		return
	end
	local key = run.runId or ("run#" .. self._serial)
	local id, car = RideChip.adapt(run)
	if key ~= self._runKey or self._awaitBaseline then
		-- a new run: the ride it starts with is the baseline, not a landing
		self._awaitBaseline = false
		self._runKey = key
		self._lastKey = id
		self:_clear(true)
		return
	end
	if id == nil or car == nil then
		self._lastKey = nil -- no ride: a later ride is a landing again
		self:_clear(true)
		return
	end
	if id ~= self._lastKey then
		self:land(id, car)
	elseif self._showingKey ~= nil and self:_held(run) then
		self:_clear(false)
	end
end

function RideChip.layout(self: RideChip)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local gearRect = RunLayout.gearRect(ctx)
	self._gear.root.Position = UDim2.fromOffset(gearRect.pos.X + gearRect.size.X, gearRect.pos.Y)
	if self._showingKey ~= nil then
		self:_place()
	end
end

function RideChip.setOptionsCallback(self: RideChip, fn: (() -> ())?)
	self._onOptions = fn
end

function RideChip.setVisible(self: RideChip, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:_clear(true)
	end
end

-- Re-applies the "not while capturing / SECURED" rule (the SECURED stack asks for it when it comes and goes).
function RideChip.refresh(self: RideChip)
	self:_apply()
end

-- a tween that is running or waiting out its delay
local function live(t: Tween?): boolean
	return t ~= nil and (t.PlaybackState == Enum.PlaybackState.Playing or t.PlaybackState == Enum.PlaybackState.Delayed)
end

function RideChip.getDebugState(self: RideChip): { [string]: any }
	local group = self._group
	local reserved = RunLayout.landingRect(self._ctx)
	local abs = RunLayout.rect(
		group.Position.X.Offset - group.Size.X.Offset / 2,
		group.Position.Y.Offset - group.Size.Y.Offset / 2,
		group.Size.X.Offset,
		group.Size.Y.Offset,
		"Landing"
	)
	local prot = RunLayout.protected(self._ctx)
	local pill = RunLayout.routeRect(self._ctx)
	local cash = RunLayout.cashRect(self._ctx)
	local gear = RunLayout.gearRect(self._ctx)
	local banner = RunLayout.bannerRect(self._ctx)
	local tweens = 0
	for _, t in { self._fadeIn, self._fadeOut, self._popUp, self._popDown } do
		if live(t) then
			tweens += 1
		end
	end
	local nameText = self._name.Text
	return {
		visible = self._visible,
		showing = self._showingKey ~= nil and group.Visible,
		showingKey = self._showingKey,
		lastKey = self._lastKey,
		car = self._car and self._car.name,
		rarityWord = self._rarity.Text,
		nameText = nameText,
		nameSize = self._name.TextSize,
		nameLines = self._lines,
		nameBoundsX = self._name.TextBounds.X,
		nameBoundsY = self._name.TextBounds.Y,
		nameBoxX = self._name.Size.X.Offset - LABEL_PAD,
		nameBoxY = self._name.Size.Y.Offset,
		nameTruncate = self._name.TextTruncate.Name,
		nameWrapped = self._name.TextWrapped,
		groupTransparency = group.GroupTransparency,
		popScale = self._pop.Scale,
		holdSeconds = HOLD,
		fadeSeconds = OUT,
		landings = self._landings,
		replaced = self._replaced,
		duplicates = self._duplicates,
		suppressed = self._suppressed,
		cleared = self._cleared,
		box = RunLayout.describe(abs),
		boxHeight = abs.size.Y,
		inside = RunLayout.inside(abs, RunLayout.design(self._ctx)),
		reservedBox = RunLayout.describe(reserved),
		overlapsProtected = RunLayout.overlaps(abs, prot),
		overlapsPill = RunLayout.overlaps(abs, pill),
		overlapsCash = RunLayout.overlaps(abs, cash),
		overlapsGear = RunLayout.overlaps(abs, gear),
		overlapsBanner = RunLayout.overlaps(abs, banner),
		reservedOverlapsProtected = RunLayout.overlaps(reserved, prot),
		reservedOverlapsPill = RunLayout.overlaps(reserved, pill),
		reservedOverlapsBanner = RunLayout.overlaps(reserved, banner),
		gearBox = RunLayout.describe(gear),
		gearSize = self._gear.body.Size.X.Offset,
		optionsPresses = self._presses,
		saysPause = false,
		tweens = tweens,
		threads = 0,
		renderStepped = false,
		connections = self._connections,
		instances = #self.root:GetDescendants(),
		landingInstances = #group:GetDescendants(),
	}
end

function RideChip.destroy(self: RideChip)
	RunBus.unregister(self._ctx, "ride", self)
	Motion.cancelAll(self._group)
	Motion.cancelAll(self._pop)
	self._token += 1
	self._trove:Destroy()
	self._connections = 0
end

return RideChip
