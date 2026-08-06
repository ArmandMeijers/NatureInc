--!strict
--[[
	RuneState.luau  (CLIENT ONLY — never require this from server code)

	Everything the rune UI needs: lifetime counts, live stats, and this
	session's gains.

	SESSION GAINS ARE CLIENT-ONLY and deliberately not saved. They exist
	to drive the corner feed, which is a "what just happened" display —
	persisting them would make it a running total, which is what the
	lifetime counts already are.

	Location: ReplicatedStorage/Modules/Runes/RuneState.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

local runeEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Runes")
local GetRuneState = runeEvents:WaitForChild("GetRuneState")
local RollResult = runeEvents:WaitForChild("RollResult")

local ZERO = BigNumber.new(0, 0)
local RETRY_MAX_WAIT = 4

local RuneState = {}

-- [runeId][typeId] = BigNum
RuneState.Counts = {} :: { [string]: { [string]: any } }
-- [runeId] = { Bulk, Speed, Luck, Rps, Opened, LuckEnabled }
RuneState.Stats = {} :: { [string]: any }
-- [runeId][typeId] = { Amount = BigNum, LastGain = os.clock() }
RuneState.Session = {} :: { [string]: { [string]: any } }

RuneState.Changed = Instance.new("BindableEvent")       -- counts/stats
RuneState.Gained = Instance.new("BindableEvent")        -- (runeId, gains)
RuneState.Ready = Instance.new("BindableEvent")
RuneState.IsReady = false

function RuneState.GetCount(runeId: string, typeId: string)
	local rune = RuneState.Counts[runeId]
	return (rune and rune[typeId]) or ZERO
end

function RuneState.GetStats(runeId: string)
	return RuneState.Stats[runeId]
end

local function deserialiseCounts(bundle: any)
	for runeId, types in bundle do
		local target = RuneState.Counts[runeId] or {}
		for typeId, serialised in types do
			target[typeId] = BigNumber.Deserialize(serialised)
		end
		RuneState.Counts[runeId] = target
	end
end

local function deserialiseStats(bundle: any)
	for runeId, stats in bundle do
		RuneState.Stats[runeId] = {
			Bulk = BigNumber.Deserialize(stats.Bulk),
			Speed = BigNumber.Deserialize(stats.Speed),
			Rps = BigNumber.Deserialize(stats.Rps),
			Opened = BigNumber.Deserialize(stats.Opened),
			Luck = stats.Luck,
			LuckEnabled = stats.LuckEnabled,
		}
	end
end

local function applyBundle(bundle: any): boolean
	if type(bundle) ~= "table" then
		return false
	end
	if bundle.Counts then
		deserialiseCounts(bundle.Counts)
	end
	if bundle.Stats then
		deserialiseStats(bundle.Stats)
	end
	RuneState.Changed:Fire()
	return true
end

function RuneState.Refresh()
	task.spawn(function()
		local ok, bundle = pcall(function()
			return GetRuneState:InvokeServer()
		end)
		if ok then
			applyBundle(bundle)
		end
	end)
end

RollResult.OnClientEvent:Connect(function(result)
	if type(result) ~= "table" or type(result.RuneId) ~= "string" then
		return
	end

	local runeId = result.RuneId
	local now = os.clock()

	if result.Gains then
		local counts = RuneState.Counts[runeId] or {}
		local session = RuneState.Session[runeId] or {}

		for typeId, serialised in result.Gains do
			local amount = BigNumber.Deserialize(serialised)
			counts[typeId] = BigNumber.Add(counts[typeId] or ZERO, amount)

			local entry = session[typeId]
			if entry then
				entry.Amount = BigNumber.Add(entry.Amount, amount)
				entry.LastGain = now
			else
				session[typeId] = { Amount = amount, LastGain = now }
			end
		end

		RuneState.Counts[runeId] = counts
		RuneState.Session[runeId] = session
		RuneState.Gained:Fire(runeId, result.Gains)
	end

	if result.Stats then
		deserialiseStats({ [runeId] = result.Stats })
	end

	RuneState.Changed:Fire()
end)

task.spawn(function()
	local attempt = 0
	while true do
		local ok, bundle = pcall(function()
			return GetRuneState:InvokeServer()
		end)
		if ok and applyBundle(bundle) then
			break
		end
		attempt += 1
		task.wait(math.min(0.5 * attempt, RETRY_MAX_WAIT))
	end

	RuneState.IsReady = true
	RuneState.Changed:Fire()
	RuneState.Ready:Fire()
end)

return RuneState
