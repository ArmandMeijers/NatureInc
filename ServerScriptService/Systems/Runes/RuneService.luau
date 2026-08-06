--[[
	RuneService.luau

	Server-side rune stats, boosts and rolling.

	RUNE BOOSTS ARE A SECOND SOURCE FOR THE SAME TAGS the upgrade schemas
	use. Anything that reads a stat should multiply BoostMath's result by
	GetMultiplier for that tag — that's the whole integration, and it's
	why a rune boosting LeafValue needs no changes to the leaf system
	beyond one multiplication.

	Location: ServerScriptService/Systems/Runes/RuneService.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local BoostMath = require(ReplicatedStorage.Modules.BoostMath)
local UpgradeService = require(ServerScriptService.Systems.UpgradeService)
local RuneConfig = require(ReplicatedStorage.Modules.Runes.RuneConfig)
local RuneScheme = require(ReplicatedStorage.Modules.Runes.RuneScheme)
local RuneMath = require(ReplicatedStorage.Modules.Runes.RuneMath)

local ZERO = BigNumber.new(0, 0)

local RuneService = {}

-- Every rune count this player holds, keyed by TYPE id. Flat rather than
-- nested by rune, because boosts are looked up by type and a type id is
-- unique across every rune.
function RuneService.GetCounts(player: Player): { [string]: any }
	local counts = {}
	for runeId, rune in RuneScheme.All do
		for _, entry in rune.Types do
			local path = RuneScheme.GetDataPath(runeId, entry.Id)
			counts[entry.Id] = path and DataManager.GetBig(player, path) or ZERO
		end
	end
	return counts
end

-- The multiplier runes contribute to a stat tag. Multiply BoostMath's
-- result by this wherever the stat is read.
function RuneService.GetMultiplier(player: Player, tag: string): number
	return RuneMath.GetBoostMultiplier(RuneService.GetCounts(player), tag)
end

function RuneService.IsLuckEnabled(player: Player): boolean
	local value = DataManager.Get(player, "Settings.Misc.RuneLuck")
	return value ~= false
end

-- Bulk, speed and luck all come from the same two sources: upgrades via
-- BoostMath, and runes via their own boosts.
function RuneService.GetStats(player: Player, runeId: string)
	local levels = UpgradeService.GetLevels(player)
	local tier = DataManager.Get(player, "Tree.TreeTier") or 1
	local counts = RuneService.GetCounts(player)

	local bulk = BigNumber.Mul(
		BoostMath.TotalBoost(levels, tier, "RuneBulk", BigNumber.FromNumber(RuneConfig.BaseBulk)),
		BigNumber.FromNumber(RuneMath.GetBoostMultiplier(counts, "RuneBulk"))
	)
	local speed = BigNumber.Mul(
		BoostMath.TotalBoost(levels, tier, "RuneSpeed", BigNumber.FromNumber(RuneConfig.BaseSpeed)),
		BigNumber.FromNumber(RuneMath.GetBoostMultiplier(counts, "RuneSpeed"))
	)
	local luck = BoostMath.TotalBoostNumber(levels, tier, "RuneLuck", RuneConfig.BaseLuck)
		* RuneMath.GetBoostMultiplier(counts, "RuneLuck")

	local rune = RuneScheme.Get(runeId)
	local opened = rune and rune.TotalStatPath and DataManager.GetBig(player, rune.TotalStatPath) or ZERO

	return {
		Bulk = bulk,
		Speed = speed,
		Luck = luck,
		Rps = RuneMath.GetRunesPerSecond(bulk, speed),
		Opened = opened,
		LuckEnabled = RuneService.IsLuckEnabled(player),
	}
end

function RuneService.GetChances(player: Player, runeId: string)
	local stats = RuneService.GetStats(player, runeId)
	return RuneMath.GetChances(runeId, stats.Luck, stats.LuckEnabled), stats
end

-- Rolls `rolls` times, charging for each. Returns the gains and how many
-- rolls actually happened, which is capped by what the player can pay
-- for — the caller asks for what time earned, not what they can afford.
function RuneService.Roll(player: Player, runeId: string, requestedRolls: any)
	local rune = RuneScheme.Get(runeId)
	if not rune or BigNumber.IsZero(requestedRolls) then
		return nil
	end

	local balance = DataManager.GetBig(player, "Currency." .. rune.Currency)
	local affordable = BigNumber.Div(balance, rune.CostPerRoll)
	local rolls = BigNumber.LessThan(affordable, requestedRolls) and affordable or requestedRolls

	if BigNumber.LessThan(rolls, BigNumber.FromNumber(1)) then
		return nil
	end

	local cost = BigNumber.Mul(rolls, rune.CostPerRoll)
	DataManager.SubtractCurrency(player, rune.Currency, cost)

	local stats = RuneService.GetStats(player, runeId)
	local chances = RuneMath.GetChances(runeId, stats.Luck, stats.LuckEnabled)
	local totalRunes = BigNumber.Mul(rolls, stats.Bulk)
	local gains = RuneMath.RollBatch(chances, totalRunes)

	for typeId, amount in gains do
		local path = RuneScheme.GetDataPath(runeId, typeId)
		if path then
			DataManager.AddBig(player, path, amount)
		end
	end

	-- Both totals move together: the per-rune one and the global one.
	DataManager.AddBig(player, "Statistics.TotalValues.TotalRunesOpened", totalRunes)
	if rune.TotalStatPath then
		DataManager.AddBig(player, rune.TotalStatPath, totalRunes)
	end

	-- Stats are re-read AFTER the write, since a rune that boosts bulk or
	-- speed has just changed them and the client should see the new value.
	return gains, RuneService.GetStats(player, runeId)
end

return RuneService
