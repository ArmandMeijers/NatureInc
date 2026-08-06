--!strict
--[[
	LeafResetCleanup.client.luau

	Wipes the leaves already lying on the platform whenever a reset clears
	the player's leaves — BOTH a reset layer and a tree tier-up. Without
	it a player can bank a full platform, reset for the payout, then
	collect the pre-reset leaves into their fresh run. Free income across
	the boundary, and it applies to either kind of reset equally.

	SAFE TO DESTROY THEM FROM OUTSIDE LeafSpawnController. That script's
	Heartbeat loop already prunes its activeLeaves list with
	`if not leaf.Parent then table.remove(...)`, which exists because the
	collect animation destroys the leaf when its tween completes rather
	than when it's collected. Anything else destroying a leaf takes the
	same path. Capacity can read one frame stale, which at worst delays a
	single spawn by a frame.

	It lives in LeafCollection because it's a leaf concern reacting to a
	reset, not a reset concern. Neither reset system needs to know leaves
	exist.

	Location: StarterPlayer/StarterPlayerScripts/LeafCollection/LeafResetCleanup.client.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ResetsModules = Modules:WaitForChild("Resets")
local ResetScheme = require(ResetsModules:WaitForChild("ResetScheme"))
local ResetState = require(ResetsModules:WaitForChild("ResetState"))
local TreeTierConfig = require(Modules:WaitForChild("TreeTierConfig"))
local TreeTierState = require(Modules:WaitForChild("TreeTierState"))

local LEAVES_FOLDER_NAME = "LocalLeaves"

local function clearLeaves()
	local leavesFolder = Workspace:FindFirstChild(LEAVES_FOLDER_NAME)
	if not leavesFolder then
		return
	end
	for _, leaf in leavesFolder:GetChildren() do
		leaf:Destroy()
	end
end

-- Reset layers declare it directly.
ResetState.Performed.Event:Connect(function(resetId: string)
	local entry = ResetScheme.Get(resetId)
	if entry and entry.ClearSpawnedLeaves then
		clearLeaves()
	end
end)

-- Tiers declare it through their Resets list. Read rather than assumed,
-- so a future tier that deliberately spares leaves doesn't wipe the
-- platform anyway.
TreeTierState.TierChanged.Event:Connect(function(newTier: number)
	local tierData = TreeTierConfig[newTier]
	if not tierData or not tierData.Resets then
		return
	end
	for _, path in tierData.Resets do
		if path == "Currency.Leafs" then
			clearLeaves()
			return
		end
	end
end)
