--!strict
-- Base presentation samples on TEST FIXTURES (Lane 3 preview, HUD rebuild 2026-10-22, worker HW;
-- ledger W-01 samples, W-03, E-07). Isolated visual samples with no mechanics: nothing here
-- buys, upgrades, unlocks, pays or saves anything, and nothing is placed on the island (W-04:
-- the modules are parameterised so a future island task could adopt them).
--
--   place(origin)              the base tour:
--     * Lineup car label   a parked proxy car (Rare, owned) with the kit plate (rarity + name)
--     * Lap Pay label      a parked proxy car + the restyled LapPay (payLap(amount) pops "+$N")
--     * Paddock board      in-world SurfaceGui: "UPGRADE", "Tier 2 -> Tier 3", a fixture price
--                          tagged PREVIEW; no buttons at all (nothing to press)
--     * progress plaque    padlock icon + "12 / 20 cars" + a progress bar (fixture numbers)
--     * first session      START lettering on the ground + four big ground chevrons leading to
--                          a portal stand-in with a DOWNTOWN destination label and a ground
--                          marker at its entry
--     * plot gate          a stand-in gate with the ArrivalSparkle (plays on ArrivedHome, or
--                          arrive())
--   placeDestinations(origin)  the W-01 samples: GARAGE, STUNT CIRCUIT and the three Worlds'
--                          names from the GDD (DOWNTOWN, DUSTY HIGHWAY, SUMMIT PASS) over
--                          stand-ins, with one wall in front of SUMMIT PASS for the occlusion
--                          check. Returns the label objects.
-- Frame of `origin`: +X right, -Z forward (toward the portal), y = ground.
--
--   local fx = BaseFixtures.new(ctx)
--   fx:place(origin)  fx:placeDestinations(origin)  fx:payLap(amount?) -> boolean
--   fx:arrive() -> boolean  fx:points() -> { [string]: Vector3 }  fx:clear()
--   fx:layout(), fx:setVisible(on), fx:destroy(), fx:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local ArrivalSparkle = require(script.Parent.ArrivalSparkle)
local DestinationLabel = require(script.Parent.DestinationLabel)
local Fixtures = require(script.Parent.Parent.Fixtures)
local GroundMarker = require(script.Parent.GroundMarker)
local LapPay = require(script.Parent.LapPay)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local ProxyCar = require(script.Parent.Parent.ProxyCar)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local A = PreviewTokens.Arcade
local INK = A.Ink
local NAVY = Color3.fromRGB(30, 44, 86) -- TOKEN CANDIDATE: in-world sign body
local POST = Color3.fromRGB(70, 76, 92)
local PPS = 40 -- SurfaceGui pixels per stud
-- Top-face SurfaceGui orientation for the START lettering; flip to 180 if Studio shows the word
-- upside down from the start position (unverified: no Studio run in this task).
local START_YAW = 0

-- FIXTURE values (not rules): shown only as samples
local FIXTURE = table.freeze({
	tierFrom = 2,
	tierTo = 3,
	price = "$12,500",
	carsOwned = 12,
	carsTotal = 20,
	lapPay = 120,
})

local BaseFixtures = {}
BaseFixtures.__index = BaseFixtures

function BaseFixtures.new(ctx: WorldKit.Ctx, _options: any?)
	local self = setmetatable({}, BaseFixtures)
	self._ctx = ctx
	self._trove = Trove.new()
	self._place = Trove.new() -- one trove per placement, cleared by clear()
	self._trove:Add(function()
		self._place:Destroy()
	end)
	self._visible = true
	self._folder = nil :: Folder?
	self._lapPay = nil :: any
	self._lapCar = nil :: BasePart?
	self._sparkle = nil :: any
	self._labels = {} :: { any }
	self._markers = {} :: { any }
	self._plates = {} :: { { board: BillboardGui, scale: UIScale, plate: WorldKit.Plate } }
	self._points = {} :: { [string]: Vector3 }
	-- the sample Lap Pay listens to a PRIVATE store, so the playground's real LapPay events never
	-- also pop a duplicate label on the fixture car
	self._lapStore = Store.new()
	self._trove:Add(function()
		self._lapStore:destroy()
	end)
	return self
end

export type BaseFixtures = typeof(BaseFixtures.new((nil :: any) :: WorldKit.Ctx))

function BaseFixtures._folderFor(self: BaseFixtures): Folder
	if self._folder and self._folder.Parent then
		return self._folder :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = "BaseFixtures"
	f.Parent = self._ctx.world
	self._place:Add(f)
	self._folder = f
	return f
end

function BaseFixtures._childCtx(self: BaseFixtures): WorldKit.Ctx
	local c = self._ctx
	return {
		store = c.store,
		screen = c.screen,
		layer = c.layer,
		world = self:_folderFor(),
		priority = c.priority,
	}
end

function BaseFixtures.clear(self: BaseFixtures)
	self._place:Destroy()
	self._place = Trove.new()
	self._folder = nil
	self._lapPay = nil
	self._lapCar = nil
	self._sparkle = nil
	table.clear(self._labels)
	table.clear(self._markers)
	table.clear(self._plates)
	table.clear(self._points)
end

-- HELPERS -------------------------------------------------------------------------------------

local function surface(part: BasePart, face: Enum.NormalId): (SurfaceGui, Frame)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0.15
	gui.AlwaysOnTop = false
	gui.MaxDistance = 220
	gui.ResetOnSpawn = false
	gui.Parent = part
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	return gui, root
end

local function icon(holder: Frame, names: { string })
	for _, n in names do
		holder:ClearAllChildren()
		if Arcade.icon(holder, n) then
			return
		end
	end
end

-- An arrow drawn from Frames (no glyph dependency): a shaft and a rotated square head.
local function arrow(parent: Instance, order: number): Frame
	local f = Arcade.make("Frame", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(56, 40),
		LayoutOrder = order,
		Parent = parent,
	}) :: Frame
	local shaft = Arcade.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(32, 12),
		BackgroundColor3 = A.Face.Keys.Keypoints[2].Value,
		Parent = f,
	}) :: Frame
	Arcade.outline(shaft, 3)
	local head = Arcade.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 38, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		Rotation = 45,
		BackgroundColor3 = A.Face.Keys.Keypoints[2].Value,
		ZIndex = 2,
		Parent = f,
	}) :: Frame
	Arcade.outline(head, 3)
	return f
end

function BaseFixtures._plateLabel(self: BaseFixtures, model: Model, car: WorldKit.CarInfo)
	local part = WorldKit.mainPart(model) :: BasePart
	local box, size = WorldKit.box(model)
	local board = Instance.new("BillboardGui")
	board.Name = "LineupLabel"
	board.Adornee = part
	board.AlwaysOnTop = false
	board.LightInfluence = 0
	board.MaxDistance = 120
	board.StudsOffsetWorldSpace = Vector3.new(0, box.Position.Y + size.Y / 2 - part.Position.Y + 1, 0)
	board.Parent = self:_folderFor()
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 0.5)
	holder.Parent = board
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = holder
	local plate = WorldKit.plate(holder, car)
	plate.holder.AnchorPoint = Vector2.new(0.5, 1)
	plate.holder.Position = UDim2.fromScale(0.5, 1)
	table.insert(self._plates, { board = board, scale = scale, plate = plate })
	self:_scalePlates()
end

function BaseFixtures._scalePlates(self: BaseFixtures)
	local s = WorldKit.billboardScale(self._ctx)
	for _, p in self._plates do
		p.scale.Scale = s
		p.board.Size = UDim2.fromOffset(math.ceil(p.plate.width * s), math.ceil(p.plate.height * s * 2))
	end
end

local function parked(folder: Instance, car: Fixtures.CarRef, cf: CFrame): Model
	local m = ProxyCar.build(car)
	WorldKit.seat(m, cf)
	m.Parent = folder
	return m
end

-- PLACE ---------------------------------------------------------------------------------------

function BaseFixtures.place(self: BaseFixtures, origin: CFrame)
	self:clear()
	local folder = self:_folderFor()
	local cctx = self:_childCtx()
	local function at(x: number, z: number): CFrame
		return origin * CFrame.new(x, 0, z)
	end
	local function pos(x: number, y: number, z: number): Vector3
		return (origin * CFrame.new(x, y, z)).Position
	end

	-- 1. Lineup car label (a Rare car in a Lineup bay is owned, so no NEW!)
	local lineupCar = table.clone(Fixtures.byId("rev6") or Fixtures.Cars[5])
	lineupCar.owned = true
	WorldKit.part(
		folder,
		"LineupBay",
		Vector3.new(10, 0.06, 18),
		at(-34, 0) + Vector3.new(0, 0.03, 0),
		Color3.fromRGB(150, 156, 168)
	)
	local lineup = parked(folder, lineupCar, at(-34, 0) * CFrame.new(0, 0.06, 0))
	self:_plateLabel(lineup, lineupCar)
	self._points.lineup = pos(-34, 3, 0)

	-- 2. Lap Pay label on a parked car (restyled LapPay, visual only)
	local lapCar = Fixtures.byId("puglet") or Fixtures.Cars[1]
	local lapModel = parked(folder, lapCar, at(-20, 0))
	local lapCtx = table.clone(cctx) :: any
	lapCtx.store = self._lapStore
	local lap = LapPay.new(lapCtx)
	self._place:Add(function()
		lap:destroy()
	end)
	self._lapCar = lapModel.PrimaryPart
	lap:setCars({ lapModel.PrimaryPart :: BasePart })
	self._lapPay = lap
	self._points.lapPay = pos(-20, 3, 0)

	-- 3. Paddock upgrade board (no buttons; the price is a fixture tagged PREVIEW)
	for _, x in { -5.5, 5.5 } do
		WorldKit.part(folder, "BoardPost", Vector3.new(0.6, 9, 0.6), at(x, -6) + Vector3.new(0, 4.5, 0), POST)
	end
	local board = WorldKit.part(folder, "PaddockBoard", Vector3.new(12, 7, 0.5), at(0, -6) + Vector3.new(0, 6, 0), NAVY)
	board.CastShadow = true
	local _, broot = surface(board, Enum.NormalId.Back) -- Back = +Z: faces the viewer at the origin
	local header = Arcade.make("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = broot,
	}) :: Frame
	Arcade.make("UIGradient", { Color = A.Fill.Missions, Rotation = 90, Parent = header })
	Arcade.outline(header, 4)
	Arcade.gloss(header)
	local title = Arcade.text(header, { text = "UPGRADE", role = "Display", name = "Title", size = 60, z = 6 })
	title.Size = UDim2.fromScale(1, 1)
	local tierRow = Arcade.make("Frame", {
		Name = "Tiers",
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundTransparency = 1,
		Parent = broot,
	}) :: Frame
	Arcade.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 14),
		Parent = tierRow,
	})
	local fromT = Arcade.text(tierRow, {
		text = "Tier " .. FIXTURE.tierFrom,
		role = "Display",
		name = "From",
		size = 48,
		autoWidth = true,
	})
	fromT.LayoutOrder = 1
	arrow(tierRow, 2)
	local toT = Arcade.text(tierRow, {
		text = "Tier " .. FIXTURE.tierTo,
		role = "Display",
		name = "To",
		size = 48,
		face = "Keys",
		autoWidth = true,
	})
	toT.LayoutOrder = 3
	local priceRow = Arcade.make("Frame", {
		Name = "Price",
		Position = UDim2.fromOffset(0, 180),
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundTransparency = 1,
		Parent = broot,
	}) :: Frame
	Arcade.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
		Parent = priceRow,
	})
	local cash = Arcade.make("Frame", {
		Name = "CashIcon",
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = priceRow,
	}) :: Frame
	icon(cash, { "Cash", "Coin" })
	local price = Arcade.text(priceRow, {
		text = FIXTURE.price,
		role = "Value",
		name = "Amount",
		size = 52,
		face = "Cash",
		italic = true,
		autoWidth = true,
	})
	price.LayoutOrder = 2
	local tag = Arcade.text(priceRow, {
		text = "PREVIEW",
		role = "Label",
		name = "PreviewTag",
		size = 24,
		colour = Color3.fromRGB(255, 230, 90),
		autoWidth = true,
	})
	tag.LayoutOrder = 3
	tag.Rotation = -6
	self._points.board = pos(0, 6, -6)

	-- 4. Padlock / progress plaque (fixture numbers)
	WorldKit.part(folder, "PlaquePost", Vector3.new(0.6, 3.5, 0.6), at(14, -6) + Vector3.new(0, 1.75, 0), POST)
	local plaque = WorldKit.part(folder, "Plaque", Vector3.new(7, 3.5, 0.4), at(14, -6) + Vector3.new(0, 4.6, 0), NAVY)
	plaque.CastShadow = true
	local _, proot = surface(plaque, Enum.NormalId.Back)
	Arcade.outline(proot, 4)
	local lock = Arcade.make("Frame", {
		Name = "Padlock",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(100, 100),
		BackgroundTransparency = 1,
		Parent = proot,
	}) :: Frame
	icon(lock, { "Padlock", "Lock" })
	local count = Arcade.text(proot, {
		text = FIXTURE.carsOwned .. " / " .. FIXTURE.carsTotal .. " cars",
		role = "Value",
		name = "Count",
		size = 40,
		face = "Cars",
		italic = true,
		xAlign = Enum.TextXAlignment.Left,
	})
	count.Position = UDim2.fromOffset(118, 22)
	count.Size = UDim2.new(1, -128, 0, 50)
	local track = Arcade.make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(122, 84),
		Size = UDim2.new(1, -140, 0, 26),
		BackgroundColor3 = INK,
		Parent = proot,
	}) :: Frame
	Arcade.corner(track, 6)
	Arcade.outline(track, 3)
	local fill = Arcade.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(FIXTURE.carsOwned / FIXTURE.carsTotal, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	}) :: Frame
	Arcade.corner(fill, 6)
	Arcade.make("UIGradient", { Color = A.Face.Cars, Rotation = 90, Parent = fill })
	self._points.plaque = pos(14, 4.6, -6)

	-- 5. First session: START on the ground, chevrons, portal stand-in with its label + marker
	local startPad = WorldKit.part(
		folder,
		"StartText",
		Vector3.new(16, 0.05, 6),
		at(34, 16) * CFrame.Angles(0, math.rad(START_YAW), 0) + Vector3.new(0, 0.06, 0),
		INK
	)
	startPad.Transparency = 1
	local _, sroot = surface(startPad, Enum.NormalId.Top)
	local start = Arcade.text(sroot, { text = "START", role = "Display", name = "Start", size = 200, outline = 10 })
	start.Size = UDim2.fromScale(1, 1)
	start.TextScaled = true
	for i = 0, 3 do
		local z = 8 - i * 7
		for side = -1, 1, 2 do
			-- each arm leans 40 degrees from the travel axis so the pair reads as "^" toward -Z
			local cf = at(34 + side * 1.5, z) * CFrame.Angles(0, math.rad(side * -40), 0)
			WorldKit.part(folder, "ChevronEdge", Vector3.new(1.5, 0.04, 5), cf + Vector3.new(0, 0.07, 0), INK)
			WorldKit.part(
				folder,
				"Chevron",
				Vector3.new(1, 0.06, 4.5),
				cf + Vector3.new(0, 0.12, 0),
				Color3.new(1, 1, 1)
			)
		end
	end
	local portalBase = at(34, -26)
	for _, x in { -6, 6 } do
		WorldKit.part(
			folder,
			"PortalPillar",
			Vector3.new(2, 16, 2),
			portalBase * CFrame.new(x, 8, 0),
			Color3.fromRGB(120, 70, 200)
		)
	end
	WorldKit.part(
		folder,
		"PortalTop",
		Vector3.new(14, 2, 2),
		portalBase * CFrame.new(0, 17, 0),
		Color3.fromRGB(120, 70, 200)
	)
	local panel = WorldKit.part(
		folder,
		"PortalStandIn",
		Vector3.new(10, 15, 0.4),
		portalBase * CFrame.new(0, 8.5, 0),
		Color3.fromRGB(186, 92, 255),
		Enum.Material.Neon
	)
	panel.Transparency = 0.35
	panel:SetAttribute("StandIn", "portal stand-in (test fixture)")
	local portalModel = Instance.new("Model")
	portalModel.Name = "PortalStandInGroup"
	portalModel.Parent = folder
	for _, child in folder:GetChildren() do
		if child.Name == "PortalPillar" or child.Name == "PortalTop" or child.Name == "PortalStandIn" then
			child.Parent = portalModel
		end
	end
	local downtown = DestinationLabel.new(cctx, {
		text = "DOWNTOWN",
		adornee = portalModel,
		preset = "Gold",
		worldHeight = 4,
		verticalOffset = 1.5,
		maxDistance = 300,
	})
	table.insert(self._labels, downtown)
	self._place:Add(function()
		downtown:destroy()
	end)
	local marker = GroundMarker.new(cctx, {
		position = (portalBase * CFrame.new(0, 0, 7)).Position,
		diameter = 9,
		colour = Color3.fromRGB(186, 92, 255),
	})
	table.insert(self._markers, marker)
	self._place:Add(function()
		marker:destroy()
	end)
	self._points.start = pos(34, 0, 16)
	self._points.portal = pos(34, 8, -26)

	-- 6. Plot gate stand-in + arrival sparkle
	local gateModel = Instance.new("Model")
	gateModel.Name = "PlotGateStandIn"
	gateModel:SetAttribute("StandIn", "plot gate stand-in (test fixture)")
	gateModel.Parent = folder
	local gateBase = at(-30, 24)
	for _, x in { -5, 5 } do
		WorldKit.part(
			gateModel,
			"GatePost",
			Vector3.new(1.2, 8, 1.2),
			gateBase * CFrame.new(x, 4, 0),
			Color3.fromRGB(240, 236, 226)
		)
	end
	WorldKit.part(
		gateModel,
		"GateBeam",
		Vector3.new(12, 1.2, 1.2),
		gateBase * CFrame.new(0, 8.4, 0),
		Color3.fromRGB(70, 190, 230)
	)
	local sparkle = ArrivalSparkle.new(cctx, { gate = gateModel, radius = 7 })
	self._sparkle = sparkle
	self._place:Add(function()
		sparkle:destroy()
	end)
	self._points.gate = pos(-30, 4, 24)
end

-- W-01 samples: five destinations in a row, one occluded by a wall
function BaseFixtures.placeDestinations(self: BaseFixtures, origin: CFrame): { any }
	local folder = self:_folderFor()
	local cctx = self:_childCtx()
	local out = {}
	local specs: { { text: string, preset: any, kind: string, x: number } } = {
		{ text = "GARAGE", preset = "Teal", kind = "Garage", x = -48 },
		{ text = "STUNT CIRCUIT", preset = "Orange", kind = "Arch", x = -24 },
		{ text = "DOWNTOWN", preset = "Gold", kind = "Portal", x = 0 },
		{ text = "DUSTY HIGHWAY", preset = "Red", kind = "Portal", x = 24 },
		{ text = "SUMMIT PASS", preset = "White", kind = "Portal", x = 48 },
	}
	for _, spec in specs do
		local base = origin * CFrame.new(spec.x, 0, 0)
		local m = Instance.new("Model")
		m.Name = "Dest_" .. spec.kind .. "_" .. spec.text
		m:SetAttribute("StandIn", "destination stand-in (test fixture)")
		m.Parent = folder
		if spec.kind == "Garage" then
			WorldKit.part(
				m,
				"GarageBlock",
				Vector3.new(16, 10, 10),
				base * CFrame.new(0, 5, 0),
				Color3.fromRGB(70, 190, 230)
			)
			WorldKit.part(m, "Door", Vector3.new(8, 7, 0.3), base * CFrame.new(0, 3.5, 5.1), INK)
		else
			local colour = if spec.kind == "Arch" then Color3.fromRGB(255, 140, 30) else Color3.fromRGB(120, 70, 200)
			for _, x in { -6, 6 } do
				WorldKit.part(m, "Pillar", Vector3.new(2, 14, 2), base * CFrame.new(x, 7, 0), colour)
			end
			WorldKit.part(m, "Top", Vector3.new(14, 2, 2), base * CFrame.new(0, 15, 0), colour)
			local p = WorldKit.part(
				m,
				"Opening",
				Vector3.new(10, 13, 0.4),
				base * CFrame.new(0, 7.5, 0),
				colour:Lerp(Color3.new(1, 1, 1), 0.3),
				Enum.Material.Neon
			)
			p.Transparency = 0.4
		end
		local label = DestinationLabel.new(cctx, {
			text = spec.text,
			adornee = m,
			preset = spec.preset,
			worldHeight = 4,
			verticalOffset = 1.5,
			maxDistance = 320,
		})
		table.insert(self._labels, label)
		self._place:Add(function()
			label:destroy()
		end)
		table.insert(out, label)
		self._points["dest_" .. spec.text] = (base * CFrame.new(0, 10, 0)).Position
	end
	-- occluder: a wall in front of SUMMIT PASS (tall enough to hide its label from the front)
	local wall = WorldKit.part(
		folder,
		"OccluderWall",
		Vector3.new(20, 30, 2),
		origin * CFrame.new(48, 15, 14),
		Color3.fromRGB(200, 190, 176),
		Enum.Material.Concrete
	)
	wall:SetAttribute("StandIn", "occlusion test wall")
	self._points.destinations = (origin * CFrame.new(0, 10, 0)).Position
	return out
end

function BaseFixtures.payLap(self: BaseFixtures, amount: number?): boolean
	local lap, car = self._lapPay, self._lapCar
	if not lap or not car then
		return false
	end
	return lap:pay(car, amount or FIXTURE.lapPay)
end

function BaseFixtures.arrive(self: BaseFixtures): boolean
	local s = self._sparkle
	return s ~= nil and s:play()
end

function BaseFixtures.points(self: BaseFixtures): { [string]: Vector3 }
	return table.clone(self._points)
end

function BaseFixtures.layout(self: BaseFixtures)
	self:_scalePlates()
	if self._lapPay then
		self._lapPay:layout()
	end
	for _, l in self._labels do
		l:layout()
	end
end

function BaseFixtures.setVisible(self: BaseFixtures, on: boolean)
	self._visible = on
	local f = self._folder
	if f then
		f.Parent = if on then self._ctx.world else nil
	end
	for _, l in self._labels do
		l:setVisible(on)
	end
end

function BaseFixtures.getDebugState(self: BaseFixtures): { [string]: any }
	local f = self._folder
	local parts, guis, buttons = 0, 0, 0
	if f then
		for _, d in f:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			elseif d:IsA("LayerCollector") then
				guis += 1
			elseif d:IsA("GuiButton") then
				buttons += 1
			end
		end
	end
	return {
		placed = f ~= nil,
		parts = parts,
		guis = guis,
		buttons = buttons, -- must stay 0: samples have no mechanics
		labels = #self._labels,
		markers = #self._markers,
		sparkle = self._sparkle and self._sparkle:getDebugState(),
		lapPay = self._lapPay and self._lapPay:getDebugState(),
	}
end

function BaseFixtures.destroy(self: BaseFixtures)
	self._trove:Destroy()
end

return BaseFixtures
