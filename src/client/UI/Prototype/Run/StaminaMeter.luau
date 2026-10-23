--!strict
-- Stamina demo meter (Lane 3 preview; Round 2, ledger R2-S1). PRESENTATION OF A PROPOSAL, off by default:
-- it draws store.run.stamina = { value, max, lowAt?, restore? } and nothing else. The rule (10 per run, one
-- spent per ACCEPTED hop, no Hop at zero while the current ride continues) belongs to Lane 1 and the
-- upgrade/restore questions to the team; a fixture adapter in the playground stands in for them, and
-- nothing here blocks input, spends, saves or ends a run.
--
-- Design: a large glossy yellow bolt, the current number big beside it, and a row of simpler bolt-shaped
-- pips (Icons2 "BoltPip") under it so the row stays countable on a phone. The number is primary; the pips
-- reinforce it. `max` is configurable: up to 10 each pip is one unit; above 10 there are still 10 pips,
-- each standing for ceil(max / 10) units, and the number carries the exact value ("14 / 20").
--   * an accepted hop (value drops): one pip drains, the number ticks (pop), the bolt gets one short
--     emphasis;
--   * at or below lowAt (3): amber bolt, number and pips, plus LOW STAMINA (on phones the word takes
--     the pips' slot for 2.5 s, then the pips return); no repeated pulsing;
--   * at zero: a cracked grey bolt, the number 0 and OUT OF STAMINA (persistent); the run is NOT ended;
--   * a restoring pickup (fixture switch, off by default): value rises, one pip refills; with a world
--     position a small bolt flies from the projected pickup to the meter, otherwise only the local pop;
--     the value is clamped to max and nothing plays when it is already full (no overflow animation).
--   * reduced motion: discrete pip, number and colour changes only: no pop, drain tween or flying bolt.
-- Placement: RunLayout.staminaRect (left-middle above the thumbstick zone), full or compact (phones).
--
--   local meter = StaminaMeter.new(ctx)
--   meter:layout(), meter:setVisible(on), meter:destroy(), meter:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Icons2 = require(script.Parent.Parent.Icons2)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local MAX_PIPS = 10
local DEFAULT_LOW_AT = 3
local LOW_WORD_SECONDS = 2.5 -- phones: how long LOW STAMINA replaces the pips
local FLIGHT_SECONDS = 0.45
local FLIGHT_WINDOW = 0.6 -- a pickup event this recent explains a value increase

local YELLOW = Color3.fromRGB(255, 214, 40)
local AMBER = Color3.fromRGB(255, 150, 24)
local PIP_EMPTY = Color3.fromRGB(58, 68, 98)

local function sequence(a: Color3, b: Color3, c: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.5, b),
		ColorSequenceKeypoint.new(1, c),
	})
end
local FACE_NORMAL = A.Face.Keys
local FACE_LOW = sequence(Color3.fromRGB(255, 214, 120), AMBER, Color3.fromRGB(226, 96, 0))
local FACE_ZERO = sequence(Color3.fromRGB(214, 218, 228), Color3.fromRGB(168, 174, 188), Color3.fromRGB(130, 136, 152))

type Pip = { holder: Frame, full: Frame, empty: Frame, lit: boolean }

local StaminaMeter = {}
StaminaMeter.__index = StaminaMeter

-- Pips for a configured max: (pip count, units per pip). Up to 10 each pip is one unit.
function StaminaMeter.pipsFor(max: number): (number, number)
	local n = math.max(1, math.floor(max))
	if n <= MAX_PIPS then
		return n, 1
	end
	return MAX_PIPS, math.ceil(n / MAX_PIPS)
end

function StaminaMeter.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, StaminaMeter)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._shown = false
	self._value = -1
	self._max = 10
	self._lowAt = DEFAULT_LOW_AT
	self._mode = "Normal" :: string -- Normal | Low | Empty
	self._compact = false
	self._pips = {} :: { Pip }
	self._pipSpec = "" :: string
	self._rect = nil :: RunLayout.Rect?
	self._drains = 0
	self._refills = 0
	self._flights = 0
	self._ticks = 0
	self._lowWordUntil = 0
	self._swapTimer = nil :: thread? -- the one pending "LOW STAMINA" swap-back, never more than one
	self._dead = false
	self._pickup = nil :: { at: number, pos: Vector2? }?
	self._boltName = "" :: string

	local root = self._trove:Add(RunLayout.canvas(ctx, "StaminaMeter"))
	self.root = root
	local holder = make("Frame", { Name = "Meter", BackgroundTransparency = 1, ZIndex = 2, Parent = root })
	RunKit.nonInteractive(holder)
	self._holder = holder

	local bolt = make("Frame", {
		Name = "Bolt",
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = holder,
	})
	make("UIScale", { Name = "Pop", Parent = bolt })
	self._bolt = bolt

	local number = Arcade.text(holder, {
		text = "",
		role = "Value",
		name = "Number",
		italic = true,
		face = "Keys",
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 4,
	})
	number.AnchorPoint = Vector2.new(0, 0.5)
	make("UIScale", { Name = "Pop", Parent = number })
	self._number = number
	self._numberGrad = number:FindFirstChildOfClass("UIGradient") :: UIGradient

	local word = Arcade.text(holder, {
		text = "",
		role = "Small",
		name = "Word",
		face = "Heat",
		xAlign = Enum.TextXAlignment.Left,
		autoWidth = true,
		z = 4,
	})
	word.AnchorPoint = Vector2.new(0, 0.5)
	word.Visible = false
	self._word = word

	local pips = make("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = holder,
	})
	self._pipRow = pips

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string, from: string?)
		if mode == "Run" and from ~= "Run" then
			self._value = -1 -- a new run: show the first state without an animation
		end
		self:_apply()
	end)
	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "StaminaPickup" then
			local pos: Vector2? = nil
			if event.worldPosition then
				local p, on = RunLayout.worldToCanvas(ctx, event.worldPosition)
				if on then
					pos = p
				end
			end
			self._pickup = { at = os.clock(), pos = pos }
		end
	end)
	self._trove:Add(function()
		self._dead = true
		local timer = self._swapTimer
		if timer then
			self._swapTimer = nil
			pcall(task.cancel, timer)
		end
		Motion.cancelAll(bolt)
		Motion.cancelAll(number)
	end)
	self:layout()
	return self
end

export type StaminaMeter = typeof(StaminaMeter.new((nil :: any) :: RunLayout.Ctx))

function StaminaMeter._drawBolt(self: StaminaMeter, kind: string, tint: Color3?)
	local name = if kind == "Empty" then "BoltEmpty" else "Bolt"
	local key = name .. tostring(tint)
	if key == self._boltName then
		return
	end
	self._boltName = key
	for _, c in self._bolt:GetChildren() do
		if c:IsA("Frame") and c.Name == "Art" then
			c:Destroy()
		end
	end
	Icons2.draw(self._bolt, name, if tint then { tint = tint } else nil)
end

-- (Re)builds the pip row for `count` pips of the current mode's size and colour.
function StaminaMeter._buildPips(self: StaminaMeter, count: number, tint: Color3)
	local compact = self._compact
	local spec = string.format("%d:%s:%s", count, if compact then "c" else "f", tostring(tint))
	if spec == self._pipSpec then
		return
	end
	self._pipSpec = spec
	local before: { boolean } = {}
	for i, p in self._pips do
		before[i] = p.lit -- states survive a rebuild (colour or size change), so no false animation
		p.holder:Destroy()
	end
	table.clear(self._pips)
	local pw, ph, gap
	if compact then
		gap = 2
		pw = math.floor((108 - (MAX_PIPS - 1) * gap) / MAX_PIPS)
		ph = 14
	else
		gap = 1
		pw = 14
		ph = 17
	end
	for i = 1, count do
		local h = make("Frame", {
			Name = "Pip" .. i,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset((i - 1) * (pw + gap), 0),
			Size = UDim2.fromOffset(pw, ph),
			ZIndex = 3,
			Parent = self._pipRow,
		})
		local empty = make(
			"Frame",
			{ Name = "Empty", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = h }
		)
		local full = make("Frame", {
			Name = "Full",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = h,
		})
		make("UIScale", { Name = "Pop", Parent = full })
		Icons2.draw(empty, "BoltPip", { tint = PIP_EMPTY })
		Icons2.draw(full, "BoltPip", { tint = tint })
		table.insert(
			self._pips,
			{ holder = h, full = full, empty = empty, lit = if before[i] == nil then true else before[i] }
		)
	end
	self._pipRow.Size = UDim2.fromOffset(count * (pw + gap), ph)
end

function StaminaMeter._flyBolt(self: StaminaMeter, from: Vector2)
	self._flights += 1
	local rect = self._rect
	if not rect then
		return
	end
	local fly = make("Frame", {
		Name = "Flight",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(34, 34),
		ZIndex = 20,
		Parent = self.root,
	})
	RunKit.nonInteractive(fly)
	Icons2.draw(fly, "Bolt")
	local boltSize = if self._compact then 32 else 56
	local target = Vector2.new(rect.pos.X + boltSize / 2, rect.pos.Y + boltSize / 2)
	local t = Motion.tween(fly, "fly", Motion.info(FLIGHT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromOffset(target.X, target.Y),
		Size = UDim2.fromOffset(boltSize * 0.7, boltSize * 0.7),
	})
	t.Completed:Connect(function()
		fly:Destroy()
	end)
end

function StaminaMeter._apply(self: StaminaMeter)
	local state = self._ctx.store:get()
	local run = state.run
	local st = if run then run.stamina else nil
	local shown = self._visible and state.mode == "Run" and st ~= nil
	self.root.Visible = self._visible
	self._holder.Visible = shown
	self._shown = shown
	if not shown or st == nil then
		return
	end
	local stamina = st :: Store.StaminaState
	local max = math.max(1, math.floor(stamina.max))
	local value = math.clamp(math.floor(stamina.value), 0, max) -- never negative or above max
	local lowAt = stamina.lowAt or DEFAULT_LOW_AT
	local previous = self._value
	local first = previous < 0
	self._value, self._max, self._lowAt = value, max, lowAt
	local mode = if value <= 0 then "Empty" elseif value <= lowAt then "Low" else "Normal"
	local modeChanged = mode ~= self._mode
	self._mode = mode
	local reduced = Motion.reduced()
	if modeChanged and mode == "Low" and not first then
		self._lowWordUntil = os.clock() + LOW_WORD_SECONDS
	end

	local tint = if mode == "Low" then AMBER else YELLOW
	self:_drawBolt(if mode == "Empty" then "Empty" else "Bolt", if mode == "Empty" then nil else tint)
	local count, units = StaminaMeter.pipsFor(max)
	self:_buildPips(count, tint)
	local litCount = math.clamp(math.ceil(value / units), 0, count)
	for i, pip in self._pips do
		local lit = i <= litCount
		local wasLit = pip.lit
		pip.lit = lit
		local scale = pip.full:FindFirstChild("Pop") :: UIScale
		if first or reduced or wasLit == lit then
			Motion.cancelAll(scale)
			scale.Scale = 1
			pip.full.Visible = lit
		elseif wasLit then
			-- one pip drains: it shrinks out quickly
			self._drains += 1
			pip.full.Visible = true
			local t = Motion.tween(scale, "drain", Motion.info(0.16), { Scale = 0 })
			t.Completed:Connect(function(playback)
				if playback == Enum.PlaybackState.Completed and not pip.lit then
					pip.full.Visible = false
				end
			end)
		else
			-- a restored pip pops back in
			self._refills += 1
			pip.full.Visible = true
			scale.Scale = 0.2
			Motion.tween(scale, "drain", Motion.info(0.2, Enum.EasingStyle.Back), { Scale = 1 })
		end
	end

	-- the number: exact value (with the max when the pips are grouped)
	local text = if units > 1 then string.format("%d / %d", value, max) else tostring(value)
	local grad = self._numberGrad
	grad.Color = if mode == "Low" then FACE_LOW elseif mode == "Empty" then FACE_ZERO else FACE_NORMAL
	local changed = text ~= self._number.Text
	self._number.Text = text
	self._ticks += if changed then 1 else 0

	-- animations: only on a real change after the first state, never in reduced motion
	if not first and not reduced and value ~= previous then
		Motion.pop(self._number, 1.18)
		Motion.pop(self._bolt, 1.15)
		if value > previous then
			task.defer(function()
				-- decided one frame later so the pickup event is known whichever listener ran first
				if self._dead then
					return
				end
				local recent = self._pickup
				if recent and os.clock() - recent.at < FLIGHT_WINDOW and recent.pos then
					self:_flyBolt(recent.pos)
				end
			end)
		end
	end
	self:_layoutInner()
end

function StaminaMeter._layoutInner(self: StaminaMeter)
	if not self._shown then
		return
	end
	local compact = self._compact
	local boltSize = if compact then 32 else 56
	self._bolt.Position = UDim2.fromOffset(0, if compact then 2 else 0)
	self._bolt.Size = UDim2.fromOffset(boltSize, boltSize)
	local numberX = boltSize + 4
	self._number.Position = UDim2.fromOffset(numberX, if compact then 18 else 28)
	self._number.TextSize = if compact then 22 else A.Text.Value
	local mode = self._mode
	local wordText = ""
	if mode == "Empty" then
		wordText = "OUT OF STAMINA"
	elseif mode == "Low" then
		wordText = "LOW STAMINA"
	end
	self._word.Text = wordText
	local wordOnScreen = wordText ~= ""
	local compactSwap = compact and mode == "Low" and os.clock() < self._lowWordUntil
	if compact then
		-- phones: the word takes the pips' slot at zero (persistently) and for a moment on turning low
		local showWord = mode == "Empty" or compactSwap
		self._word.Visible = wordOnScreen and showWord
		self._pipRow.Visible = not showWord
		self._word.Position = UDim2.fromOffset(numberX + 28, 18)
		self._pipRow.Position = UDim2.fromOffset(64, 11)
		if compactSwap and not self._swapTimer then
			-- one timer per swap window: _layoutInner runs on every run update, and a timer per call piled up threads
			self._swapTimer = task.delay(LOW_WORD_SECONDS + 0.05, function()
				self._swapTimer = nil
				if self._dead or not self._ctx.store:get().run then
					return
				end
				self:_layoutInner()
			end)
		end
	else
		self._word.Visible = wordOnScreen
		self._pipRow.Visible = true
		self._word.Position = UDim2.fromOffset(numberX + 54, 26)
		self._pipRow.Position = UDim2.fromOffset(2, 50)
	end
end

function StaminaMeter.layout(self: StaminaMeter)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect = RunLayout.staminaRect(ctx)
	self._rect = rect
	self._compact = RunLayout.compact(ctx)
	RunLayout.place(self._holder, rect)
	self._pipSpec = "" -- rebuild at the new mode's size
	self._boltName = ""
	self:_apply()
end

function StaminaMeter.setVisible(self: StaminaMeter, on: boolean)
	self._visible = on
	self:_apply()
end

function StaminaMeter.getDebugState(self: StaminaMeter): { [string]: any }
	local lit = 0
	for _, p in self._pips do
		if p.lit then
			lit += 1
		end
	end
	local rect = self._rect
	local pipCount, units = StaminaMeter.pipsFor(self._max)
	return {
		shown = self._shown,
		value = self._value,
		max = self._max,
		mode = self._mode,
		number = self._number.Text,
		word = if self._word.Visible then self._word.Text else "",
		pips = #self._pips,
		pipsLit = lit,
		pipCount = pipCount,
		unitsPerPip = units,
		compact = self._compact,
		drains = self._drains,
		refills = self._refills,
		flights = self._flights,
		ticks = self._ticks,
		reducedMotion = Motion.reduced(),
		box = rect and RunLayout.describe(rect),
		overlapsProtected = rect ~= nil and RunLayout.overlaps(rect, RunLayout.protected(self._ctx)),
		overlapsTray = rect ~= nil and RunLayout.overlaps(rect, RunLayout.trayRect(self._ctx)),
	}
end

function StaminaMeter.destroy(self: StaminaMeter)
	self._trove:Destroy()
end

return StaminaMeter
