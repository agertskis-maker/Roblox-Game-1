--!strict
-- Overlay: the shared shell for the prototype's screen mocks (Lane 3 HUD prototype, PREVIEW).
-- Every mock is drawn over the gameplay view: a semi-transparent dark dim (the HUD layer
-- underneath stays visible) and a panel in design pixels. Used only by the files in this folder.
-- HUD rebuild (2026-10-22): the text, title, close and progress helpers use the arcade kit
-- (white outlined text on the deep panels from Style.luau; no cream).
--
--   local o = Overlay.new(ctx, { name = "Garage", onBack = fn })
--   o.root      -- full-size design-coordinate frame with UIScale "HudScale" = screen:uiScale()
--   o.content   -- where the panel goes (design px; o:designSize() is its size)
--   o:kind()    -- "Wide" (desktop, tablet), "Short" (phone landscape), "Tall" (phone portrait)
--   o:open(focus?, returnTo?)  -- shows, binds Back (Escape / gamepad B), focuses `focus` when
--                                 the last input was a gamepad
--   o:close()   -- hides, unbinds Back, returns the selection to where it was
--
-- The dim also covers the device insets (it is purely visual), but nothing interactive is
-- placed outside the safe area. Insets are applied once by Screen; this file never adds them
-- to positions, it only extends the dim back over them.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Prototype = script.Parent.Parent
local Arcade = require(Prototype.Arcade)
local Motion = require(Prototype.Motion)
local PreviewTokens = require(Prototype.PreviewTokens)
local Priority = require(Prototype.Priority)
local Screen = require(Prototype.Screen)
local Sounds = require(Prototype.Sounds)
local Store = require(Prototype.Store)
local Style = require(script.Parent.Style)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local M = PreviewTokens.Motion
local make = Arcade.make

-- TOKEN CANDIDATE: width of the labelled CLOSE button (design px).
local CLOSE_W = 124

local Overlay = {}

export type Ctx = {
	store: Store.StoreObject,
	screen: Screen.ScreenObject,
	layer: Frame,
	world: Folder,
	priority: Priority.Arbiter?, -- the screen-slot arbiter (nil in isolated tests)
}

export type Kind = "Wide" | "Short" | "Tall"

export type Options = {
	name: string,
	dim: boolean?, -- default true
	dimTransparency: number?,
	onBack: (() -> ())?,
	onDim: (() -> ())?, -- the dim was tapped (default: nothing)
	sounds: boolean?, -- Open / Close hooks (default true)
	slide: boolean?, -- slide the content up on open (default true)
}

export type Overlay = {
	root: Frame,
	dim: TextButton?,
	content: Frame,
	trove: Trove.Trove,
	designSize: (self: Overlay) -> Vector2,
	kind: (self: Overlay) -> Kind,
	applyScale: (self: Overlay) -> (),
	open: (self: Overlay, focus: GuiObject?, returnTo: GuiObject?) -> (),
	close: (self: Overlay) -> (),
	isOpen: (self: Overlay) -> boolean,
	setBack: (self: Overlay, fn: (() -> ())?) -> (),
	focus: (self: Overlay, target: GuiObject?) -> (),
	destroy: (self: Overlay) -> (),
}

local function lastInputIsGamepad(): boolean
	local t = UserInputService:GetLastInputType()
	return t.Name:sub(1, 7) == "Gamepad"
end

function Overlay.designSizeFor(screen: Screen.ScreenObject): Vector2
	local p = screen:profile()
	local i = p.insets
	local safe = p.size - Vector2.new(i.left + i.right, i.top + i.bottom)
	return safe / screen:uiScale()
end

function Overlay.kindFor(size: Vector2): Kind
	if size.Y < 420 then
		return "Short"
	elseif size.X < 560 then
		return "Tall"
	end
	return "Wide"
end

function Overlay.new(ctx: Ctx, options: Options): Overlay
	local trove = Trove.new()
	local isOpen = false
	local destroyed = false
	local back = options.onBack
	local returnTo: GuiObject? = nil
	local actionName = "Lane3Back_" .. options.name .. "_" .. HttpService:GenerateGUID(false)
	local closeToken = 0
	local dimTarget = options.dimTransparency or 0.45

	local root: Frame = trove:Add(make("Frame", {
		Name = options.name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
	}))
	local hudScale: UIScale = make("UIScale", { Name = "HudScale", Parent = root })
	local dim: TextButton? = nil
	if options.dim ~= false then
		local d: TextButton = make("TextButton", {
			Name = "Dim",
			BackgroundColor3 = Style.Ink,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Selectable = false,
			Text = "",
			ZIndex = 1,
			Parent = root,
		})
		trove:Connect(d.Activated, function()
			if isOpen and options.onDim then
				options.onDim()
			end
		end)
		dim = d
	end
	local content: Frame = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = root,
	})
	local pop: UIScale = make("UIScale", { Name = "Pop", Parent = content })

	local function unbind()
		ContextActionService:UnbindAction(actionName)
	end
	trove:Add(unbind)
	trove:Add(function()
		destroyed = true
		Motion.cancelAll(content)
		Motion.cancelAll(pop)
		if dim then
			Motion.cancelAll(dim)
		end
	end)

	local overlay: Overlay
	overlay = {
		root = root,
		dim = dim,
		content = content,
		trove = trove,
		designSize = function(_self: Overlay): Vector2
			return Overlay.designSizeFor(ctx.screen)
		end,
		kind = function(self: Overlay): Kind
			return Overlay.kindFor(self:designSize())
		end,
		applyScale = function(_self: Overlay)
			local s = ctx.screen:uiScale()
			hudScale.Scale = s
			root.Size = UDim2.fromScale(1 / s, 1 / s)
			if dim then
				local i = ctx.screen:profile().insets
				dim.Position = UDim2.fromOffset(-i.left / s, -i.top / s)
				dim.Size = UDim2.new(1, (i.left + i.right) / s, 1, (i.top + i.bottom) / s)
			end
		end,
		open = function(self: Overlay, focus: GuiObject?, from: GuiObject?)
			if destroyed or isOpen then
				return
			end
			isOpen = true
			closeToken += 1
			returnTo = from or GuiService.SelectedObject
			self:applyScale()
			root.Visible = true
			ContextActionService:BindActionAtPriority(
				actionName,
				function(_name: string, state: Enum.UserInputState, _input: InputObject)
					if state == Enum.UserInputState.Begin and isOpen and back then
						back()
					end
					return Enum.ContextActionResult.Sink
				end,
				false,
				Enum.ContextActionPriority.High.Value + 10,
				Enum.KeyCode.Escape,
				Enum.KeyCode.ButtonB
			)
			if options.sounds ~= false then
				Sounds.play("Open")
			end
			local reduced = Motion.reduced()
			if dim then
				dim.BackgroundTransparency = 1
				Motion.tween(dim, "dim", Motion.info(if reduced then 0.12 else M.Panel), {
					BackgroundTransparency = dimTarget,
				})
			end
			if reduced or options.slide == false then
				Motion.cancelAll(content)
				Motion.cancelAll(pop)
				content.Position = UDim2.fromScale(0.5, 0.5)
				pop.Scale = 1
			else
				content.Position = UDim2.new(0.5, 0, 0.5, 24)
				pop.Scale = 0.97
				Motion.tween(content, "slide", Motion.info(M.Panel, Enum.EasingStyle.Quart), {
					Position = UDim2.fromScale(0.5, 0.5),
				})
				Motion.tween(pop, "pop", Motion.info(M.Panel, Enum.EasingStyle.Back), { Scale = 1 })
			end
			self:focus(focus)
		end,
		close = function(_self: Overlay)
			if destroyed or not isOpen then
				return
			end
			isOpen = false
			unbind()
			if options.sounds ~= false then
				Sounds.play("Close")
			end
			-- return the selection
			local selectedNow = GuiService.SelectedObject
			if selectedNow and selectedNow:IsDescendantOf(root) then
				local target = returnTo
				if target and target:IsDescendantOf(game) and target.Visible then
					GuiService.SelectedObject = target
				else
					GuiService.SelectedObject = nil
				end
			end
			returnTo = nil
			closeToken += 1
			local token = closeToken
			local reduced = Motion.reduced()
			local seconds = if reduced then 0.1 else M.PanelOut
			if dim then
				Motion.tween(dim, "dim", Motion.info(seconds), { BackgroundTransparency = 1 })
			end
			if not reduced and options.slide ~= false then
				Motion.tween(content, "slide", Motion.info(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0.5, 16),
				})
			end
			task.delay(seconds, function()
				if not destroyed and token == closeToken and not isOpen then
					root.Visible = false
				end
			end)
		end,
		isOpen = function(_self: Overlay): boolean
			return isOpen
		end,
		setBack = function(_self: Overlay, fn: (() -> ())?)
			back = fn
		end,
		focus = function(_self: Overlay, target: GuiObject?)
			if target and lastInputIsGamepad() then
				GuiService.SelectedObject = target
			end
		end,
		destroy = function(_self: Overlay)
			if not destroyed then
				trove:Destroy()
			end
		end,
	}
	root.Parent = ctx.layer
	overlay:applyScale()
	return overlay
end

-- The labelled CLOSE button (kit red fill + Close icon; 48 px touch minimum).
function Overlay.closeButton(parent: Instance, onActivate: () -> ()): Arcade.Button
	return Arcade.button(parent, {
		name = "Close",
		label = "CLOSE",
		fill = "Settings",
		size = "Custom",
		width = CLOSE_W,
		height = Tokens.Touch.Minimum,
		icon = "Close",
		sound = "Close",
		onActivate = onActivate,
	})
end
Overlay.CloseWidth = CLOSE_W

-- A readable single line: white (or `colour`) with the kit's minor dark outline; shrinks to fit
-- its box down to the 16 minimum instead of overflowing or cutting words.
function Overlay.text(
	parent: Instance,
	text: string,
	size: number,
	colour: Color3?,
	align: Enum.TextXAlignment?,
	z: number?
): TextLabel
	local s = math.max(size, Tokens.TextSize.Minimum)
	local label: TextLabel = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, s + 6),
		FontFace = Tokens.font(),
		Text = text,
		TextSize = s,
		TextScaled = true,
		TextColor3 = colour or Color3.new(1, 1, 1),
		TextXAlignment = align or Enum.TextXAlignment.Left,
		ZIndex = z or 6,
		Parent = parent,
	})
	make("UITextSizeConstraint", { MaxTextSize = s, MinTextSize = Tokens.TextSize.Minimum, Parent = label })
	make("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), Parent = label })
	Arcade.outline(label, "Minor")
	return label
end

-- Wrapped paragraph text that grows downward (AutomaticSize Y) inside a fixed width.
function Overlay.paragraph(parent: Instance, text: string, size: number, colour: Color3?, z: number?): TextLabel
	local p = Style.paragraph(parent, text, size, false, z)
	if colour then
		p.TextColor3 = colour
	end
	return p
end

-- An outlined white headline in the kit's Display role (optional glyph face).
function Overlay.title(parent: Instance, text: string, size: number, face: Arcade.FaceName?, z: number?): TextLabel
	local t = Style.text(parent, text, "Display", { face = face, z = z or 6, size = size })
	t.Name = "Title"
	return t
end

-- A progress bar: a dark track with a dark boundary, a kit-fill bar (0..1) and outlined text.
-- Returns the track and a setter.
function Overlay.progress(parent: Instance, fill: Arcade.FillName, z: number?): (Frame, (number, string) -> ())
	local zi = z or 6
	local track: Frame = make("Frame", {
		Name = "Progress",
		BackgroundColor3 = Style.Well,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = zi,
		Parent = parent,
	})
	Arcade.corner(track, 6)
	Arcade.outline(track, "Minor")
	local bar: Frame = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = zi + 1,
		Parent = track,
	})
	Arcade.corner(bar, 6)
	make("UIGradient", { Color = PreviewTokens.Arcade.Fill[fill], Rotation = 90, Parent = bar })
	local label = Overlay.text(track, "", 16, nil, Enum.TextXAlignment.Center, zi + 2)
	label.Size = UDim2.fromScale(1, 1)
	local function set(fraction: number, text: string)
		local f = math.clamp(fraction, 0, 1)
		bar.Size = UDim2.fromScale(f, 1)
		bar.Visible = f > 0
		label.Text = text
	end
	return track, set
end

return Overlay
