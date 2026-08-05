--!strict
--[[
	ResetMath.luau

	What a reset would pay out, and whether it's allowed.

	SHARED BETWEEN CLIENT AND SERVER on purpose. The board shows a live
	payout as your leaves tick up; the server decides what you actually
	receive. Two implementations of the same curve would eventually
	disagree, and the visible symptom is a board promising 4 compost and
	a reset handing over 3.

	Location: ReplicatedStorage/Modules/Resets/ResetMath.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local Formulas = require(ReplicatedStorage.Modules.Upgrades.Formulas)
local ResetScheme = require(ReplicatedStorage.Modules.Resets.ResetScheme)

type BigNum = BigNumber.BigNum

local ResetMath = {}

local ZERO = BigNumber.new(0, 0)

function ResetMath.GetPayout(resetId: string, inputBalance: BigNum): BigNum
	local entry = ResetScheme.Get(resetId)
	if not entry or not inputBalance then
		return ZERO
	end

	local formula = Formulas.Reset[entry.Formula]
	if not formula then
		warn(`ResetMath: '{resetId}' references unknown reset formula '{tostring(entry.Formula)}'`)
		return ZERO
	end

	return formula(inputBalance, entry.Params)
end

function ResetMath.CanReset(resetId: string, inputBalance: BigNum): boolean
	local entry = ResetScheme.Get(resetId)
	if not entry then
		return false
	end
	local payout = ResetMath.GetPayout(resetId, inputBalance)
	local minimum = BigNumber.FromNumber(entry.MinimumOutput or 1)
	return BigNumber.GreaterThanOrEqual(payout, minimum)
end

-- How much input is needed to reach MinimumOutput, for a "you need X
-- more" hint. Inverts the curve in log space rather than searching.
function ResetMath.GetRequiredInput(resetId: string): BigNum
	local entry = ResetScheme.Get(resetId)
	if not entry then
		return ZERO
	end

	local minimum = entry.MinimumOutput or 1
	local params = entry.Params

	if entry.Formula == "PowerThreshold" then
		-- payout = (input / T) ^ E  ->  input = T * minimum ^ (1 / E)
		local logInput = math.log10(params.Threshold) + math.log10(minimum) / params.Exponent
		local exponent = math.floor(logInput)
		return BigNumber.new(10 ^ (logInput - exponent), exponent)
	elseif entry.Formula == "LinearThreshold" then
		return BigNumber.FromNumber(params.Threshold * minimum)
	end

	-- Unknown curve: report the raw threshold rather than guessing.
	return BigNumber.FromNumber(params.Threshold or 0)
end

return ResetMath
