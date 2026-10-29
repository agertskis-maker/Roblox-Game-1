--!strict
-- Speedway looks on this client (Lane 3, presentation only). For each island plot it assembles
-- the Speedway for the plot's level with the shared look module (Shared.Island.Speedway.Look),
-- switches far plots to their still silhouette, plays the level-up reveal, fills the kiosk's
-- next-level board, draws the next level's ghost outline, animates the figures and plays the
-- ambience. A plot's level comes from, in order:
--   the LocalPlayer attribute "Lane3SpeedwayPreviewLevel_PlotNN", then "Lane3SpeedwayPreviewLevel"
--     (Studio preview only, set by the preview panel or a playtest script),
--   the plot's "SpeedwayLevel" attribute (the proposed Lane 2 contract: the server sets it),
--   the plot's "SpeedwayPreviewLevel" (the island preview build), else level 1.
-- In Studio the preview Lineup cars (LappingPreview, a fixture) run on every plot, and their
-- finish crossings drive the flag official, the crowd, the Lap Pay cue and the cheers.
-- Nothing here pays, prices, saves or sends anything to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Speedway = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Island"):WaitForChild("Speedway")
local Ladder = require(Speedway:WaitForChild("Ladder"))
local Look = require(Speedway:WaitForChild("Look"))
local Path = require(Speedway:WaitForChild("Path"))

local Calm = require(script.Parent.Speedway.Calm)
local Kiosk = require(script.Parent.Speedway.Kiosk)
local LappingPreview = require(script.Parent.LappingPreview)
local Life = require(script.Parent.Speedway.Life)
local PreviewPanel = require(script.Parent.Speedway.PreviewPanel)
local Reveal = require(script.Parent.Speedway.Reveal)
local Sound = require(script.Parent.Speedway.Sound)

local ROOT_NAME = "Lane3_IslandPreview"
local NEAR = 230 -- full detail inside this distance from a plot's track centre (Tunable)
local FAR = 260 -- still silhouette beyond this; between the two a plot keeps its state
local TRACK_CENTRE_U = 441

local player = Players.LocalPlayer

-- preview owner names for the plots that are not "yours" (fictional, PREVIEW only)
local FIXTURE_OWNERS = { "Pip", "Juno", "Rex", "Mo", "Kit", "Lou" }

type PlotInfo = { plot: Model, index: number, bearing: number, centre: Vector3, near: boolean, level: number }

local function attach(root: Instance): Trove.Trove
	local trove = Trove.new()
	local fx = trove:Add(Instance.new("Folder"))
	fx.Name = "Lane3_SpeedwayFx"
	fx.Parent = Workspace
	Life.setFx(fx)
	local infos: { [Model]: PlotInfo } = {}
	local panelRefresh: (() -> ())? = nil

	local function resolve(info: PlotInfo): number
		local own = player:GetAttribute(string.format("Lane3SpeedwayPreviewLevel_Plot%02d", info.index))
		if type(own) == "number" then
			return Ladder.clamp(own)
		end
		local all = player:GetAttribute("Lane3SpeedwayPreviewLevel")
		if type(all) == "number" then
			return Ladder.clamp(all)
		end
		local real = info.plot:GetAttribute("SpeedwayLevel")
		if type(real) == "number" then
			return Ladder.clamp(real)
		end
		local preview = info.plot:GetAttribute("SpeedwayPreviewLevel")
		if type(preview) == "number" then
			return Ladder.clamp(preview)
		end
		return 1
	end

	local function homeIndex(): number
		local h = player:GetAttribute("Lane3SpeedwayPreviewHome")
		return if type(h) == "number" then h else 3
	end

	local function ownerOf(info: PlotInfo): string
		local name = info.plot:GetAttribute("OwnerDisplayName")
		if type(name) == "string" then
			return name -- Roblox display names are already text-filtered by Roblox
		end
		if info.index == homeIndex() then
			return player.DisplayName
		end
		return FIXTURE_OWNERS[(info.index - 1) % #FIXTURE_OWNERS + 1]
	end

	local function options(info: PlotInfo): Look.Options
		return { index = info.index, bearing = info.bearing, owner = ownerOf(info), keepRemoved = true }
	end

	local function ghost(info: PlotInfo)
		local want = player:GetAttribute("Lane3SpeedwayGhost") ~= false and info.index == homeIndex()
		if want and info.level < Ladder.MaxLevel then
			Look.ghost(info.plot, info.level + 1, options(info))
		else
			Look.clearGhost(info.plot)
		end
	end

	local function refresh(info: PlotInfo, first: boolean)
		local level = resolve(info)
		local state = Look.state(info.plot)
		if state and state.level == level and not first then
			ghost(info)
			return
		end
		Reveal.finish(info.plot)
		local old = info.level
		local change = Look.apply(info.plot, level, options(info))
		info.level = level
		if first or level < old or not info.near then
			-- first build, an inspection downgrade or a far plot: no show, just the result
			for _, f in change.removed do
				f:Destroy()
			end
		else
			local calm = Calm()
			Reveal.play(info.plot, change.added, change.removed, calm, fx)
			if info.index == homeIndex() then
				Reveal.banner(Ladder.banner(level), calm)
			end
		end
		Life.rescan(info.plot, level)
		Life.setActive(info.plot, info.near)
		Kiosk.fill(info.plot, level, options(info))
		Sound.setLevel(info.plot, level, info.centre, fx)
		ghost(info)
		if not first and level > old and info.near then
			-- the crowd welcomes the new look
			Life.onCrossed(info.plot, nil, "Rare", 0)
		end
		if panelRefresh then
			panelRefresh()
		end
	end

	local function add(plot: Instance)
		if not plot:IsA("Model") then
			return
		end
		local index = plot:GetAttribute("PlotIndex")
		local bearing = plot:GetAttribute("BearingDeg")
		if type(index) ~= "number" or type(bearing) ~= "number" then
			return
		end
		-- an edit-mode preview of the look (HubBuild.previewSpeedway) is replaced by this
		-- client's own assembly
		for _, child in plot:GetChildren() do
			if child.Name == "SpeedwayLook" or child.Name == "SpeedwayGhost" then
				child:Destroy()
			end
		end
		local frame = Path.plotFrame(bearing)
		local info: PlotInfo = {
			plot = plot,
			index = index,
			bearing = bearing,
			centre = frame * Vector3.new(0, 0, -TRACK_CENTRE_U),
			near = true,
			level = 0,
		}
		infos[plot] = info
		refresh(info, true)
		trove:Connect(plot.AttributeChanged, function(name)
			if name == "SpeedwayLevel" or name == "SpeedwayPreviewLevel" or name == "OwnerDisplayName" then
				refresh(info, false)
			end
		end)
	end

	local island = root:WaitForChild("Island", 30)
	local plotsFolder = island and island:WaitForChild("Plots", 30)
	if not plotsFolder then
		return trove
	end
	for _, plot in plotsFolder:GetChildren() do
		add(plot)
	end
	trove:Connect(plotsFolder.ChildAdded, add)

	trove:Connect(player.AttributeChanged, function(name)
		if string.find(name, "^Lane3SpeedwayPreview") or name == "Lane3SpeedwayGhost" then
			for _, info in infos do
				refresh(info, false)
			end
		end
	end)

	-- far plots keep their silhouette only (no small props, figures or motion)
	local lastDetail = 0
	trove:Connect(RunService.Heartbeat, function()
		local now = os.clock()
		if now - lastDetail < 0.25 then
			return
		end
		lastDetail = now
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		for plot, info in infos do
			local d = (info.centre - eye).Magnitude
			local near = if info.near then d < FAR else d < NEAR
			if near ~= info.near then
				info.near = near
				if not near then
					Reveal.finish(plot)
				end
				Look.setDetail(plot, if near then "full" else "far")
				Life.rescan(plot, info.level)
				Life.setActive(plot, near)
			end
		end
		Sound.update(eye)
	end)

	-- preview Lineup cars (Studio only; a fixture) and their finish crossings
	if RunService:IsStudio() then
		task.defer(function()
			if not LappingPreview.running() and player:GetAttribute("Lane3SpeedwayPreviewCars") ~= 0 then
				local n = player:GetAttribute("Lane3SpeedwayPreviewCars")
				LappingPreview.start({ carsPerPlot = if type(n) == "number" then n else 6 })
			end
		end)
		trove:Add(function()
			LappingPreview.stop()
		end)
		trove:Connect(LappingPreview.Crossed, function(plot: Model, k: number, rarity: string)
			local info = infos[plot]
			if not info or not info.near then
				return
			end
			local folder = Workspace:FindFirstChild("Lane3_LappingPreview")
			local car = folder and folder:FindFirstChild(string.format("PreviewCar_%02d_%02d", info.index, k))
			Life.onCrossed(plot, if car and car:IsA("BasePart") then car else nil, rarity, k)
			Sound.onCrossed(plot, rarity)
		end)
		local cleanup, refreshPanel = PreviewPanel.mount(function(index: number): number
			for _, info in infos do
				if info.index == index then
					return info.level
				end
			end
			return 1
		end, #plotsFolder:GetChildren(), Ladder.MaxLevel)
		if cleanup then
			trove:Add(cleanup)
		end
		panelRefresh = refreshPanel

		-- Studio test hook: a playtest script calls Invoke("timing", s), Invoke("measure", s),
		-- Invoke("state") or Invoke("life") (this script's own module copies hold the live state)
		local control = trove:Add(Instance.new("BindableFunction"))
		control.Name = "Lane3SpeedwayControl"
		control.OnInvoke = function(command: string, ...: any): any
			if command == "timing" then
				return LappingPreview.timing(...)
			elseif command == "measure" then
				return LappingPreview.measure(...)
			elseif command == "life" then
				return Life.stats()
			elseif command == "state" then
				local out = {}
				for plot, info in infos do
					out[info.index] = {
						name = plot.Name,
						level = info.level,
						near = info.near,
						revealing = Reveal.active(plot),
					}
				end
				return out
			end
			error("unknown command " .. tostring(command))
		end
		control.Parent = player
	end

	trove:Add(function()
		for plot in infos do
			Reveal.finish(plot)
			Life.forget(plot)
			Sound.forget(plot)
			if plot.Parent then
				Look.clear(plot)
			end
		end
	end)
	return trove
end

local current: Trove.Trove? = nil
local function start(root: Instance)
	if current then
		current:Destroy()
	end
	local trove = attach(root)
	current = trove
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
	task.spawn(start, existing)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == ROOT_NAME then
		task.spawn(start, child)
	end
end)
