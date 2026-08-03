--!strict
--[[
	LeafConfig.luau

	Every tunable number for the leaf spawn/collection loop, in one place.
	Change anything here and it takes effect everywhere — nothing else in
	the leaf system hardcodes these.

	UPGRADE SCHEME
	Template.Upgrades.LeafUpgrades already has four level counters
	(LeafAdd, LeafMult, LeafSpawnRate, LeafCapacity) plus a fifth added
	here (LeafRadius, for the collection circle). UpgradeScheme below is
	what turns "level N" into an actual effect, and what STAT each level
	counter feeds. Stat names are deliberately prefixed "Leaf" --
	LeafValue / LeafCapacity / LeafSpeed / LeafRadius -- so a future
	collection board (say, one for Compost) can define its OWN
	similarly-shaped but distinctly-named scheme without any collision or
	ambiguity about which board an upgrade belongs to.

	LeafValue is the one stat that goes through BoostMath.Calculate,
	combined with whatever the tree tier grants for "Leafs" — that's
	genuinely a multiplier-stacking problem, which is exactly what
	BoostMath is for. Capacity/Speed/Radius are simple flat bonuses per
	level (see LeafBoostCalculator), not multiplier stacks, so they're
	computed directly instead of being forced through BoostMath — using
	one hammer for every nail here would just make the flat ones harder
	to read for no real benefit.

	Location: ReplicatedStorage/Modules/LeafConfig.luau
]]

local LeafConfig = {}

-- ============================================================
-- Base values (before any upgrades)
-- ============================================================

LeafConfig.BaseCapacity = 5 -- how many leaves can be on the platform at once
LeafConfig.MaxCapacity = 500 -- hard ceiling regardless of upgrades — see LeafSpawnController for why this scale is safe

LeafConfig.BaseSpawnInterval = 3 -- seconds between spawns
LeafConfig.MinSpawnInterval = 0.1 -- floor after upgrades

LeafConfig.BaseCollectionRadius = 5 -- studs
LeafConfig.MaxCollectionRadius = 30 -- sane ceiling

LeafConfig.BaseLeafValue = 1 -- value of ONE leaf before any multiplier

-- ============================================================
-- Upgrade scheme
-- Maps each Template.Upgrades.LeafUpgrades.* level counter to which
-- stat it affects and how much ONE level is worth. All placeholder
-- numbers — tune freely, nothing else needs to change to match.
-- ============================================================

export type UpgradeKind = "Additive" | "Multiplicative" | "IntervalReduction"

export type UpgradeDef = {
	Stat: "LeafValue" | "LeafCapacity" | "LeafSpeed" | "LeafRadius",
	Kind: UpgradeKind,
	PerLevel: number,
}

LeafConfig.UpgradeScheme = {
	-- Flat bonus to leaf value, e.g. level 3 = +3 before the multiplier.
	LeafAdd = { Stat = "LeafValue", Kind = "Additive", PerLevel = 1 },
	-- Multiplier on leaf value, expressed as +10%/level (linear, not
	-- compounding — level 3 = 1.3x, not 1.1^3). Combines with the tree
	-- tier's own Leafs boost via BoostMath.Calculate.
	LeafMult = { Stat = "LeafValue", Kind = "Multiplicative", PerLevel = 0.1 },
	-- Shaves this many seconds off the spawn interval per level, down to
	-- MinSpawnInterval.
	LeafSpawnRate = { Stat = "LeafSpeed", Kind = "IntervalReduction", PerLevel = 0.1 },
	-- Extra capacity slots per level.
	LeafCapacity = { Stat = "LeafCapacity", Kind = "Additive", PerLevel = 1 },
	-- Extra collection-circle radius (studs) per level.
	LeafRadius = { Stat = "LeafRadius", Kind = "Additive", PerLevel = 0.5 },
} :: { [string]: UpgradeDef }

return LeafConfig

