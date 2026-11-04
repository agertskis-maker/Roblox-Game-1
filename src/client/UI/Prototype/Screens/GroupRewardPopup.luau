--!strict
-- GroupRewardPopup: the small "Join the group, get a FREE reward!" pop-up (Lane 3, big round M16; PREVIEW), plus the
-- permanent card the Shop's Free section shows (GroupRewardPopup.card).
--
--   local popup = GroupRewardPopup.new(ctx, { gateway = Gateway?, gate = Gate?, onJoinResult = fn?, onClose = fn?, groupId = n? })
--   popup:request() -> boolean     -- the GATED entry (session cap, tutorial, cards, runs); false = not offered now
--   popup:open(returnTo?)          -- opens regardless of the gate (a deliberate tap on the Shop card)
--   popup:close()  popup:isOpen()  popup:pressJoin() -> boolean   popup:pressNotNow()   -- the button paths, for tests
--   popup:setPreset("Offer_Pending")  popup:setView("Claimed")      -- GroupFixtures presets and forced views
--   popup:layout()  popup:setVisible(on)  popup:destroy()  popup:getDebugState()  popup:touchReport()
--   GroupRewardPopup.geometry(designSize) -> Geo
--   GroupRewardPopup.card(parent, { size?, claimed?, onJoin? }) -> Card   -- the Shop "Free" card
--
-- THE JOIN CALLS. GroupService:PromptJoinAsync and Player:IsInGroupAsync are reached only through the gateway, only when the
-- player presses JOIN, and only inside pcall. The default gateway is a FAKE (GroupFixtures.fakeGateway): nothing joins for real
-- unless the lead passes GroupFixtures.realGateway() for the beta. Each documented GroupMembershipStatus is handled
-- (BRIEF M16-02b): Joined and AlreadyMember say "You're in!"; JoinRequestPending says "Request sent" (a pending request is
-- not membership); None says "You can try again later" (no guessed reason); an exception says "Could not open the group. Try
-- again." The group's displayed name is confirmed before JOIN is offered; if it cannot be, the pop-up says so and offers no
-- JOIN. Repeated JOIN presses while a prompt is open make no second prompt.
--
-- LOOK (Round 2 N7-02). The one panel family: a coloured header with an icon and an outlined title, a red square X, and a
-- light card with navy text for the words. This is the SELLING surface, so the card body is ShopKit.vividBackground (the
-- Shop's slowly moving violet, pink and orange; Reduce Motion keeps the colours and stops the sway): the reward art sits on
-- it, and the words and buttons sit on a white card beside the art.
--
-- NOTHING IS GRANTED. A client-side prompt result is not authority to grant a reward: the result is forwarded through
-- options.onJoinResult for Brian L's server-side verification, and the pop-up always shows "Reward preview. Claiming is not
-- live yet." CLAIMED appears only when the Claimed view is selected explicitly (a fixture), never after a join.
-- TIMING. popup:request() honours options.gate (GroupFixtures.newGate): once per session, only after the tutorial and any
-- welcome or results card, never during a run; any dismissal uses up the session's offer. Always dismissible (X, Not now, Back,
-- tapping outside).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local GroupFixtures = require(Prototype.SupportFixtures.GroupFixtures)
local IconArt = require(Prototype.Home.IconArt)
local Overlay = require(script.Parent.Overlay)
local PanelKit = require(script.Parent.PanelKit)
local PreviewTokens = require(Prototype.PreviewTokens)
local ShopKit = require(Prototype.ShopKit)
local Style = require(script.Parent.Style)
local SupportKit = require(script.Parent.SupportKit)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local GroupRewardPopup = {}

-- the two footer buttons, sized so both fit inside the white card of the smallest frame (design px)
local JOIN_W = 176
local LATER_W = 124

GroupRewardPopup.Headline = "Join the group, get a FREE reward!"
GroupRewardPopup.PreviewNote = "Reward preview. Claiming is not live yet."

export type View = GroupFixtures.View

export type JoinResult = { status: string, error: string? }

export type Options = {
	gateway: GroupFixtures.Gateway?,
	gate: GroupFixtures.Gate?,
	groupId: number?,
	onJoinResult: ((JoinResult) -> ())?,
	onClose: (() -> ())?,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Geo = {
	fit: SupportKit.Fit,
	pw: number,
	ph: number,
	headH: number,
	art: Rect,
	text: Rect,
	joinSize: Vector2,
	laterSize: Vector2,
}

export type DebugState = {
	open: boolean,
	kind: string,
	fit: string,
	view: string,
	headline: string,
	status: string,
	group: string,
	note: string,
	joinVisible: boolean,
	joinEnabled: boolean,
	claimedVisible: boolean,
	joinPresses: number,
	promptCalls: number,
	isInGroupCalls: number,
	nameChecks: number,
	lastStatus: string,
	gateway: string, -- "fake" or "real"
	gate: string, -- the last reason the gate gave
	instances: number,
}

export type Popup = {
	root: Frame,
	layout: (self: Popup) -> (),
	setVisible: (self: Popup, on: boolean) -> (),
	request: (self: Popup) -> boolean,
	open: (self: Popup, returnTo: GuiObject?) -> (),
	close: (self: Popup) -> (),
	isOpen: (self: Popup) -> boolean,
	pressJoin: (self: Popup) -> boolean,
	pressNotNow: (self: Popup) -> (),
	setPreset: (self: Popup, name: string) -> boolean,
	setView: (self: Popup, view: View) -> (),
	destroy: (self: Popup) -> (),
	getDebugState: (self: Popup) -> DebugState,
	touchReport: (self: Popup) -> { { name: string, w: number, h: number } },
}

-- GEOMETRY -----------------------------------------------------------------------------------

function GroupRewardPopup.geometry(ds: Vector2): Geo
	local fit = SupportKit.fitFor(ds)
	local pw, ph, headH, artW, artH
	if fit == "Compact" then
		pw, ph, headH, artW, artH = math.min(ds.X - 12, 480), math.min(ds.Y - 8, 300), 46, 120, 132
	elseif fit == "Regular" then
		pw, ph, headH, artW, artH = math.min(ds.X - 24, 520), 320, 54, 130, 142
	else
		pw, ph, headH, artW, artH = math.min(ds.X - 32, 580), 360, 60, 150, 160
	end
	local textX = 14 + artW + 14
	return {
		fit = fit,
		pw = pw,
		ph = ph,
		headH = headH,
		art = { x = 14, y = headH + math.max(math.floor((ph - headH - artH) / 2), 10), w = artW, h = artH },
		text = { x = textX, y = headH + 14, w = pw - textX - 22, h = ph - headH - 90 },
		joinSize = Vector2.new(JOIN_W, 58),
		laterSize = Vector2.new(LATER_W, 48),
	}
end

-- THE REWARD ART -----------------------------------------------------------------------------

-- The PREVIEW reward: an exclusive "Legion" paint, drawn from local shapes (a swatch disc with a star). Not a real item.
local function buildReward(parent: Instance, z: number): Frame
	local frame: Frame = make("Frame", {
		Name = "RewardArt",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Arcade.corner(frame, 8)
	Arcade.outline(frame, "Button")
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(40, 66, 140), Color3.fromRGB(18, 30, 72)),
		Rotation = 90,
		Parent = frame,
	})
	local disc: Frame = make("Frame", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.66, 0.66),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = frame,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = disc })
	Arcade.corner(disc, 999)
	Arcade.outline(disc, "Button")
	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(64, 200, 190)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 60, 150)),
		}),
		Rotation = 45,
		Parent = disc,
	})
	local star: Frame = make("Frame", {
		Name = "Star",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.56),
		BackgroundTransparency = 1,
		ZIndex = z + 2,
		Parent = disc,
	})
	IconArt.draw(star, { "Star" })
	local name = SupportKit.label(frame, "Name", 16, z + 1)
	name.Text = "Legion paint"
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -4)
	name.Size = UDim2.new(1, -8, 0, 24)
	return frame
end

-- THE POP-UP ---------------------------------------------------------------------------------

local OUTCOME_VIEW: { [string]: View } = {
	Joined = "Joined",
	AlreadyMember = "Joined",
	JoinRequestPending = "Pending",
	None = "TryLater",
	Error = "Error",
}

function GroupRewardPopup.new(ctx: Overlay.Ctx, options: Options?): Popup
	local opts: Options = options or {}
	local groupId = opts.groupId or GroupFixtures.GroupId
	local gateway: GroupFixtures.Gateway = opts.gateway or GroupFixtures.fakeGateway({ outcomes = { "Joined" } })
	local gate = opts.gate
	local geo = GroupRewardPopup.geometry(Vector2.new(750, 325))
	local view: View = "Offer"
	local forcedView: View? = nil
	local confirmedName: string? = nil
	local joining = false
	local token = 0 -- invalidates callbacks that arrive after the pop-up closed
	local joinPresses = 0
	local nameChecks = 0
	local lastStatus = ""
	local lastGate = ""
	local destroyed = false
	local popup: Popup

	local overlay = Overlay.new(ctx, {
		name = "GroupRewardPopup",
		onDim = function()
			popup:pressNotNow()
		end,
	})
	local trove = overlay.trove
	local flowTrove = trove:Extend()
	local content = overlay.content
	local shell = Style.panel(content, { name = "Panel", z = 3 })
	local panel = shell.body
	-- the selling surface: the panel's own gradient is replaced by the Shop's moving one (one gradient on the body)
	for _, child in panel:GetChildren() do
		if child:IsA("UIGradient") then
			child:Destroy()
		end
	end
	ShopKit.vividBackground(panel, trove)
	local header = Style.header(panel, { fill = "Gold", title = "FREE REWARD!", icon = "Star" })
	-- the white card for the words and the buttons (right of the art, under the header; below the header band in z)
	local textCard: Frame = make("Frame", {
		Name = "TextCard",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = panel,
	})
	Arcade.corner(textCard, 10)
	Arcade.outline(textCard, "Button")
	make(
		"UIGradient",
		{ Color = ColorSequence.new(PanelKit.CardTop, PanelKit.CardBottom), Rotation = 90, Parent = textCard }
	)
	local closeX = PanelKit.closeX(panel, function()
		popup:pressNotNow()
	end)
	trove:Add(closeX.trove)

	local art = buildReward(panel, 5)
	local previewStamp = Style.stamp(art, "PREVIEW", "Gold", 9)
	previewStamp.frame.Position = UDim2.fromOffset(4, 6)
	local claimedStamp = Style.stamp(art, "CLAIMED", "Green", 10)
	claimedStamp.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	claimedStamp.frame.Position = UDim2.fromScale(0.5, 0.5)
	claimedStamp.frame.Rotation = -10
	claimedStamp.frame.Visible = false
	local claimedTick: Frame = make("Frame", {
		Name = "ClaimedTick",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 12,
		Parent = art,
	})
	IconArt.draw(claimedTick, { "Check" })

	local headline = PanelKit.ink(SupportKit.label(panel, "Headline", 24, 6))
	local groupLabel = PanelKit.ink(SupportKit.label(panel, "Group", 18, 6), true)
	local statusLabel = PanelKit.ink(SupportKit.label(panel, "Status", 20, 6))
	-- the conspicuous no-grant note (a chip, not fine print)
	local noteChip: Frame = make("Frame", {
		Name = "HonestyNote",
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = panel,
	})
	Arcade.corner(noteChip, 8)
	Arcade.outline(noteChip, "Minor")
	local noteLabel = SupportKit.label(noteChip, "Text", 16, 7)
	noteLabel.Text = GroupRewardPopup.PreviewNote
	noteLabel.TextColor3 = PreviewTokens.Color.KeysLight
	noteLabel.Size = UDim2.fromScale(1, 1)

	local joinButton = Arcade.button(panel, {
		name = "Join",
		label = "JOIN",
		fill = "Green",
		size = "Custom",
		width = JOIN_W,
		height = 58,
		pattern = true,
		cooldown = 0.6,
		onActivate = function()
			popup:pressJoin()
		end,
	})
	trove:Add(joinButton.trove)
	joinButton.root.ZIndex = 12
	local laterButton = Arcade.button(panel, {
		name = "NotNow",
		label = "Not now",
		fill = "Garage",
		size = "Custom",
		width = LATER_W,
		height = 48,
		onActivate = function()
			popup:pressNotNow()
		end,
	})
	trove:Add(laterButton.trove)
	laterButton.root.ZIndex = 12
	local okButton = Arcade.button(panel, {
		name = "Ok",
		label = "OK",
		fill = "Home",
		size = "Custom",
		width = 170,
		height = 54,
		onActivate = function()
			popup:close()
		end,
	})
	trove:Add(okButton.trove)
	okButton.root.ZIndex = 12

	-- VIEW -----------------------------------------------------------------------------------

	local function headlineFor(v: View): string
		if v == "Joined" or v == "Member" then
			return GroupFixtures.Messages.Joined
		elseif v == "Pending" then
			return GroupFixtures.Messages.Pending
		elseif v == "Claimed" then
			return "Group reward"
		end
		return GroupRewardPopup.Headline
	end

	local function statusFor(v: View): string
		if
			v == "Checking"
			or v == "Unavailable"
			or v == "Prompting"
			or v == "TryLater"
			or v == "Error"
			or v == "Claimed"
		then
			return (GroupFixtures.Messages :: any)[v]
		end
		return ""
	end

	local function refresh()
		headline.Text = headlineFor(view)
		statusLabel.Text = statusFor(view)
		groupLabel.Visible = confirmedName ~= nil
		groupLabel.Text = if confirmedName then "Group: " .. confirmedName else ""
		local offering = view == "Offer" or view == "TryLater" or view == "Error" or view == "Prompting"
		local finished = view == "Joined" or view == "Member" or view == "Pending" or view == "Claimed"
		joinButton.root.Visible = offering
		joinButton.setEnabled(view ~= "Prompting")
		laterButton.root.Visible = offering or view == "Checking" or view == "Unavailable"
		okButton.root.Visible = finished
		claimedStamp.frame.Visible = view == "Claimed"
		claimedTick.Visible = view == "Claimed"
		previewStamp.frame.Visible = view ~= "Claimed"
		SupportKit.fitLabel(headline, headline.Text, geo.text.w, 58, 24)
		SupportKit.fitLabel(statusLabel, statusLabel.Text, geo.text.w, 28, 20)
	end

	local function setViewNow(v: View)
		view = v
		refresh()
	end

	local function layoutNow()
		overlay:applyScale()
		geo = GroupRewardPopup.geometry(overlay:designSize())
		shell.root.Size = UDim2.fromOffset(geo.pw, geo.ph)
		shell.root.Position = UDim2.new(0.5, 0, 0.5, -2)
		header.setHeight(geo.headH)
		closeX.root.Position = UDim2.new(1, -8, 0, geo.headH / 2)
		local left = header.title.Position.X.Offset
		header.title.AnchorPoint = Vector2.new(0, 0.5)
		header.title.Position = UDim2.new(0, left, 0.5, 0)
		header.title.Size = UDim2.new(1, -left - 70, 0, math.min(A.Text.Display + 8, geo.headH - 6))
		art.Position = UDim2.fromOffset(geo.art.x, geo.art.y)
		art.Size = UDim2.fromOffset(geo.art.w, geo.art.h)
		local cardX = geo.text.x - 8
		local cardW = geo.pw - cardX - 10
		textCard.Position = UDim2.fromOffset(cardX, geo.headH + 10)
		textCard.Size = UDim2.fromOffset(cardW, geo.ph - geo.headH - 16)
		claimedTick.Position = UDim2.new(0.5, 0, 0.5, -30)
		local t = geo.text
		headline.Position = UDim2.fromOffset(t.x, t.y)
		headline.Size = UDim2.fromOffset(t.w, 58)
		groupLabel.Position = UDim2.fromOffset(t.x, t.y + 58)
		groupLabel.Size = UDim2.fromOffset(t.w, 24)
		statusLabel.Position = UDim2.fromOffset(t.x, t.y + 84)
		statusLabel.Size = UDim2.fromOffset(t.w, 28)
		noteChip.Position = UDim2.fromOffset(t.x, t.y + 114)
		noteChip.Size = UDim2.fromOffset(t.w, 42)
		-- the buttons, pinned to the foot of the card
		local footY = geo.ph - 12
		joinButton.root.AnchorPoint = Vector2.new(0.5, 1)
		laterButton.root.AnchorPoint = Vector2.new(0.5, 1)
		okButton.root.AnchorPoint = Vector2.new(0.5, 1)
		local gap = 10
		local laterW = geo.laterSize.X
		local joinW = geo.joinSize.X
		local total = laterW + gap + joinW
		local startX = cardX + (cardW - total) / 2
		laterButton.root.Position = UDim2.fromOffset(startX + laterW / 2, footY)
		joinButton.root.Position = UDim2.fromOffset(startX + laterW + gap + joinW / 2, footY)
		okButton.root.Position = UDim2.fromOffset(cardX + cardW / 2, footY)
		refresh()
	end

	-- FLOW -----------------------------------------------------------------------------------

	local function checkName(myToken: number)
		setViewNow("Checking")
		nameChecks += 1
		flowTrove:Add(task.spawn(function()
			local ok, name = pcall(gateway.groupName, groupId)
			if myToken ~= token or destroyed then
				return -- late answer after the pop-up closed: the UI is not touched
			end
			if ok and GroupFixtures.nameMatches(name :: string?) then
				confirmedName = name :: string
				setViewNow("Offer")
			else
				confirmedName = nil
				setViewNow("Unavailable")
			end
		end))
	end

	local function dismiss()
		if gate then
			gate:recordDismissed()
		end
		popup:close()
	end

	overlay:setBack(function()
		dismiss()
	end)
	trove:Connect(ctx.screen.Changed, function()
		layoutNow()
	end)

	popup = {
		root = overlay.root,
		layout = function(_self: Popup)
			layoutNow()
		end,
		setVisible = function(_self: Popup, on: boolean)
			overlay.root.Visible = on and overlay:isOpen()
		end,
		request = function(self: Popup): boolean
			if overlay:isOpen() then
				return false
			end
			if gate then
				local ok, reason = gate:check()
				lastGate = reason
				if not ok then
					return false
				end
			end
			self:open(nil)
			if gate then
				gate:recordShown()
			end
			return true
		end,
		open = function(_self: Popup, returnTo: GuiObject?)
			if overlay:isOpen() or destroyed then
				return
			end
			token += 1
			joining = false
			layoutNow()
			local forced = forcedView
			if forced then
				if forced == "Member" or forced == "Joined" then
					confirmedName = confirmedName or GroupFixtures.GroupName
				end
				setViewNow(forced)
			else
				checkName(token)
			end
			local focus = if joinButton.root.Visible
				then joinButton.body
				elseif okButton.root.Visible then okButton.body
				else laterButton.body
			overlay:open(focus, returnTo)
		end,
		close = function(_self: Popup)
			if not overlay:isOpen() then
				return
			end
			token += 1
			flowTrove:Clean()
			joining = false
			overlay:close()
			if opts.onClose then
				opts.onClose()
			end
		end,
		isOpen = function(_self: Popup): boolean
			return overlay:isOpen()
		end,
		pressJoin = function(_self: Popup): boolean
			joinPresses += 1
			if joining or not (view == "Offer" or view == "TryLater" or view == "Error") then
				return false -- a repeat press while a prompt is open (or a view with no JOIN) does nothing
			end
			joining = true
			local myToken = token
			setViewNow("Prompting")
			flowTrove:Add(task.spawn(function()
				-- the one place the group is prompted: a deliberate press, in pcall, through the gateway
				local ok, result = pcall(gateway.promptJoin, groupId)
				local name = if ok then tostring(result) else "Error"
				if ok and (name == "Joined" or name == "AlreadyMember") then
					pcall(gateway.isInGroup, groupId) -- informational: the card never waits for, or promises, a server confirmation
				end
				joining = false
				lastStatus = name
				if opts.onJoinResult then
					opts.onJoinResult({ status = name, error = if ok then nil else tostring(result) })
				end
				if myToken ~= token or destroyed then
					return -- closed while the prompt was open: only the result was forwarded
				end
				setViewNow(OUTCOME_VIEW[name] or "TryLater")
			end))
			return true
		end,
		pressNotNow = function(_self: Popup)
			dismiss()
		end,
		setPreset = function(_self: Popup, name: string): boolean
			local preset = (GroupFixtures.Presets :: any)[name] :: GroupFixtures.Preset?
			if not preset then
				return false
			end
			gateway = GroupFixtures.fakeGateway(preset.config)
			forcedView = preset.view
			joining = false
			token += 1
			if overlay:isOpen() then
				if preset.view then
					setViewNow(preset.view)
				else
					checkName(token)
				end
			end
			return true
		end,
		setView = function(_self: Popup, v: View)
			forcedView = v
			setViewNow(v)
		end,
		destroy = function(_self: Popup)
			destroyed = true
			overlay:destroy()
		end,
		getDebugState = function(_self: Popup): DebugState
			return {
				open = overlay:isOpen(),
				kind = overlay:kind(),
				fit = geo.fit,
				view = view,
				headline = headline.Text,
				status = statusLabel.Text,
				group = groupLabel.Text,
				note = noteLabel.Text,
				joinVisible = joinButton.root.Visible,
				joinEnabled = joinButton.root.Visible and view ~= "Prompting",
				claimedVisible = claimedStamp.frame.Visible,
				joinPresses = joinPresses,
				promptCalls = gateway.calls.prompt,
				isInGroupCalls = gateway.calls.isInGroup,
				nameChecks = nameChecks,
				lastStatus = lastStatus,
				gateway = if gateway.isFake then "fake" else "real",
				gate = lastGate,
				instances = #overlay.root:GetDescendants(),
			}
		end,
		touchReport = function(_self: Popup): { { name: string, w: number, h: number } }
			local ds = overlay:designSize()
			local ratio = if ds.X > 0 then overlay.content.AbsoluteSize.X / ds.X else 1
			return SupportKit.touchReport(overlay.root, ratio)
		end,
	}

	layoutNow()
	return popup
end

-- THE SHOP CARD ------------------------------------------------------------------------------

export type CardOptions = {
	size: Vector2?,
	claimed: boolean?, -- an explicit fixture: shows CLAIMED
	onJoin: (() -> ())?, -- a deliberate tap: the lead opens the pop-up (GroupRewardPopup:open)
}

export type Card = {
	root: Frame,
	setClaimed: (on: boolean) -> (),
	isClaimed: () -> boolean,
	destroy: () -> (),
}

-- The same offer as a permanent card for the Shop's Free section: the reward art, the headline, the no-grant note, and
-- JOIN, or CLAIMED with a tick once the fixture says so. Tapping JOIN only calls onJoin; nothing is prompted here.
function GroupRewardPopup.card(parent: Instance, options: CardOptions?): Card
	local opts: CardOptions = options or {}
	local size = opts.size or Vector2.new(340, 140)
	local trove = Trove.new()
	local claimed = opts.claimed == true
	local root = trove:Add(Style.plate(parent, "GroupRewardCard", 6, "Garage"))
	root.Size = UDim2.fromOffset(size.X, size.Y)
	local art = buildReward(root, 7)
	art.Position = UDim2.fromOffset(8, 8)
	art.Size = UDim2.fromOffset(math.floor(size.Y * 0.62), size.Y - 16)
	local textX = 8 + math.floor(size.Y * 0.62) + 10
	local textW = size.X - textX - 10
	local title = SupportKit.label(root, "Title", 20, 8)
	title.Position = UDim2.fromOffset(textX, 6)
	title.Size = UDim2.fromOffset(textW, 52)
	SupportKit.fitLabel(title, GroupRewardPopup.Headline, textW, 52, 20)
	local note = SupportKit.label(root, "Note", 16, 8)
	note.Position = UDim2.fromOffset(textX, 58)
	note.Size = UDim2.fromOffset(textW, 40)
	note.TextColor3 = PreviewTokens.Color.KeysLight
	SupportKit.fitLabel(note, GroupRewardPopup.PreviewNote, textW, 40, 16)
	local join = Arcade.button(root, {
		name = "Join",
		label = "JOIN",
		fill = "Green",
		size = "Custom",
		width = math.min(textW, 150),
		height = 48,
		cooldown = 0.6,
		onActivate = function()
			if opts.onJoin then
				opts.onJoin()
			end
		end,
	})
	trove:Add(join.trove)
	join.root.AnchorPoint = Vector2.new(0, 1)
	join.root.Position = UDim2.new(0, textX, 1, -6)
	join.root.ZIndex = 12
	local done: Frame = make("Frame", {
		Name = "Claimed",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, textX, 1, -8),
		Size = UDim2.fromOffset(math.min(textW, 170), 44),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 12,
		Parent = root,
	})
	Arcade.corner(done, 7)
	Arcade.outline(done, "Button")
	make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = done })
	local tick: Frame = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = 13,
		Parent = done,
	})
	IconArt.draw(tick, { "Check" })
	local doneText = SupportKit.label(done, "Text", 20, 13)
	doneText.Text = "CLAIMED"
	doneText.Position = UDim2.fromOffset(38, 0)
	doneText.Size = UDim2.new(1, -42, 1, 0)
	local function apply()
		join.root.Visible = not claimed
		done.Visible = claimed
	end
	apply()
	return {
		root = root,
		setClaimed = function(on: boolean)
			claimed = on
			apply()
		end,
		isClaimed = function(): boolean
			return claimed
		end,
		destroy = function()
			trove:Destroy()
		end,
	}
end

return GroupRewardPopup
