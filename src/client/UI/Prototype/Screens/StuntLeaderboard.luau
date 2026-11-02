--!strict
-- StuntLeaderboard: the weekly Stunt Circuit board (Lane 3, big round M17-04 and M17-04b; PREVIEW). The top ten, and the local
-- player's own row or "No time yet", pinned under the list so it never scrolls away.
--
--   local board = StuntLeaderboard.new(ctx, { board = Board?, onRetry = fn?, onClose = fn? })
--   board:open(returnTo?)  board:close()  board:isOpen()
--   board:setBoard(board)              -- a StuntFixtures.Board (StuntFixtures.board("InTop") ...)
--   board:setPreset("InTop")           -- InTop, Outside, Tied, NoTime, Empty, Loading, Error (StuntFixtures.BoardOrder)
--   board:pressRetry() -> boolean      -- the TRY AGAIN of the Error view: calls options.onRetry once per press
--   board:layout()  board:setVisible(on)  board:destroy()  board:getDebugState()  board:touchReport()
--   StuntLeaderboard.geometry(designSize) -> Geo
--
-- NEVER FAKE LIVE COMPETITORS (M17-04b). Every name is a plain placeholder ("Preview Racer 03") and a PREVIEW chip and the line
-- "Preview names, not real players" stay on screen at all times; the real board is Brian L's. Ties share a rank and show it with
-- an equals sign ("4="); the next rank skips. The player's row is highlighted AND says "You", so it never depends on colour.
--
-- States: Ready (ten rows), Empty ("No times this week yet"), Loading, Error (with TRY AGAIN, a 48 px button), a player with no time
-- ("No time yet"), a player inside the top ten (their row is marked in the list and pinned below), a player outside it (pinned
-- below with the rank).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Overlay = require(script.Parent.Overlay)
local PreviewTokens = require(Prototype.PreviewTokens)
local Style = require(script.Parent.Style)
local StuntFixtures = require(Prototype.SupportFixtures.StuntFixtures)
local StuntKit = require(script.Parent.StuntKit)
local SupportKit = require(script.Parent.SupportKit)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

local A = PreviewTokens.Arcade
local make = Arcade.make

local StuntLeaderboard = {}

export type Options = {
	board: StuntFixtures.Board?,
	onRetry: (() -> ())?,
	onClose: (() -> ())?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	pw: number,
	ph: number,
	headH: number,
	week: Rect,
	list: Rect,
	pinned: Rect,
	rowH: number,
}

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	preset: string,
	state: string,
	rows: { string },
	youText: string,
	youInList: boolean,
	message: string,
	retryVisible: boolean,
	retryCalls: number,
	caption: string,
	note: string,
	instances: number,
}

export type Leaderboard = {
	root: Frame,
	layout: (self: Leaderboard) -> (),
	setVisible: (self: Leaderboard, on: boolean) -> (),
	open: (self: Leaderboard, returnTo: GuiObject?) -> (),
	close: (self: Leaderboard) -> (),
	isOpen: (self: Leaderboard) -> boolean,
	setBoard: (self: Leaderboard, board: StuntFixtures.Board) -> (),
	setPreset: (self: Leaderboard, name: string) -> boolean,
	pressRetry: (self: Leaderboard) -> boolean,
	destroy: (self: Leaderboard) -> (),
	getDebugState: (self: Leaderboard) -> DebugState,
	touchReport: (self: Leaderboard) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY ---------------------------------------------------------------------------------------------------------------

function StuntLeaderboard.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local pw, ph, headH, rowH, pinnedH
	if fit == "Compact" then
		pw, ph, headH, rowH, pinnedH = math.min(ds.X - 12, 540), ds.Y - 8, 46, 38, 46
	elseif fit == "Regular" then
		pw, ph, headH, rowH, pinnedH = math.min(ds.X - 24, 600), math.min(ds.Y - 16, 460), 54, 42, 50
	else
		pw, ph, headH, rowH, pinnedH = math.min(ds.X - 32, 680), math.min(ds.Y - 24, 560), 60, 46, 54
	end
	local pad = 12
	local weekY = headH + 6
	local weekH = 26
	local listY = weekY + weekH + 4
	local pinnedY = ph - pinnedH - 8
	return {
		fit = fit,
		pw = pw,
		ph = ph,
		headH = headH,
		week = { x = pad, y = weekY, w = pw - pad * 2, h = weekH },
		list = { x = pad, y = listY, w = pw - pad * 2, h = pinnedY - listY - 6 },
		pinned = { x = pad, y = pinnedY, w = pw - pad * 2, h = pinnedH },
		rowH = rowH,
	}
end

-- BUILD ------------------------------------------------------------------------------------------------------------------

function StuntLeaderboard.new(ctx: Overlay.Ctx, options: Options?): Leaderboard
	local opts: Options = options or {}
	local board: StuntFixtures.Board = opts.board or StuntFixtures.board("InTop")
	local geo = StuntLeaderboard.geometry(Vector2.new(750, 325))
	local retryCalls = 0
	local leaderboard: Leaderboard

	local overlay = Overlay.new(ctx, {
		name = "StuntLeaderboard",
		onDim = function()
			leaderboard:close()
		end,
	})
	local trove = overlay.trove
	local rowsTrove = trove:Extend()
	local retryTrove = trove:Extend()
	local content = overlay.content
	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	local header = Style.header(panel, { fill = "Gold", title = "WEEKLY TOP TIMES", icon = "Trophy", rightInset = 200 })
	local closeX = SupportKit.closeX(panel, function()
		leaderboard:close()
	end)
	trove:Add(closeX.trove)
	local preview = StuntKit.previewChip(header.band, nil, 12)
	preview.frame.AnchorPoint = Vector2.new(1, 0.5)

	local weekLabel = SupportKit.label(panel, "Week", 18, 6)
	local noteLabel = SupportKit.label(panel, "Note", 16, 6)
	noteLabel.TextXAlignment = Enum.TextXAlignment.Right
	noteLabel.TextColor3 = PreviewTokens.Color.KeysLight
	noteLabel.Text = "Preview names, not real players"
	noteLabel:SetAttribute("PersistentPreview", true)

	local listBox = Style.well(panel, "ListBox", 5)
	local list = Style.scroll(listBox, "Rows", 6)
	list.ScrollBarThickness = 6
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	local message = SupportKit.label(listBox, "Message", 22, 8)
	message.TextXAlignment = Enum.TextXAlignment.Center
	message.Visible = false
	local pinned = Style.plate(panel, "YourRow", 6, "Garage")
	local pinnedRank = Style.text(pinned, "", "Value", { name = "Rank", italic = true, size = 24, z = 8 })
	local pinnedName = Style.text(pinned, "YOU", "Label", { name = "Name", z = 8 })
	local pinnedTime = Style.text(pinned, "", "Value", {
		name = "Time",
		italic = true,
		size = 24,
		xAlign = Enum.TextXAlignment.Right,
		z = 8,
	})

	local retryButton: Arcade.Button? = nil

	-- ROWS -----------------------------------------------------------------------------------------------------------------

	local rankColours: { [number]: Color3 } = {
		[1] = StuntFixtures.Medals.gold.colour,
		[2] = StuntFixtures.Medals.silver.colour,
		[3] = StuntFixtures.Medals.bronze.colour,
	}

	local function buildRow(entry: StuntFixtures.Entry, index: number)
		local row = if entry.you
			then Style.plate(list, "Row" .. index, 7, "Garage")
			else Style.well(list, "Row" .. index, 7)
		row.Size = UDim2.new(1, -8, 0, geo.rowH)
		row.LayoutOrder = index
		row:SetAttribute("Rank", entry.rankText)
		row:SetAttribute("You", entry.you)
		row:SetAttribute("Tied", entry.tied)
		rowsTrove:Add(row)
		-- a round rank mark for the first three places; the number is always there too
		local markColour = rankColours[entry.rank]
		if markColour then
			local mark: Frame = make("Frame", {
				Name = "RankMark",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0.5, 0),
				Size = UDim2.fromOffset(geo.rowH - 10, geo.rowH - 10),
				BackgroundColor3 = markColour,
				BorderSizePixel = 0,
				ZIndex = 8,
				Parent = row,
			})
			Arcade.corner(mark, 99)
			Arcade.outline(mark, 2)
		end
		local rank = Style.text(row, entry.rankText, "Value", {
			name = "Rank",
			italic = true,
			size = 22,
			xAlign = Enum.TextXAlignment.Center,
			z = 9,
		})
		rank.Position = UDim2.fromOffset(2, 0)
		rank.Size = UDim2.new(0, 56, 1, 0)
		if markColour then
			rank.TextColor3 = A.Ink
			local stroke = rank:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Enabled = false
			end
		end
		local name = Style.text(row, if entry.you then "You" else entry.name, "Label", { name = "Name", z = 9 })
		name.Position = UDim2.fromOffset(64, 0)
		name.Size = UDim2.new(1, -64 - 112, 1, 0)
		local time = Style.text(row, StuntFixtures.formatTime(entry.time), "Value", {
			name = "Time",
			italic = true,
			size = 22,
			xAlign = Enum.TextXAlignment.Right,
			z = 9,
		})
		time.AnchorPoint = Vector2.new(1, 0)
		time.Position = UDim2.fromScale(1, 0)
		time.Size = UDim2.new(0, 108, 1, 0)
	end

	local function renderRetry()
		local show = board.state == "Error"
		if show and not retryButton then
			retryTrove:Clean()
			local b = Arcade.button(listBox, {
				name = "Retry",
				label = "TRY AGAIN",
				fill = "Garage",
				size = "Custom",
				width = 190,
				height = 52,
				cooldown = 0.6,
				onActivate = function()
					leaderboard:pressRetry()
				end,
			})
			retryTrove:Add(b.trove)
			b.root.ZIndex = 12
			b.root.AnchorPoint = Vector2.new(0.5, 0)
			retryButton = b
		end
		local b = retryButton
		if b then
			b.root.Visible = show
		end
	end

	local function render()
		rowsTrove:Clean()
		weekLabel.Text = board.week
		message.Visible = false
		list.Visible = true
		if board.state == "Ready" then
			for i, entry in board.entries do
				buildRow(entry, i)
			end
		elseif board.state == "Loading" then
			list.Visible = false
			message.Visible = true
			message.Text = "Loading times..."
		elseif board.state == "Error" then
			list.Visible = false
			message.Visible = true
			message.Text = "Could not load the times."
		else
			list.Visible = false
			message.Visible = true
			message.Text = "No times this week yet."
		end
		if board.state == "Ready" and #board.entries == 0 then
			list.Visible = false
			message.Visible = true
			message.Text = "No times this week yet."
		end
		-- the pinned row: always your own status
		local you = board.you
		if board.state ~= "Ready" then
			pinnedRank.Text = "--"
			pinnedTime.Text = "--"
		elseif you then
			pinnedRank.Text = "#" .. you.rankText
			pinnedTime.Text = StuntFixtures.formatTime(you.time)
		else
			pinnedRank.Text = "--"
			pinnedTime.Text = "No time yet"
		end
		renderRetry()
	end

	local function layoutNow()
		overlay:applyScale()
		geo = StuntLeaderboard.geometry(overlay:designSize())
		shell.root.Size = UDim2.fromOffset(geo.pw, geo.ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		header.setHeight(geo.headH)
		header.title.Size =
			UDim2.new(1, -header.title.Position.X.Offset - 200, 0, math.min(A.Text.Display + 8, geo.headH - 6))
		closeX.root.Position = UDim2.new(1, -8, 0, geo.headH / 2)
		preview.frame.Position = UDim2.new(1, -8 - Tokens.Touch.Minimum - 8, 0.5, 0)
		local w = geo.week
		weekLabel.Position = UDim2.fromOffset(w.x, w.y)
		weekLabel.Size = UDim2.fromOffset(w.w * 0.4, w.h)
		noteLabel.Position = UDim2.fromOffset(w.x + w.w * 0.4, w.y)
		noteLabel.Size = UDim2.fromOffset(w.w * 0.6, w.h)
		local l = geo.list
		listBox.Position = UDim2.fromOffset(l.x, l.y)
		listBox.Size = UDim2.fromOffset(l.w, l.h)
		list.Position = UDim2.fromOffset(4, 4)
		list.Size = UDim2.new(1, -8, 1, -8)
		message.AnchorPoint = Vector2.new(0.5, 0.5)
		message.Position = UDim2.fromScale(0.5, if board.state == "Error" then 0.36 else 0.5)
		message.Size = UDim2.new(1, -16, 0, 34)
		local b = retryButton
		if b then
			b.root.Position = UDim2.new(0.5, 0, 0.5, 4)
		end
		local p = geo.pinned
		pinned.Position = UDim2.fromOffset(p.x, p.y)
		pinned.Size = UDim2.fromOffset(p.w, p.h)
		pinnedRank.Position = UDim2.fromOffset(8, 0)
		pinnedRank.Size = UDim2.new(0, 80, 1, 0)
		pinnedName.Position = UDim2.fromOffset(92, 0)
		pinnedName.Size = UDim2.new(1, -92 - 170, 1, 0)
		pinnedTime.AnchorPoint = Vector2.new(1, 0)
		pinnedTime.Position = UDim2.fromScale(1, 0)
		pinnedTime.Size = UDim2.new(0, 160, 1, 0)
		for _, row in list:GetChildren() do
			if row:IsA("Frame") then
				row.Size = UDim2.new(1, -8, 0, geo.rowH)
			end
		end
	end

	overlay:setBack(function()
		leaderboard:close()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
		-- row marks depend on the row height: rebuild them at the new size
		render()
	end)

	-- PUBLIC -----------------------------------------------------------------------------------------------------------

	leaderboard = {
		root = overlay.root,
		layout = function(_self: Leaderboard)
			layoutNow()
		end,
		setVisible = function(_self: Leaderboard, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		open = function(_self: Leaderboard, returnTo: GuiObject?)
			if overlay:isOpen() then
				return
			end
			layoutNow()
			render()
			layoutNow()
			local b = retryButton
			overlay:open(if b and board.state == "Error" then b.body else closeX.root, returnTo)
		end,
		close = function(_self: Leaderboard)
			if not overlay:isOpen() then
				return
			end
			overlay:close()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Leaderboard): boolean
			return overlay:isOpen()
		end,
		setBoard = function(_self: Leaderboard, b: StuntFixtures.Board)
			board = b
			render()
			layoutNow()
		end,
		setPreset = function(self: Leaderboard, name: string): boolean
			for _, known in StuntFixtures.BoardOrder do
				if known == name then
					self:setBoard(StuntFixtures.board(name))
					return true
				end
			end
			return false
		end,
		pressRetry = function(_self: Leaderboard): boolean
			if board.state ~= "Error" then
				return false
			end
			retryCalls += 1
			if opts.onRetry then
				opts.onRetry()
			end
			return true
		end,
		destroy = function(_self: Leaderboard)
			overlay:destroy()
		end,
		getDebugState = function(_self: Leaderboard): DebugState
			local rows: { string } = {}
			local youInList = false
			for _, entry in board.entries do
				table.insert(
					rows,
					string.format("%s|%s|%s", entry.rankText, entry.name, StuntFixtures.formatTime(entry.time))
				)
				if entry.you then
					youInList = true
				end
			end
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				preset = board.id,
				state = board.state,
				rows = rows,
				youText = pinnedRank.Text .. " " .. pinnedTime.Text,
				youInList = youInList,
				message = if message.Visible then message.Text else "",
				retryVisible = retryButton ~= nil and retryButton.root.Visible,
				retryCalls = retryCalls,
				caption = preview.label.Text,
				note = noteLabel.Text,
				instances = #overlay.root:GetDescendants(),
			}
		end,
		touchReport = function(_self: Leaderboard): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	layoutNow()
	render()
	layoutNow()
	return leaderboard
end

return StuntLeaderboard
