--!strict
-- CAMERA HELPERS for reviewing the Stunt Circuit (Lane 3, M17-01 and M17-06a): an approach camera for each section, a
-- chase camera at any lap distance, and a timed flythrough of the whole lap at 0.8x, 1x or 1.2x of the nominal speed. They
-- only move the current camera; nothing is saved and nothing else is touched. The flythrough is a picture of the pacing model
-- (StuntData.NominalSpeed), not a driven lap.
--
--   StuntFly.approach(sectionId) -> CFrame                 the view a driver has as the section's warning sign comes up
--   StuntFly.chase(s) -> CFrame                            behind and above the road at lap distance s
--   StuntFly.go(sectionId)                                 puts the current camera on the section's approach view
--   StuntFly.run({ speed = 1, from = 0, to = 5250, onDone = fn? }) -> () -> ()    the flythrough; the result stops it
--   StuntFly.timeline(speedScale) -> { { s, seconds } }    when each section starts at that speed, for the clip captions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StuntData = require(script.Parent.StuntData)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local StuntFly = {}

local BEHIND = 24
local ABOVE = 9
local AHEAD = 60

-- A chase view: the camera sits `BEHIND` studs back along the road and `ABOVE` up, looking `AHEAD` studs down it.
function StuntFly.chase(s: number): CFrame
	local at = StuntData.frame(s - BEHIND, 0, ABOVE).Position
	local target = StuntData.frame(s + AHEAD, 0, 1).Position
	return CFrame.lookAt(at, target)
end

-- The approach view of a section: from 40 studs behind its warning sign (or its first stretch), looking at its obstacle.
function StuntFly.approach(sectionId: string): CFrame
	local section: StuntData.Section? = nil
	for _, sec in StuntData.Sections do
		if sec.id == sectionId then
			section = sec
		end
	end
	assert(section, "no section " .. sectionId)
	local sec = section :: StuntData.Section
	local from = sec.s0 + 20
	for _, w in StuntData.Warnings do
		if w.section == sec.id then
			from = w.s - 40
		end
	end
	local look = if sec.obstacle then (sec.obstacle.s0 + sec.obstacle.s1) / 2 else sec.s1 - 40
	local at = StuntData.frame(from, 0, 10).Position
	local target = StuntData.frame(look, 0, 2).Position
	return CFrame.lookAt(at, target)
end

local function camera(): Camera?
	return Workspace.CurrentCamera
end

function StuntFly.go(sectionId: string)
	local cam = camera()
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 70
		cam.CFrame = StuntFly.approach(sectionId)
	end
end

-- When each section starts, in seconds, at `speedScale` times the nominal speed.
function StuntFly.timeline(speedScale: number): { { s: number, seconds: number, id: string } }
	local out = {}
	for _, sec in StuntData.Sections do
		table.insert(out, {
			s = sec.s0,
			seconds = sec.s0 / (StuntData.NominalSpeed * speedScale),
			id = sec.id,
		})
	end
	return out
end

export type RunOptions = {
	speed: number?, -- 0.8, 1 or 1.2 of the nominal speed (default 1)
	from: number?,
	to: number?,
	onDone: (() -> ())?,
	onSection: ((id: string, seconds: number) -> ())?,
}

-- Flies the camera along the lap. Returns a function that stops it and gives the camera back.
function StuntFly.run(options: RunOptions?): () -> ()
	local opts: RunOptions = options or {}
	local cam = camera()
	if not cam then
		return function() end
	end
	local trove = Trove.new()
	local scale = opts.speed or 1
	local s = opts.from or 0
	local last = opts.to or StuntData.Length
	local seconds = 0
	local lastSection = ""
	local previousType = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 70
	trove:Add(function()
		cam.CameraType = previousType
	end)
	trove:Connect(RunService.Heartbeat, function(dt: number)
		s += dt * StuntData.NominalSpeed * scale
		seconds += dt
		if s >= last then
			s = last
			cam.CFrame = StuntFly.chase(s)
			if opts.onDone then
				opts.onDone()
			end
			trove:Destroy()
			return
		end
		cam.CFrame = StuntFly.chase(s)
		local id = StuntData.sectionOf(s).id
		if id ~= lastSection then
			lastSection = id
			if opts.onSection then
				opts.onSection(id, seconds)
			end
		end
	end)
	cam.CFrame = StuntFly.chase(s)
	return function()
		trove:Destroy()
	end
end

return StuntFly
