--!strict
-- Speedway ambience (Lane 3, client presentation only): quiet layers that grow with the level,
-- kept under the music and never tiring on your own plot.
--   levels 1 and 2  a soft breeze in the grass
--   level 3 on      a small crowd murmur, a little fuller at each level (capped)
--   Rare or rarer   a short cheer when such a car finishes (level 3 on), at most every 4 seconds
--   level 12        an announcer horn when a Legendary car finishes, at most every 12 seconds
-- Positional at each plot's track centre; only the two nearest plots play, so six top-level
-- plots never add up to a wall of sound. One SoundGroup ("Lane3Speedway"), nothing saved.
-- Creator Store sounds licensed for experiences (Roblox's partners), listed in
-- assets/island/kit/manifest.md; each needs Adam's listening check before it counts as final.

local SoundService = game:GetService("SoundService")

local Sound = {}

Sound.Ids = {
	-- Pro Sound Effects (free Creator Store, "Courtesy of Pro Sound Effects"); picked by name and
	-- length in Studio search, quiet volumes below
	Breeze = "rbxassetid://9113286782", -- Barstow Wind, Light, Blustery, Low Howl 1 (11.9 s loop)
	Murmur = "rbxassetid://9119996106", -- Theatre Crowd, Subdued Walla, Rises and Falls (36 s loop)
	Cheer = "rbxassetid://9120974378", -- Wrestling Crowd, Mezzanine Level, Crowd Surges (4.3 s)
	Horn = "rbxassetid://9120385769", -- Vehicle Horn, Short and Long Honks 4 (0.7 s)
}

local group: SoundGroup? = nil
type PlotSound = { emitter: BasePart, breeze: Sound?, murmur: Sound?, level: number, cheerAt: number, hornAt: number }
local plots: { [Model]: PlotSound } = {}

local function getGroup(): SoundGroup
	if group and group.Parent then
		return group
	end
	local g = Instance.new("SoundGroup")
	g.Name = "Lane3Speedway"
	g.Volume = 1
	g.Parent = SoundService
	group = g
	return g
end

local function make(parent: Instance, id: string, volume: number, looped: boolean): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 30
	s.RollOffMaxDistance = 200
	s.SoundGroup = getGroup()
	s.Parent = parent
	return s
end

-- Sets up or updates `plot`'s ambience for `level`; `centre` is the track centre (world).
function Sound.setLevel(plot: Model, level: number, centre: Vector3, fx: Instance)
	local ps = plots[plot]
	if not ps then
		local e = Instance.new("Part")
		e.Name = "SpeedwaySound"
		e.Anchored = true
		e.CanCollide = false
		e.CanQuery = false
		e.CanTouch = false
		e.Transparency = 1
		e.Size = Vector3.one
		e.CFrame = CFrame.new(centre + Vector3.yAxis * 6)
		e.Parent = fx
		ps = { emitter = e, breeze = nil, murmur = nil, level = 0, cheerAt = -100, hornAt = -100 }
		plots[plot] = ps
	end
	local p = ps :: PlotSound
	p.level = level
	if level <= 2 then
		if not p.breeze then
			p.breeze = make(p.emitter, Sound.Ids.Breeze, 0.12, true)
		end
		if p.murmur then
			p.murmur:Destroy()
			p.murmur = nil
		end
	else
		if p.breeze then
			p.breeze:Destroy()
			p.breeze = nil
		end
		if not p.murmur then
			p.murmur = make(p.emitter, Sound.Ids.Murmur, 0.05, true)
		end
		if p.murmur then
			p.murmur.Volume = math.min(0.2, 0.05 + 0.015 * (level - 3))
		end
	end
end

-- Plays the loops of the two plots nearest `eye` and pauses the rest.
function Sound.update(eye: Vector3)
	local order = {}
	for plot, ps in plots do
		table.insert(order, { plot = plot, d = (ps.emitter.Position - eye).Magnitude })
	end
	table.sort(order, function(a, b)
		return a.d < b.d
	end)
	for i, o in order do
		local ps = plots[o.plot]
		local on = i <= 2 and o.d < 260
		for _, s in { ps.breeze, ps.murmur } do
			if s then
				if on and not s.IsPlaying then
					s:Play()
				elseif not on and s.IsPlaying then
					s:Pause()
				end
			end
		end
	end
end

-- A finish crossing on `plot` (near plots only call this).
function Sound.onCrossed(plot: Model, rarity: string)
	local ps = plots[plot]
	if not ps then
		return
	end
	local now = os.clock()
	if ps.level >= 3 and rarity ~= "Common" and now - ps.cheerAt > 4 then
		ps.cheerAt = now
		local s = make(ps.emitter, Sound.Ids.Cheer, 0.22, false)
		if s then
			s.PlayOnRemove = false
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
		end
	end
	if ps.level >= 12 and rarity == "Legendary" and now - ps.hornAt > 12 then
		ps.hornAt = now
		local s = make(ps.emitter, Sound.Ids.Horn, 0.25, false)
		if s then
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
		end
	end
end

function Sound.forget(plot: Model)
	local ps = plots[plot]
	if ps then
		ps.emitter:Destroy()
		plots[plot] = nil
	end
end

return Sound
