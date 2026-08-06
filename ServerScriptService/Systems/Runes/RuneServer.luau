--[[
	RuneServer.luau

	The rolling loop and the state remote.

	ROLLING IS SERVER-DRIVEN. Every tick the server checks which players
	are standing on a rune pad and rolls for them itself. The client is
	never asked how much time passed or whether it's on the pad, because
	those are exactly the two things worth lying about — and the answer
	is worth real currency.

	Pads are Parts under workspace.Runes carrying a RuneId attribute and
	an optional Radius. Adding a second rune's pad is a part, not code.

	Location: ServerScriptService/Systems/Runes/RuneServer.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataManager = require(ServerScriptService.DataStore.DataManager)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local RuneConfig = require(ReplicatedStorage.Modules.Runes.RuneConfig)
local RuneScheme = require(ReplicatedStorage.Modules.Runes.RuneScheme)
local RuneMath = require(ReplicatedStorage.Modules.Runes.RuneMath)
local RuneService = require(script.Parent:WaitForChild("RuneService"))
local UnlockService = require(ServerScriptService.Systems.UnlockService)

local runeEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Runes")
local GetRuneState = runeEvents:WaitForChild("GetRuneState")
local RollResult = runeEvents:WaitForChild("RollResult")

local ZERO = BigNumber.new(0, 0)
local DEFAULT_RADIUS = 8
local PROFILE_WAIT_SECONDS = 30

-- Fractional rolls left over from previous ticks, per player per rune.
-- Carrying them is what keeps a speed below one roll per tick from
-- rounding to zero forever.
local carry: { [Player]: { [string]: any } } = {}

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

local function serialiseCounts(player: Player)
	local bundle = {}
	for runeId, rune in RuneScheme.All do
		local types = {}
		for _, entry in rune.Types do
			local path = RuneScheme.GetDataPath(runeId, entry.Id)
			types[entry.Id] = BigNumber.Serialize(path and DataManager.GetBig(player, path) or ZERO)
		end
		bundle[runeId] = types
	end
	return bundle
end

local function serialiseStats(stats)
	return {
		Bulk = BigNumber.Serialize(stats.Bulk),
		Speed = BigNumber.Serialize(stats.Speed),
		Rps = BigNumber.Serialize(stats.Rps),
		Opened = BigNumber.Serialize(stats.Opened),
		Luck = stats.Luck,
		LuckEnabled = stats.LuckEnabled,
	}
end

GetRuneState.OnServerInvoke = function(player: Player)
	if not waitForProfile(player) then
		return {}
	end

	local stats = {}
	for runeId in RuneScheme.All do
		stats[runeId] = serialiseStats(RuneService.GetStats(player, runeId))
	end

	return { Counts = serialiseCounts(player), Stats = stats }
end

-- Pads -------------------------------------------------------------

local function getPads(): { BasePart }
	local root = Workspace:FindFirstChild("Runes")
	if not root then
		return {}
	end
	local pads = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("RuneId") then
			table.insert(pads, descendant)
		end
	end
	return pads
end

local function padForPlayer(player: Player, pads: { BasePart }): (string?, BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, nil
	end

	for _, pad in pads do
		local radius = pad:GetAttribute("Radius") or math.max(pad.Size.X, pad.Size.Z) / 2 + DEFAULT_RADIUS / 4
		local offset = root.Position - pad.Position
		-- Horizontal distance only: standing ON the pad shouldn't stop
		-- counting because the player jumped.
		if Vector2.new(offset.X, offset.Z).Magnitude <= radius then
			return pad:GetAttribute("RuneId"), pad
		end
	end
	return nil, nil
end

-- Loop -------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(RuneConfig.TickInterval)
		local pads = getPads()
		if #pads == 0 then
			continue
		end

		for _, player in Players:GetPlayers() do
			if not DataManager.GetProfile(player) then
				continue
			end

			local runeId = padForPlayer(player, pads)
			if not runeId then
				continue
			end

			local rune = RuneScheme.Get(runeId)
			if not rune then
				continue
			end

			-- Locked runes don't roll even if someone stands on the pad.
			-- The pad is hidden client-side too, but hiding a part is not
			-- the same as disabling a mechanic.
			if rune.UnlockPath and not UnlockService.IsUnlocked(player, rune.UnlockPath) then
				continue
			end

			local playerCarry = carry[player] or {}
			carry[player] = playerCarry

			local stats = RuneService.GetStats(player, runeId)
			local rolls, remainder = RuneMath.GetRollsForTick(
				stats.Speed,
				RuneConfig.TickInterval,
				playerCarry[runeId] or ZERO
			)
			playerCarry[runeId] = remainder

			if BigNumber.IsZero(rolls) then
				continue
			end

			local gains, newStats = RuneService.Roll(player, runeId, rolls)
			if gains then
				local serialisedGains = {}
				for typeId, amount in gains do
					serialisedGains[typeId] = BigNumber.Serialize(amount)
				end
				RollResult:FireClient(player, {
					RuneId = runeId,
					Gains = serialisedGains,
					Stats = serialiseStats(newStats),
				})
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	carry[player] = nil
end)
