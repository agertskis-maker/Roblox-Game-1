--!strict
-- Per-layer fading for small Home HUD groups (Lane 3 preview). CanvasGroup is avoided for
-- transient pieces that change size (research note: CanvasGroup should stay small and static),
-- so a group records every layer's resting transparency once and fades all of them from one
-- value, the way OutlinedText.setFade does: 0 = resting look, 1 = fully transparent.
--
--   local fade = Fade.capture(root)      -- call after the group is built (re-capture if rebuilt)
--   fade:set(0.4)
--   fade:tween(1, seconds) -> Tween?     -- driven by a NumberValue; nil when snapped (seconds 0)
--   fade:destroy()

local Motion = require(script.Parent.Parent.Motion)

local Fade = {}
Fade.__index = Fade

type Entry = { instance: Instance, property: string, rest: number }

local function collect(root: Instance, list: { Entry })
	local function add(instance: Instance, property: string, value: number)
		table.insert(list, { instance = instance, property = property, rest = value })
	end
	local all = root:GetDescendants()
	table.insert(all, 1, root)
	for _, d in all do
		if d:IsA("UIStroke") then
			add(d, "Transparency", d.Transparency)
		elseif d:IsA("UIGradient") then
			continue
		elseif d:IsA("TextLabel") or d:IsA("TextButton") then
			add(d, "TextTransparency", d.TextTransparency)
			add(d, "BackgroundTransparency", d.BackgroundTransparency)
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			add(d, "ImageTransparency", d.ImageTransparency)
			add(d, "BackgroundTransparency", d.BackgroundTransparency)
		elseif d:IsA("GuiObject") then
			add(d, "BackgroundTransparency", d.BackgroundTransparency)
		end
	end
end

function Fade.capture(root: Instance)
	local self = setmetatable({}, Fade)
	self._entries = {} :: { Entry }
	collect(root, self._entries)
	self._value = Instance.new("NumberValue")
	self._value.Value = 0
	self._conn = self._value.Changed:Connect(function(v: number)
		self:_apply(v)
	end)
	self.value = 0
	return self
end

export type FadeObject = typeof(Fade.capture(Instance.new("Frame")))

function Fade._apply(self: FadeObject, f: number)
	local k = math.clamp(f, 0, 1)
	self.value = k
	for _, e in self._entries do
		if e.rest < 1 then
			(e.instance :: any)[e.property] = 1 - (1 - e.rest) * (1 - k)
		end
	end
end

function Fade.set(self: FadeObject, f: number)
	Motion.cancelAll(self._value)
	if self._value.Value == f then
		self:_apply(f)
	else
		self._value.Value = f
	end
end

function Fade.tween(self: FadeObject, f: number, seconds: number): Tween?
	if seconds <= 0 then
		self:set(f)
		return nil
	end
	return Motion.tween(self._value, "fade", Motion.info(seconds), { Value = f })
end

function Fade.destroy(self: FadeObject)
	Motion.cancelAll(self._value)
	self._conn:Disconnect()
	self._value:Destroy()
	table.clear(self._entries)
end

return Fade
