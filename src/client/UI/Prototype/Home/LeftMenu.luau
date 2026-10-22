--!strict
-- Home HUD: the arcade left menu (Lane 3 preview, HUD rebuild 2026-10-22; ledger H-01..H-05,
-- H-12, V-07). Built only from the Arcade kit (Prototype/Arcade.luau). Buttons only call the
-- callbacks they are given; nothing here opens a real shop, grants, buys or saves anything.
--
--   Settings  small red labelled rectangle ("Settings" fill, Small size) ABOVE the stack and
--             centred on it (Desktop/Tablet); no Gear, no second button.
--   Shop      Wide, "Rainbow" fill with the slow sideways drift (stopped in reduced motion and
--             while hidden — the kit does this), Gift icon left (Cart if Gift has no art), large
--             "Shop" label, faint motor pattern. Badge ONLY for actual free fixture claims
--             (options.shopFreeClaims or :setShopFreeClaims; default none). Never purchase
--             urgency, never an attention animation.
--   Garage    Wide, "Garage" fill, GarageBook icon, earned-unseen badge = store.garage.unseen.
--   Missions  Wide, "Missions" fill, Clipboard icon, earned-claim badge = store.missionsClaimable.
--   Music     Arcade.toggle bound to store.settings.musicOn (a real local preview setting:
--             Home/MusicSetting sets the preview music SoundGroup volume). No fake Slow Mode.
-- The three big buttons have equal widths, so their icon centres line up; gaps are B.Gap.
-- Badges live on each button's fixed root (the kit's design), so a press scale never shrinks or
-- clips them. Removed from the overnight menu: the "3/12" chip and the gear-only Settings.
-- No right-side square buttons, no Daily/Goals, no hotbar.
--
-- Placement per device comes from Home/Layout (Column on Desktop, TabletColumn on Tablet, a
-- two-row PhoneBlock on phones; see that file for why phones are not a column).
--
-- API: LeftMenu.new(ctx, Options?) -> LeftMenu
--   :layout()  :setVisible(on)  :destroy()  :getDebugState()
--   :getButton(name) -> GuiObject?            -- "Settings" | "Shop" | "Garage" | "Missions" | "Music"
--   :setLabelOverride(name, text?)            -- test hook for long labels (wraps to two lines)
--   :setIconOverride(name, iconName?)         -- test hook for a missing icon
--   :setShopFreeClaims(count?)                -- actual free fixture claims only
--   :setPressed(name, down)                   -- test hook: hold the press scale (badge survival)

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local IconArt = require(script.Parent.IconArt)
local Layout = require(script.Parent.Layout)
local MusicSetting = require(script.Parent.MusicSetting)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

export type Options = {
	onGarage: (() -> ())?,
	onShop: (() -> ())?,
	onMissions: (() -> ())?,
	onSettings: (() -> ())?,
	-- LOCAL OPTION (not a Store field): the number of actually free fixture claims waiting in
	-- the Shop. nil/0 = no badge. Never a sale, a timer or a purchase prompt.
	shopFreeClaims: number?,
}

export type LeftMenu = {
	root: Frame,
	layout: (self: LeftMenu) -> (),
	setVisible: (self: LeftMenu, on: boolean) -> (),
	destroy: (self: LeftMenu) -> (),
	getButton: (self: LeftMenu, name: string) -> GuiObject?,
	setLabelOverride: (self: LeftMenu, name: string, text: string?) -> (),
	setIconOverride: (self: LeftMenu, name: string, icon: string?) -> (),
	setShopFreeClaims: (self: LeftMenu, count: number?) -> (),
	setPressed: (self: LeftMenu, name: string, down: boolean) -> (),
	getDebugState: (self: LeftMenu) -> { [string]: any },
}

type Def = {
	name: string,
	label: string,
	fill: Arcade.FillName,
	icon: string?,
	fallbacks: { string }, -- tried in order when the Icons2 name has no art yet
	pattern: boolean,
	drift: boolean,
	callback: string,
}

local DEFS: { Def } = {
	{
		name = "Settings",
		label = "Settings",
		fill = "Settings",
		icon = nil,
		fallbacks = {},
		pattern = false,
		drift = false,
		callback = "onSettings",
	},
	{
		name = "Shop",
		label = "Shop",
		fill = "Rainbow",
		icon = "Gift",
		fallbacks = { "Cart", "Shop" },
		pattern = true,
		drift = true,
		callback = "onShop",
	},
	{
		name = "Garage",
		label = "Garage",
		fill = "Garage",
		icon = "GarageBook",
		fallbacks = { "Garage" },
		pattern = true,
		drift = false,
		callback = "onGarage",
	},
	{
		name = "Missions",
		label = "Missions",
		fill = "Missions",
		icon = "Clipboard",
		fallbacks = { "Missions" },
		pattern = true,
		drift = false,
		callback = "onMissions",
	},
}

local LeftMenu = {}
LeftMenu.__index = LeftMenu

function LeftMenu.new(ctx: Types.Ctx, options: Options?): LeftMenu
	local self = setmetatable({}, LeftMenu) :: any
	self._trove = Trove.new()
	self._ctx = ctx
	self._opts = options or {}
	self._labels = {} :: { [string]: string }
	self._icons = {} :: { [string]: string }
	self._buttons = {} :: { [string]: Arcade.Button }
	self._iconDrawn = {} :: { [string]: string }
	self._shopFree = self._opts.shopFreeClaims
	self._itemTrove = self._trove:Extend()
	self._builtFor = ""
	self._kind = ""
	self._toggle = nil :: Arcade.Toggle?
	local root = self._trove:Add(Arcade.make("Frame", {
		Name = "LeftMenu",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(100, 100),
		ZIndex = 4,
		Parent = ctx.layer,
	}))
	self.root = root
	self._scale = Arcade.make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })

	self._trove:Add(ctx.store:subscribe("garage", function()
		self:_refresh()
	end))
	self._trove:Add(ctx.store:subscribe("missionsClaimable", function()
		self:_refresh()
	end))
	self._trove:Add(ctx.store:subscribe("settings", function()
		local t: Arcade.Toggle? = self._toggle
		if t then
			t.set(MusicSetting.isOn(ctx.store))
		end
		MusicSetting.apply(ctx.store)
	end))
	self._trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)
	MusicSetting.apply(ctx.store)
	self:layout()
	return self :: LeftMenu
end

-- The kit drew the preferred name; when that has no art yet (Icons2 may not exist), the
-- fallbacks are tried in order (the overnight Icons art), and a neutral "?" glyph is shown only
-- when none has art (Home/IconArt). Returns the drawn name, or nil for the glyph.
local function redrawIcon(holder: Frame, preferred: string, fallbacks: { string }): string?
	if IconArt.hasArt(holder) then
		return preferred
	end
	local names = { preferred }
	for _, n in fallbacks do
		table.insert(names, n)
	end
	return IconArt.draw(holder, names)
end

function LeftMenu._build(self: any, menu: Layout.MenuLayout)
	local ctx: Types.Ctx = self._ctx
	-- keep gamepad focus on the same control across a rebuild
	local selectedName: string? = nil
	for name, b in self._buttons do
		if GuiService.SelectedObject == b.body then
			selectedName = name
		end
	end
	local toggleSelected = self._toggle ~= nil
		and GuiService.SelectedObject ~= nil
		and (GuiService.SelectedObject :: GuiObject):IsDescendantOf(self._toggle.root)
	self._itemTrove:Clean()
	table.clear(self._buttons)
	table.clear(self._iconDrawn)
	self._toggle = nil

	for _, def in DEFS do
		local small = def.name == "Settings"
		local iconName = self._icons[def.name] or def.icon
		local cb = self._opts[def.callback]
		local spec: Arcade.ButtonSpec = {
			name = def.name,
			label = self._labels[def.name] or def.label,
			fill = def.fill,
			size = if small then "Small" else menu.size,
			width = if small then nil else menu.buttonW,
			height = if small then nil else menu.buttonH,
			icon = iconName,
			pattern = def.pattern and not small,
			drift = def.drift,
			sound = "Tap",
			onActivate = function()
				if cb then
					cb()
				end
			end,
		}
		local button = Arcade.button(self.root, spec)
		self._itemTrove:Add(button.trove)
		-- the kit makes the root; the trove above destroys it with the item trove
		local pos = menu.items[def.name]
		button.root.Position = UDim2.fromOffset(pos.x, pos.y)
		if iconName and button.iconHolder then
			-- an override (test hook) keeps its own result, so a missing icon stays visible
			local fallbacks = if self._icons[def.name] then {} else def.fallbacks
			self._iconDrawn[def.name] = redrawIcon(button.iconHolder, iconName, fallbacks) or "Missing"
		end
		button.root.Visible = self.root.Visible
		if self._labels[def.name] then
			-- long override labels may wrap to two lines inside the body (never below 16)
			button.label.TextWrapped = true
		end
		self._buttons[def.name] = button
		if selectedName == def.name then
			GuiService.SelectedObject = button.body
		end
	end

	local toggle = Arcade.toggle(self.root, {
		name = "Music",
		label = "Music",
		value = MusicSetting.isOn(ctx.store),
		onChanged = function(on: boolean)
			MusicSetting.setOn(ctx.store, on)
		end,
	})
	self._itemTrove:Add(toggle.trove)
	local mpos = menu.items.Music
	toggle.root.Size = UDim2.fromOffset(Layout.MusicWidth, Layout.MusicHeight)
	toggle.root.Position = UDim2.fromOffset(mpos.x, mpos.y)
	self._toggle = toggle
	if toggleSelected then
		local hit = toggle.root:FindFirstChild("Hit") :: GuiObject?
		if hit then
			GuiService.SelectedObject = hit
		end
	end
	self:_refresh()
end

function LeftMenu._refresh(self: any)
	local state: Store.State = self._ctx.store:get()
	local garage = self._buttons.Garage
	if garage then
		garage.setBadge(state.garage.unseen)
	end
	local missions = self._buttons.Missions
	if missions then
		missions.setBadge(state.missionsClaimable)
	end
	local shop = self._buttons.Shop
	if shop then
		local n: number? = self._shopFree
		shop.setBadge(if n and n > 0 then n else nil)
	end
end

function LeftMenu.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local menu = Layout.forProfile(ctx.screen:profile(), scale).menu
	local key = string.format("%s:%d:%d", menu.kind, menu.buttonW, menu.buttonH)
	if key ~= self._builtFor then
		self._builtFor = key
		self:_build(menu)
	else
		for name, b in self._buttons do
			local pos = menu.items[name]
			b.root.Position = UDim2.fromOffset(pos.x, pos.y)
		end
		local t: Arcade.Toggle? = self._toggle
		if t then
			local mpos = menu.items.Music
			t.root.Position = UDim2.fromOffset(mpos.x, mpos.y)
		end
	end
	self._kind = menu.kind
	self._menu = menu
	self.root.Position = UDim2.fromOffset(menu.x * scale, menu.y * scale) -- layer px
	self.root.Size = UDim2.fromOffset(menu.width, menu.height)
end

function LeftMenu.setVisible(self: any, on: boolean)
	self.root.Visible = on
	-- the kit pauses the rainbow drift only when the button's own root is hidden
	for _, b in self._buttons do
		b.root.Visible = on
	end
	if not on then
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(self.root) then
			GuiService.SelectedObject = nil
		end
	end
end

function LeftMenu.getButton(self: any, name: string): GuiObject?
	if name == "Music" then
		local t: Arcade.Toggle? = self._toggle
		return if t then t.root:FindFirstChild("Hit") :: GuiObject? else nil
	end
	local b = self._buttons[name]
	return if b then b.body else nil
end

function LeftMenu.setLabelOverride(self: any, name: string, text: string?)
	self._labels[name] = text :: any
	self._builtFor = ""
	self:layout()
end

function LeftMenu.setIconOverride(self: any, name: string, icon: string?)
	self._icons[name] = icon :: any
	self._builtFor = ""
	self:layout()
end

function LeftMenu.setShopFreeClaims(self: any, count: number?)
	self._shopFree = count
	self:_refresh()
end

function LeftMenu.setPressed(self: any, name: string, down: boolean)
	local b = self._buttons[name]
	if not b then
		return
	end
	local press = b.body:FindFirstChild("Press") :: UIScale?
	if press then
		press.Scale = if down then 0.95 else 1
	end
end

function LeftMenu.getDebugState(self: any): { [string]: any }
	local ctx: Types.Ctx = self._ctx
	local items = {}
	local instances = 0
	for _ in self.root:GetDescendants() do
		instances += 1
	end
	for name, b in self._buttons do
		local pos, size = ctx.screen:rectOf(b.body)
		local badge = b.badge.frame
		local bpos, bsize = ctx.screen:rectOf(badge)
		local press = b.body:FindFirstChild("Press") :: UIScale?
		local count = badge:FindFirstChild("Count") :: TextLabel?
		items[name] = {
			label = b.label.Text,
			labelFits = b.label.TextFits,
			labelSize = b.label.TextBounds,
			bodyDesign = b.size,
			devicePos = pos,
			deviceSize = size,
			iconArt = self._iconDrawn[name],
			badgeVisible = badge.Visible,
			badgeText = if count then count.Text else nil,
			badgeDevicePos = bpos,
			badgeDeviceSize = bsize,
			pressScale = if press then press.Scale else 1,
			reserved = ctx.screen:overlapsReserved(pos, size),
		}
	end
	local toggle: Arcade.Toggle? = self._toggle
	local rpos, rsize = ctx.screen:rectOf(self.root)
	return {
		visible = self.root.Visible,
		kind = self._kind,
		scale = self._scale.Scale,
		items = items,
		music = if toggle then toggle.get() else nil,
		musicSetting = MusicSetting.isOn(ctx.store),
		shopFreeClaims = self._shopFree,
		devicePos = rpos,
		deviceSize = rsize,
		reservedOverlap = ctx.screen:overlapsReserved(rpos, rsize),
		instances = instances,
	}
end

function LeftMenu.destroy(self: any)
	self._trove:Destroy()
end

return LeftMenu
