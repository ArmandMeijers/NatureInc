--!strict
--[[
	ResetScheme.luau

	Every reset layer in the game, as data. Same idea as UpgradeSchema:
	adding a layer is one entry here plus a board part in Workspace, and
	nothing in the reset code, the UI or the server changes.

	Each entry declares:
	  Name            display title on the board
	  Order           position in the progression, low to high
	  InputCurrency   what you spend (all of it)
	  OutputCurrency  what you get
	  Formula         a name in Formulas.Reset
	  Params          that formula's params
	  MinimumOutput   the reset is refused below this. 1 by default, so
	                  the threshold in the formula IS the unlock point —
	                  no second number to keep in sync with it.
	  ResetCurrencies         dot-path currencies wiped, e.g. "Leafs"
	  ResetUpgradeCategories  Template.Upgrades.<X> blocks wiped
	  ClearSpawnedLeaves      wipe leaves already on the platform

	WHAT A RESET CLEARS IS LISTED EXPLICITLY rather than inferred from
	Order. "Everything below this layer" is the usual convention and it's
	right most of the time — but the exception always arrives eventually
	(a currency that survives on purpose, a rune track that shouldn't
	roll back), and by then the inference is load-bearing in three
	places. Listing it costs one line per layer and never surprises
	anyone.

	Composting resets LEAF things only. Compost and Nut upgrades survive
	it deliberately: a layer that wiped the currency it pays out in would
	hand you compost and immediately take the upgrades you bought with it.

	Location: ReplicatedStorage/Modules/Resets/ResetScheme.luau
]]

local ResetScheme = {}

ResetScheme.All = {
	Composting = {
		Name = "Composting",
		Order = 1,

		InputCurrency = "Leafs",
		OutputCurrency = "Compost",

		-- 10k -> 1, 15k -> ~1.7, 100k -> ~20. See Formulas.Reset.
		Formula = "PowerThreshold",
		Params = { Threshold = 10000, Exponent = 1.3 },
		MinimumOutput = 1,

		ResetCurrencies = { "Leafs" },
		ResetUpgradeCategories = { "LeafUpgrades" },
		ClearSpawnedLeaves = true,

		-- Purely cosmetic; the board falls back to Name if absent.
		BoardTitle = "Composting",
	},

	-- ============================================================
	-- The next layer goes here. Copy the block above, point Input at
	-- Compost and Output at whatever it produces, and list
	-- ResetCurrencies = { "Leafs", "Compost" } plus both upgrade
	-- categories — spelled out, not inherited from Order.
	-- ============================================================
}

-- Ids in progression order. Sorted here rather than at each call site so
-- every surface agrees, and because a generic `for` over All walks a hash
-- table in undefined order.
function ResetScheme.GetOrder(): { string }
	local ids = {}
	for resetId in ResetScheme.All do
		table.insert(ids, resetId)
	end
	table.sort(ids, function(a, b)
		local orderA = ResetScheme.All[a].Order or 1000
		local orderB = ResetScheme.All[b].Order or 1000
		if orderA == orderB then
			return a < b
		end
		return orderA < orderB
	end)
	return ids
end

function ResetScheme.Get(resetId: string)
	return ResetScheme.All[resetId]
end

return ResetScheme
