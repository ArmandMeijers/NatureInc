--[[
	CurrencyStatsService.luau

	Answers the client's request for "how much of every currency does
	this player have, and how much have they ever collected total" -- one
	bundle, one call, instead of the client needing a remote per currency.

	Reads which currencies exist from CurrencyOrder (ReplicatedStorage),
	the same shared list the HUD iterates client-side, so server and
	client can never disagree about which currencies exist or what order
	they're in.

	WAITS FOR THE PROFILE before answering. The client fires this the
	instant CurrencyStatsState is required, which is early enough that
	StartSessionAsync usually hasn't returned yet. Without the wait,
	DataManager.getProfile gives nil, every Get in the loop returns nil,
	and the client caches a bundle of zeros as though the player owned
	nothing -- which shut the HUD's "lifetime total > 0" unlock gate for
	the rest of the session, until some unrelated currency change pushed
	a real value through CurrencyNetworkBridge.

	Location: ServerScriptService/Systems/CurrencyStatsService.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local CurrencyOrder = require(ReplicatedStorage.Modules.CurrencyOrder)

local GetCurrencyStats = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Currency"):WaitForChild("GetCurrencyStats")

local PROFILE_WAIT_SECONDS = 30

-- Same poll-until-loaded shape StartUp.luau already uses. Bounded, so a
-- player whose data genuinely failed gets an empty bundle instead of
-- hanging the RemoteFunction call forever.
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

GetCurrencyStats.OnServerInvoke = function(player: Player)
	if not waitForProfile(player) then
		warn(`CurrencyStatsService: no profile for {player.Name} after {PROFILE_WAIT_SECONDS}s -- returning an empty bundle.`)
		return {}
	end

	local bundle = {}
	for _, currencyName in CurrencyOrder do
		bundle[currencyName] = {
			Current = DataManager.Get(player, "Currency." .. currencyName),
			Total = DataManager.Get(player, "Statistics.TotalValues.Total" .. currencyName .. "Collected"),
		}
	end
	return bundle
end
