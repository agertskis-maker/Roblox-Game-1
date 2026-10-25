--!strict
-- Run controls (outline section 06): Steer and Hop, nothing else.
--   Keyboard: A / D or Left / Right to steer, Space to Hop.
--   Touch: drag left or right on the lower two-thirds of the screen to steer (relative drag),
--          a short tap with no drag to Hop.
--   Gamepad (mapped, not a launch target): left stick X steers, A hops.
-- Steering is free left/right movement, the direction Adam asked for on the board.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local HOP_ACTION = "Lane1RunHop"
local TAP_MAX_MOVE = 14
local TAP_MAX_TIME = 0.3
local STICK_DEADZONE = 0.2

export type RunInput = {
	Hop: any, -- Signal fired once per Hop press
	-- Keyboard or gamepad steer, -1 (left) to 1 (right).
	getSteer: (self: RunInput) -> number,
	-- Touch drag since the last call, as a fraction of the screen width (left negative).
	takeDrag: (self: RunInput) -> number,
	-- Test override for playtests driven from the Studio MCP; nil returns control to the player.
	setOverride: (self: RunInput, steer: number?) -> (),
	destroy: (self: RunInput) -> (),
	_trove: any,
	_keys: { [Enum.KeyCode]: boolean },
	_stick: number,
	_drag: number,
	_override: number?,
}

local RunInput = {}
RunInput.__index = RunInput

local LEFT = { [Enum.KeyCode.A] = true, [Enum.KeyCode.Left] = true }
local RIGHT = { [Enum.KeyCode.D] = true, [Enum.KeyCode.Right] = true }

function RunInput.new(): RunInput
	local trove = Trove.new()
	local self = setmetatable({
		Hop = trove:Add(Signal.new()),
		_trove = trove,
		_keys = {},
		_stick = 0,
		_drag = 0,
		_override = nil,
	}, RunInput)
	local typed = (self :: any) :: RunInput

	ContextActionService:BindActionAtPriority(HOP_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			typed.Hop:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	trove:Add(function()
		ContextActionService:UnbindAction(HOP_ACTION)
	end)

	trove:Connect(UserInputService.InputBegan, function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if LEFT[input.KeyCode] or RIGHT[input.KeyCode] then
			typed._keys[input.KeyCode] = true
		end
	end)
	trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		typed._keys[input.KeyCode] = nil
	end)
	trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local x = input.Position.X
			typed._stick = if math.abs(x) < STICK_DEADZONE then 0 else x
		end
	end)

	-- Touch: one steering finger at a time; a short still touch is a tap (Hop).
	local touchStart: { [InputObject]: { pos: Vector2, time: number, last: Vector2, moved: number } } = {}
	trove:Connect(UserInputService.TouchStarted, function(touch: InputObject, processed: boolean)
		if processed then
			return
		end
		local camera = Workspace.CurrentCamera
		local pos = Vector2.new(touch.Position.X, touch.Position.Y)
		if camera and pos.Y < camera.ViewportSize.Y / 3 then
			return
		end
		touchStart[touch] = { pos = pos, time = os.clock(), last = pos, moved = 0 }
	end)
	trove:Connect(UserInputService.TouchMoved, function(touch: InputObject)
		local info = touchStart[touch]
		local camera = Workspace.CurrentCamera
		if not info or not camera then
			return
		end
		local pos = Vector2.new(touch.Position.X, touch.Position.Y)
		local dx = pos.X - info.last.X
		info.moved += (pos - info.last).Magnitude
		info.last = pos
		typed._drag += dx / math.max(camera.ViewportSize.X, 1)
	end)
	trove:Connect(UserInputService.TouchEnded, function(touch: InputObject)
		local info = touchStart[touch]
		touchStart[touch] = nil
		if info and info.moved <= TAP_MAX_MOVE and os.clock() - info.time <= TAP_MAX_TIME then
			typed.Hop:Fire()
		end
	end)

	return typed
end

function RunInput.getSteer(self: RunInput): number
	if self._override then
		return self._override
	end
	local steer = 0
	for key in self._keys do
		if LEFT[key] then
			steer -= 1
		elseif RIGHT[key] then
			steer += 1
		end
	end
	if steer == 0 then
		steer = self._stick
	end
	return math.clamp(steer, -1, 1)
end

function RunInput.takeDrag(self: RunInput): number
	local drag = self._drag
	self._drag = 0
	return drag
end

function RunInput.setOverride(self: RunInput, steer: number?)
	self._override = if steer then math.clamp(steer, -1, 1) else nil
end

function RunInput.destroy(self: RunInput)
	self._trove:Destroy()
end

return RunInput
