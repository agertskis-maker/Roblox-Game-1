--!strict
-- Speedway looks on this client (Lane 3, presentation only). For each island plot it assembles
-- the Speedway for the plot's level with the shared look module (Shared.Island.Speedway.Look),
-- switches far plots to their still silhouette, plays the level-up reveal, fills the kiosk's
-- next-level board, draws the next level's ghost outline, animates the figures and plays the
-- ambience. A plot's level comes from, in order:
--   in Studio only, the LocalPlayer attribute "Lane3SpeedwayPreviewLevel_PlotNN", then "Lane3SpeedwayPreviewLevel"
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

local BetaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Beta"):WaitForChild("BetaConfig"))

local Speedway = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Island"):WaitForChild("Speedway")
local Ladder = require(Speedway:WaitForChild("Ladder"))
local Look = require(Speedway:WaitForChild("Look"))
local Path = require(Speedway:WaitForChild("Path"))

local Calm = require(script.Parent.Speedway.Calm)
local Kiosk = require(script.Parent.Speedway.Kiosk)
local LappingPreview = require(script.Parent.LappingPreview)
local ParkingLook = require(script.Parent.Speedway.ParkingLook)
local Life = require(script.Parent.Speedway.Life)
local PreviewPanel = require(script.Parent.Speedway.PreviewPanel)
local Reveal = require(script.Parent.Speedway.Reveal)
local ShopPanel = require(script.Parent.Speedway.ShopPanel)
local Sound = require(script.Parent.Speedway.Sound)

local ROOT_NAME = "Lane3_IslandPreview"
local NEAR = 230 -- full detail inside this distance from a plot's track centre (Tunable)
local FAR = 260 -- still silhouette beyond this; between the two a plot keeps its state
local TRACK_CENTRE_U = 441
local GREET_RADIUS = 10 -- the island's prompt range (Open Garage, Hub/Environment/Destinations)
local GREET_REARM = 13 -- the keeper greets again only after the owner walked this far away

local player = Players.LocalPlayer

-- preview owner names for the plots that are not "yours" (fictional, PREVIEW only)
local FIXTURE_OWNERS = { "Pip", "Juno", "Rex", "Mo", "Kit", "Lou" }

type PlotInfo = {
	plot: Model,
	index: number,
	bearing: number,
	centre: Vector3,
	near: boolean,
	level: number,
	owner: string?,
	busy: boolean,
	dirty: boolean,
	greetArmed: boolean,
}

local function attach(root: Instance): Trove.Trove
	local trove = Trove.new()
	local fx = trove:Add(Instance.new("Folder"))
	fx.Name = "Lane3_SpeedwayFx"
	fx.Parent = Workspace
	Life.setFx(fx)
	local infos: { [Model]: PlotInfo } = {}
	local panelRefresh: (() -> ())? = nil

	local function resolve(info: PlotInfo): number
		if RunService:IsStudio() then
			-- preview overrides, Studio only (a live game follows the server's SpeedwayLevel)
			local own = player:GetAttribute(string.format("Lane3SpeedwayPreviewLevel_Plot%02d", info.index))
			if type(own) == "number" then
				return Ladder.clamp(own)
			end
			local all = player:GetAttribute("Lane3SpeedwayPreviewLevel")
			if type(all) == "number" then
				return Ladder.clamp(all)
			end
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
		-- Car Hop Beta 1: the plot the server gave this player (BetaPlots)
		local given = player:GetAttribute(BetaConfig.HomePlotAttribute)
		if type(given) == "number" then
			return given
		elseif BetaConfig.enabled() then
			return 0 -- not given a plot yet: no prompts anywhere
		end
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

	-- The two purchase prompts (Raceway round 2, approved by Adam 2026-10-29): "Upgrade Raceway" on the
	-- shop counter and "Buy Parking Spot" on the parking sign, Roblox's default prompt style, on the
	-- local player's own plot only (visitors read the board and the sign). Purchases exist only in the
	-- Studio preview: BUY raises the plot's preview level or spot count (LocalPlayer attributes), with no
	-- Cash, saving or remote. Outside Studio no price exists yet, so there is no prompt and nothing to buy.
	local PROMPT_NAME = "Lane3RacewayPrompt"
	local canBuy = RunService:IsStudio() or BetaConfig.enabled()
	-- Car Hop Beta 1: BUY asks the server (free, saved); the Studio preview keeps its local values
	local function betaRemote(name: string): RemoteEvent?
		if not BetaConfig.enabled() then
			return nil
		end
		local net = ReplicatedStorage:WaitForChild(BetaConfig.NetName, 10)
		local remote = net and net:FindFirstChild(name)
		return if remote and remote:IsA("RemoteEvent") then remote else nil
	end
	local function anchorIn(container: Instance?, attribute: string): BasePart?
		if not container then
			return nil
		end
		for _, d in container:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute(attribute) then
				return d
			end
		end
		return nil
	end
	local function sourceFor(info: PlotInfo, kind: ShopPanel.Kind, anchor: BasePart): ShopPanel.Source
		local plot = info.plot
		if kind == "upgrade" then
			return {
				kind = kind,
				plot = plot,
				anchor = anchor,
				current = function(): number
					return info.level
				end,
				busy = function(): boolean
					return info.busy or Reveal.active(plot)
				end,
				buy = if canBuy
					then function(target: number)
						local remote = betaRemote(BetaConfig.Remotes.BuyRacewayLevel)
						if remote then
							remote:FireServer()
							return
						end
						player:SetAttribute(
							string.format("Lane3SpeedwayPreviewLevel_Plot%02d", info.index),
							Ladder.clamp(target)
						)
					end
					else nil,
			}
		end
		return {
			kind = kind,
			plot = plot,
			anchor = anchor,
			current = function(): number
				local built = ParkingLook.built(plot)
				return if built then built.spots else ParkingLook.resolve(plot, info.index)
			end,
			busy = function(): boolean
				return ParkingLook.revealing(plot)
			end,
			buy = if canBuy
				then function(target: number)
					local remote = betaRemote(BetaConfig.Remotes.BuyParkingSpot)
					if remote then
						remote:FireServer()
						return
					end
					player:SetAttribute(string.format("Lane3ParkingPreviewSpots_Plot%02d", info.index), target)
				end
				else nil,
		}
	end
	local function placePrompt(info: PlotInfo, kind: ShopPanel.Kind, anchor: BasePart?)
		local mine = info.index == homeIndex() and canBuy
		local existing = anchor and anchor:FindFirstChild(PROMPT_NAME)
		if not (mine and anchor) then
			if existing then
				existing:Destroy()
			end
			return
		end
		if existing then
			return
		end
		local at = anchor :: BasePart
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.ActionText = if kind == "upgrade" then "Upgrade Raceway" else "Buy Parking Spot"
		prompt.ObjectText = if kind == "upgrade" then "Raceway shop" else "Parking"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10 -- the island's prompt range (Open Garage)
		prompt.RequiresLineOfSight = true -- the booth's body hides it from behind the shop
		prompt.Triggered:Connect(function()
			if info.index == homeIndex() then
				ShopPanel.open(sourceFor(info, kind, at))
			end
		end)
		prompt.Parent = at
	end
	local function syncPrompts(info: PlotInfo)
		placePrompt(info, "upgrade", anchorIn(info.plot:FindFirstChild("SpeedwayLook"), "ShopPromptAnchor"))
		placePrompt(info, "parking", anchorIn(info.plot:FindFirstChild("ParkingLook"), "ParkingPromptAnchor"))
	end
	local function refreshParking(info: PlotInfo, reveal: boolean)
		ParkingLook.refresh(info.plot, info.index, info.bearing, reveal, Calm(), fx)
		syncPrompts(info)
		if ShopPanel.openPlot() == info.plot then
			ShopPanel.refresh()
		end
	end

	local function build(info: PlotInfo, first: boolean)
		local level = resolve(info)
		local owner = ownerOf(info)
		local state = Look.state(info.plot)
		if state and state.level == level and info.owner == owner and not first then
			ghost(info)
			return
		end
		Reveal.finish(info.plot)
		if state and info.owner ~= owner then
			-- a new owner name: rebuild the signs (and everything else) quietly; a banner or an open
			-- purchase panel for this plot ends at once
			Look.clear(info.plot)
			first = true
			if info.index == homeIndex() then
				Reveal.cancelBanner()
			end
			if ShopPanel.openPlot() == info.plot then
				ShopPanel.close(true)
			end
		end
		info.owner = owner
		local old = info.level
		local change = Look.apply(info.plot, level, options(info))
		info.level = level
		local revealing = not (first or level < old or not info.near)
		if not revealing then
			-- first build, an inspection downgrade or a far plot: no show, just the result
			for _, f in change.removed do
				f:Destroy()
			end
			info.plot:SetAttribute("SpeedwayPathLevel", level)
			Life.rescan(info.plot, level)
			if level < old and info.index == homeIndex() then
				Reveal.cancelBanner() -- a level-down shows nothing
			end
		else
			local calm = Calm()
			Reveal.play(info.plot, change.added, change.removed, calm, fx)
			if info.index == homeIndex() then
				-- only now that the track has this level: "RACEWAY LEVEL n!", the latest level only
				Reveal.banner(level, calm)
			end
			-- the cars move to the new road, and the crowd is rescanned, once the reveal has built it
			-- (the replaced pieces are destroyed by then)
			Life.rescan(info.plot, old)
			task.delay(Reveal.Seconds + 0.05, function()
				if info.level == level and info.plot.Parent then
					info.plot:SetAttribute("SpeedwayPathLevel", level)
					Life.rescan(info.plot, level)
					Life.setActive(info.plot, info.near)
				end
			end)
		end
		Life.setActive(info.plot, info.near)
		Kiosk.fill(info.plot, level, options(info))
		Kiosk.fillScreen(info.plot, level)
		Sound.setLevel(info.plot, level, info.centre, fx)
		ghost(info)
		if not first and level > old and info.near then
			-- the crowd welcomes the new look
			Life.onCrossed(info.plot, nil, "Rare", 0)
		end
		if panelRefresh then
			panelRefresh()
		end
		syncPrompts(info)
		if ShopPanel.openPlot() == info.plot then
			ShopPanel.refresh()
		end
	end

	-- One build at a time per plot (Look.apply yields while meshes load): a change that arrives
	-- during a build is applied right after it, so none is lost and no feature is built twice.
	local function refresh(info: PlotInfo, first: boolean)
		if info.busy then
			info.dirty = true
			return
		end
		info.busy = true
		local ok, err = pcall(build, info, first)
		while ok and info.dirty and info.plot.Parent do
			info.dirty = false
			ok, err = pcall(build, info, false)
		end
		info.busy = false
		if not ok then
			warn("Speedway looks: " .. tostring(err))
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
			owner = nil,
			busy = false,
			dirty = false,
			greetArmed = true,
		}
		infos[plot] = info
		-- listen first, so a level set during the first build is not missed
		trove:Connect(plot.AttributeChanged, function(name)
			if name == "SpeedwayLevel" or name == "SpeedwayPreviewLevel" or name == "OwnerDisplayName" then
				refresh(info, false)
			elseif name == "ParkingSpots" then
				refreshParking(info, info.near)
			end
		end)
		refresh(info, true)
		refreshParking(info, false)
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
		if name == "Lane3SpeedwayPreviewHome" or name == BetaConfig.HomePlotAttribute then
			-- the preview owner changed: the purchase surface and any banner end at once
			ShopPanel.close(true)
			Reveal.cancelBanner()
		end
		if string.find(name, "^Lane3SpeedwayPreview") or name == "Lane3SpeedwayGhost" then
			for _, info in infos do
				refresh(info, false)
			end
		elseif string.find(name, "^Lane3ParkingPreviewSpots") then
			for _, info in infos do
				refreshParking(info, info.near)
			end
		end
	end)

	-- The shopkeeper of your own plot greets you once as you walk up to the counter (inside the prompt
	-- range, in front of the shop, nothing in between); it greets again only after you walked away.
	-- Visitors on someone else's plot are not greeted.
	local sightParams = RaycastParams.new()
	sightParams.FilterType = Enum.RaycastFilterType.Exclude
	local function greetOwner()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not (head and head:IsA("BasePart")) then
			return
		end
		for plot, info in infos do
			if info.index ~= homeIndex() or not info.near then
				continue
			end
			local look = plot:FindFirstChild("SpeedwayLook")
			local keeper = look and look:FindFirstChild("Shopkeeper", true)
			if not (keeper and keeper:IsA("Model") and keeper.PrimaryPart) then
				continue
			end
			local body = keeper.PrimaryPart :: BasePart
			local frame = keeper:GetAttribute("BaseCFrame")
			-- the placement frame's +Z is the keeper's front (kit meshes face their local +Z)
			local front = if typeof(frame) == "CFrame" then frame.ZVector else -body.CFrame.LookVector
			local eye = body.Position + Vector3.yAxis * 1.4
			local offset = head.Position - eye
			local flat = offset * Vector3.new(1, 0, 1)
			if flat.Magnitude > GREET_REARM then
				info.greetArmed = true
			elseif info.greetArmed and flat.Magnitude < GREET_RADIUS and flat:Dot(front) > 0 then
				-- in front of the counter (the keeper faces the park); no wall or prop in between (the
				-- booth's own body collider surrounds the keeper, so it does not count)
				local collider = look and look:FindFirstChild("ShopCollider", true)
				sightParams.FilterDescendantsInstances = if collider
					then { character, keeper, collider }
					else { character, keeper }
				if not Workspace:Raycast(eye, offset, sightParams) and Life.greet(plot) then
					info.greetArmed = false
				end
			end
		end
	end

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
		for plot, info in infos do
			if info.near and info.level >= 8 then
				Kiosk.screenDetail(plot, eye)
			end
		end
		Sound.update(eye)
		greetOwner()
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
		-- Invoke("state"), Invoke("life"), Invoke("panel"), Invoke("banner") or Invoke("openPanel", kind) (this script's own module copies hold the live state)
		local control = trove:Add(Instance.new("BindableFunction"))
		control.Name = "Lane3SpeedwayControl"
		control.OnInvoke = function(command: string, ...: any): any
			if command == "timing" then
				return LappingPreview.timing(...)
			elseif command == "measure" then
				return LappingPreview.measure(...)
			elseif command == "life" then
				return Life.stats()
			elseif command == "panel" then
				return ShopPanel.state()
			elseif command == "banner" then
				return Reveal.bannerState()
			elseif command == "openPanel" then
				-- what the owner's prompt does: open the upgrade or parking panel of the home plot
				local kind = (...) :: ShopPanel.Kind
				for _, info in infos do
					if info.index == homeIndex() then
						local container =
							info.plot:FindFirstChild(if kind == "upgrade" then "SpeedwayLook" else "ParkingLook")
						local anchor =
							anchorIn(container, if kind == "upgrade" then "ShopPromptAnchor" else "ParkingPromptAnchor")
						if anchor then
							ShopPanel.open(sourceFor(info, kind, anchor))
							return true
						end
					end
				end
				return false
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
		ShopPanel.close(true)
		Reveal.cancelBanner()
		for plot in infos do
			Reveal.finish(plot)
			Life.forget(plot)
			ParkingLook.forget(plot)
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
