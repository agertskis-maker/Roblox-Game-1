--!strict
-- Trails.TrailSelfTest (Round 8, T-01 to T-11): a Studio check of the trail engine. Not wired to anything at start-up: run it from
-- the Studio MCP with
--   require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Prototype.Style.Trails.TrailSelfTest).run()
-- It dresses a real car from ReplicatedStorage.Cars with every trail in the catalog and checks: the exhaust points come from
-- Anchors.Exhausts (one trail point per entry), every trail builds, the live-particle count stays under the tier cap, the phone
-- quality is about half of full, Reduce Motion halves again, MATCH MY PAINT changes the colours of the three trails that allow it,
-- every layer a higher tier adds really adds something, and destroying a handle leaves nothing behind. Returns lines "PASS ..." or
-- "FAIL ...". It never touches the player's save, the economy or the network.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local Exhausts = require(ReplicatedStorage.Shared.Style.Anchors.Exhausts)
local TrailFx = require(script.Parent.Parent.TrailFx)

local TrailSelfTest = {}

local CAR = "Apex"

function TrailSelfTest.run(): { string }
	local lines: { string } = {}
	local function expect(name: string, ok: boolean, detail: string?)
		table.insert(lines, (if ok then "PASS " else "FAIL ") .. name .. (if detail then " (" .. detail .. ")" else ""))
	end

	local cars = ReplicatedStorage:FindFirstChild("Cars")
	local source = if cars then cars:FindFirstChild(CAR) else nil
	if not source then
		table.insert(lines, "FAIL no car " .. CAR .. " under ReplicatedStorage.Cars")
		return lines
	end
	local before = #workspace:GetDescendants()
	local holder = Instance.new("Folder")
	holder.Name = "TrailSelfTest"
	holder.Parent = workspace
	local model = (source :: Model):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	model.Parent = holder
	model:PivotTo(CFrame.new(0, 800, 0))

	local byTier: { [number]: { alive: number, layers: number } } = {}
	for _, item in Catalog.Items.Trails do
		if not item.isNone then
			local fx = TrailFx.attachModel(model, { quality = "full", reduceMotion = false })
			fx:set(item)
			fx:setSpeed(1)
			local full = fx:stats()
			local tier = TrailFx.tierOf(item)
			local points = Exhausts[CAR].points
			expect(
				item.id .. ": builds",
				full.emitters + full.beams + full.ribbons > 0,
				string.format("%d layers", full.emitters + full.beams + full.ribbons)
			)
			expect(
				item.id .. ": exhaust points from the anchors",
				#fx:exhausts() == (if item.key == "drift" then 2 else #points),
				tostring(#fx:exhausts())
			)
			expect(
				item.id .. ": under the tier cap",
				full.alive <= TrailFx.CAP[tier] + 0.5,
				string.format("%.0f <= %d", full.alive, TrailFx.CAP[tier])
			)
			expect(
				item.id .. ": has a core (or smoke from the wheels) and a ribbon",
				(full.beams > 0 or item.key == "drift") and full.ribbons > 0
			)
			local layers = full.emitters + full.beams + full.ribbons + full.sounds + full.glows
			local entry = byTier[tier] or { alive = 0, layers = 0 }
			entry.alive = math.max(entry.alive, full.alive)
			entry.layers = math.max(entry.layers, layers)
			byTier[tier] = entry
			if tier >= 4 then
				expect(item.id .. ": Epic and up has road glow and a loop", full.glows >= 1 and full.sounds >= 1)
			else
				expect(item.id .. ": below Epic has no glow or loop", full.glows == 0 and full.sounds == 0)
			end
			fx:setQuality("phone")
			local phone = fx:stats()
			expect(
				item.id .. ": phone quality is about half",
				full.alive == 0 or phone.alive <= full.alive * 0.6,
				string.format("%.0f vs %.0f", phone.alive, full.alive)
			)
			fx:setQuality("low")
			local low = fx:stats()
			expect(
				item.id .. ": low quality has no particles, glow or loop",
				low.emitters == 0 and low.glows == 0 and low.sounds == 0
			)
			fx:setQuality("full")
			fx:setReduceMotion(true)
			local calm = fx:stats()
			expect(
				item.id .. ": Reduce Motion halves the particles",
				full.alive == 0 or calm.alive <= full.alive * 0.6,
				string.format("%.0f vs %.0f", calm.alive, full.alive)
			)
			fx:destroy()
		end
	end
	-- each tier is a visible step up: more layers than the tier below
	for tier = 2, 6 do
		local lower, this = byTier[tier - 1], byTier[tier]
		if lower and this then
			expect(
				"tier " .. tier .. " has more layers than tier " .. (tier - 1),
				this.layers > lower.layers,
				string.format("%d vs %d", this.layers, lower.layers)
			)
		end
	end
	-- MATCH MY PAINT
	for _, id in { "neon_ribbon", "comet_tail", "drift_smoke" } do
		local item = Catalog.byId("Trails", id)
		local fx = TrailFx.attachModel(model, { quality = "full" })
		expect(id .. ": supports match-paint", TrailFx.supportsMatchPaint(item))
		fx:set(item)
		local plain = fx:stats()
		fx:setMatchPaint(Color3.fromRGB(255, 0, 255))
		local matched = fx:stats()
		expect(
			id .. ": match-paint rebuilds with the same layers",
			plain.emitters == matched.emitters and plain.beams == matched.beams
		)
		fx:destroy()
	end
	expect("lightning does not allow match-paint", not TrailFx.supportsMatchPaint(Catalog.byId("Trails", "lightning")))
	-- nothing left behind
	holder:Destroy()
	local leftover = #workspace:GetDescendants() - before
	expect("no road glow or other instance left behind", leftover == 0, tostring(leftover))
	return lines
end

return TrailSelfTest
