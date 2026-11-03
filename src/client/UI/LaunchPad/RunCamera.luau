--!strict
-- A higher run camera, and a live tuner for it (Lane 3, Round 3 N7; decision 6: no edits to Brian R's files). His ChaseCamera reads
-- frozen RunConfig values, so they cannot be changed from outside. Instead this binds one render step after his (Camera + 2) and
-- re-aims the camera he just placed: his smoothing, jolts and field-of-view punches all stay, because they are read from where he
-- put it. In his in-car view, nothing is touched.
--
--   local c = RunCamera.attach()   c:destroy()      -- for one run
--   RunCamera.Settings                               -- the live values; RunCamera.Presets; RunCamera.applyPreset(name)
--   RunCamera.toggleTuner(parent)                    -- the panel: F4 during a run in the beta
--
-- Lives in the beta only. When a good view is agreed, these numbers go to Brian R for his RunConfig (CAMERA_BACK, CAMERA_UP,
-- CAMERA_LOOK_AHEAD, CAMERA_FOV) and this module goes away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Prototype = script.Parent.Parent.Prototype
local CarKit = require(Prototype.CarKit)

local RunCamera = {}

local BIND = "Lane3RunCamera"

export type Settings = { back: number, up: number, look: number, focus: number, fov: number }

-- back: studs behind the car. up: studs above it. look: studs ahead the eye aims. focus: height of that aim. fov: added degrees.
RunCamera.Presets = {
	Classic = { back = 15, up = 8.5, look = 34, focus = 2, fov = 0 },
	Higher = { back = 18, up = 14, look = 30, focus = 0, fov = 0 },
	["Top-ish"] = { back = 13, up = 20, look = 24, focus = 0, fov = -4 },
} :: { [string]: Settings }
RunCamera.PresetOrder = { "Classic", "Higher", "Top-ish" }
RunCamera.Recommended = "Higher"

RunCamera.Settings = table.clone(RunCamera.Presets[RunCamera.Recommended])

function RunCamera.applyPreset(name: string)
	local p = RunCamera.Presets[name]
	if p then
		for k, v in p do
			(RunCamera.Settings :: any)[k] = v
		end
	end
end

local function runConfig(): any?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local run = shared and shared:FindFirstChild("Run")
	local module = run and run:FindFirstChild("RunConfig")
	return if module then (require :: any)(module) else nil
end

function RunCamera.attach(): { destroy: (self: any) -> () }
	local config = runConfig()
	if not config then
		return { destroy = function(_self: any) end }
	end
	local origin: CFrame = config.ORIGIN
	local up0: number = config.CAMERA_UP
	local back0: number = config.CAMERA_BACK
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 2, function()
		local cam = Workspace.CurrentCamera
		if not cam or cam.CameraType ~= Enum.CameraType.Scriptable then
			return
		end
		local s = RunCamera.Settings
		local p = origin:PointToObjectSpace(cam.CFrame.Position)
		-- his in-car eye sits under his chase height: leave it alone
		if p.Y < up0 * 0.8 then
			return
		end
		local height = p.Y - up0 -- the car's height under his camera, with his smoothing and any jolt in it
		local eye = origin * Vector3.new(p.X, height + s.up, p.Z + (s.back - back0))
		-- his eye is roughly back0 plus half a car behind the rider
		local focus = origin * Vector3.new(p.X, height + s.focus, p.Z - back0 - 6 - s.look)
		cam.CFrame = CFrame.lookAt(eye, focus, origin.UpVector)
		cam.FieldOfView += s.fov
	end)
	return {
		destroy = function(_self: any)
			RunService:UnbindFromRenderStep(BIND)
		end,
	}
end

local panel: ScreenGui? = nil

local function settingsText(): string
	local s = RunCamera.Settings
	return string.format(
		"CAMERA_BACK = %.1f, CAMERA_UP = %.1f, CAMERA_LOOK_AHEAD = %.1f, focus height %.1f, CAMERA_FOV %+d",
		s.back,
		s.up,
		s.look,
		s.focus,
		s.fov
	)
end

function RunCamera.toggleTuner()
	if panel then
		panel:Destroy()
		panel = nil
		return
	end
	local make = CarKit.make
	local gui = make("ScreenGui", {
		Name = "Lane3CameraTuner",
		ResetOnSpawn = false,
		DisplayOrder = 30,
	}, Players.LocalPlayer:WaitForChild("PlayerGui")) :: ScreenGui
	panel = gui
	local board = CarKit.board(gui, {
		size = UDim2.fromOffset(300, 354),
		position = UDim2.new(1, -12, 0, 60),
		anchor = Vector2.new(1, 0),
		radius = 12,
		name = "Tuner",
	})
	CarKit.title(board, "RUN CAMERA", 28, {
		position = UDim2.fromOffset(12, 4),
		size = UDim2.new(1, -24, 0, 32),
		z = 3,
		shadow = false,
		stroke = 2,
	})
	local rows: { { TextLabel | string } } = {}
	local copy: TextBox
	local function refresh()
		for _, row in rows do
			local label = row[1] :: TextLabel
			label.Text = string.format("%.1f", (RunCamera.Settings :: any)[row[2] :: string])
		end
		copy.Text = settingsText()
	end
	local spec = {
		{ "Distance behind", "back", 1 },
		{ "Height", "up", 1 },
		{ "Look ahead", "look", 2 },
		{ "Aim height", "focus", 0.5 },
		{ "Field of view", "fov", 1 },
	}
	for i, r in spec do
		local y = 38 + (i - 1) * 38
		CarKit.text(board, r[1] :: string, 15, {
			position = UDim2.fromOffset(12, y),
			size = UDim2.fromOffset(136, 34),
			z = 3,
		})
		local value = CarKit.text(board, "", 16, {
			position = UDim2.fromOffset(190, y),
			size = UDim2.fromOffset(52, 34),
			align = Enum.TextXAlignment.Center,
			z = 3,
		})
		table.insert(rows, { value, r[2] :: string })
		for side, sign in { -1, 1 } do
			CarKit.button(board, {
				text = if sign < 0 then "-" else "+",
				tone = "Navy",
				px = 22,
				size = UDim2.fromOffset(36, 34),
				position = UDim2.fromOffset(if side == 1 then 150 else 246, y),
				z = 3,
				name = "Step",
				onPress = function()
					local key = r[2] :: string
					local s = RunCamera.Settings :: any
					s[key] += sign * (r[3] :: number)
					refresh()
				end,
			})
		end
	end
	for i, name in RunCamera.PresetOrder do
		CarKit.button(board, {
			text = name,
			tone = "Blue",
			px = 18,
			size = UDim2.fromOffset(88, 36),
			position = UDim2.fromOffset(10 + (i - 1) * 94, 232),
			z = 3,
			name = "Preset",
			onPress = function()
				RunCamera.applyPreset(name)
				refresh()
			end,
		})
	end
	copy = make("TextBox", {
		Name = "Copy",
		ClearTextOnFocus = false,
		TextEditable = false,
		BackgroundColor3 = CarKit.Well,
		TextColor3 = CarKit.White,
		FontFace = CarKit.body(),
		TextSize = 13,
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 274),
		Size = UDim2.new(1, -20, 0, 70),
		ZIndex = 3,
	}, board) :: TextBox
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, copy)
	refresh()
end

-- F4 opens the tuner during a run. Returns a disconnect.
function RunCamera.bindKey(): () -> ()
	local conn = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.F4 then
			RunCamera.toggleTuner()
		end
	end)
	return function()
		conn:Disconnect()
		if panel then
			panel:Destroy()
			panel = nil
		end
	end
end

return RunCamera
