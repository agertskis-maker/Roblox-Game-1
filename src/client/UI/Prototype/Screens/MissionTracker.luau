--!strict
-- MissionTracker: the compact tracker for the top Mission on the home island (Lane 3, big round M13-02; PREVIEW).
-- One objective, its numbers and a progress strip, drawn in the tutorial banner's language but smaller (the Missions
-- orange, the thick dark boundary, the gloss band, an ink status disc). It sits at the top right of the safe area.
--
--   local tracker = MissionTracker.new(ctx, { onOpen = function() ... end })   -- onOpen opens the Missions panel
--   tracker:bindPanel(panel)          -- follows MissionsPanel.topMission() as the panel's state changes
--   tracker:setMission(mission?)      -- or feed it directly (nil hides it)
--   tracker:setCollapsed(on)  tracker:isCollapsed()   tracker:layout()  tracker:setVisible(on)  tracker:destroy()
--   tracker:getDebugState()
--
-- NEVER DURING RUNS: it shows only while the store mode is "Home" and disappears the moment a run starts, so it cannot
-- compete with driving. COLLAPSIBLE: a 48 px chevron collapses it to a small icon tile (the default on phones); tapping
-- the tile expands it again, tapping the expanded tracker calls options.onOpen. While the tutorial banner is on screen it
-- gives way: it narrows, or collapses when there is no room left of the banner. It never grants or claims anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local IconArt = require(Prototype.Home.IconArt)
local Layout = require(Prototype.Home.Layout)
local MissionFixtures = require(Prototype.SupportFixtures.MissionFixtures)
local MissionsPanel = require(script.Parent.MissionsPanel)
local Motion = require(Prototype.Motion)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(Prototype.Home.Types)

local A = PreviewTokens.Arcade
local B = A.Button
local make = Arcade.make

local MissionTracker = {}

local H = 72 -- expanded height
local TILE = 56 -- collapsed tile side
local STRIP = 8
local CHEVRON = Tokens.Touch.Minimum
local MARGIN_PHONE = 6
local MARGIN = 12

export type Options = {
	onOpen: (() -> ())?,
}

export type DebugState = {
	visible: boolean,
	collapsed: boolean,
	forcedCollapsed: boolean, -- no room beside the tutorial banner
	mode: string,
	missionId: string,
	title: string,
	counter: string,
	ready: boolean,
	width: number,
	height: number,
	devicePos: Vector2,
	deviceSize: Vector2,
	reservedOverlap: string?,
}

export type Tracker = {
	root: Frame,
	layout: (self: Tracker) -> (),
	setVisible: (self: Tracker, on: boolean) -> (),
	setMission: (self: Tracker, mission: MissionFixtures.Mission?) -> (),
	bindPanel: (self: Tracker, panel: MissionsPanel.Panel) -> (),
	setCollapsed: (self: Tracker, on: boolean) -> (),
	isCollapsed: (self: Tracker) -> boolean,
	destroy: (self: Tracker) -> (),
	getDebugState: (self: Tracker) -> DebugState,
}

function MissionTracker.new(ctx: Types.Ctx, options: Options?): Tracker
	local opts: Options = options or {}
	local trove = Trove.new()
	local bindTrove = trove:Extend()
	local wanted = true
	local mission: MissionFixtures.Mission? = nil
	local collapsed = ctx.screen:profile().kind == "Phone"
	local forced = false
	local width = 250
	local destroyed = false
	local tracker: Tracker

	local root: Frame = trove:Add(make("Frame", {
		Name = "MissionTracker",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(250, H + B.DepthOffset),
		Visible = false,
		ZIndex = 5,
		Parent = ctx.layer,
	}))
	local scale: UIScale = make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })

	local lip: Frame = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, B.DepthOffset),
		Size = UDim2.fromOffset(250, H),
		BackgroundColor3 = A.Ink,
		ZIndex = 5,
		Parent = root,
	})
	Arcade.corner(lip)
	local body: TextButton = make("TextButton", {
		Name = "Body",
		Size = UDim2.fromOffset(250, H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 6,
		Parent = root,
	})
	Arcade.corner(body)
	Arcade.outline(body, "Button")
	local gradient: UIGradient = make("UIGradient", { Color = A.Fill.Missions, Rotation = 90, Parent = body })
	Arcade.gloss(body)

	local disc: Frame = make("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = A.Ink,
		ZIndex = 9,
		Parent = body,
	})
	Arcade.corner(disc, 38)
	Arcade.outline(disc, 2, Color3.new(1, 1, 1))
	local discIcon: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = disc,
	})
	local title = SupportKit.label(body, "Title", 18, 9)
	local sub = SupportKit.label(body, "Sub", 16, 9)
	sub.TextColor3 = Style.TextSoft
	local counter = Arcade.text(body, {
		text = "",
		role = "Label",
		name = "Counter",
		size = 18,
		italic = true,
		xAlign = Enum.TextXAlignment.Right,
		z = 9,
	})
	local track: Frame = make("Frame", {
		Name = "Strip",
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.45,
		ZIndex = 9,
		Parent = body,
	})
	Arcade.corner(track, STRIP / 2)
	Arcade.outline(track, "Minor")
	local fill: Frame = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = 10,
		Parent = track,
	})
	Arcade.corner(fill, STRIP / 2)
	local fillGradient: UIGradient = make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = fill })
	-- the collapse chevron: a 48 px hit box with a short white bar (collapse) drawn in it
	local chevron: TextButton = make("TextButton", {
		Name = "Collapse",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(CHEVRON, CHEVRON),
		BackgroundTransparency = 1,
		Text = "",
		Selectable = true,
		ZIndex = 12,
		Parent = body,
	})
	local chevronMark: Frame = make("Frame", {
		Name = "Mark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 13,
		Parent = chevron,
	})
	Arcade.corner(chevronMark, 3)
	Arcade.outline(chevronMark, "Minor")

	-- LOGIC ----------------------------------------------------------------------------------

	local function visualReady(): boolean
		return mission ~= nil and MissionFixtures.visual(mission) == "Ready"
	end

	local function currentWidth(): number
		return if collapsed or forced then TILE else width
	end

	local function isHome(): boolean
		return ctx.store:get().mode == "Home"
	end

	local function applyVisible()
		root.Visible = wanted and mission ~= nil and isHome()
	end

	local function setFill(p: number)
		if Motion.reduced() then
			Motion.cancelAll(fill)
			fill.Size = UDim2.fromScale(p, 1)
		else
			Motion.tween(fill, "fill", Motion.info(0.25), { Size = UDim2.fromScale(p, 1) })
		end
	end

	local function render()
		local m = mission
		if not m then
			applyVisible()
			return
		end
		local visual = MissionFixtures.visual(m)
		local ready = visual == "Ready"
		local fraction = SupportKit.fraction(m.progress, m.target, "tracker:" .. m.id)
		local compactTile = collapsed or forced
		gradient.Color = if ready then A.Fill.Gold else A.Fill.Missions
		fillGradient.Color = A.Fill.Green
		disc.BackgroundColor3 = if ready then Color3.fromRGB(30, 150, 60) else A.Ink
		discIcon:ClearAllChildren()
		IconArt.draw(discIcon, if ready then { "Check" } else { m.icon, "Star" })
		title.Text = m.text
		sub.Text = if visual == "Checking" then "Checking..." elseif ready then "Ready to claim!" else (m.sub or "")
		local p = m.progress
		local counterText = "..."
		if p ~= nil and p == p and p >= 0 then
			counterText = string.format(
				"%s/%s",
				if m.format == "cash" then Format.cash(math.min(p, m.target)) else Format.group(math.min(p, m.target)),
				if m.format == "cash" then Format.cash(m.target) else Format.group(m.target)
			)
		end
		counter.Text = counterText
		setFill(if visual == "Claimed" or visual == "Pending" then 1 else (fraction or 0))
		-- layout of the parts for the current form
		local w = currentWidth()
		lip.Size = UDim2.fromOffset(w, if compactTile then TILE else H)
		body.Size = UDim2.fromOffset(w, if compactTile then TILE else H)
		root.Size = UDim2.fromOffset(w, (if compactTile then TILE else H) + B.DepthOffset)
		title.Visible = not compactTile
		sub.Visible = not compactTile
		counter.Visible = not compactTile
		chevron.Visible = not compactTile
		if compactTile then
			disc.AnchorPoint = Vector2.new(0.5, 0.5)
			disc.Position = UDim2.new(0.5, 0, 0.5, -4)
			track.Position = UDim2.new(0, 8, 1, -STRIP - 6)
			track.Size = UDim2.new(1, -16, 0, STRIP)
		else
			disc.AnchorPoint = Vector2.new(0, 0.5)
			disc.Position = UDim2.new(0, 10, 0.5, -4)
			title.Position = UDim2.fromOffset(54, 4)
			title.Size = UDim2.fromOffset(w - 54 - CHEVRON, 26)
			SupportKit.fitLabel(title, m.text, w - 54 - CHEVRON, 26, 18)
			sub.Position = UDim2.fromOffset(54, 30)
			sub.Size = UDim2.fromOffset(w - 54 - 100, 24)
			SupportKit.fitLabel(sub, sub.Text, w - 54 - 100, 24, 16)
			counter.Position = UDim2.fromOffset(w - 100 - 6, 30)
			counter.Size = UDim2.fromOffset(94, 24)
			counter.TextXAlignment = Enum.TextXAlignment.Right
			track.Position = UDim2.fromOffset(54, H - STRIP - 8)
			track.Size = UDim2.fromOffset(w - 54 - 12, STRIP)
			chevron.Position = UDim2.new(1, -2, 0, 0)
		end
		applyVisible()
	end

	-- where it sits: top right of the safe area, narrower or collapsed beside the tutorial banner
	local function place()
		local profile = ctx.screen:profile()
		local s = ctx.screen:uiScale()
		scale.Scale = s
		local home = Layout.forProfile(profile, s)
		local phone = profile.kind == "Phone"
		local margin = if phone then MARGIN_PHONE else MARGIN
		width = if phone then 236 else 270
		forced = false
		local right = home.safeW - margin
		local top = if phone then 4 else 8
		if ctx.store:get().tutorial ~= nil and not collapsed then
			local bannerRight = home.banner.cx + home.banner.width / 2
			local room = right - (bannerRight + 8)
			if room < width then
				if room >= 190 then
					width = room
				else
					forced = true
				end
			end
		end
		root.Position = UDim2.fromOffset(right * s, top * s)
		render()
	end

	-- EVENTS ---------------------------------------------------------------------------------

	trove:Connect(body.Activated, function()
		Sounds.play("Tap")
		if collapsed or forced then
			if forced then
				return -- no room to expand beside the banner right now
			end
			tracker:setCollapsed(false)
		elseif opts.onOpen then
			opts.onOpen()
		end
	end)
	trove:Connect(chevron.Activated, function()
		Sounds.play("Tap")
		tracker:setCollapsed(true)
	end)
	trove:Connect(ctx.screen.Changed, function()
		place()
	end)
	trove:Add(ctx.store:subscribe("tutorial", function()
		place()
	end))
	trove:Connect(ctx.store.ModeChanged, function()
		applyVisible() -- never during a run or the Results
	end)
	trove:Add(Motion.onReducedChanged(function()
		render()
	end))
	trove:Add(function()
		Motion.cancelAll(fill)
	end)

	tracker = {
		root = root,
		layout = function(_self: Tracker)
			place()
		end,
		setVisible = function(_self: Tracker, on: boolean)
			wanted = on
			applyVisible()
		end,
		setMission = function(_self: Tracker, m: MissionFixtures.Mission?)
			mission = m
			render()
		end,
		bindPanel = function(self: Tracker, panel: MissionsPanel.Panel)
			bindTrove:Clean()
			bindTrove:Add(panel:subscribe(function()
				self:setMission(panel:topMission())
			end))
			self:setMission(panel:topMission())
		end,
		setCollapsed = function(_self: Tracker, on: boolean)
			collapsed = on
			place()
		end,
		isCollapsed = function(_self: Tracker): boolean
			return collapsed or forced
		end,
		destroy = function(_self: Tracker)
			if destroyed then
				return
			end
			destroyed = true
			trove:Destroy()
		end,
		getDebugState = function(_self: Tracker): DebugState
			local pos, size = ctx.screen:rectOf(body)
			local m = mission
			return {
				visible = root.Visible,
				collapsed = collapsed,
				forcedCollapsed = forced,
				mode = ctx.store:get().mode,
				missionId = if m then m.id else "",
				title = title.Text,
				counter = counter.Text,
				ready = visualReady(),
				width = currentWidth(),
				height = if collapsed or forced then TILE else H,
				devicePos = pos,
				deviceSize = size,
				reservedOverlap = ctx.screen:overlapsReserved(pos, size),
			}
		end,
	}

	place()
	return tracker
end

return MissionTracker
