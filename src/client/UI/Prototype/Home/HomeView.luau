--!strict
-- Home/HomeView: what the Home HUD knows about the screen it is on (Lane 3, Round 2 N7-03, 2026-11-02). It turns EITHER
--   * a live GuiObject (a ScreenGui, or the Frame the HUD is mounted in): its AbsoluteSize, the camera viewport and touch
--     support, the real thing a Roblox player has, OR
--   * the preview's virtual Screen (Prototype/Screen: an assumed device frame with its insets and reserved touch zones)
-- into one plain table of numbers the layout works from. Everything is in DESIGN px of the safe area: the real size divided
-- by the approved short-side scale (Tokens.uiScaleFor), so a component positions itself at (x * scale, y * scale) in real
-- px and puts a UIScale of `scale` on its own root.
--
--   local view = HomeView.new(parent, { screen = screenObject? })   -- screen: the playground's Screen; nil = live
--   view:get() -> Metrics          width, height (safe design px), scale, kind, touch, zones, margin
--   view:billboardScale() -> number  design px to real viewport px for a BillboardGui
--   view.Changed                   Signal, fires (coalesced) when any of that changes
--   view:destroy()
--
-- Reserved touch zones follow Roblox's default touch layout, as the preview's Screen assumes it (a thumbstick in the lower
-- left, the jump button in the lower right); they are approximations, so the HUD keeps clear of them with room to spare.
-- The notch and the top bar are the host's job: a ScreenGui with ScreenInsets = CoreUISafe (the default) already excludes
-- the top bar, and the preview's Screen applies its own insets once.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local HomeView = {}
HomeView.__index = HomeView

export type Rect = { name: string?, x: number, y: number, w: number, h: number }
-- A JSON-safe vector for the debug states (HttpService cannot encode a Vector2).
function HomeView.vec(v: Vector2): { x: number, y: number }
	return { x = math.floor(v.X * 10 + 0.5) / 10, y = math.floor(v.Y * 10 + 0.5) / 10 }
end

export type Metrics = {
	width: number, -- the safe area, design px
	height: number,
	scale: number, -- the HUD's UIScale
	kind: "Phone" | "Tablet" | "Desktop",
	touch: boolean,
	zones: { Rect }, -- reserved touch zones, design px in the safe area
	margin: number, -- the side margin
	top: number, -- the top margin
	bottom: number, -- the bottom margin
}

-- The preview Screen's own shape (Prototype/Screen.ScreenObject), only what is read here.
type ScreenLike = {
	profile: (any) -> any,
	uiScale: (any) -> number,
	fitScale: (any) -> number,
	Changed: any,
}

export type View = {
	Changed: any,
	get: (self: View) -> Metrics,
	billboardScale: (self: View) -> number,
	destroy: (self: View) -> (),
}

local function marginsFor(kind: string): (number, number, number)
	if kind == "Phone" then
		return 8, 4, 8
	end
	return 12, 8, 12
end

-- The default Roblox touch zones for a full viewport (design: the preview's phoneZones).
local function touchZones(viewport: Vector2): { { name: string, x: number, y: number, w: number, h: number } }
	local short = math.min(viewport.X, viewport.Y)
	local jump = if short <= 500 then 70 else 120
	local jumpPos = if short <= 500
		then Vector2.new(viewport.X - 95, viewport.Y - 90)
		else Vector2.new(viewport.X - jump * 1.5, viewport.Y - jump * 1.75)
	return {
		{ name = "Thumbstick", x = 0, y = viewport.Y * 0.55, w = viewport.X * 0.4, h = viewport.Y * 0.45 },
		{ name = "Jump", x = jumpPos.X, y = jumpPos.Y, w = jump, h = jump },
	}
end

function HomeView.new(parent: GuiBase2d?, options: { screen: any? }?): View
	local self = setmetatable({}, HomeView) :: any
	local trove = Trove.new()
	self._trove = trove
	self._parent = parent
	self._screen = if options then options.screen else nil
	self._destroyed = false
	self._pending = false
	self.Changed = trove:Add(Signal.new())
	self._last = ""

	local function changed()
		if self._pending or self._destroyed then
			return
		end
		self._pending = true
		task.defer(function()
			self._pending = false
			if self._destroyed then
				return
			end
			-- fire only when the numbers really moved, so a layout never feeds back into itself
			local m = self:get()
			local key = string.format("%d:%d:%.3f:%s:%d", m.width, m.height, m.scale, m.kind, #m.zones)
			if key ~= self._last then
				self._last = key
				self.Changed:Fire(m)
			end
		end)
	end
	local screen: ScreenLike? = self._screen
	if screen then
		trove:Add(screen.Changed:Connect(changed))
	else
		if parent then
			trove:Connect(parent:GetPropertyChangedSignal("AbsoluteSize"), changed)
		end
		local camera = Workspace.CurrentCamera
		if camera then
			trove:Connect(camera:GetPropertyChangedSignal("ViewportSize"), changed)
		end
		trove:Connect(UserInputService:GetPropertyChangedSignal("TouchEnabled"), changed)
	end
	local m = self:get()
	self._last = string.format("%d:%d:%.3f:%s:%d", m.width, m.height, m.scale, m.kind, #m.zones)
	return self :: View
end

function HomeView.get(self: any): Metrics
	local screen: ScreenLike? = self._screen
	if screen then
		local p = screen:profile()
		local i = p.insets
		local scale = screen:uiScale()
		local kind: "Phone" | "Tablet" | "Desktop" = p.kind
		local margin, top, bottom = marginsFor(kind)
		local zones: { Rect } = {}
		for _, z in p.zones do
			table.insert(zones, {
				name = z.name,
				x = (z.position.X - i.left) / scale,
				y = (z.position.Y - i.top) / scale,
				w = z.size.X / scale,
				h = z.size.Y / scale,
			})
		end
		return {
			width = (p.size.X - i.left - i.right) / scale,
			height = (p.size.Y - i.top - i.bottom) / scale,
			scale = scale,
			kind = kind,
			touch = p.touch,
			zones = zones,
			margin = margin,
			top = top,
			bottom = bottom,
		}
	end
	local parent: GuiBase2d? = self._parent
	local size = if parent then parent.AbsoluteSize else Vector2.new(1280, 720)
	local origin = if parent then parent.AbsolutePosition else Vector2.zero
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else size
	local scale = Tokens.uiScaleFor(size)
	local touch = UserInputService.TouchEnabled
	local short = math.min(viewport.X, viewport.Y)
	local kind: "Phone" | "Tablet" | "Desktop" = if touch
		then (if short <= 500 then "Phone" else "Tablet")
		else "Desktop"
	local margin, top, bottom = marginsFor(kind)
	local zones: { Rect } = {}
	if touch then
		-- the zones are drawn in the full viewport; the parent may sit lower (below the top bar)
		local inset = GuiService:GetGuiInset()
		local base = origin
		if parent and parent:IsA("ScreenGui") then
			local gui = parent :: any
			base = if gui.ScreenInsets == Enum.ScreenInsets.None then Vector2.zero else Vector2.new(0, inset.Y)
		end
		for _, z in touchZones(viewport) do
			table.insert(zones, {
				name = z.name,
				x = (z.x - base.X) / scale,
				y = (z.y - base.Y) / scale,
				w = z.w / scale,
				h = z.h / scale,
			})
		end
	end
	return {
		width = size.X / scale,
		height = size.Y / scale,
		scale = scale,
		kind = kind,
		touch = touch,
		zones = zones,
		margin = margin,
		top = top,
		bottom = bottom,
	}
end

function HomeView.billboardScale(self: any): number
	local screen: ScreenLike? = self._screen
	if screen then
		return screen:uiScale() * screen:fitScale()
	end
	return self:get().scale
end

function HomeView.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return HomeView
