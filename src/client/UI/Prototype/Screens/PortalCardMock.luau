--!strict
-- PortalCardMock: the Dusty Highway portal card drawn over gameplay (Lane 3 HUD prototype,
-- PREVIEW only; no unlock, teleport or World logic).
--
--   local portal = PortalCardMock.new(ctx, { onGo = function(car) end, onClose = fn? })
--   portal:open(returnTo?)  portal:close()  portal:isOpen()
--   portal:setLocked(on)      -- locked: requirement rows + lock, GO greyed as "LOCKED"
--                             -- unlocked: an "Unlocked" row, orange GO active
--   portal:setIndex(i)        -- the Start In carousel position
--   portal:layout()  portal:setVisible(on)  portal:destroy()  portal:getDebugState()
--
-- All values are synthetic and labelled PREVIEW on the card: "$1,200 / $5,000" Cash and
-- "2 / 3 Downtown cars" (outline v2.2: unlock = Cash + cars owned from the previous World).
-- The Start In cars are three Dusty Highway roster names (proposed roster), built as proxies.
-- The Peek area is reserved and visibly labelled "Peek (future)"; it does nothing.
-- GO only calls options.onGo(car) while unlocked. It never teleports. Default state: locked.

local Prototype = script.Parent.Parent
local CarCard = require(Prototype.Cards.CarCard)
local Gloss = require(Prototype.Gloss)
local Icons = require(Prototype.Icons)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)

local C = PreviewTokens.Color
local make = Gloss.make

local PortalCardMock = {}

export type CarRef = CarCard.CarRef

export type Options = {
	onGo: ((CarRef) -> ())?,
	onClose: (() -> ())?,
	locked: boolean?, -- default true
}

export type DebugState = {
	open: boolean,
	kind: string,
	locked: boolean,
	index: number,
	carId: string,
	goEnabled: boolean,
	goCalls: number,
	requirements: { string },
}

export type Portal = {
	root: Frame,
	layout: (self: Portal) -> (),
	setVisible: (self: Portal, on: boolean) -> (),
	open: (self: Portal, returnTo: GuiObject?) -> (),
	close: (self: Portal) -> (),
	isOpen: (self: Portal) -> boolean,
	setLocked: (self: Portal, on: boolean) -> (),
	setIndex: (self: Portal, index: number) -> (),
	destroy: (self: Portal) -> (),
	getDebugState: (self: Portal) -> DebugState,
}

-- Warm desert identity for World 2 (preview colours).
PortalCardMock.WorldLight = Color3.fromRGB(255, 200, 110)
PortalCardMock.WorldDeep = Color3.fromRGB(226, 112, 36)

-- Synthetic requirement fixtures (display only).
PortalCardMock.Requirements = {
	{ icon = "Coin", label = "Cash", have = 1200, need = 5000, cash = true },
	{ icon = "Car", label = "Downtown cars", have = 2, need = 3, cash = false },
}

local function dustyCar(
	id: string,
	name: string,
	rarity: string,
	family: string,
	quirk: string,
	paint: Color3,
	length: number
): CarRef
	return {
		id = id,
		name = name,
		rarity = rarity :: any,
		variant = "None",
		family = family,
		quirk = quirk,
		owned = true,
		paint = paint,
		length = length,
		model = "Proxy",
	}
end

-- Start In choices (synthetic; names from the proposed Dusty Highway roster).
PortalCardMock.StartCars = {
	dustyCar("razzer", "Razzer", "Common", "Compact", "Nimble", Color3.fromRGB(25, 181, 176), 11),
	dustyCar("winnie", "Winnie Bravo", "Uncommon", "Van", "Cool Runner", Color3.fromRGB(224, 165, 38), 20),
	dustyCar("baja", "Baja Bruiser", "Rare", "Pickup", "Rugged", Color3.fromRGB(226, 80, 60), 16),
} :: { CarRef }

local function money(n: number): string
	local digits = string.format("%d", n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if digits:sub(1, 1) == "," then
		digits = digits:sub(2)
	end
	return "$" .. digits
end

function PortalCardMock.new(ctx: Overlay.Ctx, options: Options?): Portal
	local opts: Options = options or {}
	local locked = opts.locked ~= false
	local index = 1
	local goCalls = 0
	local portal: Portal

	local overlay = Overlay.new(ctx, { name = "PortalCardMock" })
	local trove = overlay.trove
	local content = overlay.content

	local panel = Gloss.panel(content, {
		name = "Panel",
		size = UDim2.fromOffset(700, 400),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		radius = 20,
		z = 3,
	})
	local panelShadow = content:FindFirstChild("Shadow") :: Frame?

	-- world identity header
	local header = make("Frame", {
		Name = "Header",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = panel,
	})
	Gloss.corner(header, 16)
	Gloss.stroke(header, 3)
	Gloss.gradient(header, PortalCardMock.WorldLight, PortalCardMock.WorldDeep)
	Gloss.highlight(header, 16)
	local portalIcon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = header,
	})
	Icons.draw(portalIcon, "Portal", C.White)
	local worldTitle = Overlay.title(header, "DUSTY HIGHWAY", 32, C.White, Color3.fromRGB(255, 236, 200), 6)
	worldTitle.AnchorPoint = Vector2.new(0, 0.5)
	worldTitle.Position = UDim2.new(0, 60, 0.5, -8)
	local worldSub = Overlay.text(header, "World 2", 16, C.Ink, nil, 6)
	worldSub.AnchorPoint = Vector2.new(0, 0.5)
	worldSub.Position = UDim2.new(0, 62, 0.5, 18)
	local closeButton = Overlay.closeButton(panel, function()
		portal:close()
	end)
	trove:Add(closeButton.trove)
	closeButton.root.AnchorPoint = Vector2.new(1, 0)
	closeButton.root.ZIndex = 8

	-- left: Start In carousel + GO
	local startArea = make("Frame", { Name = "StartIn", BackgroundTransparency = 1, ZIndex = 4, Parent = panel })
	local startLabel = Overlay.text(startArea, "START IN", 18, C.Ink, Enum.TextXAlignment.Center, 6)
	startLabel.Position = UDim2.fromOffset(0, 0)
	local carCard = CarCard.new(startArea, PortalCardMock.StartCars[1], {
		size = Vector2.new(160, 224),
		spinning = false,
		anchor = Vector2.new(0.5, 0),
	})
	trove:Add(function()
		carCard:destroy()
	end)
	local counter = Overlay.text(startArea, "1 / 3", 16, C.InkSoft, Enum.TextXAlignment.Center, 6)
	local prevButton = Gloss.button(startArea, {
		name = "Previous",
		size = Vector2.new(48, 48),
		light = C.SettingsLight,
		deep = C.SettingsDeep,
		text = "<",
		textSize = 26,
		radius = 14,
		onActivate = function()
			portal:setIndex(index - 1)
		end,
		cooldown = 0.15,
	})
	trove:Add(prevButton.trove)
	local nextButton = Gloss.button(startArea, {
		name = "Next",
		size = Vector2.new(48, 48),
		light = C.SettingsLight,
		deep = C.SettingsDeep,
		text = ">",
		textSize = 26,
		radius = 14,
		onActivate = function()
			portal:setIndex(index + 1)
		end,
		cooldown = 0.15,
	})
	trove:Add(nextButton.trove)
	local goButton = Gloss.button(panel, {
		name = "Go",
		size = Vector2.new(184, 60),
		light = C.PrimaryLight,
		deep = C.PrimaryDeep,
		text = "GO",
		textSize = 30,
		radius = 18,
		onActivate = function()
			if not locked and opts.onGo then
				goCalls += 1
				opts.onGo(PortalCardMock.StartCars[index])
			end
		end,
		cooldown = 0.6,
	})
	trove:Add(goButton.trove)
	local goLock = make("Frame", {
		Name = "Lock",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = goButton.body,
	})
	Icons.draw(goLock, "Lock", C.White)

	-- right: requirements + Peek
	local reqArea = make("Frame", { Name = "Requirements", BackgroundTransparency = 1, ZIndex = 4, Parent = panel })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = reqArea,
	})
	local reqTitle = Overlay.text(reqArea, "TO UNLOCK", 18, C.Ink, nil, 6)
	reqTitle.LayoutOrder = 0
	type Row = { frame: Frame, set: (number, string) -> (), status: TextLabel, icon: Frame, text: string }
	local rows: { Row } = {}
	for i, req in PortalCardMock.Requirements do
		local row = make("Frame", {
			Name = "Row_" .. req.label,
			Size = UDim2.new(1, 0, 0, 58),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = reqArea,
		})
		Gloss.corner(row, 12)
		Gloss.stroke(row, 2)
		local icon = make("Frame", {
			Name = "Icon",
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = row,
		})
		Icons.draw(icon, req.icon :: any, C.Ink)
		local label = Overlay.text(row, req.label, 16, C.Ink, nil, 6)
		label.Position = UDim2.fromOffset(38, 6)
		label.Size = UDim2.new(1, -38 - 40, 0, 22)
		local valueText = if req.cash
			then string.format("PREVIEW %s / %s", money(req.have), money(req.need))
			else string.format("PREVIEW %d / %d", req.have, req.need)
		local track, set = Overlay.progress(row, C.CashLight, C.CashDeep, 6)
		track.Position = UDim2.fromOffset(10, 31)
		track.Size = UDim2.new(1, -20 - 34, 0, 20)
		set(req.have / req.need, valueText)
		local statusIcon = make("Frame", {
			Name = "Status",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = row,
		})
		local status = Overlay.text(row, "", 16, C.InkSoft, Enum.TextXAlignment.Right, 6)
		status.Visible = false
		table.insert(rows, { frame = row, set = set, status = status, icon = statusIcon, text = valueText })
	end
	local unlockedRow = make("Frame", {
		Name = "Unlocked",
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = C.SuccessLight,
		BorderSizePixel = 0,
		LayoutOrder = 10,
		Visible = false,
		ZIndex = 5,
		Parent = reqArea,
	})
	Gloss.corner(unlockedRow, 12)
	Gloss.stroke(unlockedRow, 2)
	local unlockedIcon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = unlockedRow,
	})
	Icons.draw(unlockedIcon, "Check", C.Ink)
	local unlockedText = Overlay.text(unlockedRow, "Unlocked! Pick a car and go.", 18, C.Ink, nil, 6)
	unlockedText.AnchorPoint = Vector2.new(0, 0.5)
	unlockedText.Position = UDim2.new(0, 44, 0.5, 0)
	unlockedText.Size = UDim2.new(1, -52, 0, 24)

	-- reserved Peek area (future; does nothing)
	local peek = make("Frame", {
		Name = "PeekReserved",
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = C.PanelShade,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		LayoutOrder = 20,
		ZIndex = 5,
		Parent = reqArea,
	})
	Gloss.corner(peek, 12)
	local peekStroke = Gloss.stroke(peek, 2)
	peekStroke.Transparency = 0.5
	local peekTitle = Overlay.text(peek, "Peek (future)", 18, C.InkSoft, Enum.TextXAlignment.Center, 6)
	peekTitle.Position = UDim2.fromOffset(0, 12)
	local peekSub = Overlay.text(peek, "Reserved: roster silhouettes", 16, C.InkSoft, Enum.TextXAlignment.Center, 6)
	peekSub.Position = UDim2.fromOffset(0, 42)

	local function applyLocked()
		for _, r in rows do
			r.frame.Visible = locked
			r.icon:ClearAllChildren()
			Icons.draw(r.icon, "Lock", C.InkSoft)
		end
		reqTitle.Text = if locked then "TO UNLOCK" else "DUSTY HIGHWAY"
		unlockedRow.Visible = not locked
		goButton.setEnabled(not locked)
		goLock.Visible = locked
		if goButton.label then
			goButton.label.Text = if locked then "LOCKED" else "GO"
			goButton.label.TextSize = if locked then 22 else 30
		end
	end

	local function applyIndex()
		local cars = PortalCardMock.StartCars
		index = ((index - 1) % #cars) + 1
		carCard:setCar(cars[index])
		counter.Text = string.format("%d / %d", index, #cars)
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local pw, ph
		if kind == "Wide" then
			pw, ph = math.min(ds.X - 32, 820), math.min(ds.Y - 24, 560)
		elseif kind == "Short" then
			pw, ph = ds.X - 24, ds.Y - 16
		else
			pw, ph = ds.X - 16, ds.Y - 16
		end
		panel.Size = UDim2.fromOffset(pw, ph)
		if panelShadow then
			panelShadow.Size = panel.Size
		end
		local headerH = if kind == "Short" then 56 else 72
		header.Position = UDim2.fromOffset(10, 10)
		header.Size = UDim2.new(1, -20 - 58, 0, headerH)
		closeButton.root.Position = UDim2.new(1, -10, 0, 10 + math.floor((headerH - 52) / 2))
		worldTitle.TextSize = if kind == "Short" then 28 else 32
		worldTitle.Size = UDim2.new(1, -72, 0, worldTitle.TextSize + 6)
		local bodyY = 10 + headerH + 8
		local bodyH = ph - bodyY - 10
		local cardSize: Vector2
		local startX, startW, startY, startH
		local goX, goBottom
		if kind == "Tall" then
			-- one column: requirements, Peek, then Start In and GO at the bottom
			reqArea.Position = UDim2.fromOffset(14, bodyY)
			reqArea.Size = UDim2.new(1, -28, 0, 270)
			cardSize = Vector2.new(140, 196)
			startH = 24 + cardSize.Y + 4 + 22
			startX, startW = 14, pw - 28
			startY = ph - 12 - 64 - 8 - startH
			goX, goBottom = pw / 2, ph - 10
		elseif kind == "Short" then
			-- phone landscape: three columns (carousel | requirements + Peek | GO)
			cardSize = Vector2.new(112, 150)
			startX, startW, startY, startH = 10, 236, bodyY, bodyH
			reqArea.Position = UDim2.fromOffset(10 + 236 + 10, bodyY)
			reqArea.Size = UDim2.fromOffset(pw - 236 - 10 - 10 - 196 - 10, bodyH)
			goX, goBottom = pw - 10 - 98, bodyY + math.floor(bodyH / 2) + 34
		else
			local leftW = math.floor(pw * 0.46)
			cardSize = if bodyH >= 420 then Vector2.new(200, 280) else Vector2.new(160, 224)
			startX, startW, startY, startH = 14, leftW - 14, bodyY, bodyH - 72
			reqArea.Position = UDim2.fromOffset(leftW + 14, bodyY)
			reqArea.Size = UDim2.fromOffset(pw - leftW - 28, bodyH)
			goX, goBottom = 14 + (leftW - 14) / 2, ph - 12
		end
		startArea.Position = UDim2.fromOffset(startX, startY)
		startArea.Size = UDim2.fromOffset(startW, startH)
		goButton.root.AnchorPoint = Vector2.new(0.5, 1)
		goButton.root.Position = UDim2.fromOffset(goX, goBottom)
		local short = kind == "Short"
		local rowH = if short then 54 else 58
		for _, r in rows do
			r.frame.Size = UDim2.new(1, 0, 0, rowH)
		end
		peek.Size = UDim2.new(1, 0, 0, if short then 44 else 84)
		peekTitle.Position = UDim2.fromOffset(0, if short then 9 else 12)
		peekSub.Visible = not short
		carCard:setSize(cardSize)
		-- Start In stack: label, the card between the two arrows, then the counter
		startLabel.Position = UDim2.fromOffset(0, 0)
		local cardY = 24
		carCard.root.AnchorPoint = Vector2.new(0.5, 0)
		carCard.root.Position = UDim2.new(0.5, 0, 0, cardY)
		local arrowY = cardY + math.floor(cardSize.Y / 2) - 26
		local half = math.floor(cardSize.X / 2)
		prevButton.root.AnchorPoint = Vector2.new(1, 0)
		prevButton.root.Position = UDim2.new(0.5, -half - 12, 0, arrowY)
		nextButton.root.AnchorPoint = Vector2.new(0, 0)
		nextButton.root.Position = UDim2.new(0.5, half + 12, 0, arrowY)
		counter.Position = UDim2.fromOffset(0, cardY + cardSize.Y + 6)
		counter.Size = UDim2.new(1, 0, 0, 22)
	end

	overlay:setBack(function()
		portal:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	portal = {
		root = overlay.root,
		layout = function(_self: Portal)
			layoutNow()
		end,
		setVisible = function(_self: Portal, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
			carCard:setVisible(on)
		end,
		open = function(_self: Portal, returnTo: GuiObject?)
			layoutNow()
			overlay:open(if locked then nextButton.body else goButton.body, returnTo)
			carCard:setSpinning(true)
		end,
		close = function(_self: Portal)
			if not overlay:isOpen() then
				return
			end
			overlay:close()
			carCard:setSpinning(false)
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Portal): boolean
			return overlay:isOpen()
		end,
		setLocked = function(_self: Portal, on: boolean)
			locked = on
			applyLocked()
		end,
		setIndex = function(_self: Portal, i: number)
			index = i
			applyIndex()
		end,
		destroy = function(_self: Portal)
			overlay:destroy()
		end,
		getDebugState = function(_self: Portal): DebugState
			local reqs = {}
			for _, r in rows do
				table.insert(reqs, r.text)
			end
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				locked = locked,
				index = index,
				carId = PortalCardMock.StartCars[index].id,
				goEnabled = not locked,
				goCalls = goCalls,
				requirements = reqs,
			}
		end,
	}

	applyLocked()
	applyIndex()
	layoutNow()
	return portal
end

return PortalCardMock
