--!strict
--[[
	RuneMath.luau

	Chances, luck, RPS and the rolling itself. Shared: the client shows
	the odds and the projected RPS, the server rolls against them. Two
	implementations would drift, and the visible symptom would be a panel
	advertising odds the game doesn't use.

	Location: ReplicatedStorage/Modules/Runes/RuneMath.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local RuneConfig = require(ReplicatedStorage.Modules.Runes.RuneConfig)
local RuneScheme = require(ReplicatedStorage.Modules.Runes.RuneScheme)

type BigNum = BigNumber.BigNum

local RuneMath = {}

local ZERO = BigNumber.new(0, 0)
local ONE = BigNumber.FromNumber(1)

-- ============================================================
-- LUCK
--
-- Luck raises rare chances and, because everything is renormalised
-- afterwards, that necessarily lowers common ones. A type's exponent is
-- its position in the rarity list scaled to 0..1 — the commonest gets
-- luck^0 (no help at all) and the rarest luck^1 (the full multiplier),
-- with everything between scaled smoothly.
--
-- Exponent rather than multiplication is what makes this hold up across
-- the whole game. Multiplying every rare by luck equally means a x1000
-- luck player finds Divine and Celestial at the same ratio they always
-- did. Weighting by rarity means luck reshapes the whole table, which is
-- what makes stacking it feel like progression rather than a flat bonus.
--
-- Commons going unobtainable falls out of this rather than being a rule:
-- their normalised share keeps shrinking until it crosses
-- RuneConfig.UnobtainableChance, at which point they're dropped and
-- their share redistributed.
-- ============================================================

export type ChanceEntry = {
	Id: string,
	Name: string,
	Chance: number,
	OneIn: number,
	Obtainable: boolean,
	Color: Color3?,
}

function RuneMath.GetChances(runeId: string, luck: number?, luckEnabled: boolean?): { ChanceEntry }
	local rune = RuneScheme.Get(runeId)
	if not rune then
		return {}
	end

	local types = rune.Types
	local count = #types
	local effectiveLuck = luck or 1

	if not rune.UsesRuneLuck or luckEnabled == false or effectiveLuck <= 1 or count < 2 then
		effectiveLuck = 1
	end

	local weights = table.create(count)
	local total = 0

	for index, entry in types do
		-- 0 for the commonest, 1 for the rarest.
		local rarity = (index - 1) / (count - 1)
		local weight = entry.Chance * (effectiveLuck ^ rarity)
		weights[index] = weight
		total += weight
	end

	if total <= 0 then
		return {}
	end

	-- Drop anything squeezed below the floor, then renormalise what's
	-- left so the column still sums to 1.
	local keptTotal = 0
	local kept = table.create(count)
	for index in types do
		local share = weights[index] / total
		local obtainable = share >= RuneConfig.UnobtainableChance
		kept[index] = obtainable
		if obtainable then
			keptTotal += weights[index]
		end
	end

	if keptTotal <= 0 then
		keptTotal = total
		for index in types do
			kept[index] = true
		end
	end

	local result = table.create(count)
	for index, entry in types do
		local chance = kept[index] and (weights[index] / keptTotal) or 0
		table.insert(result, {
			Id = entry.Id,
			Name = entry.Name,
			Chance = chance,
			OneIn = chance > 0 and (1 / chance) or math.huge,
			Obtainable = chance > 0,
			Color = entry.Color,
		})
	end

	return result
end

-- ============================================================
-- RUNE BOOSTS
--
-- multiplier = min(1 + count * Per, Max), multiplied across every type
-- that boosts the tag. Counts are BigNumbers and Max is small, so the
-- comparison happens in BigNumber space and only the RESULT is a plain
-- number — converting a count of 1e40 to compare it against 5 would
-- saturate long before the cap was reached.
-- ============================================================
function RuneMath.GetBoostMultiplier(counts: { [string]: BigNum }, tag: string): number
	local total = 1

	for runeId, rune in RuneScheme.All do
		for _, entry in rune.Types do
			local boost = entry.Boosts and entry.Boosts[tag]
			if boost then
				local count = counts[entry.Id] or ZERO
				local raw = BigNumber.Add(ONE, BigNumber.Mul(count, BigNumber.FromNumber(boost.Per)))
				local capped = BigNumber.GreaterThan(raw, BigNumber.FromNumber(boost.Max))
					and boost.Max
					or BigNumber.ToNumber(raw)
				total *= capped
			end
		end
	end

	return total
end

-- ============================================================
-- RPS
-- ============================================================
function RuneMath.GetRunesPerSecond(bulk: BigNum, speed: BigNum): BigNum
	return BigNumber.Mul(bulk, speed)
end

-- How many rolls a tick has earned, given leftover fractional rolls from
-- previous ticks. Carrying the remainder is what keeps slow speeds exact
-- instead of rounding to zero every tick and never rolling at all.
function RuneMath.GetRollsForTick(speed: BigNum, deltaTime: number, carry: BigNum): (BigNum, BigNum)
	local earned = BigNumber.Add(carry, BigNumber.Mul(speed, BigNumber.FromNumber(deltaTime)))
	if BigNumber.LessThan(earned, ONE) then
		return ZERO, earned
	end

	-- Past a few digits the fractional part is meaningless, so only small
	-- values bother tracking a remainder.
	if earned.exponent > 12 then
		return earned, ZERO
	end

	local whole = math.floor(BigNumber.ToNumber(earned))
	local wholeBig = BigNumber.FromNumber(whole)
	return wholeBig, BigNumber.Sub(earned, wholeBig)
end

-- ============================================================
-- ROLLING
--
-- Small batches are rolled one at a time so early game is genuinely
-- random. Large ones use the EXPECTED count instead: at 1e30 rolls you
-- cannot loop, and the law of large numbers means the expectation is
-- what you'd get anyway — the variance around it is invisible at that
-- scale.
--
-- Types whose expected count is below 1 keep their randomness: they're
-- granted 1 with probability equal to the expectation. Without that, a
-- rare type would go from "sometimes" to "never" the moment a player
-- crossed the batching threshold, because its expectation floors to 0.
-- ============================================================
function RuneMath.RollBatch(chances: { ChanceEntry }, totalRunes: BigNum): { [string]: BigNum }
	local gains: { [string]: BigNum } = {}
	if BigNumber.IsZero(totalRunes) then
		return gains
	end

	local asNumber = BigNumber.ToNumber(totalRunes)

	if totalRunes.exponent < 6 and asNumber <= RuneConfig.ExactRollLimit then
		for _ = 1, math.floor(asNumber) do
			local roll = math.random()
			local cumulative = 0
			for _, entry in chances do
				if entry.Obtainable then
					cumulative += entry.Chance
					if roll <= cumulative then
						gains[entry.Id] = BigNumber.Add(gains[entry.Id] or ZERO, ONE)
						break
					end
				end
			end
		end
		return gains
	end

	for _, entry in chances do
		if entry.Obtainable then
			local expected = BigNumber.Mul(totalRunes, BigNumber.FromNumber(entry.Chance))
			if BigNumber.GreaterThanOrEqual(expected, ONE) then
				gains[entry.Id] = expected
			else
				local probability = BigNumber.ToNumber(expected)
				if probability > 0 and math.random() < probability then
					gains[entry.Id] = ONE
				end
			end
		end
	end

	return gains
end

-- ONE type's contribution to ONE tag, plus whether it's capped.
--
-- GetBoostMultiplier answers "what is my total", which is what the
-- game needs; this answers "what is this rune giving me", which is
-- what the menu needs. Same formula, different question — and the
-- capped flag is only meaningful per type, since a total has no
-- maximum of its own.
function RuneMath.GetTypeBoost(count: BigNum, boost: { Per: number, Max: number }): (number, boolean)
	local raw = BigNumber.Add(ONE, BigNumber.Mul(count, BigNumber.FromNumber(boost.Per)))
	if BigNumber.GreaterThanOrEqual(raw, BigNumber.FromNumber(boost.Max)) then
		return boost.Max, true
	end
	return BigNumber.ToNumber(raw), false
end

return RuneMath
