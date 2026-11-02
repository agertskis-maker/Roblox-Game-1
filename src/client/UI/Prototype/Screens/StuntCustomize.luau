--!strict
-- StuntCustomize: the "Your Car" customization screen for the Stunt Circuit (Lane 3, big round M17-05 and M17-05a; PREVIEW).
-- A turntable with a neutral Part-built PLACEHOLDER car, three tabs (Paint, Decals, Wheels), a grid of swatches, and a big
-- EQUIP button. Whatever you tap is applied to the turntable car at once.
--
--   local c = StuntCustomize.new(ctx, { ownership = Ownership?, equipped = Equipped?, onEquip = fn?, onClose = fn? })
--   c:open(returnTo?)  c:close()  c:isOpen()
--   c:selectTab("Paint" | "Decals" | "Wheels")  c:select(itemId) -> boolean  c:pressEquip() -> boolean
--   c:rotate(degrees)  c:setSpin(on)           -- the turntable (the arrows turn it 45 degrees; it also spins by itself)
--   c:setOwnership(o)  c:setEquipped(e)        -- fixtures: a different set of owned items, a different look worn
--   c:layout()  c:setVisible(on)  c:destroy()  c:getDebugState()  c:touchReport()
--   StuntCustomize.geometry(designSize) -> Geo
--
-- THE CONTENT (M17-05a): eight free paints, eight Cash-priced PREVIEW paints, the medal finishes (Bronze, Silver, Gold), and three
-- wheel styles; a Decals tab with a few. Every price is a PREVIEW fixture ("Preview prices. Buying is not live yet.") and a
-- PREVIEW chip stays in the header. There is no Robux anywhere: a locked medal finish says which medal unlocks it and offers no way
-- to buy it.
--
-- THE STATES are distinct, and none depends on colour alone:
--   equipped     a green tick badge on the swatch and the word ON; the button says EQUIPPED
--   selected     a thick white ring round the swatch (the one you tapped)
--   previewing   the ring AND an eye mark: the turntable shows it but it is not worn; the button says EQUIP
--   locked       a dim cover, a padlock and the medal's word (GOLD ...); the button says LOCKED
--   unavailable  a grey cover, a slash and the word SOON; it cannot be previewed; the button says UNAVAILABLE
--   priced       the PREVIEW price under the swatch; previewing is allowed, the button says NOT OWNED and nothing can be bought
--
-- EQUIP CHANGES ONLY THE LOCAL DISPLAY FIXTURE. The screen never writes ownership (the fixture is read-only and its checksum is in
-- getDebugState), never touches a car model of Brian L's (the turntable car is a placeholder it builds itself), and closing the
-- screen throws away every preview and shows what is worn. Reduced motion: the turntable does not spin by itself (the arrows still
-- turn it), and the screen opens with no slide.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local IconArt = require(Prototype.Home.IconArt)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local ProxyCar = require(Prototype.ProxyCar)
local Style = require(script.Parent.Style)
local StuntFixtures = require(Prototype.SupportFixtures.StuntFixtures)
local StuntKit = require(script.Parent.StuntKit)
local SupportKit = require(script.Parent.SupportKit)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local A = PreviewTokens.Arcade
local make = Arcade.make

local StuntCustomize = {}

StuntCustomize.SpinDegreesPerSecond = 36
StuntCustomize.StepDegrees = 45
StuntCustomize.Tabs = table.freeze({ "Paint", "Decals", "Wheels" } :: { StuntFixtures.TabId })

export type Options = {
	ownership: StuntFixtures.Ownership?,
	equipped: StuntFixtures.Equipped?,
	onEquip: ((tab: string, item: StuntFixtures.Item) -> ())?,
	onClose: (() -> ())?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	pw: number,
	ph: number,
	headH: number,
	left: Rect,
	right: Rect,
	tabs: Rect,
	grid: Rect,
	view: Rect,
	tile: Vector2,
	equip: Vector2,
}

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	tab: string,
	selected: { [string]: string },
	equipped: { [string]: string },
	previewing: { [string]: boolean },
	state: string, -- the selected item's state on the current tab
	stateWord: string,
	status: string,
	detail: string,
	equipLabel: string,
	equipEnabled: boolean,
	tiles: number,
	counts: { [string]: number }, -- per state, current tab
	groups: { [string]: number }, -- per group, current tab
	carPaint: { number }, -- the turntable car's body colour, 0-255
	carDecal: string,
	carWheels: string,
	spinning: boolean,
	yaw: number,
	ownershipChecksum: string,
	ownershipUntouched: boolean,
	equipCalls: number,
	caption: string,
	instances: number,
}

export type Customize = {
	root: Frame,
	layout: (self: Customize) -> (),
	setVisible: (self: Customize, on: boolean) -> (),
	open: (self: Customize, returnTo: GuiObject?) -> (),
	close: (self: Customize) -> (),
	isOpen: (self: Customize) -> boolean,
	selectTab: (self: Customize, tab: StuntFixtures.TabId) -> (),
	select: (self: Customize, itemId: string) -> boolean,
	pressEquip: (self: Customize) -> boolean,
	rotate: (self: Customize, degrees: number) -> (),
	setSpin: (self: Customize, on: boolean) -> (),
	setOwnership: (self: Customize, o: StuntFixtures.Ownership) -> (),
	setEquipped: (self: Customize, e: StuntFixtures.Equipped) -> (),
	destroy: (self: Customize) -> (),
	getDebugState: (self: Customize) -> DebugState,
	touchReport: (self: Customize) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY ---------------------------------------------------------------------------------------------------------------

function StuntCustomize.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local pw, ph, headH, leftW, tile, equip
	if fit == "Compact" then
		pw, ph, headH, leftW = math.min(ds.X - 12, 660), ds.Y - 8, 46, 190
		tile, equip = Vector2.new(56, 74), Vector2.new(170, 52)
	elseif fit == "Regular" then
		pw, ph, headH, leftW = math.min(ds.X - 24, 700), math.min(ds.Y - 16, 440), 54, 240
		tile, equip = Vector2.new(62, 80), Vector2.new(200, 56)
	else
		pw, ph, headH, leftW = math.min(ds.X - 32, 820), math.min(ds.Y - 24, 540), 60, 290
		tile, equip = Vector2.new(70, 90), Vector2.new(230, 60)
	end
	local pad = 14
	local top = headH + 8
	local bodyH = ph - top - 8
	local rightX = pad * 2 + leftW
	local rightW = pw - pad - rightX
	local tabsH = Tokens.Touch.Minimum
	-- left: the turntable takes what is left after the name, the detail lines and the button
	local viewH = bodyH - (24 + 40 + equip.Y + 12)
	return {
		fit = fit,
		pw = pw,
		ph = ph,
		headH = headH,
		left = { x = pad, y = top, w = leftW, h = bodyH },
		right = { x = rightX, y = top, w = rightW, h = bodyH },
		tabs = { x = rightX, y = top, w = rightW, h = tabsH },
		grid = { x = rightX, y = top + tabsH + 6, w = rightW, h = bodyH - tabsH - 6 },
		view = { x = pad, y = top, w = leftW, h = math.max(viewH, 80) },
		tile = tile,
		equip = equip,
	}
end

-- THE PLACEHOLDER CAR ----------------------------------------------------------------------------------------------------

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function disc(parent: Instance, name: string, diameter: number, thick: number, cf: CFrame, colour: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(thick, diameter, diameter)
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function slab(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Colours the placeholder body from one paint colour (body, a lighter roof, darker bumpers and skirt). A medal finish is metallic.
local function paintCar(car: Model, colour: Color3, metallic: boolean)
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Body" then
				d.Color = colour
				d.Material = if metallic then Enum.Material.Metal else Enum.Material.SmoothPlastic
				d.Reflectance = if metallic then 0.18 else 0
			elseif d.Name == "Roof" then
				d.Color = colour:Lerp(WHITE, 0.1)
				d.Material = if metallic then Enum.Material.Metal else Enum.Material.SmoothPlastic
			elseif d.Name == "Bumper" or d.Name == "Skirt" then
				d.Color = colour:Lerp(BLACK, 0.55)
			end
		end
	end
end

local function clearNamed(car: Model, prefix: string)
	for _, d in car:GetChildren() do
		if string.sub(d.Name, 1, #prefix) == prefix then
			d:Destroy()
		end
	end
end

-- A decal is a few flat parts lying on the hood and roof (never a texture: there is no asset id).
local function decalCar(car: Model, decalId: string, colour: Color3, body: Color3)
	clearNamed(car, "Decal")
	local bodyPart = car:FindFirstChild("Body") :: BasePart?
	local roofPart = car:FindFirstChild("Roof") :: BasePart?
	if not bodyPart or not roofPart or decalId == "none" then
		return
	end
	local topY = bodyPart.Position.Y + bodyPart.Size.Y / 2
	local roofTop = roofPart.Position.Y + roofPart.Size.Y / 2
	local frontZ = bodyPart.Position.Z - bodyPart.Size.Z / 2
	local hoodZ = frontZ + 1.8
	local thick = 0.06
	if decalId == "stripe" then
		for _, x in { -0.9, 0.9 } do
			slab(
				car,
				"DecalStripeBody",
				Vector3.new(0.8, thick, bodyPart.Size.Z),
				CFrame.new(x, topY + thick / 2, bodyPart.Position.Z),
				colour
			)
			slab(
				car,
				"DecalStripeRoof",
				Vector3.new(0.8, thick, roofPart.Size.Z),
				CFrame.new(x, roofTop + thick / 2, roofPart.Position.Z),
				colour
			)
		end
	elseif decalId == "checker" then
		slab(car, "DecalCheckerBase", Vector3.new(4.5, thick, 1.2), CFrame.new(0, topY + thick / 2, hoodZ), WHITE)
		for i = 0, 2 do
			slab(
				car,
				"DecalCheckerTile",
				Vector3.new(0.9, thick, 1.2),
				CFrame.new(-1.8 + i * 1.8, topY + thick * 1.5, hoodZ),
				Color3.fromRGB(30, 36, 56)
			)
		end
	elseif decalId == "dot" then
		local flat = CFrame.Angles(0, 0, math.pi / 2)
		disc(car, "DecalDot", 2.4, thick, CFrame.new(0, topY + thick / 2, hoodZ) * flat, WHITE)
		disc(car, "DecalDotInner", 1.5, thick, CFrame.new(0, topY + thick * 1.5, hoodZ) * flat, colour)
	elseif decalId == "bolt" then
		for i, spec in { { -0.5, -0.9, 28 }, { 0.5, 0, -28 }, { -0.5, 0.9, 28 } } do
			slab(
				car,
				"DecalBolt" .. i,
				Vector3.new(0.55, thick, 1.7),
				CFrame.new(spec[1], topY + thick / 2, hoodZ + spec[2]) * CFrame.Angles(0, math.rad(spec[3]), 0),
				colour
			)
		end
	elseif decalId == "laurel" then
		local flat = CFrame.Angles(0, 0, math.pi / 2)
		disc(car, "DecalLaurelOuter", 3, thick, CFrame.new(0, topY + thick / 2, hoodZ) * flat, colour)
		disc(car, "DecalLaurelInner", 2.1, thick, CFrame.new(0, topY + thick * 1.5, hoodZ) * flat, body)
		disc(car, "DecalLaurelCore", 1, thick, CFrame.new(0, topY + thick * 2.5, hoodZ) * flat, colour)
	end
end

-- Wheel styles lie on the outer face of each tyre: Street a plain hub, Sport a bright rim, Classic a cream wall.
local function wheelCar(car: Model, wheelId: string)
	clearNamed(car, "WheelTrim")
	for _, w in car:GetChildren() do
		if w:IsA("BasePart") and w.Name == "Wheel" then
			local side = if w.Position.X >= 0 then 1 else -1
			local d = w.Size.Y
			local function layer(n: number, name: string, scale: number, colour: Color3)
				local x = w.Position.X + side * (w.Size.X / 2 + 0.03 + (n - 1) * 0.06)
				disc(car, "WheelTrim" .. name, d * scale, 0.06, CFrame.new(x, w.Position.Y, w.Position.Z), colour)
			end
			if wheelId == "street" then
				layer(1, "Hub", 0.5, Color3.fromRGB(120, 126, 146))
			elseif wheelId == "sport" then
				layer(1, "Rim", 0.78, Color3.fromRGB(206, 212, 228))
				layer(2, "Well", 0.5, Color3.fromRGB(56, 62, 84))
				layer(3, "Hub", 0.24, Color3.fromRGB(226, 230, 240))
			else
				layer(1, "Wall", 0.9, Color3.fromRGB(250, 240, 214))
				layer(2, "Tyre", 0.64, Color3.fromRGB(40, 44, 60))
				layer(3, "Hub", 0.3, Color3.fromRGB(222, 228, 240))
			end
		end
	end
end

-- BUILD ------------------------------------------------------------------------------------------------------------------

type Tile = {
	item: StuntFixtures.Item,
	button: TextButton,
	ring: Frame,
	eye: Frame,
	check: Frame,
	cover: Frame,
	lock: Frame,
	slash: Frame,
	caption: TextLabel,
}

local function checksum(o: StuntFixtures.Ownership): string
	local parts: { string } = {}
	for _, section in { "owned", "medals", "unavailable" } do
		local ids: { string } = {}
		for id, on in (o :: any)[section] do
			table.insert(ids, id .. "=" .. tostring(on))
		end
		table.sort(ids)
		table.insert(parts, section .. ":" .. table.concat(ids, ","))
	end
	return table.concat(parts, ";")
end

local function copyOwnership(o: StuntFixtures.Ownership): StuntFixtures.Ownership
	return { owned = table.clone(o.owned), medals = table.clone(o.medals), unavailable = table.clone(o.unavailable) }
end

local SECTION_TITLES = { Free = "FREE", Cash = "CASH (PREVIEW PRICES)", Medal = "MEDAL FINISHES" }
local GROUP_ORDER = { "Free", "Cash", "Medal" }
local STATE_WORDS = {
	equipped = "EQUIPPED",
	owned = "OWNED",
	locked = "LOCKED",
	priced = "NOT OWNED",
	unavailable = "UNAVAILABLE",
}

function StuntCustomize.new(ctx: Overlay.Ctx, options: Options?): Customize
	local opts: Options = options or {}
	local ownership = copyOwnership(opts.ownership or StuntFixtures.ownership())
	local initialChecksum = checksum(ownership)
	local equipped: StuntFixtures.Equipped = table.clone(opts.equipped or StuntFixtures.equipped())
	local selected: { [string]: string } =
		{ Paint = equipped.Paint, Decals = equipped.Decals, Wheels = equipped.Wheels }
	local tab: StuntFixtures.TabId = "Paint"
	local geo = StuntCustomize.geometry(Vector2.new(750, 325))
	local tiles: { [string]: Tile } = {}
	local builtGridKey = ""
	local builtEquipKey = ""
	local yaw = 28
	local spin = true
	local equipCalls = 0
	local customize: Customize

	local overlay = Overlay.new(ctx, {
		name = "StuntCustomize",
		onDim = function()
			customize:close()
		end,
	})
	local trove = overlay.trove
	local gridTrove = trove:Extend()
	local equipTrove = trove:Extend()
	local content = overlay.content
	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header = Style.header(panel, { fill = "Garage", title = "YOUR CAR", icon = "Car", rightInset = 200 })
	local closeX = SupportKit.closeX(panel, function()
		customize:close()
	end)
	trove:Add(closeX.trove)
	local preview = StuntKit.previewChip(header.band, nil, 12)
	preview.frame.AnchorPoint = Vector2.new(1, 0.5)

	-- the turntable (a ViewportFrame with a part-built placeholder car on a round stage) ---------------------------------

	local viewBox = Style.well(panel, "Turntable", 5)
	viewBox.ClipsDescendants = true
	local viewport: ViewportFrame = make("ViewportFrame", {
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(172, 176, 192),
		LightColor = Color3.fromRGB(255, 246, 228),
		LightDirection = Vector3.new(-0.5, -1, -0.4),
		ZIndex = 6,
		Parent = viewBox,
	})
	local camera: Camera = make("Camera", { Name = "TurntableCamera", FieldOfView = 32, Parent = viewport })
	camera.CFrame = CFrame.lookAt(Vector3.new(15, 9, 26), Vector3.new(0, 2.2, 0))
	viewport.CurrentCamera = camera
	local stage = Instance.new("Model")
	stage.Name = "Stage"
	disc(
		stage,
		"Platform",
		24,
		0.6,
		CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(70, 84, 130)
	)
	stage.WorldPivot = CFrame.identity -- turn the stage about the middle of the platform, never about its bounding box
	for i = 0, 3 do
		-- four marks round the rim, so the turn can be seen
		local a = i * math.pi / 2
		slab(
			stage,
			"StageMark" .. i,
			Vector3.new(1.4, 0.06, 3.2),
			CFrame.new(math.sin(a) * 10, 0.03, math.cos(a) * 10) * CFrame.Angles(0, a, 0),
			Color3.fromRGB(247, 200, 58)
		)
	end
	local car =
		ProxyCar.build({ name = "Placeholder", family = "Sedan", paint = Color3.fromRGB(64, 150, 235), length = 12.5 })
	car.Parent = stage
	stage.Parent = viewport
	trove:Add(stage)
	local placeholderChip = Style.chip(viewBox, "PlaceholderChip", 9)
	local placeholderText = Overlay.text(placeholderChip, "PLACEHOLDER CAR", 16, nil, Enum.TextXAlignment.Center, 10)
	placeholderChip:SetAttribute("PersistentPreview", true)

	local function applyYaw()
		stage:PivotTo(CFrame.Angles(0, math.rad(yaw), 0))
	end
	local rotateLeft = Arcade.button(viewBox, {
		name = "TurnLeft",
		label = "<",
		fill = "Garage",
		size = "Custom",
		width = 48,
		height = 48,
		cooldown = 0.1,
		onActivate = function()
			customize:rotate(-StuntCustomize.StepDegrees)
		end,
	})
	trove:Add(rotateLeft.trove)
	rotateLeft.root.ZIndex = 12
	local rotateRight = Arcade.button(viewBox, {
		name = "TurnRight",
		label = ">",
		fill = "Garage",
		size = "Custom",
		width = 48,
		height = 48,
		cooldown = 0.1,
		onActivate = function()
			customize:rotate(StuntCustomize.StepDegrees)
		end,
	})
	trove:Add(rotateRight.trove)
	rotateRight.root.ZIndex = 12

	-- what is selected, in words ---------------------------------------------------------------------------------------------

	local nameLabel = SupportKit.label(panel, "ItemName", 22, 6)
	local detailLabel = SupportKit.label(panel, "Detail", 16, 6)
	detailLabel.TextYAlignment = Enum.TextYAlignment.Top
	detailLabel.TextColor3 = Style.TextSoft

	-- tabs and the swatch grid -----------------------------------------------------------------------------------------------

	local tabs: { [string]: Style.Tab } = {}
	for _, id in StuntCustomize.Tabs do
		local t = Style.tab(panel, {
			name = "Tab_" .. id,
			label = id,
			onActivate = function()
				customize:selectTab(id)
			end,
		})
		trove:Add(t.trove)
		tabs[id] = t
	end
	local gridBox = Style.well(panel, "GridBox", 5)
	local scroll = Style.scroll(gridBox, "Items", 6)
	scroll.ScrollBarThickness = 6
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})

	-- state helpers ----------------------------------------------------------------------------------------------------------

	local function itemById(tabId: string, id: string): StuntFixtures.Item?
		for _, item in StuntFixtures.itemsFor(tabId :: StuntFixtures.TabId) do
			if item.id == id then
				return item
			end
		end
		return nil
	end

	local function stateOf(item: StuntFixtures.Item): StuntFixtures.ItemState
		return StuntFixtures.stateOf(item, ownership, (equipped :: any)[item.tab])
	end

	-- the id the turntable shows for a tab: the selected one if it can be previewed, else what is worn
	local function effectiveId(tabId: string): string
		local item = itemById(tabId, selected[tabId])
		if item and stateOf(item) ~= "unavailable" then
			return item.id
		end
		return (equipped :: any)[tabId]
	end

	local function isPreviewing(tabId: string): boolean
		return effectiveId(tabId) ~= (equipped :: any)[tabId]
	end

	local function currentItem(): StuntFixtures.Item?
		return itemById(tab, selected[tab])
	end

	local function requirementText(item: StuntFixtures.Item): string
		local medal = item.medal
		if medal then
			local info = (StuntFixtures.Medals :: { [string]: StuntFixtures.MedalInfo })[medal]
			return "Earn a " .. string.lower(info.word) .. " medal to unlock it."
		end
		return "Locked."
	end

	-- the turntable car follows the three effective picks ---------------------------------------------------------------------

	local carPaintColour = Color3.fromRGB(64, 150, 235)
	local carDecalId = "none"
	local carWheelId = "street"
	local function applyCar()
		local paintItem = itemById("Paint", effectiveId("Paint"))
		local decalItem = itemById("Decals", effectiveId("Decals"))
		local wheelItem = itemById("Wheels", effectiveId("Wheels"))
		if paintItem then
			carPaintColour = paintItem.colour
			paintCar(car, paintItem.colour, paintItem.group == "Medal")
		end
		carDecalId = if decalItem then decalItem.id else "none"
		carWheelId = if wheelItem then wheelItem.id else "street"
		decalCar(car, carDecalId, if decalItem then decalItem.colour else WHITE, carPaintColour)
		wheelCar(car, carWheelId)
	end

	-- swatch art for the three kinds of tile ------------------------------------------------------------------------------------

	local function bit(
		parent: Instance,
		name: string,
		x: number,
		y: number,
		w: number,
		h: number,
		colour: Color3,
		rotation: number?,
		round: boolean?
	): Frame
		local f: Frame = make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Rotation = rotation or 0,
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = parent,
		})
		if round then
			Arcade.corner(f, 999)
		end
		return f
	end

	local function drawArt(swatch: Frame, item: StuntFixtures.Item)
		if item.tab == "Paint" then
			swatch.BackgroundColor3 = item.colour
			if item.group == "Medal" then
				-- a soft highlight reads as metal even in grey
				make("UIGradient", {
					Color = ColorSequence.new(WHITE, item.colour),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.2),
						NumberSequenceKeypoint.new(0.45, 0.85),
						NumberSequenceKeypoint.new(1, 0.6),
					}),
					Rotation = 60,
					Parent = swatch,
				})
			end
			return
		end
		swatch.BackgroundColor3 = Color3.fromRGB(46, 62, 120)
		local ink = Color3.fromRGB(20, 26, 48)
		if item.tab == "Wheels" then
			bit(swatch, "Tyre", 0.5, 0.5, 0.74, 0.74, ink, 0, true)
			bit(swatch, "Rim", 0.5, 0.5, 0.52, 0.52, item.colour, 0, true)
			bit(swatch, "Hub", 0.5, 0.5, 0.18, 0.18, ink, 0, true)
		elseif item.id == "none" then
			bit(swatch, "Ring", 0.5, 0.5, 0.56, 0.56, Color3.fromRGB(150, 160, 190), 0, true)
			bit(swatch, "Hole", 0.5, 0.5, 0.42, 0.42, Color3.fromRGB(46, 62, 120), 0, true)
			bit(swatch, "Slash", 0.5, 0.5, 0.08, 0.7, Color3.fromRGB(150, 160, 190), 40)
		elseif item.id == "stripe" then
			bit(swatch, "A", 0.36, 0.5, 0.16, 0.72, item.colour)
			bit(swatch, "B", 0.64, 0.5, 0.16, 0.72, item.colour)
		elseif item.id == "checker" then
			for r = 0, 1 do
				for c = 0, 2 do
					bit(
						swatch,
						"Cell",
						0.25 + c * 0.25,
						0.37 + r * 0.26,
						0.24,
						0.24,
						if (r + c) % 2 == 0 then WHITE else ink
					)
				end
			end
		elseif item.id == "dot" then
			bit(swatch, "Dot", 0.5, 0.5, 0.56, 0.56, WHITE, 0, true)
			bit(swatch, "Core", 0.5, 0.5, 0.34, 0.34, item.colour, 0, true)
		elseif item.id == "bolt" then
			bit(swatch, "A", 0.42, 0.3, 0.18, 0.4, item.colour, 24)
			bit(swatch, "B", 0.58, 0.5, 0.18, 0.4, item.colour, -24)
			bit(swatch, "C", 0.42, 0.7, 0.18, 0.4, item.colour, 24)
		else
			bit(swatch, "Ring", 0.5, 0.5, 0.62, 0.62, item.colour, 0, true)
			bit(swatch, "Hole", 0.5, 0.5, 0.42, 0.42, Color3.fromRGB(46, 62, 120), 0, true)
			bit(swatch, "Core", 0.5, 0.5, 0.18, 0.18, item.colour, 0, true)
		end
	end

	-- one swatch tile --------------------------------------------------------------------------------------------------------

	local function buildTile(parent: Instance, item: StuntFixtures.Item, order: number)
		local button: TextButton = make("TextButton", {
			Name = "Tile_" .. item.id,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Selectable = true,
			ZIndex = 8,
			Parent = parent,
		})
		button:SetAttribute("Item", item.id)
		local side = geo.tile.X
		local swatch: Frame = make("Frame", {
			Name = "Swatch",
			Size = UDim2.fromOffset(side, side),
			BackgroundColor3 = item.colour,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = button,
		})
		Arcade.corner(swatch, 8)
		Arcade.outline(swatch, "Button")
		drawArt(swatch, item)
		-- the selection ring sits just outside the swatch
		local ring: Frame = make("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(side / 2, side / 2),
			Size = UDim2.fromOffset(side + 8, side + 8),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 14,
			Parent = button,
		})
		Arcade.corner(ring, 11)
		Arcade.outline(ring, 3.5, WHITE)
		-- the cover for locked and unavailable
		local cover: Frame = make("Frame", {
			Name = "Cover",
			Size = UDim2.fromOffset(side, side),
			BackgroundColor3 = Color3.fromRGB(14, 20, 38),
			BackgroundTransparency = 0.38,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 10,
			Parent = button,
		})
		Arcade.corner(cover, 8)
		local lock: Frame = make("Frame", {
			Name = "Padlock",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(side / 2, side / 2),
			Size = UDim2.fromOffset(side * 0.56, side * 0.56),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 12,
			Parent = button,
		})
		IconArt.draw(lock, { "Padlock", "Lock" })
		local slash: Frame = make("Frame", {
			Name = "Slash",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(side / 2, side / 2),
			Size = UDim2.fromOffset(5, side * 1.1),
			Rotation = 40,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 12,
			Parent = button,
		})
		Arcade.outline(slash, 1.5)
		-- the tick for what is worn
		local check: Frame = make("Frame", {
			Name = "EquippedTick",
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(-5, -5),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Color3.fromRGB(46, 190, 90),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 16,
			Parent = button,
		})
		Arcade.corner(check, 13)
		Arcade.outline(check, 2.5)
		local tick: Frame = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			ZIndex = 17,
			Parent = check,
		})
		IconArt.draw(tick, { "Check" })
		-- the eye for "previewing"
		local eye: Frame = make("Frame", {
			Name = "PreviewEye",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(side + 4, -4),
			Size = UDim2.fromOffset(28, 18),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 16,
			Parent = button,
		})
		Arcade.corner(eye, 9)
		Arcade.outline(eye, 2)
		local pupil: Frame = make("Frame", {
			Name = "Pupil",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = A.Ink,
			BorderSizePixel = 0,
			ZIndex = 17,
			Parent = eye,
		})
		Arcade.corner(pupil, 5)
		local caption = Overlay.text(button, "", 16, nil, Enum.TextXAlignment.Center, 9)
		caption.Name = "Caption"
		caption.Position = UDim2.fromOffset(-4, side + 2)
		caption.Size = UDim2.fromOffset(side + 8, geo.tile.Y - side - 2)
		gridTrove:Connect(button.Activated, function()
			customize:select(item.id)
		end)
		tiles[item.id] = {
			item = item,
			button = button,
			ring = ring,
			eye = eye,
			check = check,
			cover = cover,
			lock = lock,
			slash = slash,
			caption = caption,
		}
	end

	-- refresh every visible tile from the current state (no rebuild) ---------------------------------------------------------

	local function captionFor(item: StuntFixtures.Item, state: StuntFixtures.ItemState): string
		if state == "equipped" then
			return "ON"
		elseif state == "locked" then
			local medal = item.medal
			if medal then
				return (StuntFixtures.Medals :: { [string]: StuntFixtures.MedalInfo })[medal].word
			end
			return "LOCKED"
		elseif state == "unavailable" then
			return "SOON"
		elseif state == "priced" then
			return Format.cash(item.price or 0)
		end
		return if item.group == "Free" then "FREE" else "OWNED"
	end

	local function refreshTiles()
		for id, t in tiles do
			local state = stateOf(t.item)
			local isSelected = selected[t.item.tab] == id
			t.ring.Visible = isSelected
			t.check.Visible = state == "equipped"
			t.eye.Visible = isSelected and state ~= "equipped" and state ~= "unavailable"
			t.cover.Visible = state == "locked" or state == "unavailable"
			t.cover.BackgroundTransparency = if state == "unavailable" then 0.2 else 0.38
			t.lock.Visible = state == "locked"
			t.slash.Visible = state == "unavailable"
			t.caption.Text = captionFor(t.item, state)
			t.button:SetAttribute("State", state)
			t.button:SetAttribute("Selected", isSelected)
			t.button:SetAttribute("Previewing", isSelected and state ~= "equipped" and state ~= "unavailable")
		end
	end

	-- the status text and the big button -------------------------------------------------------------------------------------

	local equipButton: Arcade.Button? = nil

	local function statusFor(item: StuntFixtures.Item, state: StuntFixtures.ItemState): (string, string)
		if state == "equipped" then
			return item.name, "On your car now."
		elseif state == "owned" then
			return item.name, "Previewing. Tap EQUIP to wear it."
		elseif state == "priced" then
			return item.name,
				string.format(
					"Previewing. %s is a PREVIEW price. Buying is not live yet.",
					Format.cash(item.price or 0)
				)
		elseif state == "locked" then
			return item.name, requirementText(item)
		end
		return item.name, "Not available right now."
	end

	local function refreshStatus()
		local item = currentItem()
		if not item then
			nameLabel.Text = ""
			detailLabel.Text = ""
			return
		end
		local state = stateOf(item)
		local name, detail = statusFor(item, state)
		nameLabel.Text = name
		detailLabel.Text = detail
		SupportKit.fitLabel(nameLabel, name, geo.left.w, 26, 22)
		SupportKit.fitLabel(detailLabel, detail, geo.left.w, 40, 16)
		local b = equipButton
		if b then
			b.setLabel(
				if state == "owned"
					then "EQUIP"
					elseif state == "equipped" then "EQUIPPED"
					elseif state == "locked" then "LOCKED"
					elseif state == "priced" then "NOT OWNED"
					else "UNAVAILABLE"
			)
			b.setEnabled(state == "owned")
		end
	end

	local function refreshAll()
		applyCar()
		refreshTiles()
		refreshStatus()
	end

	-- the grid for the current tab ---------------------------------------------------------------------------------------------

	local function buildGrid()
		gridTrove:Clean()
		tiles = {}
		local order = 0
		local items = StuntFixtures.itemsFor(tab)
		for _, group in GROUP_ORDER do
			local inGroup: { StuntFixtures.Item } = {}
			for _, item in items do
				if item.group == group then
					table.insert(inGroup, item)
				end
			end
			if #inGroup > 0 then
				order += 1
				local section: Frame = gridTrove:Add(make("Frame", {
					Name = "Section_" .. group,
					LayoutOrder = order,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, -8, 0, 0),
					ZIndex = 7,
					Parent = scroll,
				}))
				make("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
					Parent = section,
				})
				local title = SupportKit.label(section, "Title", 16, 8)
				title.LayoutOrder = 1
				title.Size = UDim2.new(1, 0, 0, 22)
				title.TextColor3 = if group == "Cash" then PreviewTokens.Color.KeysLight else Style.TextSoft
				title.Text = (SECTION_TITLES :: any)[group]
				if group == "Cash" then
					title:SetAttribute("PersistentPreview", true)
				end
				local grid: Frame = make("Frame", {
					Name = "Grid",
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.fromScale(1, 0),
					ZIndex = 7,
					Parent = section,
				})
				make("UIGridLayout", {
					CellSize = UDim2.fromOffset(geo.tile.X + 8, geo.tile.Y + 8),
					CellPadding = UDim2.fromOffset(6, 4),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Parent = grid,
				})
				for i, item in inGroup do
					-- each tile sits in a cell a little bigger than itself, so the ring and the badges are never clipped
					local cell: Frame = make("Frame", {
						Name = "Cell_" .. item.id,
						LayoutOrder = i,
						BackgroundTransparency = 1,
						ZIndex = 7,
						Parent = grid,
					})
					local holder: Frame = make("Frame", {
						Name = "Holder",
						Position = UDim2.fromOffset(4, 4),
						Size = UDim2.fromOffset(geo.tile.X, geo.tile.Y),
						BackgroundTransparency = 1,
						ZIndex = 7,
						Parent = cell,
					})
					buildTile(holder, item, i)
					local t = tiles[item.id]
					t.button.Size = UDim2.fromOffset(geo.tile.X, geo.tile.Y)
				end
			end
		end
		refreshTiles()
	end

	local function buildEquip()
		local key = string.format("%dx%d", geo.equip.X, geo.equip.Y)
		if key == builtEquipKey and equipButton then
			return
		end
		builtEquipKey = key
		equipTrove:Clean()
		local b = Arcade.button(panel, {
			name = "Equip",
			label = "EQUIP",
			fill = "Green",
			size = "Custom",
			width = geo.equip.X,
			height = geo.equip.Y,
			pattern = true,
			cooldown = 0.4,
			onActivate = function()
				customize:pressEquip()
			end,
		})
		equipTrove:Add(b.trove)
		b.root.ZIndex = 12
		equipButton = b
	end

	local function layoutNow()
		overlay:applyScale()
		geo = StuntCustomize.geometry(overlay:designSize())
		shell.root.Size = UDim2.fromOffset(geo.pw, geo.ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		header.setHeight(geo.headH)
		header.title.Size =
			UDim2.new(1, -header.title.Position.X.Offset - 200, 0, math.min(A.Text.Display + 8, geo.headH - 6))
		closeX.root.Position = UDim2.new(1, -8, 0, geo.headH / 2)
		preview.frame.Position = UDim2.new(1, -8 - Tokens.Touch.Minimum - 8, 0.5, 0)
		-- the turntable and the lines under it
		local v = geo.view
		viewBox.Position = UDim2.fromOffset(v.x, v.y)
		viewBox.Size = UDim2.fromOffset(v.w, v.h)
		placeholderChip.AnchorPoint = Vector2.new(0.5, 0)
		placeholderChip.Position = UDim2.new(0.5, 0, 0, 4)
		placeholderChip.Size = UDim2.fromOffset(math.min(v.w - 12, 160), 26)
		placeholderText.Size = UDim2.fromScale(1, 1)
		rotateLeft.root.AnchorPoint = Vector2.new(0, 1)
		rotateLeft.root.Position = UDim2.new(0, 4, 1, -2)
		rotateRight.root.AnchorPoint = Vector2.new(1, 1)
		rotateRight.root.Position = UDim2.new(1, -4, 1, -2)
		local lineY = v.y + v.h + 4
		nameLabel.Position = UDim2.fromOffset(v.x, lineY)
		nameLabel.Size = UDim2.fromOffset(v.w, 26)
		detailLabel.Position = UDim2.fromOffset(v.x, lineY + 26)
		detailLabel.Size = UDim2.fromOffset(v.w, 40)
		buildEquip()
		local b = equipButton
		if b then
			b.root.AnchorPoint = Vector2.new(0.5, 1)
			b.root.Position = UDim2.fromOffset(v.x + v.w / 2, geo.left.y + geo.left.h + 2)
		end
		-- the tabs and the grid
		local t = geo.tabs
		local tabW = math.floor((t.w - 12) / 3)
		for i, id in StuntCustomize.Tabs do
			local tb = tabs[id]
			tb.root.Position = UDim2.fromOffset(t.x + (i - 1) * (tabW + 6), t.y)
			tb.root.Size = UDim2.fromOffset(tabW, t.h)
		end
		local g = geo.grid
		gridBox.Position = UDim2.fromOffset(g.x, g.y)
		gridBox.Size = UDim2.fromOffset(g.w, g.h)
		scroll.Position = UDim2.fromOffset(6, 6)
		scroll.Size = UDim2.new(1, -12, 1, -12)
		-- tiles change size with the fit, so a new fit rebuilds the grid
		local key = string.format("%s|%s|%dx%d", tab, geo.fit, geo.tile.X, geo.tile.Y)
		if key ~= builtGridKey then
			builtGridKey = key
			buildGrid()
		end
		refreshAll()
	end

	-- the turntable's own clock: it spins slowly unless Reduce Motion is on --------------------------------------------------

	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not overlay:isOpen() or not spin or Motion.reduced() then
			return
		end
		yaw = (yaw + StuntCustomize.SpinDegreesPerSecond * dt) % 360
		applyYaw()
	end)

	overlay:setBack(function()
		customize:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	-- PUBLIC -----------------------------------------------------------------------------------------------------------

	customize = {
		root = overlay.root,
		layout = function(_self: Customize)
			layoutNow()
		end,
		setVisible = function(_self: Customize, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		open = function(_self: Customize, returnTo: GuiObject?)
			if overlay:isOpen() then
				return
			end
			-- every preview is thrown away: the screen always opens on what is worn
			selected = { Paint = equipped.Paint, Decals = equipped.Decals, Wheels = equipped.Wheels }
			tab = "Paint"
			for id, tb in tabs do
				tb.set(id == tab)
			end
			applyYaw()
			builtGridKey = ""
			layoutNow()
			local firstTile: GuiObject? = nil
			for _, t in tiles do
				firstTile = firstTile or t.button
			end
			overlay:open(firstTile, returnTo)
		end,
		close = function(_self: Customize)
			if not overlay:isOpen() then
				return
			end
			-- closing a preview changes nothing else: ownership and what is worn stay exactly as they were
			selected = { Paint = equipped.Paint, Decals = equipped.Decals, Wheels = equipped.Wheels }
			refreshAll()
			overlay:close()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Customize): boolean
			return overlay:isOpen()
		end,
		selectTab = function(_self: Customize, id: StuntFixtures.TabId)
			if tab == id then
				return
			end
			tab = id
			for tabId, tb in tabs do
				tb.set(tabId == id)
			end
			builtGridKey = ""
			layoutNow()
		end,
		select = function(_self: Customize, itemId: string): boolean
			local item = itemById(tab, itemId)
			if not item then
				return false
			end
			selected[tab] = itemId
			refreshAll()
			return true
		end,
		pressEquip = function(_self: Customize): boolean
			local item = currentItem()
			if not item or stateOf(item) ~= "owned" then
				return false -- worn already, locked, priced, unavailable: nothing to equip
			end
			local worn: any = equipped
			worn[tab] = item.id
			equipCalls += 1
			refreshAll()
			if opts.onEquip then
				opts.onEquip(tab, item)
			end
			return true
		end,
		rotate = function(_self: Customize, degrees: number)
			yaw = (yaw + degrees) % 360
			applyYaw()
		end,
		setSpin = function(_self: Customize, on: boolean)
			spin = on
		end,
		setOwnership = function(_self: Customize, o: StuntFixtures.Ownership)
			ownership = copyOwnership(o)
			initialChecksum = checksum(ownership)
			refreshAll()
		end,
		setEquipped = function(_self: Customize, e: StuntFixtures.Equipped)
			equipped = table.clone(e)
			selected = { Paint = equipped.Paint, Decals = equipped.Decals, Wheels = equipped.Wheels }
			refreshAll()
		end,
		destroy = function(_self: Customize)
			overlay:destroy()
		end,
		getDebugState = function(_self: Customize): DebugState
			local item = currentItem()
			local state = if item then stateOf(item) else "unavailable"
			local counts: { [string]: number } = {}
			local groups: { [string]: number } = {}
			for _, t in tiles do
				local s = stateOf(t.item)
				counts[s] = (counts[s] or 0) + 1
				groups[t.item.group] = (groups[t.item.group] or 0) + 1
			end
			local previewing: { [string]: boolean } = {}
			for _, id in StuntCustomize.Tabs do
				previewing[id] = isPreviewing(id)
			end
			local b = equipButton
			local bodyColour = { 0, 0, 0 }
			local body = car:FindFirstChild("Body")
			if body and body:IsA("BasePart") then
				bodyColour = {
					math.floor(body.Color.R * 255 + 0.5),
					math.floor(body.Color.G * 255 + 0.5),
					math.floor(body.Color.B * 255 + 0.5),
				}
			end
			local sum = checksum(ownership)
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				tab = tab,
				selected = table.clone(selected),
				equipped = table.clone(equipped :: any),
				previewing = previewing,
				state = state,
				stateWord = (STATE_WORDS :: any)[state] or state,
				status = nameLabel.Text,
				detail = detailLabel.Text,
				equipLabel = if b then b.label.Text else "",
				equipEnabled = state == "owned",
				tiles = (function(): number
					local n = 0
					for _ in tiles do
						n += 1
					end
					return n
				end)(),
				counts = counts,
				groups = groups,
				carPaint = bodyColour,
				carDecal = carDecalId,
				carWheels = carWheelId,
				spinning = spin and not Motion.reduced(),
				yaw = yaw,
				ownershipChecksum = sum,
				ownershipUntouched = sum == initialChecksum,
				equipCalls = equipCalls,
				caption = preview.label.Text,
				instances = #overlay.root:GetDescendants(),
			}
		end,
		touchReport = function(_self: Customize): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	for id, tb in tabs do
		tb.set(id == tab)
	end
	applyYaw()
	layoutNow()
	return customize
end

return StuntCustomize
