--[[
	CurrencyTotalsBackfill.luau

	One pass per session, right after the profile loads: if a currency's
	lifetime total is behind its current balance, raise the total to
	match.

	Why this has to exist. Statistics.TotalValues.Total<Name>Collected is
	written in exactly one place -- DataManager.AddBig -- on purpose, so
	that spending currency or a tier-up reset can never lower it. That
	invariant is correct and worth keeping, but it means the total can
	only ever describe gains made AFTER the key existed. Any save that
	predates the key (every save from before the TotalLeavesCollected ->
	TotalLeafsCollected rename, since the mismatched key failed
	pathExistsInTemplate and AddBig quietly skipped the write) comes back
	from Reconcile with the key sitting at zero while the balance is in
	the hundreds.

	The HUD gates a row on total > 0, so those players saw nothing until
	their next gain nudged the total off zero. Seeding from the balance
	fixes them permanently on their next join, with no migration script
	and no risk to healthy saves: total >= balance is the normal state for
	anyone who has ever spent anything, and this only ever writes when the
	total is strictly behind.

	The write goes through DataManager.SetBig, so DataManager.Changed
	fires and CurrencyNetworkBridge pushes the corrected total to the
	client on its own -- nothing here needs to know about remotes.

	Location: ServerScriptService/Systems/CurrencyTotalsBackfill.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local CurrencyOrder = require(ReplicatedStorage.Modules.CurrencyOrder)

local PROFILE_WAIT_SECONDS = 30

local function backfill(player: Player)
	local deadline = os.clock() + PROFILE_WAIT_SECONDS
	while not DataManager.GetProfile(player) do
		if player.Parent ~= Players or os.clock() > deadline then
			return
		end
		task.wait(0.1)
	end

	for _, currencyName in CurrencyOrder do
		local totalPath = "Statistics.TotalValues.Total" .. currencyName .. "Collected"

		local balance = DataManager.GetBig(player, "Currency." .. currencyName)
		local total = DataManager.GetBig(player, totalPath)

		if BigNumber.GreaterThan(balance, total) then
			DataManager.SetBig(player, totalPath, balance)
			print(("CurrencyTotalsBackfill: seeded %s's %s from balance (%s)")
				:format(player.Name, totalPath, BigNumber.Format(balance, "scientific")))
		end
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(backfill, player)
end
Players.PlayerAdded:Connect(function(player)
	task.spawn(backfill, player)
end)
