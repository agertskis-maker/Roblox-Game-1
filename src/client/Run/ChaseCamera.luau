--!strict
-- Run chase camera (outline section 06): behind and above the rider, looking down the road,
-- smoothed so a Hop is followed in the air and never snaps. No roll. The field of view widens a
-- little with speed and punches out briefly on each Hop for a sense of speed; the only shake is
-- a short soft jolt on a bump or crash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)

export type ChaseCamera = {
	step: (
		self: ChaseCamera,
		dt: number,
		along: number,
		lateral: number,
		height: number,
		carLength: number,
		speed01: number
	) -> (),
	jolt: (self: ChaseCamera, strength: number) -> (),
	punch: (self: ChaseCamera) -> (),
	getCFrame: (self: ChaseCamera) -> CFrame,
	destroy: (self: ChaseCamera) -> (),
	_lateral: number?,
	_height: number,
	_back: number,
	_jolt: number,
	_punch: number,
	_fov: number,
	_time: number,
	_previousType: Enum.CameraType,
	_previousFov: number,
}

local ChaseCamera = {}
ChaseCamera.__index = ChaseCamera

local function camera(): Camera
	return Workspace.CurrentCamera :: Camera
end

function ChaseCamera.new(): ChaseCamera
	local cam = camera()
	local self = setmetatable({
		_lateral = nil,
		_height = 0,
		_back = RunConfig.CAMERA_BACK,
		_jolt = 0,
		_punch = 0,
		_fov = RunConfig.CAMERA_FOV,
		_time = 0,
		_previousType = cam.CameraType,
		_previousFov = cam.FieldOfView,
	}, ChaseCamera)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = RunConfig.CAMERA_FOV
	return (self :: any) :: ChaseCamera
end

function ChaseCamera.step(
	self: ChaseCamera,
	dt: number,
	along: number,
	lateral: number,
	height: number,
	carLength: number,
	speed01: number
)
	local follow = 1 - math.exp(-RunConfig.CAMERA_FOLLOW * dt)
	self._time += dt
	if self._lateral == nil then
		self._lateral = lateral
		self._height = height
	end
	-- Along the road the camera stays locked to the rider (speed is high); sideways, up and the
	-- distance behind (which grows with the car) all ease.
	self._lateral = (self._lateral :: number) + (lateral - (self._lateral :: number)) * follow
	self._height += (height - self._height) * follow * 0.6
	local wantBack = RunConfig.CAMERA_BACK + carLength * 0.5
	self._back += (wantBack - self._back) * follow * 0.5
	self._jolt = math.max(self._jolt - dt * 4, 0)
	self._punch = math.max(self._punch - dt * 2.2, 0)

	local wantFov = RunConfig.CAMERA_FOV
		+ (RunConfig.CAMERA_FOV_FAST - RunConfig.CAMERA_FOV) * math.clamp(speed01, 0, 1)
		+ RunConfig.CAMERA_HOP_PUNCH * self._punch
	self._fov += (wantFov - self._fov) * (1 - math.exp(-6 * dt))

	local t = self._time
	local shake = if self._jolt > 0
		then Vector3.new(math.sin(t * 61) * self._jolt, math.cos(t * 47) * self._jolt, 0)
		else Vector3.zero
	local base = RunConfig.ORIGIN
	local lat = self._lateral :: number
	local eye = (base * CFrame.new(lat, self._height + RunConfig.CAMERA_UP, -(along - self._back))).Position + shake
	local focus = (base * CFrame.new(lat, self._height + 2, -(along + RunConfig.CAMERA_LOOK_AHEAD))).Position
	local cam = camera()
	cam.CFrame = CFrame.lookAt(eye, focus, base.UpVector)
	cam.FieldOfView = self._fov
end

function ChaseCamera.jolt(self: ChaseCamera, strength: number)
	self._jolt = math.max(self._jolt, strength)
end

function ChaseCamera.punch(self: ChaseCamera)
	self._punch = 1
end

function ChaseCamera.getCFrame(_self: ChaseCamera): CFrame
	return camera().CFrame
end

function ChaseCamera.destroy(self: ChaseCamera)
	local cam = camera()
	cam.CameraType = self._previousType
	cam.FieldOfView = self._previousFov
end

return ChaseCamera
