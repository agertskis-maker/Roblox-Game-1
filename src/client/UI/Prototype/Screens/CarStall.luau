--!strict
-- CarStall: the Launch Pad's Car stall (Lane 3, Round 3 N6-04): choose the car you start in. Round 4 (E-05): only this pad's
-- World's nine cars (RealCar.forWorld), the Loaner first and always free to pick, then the cars you own, then the ones you have
-- not found yet, shown dark with a lock and not pickable. Ownership is the example collection until Brian L's save reaches the
-- client. The run still starts in Brian R's Loaner until his RunController takes a start car, and the panel says so; the choice
-- is kept in StyleState and shows on the other screens.
-- Each card's picture is built only as it scrolls near the view, so opening the stall does not load all 27.
--
--   local c = CarStall.new(ctx, { onClose = fn? })
--   c:open(world?)  c:close()  c:isOpen()  c:destroy()

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Overlay = require(script.Parent.Overlay)
local RealCar = require(Prototype.RealCar)
local StyleState = require(Prototype.StyleState)

local make = CarKit.make

local CarStall = {}

function CarStall.new(ctx: Overlay.Ctx, options: { onClose: (() -> ())? }?): { [string]: any }
	local opts = options or {}
	local overlay = Overlay.new(ctx, { name = "CarStall", dimTransparency = 0.5, slide = false })
	local trove = overlay.trove
	local buildTrove = trove:Extend()
	local isOpen = false
	local world = "Downtown"
	local self: { [string]: any } = {}

	local function build()
		buildTrove:Clean()
		CarKit.setStrokeScale(ctx.screen:uiScale())
		local D = overlay:designSize()
		local w, h = math.min(D.X - 24, 860), math.min(D.Y - 24, 500)
		local panel = buildTrove:Add(CarKit.board(overlay.content, {
			size = UDim2.fromOffset(w, h),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			z = 2,
			radius = 16,
			bolts = true,
			name = "Panel",
		})) :: Frame
		CarKit.title(panel, "YOUR CAR", 44, {
			position = UDim2.fromOffset(16, 4),
			size = UDim2.new(1, -80, 0, 50),
			top = CarKit.White,
			bottom = CarKit.Gold,
			z = 5,
		})
		local close = make("ImageButton", {
			Name = "Close",
			BackgroundTransparency = 1,
			Image = "",
			Size = UDim2.fromOffset(46, 46),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 6),
			ZIndex = 6,
		}, panel) :: ImageButton
		CarKit.slot(close, "close", 46, { position = UDim2.fromScale(0.5, 0.5), z = 6, fallback = "Close" })
		close.Activated:Connect(function()
			self:close()
		end)
		local grid = make("ScrollingFrame", {
			Name = "Grid",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 58),
			Size = UDim2.new(1, -28, 1, -96),
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 3,
			Selectable = false,
		}, panel) :: ScrollingFrame
		local cellW = math.floor((w - 40 - 16) / 3)
		make("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellW, math.round(cellW * 0.7)),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		local rings: { [string]: Frame } = {}
		local pending: { { holder: Frame, name: string } } = {}
		local cars = RealCar.forWorld(world)
		if #cars == 0 then
			CarKit.text(panel, "Cars are on their way.", 22, {
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -24, 0, 30),
				position = UDim2.new(0, 12, 0.5, -15),
				z = 5,
				name = "Empty",
			})
		end
		for i, car in cars do
			local rarity = (CarKit.Rarity :: any)[car.rarity] or CarKit.Rarity.Common
			local button = make("TextButton", {
				Name = "Car_" .. car.name,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(18, 26, 52),
				LayoutOrder = i,
				ZIndex = 4,
				Selectable = true,
			}, grid) :: TextButton
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
			make("UIStroke", { Thickness = 2.5, Color = rarity, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
			local holder = make("Frame", {
				Name = "Thumb",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(1, -10, 1, -30),
				Position = UDim2.new(0.5, 0, 0.5, -10),
				ZIndex = 5,
			}, button) :: Frame
			table.insert(pending, { holder = holder, name = car.name })
			if not car.owned then
				-- not found yet: dark over the picture, a lock, and no pick
				local shade = make("Frame", {
					Name = "NotYours",
					BackgroundColor3 = Color3.fromRGB(10, 14, 30),
					BackgroundTransparency = 0.25,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 7,
				}, button) :: Frame
				make("UICorner", { CornerRadius = UDim.new(0, 10) }, shade)
				CarKit.text(shade, "Find it in a run", 15, {
					align = Enum.TextXAlignment.Center,
					size = UDim2.new(1, -8, 0, 22),
					position = UDim2.new(0, 4, 0.5, -11),
					z = 8,
					name = "Hint",
				})
			end
			if car.loaner then
				CarKit.text(button, "LOANER", 13, {
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(1, -12, 0, 18),
					position = UDim2.fromOffset(8, 4),
					color = CarKit.Gold,
					z = 8,
					name = "Loaner",
				})
			end
			CarKit.title(button, car.name, 20, {
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -6, 0, 24),
				position = UDim2.new(0, 3, 1, -26),
				z = 8,
				shadow = false,
				stroke = 1.5,
			})
			local ring = make("Frame", {
				Name = "Selected",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Visible = StyleState.car() == car.name,
				ZIndex = 9,
			}, button) :: Frame
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, ring)
			make(
				"UIStroke",
				{ Thickness = 3.5, Color = CarKit.White, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				ring
			)
			rings[car.name] = ring
			button.Activated:Connect(function()
				if not car.owned then
					return
				end
				StyleState.setCar(car.name)
				for name, r in rings do
					r.Visible = name == car.name
				end
			end)
		end
		local function buildNear()
			local bottom = grid.AbsolutePosition.Y + grid.AbsoluteSize.Y * 1.5
			for i = #pending, 1, -1 do
				local p = pending[i]
				if p.holder.AbsolutePosition.Y < bottom then
					table.remove(pending, i)
					RealCar.thumb(p.holder, p.name)
				end
			end
		end
		buildTrove:Connect(grid:GetPropertyChangedSignal("CanvasPosition"), buildNear)
		buildTrove:Connect(grid:GetPropertyChangedSignal("AbsoluteSize"), buildNear)
		task.defer(buildNear)
		CarKit.text(panel, "For now every run starts in the Loaner. Your pick starts working soon.", 15, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -24, 0, 24),
			position = UDim2.new(0, 12, 1, -32),
			color = CarKit.Soft,
			z = 5,
			name = "Note",
		})
	end

	function self.open(_self: any, worldId: string?)
		if isOpen then
			return
		end
		isOpen = true
		world = worldId or world
		overlay:setBack(function()
			self:close()
		end)
		overlay:applyScale()
		overlay:open(nil, nil)
		build()
	end

	function self.close(_self: any)
		if not isOpen then
			return
		end
		isOpen = false
		buildTrove:Clean()
		overlay:close()
		if opts.onClose then
			opts.onClose()
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

return CarStall
