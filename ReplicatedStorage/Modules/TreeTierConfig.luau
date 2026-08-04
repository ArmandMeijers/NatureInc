--[[
	TreeTierConfig.luau

	Single source of truth for every tree tier: its cost to reach, the
	boosts it grants (current tier only — tiers don't stack), what it
	unlocks, what gets reset on tier-up, and which model represents it.
	Read by both client (UI preview, local tree model) and server
	(validation).

	ADDING A TIER IS ONE EDIT: append a TreeTierConfig[4] block below.
	Nothing anywhere counts tiers by hand — the pip track on the board,
	the MAXED state, TreeTierService's MAX_TIER and TreeTierPreview all
	read #TreeTierConfig. Add the block, add a TreeTier4 model to
	ReplicatedStorage.Assets.TreeModels, done.

	Boosts: each entry is { Amount = number, Type = "Additive" |
	"Multiplicative" | "Power" }. Fed straight into BoostMath.Calculate.

	A currency with NO Boosts entry at a given tier is treated as not yet
	unlocked at that tier, and the board renders nothing for it — that's
	the whole fix for the old "—  ->  1x" Nuts line. Give a currency its
	first Boosts entry on the tier that unlocks it (Nuts at tier 3), and
	from the tier after that it reads as a normal progression.

	Unlocks: mirrors the exact nested shape of Template.Unlocks.
	TreeTierService walks this recursively and sets the matching path(s)
	to the given value — no per-field mapping code needed.

	Reveals: DISPLAY ONLY, and deliberately separate from Unlocks.
	Unlocks is a set of data paths; what a player should be TOLD they're
	about to get is a different question with a different answer.
	"UpgradeBoards = { Nuts = true }" is not a sentence anyone wants to
	read on a board. Each entry is { Label = string, Currency = string? }
	— Currency is optional and only used to pull that currency's icon and
	gradient for the badge.

	A tier's Reveals describe what tiering INTO it grants, so they render
	on the board while the player is still on the tier below. Tier 3's
	Nuts entry is why the tier 2 board reads UNLOCK NUTS.

	If a currency gains its first Boosts entry on a tier but has no
	matching Reveals entry, TreeTierPreview synthesises one, so a new
	currency can never silently vanish from the board because someone
	forgot this field.

	Resets: dot-paths (same syntax as DataManager.Get/Set) that get reset
	to their Template default value on tier-up.

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

TreeTierConfig[1] = {
	Cost = nil, -- starting tier, nothing to pay
	Boosts = {
		Leafs = { Amount = 1, Type = "Multiplicative" },
		Compost = { Amount = 1, Type = "Multiplicative" },
	},
	Unlocks = nil,
	Reveals = nil,
	Resets = nil,
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
	Model = "TreeTier2",
}

TreeTierConfig[3] = {
	Cost = { Currency = "Compost", Amount = BigNumber.FromNumber(500000) },
	Boosts = {
		Leafs = { Amount = 10, Type = "Multiplicative" },
		Compost = { Amount = 5, Type = "Multiplicative" },
		-- First Nuts entry: this is the tier that unlocks the currency,
		-- so 1x is its baseline rather than a boost anyone earned. The
		-- tier 2 board shows the UNLOCK NUTS badge below instead of a
		-- meaningless "— -> 1x" row.
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
	Model = "TreeTier3",
}

-- ============================================================
-- TreeTierConfig[4] goes here when you're ready. Copy tier 3, raise the
-- numbers, and give Nuts a real progression value (e.g. 1.5) so the tier
-- 3 board starts reading "Nuts 1x -> 1.5x" instead of MAXED.
--
-- TreeTierConfig[4] = {
--     Cost = { Currency = "Nuts", Amount = BigNumber.FromNumber(25000) },
--     Boosts = {
--         Leafs = { Amount = 25, Type = "Multiplicative" },
--         Compost = { Amount = 12, Type = "Multiplicative" },
--         Nuts = { Amount = 1.5, Type = "Multiplicative" },
--     },
--     Unlocks = nil,
--     Reveals = nil,
--     Resets = DefaultResets,
--     Model = "TreeTier4",  -- must exist in Assets.TreeModels, or the
--                           -- player tiers up next to bare dirt
-- }
-- ============================================================

return TreeTierConfig
