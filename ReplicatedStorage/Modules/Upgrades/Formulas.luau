--!strict
--[[
	Formulas.luau

	The balance library. Every cost curve, boost curve and reset payout
	in the game is a named function here — schema entries reference one
	by name and pass params. Tuning means editing this file or a schema's
	params, never gameplay code.

	  Cost.*  (baseCost, level, params)     -> BigNum
	  Boost.* (level, params, entry)        -> number
	  Reset.* (inputAmount, params)         -> BigNum

	`entry` is the full schema entry, passed so a curve can shape itself
	around MaxLevel. IntervalDecay is why it exists; everything else
	ignores it.

	Location: ReplicatedStorage/Modules/Upgrades/Formulas.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

type BigNum = BigNumber.BigNum

local Formulas = {}

local ZERO = BigNumber.new(0, 0)

-- ============================================================
-- COST FORMULAS
-- (baseCost, level, params) -> cost of the NEXT level.
-- `level` is the CURRENT owned level, so level 0 -> baseCost.
-- ============================================================

Formulas.Cost = {}

function Formulas.Cost.Linear(baseCost: BigNum, level: number, params: { Increase: number }): BigNum
	return BigNumber.Add(baseCost, BigNumber.FromNumber(level * params.Increase))
end

function Formulas.Cost.Exponential(baseCost: BigNum, level: number, params: { Growth: number }): BigNum
	return BigNumber.Mul(baseCost, BigNumber.Pow(BigNumber.FromNumber(params.Growth), level))
end

function Formulas.Cost.Polynomial(baseCost: BigNum, level: number, params: { Power: number }): BigNum
	if level <= 0 then
		return baseCost
	end
	return BigNumber.Mul(baseCost, BigNumber.Pow(BigNumber.FromNumber(level + 1), params.Power))
end

function Formulas.Cost.Hybrid(baseCost: BigNum, level: number, params: { Growth: number, Power: number }): BigNum
	local exponentialPart = BigNumber.Pow(BigNumber.FromNumber(params.Growth), level)
	local polynomialPart = BigNumber.Pow(BigNumber.FromNumber(level + 1), params.Power)
	return BigNumber.Mul(baseCost, BigNumber.Mul(exponentialPart, polynomialPart))
end

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
-- (level, params, entry) -> this upgrade's contribution at that level.
-- Level 0 must return the identity for its BoostType (0 for Flat/Power,
-- 1 for Multiplier) so an unpurchased upgrade contributes nothing.
-- ============================================================

Formulas.Boost = {}

function Formulas.Boost.Linear(level: number, params: { PerLevel: number }): number
	return level * params.PerLevel
end

function Formulas.Boost.Percentage(level: number, params: { PerLevel: number }): number
	return 1 + (level * params.PerLevel)
end

function Formulas.Boost.ExponentialGrowth(level: number, params: { Growth: number }): number
	return params.Growth ^ level
end

function Formulas.Boost.Logarithmic(level: number, params: { Scale: number }): number
	return 1 + params.Scale * math.log(1 + level)
end

function Formulas.Boost.Softcap(level: number, params: { PerLevel: number, Softcap: number }): number
	local raw = level * params.PerLevel
	if raw <= params.Softcap then
		return raw
	end
	return params.Softcap + (raw - params.Softcap) ^ 0.5
end

function Formulas.Boost.DiminishingReturns(level: number, params: { Max: number, K: number }): number
	if level <= 0 then
		return 0
	end
	return params.Max * (level / (level + params.K))
end

function Formulas.Boost.ExponentialDecay(level: number, params: { Start: number, Rate: number, Floor: number }): number
	return math.max(params.Start * (params.Rate ^ level), params.Floor)
end

-- A cooldown curve that SHAPES ITSELF AROUND MaxLevel. Two geometric
-- phases derived at call time: Start -> KneeValue over the first
-- KneeFraction of levels, KneeValue -> Floor over the rest. Retuning how
-- long the upgrade runs is therefore a one-number change, instead of
-- solving for the rate that happens to land on the floor.
function Formulas.Boost.IntervalDecay(
	level: number,
	params: { Start: number, Floor: number, KneeValue: number?, KneeFraction: number? },
	entry: any
): number
	local maxLevel = (entry and entry.MaxLevel) or 30
	if maxLevel <= 0 then
		return params.Start
	end

	local kneeValue = params.KneeValue or 0.1
	local kneeFraction = params.KneeFraction or (2 / 3)
	local knee = math.max(1, math.round(maxLevel * kneeFraction))
	knee = math.min(knee, maxLevel - 1)

	if level <= 0 then
		return params.Start
	end
	if level >= maxLevel then
		return params.Floor
	end

	if level <= knee then
		local rate = (kneeValue / params.Start) ^ (1 / knee)
		return math.max(params.Start * (rate ^ level), params.Floor)
	end

	local tailLevels = maxLevel - knee
	local rate = (params.Floor / kneeValue) ^ (1 / tailLevels)
	return math.max(kneeValue * (rate ^ (level - knee)), params.Floor)
end

-- ============================================================
-- RESET FORMULAS
-- (inputAmount: BigNum, params) -> payout: BigNum
--
-- All of these work in LOG SPACE. Reset inputs are the whole run's
-- earnings, which is exactly the case BigNumber exists for — converting
-- to a plain number to raise it to a power saturates to infinity long
-- before a real player gets there, and hands back a NaN payout.
-- ============================================================

Formulas.Reset = {}

-- The standard prestige curve.
--
--     payout = (input / Threshold) ^ Exponent
--
-- Threshold is the point where the reset first pays out exactly 1, and
-- Exponent is how fast it creeps past that. Exponent 1 would be a flat
-- exchange rate: 10k -> 1, 20k -> 2, and resetting twice as late would
-- be worth exactly twice as much, which gives a player no reason to
-- push. Above 1 makes waiting longer worth MORE than proportionally
-- more, which is the entire tension of a prestige layer.
--
-- At Threshold 10,000 / Exponent 1.3:
--     10k  -> 1
--     15k  -> 1.69
--     25k  -> 3.4
--     100k -> 19.9
--     1M   -> 398
-- Gentle enough early that the first reset isn't a cliff, steep enough
-- later that sitting on a big bank feels rewarded.
function Formulas.Reset.PowerThreshold(
	inputAmount: BigNum,
	params: { Threshold: number, Exponent: number }
): BigNum
	if BigNumber.IsZero(inputAmount) or inputAmount.mantissa < 0 then
		return ZERO
	end

	local logInput = BigNumber.Log10(inputAmount)
	local logThreshold = math.log10(params.Threshold)
	local logPayout = params.Exponent * (logInput - logThreshold)

	if logPayout < 0 then
		return ZERO -- below the threshold: not worth anything yet
	end

	local exponent = math.floor(logPayout)
	local mantissa = 10 ^ (logPayout - exponent)
	return BigNumber.new(mantissa, exponent)
end

-- Softer alternative: linear past the threshold with no acceleration.
-- Here for balancing experiments — swap a scheme entry's Formula name.
function Formulas.Reset.LinearThreshold(
	inputAmount: BigNum,
	params: { Threshold: number }
): BigNum
	if BigNumber.IsZero(inputAmount) or inputAmount.mantissa < 0 then
		return ZERO
	end
	local payout = BigNumber.Div(inputAmount, BigNumber.FromNumber(params.Threshold))
	if BigNumber.LessThan(payout, BigNumber.FromNumber(1)) then
		return ZERO
	end
	return payout
end

return Formulas
