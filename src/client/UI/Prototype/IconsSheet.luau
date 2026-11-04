--!strict
-- IconsSheet: the icon sheet frame (Lane 3, BRIEF M9-05, 2026-11-01). Every icon of the family at 48 px and at 96 px, each
-- on a light and a dark panel, with its frame count against the 40-frame budget. A harness screen: nothing here is
-- game UI, nothing is saved, and it builds only while it is open (so it costs nothing otherwise).
--
--   local sheet = IconsSheet.new(ctx, options?)       -- the usual screen shape: ctx = { store, screen, layer, ... }
--   sheet:open(returnTo?)  sheet:close()  sheet:isOpen()  sheet:setVisible(on)  sheet:layout()  sheet:destroy()
--   sheet:getDebugState() -> { open, icons, missing, overBudget, frames, instances }
--
-- Mount line for the HUD playground (the lead adds it; this file does not edit the harness):
--   mount("iconsSheet", { "IconsSheet" }, "Overlay", {})
--   then api.open("iconsSheet")

local Arcade = require(script.Parent.Arcade)
local Icons2 = require(script.Parent.Icons2)
local PreviewTokens = require(script.Parent.PreviewTokens)
local ShopKit = require(script.Parent.ShopKit)
local Overlay = require(script.Parent.Screens.Overlay)

local make = Arcade.make
local S = PreviewTokens.Shop

local ICON_BUDGET = 40 -- frames per icon (Specimen.luau)
local SIZES = { 48, 96 }
local ROW_H = 112
local NAME_W = 190
local PANEL_W = 48 + 96 + 36
local LIGHT = Color3.fromRGB(240, 246, 252)
local DARK = Color3.fromRGB(26, 30, 42)

local IconsSheet = {}

export type Sheet = {
	root: Frame,
	layout: (self: Sheet) -> (),
	setVisible: (self: Sheet, on: boolean) -> (),
	open: (self: Sheet, returnTo: GuiObject?) -> (),
	close: (self: Sheet) -> (),
	isOpen: (self: Sheet) -> boolean,
	destroy: (self: Sheet) -> (),
	getDebugState: (self: Sheet) -> { [string]: any },
}

local function groupsToShow(): { { title: string, names: { string } } }
	local groups = (Icons2 :: any).Groups
	if type(groups) == "table" and #groups > 0 then
		return groups
	end
	return { { title = "All icons", names = (Icons2 :: any).Names } }
end

function IconsSheet.new(ctx: Overlay.Ctx, _options: { [string]: any }?): Sheet
	local overlay = Overlay.new(ctx, { name = "IconsSheet" })
	local trove = overlay.trove
	local buildTrove = trove:Extend()
	local sheet: Sheet
	local frames: { [string]: number } = {}
	local missing: { string } = {}
	local overBudget: { string } = {}
	local count = 0

	local function build()
		buildTrove:Clean()
		table.clear(frames)
		table.clear(missing)
		table.clear(overBudget)
		count = 0
		overlay:applyScale()
		local ds = overlay:designSize()
		local w, h = math.min(ds.X - 24, 640), ds.Y - 16
		local panel = ShopKit.panel(overlay.content, {
			name = "SheetPanel",
			size = UDim2.fromOffset(w, h),
			position = UDim2.new(0.5, -w / 2, 0.5, -h / 2),
			z = 3,
		})
		buildTrove:Add(panel)
		local title = ShopKit.label(panel, "ICON SHEET: 48 px and 96 px, light and dark", 24, { name = "Title", z = 6 })
		title.Position = UDim2.fromOffset(14, 8)
		title.Size = UDim2.new(1, -90, 0, 32)
		local close = ShopKit.squareButton(panel, {
			name = "Close",
			size = 48,
			fill = "Red",
			icon = "Close",
			z = 8,
			trove = buildTrove,
			sound = "Close",
			onActivate = function()
				sheet:close()
			end,
		})
		close.root.AnchorPoint = Vector2.new(1, 0)
		close.root.Position = UDim2.new(1, -8, 0, 6)
		local list: ScrollingFrame = make("ScrollingFrame", {
			Name = "List",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 62),
			Size = UDim2.new(1, -20, 1, -72),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 8,
			ClipsDescendants = true,
			ZIndex = 5,
			Parent = panel,
		})
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		for _, group in groupsToShow() do
			local heading = ShopKit.label(list, group.title, 22, { name = "Group", colour = S.Color.Warn, z = 6 })
			heading.Size = UDim2.new(1, 0, 0, 30)
			heading.LayoutOrder = nextOrder()
			for _, name in group.names do
				local row: Frame = make("Frame", {
					Name = "Row_" .. name,
					Size = UDim2.new(1, 0, 0, ROW_H),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
					ZIndex = 6,
					Parent = list,
				})
				local has = (Icons2 :: any).has(name)
				local label = ShopKit.label(row, name, 18, { name = "Name", z = 7 })
				label.Position = UDim2.fromOffset(0, 4)
				label.Size = UDim2.fromOffset(NAME_W - 8, 26)
				local info = ShopKit.label(row, if has then "" else "MISSING", 16, {
					name = "Frames",
					colour = S.Color.Error,
					z = 7,
				})
				info.Position = UDim2.fromOffset(0, 34)
				info.Size = UDim2.fromOffset(NAME_W - 8, 24)
				local worst = 0
				for panelIndex, background in { LIGHT, DARK } do
					local back: Frame = make("Frame", {
						Name = if panelIndex == 1 then "Light" else "Dark",
						Position = UDim2.fromOffset(NAME_W + (panelIndex - 1) * (PANEL_W + 8), 0),
						Size = UDim2.fromOffset(PANEL_W, ROW_H),
						BackgroundColor3 = background,
						BorderSizePixel = 0,
						ZIndex = 6,
						Parent = row,
					})
					Arcade.corner(back, 8)
					local x = 12
					for _, side in SIZES do
						local holder: Frame = make("Frame", {
							Name = "Icon" .. side,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, x, 0.5, 0),
							Size = UDim2.fromOffset(side, side),
							BackgroundTransparency = 1,
							ZIndex = 7,
							Parent = back,
						})
						local drawn = has and (Icons2 :: any).draw(holder, name)
						if not drawn then
							Arcade.icon(holder, "__missing__")
						else
							local art = holder:FindFirstChild("Art")
							local n = if art then art:GetAttribute("Frames") else nil
							if type(n) == "number" then
								worst = math.max(worst, n)
							end
						end
						x += side + 12
					end
				end
				count += 1
				if not has then
					table.insert(missing, name)
				else
					frames[name] = worst
					info.Text = string.format("%d frames", worst)
					if worst > ICON_BUDGET then
						table.insert(overBudget, name)
						info.Text = string.format("%d frames (over %d)", worst, ICON_BUDGET)
						info.TextColor3 = S.Color.Error
					else
						info.TextColor3 = S.Color.Grey
					end
				end
			end
		end
	end

	overlay:setBack(function()
		sheet:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		if overlay:isOpen() then
			build()
		end
	end)

	sheet = {
		root = overlay.root,
		layout = function(_self: Sheet)
			if overlay:isOpen() then
				build()
			end
		end,
		setVisible = function(_self: Sheet, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		open = function(_self: Sheet, returnTo: GuiObject?)
			if overlay:isOpen() then
				return
			end
			build()
			overlay:open(nil, returnTo)
		end,
		close = function(_self: Sheet)
			if not overlay:isOpen() then
				return
			end
			overlay:close()
			buildTrove:Clean() -- nothing stays built while the sheet is closed
		end,
		isOpen = function(_self: Sheet): boolean
			return overlay:isOpen()
		end,
		destroy = function(_self: Sheet)
			overlay:destroy()
		end,
		getDebugState = function(_self: Sheet): { [string]: any }
			return {
				open = overlay:isOpen(),
				icons = count,
				missing = missing,
				overBudget = overBudget,
				frames = frames,
				instances = #overlay.root:GetDescendants(),
			}
		end,
	}
	return sheet
end

return IconsSheet
