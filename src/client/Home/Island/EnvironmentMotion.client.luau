--!strict
-- Island environment motion (Lane 3, client presentation only). Moves the waterfall streaks
-- down the falling sheet and runs its foam and mist, time-based and only while the camera is
-- within range. Reduced motion follows GuiService.ReducedMotionEnabled (the player's Roblox
-- setting); the development preview may set the LocalPlayer attribute
-- "Lane3ReducedMotionOverride" (never saved), which wins while it is set.
-- Does nothing unless Workspace.Lane3_IslandEnvironment exists. The place streams in to a
-- joining client over several seconds, so it waits for the falls without a time limit and
-- picks up streaks and emitters as they arrive (a 10 s limit missed them in a playtest).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local ROOT_NAME = "Lane3_IslandEnvironment"
local ACTIVE_RANGE = 1400 -- studs from the camera to the falls
local OVERRIDE = "Lane3ReducedMotionOverride"

local player = Players.LocalPlayer

local function reducedMotion(): boolean
	local override = player:GetAttribute(OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

local function animate(trove: Trove.Trove, waterfall: Instance)
	local streakFolder = waterfall:WaitForChild("Streaks")
	while typeof(waterfall:GetAttribute("SheetCFrame")) ~= "CFrame" do
		waterfall:GetAttributeChangedSignal("SheetCFrame"):Wait()
	end
	local sheet = waterfall:GetAttribute("SheetCFrame") :: CFrame
	local centre = sheet.Position
	local active: boolean? = nil

	local function setActive(on: boolean)
		active = on
		for _, d in waterfall:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.Enabled = on
			end
		end
		for _, s in streakFolder:GetChildren() do
			if s:IsA("BasePart") then
				s.LocalTransparencyModifier = if on then 0 else 1
			end
		end
	end
	-- parts that replicate later join in the current state
	trove:Connect(waterfall.DescendantAdded, function()
		if active ~= nil then
			setActive(active)
		end
	end)

	trove:Connect(RunService.RenderStepped, function()
		local camera = Workspace.CurrentCamera
		local near = camera ~= nil and (camera.CFrame.Position - centre).Magnitude < ACTIVE_RANGE
		local want = near and not reducedMotion()
		if want ~= active then
			setActive(want)
		end
		if not active then
			return
		end
		local t = os.clock()
		for _, s in streakFolder:GetChildren() do
			if s:IsA("BasePart") then
				local length = s:GetAttribute("Length") :: number
				local speed = s:GetAttribute("Speed") :: number
				local phase = s:GetAttribute("Phase") :: number
				local offsetX = s:GetAttribute("OffsetX") :: number
				local f = (t * speed / length + phase) % 1
				s.CFrame = sheet * CFrame.new(offsetX, (0.5 - f) * length, -1.2)
			end
		end
	end)
	trove:Add(function()
		setActive(true) -- leave the static look as built
	end)
end

local current: Trove.Trove? = nil
local function attach(root: Instance)
	if current then
		current:Destroy()
	end
	local trove = Trove.new()
	current = trove
	trove:Add(task.spawn(function()
		animate(trove, root:WaitForChild("Waterfall"))
	end))
	trove:Connect(root.AncestryChanged, function()
		if not root:IsDescendantOf(Workspace) then
			trove:Destroy()
			if current == trove then
				current = nil
			end
		end
	end)
end

local existing = Workspace:FindFirstChild(ROOT_NAME)
if existing then
	attach(existing)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == ROOT_NAME then
		attach(child)
	end
end)
