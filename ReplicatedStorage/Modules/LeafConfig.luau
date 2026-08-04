--!strict
--[[
	LeafConfig.luau

	Base values and hard safety limits for the leaf loop. The UPGRADE
	scheme that used to live here has moved to
	ReplicatedStorage/Modules/Upgrades/Schema/LeafUpgrades.luau — this
	file is now only "what does a player with zero upgrades get", plus
	the ceilings that protect the game from runaway values.

	Stat tags this system reads (all defined in the schema):
	  LeafValue          currency per leaf collected
	  LeafCapacity       max leaves on the platform at once
	  LeafSpawnSpeed     seconds between spawns
	  LeafCollectionArea collection circle radius
	  NutChance          chance a spawning leaf is a nut instead

	Location: ReplicatedStorage/Modules/LeafConfig.luau
]]

local LeafConfig = {}

-- ============================================================
-- Base values (a player with zero upgrades)
-- ============================================================

LeafConfig.BaseCapacity = 5
LeafConfig.BaseSpawnInterval = 3
LeafConfig.BaseCollectionRadius = 5
LeafConfig.BaseLeafValue = 1
LeafConfig.BaseNutChance = 0

-- ============================================================
-- Hard limits
-- ============================================================

LeafConfig.MaxCapacity = 500
LeafConfig.MinSpawnInterval = 0.01 -- see BULK SPAWNING below
LeafConfig.MaxCollectionRadius = 30

-- ============================================================
-- BULK SPAWNING
-- At the fastest upgrades, the interval reaches 0.01s -- that's 100
-- spawns per second. Running an actual timer that fast means ~100
-- wakeups/second per player doing real work (clone, raycast, place),
-- which is wasteful and starts costing frames with several players on
-- a server.
--
-- So below BulkThreshold the loop STOPS shortening its wait and starts
-- spawning in batches instead: it ticks at BulkInterval and places
-- however many leaves that period earned. 0.01s interval becomes
-- "10 leaves every 0.1s" rather than "1 leaf every 0.01s". Identical
-- spawn rate, ~10x fewer wakeups, and it stays correct at any interval
-- because the batch size is derived from elapsed time, not hardcoded.
-- ============================================================

LeafConfig.BulkThreshold = 0.1 -- intervals faster than this switch to batching
LeafConfig.BulkInterval = 0.1 -- how often the batched loop ticks

-- Safety valve: never place more than this in a single batch, no matter
-- how long a frame hitch was. Prevents one lag spike from trying to
-- place thousands of leaves in one tick and making the hitch worse.
LeafConfig.MaxBulkPerTick = 50

return LeafConfig

