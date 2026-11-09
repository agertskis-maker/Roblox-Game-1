--!strict
-- Home/HomeLayout: where every piece of the Round 2 Home HUD sits (Lane 3, N7-03a, 2026-11-02). One pure function turns
-- HomeView's numbers (the safe area in design px, its reserved touch zones) into rectangles, so the parts never collide
-- with each other, the thumbstick or the jump button, and reflow instead of shrinking when the screen is small.
--
--   HomeLayout.plan(metrics, input) -> Plan
--     input = { cashW: number, cashH: number, hasTimer: boolean }
--
-- Rules (preview choices recorded here; reversible):
--   * LEFT: three labelled tiles (Shop, Garage, Missions) and the round Settings button, centred on the middle of the left edge
--     (Adam, Round 3), between the top of the safe area and whatever is below. The biggest tile that fits above the
--     thumbstick zone (and above Cash when Cash sits bottom-left) wins: 104 x 92, 104 x 72, 104 x 64 icon-over-label
--     squares, else 124 x 56 or 124 x 48 icon-beside-label rows (56 is the primary-button size, 48 the touch minimum). Phone landscape (844 x 390) ends up on rows
--     because the free height above the thumbstick is about 170 design px; a 1080p desktop gets the big squares.
--   * SETTINGS (Round 8 H-07, R8-IMG-23): Adam found Settings, which used to head the right-hand column, "very far apart" from
--     Missions. It now belongs to the left column, with ONE shared gap: `nav.gap` separates Shop from Garage, Garage from
--     Missions AND Missions from Settings (the lip under each tile adds the same DEPTH to every one of those gaps). With the
--     square tiles the round Settings button, its label under it, hangs centred under the stack ("Below"); with the short rows
--     (phones, short windows) there is no height for a fourth item above the thumbstick, so the same round button, no label,
--     sits "Beside" the Missions row, one gap (plus the lip) to its right. The goal banner's column starts to the right of it.
--   * BOTTOM LEFT: Cash, its rate and the car count, bottom-left; when that would sit in the thumbstick zone it moves to
--     sit BESIDE the zone (the approved Round 1 rule), never inside it.
--   * RIGHT: a column of round buttons from the top, 48 px on phones (no labels, at most three, then an overflow), 56 px
--     with labels on tablets and desktops (at most five). It stops above the jump zone.
--   * TOP CENTRE: one column for the notification pill, the goal pill and (instead of them) the tutorial banner, as wide as
--     the room between the left tiles and the right column allows, capped (phone 420, tablet 440, desktop 460 design px),
--     centred as close to the screen centre as the columns allow.
--   * BOTTOM RIGHT: nothing, unless a real timer is supplied (then it sits above the jump zone).

local HomeView = require(script.Parent.HomeView)

local HomeLayout = {}

local DEPTH = 4 -- the kit's shallow lip under a button (PreviewTokens.Arcade.Button.DepthOffset)

export type Tile = { style: "Stack" | "Row", w: number, h: number, gap: number }
-- The round Settings button of the left column (Round 8 H-07). x, y are relative to the nav's top-left; w, h are its root's size.
export type SettingsPlan = {
	placement: "Below" | "Beside",
	d: number, -- the disc's diameter
	labels: boolean, -- the word "Settings" under the disc ("Below" only)
	x: number,
	y: number,
	w: number,
	h: number,
}
export type NavPlan = {
	x: number,
	y: number,
	tile: Tile,
	rowHeight: number, -- a tile's root height (body + lip)
	gap: number, -- THE shared gap: Shop to Garage, Garage to Missions, Missions to Settings
	settings: SettingsPlan?, -- nil when the game gives no Settings callback
	width: number, -- the whole column, Settings included
	height: number,
	bottom: number,
}
export type CashPlan = { x: number, bottom: number, placement: "BottomLeft" | "Beside" }
export type ShortcutPlan = {
	right: number, -- the column's right edge
	y: number,
	d: number, -- the round button's diameter
	labels: boolean,
	colW: number,
	gap: number,
	slot: number, -- one entry's height including its label and gap
	capacity: number, -- how many slots fit above the jump zone
	maxPrimary: number, -- primary buttons before the overflow
	left: number, -- the column's left edge
}
export type TopPlan = { cx: number, y: number, width: number, left: number, right: number, compact: boolean }
export type TimerPlan = { right: number, bottom: number }

export type Plan = {
	metrics: HomeView.Metrics,
	nav: NavPlan,
	cash: CashPlan,
	shortcuts: ShortcutPlan,
	top: TopPlan,
	timer: TimerPlan,
}

export type Input = { cashW: number, cashH: number, hasTimer: boolean?, hasSettings: boolean? }

local SETTINGS_DISC = 56 -- the round Settings disc under square tiles (the same disc the right-hand column uses)
local ROUND_LABEL_H = 22 -- HomeButton.round's label strip
-- The top-centre column (goal line, pill, banner) is at most about this tall, so a Settings disc that begins lower than this
-- below the top never meets it.
local TOP_COLUMN_H = 130

local TILES: { Tile } = {
	{ style = "Stack", w = 104, h = 92, gap = 8 },
	{ style = "Stack", w = 104, h = 72, gap = 6 },
	{ style = "Stack", w = 104, h = 64, gap = 4 },
	{ style = "Row", w = 124, h = 56, gap = 4 }, -- the 56 px primary-button size, when the room allows
	{ style = "Row", w = 124, h = 48, gap = 4 },
}

local function overlaps(a: HomeView.Rect, b: HomeView.Rect): boolean
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

-- The smallest zone top among the zones that cover any of the x range [x0, x1] (nil = none).
local function zoneTop(zones: { HomeView.Rect }, x0: number, x1: number): number?
	local best: number? = nil
	for _, z in zones do
		if z.x < x1 and z.x + z.w > x0 then
			if best == nil or z.y < best then
				best = z.y
			end
		end
	end
	return best
end

function HomeLayout.tileRowHeight(tile: Tile): number
	return tile.h + DEPTH
end

-- Where the round Settings button goes for a tile shape. Its y is exactly the next slot of the column ((rows) x (row + gap)),
-- so the gap above it is the same shared gap as between the tiles.
function HomeLayout.settingsFor(tile: Tile): SettingsPlan
	local rowH = HomeLayout.tileRowHeight(tile)
	if tile.style == "Stack" then
		return {
			placement = "Below",
			d = SETTINGS_DISC,
			labels = true,
			x = 0,
			y = 3 * (rowH + tile.gap),
			w = tile.w,
			h = SETTINGS_DISC + ROUND_LABEL_H + 2 + DEPTH,
		}
	end
	-- a row tile: the disc is as tall as the row, to the right of Missions, one gap plus the lip away
	return {
		placement = "Beside",
		d = tile.h,
		labels = false,
		x = tile.w + tile.gap + DEPTH,
		y = 2 * (rowH + tile.gap),
		w = tile.h,
		h = tile.h + DEPTH,
	}
end

-- The whole left column's height for a tile shape (with Settings when the game has it).
local function navHeight(tile: Tile, withSettings: boolean): number
	local rowH = HomeLayout.tileRowHeight(tile)
	local h = 3 * rowH + 2 * tile.gap
	if withSettings then
		local s = HomeLayout.settingsFor(tile)
		if s.placement == "Below" then
			h = s.y + s.h
		end
	end
	return h
end

function HomeLayout.plan(m: HomeView.Metrics, input: Input): Plan
	local phone = m.kind == "Phone"

	-- 1. Cash: bottom-left, or beside the zone it would hit.
	local cashBottom = m.height - m.bottom
	local cashRect: HomeView.Rect = { x = m.margin, y = cashBottom - input.cashH, w = input.cashW, h = input.cashH }
	local placement: "BottomLeft" | "Beside" = "BottomLeft"
	for _ = 1, #m.zones do
		local hit: HomeView.Rect? = nil
		for _, z in m.zones do
			if overlaps(cashRect, z) then
				hit = z
				break
			end
		end
		if hit == nil then
			break
		end
		local previous = cashRect.x
		cashRect.x = hit.x + hit.w + 8
		if placement == "Beside" or cashRect.x + cashRect.w > m.width - m.margin then
			-- a second zone is in the way too (or the block would leave the screen): stay beside the first, never off screen
			cashRect.x = previous
			break
		end
		placement = "Beside"
	end
	local cash: CashPlan = { x = cashRect.x, bottom = cashBottom, placement = placement }

	-- 2. Left tiles: the biggest that fits above the thumbstick zone (and above Cash when that is bottom-left).
	local x0 = m.margin
	local limit = m.height - m.bottom
	if placement == "BottomLeft" then
		limit = math.min(limit, cashRect.y - 10)
	end
	local zt = zoneTop(m.zones, x0, x0 + TILES[1].w)
	if zt then
		limit = math.min(limit, zt - 2)
	end
	local avail = limit - m.top
	local withSettings = input.hasSettings ~= false
	local chosen = TILES[#TILES]
	for _, tile in TILES do
		if navHeight(tile, withSettings) <= avail then
			chosen = tile
			break
		end
	end
	local navH = navHeight(chosen, withSettings)
	-- the middle of the screen when there is room, sliding up only as far as Cash or the thumbstick needs
	local navY = math.clamp((m.height - navH) / 2, m.top, math.max(m.top, limit - navH))
	local navBottom = navY + navH
	local settings: SettingsPlan? = if withSettings then HomeLayout.settingsFor(chosen) else nil
	local navW = chosen.w
	if settings and settings.placement == "Beside" then
		navW = settings.x + settings.w
	end
	local nav: NavPlan = {
		x = x0,
		y = navY,
		tile = chosen,
		rowHeight = HomeLayout.tileRowHeight(chosen),
		gap = chosen.gap,
		settings = settings,
		width = navW,
		height = navH,
		bottom = navBottom,
	}

	-- 3. Right column of round buttons, above the jump zone.
	local d = if phone then 48 else 56
	local labels = not phone
	local colW = if labels then 100 else d
	local gap = 6
	local slot = d + (if labels then 24 else 0) + DEPTH + gap -- a round button's root: disc, label, lip, then the gap
	local right = m.width - m.margin
	local rightLimit = m.height - m.bottom
	local rz = zoneTop(m.zones, right - colW, right)
	if rz then
		rightLimit = math.min(rightLimit, rz - 6)
	end
	local capacity = math.max(1, math.floor((rightLimit - m.top + gap) / slot))
	local shortcuts: ShortcutPlan = {
		right = right,
		y = m.top,
		d = d,
		labels = labels,
		colW = colW,
		gap = gap,
		slot = slot,
		capacity = capacity,
		maxPrimary = math.min(if phone then 3 else 5, capacity),
		left = right - colW,
	}

	-- 4. The top-centre column between the left tiles and the right column.
	-- A tablet or desktop column keeps a 16 px clear lane before the round buttons (their labels hang under them), a phone 8:
	-- a pill, the goal pill or the tutorial banner never touches Settings or the shortcut column.
	local lane = if phone then 8 else 16
	-- the column starts right of the tiles; a Settings disc beside the Missions row widens that only when it rises into the
	-- column's own height (on a phone the nav sits at the top, on a tablet it sits lower and never meets the banner)
	local leftEdge = chosen.w
	if settings and settings.placement == "Beside" and navY + settings.y < m.top + TOP_COLUMN_H then
		leftEdge = nav.width
	end
	local left = nav.x + leftEdge + lane
	local rightEdge = shortcuts.left - lane
	local maxW = if phone then 320 elseif m.kind == "Tablet" then 440 else 460
	local span = rightEdge - left
	local width = math.clamp(span, 200, maxW)
	local cx = if span < width
		then (left + rightEdge) / 2
		else math.clamp(m.width / 2, left + width / 2, rightEdge - width / 2)
	local top: TopPlan = {
		cx = cx,
		y = m.top,
		width = width,
		left = left,
		right = rightEdge,
		compact = phone or width < 400,
	}

	-- 5. Bottom right: only a real timer; above the jump zone.
	local timerBottom = m.height - m.bottom
	local tz = zoneTop(m.zones, m.width - m.margin - 220, m.width - m.margin)
	if tz then
		timerBottom = math.min(timerBottom, tz - 6)
	end
	return {
		metrics = m,
		nav = nav,
		cash = cash,
		shortcuts = shortcuts,
		top = top,
		timer = { right = m.width - m.margin, bottom = timerBottom },
	}
end

return HomeLayout
