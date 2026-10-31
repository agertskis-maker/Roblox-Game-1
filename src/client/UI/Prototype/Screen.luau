--!strict
-- Virtual device screens for the HUD prototype (Lane 3 preview). Studio's device emulator needs
-- clicks nobody can make overnight, so the prototype lays itself out inside a frame of the target
-- device's size (in device pixels), with that device's assumed safe insets and reserved touch
-- zones, scaled to fit the real Studio viewport for display. This proves layout, clipping and
-- hit-box sizes at those sizes; it does not prove a real device's rendering or performance.
--
--   local screen = Screen.new(screenGui, "PhoneLandscape")
--   screen.root   -- Frame in device pixels (components place themselves inside screen.safe)
--   screen.safe   -- the safe area (insets applied once, here; components never add insets)
--   screen:uiScale()            -- the approved short-side rule for this device (Tokens.uiScaleFor)
--   screen:setProfile("PhoneLandscape")  -- fires screen.Changed(profile); landscape frames only (Round 2)
--   screen:toDevice(absolute)   -- a real-viewport pixel position or size -> device pixels
--   screen:showReserved(on)     -- diagnostics: draw the reserved thumbstick and jump zones

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Screen = {}
Screen.__index = Screen

export type Insets = { top: number, bottom: number, left: number, right: number }
export type Zone = { name: string, position: Vector2, size: Vector2 }
export type Profile = {
	name: string,
	label: string,
	kind: "Desktop" | "Tablet" | "Phone", -- layout class (every phone frame is landscape)
	size: Vector2,
	insets: Insets,
	touch: boolean,
	zones: { Zone },
}

-- Assumed insets (documented assumptions, not measurements): the Roblox top bar row (about 58
-- device px on desktop and tablet, 44 on phones) plus the device's own notch / home-indicator
-- areas. Round 2: landscape only (StarterGui.ScreenOrientation = LandscapeSensor); the portrait frame
-- is removed. PhoneLandscapeLeft / Right model a notch on one side (left or right inset 47, the other
-- 21 for the home indicator); PhoneSmall is the smallest practical viewport (740 x 360). Touch zones follow Roblox's default TouchGui layout (thumbstick in the lower left,
-- jump in the lower right), approximated.
local function phoneZones(size: Vector2): { Zone }
	local short = math.min(size.X, size.Y)
	local jump = if short <= 500 then 70 else 120
	local jumpPos = if short <= 500
		then Vector2.new(size.X - 95, size.Y - 90)
		else Vector2.new(size.X - jump * 1.5, size.Y - jump * 1.75)
	return {
		{
			name = "Thumbstick",
			position = Vector2.new(0, size.Y * 0.55),
			size = Vector2.new(size.X * 0.4, size.Y * 0.45),
		},
		{ name = "Jump", position = jumpPos, size = Vector2.new(jump, jump) },
	}
end

Screen.Profiles = {
	Desktop = {
		name = "Desktop",
		kind = "Desktop",
		label = "Desktop 1920 x 1080",
		size = Vector2.new(1920, 1080),
		insets = { top = 58, bottom = 0, left = 0, right = 0 },
		touch = false,
		zones = {},
	},
	PhoneLandscape = {
		name = "PhoneLandscape",
		kind = "Phone",
		label = "Phone landscape 844 x 390",
		size = Vector2.new(844, 390),
		insets = { top = 44, bottom = 21, left = 47, right = 47 },
		touch = true,
		zones = phoneZones(Vector2.new(844, 390)),
	},
	PhoneSmall = {
		name = "PhoneSmall",
		kind = "Phone",
		label = "Phone small landscape 740 x 360",
		size = Vector2.new(740, 360),
		insets = { top = 40, bottom = 20, left = 44, right = 44 },
		touch = true,
		zones = phoneZones(Vector2.new(740, 360)),
	},
	PhoneLandscapeLeft = {
		name = "PhoneLandscapeLeft",
		kind = "Phone",
		label = "Phone landscape, notch left 844 x 390",
		size = Vector2.new(844, 390),
		insets = { top = 44, bottom = 21, left = 47, right = 21 },
		touch = true,
		zones = phoneZones(Vector2.new(844, 390)),
	},
	PhoneLandscapeRight = {
		name = "PhoneLandscapeRight",
		kind = "Phone",
		label = "Phone landscape, notch right 844 x 390",
		size = Vector2.new(844, 390),
		insets = { top = 44, bottom = 21, left = 21, right = 47 },
		touch = true,
		zones = phoneZones(Vector2.new(844, 390)),
	},
	Tablet = {
		name = "Tablet",
		kind = "Tablet",
		label = "Tablet 1180 x 820",
		size = Vector2.new(1180, 820),
		insets = { top = 58, bottom = 20, left = 0, right = 0 },
		touch = true,
		zones = phoneZones(Vector2.new(1180, 820)),
	},
} :: { [string]: Profile }

Screen.Order = { "Desktop", "Tablet", "PhoneLandscape", "PhoneSmall", "PhoneLandscapeLeft", "PhoneLandscapeRight" }

function Screen.new(parent: Instance, profileName: string?)
	local self = setmetatable({}, Screen)
	self._trove = Trove.new()
	self.Changed = self._trove:Add(Signal.new())
	local root = Instance.new("Frame")
	root.Name = "Device"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.BackgroundTransparency = 1
	root.ClipsDescendants = true
	root.ZIndex = 1
	local fit = Instance.new("UIScale")
	fit.Name = "DeviceFit"
	fit.Parent = root
	local border = Instance.new("UIStroke")
	border.Name = "DeviceEdge"
	border.Color = Color3.fromRGB(255, 255, 255)
	border.Transparency = 0.6
	border.Thickness = 1
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = root
	local safe = Instance.new("Frame")
	safe.Name = "Safe"
	safe.BackgroundTransparency = 1
	safe.Parent = root
	local zones = Instance.new("Folder")
	zones.Name = "ReservedZones"
	zones.Parent = root
	root.Parent = parent
	self._trove:Add(root)
	self.root = root
	self.safe = safe
	self._fit = fit
	self._zones = zones
	self._showZones = false
	self._profile = Screen.Profiles[profileName or "Desktop"] or Screen.Profiles.Desktop
	local camera = Workspace.CurrentCamera
	if camera then
		self._trove:Connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
			self:_layout()
		end)
	end
	self:_layout()
	return self
end

export type ScreenObject = typeof(Screen.new(Instance.new("Folder")))

function Screen._layout(self: ScreenObject)
	local p = self._profile
	self.root.Size = UDim2.fromOffset(p.size.X, p.size.Y)
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else p.size
	-- leave a little room round the device for the preview controls
	local fit = math.min((viewport.X - 24) / p.size.X, (viewport.Y - 24) / p.size.Y, 1)
	local newFit = math.max(fit, 0.05)
	local fitChanged = math.abs(self._fit.Scale - newFit) > 1e-3
	self._fit.Scale = newFit
	local i = p.insets
	self.safe.Position = UDim2.fromOffset(i.left, i.top)
	self.safe.Size = UDim2.fromOffset(p.size.X - i.left - i.right, p.size.Y - i.top - i.bottom)
	self._zones:ClearAllChildren()
	if self._showZones then
		for _, z in p.zones do
			local f = Instance.new("Frame")
			f.Name = z.name
			f.Position = UDim2.fromOffset(z.position.X, z.position.Y)
			f.Size = UDim2.fromOffset(z.size.X, z.size.Y)
			f.BackgroundColor3 = Color3.fromRGB(255, 80, 200)
			f.BackgroundTransparency = 0.78
			f.ZIndex = 50
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Text = "RESERVED: " .. string.upper(z.name)
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextSize = 14
			label.FontFace = Tokens.font()
			label.ZIndex = 51
			label.Parent = f
			f.Parent = self._zones
		end
	end
	-- a viewport resize changes the fit: components that cache it (world billboards) re-lay out
	local changed = (self :: any).Changed
	if fitChanged and changed then
		changed:Fire(p)
	end
end

function Screen.profile(self: ScreenObject): Profile
	return self._profile
end

function Screen.uiScale(self: ScreenObject): number
	return Tokens.uiScaleFor(self._profile.size)
end

function Screen.fitScale(self: ScreenObject): number
	return self._fit.Scale
end

function Screen.setProfile(self: ScreenObject, name: string)
	local p = Screen.Profiles[name]
	if not p or p == self._profile then
		return
	end
	self._profile = p
	self:_layout()
	self.Changed:Fire(p)
end

function Screen.showReserved(self: ScreenObject, on: boolean)
	self._showZones = on
	self:_layout()
end

-- Real viewport pixels (AbsolutePosition / AbsoluteSize) to device pixels.
function Screen.toDevice(self: ScreenObject, v: Vector2): Vector2
	return v / self._fit.Scale
end

-- A GuiObject's rectangle in device pixels, relative to the device's top-left corner.
function Screen.rectOf(self: ScreenObject, g: GuiObject): (Vector2, Vector2)
	local origin = self.root.AbsolutePosition
	return self:toDevice(g.AbsolutePosition - origin), self:toDevice(g.AbsoluteSize)
end

-- Whether a device-pixel rectangle overlaps any reserved touch zone of the current profile.
function Screen.overlapsReserved(self: ScreenObject, pos: Vector2, size: Vector2): string?
	for _, z in self._profile.zones do
		local a0, a1 = pos, pos + size
		local b0, b1 = z.position, z.position + z.size
		if a0.X < b1.X and a1.X > b0.X and a0.Y < b1.Y and a1.Y > b0.Y then
			return z.name
		end
	end
	return nil
end

function Screen.destroy(self: ScreenObject)
	self._trove:Destroy()
end

return Screen
