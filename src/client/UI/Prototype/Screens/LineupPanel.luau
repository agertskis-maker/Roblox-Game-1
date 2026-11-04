--!strict
-- LineupPanel: "YOUR RACEWAY", which car sits in which parking spot (Lane 3, Round 5 L-04; reference R5-IMG-01, drawn in the
-- game's own navy panel style like the Car stall and the Garage). Built straight in Studio from the reference (R5-S07: no new
-- Figma frame this round). Every change is a request to the server (SetLineupSlot, the agreed remote): the panel shows
-- "Parking..." until the server's Lineup attribute changes, or shakes the spot and shows the server's short reason when it
-- refuses. The spots are always drawn from the server's attribute, never from the panel's own idea of them.
--
-- Spots: the plot's real count (bought spots plus the Expanded Paddock pass), in order. A filled spot shows the car, its name,
-- its rarity (word and frame colour) and its Lap Pay (PREVIEW); tapped, it offers SWAP and REMOVE. An empty spot shows "+" and
-- PICK A CAR. One more spot, locked, says GET MORE SPOTS and opens the parking panel. The pick list holds your cars that are
-- not parked, best Lap Pay first (ties by name). A car goes into the first free spot (the Lineup has no gaps).
--
--   local p = LineupPanel.new(ctx, { onMoreSpots = fn?, onChanged = fn(lineup)? })
--   p:open({ highlight = carId? })   p:close()   p:isOpen()   p:destroy()   p:getDebugState()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local RealCar = require(Prototype.RealCar)
local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local LiveData = require(ReplicatedStorage.Shared.UI.LiveData)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local make = CarKit.make

local LineupPanel = {}

export type Options = {
	onMoreSpots: (() -> ())?,
	onChanged: ((lineup: { string }) -> ())?,
}

local PENDING_TIMEOUT = 4 -- seconds before an unanswered request is given up (the panel stays usable)

function LineupPanel.new(ctx: Overlay.Ctx, options: Options?): { [string]: any }
	local opts: Options = options or {}
	local overlay = Overlay.new(ctx, { name = "LineupPanel", dimTransparency = 0.5, slide = false })
	local trove = overlay.trove
	local buildTrove = trove:Extend()
	local liveTrove = trove:Extend()
	local player = Players.LocalPlayer
	local isOpen = false
	local selected: { slot: number, carId: string?, mode: string }? = nil -- mode "pick" (empty spot or SWAP) or "menu"
	local pending: { slot: number, carId: string?, at: number }? = nil
	local reason: string? = nil
	local shakeSlot: number? = nil
	local highlight: string? = nil
	local builtShort = false -- whether the locked spot was drawn as "can't afford yet"
	local self: { [string]: any } = {}

	local function plot(): Instance?
		local index = player:GetAttribute(LiveData.Attributes.homePlot)
		local root = workspace:FindFirstChild("Lane3_IslandPreview")
		local plots = root and root:FindFirstChild("Island") and root.Island:FindFirstChild("Plots")
		return if type(index) == "number" and plots then plots:FindFirstChild(string.format("Plot%02d", index)) else nil
	end

	local function spots(): (number, number)
		local p = plot()
		local n = p and p:GetAttribute("ParkingSpots")
		local expanded = p and p:GetAttribute("ExpandedPaddock") == true
		local max = EconomyPreview.MaxSpots + (if expanded then EconomyPreview.ExpandedPaddockSpots else 0)
		return if type(n) == "number" then n else EconomyPreview.StartSpots, max
	end

	local function level(): number
		local p = plot()
		local l = p and p:GetAttribute("SpeedwayLevel")
		return if type(l) == "number" then l else 1
	end

	local function lapPayOf(carId: string): number
		local car = RosterFixtures.byId(carId)
		local save = LiveData.cars()[carId]
		if not car then
			return 0
		end
		return math.floor(EconomyPreview.lapPay(car.rarity, if save then save.Edition else 1, level()))
	end

	local function send(slot: number, carId: string?)
		if pending then
			return -- one request at a time: a second tap while pending sends nothing
		end
		local remote = LiveData.remote(LiveData.Remotes.SetLineupSlot)
		if not remote then
			reason = "Parking works in the beta place."
			self:refresh()
			return
		end
		pending = { slot = slot, carId = carId, at = os.clock() }
		reason = nil
		selected = nil
		remote:FireServer(slot, carId)
		self:refresh()
		local me = pending
		task.delay(PENDING_TIMEOUT, function()
			if pending == me then
				pending = nil
				reason = "No answer yet. Try again."
				self:refresh()
			end
		end)
	end

	local function chip(parent: Instance, text: string, colour: Color3, at: UDim2, size: UDim2, z: number)
		local f = make("Frame", {
			Name = "Chip",
			BackgroundColor3 = colour,
			Position = at,
			Size = size,
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = z,
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		CarKit.text(f, text, 14, { align = Enum.TextXAlignment.Center, size = UDim2.fromScale(1, 1), z = z + 1 })
		return f
	end

	local function carCell(parent: Instance, carId: string, w: number, h: number, z: number, order: number): TextButton
		local car = RosterFixtures.byId(carId)
		local rarityName = if car then car.rarity else "Common"
		local rarity = (CarKit.Rarity :: any)[rarityName] or CarKit.Rarity.Common
		local cell = make("TextButton", {
			Name = "Car_" .. carId,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(18, 26, 52),
			Size = UDim2.fromOffset(w, h),
			LayoutOrder = order,
			ZIndex = z,
			Selectable = true,
		}, parent) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, cell)
		make("UIStroke", { Thickness = 3, Color = rarity, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cell)
		CarKit.title(cell, string.upper(if car then car.name else carId), 18, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -8, 0, 22),
			position = UDim2.fromOffset(4, 4),
			z = z + 2,
			shadow = false,
			stroke = 1.5,
		})
		chip(
			cell,
			string.upper(rarityName),
			rarity:Lerp(CarKit.Ink, 0.35),
			UDim2.new(0.5, 0, 0, 28),
			UDim2.new(0.7, 0, 0, 20),
			z + 2
		)
		local thumb = make("Frame", {
			Name = "Thumb",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 50),
			Size = UDim2.new(1, -8, 1, -50 - 34),
			ZIndex = z + 1,
		}, cell) :: Frame
		task.defer(function()
			if thumb.Parent then
				RealCar.thumb(thumb, carId)
			end
		end)
		chip(
			cell,
			Format.cash(lapPayOf(carId)) .. " / LAP",
			CarKit.GreenDeep,
			UDim2.new(0.5, 0, 1, -30),
			UDim2.new(0.86, 0, 0, 24),
			z + 2
		)
		return cell
	end

	local function shake(frame: GuiObject)
		if Motion.reduced() then
			return -- a steady red outline says it instead
		end
		local x = frame.Position
		task.spawn(function()
			for _, dx in { -8, 8, -6, 6, -3, 0 } do
				frame.Position = x + UDim2.fromOffset(dx, 0)
				task.wait(0.04)
			end
			frame.Position = x
		end)
	end

	local function build()
		buildTrove:Clean()
		CarKit.setStrokeScale(ctx.screen:uiScale())
		local D = overlay:designSize()
		local w, h = math.min(D.X - 24, 940), math.min(D.Y - 16, 540)
		local panel = buildTrove:Add(CarKit.board(overlay.content, {
			size = UDim2.fromOffset(w, h),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			z = 2,
			radius = 16,
			bolts = true,
			name = "Panel",
		})) :: Frame
		CarKit.title(panel, "YOUR RACEWAY", 40, {
			position = UDim2.fromOffset(16, 4),
			size = UDim2.new(1, -80, 0, 46),
			top = CarKit.White,
			bottom = CarKit.Gold,
			z = 5,
		})
		local close = make("ImageButton", {
			Name = "Close",
			BackgroundTransparency = 1,
			Image = "",
			Size = UDim2.fromOffset(48, 48),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 4),
			ZIndex = 6,
		}, panel) :: ImageButton
		CarKit.slot(close, "close", 48, { position = UDim2.fromScale(0.5, 0.5), z = 6, fallback = "Close" })
		close.Activated:Connect(function()
			self:close()
		end)

		local lineup = LiveData.lineup()
		local owned = LiveData.cars()
		local count, max = spots()
		local live = LiveData.active() and LiveData.hasCars()

		-- the spots
		local rowY = 54
		local rowH = math.floor((h - rowY) * 0.5)
		local row = make("ScrollingFrame", {
			Name = "Spots",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, rowY),
			Size = UDim2.new(1, -24, 0, rowH),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ZIndex = 3,
			Selectable = false,
		}, panel) :: ScrollingFrame
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}, row)
		local cellH = rowH - 10
		local cellW = math.floor(math.min(cellH * 0.82, (w - 24 - 40) / 5))
		local cells: { [number]: GuiObject } = {}
		for slot = 1, count do
			local carId = lineup[slot]
			local isPending = pending ~= nil and pending.slot == slot
			local cell: GuiObject
			if carId then
				local b = carCell(row, carId, cellW, cellH, 4, slot)
				cell = b
				b.Activated:Connect(function()
					if pending then
						return
					end
					selected = { slot = slot, carId = carId, mode = "menu" }
					reason = nil
					self:refresh()
				end)
				if selected and selected.slot == slot and selected.mode == "pick" then
					-- the spot a SWAP will change stays marked while the player picks
					make("UIStroke", { Thickness = 4, Color = CarKit.Yellow }, b)
				end
				if selected and selected.slot == slot and selected.mode == "menu" then
					make("UIStroke", { Thickness = 4, Color = CarKit.White }, b)
					local half = math.floor((cellW - 18) / 2)
					CarKit.button(b, {
						text = "SWAP",
						tone = "Orange",
						px = 15,
						size = UDim2.fromOffset(half, 44),
						position = UDim2.new(0, 6, 1, -6),
						anchor = Vector2.new(0, 1),
						z = 9,
						name = "Swap",
						onPress = function()
							selected = { slot = slot, carId = carId, mode = "pick" }
							self:refresh()
						end,
					})
					CarKit.button(b, {
						text = "REMOVE",
						tone = "Navy",
						px = 15,
						size = UDim2.fromOffset(half, 44),
						position = UDim2.new(1, -6, 1, -6),
						anchor = Vector2.new(1, 1),
						z = 9,
						name = "Remove",
						onPress = function()
							send(slot, nil)
						end,
					})
				end
			else
				local b = make("TextButton", {
					Name = "Empty_" .. slot,
					Text = "",
					AutoButtonColor = false,
					BackgroundColor3 = Color3.fromRGB(14, 22, 46),
					Size = UDim2.fromOffset(cellW, cellH),
					LayoutOrder = slot,
					ZIndex = 4,
				}, row) :: TextButton
				cell = b
				make("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
				make("UIStroke", { Thickness = 3, Color = CarKit.ChromeBottom }, b)
				CarKit.title(b, "+", 70, {
					align = Enum.TextXAlignment.Center,
					size = UDim2.fromScale(1, 0.55),
					position = UDim2.fromScale(0, 0.08),
					color = CarKit.Orange,
					z = 5,
				})
				CarKit.button(b, {
					text = if isPending then "PARKING..." else "PICK A CAR",
					tone = "Orange",
					px = 15,
					size = UDim2.new(1, -12, 0, 44),
					position = UDim2.new(0.5, 0, 1, -6),
					anchor = Vector2.new(0.5, 1),
					z = 6,
					name = "Pick",
					onPress = function()
						if pending then
							return
						end
						selected = { slot = #lineup + 1, carId = nil, mode = "pick" }
						self:refresh()
					end,
				})
			end
			if isPending then
				CarKit.text(cell, "PARKING...", 16, {
					align = Enum.TextXAlignment.Center,
					size = UDim2.new(1, 0, 0, 22),
					position = UDim2.new(0, 0, 0.5, -11),
					color = CarKit.Yellow,
					z = 12,
					name = "Pending",
				})
			end
			if shakeSlot == slot then
				make("UIStroke", { Thickness = 4, Color = CarKit.Red }, cell)
				shake(cell)
			end
			cells[slot] = cell
		end
		if count < max then
			local lock = make("TextButton", {
				Name = "Locked",
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(14, 22, 46),
				Size = UDim2.fromOffset(cellW, cellH),
				LayoutOrder = count + 1,
				ZIndex = 4,
			}, row) :: TextButton
			make("UICorner", { CornerRadius = UDim.new(0, 12) }, lock)
			make("UIStroke", { Thickness = 3, Color = CarKit.ChromeBottom }, lock)
			CarKit.slot(lock, "lock", 64, { position = UDim2.fromScale(0.5, 0.3), z = 5, fallback = "Lock" })
			-- the next spot is sold right here (BuyParkingSpot: the server prices it and charges Cash); past the 15 that can be
			-- bought, GET MORE SPOTS opens the Shop's Expanded Paddock pass. The price is the PREVIEW number the server uses.
			local p = plot()
			local expanded = p ~= nil and p:GetAttribute("ExpandedPaddock") == true
			local bought = count - (if expanded then EconomyPreview.ExpandedPaddockSpots else 0)
			local price = EconomyPreview.spotPrice(bought + 1)
			local cash = LiveData.cash()
			if price and live then
				local short = if cash then math.max(0, price - cash) else 0
				builtShort = short > 0
				CarKit.text(lock, if short > 0 then Format.cash(short) .. " more" else "NEXT SPOT", 15, {
					align = Enum.TextXAlignment.Center,
					size = UDim2.new(1, -8, 0, 20),
					position = UDim2.new(0, 4, 0.52, 0),
					color = if short > 0 then CarKit.Soft else CarKit.White,
					z = 6,
					name = "Need",
				})
				local buy = CarKit.button(lock, {
					text = "BUY " .. Format.cash(price),
					tone = if short > 0 then "Grey" else "Green",
					px = 15,
					size = UDim2.new(1, -12, 0, 48),
					position = UDim2.new(0.5, 0, 1, -6),
					anchor = Vector2.new(0.5, 1),
					z = 6,
					name = "BuySpot",
					onPress = function()
						local remote = LiveData.remote(LiveData.Remotes.BuyParkingSpot)
						if remote and not pending then
							reason = nil
							remote:FireServer()
						end
					end,
				})
				if short > 0 then
					buy.setEnabled(false)
				end
			else
				CarKit.button(lock, {
					text = "GET MORE SPOTS",
					tone = "Orange",
					px = 14,
					size = UDim2.new(1, -12, 0, 48),
					position = UDim2.new(0.5, 0, 1, -6),
					anchor = Vector2.new(0.5, 1),
					z = 6,
					name = "MoreSpots",
					onPress = function()
						self:close()
						if opts.onMoreSpots then
							opts.onMoreSpots()
						end
					end,
				})
			end
		end

		-- the pick list, or what to do
		local listY = rowY + rowH + 6
		local listH = h - listY - 40
		local caption = if selected and selected.mode == "pick"
			then (if selected.carId then "Pick a car to swap in" else "Pick a car to park")
			else "Tap a spot to park, swap or remove a car"
		CarKit.text(panel, caption, 16, {
			position = UDim2.fromOffset(16, listY),
			size = UDim2.new(1, -32, 0, 20),
			color = CarKit.Soft,
			z = 5,
			name = "Caption",
		})
		local list = make("ScrollingFrame", {
			Name = "Pick",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, listY + 22),
			Size = UDim2.new(1, -24, 0, listH - 22),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ZIndex = 3,
			Selectable = false,
		}, panel) :: ScrollingFrame
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, list)
		local free = {}
		for id in owned do
			if not table.find(lineup, id) and RosterFixtures.byId(id) then
				table.insert(free, id)
			end
		end
		table.sort(free, function(a, b)
			local pa, pb = lapPayOf(a), lapPayOf(b)
			if pa ~= pb then
				return pa > pb
			end
			return a < b
		end)
		local pickH = listH - 26
		local pickW = math.floor(pickH * 0.9)
		if not live then
			CarKit.text(list, "Parking works in the beta place.", 18, {
				size = UDim2.fromOffset(w - 40, 40),
				color = CarKit.Soft,
				z = 5,
			})
		elseif #free == 0 then
			CarKit.text(list, "Every car you own is parked. Catch more on a run!", 18, {
				size = UDim2.fromOffset(w - 40, 40),
				color = CarKit.Soft,
				z = 5,
				name = "NoneFree",
			})
		end
		for i, id in free do
			local b = carCell(list, id, pickW, pickH, 4, i)
			if highlight == id then
				local ring = make("UIStroke", { Thickness = 5, Color = CarKit.Yellow }, b)
				if not Motion.reduced() then
					local t = TweenService:Create(
						ring,
						TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ Transparency = 0.6 }
					)
					t:Play()
					buildTrove:Add(t)
				end
			end
			b.Activated:Connect(function()
				if pending then
					return
				end
				local slot = if selected and selected.mode == "pick" then selected.slot else #lineup + 1
				if slot > count then
					reason = "Get more spots first."
					shakeSlot = nil
					self:refresh()
					return
				end
				send(slot, id)
			end)
		end

		-- the server's reason, or the PREVIEW note
		CarKit.text(panel, reason or "Lap Pay is a PREVIEW number.", 16, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -24, 0, 24),
			position = UDim2.new(0, 12, 1, -32),
			color = if reason then CarKit.Yellow else CarKit.Soft,
			z = 5,
			name = "Reason",
		})
		shakeSlot = nil
	end

	function self.refresh(_self: any)
		if isOpen then
			build()
		end
	end

	local function watchLive()
		liveTrove:Clean()
		liveTrove:Add(LiveData.changed(player, "lineup", function()
			pending = nil
			if opts.onChanged then
				opts.onChanged(LiveData.lineup())
			end
			self:refresh()
		end))
		liveTrove:Add(LiveData.changed(player, "cars", function()
			self:refresh()
		end))
		-- a bought spot (the plot's count) and Cash change what the locked spot says
		local p = plot()
		if p then
			liveTrove:Add(p:GetAttributeChangedSignal("ParkingSpots"):Connect(function()
				self:refresh()
			end))
		end
		liveTrove:Add(LiveData.changed(player, "cash", function()
			local p2 = plot()
			local count = spots()
			local expanded = p2 ~= nil and p2:GetAttribute("ExpandedPaddock") == true
			local price =
				EconomyPreview.spotPrice(count - (if expanded then EconomyPreview.ExpandedPaddockSpots else 0) + 1)
			local short = price ~= nil and (LiveData.cash() or 0) < price
			if short ~= builtShort and not pending then
				self:refresh()
			end
		end))
		local result = LiveData.onResult(function(what: string, ok: boolean, why: string?)
			if what == "BuyParkingSpot" and not ok then
				reason = why or "Not now."
				self:refresh()
				return
			end
			if what ~= "lineup" then
				return
			end
			if not ok then
				shakeSlot = if pending then pending.slot else nil
				pending = nil
				reason = why or "Not now."
				self:refresh()
			end
		end)
		if result then
			liveTrove:Add(result)
		end
	end

	function self.open(_self: any, o: { highlight: string? }?)
		highlight = o and o.highlight or nil
		if isOpen then
			build()
			return
		end
		isOpen = true
		selected, reason = nil, nil
		overlay:setBack(function()
			self:close()
		end)
		overlay:applyScale()
		overlay:open(nil, nil)
		watchLive()
		build()
	end

	function self.close(_self: any)
		if not isOpen then
			return
		end
		isOpen = false
		highlight = nil
		liveTrove:Clean()
		buildTrove:Clean()
		overlay:close()
	end

	function self.isOpen(_self: any): boolean
		return isOpen
	end

	function self.getDebugState(_self: any): { [string]: any }
		local count = spots()
		return {
			open = isOpen,
			lineup = LiveData.lineup(),
			spots = count,
			pending = if pending then pending.slot else nil,
			selected = if selected then selected.slot else nil,
			mode = if selected then selected.mode else nil,
			reason = reason,
		}
	end

	function self.destroy(_self: any)
		trove:Destroy()
	end

	return self
end

return LineupPanel
