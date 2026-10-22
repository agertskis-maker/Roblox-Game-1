--!strict
-- Shared motion vocabulary for the HUD prototype (Lane 3 preview). One place decides timings,
-- cancels superseded tweens and applies reduced motion immediately.
--
--   Motion.tween(instance, key, info, goal)   -- cancels the previous tween on (instance, key)
--   Motion.cancelAll(instance)                -- e.g. when a component is destroyed or hidden
--   Motion.reduced()                          -- the player's Roblox setting, or the preview override
--   Motion.onReducedChanged(fn) -> disconnect -- fires on every change (checked every 0.5 s,
--                                                because Roblox documents no change signal)
--   Motion.pop(instance, scale)               -- a short emphasis on a UIScale child (skipped
--                                                in reduced motion: a short fade happens instead)
--
-- Reduced motion follows GuiService.ReducedMotionEnabled plus the preview-only LocalPlayer
-- attribute "Lane3ReducedMotionOverride" (approved mechanism, 2026-10-19). Never saved.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PreviewTokens = require(script.Parent.PreviewTokens)

local Motion = {}

local OVERRIDE = "Lane3ReducedMotionOverride"

local active: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

function Motion.reduced(): boolean
	local player = Players.LocalPlayer
	local override = player and player:GetAttribute(OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

function Motion.setOverride(value: boolean?)
	local player = Players.LocalPlayer
	if player then
		player:SetAttribute(OVERRIDE, value)
	end
end

local listeners: { (boolean) -> () } = {}
local last = Motion.reduced()
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < 0.5 then
		return
	end
	accumulated = 0
	local now = Motion.reduced()
	if now ~= last then
		last = now
		for _, fn in table.clone(listeners) do
			task.spawn(fn, now)
		end
	end
end)
do
	local player = Players.LocalPlayer
	if player then
		player:GetAttributeChangedSignal(OVERRIDE):Connect(function()
			local now = Motion.reduced()
			if now ~= last then
				last = now
				for _, fn in table.clone(listeners) do
					task.spawn(fn, now)
				end
			end
		end)
	end
end

function Motion.onReducedChanged(fn: (boolean) -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		local i = table.find(listeners, fn)
		if i then
			table.remove(listeners, i)
		end
	end
end

function Motion.tween(instance: Instance, key: string, info: TweenInfo, goal: { [string]: any }): Tween
	local byKey = active[instance]
	if not byKey then
		byKey = {}
		active[instance] = byKey
	end
	local old = byKey[key]
	if old then
		old:Cancel()
	end
	local t = TweenService:Create(instance, info, goal)
	byKey[key] = t
	t.Completed:Connect(function()
		if byKey[key] == t then
			byKey[key] = nil
		end
	end)
	t:Play()
	return t
end

function Motion.cancelAll(instance: Instance)
	local byKey = active[instance]
	if byKey then
		for _, t in byKey do
			t:Cancel()
		end
		active[instance] = nil
	end
end

function Motion.info(seconds: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): TweenInfo
	return TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
end

-- A brief emphasis: scale up to `scale` (default the shared Emphasis) and back. Needs a UIScale
-- child named "Pop" (created if missing). In reduced motion the scale stays 1.
function Motion.pop(target: GuiObject, scale: number?)
	local s = target:FindFirstChild("Pop") :: UIScale?
	if not s then
		local created = Instance.new("UIScale")
		created.Name = "Pop"
		created.Parent = target
		s = created
	end
	local ui = s :: UIScale
	if Motion.reduced() then
		ui.Scale = 1
		return
	end
	local m = PreviewTokens.Motion
	ui.Scale = 1
	local up = Motion.tween(ui, "pop", Motion.info(m.EmphasisSeconds * 0.45, Enum.EasingStyle.Back), {
		Scale = scale or m.Emphasis,
	})
	up.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			Motion.tween(ui, "pop", Motion.info(m.EmphasisSeconds * 0.55), { Scale = 1 })
		end
	end)
end

-- Press feedback for buttons (touch, mouse and gamepad all use it).
function Motion.press(target: GuiObject, down: boolean)
	local s = target:FindFirstChild("Press") :: UIScale?
	if not s then
		local created = Instance.new("UIScale")
		created.Name = "Press"
		created.Parent = target
		s = created
	end
	local m = PreviewTokens.Motion
	Motion.tween(s :: UIScale, "press", Motion.info(if down then m.Press else m.Release), {
		Scale = if down then 0.94 else 1,
	})
end

return Motion
