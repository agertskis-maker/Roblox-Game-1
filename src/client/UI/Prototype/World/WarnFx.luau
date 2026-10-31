--!strict
-- World warning emphasis on the RIDDEN car (Lane 3 preview, HUD rebuild 2026-10-22, worker HW;
-- ledger E-02). Shown only for an explicit warning (store event RunWarning or `run.warning`),
-- never inferred from Heat.
--
--   * one controlled red emphasis: the shared Highlight (CarHighlight "Warn" layer, which wins
--     over the capture outline) with a red fill at 62–80% transparency and a red outline. The
--     car model is never touched: no material, colour or variant change, so nothing needs
--     restoring (getDebugState compares a fingerprint of the car's parts before and after);
--   * a world "!" badge and a short reason ("TOO HOT!") beside the rider, camera-relative to the
--     side of the roof so it never sits on the road ahead; AlwaysOnTop (safety information);
--   * no strobe: one slow fill pulse every 1.25 s (0.8 per second, under the 1 per second
--     ceiling); reduced motion: steady fill, no pop;
--   * sound: Sounds.play("Warning") once per warning id (never a repeated blip).
-- Ends when `run.warning` clears, on Dismounted / RunEnded, mode change, reset or despawn, or
-- after 4 s when the warning came only as an event (no `run.warning` holding it).
--
-- Reason mapping (truthful fallback): "TooHot" -> "TOO HOT!"; anything else -> "CAREFUL!".
--
--   local warn = WarnFx.new(ctx, { ride = model?, rideId = id? })
--   warn:setRide(instanceId?, model?)
--   warn:show(warningId, reason)  warn:clear()
--   warn:layout(), warn:setVisible(on), warn:destroy(), warn:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(script.Parent.Parent.Arcade)
local CarHighlight = require(script.Parent.CarHighlight)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local A = PreviewTokens.Arcade
local RED = PreviewTokens.Color.HeatHigh
local RED_LIGHT = Color3.fromRGB(255, 96, 80) -- TOKEN CANDIDATE: warning outline on the car
local PULSE_SECONDS = 1.25
local FILL_MIN, FILL_MAX = 0.45, 0.6 -- was 0.62..0.8: read as a hairline in Studio (reviewer, 2026-10-23)
local EVENT_ONLY_SECONDS = 4
local BOARD = Vector2.new(230, 64)

local REASONS: { [string]: string } = { TooHot = "TOO HOT!" }
local FALLBACK = "CAREFUL!"

local WarnFx = {}
WarnFx.__index = WarnFx

local function fingerprint(model: Instance?): string
	if not model then
		return ""
	end
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d.Name .. ":" .. tostring(d.Color) .. ":" .. d.Material.Name .. ":" .. d.Transparency)
		end
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

function WarnFx.new(ctx: WorldKit.Ctx, options: { ride: Instance?, rideId: string?, badge: boolean? }?)
	local self = setmetatable({}, WarnFx)
	-- badge = false: only the car emphasis (the run HUD already draws the "!" + reason chip;
	-- lead integration 2026-10-22, so the reason is never shown twice)
	self._showBadge = not (options and options.badge == false)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._ride = nil :: Instance?
	self._rideId = nil :: string?
	self._warningId = nil :: string?
	self._reason = nil :: string?
	self._startedAt = 0
	self._heldByState = false
	self._step = nil :: RBXScriptConnection?
	self._phase = 0
	self._sounds = 0
	self._shown = 0
	self._before = ""
	self._carUnchanged = true

	self._hl = CarHighlight.get(ctx.world)
	self._trove:Add(function()
		self._hl:set("Warn", nil)
		self._hl:release()
	end)

	local board = self._trove:Add(Instance.new("BillboardGui"))
	board.Name = "WarnBadge"
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = 200
	board.ResetOnSpawn = false
	board.Enabled = false
	board.Parent = ctx.world
	self._board = board
	local holder = Arcade.make("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(BOARD.X, BOARD.Y),
		Parent = board,
	})
	self._scale = Arcade.make("UIScale", { Name = "HudScale", Parent = holder }) :: UIScale
	local badge = Arcade.make("Frame", {
		Name = "Bang",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = A.Badge,
		Parent = holder,
	}) :: Frame
	Arcade.corner(badge, 12)
	Arcade.outline(badge, "Button")
	Arcade.make("UIGradient", { Color = A.Face.Danger, Rotation = 90, Parent = badge })
	local bang = Arcade.text(badge, { text = "!", role = "Display", name = "Mark", size = 40, outline = "Major" })
	bang.Size = UDim2.fromScale(1, 1)
	self._badge = badge
	local reason = Arcade.text(holder, {
		text = FALLBACK,
		role = "Display",
		name = "Reason",
		size = 30,
		face = "Danger",
		xAlign = Enum.TextXAlignment.Left,
		outline = "Major",
	})
	reason.AnchorPoint = Vector2.new(0, 0.5)
	reason.Position = UDim2.new(0, 64, 0.5, 0)
	reason.Size = UDim2.new(1, -64, 0, 40)
	self._reasonLabel = reason

	if options and options.ride then
		self:setRide(options.rideId, options.ride)
	end

	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "RunWarning" then
			self:show(event.id, event.reason or "")
		elseif event.kind == "Dismounted" or event.kind == "RunEnded" then
			self:clear()
		end
	end)
	self._trove:Add(ctx.store:subscribe("run", function(run: Store.RunState?)
		local w = run and run.warning
		if w then
			self._heldByState = true
			self:show(w.id, w.reason)
		elseif self._heldByState then
			self._heldByState = false
			self:clear()
		end
	end))
	self._trove:Connect(ctx.store.ModeChanged, function()
		self:clear()
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_render(0)
	end))
	self._trove:Add(function()
		self:_stopStep()
	end)
	self:layout()
	return self
end

export type WarnFx = typeof(WarnFx.new((nil :: any) :: WorldKit.Ctx))

function WarnFx.setRide(self: WarnFx, instanceId: string?, model: Instance?)
	if model ~= self._ride and self._warningId then
		self:clear()
	end
	self._ride = model
	self._rideId = instanceId
	local part = WorldKit.mainPart(model)
	self._board.Adornee = part
	if model and part then
		local box, size = WorldKit.box(model)
		local top = box.Position.Y + size.Y / 2 - part.Position.Y
		-- camera-relative: beside the rider (to the right) and a little above the roof
		self._board.StudsOffset = Vector3.new(size.X / 2 + 3, top + 2, 0)
	end
end

function WarnFx.show(self: WarnFx, warningId: string, reason: string)
	local part = WorldKit.mainPart(self._ride)
	if not part then
		return
	end
	if self._warningId == warningId then
		return -- duplicate or repeated state update: no restart, no second sound
	end
	local fresh = self._warningId == nil
	self._warningId = warningId
	self._reason = REASONS[reason] or FALLBACK
	self._reasonLabel.Text = self._reason :: string
	self._startedAt = os.clock()
	self._shown += 1
	if fresh then
		self._before = fingerprint(self._ride)
		self._phase = 0
		self._board.Enabled = self._visible and self._showBadge
		if not Motion.reduced() then
			Motion.pop(self._badge, 1.15)
		end
	end
	self._sounds += 1
	Sounds.play("Warning")
	self:_render(0)
	self:_startStep()
end

function WarnFx.clear(self: WarnFx)
	if not self._warningId then
		return
	end
	self._warningId = nil
	self._reason = nil
	self:_stopStep()
	self._hl:set("Warn", nil)
	self._board.Enabled = false
	self._carUnchanged = self._before == fingerprint(self._ride)
end

function WarnFx._render(self: WarnFx, dt: number)
	if not self._warningId or not self._ride then
		return
	end
	local fill = (FILL_MIN + FILL_MAX) / 2
	if not Motion.reduced() then
		self._phase = (self._phase + dt / PULSE_SECONDS) % 1
		-- one smooth pulse per period (a cosine, no hard on/off)
		local wave = (1 - math.cos(self._phase * math.pi * 2)) / 2
		fill = FILL_MAX - (FILL_MAX - FILL_MIN) * wave
	end
	if not self._visible then
		self._hl:set("Warn", nil)
		return
	end
	self._hl:set("Warn", {
		adornee = self._ride :: Instance,
		outline = RED_LIGHT,
		outlineTransparency = 0.1,
		fill = RED,
		fillTransparency = WorldKit.quantise(fill, 0.02),
	})
end

function WarnFx._startStep(self: WarnFx)
	if self._step then
		return
	end
	self._step = RunService.Heartbeat:Connect(function(dt: number)
		local ride = self._ride
		if not ride or not ride:IsDescendantOf(game) then
			self:clear()
			return
		end
		if not self._heldByState and os.clock() - self._startedAt > EVENT_ONLY_SECONDS then
			self:clear()
			return
		end
		self:_render(dt)
	end)
end

function WarnFx._stopStep(self: WarnFx)
	if self._step then
		self._step:Disconnect()
		self._step = nil
	end
end

function WarnFx.layout(self: WarnFx)
	local s = WorldKit.billboardScale(self._ctx)
	self._scale.Scale = s
	self._board.Size = UDim2.fromOffset(math.ceil(BOARD.X * s), math.ceil(BOARD.Y * s))
end

function WarnFx.setVisible(self: WarnFx, on: boolean)
	self._visible = on
	self._board.Enabled = on and self._showBadge and self._warningId ~= nil
	self:_render(0)
end

function WarnFx.getDebugState(self: WarnFx): { [string]: any }
	return {
		active = self._warningId ~= nil,
		warningId = self._warningId,
		reasonText = self._reason,
		heldByState = self._heldByState,
		highlight = self._hl:debug(),
		badgeShown = self._board.Enabled,
		sounds = self._sounds,
		shown = self._shown,
		pulsePerSecond = if Motion.reduced() then 0 else 1 / PULSE_SECONDS,
		stepping = self._step ~= nil,
		carUnchangedAfterLastWarning = self._carUnchanged,
	}
end

function WarnFx.destroy(self: WarnFx)
	self:clear()
	self._trove:Destroy()
end

return WarnFx
