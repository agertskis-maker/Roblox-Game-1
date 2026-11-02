--!strict
-- StyleStudio: the one customization screen (Lane 3, Round 3 N4), used by the Shop's Style and Trails tabs, the Stunt customization
-- screen and the Launch Pad's stalls, so they cannot disagree. A turntable car on the left; PAINT, DECALS, WHEELS and TRAILS on the
-- right, each a grid of identical cards; one big action button.
--
--   local s = StyleStudio.new(ctx, host, { tab = "Paint", size = Vector2?, trove = T, onBuy = fn?, onGetCash = fn?, tabs = {...}? })
--   s:setTab(name)  s:select(id) -> boolean  s:pressAction()  s:getDebugState()  s:destroy()
--
-- Tapping a card previews it on the car at once. An owned item offers EQUIP. A Cash item offers BUY: a PREVIEW purchase from the
-- PREVIEW Cash balance that lasts this session. A Robux item goes to `onBuy` and ends in Coming soon. A medal item says what it
-- needs. Leaving resets the preview to what is worn. Everything is PREVIEW: no remote, no save, nothing real is charged.
--
-- The trail on the turntable is a drawn ribbon behind the car, because a ViewportFrame cannot show Trail, Beam or particle
-- objects. The car's own trail in the world is a real Trail (RunTrail, Launch Pad).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local StyleState = require(Prototype.StyleState)
local Supercar = require(Prototype.Supercar)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TrailPreview = require(script.Parent.TrailPreview) :: any

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

local TAB_FAMILY: { [string]: string } = { Paint = "Paint", Decals = "Decal", Wheels = "Wheel", Trails = "Trail" }
local TAB_ICON: { [string]: string } = { Paint = "paint", Decals = "decal", Wheels = "wheel", Trails = "trail" }
local TAB_ART: { [string]: string } = {
	Paint = "art_paint",
	Decals = "art_decal",
	Wheels = "art_wheel",
	Trails = "art_trail",
}

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

function StyleStudio.new(ctx: any, host: Frame, options: Options?): { [string]: any }
	local opts: Options = options or {}
	local self: { [string]: any } = {}
	local trove = (opts.trove or Trove.new()):Extend()
	local size = opts.size or host.AbsoluteSize / math.max(ctx.screen:uiScale(), 0.01)
	local phone = size.Y < 340
	local tabNames = opts.tabs or { "Paint", "Decals", "Wheels", "Trails" }
	local tab = normalTab(opts.tab)
	local previewed: { [string]: string } = {}
	local cards: { [string]: any } = {}
	local message: TextLabel
	local action: CarKit.Button
	local stateTab: { [string]: any } = {}
	local gridHost: ScrollingFrame
	local yaw = math.rad(215)
	local dragging = false
	local dragX = 0
	local spinRestUntil = 0
	local currentSlots: { [string]: Frame } = {}

	local root = trove:Add(make("Frame", {
		Name = "StyleStudio",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 3,
	}, host)) :: Frame

	local leftW = math.floor(size.X * 0.48)
	local rightW = size.X - leftW - 8

	-- THE STAGE ---------------------------------------------------------------------------------------------------------
	local stage = CarKit.board(root, {
		size = UDim2.fromOffset(leftW, size.Y - 6),
		z = 3,
		radius = 14,
		top = Color3.fromRGB(36, 44, 92),
		bottom = Color3.fromRGB(10, 14, 34),
		name = "Stage",
	})
	CarKit.art(stage, "fx_glow", {
		size = UDim2.fromScale(1.1, 0.9),
		position = UDim2.fromScale(0.5, 0.56),
		color = Color3.fromRGB(120, 150, 255),
		transparency = 0.55,
		z = 4,
		placeholder = false,
	})
	local trailView = TrailPreview.new(stage, {
		position = UDim2.fromScale(0.34, 0.41),
		size = UDim2.fromScale(0.42, 0.22),
		z = 5,
	})
	trove:Add(function()
		trailView:destroy()
	end)
	local view = make("ViewportFrame", {
		Name = "Turntable",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, if phone then -8 else -78),
		Ambient = Color3.fromRGB(150, 150, 165),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, -0.5),
		ZIndex = 6,
		Active = true,
	}, stage) :: ViewportFrame
	local camera = make("Camera", { FieldOfView = 24 }, view) :: Camera
	view.CurrentCamera = camera
	local world = make("WorldModel", {}, view) :: WorldModel
	local rig = if Supercar.available() then Supercar.new() else nil
	local pivot = CFrame.new(0, 0.5, 0)
	if rig then
		rig.model.Parent = world
		trove:Add(function()
			rig:destroy()
		end)
	end
	-- the turntable under it
	local disc = make("Part", {
		Name = "Disc",
		Anchored = true,
		CanCollide = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 16, 16),
		CFrame = CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(52, 62, 96),
		Material = Enum.Material.SmoothPlastic,
	}, world)
	make("Part", {
		Name = "DiscEdge",
		Anchored = true,
		CanCollide = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.14, 16.6, 16.6),
		CFrame = disc.CFrame,
		Color = Color3.fromRGB(110, 170, 255),
		Material = Enum.Material.Neon,
	}, world)
	local function placeCamera()
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 7.4, 31), Vector3.new(0, 1.5, 0))
	end
	placeCamera()
	local function setYaw(a: number)
		yaw = a
		if rig then
			rig.model:PivotTo(pivot * CFrame.Angles(0, a, 0))
		end
	end
	setYaw(yaw)

	trove:Connect(view.InputBegan, function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
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

	-- WORN NOW ----------------------------------------------------------------------------------------------------------
	if not phone then
		local strip = make("Frame", {
			Name = "Current",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 66),
			ZIndex = 8,
		}, stage)
		local w = 1 / #tabNames
		for i, name in tabNames do
			local slot = CarKit.board(strip, {
				size = UDim2.new(w, -6, 1, 0),
				position = UDim2.fromScale((i - 1) * w, 0),
				z = 8,
				radius = 8,
				top = CarKit.Well,
				bottom = CarKit.Well,
				name = "Current_" .. name,
			})
			CarKit.slot(slot, TAB_ICON[name], 32, { position = UDim2.new(0, 22, 0.5, 0), z = 9 })
			CarKit.text(slot, name, 13, {
				position = UDim2.fromOffset(42, 6),
				size = UDim2.new(1, -46, 0, 16),
				color = CarKit.Soft,
				z = 9,
			})
			CarKit.text(slot, "", 14, {
				position = UDim2.fromOffset(42, 24),
				size = UDim2.new(1, -46, 0, 34),
				wrap = true,
				alignY = Enum.TextYAlignment.Top,
				z = 9,
				name = "Worn",
			})
			currentSlots[name] = slot
		end
	end

	-- THE PICKER --------------------------------------------------------------------------------------------------------
	local right = make("Frame", {
		Name = "Picker",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(leftW + 8, 0),
		Size = UDim2.fromOffset(rightW, size.Y - 6),
		ZIndex = 3,
	}, root) :: Frame

	local tabH = if phone then 40 else 52
	local actionH = if phone then 50 else 62
	local gapT = 4
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

	local function applyTrail(item: Catalog.Item?)
		trailView:set(item)
	end

	local function applyToCar()
		if rig then
			rig:setPaint(shownItem("Paint"), 0.18)
			rig:setDecal(shownItem("Decals"))
			rig:setWheels(shownItem("Wheels"))
		end
		applyTrail(shownItem("Trails"))
	end

	local function refreshCurrent()
		for name, slot in currentSlots do
			local worn = wornItem(name)
			local label = slot:FindFirstChild("Worn") :: TextLabel?
			if label then
				label.Text = worn and worn.name or "None"
			end
		end
	end

	local function priceText(item: Catalog.Item): string
		if item.robux then
			return Format.group(item.robux) .. " Robux"
		end
		return "$" .. Format.group(item.price)
	end

	local function paintCard(item: Catalog.Item, refs: any)
		local state = isShown(item)
		local selected = (previewed[item.tab] or (StyleState.get().equipped :: any)[item.tab]) == item.id
		refs.ring.Visible = selected
		refs.status.Text = if state == "equipped"
			then "EQUIPPED"
			elseif state == "owned" then "OWNED"
			elseif state == "locked" then "Win " .. string.upper(item.medal or "")
			elseif state == "unavailable" then "N/A"
			else priceText(item)
		refs.status.TextColor3 = if state == "priced" then CarKit.CashText else CarKit.White
		refs.lock.Visible = state == "locked"
	end

	local function refreshAction()
		local item = shownItem(tab)
		if not item then
			return
		end
		local state = isShown(item)
		local name = item.name
		message.Text = item.note
		if state == "equipped" then
			action.setText("EQUIPPED")
			action.setTone("Grey")
		elseif state == "owned" then
			action.setText("EQUIP")
			action.setTone("Green")
		elseif state == "locked" then
			action.setText("LOCKED")
			action.setTone("Grey")
			message.Text = "Win " .. string.upper(item.medal or "") .. " in the Stunt Circuit to unlock " .. name .. "."
		elseif state == "unavailable" then
			action.setText("NOT HERE")
			action.setTone("Grey")
		else
			action.setText("BUY " .. priceText(item))
			action.setTone("Green")
		end
	end

	local function refreshCards()
		for _, refs in cards do
			paintCard(refs.item, refs)
		end
		refreshAction()
		refreshCurrent()
	end

	local function select(id: string): boolean
		local item = Catalog.byId(tab :: any, id)
		if not item or isShown(item) == "unavailable" then
			return false
		end
		previewed[tab] = id
		applyToCar()
		refreshCards()
		return true
	end

	local function thumbFor(item: Catalog.Item, holder: Frame, z: number)
		if item.tab == "Paint" then
			local body = CarKit.art(holder, "thumb_car_body", { z = z, placeholder = false, color = item.colours[1] })
			local image = body:FindFirstChild("Image") :: ImageLabel?
			if image and #item.colours > 1 and item.kind ~= "solid" then
				local stops = {}
				for i, c in item.colours do
					table.insert(stops, ColorSequenceKeypoint.new((i - 1) / (#item.colours - 1), c))
				end
				image.ImageColor3 = CarKit.White
				make("UIGradient", { Color = ColorSequence.new(stops) }, image)
			end
			CarKit.art(holder, "thumb_car_top", { z = z + 2, placeholder = false })
		elseif item.isNone then
			CarKit.art(holder, "thumb_car_none", { z = z, placeholder = false, fallbackIcon = "Close" })
		else
			local prefix = if item.tab == "Decals"
				then "thumb_decal_"
				elseif item.tab == "Wheels" then "thumb_wheel_"
				else "ribbon_"
			CarKit.art(holder, prefix .. (item.key or ""), { z = z, placeholder = false })
		end
	end

	local function buildGrid()
		for _, c in gridHost:GetChildren() do
			if not c:IsA("UIGridLayout") then
				c:Destroy()
			end
		end
		table.clear(cards)
		local items = Catalog.itemsFor(tab :: any)
		local tierRarity: { [string]: string } = {}
		for _, t in Catalog.Tiers[tab] do
			tierRarity[t.id] = t.rarity
		end
		for order, item in items do
			local rarity = tierRarity[item.tier] or "Common"
			local edge = (CarKit.Rarity :: any)[rarity]
			local button = make("TextButton", {
				Name = "Item_" .. item.id,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(18, 26, 52),
				LayoutOrder = order,
				ZIndex = 5,
				Selectable = true,
			}, gridHost) :: TextButton
			make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
			make("UIStroke", { Thickness = 2.5, Color = edge, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
			make("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 160, 190)),
			}, button)
			CarKit.title(button, item.name, if phone then 15 else 19, {
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -6, 0, 22),
				position = UDim2.fromOffset(3, 3),
				z = 7,
				shadow = false,
				stroke = 1.5,
			})
			CarKit.text(button, rarity, 11, {
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 13),
				position = UDim2.fromOffset(0, 24),
				color = edge,
				z = 7,
			})
			local holder = make("Frame", {
				Name = "Thumb",
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0, 38),
				AnchorPoint = Vector2.new(0.5, 0),
				Size = UDim2.new(1, -8, 1, -64),
				ZIndex = 6,
			}, button) :: Frame
			thumbFor(item, holder, 6)
			local status = CarKit.title(button, "", if phone then 15 else 18, {
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, -6, 0, 22),
				position = UDim2.new(0, 3, 1, -24),
				z = 7,
				shadow = false,
				stroke = 1.5,
				name = "Status",
			})
			local lock = CarKit.slot(button, "lock", 32, { position = UDim2.new(1, -18, 0, 54), z = 8 })
			local ring = make("Frame", {
				Name = "Selected",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 9,
				Visible = false,
			}, button)
			make("UICorner", { CornerRadius = UDim.new(0, 8) }, ring)
			make(
				"UIStroke",
				{ Thickness = 3.5, Color = CarKit.White, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				ring
			)
			local refs = { item = item, ring = ring, status = status, lock = lock }
			cards[item.id] = refs
			button.Activated:Connect(function()
				select(item.id)
			end)
		end
		refreshCards()
	end

	local function setTab(name: string)
		local wanted = normalTab(name)
		if wanted == tab then
			return
		end
		tab = wanted
		for key, refs in tabRefs do
			refs.paint(key == tab)
		end
		buildGrid()
		gridHost.CanvasPosition = Vector2.zero
		spinRestUntil = 0
		-- the ribbon needs the car's tail to the left
		if tab == "Trails" then
			setYaw(math.rad(215))
		end
	end

	for i, name in tabNames do
		local family = (CarKit.Family :: any)[TAB_FAMILY[name]]
		local button = make("TextButton", {
			Name = "Tab_" .. name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = CarKit.White,
			Position = UDim2.fromOffset((i - 1) * (tabW + gapT), 0),
			Size = UDim2.fromOffset(tabW, tabH),
			ZIndex = 5,
			Selectable = true,
		}, right) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
		make("UIStroke", { Thickness = 2.5, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(family.top, family.bottom) }, button)
		local slotPx = if phone then 24 else 32
		CarKit.slot(button, TAB_ICON[name], slotPx, { position = UDim2.new(0, slotPx / 2 + 4, 0.5, 0), z = 6 })
		local label = CarKit.title(button, string.upper(name), if phone then 18 else 26, {
			position = UDim2.fromOffset(slotPx + 6, 0),
			size = UDim2.new(1, -slotPx - 8, 1, 0),
			shadow = false,
			stroke = 2,
			z = 7,
		})
		local function paintTab(on: boolean)
			button.BackgroundTransparency = if on then 0 else 0.45
			label.TextTransparency = if on then 0 else 0.25
		end
		tabRefs[name] = { paint = paintTab }
		button.Activated:Connect(function()
			setTab(name)
		end)
	end

	local well = CarKit.board(right, {
		size = UDim2.fromOffset(rightW, size.Y - tabH - actionH - 34),
		position = UDim2.fromOffset(0, tabH + 4),
		z = 4,
		radius = 10,
		top = CarKit.Well,
		bottom = CarKit.Well,
		name = "Well",
	})
	local columns = if phone then 3 elseif rightW < 560 then 3 else 4
	gridHost = make("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -8, 1, -12),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = CarKit.ChromeBottom,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 5,
		Selectable = false,
	}, well) :: ScrollingFrame
	local cellW = math.floor((rightW - 22 - 8 * (columns - 1)) / columns)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellW, math.round(cellW * 0.86)),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	}, gridHost)

	message = CarKit.text(right, "", if phone then 13 else 15, {
		size = UDim2.fromOffset(rightW, 20),
		position = UDim2.new(0, 0, 1, -actionH - 26),
		align = Enum.TextXAlignment.Center,
		color = CarKit.Soft,
		z = 5,
		name = "Note",
	})

	local function pressAction()
		local item = shownItem(tab)
		if not item then
			return
		end
		local state = isShown(item)
		if state == "owned" then
			StyleState.equip(tab, item.id)
			previewed[tab] = nil
		elseif state == "priced" then
			if item.robux then
				if opts.onBuy then
					opts.onBuy(item.id, item.name, TAB_ART[item.tab])
				end
			else
				local cash = ctx.store:get().cash or 0
				if cash >= item.price then
					ctx.store:set("cash", cash - item.price)
					StyleState.own(item.id)
					StyleState.equip(tab, item.id)
					previewed[tab] = nil
				else
					message.Text = ("You need $%s more Cash."):format(Format.group(item.price - cash))
					if opts.onGetCash then
						opts.onGetCash()
					end
					return
				end
			end
		end
		applyToCar()
		refreshCards()
	end

	action = CarKit.button(right, {
		text = "EQUIP",
		tone = "Green",
		px = if phone then 28 else 40,
		size = UDim2.new(0.8, 0, 0, actionH),
		position = UDim2.new(0.5, 0, 1, -2),
		anchor = Vector2.new(0.5, 1),
		z = 6,
		name = "Action",
		onPress = pressAction,
	})

	-- the one loop: the turntable, and animated paint at about 12 updates a second
	local accumulate = 0
	local started = os.clock()
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not root.Visible or Motion.reduced() then
			return
		end
		trailView:step(dt)
		if not dragging and os.clock() >= spinRestUntil and tab ~= "Trails" then
			setYaw(yaw + dt * math.rad(14))
		end
		accumulate += dt
		if accumulate >= 1 / 12 then
			accumulate = 0
			local paint = shownItem("Paint")
			if rig and paint and Supercar.isAnimated(paint) then
				rig:tick(((os.clock() - started) / (paint.cycleSeconds or 6)) % 1)
			end
		end
	end)
	trove:Connect(StyleState.Changed, function()
		applyToCar()
		refreshCards()
	end)

	function self.setTab(_self: any, name: string)
		setTab(name)
	end

	function self.select(_self: any, id: string): boolean
		return select(id)
	end

	function self.pressAction(_self: any)
		pressAction()
	end

	function self.getDebugState(_self: any): { [string]: any }
		local count = 0
		for _ in cards do
			count += 1
		end
		return {
			tab = tab,
			cards = count,
			previewed = previewed,
			equipped = StyleState.get().equipped,
			rig = rig ~= nil,
		}
	end

	function self.destroy(_self: any)
		trove:Destroy()
	end

	tab = ""
	setTab(opts.tab or "Paint")
	applyToCar()
	return self
end

return StyleStudio
