--!strict
-- Plot flag line motion (Lane 3, client presentation only). Each plot's sign band has cloth flags
-- and pennant bunting drawn as beams (Hub/Recipes/Plot), and each plot gate two accent flags
-- (Task 4; a smaller bend, from the beam's optional "FlagAmplitude" attribute). Near the camera the flags wave (the
-- beam bends sideways in a travelling S, with a gentle flutter) and the bunting sways a little in
-- its sag; farther away they hold still. Reduced motion (GuiService.ReducedMotionEnabled, or the
-- preview-only LocalPlayer attribute "Lane3ReducedMotionOverride") holds every flag in a soft
-- still curve. Moves are local to this client; the Trove restores the built shapes.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local ROOT_NAME = "Lane3_IslandPreview"
local OVERRIDE = "Lane3ReducedMotionOverride"
local RANGE = 320 -- studs from the camera (Tunable)
local RESCAN = 3
local AMPLITUDE = 0.9 -- sideways bend of a flag, studs (Tunable)

local player = Players.LocalPlayer

local function reducedMotion(): boolean
	local override = player:GetAttribute(OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

type Item = {
	beam: Beam,
	kind: string,
	phase: number,
	amplitude: number,
	base0: number,
	base1: number,
	at: Vector3,
}

local function run(trove: Trove.Trove, root: Instance)
	local items: { Item } = {}
	local known: { [Beam]: boolean } = {}
	local lastScan = -math.huge
	local function scan()
		for _, d in root:GetDescendants() do
			if d:IsA("Beam") and not known[d] then
				local wave = d:GetAttribute("FlagWave")
				local sag = d:GetAttribute("BuntingSag")
				local amplitude = d:GetAttribute("FlagAmplitude")
				if (type(wave) == "number" or type(sag) == "number") and d.Attachment0 then
					known[d] = true
					table.insert(items, {
						beam = d,
						kind = if type(wave) == "number" then "flag" else "bunting",
						phase = if type(wave) == "number"
							then wave
							else (d.Attachment0 :: Attachment).WorldPosition.X * 0.13,
						amplitude = if type(amplitude) == "number" then amplitude else AMPLITUDE,
						base0 = d.CurveSize0,
						base1 = d.CurveSize1,
						at = (d.Attachment0 :: Attachment).WorldPosition,
					})
				end
			end
		end
	end
	trove:Connect(RunService.RenderStepped, function()
		local now = os.clock()
		if now - lastScan > RESCAN then
			lastScan = now
			scan()
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local calm = reducedMotion()
		for _, it in items do
			local b = it.beam
			local near = (it.at - eye).Magnitude < RANGE
			if it.kind == "flag" then
				if calm or not near then
					b.CurveSize0, b.CurveSize1 = 0.35, 0.35
				else
					local t = now * 2.3 + it.phase
					local amp = it.amplitude
					b.CurveSize0 = amp * math.sin(t) + amp / 6 * math.sin(t * 3.1)
					b.CurveSize1 = amp * 1.3 * math.sin(t - 1.7) + amp / 4.5 * math.sin(t * 2.7)
				end
			elseif near and not calm then
				local sway = 0.25 * math.sin(now * 0.9 + it.phase)
				b.CurveSize0 = it.base0 + sway
				b.CurveSize1 = it.base1 - sway
			else
				b.CurveSize0, b.CurveSize1 = it.base0, it.base1
			end
		end
	end)
	trove:Add(function()
		for _, it in items do
			if it.beam.Parent then
				it.beam.CurveSize0, it.beam.CurveSize1 = it.base0, it.base1
			end
		end
	end)
end

local current: Trove.Trove? = nil
local function attach(root: Instance)
	if current then
		current:Destroy()
	end
	local trove = Trove.new()
	current = trove
	run(trove, root)
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
