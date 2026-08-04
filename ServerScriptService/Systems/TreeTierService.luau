--[[
	LeafCollectionService.luau

	Server side of the leaf loop. Two jobs:

	1. GetLeafStats (RemoteFunction) — this player's capacity / spawn
	   interval / collection radius / leaf value / nut chance, all
	   computed server-side from their upgrade levels + tree tier through
	   BoostMath. The client never computes these; it only displays what
	   the server says.

	2. CollectLeaf (RemoteEvent) — the client fires this per leaf it
	   destroys locally; the server decides what that's worth.

	WHY RATE LIMITING:
	Leaves are entirely client-local (see LeafSpawnController) for
	performance — the server never tracks where any leaf is or how many
	exist, so it cannot verify a leaf was really there. It has to trust
	that a collection happened. What it must NOT trust is how much that's
	worth: the value is always looked up server-side, never sent by the
	client. A token bucket then caps the RATE, sized to that player's own
	capacity/interval, so legitimate bursts (walking into a full
	platform) always pass while sustained spam beyond what their upgrades
	could produce gets dropped.

	Location: ServerScriptService/Systems/LeafCollectionService.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local UpgradeService = require(ServerScriptService.Systems.UpgradeService)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local BoostMath = require(ReplicatedStorage.Modules.BoostMath)
local LeafConfig = require(ReplicatedStorage.Modules.LeafConfig)

local remotesFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Leaf")
local GetLeafStats = remotesFolder:WaitForChild("GetLeafStats")
local CollectLeaf = remotesFolder:WaitForChild("CollectLeaf")

local function getStats(player: Player)
	local levels = UpgradeService.GetLevels(player)
	local tier = DataManager.Get(player, "Tree.TreeTier") or 1

	local capacity = math.floor(math.clamp(
		BoostMath.TotalBoostNumber(levels, tier, "LeafCapacity", LeafConfig.BaseCapacity),
		LeafConfig.BaseCapacity,
		LeafConfig.MaxCapacity
	))

	local interval = math.clamp(
		BoostMath.GetSpawnInterval(levels, "LeafSpawnSpeed", LeafConfig.BaseSpawnInterval),
		LeafConfig.MinSpawnInterval,
		LeafConfig.BaseSpawnInterval
	)

	local radius = math.clamp(
		BoostMath.TotalBoostNumber(levels, tier, "LeafCollectionArea", LeafConfig.BaseCollectionRadius),
		LeafConfig.BaseCollectionRadius,
		LeafConfig.MaxCollectionRadius
	)

	-- Clamped below 1 so nut chance can never fully replace leaf spawns.
	local nutChance = math.clamp(
		BoostMath.TotalBoostNumber(levels, tier, "NutChance", LeafConfig.BaseNutChance),
		0,
		0.95
	)

	return {
		Capacity = capacity,
		SpawnInterval = interval,
		CollectionRadius = radius,
		NutChance = nutChance,
	}
end

GetLeafStats.OnServerInvoke = function(player: Player)
	if not DataManager.GetProfile(player) then
		return nil
	end
	return getStats(player)
end

-- ============================================================
-- Token bucket (see header)
-- ============================================================

local buckets: { [Player]: { tokens: number, lastRefill: number } } = {}

local function tryConsumeToken(player: Player, capacity: number, interval: number): boolean
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = capacity, lastRefill = os.clock() } -- start full so a fresh join isn't throttled
		buckets[player] = bucket
	end

	local now = os.clock()
	bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.lastRefill) * (capacity / math.max(interval, LeafConfig.MinSpawnInterval)))
	bucket.lastRefill = now

	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

CollectLeaf.OnServerEvent:Connect(function(player: Player, isNut: any)
	if not DataManager.GetProfile(player) then
		return
	end

	local levels = UpgradeService.GetLevels(player)
	local tier = DataManager.Get(player, "Tree.TreeTier") or 1

	local capacity = math.floor(math.clamp(
		BoostMath.TotalBoostNumber(levels, tier, "LeafCapacity", LeafConfig.BaseCapacity),
		LeafConfig.BaseCapacity,
		LeafConfig.MaxCapacity
	))
	local interval = math.clamp(
		BoostMath.GetSpawnInterval(levels, "LeafSpawnSpeed", LeafConfig.BaseSpawnInterval),
		LeafConfig.MinSpawnInterval,
		LeafConfig.BaseSpawnInterval
	)

	if not tryConsumeToken(player, capacity, interval) then
		return -- collecting faster than their own upgrades allow
	end

	-- The client says WHICH kind it collected, which is fine: both paths
	-- are rate-limited identically and the VALUE of each is computed
	-- here, so claiming "nut" only changes which currency is awarded,
	-- never how much advantage is gained.
	if isNut == true then
		local nutValue = BoostMath.TotalBoost(levels, tier, "NutValue", BigNumber.FromNumber(1))
		DataManager.AddCurrency(player, "Nuts", nutValue)
	else
		local leafValue = BoostMath.TotalBoost(levels, tier, "LeafValue", BigNumber.FromNumber(LeafConfig.BaseLeafValue))
		DataManager.AddCurrency(player, "Leafs", leafValue)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

