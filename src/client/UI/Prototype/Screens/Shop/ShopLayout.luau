--!strict
-- ShopLayout: the Shop's responsive layout as PURE MATH (Lane 3, BRIEF M10-01b, M10-14a, M10-14b, 2026-11-01).
-- Everything is computed from the safe DESIGN size (the safe area divided by the HUD scale) every time the viewport
-- changes, so a live resize reflows; nothing is a stored per-device table. No Instances here: the numbers can be
-- checked (and are, by getDebugState) without drawing anything.
--
--   Layout.compute(inputs) -> Layout
--
-- Three tiers, chosen by the design size:
--   Desktop  design width >= 1000 and height >= 560 (1920 x 1080 is 1280 x 681 design px at the 1.5 cap):
--            content 90% of the width, title left, tabs centre, Cash and X right, hero 66% beside two stacked side
--            cards, passes in ONE row (the bundle twice as wide), Style in four columns.
--   Tablet   everything else with a height of 420 or more (1024 x 768, the Tablet frame): 94% width, hero 62% and
--            side 38% while the benefit text fits, the bundle full width over three pass cards, Style in two columns.
--   Phone    design height under 420 (landscape phones): 96% width, a compact title / Cash / X row with the tabs as a
--            SEPARATE scrollable row, the hero full width at about 3:1 with the copy left and the art right, the two
--            side cards as the next row, passes as wide horizontal cards, Style in two wide columns.

local PreviewTokens = require(script.Parent.Parent.Parent.PreviewTokens)

local L = PreviewTokens.Shop.Layout

local ShopLayout = {}

export type Tier = "Desktop" | "Tablet" | "Phone"

export type Inputs = {
	size: Vector2, -- the safe design size
	titleW: number, -- measured width of the SHOP title at this tier's size (see titleSizeFor)
	tabsW: number, -- measured width of every tab laid end to end, with the gaps between them
	cashW: number,
}

export type Layout = {
	tier: Tier,
	size: Vector2,
	contentW: number,
	margin: number,
	gap: number,
	titleSize: number,
	closeSize: number,
	rowH: number, -- the title / Cash / X row
	topPad: number,
	tabGap: number, -- the gap above and below a separate tab row
	tabsInline: boolean, -- tabs share the first row (Desktop and roomy Tablet)
	tabH: number,
	headerH: number, -- everything above the page
	pageX: number,
	pageY: number,
	pageW: number, -- includes room for the scrollbar
	pageH: number,
	-- Featured
	heroW: number,
	heroH: number,
	sideW: number,
	sideH: number,
	sideStacked: boolean, -- two side cards stacked beside the hero (Desktop, Tablet); false = a row under it (Phone)
	sideBody: boolean, -- room for a benefit line in a side card (the card builder also drops rows that do not fit)
	-- sections
	sectionHeaderH: number,
	sectionGap: number,
	-- Passes
	passMode: "Row" | "Grid" | "List",
	panelPad: number,
	passUnitW: number,
	passW: number,
	passH: number,
	bundleW: number,
	bundleH: number,
	passGap: number,
	-- Style, Cash, Free
	gridCols: number,
	gridHorizontal: boolean, -- wide horizontal cards (art left, copy right)
	gridW: number,
	gridH: number,
	freeH: number,
	footerH: number,
}

function ShopLayout.tierFor(size: Vector2): Tier
	if size.Y < L.PhoneMaxH then
		return "Phone"
	elseif size.X >= L.DesktopMinW and size.Y >= L.DesktopMinH then
		return "Desktop"
	end
	return "Tablet"
end

function ShopLayout.titleSizeFor(tier: Tier): number
	if tier == "Desktop" then
		return 56
	elseif tier == "Tablet" then
		return 44
	end
	return 34
end

function ShopLayout.closeSizeFor(tier: Tier): number
	if tier == "Desktop" then
		return L.CloseSize
	elseif tier == "Tablet" then
		return 52
	end
	return 48 -- the 44 px tutorial minimum and the project's 48 px touch token
end

function ShopLayout.compute(i: Inputs): Layout
	local W, H = i.size.X, i.size.Y
	local tier = ShopLayout.tierFor(i.size)
	local contentW = math.floor(W * (L.ContentPct :: any)[tier])
	if tier == "Desktop" then
		contentW = math.min(contentW, 1240)
	end
	local margin = math.floor((W - contentW) / 2)
	local gap = (L.Gap :: any)[tier] :: number
	local closeSize = ShopLayout.closeSizeFor(tier)
	local titleSize = ShopLayout.titleSizeFor(tier)
	local phone = tier == "Phone"
	local rowH = closeSize + (if phone then 4 else 8)
	local topPad = if phone then 2 else 8
	local tabGap = if phone then 4 else 6
	local tabH = L.TabHeight -- 44 on every tier: a tab is a touch target

	-- the tabs share the first row when they fit between the title and the Cash counter, leaving room for the X
	local inlineNeed = i.titleW + i.tabsW + i.cashW + closeSize + 5 * gap
	local tabsInline = not phone and inlineNeed <= contentW
	local headerH = topPad + rowH + (if tabsInline then 6 else (tabGap + tabH + tabGap))

	local pageH = H - headerH - 4
	local pageW = math.min(contentW + 14, W - margin)

	-- Featured -------------------------------------------------------------------------------------------------
	-- Two side cards beside the hero only when each is tall enough for a name and a 52 px button (128 px); otherwise
	-- the hero takes the full width and the side cards become the next row (M10-14a, M10-14b).
	local heroW, heroH, sideW, sideH
	local sideStacked = false
	if tier ~= "Phone" then
		local share = (L.HeroShare :: any)[tier] :: number
		local stackedW = math.floor((contentW - gap) * share)
		local stackedH = math.floor(stackedW / ((L.HeroRatio :: any)[tier] :: number))
		stackedH = math.min(stackedH, math.max(pageH - 170, 200)) -- the Passes heading stays above the fold
		if math.floor((stackedH - gap) / 2) >= 128 then
			sideStacked = true
			heroW = stackedW
			heroH = stackedH
			sideW = contentW - gap - heroW
			sideH = math.floor((heroH - gap) / 2)
		end
	end
	if not sideStacked then
		heroW = contentW
		sideW = math.floor((contentW - gap) / 2)
		local ratio = if phone then (L.HeroRatio :: any).Phone else 2.6
		heroH = math.max(math.min(math.floor(heroW / ratio), pageH - 14), 150)
		sideH = if phone then 118 else 128
	end
	local sideBody = sideStacked and sideH >= 150

	-- Passes ---------------------------------------------------------------------------------------------------
	local passGap = 14
	local panelPad = if tier == "Phone" then 10 else 14
	local passMode: "Row" | "Grid" | "List" = if tier == "Desktop"
		then "Row"
		elseif tier == "Tablet" then "Grid"
		else "List"
	local inner = contentW - 2 * panelPad
	local passUnitW, passW, passH, bundleW, bundleH
	if passMode == "Row" then
		passUnitW = math.floor((inner - 4 * passGap) / 5)
		passW = passUnitW
		passH = math.min(math.floor(passUnitW / L.PassRatio), 320)
		bundleW = 2 * passUnitW + passGap
		bundleH = passH
	elseif passMode == "Grid" then
		passUnitW = math.floor((inner - 2 * passGap) / 3)
		passW = passUnitW
		passH = math.floor(passUnitW / L.PassRatio)
		bundleW = inner
		bundleH = math.floor(passH * 0.62)
	else
		passUnitW = inner
		passW = inner
		passH = 170
		bundleW = inner
		bundleH = 196
	end

	-- Style, Cash, Free -----------------------------------------------------------------------------------------
	local gridCols = if tier == "Desktop" then 4 else 2
	local gridHorizontal = tier ~= "Desktop"
	local gridW = math.floor((contentW - (gridCols - 1) * gap) / gridCols)
	local gridH = if tier == "Desktop"
		then math.min(math.floor(gridW / 0.86), 330)
		elseif tier == "Tablet" then 160
		else 150
	local freeH = if tier == "Desktop" then 130 else 118

	return {
		tier = tier,
		size = i.size,
		contentW = contentW,
		margin = margin,
		gap = gap,
		titleSize = titleSize,
		closeSize = closeSize,
		rowH = rowH,
		topPad = topPad,
		tabGap = tabGap,
		tabsInline = tabsInline,
		tabH = tabH,
		headerH = headerH,
		pageX = margin,
		pageY = headerH,
		pageW = pageW,
		pageH = pageH,
		heroW = heroW,
		heroH = heroH,
		sideW = sideW,
		sideH = sideH,
		sideStacked = sideStacked,
		sideBody = sideBody,
		sectionHeaderH = if tier == "Desktop" then 70 elseif tier == "Tablet" then 62 else 54,
		sectionGap = if tier == "Phone" then 14 else 22,
		passMode = passMode,
		panelPad = panelPad,
		passUnitW = passUnitW,
		passW = passW,
		passH = passH,
		bundleW = bundleW,
		bundleH = bundleH,
		passGap = passGap,
		gridCols = gridCols,
		gridHorizontal = gridHorizontal,
		gridW = gridW,
		gridH = gridH,
		freeH = freeH,
		footerH = 64,
	}
end

return ShopLayout
