--[[
	UnlockService.luau

	Server-side answer to "has this player unlocked X". Every gameplay
	system that a feature gates should ask HERE rather than reading
	DataManager directly, so the nil/false/0 rule lives in one place.

	    local UnlockService = require(ServerScriptService.Systems.UnlockService)
	    if UnlockService.IsUnlocked(player, "Features.Nuts") then ... end

	HIDING A PART IS NOT DISABLING A MECHANIC. The client hides locked
	content, but a client that doesn't hide it — or an exploiter's — still
	can't spawn nuts, because the chance is zeroed and the award refused
	here.

	Location: ServerScriptService/Systems/UnlockService.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local Template = require(ServerScriptService.DataStore.Template)
local UnlockScheme = require(ReplicatedStorage.Modules.Unlocks.UnlockScheme)

local UnlockService = {}

-- Every path that exists, derived from the Template rather than listed.
-- Adding a field to Template.Unlocks makes it real everywhere with no
-- second edit.
local ALL_PATHS = {}
for path in UnlockScheme.Flatten(Template.Unlocks) do
	table.insert(ALL_PATHS, path)
end
table.sort(ALL_PATHS)

function UnlockService.GetPaths(): { string }
	return table.clone(ALL_PATHS)
end

function UnlockService.GetValue(player: Player, path: string): any
	return DataManager.Get(player, "Unlocks." .. UnlockScheme.Resolve(path))
end

function UnlockService.IsUnlocked(player: Player, path: string): boolean
	return UnlockScheme.IsUnlockedValue(UnlockService.GetValue(player, path))
end

-- Flat { ["Features.Nuts"] = 0, ... } for this player, ready to send.
function UnlockService.GetBundle(player: Player): { [string]: any }
	local bundle = {}
	for _, path in ALL_PATHS do
		bundle[path] = DataManager.Get(player, "Unlocks." .. path)
	end
	return bundle
end

-- For anything that grants an unlock outside a tier-up (a quest, a
-- purchase). Tier-ups go through TreeTierService's Unlocks table.
function UnlockService.SetUnlock(player: Player, path: string, value: any)
	DataManager.Set(player, "Unlocks." .. UnlockScheme.Resolve(path), value)
end

return UnlockService
