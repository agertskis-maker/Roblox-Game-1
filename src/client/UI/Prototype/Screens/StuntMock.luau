--!strict
-- StuntMock: a mock-only Stunt Circuit HUD (Lane 3 HUD prototype, PREVIEW only). There is no
-- racing simulation, no leaderboard and no reward: every number is a placeholder that the
-- caller sets (or the local display clock started by :play()).
--
--   local stunt = StuntMock.new(ctx, { onExit = fn? })
--   stunt:open(returnTo?)  stunt:close()  stunt:isOpen()
--   stunt:setTime(seconds)              -- lap timer display, m:ss.cc
--   stunt:setCheckpoint(n, total)       -- "CHECKPOINT 3 / 5" plus segment ticks
--   stunt:setGhostGap(seconds?)         -- "+0.42" (behind) / "-0.42" (ahead), labelled
--                                          "ghost (mock)"; nil hides it
--   stunt:setMedals({ gold, silver, bronze })   -- placeholder target times in seconds
--   stunt:play() / stunt:stop()         -- a local 10 Hz display clock (not a simulation)
--   stunt:layout()  stunt:setVisible(on)  stunt:destroy()  stunt:getDebugState()
--
-- Consistency with outline v2.2 section 10: one lap of about 60-90 s, checkpoints about every
-- 15 s (so the default total is 5, not 8), Bronze / Silver / Gold medal times, your own best
-- run always shown as a ghost, Heat off (no Heat bar here). Medal colours always come with the
-- medal word and its letter. Back (Escape / gamepad B) closes the mock.

local Prototype = script.Parent.Parent
local Gloss = require(Prototype.Gloss)
local Icons = require(Prototype.Icons)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)

local C = PreviewTokens.Color
local make = Gloss.make

local StuntMock = {}

StuntMock.DefaultMedals = { gold = 65, silver = 75, bronze = 90 } -- placeholders, seconds

export type Medals = { gold: number, silver: number, bronze: number }

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
	medals: Medals,
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
	play: (self: Stunt) -> (),
	stop: (self: Stunt) -> (),
	destroy: (self: Stunt) -> (),
	getDebugState: (self: Stunt) -> DebugState,
}

function StuntMock.formatTime(seconds: number): string
	local s = math.max(seconds, 0)
	local m = math.floor(s / 60)
	local rest = s - m * 60
	local cs = math.floor(rest * 100 + 1e-6)
	return string.format("%d:%02d.%02d", m, cs // 100, cs % 100)
end

local MEDALS = {
	{ key = "gold", word = "GOLD", letter = "G", colour = Color3.fromRGB(255, 210, 74) },
	{ key = "silver", word = "SILVER", letter = "S", colour = Color3.fromRGB(206, 214, 226) },
	{ key = "bronze", word = "BRONZE", letter = "B", colour = Color3.fromRGB(214, 140, 70) },
}

local function chip(parent: Instance, name: string, z: number): Frame
	local f = make("Frame", {
		Name = name,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Gloss.corner(f, 14)
	Gloss.stroke(f, 3)
	return f
end

function StuntMock.new(ctx: Overlay.Ctx, options: Options?): Stunt
	local opts: Options = options or {}
	local time = 42.18
	local checkpoint, checkpoints = 3, 5
	local ghostGap: number? = 0.42
	local medals: Medals = table.clone(StuntMock.DefaultMedals)
	local playing = false
	local playToken = 0
	local stunt: Stunt

	local overlay = Overlay.new(ctx, { name = "StuntMock", dim = false, sounds = false })
	local trove = overlay.trove
	local content = overlay.content

	-- mode tag (top-left; Heat is off in the Stunt Circuit, so this corner is free)
	local tag = chip(content, "ModeTag", 4)
	local tagIcon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = tag,
	})
	Icons.draw(tagIcon, "Flag", C.Ink)
	local tagText = Overlay.text(tag, "STUNT CIRCUIT", 18, C.Ink, nil, 6)
	tagText.AnchorPoint = Vector2.new(0, 0.5)
	tagText.Position = UDim2.new(0, 40, 0.5, -8)
	tagText.Size = UDim2.new(1, -48, 0, 22)
	local tagSub = Overlay.text(tag, "mock HUD", 16, C.InkSoft, nil, 6)
	tagSub:SetAttribute("PreviewCaption", true)
	tagSub.AnchorPoint = Vector2.new(0, 0.5)
	tagSub.Position = UDim2.new(0, 40, 0.5, 12)
	tagSub.Size = UDim2.new(1, -48, 0, 20)

	-- lap timer (top centre; outlined digits, no panel, like the run's Distance)
	local timer = make("Frame", { Name = "Timer", BackgroundTransparency = 1, ZIndex = 4, Parent = content })
	local timerIcon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = timer,
	})
	Icons.draw(timerIcon, "Timer", C.White)
	local timerText = Gloss.title(timer, "0:00.00", 40)
	timerText.AnchorPoint = Vector2.new(0, 0.5)
	timerText.Position = UDim2.new(0, 42, 0.5, 0)
	timerText.Size = UDim2.new(1, -42, 0, 48)
	timerText.TextXAlignment = Enum.TextXAlignment.Left
	timerText.ZIndex = 6

	-- checkpoints
	local cp = chip(content, "Checkpoints", 4)
	local cpText = Overlay.text(cp, "", 18, C.Ink, Enum.TextXAlignment.Center, 6)
	cpText.Position = UDim2.fromOffset(0, 4)
	cpText.Size = UDim2.new(1, 0, 0, 22)
	local ticks = make("Frame", {
		Name = "Ticks",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.new(1, -24, 0, 10),
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

	-- ghost gap
	local ghost = chip(content, "GhostGap", 4)
	local ghostValue = Overlay.text(ghost, "", 20, C.Ink, Enum.TextXAlignment.Center, 6)
	ghostValue.Position = UDim2.fromOffset(0, 2)
	ghostValue.Size = UDim2.new(1, 0, 0, 28)
	local ghostLabel = Overlay.text(ghost, "ghost", 16, C.InkSoft, Enum.TextXAlignment.Center, 6)
	ghostLabel.Position = UDim2.fromOffset(0, 30)
	ghostLabel.Size = UDim2.new(1, 0, 0, 20)

	-- medal targets
	local medalCard = chip(content, "Medals", 4)
	local medalList = make("Frame", {
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
	local medalTimes: { [string]: TextLabel } = {}
	for i, m in MEDALS do
		local row = make("Frame", {
			Name = "Medal_" .. m.word,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = medalList,
		})
		local disc = make("Frame", {
			Name = "Disc",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = m.colour,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = row,
		})
		Gloss.corner(disc, 12)
		Gloss.stroke(disc, 2)
		local letter = Overlay.text(disc, m.letter, 16, C.Ink, Enum.TextXAlignment.Center, 7)
		letter.Size = UDim2.fromScale(1, 1)
		local word = Overlay.text(row, m.word, 16, C.Ink, nil, 6)
		word.Position = UDim2.fromOffset(30, 0)
		word.Size = UDim2.new(1, -30 - 72, 1, 0)
		local t = Overlay.text(row, "", 16, C.Ink, Enum.TextXAlignment.Right, 6)
		t.AnchorPoint = Vector2.new(1, 0)
		t.Position = UDim2.fromScale(1, 0)
		t.Size = UDim2.new(0, 72, 1, 0)
		medalTimes[m.key] = t
	end
	local medalCaption = Overlay.text(medalList, "placeholder times", 16, C.InkSoft, Enum.TextXAlignment.Right, 6)
	medalCaption:SetAttribute("PreviewCaption", true)
	medalCaption.LayoutOrder = 10
	medalCaption.Size = UDim2.new(1, 0, 0, 20)

	local function render()
		timerText.Text = StuntMock.formatTime(time)
		cpText.Text = string.format("CHECKPOINT %d / %d", checkpoint, checkpoints)
		tickTrove:Clean()
		for i = 1, checkpoints do
			local tick = tickTrove:Add(make("Frame", {
				Name = "Tick" .. i,
				Size = UDim2.fromOffset(18, 10),
				BackgroundColor3 = if i <= checkpoint then C.HopDeep else C.White,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 7,
				Parent = ticks,
			}))
			Gloss.corner(tick, 5)
			Gloss.stroke(tick, 1.5)
		end
		local gap = ghostGap
		ghost.Visible = gap ~= nil
		if gap then
			local behind = gap >= 0
			ghostValue.Text = string.format(
				"%s%.2f %s",
				if behind then "+" else "\u{2212}",
				math.abs(gap),
				if behind then "behind" else "ahead"
			)
			ghost.BackgroundColor3 = if behind then Color3.fromRGB(255, 226, 190) else Color3.fromRGB(200, 246, 236)
			ghostLabel.Text = "ghost"
		end
		for _, m in MEDALS do
			medalTimes[m.key].Text = StuntMock.formatTime((medals :: any)[m.key])
		end
	end

	local function layoutNow()
		overlay:applyScale()
		local ds = overlay:designSize()
		local kind = Overlay.kindFor(ds)
		local timerW = 196
		if kind == "Tall" then
			tag.Position = UDim2.fromOffset(8, 6)
			tag.Size = UDim2.fromOffset(190, 52)
			timer.AnchorPoint = Vector2.new(0.5, 0)
			timer.Position = UDim2.new(0.5, 0, 0, 66)
			timer.Size = UDim2.fromOffset(timerW, 52)
			cp.AnchorPoint = Vector2.new(0.5, 0)
			cp.Position = UDim2.new(0.5, -84, 0, 124)
			cp.Size = UDim2.fromOffset(196, 48)
			ghost.AnchorPoint = Vector2.new(0.5, 0)
			ghost.Position = UDim2.new(0.5, 112, 0, 124)
			ghost.Size = UDim2.fromOffset(152, 52)
			-- medals: a compact card under the chips
			medalCard.AnchorPoint = Vector2.new(0.5, 0)
			medalCard.Position = UDim2.new(0.5, 0, 0, 184)
			medalCard.Size = UDim2.fromOffset(240, 120)
		else
			local short = kind == "Short"
			tag.Position = UDim2.fromOffset(8, 6)
			tag.Size = UDim2.fromOffset(190, 52)
			timer.AnchorPoint = Vector2.new(0.5, 0)
			timer.Position = UDim2.new(0.5, 0, 0, 4)
			timer.Size = UDim2.fromOffset(timerW, 52)
			cp.AnchorPoint = Vector2.new(1, 0)
			cp.Position = UDim2.new(0.5, -6, 0, 60)
			cp.Size = UDim2.fromOffset(196, 48)
			ghost.AnchorPoint = Vector2.new(0, 0)
			ghost.Position = UDim2.new(0.5, 6, 0, 60)
			ghost.Size = UDim2.fromOffset(if short then 150 else 176, 52)
			medalCard.AnchorPoint = Vector2.new(1, 0)
			medalCard.Position = UDim2.new(1, -8, 0, 6)
			medalCard.Size = UDim2.fromOffset(if short then 184 else 210, 120)
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
	end)

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
			timerText.Text = StuntMock.formatTime(time)
		end,
		setCheckpoint = function(_self: Stunt, n: number, total: number)
			checkpoints = math.clamp(math.floor(total), 1, 12)
			checkpoint = math.clamp(math.floor(n), 0, checkpoints)
			render()
		end,
		setGhostGap = function(_self: Stunt, seconds: number?)
			ghostGap = seconds
			render()
		end,
		setMedals = function(_self: Stunt, m: Medals)
			medals = table.clone(m)
			render()
		end,
		play = function(_self: Stunt)
			if playing then
				return
			end
			playing = true
			playToken += 1
			local token = playToken
			task.spawn(function()
				local last = os.clock()
				while playing and token == playToken do
					task.wait(0.1)
					if not playing or token ~= playToken then
						break
					end
					local now = os.clock()
					time += now - last
					last = now
					timerText.Text = StuntMock.formatTime(time)
				end
			end)
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
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				time = time,
				timeText = timerText.Text,
				checkpoint = checkpoint,
				checkpoints = checkpoints,
				ghostGap = ghostGap,
				ghostText = if ghost.Visible then ghostValue.Text .. " " .. ghostLabel.Text else "",
				medals = table.clone(medals),
				playing = playing,
			}
		end,
	}

	layoutNow()
	render()
	return stunt
end

return StuntMock
