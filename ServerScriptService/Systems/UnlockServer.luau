--[[
	UnlockServer.luau

	Wires GetUnlockState. Kept separate from UnlockService so that module
	stays a pure library other server code can require without also
	binding a remote as a side effect of being required.

	Waits for the profile before answering — a client that asks at join
	time would otherwise be told nothing is unlocked, and would hide
	content the player has actually earned until something forced a
	refresh.

	Location: ServerScriptService/Systems/UnlockServer.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local UnlockService = require(script.Parent:WaitForChild("UnlockService"))

local GetUnlockState = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Unlocks"):WaitForChild("GetUnlockState")

local PROFILE_WAIT_SECONDS = 30

local function waitForProfile(player: Player): boolean
	local deadline = os.clock() + PROFILE_WAIT_SECONDS
	while os.clock() < deadline do
		if DataManager.GetProfile(player) then
			return true
		end
		if player.Parent ~= Players then
			return false
		end
		task.wait(0.1)
	end
	return DataManager.GetProfile(player) ~= nil
end

GetUnlockState.OnServerInvoke = function(player: Player)
	if not waitForProfile(player) then
		warn(`UnlockServer: no profile for {player.Name} after {PROFILE_WAIT_SECONDS}s — returning an empty bundle.`)
		return {}
	end
	return UnlockService.GetBundle(player)
end
