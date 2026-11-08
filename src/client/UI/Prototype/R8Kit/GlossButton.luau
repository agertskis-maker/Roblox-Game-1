--!strict
-- GlossButton (Lane 3 Round 8, U-01, U-03 and O-09; API frozen by the lead, art and states built by WS-6a): the ONE big glossy
-- action button and the ONE cannot-afford treatment for every card in the game. Can afford: orange with a white highlight streak
-- and a gentle shine sweep, the label, the Cash icon and the price. Cannot afford: the same shape in grey with "NEED $470 MORE"
-- (the amount comes from the SERVER's missing value or the server-published Cash, never from a client guess) and a small round
-- green "+" that opens the Cash shop page. Max: a gold badge in its place. Busy: pressed in with a spinner, input ignored until the
-- caller changes the state (no double buy). Built from AssetIds.UpgradeCards art when it is available ("r8_card_btn_orange",
-- "_grey", "_gold", "_green", "r8_card_badge_max", "r8_card_plus", "r8_card_cash"), otherwise code-drawn (UIGradient, UIStroke,
-- UICorner). Every word and number is a live TextLabel.
--
--   local b = GlossButton.new(parent: GuiObject, props: Props) -> Button
--   b:setState(state: State, info: Info?)     b.Pressed (Signal)    b.PlusPressed (Signal)    b.frame: Frame    b:destroy()
--
--   State "buy"      orange; `label`, the Cash icon (or none) and `price`. Pressing fires Pressed ONCE and the button goes busy
--                    by itself until setState is called again.
--         "need"     grey, "NEED <need> MORE" and the green "+" (fires PlusPressed). The grey body does nothing.
--         "max"      gold badge with `maxText`; maxStyle "rosette" (the Raceway's MAX LEVEL rosette) or "banner" (default, a
--                    gold button like "ALL SPOTS OWNED"). No input.
--         "busy"     pressed in, dimmed, spinner; no input.
--         "disabled" grey, `label` only; no input.
--         "done"     the just-upgraded stamp: `doneText` ("LEVEL 6!", "NEW SPOT!") on a gold (doneTone "gold") or green
--                    ("green") body with sparkles; no input. (Added by WS-6a; the other five states are the frozen set.)
--   Info: { label, price, need, maxText, icon = "cash" | "robux" | "none", maxStyle, doneText, doneTone, metrics }
--   Props: Info & { size, position, anchor, zIndex }   (size is the button's rect: 443 x 103 design px on the Raceway card)
--   `metrics` (R8Kit.Metrics, optional): the card's design-pixel scale, so text never drops below 16 real px.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Art = require(script.Parent.Art)
local Build = require(script.Parent.Build)
local Calm = require(script.Parent.Calm)
local Metrics = require(script.Parent.Metrics)
local Palette = require(script.Parent.Palette)

local GlossButton = {}

export type State = "buy" | "need" | "max" | "busy" | "disabled" | "done"

export type Info = {
	label: string?, -- "UPGRADE", "BUY SPOT", "BUY"
	price: string?, -- already formatted ("$40.5K", "R$ 49"); a Robux button always states its Robux price
	need: string?, -- already formatted shortfall ("$470")
	maxText: string?, -- "MAX LEVEL", "ALL SPOTS OWNED"
	icon: ("cash" | "robux" | "none")?,
	maxStyle: ("rosette" | "banner")?,
	doneText: string?,
	doneTone: ("gold" | "green")?,
}

export type Props = Info & {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	metrics: any?,
}

export type Button = {
	frame: Frame,
	Pressed: any,
	PlusPressed: any,
	setState: (self: Button, state: State, info: Info?) -> (),
	destroy: (self: Button) -> (),
}

local DESIGN = Vector2.new(443, 103)
local RADIUS = 27
local PLUS_D = 70

local BODY_ART = {
	orange = "r8_card_btn_orange",
	grey = "r8_card_btn_grey",
	gold = "r8_card_btn_gold",
	green = "r8_card_btn_green",
}

local BODY_COLORS = {
	orange = { top = Palette.OrangeTop, bottom = Palette.OrangeBottom },
	grey = { top = Palette.GreyTop, bottom = Palette.GreyBottom },
	gold = { top = Palette.GoldBright, bottom = Palette.GoldDeep },
	green = { top = Palette.GreenLight, bottom = Palette.GreenDeep },
}

local Obj = {}
Obj.__index = Obj

local function colorBody(self: any, tone: string)
	local key = BODY_ART[tone]
	local usesArt = Art.apply(self.art, key)
	self.fill.Visible = not usesArt
	self.gloss.Visible = not usesArt
	if not usesArt then
		local colors = BODY_COLORS[tone]
		self.gradient.Color = ColorSequence.new(colors.top, colors.bottom)
	end
	self.artTrove:Clean()
	if usesArt then
		Art.fitSlice(self.artTrove, self.art, key, "y")
	end
end

-- Pressed in: the body drops 4 design px and darkens a little (the gloss streak of the code-drawn body goes out).
local function setPressed(self: any, pressed: boolean)
	local tint = if pressed then Color3.fromRGB(205, 205, 205) else Color3.new(1, 1, 1)
	self.body.Position = if pressed then UDim2.fromOffset(0, 4) else UDim2.new()
	self.art.ImageColor3 = tint
	self.fill.BackgroundColor3 = tint
	if pressed then
		self.gloss.Visible = false
	end
end

local function stopShine(self: any)
	self.shineGen += 1
	self.shine.Visible = false
	if self.shineThread then
		pcall(task.cancel, self.shineThread)
		self.shineThread = nil
	end
end

local function startShine(self: any)
	stopShine(self)
	if Calm() then
		return
	end
	local gen = self.shineGen
	self.shine.Visible = true
	self.shineThread = task.spawn(function()
		task.wait(0.8)
		while self.shineGen == gen and self.shine.Parent do
			self.shine.Position = UDim2.fromScale(-0.3, -0.2)
			local tween = TweenService:Create(
				self.shine,
				TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Position = UDim2.fromScale(1.15, -0.2) }
			)
			tween:Play()
			task.wait(0.85 + 3.2)
			tween:Destroy()
		end
	end)
end

local function stopSpinner(self: any)
	if self.spin then
		self.spin:Cancel()
		self.spin:Destroy()
		self.spin = nil
	end
	self.spinner.Visible = false
end

local function startSpinner(self: any)
	stopSpinner(self)
	self.spinner.Visible = true
	if Calm() then
		return
	end
	local tween = TweenService:Create(
		self.spinGradient,
		TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Rotation = 360 }
	)
	self.spinGradient.Rotation = 0
	self.spin = tween
	tween:Play()
end

function GlossButton.new(parent: GuiObject, props: Props): Button
	local trove = Trove.new()
	local metrics = props.metrics or Metrics.new(DESIGN)
	local frame: Frame = trove:Add(Build.make("Frame", {
		Name = "GlossButton",
		Size = props.size or UDim2.fromScale(0.45, 0.18),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex or 1,
	}))
	local body: Frame = Build.make("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = frame,
	})
	local art: ImageLabel = Build.make("ImageLabel", {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = body,
	})
	-- the code-drawn body (used while the art is not available)
	local fill: Frame = Build.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = body,
	})
	Build.corner(fill, UDim.new(0, RADIUS))
	Build.stroke(fill, 5, Palette.Navy)
	local gradient: UIGradient = Build.make("UIGradient", { Rotation = 90, Parent = fill })
	local gloss: Frame = Build.make("Frame", {
		Name = "Gloss",
		Position = UDim2.fromScale(0.04, 0.08),
		Size = UDim2.fromScale(0.92, 0.3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = body,
	})
	Build.corner(gloss, UDim.new(0, 14))
	-- the shine sweep, clipped to the button's rounded shape
	local mask: Frame = Build.make("Frame", {
		Name = "ShineMask",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = body,
	})
	Build.corner(mask, UDim.new(0, RADIUS - 4))
	local shine: Frame = Build.make("Frame", {
		Name = "Shine",
		Size = UDim2.fromScale(0.16, 1.4),
		Position = UDim2.fromScale(-0.3, -0.2),
		Rotation = 18,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
		Parent = mask,
	})
	Build.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shine,
	})
	-- rosette (the Raceway's MAX LEVEL), larger than the button, centred on it
	local rosette: ImageLabel = Build.make("ImageLabel", {
		Name = "Rosette",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 1.5),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 2,
		Parent = body,
	})
	-- content: the label, the Cash icon and the price in one centred row
	local row: Frame = Build.make("Frame", {
		Name = "Row",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = body,
	})
	Build.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
		Parent = row,
	})
	local function rowText(name: string, order: number, designSize: number, color: Color3, outlined: boolean): TextLabel
		local label = Build.label(row, name, "", {
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 0.8),
			TextColor3 = color,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = 5,
		})
		if outlined then
			Build.stroke(label, 6, Palette.NavyDeep, Enum.ApplyStrokeMode.Contextual)
		end
		metrics:bindText(trove, label, designSize)
		return label
	end
	local labelText = rowText("Label", 1, 50, Color3.new(1, 1, 1), true)
	local icon: ImageLabel = Build.make("ImageLabel", {
		Name = "CashIcon",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(78, 58),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = row,
	})
	if not Art.apply(icon, "r8_card_cash") then
		-- code-drawn cash stack: a green bill with a gold band
		icon.Visible = true
		icon.BackgroundTransparency = 0
		icon.BackgroundColor3 = Color3.fromRGB(52, 180, 90)
		Build.corner(icon, UDim.new(0, 8))
		Build.stroke(icon, 3, Palette.NavyDeep)
		local band = Build.make("Frame", {
			Name = "Band",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.26, 1),
			BackgroundColor3 = Palette.GoldBright,
			BorderSizePixel = 0,
			Parent = icon,
		})
		Build.stroke(band, 2, Palette.NavyDeep)
	end
	local priceText = rowText("Price", 3, 50, Color3.new(1, 1, 1), true)
	-- "NEED $470 MORE" / "MAX LEVEL" / "LEVEL 6!": one centred text over the body
	local message = Build.label(body, "Message", "", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.04, 0.5),
		Size = UDim2.fromScale(0.92, 0.8),
		TextColor3 = Palette.Navy,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		ZIndex = 5,
		Visible = false,
	})
	metrics:bindText(trove, message, 40)
	-- the green "+" of the cannot-afford state
	local plus: ImageButton = Build.make("ImageButton", {
		Name = "Plus",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(PLUS_D, PLUS_D),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		ZIndex = 8,
		Visible = false,
		Parent = frame,
	})
	if not Art.apply(plus, "r8_card_plus") then
		plus.Visible = false -- re-shown by the state; the code-drawn plus is built below
		plus.BackgroundTransparency = 0
		plus.BackgroundColor3 = Palette.Green
		Build.corner(plus, UDim.new(0.5, 0))
		Build.stroke(plus, 4, Palette.Navy)
		Build.make(
			"UIGradient",
			{ Rotation = 90, Color = ColorSequence.new(Palette.GreenLight, Palette.GreenDeep), Parent = plus }
		)
		for _, size in { UDim2.fromScale(0.54, 0.14), UDim2.fromScale(0.14, 0.54) } do
			local bar = Build.make("Frame", {
				Name = "Bar",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = size,
				BackgroundColor3 = Palette.White,
				BorderSizePixel = 0,
				ZIndex = 9,
				Parent = plus,
			})
			Build.corner(bar, UDim.new(0.5, 0))
		end
	end
	-- the plus's hit area grows to 44 real px when the card is small
	local plusHit: TextButton = Build.make("TextButton", {
		Name = "PlusHit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
		Parent = plus,
	})
	local function fitHit()
		local side = math.max(PLUS_D, math.ceil(44 / metrics.scale))
		plusHit.Size = UDim2.fromOffset(side, side)
	end
	fitHit()
	trove:Add(metrics.changed:Connect(fitHit))
	-- the spinner of the busy state
	local spinner: Frame = Build.make("Frame", {
		Name = "Spinner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
		Parent = body,
	})
	Build.corner(spinner, UDim.new(0.5, 0))
	local spinStroke = Build.stroke(spinner, 8, Color3.new(1, 1, 1))
	local spinGradient: UIGradient = Build.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = spinStroke,
	})
	-- sparkles of the "done" state
	local sparkles: { Frame } = {}
	for i, at in { 0.06, 0.94 } do
		local sparkle = Build.make("Frame", {
			Name = "Sparkle" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(at, 0.5),
			Size = UDim2.fromOffset(28, 28),
			Rotation = 45,
			BackgroundColor3 = Palette.GoldBright,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 6,
			Parent = body,
		})
		Build.stroke(sparkle, 2, Palette.Navy)
		table.insert(sparkles, sparkle)
	end
	-- the hit area (the whole body)
	local hit: TextButton = Build.make("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 7,
		Parent = frame,
	})
	local self = setmetatable({
		frame = frame,
		Pressed = Signal.new(),
		PlusPressed = Signal.new(),
		trove = trove,
		artTrove = trove:Extend(),
		metrics = metrics,
		state = "buy" :: State,
		info = {} :: Info,
		body = body,
		art = art,
		fill = fill,
		gradient = gradient,
		gloss = gloss,
		shine = shine,
		shineGen = 0,
		shineThread = nil,
		rosette = rosette,
		row = row,
		labelText = labelText,
		priceText = priceText,
		icon = icon,
		message = message,
		plus = plus,
		spinner = spinner,
		spinGradient = spinGradient,
		spin = nil,
		sparkles = sparkles,
		hit = hit,
		pressed = false,
	}, Obj)
	local s: any = self
	trove:Add(s.Pressed, "DisconnectAll")
	trove:Add(s.PlusPressed, "DisconnectAll")
	trove:Add(function()
		stopShine(s)
		stopSpinner(s)
	end)
	-- press feedback and the one-shot Pressed
	trove:Connect(hit.MouseButton1Down, function()
		if s.state == "buy" then
			setPressed(s, true)
		end
	end)
	local function release()
		if s.state == "buy" then
			setPressed(s, false)
			s.gloss.Visible = not s.art.Visible
		end
	end
	trove:Connect(hit.MouseButton1Up, release)
	trove:Connect(hit.MouseLeave, release)
	trove:Connect(hit.Activated, function()
		if s.state ~= "buy" then
			return
		end
		-- the button goes busy at once, so a second press in the same frame can never get through
		s:setState("busy", nil)
		s.Pressed:Fire()
	end)
	trove:Connect(plusHit.Activated, function()
		if s.state == "need" then
			s.PlusPressed:Fire()
		end
	end)
	s:setState("buy", props)
	frame.Parent = parent
	return s :: Button
end

function Obj.setState(self: any, state: State, info: Info?)
	if info then
		for key, value in info :: any do
			if key ~= "size" and key ~= "position" and key ~= "anchor" and key ~= "zIndex" and key ~= "metrics" then
				self.info[key] = value
			end
		end
	end
	local i: Info = self.info
	self.state = state
	self.pressed = false
	stopShine(self)
	stopSpinner(self)
	setPressed(self, false)
	self.gloss.Visible = false
	self.rosette.Visible = false
	self.message.Visible = false
	self.plus.Visible = false
	self.row.Visible = false
	for _, sparkle in self.sparkles do
		sparkle.Visible = false
	end
	self.hit.Interactable = state == "buy"
	self.body.Position = UDim2.new()
	self.fill.BackgroundTransparency = 0
	self.fill.Visible = true
	if state == "buy" or state == "busy" then
		colorBody(self, "orange")
		self.row.Visible = true
		self.labelText.Text = i.label or "BUY"
		local showIcon = i.icon ~= "none" and i.icon ~= "robux"
		self.icon.Visible = showIcon
		self.priceText.Text = i.price or ""
		self.priceText.Visible = i.price ~= nil
		if state == "buy" then
			startShine(self)
		else
			setPressed(self, true)
			self.row.Visible = true
			-- the spinner takes the place of the price while the server answers
			self.priceText.Visible = false
			self.icon.Visible = false
			startSpinner(self)
			self.spinner.Position = UDim2.fromScale(0.84, 0.5)
		end
	elseif state == "need" then
		colorBody(self, "grey")
		self.message.Visible = true
		self.message.TextColor3 = Palette.Navy
		self.message.Text = "NEED " .. (i.need or "?") .. " MORE"
		self.message.Position = UDim2.fromScale(0.03, 0.5)
		self.message.Size = UDim2.new(1, -(PLUS_D + 34), 0.8, 0)
		self.message.TextXAlignment = Enum.TextXAlignment.Center
		self.plus.Visible = true
	elseif state == "max" then
		if i.maxStyle == "rosette" and Art.apply(self.rosette, "r8_card_badge_max") then
			self.art.Visible = false
			self.fill.Visible = false
			self.gloss.Visible = false
			self.rosette.Visible = true
		else
			colorBody(self, "gold")
		end
		self.message.Visible = true
		self.message.TextColor3 = Palette.Navy
		self.message.Position = UDim2.fromScale(0.04, 0.5)
		self.message.Size = UDim2.fromScale(0.92, 0.8)
		self.message.Text = i.maxText or "MAX LEVEL"
		self.message.TextXAlignment = Enum.TextXAlignment.Center
		if self.rosette.Visible then
			-- two lines inside the rosette's disc
			local first, rest = string.match(self.message.Text, "^(%S+)%s+(.+)$")
			if first and rest then
				self.message.Text = first .. "\n" .. rest
			end
			self.message.Position = UDim2.fromScale(0.3, 0.5)
			self.message.Size = UDim2.fromScale(0.4, 1.1)
		end
	elseif state == "done" then
		colorBody(self, if i.doneTone == "green" then "green" else "gold")
		self.message.Visible = true
		self.message.TextColor3 = Color3.new(1, 1, 1)
		self.message.Text = i.doneText or "DONE!"
		self.message.Position = UDim2.fromScale(0.04, 0.5)
		self.message.Size = UDim2.fromScale(0.92, 0.8)
		self.message.TextXAlignment = Enum.TextXAlignment.Center
		if self.message:FindFirstChildOfClass("UIStroke") == nil then
			Build.stroke(self.message, 6, Palette.NavyDeep, Enum.ApplyStrokeMode.Contextual)
		end
		for _, sparkle in self.sparkles do
			sparkle.Visible = true
		end
	else -- disabled
		colorBody(self, "grey")
		self.message.Visible = true
		self.message.TextColor3 = Palette.Navy
		self.message.Text = i.label or ""
		self.message.Position = UDim2.fromScale(0.04, 0.5)
		self.message.Size = UDim2.fromScale(0.92, 0.8)
		self.message.TextXAlignment = Enum.TextXAlignment.Center
	end
	if state ~= "done" then
		local outline = self.message:FindFirstChildOfClass("UIStroke")
		if outline then
			outline:Destroy()
		end
	end
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return GlossButton
