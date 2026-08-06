--!strict
--[[
	CompostUpgrades.luau

	Schema for Template.Upgrades.CompostUpgrades — upgrades bought WITH
	Compost. Several carry LEAF tags: that's the cross-currency
	progression where spending compost improves your leaf operation. They
	need no special handling anywhere — sharing a Tag is the entire
	mechanism.

	Keys here MUST match Template exactly.

	Location: ReplicatedStorage/Modules/Upgrades/Schema/CompostUpgrades.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

-- Base walk speed a player has with zero upgrades. Kept in step with
-- PlayerSpeedController.BASE_WALK_SPEED so the board's "16 -> 17" is the
-- number the player actually gets.
local BASE_WALK_SPEED = 16

return {
	CompostMult = {
		Name = "Compost Multiplier",
		Order = 1,
		Category = "CompostUpgrades",
		Tag = "CompostValue",
		BoostType = "Multiplier",
		MaxLevel = 199, -- reads 100 on the board
		Currency = "Compost",
		BaseCost = BigNumber.FromNumber(1),
		CostFormula = "Hybrid",
		CostParams = { Growth = 1.18, Power = 1.09 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.2 },
		Display = { Mode = "Multiplier" },
	},

	CompostLeafMult = {
		Name = "Composted Leaves",
		Order = 2,
		Category = "CompostUpgrades",
		Tag = "LeafValue", -- compost spending feeding leaf income
		BoostType = "Multiplier",
		MaxLevel = 99,
		Currency = "Compost",
		BaseCost = BigNumber.FromNumber(5),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.25 },
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.25 },
		Display = { Mode = "Multiplier" },
	},

	CompostLeafCapacity = {
		Name = "Fertile Ground",
		Order = 3,
		Category = "CompostUpgrades",
		Tag = "LeafCapacity", -- stacks with LeafCapacity
		BoostType = "Flat",
		MaxLevel = 99,
		Currency = "Compost",
		BaseCost = BigNumber.FromNumber(25),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.2 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 2 },
		Display = { Mode = "Flat" },
	},

	CompostCollectionArea = {
		Name = "Wider Reach",
		Order = 4,
		Category = "CompostUpgrades",
		Tag = "LeafCollectionArea", -- stacks with LeafRadius
		BoostType = "Flat",
		MaxLevel = 9,
		Currency = "Compost",
		BaseCost = BigNumber.FromNumber(100),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.32 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 0.5 },
		Display = { Mode = "Studs" }, -- Base is added by the reader; see below
	},

	CompostWalkspeed = {
		Name = "Quick Feet",
		Order = 5,
		Category = "CompostUpgrades",
		-- Nothing else feeds WalkSpeed yet. PlayerSpeedController sums
		-- every upgrade carrying this tag, so a future "Nut Sprint" needs
		-- no code — just the same Tag.
		Tag = "WalkSpeed",
		BoostType = "Flat",
		MaxLevel = 4, -- reads 20
		Currency = "Compost",
		BaseCost = BigNumber.FromNumber(1000),
		CostFormula = "Exponential",
		CostParams = { Growth = 2.2 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 1 },
		Display = { Mode = "Flat", Base = BASE_WALK_SPEED, Decimals = 0 },
	},
}
