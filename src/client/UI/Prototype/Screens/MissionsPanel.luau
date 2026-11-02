--!strict
-- MissionsPanel: the Missions and Goals panel opened from the Missions button (Lane 3, big round M13-01; PREVIEW). Rebuilt
-- in Round 3 from the style guide (vault/design/ui-style-guide.md; reference R3-IMG-07-missions) on the CarKit: a dark pit
-- board with bolts and two tabs on top (the open one yellow, the other dark). MISSIONS: up to three chunky light rows, each
-- with a square icon tile (family colour, rays, a big icon), the objective, a progress bar with its count inside it, and the
-- reward as real art with its amount over it. A finished row shows a big green CLAIM! with a pulsing glow. GOALS: the six
-- one-time milestones as a checklist, completed ones ticked and the next one highlighted.
--
--   local panel = MissionsPanel.new(ctx, { onClaim = fn?, onRetry = fn?, onClose = fn?, state = State?,
--                                          previewResolve = "Success" | "Error" | "None"?, onClaimableChanged = fn? })
--   panel:open(returnTo?)  panel:close()  panel:isOpen()  panel:selectTab("Missions" | "Goals")
--   panel:setState(state)  panel:setPreset("OneReady")                  -- MissionFixtures presets
--   panel:pressClaim(id) -> boolean   panel:resolveClaim(id, "Success" | "Error")   -- the claim round trip
--   panel:fixtureRefresh() -> number  -- the explicit "daily refresh" switch (a fixture, never a timer)
--   panel:subscribe(fn) -> disconnect   panel:getState()   panel:topMission()
--   panel:layout()  panel:setVisible(on)  panel:destroy()  panel:getDebugState()  panel:touchReport()
--   MissionsPanel.geometry(designSize) -> Geo
--
-- NOTHING IS GRANTED. CLAIM only moves a card Ready -> Pending and calls options.onClaim(id); the server's answer
-- arrives through resolveClaim. Success shows CLAIMED with the celebration (confetti, the reward art popping and flying up,
-- the Unlock sound), keeps the card visible until that has finished, then replaces it ONCE (BRIEF M13-03a); Error puts the
-- card back to CLAIM with a message. Repeated taps while a claim is pending do nothing (one visual transition, no second
-- request). With no onClaim given the preview resolves a claim to Success after 0.35 s so the whole flow can be seen; pass
-- previewResolve = "None" to hold it. The daily refresh happens only when panel:fixtureRefresh() is called, and it never
-- touches a Ready, Pending or Claimed card (a claimable reward is never erased). A completed Goal never becomes incomplete
-- because of a refresh.
--
-- Every reward shown is PREVIEW: each reward tile carries a small PREVIEW tag, and the amounts and kinds are fixtures.
-- Bars clamp to 0..1 for drawing; a source value that is not a sane number is logged once (SupportKit.fraction).
--
-- Layout: one recipe from the design size (MissionsPanel.geometry), rebuilt when the size changes. Phone landscape (design
-- height under 420) uses short rows with the reward as a small tile and CLAIM! beside it; tablet and desktop use tall rows with
-- CLAIM! overlapping the reward tile as in the reference. Text is never under 14 px and every button face is 48 px or more.
--
-- Motion: the CLAIM! glow and the button breathe with one looping tween each, only on a Ready row while the panel is open
-- and on screen; closing, hiding or a state change cancels them. The confetti is a pool of 24 frames reused by every burst.
-- Reduce Motion (Motion.reduced): no pulse, no confetti, no flying art, no pop; CLAIMED arrives with a plain fade and the
-- replacement is an instant swap.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Fade = require(Prototype.Home.Fade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local GameIcons = require(Prototype.GameIcons)
local MissionFixtures = require(Prototype.SupportFixtures.MissionFixtures)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local Sounds = require(Prototype.Sounds)
local SupportKit = require(script.Parent.SupportKit)

local make = CarKit.make

local MissionsPanel = {}

local MAX_MISSIONS = 3
local PREVIEW_RESOLVE_SECONDS = 0.35
local CLAIM_HOLD = 1.8 -- the claimed card stays until its feedback (0.7 s) has finished, and then a moment more
local CLAIM_HOLD_REDUCED = 0.5
local CONFETTI = 24
local CONFETTI_SECONDS = 0.7

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Row plates: light, so the saturated tile and the reward art are the loudest things in a row.
local PLATE_TOP, PLATE_BOTTOM = rgb(250, 252, 255), rgb(206, 220, 244)
local READY_TOP, READY_BOTTOM = rgb(250, 254, 248), rgb(208, 236, 212) -- a pale tint: the green belongs to the reward, the bar and CLAIM!
local CLAIMED_TOP, CLAIMED_BOTTOM = rgb(232, 244, 236), rgb(196, 218, 204)
local NEXT_TOP, NEXT_BOTTOM = rgb(255, 249, 218), rgb(255, 226, 134)
local INK_SOFT = rgb(66, 84, 124)
local ERROR_INK = rgb(196, 28, 40)
local WELL_SEQ = ColorSequence.new(rgb(26, 40, 78), rgb(11, 19, 42))
local TAB_ON = ColorSequence.new(rgb(255, 230, 74), rgb(255, 176, 26))
local TAB_OFF = ColorSequence.new(CarKit.BezelTop, CarKit.BezelBottom)
local BAR_GOLD = ColorSequence.new(rgb(255, 226, 70), rgb(255, 156, 22))
local BAR_GREEN = ColorSequence.new(CarKit.Green, CarKit.GreenDeep)
local BAR_CALM = ColorSequence.new(rgb(150, 206, 160), rgb(104, 170, 120))
local STAMP_SEQ = ColorSequence.new(rgb(146, 210, 156), rgb(98, 170, 116))
local GLOW_COLOUR = rgb(150, 255, 130)
local GLOW_REST, GLOW_PEAK = 0.55, 0.22
local PULSE = TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local CONFETTI_COLOURS = {
	CarKit.Gold,
	CarKit.Green,
	CarKit.White,
	rgb(255, 84, 170),
	rgb(64, 168, 255),
	CarKit.Orange,
	rgb(176, 120, 255),
}

-- Icon tiles: the old painter name of a fixture's icon -> the art key and the family colour of its tile.
type TileLook = { art: string, family: string }
local TILES: { [string]: TileLook } = {
	HopCar = { art = "hop", family = "Lap" },
	Car = { art = "garage", family = "Wheel" },
	Track = { art = "raceway", family = "Paddock" },
	Coin = { art = "cash", family = "CashGold" },
	Flag = { art = "steer", family = "Trail" },
	Star = { art = "paint", family = "Paint" },
	GarageBook = { art = "garage", family = "Lap" },
	Medal = { art = "goals", family = "Starter" },
	Portal = { art = "portal", family = "Wheel" },
}
local DEFAULT_TILE: TileLook = { art = "missions", family = "Lap" }

-- Reward art: Cash by size (three steps), each cosmetic by its own art. `word` is what the tile shows instead of an amount.
type RewardLook = { art: string, family: string, word: string?, fallback: string }
local COSMETIC: { [string]: RewardLook } = {
	Paint = { art = "art_paint", family = "Paint", word = "PAINT", fallback = "PaintBucket" },
	Decal = { art = "art_decal", family = "Decal", word = "DECAL", fallback = "Decal" },
	Wheel = { art = "art_wheel", family = "Wheel", word = "WHEELS", fallback = "Wheel" },
	Trail = { art = "art_trail", family = "Trail", word = "TRAIL", fallback = "Trail" },
}

local function rewardLook(m: MissionFixtures.Mission): RewardLook
	local kind = m.rewardKind
	local cosmetic = if kind then COSMETIC[kind] else nil
	if cosmetic then
		return cosmetic
	end
	local amount = math.max(m.reward, 0)
	if amount < 300 then
		return { art = "art_cash1", family = "Cash", word = nil, fallback = "Cash" }
	elseif amount < 500 then
		return { art = "art_cash2", family = "CashTeal", word = nil, fallback = "Cash" }
	end
	return { art = "art_cash3", family = "CashGold", word = nil, fallback = "Cash" }
end

-- What the reward tile shows over its art: "+$750" for Cash, the word for a cosmetic.
local function rewardText(m: MissionFixtures.Mission): string
	local look = rewardLook(m)
	return look.word or ("+" .. Format.cash(math.max(m.reward, 0)))
end

-- The largest Display size, down to `least`, at which `text` fits `width` (Bangers runs narrow: about half an em a letter).
local function fitPx(text: string, width: number, most: number, least: number): number
	return math.clamp(math.floor(width / (math.max(#text, 1) * 0.5)), least, most)
end

export type Tab = "Missions" | "Goals"
export type Tier = "Phone" | "Tablet" | "Desktop"

export type Options = {
	onClaim: ((missionId: string) -> ())?,
	onRetry: (() -> ())?,
	onClose: (() -> ())?,
	onClaimableChanged: ((count: number) -> ())?,
	state: MissionFixtures.State?,
	previewResolve: ("Success" | "Error" | "None")?,
}

export type Rect = { x: number, y: number, w: number, h: number }

-- All in design px, inside the panel (0, 0 = its top left). The last five names are the first version's; they keep a meaning
-- (the tab strip, the row, the action) so a caller that read them still gets a sane number.
export type Geo = {
	fit: SupportKit.Fit,
	tier: Tier,
	k: number,
	pw: number,
	ph: number,
	tabsH: number, -- the strip above the board that the tabs stand in
	lap: number, -- how far the open tab laps over the board's top edge
	tabW: number,
	tabX: number, -- the first tab's left edge
	tabStep: number, -- from one tab's left edge to the next
	pad: number,
	gap: number,
	radius: number,
	tileRadius: number,
	list: Rect, -- where the rows (and the Goals list) go
	rowW: number,
	rowH: number,
	inset: number, -- a row's inner margin
	ih: number, -- a row's inner height: the icon tile's side
	hgap: number,
	stacked: boolean, -- tall rows: CLAIM! overlaps the reward tile. Otherwise it sits beside a square reward tile
	rewardW: number,
	btnW: number,
	btnH: number,
	claimPx: number,
	barH: number,
	titlePx: number,
	subPx: number,
	amountPx: number,
	goalH: number,
	headH: number,
	tabY: number,
	cardW: number,
	cardH: number,
	actionW: number,
}

export type CardDebug = {
	id: string,
	visual: string,
	numbers: string,
	action: string,
	sub: string,
	reward: string,
}

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	tab: string,
	load: string,
	cards: { CardDebug },
	goals: { { id: string, done: boolean, next: boolean } },
	claimTaps: number,
	claimRequests: number,
	claimsResolved: number,
	replacements: number,
	refreshes: number,
	message: string,
	instances: number,
}

export type Panel = {
	root: Frame,
	layout: (self: Panel) -> (),
	setVisible: (self: Panel, on: boolean) -> (),
	open: (self: Panel, returnTo: GuiObject?) -> (),
	close: (self: Panel) -> (),
	isOpen: (self: Panel) -> boolean,
	selectTab: (self: Panel, tab: Tab) -> (),
	setState: (self: Panel, state: MissionFixtures.State) -> (),
	setPreset: (self: Panel, name: string) -> boolean,
	pressClaim: (self: Panel, id: string) -> boolean,
	resolveClaim: (self: Panel, id: string, outcome: "Success" | "Error") -> boolean,
	fixtureRefresh: (self: Panel) -> number,
	subscribe: (self: Panel, fn: (MissionFixtures.State) -> ()) -> () -> (),
	getState: (self: Panel) -> MissionFixtures.State,
	topMission: (self: Panel) -> MissionFixtures.Mission?,
	destroy: (self: Panel) -> (),
	getDebugState: (self: Panel) -> DebugState,
	touchReport: (self: Panel) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY -----------------------------------------------------------------------------------

-- One recipe for every size, pure in the design-px viewport. Three rows always fit without scrolling: the rows share the
-- height that is left under the tab strip. Phone landscape is about 750 x 325 (and as small as 573 x 310), a 1024 x 768
-- tablet about 787 x 495, a 1920 x 1080 desktop 1280 x 681.
function MissionsPanel.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local tier: Tier = if ds.Y < 420 or ds.X < 560 then "Phone" elseif ds.X < 1000 then "Tablet" else "Desktop"
	local phone = tier == "Phone"
	local margin = if phone then 4 else 14
	local pw = math.min(ds.X - margin * 2, if phone then 700 elseif tier == "Tablet" then 760 else 880)
	local avail = math.min(ds.Y - margin * 2, if phone then 400 elseif tier == "Tablet" then 540 else 580)
	local k = if phone then 0.8 else math.clamp(math.min(pw / 760, avail / 500), 0.7, 1.3)
	local tabsH = if phone then 44 else math.round(54 * k)
	local lap = if phone then 6 else math.round(9 * k)
	local pad = if phone then 8 else math.round(17 * k) -- room for the board's corner bolts
	local gap = if phone then 5 else math.round(8 * k)
	local topGap = lap + (if phone then 4 else math.round(9 * k))
	local rowMax = if phone then 100 else math.round(136 * k)
	local rowH = math.clamp(math.floor((avail - tabsH - topGap - pad - gap * 2) / 3), 68, rowMax)
	local ph = tabsH + topGap + rowH * 3 + gap * 2 + pad
	local rowW = pw - pad * 2
	local inset = if phone then 5 else math.round(7 * k)
	local ih = rowH - inset * 2
	local stacked = rowH >= 104
	local btnH = if stacked then math.clamp(math.round(ih * 0.44), 52, 72) else math.min(52, ih)
	local rewardW = if stacked then math.clamp(math.round(rowW * 0.26), 150, 232) else ih
	local btnW = if stacked then rewardW - math.round(12 * k) else math.clamp(math.round(rowW * 0.21), 112, 140)
	local radius = if phone then 10 else 14
	local tabW = math.round(pw * 0.36)
	local list: Rect = { x = pad, y = tabsH + topGap, w = rowW, h = rowH * 3 + gap * 2 }
	return {
		fit = fit,
		tier = tier,
		k = k,
		pw = pw,
		ph = ph,
		tabsH = tabsH,
		lap = lap,
		tabW = tabW,
		tabX = math.round(pw * 0.025),
		tabStep = tabW - math.round(8 * math.max(k, 0.8)),
		pad = pad,
		gap = gap,
		radius = radius,
		tileRadius = radius - 2,
		list = list,
		rowW = rowW,
		rowH = rowH,
		inset = inset,
		ih = ih,
		hgap = if phone then 6 else math.round(10 * k),
		stacked = stacked,
		rewardW = rewardW,
		btnW = btnW,
		btnH = btnH,
		claimPx = if stacked then math.round(btnH * 0.6) else 30,
		barH = if phone then 22 else math.round(28 * k),
		titlePx = if phone then 20 else math.round(27 * k),
		subPx = if phone then 16 else math.max(16, math.round(18 * k)),
		amountPx = if stacked then math.round(ih * 0.3) else 19,
		goalH = if phone then 48 else math.round(58 * k),
		headH = tabsH,
		tabY = 0,
		cardW = rowW,
		cardH = rowH,
		actionW = btnW,
	}
end

-- BUILDING BLOCKS ----------------------------------------------------------------------------

-- A square icon tile: the family's colour, a rays motif, a big icon, then the ink line and chrome edge over it. The icon is
-- the game's art when the place has it; otherwise the painter named by the fixture, so a tile is never empty.
local function iconTile(
	parent: Instance,
	iconName: string,
	side: number,
	position: UDim2,
	z: number,
	radius: number
): Frame
	local look = TILES[iconName] or DEFAULT_TILE
	local family = CarKit.Family[look.family]
	local tile = make("Frame", {
		Name = "Tile",
		BackgroundColor3 = CarKit.White,
		Position = position,
		Size = UDim2.fromOffset(side, side),
		ZIndex = z,
	}, parent) :: Frame
	make("UIGradient", { Rotation = 100, Color = ColorSequence.new(family.top, family.bottom) }, tile)
	local rays = CarKit.pattern(tile, "rays", { color = family.motifColor, transparency = 0.45, z = 1 })
	if rays then
		make("UICorner", { CornerRadius = UDim.new(0, radius) }, rays)
	end
	CarKit.art(tile, look.art, { size = UDim2.fromScale(0.86, 0.86), z = 3, fallbackIcon = iconName, name = "TileArt" })
	CarKit.edges(tile, radius, true, family.edge)
	return tile
end

type Glow = { holder: Frame, scale: UIScale, target: Instance, prop: string }

-- The soft green halo behind CLAIM!. The pulse tweens its scale and the transparency of `target`; with no glow art in the
-- place it is a soft rounded block instead, so the button still stands out.
local function makeGlow(parent: Instance, z: number): Glow
	local holder = make("Frame", {
		Name = "Glow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z,
		Visible = false,
	}, parent) :: Frame
	local scale = make("UIScale", { Name = "Pulse" }, holder) :: UIScale
	local uri = GameIcons.uri("fx_glow")
	if uri then
		local image = make("ImageLabel", {
			Name = "GlowArt",
			BackgroundTransparency = 1,
			Image = uri,
			ImageColor3 = GLOW_COLOUR,
			ImageTransparency = GLOW_REST,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, holder)
		return { holder = holder, scale = scale, target = image, prop = "ImageTransparency" }
	end
	local block = make("Frame", {
		Name = "GlowBlock",
		BackgroundColor3 = GLOW_COLOUR,
		BackgroundTransparency = GLOW_REST,
		Size = UDim2.fromScale(0.78, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 1,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, block)
	return { holder = holder, scale = scale, target = block, prop = "BackgroundTransparency" }
end

-- BUILD --------------------------------------------------------------------------------------

type Card = {
	index: number,
	frame: Frame,
	gradient: UIGradient,
	mission: MissionFixtures.Mission,
	look: RewardLook,
	rewardWord: string,
	title: TextLabel,
	sub: TextLabel,
	track: Frame,
	fill: Frame,
	fillGradient: UIGradient,
	count: TextLabel,
	reward: Frame,
	rewardGradient: UIGradient,
	rewardMotif: ImageLabel?,
	rewardDim: Frame,
	rewardArt: Frame,
	amountBox: Frame,
	preview: Frame,
	glow: Glow,
	claim: CarKit.Button,
	breath: UIScale,
	stamp: Frame,
	stampScale: UIScale,
	fade: any,
	visual: string,
	numbers: string,
	action: string,
	rewardCentre: Vector2, -- panel coordinates, set by the layout
	claimCentre: Vector2,
}

type GoalRow = {
	frame: Frame,
	goal: MissionFixtures.Goal,
	label: TextLabel,
	right: TextLabel,
	isNext: boolean,
	done: boolean,
}

type TabParts = {
	button: TextButton,
	icon: Frame,
	label: TextLabel,
	gradient: UIGradient,
	x: number,
}

local function copyState(source: MissionFixtures.State): MissionFixtures.State
	local function list<T>(items: { T }): { T }
		local out: { T } = {}
		for _, item in items do
			table.insert(out, table.clone(item :: any))
		end
		return out
	end
	return {
		source = source.source,
		load = source.load,
		missions = list(source.missions),
		goals = list(source.goals),
		pool = list(source.pool),
	}
end

function MissionsPanel.new(ctx: Overlay.Ctx, options: Options?): Panel
	local opts: Options = options or {}
	local state = copyState(opts.state or (MissionFixtures.preset("InProgress3") :: MissionFixtures.State))
	local geo = MissionsPanel.geometry(Vector2.new(750, 325))
	local builtKey = ""
	local tab: Tab = "Missions"
	local cards: { Card } = {}
	local goalRows: { GoalRow } = {}
	local latch: { [string]: boolean } = {} -- goals seen done stay done
	local replaced: { [any]: boolean } = {} -- a claimed mission is replaced once
	local poolIndex = 0
	local claimTaps, claimRequests, claimsResolved, replacements, refreshes = 0, 0, 0, 0, 0
	local listeners: { (MissionFixtures.State) -> () } = {}
	local lastClaimable = -1
	local visibleFlag = true
	local panelObj: Panel

	local overlay = Overlay.new(ctx, {
		name = "MissionsPanel",
		onDim = function()
			panelObj:close()
		end,
	})
	local trove = overlay.trove
	local flowTrove = trove:Extend() -- claim round trips, holds and replacements
	local buildTrove = trove:Extend() -- everything the current layout built

	-- the parts of the current build (rebuilt whenever the design size changes)
	local shell: Frame = nil :: any
	local fx: Frame = nil :: any
	local goalScroll: ScrollingFrame = nil :: any
	local message: TextLabel = nil :: any
	local retryButton: CarKit.Button = nil :: any
	local closeButton: ImageButton = nil :: any
	local tabs: { [string]: TabParts } = {}
	local confetti: { Frame } = {}
	local confettiThread: thread? = nil
	local buildShell: () -> ()

	-- STATE HELPERS --------------------------------------------------------------------------

	local function visibleMissions(): { MissionFixtures.Mission }
		local out: { MissionFixtures.Mission } = {}
		for i, m in state.missions do
			if i > MAX_MISSIONS then
				break
			end
			table.insert(out, m)
		end
		return out
	end

	local function claimableCount(): number
		local n = 0
		for _, m in visibleMissions() do
			if MissionFixtures.visual(m) == "Ready" then
				n += 1
			end
		end
		return n
	end

	local function notify()
		for _, fn in table.clone(listeners) do
			fn(state)
		end
		local n = claimableCount()
		if n ~= lastClaimable then
			lastClaimable = n
			if opts.onClaimableChanged then
				opts.onClaimableChanged(n)
			end
		end
	end

	local function nextMission(): MissionFixtures.Mission
		poolIndex += 1
		local source = state.pool[((poolIndex - 1) % math.max(#state.pool, 1)) + 1]
		if source == nil then
			return MissionFixtures.fromTemplate(poolIndex)
		end
		local fresh = table.clone(source)
		fresh.id = source.id .. "#" .. poolIndex -- unique even when the pool cycles
		fresh.progress = fresh.progress or 0
		fresh.claim = "None"
		return fresh
	end

	local function goalDone(g: MissionFixtures.Goal): boolean
		return g.done or latch[g.id] == true
	end

	local function shown(): boolean
		return overlay:isOpen() and visibleFlag
	end

	-- the rows are on screen: the panel is open and on screen, on the Missions tab, with a list to show
	local function rowsShown(): boolean
		return shown() and tab == "Missions" and state.load == "Ready"
	end

	-- PULSES ---------------------------------------------------------------------------------

	local function stopPulse(card: Card)
		Motion.cancelAll(card.glow.scale)
		Motion.cancelAll(card.glow.target)
		Motion.cancelAll(card.breath)
		card.glow.scale.Scale = 1
		card.breath.Scale = 1
		local target: any = card.glow.target
		target[card.glow.prop] = GLOW_REST
	end

	-- A Ready row's glow and button breathe, only while the panel is open and on screen. Reduce Motion keeps the glow still.
	local function startPulse(card: Card)
		stopPulse(card)
		if card.visual ~= "Ready" or not rowsShown() or Motion.reduced() then
			return
		end
		Motion.tween(card.glow.scale, "pulse", PULSE, { Scale = 1.14 })
		Motion.tween(card.glow.target, "pulse", PULSE, { [card.glow.prop] = GLOW_PEAK })
		Motion.tween(card.breath, "pulse", PULSE, { Scale = 1.045 })
	end

	local function syncPulses()
		for _, c in cards do
			startPulse(c)
		end
	end

	-- The confetti pool is reused by every burst; nothing is created while a claim is celebrated.
	local function stopConfetti()
		local thread = confettiThread
		confettiThread = nil
		if thread then
			task.cancel(thread)
		end
		for _, piece in confetti do
			Motion.cancelAll(piece)
			piece.Visible = false
		end
	end

	local function stopEffects()
		for _, c in cards do
			stopPulse(c)
		end
		stopConfetti()
		if fx then
			for _, child in fx:GetChildren() do
				if child.Name == "Flyer" then
					child:Destroy()
				end
			end
		end
	end

	-- CARDS ----------------------------------------------------------------------------------

	local function numbersText(m: MissionFixtures.Mission): string
		local visual = MissionFixtures.visual(m)
		if visual == "Checking" then
			return "Checking..."
		end
		local p = m.progress :: number
		local shownValue = if p ~= p or p < 0 then 0 else math.min(p, m.target)
		if m.format == "cash" then
			return string.format("%s / %s", Format.cash(shownValue), Format.cash(m.target))
		end
		return string.format("%s / %s", Format.group(shownValue), Format.group(m.target))
	end

	-- The title, the line under it (a hint, or the error message) and the bar share a row's height. The title takes what the
	-- line leaves; when a long title cannot fit beside a hint the hint goes, but an error message always stays.
	local function placeTexts(card: Card, textX: number, textW: number)
		local g = geo
		local m = card.mission
		local isError = m.claim == "Error" and card.visual == "Ready"
		local subText = if isError then "Could not claim. Try again." else (m.sub or "")
		local width = math.max(textW, 60)
		local avail = g.ih - g.barH - 5
		local subH = g.subPx + 3
		local hasSub = subText ~= ""
		card.title.TextTruncate = Enum.TextTruncate.None
		local budget = if hasSub then avail - subH else avail
		SupportKit.fitLabel(card.title, m.text, width, budget, g.titlePx)
		local lineH = SupportKit.measure(m.text, card.title.TextSize, math.max(width - 10, 20)).Y
		if hasSub and lineH > budget then
			if isError then
				-- one line, cut with an ellipsis, so the message still shows
				card.title.TextWrapped = false
				card.title.TextTruncate = Enum.TextTruncate.AtEnd
				card.title.TextSize = 16
				lineH = 20
			else
				hasSub = false
				SupportKit.fitLabel(card.title, m.text, width, avail, g.titlePx)
				lineH = SupportKit.measure(m.text, card.title.TextSize, math.max(width - 10, 20)).Y
			end
		end
		local titleH = math.ceil(lineH) + 2
		local stack = titleH + (if hasSub then subH else 0)
		local top = g.inset + math.max((avail - stack) / 2, 0)
		card.title.Position = UDim2.fromOffset(textX, top)
		card.title.Size = UDim2.fromOffset(width, titleH)
		card.sub.Text = subText
		card.sub.TextColor3 = if isError then ERROR_INK else INK_SOFT
		card.sub.Visible = hasSub
		if hasSub then
			card.sub.Position = UDim2.fromOffset(textX, top + titleH)
			card.sub.Size = UDim2.fromOffset(width, subH)
			SupportKit.fitLabel(card.sub, subText, width, subH, g.subPx)
		end
	end

	-- Places everything in a row that depends on its state: the reward tile and CLAIM! trade places in the short rows (CLAIM!
	-- takes the right edge and the reward tile moves left of it); in the tall rows the reward block is fixed and CLAIM!
	-- overlaps its bottom.
	local function layoutCard(card: Card)
		local g = geo
		local visual = card.visual
		local slot = visual == "Ready" or visual == "Pending" or visual == "Claimed"
		local ih, inset = g.ih, g.inset
		local textX = inset + ih + g.hgap
		local rewardX, rewardW, claimX, claimY = 0, 0, 0, 0
		if g.stacked then
			rewardW = g.rewardW
			rewardX = g.rowW - inset - rewardW
			claimX = rewardX + (rewardW - g.btnW) / 2
			claimY = inset + ih - g.btnH + 4
		else
			rewardW = ih
			claimX = g.rowW - inset - g.btnW
			rewardX = if slot then claimX - g.hgap - ih else g.rowW - inset - ih
			claimY = (g.rowH - g.btnH) / 2
		end
		card.reward.Position = UDim2.fromOffset(rewardX, inset)
		card.reward.Size = UDim2.fromOffset(rewardW, ih)
		local textW = rewardX - g.hgap - textX
		card.track.Position = UDim2.fromOffset(textX, inset + ih - g.barH)
		card.track.Size = UDim2.fromOffset(math.max(textW, 40), g.barH)
		placeTexts(card, textX, textW)
		-- inside the reward tile: the art, the amount over its foot, the PREVIEW tag on top
		local amountH = math.ceil(g.amountPx * 1.1)
		local topRegion = if g.stacked and slot then ih - g.btnH + 6 else ih
		local artSize, artY, amountY = 0, 0, 0
		if g.stacked then
			artSize = math.round(math.min(topRegion * (if slot then 0.95 else 0.84), rewardW * 0.7))
			artY = math.round(topRegion * 0.5 + (if slot then 2 else 8))
			amountY = if slot then topRegion - amountH - 2 else ih - amountH - 4
		else
			artSize = math.round(ih * 0.62)
			artY = math.round(ih * 0.56)
			amountY = ih - amountH - 2
		end
		card.rewardArt.Size = UDim2.fromOffset(artSize, artSize)
		card.rewardArt.Position = UDim2.fromOffset(rewardW / 2, artY)
		card.amountBox.Position = UDim2.fromOffset(0, amountY)
		card.amountBox.Size = UDim2.fromOffset(rewardW, amountH)
		card.preview.Size = UDim2.fromOffset(math.min(64, rewardW - 6), 17)
		card.preview.Position = UDim2.new(0.5, 0, 0, 3)
		-- the one action: CLAIM! (or its waiting look), or the CLAIMED stamp in the same place
		card.claim.root.Position = UDim2.fromOffset(claimX + g.btnW / 2, claimY + g.btnH / 2)
		card.claim.root.Visible = visual == "Ready" or visual == "Pending"
		card.stamp.Position = UDim2.fromOffset(claimX + g.btnW / 2, claimY + (g.btnH - 4) / 2)
		card.stamp.Size = UDim2.fromOffset(g.btnW, g.btnH - 4)
		card.stamp.Visible = visual == "Claimed"
		card.glow.holder.Position = UDim2.fromOffset(claimX + g.btnW / 2, claimY + (g.btnH - 4) / 2)
		card.glow.holder.Size = UDim2.fromOffset(g.btnW * 1.55, g.btnH * 2)
		card.glow.holder.Visible = visual == "Ready"
		local origin = Vector2.new(g.list.x, g.list.y + (card.index - 1) * (g.rowH + g.gap))
		card.rewardCentre = origin + Vector2.new(rewardX + rewardW / 2, inset + ih / 2)
		card.claimCentre = origin + Vector2.new(claimX + g.btnW / 2, claimY + g.btnH / 2)
	end

	-- What a row looks like in its state: plate colour, bar, reward tile lit or dim, and the one action.
	local function refreshCard(card: Card)
		local g = geo
		local m = card.mission
		local visual = MissionFixtures.visual(m)
		card.visual = visual
		local fraction = SupportKit.fraction(m.progress, m.target, "mission:" .. m.id)
		local done = visual == "Ready" or visual == "Claimed" or visual == "Pending"
		card.numbers = numbersText(m)
		local amount = if visual == "Claimed" or visual == "Pending" then 1 else (fraction or 0)
		card.fill.Size = UDim2.fromScale(amount, 1)
		card.fill.Visible = amount > 0
		card.count.Text = card.numbers
		card.fillGradient.Color = if visual == "Claimed" then BAR_CALM elseif done then BAR_GREEN else BAR_GOLD
		local top, bottom = PLATE_TOP, PLATE_BOTTOM
		if visual == "Ready" or visual == "Pending" then
			top, bottom = READY_TOP, READY_BOTTOM
		elseif visual == "Claimed" then
			top, bottom = CLAIMED_TOP, CLAIMED_BOTTOM
		end
		card.gradient.Color = ColorSequence.new(top, bottom)
		-- the reward tile is lit in its family colour while it can be claimed, a dark well otherwise, dimmed once claimed
		local lit = visual == "Ready" or visual == "Pending"
		local family = CarKit.Family[card.look.family]
		card.rewardGradient.Color = if lit then ColorSequence.new(family.top, family.bottom) else WELL_SEQ
		local motif = card.rewardMotif
		if motif then
			motif.Visible = lit
		end
		card.rewardDim.Visible = visual == "Claimed"
		-- the one action
		if visual == "Ready" then
			card.action = "CLAIM"
			card.claim.setText("CLAIM!")
			card.claim.label.TextSize = g.claimPx
			card.claim.setTone("Green")
			card.claim.setEnabled(true)
		elseif visual == "Pending" then
			card.action = "Checking..."
			card.claim.setText("Checking...")
			card.claim.label.TextSize = fitPx("Checking...", g.btnW - 18, g.claimPx, 16)
			card.claim.setTone("Grey")
			card.claim.setEnabled(false)
		elseif visual == "Claimed" then
			card.action = "CLAIMED"
		elseif visual == "InProgress" then
			card.action = "Keep going"
		else
			card.action = "Checking..."
		end
	end

	local function updateCard(card: Card)
		refreshCard(card)
		layoutCard(card)
		startPulse(card)
	end

	local function buildCard(index: number, mission: MissionFixtures.Mission): Card
		local g = geo
		local look = rewardLook(mission)
		local family = CarKit.Family[look.family]
		local plate = CarKit.board(shell, {
			size = UDim2.fromOffset(g.rowW, g.rowH),
			-- anchored on its middle so a pop grows it from the centre
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(g.list.x + g.rowW / 2, g.list.y + (index - 1) * (g.rowH + g.gap) + g.rowH / 2),
			z = 6,
			radius = g.radius,
			top = PLATE_TOP,
			bottom = PLATE_BOTTOM,
			name = "Card" .. index,
		})
		local gradient = plate:FindFirstChildOfClass("UIGradient") :: UIGradient
		iconTile(plate, mission.icon, g.ih, UDim2.fromOffset(g.inset, g.inset), 7, g.tileRadius)
		local title =
			CarKit.text(plate, mission.text, g.titlePx, { color = CarKit.Ink, wrap = true, z = 8, name = "Title" })
		local sub = CarKit.text(plate, "", g.subPx, { color = INK_SOFT, wrap = true, z = 8, name = "Sub" })
		-- the progress bar: a dark capsule with the count inside it
		local track = make("Frame", {
			Name = "Bar",
			BackgroundColor3 = CarKit.Well,
			ZIndex = 8,
		}, plate) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, g.barH / 2) }, track)
		make("UIStroke", {
			Thickness = 3 * CarKit.strokeScale(),
			Color = CarKit.Ink,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, track)
		local fill = make("Frame", {
			Name = "Fill",
			BackgroundColor3 = CarKit.White,
			Size = UDim2.fromScale(0, 1),
			Visible = false,
			ZIndex = 9,
		}, track) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, g.barH / 2) }, fill)
		local fillGradient = make("UIGradient", { Rotation = 90, Color = BAR_GOLD }, fill) :: UIGradient
		local countPx = math.max(14, math.floor(g.barH * 0.78))
		local count = CarKit.title(track, "", countPx, {
			align = Enum.TextXAlignment.Center,
			shadow = false,
			stroke = math.max(2, countPx / 9),
			z = 10,
			name = "Count",
		})
		-- the reward: real art in a tile, the amount over its foot, a small PREVIEW tag on top
		local reward = make("Frame", {
			Name = "Reward",
			BackgroundColor3 = CarKit.White,
			Size = UDim2.fromOffset(g.rewardW, g.ih),
			ZIndex = 8,
		}, plate) :: Frame
		local rewardGradient = make("UIGradient", { Rotation = 100, Color = WELL_SEQ }, reward) :: UIGradient
		local motif = CarKit.pattern(reward, "rays", { color = family.motifColor, transparency = 0.45, z = 1 })
		if motif then
			make("UICorner", { CornerRadius = UDim.new(0, g.tileRadius) }, motif)
			motif.Visible = false
		end
		local rewardArt = CarKit.art(reward, look.art, {
			size = UDim2.fromOffset(g.ih * 0.6, g.ih * 0.6),
			z = 3,
			fallbackIcon = look.fallback,
			name = "RewardArt",
		})
		local dim = make("Frame", {
			Name = "Dim",
			BackgroundColor3 = CarKit.Ink,
			BackgroundTransparency = 0.5,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 6,
		}, reward) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, g.tileRadius) }, dim)
		local amountBox = make("Frame", {
			Name = "AmountBox",
			BackgroundTransparency = 1,
			ZIndex = 8,
		}, reward) :: Frame
		local isCash = look.word == nil
		CarKit.title(amountBox, rewardText(mission), fitPx(rewardText(mission), g.rewardW * 0.94, g.amountPx, 16), {
			align = Enum.TextXAlignment.Center,
			top = CarKit.White,
			bottom = if isCash then CarKit.CashText else CarKit.Gold,
			stroke = math.max(2.5, g.amountPx / 9),
			z = 1,
			name = "Amount",
		})
		local preview = make("Frame", {
			Name = "PreviewTag",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = CarKit.Ink,
			BackgroundTransparency = 0.3,
			ZIndex = 12,
		}, reward) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, preview)
		CarKit.text(preview, "PREVIEW", 14, {
			align = Enum.TextXAlignment.Center,
			color = CarKit.Soft,
			z = 1,
			name = "Text",
		})
		CarKit.edges(reward, g.tileRadius, false)
		-- CLAIM!: the glow sits behind it, the button breathes
		local glow = makeGlow(plate, 9)
		local cardRef: Card? = nil
		local claim = CarKit.button(plate, {
			text = "CLAIM!",
			tone = "Green",
			px = g.claimPx,
			size = UDim2.fromOffset(g.btnW, g.btnH),
			z = 10,
			name = "Claim",
			sound = "Tap",
			onPress = function()
				claimTaps += 1
				local current = cardRef
				if current then
					panelObj:pressClaim(current.mission.id) -- the card's CURRENT mission (it can be replaced)
				end
			end,
		})
		claim.root.AnchorPoint = Vector2.new(0.5, 0.5) -- the breathing grows it from its middle
		local breath = make("UIScale", { Name = "Breath" }, claim.root) :: UIScale
		-- the CLAIMED stamp: a calm green pill with a check
		local stamp = make("Frame", {
			Name = "ClaimedStamp",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = CarKit.White,
			Visible = false,
			ZIndex = 10,
		}, plate) :: Frame
		make("UIGradient", { Rotation = 90, Color = STAMP_SEQ }, stamp)
		CarKit.edges(stamp, 10, false)
		local stampScale = make("UIScale", { Name = "Pop" }, stamp) :: UIScale
		local checkPx = if g.stacked then 48 else 32
		CarKit.slot(stamp, "check", checkPx, {
			anchor = Vector2.new(0, 0.5),
			position = UDim2.new(0, 6, 0.5, 0),
			z = 2,
			fallback = "Check",
		})
		local stampWord = "CLAIMED"
		CarKit.title(stamp, stampWord, fitPx(stampWord, g.btnW - checkPx - 22, g.claimPx, 16), {
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(checkPx + 10, 0),
			size = UDim2.new(1, -(checkPx + 14), 1, 0),
			shadow = false,
			stroke = 2.5,
			z = 3,
			name = "Word",
		})
		local card: Card = {
			index = index,
			frame = plate,
			gradient = gradient,
			mission = mission,
			look = look,
			rewardWord = rewardText(mission),
			title = title,
			sub = sub,
			track = track,
			fill = fill,
			fillGradient = fillGradient,
			count = count,
			reward = reward,
			rewardGradient = rewardGradient,
			rewardMotif = motif,
			rewardDim = dim,
			rewardArt = rewardArt,
			amountBox = amountBox,
			preview = preview,
			glow = glow,
			claim = claim,
			breath = breath,
			stamp = stamp,
			stampScale = stampScale,
			fade = nil :: any,
			visual = "",
			numbers = "",
			action = "",
			rewardCentre = Vector2.zero,
			claimCentre = Vector2.zero,
		}
		cardRef = card
		refreshCard(card)
		layoutCard(card)
		return card
	end

	local function destroyCard(card: Card)
		stopPulse(card)
		if card.fade then
			card.fade:destroy()
			card.fade = nil
		end
		Motion.cancelAll(card.frame)
		card.frame:Destroy()
	end

	local function clearCards()
		for _, c in cards do
			destroyCard(c)
		end
		table.clear(cards)
	end

	local function findCard(id: string): (Card?, number)
		for i, c in cards do
			if c.mission.id == id then
				return c, i
			end
		end
		return nil, 0
	end

	-- A gamepad's selection must not be left on a CLAIM! that just went away: move it to the next ready one, or to Close.
	local function reselect(card: Card)
		local selected = GuiService.SelectedObject
		if selected == nil or not selected:IsDescendantOf(card.frame) then
			return
		end
		for _, other in cards do
			if other ~= card and other.visual == "Ready" then
				GuiService.SelectedObject = other.claim.root
				return
			end
		end
		GuiService.SelectedObject = closeButton
	end

	-- GOALS ----------------------------------------------------------------------------------

	local function clearGoals()
		for _, r in goalRows do
			r.frame:Destroy()
		end
		table.clear(goalRows)
	end

	local function goalRight(g: MissionFixtures.Goal, done: boolean, isNext: boolean): string
		if done then
			return "DONE"
		end
		local count = ""
		if g.progress ~= nil and g.target ~= nil then
			count = string.format(
				"%s / %s",
				Format.group(math.min(g.progress :: number, g.target :: number)),
				Format.group(g.target :: number)
			)
		end
		if isNext then
			return if count ~= "" then "NEXT: " .. count else "NEXT"
		end
		return count
	end

	local function rebuildGoals()
		clearGoals()
		if not goalScroll then
			return
		end
		local g = geo
		local nextFound = false
		for _, goal in state.goals do
			if goalDone(goal) then
				latch[goal.id] = true
			end
		end
		local bar = if g.tier == "Phone" then 4 else 6
		local w = g.rowW - bar - 10 -- the list's scroll bar, and 3 px each side so the rows' outlines are not clipped
		local side = g.goalH - g.inset * 2
		local rightW = if g.tier == "Phone" then 112 else math.max(120, math.round(150 * g.k))
		local textPx = if g.tier == "Phone" then 18 else math.round(23 * g.k)
		local y = 3
		for _, goal in state.goals do
			local done = goalDone(goal)
			local isNext = false
			if not done and not nextFound then
				isNext = true
				nextFound = true
			end
			local top, bottom = PLATE_TOP, PLATE_BOTTOM
			if done then
				top, bottom = CLAIMED_TOP, CLAIMED_BOTTOM
			elseif isNext then
				top, bottom = NEXT_TOP, NEXT_BOTTOM
			end
			local plate = CarKit.board(goalScroll, {
				size = UDim2.fromOffset(w, g.goalH),
				position = UDim2.fromOffset(3, y),
				z = 2,
				radius = g.radius,
				top = top,
				bottom = bottom,
				name = "Goal_" .. goal.id,
			})
			iconTile(plate, goal.icon, side, UDim2.fromOffset(g.inset, g.inset), 3, g.tileRadius)
			if done then
				CarKit.slot(plate, "check", if g.tier == "Phone" then 24 else 32, {
					position = UDim2.fromOffset(g.inset + side - 2, g.inset + side - 2),
					z = 6,
					fallback = "Check",
				})
			end
			local textX = g.inset + side + g.hgap + 4
			local labelW = w - textX - rightW - g.inset - g.hgap
			local label = CarKit.text(plate, goal.text, textPx, {
				color = CarKit.Ink,
				wrap = true,
				position = UDim2.fromOffset(textX, g.inset),
				size = UDim2.fromOffset(labelW, side),
				z = 4,
				name = "Text",
			})
			SupportKit.fitLabel(label, goal.text, labelW, side, textPx)
			local rightText = goalRight(goal, done, isNext)
			local rightX = w - g.inset - 6 - rightW
			local right: TextLabel
			if done or isNext then
				right =
					CarKit.title(plate, rightText, fitPx(rightText, rightW, math.max(22, math.round(26 * g.k)), 16), {
						align = Enum.TextXAlignment.Right,
						position = UDim2.fromOffset(rightX, g.inset),
						size = UDim2.fromOffset(rightW, side),
						top = CarKit.White,
						bottom = if done then CarKit.CashText else CarKit.Gold,
						shadow = false,
						stroke = 2.5,
						z = 4,
						name = "Right",
					})
			else
				right = CarKit.text(plate, rightText, math.max(16, math.round(20 * g.k)), {
					align = Enum.TextXAlignment.Right,
					color = INK_SOFT,
					position = UDim2.fromOffset(rightX, g.inset),
					size = UDim2.fromOffset(rightW, side),
					z = 4,
					name = "Right",
				})
			end
			table.insert(
				goalRows,
				{ frame = plate, goal = goal, label = label, right = right, isNext = isNext, done = done }
			)
			y += g.goalH + g.gap
		end
		goalScroll.CanvasSize = UDim2.fromOffset(0, y - g.gap + 3)
	end

	-- VIEW -----------------------------------------------------------------------------------

	local function messageText(): string
		if state.load == "Loading" then
			return "Checking..."
		elseif state.load == "Error" then
			return "Could not load your Missions."
		elseif tab == "Missions" and #state.missions == 0 then
			return "No Missions right now. Check back soon!"
		end
		return ""
	end

	local function paintTabs()
		local g = geo
		local drop = if g.tier == "Phone" then 4 else math.round(8 * g.k)
		for name, parts in tabs do
			local active = name == tab
			local visibleH = if active then g.tabsH else g.tabsH - drop
			parts.button.Position = UDim2.fromOffset(parts.x, if active then 0 else drop)
			parts.button.Size = UDim2.fromOffset(g.tabW, if active then g.tabsH + g.lap else g.tabsH - drop + g.lap + 4)
			parts.button.ZIndex = if active then 12 else 3
			parts.gradient.Color = if active then TAB_ON else TAB_OFF
			parts.label.TextColor3 = if active then CarKit.Ink else CarKit.Soft
			local stroke = parts.label:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Enabled = not active
			end
			parts.label.Size = UDim2.new(parts.label.Size.X.Scale, parts.label.Size.X.Offset, 0, visibleH)
			parts.icon.Position = UDim2.fromOffset(12, visibleH / 2)
			local image = parts.icon:FindFirstChild("Image")
			if image and image:IsA("ImageLabel") then
				image.ImageColor3 = if active then CarKit.White else rgb(170, 184, 214)
			end
		end
	end

	local function applyView()
		local ready = state.load == "Ready"
		local text = messageText()
		local showMissions = ready and tab == "Missions" and #state.missions > 0
		for _, c in cards do
			c.frame.Visible = showMissions
		end
		goalScroll.Visible = ready and tab == "Goals"
		message.Visible = text ~= ""
		SupportKit.fitLabel(message, text, geo.list.w - 40, 90, 28)
		retryButton.root.Visible = state.load == "Error" and opts.onRetry ~= nil
		paintTabs()
		syncPulses()
	end

	local function makeTab(name: Tab, word: string, art: string, painter: string, x: number): TabParts
		local g = geo
		local button = make("TextButton", {
			Name = name .. "Tab",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = CarKit.White,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(g.tabW, g.tabsH),
			Selectable = true,
			ZIndex = 3,
		}, shell) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, g.radius) }, button)
		make("UIStroke", {
			Thickness = 3 * CarKit.strokeScale(),
			Color = CarKit.Ink,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, button)
		local gradient = make("UIGradient", { Rotation = 90, Color = TAB_OFF }, button) :: UIGradient
		local iconPx = if g.tier == "Desktop" then 48 else 32
		local icon = CarKit.slot(button, art, iconPx, {
			anchor = Vector2.new(0, 0.5),
			position = UDim2.fromOffset(12, g.tabsH / 2),
			z = 5,
			fallback = painter,
		})
		-- both tabs use the size that fits the longer word, so MISSIONS and GOALS match
		local labelW = g.tabW - (12 + iconPx + 16)
		local px = fitPx("MISSIONS", labelW, if g.tier == "Phone" then 28 else math.round(38 * g.k), 16)
		local label = CarKit.title(button, word, px, {
			position = UDim2.fromOffset(12 + iconPx + 8, 0),
			size = UDim2.new(1, -(12 + iconPx + 16), 0, g.tabsH),
			shadow = false,
			z = 5,
			name = "Label",
		})
		buildTrove:Connect(button.Activated, function()
			pcall(function()
				Sounds.play("Tap")
			end)
			panelObj:selectTab(name)
		end)
		return { button = button, icon = icon, label = label, gradient = gradient, x = x }
	end

	local function buildConfetti()
		table.clear(confetti)
		for i = 1, CONFETTI do
			local wide = i % 2 == 0
			local piece = make("Frame", {
				Name = "Confetti",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = CONFETTI_COLOURS[(i - 1) % #CONFETTI_COLOURS + 1],
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(if wide then 11 else 7, if wide then 7 else 12),
				Visible = false,
				ZIndex = 1 + i,
			}, fx) :: Frame
			make("UICorner", { CornerRadius = UDim.new(0, 2) }, piece)
			table.insert(confetti, piece)
		end
	end

	buildShell = function()
		buildTrove:Clean()
		table.clear(cards)
		table.clear(goalRows)
		table.clear(tabs)
		confettiThread = nil
		CarKit.setStrokeScale(ctx.screen:uiScale())
		overlay:applyScale()
		local ds = overlay:designSize()
		geo = MissionsPanel.geometry(ds)
		builtKey =
			string.format("%d:%d:%d", math.round(ds.X), math.round(ds.Y), math.round(ctx.screen:uiScale() * 1000))
		local g = geo
		shell = buildTrove:Add(make("Frame", {
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -2),
			Size = UDim2.fromOffset(g.pw, g.ph),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, overlay.content)) :: Frame
		-- the board the rows sit on, and the two tabs standing in it
		CarKit.board(shell, {
			size = UDim2.fromOffset(g.pw, g.ph - g.tabsH),
			position = UDim2.fromOffset(0, g.tabsH),
			z = 4,
			radius = if g.tier == "Phone" then 12 else 18,
			bolts = g.tier ~= "Phone", -- the phone's bezel is too narrow for them
			name = "Board",
		})
		tabs.Missions = makeTab("Missions", "MISSIONS", "missions", "Missions", g.tabX)
		tabs.Goals = makeTab("Goals", "GOALS", "goals", "Goals", g.tabX + g.tabStep)
		-- Close: the kit's X, top right
		local closePx = 48
		closeButton = make("ImageButton", {
			Name = "CloseX",
			BackgroundTransparency = 1,
			Image = "",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -2, 0, if g.tier == "Phone" then -2 else math.max((g.tabsH - closePx) // 2, 0)),
			Size = UDim2.fromOffset(closePx, closePx),
			ZIndex = 14,
		}, shell) :: ImageButton
		CarKit.slot(closeButton, "close", closePx, { position = UDim2.fromScale(0.5, 0.5), z = 15, fallback = "Close" })
		buildTrove:Connect(closeButton.Activated, function()
			panelObj:close()
		end)
		-- the Goals list (rows are built on demand) and the state message
		goalScroll = make("ScrollingFrame", {
			Name = "GoalList",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(g.list.x, g.list.y),
			Size = UDim2.fromOffset(g.list.w, g.list.h),
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = if g.tier == "Phone" then 4 else 6,
			ScrollBarImageColor3 = CarKit.ChromeBottom,
			ClipsDescendants = true,
			Selectable = false,
			Visible = false,
			ZIndex = 6,
		}, shell) :: ScrollingFrame
		message = CarKit.text(shell, "", 28, {
			align = Enum.TextXAlignment.Center,
			wrap = true,
			color = CarKit.White,
			stroke = 2,
			position = UDim2.fromOffset(g.list.x + 20, g.list.y + g.list.h / 2 - 70),
			size = UDim2.fromOffset(g.list.w - 40, 90),
			z = 8,
			name = "Message",
		})
		retryButton = CarKit.button(shell, {
			text = "TRY AGAIN",
			tone = "Orange",
			px = 30,
			size = UDim2.fromOffset(200, 56),
			anchor = Vector2.new(0.5, 0),
			position = UDim2.fromOffset(g.pw / 2, g.list.y + g.list.h / 2 + 30),
			z = 14,
			name = "Retry",
			sound = "Tap",
			onPress = function()
				if opts.onRetry then
					opts.onRetry()
				end
			end,
		})
		retryButton.root.Visible = false
		-- a harness control: the explicit daily-refresh switch (hidden unless the harness shows its captions)
		local refreshButton = CarKit.button(shell, {
			text = "Refresh (fixture)",
			tone = "Blue",
			px = 24,
			size = UDim2.fromOffset(190, 52),
			anchor = Vector2.new(1, 1),
			position = UDim2.fromOffset(g.pw - 14, g.ph - 10),
			z = 16,
			name = "FixtureRefresh",
			sound = "Tap",
			onPress = function()
				panelObj:fixtureRefresh()
			end,
		})
		refreshButton.root.Visible = false
		refreshButton.root:SetAttribute("PreviewCaption", true)
		-- the rows
		for i, m in visibleMissions() do
			table.insert(cards, buildCard(i, m))
		end
		rebuildGoals()
		-- the effects layer: the confetti pool and the flying reward art, above everything
		fx = make("Frame", {
			Name = "Effects",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 60,
		}, shell) :: Frame
		buildConfetti()
		buildTrove:Add(function()
			local thread = confettiThread
			confettiThread = nil
			if thread then
				task.cancel(thread)
			end
		end)
		applyView()
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local key =
			string.format("%d:%d:%d", math.round(ds.X), math.round(ds.Y), math.round(ctx.screen:uiScale() * 1000))
		if key ~= builtKey then
			buildShell()
		end
	end

	-- Only the cards: the daily refresh swaps missions, the tabs and the board stay.
	local function rebuildCards()
		clearCards()
		for i, m in visibleMissions() do
			table.insert(cards, buildCard(i, m))
		end
		applyView()
		notify()
	end

	-- CLAIM FLOW -----------------------------------------------------------------------------

	-- Confetti from the claim button: 24 pooled frames fly out, spin and fade over 0.7 s, then hide until the next claim.
	local function burst(origin: Vector2, seed: number)
		stopConfetti()
		local rng = Random.new(seed)
		local reach = math.max(geo.k, 0.8)
		for _, piece in confetti do
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(50, 130) * reach
			piece.Position = UDim2.fromOffset(origin.X, origin.Y)
			piece.Rotation = rng:NextInteger(0, 180)
			piece.BackgroundTransparency = 0
			piece.Visible = true
			Motion.tween(
				piece,
				"move",
				Motion.info(CONFETTI_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Position = UDim2.fromOffset(
						origin.X + math.cos(angle) * distance,
						origin.Y + math.sin(angle) * distance + 24
					),
					Rotation = piece.Rotation + rng:NextNumber(-260, 260),
				}
			)
			Motion.tween(
				piece,
				"fade",
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, CONFETTI_SECONDS - 0.3),
				{ BackgroundTransparency = 1 }
			)
		end
		confettiThread = task.delay(CONFETTI_SECONDS + 0.05, function()
			confettiThread = nil
			for _, piece in confetti do
				piece.Visible = false
			end
		end)
	end

	-- The reward art pops, then flies to the top of the panel, shrinking and fading. A copy flies; the tile keeps its art.
	local function flyReward(card: Card)
		local g = geo
		local copy = card.rewardArt:Clone() :: Frame
		copy.Name = "Flyer"
		copy.AnchorPoint = Vector2.new(0.5, 0.5)
		copy.Position = UDim2.fromOffset(card.rewardCentre.X, card.rewardCentre.Y)
		copy.ZIndex = 70
		copy.Parent = fx
		flowTrove:Add(copy)
		local scale = make("UIScale", { Name = "Fly", Scale = 1 }, copy) :: UIScale
		local image = copy:FindFirstChild("Image")
		local up = Motion.tween(scale, "fly", Motion.info(0.14, Enum.EasingStyle.Back), { Scale = 1.4 })
		up.Completed:Once(function(status: Enum.PlaybackState)
			if status ~= Enum.PlaybackState.Completed or not copy.Parent then
				return
			end
			local away = Motion.info(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local move = Motion.tween(copy, "fly", away, { Position = UDim2.fromOffset(g.pw / 2, g.tabsH * 0.3) })
			Motion.tween(scale, "fly", away, { Scale = 0.45 })
			if image and image:IsA("ImageLabel") then
				Motion.tween(
					image,
					"fly",
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.32),
					{ ImageTransparency = 1 }
				)
			end
			move.Completed:Once(function()
				if copy.Parent then
					copy:Destroy()
				end
			end)
		end)
	end

	local function celebrate(card: Card)
		pcall(function()
			Sounds.play("Unlock")
		end)
		if not rowsShown() then
			return
		end
		if Motion.reduced() then
			-- a plain fade: the CLAIMED stamp arrives instead of popping
			local fade = Fade.capture(card.stamp)
			fade:set(1)
			fade:tween(0, 0.2)
			flowTrove:Add(function()
				fade:destroy()
			end)
			return
		end
		Motion.pop(card.frame, 1.03)
		burst(card.claimCentre, claimsResolved + 3)
		flyReward(card)
		card.stampScale.Scale = 0.6
		Motion.tween(card.stampScale, "pop", Motion.info(0.25, Enum.EasingStyle.Back), { Scale = 1 })
	end

	-- The claimed row is replaced ONCE: it fades out, a fresh mission takes its place (rebuilt in the same spot) and fades in.
	local function replaceMission(mission: MissionFixtures.Mission)
		if replaced[mission] then
			return
		end
		replaced[mission] = true
		local index = table.find(state.missions, mission)
		if not index then
			return
		end
		replacements += 1
		local fresh = nextMission()
		state.missions[index] = fresh
		local function swap()
			-- the card that still shows `mission` (the panel may have been rebuilt since the claim)
			local at = 0
			for i, c in cards do
				if c.mission == mission then
					at = i
					break
				end
			end
			if at == 0 then
				notify()
				return
			end
			local old = cards[at]
			reselect(old)
			destroyCard(old)
			local card = buildCard(at, fresh)
			cards[at] = card
			card.frame.Visible = tab == "Missions" and state.load == "Ready"
			startPulse(card)
			if not Motion.reduced() and rowsShown() then
				local fadeIn = Fade.capture(card.frame)
				card.fade = fadeIn
				fadeIn:set(1)
				local tween = fadeIn:tween(0, 0.22)
				if tween then
					tween.Completed:Once(function()
						if card.fade == fadeIn then
							card.fade = nil
						end
						fadeIn:destroy()
					end)
				end
			end
			notify()
		end
		if Motion.reduced() or not rowsShown() then
			swap()
			return
		end
		local old: Card? = nil
		for _, c in cards do
			if c.mission == mission then
				old = c
				break
			end
		end
		if not old then
			swap()
			return
		end
		local fadeOut = Fade.capture(old.frame)
		old.fade = fadeOut
		local tween = fadeOut:tween(1, 0.16)
		if tween then
			tween.Completed:Once(swap)
		else
			swap()
		end
	end

	local function scheduleReplacement(card: Card)
		local mission = card.mission
		local hold = if Motion.reduced() then CLAIM_HOLD_REDUCED else CLAIM_HOLD
		flowTrove:Add(task.delay(hold, function()
			replaceMission(mission)
		end))
	end

	local function resolve(id: string, outcome: "Success" | "Error"): boolean
		local card = findCard(id)
		if not card or card.mission.claim ~= "Pending" then
			return false
		end
		if outcome == "Success" then
			card.mission.claim = "Claimed"
			claimsResolved += 1
			updateCard(card)
			reselect(card)
			celebrate(card)
			scheduleReplacement(card)
		else
			card.mission.claim = "Error"
			updateCard(card)
		end
		notify()
		return true
	end

	overlay:setBack(function()
		panelObj:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)
	trove:Add(Motion.onReducedChanged(function()
		syncPulses()
	end))

	panelObj = {
		root = overlay.root,
		layout = function(_self: Panel)
			layoutNow()
		end,
		setVisible = function(_self: Panel, on: boolean)
			visibleFlag = on
			overlay.root.Visible = on and overlay:isOpen()
			if on then
				syncPulses()
			else
				stopEffects()
			end
		end,
		open = function(_self: Panel, returnTo: GuiObject?)
			if overlay:isOpen() then
				return
			end
			buildShell()
			notify()
			local focus: GuiObject = closeButton
			for _, c in cards do
				if c.visual == "Ready" then
					focus = c.claim.root
					break
				end
			end
			overlay:open(focus, returnTo)
			syncPulses()
		end,
		close = function(_self: Panel)
			if not overlay:isOpen() then
				return
			end
			stopEffects()
			overlay:close()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Panel): boolean
			return overlay:isOpen()
		end,
		selectTab = function(_self: Panel, which: Tab)
			if which == tab then
				return
			end
			tab = which
			if tab == "Goals" then
				rebuildGoals()
				goalScroll.CanvasPosition = Vector2.zero
			end
			applyView()
		end,
		setState = function(_self: Panel, incoming: MissionFixtures.State)
			flowTrove:Clean()
			state = copyState(incoming)
			replaced = {}
			poolIndex = 0
			table.clear(latch)
			buildShell()
			notify()
			syncPulses()
		end,
		setPreset = function(self: Panel, name: string): boolean
			local incoming = MissionFixtures.preset(name)
			if not incoming then
				return false
			end
			self:setState(incoming)
			return true
		end,
		pressClaim = function(_self: Panel, id: string): boolean
			local card = findCard(id)
			if not card or MissionFixtures.visual(card.mission) ~= "Ready" then
				return false -- a repeated tap while pending, or a card that is not ready: nothing happens
			end
			card.mission.claim = "Pending"
			claimRequests += 1
			updateCard(card)
			notify()
			if opts.onClaim then
				opts.onClaim(id)
			end
			local mode = opts.previewResolve or (if opts.onClaim == nil then "Success" else "None")
			if mode ~= "None" then
				flowTrove:Add(task.delay(PREVIEW_RESOLVE_SECONDS, function()
					resolve(id, mode :: "Success" | "Error")
				end))
			end
			return true
		end,
		resolveClaim = function(_self: Panel, id: string, outcome: "Success" | "Error"): boolean
			return resolve(id, outcome)
		end,
		fixtureRefresh = function(_self: Panel): number
			-- explicit fixture switch: untouched missions (progress exactly 0, nothing pending) get a fresh template
			local changed = 0
			for index, m in state.missions do
				if index <= MAX_MISSIONS and m.claim == "None" and m.progress == 0 then
					state.missions[index] = nextMission()
					changed += 1
				end
			end
			refreshes += 1
			if changed > 0 then
				rebuildCards()
			end
			return changed
		end,
		subscribe = function(_self: Panel, fn: (MissionFixtures.State) -> ()): () -> ()
			table.insert(listeners, fn)
			return function()
				local i = table.find(listeners, fn)
				if i then
					table.remove(listeners, i)
				end
			end
		end,
		getState = function(_self: Panel): MissionFixtures.State
			return state
		end,
		topMission = function(_self: Panel): MissionFixtures.Mission?
			return MissionFixtures.top(visibleMissions())
		end,
		destroy = function(_self: Panel)
			stopEffects()
			clearCards()
			overlay:destroy()
		end,
		getDebugState = function(_self: Panel): DebugState
			local cardInfo: { CardDebug } = {}
			for _, c in cards do
				table.insert(cardInfo, {
					id = c.mission.id,
					visual = MissionFixtures.visual(c.mission),
					numbers = c.numbers,
					action = c.action,
					sub = c.sub.Text,
					reward = "PREVIEW reward " .. c.rewardWord,
				})
			end
			local goalInfo = {}
			for _, r in goalRows do
				table.insert(goalInfo, { id = r.goal.id, done = goalDone(r.goal), next = r.isNext })
			end
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				tab = tab,
				load = state.load,
				cards = cardInfo,
				goals = goalInfo,
				claimTaps = claimTaps,
				claimRequests = claimRequests,
				claimsResolved = claimsResolved,
				replacements = replacements,
				refreshes = refreshes,
				message = message.Text,
				instances = #overlay.root:GetDescendants(),
			}
		end,
		touchReport = function(_self: Panel): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	buildShell()
	return panelObj
end

return MissionsPanel
