--[[
	TreeTierState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of this player's tree tier and their balance of whatever
	currency the NEXT tier actually costs. Mirrors your SettingsState
	pattern: anything that needs live tree-tier data (the board UI, the
	local tree model) requires this once instead of each polling the
	server independently.

	Fully dynamic — a currency name is never hardcoded here. Each tier in
	TreeTierConfig says its own Cost.Currency (e.g. Tier 2 costs Compost,
	a later tier could cost Nuts, or anything else in Template.Currency),
	and this module just tracks whichever one is currently relevant. When
	you tier up and the NEW next tier costs a different currency, the next
	poll (or the tier-up result itself) picks that up automatically.

	Location: ReplicatedStorage/Modules/TreeTierState.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)

local LocalPlayer = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TreeTier")
local GetTreeTierState = remotesFolder:WaitForChild("GetTreeTierState")
local RequestTierUp = remotesFolder:WaitForChild("RequestTierUp")
local TierUpResult = remotesFolder:WaitForChild("TierUpResult")

local TreeTierState = {}

TreeTierState.Tier = 1
TreeTierState.Balance = BigNumber.new(0, 0) -- balance of whatever currency the NEXT tier costs
TreeTierState.BalanceCurrency = nil :: string? -- e.g. "Compost", "Nuts" — nil once maxed

-- Fire with (newTier: number)
TreeTierState.TierChanged = Instance.new("BindableEvent")
-- Fire with (newBalance: BigNum, currencyName: string)
TreeTierState.BalanceChanged = Instance.new("BindableEvent")
-- Fire with (reason: string) e.g. "CannotAfford", "MaxTier"
TreeTierState.TierUpFailed = Instance.new("BindableEvent")

function TreeTierState.GetMaxTier(): number
	return #TreeTierConfig
end

-- What the NEXT tier from `tier` costs, or nil if maxed. Client-side
-- convenience so board UIs don't each re-derive this themselves.
function TreeTierState.GetNextCost(tier: number?)
	local nextData = TreeTierConfig[(tier or TreeTierState.Tier) + 1]
	return nextData and nextData.Cost
end

local function applyState(tier: number?, currencyName: string?, balanceRaw)
	if tier and tier ~= TreeTierState.Tier then
		TreeTierState.Tier = tier
		TreeTierState.TierChanged:Fire(tier)
	end

	if currencyName and balanceRaw ~= nil then
		local balance = BigNumber.Deserialize(balanceRaw)
		local changed = currencyName ~= TreeTierState.BalanceCurrency
			or not BigNumber.Equals(balance, TreeTierState.Balance)
		if changed then
			TreeTierState.Balance = balance
			TreeTierState.BalanceCurrency = currencyName
			TreeTierState.BalanceChanged:Fire(balance, currencyName)
		end
	elseif TreeTierState.BalanceCurrency ~= nil then
		-- Maxed out — no next cost, so no currency to track anymore.
		TreeTierState.BalanceCurrency = nil
	end
end

function TreeTierState.RequestTierUp()
	RequestTierUp:FireServer()
end

TierUpResult.OnClientEvent:Connect(function(result)
	if result.Success then
		applyState(result.NewTier, result.Currency, result.Balance)
	else
		TreeTierState.TierUpFailed:Fire(result.Reason)
	end
end)

-- Initial fetch, then a light fallback poll for anything that changes the
-- relevant currency outside of a tier-up (e.g. leaf -> compost conversion).
-- Swap the poll for a push from wherever that currency actually changes
-- once that's wired up — this is just the simplest thing that works today.
task.spawn(function()
	local ok, tier, currencyName, balanceRaw = pcall(function()
		return GetTreeTierState:InvokeServer()
	end)
	if ok then
		applyState(tier, currencyName, balanceRaw)
	end

	while true do
		task.wait(1)
		local success, t, c, b = pcall(function()
			return GetTreeTierState:InvokeServer()
		end)
		if success then
			applyState(t, c, b)
		end
	end
end)

return TreeTierState

