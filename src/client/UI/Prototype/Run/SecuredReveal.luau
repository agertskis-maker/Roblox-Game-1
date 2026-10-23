--!strict
-- SECURED reveal (Lane 3 preview, Round 2, R2-V1): the accomplishment moment for a CONFIRMED claim, as a vivid collectible
-- card on wide screens. It is a presentation module driven by Run/CaptureRibbon, which owns identity: it plays only for a
-- confirmed claim id (KeysConfirmed), once per id, with late and out-of-order confirmations, suppression and the
-- hand-over to Results handled there. Nothing here decides or grants ownership.
--
-- DRAMA VERSUS DRIVING VISIBILITY. A transparent large card can still hide hazards, so steering input being free is not
-- a reason to call it safe. RunLayout.revealRect only returns a place where the card CLEARS the protected road/target
-- rectangle, the top block, the touch zones, Heat, Hop, the tray and Stamina; on phones, or when no such place is clear,
-- there is no card and the compact SECURED ribbon with the car thumbnail plays at once instead (same identity, same
-- sound: it is not a second-rate placeholder). The full card is also reserved for Results and the detail view.
--
-- The card is TradingCard (Reward): SECURED stamp, readable name, rarity, family icon, NEW only on a supplied flag and the
-- supplied Lap Pay. About 1.7 s: it pops in (0.24 s), holds (1.0 s), then flies to the tray’s count and shrinks away
-- (0.45 s). Behind it: eight slow rays, one soft light bloom and at most 24 confetti pieces (a fixed pool: 33 pieces and
-- one shockwave ring in all, under the 40 cap); a LEGENDARY card adds one gold shockwave ring in UI space inside the same
-- duration. No camera, grading, whiteout or pause. The tray count already changed once at confirmation (the ribbon
-- calls tray:arrive when it starts), so the flight is only presentation.
--
-- Reduced motion: no zoom, rays, confetti, bloom, shockwave or flight: a stable, steady card for 1.3 s, then it is gone.
-- Haptics: one best-effort UINotification cue through Run/Haptics, OFF unless store.settings.haptics is true; never
-- claimed felt on hardware.
--
--   local reveal = SecuredReveal.new(ctx)            -- registered on RunBus as "reveal"
--   reveal:available() -> Rect?                       -- where the card would go, nil = use the compact ribbon
--   reveal:play(item, onDone) -> boolean              -- item = { id, car, lapPay? }; onDone(landedByFlight)
--   reveal:cancel()   reveal:isPlaying()
--   reveal:layout(), reveal:setVisible(on), reveal:destroy(), reveal:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Haptics = require(script.Parent.Haptics)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunBus = require(script.Parent.RunBus)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local TradingCard = require(script.Parent.Parent.Cards.TradingCard)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local IN = 0.24
local HOLD = 1.0
local OUT = 0.45
local HOLD_REDUCED = 1.3
local RAYS = 8
local CONFETTI = 24
local FX_CAP = 40 -- pooled pieces, rays and confetti together (the shockwave is one extra ring)

local SecuredReveal = {}
SecuredReveal.__index = SecuredReveal

export type Item = { id: string, car: Store.CarRef, lapPay: number? }

function SecuredReveal.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, SecuredReveal)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._token = 0
	self._playing = false
	self._card = nil :: any
	self._rect = nil :: RunLayout.Rect?
	self._plays = 0
	self._cancels = 0
	self._flights = 0
	self._shock = 0
	self._haptic = "none"
	self._lastReduced = false
	self._legendary = false

	local root = self._trove:Add(RunLayout.canvas(ctx, "SecuredReveal"))
	self.root = root
	local stage = make("Frame", {
		Name = "Reveal",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(RunLayout.RevealSize.X, RunLayout.RevealSize.Y),
		Visible = false,
		ZIndex = 6,
		Parent = root,
	})
	RunKit.nonInteractive(stage)
	self._stage = stage
	-- rays: eight slim gold bars around the card centre, rotating slowly behind it
	local rays = make("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(440, 440),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = stage,
	})
	for i = 1, RAYS do
		local bar = make("Frame", {
			Name = "Ray" .. i,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(16, 210),
			Rotation = (i - 1) * (360 / RAYS),
			BackgroundColor3 = A.Fill.Gold.Keypoints[1].Value,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = rays,
		})
		make("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.6, 0.55),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Parent = bar,
		})
	end
	self._rays = rays
	-- one restrained light bloom behind the card
	local bloom = make("Frame", {
		Name = "Bloom",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(320, 320),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = stage,
	})
	Arcade.corner(bloom, 999)
	make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90,
		Parent = bloom,
	})
	self._bloom = bloom
	-- the card goes here (built per play, destroyed after)
	local holder = make("Frame", {
		Name = "CardHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = stage,
	})
	self._holder = holder
	self._scale = make("UIScale", { Name = "Pop", Parent = holder })
	-- confetti: a fixed pool over the whole canvas
	local fx = make("Frame", {
		Name = "Confetti",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = root,
	})
	RunKit.nonInteractive(fx)
	self._confetti = {} :: { Frame }
	for i = 1, CONFETTI do
		local piece = make("Frame", {
			Name = "Piece" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(if i % 3 == 0 then 12 else 8, if i % 3 == 0 then 12 else 5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = false,
			ZIndex = 12,
			Parent = fx,
		})
		Arcade.outline(piece, 1.25)
		table.insert(self._confetti, piece)
	end
	-- the Legendary shockwave: one gold ring in UI space
	local shock = make("Frame", {
		Name = "Shockwave",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(200, 200),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 11,
		Parent = root,
	})
	Arcade.corner(shock, 999)
	self._shockStroke = make("UIStroke", {
		Thickness = 6,
		Color = A.Fill.Gold.Keypoints[2].Value,
		Transparency = 1,
		Parent = shock,
	})
	self._shockFrame = shock

	self._trove:Connect(ctx.store.ModeChanged, function(mode: string)
		if mode ~= "Run" then
			self:cancel()
		end
	end)
	self._trove:Add(function()
		self:cancel()
		RunBus.unregister(ctx, "reveal", self)
	end)
	RunBus.register(ctx, "reveal", self)
	self:layout()
	return self
end

export type SecuredReveal = typeof(SecuredReveal.new((nil :: any) :: RunLayout.Ctx))

function SecuredReveal.available(self: SecuredReveal): RunLayout.Rect?
	if not self._visible then
		return nil
	end
	local rect = RunLayout.revealRect(self._ctx)
	return rect
end

function SecuredReveal._cleanup(self: SecuredReveal)
	Motion.cancelAll(self._stage)
	Motion.cancelAll(self._scale)
	Motion.cancelAll(self._rays)
	Motion.cancelAll(self._bloom)
	Motion.cancelAll(self._shockFrame)
	Motion.cancelAll(self._shockStroke)
	for _, p in self._confetti do
		Motion.cancelAll(p)
		p.Visible = false
	end
	self._shockFrame.Visible = false
	self._stage.Visible = false
	self._bloom.BackgroundTransparency = 1
	self._scale.Scale = 1
	self._rays.Rotation = 0
	self._rays.Visible = true
	if self._card then
		self._card:destroy()
		self._card = nil
	end
end

function SecuredReveal.cancel(self: SecuredReveal)
	if self._playing then
		self._cancels += 1
	end
	self._token += 1
	self._playing = false
	self:_cleanup()
end

function SecuredReveal.isPlaying(self: SecuredReveal): boolean
	return self._playing
end

local function burst(self: SecuredReveal, origin: Vector2, accent: Color3)
	local colours = { A.Fill.Gold.Keypoints[2].Value, Color3.new(1, 1, 1), accent }
	for i, piece in self._confetti do
		local angle = (i / CONFETTI) * math.pi * 2 + 0.2
		local dist = 90 + (i % 5) * 28
		piece.BackgroundColor3 = colours[(i % #colours) + 1]
		piece.Position = UDim2.fromOffset(origin.X, origin.Y)
		piece.Rotation = (i * 41) % 90
		piece.BackgroundTransparency = 0
		piece.Visible = true
		local goal = origin + Vector2.new(math.cos(angle) * dist, math.sin(angle) * dist * 0.8 + 40)
		local t = Motion.tween(piece, "confetti", Motion.info(0.95), {
			Position = UDim2.fromOffset(goal.X, goal.Y),
			Rotation = piece.Rotation + 160,
			BackgroundTransparency = 1,
		})
		t.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				piece.Visible = false
			end
		end)
	end
end

-- Plays the card for a confirmed claim. Returns false when there is no clear place (use the compact ribbon).
function SecuredReveal.play(self: SecuredReveal, item: Item, onDone: ((boolean) -> ())?): boolean
	local rect = self:available()
	if not rect then
		return false
	end
	local r = rect :: RunLayout.Rect
	self:cancel()
	self._token += 1
	local token = self._token
	self._playing = true
	self._plays += 1
	self._rect = r
	local car = item.car
	self._legendary = car.rarity == "Legendary"
	local accent = RunKit.rarity(car).light
	local reduced = Motion.reduced()
	self._lastReduced = reduced

	-- the claim is confirmed, so the card shows the car in full colour (owned); NEW comes from the supplied flag
	local claimed = table.clone(car) :: any
	claimed.owned = true
	local card = TradingCard.new(self._holder, claimed, { lapPay = item.lapPay, isNew = car.owned == false }, {
		variant = "Reward",
		stamp = "SECURED",
		name = "SecuredCard",
	})
	card.root.Position = UDim2.fromScale(0, 0)
	self._card = card
	local stage = self._stage
	stage.Position = UDim2.fromOffset(r.pos.X, r.pos.Y)
	stage.Visible = true
	self._rays.Visible = not reduced
	self._haptic = Haptics.confirm(self._ctx.store:get().settings.haptics == true)

	local centre = r.pos + Vector2.new(r.size.X / 2, r.size.Y * 0.45)
	local hold = if reduced then HOLD_REDUCED else IN + HOLD
	if not reduced then
		self._scale.Scale = 0.82
		Motion.tween(self._scale, "pop", Motion.info(IN, Enum.EasingStyle.Back), { Scale = 1 })
		Motion.tween(self._rays, "spin", Motion.info(IN + HOLD + OUT, Enum.EasingStyle.Linear), { Rotation = 70 })
		self._bloom.BackgroundTransparency = 0.45
		self._bloom.Size = UDim2.fromOffset(220, 220)
		Motion.tween(self._bloom, "bloom", Motion.info(0.5), {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(380, 380),
		})
		burst(self, centre, accent)
		if self._legendary then
			self._shock += 1
			local shock = self._shockFrame
			shock.Position = UDim2.fromOffset(centre.X, centre.Y)
			shock.Size = UDim2.fromOffset(160, 160)
			shock.Visible = true
			self._shockStroke.Transparency = 0.15
			Motion.tween(shock, "shock", Motion.info(0.7), { Size = UDim2.fromOffset(560, 560) })
			Motion.tween(self._shockStroke, "shock", Motion.info(0.7), { Transparency = 1 }).Completed
				:Connect(function()
					if token == self._token then
						shock.Visible = false
					end
				end)
		end
	end
	task.delay(hold, function()
		if token ~= self._token then
			return
		end
		self:_exit(token, onDone)
	end)
	return true
end

-- The card flies to the tray count and shrinks away (presentation only: the count already changed). Reduced motion:
-- it just goes.
function SecuredReveal._exit(self: SecuredReveal, token: number, onDone: ((boolean) -> ())?)
	local reduced = Motion.reduced()
	local tray = RunBus.get(self._ctx, "tray")
	local target = if tray and tray.countPoint then tray:countPoint() else nil
	local function finish(flew: boolean)
		if token ~= self._token or not self._playing then
			return
		end
		self._playing = false
		self:_cleanup()
		if flew then
			self._flights += 1
		end
		if onDone then
			onDone(flew)
		end
	end
	if reduced or not target or not self._rect then
		finish(false)
		return
	end
	local r = self._rect :: RunLayout.Rect
	local to = RunLayout.absToCanvas(self.root, target, self._ctx)
	local toStage = Vector2.new(to.X - r.size.X / 2, to.Y - r.size.Y * 0.45)
	self._rays.Visible = false
	Motion.tween(self._stage, "fly", Motion.info(OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromOffset(toStage.X, toStage.Y),
	})
	local t = Motion.tween(self._scale, "shrink", Motion.info(OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.08,
	})
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			finish(true)
		end
	end)
end

function SecuredReveal.layout(self: SecuredReveal)
	RunLayout.fit(self._ctx, self.root)
end

function SecuredReveal.setVisible(self: SecuredReveal, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:cancel()
	end
end

function SecuredReveal.getDebugState(self: SecuredReveal): { [string]: any }
	local rect, why = RunLayout.revealRect(self._ctx)
	local live = 0
	for _, p in self._confetti do
		if p.Visible then
			live += 1
		end
	end
	local placed = self._rect
	return {
		visible = self._visible,
		playing = self._playing,
		plays = self._plays,
		cancels = self._cancels,
		flights = self._flights,
		shockwaves = self._shock,
		legendary = self._legendary,
		haptic = self._haptic,
		haptics = Haptics.counts(),
		cardAvailable = rect ~= nil,
		cardUnavailableBecause = why,
		box = rect and RunLayout.describe(rect),
		placedBox = placed and RunLayout.describe(placed),
		overlapsProtected = placed ~= nil and RunLayout.overlaps(placed, RunLayout.protected(self._ctx)),
		fxPieces = RAYS + CONFETTI,
		fxCap = FX_CAP,
		confettiLive = live,
		raysShown = self._rays.Visible and self._playing,
		scale = self._scale.Scale,
		reducedMotion = self._lastReduced,
		card = self._card and self._card:getDebugState(),
	}
end

function SecuredReveal.destroy(self: SecuredReveal)
	self._trove:Destroy()
end

return SecuredReveal
