--!strict
--[[
	UpgradePurchase.luau

	How many levels a balance can afford, and what that costs in total.

	SHARED ON PURPOSE. The client needs this to show "20x" when you hover
	MAX; the server needs it to decide what MAX actually buys. Two
	implementations of the same summation would eventually disagree, and
	the visible symptom would be a button promising 20 and delivering 19.

	Costs are per-level and compounding, so there's no closed form to
	invert — it walks levels one at a time. Bounded by MaxIterations so a
	huge balance against a cheap upgrade can't stall a frame; the cap is
	high enough that only genuinely absurd cases hit it, and hitting it
	just means MAX buys fewer than theoretically possible, never more.

	Location: ReplicatedStorage/Modules/Upgrades/UpgradePurchase.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local UpgradeSchema = require(ReplicatedStorage.Modules.Upgrades.UpgradeSchema)

type BigNum = BigNumber.BigNum

local UpgradePurchase = {}

UpgradePurchase.MaxIterations = 5000

export type Plan = {
	Levels: number,     -- how many can be bought
	TotalCost: BigNum,  -- what they cost together
	NewLevel: number,   -- level after buying them
}

local ZERO = BigNumber.new(0, 0)

function UpgradePurchase.Plan(upgradeId: string, currentLevel: number, balance: BigNum): Plan
	local entry = UpgradeSchema.Get(upgradeId)
	if not entry then
		return { Levels = 0, TotalCost = ZERO, NewLevel = currentLevel }
	end

	local level = currentLevel
	local remaining = balance
	local total = ZERO
	local bought = 0

	while bought < UpgradePurchase.MaxIterations and level < entry.MaxLevel do
		local cost = UpgradeSchema.GetCost(upgradeId, level)
		if not cost or BigNumber.GreaterThan(cost, remaining) then
			break
		end
		remaining = BigNumber.Sub(remaining, cost)
		total = BigNumber.Add(total, cost)
		level += 1
		bought += 1
	end

	return { Levels = bought, TotalCost = total, NewLevel = level }
end

-- Convenience for the common "can I buy even one" check.
function UpgradePurchase.CanAffordNext(upgradeId: string, currentLevel: number, balance: BigNum): boolean
	local cost = UpgradeSchema.GetCost(upgradeId, currentLevel)
	if not cost then
		return false -- maxed
	end
	return BigNumber.GreaterThanOrEqual(balance, cost)
end

return UpgradePurchase
