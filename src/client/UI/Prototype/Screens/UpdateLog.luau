--!strict
-- UpdateLog: the compact "What's new" panel shown on join (Lane 3, Round 2 N11-02; PREVIEW). A navy title plate with an icon, a red
-- X, up to four short notes with original icons, an optional MORE DETAILS view (a scroll), and one GOT IT! that closes it.
--
--   local log = UpdateLog.show(parent, content, { force?, isTutorialActive?, onClose? }) -> Handle?
--       content = { version?, preview?, header?, entries = { { icon, title, text?, preview? } }, details = { string }? }
--       nil when this content version was already shown this session, when the tutorial is active, or when there is nothing to show
--   log:close()  log:isOpen()  log:toggleDetails()  log:pressClose()  log:getDebugState()  log:touchReport()
--   UpdateLog.versionOf(content) -> string      -- the content's version (explicit, or derived from its entries)
--   UpdateLog.hasSeen(content) -> boolean       -- shown already in this session?
--   UpdateLog.resetSession()                    -- forget what was shown (tests only)
--   UpdateLog.new(ctx, options) -> Controller   -- the playground mount: controller:request() (once per version), :open() (always)
--   UpdateLog.geometry(designSize, entryCount, hasDetails) -> Geo
--
-- ONCE PER VERSION, SESSION ONLY (N11-02a). The version comes from the content (or is derived from the note titles and texts), and
-- "already shown" is a table that lives as long as the client does. NOTHING is saved: a new Play shows the panel again, and
-- persistent suppression needs an approved storage field from Brian L, which this file does not add. The panel is never shown
-- while `isTutorialActive` says the tutorial's first steps are running (and is then NOT counted as seen), and it never reappears
-- just because Home mounted again. The notes come from the caller as data; a planned idea carries `preview = true` and a PREVIEW
-- tag instead of being mixed in with the shipped notes, and a whole sample list shows one PREVIEW stamp.
--
-- Touch: GOT IT! is 56 px tall, MORE DETAILS and the X are 48. Reduced motion: no slide or pop, a short fade only.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local CardKit = require(script.Parent.CardKit)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local UpdateFixtures = require(Prototype.SupportFixtures.UpdateFixtures)

local A = PreviewTokens.Arcade
local make = Arcade.make

local UpdateLog = {}

UpdateLog.MaxEntries = 4

local BORDER = 5
local GAP = 8
local PAD = 10

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Entry = UpdateFixtures.Entry
export type Content = UpdateFixtures.Content

export type ShowOptions = {
	force: boolean?, -- show even when this version was already shown (a manual "What's new" button)
	isTutorialActive: (() -> boolean)?,
	onClose: (() -> ())?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	cw: number,
	ch: number,
	stageH: number,
	plateH: number,
	overhang: number,
	bodyW: number,
	bodyH: number,
	area: Rect, -- the notes (or the details), in body px
	tile: Vector2,
	footY: number, -- the foot row's bottom edge, in body px
	close: Vector2,
	more: Vector2,
	textSize: number,
}

export type DebugState = {
	open: boolean,
	fit: string,
	version: string,
	entries: number,
	showingDetails: boolean,
	hasDetails: boolean,
	preview: boolean,
	closeCalls: number,
	reduced: boolean,
}

export type Handle = {
	root: Frame,
	close: (self: Handle) -> (),
	isOpen: (self: Handle) -> boolean,
	toggleDetails: (self: Handle) -> (),
	pressClose: (self: Handle) -> boolean,
	getDebugState: (self: Handle) -> DebugState,
	touchReport: (self: Handle) -> { { name: string, w: number, h: number } },
}

-- VERSION AND SESSION MEMORY ------------------------------------------------------------------------------------------------

-- A small order-sensitive checksum of every note's title and text: any change to the list is a new version.
function UpdateLog.versionOf(content: Content): string
	if content.version then
		return content.version
	end
	local sum = 0
	local index = 0
	for _, entry in content.entries do
		for _, part in { entry.title, entry.text or "", if entry.preview then "P" else "S" } do
			for i = 1, #part do
				index += 1
				sum = (sum + string.byte(part, i) * (index % 97 + 1)) % 1000000007
			end
		end
	end
	return string.format("v%d-%x", #content.entries, sum)
end

local seen: { [string]: boolean } = {}

function UpdateLog.hasSeen(content: Content): boolean
	return seen[UpdateLog.versionOf(content)] == true
end

function UpdateLog.resetSession()
	table.clear(seen)
end

-- GEOMETRY ------------------------------------------------------------------------------------------------------------------

function UpdateLog.geometry(ds: Vector2, entryCount: number, hasDetails: boolean): Geo
	local fit = SupportKit.fitFor(ds)
	local cw, plateH, tileH, textSize, closeButton
	if fit == "Compact" then
		cw, plateH, tileH, textSize = math.min(ds.X - 16, 520), 46, 60, 16
		closeButton = Vector2.new(190, 56)
	elseif fit == "Regular" then
		cw, plateH, tileH, textSize = math.min(ds.X - 32, 560), 52, 72, 18
		closeButton = Vector2.new(220, 60)
	else
		cw, plateH, tileH, textSize = math.min(ds.X - 48, 640), 58, 84, 20
		closeButton = Vector2.new(250, 66)
	end
	local overhang = plateH / 2
	local rows = math.max(1, math.ceil(math.min(entryCount, UpdateLog.MaxEntries) / 2))
	local areaH = rows * tileH + (rows - 1) * GAP
	local topPad = overhang - BORDER + 8
	local bodyW = cw - BORDER * 2
	local footH = closeButton.Y + 4
	local bodyH = topPad + areaH + GAP + footH + 10
	local ch = bodyH + BORDER * 2
	local tileW = math.floor((bodyW - PAD * 2 - GAP) / 2)
	return {
		fit = fit,
		cw = cw,
		ch = ch,
		stageH = overhang + ch,
		plateH = plateH,
		overhang = overhang,
		bodyW = bodyW,
		bodyH = bodyH,
		area = { x = PAD, y = topPad, w = bodyW - PAD * 2, h = areaH },
		tile = Vector2.new(tileW, tileH),
		footY = bodyH - 8,
		close = closeButton,
		more = Vector2.new(if hasDetails then 170 else 0, 48),
		textSize = textSize,
	}
end

-- BUILD ---------------------------------------------------------------------------------------------------------------------

local ACCENTS = { rgb(70, 190, 255), rgb(255, 160, 50), rgb(90, 210, 100), rgb(180, 120, 255) }

local function lastInputIsGamepad(): boolean
	return UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad"
end

function UpdateLog.show(parent: GuiBase2d, content: Content, opts: ShowOptions?): Handle?
	local o: ShowOptions = opts or {}
	if #content.entries == 0 then
		return nil -- nothing to say
	end
	local version = UpdateLog.versionOf(content)
	if not o.force and seen[version] then
		return nil -- once per content version, per session
	end
	if o.isTutorialActive and o.isTutorialActive() then
		return nil -- never over the tutorial's first steps; it is not counted as seen
	end
	seen[version] = true

	local trove = Trove.new()
	local closed = false
	local closeCalls = 0
	local showingDetails = false
	local guard = SupportKit.guard()
	local actionName = "Lane3UpdateLog_" .. HttpService:GenerateGUID(false)
	local priorSelection: GuiObject? = GuiService.SelectedObject
	local details = content.details
	local hasDetails = details ~= nil and #details > 0
	local entries: { Entry } = {}
	for i, entry in content.entries do
		if i > UpdateLog.MaxEntries then
			break
		end
		table.insert(entries, entry)
	end
	local geo = UpdateLog.geometry(Vector2.new(750, 325), #entries, hasDetails)
	local builtButtons = ""
	local handle: Handle

	local function parentSize(): Vector2
		return (parent :: any).AbsoluteSize
	end

	local root: Frame = trove:Add(make("Frame", {
		Name = "UpdateLog",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = parent,
	}))
	local hudScale: UIScale = make("UIScale", { Name = "HudScale", Parent = root })
	local dim: TextButton = make("TextButton", {
		Name = "Dim",
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = root,
	})
	local contentFrame: Frame = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = root,
	})
	local pop: UIScale = make("UIScale", { Name = "Pop", Parent = contentFrame })
	local stage: Frame = make("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 270),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = contentFrame,
	})
	local card = CardKit.card(stage, { name = "Card", z = 3, border = BORDER, radius = 16 })
	local body = card.body
	local plate = CardKit.titlePlate(stage, {
		text = content.header or "WHAT'S NEW",
		icon = "Info",
		iconFallback = { "Star" },
		size = 30,
		height = 52,
		rightInset = 62,
		z = 20,
	})
	local closeX = SupportKit.closeX(stage, function()
		handle:pressClose()
	end)
	trove:Add(closeX.trove)
	closeX.root.ZIndex = 24

	-- the notes: a grid of tiles (two columns; a lone last tile spans the row) -------------------------------------------------
	local notes: Frame = make("Frame", {
		Name = "Notes",
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = body,
	})
	local tiles: { Frame } = {}
	for i, entry in entries do
		local tile: Frame = make("Frame", {
			Name = "Note" .. i,
			BackgroundColor3 = CardKit.CreamShade,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = notes,
		})
		Arcade.corner(tile, 12)
		Arcade.outline(tile, "Minor")
		local chip: Frame = make("Frame", {
			Name = "IconChip",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = tile,
		})
		Arcade.corner(chip, 10)
		Arcade.outline(chip, "Button")
		local accent = ACCENTS[(i - 1) % #ACCENTS + 1]
		make("UIGradient", {
			Color = ColorSequence.new(accent:Lerp(Color3.new(1, 1, 1), 0.35), accent),
			Rotation = 90,
			Parent = chip,
		})
		local icon = CardKit.icon(chip, { entry.icon, "Info" }, 34, 9)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		CardKit.ink(tile, entry.title, 20, { name = "Title", xAlign = Enum.TextXAlignment.Left, z = 8 })
		if entry.text then
			local t = CardKit.ink(tile, entry.text, 16, {
				name = "Text",
				xAlign = Enum.TextXAlignment.Left,
				colour = CardKit.NavySoft,
				wrapped = true,
				z = 8,
			})
			t.TextYAlignment = Enum.TextYAlignment.Top
		end
		-- a planned idea is tagged, never mixed in with the shipped notes
		local tag: Frame? = nil
		if entry.preview then
			local stamp = Style.stamp(tile, "PREVIEW", "Gold", 12)
			stamp.frame.Rotation = 0
			stamp.frame.AnchorPoint = Vector2.new(1, 0)
			stamp.frame.Position = UDim2.new(1, -6, 0, -4)
			stamp.frame.Size = UDim2.fromOffset(0, 22)
			stamp.label.Size = UDim2.fromOffset(0, 22)
			stamp.frame:SetAttribute("PersistentPreview", true)
			tag = stamp.frame
		end
		tile:SetAttribute("Preview", entry.preview == true)
		tile:SetAttribute("TagVisible", tag ~= nil)
		table.insert(tiles, tile) -- placed in layoutNow (sizes depend on the fit)
	end

	-- the details view: a scroll of paragraphs, drawn over the notes' area --------------------------------------------------------
	local scroll: ScrollingFrame = make("ScrollingFrame", {
		Name = "Details",
		BackgroundColor3 = CardKit.CreamShade,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = CardKit.Navy,
		ClipsDescendants = true,
		Visible = false,
		Selectable = false,
		ZIndex = 8,
		Parent = body,
	})
	Arcade.corner(scroll, 12)
	Arcade.outline(scroll, "Minor")
	make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = scroll,
	})
	for i, paragraph in details or {} do
		local p = CardKit.ink(
			scroll,
			paragraph,
			18,
			{ name = "P" .. i, xAlign = Enum.TextXAlignment.Left, wrapped = true, z = 9 }
		)
		p.LayoutOrder = i
		p.AutomaticSize = Enum.AutomaticSize.Y
		p.Size = UDim2.fromScale(1, 0)
		p.TextYAlignment = Enum.TextYAlignment.Top
	end

	local sampleStamp: Style.Stamp? = nil
	if content.preview then
		local s = Style.stamp(stage, "PREVIEW", "Gold", 26)
		s.frame.Name = "PreviewStamp"
		s.frame:SetAttribute("PersistentPreview", true)
		sampleStamp = s
	end

	-- the foot row: MORE DETAILS on the left, GOT IT! on the right ---------------------------------------------------------------
	local closeButton: Arcade.Button? = nil
	local moreButton: Arcade.Button? = nil
	local buttonsTrove = trove:Extend()
	local function buildButtons()
		local key = string.format("%dx%d/%d", geo.close.X, geo.close.Y, geo.more.X)
		if key == builtButtons and closeButton then
			return
		end
		builtButtons = key
		buttonsTrove:Clean()
		local c = Arcade.button(body, {
			name = "GotIt",
			label = "GOT IT!",
			fill = "Green",
			size = "Custom",
			width = geo.close.X,
			height = geo.close.Y,
			pattern = true,
			cooldown = 0.4,
			sound = "Close",
			onActivate = function()
				handle:pressClose()
			end,
		})
		buttonsTrove:Add(c.trove)
		c.root.ZIndex = 12
		closeButton = c
		moreButton = nil
		if hasDetails then
			local m = Arcade.button(body, {
				name = "More",
				label = "MORE DETAILS",
				fill = "Garage",
				size = "Custom",
				width = geo.more.X,
				height = geo.more.Y,
				cooldown = 0.3,
				onActivate = function()
					handle:toggleDetails()
				end,
			})
			buttonsTrove:Add(m.trove)
			m.root.ZIndex = 12
			moreButton = m
		end
	end

	local function renderMode()
		notes.Visible = not showingDetails
		scroll.Visible = showingDetails
		local m = moreButton
		if m then
			m.setLabel(if showingDetails then "BACK TO NEWS" else "MORE DETAILS")
		end
	end

	local function layoutNow()
		local s = Tokens.uiScaleFor(parentSize())
		hudScale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		geo = UpdateLog.geometry(parentSize() / s, #entries, hasDetails)
		stage.Size = UDim2.fromOffset(geo.cw, geo.stageH)
		card.root.AnchorPoint = Vector2.zero
		card.root.Position = UDim2.fromOffset(0, geo.overhang)
		card.root.Size = UDim2.fromOffset(geo.cw, geo.ch)
		plate:fit(geo.cw - 56 - 16)
		plate.root.Position = UDim2.fromOffset((geo.cw - 56) / 2 + 4, geo.overhang)
		closeX.root.AnchorPoint = Vector2.new(1, 0.5)
		closeX.root.Position = UDim2.fromOffset(geo.cw + 2, geo.overhang + 4)
		local a = geo.area
		notes.Position = UDim2.fromOffset(a.x, a.y)
		notes.Size = UDim2.fromOffset(a.w, a.h)
		scroll.Position = UDim2.fromOffset(a.x, a.y)
		scroll.Size = UDim2.fromOffset(a.w, a.h)
		for i, tile in tiles do
			local col = (i - 1) % 2
			local row = (i - 1) // 2
			local lone = i == #tiles and #tiles % 2 == 1
			local w = if lone then a.w else geo.tile.X
			tile.Position = UDim2.fromOffset(if lone then 0 else col * (geo.tile.X + GAP), row * (geo.tile.Y + GAP))
			tile.Size = UDim2.fromOffset(w, geo.tile.Y)
			local title = tile:FindFirstChild("Title") :: TextLabel?
			local text = tile:FindFirstChild("Text") :: TextLabel?
			local left = 8 + 44 + 10
			if title then
				title.Position = UDim2.fromOffset(left, 6)
				title.Size = UDim2.fromOffset(w - left - 8, 26)
			end
			if text then
				text.Position = UDim2.fromOffset(left, 32)
				local textH = geo.tile.Y - 36
				text.Size = UDim2.fromOffset(w - left - 8, textH)
				SupportKit.fitLabel(text, text.Text, w - left - 8, textH, geo.textSize)
				text.TextColor3 = CardKit.NavySoft
				text.TextYAlignment = Enum.TextYAlignment.Top
			elseif title then
				title.Size = UDim2.fromOffset(w - left - 8, geo.tile.Y - 12)
			end
		end
		buildButtons()
		local c = closeButton
		if c then
			c.root.AnchorPoint = Vector2.new(1, 1)
			c.root.Position = UDim2.fromOffset(geo.bodyW - PAD, geo.footY)
		end
		local m = moreButton
		if m then
			m.root.AnchorPoint = Vector2.new(0, 1)
			m.root.Position = UDim2.fromOffset(PAD, geo.footY)
		end
		local stamp = sampleStamp
		if stamp then
			stamp.frame.AnchorPoint = Vector2.new(0, 0)
			stamp.frame.Position = UDim2.fromOffset(8, geo.overhang + geo.plateH / 2 + 6)
		end
		renderMode()
	end

	-- CLOSING -------------------------------------------------------------------------------------------------------------------

	local function unbind()
		ContextActionService:UnbindAction(actionName)
	end
	trove:Add(unbind)

	local function doClose()
		if closed then
			return
		end
		closed = true
		closeCalls += 1
		unbind()
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(root) then
			local prior = priorSelection
			if prior and prior:IsDescendantOf(game) and prior.Visible then
				GuiService.SelectedObject = prior
			else
				GuiService.SelectedObject = nil
			end
		end
		if Motion.reduced() then
			trove:Destroy()
		else
			Motion.tween(dim, "dim", Motion.info(0.14), { BackgroundTransparency = 1 })
			Motion.tween(pop, "pop", Motion.info(0.14), { Scale = 0.94 })
			task.delay(0.15, function()
				trove:Destroy()
			end)
		end
		if o.onClose then
			o.onClose()
		end
	end

	trove:Connect(dim.Activated, function()
		doClose()
	end)
	trove:Connect(parent:GetPropertyChangedSignal("AbsoluteSize"), function()
		if not closed then
			layoutNow()
		end
	end)

	layoutNow()
	Sounds.play("Open")
	ContextActionService:BindActionAtPriority(
		actionName,
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin and not closed then
				if showingDetails then
					handle:toggleDetails()
				else
					doClose()
				end
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)
	if Motion.reduced() then
		dim.BackgroundTransparency = 0.45
		pop.Scale = 1
	else
		dim.BackgroundTransparency = 1
		pop.Scale = 0.94
		Motion.tween(dim, "dim", Motion.info(0.2), { BackgroundTransparency = 0.45 })
		Motion.tween(pop, "pop", Motion.info(0.22, Enum.EasingStyle.Back), { Scale = 1 })
	end
	local focus = closeButton
	if focus and lastInputIsGamepad() then
		GuiService.SelectedObject = focus.body
	end
	trove:Add(function()
		Motion.cancelAll(dim)
		Motion.cancelAll(pop)
	end)

	handle = {
		root = root,
		close = function(_self: Handle)
			doClose()
		end,
		isOpen = function(_self: Handle): boolean
			return not closed
		end,
		toggleDetails = function(_self: Handle)
			if closed or not hasDetails then
				return
			end
			showingDetails = not showingDetails
			renderMode()
		end,
		pressClose = function(_self: Handle): boolean
			if closed or not guard:tryFire() then
				return false
			end
			doClose()
			return true
		end,
		getDebugState = function(_self: Handle): DebugState
			return {
				open = not closed,
				fit = geo.fit,
				version = version,
				entries = #entries,
				showingDetails = showingDetails,
				hasDetails = hasDetails,
				preview = content.preview == true,
				closeCalls = closeCalls,
				reduced = Motion.reduced(),
			}
		end,
		touchReport = function(_self: Handle): { { name: string, w: number, h: number } }
			return SupportKit.touchReport(root, hudScale.Scale)
		end,
	}
	return handle
end

-- THE PLAYGROUND MOUNT ------------------------------------------------------------------------------------------------------------

export type Controller = {
	root: Frame?,
	request: (self: Controller) -> boolean,
	open: (self: Controller, returnTo: GuiObject?) -> (),
	close: (self: Controller) -> (),
	isOpen: (self: Controller) -> boolean,
	setContent: (self: Controller, name: string) -> boolean,
	getHandle: (self: Controller) -> Handle?,
	layout: (self: Controller) -> (),
	setVisible: (self: Controller, on: boolean) -> (),
	destroy: (self: Controller) -> (),
	getDebugState: (self: Controller) -> DebugState?,
}

-- The component the playground mounts: `request()` is the join-time entry (once per content version per session, and never over
-- an active tutorial when options.isTutorialActive says so); `open()` always shows (a manual button). Content names: "sample", "next".
function UpdateLog.new(ctx: Overlay.Ctx, options: { isTutorialActive: (() -> boolean)?, content: string? }?): Controller
	local opts = options or {}
	local contentName = opts.content or "sample"
	local current: Handle? = nil
	local destroyed = false
	local function contentNow(): Content
		if contentName == "next" then
			return UpdateFixtures.next()
		end
		return UpdateFixtures.sample()
	end
	local function present(force: boolean): boolean
		if destroyed or (current and current:isOpen()) then
			return false
		end
		local handle =
			UpdateLog.show(ctx.layer, contentNow(), { force = force, isTutorialActive = opts.isTutorialActive })
		current = handle
		return handle ~= nil
	end
	local controller: Controller
	controller = {
		root = nil,
		request = function(_self: Controller): boolean
			return present(false)
		end,
		open = function(_self: Controller, _returnTo: GuiObject?)
			present(true)
			local handle = current
			controller.root = if handle then handle.root else nil
		end,
		close = function(_self: Controller)
			if current then
				current:close()
			end
		end,
		isOpen = function(_self: Controller): boolean
			return current ~= nil and current:isOpen()
		end,
		setContent = function(_self: Controller, name: string): boolean
			if name ~= "sample" and name ~= "next" then
				return false
			end
			contentName = name
			return true
		end,
		getHandle = function(_self: Controller): Handle?
			return current
		end,
		layout = function(_self: Controller) end,
		setVisible = function(_self: Controller, on: boolean)
			local handle = current
			if handle and handle:isOpen() then
				handle.root.Visible = on
			end
		end,
		destroy = function(_self: Controller)
			destroyed = true
			if current then
				current:close()
			end
		end,
		getDebugState = function(_self: Controller): DebugState?
			return if current then current:getDebugState() else nil
		end,
	}
	return controller
end

return UpdateLog
