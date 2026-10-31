--!strict
-- ShopMock: a calm Shop mock drawn over gameplay (Lane 3 HUD prototype, PREVIEW only).
-- Nothing here can be bought: there is no MarketplaceService call, no prompt and no grant.
-- HUD rebuild (2026-10-22, H-15): restyled into the arcade family (deep panel, a STATIC rainbow
-- header band, dark pass wells with kit icon tiles, white outlined text; no cream).
--
--   local shop = ShopMock.new(ctx, { onClose = fn? })
--   shop:open(returnTo?)  shop:close()  shop:isOpen()
--   shop:layout()  shop:setVisible(on)  shop:destroy()  shop:getDebugState()
--
-- Content: exactly the three passes listed in outline v2.2 section 12 ("Delegated pass set,
-- prices Open"): Double Lap Pay, Expanded Paddock, VIP. They are delegated choices in the
-- outline, not separately approved by the owner: each card carries the harness caption "Pass
-- concept (not approved)" (PreviewCaption) and "Robux price pending" (no invented prices).
-- Calm by rule: no countdowns, no "limited", no "best value", no flashing, no idle animation
-- (the header rainbow does not drift here), and no badges: this mock has no free fixture claim,
-- so nothing earns a badge.

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)

local make = Arcade.make

local ShopMock = {}

export type Pass = {
	id: string,
	name: string,
	icon: string,
	does: string,
	never: string,
	fill: Arcade.FillName,
}

-- From outline v2.2 section 12 (wording shortened for a child-friendly card).
ShopMock.Passes = {
	{
		id = "double-lap-pay",
		name = "Double Lap Pay",
		icon = "Track",
		does = "Your cars earn 2x Lap Pay, online and offline.",
		never = "Never changes race stats, Heat or Keys.",
		fill = "Green",
	},
	{
		id = "expanded-paddock",
		name = "Expanded Paddock",
		icon = "Garage",
		does = "+3 Slots above the normal maximum, with an extra pit garage.",
		never = "Never changes how much each car earns.",
		fill = "Garage",
	},
	{
		id = "vip",
		name = "VIP",
		icon = "Star",
		does = "VIP Pearl paints, a name tag, a lounge on your plot, and a 12-hour offline cap.",
		never = "No advantage in runs or races.",
		fill = "Gold",
	},
} :: { Pass }

ShopMock.ConceptLabel = "Pass concept (not approved)"
ShopMock.PriceLabel = "Robux price pending"

export type Options = {
	onClose: (() -> ())?,
}

export type DebugState = {
	open: boolean,
	kind: string,
	passes: number,
	prices: { string },
	labels: { string },
	badges: number,
	instances: number,
}

export type Shop = {
	root: Frame,
	layout: (self: Shop) -> (),
	setVisible: (self: Shop, on: boolean) -> (),
	open: (self: Shop, returnTo: GuiObject?) -> (),
	close: (self: Shop) -> (),
	isOpen: (self: Shop) -> boolean,
	destroy: (self: Shop) -> (),
	getDebugState: (self: Shop) -> DebugState,
}

function ShopMock.new(ctx: Overlay.Ctx, options: Options?): Shop
	local opts: Options = options or {}
	local shop: Shop

	local overlay = Overlay.new(ctx, { name = "ShopMock" })
	local trove = overlay.trove
	local content = overlay.content
	local itemTrove = trove:Extend()

	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header = Style.header(panel, { fill = "Rainbow", title = "SHOP", icon = "Shop" })
	local note = Overlay.text(panel, "Preview: nothing can be bought here.", 16, Style.TextSoft, nil, 6)
	note:SetAttribute("PreviewCaption", true) -- harness caption
	local closeButton = Overlay.closeButton(panel, function()
		shop:close()
	end)
	trove:Add(closeButton.trove)
	closeButton.root.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.root.ZIndex = 12

	local list = Style.scroll(panel, "Passes", 5)
	local listLayout: UIListLayout = make("UIListLayout", {
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = list,
	})
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = list,
	})

	local priceLabels: { TextLabel } = {}
	local conceptLabels: { TextLabel } = {}

	-- One pass card. "column" = a portrait card (desktop, tablet, phone portrait);
	-- "row" = icon | text | price (phone landscape, where height is short).
	local function buildItem(pass: Pass, order: number, width: number, row: boolean)
		local card = Style.well(list, "Pass_" .. pass.id, 6)
		itemTrove:Add(card)
		card.Size = UDim2.fromOffset(width, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.LayoutOrder = order
		make("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			Parent = card,
		})
		-- kit icon tile: the pass fill, dark boundary, gloss
		local tile: Frame = make("Frame", {
			Name = "IconTile",
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = card,
		})
		Arcade.corner(tile, 7)
		Arcade.outline(tile, "Button")
		make("UIGradient", { Color = PreviewTokens.Arcade.Fill[pass.fill], Rotation = 90, Parent = tile })
		Arcade.gloss(tile)
		local iconHolder: Frame = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(48, 48),
			BackgroundTransparency = 1,
			ZIndex = 9,
			Parent = tile,
		})
		Arcade.icon(iconHolder, pass.icon)

		local textCol: Frame = make("Frame", {
			Name = "Text",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 7,
			Parent = card,
		})
		make("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = textCol,
		})
		local name = Overlay.text(textCol, pass.name, 24, nil, nil, 8)
		name.LayoutOrder = 1
		local tag = Overlay.text(textCol, ShopMock.ConceptLabel, 16, Style.TextSoft, nil, 8)
		tag:SetAttribute("PreviewCaption", true)
		tag.LayoutOrder = 2
		table.insert(conceptLabels, tag)
		local does = Style.paragraph(textCol, pass.does, 18, false, 8)
		does.LayoutOrder = 3
		local never = Style.paragraph(textCol, pass.never, 16, true, 8)
		never.LayoutOrder = 4

		-- the price box: a neutral dark chip (no sale colours, no urgency)
		local price = Style.well(card, "Price", 7)
		price.Size = UDim2.fromOffset(if row then 150 else width - 24, 46)
		local priceText = Overlay.text(price, ShopMock.PriceLabel, 18, nil, Enum.TextXAlignment.Center, 8)
		priceText.Size = UDim2.new(1, -8, 1, 0)
		priceText.Position = UDim2.fromOffset(4, 0)
		table.insert(priceLabels, priceText)

		if row then
			textCol.Position = UDim2.fromOffset(60 + 12, 0)
			textCol.Size = UDim2.fromOffset(width - 24 - 60 - 12 - 150 - 12, 0)
			price.AnchorPoint = Vector2.new(1, 0)
			price.Position = UDim2.new(1, 0, 0, 6)
			make("Frame", {
				Name = "MinHeight",
				Size = UDim2.fromOffset(1, 64),
				BackgroundTransparency = 1,
				Parent = card,
			})
		else
			textCol.Position = UDim2.fromOffset(0, 70)
			textCol.Size = UDim2.fromOffset(width - 24, 0)
			price.LayoutOrder = 5
			price.Parent = textCol
		end
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local pw, ph
		if kind == "Wide" then
			pw, ph = math.min(ds.X - 32, 940), math.min(ds.Y - 24, 600)
		elseif kind == "Short" then
			pw, ph = ds.X - 24, ds.Y - 18
		else
			pw, ph = ds.X - 16, ds.Y - 18
		end
		shell.root.Size = UDim2.fromOffset(pw, ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		local headH = if kind == "Short" then Style.HeaderHeightShort else Style.HeaderHeight
		header.setHeight(headH)
		closeButton.root.Position = UDim2.new(1, -8, 0, headH / 2)
		local titleLeft = header.title.Position.X.Offset
		header.title.Size = UDim2.new(1, -titleLeft - Overlay.CloseWidth - 18, 0, math.min(44, headH - 6))
		note.Position = UDim2.fromOffset(14, headH + 6)
		note.Size = UDim2.new(1, -28, 0, 22)
		list.Position = UDim2.fromOffset(8, headH + 30)
		list.Size = UDim2.new(1, -16, 1, -(headH + 30 + 8))
		itemTrove:Clean()
		table.clear(priceLabels)
		table.clear(conceptLabels)
		local innerW = pw - 16 - 16 - 8
		if kind == "Wide" then
			listLayout.FillDirection = Enum.FillDirection.Horizontal
			listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			local w = math.floor((innerW - 2 * 14) / 3)
			for i, pass in ShopMock.Passes do
				buildItem(pass, i, w, false)
			end
		else
			listLayout.FillDirection = Enum.FillDirection.Vertical
			for i, pass in ShopMock.Passes do
				buildItem(pass, i, innerW, kind == "Short")
			end
		end
	end

	overlay:setBack(function()
		shop:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	shop = {
		root = overlay.root,
		layout = function(_self: Shop)
			layoutNow()
		end,
		setVisible = function(_self: Shop, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		open = function(_self: Shop, returnTo: GuiObject?)
			layoutNow()
			overlay:open(closeButton.body, returnTo)
		end,
		close = function(_self: Shop)
			if not overlay:isOpen() then
				return
			end
			overlay:close()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Shop): boolean
			return overlay:isOpen()
		end,
		destroy = function(_self: Shop)
			overlay:destroy()
		end,
		getDebugState = function(_self: Shop): DebugState
			local prices, labels = {}, {}
			for _, p in priceLabels do
				table.insert(prices, p.Text)
			end
			for _, l in conceptLabels do
				table.insert(labels, l.Text)
			end
			local badges = 0
			for _, d in overlay.root:GetDescendants() do
				if d.Name == "Badge" and d:IsA("GuiObject") and d.Visible then
					badges += 1
				end
			end
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				passes = #ShopMock.Passes,
				prices = prices,
				labels = labels,
				badges = badges,
				instances = #overlay.root:GetDescendants(),
			}
		end,
	}

	layoutNow()
	return shop
end

return ShopMock
