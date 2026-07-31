--[[
	BoostMath.luau

	One place that defines how boosts combine, no matter where they come
	from. Every boost-granting system (tree tiers now; upgrade boards,
	runes, quests, prestige later) produces a list of entries in the same
	shape and hands it here — nobody writes their own "total multiplier"
	math per system.

	Combine order: (1 + ΣAdditive) × ΠMultiplicative, then raised to the
	power of (1 + ΣPower). With no Power entries that's just ^1, a no-op.

	Location: ReplicatedStorage/Modules/BoostMath.luau
]]

export type BoostType = "Additive" | "Multiplicative" | "Power"
export type BoostEntry = { Amount: number, Type: BoostType }

local BoostMath = {}

function BoostMath.Calculate(entries: { BoostEntry }): number
	local additive = 0
	local multiplicative = 1
	local power = 0

	for _, entry in entries do
		if entry.Type == "Additive" then
			additive += entry.Amount
		elseif entry.Type == "Multiplicative" then
			multiplicative *= entry.Amount
		elseif entry.Type == "Power" then
			power += entry.Amount
		else
			warn(`BoostMath.Calculate: unknown boost type '{tostring(entry.Type)}'`)
		end
	end

	local total = (1 + additive) * multiplicative
	if power ~= 0 then
		total = total ^ (1 + power)
	end
	return total
end

-- Convenience: the boost entries a currency gets from the tree tier system
-- alone (current tier only, tiers don't stack). Returns {} if that tier
-- grants nothing for this key.
function BoostMath.GetTreeTierEntries(TreeTierConfig, currentTier: number, currencyKey: string): { BoostEntry }
	local tierData = TreeTierConfig[currentTier]
	if not tierData or not tierData.Boosts or not tierData.Boosts[currencyKey] then
		return {}
	end
	return { tierData.Boosts[currencyKey] }
end

return BoostMath