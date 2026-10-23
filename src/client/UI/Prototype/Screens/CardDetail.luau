--!strict
-- CardDetail: the landscape detail view of one collectible card (Lane 3 preview, Round 2, R2-T2). Presentation
-- only: it shows the supplied car and card data (TradingCard.fineRows) and never grants, buys or equips anything.
--
--   local detail = CardDetail.new(ctx, { onDrive = function(car) end? })
--   detail:open(car, info?, returnTo?)   detail:close()   detail:isOpen()
--   detail:layout()   detail:setVisible(on)   detail:destroy()   detail:getDebugState()
--
-- Layout: the card on the left (the full reward card on wide screens, the compact card on short phone landscape),
-- the fine print on the right in a SCROLLING area (stats, quirk, finishes, flavour, footer), and a FIXED action
-- bar underneath (BACK, DRIVE). The scrolling area ends above the bar and clips its content, so nothing can scroll
-- behind the buttons (the earlier Revolution 6 clipping case); the debug state reports the gap. Back (Escape or
-- gamepad B) and CLOSE close it; the gamepad selection starts on BACK and returns to where it was.
-- An unowned card shows "?" for stats and quirk and leaks no finishes, number or date (TradingCard.fineRows).

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Overlay = require(script.Parent.Overlay)
local Style = require(script.Parent.Style)
local TradingCard = require(Prototype.Cards.TradingCard)

local make = Arcade.make

local CardDetail = {}

export type Options = { onDrive: ((TradingCard.CarRef) -> ())? }

local ROW_H = 46

function CardDetail.new(ctx: Overlay.Ctx, options: Options?)
	local opts: Options = options or {}
	local overlay = Overlay.new(ctx, { name = "CardDetail" })
	local trove = overlay.trove
	local content = overlay.content
	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header =
		Style.header(panel, { fill = "Garage", title = "COLLECTIBLE CARD", icon = "GarageBook", height = 60 })
	local closeButton = Overlay.closeButton(panel, function() end)
	trove:Add(closeButton.trove)
	closeButton.root.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.root.ZIndex = 12

	local self: any = {}
	self._open = false
	self._car = nil :: any
	self._info = {} :: any
	self._drives = 0
	self._card = nil :: any
	self._rows = {} :: { any }
	self._bars = 0

	local cardArea: Frame = make("Frame", { Name = "CardArea", BackgroundTransparency = 1, ZIndex = 4, Parent = panel })
	local rightWell = Style.well(panel, "Details", 4)
	local scroll = Style.scroll(rightWell, "Scroll", 5)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 12),
		Parent = scroll,
	})
	-- the FIXED action bar
	local bar: Frame = make("Frame", { Name = "Actions", BackgroundTransparency = 1, ZIndex = 8, Parent = panel })
	local backButton = Arcade.button(bar, {
		name = "Back",
		label = "BACK",
		fill = "Garage",
		size = "Custom",
		width = 160,
		height = 56,
		icon = "Close",
		sound = "Close",
		onActivate = function()
			self:close()
		end,
	})
	trove:Add(backButton.trove)
	backButton.root.AnchorPoint = Vector2.new(0, 0.5)
	backButton.root.Position = UDim2.fromScale(0, 0.5)
	backButton.root.ZIndex = 12
	local driveButton = Arcade.button(bar, {
		name = "Drive",
		label = "DRIVE",
		fill = "Retry",
		size = "Custom",
		width = 196,
		height = 56,
		pattern = true,
		cooldown = 0.6,
		onActivate = function()
			local car = self._car
			if car and car.owned ~= false and opts.onDrive then
				self._drives += 1
				opts.onDrive(car)
			end
		end,
	})
	trove:Add(driveButton.trove)
	driveButton.root.AnchorPoint = Vector2.new(1, 0.5)
	driveButton.root.Position = UDim2.fromScale(1, 0.5)
	driveButton.root.ZIndex = 12

	local function clearRows()
		for _, r in self._rows do
			r:Destroy()
		end
		table.clear(self._rows)
	end

	local function addRow(height: number?, order: number): Frame
		local row = Style.well(scroll, "Row" .. order, 6)
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, height or ROW_H)
		table.insert(self._rows, row)
		return row
	end

	local function renderRows()
		clearRows()
		self._bars = 0
		local car, info = self._car, self._info
		if not car then
			return
		end
		local rows = TradingCard.fineRows(car, info)
		for i, r in rows do
			if r.kind == "Stat" then
				local hasBar = r.bar ~= nil
				local row = addRow(if hasBar or r.note then 64 else ROW_H, i)
				local title = Style.text(row, r.title or "", "Label", { size = 18, z = 7, name = "Title" })
				title.Position = UDim2.fromOffset(8, 4)
				title.Size = UDim2.new(0.5, -8, 0, 26)
				local value = Style.text(
					row,
					r.value or "",
					"Label",
					{ size = 18, z = 7, name = "Value", xAlign = Enum.TextXAlignment.Right }
				)
				value.Position = UDim2.new(0.45, 0, 0, 4)
				value.Size = UDim2.new(0.55, -8, 0, 26)
				if hasBar then
					self._bars += 1
					local track = make("Frame", {
						Name = "Bar",
						Position = UDim2.fromOffset(10, 32),
						Size = UDim2.new(1, -20, 0, 8),
						BackgroundColor3 = Style.Ink,
						ZIndex = 7,
						Parent = row,
					})
					Arcade.corner(track, 4)
					local fill = make("Frame", {
						Name = "Fill",
						Size = UDim2.fromScale(math.clamp(r.bar :: number, 0, 1), 1),
						BackgroundColor3 = Color3.fromRGB(84, 220, 120),
						ZIndex = 8,
						Parent = track,
					})
					Arcade.corner(fill, 4)
				end
				if r.note then
					local note = Style.text(row, r.note, "Small", { z = 7, name = "Note", colour = Style.TextSoft })
					note.Position = UDim2.new(0, 8, 1, -24)
					note.Size = UDim2.new(1, -16, 0, 20)
				end
			elseif r.kind == "Quirk" then
				local row = addRow(66, i)
				local icon: Frame = make("Frame", {
					Name = "Icon",
					Position = UDim2.fromOffset(8, 12),
					Size = UDim2.fromOffset(40, 40),
					BackgroundTransparency = 1,
					ZIndex = 7,
					Parent = row,
				})
				Arcade.icon(icon, "Star")
				local title = Style.text(row, r.title or "", "Label", { size = 20, z = 7, name = "Quirk" })
				title.Position = UDim2.fromOffset(56, 6)
				title.Size = UDim2.new(1, -64, 0, 28)
				local line = Style.text(row, r.text or "", "Small", { z = 7, name = "Line", colour = Style.TextSoft })
				line.Position = UDim2.fromOffset(56, 36)
				line.Size = UDim2.new(1, -64, 0, 24)
			elseif r.kind == "Variants" then
				local row = addRow(58, i)
				local label = Style.text(row, "Finishes", "Small", { z = 7, name = "Label", colour = Style.TextSoft })
				label.Position = UDim2.fromOffset(8, 2)
				label.Size = UDim2.new(1, -16, 0, 20)
				local chips = r.chips or {}
				for k, chip in chips do
					local c = make("Frame", {
						Name = "Chip" .. chip.label,
						Position = UDim2.new((k - 1) / #chips, 6, 0, 24),
						Size = UDim2.new(1 / #chips, -8, 0, 28),
						BackgroundColor3 = if chip.state == "Owned"
							then Color3.fromRGB(244, 196, 60)
							elseif chip.state == "Unknown" then Color3.fromRGB(52, 66, 116)
							else Color3.fromRGB(26, 36, 78),
						ZIndex = 7,
						Parent = row,
					})
					Arcade.corner(c, 6)
					Arcade.outline(c, "Minor")
					local text = chip.label
						.. (if chip.state == "Owned" then "" elseif chip.state == "Unknown" then " ?" else " -")
					local t =
						Style.text(c, text, "Small", { z = 8, name = "Text", xAlign = Enum.TextXAlignment.Center })
					t.Size = UDim2.fromScale(1, 1)
				end
			elseif r.kind == "Flavour" then
				local row = addRow(nil, i)
				row.AutomaticSize = Enum.AutomaticSize.Y
				row.Size = UDim2.fromScale(1, 0)
				make("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
					Parent = row,
				})
				local p = Style.paragraph(row, r.text or "", 16, true, 7)
				p.Name = "Flavour"
			elseif r.kind == "Footer" then
				local row = addRow(44, i)
				local text = r.text
				local number = r.value
				local world = TradingCard.Worlds[r.world or ""]
				local worldName = if world then world.name else "World unknown"
				local line = worldName
					.. (if number then "   " .. number else "")
					.. (if text then "   " .. text else "")
				local t = Style.text(row, line, "Small", { z = 7, name = "Footer", colour = Style.TextSoft })
				t.Size = UDim2.new(1, -16, 1, 0)
				t.Position = UDim2.fromOffset(8, 0)
			end
		end
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local short = kind ~= "Wide"
		local pw, ph
		if kind == "Wide" then
			pw, ph = math.min(ds.X - 32, 820), math.min(ds.Y - 24, 560)
		else
			pw, ph = ds.X - 24, ds.Y - 18
		end
		shell.root.Size = UDim2.fromOffset(pw, ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		local headH = if short then 50 else 60
		header.setHeight(headH)
		closeButton.root.Position = UDim2.new(1, -8, 0, headH / 2)
		local titleLeft = header.title.Position.X.Offset
		local rightUsed = Overlay.CloseWidth + 18
		header.title.AnchorPoint = Vector2.new(0, 0.5)
		header.title.Position = UDim2.new(0, titleLeft, 0.5, 0)
		header.title.Size = UDim2.new(1, -titleLeft - rightUsed, 0, if short then 28 else 36)
		local barH = if short then 62 else 72
		local bodyY = headH + 10
		local barY = ph - barH - 6
		local bodyH = barY - bodyY - 6
		-- the card (left): the full reward card when it fits, else the compact card
		local reward = bodyH >= 330
		local card = self._card
		if card and card._variant ~= (if reward then "Reward" else "Compact") then
			card:destroy()
			self._card = nil
			card = nil
		end
		if not card and self._car then
			local made =
				TradingCard.new(cardArea, self._car, self._info, { variant = if reward then "Reward" else "Compact" })
			self._card = made
			card = made
		end
		local cardW = if reward then 200 else 128
		local leftW = cardW + 28
		cardArea.Position = UDim2.fromOffset(10, bodyY)
		cardArea.Size = UDim2.fromOffset(leftW, bodyH)
		if card then
			card.root.AnchorPoint = Vector2.new(0.5, 0)
			card.root.Position = UDim2.fromScale(0.5, 0)
		end
		rightWell.Position = UDim2.fromOffset(10 + leftW + 6, bodyY)
		rightWell.Size = UDim2.fromOffset(pw - leftW - 36, bodyH)
		scroll.Size = UDim2.fromScale(1, 1)
		bar.Position = UDim2.fromOffset(14, barY)
		bar.Size = UDim2.fromOffset(pw - 28, barH)
		backButton.root.Size = UDim2.fromOffset(if short then 140 else 160, 56)
	end

	overlay:setBack(function()
		self:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	function self.open(me: any, car: TradingCard.CarRef, info: TradingCard.Info?, returnTo: GuiObject?)
		me._car = car
		me._info = info or {}
		if me._card then
			me._card:setCar(car)
			me._card:setInfo(me._info)
		end
		renderRows()
		layoutNow()
		if me._card then
			me._card:setCar(car)
			me._card:setInfo(me._info)
		end
		driveButton.setEnabled(car.owned ~= false)
		scroll.CanvasPosition = Vector2.zero
		overlay:open(backButton.body, returnTo)
		me._open = true
	end
	function self.close(me: any)
		if not overlay:isOpen() then
			return
		end
		overlay:close()
		me._open = false
	end
	function self.isOpen(_me: any): boolean
		return overlay:isOpen()
	end
	function self.layout(_me: any)
		layoutNow()
	end
	function self.setVisible(_me: any, on: boolean)
		overlay.root.Visible = on and overlay:isOpen()
	end
	function self.destroy(me: any)
		if me._card then
			me._card:destroy()
		end
		overlay:destroy()
	end
	function self.getDebugState(me: any): { [string]: any }
		local scrollBottom = scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y
		local barTop = bar.AbsolutePosition.Y
		return {
			open = overlay:isOpen(),
			kind = overlay:kind(),
			carId = me._car and me._car.id,
			variant = me._card and me._card._variant,
			rows = #me._rows,
			bars = me._bars,
			canvasHeight = scroll.AbsoluteCanvasSize.Y,
			scrollHeight = scroll.AbsoluteSize.Y,
			-- the scrolling area must end above the fixed bar: nothing scrolls behind the buttons
			gapToBar = barTop - scrollBottom,
			scrollsBehindBar = scrollBottom > barTop + 0.5,
			drives = me._drives,
			driveEnabled = me._car ~= nil and me._car.owned ~= false,
			card = me._card and me._card:getDebugState(),
			instances = #overlay.root:GetDescendants(),
		}
	end

	layoutNow()
	return self
end

return CardDetail
