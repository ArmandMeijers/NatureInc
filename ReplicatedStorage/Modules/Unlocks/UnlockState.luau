--!strict
--[[
	UnlockState.luau  (CLIENT ONLY — never require this from server code)

	Local cache of which features this player has unlocked.

	REFRESH TRIGGERS are the same three that every other client cache in
	this codebase needs, for the same reason: unlocks change through
	server actions that involve no purchase, so nothing pushes them.

	  1. A startup fetch, retried until it lands.
	  2. A tier change. Tiering up is the main way things unlock.
	  3. A reset layer, since a future layer may unlock something too.

	Changed fires with no arguments — unlocks change rarely and in
	batches, so listeners re-read everything rather than tracking which
	path moved.

	Location: ReplicatedStorage/Modules/Unlocks/UnlockState.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnlockScheme = require(ReplicatedStorage.Modules.Unlocks.UnlockScheme)

local GetUnlockState = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Unlocks"):WaitForChild("GetUnlockState")

local RETRY_MAX_WAIT = 4

local UnlockState = {}

UnlockState.Values = {} :: { [string]: any }
UnlockState.Changed = Instance.new("BindableEvent")
UnlockState.Ready = Instance.new("BindableEvent")
UnlockState.IsReady = false

function UnlockState.IsUnlocked(path: string): boolean
	return UnlockScheme.IsUnlockedValue(UnlockState.Values[UnlockScheme.Resolve(path)])
end

function UnlockState.GetValue(path: string): any
	return UnlockState.Values[UnlockScheme.Resolve(path)]
end

local function applyBundle(bundle: any): boolean
	if type(bundle) ~= "table" then
		return false
	end

	local changed = false
	for path, value in bundle do
		if UnlockState.Values[path] ~= value then
			UnlockState.Values[path] = value
			changed = true
		end
	end

	if changed then
		UnlockState.Changed:Fire()
	end
	return true
end

function UnlockState.Refresh()
	task.spawn(function()
		local ok, bundle = pcall(function()
			return GetUnlockState:InvokeServer()
		end)
		if ok then
			applyBundle(bundle)
		end
	end)
end

-- Deferred: both are client-only modules with require chains of their
-- own, pulled in after this module returns rather than dragged into
-- anything that reads an unlock at load time.
task.defer(function()
	local okTier, TreeTierState = pcall(function()
		return require(ReplicatedStorage.Modules.TreeTierState)
	end)
	if okTier and TreeTierState then
		TreeTierState.TierChanged.Event:Connect(UnlockState.Refresh)
	else
		warn("UnlockState: could not hook TreeTierState.TierChanged — unlocks will not appear until rejoin.")
	end

	local okReset, ResetState = pcall(function()
		return require(ReplicatedStorage.Modules.Resets.ResetState)
	end)
	if okReset and ResetState then
		ResetState.Performed.Event:Connect(UnlockState.Refresh)
	end
end)

task.spawn(function()
	local attempt = 0
	while true do
		local ok, bundle = pcall(function()
			return GetUnlockState:InvokeServer()
		end)
		if ok and applyBundle(bundle) then
			break
		end
		attempt += 1
		task.wait(math.min(0.5 * attempt, RETRY_MAX_WAIT))
	end

	-- Unconditional: consumers rendered against an empty cache and need
	-- one signal to re-render against confirmed data. Without it, a
	-- player who has genuinely unlocked nothing never gets a Changed
	-- event, and anything waiting on one hides forever.
	UnlockState.IsReady = true
	UnlockState.Changed:Fire()
	UnlockState.Ready:Fire()
end)

return UnlockState
