--[[
	UpgradeService.luau

	Server-authoritative upgrade purchasing, and the canonical way to
	read a player's upgrade levels. Everything that needs levels goes
	through GetLevels so clamping happens in exactly one place.

	MAX PURCHASE uses the same UpgradePurchase.Plan the client uses to
	preview it. The client showing "20x" and the server buying 19 would
	be a trust bug, not a rounding one — one shared summation is the only
	way to guarantee they agree.

	The whole max purchase is charged as ONE currency subtraction and one
	level write. Looping single purchases would mean N separate
	DataManager writes and N replication pushes for one click.

	GetUpgradeState WAITS FOR THE PROFILE. It used to return an empty
	table when the profile hadn't loaded, and the client took that as
	"every upgrade is level 0" — a board full of level 1s until something
	else forced a refresh.

	Location: ServerScriptService/Systems/UpgradeService.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local UpgradeSchema = require(ReplicatedStorage.Modules.Upgrades.UpgradeSchema)
local UpgradePurchase = require(ReplicatedStorage.Modules.Upgrades.UpgradePurchase)

local upgradeEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Upgrades")
local GetUpgradeState = upgradeEvents:WaitForChild("GetUpgradeState")
local RequestPurchase = upgradeEvents:WaitForChild("RequestPurchase")
local RequestMaxPurchase = upgradeEvents:WaitForChild("RequestMaxPurchase")
local PurchaseResult = upgradeEvents:WaitForChild("PurchaseResult")

local PROFILE_WAIT_SECONDS = 30

local UpgradeService = {}

-- Debounce per player: a fast double-click must not double-charge.
local processing: { [Player]: boolean } = {}

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

-- Levels only. Cost, boost and max level are all derivable from a level
-- through UpgradeSchema, which the client already has — sending them
-- would just be a second copy to drift.
local function buildStateBundle(player: Player)
	local bundle = {}
	for upgradeId, level in UpgradeService.GetLevels(player) do
		bundle[upgradeId] = { Level = level }
	end
	return bundle
end

GetUpgradeState.OnServerInvoke = function(player: Player)
	if not waitForProfile(player) then
		warn(`UpgradeService: no profile for {player.Name} after {PROFILE_WAIT_SECONDS}s — returning an empty bundle.`)
		return {}
	end
	return buildStateBundle(player)
end

local function fail(player: Player, upgradeId: string, reason: string)
	PurchaseResult:FireClient(player, { Success = false, Reason = reason, UpgradeId = upgradeId })
end

-- Shared by both remotes. `wantMax` decides whether it buys one level or
-- everything affordable; the validation, charging and refund path are
-- identical either way and shouldn't be written twice.
local function purchase(player: Player, upgradeId: any, wantMax: boolean)
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
		local path = UpgradeSchema.GetDataPath(upgradeId)
		if not entry or not path then
			fail(player, upgradeId, "UnknownUpgrade")
			return
		end

		local level = UpgradeSchema.ClampLevel(upgradeId, DataManager.Get(player, path))
		if level >= entry.MaxLevel then
			fail(player, upgradeId, "MaxLevel")
			return
		end

		local balance = DataManager.GetBig(player, "Currency." .. entry.Currency)
		local levelsToBuy, totalCost

		if wantMax then
			local plan = UpgradePurchase.Plan(upgradeId, level, balance)
			levelsToBuy, totalCost = plan.Levels, plan.TotalCost
		else
			local cost = UpgradeSchema.GetCost(upgradeId, level)
			if not cost then
				fail(player, upgradeId, "MaxLevel")
				return
			end
			levelsToBuy = BigNumber.GreaterThanOrEqual(balance, cost) and 1 or 0
			totalCost = cost
		end

		if levelsToBuy < 1 then
			fail(player, upgradeId, "CannotAfford")
			return
		end

		DataManager.SubtractCurrency(player, entry.Currency, totalCost)

		-- Past this point currency is already spent — refund on any
		-- failure rather than leaving the player charged for nothing.
		local newLevel = level + levelsToBuy
		local appliedOk, applyErr = pcall(function()
			DataManager.Set(player, path, newLevel)
		end)

		if not appliedOk then
			DataManager.AddCurrency(player, entry.Currency, totalCost)
			warn(`UpgradeService: purchase of '{upgradeId}' failed after charging {player.Name} — refunded. Error: {applyErr}`)
			fail(player, upgradeId, "InternalError")
			return
		end

		PurchaseResult:FireClient(player, {
			Success = true,
			UpgradeId = upgradeId,
			Level = newLevel,
			LevelsBought = levelsToBuy,
		})
	end)

	if not ok then
		warn(`UpgradeService: purchase errored for {player.Name}: {err}`)
	end

	-- Unconditional: runs whether the above succeeded, failed cleanly or
	-- errored, so one bad request can't permanently lock this player out
	-- of buying anything.
	processing[player] = nil
end

RequestPurchase.OnServerEvent:Connect(function(player, upgradeId)
	purchase(player, upgradeId, false)
end)

RequestMaxPurchase.OnServerEvent:Connect(function(player, upgradeId)
	purchase(player, upgradeId, true)
end)

Players.PlayerRemoving:Connect(function(player)
	processing[player] = nil
end)

return UpgradeService
