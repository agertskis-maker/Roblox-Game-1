--!strict
-- UpgradeCard.RacewayCard (Lane 3 Round 8, U-01, U-03, U-04, U-05; built to R8-IMG-01 / 02 / 03): the RACEWAY LEVEL card, opened by
-- the Raceway shop prompt through ShopPanel. A glossy racetrack frame, a chequered-flag title ribbon "RACEWAY LEVEL <n>", a trackside
-- window with the ACTUAL pieces of the next level (NextLevelView), the stat pill "LAP PAY x<now> -> x<next>", 2 to 4 "NEW AT NEXT
-- LEVEL" chips from the real level data (Look.Features that start at the next level), one flag pip per level, the glossy UPGRADE
-- button with the Cash icon and price (cannot afford: grey "NEED $X MORE" and a green "+"; top level: the MAX LEVEL rosette;
-- buying: pressed in with a spinner, one press only), a red X (44 real px minimum) and a dark see-through backing. All words and
-- numbers are live TextLabels; all pictures are R8Kit pieces (AssetIds.UpgradeCards art, code-drawn until uploaded).
--
-- Server authority: the card only asks. BUY calls source.buy(target); the beta's remote BuyRacewayLevel takes NO arguments, the
-- server checks the Cash, prices it (src/shared/UI/EconomyPreview.racewayPrice, the same table the card shows) and answers
-- BetaResult(what, ok, reason, missing). A refusal shows the server's reason as one short red line and never takes Cash; the
-- "NEED $X MORE" amount is the server's Cash attribute (Host.cashOf) against the server's price, or the server's `missing`.
--
-- The upgrade moment (U-05): the button turns into the gold "LEVEL n!" stamp, confetti bursts from it, the flag pip pops, a
-- fanfare plays (Sounds "Unlock" and "Milestone"), the card flashes; after about a second the card fades out while the Raceway
-- reveal (Reveal.luau: camera ease, scale-up build-in with dust, the banner) plays. Reduce Motion: no confetti, pop, flash or camera
-- move; the stamp and the sound stay.
--
-- Contract: UpgradeCard/CardTypes.luau (open, close, isOpen, plot, refresh, state).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Speedway = Shared:WaitForChild("Island"):WaitForChild("Speedway")
local Ladder = require(Speedway:WaitForChild("Ladder"))
local Look = require(Speedway:WaitForChild("Look"))
local EconomyPreview = require(Shared:WaitForChild("UI"):WaitForChild("EconomyPreview"))
local Format = require(Shared:WaitForChild("UI"):WaitForChild("Format"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local Prototype: any = script.Parent.Parent.Parent.Parent.Parent.UI.Prototype
local Kit: any = Prototype.R8Kit
local Calm = require(Kit.Calm) :: () -> boolean
local Build = require(Kit.Build)
local Chip = require(Kit.Chip)
local CloseButton = require(Kit.CloseButton)
local GlossButton = require(Kit.GlossButton)
local KerbFrame = require(Kit.KerbFrame)
local Metrics = require(Kit.Metrics)
local Palette = require(Kit.Palette)
local Pips = require(Kit.Pips)
local PreviewWindow = require(Kit.PreviewWindow)
local RibbonTitle = require(Kit.RibbonTitle)
local StatPill = require(Kit.StatPill)
local Sounds = require(Prototype.Sounds)

local CardHost = require(script.Parent.CardHost)
local CardTypes = require(script.Parent.CardTypes)
local NextLevelView = require(script.Parent.NextLevelView)
local Reveal = require(script.Parent.Parent.Reveal)

local RacewayCard = {}

type Source = CardTypes.Source
type Host = CardTypes.Host

-- Design pixels = the reference image's own pixels, card-relative (R8-IMG-01 measured at 1672 x 941: the card is 988 x 527).
local DESIGN = Vector2.new(988, 527)
local MARGIN_X, MARGIN_TOP, MARGIN_BOTTOM = 60, 70, 40
local HOLDER = Vector2.new(DESIGN.X + 2 * MARGIN_X, DESIGN.Y + MARGIN_TOP + MARGIN_BOTTOM)
local VISUAL_H = 600 -- the card with its ribbon, for the height fit
local COMPACT_SHORT_SIDE = 500 -- a phone: the card takes more of the screen width (R8-IMG-03: 86 %)

local LAYOUT = {
	-- a desktop or tablet card
	wide = { colX = 500, colW = 443, bezelW = 439, chipH = 106 },
	-- a phone: a narrower window, a wider right column, so chips and the button can keep 16 real px text
	compact = { colX = 466, colW = 477, bezelW = 399, chipH = 112 },
}

local DISPLAY_ORDER = 18 -- below the level banner at 20
local SCRIM_TRANSPARENCY = 0.5
local POP_FROM = 0.96
local LOCK_TIMEOUT = 6
local HOLD_SECONDS = 1.7 -- how long Reveal waits for the card's celebration
local CELEBRATE_SECONDS = 1.2
local ERROR_SECONDS = 5
local ACTION_NAME = "Lane3RacewayPanelClose"
local NEAR_END = 0.25 -- seconds between Cash checks

local NAVY = Palette.Navy
local CONFETTI = {
	Palette.RedBright,
	Palette.GoldBright,
	Palette.Green,
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(255, 120, 190),
}

-- The chips (U-01): what level N adds, read from the Look features that start at level N. Name -> label, picture.
local CHIP_OF: { [string]: { string } } = {
	Rope = { "Rope fence", "rope" },
	Pennants = { "Pennants", "pennants" },
	StartBoard = { "Start board", "startboard" },
	EarlyKerbs = { "Kerbs", "kerbs" },
	Bleachers = { "Bleachers", "bleachers" },
	SnackCart = { "Snack cart", "snackcart" },
	LapBoard = { "Lap board", "lapboard" },
	AsphaltFlat = { "Asphalt", "asphalt" },
	TyreWallOval = { "Tyre wall", "tyrewall" },
	BleachersFull = { "Crowd", "crowd" },
	Official = { "Flag official", "official" },
	StartLights = { "Start lights", "startlights" },
	FlagLine = { "Flag line", "flagline" },
	PitGarage = { "Pit garage", "pitgarage" },
	Marshals = { "Marshals", "marshals" },
	Grandstand = { "Grandstand", "grandstand" },
	Announcer = { "Announcer", "announcer" },
	Floodlights = { "Floodlights", "floodlights" },
	Gantry = { "Start gantry", "gantry" },
	BigScreen = { "Big screen", "bigscreen" },
	LightStripMain = { "Light strips", "lightstrip" },
	AsphaltBanked = { "Banked road", "asphalt" },
	BankWallNear = { "Banked turns", "banked" },
	TyreWallStraights = { "Tyre walls", "tyrewall" },
	TyreWallGround = { "Tyre walls", "tyrewall" },
	FarCurveRaised = { "Raised turn", "raised" },
	Descent = { "Ramp down", "ramp" },
	GrandstandFull = { "Packed stands", "crowd" },
	Hump = { "Jump hump", "hump" },
	Blimp = { "Blimp", "blimp" },
	Loop = { "Loop", "loop" },
	Statue = { "Statue", "statue" },
	SkyBeams = { "Sky beams", "skybeams" },
	Cannons = { "Fireworks", "fireworks" },
	Roof = { "Roof", "roof" },
}
-- the best first: the order chips are picked in when a level adds more than four things
local CHIP_ORDER = {
	"BleachersFull",
	"Bleachers",
	"Grandstand",
	"GrandstandFull",
	"Gantry",
	"Loop",
	"Statue",
	"FarCurveRaised",
	"BankWallNear",
	"Hump",
	"Blimp",
	"Floodlights",
	"BigScreen",
	"PitGarage",
	"Official",
	"Announcer",
	"StartLights",
	"SkyBeams",
	"Cannons",
	"LightStripMain",
	"Descent",
	"FlagLine",
	"Marshals",
	"SnackCart",
	"LapBoard",
	"Rope",
	"Pennants",
	"StartBoard",
	"EarlyKerbs",
	"TyreWallOval",
	"AsphaltFlat",
	"TyreWallGround",
	"TyreWallStraights",
	"AsphaltBanked",
	"Roof",
}

export type ChipSpec = { label: string, icon: string }

-- Up to four chips for what level `level` adds (at least two for every level 2 to 12). Public so the self-test can check it.
function RacewayCard.chipsFor(level: number): { ChipSpec }
	local starts: { [string]: boolean } = {}
	for _, feature in Look.Features do
		if feature.from == level then
			starts[feature.name] = true
		end
	end
	local out: { ChipSpec } = {}
	local seen: { [string]: boolean } = {}
	for _, name in CHIP_ORDER do
		local chip = CHIP_OF[name]
		if starts[name] and chip and not seen[chip[1]] then
			seen[chip[1]] = true
			table.insert(out, { label = chip[1], icon = chip[2] })
			if #out == 4 then
				break
			end
		end
	end
	return out
end

type Card = {
	source: Source,
	host: Host,
	root: Trove.Trove, -- everything the card made
	live: Trove.Trove, -- watchers and the input binding (cleaned when the card starts to leave)
	content: Trove.Trove, -- the card's pieces (rebuilt when the profile changes)
	gui: ScreenGui,
	scrim: Frame,
	holder: Frame,
	viewScale: UIScale,
	fade: CanvasGroup,
	pop: UIScale,
	metrics: any,
	compact: boolean,
	kerb: any,
	ribbon: any,
	closeButton: any,
	preview: any,
	view: any,
	pill: any,
	header: TextLabel,
	headerLines: { Frame },
	chips: { any },
	chipTrove: Trove.Trove,
	pips: any,
	button: any,
	footnote: TextLabel,
	errorLabel: TextLabel,
	flash: Frame,
	fx: Frame,
	shown: number,
	max: number,
	locked: boolean,
	celebrating: boolean,
	target: number,
	lockedAt: number,
	buttonKey: string,
	missing: number?,
	errorToken: number,
	leaving: boolean,
	destroyed: boolean,
	nextCheck: number,
	tweens: { [Tween]: boolean },
	removeResult: (() -> ())?,
}

local active: Card? = nil
local leaving: Card? = nil

----------------------------------------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------------------------------------

local function tweenInfo(seconds: number): TweenInfo
	return TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

-- A tween the card owns: cancelled when the card closes.
local function play(
	card: Card,
	instance: Instance,
	info: TweenInfo,
	goals: { [string]: any },
	onDone: (() -> ())?
): Tween
	local tween = TweenService:Create(instance, info, goals)
	card.tweens[tween] = true
	tween.Completed:Once(function(state: Enum.PlaybackState)
		card.tweens[tween] = nil
		tween:Destroy()
		if state == Enum.PlaybackState.Completed and onDone then
			onDone()
		end
	end)
	tween:Play()
	return tween
end

local function cancelTweens(card: Card)
	local running: { Tween } = {}
	for tween in card.tweens do
		table.insert(running, tween)
	end
	for _, tween in running do
		tween:Cancel()
	end
end

local function safeCurrent(card: Card): number
	local ok, value = pcall(card.source.current)
	if ok and type(value) == "number" then
		return math.clamp(math.floor(value), Ladder.MinLevel, Ladder.MaxLevel)
	end
	return card.shown
end

-- A failing check counts as busy: the card then waits, and the lock timeout ends the wait.
local function safeBusy(card: Card): boolean
	local ok, value = pcall(card.source.busy)
	return not ok or value == true
end

-- The Cash still missing for the next level, from the numbers (0 = can afford; nil = no Cash source to compare with).
local function shortBy(card: Card): number?
	local price = EconomyPreview.racewayPrice(card.shown + 1)
	local ok, cash = pcall(card.host.cashOf)
	if not (price and ok and type(cash) == "number") then
		return nil
	end
	return math.max(0, price - cash)
end

local function selectionInside(card: Card): boolean
	local selected = GuiService.SelectedObject
	return selected ~= nil and selected:IsDescendantOf(card.gui)
end

local function destroyCard(card: Card)
	if card.destroyed then
		return
	end
	card.destroyed = true
	cancelTweens(card)
	card.live:Clean()
	if card.removeResult then
		card.removeResult()
		card.removeResult = nil
	end
	if selectionInside(card) then
		GuiService.SelectedObject = nil
	end
	card.metrics:destroy()
	card.root:Destroy()
	if active == card then
		active = nil
	end
	if leaving == card then
		leaving = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Content
----------------------------------------------------------------------------------------------------

local function buttonSpec(card: Card): (string, { [string]: any })
	if card.shown >= card.max then
		return "max", { maxText = "MAX LEVEL", maxStyle = "rosette" }
	end
	local price = EconomyPreview.racewayPrice(card.shown + 1)
	local info: { [string]: any } =
		{ label = "UPGRADE", price = if price then Format.cash(price) else "?", icon = "cash" }
	if card.locked then
		return "busy", info
	end
	if card.source.buy == nil then
		return "disabled", { label = "UPGRADE" }
	end
	local short = shortBy(card)
	if card.missing and card.missing > 0 then
		short = card.missing
	end
	if short and short > 0 then
		info.need = Format.cash(short)
		return "need", info
	end
	return "buy", info
end

-- Sets the button to match the card (only when something changed, so the spinner and the shine are not restarted every check).
local function refreshButton(card: Card)
	if card.celebrating or card.destroyed then
		return
	end
	local state, info = buttonSpec(card)
	local key = state .. "|" .. tostring(info.need) .. "|" .. tostring(info.price)
	if key == card.buttonKey then
		return
	end
	card.buttonKey = key
	card.button:setState(state, info)
end

local function headerWidth(text: string, size: number): number
	return #text * 0.58 * size
end

-- Everything that depends on the shown level.
local function render(card: Card)
	local level = card.shown
	local atMax = level >= card.max
	card.ribbon:setText(string.format("RACEWAY LEVEL %d", level))
	if atMax then
		card.pill:setValues(nil, Ladder.lapPayText(level))
	else
		card.pill:setValues(Ladder.lapPayText(level), Ladder.lapPayText(level + 1))
	end
	-- the chips: what the next level adds (at the top: what the Raceway has now)
	local shownLevel = if atMax then level else level + 1
	card.chipTrove:Clean()
	table.clear(card.chips)
	local specs = RacewayCard.chipsFor(shownLevel)
	local layout = if card.compact then LAYOUT.compact else LAYOUT.wide
	local n = math.max(#specs, 1)
	local gap = 11
	local w = (layout.colW - gap * (n - 1)) / n
	for i, spec in specs do
		local chip = Chip.new(card.kerb.content, {
			label = spec.label,
			icon = spec.icon,
			size = UDim2.fromOffset(w, layout.chipH),
			position = UDim2.fromOffset(layout.colX + (i - 1) * (w + gap), 206),
			zIndex = 1,
			metrics = card.metrics,
		})
		card.chipTrove:Add(chip, "destroy")
		table.insert(card.chips, chip)
	end
	local headerText = if atMax then "FULLY UPGRADED" else "NEW AT NEXT LEVEL"
	card.header.Text = headerText
	local half = headerWidth(headerText, card.metrics:textSize(22)) / 2 + 12
	local mid = layout.colW / 2
	card.headerLines[1].Size = UDim2.fromOffset(math.max(mid - half - 4, 0), 3)
	card.headerLines[1].Position = UDim2.fromOffset(layout.colX + 2, 190)
	card.headerLines[2].Size = UDim2.fromOffset(math.max(mid - half - 4, 0), 3)
	card.headerLines[2].Position = UDim2.fromOffset(layout.colX + layout.colW - 2 - math.max(mid - half - 4, 0), 190)
	card.pips:set(level)
	card.preview:setTag(if atMax then "MAX LEVEL" else "NEXT LEVEL")
	card.view:setLevel(shownLevel)
	card.buttonKey = ""
	refreshButton(card)
end

local function showError(card: Card, text: string)
	card.errorToken += 1
	local token = card.errorToken
	card.errorLabel.Text = text
	card.errorLabel.Visible = true
	card.footnote.Visible = false
	task.delay(ERROR_SECONDS, function()
		if card.errorToken == token and not card.destroyed then
			card.errorLabel.Visible = false
			card.footnote.Visible = true
		end
	end)
end

-- The glossy confetti that bursts from the button: little rectangles flung out and down (design px, inside the card).
local function confetti(card: Card, origin: Vector2)
	for i = 1, 34 do
		local angle = math.rad(math.random(200, 340))
		local reach = math.random(110, 300)
		local piece: Frame = Build.make("Frame", {
			Name = "Confetti",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(origin.X, origin.Y),
			Size = UDim2.fromOffset(math.random(9, 16), math.random(6, 10)),
			BackgroundColor3 = CONFETTI[(i % #CONFETTI) + 1],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 10,
			Parent = card.fx,
		})
		local out = Vector2.new(math.cos(angle) * reach, math.sin(angle) * reach)
		play(card, piece, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(origin.X + out.X, origin.Y + out.Y),
			Rotation = piece.Rotation + math.random(-260, 260),
		}, function()
			play(card, piece, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(origin.X + out.X * 1.15, origin.Y + out.Y + 190),
				BackgroundTransparency = 1,
			}, function()
				piece:Destroy()
			end)
		end)
		task.delay(1.6, function()
			if piece.Parent then
				piece:Destroy()
			end
		end)
	end
end

-- The just-upgraded moment (U-05).
local function celebrate(card: Card, newLevel: number)
	card.locked = false
	card.celebrating = true
	card.missing = nil
	card.shown = newLevel
	render(card)
	card.button:setState("done", { doneText = string.format("LEVEL %d!", newLevel), doneTone = "gold" })
	pcall(Sounds.play, "Unlock")
	pcall(Sounds.play, "Milestone")
	local calm = Calm()
	if not calm then
		card.pips:pop(newLevel)
		local layout = if card.compact then LAYOUT.compact else LAYOUT.wide
		confetti(card, Vector2.new(layout.colX + layout.colW / 2, 424))
		card.flash.BackgroundTransparency = 0.45
		play(card, card.flash, tweenInfo(0.4), { BackgroundTransparency = 1 })
	end
	-- the card leaves just before the Raceway's reveal starts (Reveal holds it for the celebration)
	local wait = math.max(if calm then 0.9 else CELEBRATE_SECONDS, Reveal.holdRemaining() - 0.2)
	task.delay(wait, function()
		if active == card and card.celebrating then
			RacewayCard.close()
		end
	end)
end

local function onPressed(card: Card)
	if active ~= card or card.locked or card.celebrating then
		return
	end
	local buy = card.source.buy
	if buy == nil then
		return
	end
	-- the button went busy by itself on the press: every early return must put it back, so the key is cleared first
	local current = safeCurrent(card)
	if current ~= card.shown or current >= card.max or safeBusy(card) then
		card.buttonKey = ""
		refreshButton(card)
		return
	end
	local short = shortBy(card)
	if short and short > 0 then
		card.buttonKey = ""
		refreshButton(card)
		return
	end
	card.locked = true
	card.target = card.shown + 1
	card.lockedAt = os.clock()
	card.errorToken += 1
	card.errorLabel.Visible = false
	card.footnote.Visible = true
	-- the Raceway reveal waits for the celebration, and the camera follows it (own upgrade only)
	Reveal.hold(HOLD_SECONDS, true)
	card.buttonKey = ""
	refreshButton(card)
	local ok, err = pcall(buy, card.target)
	if not ok then
		warn("Raceway card: the purchase request failed: " .. tostring(err))
	end
end

local function onPlus(card: Card)
	if active ~= card or card.celebrating then
		return
	end
	local open = card.host.onCashShop
	if open then
		RacewayCard.close(true)
		open()
	else
		showError(card, "Get more Cash in the Shop.")
	end
end

local function tooFar(card: Card): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - card.source.anchor.Position).Magnitude > card.host.closeDistance
end

local function step(card: Card)
	if active ~= card then
		return
	end
	if tooFar(card) then
		RacewayCard.close()
		return
	end
	if card.locked and not card.celebrating then
		local current = safeCurrent(card)
		if current > card.shown then
			celebrate(card, current)
		elseif os.clock() - card.lockedAt >= LOCK_TIMEOUT then
			-- the server never answered: back to Idle, re-read the world
			card.locked = false
			Reveal.cancelHold()
			card.buttonKey = ""
			refreshButton(card)
		end
		return
	end
	if card.celebrating then
		return
	end
	local now = os.clock()
	if now >= card.nextCheck then
		card.nextCheck = now + NEAR_END
		local current = safeCurrent(card)
		if current ~= card.shown then
			card.shown = current
			render(card)
		else
			refreshButton(card)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Layout and building
----------------------------------------------------------------------------------------------------

-- STUDIO TEST HOOK: the LocalPlayer attribute Lane3ScreenProfile ("PhoneLandscape", "Tablet") lays the card out for that screen
-- (the viewport and the notch insets of Prototype/Screen's profiles), centred in the real window, so the phone card can be
-- checked at its true pixel size. Studio only; ignored in a live game.
local STUDIO_PROFILES: { [string]: { size: Vector2, pad: Vector2 } } = {
	PhoneLandscape = { size = Vector2.new(844, 390), pad = Vector2.new(94, 0) },
	Tablet = { size = Vector2.new(1180, 820), pad = Vector2.new(0, 78) },
}

local function computeScale(card: Card): (number, boolean)
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else card.gui.AbsoluteSize
	local avail = card.gui.AbsoluteSize
	if avail.X <= 0 or avail.Y <= 0 then
		avail = viewport
	end
	local player = Players.LocalPlayer
	local profile = if RunService:IsStudio() and player then player:GetAttribute("Lane3ScreenProfile") else nil
	local emulated = if type(profile) == "string" then STUDIO_PROFILES[profile] else nil
	if emulated then
		viewport = emulated.size
		avail = emulated.size - emulated.pad
	end
	local compact = math.min(viewport.X, viewport.Y) < COMPACT_SHORT_SIDE
	local widthShare = if compact then 0.86 else 0.62
	local scale = math.min(widthShare * avail.X / DESIGN.X, 0.95 * avail.Y / VISUAL_H)
	return math.max(scale, 0.2), compact
end

-- A point on a rounded rectangle of size (w, h) with corner radius r, `d` px along it from the middle of the top edge going right,
-- and the heading of the car there in degrees (0 = right, 90 = down).
local RING_MID, RING_RADIUS = 18, 40
local RING_START = 0
local function ringPoint(d: number, w: number, h: number, r: number): (number, number, number)
	local sw, sh = w - 2 * r, h - 2 * r
	local arc = math.pi * r / 2
	local perimeter = 2 * (sw + sh) + 4 * arc
	d = (d + sw / 2) % perimeter
	if d < sw then
		return r + d, 0, 0
	end
	d -= sw
	if d < arc then
		local a = d / r
		return w - r + r * math.sin(a), r - r * math.cos(a), math.deg(a)
	end
	d -= arc
	if d < sh then
		return w, r + d, 90
	end
	d -= sh
	if d < arc then
		local a = d / r
		return w - r + r * math.cos(a), h - r + r * math.sin(a), 90 + math.deg(a)
	end
	d -= arc
	if d < sw then
		return w - r - d, h, 180
	end
	d -= sw
	if d < arc then
		local a = d / r
		return r - r * math.sin(a), h - r + r * math.cos(a), 180 + math.deg(a)
	end
	d -= arc
	if d < sh then
		return 0, h - r - d, 270
	end
	d -= sh
	local a = d / r
	return r - r * math.cos(a), r - r * math.sin(a), 270 + math.deg(a)
end

local function buildContent(card: Card)
	card.content:Clean()
	card.chipTrove:Clean()
	table.clear(card.chips)
	local layout = if card.compact then LAYOUT.compact else LAYOUT.wide
	local metrics = card.metrics
	local kerb = KerbFrame.new(card.pop.Parent, {
		kind = "kerb",
		size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
		position = UDim2.fromOffset(MARGIN_X, MARGIN_TOP),
		zIndex = 2,
		metrics = metrics,
	})
	card.content:Add(kerb, "destroy")
	card.kerb = kerb
	local root: Frame = kerb.content

	-- the trackside window with the next level's pieces
	local preview = PreviewWindow.new(root, {
		size = UDim2.fromOffset(layout.bezelW, 372),
		position = UDim2.fromOffset(49, 88),
		tag = "NEXT LEVEL",
		zIndex = 1,
		metrics = metrics,
	})
	card.content:Add(preview, "destroy")
	card.preview = preview
	card.view = NextLevelView.new(preview.content, card.source.plot)
	card.content:Add(card.view, "destroy")

	-- the stat pill
	local pill = StatPill.new(root, {
		caption = "LAP PAY",
		size = UDim2.fromOffset(layout.colW, 97),
		position = UDim2.fromOffset(layout.colX, 73),
		zIndex = 1,
		metrics = metrics,
	})
	card.content:Add(pill, "destroy")
	card.pill = pill

	-- the "NEW AT NEXT LEVEL" header between two thin lines
	local header = Build.label(root, "Header", "", {
		Position = UDim2.fromOffset(layout.colX, 177),
		Size = UDim2.fromOffset(layout.colW, 26),
		TextColor3 = NAVY,
		ZIndex = 1,
	})
	metrics:bindText(card.content, header, 22)
	card.header = header
	card.headerLines = {}
	for i = 1, 2 do
		local line: Frame = Build.make("Frame", {
			Name = "HeaderLine" .. i,
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = root,
		})
		Build.corner(line, UDim.new(0.5, 0))
		card.headerLines[i] = line
	end

	-- the flag pips
	local pips = Pips.new(root, {
		count = card.max,
		filled = card.shown,
		size = UDim2.fromOffset(layout.colW - 27, 34),
		position = UDim2.fromOffset(layout.colX + 14, 326),
		zIndex = 1,
		metrics = metrics,
	})
	card.content:Add(pips, "destroy")
	card.pips = pips

	-- the button
	local button = GlossButton.new(root, {
		size = UDim2.fromOffset(layout.colW, 103),
		position = UDim2.fromOffset(layout.colX, 372),
		zIndex = 2,
		metrics = metrics,
		label = "UPGRADE",
	})
	card.content:Add(button, "destroy")
	card.button = button
	card.content:Add(button.Pressed:Connect(function()
		onPressed(card)
	end))
	card.content:Add(button.PlusPressed:Connect(function()
		onPlus(card)
	end))

	-- the small grey "PREVIEW prices" line, and the short red line that replaces it when the server says no
	local footnote = Build.label(root, "Footnote", "PREVIEW prices", {
		Position = UDim2.fromOffset(64, 464),
		Size = UDim2.fromOffset(380, 28),
		TextColor3 = Color3.fromRGB(108, 116, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 1,
	})
	metrics:bindText(card.content, footnote, 22)
	card.footnote = footnote
	local errorLabel = Build.label(root, "ErrorLine", "", {
		Position = UDim2.fromOffset(64, 464),
		Size = UDim2.fromOffset(380, 28),
		TextColor3 = Palette.Danger,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		ZIndex = 1,
	})
	metrics:bindText(card.content, errorLabel, 22)
	card.errorLabel = errorLabel

	-- the ribbon and the close button sit on top of the frame
	local ribbon = RibbonTitle.new(root, {
		text = "RACEWAY LEVEL 1",
		size = UDim2.fromOffset(702, 103),
		position = UDim2.fromOffset(144, -47),
		zIndex = 5,
		metrics = metrics,
	})
	card.content:Add(ribbon, "destroy")
	card.ribbon = ribbon
	local close = CloseButton.new(root, {
		size = 80,
		position = UDim2.fromOffset(889, -27),
		zIndex = 6,
		metrics = metrics,
	})
	card.content:Add(close, "destroy")
	card.closeButton = close
	card.content:Add(close.Pressed:Connect(function()
		RacewayCard.close()
	end))

	-- the little car lapping the frame (U-01, the Round 7 idea kept): along the kerb ring, round its rounded corners
	-- (Reduce Motion: it waits on the start line at the top)
	local car: Frame = Build.make("Frame", {
		Name = "LapCar",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(36, 19),
		BackgroundColor3 = Color3.fromRGB(255, 150, 30),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = root,
	})
	Build.corner(car, UDim.new(0, 7))
	Build.stroke(car, 3, NAVY)
	local cabin: Frame = Build.make("Frame", {
		Name = "Cabin",
		Position = UDim2.fromOffset(15, 3),
		Size = UDim2.fromOffset(11, 13),
		BackgroundColor3 = Color3.fromRGB(150, 210, 255),
		BorderSizePixel = 0,
		Parent = car,
	})
	Build.corner(cabin, UDim.new(0, 3))
	for _, y in { -3, 14 } do
		local wheel: Frame = Build.make("Frame", {
			Name = "Wheel",
			Position = UDim2.fromOffset(6, y),
			Size = UDim2.fromOffset(9, 7),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = car,
		})
		Build.corner(wheel, UDim.new(0, 2))
	end
	local started = os.clock()
	local function place(distance: number)
		local x, y, heading = ringPoint(distance, DESIGN.X - 2 * RING_MID, DESIGN.Y - 2 * RING_MID, RING_RADIUS)
		car.Position = UDim2.fromOffset(x + RING_MID, y + RING_MID)
		car.Rotation = heading
	end
	place(RING_START)
	card.content:Add(RunService.Heartbeat:Connect(function()
		if not Calm() then
			place(RING_START + (os.clock() - started) * 150)
		end
	end))

	-- the flash and the confetti layer
	local flash: Frame = Build.make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = root,
	})
	Build.corner(flash, UDim.new(0, 55))
	card.flash = flash
	card.fx = Build.make("Frame", {
		Name = "Fx",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = root,
	})
	render(card)
end

local function applyScale(card: Card)
	local scale, compact = computeScale(card)
	card.viewScale.Scale = scale
	card.metrics:setScale(scale)
	if compact ~= card.compact then
		card.compact = compact
		buildContent(card)
	end
end

local function createCard(source: Source, host: Host, playerGui: PlayerGui): Card
	local root = Trove.new()
	-- a phone gives the card the whole height (only the notch is kept clear); anything bigger keeps clear of the top bar too
	local camera = Workspace.CurrentCamera
	local phone = camera ~= nil and math.min(camera.ViewportSize.X, camera.ViewportSize.Y) < COMPACT_SHORT_SIDE
	local gui: ScreenGui = Build.make("ScreenGui", {
		Name = "Lane3RacewayPanel",
		ResetOnSpawn = false,
		ScreenInsets = if phone then Enum.ScreenInsets.DeviceSafeInsets else Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = DISPLAY_ORDER,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	root:Add(gui)
	-- the dark see-through backing; visual only (Active false, so it never swallows a touch meant for the thumbstick)
	local scrim: Frame = Build.make("Frame", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 16, 34),
		BackgroundTransparency = SCRIM_TRANSPARENCY,
		BorderSizePixel = 0,
		Active = false,
		Parent = gui,
	})
	local holder: Frame = Build.make("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(HOLDER.X, HOLDER.Y),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local viewScale: UIScale = Build.make("UIScale", { Parent = holder })
	local fade: CanvasGroup = Build.make("CanvasGroup", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = holder,
	})
	local pop: Frame = Build.make("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = fade,
	})
	local popScale: UIScale = Build.make("UIScale", { Parent = pop })
	-- a soft shadow under the card (a navy copy, a little lower)
	local shadow: Frame = Build.make("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(MARGIN_X - 2, MARGIN_TOP + 8),
		Size = UDim2.fromOffset(DESIGN.X + 4, DESIGN.Y + 4),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = pop,
	})
	Build.corner(shadow, UDim.new(0, 62))
	-- a tap on the card is not a tap on the world behind it
	Build.make("TextButton", {
		Name = "Block",
		Position = UDim2.fromOffset(MARGIN_X, MARGIN_TOP),
		Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		ZIndex = 1,
		Parent = pop,
	})
	local metrics = Metrics.new(DESIGN)
	local card: Card = {
		source = source,
		host = host,
		root = root,
		live = Trove.new(),
		content = Trove.new(),
		gui = gui,
		scrim = scrim,
		holder = holder,
		viewScale = viewScale,
		fade = fade,
		pop = popScale,
		metrics = metrics,
		compact = false,
		kerb = nil,
		ribbon = nil,
		closeButton = nil,
		preview = nil,
		view = nil,
		pill = nil,
		header = nil :: any,
		headerLines = {},
		chips = {},
		chipTrove = Trove.new(),
		pips = nil,
		button = nil,
		footnote = nil :: any,
		errorLabel = nil :: any,
		flash = nil :: any,
		fx = nil :: any,
		shown = Ladder.MinLevel,
		max = Ladder.MaxLevel,
		locked = false,
		celebrating = false,
		target = 0,
		lockedAt = 0,
		buttonKey = "",
		missing = nil,
		errorToken = 0,
		leaving = false,
		destroyed = false,
		nextCheck = 0,
		tweens = {},
		removeResult = nil,
	}
	root:Add(card.live)
	root:Add(card.content)
	root:Add(card.chipTrove)
	return card
end

----------------------------------------------------------------------------------------------------
-- Public interface (the card contract)
----------------------------------------------------------------------------------------------------

-- Closes the open card: fades out (0.2 s, or 0.1 s opacity only with Reduce Motion). `instant` destroys at once. Closing never
-- changes any value, and a late server answer is ignored.
function RacewayCard.close(instant: boolean?)
	local card = active
	if card == nil then
		if instant == true and leaving then
			destroyCard(leaving)
		end
		return
	end
	active = nil
	card.locked = false
	card.celebrating = false
	card.live:Clean()
	if card.removeResult then
		card.removeResult()
		card.removeResult = nil
	end
	cancelTweens(card)
	if selectionInside(card) then
		GuiService.SelectedObject = nil
	end
	if leaving then
		destroyCard(leaving)
	end
	if instant == true then
		destroyCard(card)
		return
	end
	leaving = card
	local calm = Calm()
	local info = tweenInfo(if calm then 0.1 else 0.2)
	play(card, card.scrim, info, { BackgroundTransparency = 1 })
	if not calm then
		play(card, card.pop, info, { Scale = POP_FROM })
	end
	play(card, card.fade, info, { GroupTransparency = 1 }, function()
		destroyCard(card)
	end)
end

function RacewayCard.open(source: Source, host: Host)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	local replacing = active ~= nil
	RacewayCard.close(true)
	local card = createCard(source, host, playerGui)
	active = card
	card.shown = safeCurrent(card)
	local scale, compact = computeScale(card)
	card.compact = compact
	card.viewScale.Scale = scale
	card.metrics:setScale(scale)
	buildContent(card)

	-- watchers, all dropped when the card starts to close
	card.live:Connect(RunService.Heartbeat, function()
		step(card)
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		card.live:Connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
			applyScale(card)
		end)
	end
	card.live:Connect(card.gui:GetPropertyChangedSignal("AbsoluteSize"), function()
		applyScale(card)
	end)
	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_name: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				RacewayCard.close()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)
	card.live:Add(function()
		ContextActionService:UnbindAction(ACTION_NAME)
	end)
	-- the server's answer: a refusal is one short red line, and the button reads the real state again
	card.removeResult = CardHost.onResult("BuyRacewayLevel", function(ok: boolean, reason: string?, missing: number?)
		if card.destroyed or active ~= card then
			return
		end
		if ok then
			return -- the new level arrives as the plot's SpeedwayLevel; step() celebrates it
		end
		card.locked = false
		Reveal.cancelHold()
		local text = reason or "Not now."
		if missing and missing > 0 then
			card.missing = missing
			text ..= " " .. Format.cash(missing) .. " more."
		end
		showError(card, text)
		card.buttonKey = ""
		refreshButton(card)
	end)
	-- the world is still showing the last change: BUY waits for it
	if card.shown < card.max and safeBusy(card) then
		card.buttonKey = ""
		refreshButton(card)
	end
	if UserInputService.GamepadEnabled then
		local hit = card.button.frame:FindFirstChild("Hit")
		if hit and hit:IsA("GuiObject") and hit.Interactable then
			GuiService.SelectedObject = hit
		else
			GuiService.SelectedObject = card.closeButton.button
		end
	end

	-- open: fade the card (0.2 s) with a 0.96 -> 1 scale; Reduce Motion: opacity only, 0.1 s
	if replacing then
		return
	end
	local calm = Calm()
	local info = tweenInfo(if calm then 0.1 else 0.2)
	card.fade.GroupTransparency = 1
	card.scrim.BackgroundTransparency = 1
	play(card, card.fade, info, { GroupTransparency = 0 })
	play(card, card.scrim, info, { BackgroundTransparency = SCRIM_TRANSPARENCY })
	if not calm then
		card.pop.Scale = POP_FROM
		play(card, card.pop, info, { Scale = 1 })
	end
end

function RacewayCard.isOpen(): boolean
	return active ~= nil
end

function RacewayCard.plot(): Model?
	local card = active
	return if card then card.source.plot else nil
end

-- Re-reads source.current() and redraws (the world calls it when the level changes). A card in the middle of a purchase leaves it
-- to its own wait, which shows the new level as the celebration.
function RacewayCard.refresh()
	local card = active
	if card == nil or card.locked or card.celebrating then
		return
	end
	local latest = safeCurrent(card)
	if latest ~= card.shown then
		card.shown = latest
		render(card)
	end
end

-- For Studio tests.
function RacewayCard.state(): { [string]: any }
	local card = active
	if card == nil then
		return { open = false, shown = 0, locked = false }
	end
	local chips: { string } = {}
	for _, chip in card.chips do
		table.insert(chips, chip.label.Text)
	end
	local state, info = buttonSpec(card)
	return {
		open = true,
		kind = "upgrade",
		shown = card.shown,
		max = card.max,
		locked = card.locked,
		celebrating = card.celebrating,
		target = card.target,
		button = if card.celebrating then "done" else state,
		need = info.need,
		price = info.price,
		buyEnabled = card.shown < card.max and card.source.buy ~= nil,
		title = card.ribbon.label.Text,
		tag = if card.preview.tag then card.preview.tag.Text else nil,
		header = card.header.Text,
		chips = chips,
		hasScene = card.view.hasScene,
		usesArt = card.kerb.usesArt,
		compact = card.compact,
		scale = card.viewScale.Scale,
		error = if card.errorLabel.Visible then card.errorLabel.Text else nil,
		footnote = card.footnote.Visible,
		pips = card.pips.filled,
	}
end

return RacewayCard
