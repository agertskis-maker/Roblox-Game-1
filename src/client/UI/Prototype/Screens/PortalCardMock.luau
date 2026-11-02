--!strict
-- PortalCardMock: the portal card drawn over gameplay (Lane 3, big round M12-02; PREVIEW). It shows a World's gate:
-- the World name and emblem, a wide scene preview, two independent requirement rows, Peek (roster silhouettes) and, once
-- the portal is open, Start In (a horizontal picker of owned cars, the Loaner always first) and a big GO.
--
--   local portal = PortalCardMock.new(ctx, { onGo = function(request) end, onClose = fn?, state = State?, guard = Guard? })
--   portal:open(returnTo?)   portal:close()   portal:isOpen()
--   portal:setState(state)   portal:setPreset("Dusty_Checking")     -- PortalFixtures presets (see PresetNames)
--   portal:setLocked(on)     portal:setIndex(i)    portal:selectCar(id)
--   portal:showPeek(on)      portal:pressGo()      portal:pressPeek()   -- the same paths the buttons take (for tests)
--   portal:layout()  portal:setVisible(on)  portal:destroy()  portal:getDebugState()  portal:touchReport()
--   PortalCardMock.geometry(designSize) -> Geo      -- the pure layout (so a harness can check any viewport)
--
-- SEAM. Every number, name and verdict comes from a PortalFixtures.State (PREVIEW; Brian L supplies the real ones, see
-- that file). The card never works out a lock from the rows: `state.open` is the verdict. In the beta every portal is
-- open (decision 0030) and the Loaner of the World is always selectable.
--
-- GO. At most ONE start request per activation (an activation = one open of the card). It goes through options.onGo with
-- { worldId, carId, isLoaner }; the lead wires that to the existing beta start. The card does nothing else: no
-- teleport, no ownership change, no grant. A guard shared with another start path (a walk-through into an open portal)
-- can be passed as options.guard; the card then neither resets nor bypasses it.
--
-- STATES. Checking and Error show "Checking..." in place of every value (never LOCKED, never zero); a locked portal says
-- "Keep collecting!" and offers "Peek at cars"; an open portal says "Choose your starting car" and offers GO.
-- Reduced motion: nothing here animates beyond the shared overlay's short fade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local IconArt = require(Prototype.Home.IconArt)
local Overlay = require(script.Parent.Overlay)
local PortalFixtures = require(Prototype.SupportFixtures.PortalFixtures)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)

local A = PreviewTokens.Arcade
local make = Arcade.make

local PortalCardMock = {}

export type GoRequest = PortalFixtures.GoRequest

export type Options = {
	onGo: ((GoRequest) -> ())?,
	onClose: (() -> ())?,
	state: PortalFixtures.State?,
	guard: SupportKit.Guard?,
	locked: boolean?, -- older option: sets state.open = not locked
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	pw: number,
	ph: number,
	headH: number,
	footH: number,
	compact: boolean,
	scene: Rect,
	scroll: Rect,
	foot: Rect,
	innerW: number,
	stacked: boolean, -- requirement rows put the bar under the label
	rowH: number,
	chipW: number,
	chipH: number,
	iconSide: number,
	cellW: number,
	cellH: number,
}

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	world: string,
	status: string,
	locked: boolean,
	view: string,
	index: number,
	carId: string,
	goEnabled: boolean,
	goCalls: number, -- GO presses that were accepted (one per activation)
	goPresses: number, -- every GO press, accepted or not
	startRequests: number,
	lastRequest: GoRequest?,
	requirements: { string },
	choices: number,
	peekCells: number,
	instances: number,
	pill: string,
	title: string,
}

export type Portal = {
	root: Frame,
	layout: (self: Portal) -> (),
	setVisible: (self: Portal, on: boolean) -> (),
	open: (self: Portal, returnTo: GuiObject?) -> (),
	close: (self: Portal) -> (),
	isOpen: (self: Portal) -> boolean,
	setState: (self: Portal, state: PortalFixtures.State) -> (),
	setPreset: (self: Portal, name: string) -> boolean,
	setLocked: (self: Portal, on: boolean) -> (),
	setIndex: (self: Portal, index: number) -> (),
	selectCar: (self: Portal, id: string) -> boolean,
	showPeek: (self: Portal, on: boolean) -> (),
	pressGo: (self: Portal) -> boolean,
	pressPeek: (self: Portal) -> (),
	destroy: (self: Portal) -> (),
	getDebugState: (self: Portal) -> DebugState,
	touchReport: (self: Portal) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY -----------------------------------------------------------------------------------

-- The whole layout as a pure function of the design-px viewport, so 844 x 390, 667 x 375, 1024 x 768 and 1920 x 1080
-- (and any other) can be checked without opening the card. Compact (a phone in landscape): one vertical column in a
-- scrolling body with the action pinned in the card's own footer. Regular and Roomy: the scene on the left, the
-- requirements or the Start In picker on the right, the action pinned under them.
function PortalCardMock.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	if fit == "Compact" then
		local pw, ph = math.min(ds.X - 12, 720), ds.Y - 8
		local headH, footH = 52, 64
		local scrollW = pw - 20
		return {
			fit = fit,
			pw = pw,
			ph = ph,
			headH = headH,
			footH = footH,
			compact = true,
			scene = { x = 0, y = 0, w = scrollW - 8, h = 52 },
			scroll = { x = 10, y = headH + 6, w = scrollW, h = ph - headH - footH - 10 },
			foot = { x = 0, y = ph - footH, w = pw, h = footH },
			innerW = scrollW - 8,
			stacked = scrollW - 8 < 420,
			rowH = 50,
			chipW = 92,
			chipH = 96,
			iconSide = 34,
			cellW = 112,
			cellH = 122,
		}
	end
	local roomy = fit == "Roomy"
	local pw = if roomy then math.min(ds.X - 32, 880) else math.min(ds.X - 24, 760)
	local ph = if roomy then math.min(ds.Y - 24, 560) else math.min(ds.Y - 16, 460)
	local headH = if roomy then 68 else 60
	local footH = if roomy then 76 else 72
	local leftW = math.floor(pw * (if roomy then 0.42 else 0.4))
	local rightX = 12 + leftW + 12
	local rightW = pw - rightX - 12
	local stacked = rightW - 8 < 420
	return {
		fit = fit,
		pw = pw,
		ph = ph,
		headH = headH,
		footH = footH,
		compact = false,
		scene = { x = 12, y = headH + 12, w = leftW, h = ph - headH - 24 },
		scroll = { x = rightX, y = headH + 8, w = rightW, h = ph - headH - footH - 12 },
		foot = { x = rightX, y = ph - footH - 4, w = rightW, h = footH },
		innerW = rightW - 8,
		stacked = stacked,
		rowH = if stacked then 68 else (if roomy then 62 else 56),
		chipW = if roomy then 112 else 100,
		chipH = if roomy then 116 else 104,
		iconSide = if roomy then 48 else 40,
		cellW = if roomy then 124 else 112,
		cellH = if roomy then 136 else 126,
	}
end

-- BUILD --------------------------------------------------------------------------------------

type Row = {
	frame: Frame,
	req: PortalFixtures.Requirement,
	label: TextLabel,
	track: Frame,
	set: (number, string) -> (),
	check: Frame,
	icon: Frame,
	text: string,
}

type Chip = { id: string, stroke: UIStroke, tick: Frame }

local function colourSequence(worldId: string): ColorSequence
	local c = (PortalFixtures.Colours :: any)[worldId] or PortalFixtures.Colours.DustyHighway
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c.light),
		ColorSequenceKeypoint.new(0.5, c.mid),
		ColorSequenceKeypoint.new(1, c.deep),
	})
end

function PortalCardMock.new(ctx: Overlay.Ctx, options: Options?): Portal
	local opts: Options = options or {}
	local state: PortalFixtures.State = opts.state
		or PortalFixtures.preset("Dusty_Locked_BothUnmet") :: PortalFixtures.State
	if opts.locked ~= nil then
		state.open = not opts.locked
	end
	local ownGuard = opts.guard == nil
	local goGuard: SupportKit.Guard = opts.guard or SupportKit.guard()
	local view: "Main" | "Peek" = "Main"
	local selectedId = ""
	local goPresses = 0
	local startRequests = 0
	local lastRequest: GoRequest? = nil
	local geo = PortalCardMock.geometry(Vector2.new(750, 325))
	local portal: Portal
	local rows: { Row } = {}
	local chips: { Chip } = {}
	local peekCells = 0

	local overlay = Overlay.new(ctx, {
		name = "PortalCardMock",
		onDim = function()
			portal:close()
		end,
	})
	local trove = overlay.trove
	local content = overlay.content
	local pickerTrove = trove:Extend()

	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body

	-- header: World name + tag, the state pill, the X
	local header = Style.header(panel, {
		colours = colourSequence(state.worldId),
		title = state.worldName,
		icon = "Portal",
		height = 56,
	})
	local worldSub = Style.text(header.band, state.worldTag, "Label", { name = "World", z = header.title.ZIndex })
	local closeX = SupportKit.closeX(panel, function()
		portal:close()
	end)
	trove:Add(closeX.trove)
	local pill = SupportKit.pill(panel, { text = "LOCKED", icons = { "Padlock", "Lock" }, fill = "Gold", z = 12 })

	-- the scene (left on Regular and Roomy, first thing in the scrolling body on Compact)
	local scene = SupportKit.scene(panel, state.worldId, 4)
	local sceneBox = scene.root
	local dim: Frame = make("Frame", {
		Name = "LockDim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = sceneBox.ZIndex + 10,
		Parent = sceneBox,
	})
	local badge: Frame = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = A.Ink,
		ZIndex = sceneBox.ZIndex + 11,
		Parent = sceneBox,
	})
	Arcade.corner(badge, 52)
	Arcade.outline(badge, 3, Color3.new(1, 1, 1))
	local badgeIcon: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		ZIndex = badge.ZIndex + 1,
		Parent = badge,
	})
	trove:Add(function()
		scene:destroy()
	end)

	-- the body: one vertical scrolling column
	local body = Style.scroll(panel, "Body", 5)
	body.ScrollBarThickness = 6
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
	local titleLine = SupportKit.label(body, "Title", 22, 6)
	titleLine.LayoutOrder = 1
	titleLine.Size = UDim2.new(1, -8, 0, 30)
	local reqList: Frame = make("Frame", {
		Name = "Requirements",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		LayoutOrder = 2,
		ZIndex = 5,
		Parent = body,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = reqList,
	})
	local pickerBox: Frame = make("Frame", {
		Name = "StartIn",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 110),
		LayoutOrder = 3,
		ZIndex = 5,
		Parent = body,
	})
	local pickerScroll: ScrollingFrame = make("ScrollingFrame", {
		Name = "Picker",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Selectable = false,
		ZIndex = 5,
		Parent = pickerBox,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pickerScroll,
	})
	local caption = SupportKit.label(body, "PreviewValues", 16, 6)
	caption.Text = "Preview values. The real requirements come from the game."
	caption.TextColor3 = Style.TextSoft
	caption.LayoutOrder = 4
	caption.Size = UDim2.new(1, -8, 0, 40)
	caption:SetAttribute("PersistentPreview", true) -- fixture numbers must never read as real ones
	local peekBox: Frame = make("Frame", {
		Name = "Peek",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		LayoutOrder = 5,
		ZIndex = 5,
		Parent = body,
	})
	local grid: UIGridLayout = make("UIGridLayout", {
		CellSize = UDim2.fromOffset(112, 122),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = peekBox,
	})
	local peekNote = SupportKit.label(body, "PeekNote", 16, 6)
	peekNote.Text = "Cars you have not found yet show as ???"
	peekNote.TextColor3 = Style.TextSoft
	peekNote.LayoutOrder = 6
	peekNote.Size = UDim2.new(1, -8, 0, 24)

	-- the footer: the action is pinned inside the card
	local footer: Frame = make("Frame", {
		Name = "Footer",
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = panel,
	})
	local function footerButton(
		name: string,
		label: string,
		fill: Arcade.FillName,
		w: number,
		h: number,
		onActivate: () -> ()
	): Arcade.Button
		local b = Arcade.button(footer, {
			name = name,
			label = label,
			fill = fill,
			size = "Custom",
			width = w,
			height = h,
			pattern = name == "Go",
			cooldown = 0.6,
			onActivate = onActivate,
		})
		trove:Add(b.trove)
		b.root.AnchorPoint = Vector2.new(0.5, 0.5)
		b.root.Position = UDim2.fromScale(0.5, 0.5)
		b.root.ZIndex = 12
		return b
	end
	local pressGoNow: () -> boolean
	local goButton = footerButton("Go", "GO", "Retry", 210, 58, function()
		pressGoNow()
	end)
	local peekButton = footerButton("Peek", "Peek at cars", "Garage", 220, 52, function()
		portal:pressPeek()
	end)
	local backButton = footerButton("Back", "BACK", "Home", 150, 52, function()
		portal:showPeek(false)
	end)
	local waitButton = footerButton("Wait", "Checking...", "Garage", 220, 52, function() end)
	waitButton.setEnabled(false)

	-- LOGIC ----------------------------------------------------------------------------------

	local function choices(): { PortalFixtures.RosterCar }
		return PortalFixtures.startChoices(state)
	end

	local function selectedCar(): PortalFixtures.RosterCar?
		for _, c in choices() do
			if c.id == selectedId then
				return c
			end
		end
		return nil
	end

	local function ensureSelection()
		if selectedCar() == nil then
			local list = choices()
			selectedId = if list[1] then list[1].id else ""
		end
	end

	local function isReady(): boolean
		return state.status == "Ready"
	end
	local function isLocked(): boolean
		return isReady() and not state.open
	end
	local function isOpenForStart(): boolean
		return isReady() and state.open
	end

	local function reqText(req: PortalFixtures.Requirement): string
		if req.have == nil then
			return "Checking..."
		end
		local have = req.have :: number
		if have ~= have or have < 0 then
			return "Checking..."
		end
		if req.kind == "cash" then
			return string.format("%s / %s", Format.cash(have), Format.cash(req.need))
		end
		return string.format("%s / %s", Format.group(have), Format.group(req.need))
	end

	local function applyRow(row: Row)
		local req = row.req
		local fraction, valid = SupportKit.fraction(req.have, req.need, state.worldId .. ":" .. req.id)
		local text = if valid then reqText(req) else "Checking..."
		row.text = text
		row.set(fraction or 0, text)
		local met = req.have ~= nil and valid and (req.have :: number) >= req.need
		row.check.Visible = met
	end

	local function layoutRow(row: Row)
		row.frame.Size = UDim2.new(1, 0, 0, geo.rowH)
		if geo.stacked then
			row.icon.AnchorPoint = Vector2.new(0, 0)
			row.icon.Position = UDim2.fromOffset(8, 6)
			row.label.AnchorPoint = Vector2.new(0, 0)
			row.label.Position = UDim2.fromOffset(42, 4)
			row.label.Size = UDim2.new(1, -86, 0, 26)
			SupportKit.fitLabel(row.label, row.req.label, geo.innerW - 86, 26, 18)
			row.track.AnchorPoint = Vector2.new(0, 1)
			row.track.Position = UDim2.new(0, 10, 1, -7)
			row.track.Size = UDim2.new(1, -56, 0, 24)
		else
			row.icon.AnchorPoint = Vector2.new(0, 0.5)
			row.icon.Position = UDim2.new(0, 8, 0.5, 0)
			row.label.AnchorPoint = Vector2.new(0, 0.5)
			row.label.Position = UDim2.new(0, 42, 0.5, 0)
			local labelW = math.floor(geo.innerW * 0.34) - 42
			row.label.Size = UDim2.new(0, labelW, 1, -6)
			SupportKit.fitLabel(row.label, row.req.label, labelW, geo.rowH - 8, 18)
			row.track.AnchorPoint = Vector2.new(0, 0.5)
			row.track.Position = UDim2.fromScale(0.36, 0.5)
			row.track.Size = UDim2.new(0.64, -50, 0, 24)
		end
	end

	local function rebuildRows()
		for _, r in rows do
			r.frame:Destroy()
		end
		table.clear(rows)
		for i, req in state.requirements do
			local frame = Style.well(reqList, "Row_" .. req.id, 5)
			frame.LayoutOrder = i
			local icon: Frame = make("Frame", {
				Name = "Icon",
				Size = UDim2.fromOffset(28, 28),
				BackgroundTransparency = 1,
				ZIndex = 6,
				Parent = frame,
			})
			IconArt.draw(icon, { req.icon, "Star" })
			local label = SupportKit.label(frame, "Label", 18, 6)
			local track, set = Overlay.progress(frame, if req.kind == "cash" then "Green" else "Garage", 6)
			local check: Frame = make("Frame", {
				Name = "Met",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(28, 28),
				BackgroundTransparency = 1,
				Visible = false,
				ZIndex = 7,
				Parent = frame,
			})
			IconArt.draw(check, { "Check" })
			local row: Row = {
				frame = frame,
				req = req,
				label = label,
				track = track,
				set = set,
				check = check,
				icon = icon,
				text = "",
			}
			table.insert(rows, row)
			layoutRow(row)
			applyRow(row)
		end
	end

	local function refreshSelection()
		for _, chip in chips do
			local on = chip.id == selectedId
			chip.stroke.Color = if on then Color3.new(1, 1, 1) else A.Ink
			chip.stroke.Thickness = if on then 4 else A.OutlineMinor
			chip.tick.Visible = on
		end
	end

	local function buildChips()
		pickerTrove:Clean()
		for _, child in pickerScroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(chips)
		for i, c in choices() do
			local chip: TextButton = make("TextButton", {
				Name = "Chip_" .. c.id,
				LayoutOrder = i,
				Size = UDim2.fromOffset(geo.chipW, geo.chipH),
				BackgroundColor3 = Style.Well,
				BackgroundTransparency = Style.WellTransparency,
				AutoButtonColor = false,
				Text = "",
				Selectable = true,
				ZIndex = 6,
				Parent = pickerScroll,
			})
			Arcade.corner(chip, 8)
			local stroke = Arcade.outline(chip, "Minor")
			local holder: Frame = make("Frame", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 5),
				Size = UDim2.fromOffset(geo.iconSide, geo.iconSide),
				BackgroundTransparency = 1,
				ZIndex = 7,
				Parent = chip,
			})
			SupportKit.carIcon(holder, c)
			local name = SupportKit.label(chip, "Name", 16, 7)
			name.TextXAlignment = Enum.TextXAlignment.Center
			name.Position = UDim2.fromOffset(2, geo.iconSide + 8)
			name.Size = UDim2.fromOffset(geo.chipW - 4, 38)
			SupportKit.fitLabel(name, c.name, geo.chipW - 4, 38, 16)
			if c.loaner then
				local tag = SupportKit.label(chip, "Loaner", 16, 7)
				tag.Text = "LOANER"
				tag.TextXAlignment = Enum.TextXAlignment.Center
				tag.TextColor3 = PreviewTokens.Color.KeysLight
				tag.AnchorPoint = Vector2.new(0.5, 1)
				tag.Position = UDim2.new(0.5, 0, 1, -3)
				tag.Size = UDim2.fromOffset(geo.chipW - 4, 20)
			else
				local pips = SupportKit.pips(chip, c.rarity, 9)
				pips.AnchorPoint = Vector2.new(0.5, 1)
				pips.Position = UDim2.new(0.5, 0, 1, -6)
			end
			local tick: Frame = make("Frame", {
				Name = "Selected",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -3, 0, 3),
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = PreviewTokens.Color.Success,
				Visible = false,
				ZIndex = 9,
				Parent = chip,
			})
			Arcade.corner(tick, 24)
			Arcade.outline(tick, "Minor")
			local tickIcon: Frame = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				ZIndex = 10,
				Parent = tick,
			})
			IconArt.draw(tickIcon, { "Check" })
			table.insert(chips, { id = c.id, stroke = stroke, tick = tick })
			pickerTrove:Connect(chip.Activated, function()
				portal:selectCar(c.id)
			end)
		end
		refreshSelection()
		pickerBox.Size = UDim2.new(1, -8, 0, geo.chipH + 12)
	end

	local function buildPeek()
		for _, child in peekBox:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		peekCells = 0
		grid.CellSize = UDim2.fromOffset(geo.cellW, geo.cellH)
		for i, c in state.roster do
			local cell: Frame = Style.well(peekBox, "Cell_" .. c.id, 6)
			cell.LayoutOrder = i
			local holder: Frame = make("Frame", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 6),
				Size = UDim2.fromOffset(geo.iconSide, geo.iconSide),
				BackgroundTransparency = 1,
				ZIndex = 7,
				Parent = cell,
			})
			if c.owned then
				SupportKit.carIcon(holder, c)
			else
				SupportKit.carIcon(holder, { family = c.family, paint = nil })
				SupportKit.silhouette(holder)
			end
			local name = SupportKit.label(cell, "Name", 16, 7)
			name.TextXAlignment = Enum.TextXAlignment.Center
			name.Position = UDim2.fromOffset(2, geo.iconSide + 8)
			name.Size = UDim2.fromOffset(geo.cellW - 4, 38)
			SupportKit.fitLabel(name, if c.owned then c.name else "???", geo.cellW - 4, 38, 18)
			local info = (PreviewTokens.Rarity :: any)[c.rarity] or PreviewTokens.Rarity.Common
			local band: Frame = make("Frame", {
				Name = "Rarity",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -16),
				Size = UDim2.new(1, -10, 0, 22),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 7,
				Parent = cell,
			})
			Arcade.corner(band, 5)
			Arcade.outline(band, "Minor")
			make("UIGradient", { Color = ColorSequence.new(info.light, info.deep), Rotation = 90, Parent = band })
			local word = SupportKit.label(band, "Word", 16, 8)
			word.Text = info.label
			word.TextXAlignment = Enum.TextXAlignment.Center
			word.Size = UDim2.fromScale(1, 1)
			local pips = SupportKit.pips(cell, c.rarity, 8)
			pips.AnchorPoint = Vector2.new(0.5, 1)
			pips.Position = UDim2.new(0.5, 0, 1, -3)
			peekCells += 1
		end
	end

	-- apply the whole state to the visuals (cheap: at most a dozen small frames)
	local function refresh()
		ensureSelection()
		local ready = isReady()
		local locked = isLocked()
		local openNow = isOpenForStart()
		-- header
		header.title.Text = state.worldName
		worldSub.Text = state.worldTag
		local colours = colourSequence(state.worldId)
		for _, d in header.band:GetDescendants() do
			if d:IsA("UIGradient") and d.Parent and d.Parent.Name ~= "Gloss" then
				d.Color = colours
			end
		end
		if state.status == "Checking" then
			pill.set("CHECKING", { "Timer" }, "Garage")
		elseif state.status == "Error" then
			pill.set("NO DATA", { "Warning", "Close" }, "Missions")
		elseif state.open then
			pill.set("OPEN", { "Check" }, "Green")
		else
			pill.set("LOCKED", { "Padlock", "Lock" }, "Gold")
		end
		-- scene and its badge
		scene:setWorld(state.worldId)
		badgeIcon:ClearAllChildren()
		if openNow then
			dim.Visible = false
			IconArt.draw(badgeIcon, { "Portal", "Flag" })
		elseif locked then
			dim.Visible = true
			IconArt.draw(badgeIcon, { "Padlock", "Lock" })
		else
			dim.Visible = true
			IconArt.draw(badgeIcon, { "Timer" })
		end
		-- body
		local peek = view == "Peek"
		titleLine.Visible = true
		if peek then
			titleLine.Text = "Peek at cars"
		elseif not ready then
			titleLine.Text = if state.status == "Error" then "Could not check this portal." else "Checking..."
		elseif locked then
			titleLine.Text = "Keep collecting!"
		else
			titleLine.Text = "Choose your starting car"
		end
		SupportKit.fitLabel(titleLine, titleLine.Text, geo.innerW - 8, 30, 22)
		reqList.Visible = not peek and not openNow
		pickerBox.Visible = not peek and openNow
		peekBox.Visible = peek
		peekNote.Visible = peek
		-- footer
		goButton.root.Visible = not peek and openNow
		peekButton.root.Visible = not peek and locked
		backButton.root.Visible = peek
		waitButton.root.Visible = not peek and not ready
		waitButton.setLabel(if state.status == "Error" then "Can't check now" else "Checking...")
		goButton.setEnabled(not goGuard:hasFired())
	end

	local function rebuildAll()
		rebuildRows()
		buildChips()
		if view == "Peek" then
			buildPeek()
		end
		refresh()
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		geo = PortalCardMock.geometry(ds)
		shell.root.Size = UDim2.fromOffset(geo.pw, geo.ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		header.setHeight(geo.headH)
		local compact = geo.compact
		closeX.root.Position = UDim2.new(1, -8, 0, geo.headH / 2)
		pill.root.Position = UDim2.new(1, -8 - 48 - 8, 0, geo.headH / 2)
		local rightUsed = 8 + 48 + 8 + pill.width() + 10
		local left = header.title.Position.X.Offset
		header.title.AnchorPoint = Vector2.new(0, 0.5)
		header.title.Position = UDim2.new(0, left, 0.5, if compact then -8 else -10)
		header.title.Size = UDim2.new(1, -left - rightUsed, 0, if compact then 28 else 36)
		worldSub.AnchorPoint = Vector2.new(0, 0.5)
		worldSub.Position = UDim2.new(0, left + 2, 0.5, if compact then 14 else 19)
		worldSub.Size = UDim2.new(1, -left - rightUsed, 0, 22)
		-- scene
		if compact then
			sceneBox.Parent = body
			sceneBox.LayoutOrder = 0
			sceneBox.Size = UDim2.new(1, -8, 0, geo.scene.h)
			sceneBox.Position = UDim2.new()
			sceneBox.AnchorPoint = Vector2.zero
		else
			sceneBox.Parent = panel
			sceneBox.Position = UDim2.fromOffset(geo.scene.x, geo.scene.y)
			sceneBox.Size = UDim2.fromOffset(geo.scene.w, geo.scene.h)
			sceneBox.AnchorPoint = Vector2.zero
		end
		scene:layout(Vector2.new(geo.scene.w, geo.scene.h))
		badge.Size = UDim2.fromOffset(if compact then 40 else 56, if compact then 40 else 56)
		badgeIcon.Size = UDim2.fromOffset(if compact then 26 else 36, if compact then 26 else 36)
		-- body and footer
		body.Position = UDim2.fromOffset(geo.scroll.x, geo.scroll.y)
		body.Size = UDim2.fromOffset(geo.scroll.w, geo.scroll.h)
		footer.Position = UDim2.fromOffset(geo.foot.x, geo.foot.y)
		footer.Size = UDim2.fromOffset(geo.foot.w, geo.foot.h)
		rebuildAll()
	end

	-- ACTIONS --------------------------------------------------------------------------------

	pressGoNow = function(): boolean
		goPresses += 1
		if not isOpenForStart() or view ~= "Main" then
			return false
		end
		local car = selectedCar()
		if not car then
			return false
		end
		if not goGuard:tryFire() then
			return false -- one start request per activation
		end
		startRequests += 1
		goButton.setEnabled(false)
		local request: GoRequest = { worldId = state.worldId, carId = car.id, isLoaner = car.loaner == true }
		lastRequest = request
		if opts.onGo then
			opts.onGo(request)
		end
		portal:close()
		return true
	end

	overlay:setBack(function()
		if view == "Peek" then
			portal:showPeek(false)
		else
			portal:close()
		end
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
		end,
		open = function(_self: Portal, returnTo: GuiObject?)
			if overlay:isOpen() then
				return
			end
			view = "Main"
			if ownGuard then
				goGuard:reset()
			end
			layoutNow()
			local focus = if isOpenForStart() then goButton.body elseif isLocked() then peekButton.body else closeX.root
			overlay:open(focus, returnTo)
		end,
		close = function(_self: Portal)
			if not overlay:isOpen() then
				return
			end
			overlay:close()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Portal): boolean
			return overlay:isOpen()
		end,
		setState = function(_self: Portal, incoming: PortalFixtures.State)
			state = incoming
			view = "Main"
			selectedId = ""
			layoutNow()
		end,
		setPreset = function(self: Portal, name: string): boolean
			local incoming = PortalFixtures.preset(name)
			if not incoming then
				return false
			end
			self:setState(incoming)
			return true
		end,
		setLocked = function(self: Portal, on: boolean)
			state.status = "Ready"
			state.open = not on
			view = "Main"
			self:layout()
		end,
		setIndex = function(self: Portal, index: number)
			local list = choices()
			if #list == 0 then
				return
			end
			local i = ((index - 1) % #list) + 1
			self:selectCar(list[i].id)
		end,
		selectCar = function(_self: Portal, id: string): boolean
			for _, c in choices() do
				if c.id == id then
					selectedId = id
					refreshSelection()
					Sounds.play("Tap")
					return true
				end
			end
			return false
		end,
		showPeek = function(_self: Portal, on: boolean)
			local want: "Main" | "Peek" = if on then "Peek" else "Main"
			if want == view then
				return
			end
			if on and not isLocked() then
				return -- Peek belongs to the locked portal
			end
			view = want
			if on then
				buildPeek()
			end
			refresh()
			body.CanvasPosition = Vector2.zero
		end,
		pressGo = function(_self: Portal): boolean
			return pressGoNow()
		end,
		pressPeek = function(self: Portal)
			if isLocked() then
				self:showPeek(true)
			end
		end,
		destroy = function(_self: Portal)
			overlay:destroy()
		end,
		getDebugState = function(_self: Portal): DebugState
			local reqs = {}
			for _, r in rows do
				table.insert(reqs, r.req.label .. ": " .. r.text)
			end
			local index = 1
			for i, c in choices() do
				if c.id == selectedId then
					index = i
				end
			end
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				world = state.worldId,
				status = state.status,
				locked = isLocked(),
				view = view,
				index = index,
				carId = selectedId,
				goEnabled = isOpenForStart() and not goGuard:hasFired(),
				goCalls = startRequests,
				goPresses = goPresses,
				startRequests = startRequests,
				lastRequest = lastRequest,
				requirements = reqs,
				choices = #choices(),
				peekCells = peekCells,
				instances = #overlay.root:GetDescendants(),
				pill = if pill.root:FindFirstChild("Text")
					then (pill.root:FindFirstChild("Text") :: TextLabel).Text
					else "",
				title = titleLine.Text,
			}
		end,
		touchReport = function(_self: Portal): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	layoutNow()
	return portal
end

return PortalCardMock
