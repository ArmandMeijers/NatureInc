--!strict
--[[
	LeafStatsState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of this player's leaf stats (capacity, spawn interval,
	collection radius, nut chance), all computed server-side and never
	derived locally. Refreshes on a slow poll AND immediately whenever an
	upgrade purchase succeeds — so buying a capacity upgrade takes effect
	right away instead of on the next poll.

	Location: ReplicatedStorage/Modules/LeafStatsState.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeafConfig = require(ReplicatedStorage.Modules.LeafConfig)

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local GetLeafStats = eventsFolder:WaitForChild("Leaf"):WaitForChild("GetLeafStats")
local PurchaseResult = eventsFolder:WaitForChild("Upgrades"):WaitForChild("PurchaseResult")

local LeafStatsState = {}

LeafStatsState.Capacity = LeafConfig.BaseCapacity
LeafStatsState.SpawnInterval = LeafConfig.BaseSpawnInterval
LeafStatsState.CollectionRadius = LeafConfig.BaseCollectionRadius
LeafStatsState.NutChance = LeafConfig.BaseNutChance

LeafStatsState.Changed = Instance.new("BindableEvent")

local function applyStats(stats)
	if not stats then
		return
	end

	local changed = stats.Capacity ~= LeafStatsState.Capacity
		or stats.SpawnInterval ~= LeafStatsState.SpawnInterval
		or stats.CollectionRadius ~= LeafStatsState.CollectionRadius
		or stats.NutChance ~= LeafStatsState.NutChance

	LeafStatsState.Capacity = stats.Capacity
	LeafStatsState.SpawnInterval = stats.SpawnInterval
	LeafStatsState.CollectionRadius = stats.CollectionRadius
	LeafStatsState.NutChance = stats.NutChance

	if changed then
		LeafStatsState.Changed:Fire()
	end
end

local function refresh()
	local ok, stats = pcall(function()
		return GetLeafStats:InvokeServer()
	end)
	if ok then
		applyStats(stats)
	end
end

function LeafStatsState.Refresh()
	refresh()
end

-- Any successful purchase might have changed one of these stats — cheaper
-- and simpler to just re-fetch than to work out which ones locally.
PurchaseResult.OnClientEvent:Connect(function(result)
	if result and result.Success then
		task.spawn(refresh)
	end
end)

task.spawn(function()
	refresh()
	while true do
		task.wait(5) -- backup reconciliation; purchases push immediately above
		refresh()
	end
end)

return LeafStatsState

