--[[
	BoardLoaderController.client.luau

	Loops over workspace.Boards once at startup (plus anything added
	later). Each board Part carries a "BoardType" attribute; this looks it
	up in the registry below and mounts the matching UI module. Adding a
	new type of physical board later means one line here + a matching
	module in ./Modules — this script itself doesn't change.

	Location: StarterPlayer/StarterPlayerScripts/BoardLoader/BoardLoaderController.client.luau
]]

local Workspace = game:GetService("Workspace")

local modules = script.Parent:WaitForChild("Modules")

local registry: { [string]: any } = {
	TreeTier = require(modules:WaitForChild("TreeTierBoardUI")),
	-- Add future board types here, e.g. Leaderboard = require(modules.LeaderboardBoardUI),
}

local boardsRoot = Workspace:WaitForChild("Boards")

local function mount(boardPart: Instance)
	if not boardPart:IsA("BasePart") then
		return
	end
	local boardType = boardPart:GetAttribute("BoardType")
	local uiModule = boardType and registry[boardType]
	if not uiModule then
		return
	end
	uiModule.Mount(boardPart)
end

for _, boardPart in boardsRoot:GetChildren() do
	mount(boardPart)
end
boardsRoot.ChildAdded:Connect(mount)
