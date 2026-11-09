--!strict
-- PaintAudit (Round 8, C-04, V-02): "paint only on paint" for every car. For each of the 108 showroom models (27 cars x Normal, Gold,
-- Diamond, Rainbow) it paints a loud test colour (pure magenta), then a gradient, an animated paint and Galaxy, through the real
-- BodyPaint path, and reports what changed:
--   * parts: every part of the car is read before and after; the only thing that may change is the new paint shell. A wheel, tyre,
--     rim, light, glass, grille, plate, sign or roof-rack part that changes is flagged (by its name, material and transparency).
--   * regions: the drawn paint is read back from the shell's image and counted by the mask's region label (body, glass, light,
--     tyre or rim, trim, interior, other). Any painted pixel on a non-body label is flagged.
--   * quality: the painted share must be sane (a mask that paints almost nothing or almost everything is flagged), the paint must
--     really be magenta (no colour leaking from the texture), and it must have no specks under 12 texels (ragged edges).
-- Zero flags is the pass. Run it in Studio during Play, from a Server execute_luau (execute_luau cannot require game modules in this
-- Studio, so PaintAuditHook.server.luau runs it on request):
--   game.ServerStorage:SetAttribute("RunPaintAudit", "all")    -- or "Putter,Zip" (full model names)
--   -- wait for game.ServerStorage:GetAttribute("PaintAuditState") == "done", then read game.ServerStorage.CarHopPaintAuditResult.Value
-- (or require this module from a Script: require(...PaintAudit).run({ only = {...}, paints = {...}, verbose = true }))
-- The region labels are the curated mask data (tools/paint-masks builds them from each car's own texture, checked by eye on the
-- contact sheets in review/round8/frames/paint-audit); the audit proves the code path respects them on every car and edition.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)

local PaintAudit = {}

type BodyPaintApi = {
	new: (body: MeshPart, carName: string) -> any?,
	labels: (carName: string) -> (buffer?, number),
	supported: (carName: string) -> boolean,
	bodyParts: (model: Model) -> { MeshPart },
	LABEL_NAMES: { [number]: string },
}

export type CarRow = {
	model: string,
	paint: string,
	painted: number, -- texels with paint
	share: number, -- painted share of the 256 x 256 texture, 0 to 100
	regions: { [string]: number }, -- painted texels per region label name
	changedParts: { string },
	flags: { string },
}

export type Report = {
	lines: { string },
	rows: { CarRow },
	models: number,
	paints: number,
	flags: number,
}

local MAGENTA: Catalog.Item = {
	id = "audit_magenta",
	name = "Audit Magenta",
	tab = "Paint",
	tier = "solid",
	price = 0,
	kind = "solid",
	colours = { Color3.new(1, 0, 1) },
	render = "car",
	note = "Audit colour: pure magenta.",
}

local DEFAULT_PAINTS = { "magenta", "citrus_split", "aurora", "galaxy_swirl" }

-- the kind of a part, from its name: the never-paint kinds are what the audit protects
local KINDS: { { kind: string, words: { string } } } = {
	{ kind = "glass", words = { "glass", "window", "windshield", "windscreen", "screen" } },
	{ kind = "light", words = { "light", "lamp", "beam", "indicator" } },
	{ kind = "tyre", words = { "tyre", "tire", "wheel", "rim", "hub" } },
	{
		kind = "trim",
		words = { "grille", "chrome", "trim", "bumper", "plate", "sign", "rack", "pizza", "mirror", "exhaust" },
	},
}

local function kindOf(name: string): string
	local lower = string.lower(name)
	for _, k in KINDS do
		for _, word in k.words do
			if string.find(lower, word, 1, true) then
				return k.kind
			end
		end
	end
	return "body"
end

local function findBodyPaint(): ModuleScript?
	local node: Instance? = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	for _, name in { "Client", "UI", "Prototype", "Style", "BodyPaint" } do
		node = if node then node:FindFirstChild(name) else nil
	end
	if node and node:IsA("ModuleScript") then
		return node
	end
	return nil
end

local function snapshotParts(model: Model): { [BasePart]: string }
	local out: { [BasePart]: string } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local tex = if d:IsA("MeshPart") then tostring(d.TextureContent) else ""
			out[d] = string.format(
				"%s|%s|%.3f|%.3f|%s|%s",
				tostring(d.Color),
				tostring(d.Material),
				d.Transparency,
				d.Reflectance,
				tex,
				tostring(d.CFrame)
			)
		end
	end
	return out
end

-- painted texels that are alone or in a clump under `limit` texels (ragged edges); 4-connected
local function specks(alpha: { boolean }, n: number, limit: number): number
	local seen: { boolean } = {}
	local count = 0
	for start = 0, n * n - 1 do
		if alpha[start] and not seen[start] then
			local stack = { start }
			seen[start] = true
			local size = 0
			while #stack > 0 do
				local i = table.remove(stack) :: number
				size += 1
				local x, y = i % n, i // n
				if x > 0 and alpha[i - 1] and not seen[i - 1] then
					seen[i - 1] = true
					table.insert(stack, i - 1)
				end
				if x < n - 1 and alpha[i + 1] and not seen[i + 1] then
					seen[i + 1] = true
					table.insert(stack, i + 1)
				end
				if y > 0 and alpha[i - n] and not seen[i - n] then
					seen[i - n] = true
					table.insert(stack, i - n)
				end
				if y < n - 1 and alpha[i + n] and not seen[i + n] then
					seen[i + n] = true
					table.insert(stack, i + n)
				end
			end
			if size < limit then
				count += 1
			end
		end
	end
	return count
end

local function paintItem(id: string): Catalog.Item?
	if id == "magenta" then
		return MAGENTA
	end
	return Catalog.byId("Paint", id)
end

function PaintAudit.run(options: { paints: { string }?, only: { string }?, verbose: boolean? }?): Report
	local opts = options or {}
	local report: Report = { lines = {}, rows = {}, models = 0, paints = 0, flags = 0 }
	local lines = report.lines
	local module = findBodyPaint()
	if not module then
		table.insert(
			lines,
			"FLAG: BodyPaint module not found under StarterPlayer.StarterPlayerScripts.Client.UI.Prototype.Style"
		)
		report.flags += 1
		return report
	end
	local BodyPaint = require(module :: any) :: BodyPaintApi
	local folder = ReplicatedStorage:FindFirstChild("Cars")
	if not folder then
		table.insert(lines, "FLAG: ReplicatedStorage.Cars not found")
		report.flags += 1
		return report
	end
	local wanted: { [string]: boolean } = {}
	for _, name in opts.only or {} do
		wanted[name] = true
	end
	local filtered = opts.only ~= nil
	local models: { Model } = {}
	for _, c in folder:GetChildren() do
		if c:IsA("Model") and (not filtered or wanted[c.Name]) then
			table.insert(models, c)
		end
	end
	table.sort(models, function(a, b)
		return a.Name < b.Name
	end)
	for _, original in models do
		report.models += 1
		local model = original:Clone()
		local parts = BodyPaint.bodyParts(model)
		local body = parts[1]
		local labels, size = BodyPaint.labels(model.Name)
		if not body or not labels then
			local why = if not body then "no paintable body part" else "no paint mask"
			table.insert(lines, string.format("FLAG %-22s %s", model.Name, why))
			report.flags += 1
			model:Destroy()
			continue
		end
		for _, paintId in opts.paints or DEFAULT_PAINTS do
			local item = paintItem(paintId)
			if not item then
				table.insert(lines, "FLAG: unknown paint " .. paintId)
				report.flags += 1
				continue
			end
			report.paints += 1
			local row: CarRow = {
				model = model.Name,
				paint = paintId,
				painted = 0,
				share = 0,
				regions = {},
				changedParts = {},
				flags = {},
			}
			local before = snapshotParts(model)
			local painter = BodyPaint.new(body, model.Name)
			if not painter then
				table.insert(row.flags, "no painter")
			else
				painter:set(item)
				-- parts: nothing that existed may change; the shell is the only addition
				local after = snapshotParts(model)
				for part, was in before do
					if after[part] ~= was then
						table.insert(row.changedParts, part.Name)
						table.insert(row.flags, string.format("part %s changed (%s)", part.Name, kindOf(part.Name)))
					end
				end
				local added = 0
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and before[d] == nil then
						added += 1
						if d.Name ~= "BodyPaint" then
							table.insert(row.flags, "unexpected new part " .. d.Name)
						end
					end
				end
				if added ~= 1 then
					table.insert(row.flags, string.format("expected one paint shell, found %d", added))
				end
				-- regions: read the drawn paint back and count it by label
				local pixels = painter:snapshot() :: buffer?
				if not pixels then
					table.insert(row.flags, "could not read the paint image")
				else
					local solid = paintId == "magenta"
					local alpha: { boolean } = {}
					local offColour = 0
					for i = 0, size * size - 1 do
						local a = buffer.readu8(pixels, i * 4 + 3)
						if a > 0 then
							alpha[i] = true
							row.painted += 1
							local label = buffer.readu8(labels, i)
							local name = if label >= 1 and label <= 6
								then "body"
								else (BodyPaint.LABEL_NAMES[label] or "unlabelled")
							row.regions[name] = (row.regions[name] or 0) + 1
							if solid then
								local r, g, b =
									buffer.readu8(pixels, i * 4),
									buffer.readu8(pixels, i * 4 + 1),
									buffer.readu8(pixels, i * 4 + 2)
								if g > 12 or math.abs(r - b) > 12 then
									offColour += 1
								end
							end
						end
					end
					row.share = row.painted / (size * size) * 100
					for name, count in row.regions do
						if name ~= "body" then
							table.insert(row.flags, string.format("%d painted texels on %s", count, name))
						end
					end
					if row.share < 8 or row.share > 90 then
						table.insert(
							row.flags,
							string.format("painted share %.1f%% is not a believable body", row.share)
						)
					end
					if offColour > 0 then
						table.insert(row.flags, string.format("%d painted texels are not magenta", offColour))
					end
					if solid then
						-- the mask is the same for every paint, so the speck check runs once, on the magenta pass
						local small = specks(alpha, size, 12)
						if small > 0 then
							table.insert(row.flags, string.format("%d ragged specks (under 12 texels)", small))
						end
					end
				end
				painter:destroy()
			end
			report.flags += #row.flags
			table.insert(report.rows, row)
			if #row.flags > 0 then
				table.insert(
					lines,
					string.format("FLAG %-22s %-13s %s", model.Name, paintId, table.concat(row.flags, "; "))
				)
			elseif opts.verbose then
				table.insert(lines, string.format("ok   %-22s %-13s body %.1f%%", model.Name, paintId, row.share))
			end
		end
		model:Destroy()
		task.wait()
	end
	table.insert(
		lines,
		string.format(
			"PAINT AUDIT: %d models, %d paints applied, %d flags -> %s",
			report.models,
			report.paints,
			report.flags,
			if report.flags == 0 then "PASS" else "FAIL"
		)
	)
	return report
end

return PaintAudit
