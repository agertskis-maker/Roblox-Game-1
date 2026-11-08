--!strict
-- DecalAudit (Round 8, C-05): checks that every car's decals sit on its body panels, and builds the contact-sheet scene.
--
-- Run it in Play, on the client (the DecalArt module needs a client): from Studio's execute_luau with the Client datamodel,
--   local Audit = require(game.Players.LocalPlayer.PlayerScripts.Client.UI.Prototype.Style.DecalAudit)
--   local report = Audit.run()      print(report.text)      -- report.failures == 0 when every check passes
--   local sheet = Audit.sheet("Apex", Vector3.new(0, 1000, 0))   -- 3 decals x 2 sides of one car, for the contact sheet
--
-- For each of the 27 cars (ReplicatedStorage.Cars, Normal edition; Gold and Diamond share its mesh) and each side, with three
-- decals (Twin Stripes, Flames, and the number "07"), it checks:
--   1. the car has a panel entry, and the panel lies inside the body's side (length and height) and clear of every wheel arch;
--   2. the design, fitted by DecalArt.fit, lies inside the panel (and clear of the arches);
--   3. the picture a Decal really projects (read back from the EditableImage that DecalArt drew): every visible pixel is inside
--      the panel and inside the design's rectangle, so nothing lands on a window, light, arch or door gap outside the panel;
--   4. the mirroring: "07" reads the same way on both sides (never backwards), and flames face the nose on both sides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local DecalPanels = require(ReplicatedStorage.Shared.Style.Anchors.DecalPanels)
local DecalArt = require(script.Parent.DecalArt)

local DecalAudit = {}

local ARCH_GAP = 0.12 -- the arch is a little wider than the tyre, in tyre radii
local ARCH_CLEAR = 0.15 -- studs a panel keeps clear of the arch
local EDGE_CLEAR = 0.1 -- studs a panel keeps inside the body's outline
local PIXEL_SLACK = 1.5 -- picture pixels of rounding allowed at a rectangle's edge

local NUMBER_07: Catalog.Item = {
	id = "audit_number_07",
	name = "Number 07",
	tab = "Decals",
	tier = "simple",
	price = 0,
	key = "number07",
	colours = { Color3.fromRGB(248, 248, 244), Color3.fromRGB(26, 32, 56) },
	render = "car",
	note = "The decal audit's race number.",
}

-- The three decals the contact sheet shows: stripes, flames, "07".
function DecalAudit.items(): { { label: string, item: Catalog.Item } }
	local list = {}
	for _, pair in { { "stripes", "twin_stripes" }, { "flames", "flames" } } do
		local item = Catalog.byId("Decals", pair[2])
		assert(item, "decal " .. pair[2] .. " is missing from the catalog")
		table.insert(list, { label = pair[1], item = item })
	end
	table.insert(list, { label = "07", item = NUMBER_07 })
	return list
end

-- The cars the audit covers: every Normal model in ReplicatedStorage.Cars, by name.
function DecalAudit.cars(): { Model }
	local out: { Model } = {}
	local folder = ReplicatedStorage:WaitForChild("Cars")
	for _, c in folder:GetChildren() do
		if c:IsA("Model") and c:GetAttribute("Variant") == "Normal" then
			table.insert(out, c)
		end
	end
	table.sort(out, function(a: Model, b: Model): boolean
		return a.Name < b.Name
	end)
	return out
end

type Wheel = { z: number, y: number, r: number }

-- The car's wheels and body outline in its own space (origin bottom centre, +X right, -Z nose).
local function measure(model: Model): ({ Wheel }, Vector3, Vector3)
	local frame = model:GetPivot()
	local wheels: { Wheel } = {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if string.find(d.Name, "wheel_geom", 1, true) then
				local p = frame:PointToObjectSpace(d.Position)
				table.insert(wheels, { z = p.Z, y = p.Y, r = math.max(d.Size.Y, d.Size.Z) / 2 })
			elseif d.Name == "body_geom" then
				local cf = frame:ToObjectSpace(d.CFrame)
				local half = d.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local c = cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
							lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
							hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
						end
					end
				end
			end
		end
	end
	return wheels, lo, hi
end

-- Distance from the point (z, y) to the rectangle centred (cz, cy) with half sizes (hz, hy); 0 inside.
local function rectDistance(z: number, y: number, cz: number, cy: number, hz: number, hy: number): number
	local dz = math.max(math.abs(z - cz) - hz, 0)
	local dy = math.max(math.abs(y - cy) - hy, 0)
	return math.sqrt(dz * dz + dy * dy)
end

-- The rectangle a panel (or a design in it) covers, as the centre and half sizes along the car (z) and up (y).
local function rectOf(panel: CFrame, size: Vector2): (number, number, number, number)
	return panel.Position.Z, panel.Position.Y, size.X / 2, size.Y / 2
end

-- Problems with a rectangle on one side of a car: outside the body's outline, or touching a wheel arch.
local function rectProblems(
	label: string,
	cz: number,
	cy: number,
	hz: number,
	hy: number,
	wheels: { Wheel },
	lo: Vector3,
	hi: Vector3
): { string }
	local problems: { string } = {}
	if
		cz - hz < lo.Z + EDGE_CLEAR
		or cz + hz > hi.Z - EDGE_CLEAR
		or cy - hy < lo.Y + EDGE_CLEAR
		or cy + hy > hi.Y - EDGE_CLEAR
	then
		table.insert(problems, label .. " leaves the body's outline")
	end
	for i, w in wheels do
		local gap = rectDistance(w.z, w.y, cz, cy, hz, hy) - (w.r * (1 + ARCH_GAP) + ARCH_CLEAR)
		if gap < 0 then
			table.insert(problems, string.format("%s is %.2f studs into the arch of wheel %d", label, -gap, i))
		end
	end
	return problems
end

-- The visible pixels of a picture: the box round every pixel that is not see-through, and the average x of their weight.
local function inkOf(image: EditableImage): (number, number, number, number, number)
	local size = image.Size
	local px = image:ReadPixelsBuffer(Vector2.zero, size)
	local w, h = size.X, size.Y
	local minX, minY, maxX, maxY = w, h, -1, -1
	local sumX, sum = 0, 0
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local a = buffer.readu8(px, (y * w + x) * 4 + 3)
			if a > 24 then
				minX, maxX = math.min(minX, x), math.max(maxX, x)
				minY, maxY = math.min(minY, y), math.max(maxY, y)
				sumX += x * a
				sum += a
			end
		end
	end
	return minX, minY, maxX + 1, maxY + 1, if sum > 0 then sumX / sum else 0
end

local function brightAt(image: EditableImage, x: number, y: number): number
	local px = image:ReadPixelsBuffer(Vector2.new(math.floor(x), math.floor(y)), Vector2.one)
	if buffer.readu8(px, 3) < 128 then
		return 0
	end
	return (buffer.readu8(px, 0) + buffer.readu8(px, 1) + buffer.readu8(px, 2)) / 3
end

export type Row = { car: string, ok: boolean, problems: { string } }

-- Runs every check. `only` limits it to the named cars.
function DecalAudit.run(only: { string }?): { text: string, failures: number, rows: { Row }, cars: number }
	local rows: { Row } = {}
	local items = DecalAudit.items()
	local scratch = Instance.new("Folder")
	scratch.Name = "DecalAuditScratch"
	scratch.Parent = workspace
	local failures = 0
	local checked = 0
	for _, model in DecalAudit.cars() do
		if only and not table.find(only, model.Name) then
			continue
		end
		checked += 1
		local problems: { string } = {}
		local panels = DecalPanels[model.Name]
		if not panels then
			table.insert(problems, "no panel entry in Anchors/DecalPanels")
		else
			local wheels, lo, hi = measure(model)
			if #wheels ~= 4 then
				table.insert(problems, "expected 4 wheels, found " .. #wheels)
			end
			-- 1. the panels themselves
			for _, side in { "left", "right" } do
				local cf = if side == "left" then panels.left else panels.right
				local cz, cy, hz, hy = rectOf(cf, panels.size)
				for _, p in rectProblems(side .. " panel", cz, cy, hz, hy, wheels, lo, hi) do
					table.insert(problems, p)
				end
				if (cf.Position.X > 0) ~= (side == "right") then
					table.insert(problems, side .. " panel is on the wrong side of the car")
				end
				if (cf.ZVector.X > 0.99) ~= (side == "right") then
					table.insert(problems, side .. " panel does not face out of the car")
				end
			end
			-- 2 to 4. each decal, on a display copy of the car
			local copy = model:Clone()
			copy.Parent = scratch
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			local body = copy:FindFirstChild("body_geom", true) :: BasePart?
			if not body then
				table.insert(problems, "no body_geom")
			else
				for _, entry in items do
					local label, item = entry.label, entry.item
					local fit = DecalArt.fit(item, panels.size)
					if not fit then
						table.insert(problems, label .. ": design cannot be drawn")
						continue
					end
					if fit.X > panels.size.X + 1e-3 or fit.Y > panels.size.Y + 1e-3 then
						table.insert(problems, label .. " is bigger than the panel")
					end
					for _, side in { "left", "right" } do
						local cf = if side == "left" then panels.left else panels.right
						for _, p in
							rectProblems(
								label .. " " .. side,
								cf.Position.Z,
								cf.Position.Y,
								fit.X / 2,
								fit.Y / 2,
								wheels,
								lo,
								hi
							)
						do
							table.insert(problems, p)
						end
					end
					local holder = DecalArt.attach(body, copy)
					holder:set(item)
					local layout = holder:layout()
					if next(layout) == nil then
						table.insert(
							problems,
							label .. ": no panel-mode decal was made (fell back to the automatic fit)"
						)
					end
					local centres: { [string]: number } = {}
					for side, l in layout do
						local minX, minY, maxX, maxY, mass = inkOf(l.image)
						centres[side] = mass
						local p, d = l.panel, l.decal
						if
							minX < p.x0 - PIXEL_SLACK
							or maxX > p.x1 + PIXEL_SLACK
							or minY < p.y0 - PIXEL_SLACK
							or maxY > p.y1 + PIXEL_SLACK
						then
							table.insert(problems, string.format("%s %s: drawing leaves the panel", label, side))
						end
						if
							minX < d.x0 - PIXEL_SLACK
							or maxX > d.x1 + PIXEL_SLACK
							or minY < d.y0 - PIXEL_SLACK
							or maxY > d.y1 + PIXEL_SLACK
						then
							table.insert(
								problems,
								string.format("%s %s: drawing leaves its own rectangle", label, side)
							)
						end
						if maxX <= minX then
							table.insert(problems, string.format("%s %s: nothing is drawn", label, side))
						end
						if item.key == "number07" then
							-- the left edge of the "7" (right digit) has no stroke at mid height; a backwards "07" has one there
							local w, h = d.x1 - d.x0, d.y1 - d.y0
							local x = d.x0 + w * (132 - 98) / 60
							local y = d.y0 + h * 0.5
							if brightAt(l.image, x, y) > 128 then
								table.insert(problems, string.format("%s %s: the number reads backwards", label, side))
							end
						end
					end
					if item.key == "flames" and centres.left and centres.right and layout.left and layout.right then
						-- flames are heaviest at the nose: the left side's nose is at the picture's left, the right side's at its right
						local l, r = layout.left.decal, layout.right.decal
						if centres.left >= (l.x0 + l.x1) / 2 then
							table.insert(problems, "flames left: heavy end is at the tail")
						end
						if centres.right <= (r.x0 + r.x1) / 2 then
							table.insert(problems, "flames right: heavy end is at the tail")
						end
					end
					holder:destroy()
				end
			end
			copy:Destroy()
		end
		local ok = #problems == 0
		if not ok then
			failures += 1
		end
		table.insert(rows, { car = model.Name, ok = ok, problems = problems })
	end
	scratch:Destroy()
	local lines = {}
	for _, row in rows do
		table.insert(
			lines,
			string.format("%-14s %s", row.car, if row.ok then "ok" else "FAIL: " .. table.concat(row.problems, "; "))
		)
	end
	table.insert(lines, string.format("%d cars checked, %d failed", checked, failures))
	return { text = table.concat(lines, "\n"), failures = failures, rows = rows, cars = checked }
end

-- The contact-sheet scene for one car: three decals (stripes, flames, "07") by two sides, around `origin`. The left sides are in the
-- top row, the right sides in the bottom row; look at them from +X (camera at origin + (distance, 0, 0) looking -X). Each cell has a
-- label above it. Returns the folder (destroy it when done), the camera CFrame and the field of view to use.
function DecalAudit.sheet(carName: string, origin: Vector3): (Folder, CFrame, number)
	local cars = ReplicatedStorage:WaitForChild("Cars")
	local template = cars:FindFirstChild(carName)
	assert(template and template:IsA("Model"), "no car called " .. carName)
	local folder = Instance.new("Folder")
	folder.Name = "DecalSheet_" .. carName
	folder.Parent = workspace
	for row, side in { "left", "right" } do
		for col, entry in DecalAudit.items() do
			local car = template:Clone()
			for _, d in car:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				elseif d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			-- the right side faces the camera at +X as built; turn the car round to show its left side
			local spin = if side == "left" then CFrame.Angles(0, math.pi, 0) else CFrame.identity
			local at = origin + Vector3.new(0, (2 - row) * 12, (2 - col) * 15)
			car:PivotTo(CFrame.new(at) * spin)
			car.Parent = folder
			local body = car:FindFirstChild("body_geom", true) :: BasePart?
			if body then
				DecalArt.attach(body, car):set(entry.item)
			end
			local tag = Instance.new("Part")
			tag.Name = "Label"
			tag.Anchored = true
			tag.CanCollide = false
			tag.Transparency = 1
			tag.Size = Vector3.one
			tag.Position = at + Vector3.new(6, 8.2, 0)
			tag.Parent = car
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(300, 34)
			gui.AlwaysOnTop = true
			gui.Adornee = tag
			gui.Parent = tag
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.TextColor3 = Color3.new(1, 1, 1)
			text.TextStrokeTransparency = 0
			text.TextSize = 24
			text.Font = Enum.Font.GothamBold
			text.Text = string.format("%s  %s  %s", carName, string.upper(side), entry.label)
			text.Parent = gui
		end
	end
	local centre = origin + Vector3.new(0, 6, 0)
	return folder, CFrame.lookAt(centre + Vector3.new(170, 0, 0), centre), 11
end

return DecalAudit
