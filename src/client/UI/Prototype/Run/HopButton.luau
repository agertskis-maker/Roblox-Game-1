--!strict
-- Hop control for the rebuilt run view (Lane 3 preview, HUD rebuild worker HR; U-07). A chunky
-- arcade rectangle (limited rounding, thick dark boundary, teal/white = Hop's colour) with the
-- original CarJump symbol (Icons2) and "HOP", bottom right with clearance (RunLayout.hopRect:
-- beside the Roblox Jump zone on touch, never in a reserved zone or the protected road region).
-- Presentation only: it shows run.hop and run.hopCooldown01 as supplied; pressing it only calls
-- the preview intent callback. It never hops, picks a target or judges a landing (Lane 1).
--
-- Input-specific label (UserInputService.PreferredInput when available, else GamepadEnabled /
-- TouchEnabled / KeyboardEnabled; the device profile's touch flag wins in the playground):
--   keyboard  a "Space" key chip under the button
--   touch     no key label (the button is the control)
--   gamepad   the bound button's chip. No real binding exists in the preview: ButtonA is the
--             documented ASSUMPTION ("A"), overridable with options.gamepadKey.
-- States, never by colour alone:
--   Available    teal, full-strength icon, "HOP"
--   Timing       + a white ring around the button (gentle pulse; static in reduced motion)
--   cooldown     a dark radial sweep shrinking to 0 + dimmed icon + "WAIT"
--   Unavailable  grey fill + dimmed icon + diagonal hatching + "HOP" dimmed; not pressable
--
--   local hop = HopButton.new(ctx, { onHopIntent = fn?, gamepadKey = "A"? })
--   hop:setHopIntent(fn)        -- preview: called on press; no gameplay
--   hop:setInputKind(kind?)     -- "Keyboard" | "Touch" | "Gamepad" | nil (auto) for review
--   hop:layout(), hop:setVisible(on), hop:destroy(), hop:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Arc = require(script.Parent.Arc)
local Arcade = require(script.Parent.Parent.Arcade)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local SIZE = PreviewTokens.Size.HopButton -- 96 design px body
local KEY_CHIP_H = 26

export type InputKind = "Keyboard" | "Touch" | "Gamepad"
export type Options = { onHopIntent: (() -> ())?, gamepadKey: string? }

local HopButton = {}
HopButton.__index = HopButton

function HopButton.new(ctx: RunLayout.Ctx, options: Options?)
	local self = setmetatable({}, HopButton)
	local opts: Options = options or {}
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._state = "" :: string
	self._cooldown = 0
	self._intents = 0
	self._onIntent = opts.onHopIntent
	self._gamepadKey = opts.gamepadKey or "A"
	self._forced = nil :: InputKind?
	self._input = "Keyboard" :: InputKind
	self._rect = nil :: RunLayout.Rect?
	self._conflict = nil :: string?
	self._reservedHit = nil :: string?
	self._last = -math.huge

	local root = self._trove:Add(RunLayout.canvas(ctx, "HopButton"))
	self.root = root
	local holder = make("Frame", {
		Name = "Hop",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SIZE, SIZE + 4),
		ZIndex = 2,
		Parent = root,
	})
	self._holder = holder
	local body = make("TextButton", {
		Name = "Body",
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 3,
		Parent = holder,
	})
	local press = make("UIScale", { Name = "Press", Parent = body })
	self._body = body
	self._press = press
	local lip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, A.Button.DepthOffset),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		ZIndex = 3,
		Parent = body,
	})
	Arcade.corner(lip, 12)
	local face = make("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = body,
	})
	Arcade.corner(face, 12)
	Arcade.outline(face, "Button")
	self._grad = make("UIGradient", { Color = A.Fill.Home, Rotation = 90, Parent = face })
	Arcade.gloss(face)
	self._face = face
	local icon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(SIZE * 0.58, SIZE * 0.58),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = face,
	})
	Arcade.icon(icon, "CarJump")
	-- dim veil over the icon (structure cue for cooldown / unavailable)
	local veil = make("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = face,
	})
	Arcade.corner(veil, 12)
	self._veil = veil
	local label = Arcade.text(face, { text = "HOP", role = "Button", name = "Label", size = 24, z = 12 })
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -2)
	label.Size = UDim2.new(1, -6, 0, 30)
	self._label = label
	-- diagonal hatching for Unavailable
	local hatch = make("Frame", {
		Name = "Hatch",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 10,
		Parent = face,
	})
	for i = -2, 5 do
		make("Frame", {
			Name = "Stripe" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(i * 22, SIZE / 2),
			Size = UDim2.fromOffset(6, SIZE * 1.8),
			Rotation = 35,
			BackgroundColor3 = A.Ink,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = 10,
			Parent = hatch,
		})
	end
	self._hatch = hatch
	-- cooldown sweep (dark wedge shrinking from hopCooldown01 to 0)
	local sweep = Arc.new(face, SIZE * 1.5, A.Ink, 0.5, 11)
	self._sweep = sweep
	-- Timing ring outside the boundary
	local ring = make("Frame", {
		Name = "TimingRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 16, 1, 16),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = body,
	})
	Arcade.corner(ring, 18)
	local ringStroke = make("UIStroke", { Thickness = 4, Color = Color3.new(1, 1, 1), Parent = ring })
	local ringScale = make("UIScale", { Name = "Pulse", Parent = ring })
	self._ring, self._ringStroke, self._ringScale = ring, ringStroke, ringScale
	-- input key chip (keyboard / gamepad)
	local chip = make("Frame", {
		Name = "KeyChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, A.Button.DepthOffset + 4),
		Size = UDim2.fromOffset(78, KEY_CHIP_H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = holder,
	})
	Arcade.corner(chip, 6)
	Arcade.outline(chip, "Major")
	local chipText = Arcade.text(chip, { text = "Space", role = "Small", name = "Key", colour = A.Ink, z = 6 })
	chipText.Size = UDim2.fromScale(1, 1)
	local chipStroke = chipText:FindFirstChildOfClass("UIStroke")
	if chipStroke then
		chipStroke.Enabled = false -- dark text on a white key cap needs no outline
	end
	self._chip, self._chipText = chip, chipText

	self._trove:Connect(body.Activated, function()
		self:_intent()
	end)
	self._trove:Connect(body.MouseButton1Down, function()
		if self:_pressable() then
			Motion.tween(press, "press", Motion.info(A.Motion.Press), { Scale = 0.94 })
		end
	end)
	self._trove:Connect(body.MouseButton1Up, function()
		Motion.tween(press, "press", Motion.info(A.Motion.Release), { Scale = 1 })
	end)
	self._trove:Connect(body.MouseLeave, function()
		Motion.tween(press, "press", Motion.info(A.Motion.Release), { Scale = 1 })
	end)
	self._trove:Connect(UserInputService.LastInputTypeChanged, function()
		self:_applyInput()
	end)
	pcall(function()
		self._trove:Connect(UserInputService:GetPropertyChangedSignal("PreferredInput"), function()
			self:_applyInput()
		end)
	end)
	self._trove:Add(function()
		Motion.cancelAll(press)
		Motion.cancelAll(ringScale)
		Motion.cancelAll(ringStroke)
	end)
	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function()
		self:_apply()
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_applyRing()
	end))
	self:layout()
	return self
end

export type HopButton = typeof(HopButton.new((nil :: any) :: RunLayout.Ctx))

function HopButton._pressable(self: HopButton): boolean
	return self._state ~= "Unavailable" and self._state ~= "" and self._cooldown <= 0.001
end

function HopButton._intent(self: HopButton)
	local now = os.clock()
	if not self:_pressable() or now - self._last < 0.25 then
		return
	end
	self._last = now
	self._intents += 1
	Sounds.play("Hop")
	local fn = self._onIntent
	if fn then
		fn()
	end
end

function HopButton._detectInput(self: HopButton): InputKind
	if self._forced then
		return self._forced :: InputKind
	end
	if self._ctx.screen:profile().touch then
		return "Touch"
	end
	local kind: InputKind? = nil
	pcall(function()
		local p = (UserInputService :: any).PreferredInput
		if p == (Enum :: any).PreferredInput.Gamepad then
			kind = "Gamepad"
		elseif p == (Enum :: any).PreferredInput.Touch then
			kind = "Touch"
		elseif p ~= nil then
			kind = "Keyboard"
		end
	end)
	if kind then
		return kind :: InputKind
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "Keyboard"
end

function HopButton._applyInput(self: HopButton)
	local kind = self:_detectInput()
	self._input = kind
	self._chip.Visible = kind ~= "Touch"
	if kind == "Keyboard" then
		self._chipText.Text = "Space"
		self._chip.Size = UDim2.fromOffset(78, KEY_CHIP_H)
	elseif kind == "Gamepad" then
		self._chipText.Text = self._gamepadKey
		self._chip.Size = UDim2.fromOffset(KEY_CHIP_H + 8, KEY_CHIP_H + 8)
		self._chip:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	end
	if kind == "Keyboard" then
		self._chip:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 6)
	end
end

function HopButton._applyRing(self: HopButton)
	local timing = self._state == "Timing"
	local ring, scale, stroke = self._ring, self._ringScale, self._ringStroke
	Motion.cancelAll(scale)
	Motion.cancelAll(stroke)
	ring.Visible = timing
	scale.Scale = 1
	stroke.Transparency = 0
	if timing and not Motion.reduced() and self._visible then
		-- about 1.1 pulses per second, well under the 2.5 per second ceiling
		local info = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, true)
		Motion.tween(scale, "pulse", info, { Scale = 1.08 })
		Motion.tween(stroke, "pulse", info, { Transparency = 0.5 })
	end
end

function HopButton._apply(self: HopButton)
	local run = self._ctx.store:get().run
	self._holder.Visible = self._ctx.store:get().mode == "Run" and run ~= nil
	local state = if run then run.hop else "Unavailable"
	local cooldown = if run then math.clamp(run.hopCooldown01, 0, 1) else 0
	self._cooldown = cooldown
	self._sweep:set(cooldown)
	local changed = state ~= self._state
	self._state = state
	local unavailable = state == "Unavailable"
	local cooling = not unavailable and cooldown > 0.001
	self._grad.Color = if unavailable then A.Fill.Disabled else A.Fill.Home
	self._hatch.Visible = unavailable
	self._veil.BackgroundTransparency = if unavailable then 0.5 elseif cooling then 0.55 else 1
	self._label.Text = if cooling then "WAIT" else "HOP"
	self._label.TextTransparency = if unavailable then 0.35 else 0
	self._body.Active = not unavailable
	if changed then
		self:_applyRing()
	end
end

function HopButton.layout(self: HopButton)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect, conflict = RunLayout.hopRect(ctx)
	self._rect = rect
	self._conflict = conflict
	self._holder.Position = UDim2.fromOffset(rect.pos.X, rect.pos.Y)
	local pos, size = RunLayout.toDevice(ctx, rect)
	self._reservedHit = ctx.screen:overlapsReserved(pos, size)
	self:_applyInput()
	-- the key chip sits under the button on desktop; above it when that would leave the canvas
	local d = RunLayout.design(ctx)
	local below = rect.pos.Y + SIZE + A.Button.DepthOffset + 4 + KEY_CHIP_H + 4 <= d.Y
	self._chip.AnchorPoint = if below then Vector2.new(0.5, 0) else Vector2.new(0.5, 1)
	self._chip.Position = if below
		then UDim2.new(0.5, 0, 0, SIZE + A.Button.DepthOffset + 4)
		else UDim2.new(0.5, 0, 0, -6)
	self:_apply()
end

function HopButton.setHopIntent(self: HopButton, fn: (() -> ())?)
	self._onIntent = fn
end

function HopButton.setInputKind(self: HopButton, kind: InputKind?)
	self._forced = kind
	self:_applyInput()
end

function HopButton.setVisible(self: HopButton, on: boolean)
	self._visible = on
	self.root.Visible = on
	self:_applyRing()
end

function HopButton.getDebugState(self: HopButton): { [string]: any }
	local rect = self._rect
	return {
		visible = self._visible,
		input = self._input,
		forcedInput = self._forced,
		keyLabel = if self._chip.Visible then self._chipText.Text else nil,
		state = self._state,
		cooldown01 = self._cooldown,
		sweep = self._sweep:get(),
		label = self._label.Text,
		hatched = self._hatch.Visible,
		iconDimmed = self._veil.BackgroundTransparency < 1,
		ringShown = self._ring.Visible,
		ringPulsing = self._ring.Visible and not Motion.reduced(),
		intents = self._intents,
		box = rect and RunLayout.describe(rect),
		conflict = self._conflict,
		overlapsReserved = self._reservedHit,
		overlapsProtected = rect ~= nil and RunLayout.overlaps(rect, RunLayout.protected(self._ctx)),
	}
end

function HopButton.destroy(self: HopButton)
	self._trove:Destroy()
end

return HopButton
