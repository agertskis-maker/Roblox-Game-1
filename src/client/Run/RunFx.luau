--!strict
-- Small, clean run effects (outline: "effects are small and clean, never screen-filling"):
-- landing dust, bump sparks, Heat steam, a claim burst, a Hop trail and speed lines. Uses only
-- textures and sounds that ship inside Roblox Studio (rbxasset://), so nothing is uploaded.
-- Lane 3 owns the final effects and sounds; these are placeholders for feel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Trove = require(ReplicatedStorage.Packages.Trove)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local SOUNDS = {
	hop = "rbxasset://sounds/action_jump.mp3",
	land = "rbxasset://sounds/action_jump_land.mp3",
	bump = "rbxasset://sounds/collide.wav",
	claim = "rbxasset://sounds/electronicpingshort.wav",
	alert = "rbxasset://sounds/electronicpingshort.wav",
}

export type RunFx = {
	folder: Folder,
	dust: (self: RunFx, at: CFrame, size: number) -> (),
	sparks: (self: RunFx, at: CFrame) -> (),
	burst: (self: RunFx, at: CFrame, colour: Color3) -> (),
	sound: (self: RunFx, name: string, volume: number?, pitch: number?) -> (),
	setSteam: (self: RunFx, model: Model?, heat: number) -> (),
	setSpeedLines: (self: RunFx, camera: CFrame, amount: number) -> (),
	setTrail: (self: RunFx, root: BasePart?, on: boolean) -> (),
	destroy: (self: RunFx) -> (),
	_trove: any,
	_anchor: Part,
	_speed: ParticleEmitter,
	_steam: ParticleEmitter?,
	_steamModel: Model?,
	_trail: Trail?,
}

local RunFx = {}
RunFx.__index = RunFx

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightEmission = 0.3
	e.LockedToPart = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

function RunFx.new(parent: Instance): RunFx
	local trove = Trove.new()
	local folder = trove:Add(Instance.new("Folder"))
	folder.Name = "Fx"
	folder.Parent = parent

	local anchor = Instance.new("Part")
	anchor.Name = "FxAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(30, 18, 1)
	anchor.Parent = folder

	-- Speed lines: thin white streaks in a sheet just ahead of the camera.
	local speed = emitter(anchor, {
		Name = "SpeedLines",
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(0.12),
		Lifetime = NumberRange.new(0.25, 0.4),
		Speed = NumberRange.new(90, 120),
		EmissionDirection = Enum.NormalId.Back,
		Squash = NumberSequence.new(-3),
		Rate = 0,
		LightEmission = 1,
	})
	speed.Enabled = true

	local self = setmetatable({
		folder = folder,
		_trove = trove,
		_anchor = anchor,
		_speed = speed,
		_steam = nil,
		_steamModel = nil,
		_trail = nil,
	}, RunFx)
	return (self :: any) :: RunFx
end

local function oneShot(self: RunFx, at: CFrame, props: { [string]: any }, count: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = at
	p.Parent = self.folder
	local e = emitter(p, props)
	e:Emit(count)
	task.delay(2, function()
		p:Destroy()
	end)
end

function RunFx.dust(self: RunFx, at: CFrame, size: number)
	oneShot(self, at, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(226, 214, 196)),
		Transparency = NumberSequence.new(0.4, 1),
		Size = NumberSequence.new(size * 0.4, size * 0.9),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 20),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 0,
	}, 14)
end

function RunFx.sparks(self: RunFx, at: CFrame)
	oneShot(self, at, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 210, 90)),
		Size = NumberSequence.new(0.35, 0),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(18, 30),
		SpreadAngle = Vector2.new(70, 70),
		LightEmission = 1,
		Acceleration = Vector3.new(0, -60, 0),
	}, 18)
end

function RunFx.burst(self: RunFx, at: CFrame, colour: Color3)
	oneShot(self, at, {
		Texture = SPARKLE,
		Color = ColorSequence.new(colour),
		Size = NumberSequence.new(1.2, 0),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(16, 28),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Drag = 3,
	}, 40)
end

function RunFx.sound(self: RunFx, name: string, volume: number?, pitch: number?)
	local id = (SOUNDS :: any)[name]
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end

-- Steam from the ridden car's hood, growing from the Warning stage.
function RunFx.setSteam(self: RunFx, model: Model?, heat: number)
	if model ~= self._steamModel then
		if self._steam then
			self._steam:Destroy()
			self._steam = nil
		end
		self._steamModel = model
		local body = model
			and (model:FindFirstChild("Body") or model:FindFirstChild("Cab") or model:FindFirstChild("Tank"))
		if body and body:IsA("BasePart") then
			local att = Instance.new("Attachment")
			att.Position = Vector3.new(0, body.Size.Y / 2, -body.Size.Z * 0.35)
			att.Parent = body
			self._steam = emitter(att, {
				Name = "Steam",
				Texture = SMOKE,
				Color = ColorSequence.new(Color3.fromRGB(240, 240, 240)),
				Transparency = NumberSequence.new(0.35, 1),
				Size = NumberSequence.new(1, 3.5),
				Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(6, 10),
				SpreadAngle = Vector2.new(25, 25),
				EmissionDirection = Enum.NormalId.Top,
				LightEmission = 0,
			})
		end
	end
	local steam = self._steam
	if steam then
		local a = math.clamp((heat - 0.6) / 0.4, 0, 1)
		steam.Enabled = a > 0
		steam.Rate = 6 + a * 30
		steam.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240):Lerp(Color3.fromRGB(90, 90, 96), a * 0.7))
	end
end

function RunFx.setSpeedLines(self: RunFx, camera: CFrame, amount: number)
	self._anchor.CFrame = camera * CFrame.new(0, 0, -14)
	self._speed.Rate = 60 * math.clamp(amount, 0, 1)
end

-- A short glowing streak behind the rider during a Hop.
function RunFx.setTrail(self: RunFx, root: BasePart?, on: boolean)
	if root and not self._trail then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 1, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -1, 0)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.35
		trail.LightEmission = 1
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110))
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.Parent = root
		self._trail = trail
		self._trove:Add(a0)
		self._trove:Add(a1)
		self._trove:Add(trail)
	end
	if self._trail then
		self._trail.Enabled = on
	end
end

function RunFx.destroy(self: RunFx)
	if self._steam then
		self._steam:Destroy()
	end
	self._trove:Destroy()
end

return RunFx
