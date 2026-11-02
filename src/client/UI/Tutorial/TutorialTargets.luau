--!strict
-- TutorialTargets: finds the GuiObject the pointing hand should mark (BRIEF M11-04), by a stable key, at the moment it is
-- needed. A panel that opens later (the Raceway card, the results screen) is found when it appears, and a target that is
-- hidden returns nil, so the hand never points at an empty spot.
--
-- Order for every key: options.uiTargets[key]() first (the lead or a fixture can name the exact object), then the default
-- finder below. Keys: ShopButton, ResultsHome, UpgradeBuy, Park, Hop.
--
--   Targets.resolve(key, ctx, options) -> GuiObject?
--   Targets.isShown(gui) -> boolean          visible, on screen, every ancestor visible and enabled
--
-- Default finders (all best effort, never an error):
--   ShopButton   options.menu:getButton("Shop") (a LeftMenu instance), else a GuiObject named "Shop" under ctx.layer
--   ResultsHome  options.run:getResultsButton() (the beta's Retry on Brian R's results card, or a Home button), else a
--                GuiObject named "GoHome" (the HUD playground results card)
--   UpgradeBuy   PlayerGui.Lane3RacewayPanel, only when its card says "RACEWAY UPGRADES": the descendant named "Buy"
--   Park / Hop   no default (the beta has neither control); only options.uiTargets can supply them

local Players = game:GetService("Players")

local Targets = {}

export type Options = {
	uiTargets: { [string]: () -> GuiObject? }?,
	menu: any?,
	run: any?,
}

function Targets.isShown(gui: GuiObject?): boolean
	if not gui or not gui:IsDescendantOf(game) then
		return false
	end
	if gui.AbsoluteSize.X <= 0 or gui.AbsoluteSize.Y <= 0 then
		return false
	end
	local node: Instance? = gui
	while node and node ~= game do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("LayerCollector") and not (node :: any).Enabled then
			return false
		end
		node = node.Parent
	end
	return true
end

local function findNamed(root: Instance?, name: string): GuiObject?
	if not root then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d.Name == name and d:IsA("GuiObject") then
			return d
		end
	end
	return nil
end

local function raceway(): GuiObject?
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChild("PlayerGui")
	local panel = gui and gui:FindFirstChild("Lane3RacewayPanel")
	if not panel then
		return nil
	end
	local isUpgrade = false
	for _, d in panel:GetDescendants() do
		if d:IsA("TextLabel") and string.upper(d.Text) == "RACEWAY UPGRADES" then
			isUpgrade = true
			break
		end
	end
	if not isUpgrade then
		return nil
	end
	for _, d in panel:GetDescendants() do
		if d.Name == "Buy" and d:IsA("GuiButton") then
			return d
		end
	end
	return findNamed(panel, "Buy")
end

function Targets.resolve(key: string, ctx: { layer: Frame }, options: Options?): GuiObject?
	local o: Options = options or {}
	local custom = o.uiTargets and o.uiTargets[key]
	if custom then
		local ok, found = pcall(custom)
		if ok and found and Targets.isShown(found) then
			return found
		end
		if ok and found == nil then
			return nil
		end
	end
	local found: GuiObject? = nil
	if key == "ShopButton" then
		local menu = o.menu
		if menu and type(menu.getButton) == "function" then
			local ok, button = pcall(function()
				return menu:getButton("Shop")
			end)
			if ok then
				found = button
			end
		end
		if not found then
			found = findNamed(ctx.layer, "Shop")
		end
	elseif key == "ResultsHome" then
		local run = o.run
		if run and type(run.getResultsButton) == "function" then
			local ok, button = pcall(function()
				return run:getResultsButton()
			end)
			if ok then
				found = button
			end
		end
		if not found then
			found = findNamed(ctx.layer.Parent, "GoHome")
		end
	elseif key == "UpgradeBuy" then
		found = raceway()
	end
	if found and Targets.isShown(found) then
		return found
	end
	return nil
end

return Targets
