--[[
	DataManager.luau

	Wraps ProfileStore: handles session lifecycle (join/leave/shutdown) and
	exposes the read/write API the rest of the game uses. Nobody else should
	require ProfileStore directly — go through this module.

	Location: ServerScriptService/DataStore/DataManager.luau
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.ProfileStore)
local Template = require(script.Parent.Template)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

local DataManager = {}

local PlayerStore = ProfileStore.New("PlayerStore", Template)
local Profiles: { [Player]: any } = {}

-- ============================================================
-- Session lifecycle
-- ============================================================

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

-- ============================================================
-- Generic path-based access
-- Works for any category without writing a new function per field,
-- e.g. DataManager.Get(player, "Tree.Tier"), "Settings.NumberNotation"
-- ============================================================

local function getPath(data: any, path: string): any
	local current = data
	for _, key in string.split(path, ".") do
		if type(current) ~= "table" then
			return nil
		end
		current = current[key]
	end
	return current
end

local function setPath(data: any, path: string, value: any)
	local keys = string.split(path, ".")
	local current = data
	for i = 1, #keys - 1 do
		current = current[keys[i]]
		if type(current) ~= "table" then
			error(`DataManager.Set: invalid path '{path}'`)
		end
	end
	current[keys[#keys]] = value
end

function DataManager.GetProfile(player: Player): any
	return Profiles[player]
end

function DataManager.Get(player: Player, path: string): any
	local profile = Profiles[player]
	if not profile then
		return nil
	end
	return getPath(profile.Data, path)
end

function DataManager.Set(player: Player, path: string, value: any)
	local profile = Profiles[player]
	if not profile or not profile:IsActive() then
		return
	end
	setPath(profile.Data, path, value)
end

-- ============================================================
-- Currency helpers (BigNumber-aware)
-- ============================================================

function DataManager.GetCurrency(player: Player, currencyName: string)
	local raw = DataManager.Get(player, "Currency." .. currencyName)
	return BigNumber.Deserialize(raw)
end

function DataManager.SetCurrency(player: Player, currencyName: string, amount)
	DataManager.Set(player, "Currency." .. currencyName, BigNumber.Serialize(amount))
end

function DataManager.AddCurrency(player: Player, currencyName: string, amount)
	local current = DataManager.GetCurrency(player, currencyName)
	local newValue = BigNumber.Add(current, amount)
	DataManager.SetCurrency(player, currencyName, newValue)
	return newValue
end

function DataManager.SubtractCurrency(player: Player, currencyName: string, amount)
	local current = DataManager.GetCurrency(player, currencyName)
	local newValue = BigNumber.Sub(current, amount)
	if BigNumber.LessThan(newValue, BigNumber.new(0, 0)) then
		newValue = BigNumber.new(0, 0)
	end
	DataManager.SetCurrency(player, currencyName, newValue)
	return newValue
end

function DataManager.CanAfford(player: Player, currencyName: string, cost): boolean
	local current = DataManager.GetCurrency(player, currencyName)
	return BigNumber.GreaterThanOrEqual(current, cost)
end


return DataManager