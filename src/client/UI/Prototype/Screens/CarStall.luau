--!strict
-- CarStall: the Launch Pad's Car stall (Lane 3, Round 3 N6-04): choose the car you start in. PREVIEW: the run always starts in Brian
-- R's Loaner until his RunController takes a start car, and the panel says so; the choice is kept in StyleState for that day.
--
--   local c = CarStall.new(ctx, { onClose = fn? })
--   c:open()  c:close()  c:isOpen()  c:destroy()

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Fixtures = require(Prototype.Fixtures) :: any
local Overlay = require(script.Parent.Overlay)
local StyleState = require(Prototype.StyleState)

local make = CarKit.make

local CarStall = {}

function CarStall.new(ctx: Overlay.Ctx, options: { onClose: (() -> ())? }?): { [string]: any }
	local opts = options or {}
	local overlay = Overlay.new(ctx, { name = "CarStall", dimTransparency = 0.5, slide = false })
	local trove = overlay.trove
	local buildTrove = trove:Extend()
	local isOpen = false
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
		local state = StyleState.get() :: any
		local rings: { [string]: Frame } = {}
		local cars = Fixtures.Cars or {}
		for i, car in cars do
			if i > 6 then
				break
			end
			local rarity = (CarKit.Rarity :: any)[car.rarity] or CarKit.Rarity.Common
			local button = make("TextButton", {
				Name = "Car_" .. car.id,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(18, 26, 52),
				LayoutOrder = i,
				ZIndex = 4,
				Selectable = true,
			}, grid) :: TextButton
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
			make("UIStroke", { Thickness = 2.5, Color = rarity, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
			CarKit.art(button, "thumb_car_body", {
				size = UDim2.new(1, -10, 1, -30),
				position = UDim2.new(0.5, 0, 0.5, -10),
				color = rarity,
				z = 5,
				placeholder = false,
			})
			CarKit.art(button, "thumb_car_top", {
				size = UDim2.new(1, -10, 1, -30),
				position = UDim2.new(0.5, 0, 0.5, -10),
				z = 7,
				placeholder = false,
			})
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
				Visible = state.car == car.id,
				ZIndex = 9,
			}, button) :: Frame
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, ring)
			make("UIStroke", { Thickness = 3.5, Color = CarKit.White, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
			rings[car.id] = ring
			button.Activated:Connect(function()
				state.car = car.id
				for id, r in rings do
					r.Visible = id == car.id
				end
			end)
		end
		CarKit.text(panel, "For now every run starts in the Loaner. Your pick starts working soon.", 15, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -24, 0, 24),
			position = UDim2.new(0, 12, 1, -32),
			color = CarKit.Soft,
			z = 5,
			name = "Note",
		})
	end

	function self.open(_self: any)
		if isOpen then
			return
		end
		isOpen = true
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
