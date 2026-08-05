--[[
	TreeTierConfig.luau

	Single source of truth for every tree tier: its cost to reach, the
	boosts it grants (current tier only — tiers don't stack), what it
	unlocks, what gets reset on tier-up, and which model represents it.

	ADDING A TIER IS ONE EDIT: append a TreeTierConfig[4] block. Nothing
	counts tiers by hand — the board's pip track, the MAXED state,
	TreeTierService's MAX_TIER and TreeTierPreview all read
	#TreeTierConfig.

	Resets            dot-paths reset to their Template default value.
	ResetUpgradeCategories
	                  which Template.Upgrades.<X> blocks get wiped. Listed
	                  as CATEGORIES rather than individual paths so adding
	                  an upgrade to a schema doesn't also require
	                  remembering to add it here — TreeTierService walks
	                  the schema for the actual paths. A tree reset is the
	                  game's main prestige; leaving upgrade levels intact
	                  through one made it nearly free.

	Reveals           DISPLAY ONLY, deliberately separate from Unlocks.
	                  Unlocks is a set of data paths; what a player should
	                  be TOLD they're getting is a different question.
	                  A tier's Reveals show while the player is on the
	                  tier below, which is why tier 3's Nuts entry is what
	                  puts UNLOCK NUTS on the tier 2 board.

	Location: ReplicatedStorage/Modules/TreeTierConfig.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

local TreeTierConfig = {}

local DefaultResets = {
	"Currency.Leafs",
	"Currency.Compost",
	"Currency.Nuts",
}

local DefaultUpgradeResets = {
	"LeafUpgrades",
	"CompostUpgrades",
	"NutUpgrades",
}

TreeTierConfig[1] = {
	Cost = nil, -- starting tier, nothing to pay
	Boosts = {
		Leafs = { Amount = 1, Type = "Multiplicative" },
		Compost = { Amount = 1, Type = "Multiplicative" },
	},
	Unlocks = nil,
	Reveals = nil,
	Resets = nil,
	ResetUpgradeCategories = nil,
	Model = "TreeTier1",
}

TreeTierConfig[2] = {
	Cost = { Currency = "Compost", Amount = BigNumber.FromNumber(50000) },
	Boosts = {
		Leafs = { Amount = 5, Type = "Multiplicative" },
		Compost = { Amount = 2, Type = "Multiplicative" },
	},
	Unlocks = {
		Runes = { LeafRune = true },
	},
	Reveals = {
		{ Label = "Leaf Runes" },
	},
	Resets = DefaultResets,
	ResetUpgradeCategories = DefaultUpgradeResets,
	Model = "TreeTier2",
}

TreeTierConfig[3] = {
	Cost = { Currency = "Compost", Amount = BigNumber.FromNumber(500000) },
	Boosts = {
		Leafs = { Amount = 10, Type = "Multiplicative" },
		Compost = { Amount = 5, Type = "Multiplicative" },
		-- First Nuts entry: the tier that unlocks the currency, so 1x is
		-- its baseline rather than a boost anyone earned. The tier 2
		-- board shows UNLOCK NUTS instead of a meaningless "— -> 1x".
		Nuts = { Amount = 1, Type = "Multiplicative" },
	},
	Unlocks = {
		Nuts = true,
		UpgradeBoards = { Nuts = true },
	},
	Reveals = {
		{ Label = "Nuts", Currency = "Nuts" },
	},
	Resets = DefaultResets,
	ResetUpgradeCategories = DefaultUpgradeResets,
	Model = "TreeTier3",
}

-- ============================================================
-- TreeTierConfig[4] goes here when you're ready. Copy tier 3, raise the
-- numbers, and give Nuts a real progression value (e.g. 1.5) so the tier
-- 3 board starts reading "Nuts 1x -> 1.5x" instead of MAXED.
--
-- Model must exist in ReplicatedStorage.Assets.TreeModels, or the player
-- tiers up next to bare dirt — TreeSpawnController warns and spawns
-- nothing for a model it can't find.
-- ============================================================

return TreeTierConfig
