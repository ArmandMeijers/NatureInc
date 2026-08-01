--!strict
--[[
	DataManager.luau

	Wraps ProfileStore: handles session lifecycle (join/leave/shutdown) and
	exposes the read/write API the rest of the game uses. Nobody else should
	require ProfileStore directly — go through this module.

	Location: ServerScriptService/DataStore/DataManager.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.ProfileStore)
local Template = require(script.Parent.Template)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

type BigNum = BigNumber.BigNum
type Profile = ProfileStore.Profile<typeof(Template)>

local DataManager = {}

local PlayerStore = ProfileStore.New("PlayerStore", Template)
local Profiles: { [Player]: Profile } = {}

-- ============================================================
-- Lightweight signal
-- Plain listener table instead of a BindableEvent — Set() can fire this
-- often (currency ticks, sacrifice loops), so we skip Instance overhead.
-- ============================================================

type Connection = { Disconnect: (self: Connection) -> () }

local function newSignal()
	local listeners: { (...any) -> () } = {}
	local signal = {}

	function signal.Connect(_, fn: (...any) -> ()): Connection
		table.insert(listeners, fn)
		local connection = {}
		function connection.Disconnect()
			local index = table.find(listeners, fn)
			if index then
				table.remove(listeners, index)
			end
		end
		return connection
	end

	function signal.Fire(_, ...: any)
		for _, fn in listeners do
			task.spawn(fn, ...)
		end
	end

	return signal
end

-- Fired as (player, path, newValue) whenever Set/Update/Remove changes data.
-- UI (settings panel, currency HUD, quests later) subscribes instead of polling:
--   DataManager.Changed:Connect(function(player, path, newValue)
--       if path == "Currency.Leafs" then ... end
--   end)
DataManager.Changed = newSignal()

-- ============================================================
-- Session lifecycle
-- ============================================================

local function getProfile(player: Player): Profile?
	local profile = Profiles[player]
	if not profile or not profile:IsActive() then
		return nil
	end
	return profile
end

local function onPlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("Data load failed — please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile() -- merges any new Template fields into this save

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		player:Kick("Data session ended — please rejoin.")
	end)

	if player.Parent == Players then
		Profiles[player] = profile
	else
		-- Player left during the async load — release immediately.
		profile:EndSession()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

function DataManager.GetProfile(player: Player): Profile?
	return Profiles[player]
end

-- Yields until the player's profile has finished loading, the player leaves,
-- or `timeout` seconds pass (default 15) — whichever comes first.
function DataManager.WaitForProfile(player: Player, timeout: number?): Profile?
	if Profiles[player] then
		return Profiles[player]
	end

	local timeoutAt = os.clock() + (timeout or 15)

	while player.Parent == Players and not Profiles[player] do
		if os.clock() >= timeoutAt then
			return nil
		end
		task.wait(0.05)
	end

	return Profiles[player]
end

-- ============================================================
-- Path caching + schema validation
-- ============================================================

local PathCache: { [string]: { string } } = {}

local function getKeys(path: string): { string }
	local keys = PathCache[path]
	if not keys then
		keys = string.split(path, ".")
		PathCache[path] = keys
	end
	return keys
end

-- Validates against Template (the schema), NOT a player's live data.
-- This is deliberate: after Remove() nils out a real key, the key still
-- exists in Template, so a later Set() on that same path won't be wrongly
-- flagged as a typo. A live-data check would get that wrong.
local TemplatePathCache: { [string]: boolean } = {}

local function pathExistsInTemplate(path: string): boolean
	local cached = TemplatePathCache[path]
	if cached ~= nil then
		return cached
	end

	local current: any = Template
	local exists = true
	for _, key in getKeys(path) do
		if type(current) ~= "table" then
			exists = false
			break
		end
		current = current[key]
	end

	TemplatePathCache[path] = exists
	return exists
end

local function getPath(data: any, path: string): any
	local current = data
	for _, key in getKeys(path) do
		if type(current) ~= "table" then
			return nil
		end
		current = current[key]
	end
	return current
end

local function setPath(data: any, path: string, value: any)
	local keys = getKeys(path)
	local current = data
	for i = 1, #keys - 1 do
		local nextValue = current[keys[i]]
		if type(nextValue) ~= "table" then
			-- The live save has something other than a table here, even
			-- though Template says this segment should be one -- almost
			-- always stale data left over from before a Template shape
			-- change (Reconcile only fills in MISSING keys; it never
			-- fixes one that already exists with the wrong shape).
			-- Self-heal instead of crashing: a hard error here, called
			-- from inside something like a currency-charging tier-up,
			-- would leave the player charged with nothing to show for it
			-- and the request permanently stuck.
			warn(`DataManager.Set: '{keys[i]}' in path '{path}' wasn't a table (was {typeof(nextValue)}) — replacing with a fresh table instead of crashing. This usually means old save data predates a Template shape change.`)
			nextValue = {}
			current[keys[i]] = nextValue
		end
		current = nextValue
	end
	current[keys[#keys]] = value
end

-- ============================================================
-- Generic path-based access
-- ============================================================

function DataManager.Get(player: Player, path: string): any
	local profile = getProfile(player)
	if not profile then
		return nil
	end

	if not pathExistsInTemplate(path) then
		warn(`DataManager.Get: unknown path '{path}' — check for a typo against Template.luau`)
		return nil
	end

	return getPath(profile.Data, path)
end

function DataManager.Set(player: Player, path: string, value: any): boolean
	local profile = getProfile(player)
	if not profile then
		return false
	end

	if not pathExistsInTemplate(path) then
		warn(`DataManager.Set: unknown path '{path}' — refusing to create a new key, check for a typo`)
		return false
	end

	setPath(profile.Data, path, value)
	DataManager.Changed:Fire(player, path, value)
	return true
end

-- DataManager.Update(player, "Tree.Tier", function(tier) return tier + 1 end)
function DataManager.Update(player: Player, path: string, callback: (any) -> any): boolean
	local current = DataManager.Get(player, path)
	return DataManager.Set(player, path, callback(current))
end

function DataManager.Remove(player: Player, path: string): boolean
	return DataManager.Set(player, path, nil)
end

function DataManager.Exists(player: Player, path: string): boolean
	return DataManager.Get(player, path) ~= nil
end

-- Table defaults in Template (e.g. a serialized BigNumber { m = 0, e = 0 })
-- must never be handed out by reference — assigning Template's own table
-- directly would let every reset player share (and potentially corrupt)
-- the same table Template itself uses for every other player forever.
local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, nested in value do
		copy[key] = deepCopy(nested)
	end
	return copy
end

-- Resets a path back to whatever Template currently says its default is.
-- Used by TreeTierService on tier-up (e.g. reset Currency.Leafs/Compost).
function DataManager.ResetToDefault(player: Player, path: string): boolean
	if not pathExistsInTemplate(path) then
		warn(`DataManager.ResetToDefault: unknown path '{path}' — check for a typo against Template.luau`)
		return false
	end

	local defaultValue = deepCopy(getPath(Template, path))
	return DataManager.Set(player, path, defaultValue)
end

-- Escape hatch for systems that need many values at once. This is the LIVE
-- table — write through Set/Update/Remove instead of mutating it directly,
-- or DataManager.Changed won't fire and other systems won't find out.
function DataManager.GetData(player: Player): { [string]: any }?
	local profile = getProfile(player)
	if not profile then
		return nil
	end
	return profile.Data
end

-- ============================================================
-- BigNumber-aware helpers
-- Generic so any future BigNumber stat (XP, Damage, PlayTime...) is just
-- another path — no new Get/Set/Add functions needed per stat.
-- ============================================================

function DataManager.GetBig(player: Player, path: string): BigNum
	return BigNumber.Deserialize(DataManager.Get(player, path))
end

-- Currency.<Name> -> Statistics.TotalValues.Total<Name>Collected. Only
-- currency paths have a matching lifetime-total stat.
local function getTotalStatPath(path: string): string?
	local currencyName = path:match("^Currency%.([%w_]+)$")
	if not currencyName then
		return nil
	end
	return "Statistics.TotalValues.Total" .. currencyName .. "Collected"
end

function DataManager.SetBig(player: Player, path: string, value: BigNum): boolean
	return DataManager.Set(player, path, BigNumber.Serialize(value))
end

-- Adding currency (or any other Big stat with a matching Total<Name>
-- entry) bumps BOTH the current balance AND its lifetime total, in one
-- call: AddCurrency(player, "Leafs", amount) raises Currency.Leafs AND
-- Statistics.TotalValues.TotalLeafsCollected by the same amount.
--
-- Total is ONLY ever touched here, on purpose -- SetBig/SubtractBig never
-- touch it, so spending currency, or a tier-up reset zeroing it back to
-- 0, can never lower it. Whatever the currency param is (Leafs, Compost,
-- Nuts, or anything added later), this covers it automatically as long
-- as Template has a matching Total<Name>Collected entry -- no new code
-- needed per currency.
function DataManager.AddBig(player: Player, path: string, amount: BigNum): BigNum
	local newValue = BigNumber.Add(DataManager.GetBig(player, path), amount)
	DataManager.SetBig(player, path, newValue)

	local totalStatPath = getTotalStatPath(path)
	if totalStatPath and pathExistsInTemplate(totalStatPath) then
		local newTotal = BigNumber.Add(DataManager.GetBig(player, totalStatPath), amount)
		DataManager.SetBig(player, totalStatPath, newTotal)
	end

	return newValue
end

function DataManager.SubtractBig(player: Player, path: string, amount: BigNum): BigNum
	local newValue = BigNumber.Sub(DataManager.GetBig(player, path), amount)
	if BigNumber.LessThan(newValue, BigNumber.new(0, 0)) then
		newValue = BigNumber.new(0, 0)
	end
	DataManager.SetBig(player, path, newValue)
	return newValue
end

-- ============================================================
-- Currency helpers
-- Thin wrappers over *Big — kept because AddCurrency(player, "Leafs", ...)
-- reads better at call sites than AddBig(player, "Currency.Leafs", ...)
-- everywhere in gameplay code.
-- ============================================================

function DataManager.GetCurrency(player: Player, currencyName: string): BigNum
	return DataManager.GetBig(player, "Currency." .. currencyName)
end

function DataManager.SetCurrency(player: Player, currencyName: string, amount: BigNum): boolean
	return DataManager.SetBig(player, "Currency." .. currencyName, amount)
end

function DataManager.AddCurrency(player: Player, currencyName: string, amount: BigNum): BigNum
	return DataManager.AddBig(player, "Currency." .. currencyName, amount)
end

function DataManager.SubtractCurrency(player: Player, currencyName: string, amount: BigNum): BigNum
	return DataManager.SubtractBig(player, "Currency." .. currencyName, amount)
end

function DataManager.CanAfford(player: Player, currencyName: string, cost: BigNum): boolean
	local current = DataManager.GetCurrency(player, currencyName)
	return BigNumber.GreaterThanOrEqual(current, cost)
end

return DataManager

