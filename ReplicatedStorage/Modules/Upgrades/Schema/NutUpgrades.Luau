--!strict
--[[
	NutUpgrades.luau

	Schema for Template.Upgrades.NutUpgrades.

	NutChance uses DiminishingReturns on purpose: it's the chance a
	spawning leaf is replaced by a nut, so it must approach but never
	reach 100% — a formula that could hit 1.0 would mean zero leaves ever
	spawn again, which would break leaf income entirely at max level.
	DiminishingReturns is mathematically incapable of reaching its Max,
	so that failure mode can't happen no matter how it's balanced later.

	Location: ReplicatedStorage/Modules/Upgrades/Schema/NutUpgrades.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

return {
	NutMult = {
		Name = "Nut Multiplier",
		Category = "NutUpgrades",
		Tag = "NutValue",
		BoostType = "Multiplier",
		MaxLevel = 500,
		Currency = "Nuts",
		BaseCost = BigNumber.FromNumber(10),
		CostFormula = "Hybrid",
		CostParams = { Growth = 1.26, Power = 1.1 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.22 },
	},

	NutCompostMult = {
		Name = "Nutrient Rich",
		Category = "NutUpgrades",
		Tag = "CompostValue", -- nut spending feeding compost income
		BoostType = "Multiplier",
		MaxLevel = 250,
		Currency = "Nuts",
		BaseCost = BigNumber.FromNumber(15),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.3 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.18 },
	},

	NutLeafMult = {
		Name = "Nutty Growth",
		Category = "NutUpgrades",
		Tag = "LeafValue", -- nut spending feeding leaf income
		BoostType = "Multiplier",
		MaxLevel = 250,
		Currency = "Nuts",
		BaseCost = BigNumber.FromNumber(12),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.3 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.2 },
	},

	NutChance = {
		Name = "Nut Chance",
		Category = "NutUpgrades",
		Tag = "NutChance",
		BoostType = "Flat", -- a probability in 0..1, read directly
		MaxLevel = 100,
		Currency = "Nuts",
		BaseCost = BigNumber.FromNumber(20),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.35 },
		-- Approaches 35% and mathematically cannot reach it (see header).
		BoostFormula = "DiminishingReturns",
		BoostParams = { Max = 0.35, K = 60 },
	},
}

