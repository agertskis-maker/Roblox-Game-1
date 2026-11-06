--!strict
-- RacewayLineup: the real Lineup cars on every owned plot's Raceway (Round 5, L-02 and L-04; Lane 3, presentation only).
-- For each plot with an Owner, the owner's Lineup (LiveData, the owner's replicated attribute) drives round the plot's lap
-- path on the SERVER's Lap Pay clock (src/shared/UI/LapClock; the plot carries the epoch and lap length). So the car crosses
-- the line when the server pays, on every client, and a late payout event can never add a lap. The cars are rebuilt from
-- the attribute whenever it changes, never from a panel's own state. Visitors see the same cars and pops as the owner.
--
-- A payout (BetaLapPaid: plot, slot, carId, amount, newCash?) pops "+$N" above that car for everyone; only the owner's copy
-- carries newCash, and only the owner sees the money fly to their Cash counter. The amount drawn is the server's.
-- Reduce Motion: the pop appears and fades in place, no rise and no flight. A missing car model never stops a payout (the
-- server pays from the save); the stand-in car drives instead and the miss is logged once.
-- Off without a live server (LiveData.active()): the Studio LappingPreview fixture covers that case.
-- Round 7 (K-01): every Uncommon or better car (and every Gold, Diamond, Rainbow or Galaxy edition) wears its RacewayAura, and a
-- Legendary crossing the line on a payout sets off fireworks, so visitors see who has the good cars.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveData = require(Shared:WaitForChild("UI"):WaitForChild("LiveData"))
local LapClock = require(Shared.UI:WaitForChild("LapClock"))
local Path = require(Shared:WaitForChild("Island"):WaitForChild("Speedway"):WaitForChild("Path"))
local Format = require(Shared.UI:WaitForChild("Format"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local UI = script.Parent.Parent.Parent:WaitForChild("UI")
local Prototype = UI:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local RacewayAura = require(Prototype:WaitForChild("Style"):WaitForChild("RacewayAura"))
local RealCar = require(Prototype:WaitForChild("RealCar"))
local Sounds = require(Prototype:WaitForChild("Sounds"))
local StyleState = require(Prototype:WaitForChild("StyleState"))

local player = Players.LocalPlayer

local t0 = os.clock()
while not LiveData.active() and os.clock() - t0 < 15 do
	task.wait(0.25)
end
if not LiveData.active() then
	return
end

local ACTIVE_RADIUS = 320 -- studs from the camera to a plot's centre; farther plots are not moved
local CAR_LENGTH = 12.6
local CAR_HEIGHT = 5.2
local WHEELBASE = 8.5

type Car = { rig: any, slot: number, carId: string, placed: boolean, edition: number, aura: any, auraBody: any }
type Lane = {
	plot: Model,
	index: number,
	frame: CFrame,
	centre: Vector3,
	owner: Player?,
	key: string, -- the Lineup text the cars were built from
	cars: { Car },
	trove: any,
	refresh: (() -> ())?,
}

local folder = Instance.new("Folder")
folder.Name = "Lane3_RacewayLineup"
folder.Parent = Workspace

local lanes: { [Model]: Lane } = {}
local warned: { [string]: boolean } = {}

local function plotsFolder(): Instance?
	local root = Workspace:FindFirstChild("Lane3_IslandPreview")
	local island = root and root:FindFirstChild("Island")
	return island and island:FindFirstChild("Plots")
end

local function levelOf(plot: Model): number
	local l = plot:GetAttribute("SpeedwayPathLevel")
	if type(l) ~= "number" then
		l = plot:GetAttribute("SpeedwayLookLevel")
	end
	return if type(l) == "number" then l else 4
end

local function ownerOf(plot: Model): Player?
	local id = plot:GetAttribute("Owner")
	return if type(id) == "number" then Players:GetPlayerByUserId(id) else nil
end

local function clear(lane: Lane)
	lane.trove:Clean()
	lane.cars = {}
end

local function rebuild(lane: Lane)
	clear(lane)
	local owner = lane.owner
	if not owner then
		lane.key = ""
		return
	end
	local list = LiveData.lineup(owner)
	lane.key = table.concat(list, ",")
	for slot, carId in list do
		local rig = RealCar.mount(folder, { length = CAR_LENGTH, height = CAR_HEIGHT })
		rig:setCar(carId)
		if rig.source ~= carId and not warned[carId] then
			warned[carId] = true
			warn("[RacewayLineup] no model for " .. carId .. "; the stand-in car drives (Lap Pay is unaffected)")
		end
		lane.trove:Add(function()
			rig:destroy()
		end)
		-- Round 7 (C-08): your own selected car wears your Style Shop look here too
		if owner == Players.LocalPlayer and carId == StyleState.car() then
			rig:setPaint(StyleState.item("Paint"))
			rig:setDecal(StyleState.item("Decals"))
			rig:setWheels(StyleState.item("Wheels"))
			rig:setTrail(StyleState.item("Trails"))
		end
		local saved = LiveData.cars(owner)[carId]
		local car: Car = {
			rig = rig,
			slot = slot,
			carId = carId,
			placed = false,
			edition = if saved and type(saved.Edition) == "number" then saved.Edition else 1,
			aura = nil,
			auraBody = nil,
		}
		lane.trove:Add(function()
			if car.aura then
				car.aura:destroy()
			end
		end)
		table.insert(lane.cars, car)
	end
end

local function watch(plot: Instance)
	if not plot:IsA("Model") or lanes[plot] then
		return
	end
	local bearing = plot:GetAttribute("BearingDeg")
	if type(bearing) ~= "number" then
		return
	end
	local frame = Path.plotFrame(bearing)
	local index = tonumber(string.match(plot.Name, "%d+")) or 0
	local lane: Lane = {
		plot = plot,
		index = index,
		frame = frame,
		centre = frame * Vector3.new(0, 0, -441),
		owner = nil,
		key = "",
		cars = {},
		trove = Trove.new(),
	}
	lanes[plot] = lane
	local ownerConn: RBXScriptConnection? = nil
	local function onOwner()
		if ownerConn then
			ownerConn:Disconnect()
			ownerConn = nil
		end
		lane.owner = ownerOf(plot)
		if lane.owner then
			ownerConn = LiveData.changed(lane.owner, "lineup", function()
				rebuild(lane)
			end)
		end
		rebuild(lane)
	end
	lane.refresh = onOwner
	plot:GetAttributeChangedSignal("Owner"):Connect(onOwner)
	onOwner()
end

-- where slot `slot`'s car is on its lap now (server clock)
local function carFrame(lane: Lane, slot: number, now: number): CFrame?
	local epoch = lane.plot:GetAttribute(LiveData.Attributes.lapEpoch)
	local lap = lane.plot:GetAttribute(LiveData.Attributes.lapSeconds)
	if type(epoch) ~= "number" or type(lap) ~= "number" or lap <= 0 then
		return nil
	end
	local path = Path.forLevel(levelOf(lane.plot))
	-- phase 0 is the line; LappingPreview's path also starts its lap there
	local f = LapClock.phase(now, epoch, slot, lap)
	local s = Path.distanceAt(path, f)
	local pos, look, up = Path.sample(path, s)
	local wp = lane.frame * (pos + up * Path.carLift(path, s, WHEELBASE))
	-- a RealCar's front is its -Z (its LookVector), so it looks along the way it drives (2026-11-05: it was turned the
	-- LappingPreview stand-in's way, +Z forward, and drove backwards)
	return CFrame.lookAt(wp, wp + lane.frame:VectorToWorldSpace(look), lane.frame:VectorToWorldSpace(up))
end

RunService.RenderStepped:Connect(function()
	RacewayAura.step(os.clock())
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = Workspace:GetServerTimeNow()
	for _, lane in lanes do
		local near = (lane.centre - eye).Magnitude <= ACTIVE_RADIUS
		for _, car in lane.cars do
			-- every car gets its place on its first frame (never left at the world origin, the fountain); far plots then rest
			if near or not car.placed then
				local cf = carFrame(lane, car.slot, now)
				if cf then
					-- a RealCar's pivot is the bottom centre between its wheels, so it sits on the track as it is
					-- (2026-11-05: it was lifted half a car, as for a pivot at the middle, and floated)
					car.rig:pivotTo(cf)
					car.placed = true
				end
			end
			-- K-01: the aura goes on once the car's body has loaded (and again if the body was swapped)
			local body = car.rig._body
			if body and body ~= car.auraBody then
				if car.aura then
					car.aura:destroy()
				end
				car.auraBody = body
				car.aura = RacewayAura.attach(body.model, car.carId, car.edition)
			end
		end
	end
end)

-- the "+$N" pop above a car, and for the owner the money's flight to the Cash counter
local function cashTarget(): Vector2?
	local home = player.PlayerGui:FindFirstChild("CarHopHome")
	local plus = home and home:FindFirstChild("CashPlus", true)
	if plus and plus:IsA("GuiObject") and plus.Visible then
		return plus.AbsolutePosition + plus.AbsoluteSize / 2
	end
	return nil
end

local flyGui = Instance.new("ScreenGui")
flyGui.Name = "Lane3LapPayFly"
flyGui.IgnoreGuiInset = true
flyGui.ResetOnSpawn = false
flyGui.DisplayOrder = 30
flyGui.Parent = player:WaitForChild("PlayerGui")

local function popAt(part: BasePart, amount: number, mine: boolean)
	local bill = Instance.new("BillboardGui")
	bill.Name = "LapPayPop"
	bill.Size = UDim2.fromOffset(160, 56)
	bill.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	bill.AlwaysOnTop = true
	bill.MaxDistance = 220
	bill.Adornee = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "+" .. Format.cash(amount)
	label.TextColor3 = Color3.fromRGB(120, 230, 90)
	label.TextStrokeColor3 = Color3.fromRGB(16, 30, 60)
	label.TextStrokeTransparency = 0
	label.Parent = bill
	bill.Parent = flyGui
	local calm = Motion.reduced()
	if not calm then
		TweenService:Create(bill, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffsetWorldSpace = Vector3.new(0, 10, 0),
		}):Play()
	end
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.8), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.4, function()
		bill:Destroy()
	end)
	-- the owner's own money flies to their counter (a look only: the counter shows the server's Cash already)
	local camera = Workspace.CurrentCamera
	local target = cashTarget()
	if not (mine and not calm and camera and target) then
		return
	end
	local from, onScreen = camera:WorldToViewportPoint(part.Position + Vector3.new(0, 6, 0))
	if not onScreen then
		return
	end
	local coin = Instance.new("TextLabel")
	coin.BackgroundTransparency = 1
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Size = UDim2.fromOffset(44, 44)
	coin.Position = UDim2.fromOffset(from.X, from.Y)
	coin.Font = Enum.Font.FredokaOne
	coin.TextScaled = true
	coin.Text = "$"
	coin.TextColor3 = Color3.fromRGB(120, 230, 90)
	coin.TextStrokeTransparency = 0
	coin.Parent = flyGui
	local tween = TweenService:Create(coin, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromOffset(target.X, target.Y),
		Size = UDim2.fromOffset(22, 22),
	})
	tween:Play()
	tween.Completed:Connect(function()
		coin:Destroy()
	end)
end

local lapPaid = LiveData.remote(LiveData.Remotes.LapPaid)
if lapPaid then
	lapPaid.OnClientEvent:Connect(function(plotIndex: any, slot: any, _carId: any, amount: any, newCash: any)
		if type(plotIndex) ~= "number" or type(slot) ~= "number" or type(amount) ~= "number" then
			return
		end
		for _, lane in lanes do
			if lane.index == plotIndex then
				local car = lane.cars[slot]
				local body = car and car.rig._body
				local part = body and body.model and body.model.PrimaryPart
					or (body and body.model and body.model:FindFirstChildWhichIsA("BasePart", true))
				if part then
					popAt(part, amount, newCash ~= nil)
				end
				-- K-01: a Legendary crossing the line gets fireworks, and a cheer for its owner
				if car and car.aura and car.aura.rarity == "Legendary" then
					RacewayAura.celebrate(car.aura)
					if newCash ~= nil then
						Sounds.play("NewBest", 0.5)
					end
				end
			end
		end
	end)
end

local plots = plotsFolder()
while not plots do
	task.wait(1)
	plots = plotsFolder()
end
for _, plot in (plots :: Instance):GetChildren() do
	watch(plot)
end
(plots :: Instance).ChildAdded:Connect(watch)
Players.PlayerAdded:Connect(function()
	for plot, lane in lanes do
		if ownerOf(plot) ~= lane.owner and lane.refresh then
			lane.refresh()
		end
	end
end)
-- Round 7 (C-08): a change in what you wear or which car you picked repaints your own Raceway at once
StyleState.Changed:Connect(function()
	for _, lane in lanes do
		if lane.owner == Players.LocalPlayer then
			rebuild(lane)
		end
	end
end)
