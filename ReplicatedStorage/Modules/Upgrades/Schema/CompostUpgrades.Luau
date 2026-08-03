--!strict
--[[
	CompostUpgrades.luau

	Schema for Template.Upgrades.CompostUpgrades — upgrades bought WITH
	Compost. Note two of these carry LEAF tags (LeafCollectionArea,
	LeafCapacity): that's the cross-currency progression you described,
	where spending compost improves your leaf operation. They need no
	special handling anywhere — sharing a Tag is the entire mechanism.

	Location: ReplicatedStorage/Modules/Upgrades/Schema/CompostUpgrades.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

return {
	CompostMult = {
		Name = "Compost Multiplier",
		Category = "CompostUpgrades",
		Tag = "CompostValue",
		BoostType = "Multiplier",
		MaxLevel = 100,
		Currency = "Compost",
		BaseCost = BigNumber.FromNumber(25),
		CostFormula = "Hybrid",
		CostParams = { Growth = 1.24, Power = 1.1 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.2 },
	},

	CompostLeafMult = {
		Name = "Composted Leaves",
		Category = "CompostUpgrades",
		Tag = "LeafValue", -- compost spending feeding leaf income
		BoostType = "Multiplier",
		MaxLevel = 250,
		Currency = "Compost",
		BaseCost = BigNumber.FromNumber(40),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.28 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.15 },
	},

	CompostCollectionArea = {
		Name = "Wider Reach",
		Category = "CompostUpgrades",
		Tag = "LeafCollectionArea", -- stacks with LeafRadius
		BoostType = "Flat",
		MaxLevel = 40,
		Currency = "Compost",
		BaseCost = BigNumber.FromNumber(60),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.32 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 0.5 },
	},

	CompostLeafCapacity = {
		Name = "Fertile Ground",
		Category = "CompostUpgrades",
		Tag = "LeafCapacity", -- stacks with LeafCapacity
		BoostType = "Flat",
		MaxLevel = 200,
		Currency = "Compost",
		BaseCost = BigNumber.FromNumber(50),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.2 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 2 },
	},
}

