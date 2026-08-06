--!strict
--[[
	RuneTags.luau

	How a stat TAG is presented: what to call it, and which gradient to
	wear.

	Tags are the shared vocabulary between upgrades, runes and the stats
	that read them — "LeafValue" is a key, not a label. This is the one
	place that turns a key into something a player should read, so a tag
	renamed in a schema doesn't leave a different wording in three
	different panels.

	Art names index ReplicatedStorage.CurrencyVisuals.<Art>.<Art>GRAD via
	CurrencyArt, which is why the rune stats got folders there rather than
	a scheme of their own. Anything with no gradient falls back to the
	Color below.

	Location: ReplicatedStorage/Modules/Runes/RuneTags.luau
]]

local RuneTags = {}

RuneTags.Info = {
	LeafValue    = { Label = "Leafs",      Art = "Leafs",     Color = Color3.fromRGB(150, 220, 140) },
	CompostValue = { Label = "Compost",    Art = "Compost",   Color = Color3.fromRGB(200, 150, 90) },
	NutValue     = { Label = "Nuts",       Art = "Nuts",      Color = Color3.fromRGB(230, 160, 80) },
	RuneBulk     = { Label = "Rune Bulk",  Art = "RuneBulk",  Color = Color3.fromRGB(140, 200, 255) },
	RuneSpeed    = { Label = "Rune Speed", Art = "RuneSpeed", Color = Color3.fromRGB(255, 200, 120) },
	RuneLuck     = { Label = "Rune Luck",  Art = "RuneLuck",  Color = Color3.fromRGB(210, 160, 255) },
}

-- Order tags appear in a box. Unlisted tags fall to the end
-- alphabetically, so a new tag renders sensibly before anyone adds it
-- here.
RuneTags.Order = {
	"LeafValue",
	"CompostValue",
	"NutValue",
	"RuneBulk",
	"RuneSpeed",
	"RuneLuck",
}

function RuneTags.Get(tag: string)
	return RuneTags.Info[tag] or { Label = tag, Art = tag, Color = Color3.fromRGB(230, 230, 230) }
end

function RuneTags.Rank(tag: string): number
	for index, name in RuneTags.Order do
		if name == tag then
			return index
		end
	end
	return 1000
end

-- A type's boosts, sorted for display.
function RuneTags.SortedBoosts(boosts: { [string]: any }): { { Tag: string, Boost: any } }
	local list = {}
	for tag, boost in boosts do
		table.insert(list, { Tag = tag, Boost = boost })
	end
	table.sort(list, function(a, b)
		local rankA, rankB = RuneTags.Rank(a.Tag), RuneTags.Rank(b.Tag)
		if rankA == rankB then
			return a.Tag < b.Tag
		end
		return rankA < rankB
	end)
	return list
end

return RuneTags
