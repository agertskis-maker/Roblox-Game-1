--!strict
-- Avenue boost lanes (Lane 3, build-time visuals). Adam approved the mechanic on 2026-10-21: a
-- glowing white chevron strip down the middle of each plot avenue, one half pointing toward the
-- island centre and the other back toward the plot, read as one paired route. Each half is a flat
-- beam just above the avenue surface (no parts, no collision, no raised edge), broken where a
-- bridge deck crosses the avenue. The client pulses them (Home/Island/EnvironmentMotion) and holds
-- them steady under reduced motion.
--
-- The speed boost itself is NOT built here and is not given to players: movement speed belongs
-- to Lane 1 (Brian R), no shared movement interface exists yet, and the proposed contract waits
-- for approval (vault/design/island-rework.md). BoostLanes.strips() gives the strip geometry that
-- the preview boost in Hub/Preview/WalkTests uses, and that the integrated boost would use.

local AssetIds = require(script.Parent.AssetIds)
local Layout = require(script.Parent.Parent.Layout)

local BoostLanes = {}

local park = Layout.Data.park
local SURFACE_TOP = Layout.SurfaceY + 0.08 -- the avenue strips' top face (measured in Studio)
local LANE_OFFSET = 1.2 -- each half's centre from the avenue centreline
local LANE_WIDTH = 1.8
BoostLanes.HalfWidth = LANE_OFFSET + LANE_WIDTH / 2 -- the whole strip, both halves (2.1)
BoostLanes.ProposedMultiplier = 1.5 -- proposal only (WalkSpeed 16 to 24 while on the strip)
BoostLanes.ProposedLinger = 0.5 -- seconds the boost lasts after stepping off (proposal)

export type Strip = { avenue: number, from: Vector2, to: Vector2 } -- plan points, plot end first

-- The avenues' boost strips in plan coordinates, plot end first, split at bridge decks.
function BoostLanes.strips(): { Strip }
	local out: { Strip } = {}
	for i = 1, 6 do
		local name = "Avenue" .. i
		local avenue
		for _, path in park.paths do
			if (path :: any).kind == name then
				avenue = path
			end
		end
		assert(avenue, "no " .. name)
		local a, b = avenue.points[1], avenue.points[#avenue.points]
		local length = (b - a).Magnitude
		local dir = (b - a) / length
		-- gaps along the avenue where a bridge deck crosses it
		local gaps: { { number } } = {}
		for _, br in park.bridges do
			if br.path == name then
				local t = (br.at - a):Dot(dir)
				table.insert(gaps, { t - br.span / 2 - 1, t + br.span / 2 + 1 })
			end
		end
		table.sort(gaps, function(x, y)
			return x[1] < y[1]
		end)
		local t0 = 2 -- start a little inside the avenue
		for _, g in gaps do
			if g[1] > t0 + 4 then
				table.insert(out, { avenue = i, from = a + dir * t0, to = a + dir * g[1] })
			end
			t0 = g[2]
		end
		if length - 2 > t0 + 4 then
			table.insert(out, { avenue = i, from = a + dir * t0, to = a + dir * (length - 2) })
		end
	end
	return out
end

local function world(p: Vector2, y: number): Vector3
	return Vector3.new(p.X, y, -p.Y)
end

-- A flat attachment: X along the lane, Y across it (a beam that does not face the camera is as
-- wide as its attachments' Y axis).
local function attach(host: BasePart, pos: Vector3, along: Vector3): Attachment
	local a = Instance.new("Attachment")
	local x = along.Unit
	local y = Vector3.new(0, 1, 0):Cross(x).Unit
	a.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, x, y))
	a.Parent = host
	return a
end

function BoostLanes.build(parent: Instance): { strips: number, beams: number }
	local old = parent:FindFirstChild("BoostLanes")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "BoostLanes"
	model:SetAttribute("Preview", "visual only; the speed boost waits for the movement contract")
	local host = Instance.new("Part")
	host.Name = "LaneHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.one
	host.CFrame = CFrame.new()
	host.Parent = model
	local strips = BoostLanes.strips()
	local beams = 0
	for k, s in strips do
		local dir = s.to - s.from
		local side = Vector2.new(-dir.Y, dir.X).Unit
		-- a slate inlay under both halves, so white chevrons read on the light paving
		do
			local along = world(s.to, 0) - world(s.from, 0)
			local a0 = attach(host, world(s.from, SURFACE_TOP + 0.02), along)
			local a1 = attach(host, world(s.to, SURFACE_TOP + 0.02), along)
			local inlay = Instance.new("Beam")
			inlay.Name = string.format("Avenue%dInlay%02d", s.avenue, k)
			inlay.Attachment0 = a0
			inlay.Attachment1 = a1
			inlay.Width0 = 2 * BoostLanes.HalfWidth + 0.5
			inlay.Width1 = inlay.Width0
			inlay.FaceCamera = false
			inlay.Segments = 1
			inlay.Color = ColorSequence.new(Color3.fromRGB(88, 104, 126))
			inlay.Transparency = NumberSequence.new(0.1)
			inlay.LightEmission = 0
			inlay.LightInfluence = 1
			inlay.ZOffset = 0.02
			inlay.Parent = model
			beams += 1
		end
		for _, lane in { { "Inbound", 1 }, { "Outbound", -1 } } do
			local offset = side * LANE_OFFSET * lane[2]
			local p0, p1 = s.from + offset, s.to + offset
			-- the chevrons point from Attachment0 to Attachment1: toward the centre on the inbound
			-- half, back toward the plot on the outbound half
			if lane[1] == "Outbound" then
				p0, p1 = p1, p0
			end
			local along = world(p1, 0) - world(p0, 0)
			local a0 = attach(host, world(p0, SURFACE_TOP + 0.04), along)
			local a1 = attach(host, world(p1, SURFACE_TOP + 0.04), along)
			local b = Instance.new("Beam")
			b.Name = string.format("Avenue%d%s%02d", s.avenue, lane[1], k)
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Texture = AssetIds.Textures.Chevron
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 3.6
			b.TextureSpeed = 0.6
			b.Width0 = LANE_WIDTH
			b.Width1 = LANE_WIDTH
			b.FaceCamera = false
			b.Segments = 1
			b.Color = ColorSequence.new(Color3.fromRGB(246, 250, 255))
			b.Transparency = NumberSequence.new(0.22)
			b.LightEmission = 0.7
			b.LightInfluence = 0.3
			b.Brightness = 1.3
			b.ZOffset = 0.05
			b:SetAttribute("BaseSpeed", 0.6)
			b:SetAttribute("BoostLane", lane[1])
			b:SetAttribute("Avenue", s.avenue)
			b.Parent = model
			beams += 1
		end
	end
	model.Parent = parent
	return { strips = #strips, beams = beams }
end

return BoostLanes
