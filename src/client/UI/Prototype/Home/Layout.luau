--!strict
-- One place that decides where every Home HUD piece sits for each device profile (Lane 3
-- preview, HUD rebuild 2026-10-22), so the left menu, the bottom-left stats, the tutorial banner,
-- the toast stack and the timer proposal never collide with each other or with a reserved touch
-- zone. Every number is in design px inside ctx.layer (the safe area), before the HudScale
-- UIScale; a component positions its root at (x * scale, y * scale) because a UIScale does not
-- move its own object.
--
--   Layout.forProfile(profile, scale) -> HomeLayout
--   Layout.cashMetrics() -> CashMetrics      -- the approved counter's row height / reserved size
--   Layout.reservedRects(profile, scale)     -- reserved touch zones in safe design px
--   Layout.rootHeight(bodyHeight)            -- an Arcade button's root height (hit box + lip)
--
-- Placement rules (preview choices, recorded here; reversible):
--   Desktop 1920x1080 (scale 1.5): references' left-centre column — the small red Settings
--     rectangle centred above Shop / Garage / Missions (Wide), the Music toggle row under the
--     stack; the column is centred at about 0.47 of the safe height. Stats bottom-left (no
--     panels). Banner top centre; toasts under it; timer proposal bottom-right.
--   Tablet 1180x820 (1.5): the same column with Compact buttons, but the thumbstick zone starts
--     at about 0.53 of the safe height, so the column starts at the top and the Music toggle sits
--     right of Settings (a 5-row column would run into the zone). Stats sit BESIDE the thumbstick
--     zone (right of it), bottom.
--   PhoneLandscape 844x390 (1.0): the free height above the thumbstick zone is about 170 design
--     px, and a column of Settings + three buttons at the 48 px touch minimum needs at least
--     4 x 52 + gaps = 226, so the phone uses a two-row compact block instead: [Settings][Music]
--     over [Shop][Garage][Missions] (Compact width, equal). Stats sit BESIDE the thumbstick zone.
--   PhoneSmall 740x360 and the notch variants (PhoneLandscapeLeft / Right): the PhoneLandscape rules.
--   Round 2: landscape only (no portrait profile); the stats are Cash + the earning line (the owned-car
--     count moved into the Garage button), and during a run Cash alone sits top-left (see StatsStack).
-- The centre of the screen (avatar, road) stays open on every profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local CashIcon = require(script.Parent.Parent.Parent.CurrencyCounter.CashIcon)
local CurrencyCounter = require(script.Parent.Parent.Parent.CurrencyCounter)
local Arcade = require(script.Parent.Parent.Arcade)
local OutlinedText = require(script.Parent.Parent.Parent.OutlinedText)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Screen = require(script.Parent.Parent.Screen)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local A = PreviewTokens.Arcade
local B = A.Button
local S = A.Stats

local Layout = {}

-- Same widest samples as the approved RunHud Cash counter.
Layout.CashWidest = { "$9,999", "$99.9K", "$999K", "$9.99M", "$99.9M", "$999M", "$999B", "$999T", "$1,000T" }
Layout.EarningHeight = 24
Layout.BannerTabOverlap = 12 -- the TUTORIAL tab sits this far above the banner body
Layout.BannerMaxBody = 72
Layout.HintHeight = 24
Layout.HintGap = 4
Layout.ToastHeight = 44
Layout.ToastGap = 6
-- TOKEN CANDIDATE: the Music toggle row width (kit track 92 + gap 10 + "Music" label at 22 px).
Layout.MusicWidth = 174
Layout.MusicHeight = Tokens.Touch.Minimum
-- TOKEN CANDIDATE: timer proposal row (Timer text + 44 px event icon).
Layout.TimerHeight = 48
Layout.TimerWidth = 300

export type Rect = { name: string, x: number, y: number, w: number, h: number }

export type CashMetrics = {
	rowHeight: number,
	reservedWidth: number,
	reservedHeight: number,
	valueX: number,
	artLeft: number,
	iconSide: number,
}

export type ItemPos = { x: number, y: number }

export type MenuLayout = {
	kind: "Column" | "TabletColumn" | "PhoneBlock",
	x: number,
	y: number,
	width: number,
	height: number,
	size: "Wide" | "Compact" | "Custom",
	buttonW: number,
	buttonH: number,
	items: { [string]: ItemPos }, -- Settings, Shop, Garage, Missions, Music (top-left, menu space)
}

export type StatsLayout = {
	x: number,
	bottom: number,
	width: number, -- typical visible width (for overlap checks), not the reserved width
	height: number,
	placement: "BottomLeft" | "Beside",
}

export type BannerLayout = { cx: number, y: number, width: number, maxBodyHeight: number, textSize: number }
export type ToastLayout = { x: number, y: number, width: number, anchorX: number }
export type TimerLayout = { right: number, bottom: number, width: number, height: number }

export type HomeLayout = {
	profile: string,
	scale: number,
	safeW: number,
	safeH: number,
	phone: boolean,
	reserved: { Rect },
	menu: MenuLayout,
	stats: StatsLayout,
	-- the Cash row (for a standalone CashLine): top-left of the counter, its earning-line offset
	cash: { x: number, y: number, inlineEarning: boolean, earningY: number, bottom: number },
	banner: BannerLayout,
	toasts: ToastLayout,
	timers: TimerLayout,
}

local metrics: CashMetrics? = nil

function Layout.cashMetrics(): CashMetrics
	if metrics then
		return metrics
	end
	local size = Tokens.TextSize.Cash
	local outline = OutlinedText.Outline
	local widest = 0
	for _, sample in Layout.CashWidest do
		local v = TextService:GetTextSize(sample, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096))
		widest = math.max(widest, v.X)
	end
	local textWidth = math.ceil(widest + 2 * outline)
	local side = CashIcon.Size.X
	local art = CashIcon.ArtSize
	local rowHeight = math.max(CashIcon.Size.Y, size + 2 * outline + OutlinedText.ShadowOffset)
	local inkLeft = OutlinedText.DollarInkLeftEm * size - outline
	local valueX = side / 2 + art.X / 2 + CurrencyCounter.Gap - inkLeft
	local punchRoom = math.ceil(textWidth * Tokens.Motion.CashPunchBig)
	local m: CashMetrics = {
		rowHeight = rowHeight,
		reservedWidth = valueX + textWidth + punchRoom,
		reservedHeight = rowHeight + 22 + 10, -- the counter's gain label slot (LABEL_SIZE + 10)
		valueX = valueX,
		artLeft = side / 2 - art.X / 2,
		iconSide = side,
	}
	metrics = m
	return m
end

-- Height of the bottom-left stats block: the Cash row and the earning line (the earning line
-- shares the Cash counter's gain-label slot and ducks while that label shows). Round 2: the car row
-- (cyan icon, inert "+", owned count) is gone; the count lives on the Garage button.
function Layout.statsHeight(): number
	local m = Layout.cashMetrics()
	return m.rowHeight + 2 + Layout.EarningHeight
end

-- Run-time Cash: compact, top-left of the safe area (design px, below the core UI inset).
Layout.RunCashPos = Vector2.new(12, 12)
function Layout.runCashScale(): number
	return A.Text.ValueRun / A.Text.Value
end
-- The visible compact Cash block (icon + a typical value), for overlap checks.
function Layout.runCashSize(): Vector2
	local m = Layout.cashMetrics()
	local k = Layout.runCashScale()
	return Vector2.new((m.valueX + 150) * k, m.rowHeight * k)
end

-- A typical visible width of the stats block (icon + "$999.9K"-sized number), used only for
-- overlap checks; the Cash counter itself reserves the widest value.
function Layout.statsTypicalWidth(): number
	return Layout.cashMetrics().valueX + 170
end

function Layout.rootHeight(bodyHeight: number): number
	return math.max(bodyHeight, Tokens.Touch.Minimum) + B.DepthOffset
end

function Layout.reservedRects(profile: Screen.Profile, scale: number): { Rect }
	local i = profile.insets
	local out: { Rect } = {}
	for _, z in profile.zones do
		table.insert(out, {
			name = z.name,
			x = (z.position.X - i.left) / scale,
			y = (z.position.Y - i.top) / scale,
			w = z.size.X / scale,
			h = z.size.Y / scale,
		})
	end
	return out
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

local function firstOverlap(r: Rect, list: { Rect }): Rect?
	for _, z in list do
		if overlaps(r, z) then
			return z
		end
	end
	return nil
end

-- Centre a block of `maxWidth` in [left, right], as close to `preferred` as possible.
local function fit(left: number, right: number, maxWidth: number, preferred: number): (number, number)
	local width = math.max(200, math.min(maxWidth, right - left))
	if right - left < width then
		return width, (left + right) / 2
	end
	return width, math.clamp(preferred, left + width / 2, right - width / 2)
end

local function menuShape(name: string, safeW: number, margin: number): MenuLayout
	local gap = B.Gap
	local smallRoot = Layout.rootHeight(B.SmallH)
	local items: { [string]: ItemPos } = {}
	if name == "Desktop" then
		local w, h = B.WideW, B.WideH
		local rh = Layout.rootHeight(h)
		items.Settings = { x = (w - B.SmallW) / 2, y = 0 }
		local y = smallRoot + gap
		items.Shop = { x = 0, y = y }
		items.Garage = { x = 0, y = y + rh + gap }
		-- the Garage button is taller by Arcade.PillExtra (its collection pill sits under the label)
		items.Missions = { x = 0, y = y + 2 * (rh + gap) + Arcade.PillExtra }
		items.Music = { x = 0, y = y + 3 * (rh + gap) + 2 + Arcade.PillExtra }
		return {
			kind = "Column",
			x = margin,
			y = 0,
			width = math.max(w, Layout.MusicWidth),
			height = items.Music.y + Layout.MusicHeight,
			size = "Wide",
			buttonW = w,
			buttonH = h,
			items = items,
		}
	elseif name == "Tablet" then
		local w, h = B.CompactW, B.CompactH
		local rh = Layout.rootHeight(h)
		items.Settings = { x = (w - B.SmallW) / 2, y = 0 }
		items.Music = { x = items.Settings.x + B.SmallW + gap, y = (smallRoot - Layout.MusicHeight) / 2 }
		local y = smallRoot + gap
		items.Shop = { x = 0, y = y }
		items.Garage = { x = 0, y = y + rh + gap }
		items.Missions = { x = 0, y = y + 2 * (rh + gap) + Arcade.PillExtra }
		return {
			kind = "TabletColumn",
			x = margin,
			y = 0,
			width = math.max(w, items.Music.x + Layout.MusicWidth),
			height = items.Missions.y + rh,
			size = "Compact",
			buttonW = w,
			buttonH = h,
			items = items,
		}
	end
	-- phones: [Settings][Music] over [Shop][Garage][Missions]
	local phoneGap = 6
	local avail = math.min(safeW - 2 * margin, 3 * B.CompactW + 2 * phoneGap)
	local w = math.floor((avail - 2 * phoneGap) / 3)
	local h = B.CompactH
	local rh = Layout.rootHeight(h)
	items.Settings = { x = 0, y = 0 }
	items.Music = { x = B.SmallW + phoneGap + 4, y = (smallRoot - Layout.MusicHeight) / 2 }
	local y = smallRoot + phoneGap
	items.Shop = { x = 0, y = y }
	items.Garage = { x = w + phoneGap, y = y }
	items.Missions = { x = 2 * (w + phoneGap), y = y }
	return {
		kind = "PhoneBlock",
		x = margin,
		y = 0,
		width = math.max(3 * w + 2 * phoneGap, items.Music.x + Layout.MusicWidth),
		height = y + rh + Arcade.PillExtra, -- Garage is the tallest of the row
		size = "Custom",
		buttonW = w,
		buttonH = h,
		items = items,
	}
end

function Layout.forProfile(profile: Screen.Profile, scale: number): HomeLayout
	local name = profile.name
	local i = profile.insets
	local safeW = (profile.size.X - i.left - i.right) / scale
	local safeH = (profile.size.Y - i.top - i.bottom) / scale
	local phone = profile.kind == "Phone"
	local margin = if phone then 8 else S.MarginLeft
	local reserved = Layout.reservedRects(profile, scale)
	local m = Layout.cashMetrics()

	-- 1. Stats: bottom-left; beside a reserved zone it would hit.
	local statsH = Layout.statsHeight()
	local statsW = Layout.statsTypicalWidth()
	local sx = margin
	local bottom = safeH - (if phone then 8 else S.MarginBottom)
	local placement: "BottomLeft" | "Beside" = "BottomLeft"
	local hit = firstOverlap({ name = "stats", x = sx, y = bottom - statsH, w = statsW, h = statsH }, reserved)
	if hit then
		sx = hit.x + hit.w + 8
		placement = "Beside"
	end
	local stats: StatsLayout = { x = sx, bottom = bottom, width = statsW, height = statsH, placement = placement }
	local statsTop = bottom - statsH

	-- 2. Banner block height (the banner itself is placed after the menu).
	local blockH = Layout.BannerTabOverlap + Layout.BannerMaxBody + Layout.HintGap + Layout.HintHeight
	local bannerY = if phone then 4 else 8

	-- 3. Menu.
	local menu = menuShape(name, safeW, margin)
	local top = if phone then 4 else 8
	local desired = safeH * 0.47 - menu.height / 2
	local limit = math.huge
	if stats.x < menu.x + menu.width then
		limit = statsTop - (if phone then 4 else 12) - menu.height
	end
	for _, z in reserved do
		if z.x < menu.x + menu.width and z.x + z.w > menu.x then
			limit = math.min(limit, z.y - 6 - menu.height)
		end
	end
	menu.y = math.clamp(desired, top, math.max(top, limit))
	local menuRight = menu.x + menu.width

	-- 4. Banner.
	local bannerLeft = margin
	if menu.y < bannerY + blockH then
		bannerLeft = menuRight + 12
	end
	local bannerW, bannerCx = fit(bannerLeft, safeW - 16, if phone then 340 else 460, safeW / 2)
	local banner: BannerLayout = {
		cx = bannerCx,
		y = bannerY,
		width = bannerW,
		maxBodyHeight = Layout.BannerMaxBody,
		textSize = Tokens.TextSize.Value,
	}

	-- 5. Toasts.
	local toastH = 2 * Layout.ToastHeight + Layout.ToastGap
	local ty = banner.y + blockH + 6
	local toastLeft = margin
	if ty < menu.y + menu.height and ty + toastH > menu.y then
		toastLeft = math.max(toastLeft, menuRight + 12)
	end
	if ty < bottom and ty + toastH > statsTop then
		toastLeft = math.max(toastLeft, stats.x + statsW + 12)
	end
	local toastW, toastCx = fit(toastLeft, safeW - 16, 360, banner.cx)
	local toasts: ToastLayout = { x = toastCx, y = ty, width = toastW, anchorX = 0.5 }

	-- 6. Timer proposal: bottom-right, above a reserved zone it would hit.
	local tBottom = safeH - (if phone then 8 else S.MarginBottom)
	local tRight = safeW - 16
	local tHit = firstOverlap({
		name = "timers",
		x = tRight - Layout.TimerWidth,
		y = tBottom - Layout.TimerHeight,
		w = Layout.TimerWidth,
		h = Layout.TimerHeight,
	}, reserved)
	if tHit then
		tBottom = tHit.y - 6
	end
	local timers: TimerLayout =
		{ right = tRight, bottom = tBottom, width = Layout.TimerWidth, height = Layout.TimerHeight }

	local cashY = statsTop
	return {
		profile = name,
		scale = scale,
		safeW = safeW,
		safeH = safeH,
		phone = phone,
		reserved = reserved,
		menu = menu,
		stats = stats,
		cash = {
			x = stats.x,
			y = cashY,
			inlineEarning = true,
			earningY = m.rowHeight + 2,
			bottom = bottom,
		},
		banner = banner,
		toasts = toasts,
		timers = timers,
	}
end

return Layout
