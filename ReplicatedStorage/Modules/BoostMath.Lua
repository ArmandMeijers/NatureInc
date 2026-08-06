--!strict
--[[
	BoostMath.luau

	One place that defines how boosts combine, no matter where they come
	from. Every source (upgrades, tree tiers now; runes, pets, areas,
	quests later) contributes entries in the same shape and hands them
	here — nobody writes their own "total multiplier" math per system.

	THE FORMULA:
		Final = (((Base + ΣFlat) × ΠMultipliers) ^ (1 + ΣPower)) × ΠFinalMultipliers

	Everything is BigNumber from the multiply step onward: ExponentialGrowth
	upgrades compound, and several stacked (LeafMult × CompostLeafMult ×
	NutLeafMult × tree tier) blow past float range quickly. Flat and Power
	sums stay plain numbers — they're small by nature and only exponents.

	MODULAR BY TAG:
	  BoostMath.TotalBoost(levels, tier, "LeafValue")
	  BoostMath.TotalBoost(levels, tier, "CompostValue")
	Same call, different stat. Every upgrade tagged with that stat, from
	ANY currency's schema, is collected automatically — no per-stat code.
	Adding a new upgrade that boosts an existing stat needs zero changes
	here; adding a brand-new stat needs zero changes here.

	Location: ReplicatedStorage/Modules/BoostMath.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local UpgradeSchema = require(ReplicatedStorage.Modules.Upgrades.UpgradeSchema)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)

type BigNum = BigNumber.BigNum

-- Kept for backward compatibility with the old entry shape used by
-- TreeTierConfig.Boosts ({ Amount = n, Type = "Multiplicative" }).
export type BoostType = "Additive" | "Multiplicative" | "Power"
export type BoostEntry = { Amount: number, Type: BoostType }

local BoostMath = {}

local ONE = BigNumber.FromNumber(1)

-- Tree tier boosts are keyed by currency name ("Leafs"), but stat tags
-- are more granular ("LeafValue"). This maps a tag to the tier key that
-- feeds it, so tiers keep their simple per-currency config while the
-- rest of the system speaks in tags. Tags absent here just get no tier
-- contribution, which is correct — a tier boosting "Leafs" income
-- shouldn't silently also boost leaf CAPACITY.
local TAG_TO_TIER_KEY: { [string]: string } = {
	LeafValue = "Leafs",
	CompostValue = "Compost",
	NutValue = "Nuts",
}

-- Collected contributions for one stat, before combining.
type Accumulator = {
	Flat: number,
	Multiplier: BigNum,
	Power: number,
	FinalMultiplier: BigNum,
}

local function newAccumulator(): Accumulator
	return {
		Flat = 0,
		Multiplier = BigNumber.FromNumber(1),
		Power = 0,
		FinalMultiplier = BigNumber.FromNumber(1),
	}
end

local function addContribution(acc: Accumulator, boostType: string, value: number)
	if boostType == "Flat" then
		acc.Flat += value
	elseif boostType == "Multiplier" then
		acc.Multiplier = BigNumber.Mul(acc.Multiplier, BigNumber.FromNumber(value))
	elseif boostType == "Power" then
		acc.Power += value
	elseif boostType == "FinalMultiplier" then
		acc.FinalMultiplier = BigNumber.Mul(acc.FinalMultiplier, BigNumber.FromNumber(value))
	end
	-- SpeedInterval deliberately ignored here — it doesn't combine like a
	-- boost at all (see GetSpawnInterval).
end

-- Every upgrade tagged `tag`, at this player's levels.
local function accumulateUpgrades(acc: Accumulator, levels: { [string]: number }, tag: string)
	local upgradeIds = UpgradeSchema.ByTag[tag]
	if not upgradeIds then
		return
	end

	for _, upgradeId in upgradeIds do
		local entry = UpgradeSchema.All[upgradeId]
		local level = UpgradeSchema.ClampLevel(upgradeId, levels[upgradeId])
		if level > 0 then
			addContribution(acc, entry.BoostType, UpgradeSchema.GetBoostValue(upgradeId, level))
		end
	end
end

-- Current tree tier only — tiers don't stack.
local function accumulateTreeTier(acc: Accumulator, tier: number, tag: string)
	local tierKey = TAG_TO_TIER_KEY[tag]
	if not tierKey then
		return
	end

	local tierData = TreeTierConfig[tier]
	local boost = tierData and tierData.Boosts and tierData.Boosts[tierKey]
	if not boost then
		return
	end

	-- TreeTierConfig uses the older Additive/Multiplicative/Power names.
	if boost.Type == "Additive" then
		acc.Flat += boost.Amount
	elseif boost.Type == "Multiplicative" then
		acc.Multiplier = BigNumber.Mul(acc.Multiplier, BigNumber.FromNumber(boost.Amount))
	elseif boost.Type == "Power" then
		acc.Power += boost.Amount
	end
end

local function combine(acc: Accumulator, base: BigNum): BigNum
	local total = BigNumber.Mul(BigNumber.Add(base, BigNumber.FromNumber(acc.Flat)), acc.Multiplier)
	if acc.Power ~= 0 then
		total = BigNumber.Pow(total, 1 + acc.Power)
	end
	return BigNumber.Mul(total, acc.FinalMultiplier)
end

-- ============================================================
-- Public API
-- ============================================================

-- The headline function. `levels` is a flat { [upgradeId]: level } map
-- (see UpgradeService.GetLevels), `tier` the player's tree tier, `tag`
-- the stat wanted. `base` defaults to 1.
function BoostMath.TotalBoost(levels: { [string]: number }, tier: number, tag: string, base: BigNum?): BigNum
	local acc = newAccumulator()
	accumulateUpgrades(acc, levels, tag)
	accumulateTreeTier(acc, tier, tag)
	return combine(acc, base or ONE)
end

-- Same, as a plain number. Only for stats that are genuinely small and
-- bounded — capacity, radius, chance. Never for currency values, which
-- must stay BigNumber all the way through.
function BoostMath.TotalBoostNumber(levels: { [string]: number }, tier: number, tag: string, base: number?): number
	local result = BoostMath.TotalBoost(levels, tier, tag, BigNumber.FromNumber(base or 1))
	return BigNumber.ToNumber(result)
end

-- SpeedInterval is its own thing: each such upgrade RESOLVES to an
-- interval (3s -> 2.7s -> ...) rather than contributing a factor, so
-- "combining" them means taking the best (smallest) one, not
-- multiplying. Multiple speed upgrades feeding one tag would otherwise
-- multiply into nonsense.
function BoostMath.GetSpawnInterval(levels: { [string]: number }, tag: string, fallback: number): number
	local upgradeIds = UpgradeSchema.ByTag[tag]
	if not upgradeIds then
		return fallback
	end

	local best = fallback
	for _, upgradeId in upgradeIds do
		local entry = UpgradeSchema.All[upgradeId]
		if entry.BoostType == "SpeedInterval" then
			local level = UpgradeSchema.ClampLevel(upgradeId, levels[upgradeId])
			best = math.min(best, UpgradeSchema.GetBoostValue(upgradeId, level))
		end
	end
	return best
end

-- Legacy shim: the old list-of-entries API, kept so any not-yet-migrated
-- caller keeps working rather than silently breaking.
function BoostMath.Calculate(entries: { BoostEntry }): number
	local additive, multiplicative, power = 0, 1, 0
	for _, entry in entries do
		if entry.Type == "Additive" then
			additive += entry.Amount
		elseif entry.Type == "Multiplicative" then
			multiplicative *= entry.Amount
		elseif entry.Type == "Power" then
			power += entry.Amount
		end
	end
	local total = (1 + additive) * multiplicative
	if power ~= 0 then
		total = total ^ (1 + power)
	end
	return total
end

function BoostMath.GetTreeTierEntries(config, currentTier: number, currencyKey: string): { BoostEntry }
	local tierData = config[currentTier]
	if not tierData or not tierData.Boosts or not tierData.Boosts[currencyKey] then
		return {}
	end
	return { tierData.Boosts[currencyKey] }
end

return BoostMath