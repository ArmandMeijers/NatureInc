--[[
	TreeTierService.luau

	Server-authoritative tree tier logic. Validates and processes tier-up
	requests: charges the cost, resets what the tier says to reset,
	deep-applies Unlocks, bumps Tree.TreeTier, and answers the client's
	state request.

	UPGRADE RESETS are driven off the schema, not a hardcoded path list.
	The tier declares CATEGORIES ("LeafUpgrades"); this walks
	UpgradeSchema for every upgrade in them and resets each to its
	Template default. Adding an upgrade to a schema file therefore
	includes it in the reset automatically — a path list would have
	needed updating in two places and would silently keep whatever
	someone forgot.

	Cost currency is read from TreeTierConfig[tier].Cost.Currency, never
	assumed — different tiers can cost different currencies.

	GetTreeTierState waits for the profile before answering and returns
	only the tier. The client invokes it the moment TreeTierState is
	required, which is early enough that StartSessionAsync usually hasn't
	returned; without the wait a tier 3 player would stare at a tier 1
	board until they tiered up or rejoined.

	Location: ServerScriptService/Systems/TreeTierService.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)
local UpgradeSchema = require(ReplicatedStorage.Modules.Upgrades.UpgradeSchema)

local remotesFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TreeTier")
local GetTreeTierState = remotesFolder:WaitForChild("GetTreeTierState")
local RequestTierUp = remotesFolder:WaitForChild("RequestTierUp")
local TierUpResult = remotesFolder:WaitForChild("TierUpResult")

local MAX_TIER = #TreeTierConfig
local PROFILE_WAIT_SECONDS = 30

-- Debounce so a fast double-click can't fire two tier-ups before the
-- first resolves (double charge / double reset).
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

-- Every upgrade in the listed categories, back to its Template default.
local function resetUpgradeCategories(player: Player, categories: { string })
	local wanted: { [string]: boolean } = {}
	for _, category in categories do
		wanted[category] = true
	end

	for upgradeId, entry in UpgradeSchema.All do
		if wanted[entry.Category] then
			local path = UpgradeSchema.GetDataPath(upgradeId)
			if path then
				DataManager.ResetToDefault(player, path)
			end
		end
	end
end

local function sendResult(player: Player, success: boolean, extra: { [string]: any }?)
	local payload = extra or {}
	payload.Success = success
	TierUpResult:FireClient(player, payload)
end

GetTreeTierState.OnServerInvoke = function(player: Player)
	if not waitForProfile(player) then
		warn(`TreeTierService: no profile for {player.Name} after {PROFILE_WAIT_SECONDS}s — returning tier 1.`)
		return 1
	end
	return DataManager.Get(player, "Tree.TreeTier") or 1
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
		-- tier-up that didn't happen.
		local appliedOk, applyErr = pcall(function()
			if nextTierData.Resets then
				for _, path in nextTierData.Resets do
					DataManager.ResetToDefault(player, path)
				end
			end

			if nextTierData.ResetUpgradeCategories then
				resetUpgradeCategories(player, nextTierData.ResetUpgradeCategories)
			end

			if nextTierData.Unlocks then
				applyUnlocks(player, nextTierData.Unlocks, "Unlocks")
			end

			DataManager.Set(player, "Tree.TreeTier", currentTier + 1)
		end)

		if not appliedOk then
			DataManager.AddCurrency(player, cost.Currency, cost.Amount)
			warn(`TreeTierService: tier-up for {player.Name} failed after charging — refunded. Error: {applyErr}`)
			sendResult(player, false, { Reason = "InternalError" })
			return
		end

		sendResult(player, true, { NewTier = currentTier + 1 })
	end)

	if not ok then
		warn(`TreeTierService: RequestTierUp errored for {player.Name}: {err}`)
	end

	-- Unconditional: runs whether the above succeeded, failed cleanly or
	-- errored, so one bad request can never permanently lock this player
	-- out of tiering up again.
	processing[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	processing[player] = nil
end)
