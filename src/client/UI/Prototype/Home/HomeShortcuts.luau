--!strict
-- Home/HomeShortcuts: the right-hand column of round icon buttons (Lane 3, N7-01 / N7-03a, 2026-11-02): Leaderboard,
-- Rewards (claimable missions), VIP and Free gift (Settings moved to the left column under Missions in Round 8, H-07, see
-- HomeNav and HomeLayout). Only entries the game really has are added (a missing adapter
-- means no button, never a dead one). On a phone at most three show; the rest wait behind a "..." overflow button that opens
-- a small list of 48 px rows. A badge appears only for a real waiting state.
--
--   local column = HomeShortcuts.new(parent)
--   column:setEntries({ { id, label, icons, fill, priority, order, onActivate, badge }, ... })
--   column:setBadge(id, value)       -- a count or "!" (nil / 0 hides it); also updates the overflow rows
--   column:place(plan, scale)        -- HomeLayout.ShortcutPlan: reflows, and rebuilds when the visible set changes
--   column:getButton(id) -> GuiObject?   column:closeOverflow()   column:setVisible(on)   column:getDebugState()
--   column:destroy()
--
-- priority: lower = kept visible first when there is not room (Free gift while claimable, then Rewards, Leaderboard ...).
-- order: the position top to bottom among the visible ones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local HomeButton = require(script.Parent.HomeButton)
local HomeLayout = require(script.Parent.HomeLayout)
local HomeView = require(script.Parent.HomeView)
local IconArt = require(script.Parent.IconArt)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local make = Arcade.make
local A = PreviewTokens.Arcade

local PANEL_W = 188
local ROW_H = Tokens.Touch.Minimum
local PANEL_CLOSE_AFTER = 6 -- seconds; the list closes by itself, a tap on a row or on "..." closes it at once

export type Entry = {
	id: string,
	label: string,
	icons: { string },
	fill: Arcade.FillName,
	priority: number,
	order: number,
	onActivate: (() -> ())?,
	badge: (number | string)?,
}

export type Column = {
	setEntries: (self: Column, entries: { Entry }) -> (),
	setBadge: (self: Column, id: string, value: (number | string | boolean)?) -> (),
	place: (self: Column, plan: HomeLayout.ShortcutPlan, scale: number) -> (),
	getButton: (self: Column, id: string) -> GuiObject?,
	closeOverflow: (self: Column) -> (),
	setVisible: (self: Column, on: boolean) -> (),
	getDebugState: (self: Column) -> { [string]: any },
	destroy: (self: Column) -> (),
}

local HomeShortcuts = {}
HomeShortcuts.__index = HomeShortcuts

local function badgeValue(v: (number | string | boolean)?): (number | string)?
	if v == nil or v == false then
		return nil
	elseif v == true then
		return "!"
	end
	return v :: any
end

function HomeShortcuts.new(parent: Instance): Column
	local self = setmetatable({}, HomeShortcuts) :: any
	self._trove = Trove.new()
	self._entries = {} :: { Entry }
	self._buttons = {} :: { [string]: HomeButton.Button }
	self._visibleIds = {} :: { string }
	self._hidden = {} :: { Entry }
	self._itemTrove = self._trove:Extend()
	self._key = ""
	self._plan = nil :: HomeLayout.ShortcutPlan?
	self._panel = nil :: Frame?
	self._panelThread = nil :: thread?
	local root = self._trove:Add(make("Frame", {
		Name = "HomeShortcuts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(56, 240),
		ZIndex = 4,
		Parent = parent,
	}))
	self.root = root
	self._scale = make("UIScale", { Name = "HudScale", Scale = 1, Parent = root })
	self._trove:Add(function()
		self:_cancelPanelTimer()
	end)
	return self :: Column
end

function HomeShortcuts.setEntries(self: any, entries: { Entry })
	local list = table.clone(entries)
	table.sort(list, function(a: Entry, b: Entry)
		return a.order < b.order
	end)
	self._entries = list
	self._key = "" -- rebuild on the next place
	if self._plan then
		self:place(self._plan, self._scale.Scale)
	end
end

function HomeShortcuts.setBadge(self: any, id: string, value: (number | string | boolean)?)
	local v = badgeValue(value)
	for _, e in self._entries do
		if e.id == id then
			e.badge = v
		end
	end
	local b = self._buttons[id]
	if b then
		b.setBadge(v)
	end
	-- the overflow button shows a badge when a hidden entry has one
	local more = self._buttons.__more
	if more then
		local any = false
		for _, e in self._hidden do
			if e.badge ~= nil then
				any = true
			end
		end
		more.setBadge(if any then "!" else nil)
	end
	if self._panel then
		self:_buildPanel()
	end
end

-- Which entries stay on screen: all of them when they fit, else the best by priority (kept in column order).
function HomeShortcuts._split(self: any, plan: HomeLayout.ShortcutPlan): ({ Entry }, { Entry })
	local entries: { Entry } = self._entries
	if #entries <= plan.maxPrimary then
		return entries, {}
	end
	local keep = math.max(1, math.min(plan.maxPrimary, plan.capacity - 1))
	local byPriority = table.clone(entries)
	table.sort(byPriority, function(a: Entry, b: Entry)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return a.order < b.order
	end)
	local chosen: { [string]: boolean } = {}
	for i = 1, keep do
		chosen[byPriority[i].id] = true
	end
	local visible: { Entry } = {}
	local hidden: { Entry } = {}
	for _, e in entries do
		table.insert(if chosen[e.id] then visible else hidden, e)
	end
	return visible, hidden
end

function HomeShortcuts._cancelPanelTimer(self: any)
	local t: thread? = self._panelThread
	self._panelThread = nil
	if t and coroutine.status(t) ~= "dead" then
		pcall(task.cancel, t)
	end
end

function HomeShortcuts.closeOverflow(self: any)
	self:_cancelPanelTimer()
	local panel: Frame? = self._panel
	if panel then
		self._panel = nil
		self._panelTrove:Destroy()
		Sounds.play("Close")
	end
end

function HomeShortcuts._buildPanel(self: any)
	local plan: HomeLayout.ShortcutPlan = self._plan
	if self._panelTrove then
		self._panelTrove:Destroy()
	end
	local ptrove = Trove.new()
	self._panelTrove = ptrove
	local hidden: { Entry } = self._hidden
	local more = self._buttons.__more
	if not more or #hidden == 0 then
		self._panel = nil
		return
	end
	local height = #hidden * (ROW_H + 4) + 12
	local panel = ptrove:Add(make("Frame", {
		Name = "OverflowPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset((plan.colW - plan.d) / 2 - 8, more.root.Position.Y.Offset),
		Size = UDim2.fromOffset(PANEL_W, height),
		BackgroundColor3 = PreviewTokens.Shop.Color.Panel,
		ZIndex = 20,
		Parent = self.root,
	}))
	Arcade.corner(panel, 12)
	Arcade.outline(panel, "Button")
	for i, e in hidden do
		local row = make("TextButton", {
			Name = "Row_" .. e.id,
			Position = UDim2.fromOffset(6, 6 + (i - 1) * (ROW_H + 4)),
			Size = UDim2.new(1, -12, 0, ROW_H),
			BackgroundColor3 = PreviewTokens.Shop.Color.PanelDeep,
			AutoButtonColor = false,
			Text = "",
			Selectable = true,
			ZIndex = 21,
			Parent = panel,
		})
		Arcade.corner(row, 8)
		Arcade.outline(row, "Minor")
		local icon = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			ZIndex = 22,
			Parent = row,
		})
		IconArt.draw(icon, e.icons)
		local text = Arcade.text(row, {
			text = e.label,
			role = "Label",
			name = "Label",
			xAlign = Enum.TextXAlignment.Left,
			z = 22,
		})
		text.AnchorPoint = Vector2.new(0, 0.5)
		text.Position = UDim2.new(0, 46, 0.5, 0)
		text.Size = UDim2.new(1, -76, 0, 28)
		if e.badge ~= nil then
			local dot = make("Frame", {
				Name = "Badge",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = A.Badge,
				ZIndex = 22,
				Parent = row,
			})
			Arcade.corner(dot, 18)
			Arcade.outline(dot, 2)
		end
		ptrove:Connect(row.Activated, function()
			Sounds.play("Tap")
			self:closeOverflow()
			if e.onActivate then
				e.onActivate()
			end
		end)
	end
	self._panel = panel
	-- the list closes by itself
	self:_cancelPanelTimer()
	self._panelThread = task.delay(PANEL_CLOSE_AFTER, function()
		self._panelThread = nil
		if self._panel == panel then
			self:closeOverflow()
		end
	end)
	if not Motion.reduced() then
		panel.Position = panel.Position + UDim2.fromOffset(10, 0)
		Motion.tween(panel, "slide", Motion.info(0.14), { Position = panel.Position - UDim2.fromOffset(10, 0) })
	end
end

function HomeShortcuts._toggleOverflow(self: any)
	if self._panel then
		self:closeOverflow()
		return
	end
	Sounds.play("Open")
	self:_buildPanel()
end

function HomeShortcuts._build(self: any, plan: HomeLayout.ShortcutPlan)
	self:closeOverflow()
	self._itemTrove:Clean()
	table.clear(self._buttons)
	local visible, hidden = self:_split(plan)
	self._hidden = hidden
	self._visibleIds = {}
	local index = 0
	for _, e in visible do
		index += 1
		local button = HomeButton.round(self.root, {
			name = e.id,
			label = if plan.labels then e.label else nil,
			fill = e.fill,
			icons = e.icons,
			d = plan.d,
			colW = plan.colW,
			badge = e.badge,
			onActivate = e.onActivate,
		})
		self._itemTrove:Add(button.trove)
		button.root.Position = UDim2.fromOffset(0, (index - 1) * plan.slot)
		self._buttons[e.id] = button
		table.insert(self._visibleIds, e.id)
	end
	if #hidden > 0 then
		index += 1
		local any = false
		for _, e in hidden do
			if e.badge ~= nil then
				any = true
			end
		end
		local more = HomeButton.round(self.root, {
			name = "More",
			label = if plan.labels then "More" else nil,
			fill = "Garage",
			icons = {},
			glyph = "...",
			d = plan.d,
			colW = plan.colW,
			badge = if any then "!" else nil,
			onActivate = function()
				self:_toggleOverflow()
			end,
		})
		self._itemTrove:Add(more.trove)
		more.root.Position = UDim2.fromOffset(0, (index - 1) * plan.slot)
		self._buttons.__more = more
	end
end

function HomeShortcuts.place(self: any, plan: HomeLayout.ShortcutPlan, scale: number)
	local ids: { string } = {}
	for _, e in self._entries do
		table.insert(ids, e.id)
	end
	local key =
		string.format("%s:%d:%d:%d:%d", table.concat(ids, ","), plan.d, plan.colW, plan.maxPrimary, plan.capacity)
	self._plan = plan
	self._scale.Scale = scale
	if key ~= self._key then
		self._key = key
		self:_build(plan)
	end
	local count = #self._visibleIds + (if #self._hidden > 0 then 1 else 0)
	self.root.Size = UDim2.fromOffset(plan.colW, math.max(plan.slot, count * plan.slot))
	self.root.Position = UDim2.fromOffset(plan.left * scale, plan.y * scale)
end

function HomeShortcuts.getButton(self: any, id: string): GuiObject?
	local b = self._buttons[id]
	return if b then b.body else nil
end

function HomeShortcuts.setVisible(self: any, on: boolean)
	self.root.Visible = on
	if not on then
		self:closeOverflow()
	end
end

function HomeShortcuts.getDebugState(self: any): { [string]: any }
	local out: { [string]: any } = {
		visible = self._visibleIds,
		hidden = {},
		overflowOpen = self._panel ~= nil,
		buttons = {},
	}
	for _, e in self._hidden do
		table.insert(out.hidden, e.id)
	end
	for id, b in self._buttons do
		out.buttons[id] = {
			absSize = HomeView.vec(b.body.AbsoluteSize),
			absPos = HomeView.vec(b.body.AbsolutePosition),
			badge = b.badge.frame.Visible,
		}
	end
	return out
end

function HomeShortcuts.destroy(self: any)
	self:closeOverflow()
	self._trove:Destroy()
end

return HomeShortcuts
