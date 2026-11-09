--!strict
-- ParkingCard (Lane 3 Round 8, WS-6b: U-02, U-03, U-04, U-06 for the PARKING card; built to R8-IMG-04 desktop, R8-IMG-05 states and
-- R8-IMG-06 phone, from the LAYOUT SPEC tables in review/round8/chatgpt-images/GENERATION-NOTES.md).
--
-- The card is a glossy asphalt frame with painted white bay lines, yellow kerb stripes and chequered corners, a big blue P sign badge
-- over a cream ribbon titled PARKING SPOTS, a window showing the NEXT parking tier (the real tier pieces from ParkingTiers, drawn
-- in a ViewportFrame with your parked cars), the big "6 -> 7 SPOTS" line, a strip of bay icons (a car in its rarity colour, an
-- owned empty bay dashed, the next bay glowing green, a padlock), the orange BUY SPOT button and a round red close button. Built on
-- the R8Kit pieces (KerbFrame, RibbonTitle, PreviewWindow, StatPill.bigNumber, CloseButton, GlossButton, Metrics).
--
-- The card contract (UpgradeCard/CardTypes.luau; ShopPanel forwards kind = "parking" here):
--   ParkingCard.open(source, host)    builds and shows the card in its own ScreenGui (replacing one that is already open)
--   ParkingCard.close(instant?)       ParkingCard.isOpen()    ParkingCard.plot()    ParkingCard.refresh()    ParkingCard.state()
-- Embedding and tests:
--   ParkingCard.new(parent, source, host?, onClose?) -> Card   a card inside any GuiObject; it fits itself and re-fits
--   card:setData(patch)  card:refresh()  card:destroy()  card.Closed (Signal)      ParkingCard.setData(patch) on the open card
--
-- Nothing here prices, charges or saves: the price shown is EconomyPreview.spotPrice (the table the server uses), the Cash shown is
-- host.cashOf() (the server's BetaCash), and BUY only calls source.buy(target), which ShopPanel's owner wires to the BuyParkingSpot
-- remote (no arguments). The server refuses an unaffordable or over-the-top buy and replies on BetaResult (CardHost.onResult); a
-- refusal shows a short red line here and takes no Cash.
--
-- States (U-03): "buy" (orange), "need" (grey, NEED $X MORE, green +), "max" (gold ALL SPOTS OWNED), "busy" (pressed in, waiting for
-- the server and the world's reveal; a press is ignored), and the NEW SPOT! moment after a confirmed buy (confetti and the new bay
-- pops; Reduce Motion: no confetti and no pop, the banner only). Art: AssetIds.UpgradeCards r8_card_parking_* when uploaded (or in a
-- Studio place with Lane3_LocalArt), otherwise the code-drawn version below (UICorner, UIStroke, UIGradient).

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
local Ctx = require(Speedway:WaitForChild("Ctx"))
local Parking = require(Speedway:WaitForChild("Parking"))
local ParkingTiers = require(Speedway:WaitForChild("ParkingTiers"))
local EconomyPreview = require(Shared:WaitForChild("UI"):WaitForChild("EconomyPreview"))
local Format = require(Shared:WaitForChild("UI"):WaitForChild("Format"))
local LiveData = require(Shared:WaitForChild("UI"):WaitForChild("LiveData"))
local RosterFixtures = require(Shared:WaitForChild("UI"):WaitForChild("RosterFixtures"))
local Tokens = require(Shared:WaitForChild("UI"):WaitForChild("Tokens"))
local Signal = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Signal"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local CardHost = require(script.Parent.CardHost)
local CardTypes = require(script.Parent.CardTypes)
local Calm = require(script.Parent.Parent.Calm)

local ClientRoot = script.Parent.Parent.Parent.Parent.Parent
local Prototype = ClientRoot:WaitForChild("UI"):WaitForChild("Prototype")
local R8Kit = Prototype:WaitForChild("R8Kit")
local Art = require(R8Kit:WaitForChild("Art"))
local Build = require(R8Kit:WaitForChild("Build"))
local CloseButton = require(R8Kit:WaitForChild("CloseButton"))
local GlossButton = require(R8Kit:WaitForChild("GlossButton"))
local KerbFrame = require(R8Kit:WaitForChild("KerbFrame"))
local Metrics = require(R8Kit:WaitForChild("Metrics"))
local Palette = require(R8Kit:WaitForChild("Palette"))
local PreviewWindow = require(R8Kit:WaitForChild("PreviewWindow"))
local RibbonTitle = require(R8Kit:WaitForChild("RibbonTitle"))
local StatPill = require(R8Kit:WaitForChild("StatPill"))

local ParkingCard = {}
-- the methods of one card (setData, refresh, destroy); the module's own functions are the card contract below
local CardObj = {}
CardObj.__index = CardObj
local refreshCard: (self: any) -> ()

export type Source = CardTypes.Source
export type Host = CardTypes.Host

-- Overrides of the live reads (every field optional): for tests and the comparison frames.
export type Data = {
	owned: number?,
	max: number?,
	cash: number?, -- the player's Cash
	busy: boolean?,
	failed: string?, -- a refusal line to show (red)
	celebrate: boolean?, -- show the NEW SPOT! moment (and keep it until cleared)
	lineup: { string }?, -- parked car ids by spot
	expanded: boolean?,
}

export type Card = {
	frame: Frame,
	Closed: any,
	setData: (self: Card, patch: Data?) -> (),
	refresh: (self: Card) -> (),
	destroy: (self: Card) -> (),
}

----------------------------------------------------------------------------------------------------
-- Design numbers (design pixels, the reference image's own: one UIScale fits the whole card). Positions come from the LAYOUT SPEC
-- percentages of the reference images measured against the frame (desktop R8-IMG-04 and phone R8-IMG-06 agree to about one point).
----------------------------------------------------------------------------------------------------

local FW = 1280 -- frame width (reference frame 1271)
local FH_REGULAR = 680 -- frame height, desktop and tablet (reference frame 1271 x 676)
local FH_COMPACT = 580 -- phone landscape (reference frame 1412 x 640, a wider card)
local PHONE_SHORT_SIDE = 500
local FIT = 0.94 -- how much of the parent the card (badge to bottom edge) may use

local RARITY_COLOUR: { [string]: Color3 } = {
	Common = Color3.fromRGB(255, 150, 40),
	Uncommon = Color3.fromRGB(70, 220, 110),
	Rare = Color3.fromRGB(60, 150, 255),
	Epic = Color3.fromRGB(176, 92, 246),
	Legendary = Color3.fromRGB(255, 214, 40),
}

local SLOTS = 8 -- bay icons in the strip
local NEXT_WEIGHT = 1.5 -- the NEXT cell is wider so its label reads at the minimum text size on a phone
local NEW_SPOT_SECONDS = 2.6
local FAIL_SECONDS = 4
local LOCK_SECONDS = 6 -- a buy that nothing answers: back to idle and re-read
local POLL_SECONDS = 0.12
local DISPLAY_ORDER = 18 -- the same layer as the other upgrade cards, below the level banner at 20
local SCRIM_TRANSPARENCY = 0.55
local ACTION_NAME = "Lane3ParkingCardClose"

local FRAME_KEY = "r8_card_parking_frame"
local HUMP_KEY = "r8_card_parking_hump"
local RIBBON_KEY = "r8_card_parking_ribbon"
local BADGE_KEY = "r8_card_parking_badge"
local CAR_KEY = "r8_card_parking_car"
local EMPTY_KEY = "r8_card_parking_bay_empty"
local NEXT_KEY = "r8_card_parking_bay_next"
local LOCK_KEY = "r8_card_parking_lock"

local NAVY = Palette.Navy
local ASPHALT = Palette.Asphalt
local ASPHALT_DARK = Color3.fromRGB(37, 41, 50)
local WHITE = Color3.fromRGB(253, 247, 247)

type Layout = {
	fh: number, -- frame height
	rise: number, -- how far the badge stands above the frame
	height: number, -- the whole card, badge to bottom edge
}

local function layoutFor(compact: boolean): Layout
	local fh = if compact then FH_COMPACT else FH_REGULAR
	local rise = if compact then 134 else 156
	return { fh = fh, rise = rise, height = rise + fh }
end

----------------------------------------------------------------------------------------------------
-- Small builders (design pixels)
----------------------------------------------------------------------------------------------------

local make = Build.make

local function corner(parent: Instance, radius: number)
	Build.corner(parent, UDim.new(0, radius))
end

local function stroke(parent: Instance, thickness: number, color: Color3): UIStroke
	return Build.stroke(parent, thickness, color)
end

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return make("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

-- A rectangle at a design-pixel position (transparent unless a colour is given).
local function box(parent: Instance, name: string, x: number, y: number, w: number, h: number, fill: Color3?): Frame
	return make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = fill or Color3.new(1, 1, 1),
		BackgroundTransparency = if fill then 0 else 1,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

-- An ImageLabel of the uploaded art (nil when the key has no art here, so the caller draws the code version).
local function image(
	parent: Instance,
	name: string,
	key: string,
	x: number,
	y: number,
	w: number,
	h: number
): ImageLabel?
	local uri = Art.image(key)
	if uri == "" then
		return nil
	end
	return make("ImageLabel", {
		Name = name,
		Image = uri,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ScaleType = Enum.ScaleType.Stretch,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

-- A text label in a box; `outline` is a navy contextual stroke in design pixels. TextScaled up to maxSize.
local function text(
	parent: Instance,
	name: string,
	value: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	outline: number,
	maxSize: number
): TextLabel
	local label: TextLabel = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		FontFace = Tokens.font(),
		Text = value,
		TextColor3 = color,
		TextScaled = true,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = parent,
	})
	make("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = maxSize, Parent = label })
	if outline > 0 then
		Build.stroke(label, outline, NAVY, Enum.ApplyStrokeMode.Contextual)
	end
	return label
end

local function lineBetween(
	parent: Instance,
	ax: number,
	ay: number,
	bx: number,
	by: number,
	thickness: number,
	color: Color3
): Frame
	local dx, dy = bx - ax, by - ay
	local bar = make("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
		Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + thickness, thickness),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
	corner(bar, math.floor(thickness / 2))
	return bar
end

----------------------------------------------------------------------------------------------------
-- Pieces drawn by this card: uploaded art when the key resolves, else the code-drawn version
----------------------------------------------------------------------------------------------------

-- The arched asphalt hump behind the ribbon.
local function buildHump(parent: Instance, ribbonTop: number)
	local hw = FW * 0.47
	local hh = hw * 200 / 1024
	local x = (FW - hw) / 2
	local y = ribbonTop + 36 - hh
	local art = image(parent, "Hump", HUMP_KEY, x, y, hw, hh)
	if art then
		art.ZIndex = 2
		return
	end
	local hump = box(parent, "Hump", x + hw * 0.025, y + hh * 0.07, hw * 0.95, hh * 0.93, ASPHALT)
	hump.ZIndex = 2
	corner(hump, 110)
	gradient(hump, Color3.fromRGB(74, 80, 93), ASPHALT_DARK, 90)
	stroke(hump, 6, NAVY)
	box(hump, "Kerb", hw * 0.12, 3, hw * 0.24, 16, Palette.Yellow).ZIndex = 3
	box(hump, "Kerb", hw * 0.62, 3, hw * 0.24, 16, Palette.Yellow).ZIndex = 3
end

-- The P badge (the one allowed letter in the art).
local function buildBadge(parent: Instance, fh: number)
	local bw = FW * 0.17
	local bh = bw * 440 / 512
	local x = (FW - bw) / 2
	local y = -0.221 * fh - 0.032 * bh
	local art = image(parent, "Badge", BADGE_KEY, x, y, bw, bh)
	if art then
		art.ZIndex = 4
		return
	end
	local holder = box(parent, "Badge", x, y, bw, bh, nil)
	holder.ZIndex = 4
	local face = box(holder, "Face", bw * 0.035, bh * 0.032, bw * 0.93, bh * 0.855, Palette.Blue)
	corner(face, 40)
	gradient(face, Color3.fromRGB(91, 180, 255), Color3.fromRGB(10, 63, 190), 90)
	stroke(face, 8, NAVY)
	local gloss = box(face, "Gloss", bw * 0.06, 8, bw * 0.4, 14, Color3.new(1, 1, 1))
	gloss.BackgroundTransparency = 0.35
	corner(gloss, 7)
	text(face, "P", "P", 0, 0, bw * 0.93, bh * 0.855, Color3.new(1, 1, 1), 0, 200)
end

-- The yellow kerb stripes and slanted bay dashes the kit's plain asphalt fallback does not draw (only when there is no frame art).
local function decorateAsphalt(parent: Instance, fh: number)
	local seg = 150
	for i = 0, 5 do
		local x = 150 + i * seg * 1.5
		if x + seg < FW - 140 then
			box(parent, "KerbTop", x, 12, seg, 14, Palette.Yellow)
			box(parent, "KerbBottom", x + seg * 0.75, fh - 26, seg, 14, Palette.Yellow)
		end
	end
	for i = 0, 2 do
		local y = 150 + i * (fh - 300) / 3
		box(parent, "KerbLeft", 12, y, 14, 90, Palette.Yellow)
		box(parent, "KerbRight", FW - 26, y + 40, 14, 90, Palette.Yellow)
	end
end

-- A dashed outline of small frames (for the code-drawn empty bay).
local function dashedBay(parent: Instance, w: number, h: number)
	local t, dash, gap = 6, 20, 14
	local function run(x: number, y: number, length: number, horizontal: boolean)
		local count = math.max(1, math.floor((length + gap) / (dash + gap) + 0.5))
		local size = if count == 1 then length else dash
		local space = if count == 1 then 0 else (length - count * size) / (count - 1)
		for i = 0, count - 1 do
			local o = i * (size + space)
			if horizontal then
				corner(box(parent, "Dash", x + o, y, size, t, WHITE), 3)
			else
				corner(box(parent, "Dash", x, y + o, t, size, WHITE), 3)
			end
		end
	end
	local r = 18
	run(r, 0, w - 2 * r, true)
	run(r, h - t, w - 2 * r, true)
	run(0, r, h - 2 * r, false)
	run(w - t, r, h - 2 * r, false)
end

-- The strip icons. Each takes the cell holder and its size and draws centred.
local function drawCar(parent: Instance, w: number, h: number, colour: Color3)
	-- the art's car body is 192 x 372 px inside a 256 x 400 canvas
	local ch = math.min(h * 0.86, w * 0.7 / 0.516)
	local cw = ch * 192 / 372
	local x, y = (w - cw) / 2, (h - ch) / 2
	local k = ch / 372
	local art = image(parent, "Car", CAR_KEY, x - 32 * k, y - 14 * k, 256 * k, 400 * k)
	if art then
		art.ImageColor3 = colour
		art.ZIndex = 4
		return
	end
	local body = box(parent, "Car", x + cw * 0.04, y, cw * 0.92, ch, colour)
	body.ZIndex = 4
	corner(body, math.floor(cw * 0.3))
	gradient(body, colour:Lerp(Color3.new(1, 1, 1), 0.35), colour:Lerp(Color3.new(0, 0, 0), 0.25), 0)
	stroke(body, 4, NAVY)
	local front = box(body, "Windshield", cw * 0.12, ch * 0.3, cw * 0.68, ch * 0.2, Color3.fromRGB(38, 44, 66))
	corner(front, 6)
	local rear = box(body, "RearGlass", cw * 0.14, ch * 0.66, cw * 0.62, ch * 0.14, Color3.fromRGB(38, 44, 66))
	corner(rear, 5)
end

local function drawEmpty(parent: Instance, w: number, h: number)
	-- the dashed rectangle is 188 x 344 px inside a 256 x 400 canvas
	local ch = h * 0.84
	local cw = math.min(w * 0.72, ch * 188 / 344)
	local x, y = (w - cw) / 2, (h - ch) / 2
	local kx, ky = cw / 188, ch / 344
	local art = image(parent, "Empty", EMPTY_KEY, x - 34 * kx, y - 28 * ky, 256 * kx, 400 * ky)
	if art then
		art.ZIndex = 4
		return
	end
	local holder = box(parent, "Empty", x, y, cw, ch, nil)
	holder.ZIndex = 4
	dashedBay(holder, cw, ch)
end

-- The glowing NEXT bay: returns the NEXT label (so it keeps the minimum text size).
local function drawNext(parent: Instance, w: number, h: number): TextLabel
	local cw, ch = w * 0.92, h * 0.74
	local x, y = (w - cw) / 2, h * 0.17
	-- the green square is 212 x 236 px inside a 320 x 400 canvas (the glow and three ticks are around it)
	local kx, ky = cw / 212, ch / 236
	local art = image(parent, "Next", NEXT_KEY, x - 54 * kx, y - 112 * ky, 320 * kx, 400 * ky)
	if art then
		art.ZIndex = 4
	else
		local glow = box(parent, "Glow", x - 6, y - 6, cw + 12, ch + 12, Color3.fromRGB(124, 255, 74))
		glow.BackgroundTransparency = 0.65
		glow.ZIndex = 4
		corner(glow, 30)
		local face = box(parent, "NextFace", x, y, cw, ch, Palette.Green)
		face.ZIndex = 5
		corner(face, 24)
		gradient(face, Color3.fromRGB(140, 255, 90), Color3.fromRGB(30, 158, 46), 90)
		stroke(face, 5, Color3.fromRGB(185, 255, 154))
		for i, t in { { 0.5, -22, 0 }, { 0.2, -16, -18 }, { 0.8, -16, 18 } } do
			local tick = box(parent, "Tick" .. i, x + cw * t[1] - 4, y + t[2], 8, 18, Color3.fromRGB(180, 255, 140))
			tick.ZIndex = 5
			tick.Rotation = t[3]
			corner(tick, 4)
		end
	end
	local label = text(parent, "NextText", "NEXT", x, y + ch * 0.28, cw, ch * 0.44, Color3.new(1, 1, 1), 4, 40)
	label.ZIndex = 8
	return label
end

local function drawLock(parent: Instance, w: number, h: number)
	local s = math.min(w * 0.7, h * 0.4)
	local x, y = (w - s) / 2, (h - s) / 2
	local art = image(parent, "Lock", LOCK_KEY, x, y, s, s)
	if art then
		art.ZIndex = 4
		return
	end
	local holder = box(parent, "Lock", x, y, s, s, nil)
	holder.ZIndex = 4
	local shackle = box(holder, "Shackle", s * 0.26, s * 0.02, s * 0.48, s * 0.55, nil)
	corner(shackle, math.floor(s * 0.22))
	stroke(shackle, math.max(4, math.floor(s * 0.12)), Palette.Chrome)
	local body = box(holder, "Body", s * 0.1, s * 0.42, s * 0.8, s * 0.52, Palette.Gold)
	body.ZIndex = 2
	corner(body, math.floor(s * 0.14))
	gradient(body, Color3.fromRGB(255, 233, 138), Palette.GoldDeep, 90)
	stroke(body, 4, NAVY)
	local hole = box(body, "Hole", s * 0.32, s * 0.12, s * 0.16, s * 0.16, NAVY)
	corner(hole, math.floor(s * 0.08))
	box(body, "Slot", s * 0.37, s * 0.22, s * 0.06, s * 0.16, NAVY)
end

-- The green arrow of "6 -> 7" (the kit's r8_card_arrow, or a code-drawn one).
local function drawArrow(parent: Instance, w: number, h: number)
	local img: ImageLabel = make("ImageLabel", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(w, h),
		Parent = parent,
	})
	if Art.apply(img, "r8_card_arrow") then
		return
	end
	img.Visible = true
	local function strokes(thickness: number, color: Color3)
		lineBetween(img, w * 0.1, h * 0.5, w * 0.8, h * 0.5, thickness, color)
		lineBetween(img, w * 0.55, h * 0.12, w * 0.88, h * 0.5, thickness, color)
		lineBetween(img, w * 0.55, h * 0.88, w * 0.88, h * 0.5, thickness, color)
	end
	strokes(h * 0.34, NAVY)
	strokes(h * 0.22, Palette.GreenLight)
end

----------------------------------------------------------------------------------------------------
-- The state
----------------------------------------------------------------------------------------------------

type View = {
	owned: number,
	max: number,
	expanded: boolean,
	price: number?,
	cash: number?,
	need: number?, -- how much Cash is missing (0 or nil = enough)
	state: string, -- "buy" | "need" | "max" | "busy" | "disabled"
	worldBusy: boolean, -- the world's reveal for a change is still running
	celebrating: boolean,
	failed: string?,
	lineup: { string },
}

type Self = {
	frame: Frame,
	Closed: any,
	source: Source,
	host: Host?,
	onClose: (() -> ())?,
	parent: GuiObject,
	trove: any,
	root: Frame,
	scale: UIScale,
	fitScale: number,
	popFactor: number,
	layout: Layout,
	metrics: any,
	override: Data?,
	pending: { target: number, at: number }?,
	celebratingUntil: number,
	failedText: string?,
	failedUntil: number,
	serverMissing: number?,
	lastOwned: number,
	lastSig: string,
	lastView: View?,
	pollClock: number,
	destroyed: boolean,
	small: { TextLabel },
	-- widgets
	kerb: any,
	window: any,
	pill: Frame?,
	numFrom: TextLabel?,
	numTo: TextLabel?,
	arrow: Frame?,
	word: TextLabel?,
	stripHolder: Frame?,
	stripSig: string,
	stripKinds: { [string]: number },
	button: any,
	moreButton: TextButton?,
	failPill: Frame?,
	failLabel: TextLabel?,
	notePill: Frame?,
	tagText: string?,
	sceneViewport: ViewportFrame?,
	sceneSig: string,
	sceneTrove: Trove.Trove,
	sceneStats: { parts: number, cars: number },
	tweens: { [Tween]: boolean },
}

local function isCompact(parent: GuiObject): boolean
	local player = Players.LocalPlayer
	local profile = player and player:GetAttribute("Lane3ScreenProfile")
	if profile == "PhoneLandscape" then
		return true
	elseif profile == "Tablet" or profile == "Desktop" then
		return false
	end
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else parent.AbsoluteSize
	return math.min(viewport.X, viewport.Y) < PHONE_SHORT_SIDE
end

-- The price of the next spot: the PREVIEW ladder is indexed by BOUGHT spots, and the pass's three bays are not bought.
local function nextPrice(owned: number, expanded: boolean): number?
	local extra = if expanded then Parking.ExpandedSpots else 0
	return EconomyPreview.spotPrice(owned - extra + 1)
end

local function readNumber(fn: (() -> number)?, fallback: number): number
	if fn == nil then
		return fallback
	end
	local ok, value = pcall(fn)
	if ok and type(value) == "number" then
		return value
	end
	return fallback
end

local function cashNow(self: Self): number?
	local o = self.override
	if o and o.cash ~= nil then
		return o.cash
	end
	local host = self.host
	if host then
		local ok, value = pcall(host.cashOf)
		if ok and type(value) == "number" then
			return value
		end
		return nil
	end
	return LiveData.cash()
end

local function derive(self: Self): View
	local o = self.override
	local plot = self.source.plot
	local expanded = if o and o.expanded ~= nil then o.expanded else Parking.hasExpanded(plot)
	local max = if o and o.max then o.max else Parking.maxFor(plot)
	local owned = if o and o.owned then o.owned else readNumber(self.source.current, Parking.StartSpots)
	owned = math.clamp(math.floor(owned), 1, max)
	local price = if owned >= max then nil else nextPrice(owned, expanded)
	local cash = cashNow(self)
	local need: number? = nil
	if price and cash ~= nil then
		need = math.max(0, price - cash)
	elseif price and self.serverMissing then
		need = self.serverMissing
	end
	local busyWorld = false
	if o and o.busy ~= nil then
		busyWorld = o.busy
	else
		local ok, value = pcall(self.source.busy)
		busyWorld = ok and value == true
	end
	local now = os.clock()
	local celebrating = (o ~= nil and o.celebrate == true) or now < self.celebratingUntil
	local state: string
	if owned >= max then
		state = "max"
	elseif self.source.buy == nil or price == nil then
		state = "disabled"
	elseif self.pending ~= nil or busyWorld then
		state = "busy"
	elseif need ~= nil and need > 0 then
		state = "need"
	else
		state = "buy"
	end
	local failed = (o and o.failed) or (if now < self.failedUntil then self.failedText else nil)
	local lineup = if o and o.lineup then o.lineup else LiveData.lineup()
	return {
		owned = owned,
		max = max,
		expanded = expanded,
		price = price,
		cash = cash,
		need = need,
		state = state,
		worldBusy = busyWorld,
		celebrating = celebrating,
		failed = failed,
		lineup = lineup,
	}
end

-- The strip's cells for a view: always SLOTS slots when the Paddock has that many bays to show. The window shows the last owned bays,
-- then the NEXT bay (never during the NEW SPOT! moment), then a padlock for the bays still locked (more padlocks while few are owned).
type Cell = { kind: string, bay: number, rarity: string? }

local function buildCells(view: View): { Cell }
	local owned, max = view.owned, view.max
	local showNext = not view.celebrating
	local remaining = max - owned
	local nextCell = if showNext and remaining > 0 then 1 else 0
	local locks = if remaining - nextCell > 0 then 1 else 0
	local ownedCells = math.min(owned, SLOTS - nextCell - locks)
	local extra = SLOTS - nextCell - locks - ownedCells
	if extra > 0 then
		locks += math.min(extra, math.max(remaining - nextCell - locks, 0))
	end
	local cells: { Cell } = {}
	for bay = owned - ownedCells + 1, owned do
		local id = view.lineup[bay]
		local car = if id then RosterFixtures.byId(id) else nil
		if car then
			table.insert(cells, { kind = "car", bay = bay, rarity = car.rarity })
		else
			table.insert(cells, { kind = "empty", bay = bay })
		end
	end
	if nextCell == 1 then
		table.insert(cells, { kind = "next", bay = owned + 1 })
	end
	for i = 1, locks do
		table.insert(cells, { kind = "lock", bay = owned + nextCell + i })
	end
	return cells
end

local function signatureOf(view: View): string
	return table.concat({
		view.owned,
		view.max,
		view.state,
		tostring(view.celebrating),
		tostring(view.failed),
		tostring(view.price),
		tostring(if view.need then math.floor(view.need) else "-"),
		table.concat(view.lineup, ","),
	}, "|")
end

----------------------------------------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------------------------------------

-- The small labels keep the style guide minimum in REAL pixels (16 / scale design pixels); destroyed labels drop out of the list.
local function applyMinText(self: Self)
	local keep: { TextLabel } = {}
	for _, label in self.small do
		if label.Parent ~= nil then
			table.insert(keep, label)
			local c = label:FindFirstChildOfClass("UITextSizeConstraint")
			if c then
				c.MinTextSize = self.metrics:textSize(16)
			end
		end
	end
	self.small = keep
end

local function track(self: Self, tween: Tween)
	self.tweens[tween] = true
	tween.Completed:Once(function()
		self.tweens[tween] = nil
		tween:Destroy()
	end)
	tween:Play()
end

-- "6 -> 7 SPOTS" (two numbers and the arrow), or "8 SPOTS" / "7 SPOTS" (one green number) at the top and in the NEW SPOT! moment.
local function setStat(self: Self, view: View)
	local pill = self.pill
	local from, to, arrow, word = self.numFrom, self.numTo, self.arrow, self.word
	if not (pill and from and to and arrow and word) then
		return
	end
	local ph = self.layout.fh * 0.209
	local pw = FW * 0.495
	local two = view.owned < view.max and not view.celebrating
	local numW, arrowW, gap = pw * 0.15, pw * 0.13, pw * 0.02
	local wordW = pw * 0.34
	local total = if two then numW * 2 + arrowW + gap * 4 + wordW else numW + gap * 2 + wordW
	local x = (pw - total) / 2
	local numH = ph * 0.84
	local y = (ph - numH) / 2
	local function put(label: GuiObject, lx: number, lw: number, ly: number?, lh: number?)
		label.Position = UDim2.fromOffset(lx, ly or y)
		label.Size = UDim2.fromOffset(lw, lh or numH)
	end
	from.Visible = two
	arrow.Visible = two
	to.Visible = true
	if two then
		from.Text = tostring(view.owned)
		to.Text = tostring(view.owned + 1)
		put(from, x, numW)
		put(arrow, x + numW + gap, arrowW, ph * 0.26, ph * 0.48)
		put(to, x + numW + gap * 2 + arrowW, numW)
		put(word, x + numW * 2 + arrowW + gap * 4, wordW)
	else
		to.Text = tostring(view.owned)
		put(to, x, numW)
		put(word, x + numW + gap * 2, wordW)
	end
end

local function popCell(self: Self, cell: GuiObject)
	if Calm() then
		return
	end
	local s = make("UIScale", { Scale = 0.55, Parent = cell })
	track(
		self,
		TweenService:Create(s, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	)
	task.delay(0.5, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function setStrip(self: Self, view: View, popBay: number?)
	local holder = self.stripHolder
	if not holder then
		return
	end
	local sig = table.concat({ view.owned, view.max, tostring(view.celebrating), table.concat(view.lineup, ",") }, "|")
	if sig == self.stripSig then
		return
	end
	self.stripSig = sig
	for _, child in holder:GetChildren() do
		child:Destroy()
	end
	local cells = buildCells(view)
	local kinds: { [string]: number } = {}
	for _, c in cells do
		kinds[c.kind] = (kinds[c.kind] or 0) + 1
	end
	self.stripKinds = kinds
	local W, H = holder.Size.X.Offset, holder.Size.Y.Offset
	local weights = 0
	for _, c in cells do
		weights += if c.kind == "next" then NEXT_WEIGHT else 1
	end
	local unit = W / math.max(weights, 1)
	local x = 0
	for i, c in cells do
		local w = unit * (if c.kind == "next" then NEXT_WEIGHT else 1)
		local cell = box(holder, "Cell" .. i, x, 0, w, H, nil)
		cell.ZIndex = 3
		if i > 1 then
			-- the painted white line between bays
			local line = box(holder, "Divider" .. i, x - 2, H * 0.06, 4, H * 0.88, WHITE)
			line.ZIndex = 3
		end
		if c.kind == "car" then
			drawCar(cell, w, H, RARITY_COLOUR[c.rarity or "Common"] or RARITY_COLOUR.Common)
		elseif c.kind == "empty" then
			drawEmpty(cell, w, H)
		elseif c.kind == "next" then
			table.insert(self.small, drawNext(cell, w, H))
		else
			drawLock(cell, w, H)
		end
		if popBay and c.bay == popBay and c.kind ~= "next" then
			popCell(self, cell)
		end
		x += w
	end
	applyMinText(self) -- the NEXT label keeps the minimum text size
end

-- Confetti from the button: a handful of small coloured pieces that fall and fade. Reduce Motion: none.
local function confetti(self: Self)
	if Calm() then
		return
	end
	local fh = self.layout.fh
	local ox, oy = FW * 0.455 + FW * 0.2475, self.layout.rise + fh * 0.78
	local colors = {
		Palette.GoldBright,
		Palette.GreenLight,
		Palette.Red,
		Color3.fromRGB(60, 150, 255),
		Color3.fromRGB(255, 150, 40),
		WHITE,
	}
	local rng = Random.new(math.floor(os.clock() * 1000))
	for i = 1, 26 do
		local piece = box(
			self.root,
			"Confetti",
			ox,
			oy,
			rng:NextInteger(10, 18),
			rng:NextInteger(8, 14),
			colors[(i % #colors) + 1]
		)
		piece.ZIndex = 30
		piece.Rotation = rng:NextInteger(0, 180)
		corner(piece, 3)
		local angle = rng:NextNumber(-math.pi * 0.95, -math.pi * 0.05)
		local dist = rng:NextNumber(120, 340)
		local tx, ty = ox + math.cos(angle) * dist, oy + math.sin(angle) * dist + rng:NextNumber(40, 120)
		local info = TweenInfo.new(rng:NextNumber(0.7, 1.15), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		track(
			self,
			TweenService:Create(piece, info, {
				Position = UDim2.fromOffset(tx, ty),
				Rotation = piece.Rotation + rng:NextInteger(-260, 260),
				BackgroundTransparency = 1,
			})
		)
		task.delay(1.3, function()
			if piece.Parent then
				piece:Destroy()
			end
		end)
	end
end

local function playFanfare()
	local ok, Sounds = pcall(function()
		return require(Prototype:WaitForChild("Sounds"))
	end)
	if ok and Sounds then
		pcall(function()
			(Sounds :: any).play("Unlock", 0.6)
		end)
	end
end

local function setButton(self: Self, view: View)
	local b = self.button
	if not b then
		return
	end
	local price = if view.price then Format.cash(view.price) else nil
	local qw, qh = FW * 0.495, self.layout.fh * 0.223
	local more = self.moreButton
	local wantMore = view.state == "max" and not view.expanded and not view.celebrating
	local host = self.host
	wantMore = wantMore and host ~= nil and host.onMoreSpots ~= nil
	b.frame.Size = UDim2.fromOffset(if wantMore then qw * 0.64 else qw, qh)
	if more then
		more.Visible = wantMore
	end
	if view.celebrating then
		b:setState("done", { doneText = "NEW SPOT!", doneTone = "green" })
	elseif view.state == "max" then
		b:setState("max", { maxText = "ALL SPOTS OWNED", maxStyle = "banner" })
	elseif view.state == "need" then
		b:setState("need", { label = "BUY SPOT", price = price, need = Format.cash(view.need or 0), icon = "cash" })
	elseif view.state == "busy" then
		b:setState("busy", { label = "BUY SPOT", price = price, icon = "cash" })
	elseif view.state == "disabled" then
		b:setState("disabled", { label = "BUY SPOT", price = price, icon = "cash" })
	else
		b:setState("buy", { label = "BUY SPOT", price = price, icon = "cash" })
	end
end

local function setFooter(self: Self, view: View)
	local fail, note = self.failPill, self.notePill
	if fail and self.failLabel then
		fail.Visible = view.failed ~= nil
		if view.failed then
			self.failLabel.Text = view.failed
		end
	end
	if note then
		note.Visible = view.failed == nil
	end
end

-- "NEW LOOK" on the window when buying the next spot changes the Paddock's tier.
local function setTag(self: Self, view: View)
	local want: string? = nil
	if view.state ~= "max" and not view.celebrating then
		local now = ParkingTiers.tierOf(view.owned)
		local next = ParkingTiers.tierOf(math.min(view.owned + 1, view.max))
		if next > now then
			want = "NEW LOOK"
		end
	end
	if want ~= self.tagText then
		self.tagText = want
		self.window:setTag(want)
		local label = self.window.tag :: TextLabel?
		if label then
			table.insert(self.small, label)
			applyMinText(self)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- The next-tier window: the REAL tier pieces (ParkingTiers via Parking.build) in a ViewportFrame, with your parked cars
----------------------------------------------------------------------------------------------------

local function fitCar(model: Model, length: number, width: number)
	local _, size = model:GetBoundingBox()
	local fit = math.min(length / math.max(size.Z, 0.01), width / math.max(size.X, 0.01))
	model:ScaleTo(model:GetScale() * fit)
end

local function destroyScene(self: Self)
	self.sceneTrove:Clean()
	self.sceneViewport = nil
	self.sceneSig = ""
end

local function buildScene(self: Self, view: View)
	local window = self.window
	if window == nil or self.destroyed then
		return
	end
	local showSpots = if view.owned < view.max and not view.celebrating then view.owned + 1 else view.owned
	local sig = table.concat({ showSpots, tostring(view.expanded), table.concat(view.lineup, ",") }, "|")
	if sig == self.sceneSig then
		return
	end
	destroyScene(self)
	self.sceneSig = sig

	local viewport: ViewportFrame = make("ViewportFrame", {
		Name = "Scene",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(178, 180, 194),
		LightColor = Color3.fromRGB(255, 248, 232),
		LightDirection = Vector3.new(-0.5, -1, 0.35),
		Parent = window.content,
	})
	self.sceneTrove:Add(viewport)
	self.sceneViewport = viewport
	local world = make("WorldModel", { Parent = viewport })

	-- the real tier pieces, built into a scratch plot that never enters the Workspace
	local scratch = Instance.new("Model")
	scratch.Name = "ParkingPreviewPlot"
	if view.expanded then
		scratch:SetAttribute(Parking.ExpandedAttribute, true)
	end
	local ctx = Ctx.new(scratch, 1, 0, 1, "")
	local ok, built = pcall(Parking.build, scratch, ctx, showSpots)
	if self.destroyed or viewport.Parent == nil then
		scratch:Destroy()
		return -- the card closed (or the view changed) while the pieces were being made
	end
	local parts = 0
	if ok and built then
		local folder = built.folder
		for _, d in folder:GetDescendants() do
			if d:IsA("SurfaceGui") or d:IsA("Light") or d:IsA("ProximityPrompt") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				parts += 1
			end
		end
		folder.Parent = world
	end
	scratch:Destroy()

	-- grass around the paddock, so the window shows ground under the sky
	make("Part", {
		Name = "Grass",
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(900, 0.2, 900),
		Position = Vector3.new(0, -0.05, -290),
		Color = Color3.fromRGB(104, 190, 64),
		Material = Enum.Material.Grass,
		Parent = world,
	})
	parts += 1

	-- parked cars in their bays
	local expanded = view.expanded
	local cars = 0
	local okCar, RealCar = pcall(function()
		return require(Prototype:WaitForChild("RealCar"))
	end)
	if okCar and RealCar then
		for bayIndex = 1, math.min(view.owned, #view.lineup) do
			local entry = RosterFixtures.byId(view.lineup[bayIndex])
			local bay = Parking.bay(bayIndex, expanded)
			if entry and bay then
				local model = (RealCar :: any).displayModel(entry.model)
				if model then
					fitCar(model, 11.5, 6.6)
					local mid = (bay.back + bay.mouth) / 2
					local at = Ctx.at(ctx, bay.x, mid, 0.3)
					local toward = Ctx.dir(ctx, -Parking.opening(bay))
					model:PivotTo(CFrame.lookAt(at, at + toward))
					model.Parent = world
					cars += 1
					for _, d in model:GetDescendants() do
						if d:IsA("BasePart") then
							parts += 1
						end
					end
				end
			end
		end
	end
	self.sceneStats = { parts = parts, cars = cars }

	-- the new bay glows green
	if view.owned < view.max and not view.celebrating then
		local bay = Parking.bay(showSpots, expanded)
		local glow = make("Part", {
			Name = "NewBayGlow",
			Anchored = true,
			CanCollide = false,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(110, 255, 90),
			Transparency = 0.55,
			Size = Vector3.new(Parking.BayHalfWidth * 2 - 0.6, 0.06, (bay.mouth - bay.back) - 0.8),
			CFrame = CFrame.new(Ctx.at(ctx, bay.x, (bay.back + bay.mouth) / 2, 0.34)),
			Parent = world,
		})
		if not Calm() then
			local pulse = TweenService:Create(
				glow,
				TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.8 }
			)
			pulse:Play()
			self.sceneTrove:Add(function()
				pulse:Cancel()
				pulse:Destroy()
			end)
		end
	end

	-- camera: from the aisle side of row A, looking across the rows at the canopy; a slow sway unless Reduce Motion
	local camera = make("Camera", { FieldOfView = 46, Parent = viewport })
	viewport.CurrentCamera = camera
	local centre = Ctx.at(ctx, 0, (Parking.RowA[1] + Parking.RowB[2]) / 2, 2)
	local back = if expanded then 94 else 78
	local function place(sway: number)
		local from = centre + Vector3.new(-14 + sway * 40, 28, back)
		camera.CFrame = CFrame.lookAt(from, centre + Vector3.new(0, -2, 0))
	end
	place(0)
	if not Calm() then
		local started = os.clock()
		local acc = 0
		self.sceneTrove:Add(RunService.Heartbeat:Connect(function(dt: number)
			acc += dt
			if acc < 1 / 24 then
				return
			end
			acc = 0
			place(math.sin((os.clock() - started) * 0.35) * 0.22)
		end))
	end
end

----------------------------------------------------------------------------------------------------
-- The card
----------------------------------------------------------------------------------------------------

local function applyScale(self: Self)
	self.scale.Scale = self.fitScale * self.popFactor
end

local function refit(self: Self)
	if self.destroyed then
		return
	end
	local size = self.parent.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local fit = math.min(size.X * FIT / FW, size.Y * FIT / self.layout.height)
	self.fitScale = fit
	applyScale(self)
	self.metrics:setScale(fit)
	self.root.Visible = true
end

local function startCelebration(self: Self)
	self.celebratingUntil = os.clock() + NEW_SPOT_SECONDS
	confetti(self)
	playFanfare()
end

local function onBuyPressed(self: Self)
	if self.destroyed or self.pending then
		return
	end
	local view = derive(self)
	if view.state ~= "buy" then
		return
	end
	local buy = self.source.buy
	if buy == nil then
		return
	end
	-- locked before the request runs, so a second press in the same frame can never get through
	self.pending = { target = view.owned + 1, at = os.clock() }
	self.failedUntil = 0
	local ok, err = pcall(buy, view.owned + 1)
	if not ok then
		warn("ParkingCard: the purchase request failed: " .. tostring(err))
		self.pending = nil
	end
	refreshCard(self)
end

local function poll(self: Self)
	local p = self.pending
	if p then
		local view = derive(self)
		local waited = os.clock() - p.at
		if view.owned >= p.target and not view.worldBusy then
			-- confirmed and shown: the NEW SPOT! moment
			self.pending = nil
			startCelebration(self)
		elseif view.owned >= p.target then
			-- bought, the world's reveal is still running: keep the busy button
			p.at = os.clock()
		elseif waited >= LOCK_SECONDS then
			self.pending = nil -- nothing answered: back to idle, the next read shows the truth
		end
	end
	refreshCard(self)
end

function ParkingCard.new(parent: GuiObject, source: Source, host: Host?, onClose: (() -> ())?): Card
	local trove = Trove.new()
	local compact = isCompact(parent)
	local layout = layoutFor(compact)
	local fh = layout.fh
	local metrics = Metrics.new(Vector2.new(FW, layout.height))

	local root: Frame = trove:Add(make("Frame", {
		Name = "ParkingCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(FW, layout.height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true, -- a tap on the card is not a tap on the world behind it
	}))
	local scale: UIScale = make("UIScale", { Parent = root })

	local self: Self = setmetatable(
		{
			frame = root,
			Closed = Signal.new(),
			source = source,
			host = host,
			onClose = onClose,
			parent = parent,
			trove = trove,
			root = root,
			scale = scale,
			fitScale = 1,
			popFactor = 1,
			layout = layout,
			metrics = metrics,
			override = nil,
			pending = nil,
			celebratingUntil = 0,
			failedText = nil,
			failedUntil = 0,
			serverMissing = nil,
			lastOwned = -1,
			lastSig = "",
			lastView = nil,
			pollClock = 0,
			destroyed = false,
			small = {},
			kerb = nil,
			window = nil,
			pill = nil,
			numFrom = nil,
			numTo = nil,
			arrow = nil,
			word = nil,
			stripHolder = nil,
			stripSig = "",
			stripKinds = {},
			button = nil,
			moreButton = nil,
			failPill = nil,
			failLabel = nil,
			notePill = nil,
			tagText = nil,
			sceneViewport = nil,
			sceneSig = "",
			sceneTrove = Trove.new(),
			sceneStats = { parts = 0, cars = 0 },
			tweens = {},
		} :: any,
		CardObj
	) :: any
	trove:Add(self.Closed, "DisconnectAll")
	trove:Add(self.sceneTrove)
	trove:Add(function()
		metrics:destroy()
	end)

	-- ---- the soft shadow, then the frame (KerbFrame, kind asphalt) with its cream panel; the card's pieces go in its content layer
	local shadow = box(root, "Shadow", 6, layout.rise + 14, FW - 12, fh - 4, NAVY)
	shadow.BackgroundTransparency = 0.72
	shadow.ZIndex = 0
	corner(shadow, 70)
	local kerb = KerbFrame.new(root, {
		kind = "asphalt",
		size = UDim2.fromOffset(FW, fh),
		position = UDim2.fromOffset(0, layout.rise),
		artKey = FRAME_KEY,
		thickness = 40,
		radius = 60,
		metrics = metrics,
	})
	trove:Add(function()
		kerb:destroy()
	end)
	self.kerb = kerb
	local content = kerb.content
	if not kerb.usesArt then
		decorateAsphalt(content, fh)
	end

	-- ---- the hump, the ribbon with its title, the badge
	local bandW = FW * 0.45
	local bandH = bandW * 150 / 1024
	local bandX = (FW - bandW) / 2
	local bandY = fh * 0.146 - bandH
	buildHump(content, bandY)
	if Art.has(RIBBON_KEY) then
		local ribbon = RibbonTitle.new(content, {
			text = "PARKING SPOTS",
			size = UDim2.fromOffset(bandW, bandH),
			position = UDim2.fromOffset(bandX, bandY),
			zIndex = 3,
			textSize = 58,
			artKey = RIBBON_KEY,
			metrics = metrics,
		})
		trove:Add(function()
			ribbon:destroy()
		end)
		-- navy words on the cream band (the kit's default is white words on the chequered flag)
		ribbon.label.TextColor3 = NAVY
		local outline = ribbon.label:FindFirstChildOfClass("UIStroke")
		if outline then
			outline:Destroy()
		end
	else
		local band = box(content, "Band", bandX, bandY, bandW, bandH, Palette.CreamLight)
		band.ZIndex = 3
		corner(band, 22)
		gradient(band, Color3.fromRGB(255, 251, 239), Color3.fromRGB(235, 212, 174), 90)
		stroke(band, 7, NAVY)
		local gloss = box(band, "Gloss", 22, 6, bandW - 44, 6, Color3.new(1, 1, 1))
		gloss.BackgroundTransparency = 0.2
		corner(gloss, 3)
		local title =
			text(band, "Title", "PARKING SPOTS", bandW * 0.1, bandH * 0.12, bandW * 0.8, bandH * 0.76, NAVY, 0, 58)
		table.insert(self.small, title)
	end
	buildBadge(content, fh)
	local close = CloseButton.new(content, {
		size = FW * 0.092,
		position = UDim2.fromOffset(FW * 0.892, -0.039 * fh),
		zIndex = 14,
		metrics = metrics,
	})
	trove:Add(function()
		close:destroy()
	end)
	trove:Add(close.Pressed:Connect(function()
		self.Closed:Fire()
		if self.onClose then
			self.onClose()
		end
	end))

	-- ---- the preview window (a tag appears when the next spot changes the Paddock's look)
	local window = PreviewWindow.new(content, {
		size = UDim2.fromOffset(FW * 0.40, fh * 0.727),
		position = UDim2.fromOffset(FW * 0.04, fh * 0.164),
		zIndex = 7,
		metrics = metrics,
	})
	trove:Add(function()
		window:destroy()
	end)
	self.window = window

	-- ---- the "6 -> 7 SPOTS" pill: the kit's pill art (or a cream rounded frame) and StatPill.bigNumber numbers
	local sx, sy, sw, sh = FW * 0.455, fh * 0.171, FW * 0.495, fh * 0.209
	local pill = box(content, "Stat", sx, sy, sw, sh, nil)
	pill.ZIndex = 7
	local pillArt: ImageLabel = make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = pill,
	})
	if Art.apply(pillArt, "r8_card_pill") then
		Art.fitSlice(trove, pillArt, "r8_card_pill", "y")
	else
		local fill = box(pill, "Fill", 0, 0, sw, sh, Palette.CreamLight)
		fill.Size = UDim2.fromScale(1, 1)
		corner(fill, 40)
		gradient(fill, Color3.fromRGB(255, 249, 232), Color3.fromRGB(240, 222, 188), 90)
		stroke(fill, 4, Color3.fromRGB(205, 178, 128))
	end
	local numbers = box(pill, "Numbers", 0, 0, sw, sh, nil)
	numbers.Size = UDim2.fromScale(1, 1)
	numbers.ZIndex = 2
	self.pill = numbers
	self.numFrom = StatPill.bigNumber(numbers, "0", { designSize = 150, tone = "gold", zIndex = 3, metrics = metrics })
	self.numTo = StatPill.bigNumber(numbers, "0", { designSize = 150, tone = "green", zIndex = 3, metrics = metrics })
	local arrowHolder = box(numbers, "ArrowHolder", 0, 0, sw * 0.13, sh * 0.48, nil)
	arrowHolder.ZIndex = 3
	drawArrow(arrowHolder, sw * 0.13, sh * 0.48)
	self.arrow = arrowHolder
	self.word = text(numbers, "Word", "SPOTS", 0, 0, 100, 100, NAVY, 0, 120)
	self.word.ZIndex = 3

	-- ---- the bay strip
	local bx, by, bw, bh = FW * 0.455, fh * 0.41, FW * 0.495, fh * 0.223
	local chrome = box(content, "Strip", bx, by, bw, bh, Palette.Chrome)
	chrome.ZIndex = 7
	corner(chrome, 38)
	gradient(chrome, Color3.fromRGB(233, 237, 246), Color3.fromRGB(146, 156, 182), 90)
	stroke(chrome, 5, NAVY)
	local asphalt = box(chrome, "Asphalt", 10, 10, bw - 20, bh - 20, ASPHALT)
	asphalt.ZIndex = 2
	corner(asphalt, 30)
	gradient(asphalt, Color3.fromRGB(70, 76, 88), ASPHALT_DARK, 90)
	local cellHolder = box(asphalt, "Cells", 8, 8, bw - 36, bh - 36, nil)
	cellHolder.ZIndex = 3
	self.stripHolder = cellHolder

	-- ---- the button (R8Kit.GlossButton)
	local qx, qy, qw, qh = FW * 0.455, fh * 0.666, FW * 0.495, fh * 0.223
	local button = GlossButton.new(content, {
		size = UDim2.fromOffset(qw, qh),
		position = UDim2.fromOffset(qx, qy),
		label = "BUY SPOT",
		icon = "cash",
		zIndex = 8,
		metrics = metrics,
	})
	self.button = button
	trove:Add(function()
		button:destroy()
	end)
	trove:Add(button.Pressed:Connect(function()
		onBuyPressed(self)
	end))
	trove:Add(button.PlusPressed:Connect(function()
		local h = self.host
		if h and h.onCashShop then
			h.onCashShop()
		end
	end))

	-- a small MORE SPOTS button next to the gold badge (a full Paddock without the pass, when the host gave a handler)
	local more: TextButton = make("TextButton", {
		Name = "MoreSpots",
		Position = UDim2.fromOffset(qx + qw * 0.67, qy + qh * 0.08),
		Size = UDim2.fromOffset(qw * 0.33, qh * 0.84),
		BackgroundColor3 = Palette.CreamLight,
		AutoButtonColor = true,
		Text = "",
		Visible = false,
		ZIndex = 12,
		Parent = content,
	})
	corner(more, 30)
	stroke(more, 5, NAVY)
	local moreText = text(more, "Text", "MORE SPOTS", 10, 8, qw * 0.33 - 20, qh * 0.84 - 16, NAVY, 0, 40)
	table.insert(self.small, moreText)
	trove:Connect(more.Activated, function()
		local h = self.host
		if h and h.onMoreSpots then
			h.onMoreSpots()
		end
	end)
	self.moreButton = more

	-- ---- the bottom ring: the PREVIEW note (left) or a refusal line (centre, red)
	local ny = fh - 52
	local note = box(content, "Note", FW * 0.05, ny, FW * 0.19, 42, ASPHALT_DARK)
	note.ZIndex = 12
	corner(note, 21)
	local betaPlace = ReplicatedStorage:FindFirstChild("CarHopBeta") ~= nil
	local noteText = text(
		note,
		"Text",
		if betaPlace then "PREVIEW prices" else "Studio preview",
		6,
		2,
		FW * 0.19 - 12,
		38,
		Palette.CreamLight,
		0,
		30
	)
	table.insert(self.small, noteText)
	self.notePill = note
	local fail = box(content, "Refused", FW * 0.25, ny - 4, FW * 0.5, 50, Palette.Red)
	fail.ZIndex = 14
	corner(fail, 25)
	stroke(fail, 4, NAVY)
	gradient(fail, Color3.fromRGB(255, 110, 100), Palette.RedDeep, 90)
	local failText = text(fail, "Text", "", 16, 3, FW * 0.5 - 32, 44, Color3.new(1, 1, 1), 3, 34)
	table.insert(self.small, failText)
	fail.Visible = false
	self.failPill, self.failLabel = fail, failText

	trove:Add(metrics.changed:Connect(function()
		applyMinText(self)
	end))
	applyMinText(self)

	root.Visible = false -- shown by the first fit, so the card never flashes at full size
	root.Parent = parent

	-- ---- live inputs: the server's refusal lines, Cash, and the 8 Hz poll
	trove:Add(CardHost.onResult("BuyParkingSpot", function(ok: boolean, reason: string?, missing: number?)
		if self.destroyed or ok then
			return -- confirmed: the world's count arrives through source.current() and the poll celebrates
		end
		self.pending = nil
		self.failedText = reason or "Not now."
		self.failedUntil = os.clock() + FAIL_SECONDS
		if missing ~= nil then
			self.serverMissing = missing
		end
		refreshCard(self)
	end))
	local player = Players.LocalPlayer
	if player then
		trove:Add(LiveData.changed(player, "cash", function()
			self.serverMissing = nil
			refreshCard(self)
		end))
	end
	trove:Add(RunService.Heartbeat:Connect(function(dt: number)
		self.pollClock += dt
		if self.pollClock >= POLL_SECONDS then
			self.pollClock = 0
			poll(self)
		end
	end))
	trove:Connect(parent:GetPropertyChangedSignal("AbsoluteSize"), function()
		refit(self)
	end)
	refit(self)
	self.lastOwned = derive(self).owned
	refreshCard(self)
	return self :: any
end

function CardObj.setData(self: Self, patch: Data?)
	self.override = patch
	if patch and patch.celebrate == true then
		startCelebration(self)
	end
	self.lastSig = ""
	refreshCard(self)
end

CardObj.refresh = function(self: Self)
	refreshCard(self)
end

refreshCard = function(self: Self)
	if self.destroyed then
		return
	end
	local view = derive(self)
	self.lastView = view
	local sig = signatureOf(view)
	if sig == self.lastSig then
		return
	end
	self.lastSig = sig
	local popBay: number? = nil
	if self.lastOwned >= 0 and view.owned > self.lastOwned then
		popBay = view.owned
	end
	self.lastOwned = view.owned
	setStat(self, view)
	setStrip(self, view, popBay)
	setButton(self, view)
	setFooter(self, view)
	setTag(self, view)
	-- the window is built after the card is on screen (a few dozen parts and the parked cars)
	task.defer(function()
		if not self.destroyed then
			buildScene(self, view)
		end
	end)
end

function CardObj.destroy(self: Self)
	if self.destroyed then
		return
	end
	self.destroyed = true
	for tween in self.tweens do
		tween:Cancel()
	end
	table.clear(self.tweens)
	self.trove:Destroy()
end

----------------------------------------------------------------------------------------------------
-- The panel: the card contract ShopPanel forwards to (one card open at a time)
----------------------------------------------------------------------------------------------------

type Panel = {
	card: Self,
	source: Source,
	host: Host,
	gui: ScreenGui,
	scrim: Frame,
	pop: NumberValue,
	root: Trove.Trove,
	live: Trove.Trove,
	tweens: { [Tween]: boolean },
	leaving: boolean,
}

local active: Panel? = nil
local leaving: Panel? = nil

local function destroyPanel(p: Panel)
	for tween in p.tweens do
		tween:Cancel()
	end
	table.clear(p.tweens)
	p.live:Clean()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(p.gui) then
		GuiService.SelectedObject = nil
	end
	(p.card :: any):destroy()
	p.root:Destroy()
	if active == p then
		active = nil
	end
	if leaving == p then
		leaving = nil
	end
end

local function play(p: Panel, instance: Instance, info: TweenInfo, goals: { [string]: any }, onDone: (() -> ())?)
	local tween = TweenService:Create(instance, info, goals)
	p.tweens[tween] = true
	tween.Completed:Once(function(state: Enum.PlaybackState)
		p.tweens[tween] = nil
		tween:Destroy()
		if state == Enum.PlaybackState.Completed and onDone then
			onDone()
		end
	end)
	tween:Play()
end

local function tooFar(p: Panel): boolean
	local character = Players.LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return false -- nothing to measure (between lives): the other close rules still apply
	end
	local anchor = p.source.anchor
	if anchor == nil or anchor.Parent == nil then
		return false
	end
	return (rootPart.Position - anchor.Position).Magnitude > p.host.closeDistance
end

function ParkingCard.close(instant: boolean?)
	local p = active
	if p == nil then
		if instant == true and leaving then
			destroyPanel(leaving)
		end
		return
	end
	active = nil
	p.live:Clean()
	if leaving then
		destroyPanel(leaving)
	end
	if instant == true then
		destroyPanel(p)
		return
	end
	leaving = p
	p.leaving = true
	local calm = Calm()
	local info =
		TweenInfo.new(if calm then 0.1 else Tokens.Motion.Panel, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	play(p, p.scrim, info, { BackgroundTransparency = 1 })
	if calm then
		task.delay(0.1, function()
			if leaving == p then
				destroyPanel(p)
			end
		end)
	else
		play(p, p.pop, info, { Value = 0.94 }, function()
			destroyPanel(p)
		end)
	end
end

function ParkingCard.open(source: Source, host: Host)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	local replacing = active ~= nil
	ParkingCard.close(true)

	local root = Trove.new()
	local gui: ScreenGui = make("ScreenGui", {
		Name = "Lane3ParkingCard",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = DISPLAY_ORDER,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	root:Add(gui)
	-- the scrim is visual only: Active false, so it never swallows a touch meant for the thumbstick
	local scrim = box(gui, "Scrim", 0, 0, 0, 0, NAVY)
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundTransparency = SCRIM_TRANSPARENCY
	scrim.Active = false
	local holder = make("Frame", {
		Name = "Holder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})

	local popValue = Instance.new("NumberValue")
	popValue.Value = 1
	root:Add(popValue)

	local p: Panel = {
		card = nil :: any,
		source = source,
		host = host,
		gui = gui,
		scrim = scrim,
		pop = popValue,
		root = root,
		live = Trove.new(),
		tweens = {},
		leaving = false,
	}
	root:Add(p.live)
	p.card = ParkingCard.new(holder, source, host, function()
		ParkingCard.close()
	end) :: any
	root:Connect(popValue.Changed, function(value: number)
		p.card.popFactor = value
		applyScale(p.card)
	end)
	active = p

	-- watchers, dropped when the card starts to close
	p.live:Connect(RunService.Heartbeat, function()
		if active == p and tooFar(p) then
			ParkingCard.close()
		end
	end)
	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_name: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				ParkingCard.close()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)
	p.live:Add(function()
		ContextActionService:UnbindAction(ACTION_NAME)
	end)
	if UserInputService.GamepadEnabled then
		local hit = p.card.button and p.card.button.frame:FindFirstChild("Hit")
		if hit and hit:IsA("GuiObject") then
			GuiService.SelectedObject = hit
		end
	end

	-- open: a 0.94 -> 1 pop and the scrim fading in (Reduce Motion: the scrim only, 0.1 s)
	if replacing then
		return
	end
	local calm = Calm()
	local info =
		TweenInfo.new(if calm then 0.1 else Tokens.Motion.Panel, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	scrim.BackgroundTransparency = 1
	play(p, scrim, info, { BackgroundTransparency = SCRIM_TRANSPARENCY })
	if not calm then
		popValue.Value = 0.94
		play(p, popValue, info, { Value = 1 })
	end
end

function ParkingCard.isOpen(): boolean
	return active ~= nil
end

function ParkingCard.plot(): Model?
	local p = active
	return if p then p.source.plot else nil
end

function ParkingCard.refresh()
	local p = active
	if p then
		refreshCard(p.card)
	end
end

-- Test hook: overrides of the live reads on the open card (nil clears them); see Data.
function ParkingCard.setCardData(patch: Data?)
	local p = active
	if p then
		CardObj.setData(p.card, patch)
	end
end

-- For Studio tests.
function ParkingCard.state(): { [string]: any }
	local p = active
	if p == nil then
		return { open = false, shown = 0, locked = false, buyEnabled = false }
	end
	local card = p.card
	local view = card.lastView or derive(card)
	return {
		open = true,
		kind = "parking",
		shown = view.owned,
		max = view.max,
		state = view.state,
		locked = card.pending ~= nil,
		target = if card.pending then card.pending.target else view.owned,
		buyEnabled = view.state == "buy",
		celebrating = view.celebrating,
		price = view.price,
		need = view.need,
		failed = view.failed,
		cells = card.stripKinds,
		tag = card.tagText,
		scrolls = false,
		usesArt = card.kerb ~= nil and card.kerb.usesArt,
		scene = card.sceneStats,
		layout = {
			scale = card.fitScale,
			padding = 0,
			cardSize = Vector2.new(FW, card.layout.fh),
		},
	}
end

return ParkingCard
