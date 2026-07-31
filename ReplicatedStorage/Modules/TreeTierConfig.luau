--[[
	TreeTierConfig.luau

	Single source of truth for every tree tier: its cost to reach, the
	boosts it grants (current tier only — tiers don't stack), what it
	unlocks, what gets reset on tier-up, and which model represents it.
	Read by both client (UI preview, local tree model) and server
	(validation). All numbers below are placeholders — adjust freely.

	Boosts: each entry is { Amount = number, Type = "Additive" |
	"Multiplicative" | "Power" }. Fed straight into BoostMath.Calculate.

	Unlocks: mirrors the exact nested shape of Template.Unlocks. TreeTierService
	walks this recursively and sets the matching path(s) to the given value —
	no per-field mapping code needed. Add/rename fields in Template.Unlocks
	freely; this just needs to point at valid paths under it.

	Resets: dot-paths (same syntax as DataManager.Get/Set) that get reset to
	their Template default value on tier-up.

	Location: ReplicatedStorage/Modules/TreeTierConfig.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

local TreeTierConfig = {}


local DefaultResets = {
	"Currency.Leafs",
	"Currency.Compost",
}

TreeTierConfig[1] = {
	Cost = nil, -- starting tier, nothing to pay
	Boosts = {
		Leafs = { Amount = 1, Type = "Multiplicative" },
		Compost = { Amount = 1, Type = "Multiplicative" },
	},
	Unlocks = nil,
	Resets = nil,
	Model = "TreeTier1",
}

TreeTierConfig[2] = {
	Cost = { Currency = "Compost", Amount = BigNumber.FromNumber(500000) },
	Boosts = {
		Leafs = { Amount = 3, Type = "Multiplicative" },
		Compost = { Amount = 1.5, Type = "Multiplicative" },
	},
	Unlocks = {
		UpgradeBoards = { Compost = true },
		Runes = { LeafRune = true },
	},
	Resets = DefaultResets,
	Model = "TreeTier2",
}

TreeTierConfig[3] = {
	Cost = { Currency = "Compost", Amount = BigNumber.FromNumber(5000000) },
	Boosts = {
		Leafs = { Amount = 6, Type = "Multiplicative" },
		Compost = { Amount = 2, Type = "Multiplicative" },
		Nuts = { Amount = 1, Type = "Multiplicative" },
	},
	Unlocks = {
		UpgradeBoards = { Nuts = true },
	},
	Resets = DefaultResets
	Model = "TreeTier3",
}

return TreeTierConfig
