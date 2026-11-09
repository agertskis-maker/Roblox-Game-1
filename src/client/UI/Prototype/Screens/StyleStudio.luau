--!strict
-- StyleStudio: the one customization screen (Lane 3, Round 3 N4), used by the Garage's Customize screen, the Stunt customization
-- screen and the Launch Pad's stalls, so they cannot disagree. A turntable car on the left; PAINT, DECALS, WHEELS and TRAILS on the
-- right, each a grid of tiles; TRY, BUY and EQUIP under them. Round 8 (WS-3) rebuilt it to the reference (R8-IMG-13, 16, 18):
--
--   C-06  every Paint and Decal tile shows the player's SELECTED car in that item (Style/Shop/ShopGrid, TileCar), not a sports car
--   C-07  "EQUIPPED ON: <CAR>" above the buttons, an "Equipped!" toast with a sparkle, a green check on everything owned
--   W-04  WHEELS tiles are rim icons; tapping one fits the rims on the car and the camera eases to a close shot of the front
--         wheel for two seconds (Style/Shop/WheelCam), then back
--   T-09  TRAILS tiles are trail icons; the turntable becomes a TREADMILL ROAD (Style/Shop/Treadmill) with wind lines so the trail
--         streams as in a run; tapping the preview fires the hop burst (Style/Shop/ShopTrail)
--
--   local s = StyleStudio.new(ctx, host, { tab = "Paint", size = Vector2?, trove = T, onBuy = fn?, onGetCash = fn?, tabs = {...}? })
--   s:setTab(name)  s:select(id) -> boolean  s:pressAction()  s:tryOn()  s:getDebugState()  s:destroy()
--
-- Tapping a tile TRIES it on the car at once (only this screen's preview changes; switching tab or closing takes it off). An owned
-- item offers EQUIP. A Cash item offers BUY. In the beta, BUY and EQUIP only ASK the server (StyleState.buy and StyleState.equip;
-- the server prices, checks ownership and saves); BUY waits for the server's answer, then wears the item. A Robux item goes to
-- `onBuy` and shows its price only when the real price is known. A VIP item says it comes with the VIP pass. Where there is no
-- beta server (the UI playgrounds) BUY is the old PREVIEW purchase from the screen's PREVIEW Cash. The client never sends an
-- amount or a price.
--
-- The trail on the turntable is parts on the car's tail (ShopTrail over TrailPreview), because a ViewportFrame cannot show Trail,
-- Beam or particle objects; it turns with the car. The car's own trail in the world is a real Trail (CarLookApplier).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local RealCar = require(Prototype.RealCar)
local ShopGrid = require(Prototype.Style.Shop.ShopGrid)
local ShopLook = require(Prototype.Style.Shop.ShopLook)
local ShopTrail = require(Prototype.Style.Shop.ShopTrail)
local TrailFx = require(Prototype.Style.TrailFx) :: any
local Toast = require(Prototype.Style.Shop.Toast)
local Treadmill = require(Prototype.Style.Shop.Treadmill)
local WheelCam = require(Prototype.Style.Shop.WheelCam)
local StyleState = require(Prototype.StyleState)
local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = CarKit.make

local StyleStudio = {}

export type Options = {
	tab: string?,
	size: Vector2?,
	trove: any?,
	onBuy: ((id: string, title: string, art: string?) -> ())?,
	onGetCash: (() -> ())?,
	tabs: { string }?,
}

local TAB_ICON: { [string]: string } = { Paint = "paint", Decals = "decal", Wheels = "wheel", Trails = "trail" }
local TAB_ART: { [string]: string } = {
	Paint = "art_paint",
	Decals = "art_decal",
	Wheels = "art_wheel",
	Trails = "art_trail",
}

-- the reference's palette (GENERATION-NOTES): cream, navy, orange, green, gold
local CREAM = Color3.fromRGB(255, 244, 218)
local WELL = Color3.fromRGB(243, 226, 186)
local NAVY = Color3.fromRGB(20, 33, 63)
local ORANGE_TOP = Color3.fromRGB(255, 180, 75)
local ORANGE_BOTTOM = Color3.fromRGB(244, 119, 22)
local WHITE = Color3.new(1, 1, 1)

local TRAIL_LENGTH = 7.5 -- the ribbon on the treadmill, longer than on a still turntable
local TRAIL_YAW = math.rad(117) -- the car's nose to the lower left, its trail streaming to the upper right
local WHEEL_YAW = math.rad(117) -- the same: the car's left side and its front wheel face the screen
local FEEDBACK_SECONDS = 3
local IDLE_TRAIL_SPEED = 0.2 -- T-03: a standing car's trail is short and gentle; only the treadmill runs it at 1

local function normalTab(name: string?): string
	local key = string.lower(name or "paint")
	if key == "trails" or key == "trail" then
		return "Trails"
	elseif key == "decals" or key == "decal" then
		return "Decals"
	elseif key == "wheels" or key == "wheel" then
		return "Wheels"
	end
	return "Paint"
end

local function angleDifference(from: number, to: number): number
	return ((to - from + math.pi) % (math.pi * 2)) - math.pi
end

function StyleStudio.new(ctx: any, host: Frame, options: Options?): { [string]: any }
	local opts: Options = options or {}
	local self: { [string]: any } = {}
	local trove = (opts.trove or Trove.new()):Extend()
	local size = opts.size or host.AbsoluteSize / math.max(ctx.screen:uiScale(), 0.01)
	local phone = size.Y < 340
	local tabNames = opts.tabs or { "Paint", "Decals", "Wheels", "Trails" }
	local tab = normalTab(opts.tab)
	local previewed: { [string]: string } = {}
	local grid: any = nil
	local lastSignature = ""
	local pending: string? = nil -- the id BUY is waiting on
	local pendingEquip: { tab: string, id: string, at: number }? = nil
	local feedback: string? = nil
	local feedbackUntil = 0
	local yaw = math.rad(215)
	local yawGoal: number? = nil
	local dragging = false
	local dragX = 0
	local spinRestUntil = 0
	local lift = 0 -- the car's hop (the burst), in studs
	local leapAge = 1 -- seconds into the hop, 1 or more when none is running

	trove:Add(function()
		if grid then
			grid:destroy()
			grid = nil
		end
	end)

	local root = trove:Add(make("Frame", {
		Name = "StyleStudio",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 3,
	}, host)) :: Frame

	local leftW = math.floor(size.X * 0.45)
	local rightW = size.X - leftW - 10
	local stageH = size.Y - 6

	-- THE STAGE ---------------------------------------------------------------------------------------------------------
	local frame = make("Frame", {
		Name = "StageFrame",
		BackgroundColor3 = CREAM,
		Size = UDim2.fromOffset(leftW, stageH),
		ZIndex = 3,
	}, root) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 18) }, frame)
	make("UIStroke", { Thickness = 3, Color = NAVY, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	local stage = make("Frame", {
		Name = "Stage",
		BackgroundColor3 = WHITE,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(leftW - 12, stageH - 12),
		ZIndex = 4,
	}, frame) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, stage)
	-- sunny sky over a dark road, as in the reference
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(104, 184, 250)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(196, 230, 253)),
			ColorSequenceKeypoint.new(0.52, Color3.fromRGB(96, 104, 126)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 64, 86)),
		}),
	}, stage)
	local view = make("ViewportFrame", {
		Name = "Turntable",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(165, 165, 178),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, -0.5),
		ZIndex = 6,
		Active = true,
	}, stage) :: ViewportFrame
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, view)
	local stageAspect = (leftW - 12) / math.max(stageH - 12, 1)
	local camera = make("Camera", { FieldOfView = math.clamp(29 / stageAspect, 19, 36) }, view) :: Camera
	view.CurrentCamera = camera
	local world = make("WorldModel", {}, view) :: WorldModel
	local trailView = ShopTrail.new(world, TRAIL_LENGTH)
	trove:Add(function()
		trailView:destroy()
	end)
	local rig = RealCar.mount(world, { height = 8 }) -- a tall truck (the pizza sign) still fills the stage
	rig:setCar(ShopLook.baseCar(StyleState.car()))
	trove:Add(function()
		rig:destroy()
	end)
	local pivot = CFrame.new(0, 0.5, 0)

	-- the turntable under the car: a dark disc ringed with red and white kerbs, like the reference's track
	local turntable = make("Model", { Name = "Turntable" }, world) :: Model
	make("Part", {
		Name = "Disc",
		Anchored = true,
		CanCollide = false,
		CastShadow = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 16, 16),
		CFrame = CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(62, 70, 94),
		Material = Enum.Material.SmoothPlastic,
	}, turntable)
	for i = 0, 27 do
		local a = (i / 28) * math.pi * 2
		make("Part", {
			Name = "Kerb",
			Anchored = true,
			CanCollide = false,
			CastShadow = false,
			Size = Vector3.new(1.1, 0.56, 2.05),
			CFrame = CFrame.new(math.cos(a) * 8.45, 0.4, math.sin(a) * 8.45) * CFrame.Angles(0, -a, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(231, 72, 67) else Color3.fromRGB(255, 248, 238),
			Material = Enum.Material.SmoothPlastic,
		}, turntable)
	end
	local treadmill = Treadmill.new(world)
	trove:Add(function()
		treadmill:destroy()
	end)
	local wheelCam = WheelCam.new(camera)
	local baseCF = CFrame.identity
	local baseFov = camera.FieldOfView

	-- the camera backs off until the whole car fits, and on the Trails tab its trail and the belt too
	local function placeCamera()
		wheelCam:cancel()
		camera.FieldOfView = math.clamp(29 / stageAspect, 19, 36)
		local tanHalf = math.tan(math.rad(camera.FieldOfView) / 2)
		local focus = Vector3.new(0, 2.9, 0)
		local reach = 7.6
		if tab == "Trails" then
			local back = CFrame.Angles(0, TRAIL_YAW, 0).LookVector * -1
			focus = Vector3.new(0, 2.2, 0) + back * 3.6
			reach = 10.4
		end
		local distance = math.max(31, 5.4 / tanHalf, reach / (tanHalf * stageAspect))
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, distance * 0.24, distance), focus)
		baseCF = camera.CFrame
		baseFov = camera.FieldOfView
	end
	placeCamera()

	local function setYaw(a: number)
		yaw = a
		rig:pivotTo(pivot * CFrame.new(0, lift, 0) * CFrame.Angles(0, a, 0))
	end
	setYaw(yaw)

	trove:Connect(view.InputBegan, function(input: InputObject)
		if
			(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and tab ~= "Trails" -- the treadmill road is straight: the car stays on it
			and not wheelCam:active()
		then
			dragging = true
			dragX = input.Position.X
		end
	end)
	trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			yawGoal = nil
			setYaw(yaw + (input.Position.X - dragX) * 0.012)
			dragX = input.Position.X
			spinRestUntil = os.clock() + 2
		end
	end)
	trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	-- Round 7 (C-01): says when the car shows something not bought or not worn yet
	local tryLabel = CarKit.text(stage, "TRYING IT ON", if phone then 14 else 16, {
		align = Enum.TextXAlignment.Center,
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 8),
		size = UDim2.fromOffset(220, 24),
		color = CarKit.Yellow,
		stroke = 1.5,
		z = 9,
		name = "Trying",
	})
	tryLabel.Visible = false

	-- the name of what the car shows (and, on a big screen, its one line), on a cream plate at the foot of the stage
	local plateH = if phone then 30 else 58
	local plate = make("Frame", {
		Name = "Caption",
		BackgroundColor3 = CREAM,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -28, 0, plateH),
		ZIndex = 8,
	}, stage) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, plate)
	make("UIStroke", { Thickness = 2.5, Color = NAVY, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, plate)
	local plateName = CarKit.text(plate, "", if phone then 17 else 22, {
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, -16, 0, if phone then plateH else 30),
		position = UDim2.fromOffset(8, if phone then 0 else 2),
		color = NAVY,
		z = 9,
		name = "Name",
	})
	local plateNote = CarKit.text(plate, "", 14, {
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, -16, 0, 20),
		position = UDim2.fromOffset(8, 31),
		color = Color3.fromRGB(70, 82, 116),
		z = 9,
		name = "Note",
	})
	plateNote.Visible = not phone

	-- T-08: MATCH MY PAINT, shown on the Trails tab for a trail that can take its colour from the paint (TrailFx says which)
	local function supportsMatch(item: Catalog.Item?): boolean
		local check = TrailFx.supportsMatchPaint
		return item ~= nil and type(check) == "function" and check(item) == true
	end
	local matchButton = make("TextButton", {
		Name = "MatchPaint",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = CREAM,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(plateH + 18)),
		Size = UDim2.fromOffset(if phone then 176 else 220, if phone then 28 else 34),
		ZIndex = 9,
		Visible = false,
		Selectable = true,
	}, stage) :: TextButton
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, matchButton)
	make("UIStroke", { Thickness = 2.5, Color = NAVY, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, matchButton)
	local matchBox = make("Frame", {
		Name = "Box",
		BackgroundColor3 = WHITE,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		ZIndex = 10,
	}, matchButton) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, matchBox)
	make("UIStroke", { Thickness = 2, Color = NAVY, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, matchBox)
	local matchTick = make(
		"Frame",
		{ Name = "Tick", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 11 },
		matchBox
	) :: Frame
	for _, leg in { { 0.31, 0.6, 0.3, 45 }, { 0.58, 0.5, 0.55, -52 } } do
		local bar = make("Frame", {
			BackgroundColor3 = WHITE,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(leg[1], leg[2]),
			Size = UDim2.fromScale(leg[3], 0.14),
			Rotation = leg[4],
			ZIndex = 11,
		}, matchTick)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
	end
	CarKit.text(matchButton, "MATCH MY PAINT", if phone then 14 else 17, {
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(34, 0),
		size = UDim2.new(1, -42, 1, 0),
		color = NAVY,
		z = 10,
		name = "Words",
	})

	-- THE PICKER --------------------------------------------------------------------------------------------------------
	local right = make("Frame", {
		Name = "Picker",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(leftW + 10, 0),
		Size = UDim2.fromOffset(rightW, stageH),
		ZIndex = 3,
	}, root) :: Frame

	local tabH = if phone then 36 else 54
	local actionH = if phone then 42 else 62
	local lineH = if phone then 16 else 26
	local gapT = 6
	local tabW = (rightW - gapT * (#tabNames - 1)) / #tabNames
	local tabRefs: { [string]: any } = {}

	local function isShown(item: Catalog.Item): Catalog.ItemState
		local s = StyleState.get()
		return Catalog.stateOf(item, s.ownership, (s.equipped :: any)[item.tab])
	end

	local function wornItem(name: string): Catalog.Item?
		return StyleState.item(name)
	end

	local function shownItem(name: string): Catalog.Item?
		local id = previewed[name]
		return if id then Catalog.byId(name :: any, id) else wornItem(name)
	end

	local function cash(): number
		local live = Players.LocalPlayer and Players.LocalPlayer:GetAttribute(BetaConfig.CashAttribute)
		if StyleState.live() and type(live) == "number" then
			return live
		end
		return ctx.store:get().cash or 0
	end

	local function priceText(item: Catalog.Item): string
		if item.robux then
			-- Round 7: never a live-looking Robux price while the product is not on sale
			return "R$ ---"
		end
		return Format.cash(item.price)
	end

	-- THE TABS: cream pills, the open one orange, as in the reference
	for i, name in tabNames do
		local button = make("TextButton", {
			Name = "Tab_" .. name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = CREAM,
			Position = UDim2.fromOffset((i - 1) * (tabW + gapT), 0),
			Size = UDim2.fromOffset(tabW, tabH),
			ZIndex = 5,
			Selectable = true,
		}, right) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, 14) }, button)
		make("UIStroke", { Thickness = 2.5, Color = NAVY, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
		local fill =
			make("UIGradient", { Rotation = 90, Color = ColorSequence.new(CREAM, CREAM) }, button) :: UIGradient
		local slotPx = if phone then 28 else 40
		CarKit.slot(button, TAB_ICON[name], slotPx, { position = UDim2.new(0, slotPx / 2 + 6, 0.5, 0), z = 6 })
		local label = make("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			FontFace = CarKit.body(),
			Text = string.upper(name),
			TextColor3 = NAVY,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(slotPx + 12, 0),
			Size = UDim2.new(1, -slotPx - 16, 1, 0),
			ZIndex = 7,
		}, button) :: TextLabel
		make("UITextSizeConstraint", { MaxTextSize = if phone then 17 else 26, MinTextSize = 9 }, label)
		local function paintTab(on: boolean)
			fill.Color = if on then ColorSequence.new(ORANGE_TOP, ORANGE_BOTTOM) else ColorSequence.new(CREAM, CREAM)
			label.TextColor3 = if on then WHITE else NAVY
		end
		tabRefs[name] = { paint = paintTab }
		trove:Connect(button.Activated, function()
			self:setTab(name)
		end)
	end

	-- THE GRID
	local footerH = lineH + 8 + actionH + 4
	local well = make("Frame", {
		Name = "Well",
		BackgroundColor3 = WELL,
		Position = UDim2.fromOffset(0, tabH + 8),
		Size = UDim2.fromOffset(rightW, stageH - tabH - 8 - footerH),
		ZIndex = 4,
	}, right) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, well)
	make("UIStroke", { Thickness = 3, Color = NAVY, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, well)
	local gridHost = make("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -14, 1, -16),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = NAVY,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 5,
		Selectable = false,
	}, well) :: ScrollingFrame
	local gridLayout = make("UIGridLayout", {
		CellSize = UDim2.fromOffset(100, 100),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	}, gridHost) :: UIGridLayout

	-- THE FOOTER: "EQUIPPED ON: CAR", then TRY, BUY and EQUIP
	local line = CarKit.text(right, "", if phone then 14 else 20, {
		size = UDim2.fromOffset(rightW, lineH),
		position = UDim2.new(0, 0, 1, -actionH - 6 - lineH),
		align = Enum.TextXAlignment.Center,
		color = CarKit.White,
		stroke = 1.5,
		z = 5,
		name = "EquippedOn",
	})

	local function buttonRow(): (number, number, number)
		local gap = 8
		local free = rightW - gap * 2
		return math.floor(free * 0.24), math.floor(free * 0.46), math.floor(free * 0.30)
	end
	local tryW, buyW, equipW = buttonRow()
	local px = if phone then 24 else 34
	local function makeButton(
		name: string,
		text: string,
		tone: string,
		x: number,
		width: number,
		onPress: () -> ()
	): CarKit.Button
		return CarKit.button(right, {
			text = text,
			tone = tone,
			px = px,
			size = UDim2.fromOffset(width, actionH),
			position = UDim2.new(0, x, 1, -2),
			anchor = Vector2.new(0, 1),
			z = 6,
			name = name,
			onPress = onPress,
		})
	end

	local function refreshLine()
		local now = os.clock()
		if feedback and now < feedbackUntil then
			line.Text = feedback
			line.TextColor3 = CarKit.CashText
		else
			feedback = nil
			line.Text = "EQUIPPED ON: " .. ShopLook.carTitle(StyleState.car())
			line.TextColor3 = CarKit.White
		end
	end

	local function say(words: string)
		feedback = words
		feedbackUntil = os.clock() + FEEDBACK_SECONDS
		refreshLine()
		task.delay(FEEDBACK_SECONDS + 0.05, function()
			if root.Parent then
				refreshLine()
			end
		end)
	end

	-- the car on the stage ------------------------------------------------------------------------------------------------
	local function applyTrail(item: Catalog.Item?)
		local shown = item
		if item and StyleState.matchPaint() and supportsMatch(item) then
			local paint = shownItem("Paint")
			if paint and paint.id ~= "factory_paint" then
				shown = table.clone(item)
				shown.colours = paint.colours -- the trail takes the paint's colours
			end
		end
		trailView:set(shown)
	end

	local function applyToCar()
		rig:setCar(ShopLook.baseCar(StyleState.car()))
		rig:setPaint(shownItem("Paint"), 0.18)
		rig:setDecal(shownItem("Decals"))
		rig:setWheels(shownItem("Wheels"))
		rig:setTrailSpeed(if tab == "Trails" then 1 else IDLE_TRAIL_SPEED) -- a new car's handle starts at run speed
		applyTrail(if tab == "Trails" then shownItem("Trails") else nil)
	end

	local tryButton: CarKit.Button
	local buyButton: CarKit.Button
	local equipButton: CarKit.Button

	local function refreshAction()
		local item = shownItem(tab)
		refreshLine()
		matchButton.Visible = tab == "Trails" and supportsMatch(shownItem("Trails"))
		matchBox.BackgroundColor3 = if StyleState.matchPaint() then Color3.fromRGB(73, 200, 87) else WHITE
		matchTick.Visible = StyleState.matchPaint()
		if not item then
			return
		end
		local state = isShown(item)
		local name = item.name
		local trying = previewed[tab] ~= nil and state ~= "equipped"
		tryLabel.Visible = trying
		tryLabel.Text = "TRYING IT ON"
		plateName.Text = string.upper(name)
		plateNote.Text = string.match(item.note, "^[^.!]+[.!]") or item.note -- one short line
		tryButton.setText("TRY")
		-- BUY
		local buyEnabled = false
		if pending == item.id then
			buyButton.setText("BUYING...")
			buyButton.setTone("Grey")
		elseif state == "equipped" or state == "owned" then
			buyButton.setText("OWNED")
			buyButton.setTone("Grey")
		elseif state == "locked" and item.vip then
			buyButton.setText("VIP PASS")
			buyButton.setTone("Grey")
			plateNote.Text = name .. " comes with the VIP pass (in the Shop)."
		elseif state == "locked" then
			buyButton.setText("LOCKED")
			buyButton.setTone("Grey")
			plateNote.Text = "Win "
				.. string.upper(item.medal or "")
				.. " in the Stunt Circuit to unlock "
				.. name
				.. "."
		elseif state == "unavailable" then
			buyButton.setText("NOT HERE")
			buyButton.setTone("Grey")
		elseif item.robux then
			buyButton.setText("ROBUX: SOON")
			buyButton.setTone("Grey")
			buyEnabled = true
		else
			local short = item.price - cash()
			buyEnabled = true
			if short > 0 and StyleState.live() then
				buyButton.setText("NEED " .. Format.cash(short) .. " MORE")
				buyButton.setTone("Grey")
			else
				buyButton.setText("BUY " .. priceText(item))
				buyButton.setTone("Orange")
			end
		end
		buyButton.setEnabled(buyEnabled)
		-- EQUIP
		if state == "equipped" then
			equipButton.setText("EQUIPPED")
			equipButton.setTone("Grey")
			equipButton.setEnabled(false)
		elseif state == "owned" then
			equipButton.setText("EQUIP")
			equipButton.setTone("Navy")
			equipButton.setEnabled(true)
		else
			equipButton.setText("EQUIP")
			equipButton.setTone("Grey")
			equipButton.setEnabled(false)
		end
	end

	local function refreshCards()
		if grid then
			grid:refresh(previewed[tab])
		end
		refreshAction()
	end

	-- the tiles redraw only when something they wear changes (the car, or the paint, decal and wheels worn)
	local function checkTiles()
		local signature = ShopLook.signature(StyleState.car(), StyleState.get().equipped :: any, tab)
		if signature ~= lastSignature then
			lastSignature = signature
			if grid then
				grid:redrawCars()
			end
		end
	end

	-- W-04: the camera eases to the front wheel for two seconds, with the car turned to show it
	local function startWheelCam()
		if tab ~= "Wheels" or Motion.reduced() then
			return
		end
		local model: Model? = rig:model()
		if not model then
			return
		end
		local current = model:GetPivot()
		local target = pivot * CFrame.new(0, lift, 0) * CFrame.Angles(0, WHEEL_YAW, 0)
		local left = -target.RightVector
		local front = target.LookVector
		local found = WheelCam.frontWheel(model, -current.RightVector)
		if not found then
			return
		end
		-- where that wheel will be once the car has turned to WHEEL_YAW
		local wheel = target * current:PointToObjectSpace(found)
		yawGoal = WHEEL_YAW
		spinRestUntil = os.clock() + WheelCam.SECONDS + 0.4
		wheelCam:start(baseCF, baseFov, wheel, left, front)
	end

	-- T-09: tapping the preview fires the hop burst (the car leaps; its trail bursts out in its colours)
	local function fireBurst()
		if tab ~= "Trails" then
			return
		end
		local item = shownItem("Trails")
		if not item or item.isNone then
			return
		end
		leapAge = 0
		trailView:burst("leap", rig:tail(), Motion.reduced())
	end

	local function tryOn()
		if tab == "Wheels" then
			startWheelCam()
		elseif tab == "Trails" then
			fireBurst()
		else
			spinRestUntil = 0
		end
	end

	local function pick(id: string): boolean
		local item = Catalog.byId(tab :: any, id)
		if not item or isShown(item) == "unavailable" then
			return false
		end
		previewed[tab] = id
		applyToCar()
		checkTiles()
		refreshCards()
		tryOn() -- the tile tries itself on the big car at once: a wheel shot, a burst, or just the new look
		return true
	end

	local function buildGrid()
		if grid then
			grid:destroy()
			grid = nil
		end
		local columns = if tab == "Paint" or tab == "Decals"
			then (if phone then 3 elseif rightW < 560 then 3 else 4)
			else 3
		local padding = 8
		local cellW = math.floor((rightW - 22 - padding * (columns - 1)) / columns)
		local cellH = math.round(cellW * (if phone then 0.84 else 1.02))
		gridLayout.CellSize = UDim2.fromOffset(cellW, cellH)
		gridLayout.CellPadding = UDim2.fromOffset(padding, padding)
		grid = ShopGrid.new(gridHost, {
			tab = tab,
			phone = phone,
			columns = columns,
			cellW = cellW,
			cellH = cellH,
			padding = padding,
			z = 6,
			onPick = function(id: string)
				pick(id)
			end,
		})
		lastSignature = ShopLook.signature(StyleState.car(), StyleState.get().equipped :: any, tab)
		refreshCards()
	end

	local function showStageFor(name: string)
		local trails = name == "Trails"
		turntable.Parent = if trails then nil else world
		if trails then
			treadmill:setYaw(TRAIL_YAW)
			treadmill:show()
		else
			treadmill:hide()
		end
		trailView:setSpeed(if trails then 1 else IDLE_TRAIL_SPEED)
		rig:setTrailSpeed(if trails then 1 else IDLE_TRAIL_SPEED)
	end

	local function setTab(name: string)
		local wanted = normalTab(name)
		if wanted == tab then
			return
		end
		tab = wanted
		table.clear(previewed) -- Round 7 (C-07): a tab change takes off whatever was being tried
		leapAge = 1
		lift = 0
		showStageFor(tab)
		applyToCar()
		for key, refs in tabRefs do
			refs.paint(key == tab)
		end
		buildGrid()
		gridHost.CanvasPosition = Vector2.zero
		spinRestUntil = 0
		placeCamera()
		yawGoal = nil
		setYaw(if tab == "Trails" then TRAIL_YAW else yaw) -- side on: the tail and its trail both show
		applyTrail(if tab == "Trails" then shownItem("Trails") else nil)
		refreshCards()
	end

	local function equip()
		local item = shownItem(tab)
		if not item or pending then
			return
		end
		if isShown(item) == "owned" then
			pendingEquip = { tab = tab, id = item.id, at = os.clock() }
			StyleState.equip(tab, item.id)
		end
	end

	local function buy()
		local item = shownItem(tab)
		if not item or pending then
			return
		end
		if isShown(item) ~= "priced" then
			return
		end
		if item.robux then
			if opts.onBuy then
				opts.onBuy(item.id, item.name, TAB_ART[item.tab])
			end
		elseif StyleState.live() then
			if item.price > cash() then
				if opts.onGetCash then
					opts.onGetCash()
				end
				return
			end
			pending = item.id
			StyleState.buy(tab, item.id)
			task.delay(5, function()
				if pending == item.id then
					pending = nil
					say("No answer from the shop. Try again.")
					refreshAction()
				end
			end)
		else
			local have = ctx.store:get().cash or 0
			if have >= item.price then
				ctx.store:set("cash", have - item.price)
				StyleState.own(item.id)
				pendingEquip = { tab = tab, id = item.id, at = os.clock() }
				StyleState.equip(tab, item.id)
			else
				say(("You need $%s more Cash."):format(Format.group(item.price - have)))
				if opts.onGetCash then
					opts.onGetCash()
				end
				return
			end
		end
		applyToCar()
		refreshCards()
	end

	local function pressAction()
		local item = shownItem(tab)
		if not item or pending then
			return
		end
		local state = isShown(item)
		if state == "owned" then
			equip()
		elseif state == "priced" then
			buy()
		end
		applyToCar()
		refreshCards()
	end

	tryButton = makeButton("Try", "TRY", "Green", 0, tryW, function()
		if shownItem(tab) then
			tryOn()
		end
	end)
	buyButton = makeButton("Buy", "BUY", "Orange", tryW + 8, buyW, buy)
	equipButton = makeButton("Equip", "EQUIP", "Navy", tryW + buyW + 16, equipW, function()
		equip()
		applyToCar()
		refreshCards()
	end)

	for key, refs in tabRefs do
		refs.paint(key == normalTab(opts.tab))
	end

	-- the one loop: the turntable, the treadmill, the wheel shot, the tiles, and animated paint at about 12 updates a second
	local accumulate = 0
	local started = os.clock()
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not root.Visible then
			return
		end
		local reduced = Motion.reduced()
		-- the hop
		if leapAge < 1 then
			leapAge += dt / 0.75
			lift = if leapAge >= 1 then 0 else 2.2 * 4 * leapAge * (1 - leapAge)
			rig:pivotTo(pivot * CFrame.new(0, lift, 0) * CFrame.Angles(0, yaw, 0))
		end
		-- the car turns to the wheel shot's angle
		if yawGoal then
			local diff = angleDifference(yaw, yawGoal)
			if math.abs(diff) < 0.01 then
				setYaw(yawGoal)
				yawGoal = nil
			else
				setYaw(yaw + diff * math.min(1, dt * 9))
			end
		end
		wheelCam:step(dt)
		trailView:step(dt, rig:tail(), reduced)
		if tab == "Trails" then
			treadmill:step(dt, 1, reduced)
		end
		if grid then
			grid:step(dt, previewed[tab] or (StyleState.get().equipped :: any)[tab], reduced)
		end
		if reduced then
			return
		end
		if
			tab ~= "Trails"
			and not dragging
			and not yawGoal
			and not wheelCam:active()
			and os.clock() >= spinRestUntil
		then
			setYaw(yaw + dt * math.rad(14))
		end
		accumulate += dt
		if accumulate >= 1 / 12 then
			accumulate = 0
			local paint = shownItem("Paint")
			if paint and RealCar.isAnimated(paint) then
				rig:tick(((os.clock() - started) / (paint.cycleSeconds or 6)) % 1)
			end
		end
	end)
	-- tapping the turntable on the Trails tab fires the burst (a drag there does nothing: the road is straight)
	trove:Connect(view.InputBegan, function(input: InputObject)
		if
			tab == "Trails"
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			fireBurst()
		end
	end)

	trove:Connect(matchButton.Activated, function()
		StyleState.setMatchPaint(not StyleState.matchPaint())
	end)
	trove:Connect(StyleState.Changed, function()
		-- an equip the server accepted: the previewed item is now the worn one
		for key, id in previewed do
			if (StyleState.get().equipped :: any)[key] == id then
				previewed[key] = nil
			end
		end
		local celebrate = pendingEquip ~= nil
			and (StyleState.get().equipped :: any)[pendingEquip.tab] == pendingEquip.id
		if pendingEquip and (celebrate or os.clock() - pendingEquip.at > 5) then
			pendingEquip = nil
		end
		applyToCar()
		checkTiles()
		refreshCards()
		if celebrate then
			Toast.show(stage, "Equipped!", { z = 14, reduced = Motion.reduced() })
		end
	end)
	-- Round 7 (C-07): the server's answer to BUY. Bought: wear it at once. Refused: say why.
	local net = ReplicatedStorage:FindFirstChild(BetaConfig.NetName)
	local result = net and net:FindFirstChild(BetaConfig.Remotes.Result)
	if result and result:IsA("RemoteEvent") then
		trove:Connect(result.OnClientEvent, function(what: string, ok: boolean, reason: string?)
			if what ~= "BuyStyle" or not pending then
				return
			end
			local id = pending
			pending = nil
			local item = Catalog.byId(tab :: any, id)
			if ok and item then
				pendingEquip = { tab = item.tab, id = item.id, at = os.clock() }
				StyleState.equip(item.tab, item.id)
				say(item.name .. " is yours!")
			elseif reason then
				say(reason)
			end
			refreshCards()
		end)
	end
	local cashWatch = Players.LocalPlayer and Players.LocalPlayer:GetAttributeChangedSignal(BetaConfig.CashAttribute)
	if cashWatch then
		trove:Connect(cashWatch, refreshAction)
	end

	function self.setTab(_self: any, name: string)
		setTab(name)
	end

	function self.select(_self: any, id: string): boolean
		return pick(id)
	end

	function self.pressAction(_self: any)
		pressAction()
	end

	function self.tryOn(_self: any)
		tryOn()
	end

	function self.getDebugState(_self: any): { [string]: any }
		local state = StyleState.get()
		return {
			tab = tab,
			cards = if grid then grid:count() else 0,
			carTiles = if grid then grid:builtCars() else 0,
			previewed = previewed,
			equipped = state.equipped,
			car = StyleState.car(),
			rig = rig.source,
			line = line.Text,
			wheelCam = wheelCam:active(),
			treadmill = tab == "Trails",
		}
	end

	function self.destroy(_self: any)
		trove:Destroy()
	end

	tab = ""
	setTab(opts.tab or "Paint")
	applyToCar()
	refreshCards()
	return self
end

return StyleStudio
