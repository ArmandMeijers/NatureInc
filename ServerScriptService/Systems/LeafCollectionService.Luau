--[[
	LeafCollectionService.luau

	Server side of the leaf loop. Two jobs:

	1. GetLeafStats (RemoteFunction) — reports this player's current
	   capacity/spawn interval/collection radius/value multiplier, all
	   computed server-side from their upgrade levels + tree tier via
	   LeafBoostCalculator. The client never computes these itself; it
	   only ever displays what the server says.

	2. CollectLeaf (RemoteEvent) — the client fires this once per leaf it
	   destroys locally, and the server awards LeafConfig.BaseLeafValue *
	   (that player's value multiplier) Leaf currency for it.

	IMPORTANT — why this needs rate limiting at all:
	Leaves are entirely client-local (see LeafSpawnController) for
	performance — the server never tracks where any leaf is, or even how
	many exist. That means the server has NO way to verify "yes, a leaf
	really was there to collect." It has to trust the client's word that
	a collection happened. What it must NOT trust is anything about HOW
	MUCH that collection is worth — the value multiplier is always looked
	up server-side, never taken from the client — and it must stop a
	compromised/scripted client from just firing CollectLeaf in a tight
	loop for unlimited currency.

	A flat cooldown between calls would break the real, intended pattern
	of "walk into a pile and collect several leaves in one moment" (the
	collection circle can legitimately catch many leaves at once). So
	this uses a token bucket instead: each player has a budget that
	refills at their own (capacity / interval) rate — their own legitimate
	max collection rate — capped at their own capacity. Real play, even
	bursty real play, always stays under budget. Sustained spam beyond
	what their own upgrades could ever produce gets rejected.

	Location: ServerScriptService/Systems/LeafCollectionService.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local LeafConfig = require(ReplicatedStorage.Modules.LeafConfig)
local LeafBoostCalculator = require(ReplicatedStorage.Modules.LeafBoostCalculator)

local remotesFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Leaf")
local GetLeafStats = remotesFolder:WaitForChild("GetLeafStats")
local CollectLeaf = remotesFolder:WaitForChild("CollectLeaf")

local function getLevels(player: Player): LeafBoostCalculator.LeafLevels
	return {
		LeafAdd = DataManager.Get(player, "Upgrades.LeafUpgrades.LeafAdd") or 0,
		LeafMult = DataManager.Get(player, "Upgrades.LeafUpgrades.LeafMult") or 0,
		LeafSpawnRate = DataManager.Get(player, "Upgrades.LeafUpgrades.LeafSpawnRate") or 0,
		LeafCapacity = DataManager.Get(player, "Upgrades.LeafUpgrades.LeafCapacity") or 0,
		LeafRadius = DataManager.Get(player, "Upgrades.LeafUpgrades.LeafRadius") or 0,
	}
end

local function getStats(player: Player)
	local levels = getLevels(player)
	local tier = DataManager.Get(player, "Tree.TreeTier") or 1
	return {
		Capacity = LeafBoostCalculator.GetCapacity(levels),
		SpawnInterval = LeafBoostCalculator.GetSpawnInterval(levels),
		CollectionRadius = LeafBoostCalculator.GetCollectionRadius(levels),
		ValueMultiplier = LeafBoostCalculator.GetValueMultiplier(levels, tier),
	}
end

GetLeafStats.OnServerInvoke = function(player: Player)
	return getStats(player)
end

-- ============================================================
-- Token bucket rate limiting (see header)
-- ============================================================

local buckets: { [Player]: { tokens: number, lastRefill: number } } = {}

local function tryConsumeToken(player: Player, capacity: number, interval: number): boolean
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = capacity, lastRefill = os.clock() } -- start full: fresh join shouldn't feel throttled
		buckets[player] = bucket
	end

	local now = os.clock()
	local elapsed = now - bucket.lastRefill
	local refillRate = capacity / math.max(interval, LeafConfig.MinSpawnInterval)
	bucket.tokens = math.min(capacity, bucket.tokens + elapsed * refillRate)
	bucket.lastRefill = now

	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

CollectLeaf.OnServerEvent:Connect(function(player: Player)
	if not DataManager.GetProfile(player) then
		return
	end

	local levels = getLevels(player)
	local capacity = LeafBoostCalculator.GetCapacity(levels)
	local interval = LeafBoostCalculator.GetSpawnInterval(levels)

	if not tryConsumeToken(player, capacity, interval) then
		return -- silently dropped: this player is collecting faster than their own upgrades allow
	end

	local tier = DataManager.Get(player, "Tree.TreeTier") or 1
	local multiplier = LeafBoostCalculator.GetValueMultiplier(levels, tier)
	local value = BigNumber.FromNumber(LeafConfig.BaseLeafValue * multiplier)

	DataManager.AddCurrency(player, "Leafs", value)
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

