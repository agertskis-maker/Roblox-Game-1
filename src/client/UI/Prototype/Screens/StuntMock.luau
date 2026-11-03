--!strict
-- StuntMock: the Stunt Circuit race HUD (Lane 3, PREVIEW only; big round M17-04, finished 2026-11-01). There is no racing
-- simulation, no leaderboard and no reward: every number is a fixture that the caller sets (or the local display clock started
-- by :play()). HUD rebuild (2026-10-22, H-15): the lap timer is a large italic outlined number with no backing card; the mode
-- tag, checkpoints, ghost, flash and medal list are compact dark kit chips with the thick boundary (no cream pills).
--
--   local stunt = StuntMock.new(ctx, { onExit = fn? })
--   stunt:open(returnTo?)  stunt:close()  stunt:isOpen()
--   stunt:setTime(seconds)              -- lap timer display, m:ss.cc (the timer is the stable anchor at the top)
--   stunt:setCheckpoint(n, total)       -- "CHECKPOINT 3 / 5" plus segment ticks (secondary to the timer)
--   stunt:setGhostGap(seconds?)         -- "+0.42 behind" / "-0.42 ahead" with "ghost"; nil, NaN or a silly value hides it
--   stunt:setMedals({ gold, silver, bronze })   -- PREVIEW target times in seconds (StuntFixtures.MedalTargets)
--   stunt:flashCheckpoint(n, delta?)    -- a short "CHECKPOINT 2" banner, with the ghost split when one is supplied
--   stunt:setPreset("AheadOfGhost")     -- StuntFixtures.HudPresets: Default, AheadOfGhost, NoGhost, Start, GoldMissed, AllMissed
--   stunt:play() / stunt:stop()         -- a local 10 Hz display clock (not a simulation)
--   stunt:layout()  stunt:setVisible(on)  stunt:destroy()  stunt:getDebugState()
--
-- THE MEDAL LIST (M17-04b): the three targets are NAMED PREVIEW values with a PREVIEW caption that stays on screen. A target
-- the clock has already passed is MISSED: its row is dimmed and its time struck through (state is never colour alone); the
-- best target still reachable carries a white outline (the goal). Nothing here says the targets are balanced.
--
-- Consistency with outline v2.2 section 10: one lap of about 60-90 s, checkpoints about every 15 s (so the default total is 5:
-- four arches and the line), Bronze / Silver / Gold target times, your own best run as a ghost, Heat off (no Heat bar here).
-- Reduced motion: the checkpoint banner appears and disappears with no movement. Back (Escape / gamepad B) closes the mock.

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)
local StuntFixtures = require(Prototype.SupportFixtures.StuntFixtures)

local A = PreviewTokens.Arcade
local make = Arcade.make

local StuntMock = {}

StuntMock.DefaultMedals = table.clone(StuntFixtures.MedalTargets) -- PREVIEW seconds (kept for older callers)

export type Medals = StuntFixtures.Targets

export type Options = {
	onExit: (() -> ())?,
}

export type DebugState = {
	open: boolean,
	kind: string,
	time: number,
	timeText: string,
	checkpoint: number,
	checkpoints: number,
	ghostGap: number?,
	ghostText: string,
	ghostVisible: boolean,
	medals: Medals,
	missed: { string },
	goal: string,
	caption: string,
	tagCaption: string,
	flashText: string,
	flashVisible: boolean,
	preset: string,
	playing: boolean,
}

export type Stunt = {
	root: Frame,
	layout: (self: Stunt) -> (),
	setVisible: (self: Stunt, on: boolean) -> (),
	open: (self: Stunt, returnTo: GuiObject?) -> (),
	close: (self: Stunt) -> (),
	isOpen: (self: Stunt) -> boolean,
	setTime: (self: Stunt, seconds: number) -> (),
	setCheckpoint: (self: Stunt, n: number, total: number) -> (),
	setGhostGap: (self: Stunt, seconds: number?) -> (),
	setMedals: (self: Stunt, medals: Medals) -> (),
	flashCheckpoint: (self: Stunt, n: number, delta: number?) -> (),
	setPreset: (self: Stunt, name: string) -> boolean,
	play: (self: Stunt) -> (),
	stop: (self: Stunt) -> (),
	destroy: (self: Stunt) -> (),
	getDebugState: (self: Stunt) -> DebugState,
}

function StuntMock.formatTime(seconds: number): string
	return StuntFixtures.formatTime(seconds)
end

local MEDALS = {
	{ key = "gold", word = "GOLD", letter = "G", colour = Color3.fromRGB(255, 210, 74) },
	{ key = "silver", word = "SILVER", letter = "S", colour = Color3.fromRGB(206, 214, 226) },
	{ key = "bronze", word = "BRONZE", letter = "B", colour = Color3.fromRGB(214, 140, 70) },
}

-- TOKEN CANDIDATE: ghost chip tints (behind = warm, ahead = cool) over the dark chip.
local GHOST_BEHIND = Color3.fromRGB(255, 196, 120)
local GHOST_AHEAD = Color3.fromRGB(120, 245, 225)

local FLASH_SECONDS = 1.6
local GHOST_LIMIT = 599 -- a gap beyond ten minutes is not meaningful for a lap of about a minute and a half

local function meaningful(gap: number?): boolean
	if gap == nil then
		return false
	end
	local g = gap :: number
	return g == g and math.abs(g) <= GHOST_LIMIT
end

function StuntMock.new(ctx: Overlay.Ctx, options: Options?): Stunt
	local opts: Options = options or {}
	local time = 42.18
	local checkpoint, checkpoints = 3, 5
	local ghostGap: number? = 0.42
	local medals: Medals = table.clone(StuntMock.DefaultMedals)
	local playing = false
	local playToken = 0
	local presetName = "Default"
	local flashToken = 0
	local lastStateKey = ""
	local stunt: Stunt

	local overlay = Overlay.new(ctx, { name = "StuntMock", dim = false, sounds = false })
	local trove = overlay.trove
	local content = overlay.content
	local flashTrove = trove:Extend()

	-- mode tag (top-left; Heat is off in the Stunt Circuit, so this corner is free)
	local tag = Style.chip(content, "ModeTag", 4)
	local tagIcon: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = tag,
	})
	Arcade.icon(tagIcon, "Flag")
	local tagText = Overlay.text(tag, "STUNT CIRCUIT", 20, nil, nil, 6)
	tagText.AnchorPoint = Vector2.new(0, 0.5)
	tagText.Position = UDim2.new(0, 46, 0.5, -8)
	tagText.Size = UDim2.new(1, -52, 0, 24)
	-- the persistent caption: it is part of the screen, not a harness caption, so it carries PersistentPreview
	local tagSub = Overlay.text(tag, StuntFixtures.Caption, 16, Style.TextSoft, nil, 6)
	tagSub.Name = "TagCaption"
	tagSub:SetAttribute("PersistentPreview", true)
	tagSub.AnchorPoint = Vector2.new(0, 0.5)
	tagSub.Position = UDim2.new(0, 46, 0.5, 12)
	tagSub.Size = UDim2.new(1, -52, 0, 20)

	-- lap timer (top centre; a big italic outlined number, no panel, like the run's Distance)
	local timer: Frame = make("Frame", { Name = "Timer", BackgroundTransparency = 1, ZIndex = 4, Parent = content })
	local timerIcon: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(42, 42),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = timer,
	})
	Arcade.icon(timerIcon, "Timer")
	local timerText = Style.text(timer, "0:00.00", "Value", { name = "Time", italic = true, face = "White", z = 6 })
	timerText.AnchorPoint = Vector2.new(0, 0.5)
	timerText.Position = UDim2.new(0, 48, 0.5, 0)
	timerText.Size = UDim2.new(1, -48, 0, 48)

	-- checkpoints
	local cp = Style.chip(content, "Checkpoints", 4)
	local cpText = Overlay.text(cp, "", 18, nil, Enum.TextXAlignment.Center, 6)
	cpText.Position = UDim2.fromOffset(0, 3)
	cpText.Size = UDim2.new(1, 0, 0, 24)
	local ticks: Frame = make("Frame", {
		Name = "Ticks",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = cp,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ticks,
	})
	local tickTrove = trove:Extend()

	-- ghost gap (shown only when a meaningful gap is supplied; the layout slot stays so nothing jumps)
	local ghost = Style.chip(content, "GhostGap", 4)
	local ghostValue = Style.text(ghost, "", "Value", {
		name = "Gap",
		italic = true,
		size = 22,
		xAlign = Enum.TextXAlignment.Center,
		z = 6,
	})
	ghostValue.Position = UDim2.fromOffset(4, 2)
	ghostValue.Size = UDim2.new(1, -8, 0, 28)
	local ghostLabel = Overlay.text(ghost, "ghost", 16, Style.TextSoft, Enum.TextXAlignment.Center, 6)
	ghostLabel.Position = UDim2.fromOffset(0, 30)
	ghostLabel.Size = UDim2.new(1, 0, 0, 20)

	-- the checkpoint banner: a short flash under the timer row
	local flash = Style.chip(content, "CheckpointFlash", 8)
	flash.Visible = false
	local flashScale: UIScale = make("UIScale", { Name = "FlashScale", Parent = flash })
	local flashName = Style.text(flash, "", "Label", { name = "Name", size = 24, z = 10 })
	flashName.AnchorPoint = Vector2.new(0, 0.5)
	flashName.Position = UDim2.new(0, 10, 0.5, 0)
	flashName.Size = UDim2.new(0.52, -10, 0, 30)
	local flashDelta = Style.text(flash, "", "Value", {
		name = "Split",
		italic = true,
		size = 22,
		xAlign = Enum.TextXAlignment.Right,
		z = 10,
	})
	flashDelta.AnchorPoint = Vector2.new(1, 0.5)
	flashDelta.Position = UDim2.new(1, -10, 0.5, 0)
	flashDelta.Size = UDim2.new(0.48, -10, 0, 28)

	-- medal targets
	local medalCard = Style.chip(content, "Medals", 4)
	local medalList: Frame = make("Frame", {
		Name = "List",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 1, -12),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = medalCard,
	})
	make("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = medalList,
	})
	type MedalRow = {
		row: Frame,
		disc: Frame,
		word: TextLabel,
		time: TextLabel,
		goal: Frame,
	}
	local medalRows: { [string]: MedalRow } = {}
	for i, m in MEDALS do
		local row: Frame = make("Frame", {
			Name = "Medal_" .. m.word,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = medalList,
		})
		local goal: Frame = make("Frame", {
			Name = "Goal",
			Position = UDim2.fromOffset(-4, 0),
			Size = UDim2.new(1, 8, 1, 0),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 5,
			Parent = row,
		})
		Arcade.corner(goal, 7)
		Arcade.outline(goal, 2, Color3.new(1, 1, 1))
		local disc: Frame = make("Frame", {
			Name = "Disc",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = m.colour,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = row,
		})
		Arcade.corner(disc, 13)
		Arcade.outline(disc, 2.5)
		local letter = Overlay.text(disc, m.letter, 16, A.Ink, Enum.TextXAlignment.Center, 7)
		letter.Size = UDim2.fromScale(1, 1)
		local stroke = letter:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Enabled = false -- dark letter on a light disc needs no outline
		end
		local word = Overlay.text(row, m.word, 16, nil, nil, 6)
		word.Position = UDim2.fromOffset(32, 0)
		word.Size = UDim2.new(1, -32 - 76, 1, 0)
		local t = Style.text(row, "", "Small", {
			name = "Time",
			italic = true,
			xAlign = Enum.TextXAlignment.Right,
			z = 6,
		})
		t.RichText = true
		t.AnchorPoint = Vector2.new(1, 0)
		t.Position = UDim2.fromScale(1, 0)
		t.Size = UDim2.new(0, 76, 1, 0)
		medalRows[m.key] = { row = row, disc = disc, word = word, time = t, goal = goal }
	end
	-- the persistent caption: these targets are PREVIEW values until they are measured with the real car physics
	local medalCaption = Overlay.text(medalList, "PREVIEW targets", 16, Style.TextSoft, Enum.TextXAlignment.Right, 6)
	medalCaption.Name = "TargetsCaption"
	medalCaption:SetAttribute("PersistentPreview", true)
	medalCaption.LayoutOrder = 10
	medalCaption.Size = UDim2.new(1, 0, 0, 20)

	-- which targets the clock has passed, and the best one still reachable
	local function medalStates(): ({ string }, string)
		local missed: { string } = {}
		local goal = ""
		for _, m in MEDALS do
			if time > (medals :: any)[m.key] then
				table.insert(missed, m.key)
			elseif goal == "" then
				goal = m.key
			end
		end
		return missed, goal
	end

	local function renderMedals(force: boolean)
		local missed, goal = medalStates()
		local key = table.concat(missed, ",")
			.. "|"
			.. goal
			.. "|"
			.. medals.gold
			.. ","
			.. medals.silver
			.. ","
			.. medals.bronze
		if not force and key == lastStateKey then
			return
		end
		lastStateKey = key
		for _, m in MEDALS do
			local r = medalRows[m.key]
			local isMissed = table.find(missed, m.key) ~= nil
			local text = StuntFixtures.formatTime((medals :: any)[m.key])
			r.time.Text = if isMissed then "<s>" .. text .. "</s>" else text
			r.time.TextTransparency = if isMissed then 0.45 else 0
			r.word.TextTransparency = if isMissed then 0.45 else 0
			r.disc.BackgroundTransparency = if isMissed then 0.55 else 0
			r.goal.Visible = m.key == goal
			r.row:SetAttribute("Missed", isMissed)
			r.row:SetAttribute("Goal", m.key == goal)
		end
	end

	local function renderGhost()
		local gap = ghostGap
		local show = meaningful(gap)
		ghost.Visible = show
		if show and gap then
			local behind = gap >= 0
			ghostValue.Text = string.format(
				"%s%.2f %s",
				if behind then "+" else "\u{2212}",
				math.abs(gap),
				if behind then "behind" else "ahead"
			)
			ghostValue.TextColor3 = if behind then GHOST_BEHIND else GHOST_AHEAD
			ghostLabel.Text = "ghost"
		end
	end

	local function render()
		timerText.Text = StuntFixtures.formatTime(time)
		cpText.Text = string.format("CHECKPOINT %d / %d", checkpoint, checkpoints)
		tickTrove:Clean()
		for i = 1, checkpoints do
			-- passed ticks are filled AND taller (state is not colour alone)
			local passed = i <= checkpoint
			local tick: Frame = tickTrove:Add(make("Frame", {
				Name = "Tick" .. i,
				Size = UDim2.fromOffset(18, if passed then 12 else 8),
				BackgroundColor3 = if passed then Color3.new(1, 1, 1) else Style.Well,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 7,
				Parent = ticks,
			}))
			Arcade.corner(tick, 3)
			Arcade.outline(tick, 1.5)
		end
		renderGhost()
		renderMedals(true)
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local timerW = 210
		if kind == "Tall" then
			tag.Position = UDim2.fromOffset(8, 6)
			tag.Size = UDim2.fromOffset(200, 54)
			timer.AnchorPoint = Vector2.new(0.5, 0)
			timer.Position = UDim2.new(0.5, 0, 0, 68)
			timer.Size = UDim2.fromOffset(timerW, 54)
			cp.AnchorPoint = Vector2.new(0.5, 0)
			cp.Position = UDim2.new(0.5, -84, 0, 128)
			cp.Size = UDim2.fromOffset(196, 50)
			ghost.AnchorPoint = Vector2.new(0.5, 0)
			ghost.Position = UDim2.new(0.5, 112, 0, 128)
			ghost.Size = UDim2.fromOffset(152, 54)
			medalCard.AnchorPoint = Vector2.new(0.5, 0)
			medalCard.Position = UDim2.new(0.5, 0, 0, 192)
			medalCard.Size = UDim2.fromOffset(250, 124)
			flash.AnchorPoint = Vector2.new(0.5, 0)
			flash.Position = UDim2.new(0.5, 0, 0, 324)
			flash.Size = UDim2.fromOffset(300, 44)
		else
			local short = kind == "Short"
			tag.Position = UDim2.fromOffset(8, 6)
			tag.Size = UDim2.fromOffset(200, 54)
			timer.AnchorPoint = Vector2.new(0.5, 0)
			timer.Position = UDim2.new(0.5, 0, 0, 4)
			timer.Size = UDim2.fromOffset(timerW, 54)
			cp.AnchorPoint = Vector2.new(1, 0)
			cp.Position = UDim2.new(0.5, -6, 0, 62)
			cp.Size = UDim2.fromOffset(196, 50)
			ghost.AnchorPoint = Vector2.new(0, 0)
			ghost.Position = UDim2.new(0.5, 6, 0, 62)
			ghost.Size = UDim2.fromOffset(if short then 156 else 180, 54)
			medalCard.AnchorPoint = Vector2.new(1, 0)
			medalCard.Position = UDim2.new(1, -8, 0, 6)
			medalCard.Size = UDim2.fromOffset(if short then 196 else 220, 124)
			flash.AnchorPoint = Vector2.new(0.5, 0)
			flash.Position = UDim2.new(0.5, 0, 0, 122)
			flash.Size = UDim2.fromOffset(if short then 300 else 340, 44)
		end
	end

	overlay:setBack(function()
		stunt:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)
	trove:Add(function()
		playToken += 1
		flashToken += 1
		Motion.cancelAll(flashScale)
	end)

	local function hideFlash()
		flashToken += 1
		Motion.cancelAll(flashScale)
		flashScale.Scale = 1
		flash.Visible = false
	end

	stunt = {
		root = overlay.root,
		layout = function(_self: Stunt)
			layoutNow()
		end,
		setVisible = function(_self: Stunt, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		open = function(_self: Stunt, returnTo: GuiObject?)
			layoutNow()
			render()
			overlay:open(nil, returnTo)
		end,
		close = function(self: Stunt)
			if not overlay:isOpen() then
				return
			end
			self:stop()
			hideFlash()
			overlay:close()
			if opts.onExit then
				opts.onExit()
			end
		end,
		isOpen = function(_self: Stunt): boolean
			return overlay:isOpen()
		end,
		setTime = function(_self: Stunt, seconds: number)
			time = math.max(seconds, 0)
			timerText.Text = StuntFixtures.formatTime(time)
			renderMedals(false)
		end,
		setCheckpoint = function(_self: Stunt, n: number, total: number)
			checkpoints = math.clamp(math.floor(total), 1, 12)
			checkpoint = math.clamp(math.floor(n), 0, checkpoints)
			render()
		end,
		setGhostGap = function(_self: Stunt, seconds: number?)
			ghostGap = seconds
			renderGhost()
		end,
		setMedals = function(_self: Stunt, m: Medals)
			medals = table.clone(m)
			renderMedals(true)
		end,
		flashCheckpoint = function(_self: Stunt, n: number, delta: number?)
			flashName.Text = string.format("CHECKPOINT %d", math.floor(n))
			if meaningful(delta) and delta then
				local behind = delta >= 0
				flashDelta.Text = string.format("%s%.2f", if behind then "+" else "\u{2212}", math.abs(delta))
				flashDelta.TextColor3 = if behind then GHOST_BEHIND else GHOST_AHEAD
			else
				flashDelta.Text = ""
			end
			flashToken += 1
			local token = flashToken
			Motion.cancelAll(flashScale)
			flash.Visible = true
			if Motion.reduced() then
				flashScale.Scale = 1 -- no movement: it simply appears and goes
			else
				flashScale.Scale = 0.88
				Motion.tween(flashScale, "pop", Motion.info(0.16, Enum.EasingStyle.Back), { Scale = 1 })
			end
			flashTrove:Clean()
			flashTrove:Add(task.delay(FLASH_SECONDS, function()
				if token == flashToken then
					hideFlash()
				end
			end))
		end,
		setPreset = function(_self: Stunt, name: string): boolean
			local preset = (StuntFixtures.HudPresets :: any)[name] :: StuntFixtures.HudPreset?
			if not preset then
				return false
			end
			presetName = name
			time = preset.time
			checkpoint = math.clamp(preset.checkpoint, 0, preset.total)
			checkpoints = preset.total
			ghostGap = preset.ghostGap
			render()
			hideFlash()
			return true
		end,
		play = function(_self: Stunt)
			if playing then
				return
			end
			playing = true
			playToken += 1
			local token = playToken
			trove:Add(task.spawn(function()
				local last = os.clock()
				while playing and token == playToken do
					task.wait(0.1)
					if not playing or token ~= playToken then
						break
					end
					local now = os.clock()
					time += now - last
					last = now
					timerText.Text = StuntFixtures.formatTime(time)
					renderMedals(false)
				end
			end))
		end,
		stop = function(_self: Stunt)
			playing = false
			playToken += 1
		end,
		destroy = function(_self: Stunt)
			playing = false
			overlay:destroy()
		end,
		getDebugState = function(_self: Stunt): DebugState
			local missed, goal = medalStates()
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				time = time,
				timeText = timerText.Text,
				checkpoint = checkpoint,
				checkpoints = checkpoints,
				ghostGap = ghostGap,
				ghostText = if ghost.Visible then ghostValue.Text .. " " .. ghostLabel.Text else "",
				ghostVisible = ghost.Visible,
				medals = table.clone(medals),
				missed = missed,
				goal = goal,
				caption = medalCaption.Text,
				tagCaption = tagSub.Text,
				flashText = flashName.Text .. " " .. flashDelta.Text,
				flashVisible = flash.Visible,
				preset = presetName,
				playing = playing,
			}
		end,
	}

	layoutNow()
	render()
	return stunt
end

return StuntMock
