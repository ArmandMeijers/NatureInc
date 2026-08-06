--!strict
--[[
	RuneScheme.luau

	Merges the per-rune schema files into one lookup, the same way
	UpgradeSchema does for upgrades. Adding a rune is a file in Schema/
	plus one line in SCHEMA_FILES.

	Every list it hands out is a COPY, because callers filter and sort
	them (unobtainable types, display order) and must not be able to
	scramble the shared table doing it.

	Location: ReplicatedStorage/Modules/Runes/RuneScheme.luau
]]

local schemaFolder = script.Parent.Schema

local SCHEMA_FILES = {
	LeafRune = require(schemaFolder.LeafRune),
}

local RuneScheme = {}

RuneScheme.All = SCHEMA_FILES

function RuneScheme.Get(runeId: string)
	return RuneScheme.All[runeId]
end

function RuneScheme.GetOrder(): { string }
	local ids = {}
	for runeId in RuneScheme.All do
		table.insert(ids, runeId)
	end
	table.sort(ids, function(a, b)
		local orderA = RuneScheme.All[a].Order or 1000
		local orderB = RuneScheme.All[b].Order or 1000
		if orderA == orderB then
			return a < b
		end
		return orderA < orderB
	end)
	return ids
end

function RuneScheme.GetType(runeId: string, typeId: string)
	local rune = RuneScheme.Get(runeId)
	if not rune then
		return nil
	end
	for _, entry in rune.Types do
		if entry.Id == typeId then
			return entry
		end
	end
	return nil
end

-- Dot-path to one type's saved count.
function RuneScheme.GetDataPath(runeId: string, typeId: string): string?
	local rune = RuneScheme.Get(runeId)
	if not rune then
		return nil
	end
	return `Runes.{rune.DataKey}.{typeId}`
end

return RuneScheme
