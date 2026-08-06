--!strict
--[[
	NutUpgrades.luau

	Schema for Template.Upgrades.NutUpgrades.

	NutChance uses DiminishingReturns on purpose: it's the chance a
	spawning leaf is REPLACED by a nut, so it must approach but never
	reach 100% — a formula that could hit 1.0 would mean no leaf ever
	spawns again, which breaks leaf income entirely at max level.
	DiminishingReturns is mathematically incapable of reaching its Max,
	so that failure mode can't happen however it's rebalanced later.

	The numbers are set so max level lands just under
	LeafConfig.MaxNutChance rather than at it:

	    DiminishingReturns(level) = Max * level / (level + K)
	    at level 99, Max 0.30, K 25  ->  0.2395
	    plus LeafConfig.BaseNutChance (0.01)  ->  0.2495

	So the last level is still worth buying — it isn't silently eaten by
	the clamp, which is what happens when a curve is tuned to exceed its
	own ceiling.

	Location: ReplicatedStorage/Modules/Upgrades/Schema/NutUpgrades.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local LeafConfig = require(ReplicatedStorage.Modules.LeafConfig)

return {
	NutMult = {
		Name = "Nut Multiplier",
		Order = 1,
		Category = "NutUpgrades",
		Tag = "NutValue",
		BoostType = "Multiplier",
		MaxLevel = 199,
		Currency = "Nuts",
		BaseCost = BigNumber.FromNumber(1),
		CostFormula = "Hybrid",
		CostParams = { Growth = 1.23, Power = 1.09 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.55 },
		Display = { Mode = "Multiplier" },
	},

	NutChance = {
		Name = "Nut Chance",
		Order = 2,
		Category = "NutUpgrades",
		Tag = "NutChance",
		BoostType = "Flat", -- a probability in 0..1, read directly
		MaxLevel = 99, -- reads 100
		Currency = "Nuts",
		BaseCost = BigNumber.FromNumber(10),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.25 },
		-- Approaches 30% and mathematically cannot reach it; with the 1%
		-- base that puts max level at ~24.95%, just under the ceiling.
		BoostFormula = "DiminishingReturns",
		BoostParams = { Max = 0.30, K = 25 },
		-- Base included so the board shows the player's ACTUAL chance
		-- ("1% -> 1.2%") rather than this upgrade's private contribution,
		-- which would read 0% at level 0 and mean nothing.
		Display = { Mode = "Percent", Base = LeafConfig.BaseNutChance, Decimals = 2 },
	},

	NutCompostMult = {
		Name = "Nutrient Rich",
		Order = 3,
		Category = "NutUpgrades",
		Tag = "CompostValue", -- nut spending feeding compost income
		BoostType = "Multiplier",
		MaxLevel = 99,
		Currency = "Nuts",
		BaseCost = BigNumber.FromNumber(25),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.3 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.18 },
		Display = { Mode = "Multiplier" },
	},

	NutLeafMult = {
		Name = "Nutty Growth",
		Order = 4,
		Category = "NutUpgrades",
		Tag = "LeafValue", -- nut spending feeding leaf income
		BoostType = "Multiplier",
		MaxLevel = 99,
		Currency = "Nuts",
		BaseCost = BigNumber.FromNumber(25),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.3 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.18 },
		Display = { Mode = "Multiplier" },
	},
}
