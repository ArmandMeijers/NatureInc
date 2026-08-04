--!strict
--[[
	CurrencyStatsState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of this player's balance AND lifetime total for every
	currency in CurrencyOrder, kept in sync with the server. Same pattern
	as TreeTierState/SettingsState: whatever needs live currency data
	requires this once instead of polling the server itself.

	Two sync paths, on purpose:
	  1. CurrencyBalanceChanged (pushed by CurrencyNetworkBridge the
	     instant DataManager changes a currency/total server-side) —
	     this is what makes collecting a leaf show up in the HUD
	     immediately instead of up to a second later.
	  2. GetCurrencyStats (invoked once at startup, then polled slowly) —
	     the startup fetch is what every consumer's FIRST render depends
	     on; the repeat poll is only a reconciliation net for a missed
	     push.

	STARTUP, and why it's shaped like this. Consumers bind with LiveBind,
	which computes once immediately and then again on Changed. So the
	very first render happens against whatever this cache holds at
	require time — all zeros. Every one of them therefore depends on
	Changed firing at least once after the real data arrives.

	It didn't. The old applyBundle fired Changed only when a value
	DIFFERED from what was cached, and the startup bundle was itself
	zeros (CurrencyStatsService answered before the profile had loaded).
	Zero equals zero, so nothing fired, so the HUD sat on its zero-state
	render until an unrelated currency change pushed something through —
	which is why rows only showed up after you collected something.

	Two changes: the first fetch retries until it lands instead of
	silently falling back to the 10s poll, and once it lands Changed
	fires for EVERY currency unconditionally, difference or not. That
	unconditional fire is the "run once at the start" signal.

	Location: ReplicatedStorage/Modules/CurrencyStatsState.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local CurrencyOrder = require(ReplicatedStorage.Modules.CurrencyOrder)

local currencyEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Currency")
local GetCurrencyStats = currencyEvents:WaitForChild("GetCurrencyStats")
local CurrencyBalanceChanged = currencyEvents:WaitForChild("CurrencyBalanceChanged")

local RECONCILE_INTERVAL = 10
local RETRY_MAX_WAIT = 4

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

-- Fires once, after the first successful bundle has been applied.
-- IsReady is there for anything that requires this module late and would
-- otherwise sit waiting for an event that already fired.
CurrencyStatsState.Ready = Instance.new("BindableEvent")
CurrencyStatsState.IsReady = false

local function applyBundle(bundle: any)
	if type(bundle) ~= "table" then
		return
	end

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

-- Handles a single pushed (path, value) pair — either "Currency.<n>"
-- or "Statistics.TotalValues.Total<n>Collected". Anything else (a
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

local function fetch(): (boolean, any)
	return pcall(function()
		return GetCurrencyStats:InvokeServer()
	end)
end

task.spawn(function()
	-- Retry the startup fetch. CurrencyStatsService waits for the profile
	-- now, so this normally lands first try; the retry covers an outright
	-- error (mid-teleport, a server-side hiccup) rather than leaving the
	-- HUD blank until the reconcile poll comes round.
	local attempt = 0
	while true do
		local ok, bundle = fetch()
		if ok and type(bundle) == "table" then
			applyBundle(bundle)
			break
		end
		attempt += 1
		task.wait(math.min(0.5 * attempt, RETRY_MAX_WAIT))
	end

	-- The unconditional startup fire. applyBundle above only signals
	-- currencies whose value actually moved, and a legitimately-zero
	-- currency never moves — but its consumers still need one signal to
	-- render against real, confirmed data instead of the pre-fetch guess.
	CurrencyStatsState.IsReady = true
	for _, currencyName in CurrencyOrder do
		CurrencyStatsState.Changed:Fire(currencyName)
	end
	CurrencyStatsState.Ready:Fire()

	while true do
		task.wait(RECONCILE_INTERVAL)
		local ok, bundle = fetch()
		if ok then
			applyBundle(bundle)
		end
	end
end)

return CurrencyStatsState
