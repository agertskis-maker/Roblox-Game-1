--!strict
-- Home/HomeNav: the left column of the Round 2 Home HUD (Lane 3, N7-01 / N7-03a, 2026-11-02): three big labelled tiles,
-- Shop (the kit's slow rainbow, kept), Garage and Missions. Which shape they take (icon over label, or icon beside label)
-- is HomeLayout's decision for the screen; this module only draws what it is told and calls the callbacks it is given.
-- Buttons open things; nothing here buys, grants or saves.
--
--   local nav = HomeNav.new(parent, { onShop, onGarage, onMissions })
--   nav:place(plan)               -- HomeLayout.NavPlan + the HUD scale: moves and, when the tile shape changed, rebuilds
--   nav:setBadge("Shop" | "Garage" | "Missions", value)   -- a red "!" (true / string) or a count; nil or 0 hides it
--   nav:getButton(name) -> GuiObject?      -- the pressable body, for focus and the tutorial hand
--   nav:getRoot() -> Frame   nav:setVisible(on)   nav:destroy()   nav:getDebugState()
--
-- A badge is shown ONLY for a real unread or claimable state, which the caller supplies; there is no urgency animation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local HomeButton = require(script.Parent.HomeButton)
local HomeLayout = require(script.Parent.HomeLayout)
local HomeView = require(script.Parent.HomeView)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type Adapters = {
	onShop: (() -> ())?,
	onGarage: (() -> ())?,
	onMissions: (() -> ())?,
}

export type Nav = {
	place: (self: Nav, plan: HomeLayout.NavPlan, scale: number) -> (),
	setBadge: (self: Nav, name: string, value: (number | string | boolean)?) -> (),
	getButton: (self: Nav, name: string) -> GuiObject?,
	getRoot: (self: Nav) -> Frame,
	setVisible: (self: Nav, on: boolean) -> (),
	getDebugState: (self: Nav) -> { [string]: any },
	destroy: (self: Nav) -> (),
}

type Def = {
	name: string,
	label: string,
	fill: Arcade.FillName,
	icons: { string },
	drift: boolean,
	callback: string,
}

local DEFS: { Def } = {
	{
		name = "Shop",
		label = "Shop",
		fill = "Rainbow",
		icons = { "Shop", "Gift", "Cart" },
		drift = true,
		callback = "onShop",
	},
	{
		name = "Garage",
		label = "Garage",
		fill = "Garage",
		icons = { "Garage", "GarageBook" },
		drift = false,
		callback = "onGarage",
	},
	{
		name = "Missions",
		label = "Missions",
		fill = "Missions",
		icons = { "Missions", "Clipboard" },
		drift = false,
		callback = "onMissions",
	},
}

local HomeNav = {}
HomeNav.__index = HomeNav

local function badgeValue(v: (number | string | boolean)?): (number | string)?
	if v == nil or v == false then
		return nil
	elseif v == true then
		return "!"
	end
	return v :: any
end

function HomeNav.new(parent: Instance, adapters: Adapters): Nav
	local self = setmetatable({}, HomeNav) :: any
	self._trove = Trove.new()
	self._adapters = adapters
	self._badges = {} :: { [string]: (number | string)? }
	self._buttons = {} :: { [string]: HomeButton.Button }
	self._itemTrove = self._trove:Extend()
	self._key = ""
	self._plan = nil :: HomeLayout.NavPlan?
	local root = self._trove:Add(Arcade.make("Frame", {
		Name = "HomeNav",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(124, 200),
		ZIndex = 4,
		Parent = parent,
	}))
	self.root = root
	self._scale = Arcade.make("UIScale", { Name = "HudScale", Scale = 1, Parent = root })
	return self :: Nav
end

function HomeNav._build(self: any, plan: HomeLayout.NavPlan)
	self._itemTrove:Clean()
	table.clear(self._buttons)
	local tile = plan.tile
	for i, def in DEFS do
		local button = HomeButton.square(self.root, {
			name = def.name,
			label = def.label,
			fill = def.fill,
			icons = def.icons,
			style = tile.style,
			w = tile.w,
			h = tile.h,
			drift = def.drift,
			badge = self._badges[def.name],
			onActivate = function()
				local cb = (self._adapters :: any)[def.callback]
				if cb then
					cb()
				end
			end,
		})
		self._itemTrove:Add(button.trove)
		button.root.Position = UDim2.fromOffset(0, (i - 1) * (plan.rowHeight + tile.gap))
		self._buttons[def.name] = button
	end
end

function HomeNav.place(self: any, plan: HomeLayout.NavPlan, scale: number)
	local tile = plan.tile
	local key = string.format("%s:%d:%d", tile.style, tile.w, tile.h)
	self._plan = plan
	self._scale.Scale = scale
	if key ~= self._key then
		self._key = key
		self:_build(plan)
	end
	local height = 3 * plan.rowHeight + 2 * tile.gap
	self.root.Size = UDim2.fromOffset(tile.w, height)
	self.root.Position = UDim2.fromOffset(plan.x * scale, plan.y * scale)
end

function HomeNav.setBadge(self: any, name: string, value: (number | string | boolean)?)
	local v = badgeValue(value)
	self._badges[name] = v
	local b = self._buttons[name]
	if b then
		b.setBadge(v)
	end
end

function HomeNav.getButton(self: any, name: string): GuiObject?
	local b = self._buttons[name]
	return if b then b.body else nil
end

function HomeNav.getRoot(self: any): Frame
	return self.root
end

function HomeNav.setVisible(self: any, on: boolean)
	self.root.Visible = on
end

function HomeNav.getDebugState(self: any): { [string]: any }
	local out: { [string]: any } = { style = self._plan and self._plan.tile.style, buttons = {} }
	for name, b in self._buttons do
		out.buttons[name] = {
			size = HomeView.vec(b.size),
			absSize = HomeView.vec(b.body.AbsoluteSize),
			absPos = HomeView.vec(b.body.AbsolutePosition),
			badge = b.badge.frame.Visible,
			label = if b.label then b.label.Text else nil,
			labelFits = if b.label then b.label.TextFits else nil,
		}
	end
	return out
end

function HomeNav.destroy(self: any)
	self._trove:Destroy()
end

return HomeNav
