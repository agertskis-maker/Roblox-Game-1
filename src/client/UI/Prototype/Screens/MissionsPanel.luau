--!strict
-- MissionsPanel: the Missions and Goals panel opened from the Missions button (Lane 3, big round M13-01; PREVIEW).
-- Two tabs. MISSIONS: up to three cards, each with an icon, one short objective, a progress bar with numbers, a
-- "PREVIEW reward" chip and one action (Keep going / CLAIM / Checking... / CLAIMED). GOALS: the six one-time milestones
-- as a checklist, completed ones ticked and the next one highlighted.
--
--   local panel = MissionsPanel.new(ctx, { onClaim = fn?, onRetry = fn?, onClose = fn?, state = State?,
--                                          previewResolve = "Success" | "Error" | "None"?, onClaimableChanged = fn? })
--   panel:open(returnTo?)  panel:close()  panel:isOpen()  panel:selectTab("Missions" | "Goals")
--   panel:setState(state)  panel:setPreset("OneReady")                  -- MissionFixtures presets
--   panel:pressClaim(id) -> boolean   panel:resolveClaim(id, "Success" | "Error")   -- the claim round trip
--   panel:fixtureRefresh() -> number  -- the explicit "daily refresh" switch (a fixture, never a timer)
--   panel:subscribe(fn) -> disconnect   panel:getState()   panel:topMission()
--   panel:layout()  panel:setVisible(on)  panel:destroy()  panel:getDebugState()  panel:touchReport()
--   MissionsPanel.geometry(designSize) -> Geo
--
-- NOTHING IS GRANTED. CLAIM only moves a card Ready -> Pending and calls options.onClaim(id); the server's answer
-- arrives through resolveClaim. Success shows CLAIMED with a short celebration, keeps the card visible until that
-- feedback has finished, then replaces it ONCE (BRIEF M13-03a); Error puts the card back to CLAIM with a message.
-- Repeated taps while a claim is pending do nothing (one visual transition, no second request). With no onClaim given the
-- preview resolves a claim to Success after 0.7 s so the whole flow can be seen; pass previewResolve = "None" to hold it.
-- The daily refresh happens only when panel:fixtureRefresh() is called, and it never touches a Ready, Pending or Claimed
-- card (a claimable reward is never erased). A completed Goal never becomes incomplete because of a refresh.
--
-- Bars clamp to 0..1 for drawing; a source value that is not a sane number is logged once (SupportKit.fraction).
-- Reduced motion: no confetti, no pop, no fade; the replacement is an instant swap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Fade = require(Prototype.Home.Fade)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local IconArt = require(Prototype.Home.IconArt)
local MissionFixtures = require(Prototype.SupportFixtures.MissionFixtures)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Sounds = require(Prototype.Sounds)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)

local A = PreviewTokens.Arcade
local make = Arcade.make

local MissionsPanel = {}

local MAX_MISSIONS = 3
local PREVIEW_RESOLVE_SECONDS = 0.7
local CLAIM_HOLD = 1.2 -- the claimed card stays until its feedback has finished
local CLAIM_HOLD_REDUCED = 0.5

export type Tab = "Missions" | "Goals"

export type Options = {
	onClaim: ((missionId: string) -> ())?,
	onRetry: (() -> ())?,
	onClose: (() -> ())?,
	onClaimableChanged: ((count: number) -> ())?,
	state: MissionFixtures.State?,
	previewResolve: ("Success" | "Error" | "None")?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	pw: number,
	ph: number,
	headH: number,
	tabsH: number,
	tabY: number,
	tabW: number,
	list: Rect,
	cardW: number,
	cardH: number,
	actionW: number,
	goalH: number,
}

export type CardDebug = {
	id: string,
	visual: string,
	numbers: string,
	action: string,
	sub: string,
	reward: string,
}

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	tab: string,
	load: string,
	cards: { CardDebug },
	goals: { { id: string, done: boolean, next: boolean } },
	claimTaps: number,
	claimRequests: number,
	claimsResolved: number,
	replacements: number,
	refreshes: number,
	message: string,
	instances: number,
}

export type Panel = {
	root: Frame,
	layout: (self: Panel) -> (),
	setVisible: (self: Panel, on: boolean) -> (),
	open: (self: Panel, returnTo: GuiObject?) -> (),
	close: (self: Panel) -> (),
	isOpen: (self: Panel) -> boolean,
	selectTab: (self: Panel, tab: Tab) -> (),
	setState: (self: Panel, state: MissionFixtures.State) -> (),
	setPreset: (self: Panel, name: string) -> boolean,
	pressClaim: (self: Panel, id: string) -> boolean,
	resolveClaim: (self: Panel, id: string, outcome: "Success" | "Error") -> boolean,
	fixtureRefresh: (self: Panel) -> number,
	subscribe: (self: Panel, fn: (MissionFixtures.State) -> ()) -> () -> (),
	getState: (self: Panel) -> MissionFixtures.State,
	topMission: (self: Panel) -> MissionFixtures.Mission?,
	destroy: (self: Panel) -> (),
	getDebugState: (self: Panel) -> DebugState,
	touchReport: (self: Panel) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY -----------------------------------------------------------------------------------

-- A single card column at every size (a phone scrolls, a desktop shows all three). Pure in the design-px viewport.
function MissionsPanel.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local pw, ph, headH, tabsH
	if fit == "Compact" then
		pw, ph, headH, tabsH = math.min(ds.X - 12, 640), ds.Y - 8, 48, 46
	elseif fit == "Regular" then
		pw, ph, headH, tabsH = math.min(ds.X - 24, 640), math.min(ds.Y - 16, 460), 56, 50
	else
		pw, ph, headH, tabsH = math.min(ds.X - 32, 720), math.min(ds.Y - 24, 540), 64, 52
	end
	local tabY = headH + 8
	local listY = tabY + tabsH + 8
	local list = { x = 10, y = listY, w = pw - 20, h = ph - listY - 10 }
	return {
		fit = fit,
		pw = pw,
		ph = ph,
		headH = headH,
		tabsH = tabsH,
		tabY = tabY,
		tabW = math.floor((pw - 24 - 8) / 2),
		list = list,
		cardW = list.w - 8,
		cardH = if fit == "Roomy" then 100 else 92,
		actionW = 124,
		goalH = if fit == "Roomy" then 60 else 54,
	}
end

-- BUILD --------------------------------------------------------------------------------------

type Card = {
	frame: Frame,
	mission: MissionFixtures.Mission,
	icon: Frame,
	title: TextLabel,
	sub: TextLabel,
	chip: Frame,
	chipLabel: TextLabel,
	track: Frame,
	setBar: (number, string) -> (),
	fillGradient: UIGradient,
	claim: Arcade.Button,
	pill: Frame,
	pillLabel: TextLabel,
	pillIcon: Frame,
	pillGradient: UIGradient,
	stroke: UIStroke,
	fade: any,
	numbers: string,
	action: string,
}

type GoalRow = {
	frame: Frame,
	goal: MissionFixtures.Goal,
	tick: Frame,
	tickIcon: Frame,
	label: TextLabel,
	right: TextLabel,
	stroke: UIStroke,
	isNext: boolean,
}

local function copyState(source: MissionFixtures.State): MissionFixtures.State
	local function list<T>(items: { T }): { T }
		local out: { T } = {}
		for _, item in items do
			table.insert(out, table.clone(item :: any))
		end
		return out
	end
	return {
		source = source.source,
		load = source.load,
		missions = list(source.missions),
		goals = list(source.goals),
		pool = list(source.pool),
	}
end

function MissionsPanel.new(ctx: Overlay.Ctx, options: Options?): Panel
	local opts: Options = options or {}
	local state = copyState(opts.state or (MissionFixtures.preset("InProgress3") :: MissionFixtures.State))
	local geo = MissionsPanel.geometry(Vector2.new(750, 325))
	local tab: Tab = "Missions"
	local cards: { Card } = {}
	local goalRows: { GoalRow } = {}
	local latch: { [string]: boolean } = {} -- goals seen done stay done
	local replaced: { [any]: boolean } = {} -- a claimed mission is replaced once
	local poolIndex = 0
	local claimTaps, claimRequests, claimsResolved, replacements, refreshes = 0, 0, 0, 0, 0
	local listeners: { (MissionFixtures.State) -> () } = {}
	local lastClaimable = -1
	local panelObj: Panel

	local overlay = Overlay.new(ctx, {
		name = "MissionsPanel",
		onDim = function()
			panelObj:close()
		end,
	})
	local trove = overlay.trove
	local flowTrove = trove:Extend() -- claim round trips, holds and replacements
	local content = overlay.content

	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header = Style.header(panel, { fill = "Missions", title = "MISSIONS", icon = "Missions" })
	local closeX = SupportKit.closeX(panel, function()
		panelObj:close()
	end)
	trove:Add(closeX.trove)

	local missionsTab = Style.tab(panel, {
		name = "MissionsTab",
		label = "Missions",
		onActivate = function()
			panelObj:selectTab("Missions")
		end,
	})
	local goalsTab = Style.tab(panel, {
		name = "GoalsTab",
		label = "Goals",
		onActivate = function()
			panelObj:selectTab("Goals")
		end,
	})
	trove:Add(missionsTab.trove)
	trove:Add(goalsTab.trove)

	local missionList = Style.scroll(panel, "MissionList", 5)
	missionList.ScrollBarThickness = 6
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = missionList,
	})
	local goalList = Style.scroll(panel, "GoalList", 5)
	goalList.ScrollBarThickness = 6
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = goalList,
	})
	local message = SupportKit.label(panel, "Message", 22, 6)
	message.TextXAlignment = Enum.TextXAlignment.Center
	local retryButton = Arcade.button(panel, {
		name = "Retry",
		label = "TRY AGAIN",
		fill = "Garage",
		size = "Custom",
		width = 190,
		height = 52,
		onActivate = function()
			if opts.onRetry then
				opts.onRetry()
			end
		end,
	})
	trove:Add(retryButton.trove)
	retryButton.root.ZIndex = 12
	retryButton.root.Visible = false
	-- a harness control: the explicit daily-refresh switch (hidden unless the harness shows its captions)
	local refreshButton = Arcade.button(panel, {
		name = "FixtureRefresh",
		label = "Refresh (fixture)",
		fill = "Home",
		size = "Custom",
		width = 190,
		height = 48,
		onActivate = function()
			panelObj:fixtureRefresh()
		end,
	})
	trove:Add(refreshButton.trove)
	refreshButton.root.ZIndex = 14
	refreshButton.root.Visible = false
	refreshButton.root:SetAttribute("PreviewCaption", true)

	-- STATE HELPERS --------------------------------------------------------------------------

	local function visibleMissions(): { MissionFixtures.Mission }
		local out: { MissionFixtures.Mission } = {}
		for i, m in state.missions do
			if i > MAX_MISSIONS then
				break
			end
			table.insert(out, m)
		end
		return out
	end

	local function claimableCount(): number
		local n = 0
		for _, m in visibleMissions() do
			if MissionFixtures.visual(m) == "Ready" then
				n += 1
			end
		end
		return n
	end

	local function notify()
		for _, fn in table.clone(listeners) do
			fn(state)
		end
		local n = claimableCount()
		if n ~= lastClaimable then
			lastClaimable = n
			if opts.onClaimableChanged then
				opts.onClaimableChanged(n)
			end
		end
	end

	local function nextMission(): MissionFixtures.Mission
		poolIndex += 1
		local source = state.pool[((poolIndex - 1) % math.max(#state.pool, 1)) + 1]
		if source == nil then
			return MissionFixtures.fromTemplate(poolIndex)
		end
		local fresh = table.clone(source)
		fresh.id = source.id .. "#" .. poolIndex -- unique even when the pool cycles
		fresh.progress = fresh.progress or 0
		fresh.claim = "None"
		return fresh
	end

	local function goalDone(g: MissionFixtures.Goal): boolean
		return g.done or latch[g.id] == true
	end

	-- CARDS ----------------------------------------------------------------------------------

	local function numbersText(m: MissionFixtures.Mission): string
		local visual = MissionFixtures.visual(m)
		if visual == "Checking" then
			return "Checking..."
		end
		local p = m.progress :: number
		local shown = if p ~= p or p < 0 then 0 else math.min(p, m.target)
		if m.format == "cash" then
			return string.format("%s / %s", Format.cash(shown), Format.cash(m.target))
		end
		return string.format("%s / %s", Format.group(shown), Format.group(m.target))
	end

	local function refreshCard(card: Card)
		local m = card.mission
		local visual = MissionFixtures.visual(m)
		local fraction = SupportKit.fraction(m.progress, m.target, "mission:" .. m.id)
		local done = visual == "Ready" or visual == "Claimed" or visual == "Pending"
		card.numbers = numbersText(m)
		card.setBar(if visual == "Claimed" or visual == "Pending" then 1 else (fraction or 0), card.numbers)
		card.fillGradient.Color = if done then A.Fill.Green else A.Fill.Garage
		card.title.Text = m.text
		local subText = m.sub or ""
		if m.claim == "Error" and visual == "Ready" then
			subText = "Could not claim. Try again."
		end
		card.sub.Text = subText
		card.chipLabel.Text =
			string.format('PREVIEW reward <font color="#FFD24A">%s</font>', Format.cash(math.max(m.reward, 0)))
		card.icon:ClearAllChildren()
		IconArt.draw(card.icon, { m.icon, "Star" })
		-- the one action
		card.claim.root.Visible = visual == "Ready"
		card.pill.Visible = visual ~= "Ready"
		if visual == "Ready" then
			card.action = "CLAIM"
		elseif visual == "Claimed" then
			card.action = "CLAIMED"
			card.pillLabel.Text = "CLAIMED"
			card.pillGradient.Color = A.Fill.Green
			card.pillIcon.Visible = true
		elseif visual == "InProgress" then
			card.action = "Keep going"
			card.pillLabel.Text = "Keep going"
			card.pillGradient.Color = A.Fill.Garage
			card.pillIcon.Visible = false
		else
			card.action = "Checking..."
			card.pillLabel.Text = "Checking..."
			card.pillGradient.Color = A.Fill.Disabled
			card.pillIcon.Visible = false
		end
		card.stroke.Color = if visual == "Ready" then PreviewTokens.Color.KeysLight else A.Ink
		card.stroke.Thickness = if visual == "Ready" then 4 else A.OutlineMinor
		card.frame.BackgroundColor3 = if visual == "Claimed" then Color3.fromRGB(24, 90, 54) else Style.Well
	end

	local function layoutCard(card: Card)
		local cardW, cardH, actionW = geo.cardW, geo.cardH, geo.actionW
		card.frame.Size = UDim2.fromOffset(cardW, cardH)
		card.icon.Position = UDim2.fromOffset(10, (cardH - 48) / 2)
		local textX = 68
		local textW = cardW - textX - actionW - 18
		card.title.Position = UDim2.fromOffset(textX, 5)
		card.title.Size = UDim2.fromOffset(textW, 30)
		SupportKit.fitLabel(card.title, card.mission.text, textW, 30, 20)
		local chipW = math.ceil(SupportKit.measure("PREVIEW reward $250", 16).X) + 40
		card.chip.Size = UDim2.fromOffset(chipW, 24)
		card.chip.Position = UDim2.fromOffset(textX + textW - chipW, 36)
		card.sub.Position = UDim2.fromOffset(textX, 34)
		card.sub.Size = UDim2.fromOffset(math.max(textW - chipW - 6, 40), 28)
		SupportKit.fitLabel(card.sub, card.sub.Text, math.max(textW - chipW - 6, 40), 28, 16)
		card.track.Position = UDim2.fromOffset(textX, cardH - 31)
		card.track.Size = UDim2.fromOffset(textW, 22)
		for _, o in { card.claim.root, card.pill } do
			o.AnchorPoint = Vector2.new(0.5, 0.5)
			o.Position = UDim2.fromOffset(cardW - actionW / 2 - 10, cardH / 2)
		end
	end

	local function buildCard(index: number, mission: MissionFixtures.Mission): Card
		local frame = Style.well(missionList, "Card" .. index, 6)
		frame.LayoutOrder = index
		local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
		make("UIScale", { Name = "Pop", Parent = frame })
		local icon: Frame = make("Frame", {
			Name = "Icon",
			Size = UDim2.fromOffset(48, 48),
			BackgroundTransparency = 1,
			ZIndex = 7,
			Parent = frame,
		})
		local title = SupportKit.label(frame, "Title", 20, 7)
		local sub = SupportKit.label(frame, "Sub", 16, 7)
		sub.TextColor3 = Style.TextSoft
		local chip: Frame = make("Frame", {
			Name = "RewardChip",
			BackgroundColor3 = A.Ink,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = frame,
		})
		Arcade.corner(chip, 12)
		Arcade.outline(chip, "Minor")
		local coin: Frame = make("Frame", {
			Name = "Coin",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 5, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			ZIndex = 8,
			Parent = chip,
		})
		IconArt.draw(coin, { "Coin" })
		local chipLabel = SupportKit.label(chip, "Text", 16, 8)
		chipLabel.RichText = true
		chipLabel.Position = UDim2.fromOffset(26, 0)
		chipLabel.Size = UDim2.new(1, -28, 1, 0)
		chipLabel.TextXAlignment = Enum.TextXAlignment.Left
		local track, setBar = Overlay.progress(frame, "Garage", 7)
		local fillGradient = (track:FindFirstChild("Fill") :: Frame):FindFirstChildOfClass("UIGradient") :: UIGradient
		local cardRef: Card? = nil
		local claim = Arcade.button(frame, {
			name = "Claim",
			label = "CLAIM",
			fill = "Green",
			size = "Custom",
			width = 124,
			height = 48,
			pattern = true,
			cooldown = 0.4,
			onActivate = function()
				claimTaps += 1
				local current = cardRef
				if current then
					panelObj:pressClaim(current.mission.id) -- the card's CURRENT mission (it can be replaced)
				end
			end,
		})
		claim.root.ZIndex = 9
		local pill: Frame = make("Frame", {
			Name = "Status",
			Size = UDim2.fromOffset(124, 44),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 8,
			Parent = frame,
		})
		Arcade.corner(pill, 7)
		Arcade.outline(pill, "Minor")
		local pillGradient: UIGradient = make("UIGradient", { Color = A.Fill.Garage, Rotation = 90, Parent = pill })
		local pillIcon: Frame = make("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 9,
			Parent = pill,
		})
		IconArt.draw(pillIcon, { "Check" })
		local pillLabel = SupportKit.label(pill, "Text", 18, 9)
		pillLabel.TextXAlignment = Enum.TextXAlignment.Center
		pillLabel.Size = UDim2.fromScale(1, 1)
		local card: Card = {
			frame = frame,
			mission = mission,
			icon = icon,
			title = title,
			sub = sub,
			chip = chip,
			chipLabel = chipLabel,
			track = track,
			setBar = setBar,
			fillGradient = fillGradient,
			claim = claim,
			pill = pill,
			pillLabel = pillLabel,
			pillIcon = pillIcon,
			pillGradient = pillGradient,
			stroke = stroke,
			fade = nil,
			numbers = "",
			action = "",
		}
		cardRef = card
		refreshCard(card)
		layoutCard(card)
		card.fade = Fade.capture(frame)
		return card
	end

	local function clearCards()
		for _, c in cards do
			c.claim.destroy()
			if c.fade then
				c.fade:destroy()
			end
			Motion.cancelAll(c.frame)
			c.frame:Destroy()
		end
		table.clear(cards)
	end

	local function findCard(id: string): (Card?, number)
		for i, c in cards do
			if c.mission.id == id then
				return c, i
			end
		end
		return nil, 0
	end

	-- GOALS ----------------------------------------------------------------------------------

	local function clearGoals()
		for _, r in goalRows do
			r.frame:Destroy()
		end
		table.clear(goalRows)
	end

	local function goalRight(row: GoalRow): string
		local g = row.goal
		if goalDone(g) then
			return "DONE"
		end
		local count = ""
		if g.progress ~= nil and g.target ~= nil then
			count = string.format(
				"%s / %s",
				Format.group(math.min(g.progress :: number, g.target :: number)),
				Format.group(g.target :: number)
			)
		end
		if row.isNext then
			return if count ~= "" then "NEXT · " .. count else "NEXT"
		end
		return count
	end

	local function layoutGoal(row: GoalRow)
		local w = geo.cardW
		row.frame.Size = UDim2.fromOffset(w, geo.goalH)
		row.tick.Position = UDim2.new(0, 10, 0.5, 0)
		local rightW = 124
		row.label.Position = UDim2.new(0, 54, 0.5, 0)
		row.label.Size = UDim2.fromOffset(w - 54 - rightW - 10, geo.goalH - 8)
		SupportKit.fitLabel(row.label, row.goal.text, w - 54 - rightW - 10, geo.goalH - 8, 20)
		row.right.Position = UDim2.new(1, -8, 0.5, 0)
		row.right.Size = UDim2.fromOffset(rightW, 28)
	end

	local function rebuildGoals()
		clearGoals()
		local nextFound = false
		for _, g in state.goals do
			if goalDone(g) then
				latch[g.id] = true
			end
		end
		for i, g in state.goals do
			local done = goalDone(g)
			local isNext = false
			if not done and not nextFound then
				isNext = true
				nextFound = true
			end
			local frame = Style.well(goalList, "Goal_" .. g.id, 6)
			frame.LayoutOrder = i
			local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
			if isNext then
				stroke.Color = PreviewTokens.Color.KeysLight
				stroke.Thickness = 4
			end
			if done then
				frame.BackgroundColor3 = Color3.fromRGB(24, 90, 54)
			end
			local tick: Frame = make("Frame", {
				Name = "Tick",
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.fromOffset(34, 34),
				BackgroundColor3 = if done then PreviewTokens.Color.Success else A.Ink,
				ZIndex = 7,
				Parent = frame,
			})
			Arcade.corner(tick, 8)
			Arcade.outline(tick, "Minor")
			local tickIcon: Frame = make("Frame", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(24, 24),
				BackgroundTransparency = 1,
				ZIndex = 8,
				Parent = tick,
			})
			if done then
				IconArt.draw(tickIcon, { "Check" })
			else
				IconArt.draw(tickIcon, { g.icon, "Star" })
			end
			local label = SupportKit.label(frame, "Text", 20, 7)
			label.AnchorPoint = Vector2.new(0, 0.5)
			label.Text = g.text
			local right = SupportKit.label(frame, "Right", 16, 7)
			right.AnchorPoint = Vector2.new(1, 0.5)
			right.TextXAlignment = Enum.TextXAlignment.Right
			right.TextColor3 = if isNext then PreviewTokens.Color.KeysLight else Style.TextSoft
			local row: GoalRow = {
				frame = frame,
				goal = g,
				tick = tick,
				tickIcon = tickIcon,
				label = label,
				right = right,
				stroke = stroke,
				isNext = isNext,
			}
			right.Text = goalRight(row)
			table.insert(goalRows, row)
			layoutGoal(row)
		end
	end

	-- VIEW -----------------------------------------------------------------------------------

	local function messageText(): string
		if state.load == "Loading" then
			return "Checking..."
		elseif state.load == "Error" then
			return "Could not load your Missions."
		elseif tab == "Missions" and #state.missions == 0 then
			return "No Missions right now. Check back soon!"
		end
		return ""
	end

	local function applyView()
		local ready = state.load == "Ready"
		local text = messageText()
		missionList.Visible = ready and tab == "Missions" and #state.missions > 0
		goalList.Visible = ready and tab == "Goals"
		message.Visible = text ~= ""
		SupportKit.fitLabel(message, text, geo.list.w - 20, 60, 22)
		retryButton.root.Visible = state.load == "Error" and opts.onRetry ~= nil
		missionsTab.set(tab == "Missions")
		goalsTab.set(tab == "Goals")
	end

	local function rebuildMissions()
		clearCards()
		for i, m in visibleMissions() do
			table.insert(cards, buildCard(i, m))
		end
		-- the Home menu badge and the tracker follow
		notify()
	end

	local function rebuildAll()
		rebuildMissions()
		rebuildGoals()
		applyView()
	end

	local function layoutNow()
		overlay:applyScale()
		geo = MissionsPanel.geometry(overlay:designSize())
		shell.root.Size = UDim2.fromOffset(geo.pw, geo.ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		header.setHeight(geo.headH)
		closeX.root.Position = UDim2.new(1, -8, 0, geo.headH / 2)
		local left = header.title.Position.X.Offset
		header.title.AnchorPoint = Vector2.new(0, 0.5)
		header.title.Position = UDim2.new(0, left, 0.5, 0)
		header.title.Size = UDim2.new(1, -left - 70, 0, math.min(A.Text.Display + 8, geo.headH - 6))
		missionsTab.root.Position = UDim2.fromOffset(12, geo.tabY)
		missionsTab.root.Size = UDim2.fromOffset(geo.tabW, geo.tabsH)
		goalsTab.root.Position = UDim2.fromOffset(12 + geo.tabW + 8, geo.tabY)
		goalsTab.root.Size = UDim2.fromOffset(geo.tabW, geo.tabsH)
		for _, l in { missionList, goalList } do
			l.Position = UDim2.fromOffset(geo.list.x, geo.list.y)
			l.Size = UDim2.fromOffset(geo.list.w, geo.list.h)
		end
		message.Position = UDim2.fromOffset(geo.list.x + 10, geo.list.y + geo.list.h / 2 - 50)
		message.Size = UDim2.fromOffset(geo.list.w - 20, 60)
		SupportKit.fitLabel(message, message.Text, geo.list.w - 20, 60, 22)
		retryButton.root.AnchorPoint = Vector2.new(0.5, 0)
		retryButton.root.Position = UDim2.fromOffset(geo.pw / 2, geo.list.y + geo.list.h / 2 + 14)
		refreshButton.root.AnchorPoint = Vector2.new(1, 1)
		refreshButton.root.Position = UDim2.fromOffset(geo.pw - 14, geo.ph - 10)
		for _, c in cards do
			layoutCard(c)
		end
		for _, r in goalRows do
			layoutGoal(r)
		end
	end

	-- CLAIM FLOW -----------------------------------------------------------------------------

	local function replaceCard(card: Card)
		if replaced[card.mission] then
			return
		end
		replaced[card.mission] = true
		local index = table.find(state.missions, card.mission)
		if not index then
			return
		end
		replacements += 1
		local fresh = nextMission()
		state.missions[index] = fresh
		local function swap()
			card.mission = fresh
			refreshCard(card)
			layoutCard(card)
			card.fade:tween(0, if Motion.reduced() then 0 else 0.22)
			notify()
		end
		if Motion.reduced() then
			swap()
			return
		end
		local tween = card.fade:tween(1, 0.16)
		if tween then
			tween.Completed:Once(function()
				if card.frame.Parent then
					swap()
				end
			end)
		else
			swap()
		end
	end

	local function celebrate(card: Card)
		Sounds.play("Unlock")
		if Motion.reduced() then
			return
		end
		Motion.pop(card.frame, 1.04)
		local centre = Vector2.new(geo.cardW - geo.actionW / 2 - 10, geo.cardH / 2)
		flowTrove:Add(SupportKit.burst(card.frame, centre, 14, claimsResolved + 3))
	end

	local function scheduleReplacement(card: Card)
		local hold = if Motion.reduced() then CLAIM_HOLD_REDUCED else CLAIM_HOLD
		flowTrove:Add(task.delay(hold, function()
			replaceCard(card)
		end))
	end

	local function resolve(id: string, outcome: "Success" | "Error"): boolean
		local card = findCard(id)
		if not card or card.mission.claim ~= "Pending" then
			return false
		end
		if outcome == "Success" then
			card.mission.claim = "Claimed"
			claimsResolved += 1
			refreshCard(card)
			celebrate(card)
			scheduleReplacement(card)
		else
			card.mission.claim = "Error"
			refreshCard(card)
			layoutCard(card)
		end
		notify()
		return true
	end

	overlay:setBack(function()
		panelObj:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	panelObj = {
		root = overlay.root,
		layout = function(_self: Panel)
			layoutNow()
		end,
		setVisible = function(_self: Panel, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		open = function(_self: Panel, returnTo: GuiObject?)
			if overlay:isOpen() then
				return
			end
			layoutNow()
			rebuildAll()
			layoutNow()
			overlay:open(closeX.root, returnTo)
		end,
		close = function(_self: Panel)
			if not overlay:isOpen() then
				return
			end
			overlay:close()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Panel): boolean
			return overlay:isOpen()
		end,
		selectTab = function(_self: Panel, which: Tab)
			if which == tab then
				return
			end
			tab = which
			if tab == "Goals" then
				rebuildGoals()
			end
			applyView()
		end,
		setState = function(_self: Panel, incoming: MissionFixtures.State)
			flowTrove:Clean()
			state = copyState(incoming)
			replaced = {}
			poolIndex = 0
			table.clear(latch)
			rebuildAll()
			layoutNow()
		end,
		setPreset = function(self: Panel, name: string): boolean
			local incoming = MissionFixtures.preset(name)
			if not incoming then
				return false
			end
			self:setState(incoming)
			return true
		end,
		pressClaim = function(_self: Panel, id: string): boolean
			local card = findCard(id)
			if not card or MissionFixtures.visual(card.mission) ~= "Ready" then
				return false -- a repeated tap while pending, or a card that is not ready: nothing happens
			end
			card.mission.claim = "Pending"
			claimRequests += 1
			refreshCard(card)
			notify()
			if opts.onClaim then
				opts.onClaim(id)
			end
			local mode = opts.previewResolve or (if opts.onClaim == nil then "Success" else "None")
			if mode ~= "None" then
				flowTrove:Add(task.delay(PREVIEW_RESOLVE_SECONDS, function()
					resolve(id, mode :: "Success" | "Error")
				end))
			end
			return true
		end,
		resolveClaim = function(_self: Panel, id: string, outcome: "Success" | "Error"): boolean
			return resolve(id, outcome)
		end,
		fixtureRefresh = function(_self: Panel): number
			-- explicit fixture switch: untouched missions (progress exactly 0, nothing pending) get a fresh template
			local changed = 0
			for index, m in state.missions do
				if index <= MAX_MISSIONS and m.claim == "None" and m.progress == 0 then
					state.missions[index] = nextMission()
					changed += 1
				end
			end
			refreshes += 1
			if changed > 0 then
				rebuildMissions()
				layoutNow()
			end
			return changed
		end,
		subscribe = function(_self: Panel, fn: (MissionFixtures.State) -> ()): () -> ()
			table.insert(listeners, fn)
			return function()
				local i = table.find(listeners, fn)
				if i then
					table.remove(listeners, i)
				end
			end
		end,
		getState = function(_self: Panel): MissionFixtures.State
			return state
		end,
		topMission = function(_self: Panel): MissionFixtures.Mission?
			return MissionFixtures.top(visibleMissions())
		end,
		destroy = function(_self: Panel)
			clearCards()
			overlay:destroy()
		end,
		getDebugState = function(_self: Panel): DebugState
			local cardInfo: { CardDebug } = {}
			for _, c in cards do
				table.insert(cardInfo, {
					id = c.mission.id,
					visual = MissionFixtures.visual(c.mission),
					numbers = c.numbers,
					action = c.action,
					sub = c.sub.Text,
					reward = c.chipLabel.Text,
				})
			end
			local goalInfo = {}
			for _, r in goalRows do
				table.insert(goalInfo, { id = r.goal.id, done = goalDone(r.goal), next = r.isNext })
			end
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				tab = tab,
				load = state.load,
				cards = cardInfo,
				goals = goalInfo,
				claimTaps = claimTaps,
				claimRequests = claimRequests,
				claimsResolved = claimsResolved,
				replacements = replacements,
				refreshes = refreshes,
				message = message.Text,
				instances = #overlay.root:GetDescendants(),
			}
		end,
		touchReport = function(_self: Panel): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	rebuildAll()
	layoutNow()
	return panelObj
end

return MissionsPanel
