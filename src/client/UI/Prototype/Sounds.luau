--!strict
-- Typed UI sound hooks for the HUD prototype (Lane 3 preview). Components call
-- Sounds.play("CashGain") and never create sounds themselves.
--
-- No sound asset is inserted overnight (nobody can listen to check it, and no partner licence
-- text was verified), so every hook is silent by default: it is counted (for tests) and plays
-- only if an id is configured with Sounds.configure. Everything goes through one preview-only
-- SoundGroup "Lane3PreviewUI" whose volume the preview Settings panel controls.

local SoundService = game:GetService("SoundService")

local Sounds = {}

export type Hook =
	"Tap"
	| "Open"
	| "Close"
	| "CashGain"
	| "CashBig"
	| "CashSpend"
	| "Toast"
	| "TutorialDone"
	| "Unlock"
	| "LapPay"
	| "KeysTick"
	| "KeysCapture"
	| "Hop"
	| "Dash"
	| "Milestone"
	| "ResultsCount"
	| "NewBest"

local ids: { [string]: string } = {}
local counts: { [string]: number } = {}
local group: SoundGroup? = nil
local music: SoundGroup? = nil

local function ensureGroup(): SoundGroup
	if group and group.Parent then
		return group
	end
	local g = SoundService:FindFirstChild("Lane3PreviewUI") :: SoundGroup?
	if not g then
		local created = Instance.new("SoundGroup")
		created.Name = "Lane3PreviewUI"
		created.Volume = 0.6
		created.Parent = SoundService
		g = created
	end
	group = g
	return g :: SoundGroup
end

function Sounds.musicGroup(): SoundGroup
	if music and music.Parent then
		return music
	end
	local g = SoundService:FindFirstChild("Lane3PreviewMusic") :: SoundGroup?
	if not g then
		local created = Instance.new("SoundGroup")
		created.Name = "Lane3PreviewMusic"
		created.Volume = 0.5
		created.Parent = SoundService
		g = created
	end
	music = g
	return g :: SoundGroup
end

function Sounds.group(): SoundGroup
	return ensureGroup()
end

-- Assign a verified, permitted sound id to a hook (preview only; record its source).
function Sounds.configure(hook: Hook, id: string?)
	ids[hook] = id :: any
end

function Sounds.play(hook: Hook, volume: number?)
	counts[hook] = (counts[hook] or 0) + 1
	local id = ids[hook]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.SoundGroup = ensureGroup()
	s.Parent = ensureGroup()
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(5, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function Sounds.counts(): { [string]: number }
	return table.clone(counts)
end

function Sounds.resetCounts()
	table.clear(counts)
end

return Sounds
