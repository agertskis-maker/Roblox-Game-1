--!strict
-- The player's two volume categories (Lane 3 preview, Settings sound rows 2026-10-29; spec vault/design/ui/settings-sound.md).
--
-- Two SoundGroups in SoundService, made by this client, so they are this player's own: "Music" and "Effects". Their Volume is
-- the player's effective level (0..1, from the Settings sliders and mute buttons through Home/MusicSetting). Every mix group
-- is NESTED under one of them and keeps its own approved level (SoundGroup Volume is a multiplier and nested groups multiply,
-- Creator Docs "Sound groups", checked 2026-10-29), so at 100 the game sounds exactly as the approved mix:
--   Music   -> Lane3PreviewMusic (Sounds.musicGroup, 0.5) -> the duck / base / tension groups (Music.luau)
--   Effects -> Lane3PreviewUI (Sounds.group, 0.6): every Sounds hook and the Settings preview tick
-- A Sound joins through its own Sound.SoundGroup (membership, not parenting), so its Volume, position and rolloff are untouched.
-- Code outside the HUD (World ambience, the island) joins a category by parenting ITS mix group to AudioMix.group(name).
--
--   AudioMix.group(name) -> SoundGroup                  -- "Music" | "Effects": finds the existing group first, never duplicates
--   AudioMix.setLevel(name, level01, seconds?)          -- the player's level; a short linear ramp (no clicks), 0 = at once
--   AudioMix.level(name) -> number                      -- the level last asked for (the group may still be ramping to it)
--   AudioMix.reset()                                    -- cancel ramps (unmount, tests); the groups stay
--   AudioMix.getDebugState() -> table                   -- both groups, their Volumes and nested children

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioMix = {}

export type Category = "Music" | "Effects"

AudioMix.RAMP = 0.05 -- a slider change: fast enough to feel instant, long enough to avoid a click

type Slot = { tween: Tween?, target: number }

local groups: { [string]: SoundGroup } = {}
local slots: { [string]: Slot } = {
	Music = { tween = nil, target = 1 },
	Effects = { tween = nil, target = 1 },
}

function AudioMix.group(name: Category): SoundGroup
	local g = groups[name]
	if g and g.Parent then
		return g
	end
	local found = SoundService:FindFirstChild(name)
	if found and found:IsA("SoundGroup") then
		g = found
	else
		local made = Instance.new("SoundGroup")
		made.Name = name
		made.Volume = slots[name].target
		made.Parent = SoundService
		g = made
	end
	groups[name] = g :: SoundGroup
	return g :: SoundGroup
end

local function cancel(slot: Slot)
	local tween = slot.tween
	if tween then
		slot.tween = nil
		tween:Cancel()
	end
end

function AudioMix.setLevel(name: Category, level01: number, seconds: number?)
	local slot = slots[name]
	local target = math.clamp(if level01 ~= level01 then 0 else level01, 0, 1)
	local g = AudioMix.group(name)
	local time = seconds or AudioMix.RAMP
	if slot.tween and slot.target == target then
		return -- already heading there: a repeated apply never restarts or cuts a ramp
	end
	cancel(slot)
	slot.target = target
	if time <= 0 or math.abs(g.Volume - target) < 0.001 then
		g.Volume = target
		return
	end
	local style = if time <= 0.1 then Enum.EasingStyle.Linear else Enum.EasingStyle.Sine
	local tween = TweenService:Create(g, TweenInfo.new(time, style, Enum.EasingDirection.InOut), { Volume = target })
	slot.tween = tween
	tween.Completed:Once(function()
		if slot.tween == tween then
			slot.tween = nil
		end
	end)
	tween:Play()
end

function AudioMix.level(name: Category): number
	return slots[name].target
end

function AudioMix.reset()
	for _, slot in slots do
		cancel(slot)
	end
end

function AudioMix.getDebugState(): { [string]: any }
	local out: { [string]: any } = {}
	for _, name in { "Music", "Effects" } do
		local g = AudioMix.group(name :: Category)
		local children = {}
		for _, child in g:GetDescendants() do
			if child:IsA("SoundGroup") then
				table.insert(children, string.format("%s=%.2f", child.Name, child.Volume))
			end
		end
		out[name] = {
			volume = g.Volume,
			target = slots[name].target,
			ramping = slots[name].tween ~= nil,
			parent = if g.Parent then g.Parent.Name else nil,
			children = children,
		}
	end
	return out
end

return AudioMix
