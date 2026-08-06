--!strict
--[[
	LeafUpgrades.luau

	Schema for everything under Template.Upgrades.LeafUpgrades. Keys here
	MUST match Template exactly.

	Every entry declares:
	  Name        display title, shown at the top of its board card
	  Order       position on the board. Lua hash iteration has no
	              defined order, so "the order I typed them in" isn't
	              recoverable — it has to be written down.
	  Category    which Template.Upgrades.<X> block it lives in
	  Tag         WHICH STAT this feeds. Upgrades across different
	              categories can share a Tag and they all stack into that
	              one stat automatically.
	  BoostType   how the value combines
	  MaxLevel    hard ceiling. The board shows level+1 / MaxLevel+1, so
	              an unbought upgrade reads 1/30 rather than 0/29 — these
	              caps are set one below a round number on purpose.
	  BaseCost + CostFormula + CostParams   -> Formulas.Cost.<name>
	  BoostFormula + BoostParams            -> Formulas.Boost.<name>
	  Currency    what you pay with
	  Display     how the board writes the value:
	                Flat        +10 -> +11
	                Multiplier  x10 -> x23
	                Seconds     3s -> 2.3s
	                Studs       5 studs -> 6 studs   (needs Base)
	                Percent     15% -> 16%
	              Base is the zero-upgrade value from LeafConfig, so
	              absolute stats read as the number the player actually
	              has rather than as a delta.

	Location: ReplicatedStorage/Modules/Upgrades/Schema/LeafUpgrades.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local LeafConfig = require(ReplicatedStorage.Modules.LeafConfig)

return {
	LeafAdd = {
		Name = "Leaf Value",
		Order = 1,
		Category = "LeafUpgrades",
		Tag = "LeafValue",
		BoostType = "Flat",
		MaxLevel = 199, -- reads 100 on the board
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(5),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.15 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 1 },
		Display = { Mode = "Flat" },
	},

	LeafMult = {
		Name = "Leaf Multiplier",
		Order = 2,
		Category = "LeafUpgrades",
		Tag = "LeafValue",
		BoostType = "Multiplier",
		MaxLevel = 99, -- reads 50
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(10),
		CostFormula = "Hybrid",
		CostParams = { Growth = 1.18, Power = 1.09 },
		-- Compounding on purpose: this is the upgrade meant to carry
		-- leaf income into BigNumber territory long-term.
		BoostFormula = "ExponentialGrowth",
		BoostParams = { Growth = 1.22 },
		Display = { Mode = "Multiplier" },
	},

	LeafSpawnRate = {
		Name = "Spawn Speed",
		Order = 3,
		Category = "LeafUpgrades",
		Tag = "LeafSpawnSpeed",
		-- SpeedInterval RESOLVES to an interval rather than combining
		-- like a boost — see BoostMath.GetSpawnInterval.
		BoostType = "SpeedInterval",
		-- 29 reads 30. IntervalDecay reshapes itself around whatever
		-- this is, so retuning the length of the upgrade is a one-number
		-- change — no solving for the rate that happens to land on the
		-- floor.
		MaxLevel = 29,
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(50),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.35 },
		-- 3s -> ~0.1s across the first two thirds, then 0.1 -> 0.01
		-- across the last third.
		BoostFormula = "IntervalDecay",
		BoostParams = {
			Start = LeafConfig.BaseSpawnInterval,
			Floor = LeafConfig.MinSpawnInterval,
			KneeValue = 0.1,
			KneeFraction = 2 / 3,
		},
		Display = { Mode = "Seconds", Decimals = 2 },
	},

	LeafCapacity = {
		Name = "Leaf Capacity",
		Order = 4,
		Category = "LeafUpgrades",
		Tag = "LeafCapacity",
		BoostType = "Flat",
		MaxLevel = 294, -- base 5 + 494 = 499, just under LeafConfig's 500 ceiling
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(25),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.2 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 1 },
		Display = { Mode = "Flat", Base = LeafConfig.BaseCapacity },
	},

	LeafRadius = {
		Name = "Collection Area",
		Order = 5,
		Category = "LeafUpgrades",
		Tag = "LeafCollectionArea",
		BoostType = "Flat",
		-- 9 reads 10. Base 5 + (9 x 0.5) = 9.5 studs, well inside
		-- LeafConfig.MaxCollectionRadius.
		MaxLevel = 9,
		Currency = "Leafs",
		BaseCost = BigNumber.FromNumber(200),
		CostFormula = "Exponential",
		CostParams = { Growth = 1.6 },
		BoostFormula = "Linear",
		BoostParams = { PerLevel = 0.5 },
		Display = { Mode = "Studs", Base = LeafConfig.BaseCollectionRadius, Decimals = 1 },
	},
}
