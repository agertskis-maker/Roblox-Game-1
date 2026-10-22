--!strict
-- Keeps the island's planning overlay out of play (Lane 3). The greybox preview's Helpers folder
-- (plot reservations, sector rays, viewing corridors and their labels) is a Studio edit-mode
-- tool, drawn only on request (Hub/HubBuild.showHelpers). If a saved place still holds it, this
-- removes it on this client as soon as it appears, so it never shows during Play or in a
-- published game. The reservation and corridor data stay in Layout; nothing else is touched.

local Workspace = game:GetService("Workspace")

local ROOT_NAME = "Lane3_IslandPreview"

local function watch(root: Instance)
	local existing = root:FindFirstChild("Helpers")
	if existing then
		existing:Destroy()
	end
	root.ChildAdded:Connect(function(child)
		if child.Name == "Helpers" then
			child:Destroy()
		end
	end)
end

local root = Workspace:FindFirstChild(ROOT_NAME)
if root then
	watch(root)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == ROOT_NAME then
		watch(child)
	end
end)
