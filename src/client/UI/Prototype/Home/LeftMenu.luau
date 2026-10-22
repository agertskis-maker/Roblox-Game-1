--!strict
-- Home HUD: left menu under Cash (Lane 3 preview). Buttons only call the callbacks they are
-- given; nothing here opens a real shop, grants, buys or saves anything.
--
--   Garage   cyan, Garage icon, label "GARAGE", collection progress pill "3/12"
--            (store.garage.owned / total), red badge = store.garage.unseen (earned, not seen)
--   Shop     friendly rainbow body, Shop icon, label "SHOP". No badge and no attention
--            animation, ever (calm paid UI, no pressure).
--   Missions orange, clipboard icon, label "MISSIONS", badge = store.missionsClaimable
--            (earned free claims only)
--   Settings smaller (48) navy gear, icon only (decision: the gear is universally read, and a
--            label would give a secondary control the same weight as the main three; its
--            accessible name is the button's Name "Settings").
--
-- Labels sit under each body (not inside it), so long labels never clip: each item is as wide
-- as max(body + badge room, measured label). Badges: 0 hidden, 1..9, then "9+" (Gloss.badge).
-- Bodies are 64 design px (96 device px on 1080p at scale 1.5) on Desktop and Tablet, 48 on
-- phones (the touch minimum) with 16 px labels. Placement comes from Home/Layout: a column on
-- Desktop, a row on Tablet and phones so the menu ends above the reserved thumbstick zone.
-- Text is never shrunk below 16.
--
-- API: LeftMenu.new(ctx, { onGarage, onShop, onMissions, onSettings }) -> LeftMenu
--   :layout()  :setVisible(on)  :destroy()
--   :getButton(name) -> GuiObject?   -- "Garage" | "Shop" | "Missions" | "Settings" (focus return)
--   :setLabelOverride(name, text?)   -- test hook for long labels (e.g. "COLLECTION")
--   :getDebugState()

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Gloss = require(script.Parent.Parent.Gloss)
local Icons = require(script.Parent.Parent.Icons)
local Layout = require(script.Parent.Layout)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local C = PreviewTokens.Color
local make = Gloss.make

export type Callbacks = {
	onGarage: (() -> ())?,
	onShop: (() -> ())?,
	onMissions: (() -> ())?,
	onSettings: (() -> ())?,
}

export type LeftMenu = {
	root: Frame,
	layout: (self: LeftMenu) -> (),
	setVisible: (self: LeftMenu, on: boolean) -> (),
	destroy: (self: LeftMenu) -> (),
	getButton: (self: LeftMenu, name: string) -> GuiObject?,
	setLabelOverride: (self: LeftMenu, name: string, text: string?) -> (),
	getDebugState: (self: LeftMenu) -> { [string]: any },
}

type ItemDef = {
	name: string,
	label: string?,
	icon: Icons.Name,
	light: Color3,
	deep: Color3,
	small: boolean,
	rainbow: boolean,
	callback: string,
}

local ITEMS: { ItemDef } = {
	{
		name = "Garage",
		label = Layout.MenuLabels.Garage,
		icon = "Garage",
		light = C.GarageLight,
		deep = C.GarageDeep,
		small = false,
		rainbow = false,
		callback = "onGarage",
	},
	{
		name = "Shop",
		label = Layout.MenuLabels.Shop,
		icon = "Shop",
		light = C.White,
		deep = C.White,
		small = false,
		rainbow = true,
		callback = "onShop",
	},
	{
		name = "Missions",
		label = Layout.MenuLabels.Missions,
		icon = "Missions",
		light = C.MissionsLight,
		deep = C.MissionsDeep,
		small = false,
		rainbow = false,
		callback = "onMissions",
	},
	{
		name = "Settings",
		label = nil,
		icon = "Settings",
		light = C.SettingsLight,
		deep = C.SettingsDeep,
		small = true,
		rainbow = false,
		callback = "onSettings",
	},
}

-- Soft candy rainbow (6 stops, the documented maximum for a cheap gradient).
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 170)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 70)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 225, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(110, 220, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(90, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 130, 255)),
})

type Item = {
	def: ItemDef,
	frame: Frame,
	button: Gloss.Button,
	label: TextLabel?,
	badge: Frame?,
	progress: TextLabel?,
	width: number,
	height: number,
}

local LeftMenu = {}
LeftMenu.__index = LeftMenu

local function measure(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4096, 4096)).X
end

function LeftMenu.new(ctx: Types.Ctx, callbacks: Callbacks?): LeftMenu
	local self = setmetatable({}, LeftMenu) :: any
	self._trove = Trove.new()
	self._ctx = ctx
	self._callbacks = callbacks or {}
	self._overrides = {} :: { [string]: string }
	self._items = {} :: { Item }
	self._itemTrove = self._trove:Extend()
	self._builtFor = ""
	local root = self._trove:Add(make("Frame", {
		Name = "LeftMenu",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(100, 100),
		ZIndex = 4,
		Parent = ctx.layer,
	}))
	self.root = root
	self._scale = make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })

	self._trove:Add(ctx.store:subscribe("garage", function()
		self:_refresh()
	end))
	self._trove:Add(ctx.store:subscribe("missionsClaimable", function()
		self:_refresh()
	end))
	self._trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)
	self:layout()
	return self :: LeftMenu
end

function LeftMenu._build(self: any, menu: Layout.MenuLayout)
	-- Keep gamepad focus on the same button across a rebuild.
	local selectedName: string? = nil
	for _, item in self._items do
		if GuiService.SelectedObject == item.button.body then
			selectedName = item.def.name
		end
	end
	self._itemTrove:Clean()
	table.clear(self._items)
	for _, def in ITEMS do
		local body = if def.small then menu.small else menu.body
		local labelText = self._overrides[def.name] or def.label
		local width = Layout.menuItemWidth(menu, def.name, labelText)
		local height = body + 4 + (if labelText then 2 + menu.labelSize + 4 else 0)
		local frame = self._itemTrove:Add(make("Frame", {
			Name = "Item_" .. def.name,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(width, height),
			ZIndex = 4,
			Parent = self.root,
		}))
		local cb = self._callbacks[def.callback]
		local button = Gloss.button(frame, {
			name = def.name,
			size = Vector2.new(body, body),
			position = UDim2.fromScale(0.5, 0),
			anchor = Vector2.new(0.5, 0),
			light = def.light,
			deep = def.deep,
			radius = if def.small then 14 else 18,
			icon = function(holder: Frame)
				Icons.draw(holder, def.icon)
			end,
			iconSize = math.floor(body * (if def.small then 0.66 else 0.7)),
			sound = "Tap",
			onActivate = function()
				if cb then
					cb()
				end
			end,
		})
		self._itemTrove:Add(button.trove)
		if def.rainbow then
			local g = button.body:FindFirstChildOfClass("UIGradient")
			if g then
				g.Color = RAINBOW
				g.Rotation = 35
			end
		end
		local label: TextLabel? = nil
		if labelText then
			local l = make("TextLabel", {
				Name = "Label",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, body + 4 + 2),
				Size = UDim2.new(1, 0, 0, menu.labelSize + 4),
				BackgroundTransparency = 1,
				FontFace = Tokens.font(),
				Text = labelText,
				TextSize = math.max(menu.labelSize, Tokens.TextSize.Minimum),
				TextColor3 = C.White,
				TextWrapped = false,
				ZIndex = 6,
				Parent = frame,
			})
			Gloss.stroke(l, 2.5, C.Ink, Enum.ApplyStrokeMode.Contextual)
			label = l
		end
		local badge: Frame? = nil
		local progress: TextLabel? = nil
		if def.name == "Garage" or def.name == "Missions" then
			badge = Gloss.badge(button.body, 0)
		end
		if def.name == "Garage" then
			local pill = make("Frame", {
				Name = "Progress",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, -6, 1, -8),
				Size = UDim2.fromOffset(44, 22),
				BackgroundColor3 = C.Ink,
				BorderSizePixel = 0,
				ZIndex = button.body.ZIndex + 5,
				Parent = button.body,
			})
			Gloss.corner(pill, 11)
			Gloss.stroke(pill, 2, C.White)
			progress = make("TextLabel", {
				Name = "Count",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				FontFace = Tokens.font(),
				TextSize = Tokens.TextSize.Minimum,
				TextColor3 = C.White,
				Text = "",
				ZIndex = pill.ZIndex + 1,
				Parent = pill,
			})
		end
		table.insert(self._items, {
			def = def,
			frame = frame,
			button = button,
			label = label,
			badge = badge,
			progress = progress,
			width = width,
			height = height,
		})
		if selectedName == def.name then
			GuiService.SelectedObject = button.body
		end
	end
	self:_refresh()
end

function LeftMenu._refresh(self: any)
	local state: Store.State = self._ctx.store:get()
	for _, item in self._items do
		if item.def.name == "Garage" then
			if item.badge then
				Gloss.setBadge(item.badge, state.garage.unseen)
			end
			if item.progress then
				local text = string.format("%d/%d", state.garage.owned, state.garage.total)
				item.progress.Text = text
				local pill = item.progress.Parent :: Frame
				pill.Size = UDim2.fromOffset(math.max(44, math.ceil(measure(text, Tokens.TextSize.Minimum)) + 14), 22)
			end
		elseif item.def.name == "Missions" and item.badge then
			Gloss.setBadge(item.badge, state.missionsClaimable)
		end
	end
end

function LeftMenu.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local menu = Layout.forProfile(ctx.screen:profile(), scale).menu
	local key = string.format("%s:%d:%d:%d", menu.kind, menu.body, menu.small, menu.labelSize)
	if key ~= self._builtFor then
		self._builtFor = key
		self:_build(menu)
	end
	-- Place the items: a column (left-aligned, centred on the widest body) or a row.
	local x, y = 0, 0
	local w, h = 0, 0
	local colWidth = 0
	for _, item in self._items do
		colWidth = math.max(colWidth, item.width)
	end
	for _, item in self._items do
		if menu.kind == "Column" then
			item.frame.Position = UDim2.fromOffset((colWidth - item.width) / 2, y)
			y += item.height + menu.gap
			w = colWidth
			h = y - menu.gap
		else
			item.frame.Position = UDim2.fromOffset(x, 0)
			x += item.width + menu.gap
			w = x - menu.gap
			h = math.max(h, item.height)
		end
	end
	self.root.Position = UDim2.fromOffset(menu.x * scale, menu.y * scale) -- layer px (UIScale does not move it)
	self.root.Size = UDim2.fromOffset(w, h)
	self._kind = menu.kind
end

function LeftMenu.setVisible(self: any, on: boolean)
	self.root.Visible = on
	if not on then
		for _, item in self._items do
			if GuiService.SelectedObject == item.button.body then
				GuiService.SelectedObject = nil
			end
		end
	end
end

function LeftMenu.getButton(self: any, name: string): GuiObject?
	for _, item in self._items do
		if item.def.name == name then
			return item.button.body
		end
	end
	return nil
end

function LeftMenu.setLabelOverride(self: any, name: string, text: string?)
	self._overrides[name] = text :: any
	self._builtFor = ""
	self:layout()
end

function LeftMenu.getDebugState(self: any): { [string]: any }
	local ctx: Types.Ctx = self._ctx
	local items = {}
	for _, item in self._items do
		local pos, size = ctx.screen:rectOf(item.button.body)
		local labelFits = true
		if item.label then
			labelFits = item.label.TextFits and item.label.TextBounds.X <= item.label.AbsoluteSize.X + 0.5
		end
		items[item.def.name] = {
			body = item.button.body.Size.X.Offset,
			deviceBody = size,
			devicePos = pos,
			label = if item.label then item.label.Text else nil,
			labelSize = if item.label then item.label.TextSize else nil,
			labelFits = labelFits,
			badgeVisible = if item.badge then item.badge.Visible else false,
			badgeText = if item.badge then (item.badge:FindFirstChild("Count") :: TextLabel).Text else nil,
			progress = if item.progress then item.progress.Text else nil,
			reserved = ctx.screen:overlapsReserved(pos, size),
		}
	end
	local rpos, rsize = ctx.screen:rectOf(self.root)
	return {
		visible = self.root.Visible,
		kind = self._kind,
		scale = self._scale.Scale,
		items = items,
		devicePos = rpos,
		deviceSize = rsize,
		reservedOverlap = ctx.screen:overlapsReserved(rpos, rsize),
	}
end

function LeftMenu.destroy(self: any)
	self._trove:Destroy()
end

return LeftMenu
