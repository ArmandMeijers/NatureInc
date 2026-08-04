--!strict
--[[
	TreeTierPreview.luau

	Turns "what tier is the player on" into "what should the UI say", as
	plain data. No Instances, no theme, no signals — so the rules about
	what's shown live in one readable place instead of being tangled
	through UI construction code, and anything that needs to describe a
	tier (the board, the top progress bar, a quest, a tooltip) gets the
	same answer without reimplementing it.

	THE RULE THAT MATTERS. A currency shows a boost row only if it has a
	Boosts entry on the CURRENT tier. If its first entry appears on the
	next tier, that's an unlock, not a boost, and it goes in Reveals
	instead. That's what turns the old "Nuts   —  ->  1x" into "UNLOCK
	NUTS" on tier 2, and lets tier 3 onward read "Nuts  1x -> 1.5x" like
	any other currency.

	Ordering comes from CurrencyOrder, the same shared list the HUD uses,
	so no surface can drift out of order with the rest of the game.

	Location: ReplicatedStorage/Modules/TreeTierPreview.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local CurrencyOrder = require(ReplicatedStorage.Modules.CurrencyOrder)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)

export type BoostRow = {
	Currency: string,
	CurrentText: string,
	NextText: string?, -- nil when maxed: show the current value alone
}

export type Reveal = {
	Label: string,
	Currency: string?,
}

export type Preview = {
	Tier: number,
	NextTier: number?,
	MaxTier: number,
	IsMaxed: boolean,
	Boosts: { BoostRow },
	Reveals: { Reveal },
	Cost: { Currency: string, Amount: any }?,
}

local TreeTierPreview = {}

function TreeTierPreview.GetMaxTier(): number
	return #TreeTierConfig
end

-- "5x", "+12", "^2". Kept here rather than in the UI so every surface
-- that describes a boost describes it identically.
function TreeTierPreview.FormatBoost(entry: { Amount: number, Type: string }?): string
	if not entry then
		return "—"
	elseif entry.Type == "Additive" then
		return "+" .. tostring(entry.Amount)
	elseif entry.Type == "Power" then
		return "^" .. tostring(entry.Amount)
	end
	return tostring(entry.Amount) .. "x" -- Multiplicative
end

-- How far along the player is toward a cost, as 0..1. Shared by the
-- board's cost bar and the top progress bar, because two copies of this
-- would eventually disagree and one of them would be the one on screen.
--
-- The division happens in BigNumber space FIRST. Converting each side to
-- a plain number and dividing looks equivalent and isn't: these values
-- routinely sit past what a double can hold, so both sides saturate to
-- infinity and the result comes out as a NaN.
function TreeTierPreview.GetRatio(balance: any, costAmount: any): number
	if not balance or not costAmount or BigNumber.IsZero(costAmount) then
		return 0
	end
	return math.clamp(BigNumber.ToNumber(BigNumber.Div(balance, costAmount)), 0, 1)
end

function TreeTierPreview.Build(tier: number): Preview
	local currentData = TreeTierConfig[tier]
	local nextData = TreeTierConfig[tier + 1]

	local boosts: { BoostRow } = {}
	local reveals: { Reveal } = {}
	local revealedCurrencies: { [string]: boolean } = {}

	-- Author-written reveals first, so their wording and order wins.
	if nextData and nextData.Reveals then
		for _, reveal in nextData.Reveals do
			table.insert(reveals, { Label = reveal.Label, Currency = reveal.Currency })
			if reveal.Currency then
				revealedCurrencies[reveal.Currency] = true
			end
		end
	end

	for _, currencyName in CurrencyOrder do
		local currentBoost = currentData and currentData.Boosts and currentData.Boosts[currencyName]
		local nextBoost = nextData and nextData.Boosts and nextData.Boosts[currencyName]

		if currentBoost then
			-- Already unlocked: a normal current -> next progression.
			table.insert(boosts, {
				Currency = currencyName,
				CurrentText = TreeTierPreview.FormatBoost(currentBoost),
				NextText = nextBoost and TreeTierPreview.FormatBoost(nextBoost) or nil,
			})
		elseif nextBoost and not revealedCurrencies[currencyName] then
			-- First appearance on the next tier and nobody wrote a
			-- Reveals entry for it. Synthesise one rather than letting a
			-- brand new currency show up nowhere at all.
			table.insert(reveals, { Label = currencyName, Currency = currencyName })
			revealedCurrencies[currencyName] = true
		end
	end

	return {
		Tier = tier,
		NextTier = nextData and (tier + 1) or nil,
		MaxTier = TreeTierPreview.GetMaxTier(),
		IsMaxed = nextData == nil,
		Boosts = boosts,
		Reveals = reveals,
		Cost = nextData and nextData.Cost or nil,
	}
end

return TreeTierPreview
