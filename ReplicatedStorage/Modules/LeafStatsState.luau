--!strict
--[[
	LeafStatsState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of this player's current leaf-system stats (capacity,
	spawn interval, collection radius, value multiplier), all computed
	server-side and never trusted from anywhere else. Same poll pattern
	as TreeTierState/CurrencyStatsState: fetch once, then keep polling
	lightly, fire Changed when anything actually differs.

	Location: ReplicatedStorage/Modules/LeafStatsState.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeafConfig = require(ReplicatedStorage.Modules.LeafConfig)

local GetLeafStats = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Leaf"):WaitForChild("GetLeafStats")

local LeafStatsState = {}

LeafStatsState.Capacity = LeafConfig.BaseCapacity
LeafStatsState.SpawnInterval = LeafConfig.BaseSpawnInterval
LeafStatsState.CollectionRadius = LeafConfig.BaseCollectionRadius
LeafStatsState.ValueMultiplier = 1

-- Fires with no arguments whenever any of the above changes.
LeafStatsState.Changed = Instance.new("BindableEvent")

local function applyStats(stats)
	if not stats then
		return
	end

	local changed = stats.Capacity ~= LeafStatsState.Capacity
		or stats.SpawnInterval ~= LeafStatsState.SpawnInterval
		or stats.CollectionRadius ~= LeafStatsState.CollectionRadius
		or stats.ValueMultiplier ~= LeafStatsState.ValueMultiplier

	LeafStatsState.Capacity = stats.Capacity
	LeafStatsState.SpawnInterval = stats.SpawnInterval
	LeafStatsState.CollectionRadius = stats.CollectionRadius
	LeafStatsState.ValueMultiplier = stats.ValueMultiplier

	if changed then
		LeafStatsState.Changed:Fire()
	end
end

task.spawn(function()
	local ok, stats = pcall(function()
		return GetLeafStats:InvokeServer()
	end)
	if ok then
		applyStats(stats)
	end

	while true do
		task.wait(2) -- these only change when an upgrade is bought or a tier-up happens — no need to poll fast
		local success, result = pcall(function()
			return GetLeafStats:InvokeServer()
		end)
		if success then
			applyStats(result)
		end
	end
end)

return LeafStatsState

