--!strict
--[[
	LeafUpgrades.luau

	Schema for everything under Template.Upgrades.LeafUpgrades. Keys here
	MUST match Template exactly — UpgradeSchema validates that on load and
	warns loudly if they ever drift apart.

	Every entry declares:
	  Name        display name for UI
	  Category    which Template.Upgrades.<X> block it lives in
	  Tag         WHICH STAT this feeds. Multiple upgrades across
	              different categories can share one Tag and they all
	              stack into that one stat automatically — that's how
	              CompostLeafCapacity boosts the same LeafCapacity that
	              LeafCapacity does, with zero special-case code.
	  BoostType   how the value combines: "Flat" | "Multiplier" |
	              "Power" | "FinalMultiplier" | "SpeedInterval"
	  MaxLevel    hard ceiling; purchases refuse past it and saved data
	              is always clamped to it on read
	  BaseCost    cost of level 1
	  CostFormula + CostParams   -> Formulas.Cost.<name>
	  BoostFormula + BoostParams -> Formulas.Boost.<name>
	  Currency    what you pay with

	All numbers are placeholders — tune in here and Formulas.luau.

	Location: ReplicatedStorage/Modules/Upgrades/Schema/LeafUpgrades.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

return {
	LeafAdd = {
		Name = "Leaf Value",
		Category = "LeafUpgrades",
		Tag = "LeafValue",
		BoostType = "Flat",
		MaxLevel = 100,
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(10),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.15 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 1 },
	},

	LeafMult = {
		Name = "Leaf Multiplier",
		Category = "LeafUpgrades",
		Tag = "LeafValue",
		BoostType = "Multiplier",
		MaxLevel = 50,
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(100),
		CostFormula = "Hybrid",
		CostParams = { Growth = 1.22, Power = 1.1 },
		-- Compounding on purpose: this is the upgrade that's meant to
		-- carry leaf income into BigNumber territory long-term.
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.18 },
	},

	LeafSpawnRate = {
		Name = "Spawn Speed",
		Category = "LeafUpgrades",
		Tag = "LeafSpawnSpeed",
		-- SpeedInterval entries RESOLVE to an interval rather than
		-- combining like a boost — see BoostMath.GetSpawnInterval.
		BoostType = "SpeedInterval",
		MaxLevel = 50, -- the decay curve hits its 0.01 floor exactly here; higher levels would be dead purchases
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(50),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.25 },
		-- 3s -> 2.73 -> 2.48 -> ... -> 0.01 floor.
		BoostFormula = "ExponentialDecay",
		BoostParams = { Start = 3, Rate = 0.91, Floor = 0.01 },
	},

	LeafCapacity = {
		Name = "Leaf Capacity",
		Category = "LeafUpgrades",
		Tag = "LeafCapacity",
		BoostType = "Flat",
		MaxLevel = 495, -- base 5 + 495 = the 500 ceiling in LeafConfig
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(75),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.18 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 1 },
	},

	LeafRadius = {
		Name = "Collection Area",
		Category = "LeafUpgrades",
		Tag = "LeafCollectionArea",
		BoostType = "Flat",
		MaxLevel = 10,
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(200),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.3 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 0.5 },
	},
}

