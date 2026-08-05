--!strict
--[[
	UpgradeSchema.luau

	Merges every per-currency schema file into one lookup and provides
	the cost/level helpers everything else uses. Adding a whole upgrade
	family = drop a file in Schema/ and add one line to SCHEMA_FILES.
	Adding a single upgrade = one entry in an existing file.

	TWO CHANGES WORTH KNOWING ABOUT:

	1. ByCategory is SORTED, by each entry's Order field. It used to be
	   built by iterating the schema file with a generic for, which walks
	   a hash table in whatever order Lua feels like — so the board's
	   column order would have been stable within a session and
	   different between them. Lua gives no way to read "the order I
	   typed these in", so the order has to be written down explicitly.

	2. Boost formulas receive the full entry as a third argument, so a
	   curve can shape itself around MaxLevel (see Formulas.IntervalDecay).
	   Every existing formula ignores it.

	Location: ReplicatedStorage/Modules/Upgrades/UpgradeSchema.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local Formulas = require(ReplicatedStorage.Modules.Upgrades.Formulas)

type BigNum = BigNumber.BigNum

export type BoostType = "Flat" | "Multiplier" | "Power" | "FinalMultiplier" | "SpeedInterval"

export type DisplayMode = "Flat" | "Multiplier" | "Seconds" | "Studs" | "Percent"

export type UpgradeEntry = {
	Name: string,
	Category: string,
	Tag: string,
	Order: number?,
	BoostType: BoostType,
	MaxLevel: number,
	Currency: string,
	BaseCost: BigNum,
	CostFormula: string,
	CostParams: any,
	BoostFormula: string,
	BoostParams: any,
	Display: { Mode: DisplayMode, Base: number?, Decimals: number? }?,
}

local schemaFolder = script.Parent.Schema
local SCHEMA_FILES = {
	require(schemaFolder.LeafUpgrades),
	require(schemaFolder.CompostUpgrades),
	require(schemaFolder.NutUpgrades),
}

local UpgradeSchema = {}

UpgradeSchema.All = {} :: { [string]: UpgradeEntry }
UpgradeSchema.ByTag = {} :: { [string]: { string } }
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

-- Sorted once at load. Order first, then id as a tiebreak so an entry
-- missing an Order still lands somewhere deterministic rather than
-- wherever the hash walk left it.
for _, categoryList in UpgradeSchema.ByCategory do
	table.sort(categoryList, function(a, b)
		local orderA = UpgradeSchema.All[a].Order or 1000
		local orderB = UpgradeSchema.All[b].Order or 1000
		if orderA == orderB then
			return a < b
		end
		return orderA < orderB
	end)
end

function UpgradeSchema.Get(upgradeId: string): UpgradeEntry?
	return UpgradeSchema.All[upgradeId]
end

-- Ids for one board, in display order. Returns a copy: callers sort and
-- filter these (maxed-to-the-back, hidden-when-maxed) and must not be
-- able to scramble the shared list doing it.
function UpgradeSchema.GetCategoryOrder(category: string): { string }
	local source = UpgradeSchema.ByCategory[category]
	if not source then
		return {}
	end
	return table.clone(source)
end

function UpgradeSchema.GetDataPath(upgradeId: string): string?
	local entry = UpgradeSchema.All[upgradeId]
	if not entry then
		return nil
	end
	return `Upgrades.{entry.Category}.{upgradeId}`
end

-- Always clamped to [0, MaxLevel]. Saved data is never trusted to be in
-- range — a MaxLevel reduction during balancing would otherwise leave
-- existing players above the new cap forever.
function UpgradeSchema.ClampLevel(upgradeId: string, rawLevel: number?): number
	local entry = UpgradeSchema.All[upgradeId]
	if not entry then
		return 0
	end
	return math.clamp(math.floor(rawLevel or 0), 0, entry.MaxLevel)
end

-- Cost to go from `level` to `level + 1`. nil at max level, which callers
-- treat as "not purchasable" rather than "free".
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
	return boostFormula(level, entry.BoostParams, entry)
end

return UpgradeSchema
