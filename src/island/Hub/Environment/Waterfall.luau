--!strict
-- The waterfall, as a deliberate visual (terrain water does not fall): layered falling sheets
-- in the cliff notch, a lip of white water, streaks that the client moves down the sheet
-- (Home/Island/EnvironmentMotion), foam rings and restrained foam and mist particles in the
-- plunge pool. Built-in particle texture only; no uploads. Placeholder-free: this is the
-- environment's falls, tuned at the environment review.

local Field = require(script.Parent.Field)
local Kit = require(script.Parent.Parent.Parent.Kit)

local Waterfall = {}

local rgb = Color3.fromRGB

function Waterfall.build(parent: Instance): Model
	local fall = Field.Fall
	local creek = Field.Creek
	local model = Instance.new("Model")
	model.Name = "Waterfall"
	local x = fall.x
	local topY = fall.lip + creek.depth
	local bottomY = Field.LakeLevel
	local height = topY - bottomY
	local zTop = -(fall.cliffY - 0.5) -- world Z of the lip (plan y -280)
	local zFoot = -(fall.cliffY + 9) -- the sheet leans north, clear of the rock face, into the pool
	local mid = Vector3.new(x, (topY + bottomY) / 2, (zTop + zFoot) / 2)
	-- X east, Y up along the sheet (foot to lip), so the front face (-Z) looks north at the plots
	local along = Vector3.new(0, height, zTop - zFoot)
	local lean = CFrame.fromMatrix(mid, Vector3.xAxis, along.Unit)
	local length = along.Magnitude

	local function sheet(
		name: string,
		width: number,
		offset: number,
		colour: Color3,
		transparency: number,
		material: Enum.Material,
		dx: number?,
		shorten: number?
	)
		local cut = shorten or 0
		Kit.part(model, Vector3.new(width, length - cut, 0.6), lean * CFrame.new(dx or 0, -cut / 2, -offset), {
			name = name,
			color = colour,
			material = material,
			transparency = transparency,
			castShadow = false,
		})
	end
	sheet("SheetBack", fall.width - 2, -0.7, rgb(150, 214, 222), 0.1, Enum.Material.SmoothPlastic)
	sheet("SheetFront", fall.width, 0, rgb(200, 242, 246), 0.45, Enum.Material.Glass)
	sheet("SheetEdgeL", 3, 0.3, rgb(236, 252, 252), 0.35, Enum.Material.Glass, -fall.width / 2 + 2, 6)
	sheet("SheetEdgeR", 2.2, 0.4, rgb(236, 252, 252), 0.4, Enum.Material.Glass, fall.width / 2 - 1.5, 14)
	sheet("SheetVeil", fall.width - 5, 0.8, rgb(236, 252, 252), 0.55, Enum.Material.Glass)
	-- side sheets turned toward the end plots, so the falls keep their width seen from an angle
	for _, side in { -1, 1 } do
		Kit.part(
			model,
			Vector3.new(6, length - 4, 0.5),
			lean * CFrame.new(side * (fall.width / 2 - 1.5), -2, -0.4) * CFrame.Angles(0, math.rad(side * -35), 0),
			{
				name = "SheetSide",
				color = rgb(222, 248, 250),
				material = Enum.Material.Glass,
				transparency = 0.4,
				castShadow = false,
			}
		)
	end
	Kit.part(model, Vector3.new(fall.width + 1, 1, 2.4), CFrame.new(x, topY - 0.3, zTop - 0.4), {
		name = "Lip",
		color = rgb(240, 252, 252),
		transparency = 0.2,
		castShadow = false,
	})

	-- streaks: the client moves these down the sheet; at rest they sit spread along it
	local streaks = Instance.new("Folder")
	streaks.Name = "Streaks"
	streaks.Parent = model
	local rng = Random.new(29)
	for k = 1, 12 do
		local phase = rng:NextNumber()
		local dx = (k - 6.5) / 6 * (fall.width / 2 - 1)
		local p = Kit.part(streaks, Vector3.new(0.45, 9, 0.15), lean * CFrame.new(dx, (0.5 - phase) * length, -1.2), {
			name = "Streak",
			color = rgb(248, 255, 255),
			transparency = 0.25,
			castShadow = false,
		})
		p:SetAttribute("Phase", phase)
		p:SetAttribute("OffsetX", dx)
		p:SetAttribute("Length", length)
		p:SetAttribute("Speed", rng:NextNumber(34, 42))
	end
	model:SetAttribute("SheetCFrame", lean)

	-- plunge pool foam and mist
	local pool = Field.Pool
	local foot = Vector3.new(x, bottomY, zFoot)
	for k, spec in { { 22, 0.45 }, { 15, 0.3 }, { 9, 0.15 } } do
		Kit.disc(model, foot + Vector3.new(0, 0, -(k - 1) * 0.8), spec[1], 0.25, bottomY + 0.12 + k * 0.04, {
			name = "Foam",
			color = rgb(246, 252, 252),
			transparency = spec[2],
			castShadow = false,
		})
	end
	local emitterHost = Kit.part(model, Vector3.new(1, 1, 1), CFrame.new(foot + Vector3.new(0, 0.5, 0)), {
		name = "SprayHost",
		transparency = 1,
		castShadow = false,
	})
	local foam = Instance.new("ParticleEmitter")
	foam.Name = "Foam"
	foam.Color = ColorSequence.new(rgb(255, 255, 255))
	foam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	foam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	foam.Lifetime = NumberRange.new(1.2, 1.8)
	foam.Rate = 30
	foam.Speed = NumberRange.new(6, 12)
	foam.SpreadAngle = Vector2.new(35, 35)
	foam.Acceleration = Vector3.new(0, -8, 0)
	foam.LightEmission = 0.2
	foam.Parent = emitterHost
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Color = ColorSequence.new(rgb(230, 245, 248))
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 20) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(3, 4.5)
	mist.Rate = 5
	mist.Speed = NumberRange.new(2, 4)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Drag = 1
	mist.Parent = emitterHost
	model:SetAttribute("PoolRadius", pool.radius)
	model.Parent = parent
	return model
end

return Waterfall
