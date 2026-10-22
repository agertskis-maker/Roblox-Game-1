--!strict
-- PortalCardMock: the Dusty Highway portal card drawn over gameplay (Lane 3 HUD prototype,
-- PREVIEW only; no unlock, teleport or World logic). HUD rebuild (2026-10-22, H-15): restyled
-- into the arcade family (deep panel, warm world header band, kit buttons, dark wells).
--
--   local portal = PortalCardMock.new(ctx, { onGo = function(car) end, onClose = fn? })
--   portal:open(returnTo?)  portal:close()  portal:isOpen()
--   portal:setLocked(on)      -- locked: requirement rows + a disabled LOCKED button
--                             -- unlocked: an "Unlocked" row, orange GO active
--   portal:setIndex(i)        -- the Start In carousel position
--   portal:layout()  portal:setVisible(on)  portal:destroy()  portal:getDebugState()
--
-- All values are synthetic: "$1,200 / $5,000" Cash and "2 / 3 Downtown cars" (outline v2.2:
-- unlock = Cash + cars owned from the previous World). The "Preview values" caption and the
-- reserved Peek area are HARNESS CAPTIONS (PreviewCaption), so player-facing captures show
-- neither. The Start In cars are three Dusty Highway roster names (proposed roster), built as
-- proxies. GO only calls options.onGo(car) while unlocked. It never teleports. Default: locked.

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CarCard = require(Prototype.Cards.CarCard)
local Icons = require(Prototype.Icons)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)

local make = Arcade.make

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
	instances: number,
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

-- Warm desert identity for World 2 (preview colours). TOKEN CANDIDATE (world header band).
PortalCardMock.WorldLight = Color3.fromRGB(255, 200, 110)
PortalCardMock.WorldMid = Color3.fromRGB(246, 150, 60)
PortalCardMock.WorldDeep = Color3.fromRGB(214, 96, 28)

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

	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body

	-- world identity header
	local header = Style.header(panel, {
		colours = ColorSequence.new({
			ColorSequenceKeypoint.new(0, PortalCardMock.WorldLight),
			ColorSequenceKeypoint.new(0.5, PortalCardMock.WorldMid),
			ColorSequenceKeypoint.new(1, PortalCardMock.WorldDeep),
		}),
		title = "DUSTY HIGHWAY",
		icon = "Portal",
		height = 72,
	})
	local worldSub = Style.text(header.band, "World 2", "Label", { name = "World", z = header.title.ZIndex })
	local closeButton = Overlay.closeButton(panel, function()
		portal:close()
	end)
	trove:Add(closeButton.trove)
	closeButton.root.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.root.ZIndex = 12

	-- left: Start In carousel + GO
	local startArea: Frame = make("Frame", { Name = "StartIn", BackgroundTransparency = 1, ZIndex = 4, Parent = panel })
	local startLabel = Overlay.text(startArea, "START IN", 18, nil, Enum.TextXAlignment.Center, 6)
	startLabel.Position = UDim2.fromOffset(0, 0)
	local carCard = CarCard.new(startArea, PortalCardMock.StartCars[1], {
		size = Vector2.new(160, 224),
		spinning = false,
		anchor = Vector2.new(0.5, 0),
	})
	trove:Add(function()
		carCard:destroy()
	end)
	local counter = Overlay.text(startArea, "1 / 3", 16, Style.TextSoft, Enum.TextXAlignment.Center, 6)
	local function arrow(name: string, label: string, step: number): Arcade.Button
		local b = Arcade.button(startArea, {
			name = name,
			label = label,
			fill = "Garage",
			size = "Custom",
			width = 52,
			height = 52,
			cooldown = 0.15,
			onActivate = function()
				portal:setIndex(index + step)
			end,
		})
		b.root.ZIndex = 12
		trove:Add(b.trove)
		return b
	end
	local prevButton = arrow("Previous", "<", -1)
	local nextButton = arrow("Next", ">", 1)
	local goButton = Arcade.button(panel, {
		name = "Go",
		label = "GO",
		fill = "Retry",
		size = "Custom",
		width = 196,
		height = 62,
		pattern = true,
		cooldown = 0.6,
		onActivate = function()
			if not locked and opts.onGo then
				goCalls += 1
				opts.onGo(PortalCardMock.StartCars[index])
			end
		end,
	})
	trove:Add(goButton.trove)
	goButton.root.ZIndex = 12
	-- the locked state is its own disabled button with a lock icon and a word (not colour alone)
	local lockedButton = Arcade.button(panel, {
		name = "Locked",
		label = "LOCKED",
		fill = "Retry",
		size = "Custom",
		width = 196,
		height = 62,
		icon = "Lock",
	})
	trove:Add(lockedButton.trove)
	lockedButton.root.ZIndex = 12
	lockedButton.setEnabled(false)

	-- right: requirements + Peek
	local reqArea: Frame =
		make("Frame", { Name = "Requirements", BackgroundTransparency = 1, ZIndex = 4, Parent = panel })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = reqArea,
	})
	local reqTitle = Overlay.text(reqArea, "TO UNLOCK", 20, nil, nil, 6)
	reqTitle.LayoutOrder = 0
	type Row = { frame: Frame, status: Frame, text: string }
	local rows: { Row } = {}
	for i, req in PortalCardMock.Requirements do
		local row = Style.well(reqArea, "Row_" .. req.label, 5)
		row.Size = UDim2.new(1, 0, 0, 62)
		row.LayoutOrder = i
		local icon: Frame = make("Frame", {
			Name = "Icon",
			Position = UDim2.fromOffset(8, 5),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = row,
		})
		Arcade.icon(icon, req.icon)
		local label = Overlay.text(row, req.label, 18, nil, nil, 6)
		label.Position = UDim2.fromOffset(40, 5)
		label.Size = UDim2.new(1, -40 - 40, 0, 24)
		local valueText = if req.cash
			then string.format("%s / %s", money(req.have), money(req.need))
			else string.format("%d / %d", req.have, req.need)
		local track, set = Overlay.progress(row, if req.cash then "Green" else "Garage", 6)
		track.Position = UDim2.fromOffset(10, 34)
		track.Size = UDim2.new(1, -20 - 36, 0, 22)
		set(req.have / req.need, valueText)
		local statusIcon: Frame = make("Frame", {
			Name = "Status",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = row,
		})
		table.insert(rows, { frame = row, status = statusIcon, text = valueText })
	end
	local unlockedRow: Frame = make("Frame", {
		Name = "Unlocked",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		LayoutOrder = 10,
		Visible = false,
		ZIndex = 5,
		Parent = reqArea,
	})
	Arcade.corner(unlockedRow, 8)
	Arcade.outline(unlockedRow, "Button")
	make("UIGradient", { Color = PreviewTokens.Arcade.Fill.Green, Rotation = 90, Parent = unlockedRow })
	local unlockedIcon: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = unlockedRow,
	})
	Icons.draw(unlockedIcon, "Check", Color3.new(1, 1, 1))
	local unlockedText = Overlay.text(unlockedRow, "Unlocked! Pick a car and go.", 20, nil, nil, 6)
	unlockedText.AnchorPoint = Vector2.new(0, 0.5)
	unlockedText.Position = UDim2.new(0, 46, 0.5, 0)
	unlockedText.Size = UDim2.new(1, -54, 0, 26)

	local caption = Overlay.text(reqArea, "Preview values", 16, Style.TextSoft, nil, 6)
	caption:SetAttribute("PreviewCaption", true) -- harness caption
	caption.LayoutOrder = 15

	-- reserved Peek area (future; does nothing) - a harness caption, so player captures omit it
	local peek = Style.well(reqArea, "PeekReserved", 5)
	peek:SetAttribute("PreviewCaption", true)
	peek.Size = UDim2.new(1, 0, 0, 84)
	peek.LayoutOrder = 20
	local peekTitle = Overlay.text(peek, "Peek (future)", 18, Style.TextSoft, Enum.TextXAlignment.Center, 6)
	peekTitle.Position = UDim2.fromOffset(0, 12)
	local peekSub =
		Overlay.text(peek, "Reserved: roster silhouettes", 16, Style.TextSoft, Enum.TextXAlignment.Center, 6)
	peekSub.Position = UDim2.fromOffset(0, 42)

	local function applyLocked()
		for _, r in rows do
			r.frame.Visible = locked
			r.status:ClearAllChildren()
			Arcade.icon(r.status, "Lock")
		end
		reqTitle.Text = if locked then "TO UNLOCK" else "DUSTY HIGHWAY"
		unlockedRow.Visible = not locked
		goButton.root.Visible = not locked
		lockedButton.root.Visible = locked
		goButton.setEnabled(not locked)
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
			pw, ph = ds.X - 24, ds.Y - 18
		else
			pw, ph = ds.X - 16, ds.Y - 18
		end
		shell.root.Size = UDim2.fromOffset(pw, ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		local short = kind == "Short"
		local headH = if short then 56 else 72
		header.setHeight(headH)
		closeButton.root.Position = UDim2.new(1, -8, 0, headH / 2)
		local titleLeft = header.title.Position.X.Offset
		local rightUsed = Overlay.CloseWidth + 18
		header.title.AnchorPoint = Vector2.new(0, 0.5)
		header.title.Position = UDim2.new(0, titleLeft, 0.5, if short then -8 else -10)
		header.title.Size = UDim2.new(1, -titleLeft - rightUsed, 0, if short then 30 else 38)
		worldSub.AnchorPoint = Vector2.new(0, 0.5)
		worldSub.Position = UDim2.new(0, titleLeft + 2, 0.5, if short then 15 else 20)
		worldSub.Size = UDim2.new(1, -titleLeft - rightUsed, 0, 22)
		local bodyY = headH + 12
		local bodyH = ph - bodyY - 10
		local cardSize: Vector2
		local startX, startW, startY, startH
		local goX, goBottom
		if kind == "Tall" then
			-- one column: requirements, then Start In and GO at the bottom
			reqArea.Position = UDim2.fromOffset(14, bodyY)
			reqArea.Size = UDim2.new(1, -28, 0, 270)
			cardSize = Vector2.new(140, 196)
			startH = 24 + cardSize.Y + 4 + 22
			startX, startW = 14, pw - 28
			startY = ph - 12 - 66 - 8 - startH
			goX, goBottom = pw / 2, ph - 10
		elseif short then
			-- phone landscape: three columns (carousel | requirements | GO)
			cardSize = Vector2.new(112, 150)
			startX, startW, startY, startH = 10, 236, bodyY, bodyH
			reqArea.Position = UDim2.fromOffset(10 + 236 + 10, bodyY)
			reqArea.Size = UDim2.fromOffset(pw - 236 - 10 - 10 - 206 - 10, bodyH)
			goX, goBottom = pw - 10 - 103, bodyY + math.floor(bodyH / 2) + 36
		else
			local leftW = math.floor(pw * 0.46)
			cardSize = if bodyH >= 420 then Vector2.new(200, 280) else Vector2.new(160, 224)
			startX, startW, startY, startH = 14, leftW - 14, bodyY, bodyH - 76
			reqArea.Position = UDim2.fromOffset(leftW + 14, bodyY)
			reqArea.Size = UDim2.fromOffset(pw - leftW - 28, bodyH)
			goX, goBottom = 14 + (leftW - 14) / 2, ph - 12
		end
		startArea.Position = UDim2.fromOffset(startX, startY)
		startArea.Size = UDim2.fromOffset(startW, startH)
		for _, b in { goButton, lockedButton } do
			b.root.AnchorPoint = Vector2.new(0.5, 1)
			b.root.Position = UDim2.fromOffset(goX, goBottom)
		end
		local rowH = if short then 58 else 62
		for _, r in rows do
			r.frame.Size = UDim2.new(1, 0, 0, rowH)
		end
		peek.Size = UDim2.new(1, 0, 0, if short then 44 else 84)
		peekTitle.Position = UDim2.fromOffset(0, if short then 9 else 12)
		peekSub.Visible = not short
		carCard:setSize(cardSize)
		-- Start In stack: label, the card between the two arrows, then the counter
		startLabel.Position = UDim2.fromOffset(0, 0)
		local cardY = 26
		carCard.root.AnchorPoint = Vector2.new(0.5, 0)
		carCard.root.Position = UDim2.new(0.5, 0, 0, cardY)
		local arrowY = cardY + math.floor(cardSize.Y / 2) - 28
		local half = math.floor(cardSize.X / 2)
		prevButton.root.AnchorPoint = Vector2.new(1, 0)
		prevButton.root.Position = UDim2.new(0.5, -half - 12, 0, arrowY)
		nextButton.root.AnchorPoint = Vector2.new(0, 0)
		nextButton.root.Position = UDim2.new(0.5, half + 12, 0, arrowY)
		counter.Position = UDim2.fromOffset(0, cardY + cardSize.Y + 8)
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
				instances = #overlay.root:GetDescendants(),
			}
		end,
	}

	applyLocked()
	applyIndex()
	layoutNow()
	return portal
end

return PortalCardMock
