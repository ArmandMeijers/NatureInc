--[[
	TreeTierState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of this player's tree tier and Compost balance, kept in
	sync with the server. Mirrors your SettingsState pattern: anything
	that needs live tree-tier data (the board UI, the local tree model)
	requires this once instead of each polling the server independently.

	Only tracks Compost right now since that's the only tier-up cost
	currency. If a later tier costs something else, extend applyState /
	GetTreeTierState to track that currency too.

	Location: ReplicatedStorage/Modules/TreeTierState.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)

local LocalPlayer = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TreeTier")
local GetTreeTierState = remotesFolder:WaitForChild("GetTreeTierState")
local RequestTierUp = remotesFolder:WaitForChild("RequestTierUp")
local TierUpResult = remotesFolder:WaitForChild("TierUpResult")

local TreeTierState = {}

TreeTierState.Tier = 1
TreeTierState.Compost = BigNumber.new(0, 0)

-- Fire with (newTier: number) / (newCompost: BigNum)
TreeTierState.TierChanged = Instance.new("BindableEvent")
TreeTierState.CompostChanged = Instance.new("BindableEvent")
-- Fire with (reason: string) e.g. "CannotAfford", "MaxTier"
TreeTierState.TierUpFailed = Instance.new("BindableEvent")

function TreeTierState.GetMaxTier(): number
	return #TreeTierConfig
end

local function applyState(tier: number, compostRaw)
	if tier and tier ~= TreeTierState.Tier then
		TreeTierState.Tier = tier
		TreeTierState.TierChanged:Fire(tier)
	end

	if compostRaw then
		local compost = BigNumber.Deserialize(compostRaw)
		if not BigNumber.Equals(compost, TreeTierState.Compost) then
			TreeTierState.Compost = compost
			TreeTierState.CompostChanged:Fire(compost)
		end
	end
end

function TreeTierState.RequestTierUp()
	RequestTierUp:FireServer()
end

TierUpResult.OnClientEvent:Connect(function(result)
	if result.Success then
		applyState(result.NewTier, result.Compost)
	else
		TreeTierState.TierUpFailed:Fire(result.Reason)
	end
end)

-- Initial fetch, then a light fallback poll for anything that changes
-- Compost outside of a tier-up (e.g. your leaf -> compost conversion).
-- Swap the poll for a push from wherever Compost actually changes once
-- that's wired up — this is just the simplest thing that works today.
task.spawn(function()
	local ok, tier, compostRaw = pcall(function()
		return GetTreeTierState:InvokeServer()
	end)
	if ok then
		applyState(tier, compostRaw)
	end

	while true do
		task.wait(1)
		local success, t, c = pcall(function()
			return GetTreeTierState:InvokeServer()
		end)
		if success then
			applyState(t, c)
		end
	end
end)

return TreeTierState
