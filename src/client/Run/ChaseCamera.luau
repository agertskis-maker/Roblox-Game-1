--!strict
-- Run chase camera (outline section 06): about 12 studs behind and 6 above the ridden car,
-- looking a little down the road, smoothed so a Hop is followed in the air and never snaps.
-- No roll; fixed field of view; the only shake is a short soft jolt on a crash or bump.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)

export type ChaseCamera = {
	step: (self: ChaseCamera, dt: number, along: number, lateral: number, height: number, carLength: number) -> (),
	jolt: (self: ChaseCamera, strength: number) -> (),
	destroy: (self: ChaseCamera) -> (),
	_along: number?,
	_lateral: number,
	_height: number,
	_jolt: number,
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
		_along = nil,
		_lateral = 0,
		_height = 0,
		_jolt = 0,
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
	carLength: number
)
	local follow = 1 - math.exp(-RunConfig.CAMERA_FOLLOW * dt)
	if self._along == nil then
		self._along = along
		self._lateral = lateral
		self._height = height
	end
	-- Along the road the camera stays locked to the rider (speed is high); sideways and up it eases.
	self._along = along
	self._lateral += (lateral - self._lateral) * follow
	self._height += (height - self._height) * follow * 0.6
	self._jolt = math.max(self._jolt - dt * 4, 0)

	local back = RunConfig.CAMERA_BACK + carLength / 2
	local shake = if self._jolt > 0
		then Vector3.new(math.sin(os.clock() * 61) * self._jolt, math.cos(os.clock() * 47) * self._jolt, 0)
		else Vector3.zero
	local base = RunConfig.ORIGIN
	local eye = (base * CFrame.new(self._lateral, self._height + RunConfig.CAMERA_UP, -(along - back))).Position + shake
	local focus = (base * CFrame.new(self._lateral, self._height + 1, -(along + RunConfig.CAMERA_LOOK_AHEAD))).Position
	camera().CFrame = CFrame.lookAt(eye, focus, base.UpVector)
end

function ChaseCamera.jolt(self: ChaseCamera, strength: number)
	self._jolt = math.max(self._jolt, strength)
end

function ChaseCamera.destroy(self: ChaseCamera)
	local cam = camera()
	cam.CameraType = self._previousType
	cam.FieldOfView = self._previousFov
end

return ChaseCamera
