--!strict
--[[
	UnlockScheme.luau

	The rules for reading Template.Unlocks. Shared, because the server
	decides what's unlocked and the client decides what to show, and they
	must agree on what "unlocked" means.

	WHAT COUNTS AS UNLOCKED: anything except nil, false and 0.

	That third one is the important one. Template.Unlocks mixes booleans
	(Runes.LeafRune = false) with numbers (Features.Nuts = 0), and a
	number is there so a feature can later be unlocked to a LEVEL rather
	than just on — tiers of an area, rune slots, that sort of thing.
	Plain Lua truthiness would call 0 unlocked, since only nil and false
	are falsy in Lua. Every check goes through IsUnlockedValue so that
	trap exists in one place instead of at every call site.

	PATHS are dot-paths into Template.Unlocks: "Features.Nuts",
	"UpgradeBoards.Nuts", "Runes.LeafRune". Aliases below let an instance
	in Workspace carry a short name instead, so level design doesn't have
	to mirror the data layout.

	TO GATE ANYTHING: put an "UnlockPath" attribute on it in Workspace.
	No code anywhere needs to know what it is.

	Location: ReplicatedStorage/Modules/Unlocks/UnlockScheme.luau
]]

local UnlockScheme = {}

-- The attribute a world instance carries to say what gates it.
UnlockScheme.AttributeName = "UnlockPath"

-- Short names usable in the attribute instead of the full dot-path.
-- Purely a convenience; the full path always works too.
UnlockScheme.Aliases = {
	Nuts        = "Features.Nuts",
	NutBoard    = "UpgradeBoards.Nuts",
	LeafBoard   = "UpgradeBoards.Leafs",
	CompostBoard = "UpgradeBoards.Compost",
	CompostReset = "ResetBoards.CompostBoard",
	LeafRune    = "Runes.LeafRune",
	Area1       = "Areas.Area1",
}

function UnlockScheme.Resolve(path: string): string
	return UnlockScheme.Aliases[path] or path
end

-- nil, false and 0 are locked. Everything else is unlocked.
function UnlockScheme.IsUnlockedValue(value: any): boolean
	if value == nil or value == false then
		return false
	end
	if type(value) == "number" and value <= 0 then
		return false
	end
	return true
end

-- Turns a nested Unlocks table into { ["Features.Nuts"] = 0, ... }.
-- Flat is what both sides actually want: one lookup, no walking, and a
-- shape that survives being sent over a remote unchanged.
function UnlockScheme.Flatten(source: { [string]: any }, prefix: string?, into: { [string]: any }?): { [string]: any }
	local result = into or {}
	for key, value in source do
		local path = prefix and (prefix .. "." .. key) or key
		if type(value) == "table" then
			UnlockScheme.Flatten(value, path, result)
		else
			result[path] = value
		end
	end
	return result
end

return UnlockScheme
