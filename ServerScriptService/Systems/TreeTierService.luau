--[[
	TreeTierService.luau

	Server-authoritative tree tier logic. Validates and processes tier-up
	requests: charges the cost, resets the paths TreeTierConfig says to
	reset (to their Template default value), deep-applies Unlocks, bumps
	Tree.TreeTier, and answers the client's state requests.

	Requires the DataManager.ResetToDefault addition — see the snippet
	provided alongside this file.

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

GetTreeTierState.OnServerInvoke = function(player: Player)
	local tier = DataManager.Get(player, "Tree.TreeTier") or 1
	local compost = DataManager.Get(player, "Currency.Compost")
	return tier, compost
end

RequestTierUp.OnServerEvent:Connect(function(player: Player)
	if processing[player] then
		return
	end
	if not DataManager.GetProfile(player) then
		return
	end
	processing[player] = true

	local currentTier = DataManager.Get(player, "Tree.TreeTier") or 1

	if currentTier >= MAX_TIER then
		sendResult(player, false, { Reason = "MaxTier" })
		processing[player] = nil
		return
	end

	local nextTierData = TreeTierConfig[currentTier + 1]
	local cost = nextTierData.Cost

	if not cost or not DataManager.CanAfford(player, cost.Currency, cost.Amount) then
		sendResult(player, false, { Reason = "CannotAfford" })
		processing[player] = nil
		return
	end

	DataManager.SubtractCurrency(player, cost.Currency, cost.Amount)

	if nextTierData.Resets then
		for _, path in nextTierData.Resets do
			DataManager.ResetToDefault(player, path)
		end
	end

	if nextTierData.Unlocks then
		applyUnlocks(player, nextTierData.Unlocks, "Unlocks")
	end

	local newTier = currentTier + 1
	DataManager.Set(player, "Tree.TreeTier", newTier)

	sendResult(player, true, {
		NewTier = newTier,
		Compost = DataManager.Get(player, "Currency.Compost"),
	})

	processing[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	processing[player] = nil
end)
