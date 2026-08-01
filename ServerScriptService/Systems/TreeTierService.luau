--[[
	TreeTierService.luau

	Server-authoritative tree tier logic. Validates and processes tier-up
	requests: charges the cost, resets the paths TreeTierConfig says to
	reset (to their Template default value), deep-applies Unlocks, bumps
	Tree.TreeTier, and answers the client's state requests.

	Cost currency is read from TreeTierConfig[tier].Cost.Currency, never
	assumed — different tiers can cost different currencies (Compost now,
	something else later) with no changes needed here.

	Location: ServerScriptService/Systems/TreeTierService.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)

local remotesFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TreeTier")
local GetTreeTierState = remotesFolder:WaitForChild("GetTreeTierState")
local RequestTierUp = remotesFolder:WaitForChild("RequestTierUp")
local TierUpResult = remotesFolder:WaitForChild("TierUpResult")

local MAX_TIER = #TreeTierConfig

-- Debounce so a fast double-click can't fire two tier-ups before the first
-- one resolves (double charge / double reset).
local processing: { [Player]: boolean } = {}

local function applyUnlocks(player: Player, unlocksTable: { [string]: any }, pathPrefix: string)
	for key, value in unlocksTable do
		local path = pathPrefix .. "." .. key
		if type(value) == "table" then
			applyUnlocks(player, value, path)
		else
			DataManager.Set(player, path, value)
		end
	end
end

local function sendResult(player: Player, success: boolean, extra: { [string]: any }?)
	local payload = extra or {}
	payload.Success = success
	TierUpResult:FireClient(player, payload)
end

-- Whatever currency `tier`'s NEXT tier costs, and the player's current
-- balance of it. Returns (nil, nil) once maxed — nothing left to afford.
local function getNextCostBalance(player: Player, tier: number): (string?, any)
	local nextTierData = TreeTierConfig[tier + 1]
	local cost = nextTierData and nextTierData.Cost
	if not cost then
		return nil, nil
	end
	return cost.Currency, DataManager.Get(player, "Currency." .. cost.Currency)
end

GetTreeTierState.OnServerInvoke = function(player: Player)
	local tier = DataManager.Get(player, "Tree.TreeTier") or 1
	local currency, balance = getNextCostBalance(player, tier)
	return tier, currency, balance
end

RequestTierUp.OnServerEvent:Connect(function(player: Player)
	if processing[player] then
		return
	end
	if not DataManager.GetProfile(player) then
		return
	end
	processing[player] = true

	local ok, err = pcall(function()
		local currentTier = DataManager.Get(player, "Tree.TreeTier") or 1

		if currentTier >= MAX_TIER then
			sendResult(player, false, { Reason = "MaxTier" })
			return
		end

		local nextTierData = TreeTierConfig[currentTier + 1]
		local cost = nextTierData.Cost

		if not cost or not DataManager.CanAfford(player, cost.Currency, cost.Amount) then
			sendResult(player, false, { Reason = "CannotAfford" })
			return
		end

		DataManager.SubtractCurrency(player, cost.Currency, cost.Amount)

		-- Everything past this point already spent the player's currency.
		-- If any of it fails, refund rather than leave them charged for a
		-- tier-up that didn't actually happen.
		local appliedOk, applyErr = pcall(function()
			if nextTierData.Resets then
				for _, path in nextTierData.Resets do
					DataManager.ResetToDefault(player, path)
				end
			end

			if nextTierData.Unlocks then
				applyUnlocks(player, nextTierData.Unlocks, "Unlocks")
			end

			DataManager.Set(player, "Tree.TreeTier", currentTier + 1)
		end)

		if not appliedOk then
			DataManager.AddCurrency(player, cost.Currency, cost.Amount)
			warn(`TreeTierService: tier-up for {player.Name} failed after charging — refunded {cost.Amount.mantissa}e{cost.Amount.exponent} {cost.Currency}. Error: {applyErr}`)
			sendResult(player, false, { Reason = "InternalError" })
			return
		end

		local newTier = currentTier + 1
		local currency, balance = getNextCostBalance(player, newTier)
		sendResult(player, true, {
			NewTier = newTier,
			Currency = currency,
			Balance = balance,
		})
	end)

	if not ok then
		warn(`TreeTierService: RequestTierUp errored for {player.Name}: {err}`)
	end

	-- Unconditional: runs whether the above succeeded, failed cleanly, or
	-- errored outright, so a single bad request can never permanently
	-- lock this player out of tiering up again.
	processing[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	processing[player] = nil
end)

