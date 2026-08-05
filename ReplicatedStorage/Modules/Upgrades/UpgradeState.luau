--!strict
--[[
	UpgradeState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of this player's upgrade LEVELS, and nothing else.

	Levels are all it needs. Cost, boost value, max level and display text
	are all derived from the level through UpgradeSchema and
	UpgradeDisplay, both in ReplicatedStorage — so the client computes
	everything itself from one number per upgrade. Shipping costs and
	boosts over the wire would send data the client can already derive,
	and hand it a second copy to drift out of sync with.

	FOUR SYNC PATHS. Three of them are "something changed a level", and
	the pattern behind the two that were missing is worth naming: any
	server action that rewrites upgrade levels WITHOUT a purchase leaves
	this cache stale while the data is perfectly correct. Both resets do
	exactly that.

	  1. GetUpgradeState, invoked at startup and retried until it lands.
	  2. PurchaseResult, pushed after every buy — single or max.
	  3. A tier change. Tiering up resets upgrade categories.
	  4. A reset layer. Composting wipes LeafUpgrades.

	Paths 3 and 4 hook existing client signals rather than adding
	remotes: the server already tells us both events happened, and both
	are the only things that reset levels.

	Location: ReplicatedStorage/Modules/Upgrades/UpgradeState.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeSchema = require(ReplicatedStorage.Modules.Upgrades.UpgradeSchema)

local upgradeEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Upgrades")
local GetUpgradeState = upgradeEvents:WaitForChild("GetUpgradeState")
local RequestPurchase = upgradeEvents:WaitForChild("RequestPurchase")
local RequestMaxPurchase = upgradeEvents:WaitForChild("RequestMaxPurchase")
local PurchaseResult = upgradeEvents:WaitForChild("PurchaseResult")

local RETRY_MAX_WAIT = 4

local UpgradeState = {}

UpgradeState.Levels = {} :: { [string]: number }

-- Fires with (upgradeId: string). Listeners re-read Levels themselves.
UpgradeState.Changed = Instance.new("BindableEvent")
-- Fires with (reason: string, upgradeId: string)
UpgradeState.PurchaseFailed = Instance.new("BindableEvent")

UpgradeState.Ready = Instance.new("BindableEvent")
UpgradeState.IsReady = false

for upgradeId in UpgradeSchema.All do
	UpgradeState.Levels[upgradeId] = 0
end

function UpgradeState.GetLevel(upgradeId: string): number
	return UpgradeState.Levels[upgradeId] or 0
end

local function setLevel(upgradeId: string, level: number)
	local clamped = UpgradeSchema.ClampLevel(upgradeId, level)
	if UpgradeState.Levels[upgradeId] ~= clamped then
		UpgradeState.Levels[upgradeId] = clamped
		UpgradeState.Changed:Fire(upgradeId)
	end
end

local function applyBundle(bundle: any): boolean
	if type(bundle) ~= "table" or next(bundle) == nil then
		return false
	end
	for upgradeId, entry in bundle do
		if type(entry) == "table" and type(entry.Level) == "number" then
			setLevel(upgradeId, entry.Level)
		end
	end
	return true
end

-- Public, so anything that knows it invalidated the levels can say so.
function UpgradeState.Refresh()
	task.spawn(function()
		local ok, bundle = pcall(function()
			return GetUpgradeState:InvokeServer()
		end)
		if ok then
			applyBundle(bundle)
		end
	end)
end

function UpgradeState.RequestPurchase(upgradeId: string)
	RequestPurchase:FireServer(upgradeId)
end

function UpgradeState.RequestMaxPurchase(upgradeId: string)
	RequestMaxPurchase:FireServer(upgradeId)
end

PurchaseResult.OnClientEvent:Connect(function(result)
	if type(result) ~= "table" or type(result.UpgradeId) ~= "string" then
		return
	end
	if result.Success and type(result.Level) == "number" then
		setLevel(result.UpgradeId, result.Level)
	elseif not result.Success then
		UpgradeState.PurchaseFailed:Fire(result.Reason or "Unknown", result.UpgradeId)
	end
end)

-- Deferred: both of these are client-only modules that pull in further
-- chains of their own, so they're required after this module returns
-- rather than dragging all of it into anything that touches upgrade
-- levels at load time.
task.defer(function()
	local okTier, TreeTierState = pcall(function()
		return require(ReplicatedStorage.Modules.TreeTierState)
	end)
	if okTier and TreeTierState then
		TreeTierState.TierChanged.Event:Connect(function()
			UpgradeState.Refresh()
		end)
	else
		warn("UpgradeState: could not hook TreeTierState.TierChanged — levels will not refresh on a tree reset.")
	end

	local okReset, ResetState = pcall(function()
		return require(ReplicatedStorage.Modules.Resets.ResetState)
	end)
	if okReset and ResetState then
		ResetState.Performed.Event:Connect(function()
			UpgradeState.Refresh()
		end)
	else
		warn("UpgradeState: could not hook ResetState.Performed — levels will not refresh on a reset layer.")
	end
end)

task.spawn(function()
	local attempt = 0
	while true do
		local ok, bundle = pcall(function()
			return GetUpgradeState:InvokeServer()
		end)
		if ok and applyBundle(bundle) then
			break
		end
		attempt += 1
		task.wait(math.min(0.5 * attempt, RETRY_MAX_WAIT))
	end

	-- Unconditional: consumers bound against a pre-fetch guess of all
	-- zeros and need one signal to re-render against confirmed data,
	-- even where the guess happened to be right.
	UpgradeState.IsReady = true
	for upgradeId in UpgradeSchema.All do
		UpgradeState.Changed:Fire(upgradeId)
	end
	UpgradeState.Ready:Fire()
end)

return UpgradeState
