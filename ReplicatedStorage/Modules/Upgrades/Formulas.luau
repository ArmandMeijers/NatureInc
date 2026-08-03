--!strict
--[[
	Formulas.luau

	The balance library. Every cost curve and every boost curve in the
	game is a named function in here — schema entries just reference one
	by name and pass params. Tuning the whole game means editing this
	file (or the params in a schema entry), never gameplay code.

	Two families:
	  Cost.*  (baseCost: BigNum, level: number, params) -> BigNum
	          Cost to buy the NEXT level, i.e. going level -> level+1.
	  Boost.* (level: number, params) -> number
	          The raw value this upgrade contributes at that level.
	          What that value MEANS depends on the entry's BoostType
	          (see UpgradeSchema): a Flat entry's 5 is "+5", a Multiplier
	          entry's 2.5 is "x2.5".

	Costs return BigNumber because they run away fast (exponential^level
	passes 1e308 well before level 1000). Boost values return plain
	numbers and get converted to BigNumber at combine time in BoostMath —
	individual boost contributions stay in a sane range even when the
	COMBINED product is astronomically large.

	Location: ReplicatedStorage/Modules/Upgrades/Formulas.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

type BigNum = BigNumber.BigNum

local Formulas = {}

-- ============================================================
-- COST FORMULAS
-- All take (baseCost, level, params) and return the cost of the NEXT
-- level. `level` is the CURRENT owned level, so level 0 -> baseCost.
-- ============================================================

Formulas.Cost = {}

-- Cost = Base + (Level × Increase).  Early game only — falls behind fast.
function Formulas.Cost.Linear(baseCost: BigNum, level: number, params: { Increase: number }): BigNum
	return BigNumber.Add(baseCost, BigNumber.FromNumber(level * params.Increase))
end

-- Cost = Base × Growth^Level.  The workhorse — use this unless you have
-- a reason not to. Growth 1.15 = +15% per level.
function Formulas.Cost.Exponential(baseCost: BigNum, level: number, params: { Growth: number }): BigNum
	return BigNumber.Mul(baseCost, BigNumber.Pow(BigNumber.FromNumber(params.Growth), level))
end

-- Cost = Base × Level^Power.  Slower than exponential; good for upgrades
-- you want players to max eventually.
function Formulas.Cost.Polynomial(baseCost: BigNum, level: number, params: { Power: number }): BigNum
	if level <= 0 then
		return baseCost
	end
	return BigNumber.Mul(baseCost, BigNumber.Pow(BigNumber.FromNumber(level + 1), params.Power))
end

-- Cost = Base × Growth^Level × Level^Power.  Exponential that accelerates
-- even harder late — for long-term progression sinks.
function Formulas.Cost.Hybrid(baseCost: BigNum, level: number, params: { Growth: number, Power: number }): BigNum
	local exponentialPart = BigNumber.Pow(BigNumber.FromNumber(params.Growth), level)
	local polynomialPart = BigNumber.Pow(BigNumber.FromNumber(level + 1), params.Power)
	return BigNumber.Mul(baseCost, BigNumber.Mul(exponentialPart, polynomialPart))
end

-- Different formula past each breakpoint, for endgame balancing.
-- params.Tiers = { { UpTo = 25, Formula = "Exponential", Params = {...} }, ... }
-- Last tier's UpTo can be math.huge to catch everything above.
function Formulas.Cost.Piecewise(baseCost: BigNum, level: number, params: { Tiers: { any } }): BigNum
	for _, tier in params.Tiers do
		if level < tier.UpTo then
			local formula = Formulas.Cost[tier.Formula]
			if not formula then
				warn(`Formulas.Cost.Piecewise: unknown formula '{tostring(tier.Formula)}'`)
				return baseCost
			end
			return formula(baseCost, level, tier.Params)
		end
	end
	return baseCost
end

-- ============================================================
-- BOOST FORMULAS
-- All take (level, params) and return this upgrade's contribution AT
-- that level. Level 0 must always return the identity value for its
-- BoostType (0 for Flat/Power, 1 for Multiplier) so an unpurchased
-- upgrade contributes nothing.
-- ============================================================

Formulas.Boost = {}

-- Value = Level × PerLevel.  Identity at level 0 = 0. Use with Flat.
function Formulas.Boost.Linear(level: number, params: { PerLevel: number }): number
	return level * params.PerLevel
end

-- Value = 1 + (Level × PerLevel).  Identity at level 0 = 1. Use with
-- Multiplier. PerLevel 0.25 = +25% per level, added linearly (level 4 =
-- 2x, not 1.25^4) — predictable, easy to reason about while balancing.
function Formulas.Boost.Percentage(level: number, params: { PerLevel: number }): number
	return 1 + (level * params.PerLevel)
end

-- Value = Growth^Level.  Identity at level 0 = 1. Use with Multiplier
-- when you want compounding — this is what makes big numbers happen.
-- Growth 1.15 at level 50 ≈ 1083x.
function Formulas.Boost.ExponentialGrowth(level: number, params: { Growth: number }): number
	return params.Growth ^ level
end

-- Value = 1 + Scale × log(1 + Level).  Identity at level 0 = 1. Soft
-- scaling — strong early, flattens hard. Use with Multiplier.
function Formulas.Boost.Logarithmic(level: number, params: { Scale: number }): number
	return 1 + params.Scale * math.log(1 + level)
end

-- Linear until Softcap, then square-root growth past it. Stops a stat
-- running away without ever hard-stopping progression.
function Formulas.Boost.Softcap(level: number, params: { PerLevel: number, Softcap: number }): number
	local raw = level * params.PerLevel
	if raw <= params.Softcap then
		return raw
	end
	return params.Softcap + (raw - params.Softcap) ^ 0.5
end

-- Value = Max × (Level / (Level + K)).  Approaches Max, never reaches
-- it. Built for bounded stats like NutChance (a percentage that must
-- never hit 100%). Identity at level 0 = 0. Use with Flat.
function Formulas.Boost.DiminishingReturns(level: number, params: { Max: number, K: number }): number
	if level <= 0 then
		return 0
	end
	return params.Max * (level / (level + params.K))
end

-- Decays a starting value toward Floor, shrinking by Rate each level:
-- 3 -> 2.55 -> 2.17 -> ... -> Floor. Built for spawn INTERVAL, where
-- "better" means smaller. Returns the resulting interval directly, not
-- a delta — see UpgradeSchema's SpeedInterval BoostType.
function Formulas.Boost.ExponentialDecay(level: number, params: { Start: number, Rate: number, Floor: number }): number
	local value = params.Start * (params.Rate ^ level)
	return math.max(value, params.Floor)
end

return Formulas

