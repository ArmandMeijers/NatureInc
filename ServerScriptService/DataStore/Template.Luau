--[[
	Template.luau

	The single source of truth for a player's data shape. This is the ONLY
	file you touch to add a new top-level category or field — ProfileStore's
	Profile:Reconcile() recursively merges any new key here into existing
	player saves automatically, no migration code needed.

	Location: ServerScriptService/DataStore/Template.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

local function zero()
	return BigNumber.Serialize(BigNumber.new(0, 0))
end

local Template = {}

Template.Currency = {
	Leafs = zero(),
	Compost = zero(),
	Nuts = zero(),
}

Template.Statistics = {

	TotalValues = {
		TotalLeavesCollected = zero(),
		TotalCompostCollected = zero(),
		TotalNutsCollected = zero(),
		TotalRunesOpened = zero(),
	},

	PlayTime = 0, -- seconds
	JoinCount = 0,
	RobuxSpent = 0,

}

Template.Tree = {
	TreeTier = 1,
}

Template.Unlocks = {
	-- Currency tiers
	Nuts = false,

	-- Upgrade boards
	UpgradeBoards = {
		Leafs = true,
		Compost = false,
		Nuts = false,
	},

	-- Runes
	Runes = {
		LeafRune = false,
	},

	-- Areas
	Areas = {
		Area1 = true,
	},

}

Template.Upgrades = {
	-- Leaf upgrades
	LeafUpgrades = {
		LeafAdd = 0,
		LeafMult = 0,
		LeafSpawnRate = 0,
		LeafCapacity = 0,
	},


	-- Compost upgrades
	CompostUpgrades = {	
		CompostMult = 0,
		CompostLeafMult = 0,
		CompostCollectionArea = 0,
		CompostLeafCapacity = 0,
	},

	-- Nuts upgrades
	NutUpgrades = {
		NutMult = 0,
		NutCompostMult = 0,
		NutLeafMult = 0,
		NutChance = 0,
	},
}

Template.Settings = {

	General = {
		NumberNotation = "scientific", -- "scientific" or "abbreviation"
		HidePlayers = false,
		HideMaxUpgrades = false,
	},

	Audio = {
		Music = true,
		SoundEffects = true,
	},

	Misc = {},

	CurrencyView = {
		Leafs = true,
		Compost = true,
		Nuts = true,
	}
}

-- Stackable resources — keyed by itemId, value is quantity.
-- e.g. Items["oak_leaf_bundle"] = 12
Template.Items = {}

--Runes where value equal quntaty of that rune (zeroed as rune may surpass e303)
Template.Runes = {
	LeafRune = {
		OakLeaf = zero(),
		MapleLeaf = zero(),
		CherryLeaf = zero(),
		GoldenLeaf = zero(),
		CrystalLeaf = zero(),
		CelestialLeaf = zero(),
		DivineLeaf = zero(),
	},
}

Template.Quests = {
}

return Template
