--!strict
-- Confirmed-capture celebration for the run view (Lane 3 preview, worker H3). It plays ONLY on
-- an explicit store event { kind = "KeysConfirmed", car = CarRef } - the owning lane's
-- confirmed claim, supplied by the preview adapter. Keys progress reaching 100% never plays it.
--
--   "YOU GOT THE KEYS!" headline, a short rarity-coloured burst (12 rays, bounded), a card
--   reveal with a restrained tilt (6 degrees settling to 0), bounded confetti (14 pieces from a
--   fixed pool) and Sounds.play("KeysCapture"). Auto-dismisses after about 2.2 s.
--
-- Keep driving visible: the large card is offered beside the landing view (left side, clear of
-- the reserved LANDING VIEW band, the touch zones and the Heat panel). If that rectangle does not
-- fit, it immediately uses a compact ribbon at the top (under Distance + coins) and defers the
-- expanded card to Results: pendingCards() lists the deferred cars, takePendingCards() hands
-- them over and clears the list. A new run (mode -> Run) clears the list; Results mode
-- dismisses the celebration at once (Results supersedes run feedback).
--
-- Reduced motion: a calm version - fade in, no tilt, no burst, no confetti, shorter (1.6 s).
--
-- The card is Cards/CarCard when another worker's module is present at runtime (required lazily
-- inside pcall; API CarCard.new(parent, car, { size, position, anchor, spinning }) -> { root,
-- destroy }, spinning only outside reduced motion); otherwise a simple framed name card drawn here.
--
--   local cel = CaptureCelebration.new(ctx)
--   cel:pendingCards() -> { CarRef }, cel:takePendingCards() -> { CarRef }
--   cel:dismiss(), cel:layout(), cel:setVisible(on), cel:destroy(), cel:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local S = PreviewTokens.Size
local make = Gloss.make

local RAYS = 12
local CONFETTI = 14
local SECONDS = 2.2
local SECONDS_REDUCED = 1.6
local TILT = 6
local RIBBON_H = 36
local OWNER = "CaptureCelebration"
local PRIORITY = 3

local CaptureCelebration = {}
CaptureCelebration.__index = CaptureCelebration

local function rarityOf(car: Store.CarRef)
	return PreviewTokens.Rarity[car.rarity] or PreviewTokens.Rarity.Common
end

-- A simple framed name card (fallback when Cards/CarCard is not present).
local function fallbackCard(parent: Instance, car: Store.CarRef): Frame
	local r = rarityOf(car)
	local card = make("Frame", {
		Name = "FallbackCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = parent,
	})
	Gloss.corner(card, 18)
	local frame = Gloss.stroke(card, 5, r.deep)
	frame.LineJoinMode = Enum.LineJoinMode.Round
	local strip = make("Frame", {
		Name = "RarityStrip",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = r.deep,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = card,
	})
	Gloss.corner(strip, 16)
	Gloss.gradient(strip, r.light, r.deep)
	local label = Gloss.label(strip, r.label, 18, C.White)
	label.Size = UDim2.new(1, -60, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 12
	Gloss.stroke(label, 2, C.Ink, Enum.ApplyStrokeMode.Contextual)
	local pips = make("Frame", {
		Name = "Pips",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(5 * 10, 10),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = strip,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 2),
		Parent = pips,
	})
	for _ = 1, r.pips do
		local pip = make("Frame", {
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			ZIndex = 13,
			Parent = pips,
		})
		Gloss.corner(pip, 4)
		Gloss.stroke(pip, 1, C.Ink)
	end
	local art = make("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.new(1, -28, 0, 112),
		BackgroundColor3 = r.light,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = card,
	})
	Gloss.corner(art, 12)
	Gloss.gradient(art, C.White, r.light)
	local carIcon = make("Frame", {
		Name = "CarIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = art,
	})
	Icons.draw(carIcon, "Car", r.deep)
	make("TextLabel", {
		Name = "CarName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 166),
		Size = UDim2.new(1, -24, 0, 56),
		FontFace = Tokens.font(),
		Text = car.name,
		TextSize = Tokens.TextSize.Value,
		TextColor3 = C.Ink,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 12,
		Parent = card,
	})
	make("TextLabel", {
		Name = "Family",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 1, -48),
		Size = UDim2.new(1, -24, 0, 20),
		FontFace = Tokens.font(),
		Text = car.family .. " · " .. car.quirk,
		TextSize = Tokens.TextSize.Minimum,
		TextColor3 = C.InkSoft,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 12,
		Parent = card,
	})

	return card
end

-- Lazily requires Cards/CarCard (another worker's module) inside pcall.
local function tryCarCard(holder: Frame, car: Store.CarRef): (GuiObject?, any)
	local proto = script.Parent.Parent
	local folder = proto:FindFirstChild("Cards")
	local module = folder and folder:FindFirstChild("CarCard")
	if not (module and module:IsA("ModuleScript")) then
		return nil, nil
	end
	local ok, result = pcall(function()
		local M = (require :: any)(module)
		return M.new(holder, car, {
			size = Vector2.new(S.CardWidth, S.CardHeight),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			spinning = not Motion.reduced(),
		})
	end)
	if not ok or type(result) ~= "table" then
		return nil, nil
	end
	local root = result.root or result.Root
	if typeof(root) == "Instance" and root:IsA("GuiObject") then
		-- the celebration card is not a button: never take input away from driving
		for _, g in { root, result.body } do
			if typeof(g) == "Instance" and g:IsA("GuiObject") then
				g.Active = false
			end
		end
		return root, result
	end
	return nil, nil
end

function CaptureCelebration.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, CaptureCelebration)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._playing = false
	self._mode = "None" :: "None" | "Card" | "Ribbon"
	self._pending = {} :: { Store.CarRef }
	self._plays = 0
	self._token = 0
	self._car = nil :: Store.CarRef?
	self._cardTrove = self._trove:Extend()
	self._cardSource = "None"
	self._cardObj = nil :: any
	self._cardRect = nil :: RunLayout.Rect?
	self._slot = RunLayout.slot(ctx.screen)

	local root = self._trove:Add(RunLayout.canvas(ctx, "CaptureCelebration"))
	self.root = root

	-- Headline (card mode): top centre under Distance + coins.
	local headline = Gloss.title(root, "YOU GOT THE KEYS!", Tokens.TextSize.Display, C.KeysLight, C.KeysDeep)
	headline.Name = "Headline"
	headline.AnchorPoint = Vector2.new(0.5, 0)
	headline.Size = UDim2.fromOffset(520, Tokens.TextSize.Display + 8)
	headline.ZIndex = 20
	headline.Visible = false
	self._headline = headline

	-- Ribbon (compact mode): a gold strip with the headline and the car name.
	-- (a CanvasGroup so the calm reduced-motion version can fade it as one piece)
	local ribbon = make("CanvasGroup", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(420, RIBBON_H + 6),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	local ribbonBody = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 0, RIBBON_H),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = ribbon,
	})
	Gloss.corner(ribbonBody, RIBBON_H / 2)
	Gloss.stroke(ribbonBody, 3, C.Ink)
	Gloss.gradient(ribbonBody, C.KeysLight, C.KeysDeep)
	local ribbonKey = make("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = ribbonBody,
	})
	Icons.draw(ribbonKey, "Key", C.Ink)
	local ribbonText = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -52, 1, 0),
		FontFace = Tokens.font(),
		Text = "",
		TextSize = Tokens.TextSize.Label,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = false,
		ZIndex = 22,
		Parent = ribbonBody,
	})
	Gloss.stroke(ribbonText, 2.5, C.Ink, Enum.ApplyStrokeMode.Contextual)
	self._ribbon = ribbon
	self._ribbonText = ribbonText

	-- Card holder (rotation for the tilt lives here).
	local cardHolder = make("Frame", {
		Name = "CardHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(S.CardWidth, S.CardHeight),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = root,
	})
	self._cardHolder = cardHolder
	local cardScale = make("UIScale", { Name = "Reveal", Scale = 1, Parent = cardHolder })
	self._cardScale = cardScale

	-- Burst: 12 rays behind the card, from a fixed pool.
	local burst = make("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Visible = false,
		Parent = root,
	})
	self._burst = burst
	self._rays = {} :: { Frame }
	for i = 1, RAYS do
		-- A GuiObject rotates about its own centre, so each ray hangs from a rotated square pivot
		-- centred on the burst point; the ray's bottom sits at the pivot's centre.
		local pivot = make("Frame", {
			Name = "Pivot" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(420, 420),
			Rotation = (i - 1) * (360 / RAYS),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = burst,
		})
		local ray = make("Frame", {
			Name = "Ray",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.5, -30),
			Size = UDim2.fromOffset(10, 20),
			BackgroundColor3 = C.White,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = pivot,
		})
		Gloss.corner(ray, 5)
		table.insert(self._rays, ray)
	end
	-- Confetti: 14 pieces from a fixed pool.
	self._confetti = {} :: { Frame }
	for i = 1, CONFETTI do
		local piece = make("Frame", {
			Name = "Confetti" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(8, 12),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 15,
			Parent = root,
		})
		Gloss.corner(piece, 2)
		table.insert(self._confetti, piece)
	end

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "KeysConfirmed" and event.car then
			self:play(event.car)
		end
	end)
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string, from: string?)
		if mode == "Results" or mode == "Home" then
			self:dismiss()
		end
		if mode == "Run" and from ~= nil then
			table.clear(self._pending)
		end
	end)
	self._trove:Connect(self._slot.Preempted, function(owner: string)
		if owner == OWNER then
			self:dismiss()
		end
	end)
	self._trove:Connect(RunLayout.topChanged(ctx.screen), function()
		self:layout()
	end)
	self._trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced and self._playing then
			self:_stopMotion()
			self._cardHolder.Rotation = 0
			self._cardScale.Scale = 1
			local obj = self._cardObj
			if obj and type(obj.setSpinning) == "function" then
				pcall(obj.setSpinning, obj, false)
			end
		end
	end))
	self._trove:Add(function()
		self._token += 1
		self:_stopMotion()
		self._slot.release(OWNER)
	end)
	self:layout()
	return self
end

export type CaptureCelebration = typeof(CaptureCelebration.new((nil :: any) :: RunLayout.Ctx))

-- Where the large card would go: left of the landing view, vertically centred on the band.
function CaptureCelebration._cardCandidate(self: CaptureCelebration): RunLayout.Rect
	local ctx = self._ctx
	local band = RunLayout.landingBand(ctx)
	local w, h = S.CardWidth, S.CardHeight
	local m = RunLayout.Margin
	local cx = math.max(m + w / 2, (band.pos.X - m) / 2)
	local cy = band.pos.Y + band.size.Y / 2
	return RunLayout.rect(cx - w / 2, cy - h / 2, w, h, "Card")
end

function CaptureCelebration._cardFits(self: CaptureCelebration): (boolean, string?)
	local ctx = self._ctx
	local rect = self:_cardCandidate()
	local _, conflict = RunLayout.solve(ctx, { rect }, {
		RunLayout.landingBand(ctx),
		RunLayout.heatPanelRect(ctx),
		RunLayout.topBlock(ctx),
		(RunLayout.keysRect(ctx)),
	})
	return conflict == nil, conflict
end

function CaptureCelebration.layout(self: CaptureCelebration)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local d = RunLayout.design(ctx)
	local y = RunLayout.messageY(ctx)
	self._headline.Position = UDim2.fromOffset(d.X / 2, y)
	self._headline.Size = UDim2.fromOffset(math.min(520, d.X - 24), Tokens.TextSize.Display + 8)
	self._ribbon.Position = UDim2.fromOffset(d.X / 2, y)
	self._ribbon.Size = UDim2.fromOffset(math.min(440, d.X - 24), RIBBON_H + 6)
	local rect = self:_cardCandidate()
	self._cardRect = rect
	local cx, cy = rect.pos.X + rect.size.X / 2, rect.pos.Y + rect.size.Y / 2
	self._cardHolder.Position = UDim2.fromOffset(cx, cy)
	self._burst.Position = UDim2.fromOffset(cx, cy)
end

function CaptureCelebration._ribbonRect(self: CaptureCelebration): RunLayout.Rect
	local r = self._ribbon
	local w, h = r.Size.X.Offset, r.Size.Y.Offset
	return RunLayout.rect(r.Position.X.Offset - w / 2, r.Position.Y.Offset, w, h, "Ribbon")
end

function CaptureCelebration._stopMotion(self: CaptureCelebration)
	Motion.cancelAll(self._cardHolder)
	Motion.cancelAll(self._cardScale)
	Motion.cancelAll(self._headline)
	self._headline.TextTransparency = 0
	for _, child in self._headline:GetChildren() do
		if child:IsA("UIStroke") then
			Motion.cancelAll(child)
			child.Transparency = 0
		end
	end
	Motion.cancelAll(self._ribbon)
	self._ribbon.GroupTransparency = 0
	for _, r in self._rays do
		Motion.cancelAll(r)
		r.BackgroundTransparency = 1
	end
	for _, p in self._confetti do
		Motion.cancelAll(p)
		p.Visible = false
	end
	self._burst.Visible = false
end

function CaptureCelebration._buildCard(self: CaptureCelebration, car: Store.CarRef)
	self._cardTrove:Clean()
	local root, obj = tryCarCard(self._cardHolder, car)
	if root then
		self._cardSource = "CarCard"
		self._cardObj = obj
		self._cardTrove:Add(function()
			if obj and type(obj.destroy) == "function" then
				pcall(obj.destroy, obj)
			elseif root.Parent then
				root:Destroy()
			end
		end)
	else
		self._cardSource = "Fallback"
		self._cardObj = nil
		self._cardTrove:Add(fallbackCard(self._cardHolder, car))
	end
end

function CaptureCelebration._playBurst(self: CaptureCelebration, colour: Color3)
	self._burst.Visible = true
	for _, ray in self._rays do
		ray.BackgroundColor3 = colour
		ray.BackgroundTransparency = 0.15
		ray.Size = UDim2.fromOffset(10, 40)
		Motion.tween(ray, "ray", Motion.info(0.55), {
			Size = UDim2.fromOffset(6, 190),
			BackgroundTransparency = 1,
		})
	end
end

function CaptureCelebration._playConfetti(self: CaptureCelebration, origin: Vector2, colours: { Color3 })
	local rng = Random.new(self._plays)
	for i, piece in self._confetti do
		piece.BackgroundColor3 = colours[(i - 1) % #colours + 1]
		piece.Position = UDim2.fromOffset(origin.X, origin.Y)
		piece.Rotation = rng:NextNumber(-30, 30)
		piece.BackgroundTransparency = 0
		piece.Visible = true
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(70, 150)
		local target = origin + Vector2.new(math.cos(angle) * dist, math.sin(angle) * dist * 0.6 + 60)
		local t = Motion.tween(piece, "fly", Motion.info(rng:NextNumber(0.8, 1.1), Enum.EasingStyle.Quad), {
			Position = UDim2.fromOffset(target.X, target.Y),
			Rotation = piece.Rotation + rng:NextNumber(-160, 160),
			BackgroundTransparency = 1,
		})
		t.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				piece.Visible = false
			end
		end)
	end
end

function CaptureCelebration._fadeHeadline(self: CaptureCelebration)
	local h = self._headline
	h.TextTransparency = 1
	Motion.tween(h, "fade", Motion.info(0.2), { TextTransparency = 0 })
	for _, child in h:GetChildren() do
		if child:IsA("UIStroke") then
			child.Transparency = 1
			Motion.tween(child, "fade", Motion.info(0.2), { Transparency = 0 })
		end
	end
end

-- Plays the celebration for a confirmed car (the store event calls this).
function CaptureCelebration.play(self: CaptureCelebration, input: Store.CarRef)
	-- the event confirms the claim, so the reveal shows the car as owned (never as a silhouette)
	local car = table.clone(input)
	car.owned = true
	self._token += 1
	local token = self._token
	self:_stopMotion()
	self._plays += 1
	self._car = car
	self._playing = true
	self._slot.claim(OWNER, PRIORITY)
	Sounds.play("KeysCapture")
	self:layout()
	local reduced = Motion.reduced()
	local r = rarityOf(car)
	local fits = self:_cardFits()
	if fits then
		self._mode = "Card"
		self._ribbon.Visible = false
		self:_buildCard(car)
		local holder = self._cardHolder
		holder.Visible = true
		self._headline.Visible = true
		if reduced then
			holder.Rotation = 0
			self._cardScale.Scale = 1
			-- calm version: a short fade, no movement
			self:_fadeHeadline()
		else
			holder.Rotation = TILT
			self._cardScale.Scale = 0.6
			Motion.tween(holder, "tilt", Motion.info(0.45, Enum.EasingStyle.Back), { Rotation = 0 })
			Motion.tween(self._cardScale, "reveal", Motion.info(0.35, Enum.EasingStyle.Back), { Scale = 1 })
			Motion.pop(self._headline, 1.1)
			self:_playBurst(r.light)
			local rect = self._cardRect :: RunLayout.Rect
			self:_playConfetti(rect.pos + rect.size / 2, { r.light, r.deep, C.KeysLight, C.White })
		end
	else
		-- compact ribbon now, expanded card deferred to Results
		self._mode = "Ribbon"
		table.insert(self._pending, car)
		self._cardTrove:Clean()
		self._cardHolder.Visible = false
		self._headline.Visible = false
		self._ribbon.Visible = true
		self._ribbonText.Text = "YOU GOT THE KEYS!  " .. car.name
		if reduced then
			self._ribbon.GroupTransparency = 1
			Motion.tween(self._ribbon, "fade", Motion.info(0.2), { GroupTransparency = 0 })
		else
			self._ribbon.GroupTransparency = 0
			Motion.pop(self._ribbon, 1.08)
		end
	end
	task.delay(if reduced then SECONDS_REDUCED else SECONDS, function()
		if token == self._token then
			self:dismiss()
		end
	end)
end

function CaptureCelebration.dismiss(self: CaptureCelebration)
	self._token += 1
	if not self._playing then
		return
	end
	self._playing = false
	self:_stopMotion()
	self._headline.Visible = false
	self._ribbon.Visible = false
	self._cardHolder.Visible = false
	self._cardHolder.Rotation = 0
	self._cardScale.Scale = 1
	self._cardTrove:Clean()
	self._mode = "None"
	self._slot.release(OWNER)
end

function CaptureCelebration.pendingCards(self: CaptureCelebration): { Store.CarRef }
	return table.clone(self._pending)
end

function CaptureCelebration.takePendingCards(self: CaptureCelebration): { Store.CarRef }
	local out = self._pending
	self._pending = {}
	return out
end

function CaptureCelebration.setVisible(self: CaptureCelebration, on: boolean)
	self._visible = on
	self.root.Visible = on
	if not on then
		self:dismiss()
	end
end

function CaptureCelebration.getDebugState(self: CaptureCelebration): { [string]: any }
	local fits, conflict = self:_cardFits()
	local rays = 0
	for _, ray in self._rays do
		if ray.BackgroundTransparency < 1 then
			rays += 1
		end
	end
	local confetti = 0
	for _, p in self._confetti do
		if p.Visible then
			confetti += 1
		end
	end
	local rect = self._cardRect
	local pendingNames = {}
	for _, c in self._pending do
		table.insert(pendingNames, c.name)
	end
	return {
		visible = self._visible,
		playing = self._playing,
		mode = self._mode,
		car = self._car and (self._car :: Store.CarRef).name,
		plays = self._plays,
		cardFits = fits,
		cardConflict = conflict,
		cardBox = rect and RunLayout.describe(rect),
		cardSource = self._cardSource,
		cardRotation = self._cardHolder.Rotation,
		raysActive = rays,
		raysPool = #self._rays,
		confettiActive = confetti,
		confettiPool = #self._confetti,
		pendingCards = pendingNames,
		ribbonBox = RunLayout.describe(self:_ribbonRect()),
		ribbonOverlapsLandingView = RunLayout.overlaps(self:_ribbonRect(), RunLayout.landingBand(self._ctx)),
		slotHolder = self._slot.holder(),
		reducedMotion = Motion.reduced(),
	}
end

function CaptureCelebration.destroy(self: CaptureCelebration)
	self._trove:Destroy()
end

return CaptureCelebration
