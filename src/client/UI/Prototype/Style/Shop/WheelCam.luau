--!strict
-- WheelCam (Lane 3 Round 8, W-04): on the Wheels tab, tapping a rim fits it on the turntable car and the camera eases in to a
-- close shot of the front wheel for two seconds, then eases back out. This file only moves the camera and finds the wheel; the
-- screen decides when to start it.
--
--   local cam = WheelCam.new(camera: Camera)
--   cam:start(base: CFrame, fov: number, wheel: Vector3, side: Vector3, front: Vector3)   -- the resting shot and the wheel
--   cam:step(dt) -> boolean        moves the camera; true while the wheel shot owns it
--   cam:active() -> boolean        cam:cancel()
--   WheelCam.frontWheel(model: Model, left: Vector3) -> Vector3?    the car's front wheel on the side facing `left`

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WheelCam = {}
WheelCam.__index = WheelCam

local EASE_IN = 0.45
local HOLD = 1.1
-- STUDIO TEST HOOK: in Studio only, the LocalPlayer attribute Lane3WheelCamHold (seconds) holds the close shot longer, so a
-- slow screenshot can catch it. Players never have it.
local HOLD_ATTRIBUTE = "Lane3WheelCamHold"
local EASE_OUT = 0.45
WheelCam.SECONDS = EASE_IN + HOLD + EASE_OUT -- 2.0

local function holdSeconds(): number
	if RunService:IsStudio() then
		local player = Players.LocalPlayer
		local extra = player and player:GetAttribute(HOLD_ATTRIBUTE)
		if type(extra) == "number" then
			return math.clamp(extra, 0, 60)
		end
	end
	return HOLD
end

local DISTANCE = 6.2 -- from the wheel to the lens
local CLOSE_FOV = 26

local function smooth(u: number): number
	local x = math.clamp(u, 0, 1)
	return x * x * (3 - 2 * x)
end

function WheelCam.new(camera: Camera): any
	return setmetatable({ _camera = camera, _t = nil }, WheelCam)
end

-- `side` points out of the car's side that faces the screen, `front` out of its nose: the lens sits a little in front of the
-- wheel's side so the rim shows nearly face on, with the arch and the headlight round it.
function WheelCam.start(self: any, base: CFrame, fov: number, wheel: Vector3, side: Vector3, front: Vector3)
	local direction = (side * 0.82 + front * 0.42 + Vector3.yAxis * 0.1).Unit
	local eye = wheel + direction * DISTANCE
	self._base = base
	self._baseFov = fov
	self._shot = CFrame.lookAt(eye, wheel + Vector3.new(0, 0.1, 0))
	self._t = 0
	self._hold = holdSeconds()
	self._total = EASE_IN + self._hold + EASE_OUT
end

function WheelCam.active(self: any): boolean
	return self._t ~= nil
end

function WheelCam.cancel(self: any)
	if self._t ~= nil then
		self._t = nil
		self._camera.CFrame = self._base
		self._camera.FieldOfView = self._baseFov
	end
end

function WheelCam.step(self: any, dt: number): boolean
	local t = self._t
	if t == nil then
		return false
	end
	t += dt
	if t >= self._total then
		self._t = nil
		self._camera.CFrame = self._base
		self._camera.FieldOfView = self._baseFov
		return false
	end
	self._t = t
	local amount = if t < EASE_IN
		then smooth(t / EASE_IN)
		elseif t < EASE_IN + self._hold then 1
		else 1 - smooth((t - EASE_IN - self._hold) / EASE_OUT)
	self._camera.CFrame = self._base:Lerp(self._shot, amount)
	self._camera.FieldOfView = self._baseFov + (CLOSE_FOV - self._baseFov) * amount
	return true
end

-- The wheel parts keep Brian L's names ("front"/"rear" and "wheel" in them, as RealCar reads them). Of the front wheels, the
-- one on the side that faces the screen.
function WheelCam.frontWheel(model: Model, left: Vector3): Vector3?
	local best: Vector3? = nil
	local score = -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "wheel", 1, true) and string.find(d.Name, "front", 1, true) then
			local s = (d.Position - model:GetPivot().Position):Dot(left)
			if s > score then
				best, score = d.Position, s
			end
		end
	end
	return best
end

return WheelCam
