--!strict
-- UpgradeCard.NextLevelView (Lane 3 Round 8, U-04): the picture in the Raceway card's trackside window. A ViewportFrame that renders
-- the ACTUAL pieces the next Raceway level adds (the signature piece of src/shared/Island/Speedway/Look.luau plus the props of that
-- level), built for a private bearing-0 plot frame, small and slowly turning, lit from the upper left like the reference. A level
-- that adds only ground (nothing buildable) or a place without the kit meshes shows a sky and a gold badge instead.
-- Cost: one ViewportFrame with at most a few hundred parts, alive only while the card is open; the camera moves only when
-- Reduce Motion is off. The whole scene is destroyed with the view.
--
--   local v = NextLevelView.new(parent: GuiObject, plot: Model) -> View
--   v:setLevel(level: number)      builds the pieces level `level` adds (nil-safe; a newer call cancels an older one)
--   v.frame: ViewportFrame         v.hasScene: boolean (true when real pieces are showing)       v:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Speedway = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Island"):WaitForChild("Speedway")
local Ctx = require(Speedway:WaitForChild("Ctx"))
local Ladder = require(Speedway:WaitForChild("Ladder"))
local Look = require(Speedway:WaitForChild("Look"))

local Calm = (require :: any)(script.Parent.Parent.Parent.Parent.Parent.UI.Prototype.R8Kit.Calm) :: () -> boolean

local NextLevelView = {}

export type View = {
	frame: ViewportFrame,
	hasScene: boolean,
	setLevel: (self: View, level: number) -> (),
	destroy: (self: View) -> (),
}

-- the props shown next to the level's signature piece, best first (names of Look.Features)
local SUPPORT: { [string]: number } = {
	BleachersFull = 1,
	Bleachers = 2,
	Grandstand = 3,
	GrandstandFull = 4,
	Gantry = 5,
	Floodlights = 6,
	BigScreen = 7,
	Official = 8,
	StartLights = 9,
	FlagLine = 10,
	PitGarage = 11,
	Announcer = 12,
	SnackCart = 13,
	StartBoard = 14,
	Pennants = 15,
	Blimp = 16,
	Statue = 17,
	Cannons = 18,
	LapBoard = 19,
}
local MAX_SUPPORT = 3
local FOV = 36

local Obj = {}
Obj.__index = Obj

local function newParts(folder: Folder): Look.Parts
	local function sub(name: string): Folder
		local s = Instance.new("Folder")
		s.Name = name
		s.Parent = folder
		return s
	end
	return { major = sub("Major"), minor = sub("Minor"), life = sub("Life") }
end

-- The scene for `level`: a Model holding the signature piece and up to MAX_SUPPORT props, or nil when nothing could be built.
local function buildScene(plot: Model, level: number): Model?
	local model = Instance.new("Model")
	model.Name = "NextLevelScene"
	local options: Look.Options = { index = 1, bearing = 0, owner = "", keepRemoved = false }
	local ok = pcall(function()
		local piece = Look.signaturePiece(plot, level, options)
		if piece then
			piece.Parent = model
		end
		local ctx = Ctx.new(plot, 1, 0, level, "")
		local signature = Look.SignatureFeature[Ladder.get(level).signature]
		local picks: { Look.Feature } = {}
		for _, feature in Look.Features do
			if feature.from == level and SUPPORT[feature.name] and feature.name ~= signature then
				table.insert(picks, feature)
			end
		end
		table.sort(picks, function(a, b)
			return (SUPPORT[a.name] :: number) < (SUPPORT[b.name] :: number)
		end)
		for i = 1, math.min(#picks, MAX_SUPPORT) do
			local folder = Instance.new("Folder")
			folder.Name = picks[i].name
			picks[i].build(newParts(folder), ctx)
			folder.Parent = model
		end
	end)
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Transparency = if d.Transparency >= 0.95 then 1 else d.Transparency
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Sound") or d:IsA("SurfaceGui") then
			d:Destroy()
		end
	end
	if not ok or parts == 0 then
		model:Destroy()
		return nil
	end
	return model
end

function NextLevelView.new(parent: GuiObject, plot: Model): View
	local trove = Trove.new()
	local frame: ViewportFrame = trove:Add(Instance.new("ViewportFrame"))
	frame.Name = "NextLevelView"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Ambient = Color3.fromRGB(150, 158, 182)
	frame.LightColor = Color3.fromRGB(255, 240, 214)
	frame.LightDirection = Vector3.new(-0.55, -1, -0.45)
	frame.ImageTransparency = 0
	frame.Parent = parent
	local camera: Camera = trove:Add(Instance.new("Camera"))
	camera.FieldOfView = FOV
	camera.Parent = frame
	frame.CurrentCamera = camera
	local self = setmetatable({
		frame = frame,
		hasScene = false,
		trove = trove,
		plot = plot,
		camera = camera,
		scene = nil,
		focus = Vector3.zero,
		distance = 40,
		angle = math.rad(35),
		token = 0,
		connection = nil,
	}, Obj)
	local s: any = self
	trove:Add(function()
		s.token += 1
		if s.connection then
			s.connection:Disconnect()
			s.connection = nil
		end
	end)
	return s :: View
end

local function aim(self: any)
	local dir = Vector3.new(math.sin(self.angle) * 0.82, 0.5, math.cos(self.angle) * 0.82).Unit
	self.camera.CFrame = CFrame.lookAt(self.focus + dir * self.distance, self.focus)
end

function Obj.setLevel(self: any, level: number)
	self.token += 1
	local token = self.token
	if self.scene then
		self.scene:Destroy()
		self.scene = nil
	end
	self.hasScene = false
	task.spawn(function()
		local scene = buildScene(self.plot, level)
		if token ~= self.token or not self.frame.Parent then
			if scene then
				scene:Destroy()
			end
			return
		end
		if not scene then
			return
		end
		-- stand the scene on a patch of grass and frame it
		local cf, size = scene:GetBoundingBox()
		local base = Instance.new("Part")
		base.Name = "Grass"
		base.Anchored = true
		base.CanCollide = false
		base.CanQuery = false
		base.CanTouch = false
		base.Material = Enum.Material.SmoothPlastic
		base.Color = Color3.fromRGB(110, 196, 84)
		base.Shape = Enum.PartType.Cylinder
		local diameter = math.max(size.X, size.Z) * 1.45 + 8
		base.Size = Vector3.new(1, diameter, diameter)
		base.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 - 0.5, cf.Position.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		base.Parent = scene
		scene.Parent = self.frame
		self.scene = scene
		self.hasScene = true
		self.focus = cf.Position - Vector3.new(0, size.Y * 0.1, 0)
		local radius = math.max(size.Magnitude * 0.5, 8)
		self.distance = radius / math.tan(math.rad(FOV / 2)) * 0.82
		aim(self)
		if self.connection == nil and not Calm() then
			local last = os.clock()
			self.connection = RunService.RenderStepped:Connect(function()
				local now = os.clock()
				self.angle += (now - last) * 0.28 -- a slow turn: one lap in about 22 s
				last = now
				if self.hasScene and not Calm() then
					aim(self)
				end
			end)
		end
	end)
end

function Obj.destroy(self: any)
	self.trove:Destroy()
end

return NextLevelView
