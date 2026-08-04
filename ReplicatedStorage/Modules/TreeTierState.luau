--!strict
--[[
	TreeTierState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of this player's tree tier, plus their balance of
	whatever currency the NEXT tier costs.

	NO POLLING. The old version invoked GetTreeTierState once a second,
	forever, per player, purely to notice a currency change — while
	CurrencyNetworkBridge was already pushing every currency change to
	the client the instant DataManager wrote it, and CurrencyStatsState
	was already caching the result. So the balance is read from there
	now: the board reacts on the frame the currency moves instead of up
	to a second later, and the server stops answering a RemoteFunction
	per player per second for data it had already sent.

	That leaves the tier itself, which only ever changes through a
	tier-up — and a tier-up already reports its own result over
	TierUpResult. So GetTreeTierState is invoked exactly once, at
	startup, to learn the tier we joined on.

	Currency is never hardcoded. Each tier in TreeTierConfig declares its
	own Cost.Currency, and this tracks whichever one is currently
	relevant — including switching to a different currency when a
	tier-up changes what the next tier costs.

	Location: ReplicatedStorage/Modules/TreeTierState.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)
local CurrencyStatsState = require(ReplicatedStorage.Modules.CurrencyStatsState)

local remotesFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TreeTier")
local GetTreeTierState = remotesFolder:WaitForChild("GetTreeTierState")
local RequestTierUp = remotesFolder:WaitForChild("RequestTierUp")
local TierUpResult = remotesFolder:WaitForChild("TierUpResult")

local RETRY_MAX_WAIT = 4

local TreeTierState = {}

TreeTierState.Tier = 1
TreeTierState.Balance = BigNumber.new(0, 0) -- balance of whatever currency the NEXT tier costs
TreeTierState.BalanceCurrency = nil :: string? -- e.g. "Compost", "Nuts" — nil once maxed

-- Fires with (newTier: number)
TreeTierState.TierChanged = Instance.new("BindableEvent")
-- Fires with (newBalance: BigNum, currencyName: string?)
TreeTierState.BalanceChanged = Instance.new("BindableEvent")
-- Fires with (reason: string) e.g. "CannotAfford", "MaxTier"
TreeTierState.TierUpFailed = Instance.new("BindableEvent")

-- Fires once the startup tier fetch has landed. IsReady is there for
-- anything requiring this module late, which would otherwise sit waiting
-- on an event that already fired.
TreeTierState.Ready = Instance.new("BindableEvent")
TreeTierState.IsReady = false

function TreeTierState.GetMaxTier(): number
	return #TreeTierConfig
end

-- What the NEXT tier from `tier` costs, or nil if maxed.
function TreeTierState.GetNextCost(tier: number?)
	local nextData = TreeTierConfig[(tier or TreeTierState.Tier) + 1]
	return nextData and nextData.Cost
end

local function nextCostCurrency(): string?
	local cost = TreeTierState.GetNextCost()
	return cost and cost.Currency or nil
end

-- Pulls the relevant balance out of CurrencyStatsState and fires only on
-- an actual change. Called both when currency data moves and when the
-- tier moves, since a tier-up can change WHICH currency is relevant.
local function syncBalance()
	local currencyName = nextCostCurrency()

	if not currencyName then
		-- Maxed: no next cost, so nothing left to track.
		if TreeTierState.BalanceCurrency ~= nil then
			TreeTierState.BalanceCurrency = nil
			TreeTierState.BalanceChanged:Fire(TreeTierState.Balance, nil)
		end
		return
	end

	local balance = CurrencyStatsState.Balances[currencyName] or BigNumber.new(0, 0)
	local changed = currencyName ~= TreeTierState.BalanceCurrency
		or not BigNumber.Equals(balance, TreeTierState.Balance)

	if changed then
		TreeTierState.Balance = balance
		TreeTierState.BalanceCurrency = currencyName
		TreeTierState.BalanceChanged:Fire(balance, currencyName)
	end
end

local function setTier(tier: number?)
	if tier and tier ~= TreeTierState.Tier then
		TreeTierState.Tier = tier
		TreeTierState.TierChanged:Fire(tier)
	end
	syncBalance()
end

function TreeTierState.RequestTierUp()
	RequestTierUp:FireServer()
end

TierUpResult.OnClientEvent:Connect(function(result)
	if result.Success then
		setTier(result.NewTier)
	else
		TreeTierState.TierUpFailed:Fire(result.Reason)
	end
end)

CurrencyStatsState.Changed.Event:Connect(syncBalance)

task.spawn(function()
	-- One fetch, retried until it lands. TreeTierService waits for the
	-- profile before answering now, so this normally succeeds first try;
	-- the retry covers an outright error rather than leaving the board
	-- claiming Tier 1 for the rest of the session.
	local attempt = 0
	while true do
		local ok, tier = pcall(function()
			return GetTreeTierState:InvokeServer()
		end)
		if ok and type(tier) == "number" then
			setTier(tier)
			break
		end
		attempt += 1
		task.wait(math.min(0.5 * attempt, RETRY_MAX_WAIT))
	end

	TreeTierState.IsReady = true
	-- Unconditional, for the same reason CurrencyStatsState fires one:
	-- consumers bound against a pre-fetch guess of Tier 1 and need a
	-- signal to re-render against confirmed data even when the guess
	-- happened to be right.
	TreeTierState.TierChanged:Fire(TreeTierState.Tier)
	syncBalance()
	TreeTierState.Ready:Fire()
end)

return TreeTierState
