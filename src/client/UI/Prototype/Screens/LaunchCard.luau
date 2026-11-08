--!strict
-- LaunchCard: the card that opens when you step on a Launch Pad's ramp (Lane 3, Round 3 N6-03). The World's name, your car on a
-- turntable, your trail behind it, what it wears, two small change buttons and a giant START!. It starts nothing itself: it calls
-- onStart.
-- Round 7 (A-07): no "hops this run" line (Adam: the card should not say how many hops you have), the car centred in its
-- frame, and a red X top right (48 px) that closes it, as walking off the ramp does.
-- Round 8 (C-03, R8-IMG-25; Adam: "it doesn't give me some kind of confirmation for the car that I chose"): the car's name and rarity,
-- and four rows that list what it wears (PAINT, DECAL, WHEELS, TRAIL). When a car is picked (CHANGE CAR here, or RIDE THIS CAR in the
-- Garage) the turntable swaps with a sparkle burst and a short whoosh, a green check stamps onto the card, a toast says
-- "READY TO RIDE: <CAR>", and the CHANGE CAR button shows a small portrait of the car. Reduce Motion: the check and the toast just
-- appear and the card's edge glows green for a moment; nothing flies or slides. The pick itself is saved by the server
-- (PickRideCar, src/client/UI/Prototype/RidePick); this card only shows it.
--
--   local c = LaunchCard.new(ctx, { onStart = fn, onChangeCar = fn?, onChangeTrail = fn?, onClose = fn? })
--   c:open(worldTitle, hint?)  c:close()  c:isOpen()  c:press()  c:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local RealCar = require(Prototype.RealCar)
local Sounds = require(Prototype.Sounds)
local StyleState = require(Prototype.StyleState)
local TrailPreview = require(script.Parent.TrailPreview) :: any
local CarLook = require(ReplicatedStorage.Shared.Style.CarLook)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local make = CarKit.make

local LaunchCard = {}

export type Options = {
	onStart: () -> (),
	onChangeCar: (() -> ())?,
	onChangeTrail: (() -> ())?,
	onClose: (() -> ())?,
}

local GREEN_TOP = Color3.fromRGB(96, 226, 92)
local GREEN_BOTTOM = Color3.fromRGB(28, 160, 52)
local GREEN_LIP = Color3.fromRGB(10, 92, 30)
local ROW_NAMES = { "PAINT", "DECAL", "WHEELS", "TRAIL" }
local ROW_TABS: { string } = { "Paint", "Decals", "Wheels", "Trails" }

-- What a worn item is called on a row: the catalog's name in capitals ("FRESH LIME"); factory paint and no decal say so.
local function wornName(tab: string): (string, Color3?)
	local item = StyleState.item(tab)
	if not item then
		return (if tab == "Paint"
			then "FACTORY PAINT"
			elseif tab == "Decals" then "NO DECAL"
			elseif tab == "Wheels" then "STOCK WHEELS"
			else "NO TRAIL"),
			nil
	end
	local name = string.upper(item.name)
	if item.isNone or item.id == "factory_paint" or item.id == "stock_five" then
		name = if tab == "Paint" then "FACTORY PAINT" elseif tab == "Wheels" then "STOCK WHEELS" else name
	end
	return name, if item.isNone or item.id == "factory_paint" then nil else item.colours[1]
end

function LaunchCard.new(ctx: Overlay.Ctx, options: Options): { [string]: any }
	local overlay = Overlay.new(ctx, { name = "LaunchCard", dimTransparency = 0.6, slide = false })
	local trove = overlay.trove
	local buildTrove = trove:Extend()
	local isOpen = false
	local self: { [string]: any } = {}

	local function build(title: string, hint: string?)
		buildTrove:Clean()
		CarKit.setStrokeScale(ctx.screen:uiScale())
		local D = overlay:designSize()
		local h = math.min(D.Y - 16, 620)
		-- wide screens get a second column for the car's name and what it wears (R8-IMG-25); a tall phone stacks them
		local wide = D.X - 24 >= h * 1.3
		local w = if wide then math.min(D.X - 24, h * 1.62) else math.min(D.X - 24, h * 0.98)
		local k = h / 620
		local card = buildTrove:Add(CarKit.board(overlay.content, {
			size = UDim2.fromOffset(w, h),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			z = 3,
			radius = math.round(22 * k),
			top = Color3.fromRGB(32, 62, 150),
			bottom = Color3.fromRGB(10, 16, 48),
			bolts = true,
			name = "Card",
		})) :: Frame
		local titlePx = math.max(math.round(76 * k), 36)
		CarKit.title(card, title, titlePx, {
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(8, 14),
			size = UDim2.new(1, -16, 0, titlePx * 1.06),
			top = CarKit.Yellow,
			bottom = CarKit.Orange,
			z = 6,
			name = "World",
		})
		CarKit.pattern(card, "speed", { color = Color3.fromRGB(170, 210, 255), transparency = 0.86, z = 3 })
		local stageY = titlePx * 1.1 + 14
		-- the red X, top right, clear of the title's letters
		local closePx = 48
		local closeButton = make("ImageButton", {
			Name = "CloseX",
			BackgroundTransparency = 1,
			Image = "",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(closePx, closePx),
			ZIndex = 12,
		}, card) :: ImageButton
		CarKit.slot(closeButton, "close", closePx, { position = UDim2.fromScale(0.5, 0.5), z = 13, fallback = "Close" })
		buildTrove:Connect(closeButton.Activated, function()
			self:close()
		end)
		local bottom = math.round(190 * k)
		local stageH = h - stageY - bottom
		-- the turntable: the left column on a wide card, the whole width (and a shorter stage) on a stacked one
		local viewW = if wide then math.round(w * 0.5) - 10 else w - 12
		local viewH = if wide then stageH else math.round(stageH * 0.56)
		local view = make("ViewportFrame", {
			Name = "Turntable",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(6, stageY),
			Size = UDim2.fromOffset(viewW, viewH),
			Ambient = Color3.fromRGB(150, 150, 165),
			LightColor = Color3.fromRGB(255, 250, 240),
			LightDirection = Vector3.new(-0.6, -1, -0.5),
			ZIndex = 5,
		}, card) :: ViewportFrame
		local camera = make("Camera", { FieldOfView = 17.5 }, view) :: Camera
		view.CurrentCamera = camera
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 7.2, 30), Vector3.new(0, 1.9, 0))
		local world = make("WorldModel", {}, view) :: WorldModel
		local trailView = TrailPreview.new(world, { length = 5.5 })
		buildTrove:Add(function()
			trailView:destroy()
		end)
		make("Part", {
			Anchored = true,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 13, 13),
			CFrame = CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(40, 48, 84),
		}, world)
		make("Part", {
			Anchored = true,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.14, 13.6, 13.6),
			CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(110, 170, 255),
			Material = Enum.Material.Neon,
		}, world)
		local rig = RealCar.mount(world, { height = 4.8 })
		-- the car turns about its own middle, whatever car it is (A-07: centred on every screen size); measured once per loaded body
		local measured: any = nil
		local centre = Vector3.zero
		local function place(angle: number)
			local body = rig._body
			if body and body ~= measured then
				measured = body
				local box = body.model:GetBoundingBox()
				local off = body.model:GetPivot():PointToObjectSpace(box.Position)
				centre = Vector3.new(off.X, 0, off.Z)
			end
			rig:pivotTo(CFrame.new(0, 0.5, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(-centre))
		end

		-- the car's name and rarity, and the four rows of what it wears ------------------------------------------------------
		local infoX = if wide then viewW + 14 else 12
		local infoY = if wide then stageY else stageY + viewH + 4
		local infoW = if wide then w - infoX - 14 else w - 24
		local infoH = if wide then stageH else stageH - viewH - 4
		local info = make("Frame", {
			Name = "Info",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(infoX, infoY),
			Size = UDim2.fromOffset(infoW, infoH),
			ZIndex = 6,
		}, card) :: Frame
		local namePx = math.max(math.round((if wide then 40 else 30) * k), 22)
		local nameLabel = CarKit.title(info, "", namePx, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, namePx * 1.1),
			top = CarKit.White,
			bottom = CarKit.Soft,
			z = 7,
			name = "CarName",
		})
		local tagH = math.max(math.round(26 * k), 20)
		local tag = make("Frame", {
			Name = "RarityTag",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, namePx * 1.1 + 4),
			Size = UDim2.fromOffset(math.max(math.round(150 * k), 100), tagH),
			BackgroundColor3 = Color3.fromRGB(226, 230, 240),
			ZIndex = 7,
		}, info) :: Frame
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, tag)
		local tagStroke = make(
			"UIStroke",
			{ Thickness = 2.5, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
			tag
		) :: UIStroke
		local tagLabel = CarKit.text(tag, "", math.max(math.round(17 * k), 13), {
			align = Enum.TextXAlignment.Center,
			color = CarKit.Ink,
			z = 8,
			name = "Rarity",
		})
		tagLabel.FontFace = CarKit.display()
		local rowTop = namePx * 1.1 + 4 + tagH + math.round(10 * k)
		local rowAreaH = infoH - rowTop
		local rowGap = math.max(math.round(6 * k), 3)
		local cols = if wide then 1 else 2
		local rowsPerCol = 4 // cols
		local rowH = math.floor((rowAreaH - rowGap * (rowsPerCol - 1)) / rowsPerCol)
		local rowW = math.floor((infoW - rowGap * (cols - 1)) / cols)
		local rowValues: { TextLabel } = {}
		local rowSwatches: { Frame } = {}
		for i, label in ROW_NAMES do
			local col = (i - 1) // rowsPerCol
			local r = (i - 1) % rowsPerCol
			local row = make("Frame", {
				Name = "Row_" .. label,
				BackgroundColor3 = CarKit.Well,
				BackgroundTransparency = 0.1,
				Position = UDim2.fromOffset(col * (rowW + rowGap), rowTop + r * (rowH + rowGap)),
				Size = UDim2.fromOffset(rowW, rowH),
				ZIndex = 7,
			}, info) :: Frame
			make("UICorner", { CornerRadius = UDim.new(0, math.max(math.round(10 * k), 6)) }, row)
			make("UIStroke", { Thickness = 2, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, row)
			local swatch = make("Frame", {
				Name = "Swatch",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(math.max(rowH - 14, 14), math.max(rowH - 14, 14)),
				BackgroundColor3 = CarKit.Soft,
				ZIndex = 8,
			}, row) :: Frame
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, swatch)
			make(
				"UIStroke",
				{ Thickness = 2, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				swatch
			)
			local textX = 8 + math.max(rowH - 14, 14) + 8
			CarKit.text(row, label .. ":", math.max(math.round(15 * k), 11), {
				align = Enum.TextXAlignment.Left,
				color = CarKit.Gold,
				size = UDim2.new(1, -textX - 4, 0.4, 0),
				position = UDim2.new(0, textX, 0.06, 0),
				z = 8,
				name = "Label",
			})
			local value = CarKit.title(row, "", math.max(math.round(21 * k), 13), {
				align = Enum.TextXAlignment.Left,
				size = UDim2.new(1, -textX - 4, 0.52, 0),
				position = UDim2.new(0, textX, 0.42, 0),
				shadow = false,
				stroke = 1.5,
				z = 8,
				name = "Value",
			})
			value.TextTruncate = Enum.TextTruncate.AtEnd
			rowValues[i] = value
			rowSwatches[i] = swatch
		end

		local function refreshInfo()
			local carId = StyleState.car()
			local car = RosterFixtures.byId(carId)
			nameLabel.Text = string.upper(if car then car.name else carId)
			local rarity = if car then car.rarity else "Common"
			tagLabel.Text = string.upper(rarity)
			local tint = (CarKit.Rarity :: any)[rarity] or CarKit.Rarity.Common
			-- Common stays a quiet light grey with navy letters (R8-IMG-25); a rarer car's tag carries its colour
			tag.BackgroundColor3 = if rarity == "Common" then Color3.fromRGB(226, 230, 240) else tint
			tagStroke.Color = CarKit.Ink
			for i, tab in ROW_TABS do
				local text, colour = wornName(tab)
				rowValues[i].Text = text
				rowSwatches[i].BackgroundColor3 = colour or CarKit.Soft
			end
		end

		local function applyStyle()
			rig:setCar(StyleState.car())
			rig:setPaint(StyleState.item("Paint"), 0.18)
			rig:setDecal(StyleState.item("Decals"))
			rig:setWheels(StyleState.item("Wheels"))
			trailView:set(StyleState.item("Trails"))
			refreshInfo()
		end
		rig:pivotTo(CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(242), 0))
		buildTrove:Add(function()
			rig:destroy()
		end)
		RealCar.preload(StyleState.car())
		applyStyle()

		-- the car sways a little: enough to feel alive, never turning its tail away from the ribbon
		local started = os.clock()
		buildTrove:Connect(RunService.Heartbeat, function(dt: number)
			place(math.rad(242 + (if Motion.reduced() then 0 else math.sin((os.clock() - started) * 0.7) * 10)))
			trailView:step(dt, rig:tail())
		end)

		-- the buttons -------------------------------------------------------------------------------------------------------
		local small = math.max(math.round(52 * k), 46)
		local smallW = (w - 44 * k) / 2
		local portraitPx = math.max(small - 8, 38)
		local changeCar = CarKit.button(card, {
			text = "CHANGE CAR",
			tone = "Navy",
			px = math.max(math.round(26 * k), 18),
			icon = "garage",
			iconPx = portraitPx,
			size = UDim2.fromOffset(smallW, small),
			position = UDim2.new(0, 16 * k, 1, -math.round(124 * k) - 12),
			anchor = Vector2.new(0, 1),
			z = 7,
			name = "ChangeCar",
			onPress = options.onChangeCar,
		})
		-- the chosen car's portrait takes the icon's place on the button (C-03)
		local portraitHolder: Frame? = nil
		do
			local row = changeCar.face:FindFirstChild("Row")
			for _, c in if row then row:GetChildren() else {} do
				if c:IsA("Frame") and c.LayoutOrder == 1 then
					portraitHolder = c
				end
			end
			local holder = portraitHolder
			if holder then
				for _, c in holder:GetChildren() do
					c:Destroy()
				end
			end
		end
		local function refreshPortrait()
			local holder = portraitHolder
			if not holder then
				return
			end
			for _, c in holder:GetChildren() do
				c:Destroy()
			end
			local look = CarLook.fromEquipped(StyleState.car(), StyleState.get().equipped)
			RealCar.thumb(holder, StyleState.car(), look)
		end
		refreshPortrait()
		CarKit.button(card, {
			text = "CHANGE TRAIL",
			tone = "Navy",
			px = math.max(math.round(26 * k), 18),
			icon = "trail",
			size = UDim2.fromOffset(smallW, small),
			position = UDim2.new(1, -16 * k, 1, -math.round(124 * k) - 12),
			anchor = Vector2.new(1, 1),
			z = 7,
			name = "ChangeTrail",
			onPress = options.onChangeTrail,
		})
		local start = CarKit.button(card, {
			text = "START!",
			tone = "Orange", -- A-07: START stays the big orange button
			px = math.max(math.round(74 * k), 40),
			size = UDim2.new(1, -math.round(36 * k), 0, math.round(112 * k)),
			position = UDim2.new(0.5, 0, 1, -math.round(14 * k)),
			anchor = Vector2.new(0.5, 1),
			z = 7,
			radius = 22,
			name = "Start",
			onPress = function()
				self:press()
			end,
		})
		local glow = CarKit.art(card, "fx_glow", {
			size = UDim2.new(1.1, 0, 0, math.round(190 * k)),
			position = UDim2.new(0.5, 0, 1, -math.round(70 * k)),
			color = CarKit.Orange,
			transparency = 0.55,
			z = 6,
			placeholder = false,
		})
		if not Motion.reduced() then
			local image = glow:FindFirstChild("Image") :: ImageLabel?
			buildTrove:Connect(RunService.Heartbeat, function()
				if image then
					image.ImageTransparency = 0.6 + 0.16 * math.sin(os.clock() * 3.2)
				end
			end)
		end
		if hint then
			CarKit.title(card, hint, math.max(math.round(30 * k), 20), {
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 34),
				position = UDim2.new(0, 0, 1, -math.round(190 * k) - 30),
				color = CarKit.Yellow,
				stroke = 2.5,
				z = 8,
				name = "Hint",
			})
		end

		-- the confirmation (C-03): sparkle burst, whoosh, a green check, the toast -----------------------------------------------
		local check: Frame? = nil
		local toastSerial = 0
		local function celebrate()
			local carId = StyleState.car()
			local car = RosterFixtures.byId(carId)
			local name = string.upper(if car then car.name else carId)
			local calm = Motion.reduced()
			toastSerial += 1
			local serial = toastSerial
			pcall(function()
				Sounds.play("HopLock", 0.6)
				Sounds.play("Toast", 0.5)
			end)
			-- the green check: stamped on (it stays while the card is open, as the calm state of R8-IMG-25 shows)
			local checkPx = math.max(math.round(64 * k), 44)
			if check then
				check:Destroy()
			end
			local stamp = make("Frame", {
				Name = "ReadyCheck",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(checkPx * 0.5 + 6, checkPx * 0.5 + 6),
				Size = UDim2.fromOffset(checkPx, checkPx),
				BackgroundColor3 = GREEN_BOTTOM,
				ZIndex = 14,
			}, card) :: Frame
			check = stamp
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, stamp)
			make(
				"UIStroke",
				{ Thickness = 3.5, Color = CarKit.White, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				stamp
			)
			make("UIGradient", { Rotation = 90, Color = ColorSequence.new(GREEN_TOP, GREEN_BOTTOM) }, stamp)
			local mark = CarKit.title(stamp, "✔", math.round(checkPx * 0.62), {
				align = Enum.TextXAlignment.Center,
				size = UDim2.fromScale(1, 1),
				shadow = false,
				stroke = 2,
				z = 15,
				name = "Mark",
			})
			mark.TextColor3 = CarKit.White
			buildTrove:Add(stamp)
			local scale = make("UIScale", { Scale = if calm then 1 else 2.4 }, stamp) :: UIScale
			if not calm then
				stamp.BackgroundTransparency = 0.6
				TweenService
					:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
					:Play()
				TweenService:Create(stamp, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
			end
			-- the toast across the title, then it goes
			local old = card:FindFirstChild("ReadyToast")
			if old then
				old:Destroy()
			end
			local toastH = math.max(math.round(54 * k), 38)
			local toast = make("Frame", {
				Name = "ReadyToast",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, if calm then toastH * 0.5 + 10 else -toastH),
				Size = UDim2.new(1, -math.round(checkPx * 2.4), 0, toastH),
				BackgroundColor3 = GREEN_BOTTOM,
				ZIndex = 16,
			}, card) :: Frame
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, toast)
			make("UIStroke", { Thickness = 3, Color = GREEN_LIP, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, toast)
			make("UIGradient", { Rotation = 90, Color = ColorSequence.new(GREEN_TOP, GREEN_BOTTOM) }, toast)
			local text = CarKit.title(toast, "READY TO RIDE: " .. name, math.max(math.round(30 * k), 16), {
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -16, 1, 0),
				position = UDim2.fromOffset(8, 0),
				shadow = false,
				stroke = 2,
				z = 17,
				name = "ToastText",
			})
			text.TextScaled = true
			make("UITextSizeConstraint", { MaxTextSize = math.max(math.round(30 * k), 16), MinTextSize = 10 }, text)
			buildTrove:Add(toast)
			if not calm then
				TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Position = UDim2.new(0.5, 0, 0, toastH * 0.5 + 10),
				}):Play()
			end
			task.delay(2.4, function()
				if toastSerial ~= serial or not toast.Parent then
					return
				end
				if calm then
					toast:Destroy()
					return
				end
				local out =
					TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Position = UDim2.new(0.5, 0, 0, -toastH),
					})
				out.Completed:Connect(function()
					toast:Destroy()
				end)
				out:Play()
			end)
			-- the car appears in a burst of sparkles over the turntable (Reduce Motion: the card's edge glows green instead)
			if calm then
				local edge = make("UIStroke", {
					Name = "ReadyGlow",
					Thickness = 5,
					Color = Color3.fromRGB(90, 255, 120),
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}, card)
				task.delay(1.2, function()
					edge:Destroy()
				end)
				return
			end
			local burst = make("Frame", {
				Name = "SparkleBurst",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(6, stageY),
				Size = UDim2.fromOffset(viewW, viewH),
				ZIndex = 9,
			}, card) :: Frame
			buildTrove:Add(burst)
			local flash = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.52),
				Size = UDim2.fromOffset(viewH * 0.3, viewH * 0.3),
				BackgroundColor3 = Color3.fromRGB(255, 250, 214),
				BackgroundTransparency = 0.35,
				ZIndex = 9,
			}, burst) :: Frame
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, flash)
			TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(viewH * 1.05, viewH * 1.05),
				BackgroundTransparency = 1,
			}):Play()
			local rng = Random.new(os.clock() * 1000)
			for i = 1, 14 do
				local px = math.round((6 + rng:NextNumber() * 9) * math.max(k, 0.7))
				local angle = (i / 14) * math.pi * 2 + rng:NextNumber() * 0.4
				local reach = viewH * (0.34 + rng:NextNumber() * 0.2)
				local spark = make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.52),
					Size = UDim2.fromOffset(px, px),
					Rotation = 45,
					BackgroundColor3 = if i % 3 == 0 then CarKit.Gold else Color3.fromRGB(255, 252, 235),
					ZIndex = 10,
				}, burst) :: Frame
				make("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(255, 214, 90), Transparency = 0.3 }, spark)
				TweenService:Create(
					spark,
					TweenInfo.new(0.6 + rng:NextNumber() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Position = UDim2.new(0.5, math.cos(angle) * reach, 0.52, math.sin(angle) * reach * 0.8),
						BackgroundTransparency = 1,
						Rotation = 225,
					}
				):Play()
			end
			task.delay(1.1, function()
				if burst.Parent then
					burst:Destroy()
				end
			end)
		end

		-- a pick (CHANGE CAR here, or RIDE THIS CAR in the Garage) changes StyleState's car while this card is open
		buildTrove:Connect(StyleState.Changed, function(what: any)
			applyStyle()
			refreshPortrait() -- the portrait wears the paint, decal and wheels now worn
			if what == "car" then
				celebrate()
			end
		end)
		overlay:focus(start.root)
		Motion.pop(card, 0.94)
	end

	function self.open(_self: any, title: string, hint: string?)
		if isOpen then
			return
		end
		isOpen = true
		overlay:setBack(function()
			self:close()
		end)
		overlay:applyScale()
		overlay:open(nil, nil)
		build(title, hint)
	end

	function self.close(_self: any)
		if not isOpen then
			return
		end
		isOpen = false
		buildTrove:Clean()
		overlay:close()
		if options.onClose then
			options.onClose()
		end
	end

	function self.press(_self: any)
		if isOpen then
			isOpen = false
			buildTrove:Clean()
			overlay:close()
			options.onStart()
		end
	end

	function self.isOpen(_self: any): boolean
		return isOpen
	end

	function self.destroy(_self: any)
		trove:Destroy()
	end

	return self
end

return LaunchCard
