--!strict
-- LaunchCard: the card that opens when you step on a Launch Pad's ramp (Lane 3, Round 3 N6-03). The World's name, your car on a
-- turntable, your trail behind it, two small change buttons and a giant START!. It starts nothing itself: it calls onStart.
--
--   local c = LaunchCard.new(ctx, { onStart = fn, onChangeCar = fn?, onChangeTrail = fn?, onClose = fn? })
--   c:open(worldTitle, hint?)  c:close()  c:isOpen()  c:press()  c:destroy()

local RunService = game:GetService("RunService")

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local RealCar = require(Prototype.RealCar)
local StyleState = require(Prototype.StyleState)
local TrailPreview = require(script.Parent.TrailPreview) :: any

local make = CarKit.make

local LaunchCard = {}

export type Options = {
	onStart: () -> (),
	onChangeCar: (() -> ())?,
	onChangeTrail: (() -> ())?,
	onClose: (() -> ())?,
}

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
		local w = math.min(D.X - 24, h * 0.98)
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
		local boltPx = math.max(math.round(30 * k), 24)
		CarKit.slot(card, "stamina", boltPx, {
			position = UDim2.new(0.5, -math.round(58 * k), 0, stageY + boltPx * 0.4),
			z = 7,
		})
		CarKit.text(card, "10 hops this run", math.max(math.round(18 * k), 14), {
			position = UDim2.new(0.5, -math.round(38 * k), 0, stageY - 4),
			size = UDim2.fromOffset(180, boltPx),
			stroke = 1.5,
			z = 7,
			name = "Bolts",
		})
		local bottom = math.round(190 * k)
		local stageH = h - stageY - bottom
		local trailView = TrailPreview.new(card, {
			position = UDim2.new(0.36, 0, 0, stageY + stageH * 0.42),
			size = UDim2.fromScale(0.34, 0.16),
			z = 4,
		})
		buildTrove:Add(function()
			trailView:destroy()
		end)
		local view = make("ViewportFrame", {
			Name = "Turntable",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(6, stageY),
			Size = UDim2.new(1, -12, 0, stageH),
			Ambient = Color3.fromRGB(150, 150, 165),
			LightColor = Color3.fromRGB(255, 250, 240),
			LightDirection = Vector3.new(-0.6, -1, -0.5),
			ZIndex = 5,
		}, card) :: ViewportFrame
		local camera = make("Camera", { FieldOfView = 17.5 }, view) :: Camera
		view.CurrentCamera = camera
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 7.2, 30), Vector3.new(0, 1.3, 0))
		local world = make("WorldModel", {}, view) :: WorldModel
		make("Part", {
			Anchored = true,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 15, 15),
			CFrame = CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(40, 48, 84),
		}, world)
		make("Part", {
			Anchored = true,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.14, 15.6, 15.6),
			CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(110, 170, 255),
			Material = Enum.Material.Neon,
		}, world)
		local rig = RealCar.mount(world)
		local function applyStyle()
			rig:setCar(StyleState.car())
			rig:setPaint(StyleState.item("Paint"), 0.18)
			rig:setDecal(StyleState.item("Decals"))
			rig:setWheels(StyleState.item("Wheels"))
			trailView:set(StyleState.item("Trails"))
		end
		rig:pivotTo(CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(215), 0))
		buildTrove:Add(function()
			rig:destroy()
		end)
		applyStyle()
		buildTrove:Connect(StyleState.Changed, applyStyle)

		-- the car sways a little: enough to feel alive, never turning its tail away from the ribbon
		local started = os.clock()
		buildTrove:Connect(RunService.Heartbeat, function(dt: number)
			trailView:step(dt)
			if not Motion.reduced() then
				local a = math.rad(215 + math.sin((os.clock() - started) * 0.7) * 12)
				rig:pivotTo(CFrame.new(0, 0.5, 0) * CFrame.Angles(0, a, 0))
			end
		end)

		local small = math.max(math.round(52 * k), 46)
		local smallW = (w - 44 * k) / 2
		local carName = "CHANGE CAR"
		CarKit.button(card, {
			text = carName,
			tone = "Navy",
			px = math.max(math.round(26 * k), 18),
			icon = "garage",
			size = UDim2.fromOffset(smallW, small),
			position = UDim2.new(0, 16 * k, 1, -math.round(124 * k) - 12),
			anchor = Vector2.new(0, 1),
			z = 7,
			name = "ChangeCar",
			onPress = options.onChangeCar,
		})
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
			tone = "Green",
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
			color = CarKit.Green,
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
