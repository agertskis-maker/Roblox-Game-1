--!strict
-- PLAYGROUND ONLY (Lane 3 preview). The developer panel for the HUD playground: device profile,
-- mode, scenario picker, reduced-motion override, reserved-zone diagnostics, Heat variant, reset
-- and hide (for clean captures; everything stays scriptable through _G.Lane3Hud while hidden).
-- It sits outside the virtual device frame and is labelled PREVIEW so it never reads as player UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local DebugPanel = {}
DebugPanel.__index = DebugPanel

local function button(parent: Instance, text: string, order: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = text
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 22)
	b.BackgroundColor3 = Color3.fromRGB(40, 48, 66)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.Text = text
	b.AutoButtonColor = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = b
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

local function header(parent: Instance, text: string, order: number)
	local t = Instance.new("TextLabel")
	t.LayoutOrder = order
	t.Size = UDim2.new(1, 0, 0, 16)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.fromRGB(255, 210, 74)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 11
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = text
	t.Parent = parent
end

function DebugPanel.new(gui: ScreenGui, api: any)
	local self = setmetatable({}, DebugPanel)
	local trove = Trove.new()
	self._trove = trove
	local frame = trove:Add(Instance.new("ScrollingFrame"))
	frame.Name = "Lane3PreviewDebugPanel"
	frame.Position = UDim2.fromOffset(6, 6)
	frame.Size = UDim2.new(0, 170, 1, -12)
	frame.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
	frame.BackgroundTransparency = 0.1
	frame.ScrollBarThickness = 4
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.ZIndex = 100
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 3)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 5)
	pad.PaddingRight = UDim.new(0, 5)
	pad.PaddingTop = UDim.new(0, 5)
	pad.Parent = frame
	local n = 0
	local function nextOrder(): number
		n += 1
		return n
	end
	header(frame, "PREVIEW PLAYGROUND (Studio only)", nextOrder())
	local status = Instance.new("TextLabel")
	status.LayoutOrder = nextOrder()
	status.Size = UDim2.new(1, 0, 0, 30)
	status.BackgroundTransparency = 1
	status.TextColor3 = Color3.fromRGB(200, 210, 230)
	status.Font = Enum.Font.Gotham
	status.TextSize = 10
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = frame
	self._status = status

	header(frame, "Device", nextOrder())
	for _, name in { "Desktop", "PhoneLandscape", "PhonePortrait", "Tablet" } do
		button(frame, name, nextOrder(), function()
			api.setProfile(name)
		end)
	end
	header(frame, "Mode", nextOrder())
	button(frame, "Home", nextOrder(), function()
		api.goHome()
	end)
	button(frame, "Run", nextOrder(), function()
		api.goRun()
	end)
	header(frame, "Options", nextOrder())
	button(frame, "Reduce Motion: toggle", nextOrder(), function()
		local p = game:GetService("Players").LocalPlayer
		local now = p:GetAttribute("Lane3ReducedMotionOverride")
		p:SetAttribute("Lane3ReducedMotionOverride", if now == true then false elseif now == false then nil else true)
	end)
	local zones = false
	button(frame, "Reserved zones: toggle", nextOrder(), function()
		zones = not zones
		api.screen:showReserved(zones)
	end)
	button(frame, "Heat variant: toggle", nextOrder(), function()
		local run = api.components.run
		if run and run.setHeatVariant and run.getDebugState then
			local d = run:getDebugState()
			run:setHeatVariant(if d.heatVariant == "Proposal" then "Approved" else "Proposal")
		end
	end)
	button(frame, "Reset to baseline", nextOrder(), function()
		api.reset()
	end)
	button(frame, "Hide controls", nextOrder(), function()
		self:setHidden(true)
	end)
	header(frame, "Scenarios", nextOrder())
	for _, name in api.scenarios.list do
		button(frame, name, nextOrder(), function()
			api.play(name)
		end)
	end
	frame.Parent = gui
	self._frame = frame
	trove:Add(task.spawn(function()
		while true do
			local failures = 0
			for _ in api.failures do
				failures += 1
			end
			local p = api.screen:profile()
			local reduced = game:GetService("Players").LocalPlayer:GetAttribute("Lane3ReducedMotionOverride")
			status.Text = string.format(
				"%s x%.2f (scale %.2f)\nmode %s  RM %s  fail %d\n%s",
				p.name,
				api.screen:fitScale(),
				api.screen:uiScale(),
				api.store:get().mode,
				tostring(reduced),
				failures,
				api.scenarios.current or "idle"
			)
			task.wait(0.5)
		end
	end))
	local _ = Tokens
	return self
end

function DebugPanel.setHidden(self: any, hidden: boolean)
	self._frame.Visible = not hidden
end

function DebugPanel.destroy(self: any)
	self._trove:Destroy()
end

return DebugPanel
