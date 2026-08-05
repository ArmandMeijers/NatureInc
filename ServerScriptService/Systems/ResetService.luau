--[[
	ResetService.luau

	Server-authoritative reset layers. Reads what a layer does from
	ResetScheme and what it pays from ResetMath — the same module the
	board uses for its live preview, so the number you're shown is the
	number you get.

	ORDER OF OPERATIONS MATTERS. The payout is computed from the input
	balance BEFORE anything is wiped, the wipes happen next, and the
	payout is credited LAST. Crediting first would work today, but only
	because no layer currently outputs a currency it also resets — and
	the first one that does would silently hand the player their payout
	and then delete it.

	Upgrade resets are driven off UpgradeSchema by category, so adding an
	upgrade includes it automatically rather than needing a path list
	updated in two places.

	Location: ServerScriptService/Systems/ResetService.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local UpgradeSchema = require(ReplicatedStorage.Modules.Upgrades.UpgradeSchema)
local ResetScheme = require(ReplicatedStorage.Modules.Resets.ResetScheme)
local ResetMath = require(ReplicatedStorage.Modules.Resets.ResetMath)

local resetEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Resets")
local RequestReset = resetEvents:WaitForChild("RequestReset")
local ResetResult = resetEvents:WaitForChild("ResetResult")

-- Debounce per player: a fast double-click must not reset twice, which
-- would pay out once and wipe twice.
local processing: { [Player]: boolean } = {}

local function fail(player: Player, resetId: string, reason: string)
	ResetResult:FireClient(player, { Success = false, ResetId = resetId, Reason = reason })
end

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

RequestReset.OnServerEvent:Connect(function(player: Player, resetId: any)
	if type(resetId) ~= "string" then
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
		local entry = ResetScheme.Get(resetId)
		if not entry then
			fail(player, resetId, "UnknownReset")
			return
		end

		-- Read the balance and decide the payout BEFORE anything is wiped.
		local inputBalance = DataManager.GetBig(player, "Currency." .. entry.InputCurrency)
		if not ResetMath.CanReset(resetId, inputBalance) then
			fail(player, resetId, "CannotAfford")
			return
		end

		local payout = ResetMath.GetPayout(resetId, inputBalance)

		local appliedOk, applyErr = pcall(function()
			for _, currencyName in entry.ResetCurrencies or {} do
				DataManager.ResetToDefault(player, "Currency." .. currencyName)
			end

			if entry.ResetUpgradeCategories then
				resetUpgradeCategories(player, entry.ResetUpgradeCategories)
			end

			-- Credited last, so a layer that outputs a currency it also
			-- resets pays out rather than paying out and deleting it.
			-- AddCurrency also raises Total<Name>Collected, which is what
			-- unlocks the currency's HUD row.
			DataManager.AddCurrency(player, entry.OutputCurrency, payout)
		end)

		if not appliedOk then
			warn(`ResetService: '{resetId}' failed part-way for {player.Name}: {applyErr}`)
			fail(player, resetId, "InternalError")
			return
		end

		ResetResult:FireClient(player, {
			Success = true,
			ResetId = resetId,
			Gained = BigNumber.Serialize(payout),
		})
	end)

	if not ok then
		warn(`ResetService: RequestReset errored for {player.Name}: {err}`)
	end

	-- Unconditional: runs whether the above succeeded, failed cleanly or
	-- errored, so one bad request can't lock this player out of resetting.
	processing[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	processing[player] = nil
end)
