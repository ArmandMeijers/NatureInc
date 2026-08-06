--!strict
--[[
	LeafRune.luau

	The first rune. Everything about a rune lives in a file like this one:
	what it costs, what its types are, how rare each is, and what each one
	boosts. Adding a rune is a new file plus one line in RuneScheme.

	TYPES ARE LISTED COMMONEST FIRST. That order is the rarity order, and
	RuneMath uses the index to decide how much luck helps a type — so the
	list order is meaningful, not cosmetic.

	CHANCE is a probability and the column should sum to 1. It's written
	as a plain number rather than "1 in N" because that's the form every
	calculation wants; the UI does the 1/x conversion for display.

	BOOSTS map a stat TAG to { Per, Max }:
	    multiplier = min(1 + count * Per, Max)
	The tags are the same ones the upgrade schemas use, which is what lets
	a rune and an upgrade stack on the same stat with no special handling
	anywhere. RuneBulk, RuneSpeed and RuneLuck feed back into the rune
	loop itself.

	Location: ReplicatedStorage/Modules/Runes/Schema/LeafRune.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

return {
	Name = "Leaf Rune",
	Order = 1,

	Currency = "Leafs",
	CostPerRoll = BigNumber.FromNumber(250),

	-- Where counts are saved. Must match Template.Runes.<key>.
	DataKey = "LeafRune",
	-- Bumped alongside Statistics.TotalValues.TotalRunesOpened.
	TotalStatPath = "Statistics.TotalValues.TotalLeafRunesOpened",

	-- Set false for a rune whose odds ignore Rune Luck entirely.
	UsesRuneLuck = true,

	-- Gates the rune's model, pad and panels. Tier 2 sets this.
	UnlockPath = "Runes.LeafRune",

	-- Commonest first. Chances sum to 1.
	Types = {
		{
			Id = "OakLeaf",
			Name = "Oak Leaf",
			Chance = 0.6,
			Color = Color3.fromRGB(150, 200, 120),
			Boosts = { LeafValue = { Per = 0.02, Max = 5 } },
		},
		{
			Id = "MapleLeaf",
			Name = "Maple Leaf",
			Chance = 0.25,
			Color = Color3.fromRGB(230, 140, 70),
			Boosts = {
				CompostValue = { Per = 0.02, Max = 5 },
				RuneBulk = { Per = 0.05, Max = 3 },
			},
		},
		{
			Id = "CherryLeaf",
			Name = "Cherry Leaf",
			Chance = 0.1,
			Color = Color3.fromRGB(240, 150, 190),
			Boosts = {
				LeafValue = { Per = 0.05, Max = 10 },
				CompostValue = { Per = 0.05, Max = 10 },
			},
		},
		{
			Id = "GoldenLeaf",
			Name = "Golden Leaf",
			Chance = 0.04,
			Color = Color3.fromRGB(255, 210, 80),
			Boosts = {
				LeafValue = { Per = 0.05, Max = 25 },
				CompostValue = { Per = 0.05, Max = 25 },
				RuneSpeed = { Per = 0.01, Max = 5 },
			},
		},
		{
			Id = "CrystalLeaf",
			Name = "Crystal Leaf",
			Chance = 0.008,
			Color = Color3.fromRGB(140, 220, 255),
			Boosts = {
				CompostValue = { Per = 0.25, Max = 30 },
				NutValue = { Per = 0.25, Max = 30 },
				RuneLuck = { Per = 0.01, Max = 3 },
			},
		},
		{
			Id = "CelestialLeaf",
			Name = "Celestial Leaf",
			Chance = 0.0018,
			Color = Color3.fromRGB(190, 150, 255),
			Boosts = {
				RuneLuck = { Per = 0.05, Max = 15 },
				RuneBulk = { Per = 0.1, Max = 10 },
				RuneSpeed = { Per = 0.1, Max = 5 },
			},
		},
		{
			Id = "DivineLeaf",
			Name = "Divine Leaf",
			Chance = 0.0002,
			Color = Color3.fromRGB(255, 245, 200),
			Boosts = {
				LeafValue = { Per = 1, Max = 100 },
				CompostValue = { Per = 1, Max = 100 },
				NutValue = { Per = 1, Max = 100 },
				RuneLuck = { Per = 0.5, Max = 10 },
				RuneBulk = { Per = 0.5, Max = 10 },
				RuneSpeed = { Per = 0.5, Max = 10 },
			},
		},
	},
}
