--!strict
-- Island foliage sway (Lane 3, client presentation only). Tree canopies and bushes planted by
-- the island environment (its Flora and ParkDressing folders) carry a "Sway" attribute (strength) and canopies a "SwayPivotY" (where
-- the crown meets the trunk). The nearest few dozen within SWAY_RANGE of the camera rock gently
-- about that pivot in a slow breeze; everything farther away stays still. The moves are local to
-- this client and never replicate. Reduced motion (GuiService.ReducedMotionEnabled, or the
-- preview-only LocalPlayer attribute "Lane3ReducedMotionOverride") keeps foliage still.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local ROOT_NAME = "Lane3_IslandEnvironment"
local FOLDERS = { "Flora", "ParkDressing" } -- where swaying plants live (rebuilt folders are rescanned)
local OVERRIDE = "Lane3ReducedMotionOverride"
local SWAY_RANGE = 140 -- studs from the camera (Tunable)
local MAX_ACTIVE = 48 -- canopies moved per frame at most (Tunable)
local MAX_ANGLE = math.rad(1.6) -- at Sway 1 (Tunable)
local RESCAN = 2 -- seconds between rescans for streamed-in foliage
local REPICK = 0.5 -- seconds between choosing the nearest canopies
local WIND = Vector3.new(0.8, 0, 0.6).Unit

local player = Players.LocalPlayer

type Item = { part: BasePart, rest: CFrame, pivot: Vector3, strength: number, phase: number }

local function reducedMotion(): boolean
	local override = player:GetAttribute(OVERRIDE)
	if type(override) == "boolean" then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

local function run(trove: Trove.Trove, root: Instance)
	local items: { [BasePart]: Item } = {}
	local active: { Item } = {}
	local lastScan, lastPick = -math.huge, -math.huge
	local axis = Vector3.new(0, 1, 0):Cross(WIND)

	local function scan()
		for _, name in FOLDERS do
			local folder = root:FindFirstChild(name)
			for _, d in if folder then folder:GetDescendants() else {} do
				if d:IsA("BasePart") and not items[d] then
					local strength = d:GetAttribute("Sway")
					if type(strength) == "number" and strength > 0 then
						local pivotY = d:GetAttribute("SwayPivotY")
						local p = d.Position
						items[d] = {
							part = d,
							rest = d.CFrame,
							pivot = Vector3.new(
								p.X,
								if type(pivotY) == "number" then pivotY else p.Y - d.Size.Y / 2,
								p.Z
							),
							strength = strength,
							phase = (p.X * 0.137 + p.Z * 0.091) % (math.pi * 2),
						}
					end
				end
			end
		end
		for part in items do
			if not part:IsDescendantOf(root) then
				items[part] = nil
			end
		end
	end

	local function settle(list: { Item })
		for _, it in list do
			it.part.CFrame = it.rest
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
		if reducedMotion() then
			if #active > 0 then
				settle(active)
				table.clear(active)
			end
			return
		end
		if now - lastPick > REPICK then
			lastPick = now
			local eye = camera.CFrame.Position
			local near: { { item: Item, d: number } } = {}
			for _, it in items do
				local d = (it.pivot - eye).Magnitude
				if d < SWAY_RANGE then
					table.insert(near, { item = it, d = d })
				end
			end
			table.sort(near, function(a, b)
				return a.d < b.d
			end)
			local keep: { [Item]: boolean } = {}
			local nextActive: { Item } = {}
			for i = 1, math.min(MAX_ACTIVE, #near) do
				keep[near[i].item] = true
				table.insert(nextActive, near[i].item)
			end
			for _, it in active do
				if not keep[it] then
					it.part.CFrame = it.rest
				end
			end
			active = nextActive
		end
		if #active == 0 then
			return
		end
		local parts = table.create(#active)
		local frames = table.create(#active)
		for _, it in active do
			-- a slow main sway with a quicker flutter on top, offset per tree
			local a = MAX_ANGLE
				* it.strength
				* (0.7 * math.sin(now * 0.9 + it.phase) + 0.3 * math.sin(now * 2.3 + it.phase * 1.7))
			local pivot = CFrame.new(it.pivot)
			table.insert(parts, it.part)
			table.insert(frames, pivot * CFrame.fromAxisAngle(axis, a) * pivot:Inverse() * it.rest)
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	trove:Add(function()
		settle(active)
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
		run(trove, root)
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
