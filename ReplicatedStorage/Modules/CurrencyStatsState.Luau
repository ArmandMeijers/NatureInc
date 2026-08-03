--!strict
--[[
	CurrencyStatsState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of this player's balance AND lifetime total for every
	currency in CurrencyOrder, kept in sync with the server. Same pattern
	as TreeTierState/SettingsState: whatever needs live currency data (the
	stats menu) requires this once instead of polling the server itself.

	Two sync paths, on purpose:
	  1. CurrencyBalanceChanged (pushed by CurrencyNetworkBridge the
	     instant DataManager changes a currency/total server-side) —
	     this is what makes collecting a leaf show up in the HUD
	     immediately instead of up to a second later.
	  2. GetCurrencyStats (polled, slow) — a reconciliation safety net in
	     case a push ever gets missed (e.g. briefly disconnected), not
	     the primary path anymore.

	Location: ReplicatedStorage/Modules/CurrencyStatsState.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local CurrencyOrder = require(ReplicatedStorage.Modules.CurrencyOrder)

local currencyEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Currency")
local GetCurrencyStats = currencyEvents:WaitForChild("GetCurrencyStats")
local CurrencyBalanceChanged = currencyEvents:WaitForChild("CurrencyBalanceChanged")

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

-- Handles a single pushed (path, value) pair — either "Currency.<Name>"
-- or "Statistics.TotalValues.Total<Name>Collected". Anything else (a
-- currency not in CurrencyOrder, or an unrelated stat) is ignored.
CurrencyBalanceChanged.OnClientEvent:Connect(function(path: string, value: any)
	local currencyName = path:match("^Currency%.([%w_]+)$")
	if currencyName and table.find(CurrencyOrder, currencyName) then
		local balance = BigNumber.Deserialize(value)
		if not BigNumber.Equals(balance, CurrencyStatsState.Balances[currencyName]) then
			CurrencyStatsState.Balances[currencyName] = balance
			CurrencyStatsState.Changed:Fire(currencyName)
		end
		return
	end

	local totalCurrencyName = path:match("^Statistics%.TotalValues%.Total([%w_]+)Collected$")
	if totalCurrencyName and table.find(CurrencyOrder, totalCurrencyName) then
		local total = BigNumber.Deserialize(value)
		if not BigNumber.Equals(total, CurrencyStatsState.Totals[totalCurrencyName]) then
			CurrencyStatsState.Totals[totalCurrencyName] = total
			CurrencyStatsState.Changed:Fire(totalCurrencyName)
		end
	end
end)

-- Initial fetch, then a slow reconciliation poll — the push above is the
-- fast path now, this is just a safety net.
task.spawn(function()
	local ok, bundle = pcall(function()
		return GetCurrencyStats:InvokeServer()
	end)
	if ok then
		applyBundle(bundle)
	end

	while true do
		task.wait(10)
		local success, result = pcall(function()
			return GetCurrencyStats:InvokeServer()
		end)
		if success then
			applyBundle(result)
		end
	end
end)

return CurrencyStatsState
