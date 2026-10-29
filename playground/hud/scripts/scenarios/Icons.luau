--!strict
-- PLAYGROUND ONLY (Lane 3 Round 3, R3-C1 Cash icon band and R3-C2 Hop icon). Specimens for screenshots (the icon at its
-- real HUD pixel size and at 4x, on a bright and a dark panel side by side, plus desaturated copies of the Hop pieces)
-- and PASS / FAIL checks. Nothing here is a game rule; every value is a synthetic fixture played through the preview
-- store. The specimen scenarios build their own panels in the Modal layer (nothing is mounted by the lead) and the
-- sheet stays until "Icons: specimen off" (or the next Icons specimen) removes it; Debris removes it after ten minutes
-- in any case, so a cancelled scenario never leaves it behind for good.
--
--   Icons: Cash specimen               approved CashIcon (Run view) and CashStack (Home line): HUD size, zoom x4
--   Icons: Hop icon specimen           HopCar (the car alone since 2026-10-28) on the Hop face colour: HUD size,
--                                      zoom x4, colour and greyscale
--   Icons: Hop button states specimen  the four button looks (ready, cooldown, no target, no Stamina) at phone size,
--                                      at this screen's HUD size, and in greyscale
--   Icons: Hop arrow matrix specimen   the four Hop arrow candidates (A to D) x the four button looks (ready, no target,
--                                      cooldown, no Stamina) at the REAL button size of this screen, as a small panel over
--                                      whatever is behind it (play it over a Downtown run frame and take the screenshot)
--   Icons: Hop arrow candidates specimen  the four arrows at phone size, at this screen's HUD size and in greyscale
--   Icons: specimen off                removes the sheet
--   Icons: Cash icon geometry          the band crosses the whole bundle; art size and holder size did not change
--   Icons: Icon names and budgets      HopCar drawn, HopFigure gone, frame budgets
--   Icons: Hop arrow candidates        each candidate draws within 40 frames, the shipped constant is None or A to D,
--                                      the car is identical in all of them, the arrows differ, stay inside the face, no
--                                      thin strokes; with None (shipped, Adam 2026-10-28) HopCar is the car alone,
--                                      filling most of the button
--   Icons: Hop arrow states            every candidate keeps the four button looks different; the live button still
--                                      draws "HopCar"
--   Icons: Hop label fit               every state's word fits the 96 px button at 16 px or more
--   Icons: Hop button states           the live button: ready / noTarget / cooldown / noStamina all differ
--   Icons: Hop precedence              the order OutOfStamina > Cooldown > NoTarget > BestTiming > Ready is unchanged
--   Icons: leaks                       specimens and the live button leave nothing behind

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI")
local Prototype = UI:WaitForChild("Prototype")
local Run = Prototype:WaitForChild("Run")
local Arcade = require(Prototype:WaitForChild("Arcade"))
local CashIcon = require(UI:WaitForChild("CurrencyCounter"):WaitForChild("CashIcon"))
local HopButton = require(Run:WaitForChild("HopButton"))
local HopState = require(Run:WaitForChild("HopState"))
local IconGeometry = require(UI:WaitForChild("IconGeometry"))
local Icons2 = require(Prototype:WaitForChild("Icons2"))
local Motion = require(Prototype:WaitForChild("Motion"))
local PreviewTokens = require(Prototype:WaitForChild("PreviewTokens"))
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)

type Host = { [string]: any }

local A = PreviewTokens.Arcade
local ZOOM = 4
local ICON_BUDGET = 40 -- frames per icon (Specimen.luau)
local SPECIMEN_NAME = "IconsSpecimen"
local SPECIMEN_SECONDS = 600
local PAD = 16
local GAP = 24
local CAPTION_HEIGHT = 64 -- three lines of 16 px

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

local function debugOf(host: Host, key: string): { [string]: any }
	local c = comp(host, key)
	return if c and c.getDebugState then c:getDebugState() else {}
end

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s: %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function freshRun(host: Host)
	Motion.setOverride(nil)
	if host.store:get().mode == "Run" then
		host.store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.6)
end

-- Sets (or clears) one run field the store keeps.
local function setRun(host: Host, fields: { [string]: any })
	local run = host.store:get().run
	if not run then
		return
	end
	local merged = table.clone(run) :: any
	for k, v in fields do
		merged[k] = if v == "__nil" then nil else v
	end
	host.store:set("run", merged)
end

local function stamina(value: number?): any
	if value == nil then
		return "__nil"
	end
	return { value = value, max = 10, lowAt = 3, restore = false }
end

-- A two-line word on one log line.
local function flat(text: string): string
	return (string.gsub(text, "\n", " / "))
end

local function count(set: { [any]: boolean }): number
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

-- SPECIMEN SHEETS ----------------------------------------------------------------------------------------------

-- A desaturated copy of everything under `root`: fills, strokes, text and gradients become the grey of the same
-- brightness (Tokens.toGrey). Used to check that nothing depends on colour alone.
local function greyscale(root: Instance)
	local list: { Instance } = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		local g = d :: any
		if d:IsA("GuiObject") then
			g.BackgroundColor3 = Tokens.toGrey(g.BackgroundColor3)
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				g.TextColor3 = Tokens.toGrey(g.TextColor3)
			end
		elseif d:IsA("UIStroke") then
			g.Color = Tokens.toGrey(g.Color)
		elseif d:IsA("UIGradient") then
			local keys: { ColorSequenceKeypoint } = {}
			for _, k in g.Color.Keypoints do
				table.insert(keys, ColorSequenceKeypoint.new(k.Time, Tokens.toGrey(k.Value)))
			end
			g.Color = ColorSequence.new(keys)
		end
	end
end

-- A holder of `design * scale` device px whose content is built at design size and scaled by a UIScale (the way the
-- HUD canvas scales everything: strokes included).
local function scaled(parent: Instance, design: Vector2, scale: number, build: (inner: Frame) -> ()): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Scaled"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(design.X * scale, design.Y * scale)
	holder.Parent = parent
	local inner = Instance.new("Frame")
	inner.Name = "Design"
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromOffset(design.X, design.Y)
	inner.Parent = holder
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = scale
	uiScale.Parent = inner
	build(inner)
	return holder
end

type Cell = {
	design: Vector2,
	scale: number,
	build: (inner: Frame) -> (),
	caption: string,
	grey: boolean?,
}

local function cellWidth(cell: Cell): number
	return math.max(cell.design.X * cell.scale, 150)
end

local function cellHeight(cell: Cell): number
	return cell.design.Y * cell.scale
end

-- The unscaled size of a sheet's content: a title line, then each row of cells with a caption row under it.
local function measure(rows: { { Cell } }): Vector2
	local width, height = 0, 36
	for _, row in rows do
		local rowWidth, rowHeight = 0, 0
		for _, cell in row do
			rowWidth += cellWidth(cell) + GAP
			rowHeight = math.max(rowHeight, cellHeight(cell))
		end
		width = math.max(width, rowWidth - GAP)
		height += rowHeight + CAPTION_HEIGHT + GAP
	end
	return Vector2.new(width, height - GAP)
end

local function label(parent: Instance, text: string, colour: Color3, position: Vector2, size: Vector2): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = Tokens.font()
	t.TextSize = Tokens.TextSize.Minimum
	t.TextColor3 = colour
	t.Text = text
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.Position = UDim2.fromOffset(position.X, position.Y)
	t.Size = UDim2.fromOffset(size.X, size.Y)
	t.Parent = parent
	return t
end

local PALETTES = {
	{ name = "Bright", bg = Color3.fromRGB(240, 246, 252), text = Color3.fromRGB(22, 36, 63) },
	{ name = "Dark", bg = Color3.fromRGB(26, 30, 42), text = Color3.fromRGB(236, 240, 248) },
}

local function clearSpecimen(host: Host)
	for _, child in host.api.layers.Modal:GetChildren() do
		if child.Name == SPECIMEN_NAME then
			child:Destroy()
		end
	end
end

-- Builds the bright and the dark panel side by side, each holding the same rows, and fits them to the device frame.
local function showSpecimen(host: Host, title: string, rows: { { Cell } })
	clearSpecimen(host)
	local safe = host.api.screen.safe.Size
	local needed = measure(rows)
	local fit = math.min(1, (safe.X.Offset / 2 - 2 * PAD) / needed.X, (safe.Y.Offset - 2 * PAD) / needed.Y)
	local root = Instance.new("Frame")
	root.Name = SPECIMEN_NAME
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = host.api.layers.Modal
	Debris:AddItem(root, SPECIMEN_SECONDS)
	for side, palette in PALETTES do
		local panel = Instance.new("Frame")
		panel.Name = "Panel" .. palette.name
		panel.BackgroundColor3 = palette.bg
		panel.BorderSizePixel = 0
		panel.Position = UDim2.fromScale(0.5 * (side - 1), 0)
		panel.Size = UDim2.fromScale(0.5, 1)
		panel.Parent = root
		local content = Instance.new("Frame")
		content.Name = "Content"
		content.BackgroundTransparency = 1
		content.Position = UDim2.fromOffset(PAD, PAD)
		content.Size = UDim2.fromOffset(needed.X, needed.Y)
		content.Parent = panel
		local contentScale = Instance.new("UIScale")
		contentScale.Scale = fit
		contentScale.Parent = content
		label(
			content,
			title .. " on a " .. string.lower(palette.name) .. " background",
			palette.text,
			Vector2.zero,
			Vector2.new(needed.X, 28)
		)
		local y = 36
		for _, row in rows do
			local x, rowHeight = 0, 0
			for _, cell in row do
				local holder = scaled(content, cell.design, cell.scale, cell.build)
				holder.Position = UDim2.fromOffset(x, y)
				if cell.grey then
					greyscale(holder)
				end
				label(
					content,
					cell.caption,
					palette.text,
					Vector2.new(x, y + cellHeight(cell) + 4),
					Vector2.new(cellWidth(cell), CAPTION_HEIGHT)
				)
				x += cellWidth(cell) + GAP
				rowHeight = math.max(rowHeight, cellHeight(cell))
			end
			y += rowHeight + CAPTION_HEIGHT + GAP
		end
	end
	host.log(
		string.format(
			'Icons specimen "%s" shown: content %.0f x %.0f, fitted x%.2f (1.00 = real pixels; pick the Desktop profile if it is below 1)',
			title,
			needed.X,
			needed.Y,
			fit
		)
	)
end

-- The scales a specimen shows: phone size, this screen's HUD size (when it differs), and the zoom.
local function scalesFor(host: Host): { { scale: number, text: string } }
	local hud = host.api.screen:uiScale()
	local list = { { scale = 1, text = "x1 design px (phone size)" } }
	if math.abs(hud - 1) > 0.01 then
		table.insert(list, { scale = hud, text = string.format("x%.2f (this screen's HUD)", hud) })
	end
	table.insert(list, { scale = ZOOM, text = "zoom x" .. ZOOM })
	return list
end

-- CELL BUILDERS ------------------------------------------------------------------------------------------------

local function buildCashApproved(inner: Frame)
	CashIcon.build(inner, Tokens.Color)
end

-- The Home line's art: Icons2 CashStack in a box of the approved icon's size (as CashLine draws it).
local function buildCashStack(inner: Frame)
	local box = Instance.new("Frame")
	box.Name = "CashStackIcon"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(CashIcon.Size.X, CashIcon.Size.Y)
	box.BackgroundTransparency = 1
	box.Parent = inner
	Arcade.icon(box, "CashStack")
end

local HOP_PLATE = Vector2.new(HopButton.iconSizeFor("HopCar") + 12, HopButton.iconSizeFor("HopCar") + 12)

-- The named Hop icon on the button's own face colour, the size it has on the real button.
local function hopIconBuilder(name: string): (Frame) -> ()
	return function(inner: Frame)
		local plate = Instance.new("Frame")
		plate.Name = "Plate"
		plate.Size = UDim2.fromScale(1, 1)
		plate.BackgroundColor3 = Color3.new(1, 1, 1)
		plate.Parent = inner
		Arcade.corner(plate, 12)
		Arcade.outline(plate, "Button")
		local gradient = Instance.new("UIGradient")
		gradient.Color = A.Fill.Home
		gradient.Rotation = 90
		gradient.Parent = plate
		local icon = Instance.new("Frame")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromOffset(HopButton.iconSizeFor(name), HopButton.iconSizeFor(name))
		icon.BackgroundTransparency = 1
		icon.ZIndex = 2
		icon.Parent = plate
		Arcade.icon(icon, name)
	end
end

local buildHopIcon = hopIconBuilder("HopCar")

local HOP_DISPLAYS = {
	{ display = "Ready", cooldown = 0, text = "ready" },
	{ display = "Cooldown", cooldown = 0.6, text = "cooldown" },
	{ display = "NoTarget", cooldown = 0, text = "no target" },
	{ display = "OutOfStamina", cooldown = 0, text = "no Stamina" },
}

-- The Hop arrow candidates (Icons2 "HopCar_A" .. "HopCar_D"; Icons2.HopArrow picks the one HopCar draws) and the four
-- button looks the matrix shows, in the order of the brief.
local HOP_LETTERS = { "A", "B", "C", "D" }
local HOP_ARROW_TEXT: { [string]: string } = {
	A = "tall hop",
	B = "hop and streaks",
	C = "springy kink",
	D = "steep launch",
}
local MATRIX_STATES = {
	{ display = "Ready", cooldown = 0 },
	{ display = "NoTarget", cooldown = 0 },
	{ display = "Cooldown", cooldown = 0.6 },
	{ display = "OutOfStamina", cooldown = 0 },
}
local MATRIX_GAP = 8 -- device px between two faces
local MATRIX_LETTER_WIDTH = 36
local MATRIX_CAPTION_HEIGHT = 60 -- three lines of 16 px
-- What the arrows are measured against: the car inside the icon must never move, and an arrow keeps clear of the face.
local CAR_POSITION = UDim2.fromScale(0.5, 0.675)
local CAR_SIZE = UDim2.fromScale(0.66, 0.66)
local FACE_CLEARANCE = 5 -- design px an arrow keeps from the edge of the button face
local ICON_TOP = 6 -- HopButton puts the icon 6 design px below the top edge of the face
local MIN_STROKE = 4.5 -- design px: the thinnest bar of an arrow at the button's icon size (the lip layer)

-- SPECIMEN SCENARIOS -------------------------------------------------------------------------------------------

local S: { [string]: (Host) -> () } = {}

S["Icons: Cash specimen"] = function(host: Host)
	local rows: { { Cell } } = { {} }
	for _, s in scalesFor(host) do
		table.insert(rows[1], {
			design = CashIcon.Size,
			scale = s.scale,
			build = buildCashApproved,
			caption = "Run view icon, " .. s.text,
		})
	end
	rows[2] = {}
	for _, s in scalesFor(host) do
		table.insert(rows[2], {
			design = CashIcon.Size,
			scale = s.scale,
			build = buildCashStack,
			caption = "Home line icon, " .. s.text,
		})
	end
	showSpecimen(host, "Cash icon", rows)
end

S["Icons: Hop icon specimen"] = function(host: Host)
	local colour: { Cell } = {}
	local grey: { Cell } = {}
	for _, s in scalesFor(host) do
		table.insert(colour, {
			design = HOP_PLATE,
			scale = s.scale,
			build = buildHopIcon,
			caption = "Colour, " .. s.text,
		})
		if s.scale == 1 or s.scale == ZOOM then
			table.insert(grey, {
				design = HOP_PLATE,
				scale = s.scale,
				build = buildHopIcon,
				grey = true,
				caption = "Greyscale, " .. s.text,
			})
		end
	end
	showSpecimen(host, "Hop icon", { colour, grey })
end

S["Icons: Hop button states specimen"] = function(host: Host)
	local size = Vector2.new(HopButton.Size, HopButton.Size + 4)
	local function row(scale: number, grey: boolean, text: string): { Cell }
		local cells: { Cell } = {}
		for _, d in HOP_DISPLAYS do
			table.insert(cells, {
				design = size,
				scale = scale,
				build = function(inner: Frame)
					HopButton.buildSpecimenFace(inner, d.display, d.cooldown)
				end,
				grey = grey,
				caption = d.text .. ", " .. text,
			})
		end
		return cells
	end
	local rows: { { Cell } } = { row(1, false, "x1 (phone size)") }
	local hud = host.api.screen:uiScale()
	if math.abs(hud - 1) > 0.01 then
		table.insert(rows, row(hud, false, string.format("x%.2f (this screen)", hud)))
	end
	table.insert(rows, row(1, true, "greyscale x1"))
	showSpecimen(host, "Hop button looks", rows)
	for _, d in HOP_DISPLAYS do
		local width, fits = HopButton.measureLabel(d.display)
		host.log(
			string.format(
				'Icons Hop word for %s: "%s" is %.1f px wide, fits %s',
				d.text,
				flat(HopState.label(d.display)),
				width,
				tostring(fits)
			)
		)
	end
end

-- The four arrow candidates against the four button looks at the REAL button size of this screen (the HUD scale),
-- in a small panel over whatever is behind it, so a Downtown run frame shows through. If the panel does not fit
-- the safe area it is shrunk and the log says by how much.
local function showHopMatrix(host: Host, letters: { string })
	clearSpecimen(host)
	local scale = host.api.screen:uiScale()
	local face = Vector2.new(HopButton.Size, HopButton.Size + 4)
	local cellW, cellH = face.X * scale + MATRIX_GAP, face.Y * scale + MATRIX_GAP
	local needed =
		Vector2.new(MATRIX_LETTER_WIDTH + #MATRIX_STATES * cellW - MATRIX_GAP, #letters * cellH + MATRIX_CAPTION_HEIGHT)
	local safe = host.api.screen.safe
	local fit = math.min(1, safe.Size.X.Offset / (needed.X + 2 * PAD), safe.Size.Y.Offset / (needed.Y + 2 * PAD))
	local root = Instance.new("Frame")
	root.Name = SPECIMEN_NAME
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = host.api.layers.Modal
	Debris:AddItem(root, SPECIMEN_SECONDS)
	local panel = Instance.new("Frame")
	panel.Name = "Matrix"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromOffset(
		safe.Position.X.Offset + safe.Size.X.Offset / 2,
		safe.Position.Y.Offset + safe.Size.Y.Offset / 2
	)
	panel.Size = UDim2.fromOffset(needed.X + 2 * PAD, needed.Y + 2 * PAD)
	panel.BackgroundColor3 = A.Ink
	panel.BackgroundTransparency = 0.3
	panel.BorderSizePixel = 0
	panel.Parent = root
	Arcade.corner(panel, 12)
	local panelScale = Instance.new("UIScale")
	panelScale.Scale = fit
	panelScale.Parent = panel
	local white = Color3.new(1, 1, 1)
	for r, letter in letters do
		local y = PAD + (r - 1) * cellH
		local mark = label(panel, letter, white, Vector2.new(PAD, y), Vector2.new(MATRIX_LETTER_WIDTH, face.Y * scale))
		mark.TextSize = 24
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.TextYAlignment = Enum.TextYAlignment.Center
		for c, state in MATRIX_STATES do
			local holder = scaled(panel, face, scale, function(inner: Frame)
				HopButton.buildSpecimenFace(inner, state.display, state.cooldown, "HopCar_" .. letter)
			end)
			holder.Name = "Hop_" .. letter .. "_" .. HopState.key(state.display)
			holder.Position = UDim2.fromOffset(PAD + MATRIX_LETTER_WIDTH + (c - 1) * cellW, y)
		end
	end
	local profile = host.api.screen:profile().name
	label(
		panel,
		string.format(
			"Real button size x%.2f on %s. Rows: A tall hop, B hop and streaks, C springy kink, D steep launch. Shipped: %s.",
			scale,
			profile,
			tostring(Icons2.HopArrow)
		),
		white,
		Vector2.new(PAD, PAD + #letters * cellH),
		Vector2.new(needed.X, MATRIX_CAPTION_HEIGHT)
	)
	host.log(
		string.format(
			"Icons Hop arrow matrix shown: %d faces at real size x%.2f on %s, fitted x%.2f (1.00 = real pixels; pick a bigger profile if it is below 1)",
			#letters * #MATRIX_STATES,
			scale,
			profile,
			fit
		)
	)
end

S["Icons: Hop arrow matrix specimen"] = function(host: Host)
	showHopMatrix(host, HOP_LETTERS)
end

-- One candidate row at a time: four faces fit every landscape frame at real size (fit 1.00), so these are the native
-- size proof; the full matrix shrinks on phones.
for _, letter in HOP_LETTERS do
	S["Icons: Hop arrow matrix row " .. letter] = function(host: Host)
		showHopMatrix(host, { letter })
	end
end

-- Review clip (round 3 close-out): the LIVE Hop button pressed the way a finger or mouse presses it (the press scale
-- tween, then the intent, which plays the Hop sound), three times while ready, then once each while there is no car
-- and while Stamina is empty, where nothing may play. Uses the button's own press path; no gameplay.
S["Icons: Hop press with sound (review clip)"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.api.setHopTarget(2)
	local hop = comp(host, "hop")
	if not hop then
		host.log("FAIL: Hop press clip: no live Hop button")
		return
	end
	local function press(name: string)
		local scale = hop._press :: UIScale?
		if scale then
			Motion.tween(scale, "press", Motion.info(A.Motion.Press), { Scale = 0.94 })
		end
		host.wait(0.12)
		hop:_intent()
		if scale then
			Motion.tween(scale, "press", Motion.info(A.Motion.Release), { Scale = 1 })
		end
		host.log("Hop press clip: " .. name .. ", intents " .. tostring(hop._intents))
	end
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil" })
	host.wait(1.2)
	for i = 1, 3 do
		press("ready " .. i)
		host.wait(1.1)
	end
	setRun(host, { hop = "Unavailable", hopCooldown01 = 0 })
	host.wait(1)
	press("no car (silent)")
	host.wait(1.2)
	setRun(host, { hop = "Available", stamina = stamina(0) })
	host.wait(1)
	press("no Stamina (silent)")
	host.wait(1.2)
	setRun(host, { hop = "Available", stamina = "__nil" })
	host.wait(0.8)
end
-- The four arrows as bare icons on the button's face colour: phone design size, this screen's HUD size, greyscale.
S["Icons: Hop arrow candidates specimen"] = function(host: Host)
	local function row(scale: number, grey: boolean, text: string): { Cell }
		local cells: { Cell } = {}
		for _, letter in HOP_LETTERS do
			table.insert(cells, {
				design = HOP_PLATE,
				scale = scale,
				build = hopIconBuilder("HopCar_" .. letter),
				grey = grey,
				caption = letter .. " " .. HOP_ARROW_TEXT[letter] .. ", " .. text,
			})
		end
		return cells
	end
	local rows: { { Cell } } = { row(1, false, "x1 (phone size)") }
	local hud = host.api.screen:uiScale()
	if math.abs(hud - 1) > 0.01 then
		table.insert(rows, row(hud, false, string.format("x%.2f (this screen)", hud)))
	end
	table.insert(rows, row(1, true, "greyscale x1"))
	showSpecimen(host, "Hop arrow candidates", rows)
end

S["Icons: specimen off"] = function(host: Host)
	clearSpecimen(host)
	host.api.applyMode()
	host.log("Icons specimen removed")
end

-- CHECKS -------------------------------------------------------------------------------------------------------

S["Icons: Cash icon geometry"] = function(host: Host)
	local g = CashIcon.debugGeometry()
	local band = g.band
	local stackBottom = g.stack.Y
	-- the band goes right round the bundle: from just past the top note's back edge to the lowest bill's edge
	verdict(
		host,
		"Band covers the whole bundle",
		band.y < 0 and math.abs(band.y + band.h - stackBottom) < 0.01 and band.h > g.bill.Y,
		string.format(
			"band from y %.1f for %.1f px; stack ends at %.1f, top note is %.1f tall",
			band.y,
			band.h,
			stackBottom,
			g.bill.Y
		)
	)
	-- Round 2 (revision 4) reference shapes: the band that stopped on the top note. The art and holder sizes must be the same
	local outline, radius = 2, 3
	local shapes: { IconGeometry.Shape } = {
		{ x = 2 * g.fan.X + 1, y = 2 * g.fan.Y + 2, w = g.bill.X, h = g.bill.Y, r = radius },
		{
			x = (g.bill.X - band.w) / 2 - outline,
			y = -2 - outline,
			w = band.w + 2 * outline,
			h = g.bill.Y + 2 * 2 + 2 * outline,
			r = 2 + outline,
		},
	}
	for i = 0, 2 do
		table.insert(shapes, {
			x = i * g.fan.X - outline,
			y = i * g.fan.Y - outline,
			w = g.bill.X + 2 * outline,
			h = g.bill.Y + 2 * outline,
			r = radius + outline,
		})
	end
	local reference = IconGeometry.bounds(shapes, g.stack, g.rotation, g.stackScale)
	local art = CashIcon.ArtSize
	verdict(
		host,
		"Art size unchanged (nothing displaced)",
		math.abs(reference.X - art.X) < 0.01 and math.abs(reference.Y - art.Y) < 0.01,
		string.format(
			"round 2 %.2f x %.2f, now %.2f x %.2f, holder %d",
			reference.X,
			reference.Y,
			art.X,
			art.Y,
			CashIcon.Size.X
		)
	)
	-- the built icon: the band is the top bill's child, centred across it, with a fold line and a hard colour step
	local parent = Instance.new("Frame")
	CashIcon.build(parent, Tokens.Color)
	local top = parent:FindFirstChild("BillTop", true)
	local built = top and top:FindFirstChild("Band") :: Frame?
	local fold = built and built:FindFirstChild("Fold")
	local gradient = built and built:FindFirstChildOfClass("UIGradient")
	local steps = 0
	if gradient then
		local keys = gradient.Color.Keypoints
		for i = 2, #keys do
			if keys[i].Time - keys[i - 1].Time < 0.005 then
				steps += 1
			end
		end
	end
	verdict(
		host,
		"Band built as the top note's child, centred, with a fold and a hard step",
		built ~= nil
			and fold ~= nil
			and built.AnchorPoint.X == 0.5
			and built.Position.X.Scale == 0.5
			and built.Size.Y.Offset == band.h
			and steps == 1,
		string.format(
			"band %s, fold %s, height %s, colour steps %d",
			tostring(built ~= nil),
			tostring(fold ~= nil),
			tostring(built and built.Size.Y.Offset),
			steps
		)
	)
	parent:Destroy()
	-- the Home line's art: one band silhouette drawn over all three bills
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(CashIcon.Size.X, CashIcon.Size.Y)
	local drawn = Icons2.draw(box, "CashStack")
	local art2 = box:FindFirstChild("Art")
	local frames = if art2 then art2:GetAttribute("Frames") else nil
	verdict(
		host,
		"CashStack draws within the frame budget",
		drawn and type(frames) == "number" and frames <= ICON_BUDGET,
		string.format("drawn %s, frames %s of %d", tostring(drawn), tostring(frames), ICON_BUDGET)
	)
	box:Destroy()
end

S["Icons: Icon names and budgets"] = function(host: Host)
	verdict(
		host,
		"HopCar exists and the character icon is gone",
		Icons2.has("HopCar") and not Icons2.has("HopFigure"),
		string.format("HopCar %s, HopFigure %s", tostring(Icons2.has("HopCar")), tostring(Icons2.has("HopFigure")))
	)
	for _, side in { 32, 48, 56, 64 } do
		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromOffset(side, side)
		local drawn = Icons2.draw(holder, "HopCar")
		local art = holder:FindFirstChild("Art")
		local frames = if art then art:GetAttribute("Frames") else nil
		verdict(
			host,
			string.format("HopCar at %d px", side),
			drawn and type(frames) == "number" and frames <= ICON_BUDGET,
			string.format("drawn %s, frames %s of %d", tostring(drawn), tostring(frames), ICON_BUDGET)
		)
		holder:Destroy()
	end
end

-- HOP ARROW CHECKS ---------------------------------------------------------------------------------------------

-- Draws one named icon into a fresh holder (kept off screen): returns whether it drew, the holder and its Art frame.
local function drawIcon(name: string, side: number): (boolean, Frame, Frame?)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(side, side)
	local drawn = Icons2.draw(holder, name)
	return drawn, holder, holder:FindFirstChild("Art") :: Frame?
end

-- What decides how a drawing looks (frames, corners, gradients) as one string, so two drawings can be compared.
-- ZIndex is left out when the trees sit at different depths (the car after one or two arc groups).
local function signature(roots: { Instance }, withZ: boolean): string
	local parts: { string } = {}
	local function add(inst: Instance)
		local o = inst :: any
		if inst:IsA("Frame") then
			table.insert(
				parts,
				string.format(
					"F|%s|%s|%.3f|%s|%.2f|%s",
					tostring(o.Position),
					tostring(o.Size),
					o.Rotation,
					o.BackgroundColor3:ToHex(),
					o.BackgroundTransparency,
					if withZ then tostring(o.ZIndex) else ""
				)
			)
		elseif inst:IsA("UICorner") then
			table.insert(parts, "C|" .. tostring(o.CornerRadius))
		elseif inst:IsA("UIGradient") then
			local colours: { string } = {}
			for _, key in o.Color.Keypoints do
				table.insert(colours, key.Value:ToHex())
			end
			table.insert(parts, string.format("G|%.1f|%s", o.Rotation, table.concat(colours, ",")))
		end
	end
	for _, root in roots do
		add(root)
		for _, d in root:GetDescendants() do
			add(d)
		end
	end
	return table.concat(parts, ";")
end

-- The pieces of an icon that are not the car.
local function arrowRoots(art: Frame): { Instance }
	local roots: { Instance } = {}
	for _, child in art:GetChildren() do
		if child.Name ~= "Car" then
			table.insert(roots, child)
		end
	end
	return roots
end

-- The box (design px, relative to the icon holder) that the arrow's own frames cover, rotation included (the corners of
-- a pill reach a little past its curve, so this is a safe over-estimate), and the thinnest bar (the lip layer is the
-- one frame of a bar with no outline growth or shrink).
local function arrowBox(art: Frame, side: number): (number, number, number, number, number)
	local x0, y0, x1, y1, thin = math.huge, math.huge, -math.huge, -math.huge, math.huge
	for _, child in arrowRoots(art) do
		if child:IsA("Frame") then
			local f = child :: Frame
			local cx = f.Position.X.Scale * side + f.Position.X.Offset
			local cy = f.Position.Y.Scale * side + f.Position.Y.Offset
			local w = f.Size.X.Scale * side + f.Size.X.Offset
			local h = f.Size.Y.Scale * side + f.Size.Y.Offset
			local angle = math.rad(f.Rotation)
			local cos, sin = math.cos(angle), math.sin(angle)
			for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
				local lx, ly = corner[1] * w / 2, corner[2] * h / 2
				local px, py = cx + lx * cos - ly * sin, cy + lx * sin + ly * cos
				x0, x1 = math.min(x0, px), math.max(x1, px)
				y0, y1 = math.min(y0, py), math.max(y1, py)
			end
			if f.Size.X.Offset == 0 and f.Size.Y.Offset == 0 then
				thin = math.min(thin, math.min(w, h))
			end
		end
	end
	return x0, y0, x1, y1, thin
end

S["Icons: Hop arrow candidates"] = function(host: Host)
	local selected = Icons2.HopArrow
	local valid = selected == "None"
	for _, letter in HOP_LETTERS do
		if letter == selected then
			valid = true
		end
	end
	verdict(host, "Shipped arrow is None or one of A, B, C, D", valid, "Icons2.HopArrow = " .. tostring(selected))
	local carSigns: { [string]: boolean } = {}
	local arrowSigns: { [string]: boolean } = {}
	for _, letter in HOP_LETTERS do
		local name = "HopCar_" .. letter
		local drawn, holder, art = drawIcon(name, math.round(HopButton.IconSize))
		local side = holder.Size.X.Offset
		local frames = if art then art:GetAttribute("Frames") else nil
		verdict(
			host,
			name .. " draws within the frame budget",
			drawn
				and art ~= nil
				and art:GetAttribute("Icon") == name
				and type(frames) == "number"
				and frames <= ICON_BUDGET,
			string.format("drawn %s, frames %s of %d", tostring(drawn), tostring(frames), ICON_BUDGET)
		)
		if art then
			local car = art:FindFirstChild("Car") :: Frame?
			verdict(
				host,
				name .. " leaves the car where it was",
				car ~= nil and car.Position == CAR_POSITION and car.Size == CAR_SIZE and car.Rotation == 0,
				if car
					then string.format(
						"%s, %s, rotation %.1f",
						tostring(car.Position),
						tostring(car.Size),
						car.Rotation
					)
					else "no Car frame"
			)
			if car then
				carSigns[signature({ car }, false)] = true
			end
			arrowSigns[signature(arrowRoots(art), true)] = true
			local x0, y0, x1, _, thin = arrowBox(art, side)
			local faceLeft = -(HopButton.Size - side) / 2
			local faceRight = side + (HopButton.Size - side) / 2
			verdict(
				host,
				name .. " keeps clear of the button's edge",
				x0 >= faceLeft + FACE_CLEARANCE and x1 <= faceRight - FACE_CLEARANCE and y0 >= FACE_CLEARANCE - ICON_TOP,
				string.format(
					"x %.1f to %.1f of the face's %.1f to %.1f, top %.1f of %.1f (%d px clear needed)",
					x0,
					x1,
					faceLeft,
					faceRight,
					y0,
					-ICON_TOP,
					FACE_CLEARANCE
				)
			)
			verdict(
				host,
				name .. " has no thin strokes",
				thin >= MIN_STROKE,
				string.format("thinnest bar %.2f px at the %d px icon (needs %.1f)", thin, side, MIN_STROKE)
			)
		end
		holder:Destroy()
	end
	-- HopCar itself. "None" (shipped since Adam's 2026-10-28 call): the car alone, nothing else, filling most of the
	-- button. A letter: exactly that candidate, with the same car.
	if selected == "None" then
		local slot = math.round(HopButton.iconSizeFor("HopCar"))
		local drawnH, holderH, artH = drawIcon("HopCar", slot)
		local car = if artH then artH:FindFirstChild("Car") :: Frame? else nil
		local others = if artH then #arrowRoots(artH) else -1
		-- the car drawing spans 0.92 of its box across (Icons2 carShape)
		local carWide = if car then car.Size.X.Scale * 0.92 * slot else 0
		verdict(
			host,
			"HopCar is the car alone, filling most of the button",
			drawnH and car ~= nil and others == 0 and carWide >= 0.7 * HopButton.Size,
			string.format(
				"%d other pieces, car about %.0f px wide of the %d px button in a %d px slot",
				others,
				carWide,
				HopButton.Size,
				slot
			)
		)
		holderH:Destroy()
	else
		local drawnA, holderA, artA = drawIcon("HopCar", math.round(HopButton.IconSize))
		local drawnB, holderB, artB = drawIcon("HopCar_" .. tostring(selected), math.round(HopButton.IconSize))
		if artA then
			local carA = artA:FindFirstChild("Car") :: Frame?
			if carA then
				carSigns[signature({ carA }, false)] = true
			end
		end
		verdict(
			host,
			"HopCar draws the shipped candidate",
			drawnA
				and drawnB
				and artA ~= nil
				and artB ~= nil
				and signature(artA:GetChildren(), true) == signature(artB:GetChildren(), true),
			"HopCar against HopCar_" .. tostring(selected)
		)
		holderA:Destroy()
		holderB:Destroy()
	end
	verdict(
		host,
		"The car is identical in all four candidates (and HopCar when it draws one)",
		count(carSigns) == 1,
		string.format("%d different car drawings (needs 1)", count(carSigns))
	)
	verdict(
		host,
		"The four arrows are different drawings",
		count(arrowSigns) == #HOP_LETTERS,
		string.format("%d different arrows of %d", count(arrowSigns), #HOP_LETTERS)
	)
end

local function faceSignature(body: Frame): string
	local face = body:FindFirstChild("Face") :: Frame
	local fill = face:FindFirstChildOfClass("UIGradient")
	local function shown(name: string): string
		local f = face:FindFirstChild(name) :: GuiObject?
		return if f then tostring(f.Visible) else "none"
	end
	local dim = face:FindFirstChild("Dim") :: Frame?
	local word = face:FindFirstChild("Label") :: TextLabel?
	return table.concat({
		if fill then fill.Color.Keypoints[2].Value:ToHex() else "none",
		shown("Icon"),
		shown("Bolt"),
		shown("Hatch"),
		shown("Slash"),
		if dim then tostring(dim.BackgroundTransparency) else "none",
		if word then word.Text else "none",
	}, "|")
end

-- The icon the face draws in its icon slot ("" when there is none).
local function faceIcon(root: Instance): string
	local slot = root:FindFirstChild("Icon", true)
	local art = if slot then slot:FindFirstChild("Art") else nil
	local name = if art then art:GetAttribute("Icon") else nil
	return if type(name) == "string" then name else ""
end

S["Icons: Hop arrow states"] = function(host: Host)
	local expectedIcon = UDim2.fromOffset(HopButton.IconSize, HopButton.IconSize)
	for _, letter in HOP_LETTERS do
		local name = "HopCar_" .. letter
		local scratch = Instance.new("Frame")
		local looks: { [string]: boolean } = {}
		local slotOk = true
		for _, state in MATRIX_STATES do
			local body = HopButton.buildSpecimenFace(scratch, state.display, state.cooldown, name)
			looks[faceSignature(body)] = true
			local slot = body:FindFirstChild("Icon", true) :: Frame?
			if faceIcon(body) ~= name or slot == nil or slot.Size ~= expectedIcon then
				slotOk = false
			end
		end
		verdict(
			host,
			name .. " keeps the four button looks different",
			count(looks) == #MATRIX_STATES and slotOk,
			string.format(
				"%d different looks of %d, icon slot draws %s at the same size: %s",
				count(looks),
				#MATRIX_STATES,
				name,
				tostring(slotOk)
			)
		)
		scratch:Destroy()
	end
	-- no icon name: the specimen (like the live button) draws HopCar
	local plain = Instance.new("Frame")
	local body = HopButton.buildSpecimenFace(plain, "Ready", 0)
	verdict(host, "A specimen with no icon name draws HopCar", faceIcon(body) == "HopCar", "icon " .. faceIcon(body))
	plain:Destroy()
	-- the live button
	host.api.setSpeed(0)
	freshRun(host)
	local live = comp(host, "hop")
	if live and live.root then
		verdict(
			host,
			"The live Hop button still draws HopCar",
			faceIcon(live.root) == "HopCar",
			"icon " .. faceIcon(live.root)
		)
		local slot = live.root:FindFirstChild("Icon", true) :: Frame?
		local want = HopButton.iconSizeFor("HopCar")
		verdict(
			host,
			"The live Hop icon slot has HopCar's size",
			slot ~= nil and slot.Size == UDim2.fromOffset(want, want),
			string.format("slot %s, wanted %d px", if slot then tostring(slot.Size) else "none", want)
		)
	else
		verdict(host, "Hop button mounted", false, "components.hop is missing")
	end
	host.api.setSpeed(nil)
end

S["Icons: Hop label fit"] = function(host: Host)
	for _, display in HopState.Order do
		local width, fits = HopButton.measureLabel(display)
		verdict(
			host,
			"Word for " .. display,
			fits,
			string.format(
				'"%s" is %.1f px wide; the button has room for %d',
				flat(HopState.label(display)),
				width,
				HopButton.Size - 12
			)
		)
	end
	local live = debugOf(host, "hop")
	if live.labelSize ~= nil then
		verdict(
			host,
			"Live label is at least 16 px",
			live.labelSize >= Tokens.TextSize.Minimum,
			"size " .. tostring(live.labelSize)
		)
	end
end

-- Pure precedence (the same table the button and every target cue follow); nothing here may have moved.
S["Icons: Hop precedence"] = function(host: Host)
	verdict(
		host,
		"Precedence order",
		table.concat(HopState.Order, ">") == "OutOfStamina>Cooldown>NoTarget>BestTiming>Ready",
		table.concat(HopState.Order, ">")
	)
	local cases: { { hop: string, cooldown: number, stamina: number?, expect: string } } = {
		{ hop = "Available", cooldown = 0, expect = "Ready" },
		{ hop = "Timing", cooldown = 0, expect = "BestTiming" },
		{ hop = "Unavailable", cooldown = 0, expect = "NoTarget" },
		{ hop = "Available", cooldown = 1, expect = "Cooldown" },
		{ hop = "Timing", cooldown = 1, expect = "Cooldown" },
		{ hop = "Unavailable", cooldown = 1, expect = "Cooldown" },
		{ hop = "Available", cooldown = 0, stamina = 0, expect = "OutOfStamina" },
		{ hop = "Timing", cooldown = 1, stamina = 0, expect = "OutOfStamina" },
		{ hop = "Unavailable", cooldown = 0, stamina = 0, expect = "OutOfStamina" },
		{ hop = "Timing", cooldown = 0, stamina = 5, expect = "BestTiming" },
	}
	for _, c in cases do
		local run = {
			hop = c.hop,
			hopCooldown01 = c.cooldown,
			stamina = if c.stamina ~= nil then { value = c.stamina, max = 10 } else nil,
		}
		local got = HopState.resolve(run :: any)
		verdict(
			host,
			string.format("%s / cooldown %d / stamina %s", c.hop, c.cooldown, tostring(c.stamina)),
			got == c.expect,
			string.format("expected %s, got %s, key %s", c.expect, got, HopState.key(got))
		)
	end
	verdict(host, "No run reads as NoTarget", HopState.resolve(nil) == "NoTarget", HopState.resolve(nil))
end

S["Icons: Hop button states"] = function(host: Host)
	host.api.setSpeed(0)
	freshRun(host)
	host.api.backdrop.hold(0)
	if not comp(host, "hop") then
		verdict(host, "Hop button mounted", false, "components.hop is missing")
		host.api.setSpeed(nil)
		return
	end
	local cases = {
		{ key = "ready", display = "Ready", hop = "Available", cooldown = 0, st = nil },
		{ key = "noTarget", display = "NoTarget", hop = "Unavailable", cooldown = 0, st = nil },
		{ key = "cooldown", display = "Cooldown", hop = "Available", cooldown = 1, st = nil },
		{ key = "noStamina", display = "OutOfStamina", hop = "Available", cooldown = 0, st = 0 },
	}
	local keys: { [string]: boolean } = {}
	local tints: { [string]: boolean } = {}
	local labels: { [string]: boolean } = {}
	local overlays: { [string]: boolean } = {}
	for _, c in cases do
		setRun(host, { hop = c.hop, hopCooldown01 = c.cooldown, stamina = stamina(c.st) })
		host.wait(0.6) -- past the best-timing filter; the fixture decays a cooldown over 1.5 s, so it still runs here
		local d = debugOf(host, "hop")
		keys[d.stateKey] = true
		tints[d.tint] = true
		labels[d.label] = true
		local overlay = if d.hatched
			then "hatch"
			elseif d.outOfStamina then "bolt"
			elseif d.sweep > 0 then "sweep"
			else "none"
		overlays[overlay] = true
		local overlayOk = (c.key == "ready" and overlay == "none" and d.carIcon == true and d.iconDimmed == false)
			or (c.key == "noTarget" and overlay == "hatch" and d.carIcon == true and d.iconDimmed == true)
			or (c.key == "cooldown" and overlay == "sweep" and d.carIcon == true and d.iconDimmed == true)
			or (c.key == "noStamina" and overlay == "bolt" and d.boltIcon == true and d.carIcon == false)
		verdict(
			host,
			"State " .. c.key,
			d.stateKey == c.key
				and d.label == HopState.label(c.display)
				and overlayOk
				and d.labelFits == true
				and d.labelSize >= Tokens.TextSize.Minimum,
			string.format(
				'key %s, word "%s" at %d px (fits %s), tint #%s, fill %s, overlay %s, sweep %.2f, dimmed %s',
				tostring(d.stateKey),
				flat(tostring(d.label)),
				d.labelSize,
				tostring(d.labelFits),
				tostring(d.tint),
				tostring(d.fillName),
				overlay,
				d.sweep,
				tostring(d.iconDimmed)
			)
		)
	end
	verdict(
		host,
		"Four states, four different looks",
		count(keys) == 4 and count(tints) == 4 and count(labels) == 4 and count(overlays) == 4,
		string.format(
			"keys %d, tints %d, words %d, overlays %d (each needs 4)",
			count(keys),
			count(tints),
			count(labels),
			count(overlays)
		)
	)
	-- the same Stamina and cooldown values together: Stamina outranks the cooldown, and the wedge stays out of it
	setRun(host, { hop = "Available", hopCooldown01 = 1, stamina = stamina(0) })
	host.wait(0.6)
	local both = debugOf(host, "hop")
	verdict(
		host,
		"No Stamina outranks the cooldown, with no wedge",
		both.stateKey == "noStamina" and both.sweep == 0,
		string.format("key %s, sweep %.2f", tostring(both.stateKey), both.sweep)
	)
	-- no target while the cooldown runs: the cooldown outranks it
	setRun(host, { hop = "Unavailable", hopCooldown01 = 1, stamina = "__nil" })
	host.wait(0.6)
	local cooling = debugOf(host, "hop")
	verdict(
		host,
		"Cooldown outranks no target",
		cooling.stateKey == "cooldown" and cooling.sweep > 0,
		string.format("key %s, sweep %.2f", tostring(cooling.stateKey), cooling.sweep)
	)
	-- best timing keeps its gold ring and the plain HOP word
	setRun(host, { hop = "Timing", hopCooldown01 = 0, stamina = "__nil", hopWindowId = "icons-1" })
	host.wait(0.7)
	local best = debugOf(host, "hop")
	verdict(
		host,
		"Best timing keeps the ring and HOP",
		best.stateKey == "bestTiming" and best.ringShown == true and best.label == "HOP",
		string.format(
			"key %s, ring %s, word %s",
			tostring(best.stateKey),
			tostring(best.ringShown),
			tostring(best.label)
		)
	)
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil", hopWindowId = "__nil" })
	host.api.setSpeed(nil)
end

S["Icons: leaks"] = function(host: Host)
	-- specimen faces: build twenty, destroy, nothing is left
	local scratch = Instance.new("Frame")
	for i = 1, 20 do
		HopButton.buildSpecimenFace(scratch, HOP_DISPLAYS[(i - 1) % #HOP_DISPLAYS + 1].display, 0.5)
	end
	local built = #scratch:GetDescendants()
	scratch:Destroy()
	verdict(
		host,
		"Specimen faces build and clean up",
		built > 0 and scratch.Parent == nil,
		"descendants built " .. built
	)
	-- a specimen sheet: one on screen at a time, none after "off"
	S["Icons: Hop icon specimen"](host)
	S["Icons: Hop icon specimen"](host)
	local sheets = 0
	for _, child in host.api.layers.Modal:GetChildren() do
		if child.Name == SPECIMEN_NAME then
			sheets += 1
		end
	end
	clearSpecimen(host)
	local after = 0
	for _, child in host.api.layers.Modal:GetChildren() do
		if child.Name == SPECIMEN_NAME then
			after += 1
		end
	end
	verdict(
		host,
		"One sheet at a time, none after off",
		sheets == 1 and after == 0,
		string.format("on screen %d, after off %d", sheets, after)
	)
	-- the arrow matrix: one panel at a time as well, none after off
	S["Icons: Hop arrow matrix specimen"](host)
	S["Icons: Hop arrow matrix specimen"](host)
	local panels = 0
	for _, child in host.api.layers.Modal:GetChildren() do
		if child.Name == SPECIMEN_NAME then
			panels += 1
		end
	end
	clearSpecimen(host)
	local panelsAfter = 0
	for _, child in host.api.layers.Modal:GetChildren() do
		if child.Name == SPECIMEN_NAME then
			panelsAfter += 1
		end
	end
	verdict(
		host,
		"One arrow matrix at a time, none after off",
		panels == 1 and panelsAfter == 0,
		string.format("on screen %d, after off %d", panels, panelsAfter)
	)
	-- the live button: cycling states must not add instances or connections
	host.api.setSpeed(0)
	freshRun(host)
	if not comp(host, "hop") then
		verdict(host, "Hop button mounted", false, "components.hop is missing")
		host.api.setSpeed(nil)
		return
	end
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil" })
	host.wait(0.8)
	local before = debugOf(host, "hop")
	for i = 1, 12 do
		local k = i % 4
		setRun(host, {
			hop = if k == 1 then "Unavailable" else "Available",
			hopCooldown01 = if k == 2 then 1 else 0,
			stamina = if k == 3 then stamina(0) else "__nil",
		})
		host.wait(0.1)
	end
	setRun(host, { hop = "Available", hopCooldown01 = 0, stamina = "__nil" })
	host.wait(0.6)
	local final = debugOf(host, "hop")
	verdict(
		host,
		"Live button: states add no instances, connections or threads",
		final.instances == before.instances and final.connections == before.connections and final.threads == 0,
		string.format(
			"instances %s -> %s, connections %s -> %s, threads %s",
			tostring(before.instances),
			tostring(final.instances),
			tostring(before.connections),
			tostring(final.connections),
			tostring(final.threads)
		)
	)
	host.api.setSpeed(nil)
end

return S
