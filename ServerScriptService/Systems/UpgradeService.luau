--[[
	UpgradeService.luau

	Server-authoritative upgrade purchasing + the canonical way to read a
	player's upgrade levels. Everything that needs levels goes through
	GetLevels here so clamping-to-MaxLevel happens in exactly one place.

	Location: ServerScriptService/Systems/UpgradeService.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local UpgradeSchema = require(ReplicatedStorage.Modules.Upgrades.UpgradeSchema)

local upgradeEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Upgrades")
local GetUpgradeState = upgradeEvents:WaitForChild("GetUpgradeState")
local RequestPurchase = upgradeEvents:WaitForChild("RequestPurchase")
local PurchaseResult = upgradeEvents:WaitForChild("PurchaseResult")

local UpgradeService = {}

-- Debounce per player: a fast double-click must not double-charge.
local processing: { [Player]: boolean } = {}

-- Flat { [upgradeId]: clampedLevel } for every upgrade in the schema.
-- This exact shape is what BoostMath.TotalBoost expects.
function UpgradeService.GetLevels(player: Player): { [string]: number }
	local levels = {}
	for upgradeId in UpgradeSchema.All do
		local path = UpgradeSchema.GetDataPath(upgradeId)
		levels[upgradeId] = UpgradeSchema.ClampLevel(upgradeId, path and DataManager.Get(player, path))
	end
	return levels
end

local function buildStateBundle(player: Player)
	local levels = UpgradeService.GetLevels(player)
	local bundle = {}

	for upgradeId, entry in UpgradeSchema.All do
		local level = levels[upgradeId]
		local cost = UpgradeSchema.GetCost(upgradeId, level)
		bundle[upgradeId] = {
			Level = level,
			MaxLevel = entry.MaxLevel,
			Name = entry.Name,
			Category = entry.Category,
			Currency = entry.Currency,
			-- nil cost = maxed. Serialized because costs are BigNumbers.
			Cost = cost and BigNumber.Serialize(cost) or nil,
		}
	end

	return bundle
end

GetUpgradeState.OnServerInvoke = function(player: Player)
	if not DataManager.GetProfile(player) then
		return {}
	end
	return buildStateBundle(player)
end

RequestPurchase.OnServerEvent:Connect(function(player: Player, upgradeId: any)
	if type(upgradeId) ~= "string" then
		return -- never trust the client's argument types
	end
	if processing[player] then
		return
	end
	if not DataManager.GetProfile(player) then
		return
	end
	processing[player] = true

	local ok, err = pcall(function()
		local entry = UpgradeSchema.Get(upgradeId)
		if not entry then
			PurchaseResult:FireClient(player, { Success = false, Reason = "UnknownUpgrade", UpgradeId = upgradeId })
			return
		end

		local path = UpgradeSchema.GetDataPath(upgradeId)
		if not path then
			PurchaseResult:FireClient(player, { Success = false, Reason = "UnknownUpgrade", UpgradeId = upgradeId })
			return
		end

		local level = UpgradeSchema.ClampLevel(upgradeId, DataManager.Get(player, path))

		if level >= entry.MaxLevel then
			PurchaseResult:FireClient(player, { Success = false, Reason = "MaxLevel", UpgradeId = upgradeId })
			return
		end

		local cost = UpgradeSchema.GetCost(upgradeId, level)
		if not cost then
			PurchaseResult:FireClient(player, { Success = false, Reason = "MaxLevel", UpgradeId = upgradeId })
			return
		end

		if not DataManager.CanAfford(player, entry.Currency, cost) then
			PurchaseResult:FireClient(player, { Success = false, Reason = "CannotAfford", UpgradeId = upgradeId })
			return
		end

		DataManager.SubtractCurrency(player, entry.Currency, cost)

		-- Past this point currency is already spent — refund on any
		-- failure rather than leaving the player charged for nothing.
		local appliedOk, applyErr = pcall(function()
			DataManager.Set(player, path, level + 1)
		end)

		if not appliedOk then
			DataManager.AddCurrency(player, entry.Currency, cost)
			warn(`UpgradeService: purchase of '{upgradeId}' failed after charging {player.Name} — refunded. Error: {applyErr}`)
			PurchaseResult:FireClient(player, { Success = false, Reason = "InternalError", UpgradeId = upgradeId })
			return
		end

		local newLevel = level + 1
		local nextCost = UpgradeSchema.GetCost(upgradeId, newLevel)
		PurchaseResult:FireClient(player, {
			Success = true,
			UpgradeId = upgradeId,
			Level = newLevel,
			NextCost = nextCost and BigNumber.Serialize(nextCost) or nil,
		})
	end)

	if not ok then
		warn(`UpgradeService: RequestPurchase errored for {player.Name}: {err}`)
	end

	processing[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	processing[player] = nil
end)

return UpgradeService

