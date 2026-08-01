--!strict
--[[
	CurrencyStatsState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of this player's balance AND lifetime total for every
	currency in CurrencyOrder, kept in sync with the server. Same pattern
	as TreeTierState/SettingsState: whatever needs live currency data (the
	stats menu) requires this once instead of polling the server itself.

	Location: ReplicatedStorage/Modules/CurrencyStatsState.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local CurrencyOrder = require(ReplicatedStorage.Modules.CurrencyOrder)

local GetCurrencyStats = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Currency"):WaitForChild("GetCurrencyStats")

local CurrencyStatsState = {}

CurrencyStatsState.Balances = {} :: { [string]: BigNumber.BigNum }
CurrencyStatsState.Totals = {} :: { [string]: BigNumber.BigNum }

for _, currencyName in CurrencyOrder do
	CurrencyStatsState.Balances[currencyName] = BigNumber.new(0, 0)
	CurrencyStatsState.Totals[currencyName] = BigNumber.new(0, 0)
end

-- Fires with (currencyName: string) whenever that currency's Balance
-- and/or Total changes. Listeners re-read CurrencyStatsState.Balances /
-- .Totals themselves rather than receiving the values as arguments, so
-- one row can listen once and stay correct regardless of which of the
-- two actually changed.
CurrencyStatsState.Changed = Instance.new("BindableEvent")

local function applyBundle(bundle)
	for _, currencyName in CurrencyOrder do
		local entry = bundle[currencyName]
		if not entry then
			continue
		end

		local changed = false

		if entry.Current ~= nil then
			local balance = BigNumber.Deserialize(entry.Current)
			if not BigNumber.Equals(balance, CurrencyStatsState.Balances[currencyName]) then
				CurrencyStatsState.Balances[currencyName] = balance
				changed = true
			end
		end

		if entry.Total ~= nil then
			local total = BigNumber.Deserialize(entry.Total)
			if not BigNumber.Equals(total, CurrencyStatsState.Totals[currencyName]) then
				CurrencyStatsState.Totals[currencyName] = total
				changed = true
			end
		end

		if changed then
			CurrencyStatsState.Changed:Fire(currencyName)
		end
	end
end

-- Initial fetch, then a light poll -- same pattern as TreeTierState.
-- Swap for a push from wherever currencies actually change once that
-- exists; this is the simplest thing that works today.
task.spawn(function()
	local ok, bundle = pcall(function()
		return GetCurrencyStats:InvokeServer()
	end)
	if ok then
		applyBundle(bundle)
	end

	while true do
		task.wait(1)
		local success, result = pcall(function()
			return GetCurrencyStats:InvokeServer()
		end)
		if success then
			applyBundle(result)
		end
	end
end)

return CurrencyStatsState

