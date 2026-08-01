--[[
	CurrencyStatsService.luau

	Answers the client's request for "how much of every currency does
	this player have, and how much have they ever collected total" -- one
	bundle, one call, instead of the client needing a remote per currency.

	Reads which currencies exist from CurrencyOrder (ReplicatedStorage),
	the same shared list the stats menu iterates client-side, so server
	and client can never disagree about which currencies exist or what
	order they're in.

	Location: ServerScriptService/Systems/CurrencyStatsService.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local CurrencyOrder = require(ReplicatedStorage.Modules.CurrencyOrder)

local GetCurrencyStats = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Currency"):WaitForChild("GetCurrencyStats")

GetCurrencyStats.OnServerInvoke = function(player: Player)
	local bundle = {}
	for _, currencyName in CurrencyOrder do
		bundle[currencyName] = {
			Current = DataManager.Get(player, "Currency." .. currencyName),
			Total = DataManager.Get(player, "Statistics.TotalValues.Total" .. currencyName .. "Collected"),
		}
	end
	return bundle
end

