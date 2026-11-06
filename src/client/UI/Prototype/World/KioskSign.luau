--!strict
-- KioskSign: the floating sign over an upgrade kiosk (Round 7, H-03). Lane 3, presentation only. Three lines readable from
-- 20 studs: the kiosk's name, "now -> next" and the price ("MAX LEVEL" at the top). The numbers come from a `read` function
-- the kiosk gives (save attributes and the PREVIEW prices), read twice a second while the sign is on screen, so a purchase
-- shows on the sign without wiring every signal. The sign is sized in studs, so it reads the same on every screen.
--
--   KioskSign.attach(part, { title, colour?, height?, read }) -> () -> ()   returns a remover

local RunService = game:GetService("RunService")

local KioskSign = {}

local NAVY = Color3.fromRGB(22, 34, 72)
local CREAM = Color3.fromRGB(255, 246, 224)
local MINT = Color3.fromRGB(128, 236, 170)
local INK = Color3.fromRGB(10, 14, 32)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

export type Options = {
	title: string,
	colour: Color3?,
	height: number?, -- studs above the part's centre (default 8)
	read: () -> (string, string?), -- "LEVEL 3 -> 4", "$1.2K" (nil price: at the top)
}

type Sign = { gui: BillboardGui, step: TextLabel, price: TextLabel, read: () -> (string, string?) }

local signs: { [Sign]: boolean } = {}
local clock = 0

local function label(parent: Instance, text: string, y: number, h: number, colour: Color3, name: string): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.05, y)
	t.Size = UDim2.fromScale(0.9, h)
	t.FontFace = FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = colour
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Parent = t
	t.Parent = parent
	return t
end

local function refresh(sign: Sign)
	local ok, step, price = pcall(sign.read)
	if not ok then
		return
	end
	sign.step.Text = step
	sign.price.Text = price or "MAX LEVEL"
	sign.price.TextColor3 = if price then MINT else CREAM
end

function KioskSign.attach(part: BasePart, options: Options): () -> ()
	local gui = Instance.new("BillboardGui")
	gui.Name = "Lane3KioskSign"
	gui.Size = UDim2.fromScale(12, 4.8) -- studs (reviewer, 2026-11-05: 9 x 3.6 was too small to read from 20 studs)
	gui.StudsOffset = Vector3.new(0, options.height or 8, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.ResetOnSpawn = false
	gui.Adornee = part
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.BackgroundColor3 = NAVY
	plate.Size = UDim2.fromScale(1, 1)
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = plate
	local ring = Instance.new("UIStroke")
	ring.Color = options.colour or Color3.fromRGB(250, 206, 70)
	ring.Thickness = 4
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = plate
	label(plate, options.title, 0.04, 0.36, options.colour or Color3.fromRGB(250, 206, 70), "Title")
	local sign: Sign = {
		gui = gui,
		step = label(plate, "", 0.4, 0.3, CREAM, "Step"),
		price = label(plate, "", 0.68, 0.28, MINT, "Price"),
		read = options.read,
	}
	refresh(sign)
	gui.Parent = part
	signs[sign] = true
	local function remove()
		signs[sign] = nil
		gui:Destroy()
	end
	gui.Destroying:Once(function()
		signs[sign] = nil
	end)
	return remove
end

RunService.Heartbeat:Connect(function(dt: number)
	clock += dt
	if clock < 0.5 then
		return
	end
	clock = 0
	for sign in signs do
		if sign.gui.Parent then
			refresh(sign)
		end
	end
end)

return KioskSign
