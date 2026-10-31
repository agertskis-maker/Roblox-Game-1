--!strict
-- Hop landing reticle, target rim and brief HOP cue (Lane 3 preview, Round 2, R2-P1). Presentation only: it is
-- driven by setTarget / setState (from Run/HopCue) and never picks a target or judges a landing (Lane 1, Brian R).
--
-- ONE coordinated target. The footprint ring (World/HopRing) says WHERE, this reticle says the landing spot on the
-- roof, the thin teal rim outlines the target, and one brief "HOP" word appears once on lock-on. They share one
-- target model and one state, never four independent markers.
--
--   * RETICLE: four flat corner brackets (8 pooled parts) lying on the roof plane, sized from the target's bounding
--     box (small and restrained: 34% of the shorter side, 0.7-1.4 studs). It is anchored to the model bounds: the
--     roof top for a closed vehicle, the seat height for an open one (a model attribute OpenTop = true, or
--     VehicleKind = "Motorcycle"), so it never floats a bullseye inside a windshield or above an implausible spot.
--     Real car meshes are not in the repo yet: the preview proxies are boxes, so the roof anchor is their top and
--     this is labelled a proxy limitation.
--   * BEST: the brackets tighten to 72% and turn gold (one accent, held steady); the rim brightens.
--   * RIM: one Highlight (outline only, depth-occluded) on the target model, reused, never rebuilt.
--   * CUE: a small billboard word, shown for CUE_SECONDS after flashCue(), steady in reduced motion.
--   * Hidden: nothing is in the world and nothing runs. A target that despawns hides everything at once.
-- Follows the target on Heartbeat only while shown.
--
--   local reticle = LandingReticle.new(ctx, { target = model? })
--   reticle:setTarget(model?)   reticle:setState("Hidden" | "Ready" | "Best")   reticle:flashCue()
--   reticle:anchor() -> (CFrame?, number, "Roof" | "Open")   -- for tests (nil frame when the target is gone)
--   reticle:layout(), reticle:setVisible(on), reticle:destroy(), reticle:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKit = require(script.Parent.WorldKit)

local C = PreviewTokens.Color
local INK = PreviewTokens.Arcade.Ink
local GOLD = Color3.fromRGB(255, 204, 48) -- Hop's one timing accent (Keys gold stays a different, nearby shape)

export type ReticleState = "Hidden" | "Ready" | "Best"

local ARMS = 8
local TIGHT = 0.72
local FOLLOW = 16 -- 1/s: how quickly the brackets tighten
local CUE_SECONDS = 0.9
local THICK = 0.1
local ARM_WIDTH = 0.2

local LandingReticle = {}
LandingReticle.__index = LandingReticle

function LandingReticle.new(ctx: WorldKit.Ctx, options: { target: Instance? }?)
	local self = setmetatable({}, LandingReticle)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._state = "Hidden" :: ReticleState
	self._target = nil :: Instance?
	self._k = 1
	self._kGoal = 1
	self._half = 1
	self._kind = "Roof"
	self._cueUntil = 0
	self._step = nil :: RBXScriptConnection?
	self._moves = 0
	self._retargets = 0
	self._cues = 0

	local folder = self._trove:Add(Instance.new("Folder"))
	folder.Name = "LandingReticle"
	self._folder = folder
	self._arms = {} :: { BasePart }
	for i = 1, ARMS do
		local p = WorldKit.part(
			folder,
			"Arm" .. i,
			Vector3.new(0.5, THICK, ARM_WIDTH),
			CFrame.new(),
			C.HopLight,
			Enum.Material.Neon
		)
		p.Transparency = 1
		table.insert(self._arms, p)
	end
	-- the rim: one reused Highlight, outline only
	local rim = Instance.new("Highlight")
	rim.Name = "TargetRim"
	rim.DepthMode = Enum.HighlightDepthMode.Occluded
	rim.FillTransparency = 1
	rim.OutlineColor = C.HopLight
	rim.OutlineTransparency = 0.45
	rim.Enabled = false
	rim.Parent = folder
	self._rim = rim
	-- the brief cue word
	local anchor = WorldKit.part(folder, "CueAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), C.White)
	anchor.Transparency = 1
	self._cueAnchor = anchor
	local board = Instance.new("BillboardGui")
	board.Name = "HopCue"
	board.Adornee = anchor
	board.AlwaysOnTop = false
	board.LightInfluence = 0
	board.MaxDistance = 140
	board.ResetOnSpawn = false
	board.Size = UDim2.fromScale(3.6, 1.3)
	board.Enabled = false
	board.Parent = anchor
	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.BackgroundTransparency = 1
	word.Size = UDim2.fromScale(1, 1)
	word.FontFace = Tokens.font()
	word.TextScaled = true
	word.Text = "HOP"
	word.TextColor3 = C.White
	word.Parent = board
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = INK
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = word
	self._board, self._word = board, word

	self._trove:Add(Motion.onReducedChanged(function()
		self:_apply()
	end))
	self._trove:Add(function()
		self:_stopStep()
	end)
	if options and options.target then
		self:setTarget(options.target)
	end
	return self
end

export type LandingReticle = typeof(LandingReticle.new((nil :: any) :: WorldKit.Ctx))

-- The reticle's anchor on a model: a yaw-only frame at the landing spot, the half-size of the brackets and the
-- anchor kind. nil when the model is gone.
local function anchorOf(model: Instance?): (CFrame?, number, string)
	if not model or not model:IsDescendantOf(game) then
		return nil, 1, "Roof"
	end
	local box, size = WorldKit.box(model)
	local open = model:GetAttribute("OpenTop") == true or model:GetAttribute("VehicleKind") == "Motorcycle"
	local y = if open then box.Position.Y - size.Y / 2 + size.Y * 0.62 else box.Position.Y + size.Y / 2 + 0.08
	local at = Vector3.new(box.Position.X, y, box.Position.Z)
	local half = math.clamp(0.34 * math.min(size.X, size.Z), 0.7, 1.4)
	return WorldKit.flat(box, at), half, if open then "Open" else "Roof"
end

function LandingReticle.anchor(self: LandingReticle): (CFrame?, number, string)
	return anchorOf(self._target)
end

function LandingReticle._stopStep(self: LandingReticle)
	if self._step then
		self._step:Disconnect()
		self._step = nil
	end
end

function LandingReticle._place(self: LandingReticle)
	local base, half, kind = anchorOf(self._target)
	if not base then
		return false
	end
	self._half, self._kind = half, kind
	local h = half * self._k
	local a = 0.45 * h
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	local i = 0
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local sx, sz = corner[1], corner[2]
		local horizontal = self._arms[i * 2 + 1]
		local vertical = self._arms[i * 2 + 2]
		horizontal.Size = Vector3.new(a, THICK, ARM_WIDTH)
		vertical.Size = Vector3.new(ARM_WIDTH, THICK, a)
		table.insert(parts, horizontal)
		table.insert(frames, base * CFrame.new(sx * (h - a / 2), 0, sz * h))
		table.insert(parts, vertical)
		table.insert(frames, base * CFrame.new(sx * h, 0, sz * (h - a / 2)))
		i += 1
	end
	Workspace:BulkMoveTo(parts, frames)
	self._cueAnchor.CFrame = base * CFrame.new(0, 2.4, 0)
	self._moves += 1
	return true
end

function LandingReticle._apply(self: LandingReticle)
	local target = self._target
	local wanted = self._visible and self._state ~= "Hidden" and target ~= nil and target:IsDescendantOf(game)
	if not wanted then
		self:_stopStep()
		self._folder.Parent = nil
		self._rim.Enabled = false
		self._board.Enabled = false
		self._cueUntil = 0
		return
	end
	local best = self._state == "Best"
	for _, p in self._arms do
		p.Color = if best then GOLD else C.HopLight
		p.Transparency = if best then 0 else 0.1
	end
	self._rim.Adornee = target
	self._rim.OutlineTransparency = if best then 0.1 else 0.45
	self._rim.Enabled = true
	self._kGoal = if best then TIGHT else 1
	if Motion.reduced() then
		self._k = self._kGoal
	end
	self._folder.Parent = self._ctx.world
	if not self:_place() then
		self._folder.Parent = nil
		self._rim.Enabled = false
		return
	end
	if not self._step then
		self._step = RunService.Heartbeat:Connect(function(dt: number)
			local t = self._target
			if not t or not t:IsDescendantOf(game) then
				-- a despawned target: drop it at once (a new setTarget restarts)
				self._target = nil
				self:_apply()
				return
			end
			if self._k ~= self._kGoal then
				if Motion.reduced() then
					self._k = self._kGoal
				else
					self._k += (self._kGoal - self._k) * (1 - math.exp(-FOLLOW * dt))
					if math.abs(self._k - self._kGoal) < 0.002 then
						self._k = self._kGoal
					end
				end
			end
			self:_place()
			if self._board.Enabled and os.clock() >= self._cueUntil then
				self._board.Enabled = false
			end
		end)
	end
end

function LandingReticle.setTarget(self: LandingReticle, target: Instance?)
	if target and not (target:IsA("Model") or target:IsA("BasePart")) then
		target = nil
	end
	if target ~= self._target then
		self._retargets += 1
		self._board.Enabled = false
		self._cueUntil = 0
	end
	self._target = target
	self:_apply()
end

function LandingReticle.setState(self: LandingReticle, state: ReticleState)
	if state ~= "Hidden" and state ~= "Ready" and state ~= "Best" then
		return
	end
	self._state = state
	self:_apply()
end

-- One brief "HOP" word above the roof (only while the reticle is showing).
function LandingReticle.flashCue(self: LandingReticle)
	if self._folder.Parent == nil then
		return
	end
	self._cues += 1
	self._cueUntil = os.clock() + CUE_SECONDS
	self._board.Enabled = true
end

function LandingReticle.layout(_self: LandingReticle) end

function LandingReticle.setVisible(self: LandingReticle, on: boolean)
	self._visible = on
	self:_apply()
end

function LandingReticle.getDebugState(self: LandingReticle): { [string]: any }
	local visibleArms = 0
	for _, p in self._arms do
		if p.Transparency < 1 and self._folder.Parent ~= nil then
			visibleArms += 1
		end
	end
	return {
		state = self._state,
		shown = self._folder.Parent ~= nil,
		target = self._target and self._target:GetFullName(),
		anchorKind = self._kind,
		half = self._half,
		tighten = self._k,
		arms = #self._arms,
		visibleArms = visibleArms,
		rim = self._rim.Enabled,
		cue = self._board.Enabled,
		cues = self._cues,
		stepping = self._step ~= nil,
		moves = self._moves,
		retargets = self._retargets,
		reducedMotion = Motion.reduced(),
	}
end

function LandingReticle.destroy(self: LandingReticle)
	self._trove:Destroy()
end

return LandingReticle
