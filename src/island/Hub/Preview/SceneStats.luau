--!strict
-- DEVELOPMENT MEASUREMENTS (Lane 3). Counts what the island preview builds, by container:
-- parts, MeshParts, unions, beams, particle emitters (with a live-particle estimate of
-- rate x longest lifetime), lights and all instances, plus Studio's own memory figure.
--
--   require(game.ServerStorage.Island.Hub.Preview.SceneStats).run()

local Stats = game:GetService("Stats")

local SceneStats = {}

export type Counts = {
	instances: number,
	parts: number,
	meshParts: number,
	unions: number,
	beams: number,
	emitters: number,
	liveParticlesEstimate: number,
	lights: number,
}

local function count(root: Instance): Counts
	local c: Counts = {
		instances = 0,
		parts = 0,
		meshParts = 0,
		unions = 0,
		beams = 0,
		emitters = 0,
		liveParticlesEstimate = 0,
		lights = 0,
	}
	for _, d in root:GetDescendants() do
		c.instances += 1
		if d:IsA("MeshPart") then
			c.meshParts += 1
		elseif d:IsA("UnionOperation") then
			c.unions += 1
		elseif d:IsA("BasePart") then
			c.parts += 1
		elseif d:IsA("Beam") then
			c.beams += 1
		elseif d:IsA("ParticleEmitter") then
			c.emitters += 1
			c.liveParticlesEstimate += math.ceil(d.Rate * d.Lifetime.Max)
		elseif d:IsA("Light") then
			c.lights += 1
		end
	end
	return c
end

function SceneStats.run(): { [string]: any }
	local report: { [string]: any } = { memoryMb = math.round(Stats:GetTotalMemoryUsageMb()) }
	local preview = workspace:FindFirstChild("Lane3_IslandPreview")
	if preview then
		local island = preview:FindFirstChild("Island")
		if island then
			for _, name in { "Plots", "Plaza", "Scenery" } do
				local child = island:FindFirstChild(name)
				if child then
					report[name] = count(child)
				end
			end
		end
		local helpers = preview:FindFirstChild("Helpers")
		if helpers then
			report.Helpers = count(helpers)
		end
	end
	local env = workspace:FindFirstChild("Lane3_IslandEnvironment")
	if env then
		for _, child in env:GetChildren() do
			report["Environment." .. child.Name] = count(child)
		end
	end
	return report
end

return SceneStats
