--!strict
--[[
	LeafBoostCalculator.luau

	Pure functions turning a player's upgrade levels (+ current tree tier)
	into the actual numbers the leaf system runs on: capacity, spawn
	interval, collection radius, and leaf value multiplier. No side
	effects, no DataManager calls in here — callers pass in the raw
	levels/tier they already fetched, so this stays trivially testable
	and reusable (server uses it authoritatively; nothing stops a client
	preview from calling it too later if that's ever useful).

	Location: ReplicatedStorage/Modules/LeafBoostCalculator.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostMath = require(ReplicatedStorage.Modules.BoostMath)
local LeafConfig = require(ReplicatedStorage.Modules.LeafConfig)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)

local LeafBoostCalculator = {}

export type LeafLevels = {
	LeafAdd: number,
	LeafMult: number,
	LeafSpawnRate: number,
	LeafCapacity: number,
	LeafRadius: number,
}

-- One upgrade field's contribution as a single BoostMath entry, given its
-- current level. Only meaningful for Additive/Multiplicative kinds —
-- IntervalReduction fields (LeafSpawnRate) aren't multiplier stacks and
-- are handled directly in GetSpawnInterval below instead.
local function levelToEntry(fieldName: string, level: number): BoostMath.BoostEntry?
	local def = LeafConfig.UpgradeScheme[fieldName]
	if not def then
		return nil
	end

	if def.Kind == "Additive" then
		return { Amount = level * def.PerLevel, Type = "Additive" }
	elseif def.Kind == "Multiplicative" then
		return { Amount = 1 + (level * def.PerLevel), Type = "Multiplicative" }
	end
	return nil
end

-- Final leaf value multiplier: tree tier's Leafs boost (if any) combined
-- with the LeafAdd/LeafMult upgrade levels, all through BoostMath —
-- this IS a genuine multiplier-stacking problem, unlike the other three.
function LeafBoostCalculator.GetValueMultiplier(levels: LeafLevels, currentTier: number): number
	local entries = BoostMath.GetTreeTierEntries(TreeTierConfig, currentTier, "Leafs")

	local addEntry = levelToEntry("LeafAdd", levels.LeafAdd)
	if addEntry then
		table.insert(entries, addEntry)
	end

	local multEntry = levelToEntry("LeafMult", levels.LeafMult)
	if multEntry then
		table.insert(entries, multEntry)
	end

	return BoostMath.Calculate(entries)
end

function LeafBoostCalculator.GetCapacity(levels: LeafLevels): number
	local def = LeafConfig.UpgradeScheme.LeafCapacity
	local capacity = LeafConfig.BaseCapacity + (levels.LeafCapacity * def.PerLevel)
	return math.clamp(capacity, LeafConfig.BaseCapacity, LeafConfig.MaxCapacity)
end

function LeafBoostCalculator.GetSpawnInterval(levels: LeafLevels): number
	local def = LeafConfig.UpgradeScheme.LeafSpawnRate
	local interval = LeafConfig.BaseSpawnInterval - (levels.LeafSpawnRate * def.PerLevel)
	return math.clamp(interval, LeafConfig.MinSpawnInterval, LeafConfig.BaseSpawnInterval)
end

function LeafBoostCalculator.GetCollectionRadius(levels: LeafLevels): number
	local def = LeafConfig.UpgradeScheme.LeafRadius
	local radius = LeafConfig.BaseCollectionRadius + (levels.LeafRadius * def.PerLevel)
	return math.clamp(radius, LeafConfig.BaseCollectionRadius, LeafConfig.MaxCollectionRadius)
end

return LeafBoostCalculator

