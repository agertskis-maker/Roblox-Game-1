--!strict
-- One place that decides where every Home HUD piece sits for each device profile (Lane 3
-- preview), so the Cash line, left menu, tutorial banner and toast stack never collide.
-- Every number is in design px inside ctx.layer (the safe area), before the HudScale UIScale.
--
--   Layout.forProfile(profile, scale) -> HomeLayout
--   Layout.cashMetrics() -> CashMetrics    -- the approved counter's row height / reserved size
--   Layout.menuItemHeight(menu) -> number
--
-- Placement rules (preview choices, recorded here):
--   Desktop 1920x1080 (scale 1.5): Cash top-left, earning line below it, menu as a column under
--     Cash; banner centred at the top; toasts under the banner.
--   Tablet 1180x820 (1.5): the menu is a row under Cash, because a column would run into the
--     reserved thumbstick zone (lower-left 40% x 45% of the screen).
--   PhoneLandscape 844x390 (1.0): the earning line shares the slot under the Cash number (it
--     fades out while the approved counter's own "+$N" label shows there), the menu is a row of
--     48 px buttons with 16 px labels, which ends above the thumbstick zone; banner and toasts
--     sit right of Cash's reserved width and left of the top-right Settings/ride-chip area.
--   PhonePortrait 390x844 (1.0): Cash, then the menu row, then a full-width banner with wrapping
--     text; toasts are right-aligned and 220 px wide so they stay right of the thumbstick zone.
-- The top-right corner (RIGHT_RESERVE) is left free for the Settings / ride chip area.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local CashIcon = require(script.Parent.Parent.Parent.CurrencyCounter.CashIcon)
local CurrencyCounter = require(script.Parent.Parent.Parent.CurrencyCounter)
local OutlinedText = require(script.Parent.Parent.Parent.OutlinedText)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Screen = require(script.Parent.Parent.Screen)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local Layout = {}

-- Same widest samples as the approved RunHud Cash counter.
Layout.CashWidest = { "$9,999", "$99.9K", "$999K", "$9.99M", "$99.9M", "$999M", "$999B", "$999T", "$1,000T" }
Layout.EarningHeight = 24
Layout.BannerTabOverlap = 12 -- the TUTORIAL tab sits this far above the banner body
Layout.HintHeight = 24
Layout.HintGap = 4
Layout.ToastHeight = 44
Layout.ToastGap = 6

export type CashMetrics = {
	rowHeight: number,
	reservedWidth: number,
	reservedHeight: number,
	valueX: number,
	artLeft: number,
}

export type MenuLayout = {
	kind: "Column" | "Row",
	x: number,
	y: number,
	body: number,
	small: number,
	labelSize: number,
	gap: number,
}

export type BannerLayout = { cx: number, y: number, width: number, maxBodyHeight: number, textSize: number }
export type ToastLayout = { x: number, y: number, width: number, anchorX: number }

export type HomeLayout = {
	profile: string,
	scale: number,
	safeW: number,
	safeH: number,
	cash: { x: number, y: number, inlineEarning: boolean, earningY: number, bottom: number },
	menu: MenuLayout,
	banner: BannerLayout,
	toasts: ToastLayout,
	rightReserve: number,
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
	}
	metrics = m
	return m
end

-- Menu labels (one source for LeftMenu and the layout maths). Settings has no label.
Layout.MenuOrder = { "Garage", "Shop", "Missions", "Settings" }
Layout.MenuLabels = { Garage = "GARAGE", Shop = "SHOP", Missions = "MISSIONS" } :: { [string]: string }

function Layout.menuItemHeight(menu: MenuLayout): number
	return menu.body + 4 + 2 + menu.labelSize + 4
end

-- Width of one menu item: the body plus badge / progress-pill room, or the label if wider.
function Layout.menuItemWidth(menu: MenuLayout, name: string, label: string?): number
	local body = if name == "Settings" then menu.small else menu.body
	local text = label or Layout.MenuLabels[name]
	local labelWidth = 0
	if text then
		labelWidth = TextService:GetTextSize(text, menu.labelSize, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X + 6
	end
	return math.max(body + 14, labelWidth)
end

-- Width of the menu laid out as a row (default labels).
function Layout.menuRowWidth(menu: MenuLayout): number
	local w = 0
	for _, name in Layout.MenuOrder do
		w += Layout.menuItemWidth(menu, name, nil)
	end
	return w + (#Layout.MenuOrder - 1) * menu.gap
end

-- Centre a block of `maxWidth` in [left, right], as close to `preferred` as possible.
local function fit(left: number, right: number, maxWidth: number, preferred: number): (number, number)
	local width = math.max(200, math.min(maxWidth, right - left))
	if right - left < width then
		return width, (left + right) / 2
	end
	return width, math.clamp(preferred, left + width / 2, right - width / 2)
end

function Layout.forProfile(profile: Screen.Profile, scale: number): HomeLayout
	local name = profile.name
	local i = profile.insets
	local safeW = (profile.size.X - i.left - i.right) / scale
	local safeH = (profile.size.Y - i.top - i.bottom) / scale
	local m = Layout.cashMetrics()
	local phone = name == "PhoneLandscape" or name == "PhonePortrait"
	local margin = if phone then 8 else 12
	local cashY = if phone then 0 else 6
	local inline = phone
	local earningY = if inline then m.rowHeight + 2 else m.reservedHeight + 2
	local cashBottom = cashY + (if inline then m.reservedHeight else earningY + Layout.EarningHeight)
	local menuKind: "Column" | "Row" = if name == "Desktop" then "Column" else "Row"
	local menu: MenuLayout
	if phone then
		menu = { kind = "Row", x = margin, y = cashBottom + 1, body = 48, small = 48, labelSize = 16, gap = 10 }
	else
		menu = {
			kind = menuKind,
			x = margin,
			y = cashBottom + 8,
			body = PreviewTokens.Size.MenuButton,
			small = 48,
			labelSize = 18,
			gap = 12,
		}
	end
	local menuRight = menu.x + (if menu.kind == "Row" then Layout.menuRowWidth(menu) else menu.body + 40)
	local rightReserve = if name == "Desktop" then 200 elseif name == "Tablet" then 180 else 150
	local bannerMaxBody = if name == "PhonePortrait" then 76 else 72
	local bannerY = if phone then 6 else 8
	local blockBottom = bannerY + Layout.BannerTabOverlap + bannerMaxBody + Layout.HintGap + Layout.HintHeight
	local banner: BannerLayout
	if name == "PhonePortrait" then
		local top = menu.y + Layout.menuItemHeight(menu) + 6
		banner = { cx = safeW / 2, y = top, width = safeW - 2 * margin, maxBodyHeight = bannerMaxBody, textSize = 18 }
	else
		local left = margin + m.reservedWidth + 12
		-- the hint line must also clear a menu row that starts above the banner block's bottom
		if menu.kind == "Row" and blockBottom > menu.y then
			left = math.max(left, menuRight + 12)
		end
		local width, cx = fit(left, safeW - rightReserve, if phone then 300 else 460, safeW / 2)
		banner = {
			cx = cx,
			y = bannerY,
			width = width,
			maxBodyHeight = bannerMaxBody,
			textSize = if phone then 18 else 20,
		}
	end
	local toastY = banner.y + Layout.BannerTabOverlap + bannerMaxBody + Layout.HintGap + Layout.HintHeight + 6
	local toasts: ToastLayout
	if name == "PhonePortrait" then
		toasts = { x = safeW - margin, y = toastY, width = 220, anchorX = 1 }
	else
		local left = margin + m.reservedWidth + 12
		if menu.kind == "Row" and toastY + 2 * Layout.ToastHeight > menu.y then
			left = math.max(left, menuRight + 12)
		end
		local width, cx = fit(left, safeW - rightReserve, 360, banner.cx)
		toasts = { x = cx, y = toastY, width = width, anchorX = 0.5 }
	end
	return {
		profile = name,
		scale = scale,
		safeW = safeW,
		safeH = safeH,
		cash = { x = margin, y = cashY, inlineEarning = inline, earningY = earningY, bottom = cashBottom },
		menu = menu,
		banner = banner,
		toasts = toasts,
		rightReserve = rightReserve,
	}
end

return Layout
