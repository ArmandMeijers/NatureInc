--!strict
--[[
	UpgradeSchema.luau

	Merges every per-currency schema file into one lookup, and provides
	the cost/level helpers everything else uses. Adding a whole new
	upgrade family = drop a file in Schema/ and add one line to
	SCHEMA_FILES below. Adding a single upgrade = one entry in an
	existing file. Nothing else in the codebase changes either way.

	Location: ReplicatedStorage/Modules/Upgrades/UpgradeSchema.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local Formulas = require(ReplicatedStorage.Modules.Upgrades.Formulas)

type BigNum = BigNumber.BigNum

export type BoostType = "Flat" | "Multiplier" | "Power" | "FinalMultiplier" | "SpeedInterval"

export type UpgradeEntry = {
	Name: string,
	Category: string,
	Tag: string,
	BoostType: BoostType,
	MaxLevel: number,
	Currency: string,
	BaseCost: BigNum,
	CostFormula: string,
	CostParams: any,
	BoostFormula: string,
	BoostParams: any,
}

local schemaFolder = script.Parent.Schema
local SCHEMA_FILES = {
	require(schemaFolder.LeafUpgrades),
	require(schemaFolder.CompostUpgrades),
	require(schemaFolder.NutUpgrades),
}

local UpgradeSchema = {}

-- Flat lookup: upgradeId -> entry. Ids are unique across all files.
UpgradeSchema.All = {} :: { [string]: UpgradeEntry }

-- Tag -> { upgradeId }, built once at load. This is what lets
-- BoostMath ask "everything feeding LeafCapacity" without scanning the
-- whole schema on every single stat lookup — and those lookups happen
-- constantly (every spawn tick, every collection).
UpgradeSchema.ByTag = {} :: { [string]: { string } }

-- Category -> { upgradeId }, for UI that lists one board's upgrades.
UpgradeSchema.ByCategory = {} :: { [string]: { string } }

for _, file in SCHEMA_FILES do
	for upgradeId, entry in file do
		if UpgradeSchema.All[upgradeId] then
			warn(`UpgradeSchema: duplicate upgrade id '{upgradeId}' — ids must be unique across ALL schema files. Later definition wins.`)
		end
		UpgradeSchema.All[upgradeId] = entry

		local tagList = UpgradeSchema.ByTag[entry.Tag]
		if not tagList then
			tagList = {}
			UpgradeSchema.ByTag[entry.Tag] = tagList
		end
		table.insert(tagList, upgradeId)

		local categoryList = UpgradeSchema.ByCategory[entry.Category]
		if not categoryList then
			categoryList = {}
			UpgradeSchema.ByCategory[entry.Category] = categoryList
		end
		table.insert(categoryList, upgradeId)
	end
end

function UpgradeSchema.Get(upgradeId: string): UpgradeEntry?
	return UpgradeSchema.All[upgradeId]
end

-- The data path this upgrade's level lives at, e.g.
-- "Upgrades.LeafUpgrades.LeafAdd". One place builds these, so a
-- Template restructure only needs fixing here.
function UpgradeSchema.GetDataPath(upgradeId: string): string?
	local entry = UpgradeSchema.All[upgradeId]
	if not entry then
		return nil
	end
	return `Upgrades.{entry.Category}.{upgradeId}`
end

-- Always clamped to [0, MaxLevel]. Saved data is never trusted to be in
-- range — a schema MaxLevel reduction during balancing would otherwise
-- leave existing players sitting above the new cap forever.
function UpgradeSchema.ClampLevel(upgradeId: string, rawLevel: number?): number
	local entry = UpgradeSchema.All[upgradeId]
	if not entry then
		return 0
	end
	return math.clamp(math.floor(rawLevel or 0), 0, entry.MaxLevel)
end

-- Cost to go from `level` to `level + 1`. Returns nil at max level,
-- which callers treat as "not purchasable" rather than "free".
function UpgradeSchema.GetCost(upgradeId: string, level: number): BigNum?
	local entry = UpgradeSchema.All[upgradeId]
	if not entry then
		return nil
	end
	if level >= entry.MaxLevel then
		return nil
	end

	local costFormula = Formulas.Cost[entry.CostFormula]
	if not costFormula then
		warn(`UpgradeSchema: '{upgradeId}' references unknown cost formula '{entry.CostFormula}'`)
		return nil
	end
	return costFormula(entry.BaseCost, level, entry.CostParams)
end

-- This upgrade's raw contribution at that level (see Formulas header).
function UpgradeSchema.GetBoostValue(upgradeId: string, level: number): number
	local entry = UpgradeSchema.All[upgradeId]
	if not entry then
		return 0
	end

	local boostFormula = Formulas.Boost[entry.BoostFormula]
	if not boostFormula then
		warn(`UpgradeSchema: '{upgradeId}' references unknown boost formula '{entry.BoostFormula}'`)
		return 0
	end
	return boostFormula(level, entry.BoostParams)
end

return UpgradeSchema

