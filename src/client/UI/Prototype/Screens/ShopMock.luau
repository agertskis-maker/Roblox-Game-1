--!strict
-- ShopMock: a calm Shop mock drawn over gameplay (Lane 3 HUD prototype, PREVIEW only).
-- Nothing here can be bought: there is no MarketplaceService call, no prompt and no grant.
--
--   local shop = ShopMock.new(ctx, { onClose = fn? })
--   shop:open(returnTo?)  shop:close()  shop:isOpen()
--   shop:layout()  shop:setVisible(on)  shop:destroy()  shop:getDebugState()
--
-- Content: exactly the three passes listed in outline v2.2 section 12 ("Delegated pass set,
-- prices Open"): Double Lap Pay, Expanded Paddock, VIP. They are delegated choices in the
-- outline, not separately approved by the owner, so every card says "Pass concept (not
-- approved)". Each card shows what it does, what it never does, and "Robux price pending"
-- (no invented prices). Calm by rule: no countdowns, no flashing, no "best value", no idle
-- animation; only the shared panel open / close transition.

local Prototype = script.Parent.Parent
local Gloss = require(Prototype.Gloss)
local Icons = require(Prototype.Icons)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)

local C = PreviewTokens.Color
local make = Gloss.make

local ShopMock = {}

export type Pass = {
	id: string,
	name: string,
	icon: Icons.Name,
	does: string,
	never: string,
	light: Color3,
	deep: Color3,
}

-- From outline v2.2 section 12 (wording shortened for a child-friendly card).
ShopMock.Passes = {
	{
		id = "double-lap-pay",
		name = "Double Lap Pay",
		icon = "Track",
		does = "Your cars earn 2x Lap Pay, online and offline.",
		never = "Never changes race stats, Heat or Keys.",
		light = C.CashLight,
		deep = C.CashDeep,
	},
	{
		id = "expanded-paddock",
		name = "Expanded Paddock",
		icon = "Garage",
		does = "+3 Slots above the normal maximum, with an extra pit garage.",
		never = "Never changes how much each car earns.",
		light = C.GarageLight,
		deep = C.GarageDeep,
	},
	{
		id = "vip",
		name = "VIP",
		icon = "Star",
		does = "VIP Pearl paints, a name tag, a lounge on your plot, and a 12-hour offline cap.",
		never = "No advantage in runs or races.",
		light = C.KeysLight,
		deep = C.KeysDeep,
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

	local panel = Gloss.panel(content, {
		name = "Panel",
		size = UDim2.fromOffset(700, 400),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		radius = 20,
		z = 3,
	})
	local panelShadow = content:FindFirstChild("Shadow") :: Frame?

	local headerIcon = make("Frame", {
		Name = "Icon",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = panel,
	})
	Icons.draw(headerIcon, "Shop", C.PrimaryDeep)
	local title = Overlay.title(panel, "SHOP", 30, C.PrimaryLight, C.PrimaryDeep, 6)
	title.Position = UDim2.fromOffset(64, 12)
	title.Size = UDim2.fromOffset(160, 40)
	-- a thin static rainbow accent (the Shop's friendly identity; it never moves)
	local accent = make("Frame", {
		Name = "Accent",
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 0, 4),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = panel,
	})
	Gloss.corner(accent, 2)
	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 196, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 220, 130)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 120, 255)),
		}),
		Parent = accent,
	})
	local note = Overlay.text(panel, "Preview: nothing can be bought here.", 16, C.InkSoft, nil, 6)
	local closeButton = Overlay.closeButton(panel, function()
		shop:close()
	end)
	trove:Add(closeButton.trove)
	closeButton.root.AnchorPoint = Vector2.new(1, 0)
	closeButton.root.Position = UDim2.new(1, -10, 0, 8)

	local list: ScrollingFrame = make("ScrollingFrame", {
		Name = "Passes",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Ink,
		ScrollBarImageTransparency = 0.3,
		Selectable = false,
		ZIndex = 5,
		Parent = panel,
	})
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
	local firstItem: GuiObject? = nil

	-- One pass card. "column" = a portrait card (desktop, tablet, phone portrait);
	-- "row" = icon | text | price (phone landscape, where height is short).
	local function buildItem(pass: Pass, order: number, width: number, row: boolean)
		local card = itemTrove:Add(make("Frame", {
			Name = "Pass_" .. pass.id,
			Size = UDim2.fromOffset(width, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 6,
			Parent = list,
		}))
		Gloss.corner(card, 16)
		Gloss.stroke(card, 3)
		make("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			Parent = card,
		})
		local tile = make("Frame", {
			Name = "IconTile",
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = card,
		})
		Gloss.corner(tile, 14)
		Gloss.stroke(tile, 2)
		Gloss.gradient(tile, pass.light, pass.deep)
		local iconHolder = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(36, 36),
			BackgroundTransparency = 1,
			ZIndex = 8,
			Parent = tile,
		})
		Icons.draw(iconHolder, pass.icon, C.White)

		local textCol = make("Frame", {
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
		local name = Overlay.text(textCol, pass.name, 22, C.Ink, nil, 8)
		name.LayoutOrder = 1
		local tag = Overlay.text(textCol, ShopMock.ConceptLabel, 16, C.InkSoft, nil, 8)
		tag.LayoutOrder = 2
		table.insert(conceptLabels, tag)
		local does = Overlay.paragraph(textCol, pass.does, 16, C.Ink, 8)
		does.LayoutOrder = 3
		local never = Overlay.paragraph(textCol, pass.never, 16, C.InkSoft, 8)
		never.LayoutOrder = 4

		local price = make("Frame", {
			Name = "Price",
			Size = UDim2.fromOffset(if row then 150 else width - 24, 44),
			BackgroundColor3 = C.PanelShade,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = card,
		})
		Gloss.corner(price, 12)
		Gloss.stroke(price, 2).Transparency = 0.4
		local priceText = Overlay.text(price, ShopMock.PriceLabel, 16, C.Ink, Enum.TextXAlignment.Center, 8)
		priceText.TextWrapped = true
		priceText.TextTruncate = Enum.TextTruncate.None
		priceText.Size = UDim2.new(1, -8, 1, 0)
		priceText.Position = UDim2.fromOffset(4, 0)
		table.insert(priceLabels, priceText)

		if row then
			-- icon | text | price
			textCol.Position = UDim2.fromOffset(56 + 12, 0)
			textCol.Size = UDim2.fromOffset(width - 24 - 56 - 12 - 150 - 12, 0)
			price.AnchorPoint = Vector2.new(1, 0)
			price.Position = UDim2.new(1, 0, 0, 6)
			make("Frame", {
				Name = "MinHeight",
				Size = UDim2.fromOffset(1, 60),
				BackgroundTransparency = 1,
				Parent = card,
			})
		else
			-- icon on top, then name, label, text and the price box in one list
			textCol.Position = UDim2.fromOffset(0, 64)
			textCol.Size = UDim2.fromOffset(width - 24, 0)
			price.LayoutOrder = 5
			price.Parent = textCol
		end
		if not firstItem then
			firstItem = card
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
			pw, ph = ds.X - 24, ds.Y - 16
		else
			pw, ph = ds.X - 16, ds.Y - 16
		end
		panel.Size = UDim2.fromOffset(pw, ph)
		if panelShadow then
			panelShadow.Size = panel.Size
		end
		note.Position = UDim2.fromOffset(16, 66)
		note.Size = UDim2.new(1, -32, 0, 22)
		list.Position = UDim2.fromOffset(8, 94)
		list.Size = UDim2.new(1, -16, 1, -102)
		itemTrove:Clean()
		table.clear(priceLabels)
		table.clear(conceptLabels)
		firstItem = nil
		local innerW = pw - 16 - 16
		if kind == "Wide" then
			listLayout.FillDirection = Enum.FillDirection.Horizontal
			listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			list.ScrollingDirection = Enum.ScrollingDirection.Y
			list.AutomaticCanvasSize = Enum.AutomaticSize.Y
			local w = math.floor((innerW - 8 - 2 * 14) / 3)
			for i, pass in ShopMock.Passes do
				buildItem(pass, i, w, false)
			end
		else
			listLayout.FillDirection = Enum.FillDirection.Vertical
			list.ScrollingDirection = Enum.ScrollingDirection.Y
			list.AutomaticCanvasSize = Enum.AutomaticSize.Y
			for i, pass in ShopMock.Passes do
				buildItem(pass, i, innerW - 8, kind == "Short")
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
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				passes = #ShopMock.Passes,
				prices = prices,
				labels = labels,
			}
		end,
	}

	layoutNow()
	return shop
end

return ShopMock
