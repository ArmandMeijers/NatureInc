--[[
	CurrencyNetworkBridge.luau

	Forwards currency changes to the client the instant they happen,
	instead of clients finding out via their next poll. DataManager.Set
	already fires DataManager.Changed for every change (see
	DataManager.luau) — that signal is server-only by design, kept
	networking-agnostic on purpose. This is the one place that bridges it
	to the network, so DataManager itself never has to know about Remotes,
	and nothing else (LeafCollectionService, TreeTierService, any future
	currency-granting system) ever has to remember to push an update
	itself — collect currency through DataManager.AddCurrency/SetCurrency/
	etc. anywhere, and this catches it automatically.

	Only forwards Currency.* and Statistics.TotalValues.Total*Collected —
	nothing else leaks over this channel.

	Location: ServerScriptService/Systems/CurrencyNetworkBridge.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.DataStore.DataManager)

local remote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Currency"):WaitForChild("CurrencyBalanceChanged")

local function isRelevant(path: string): boolean
	return path:match("^Currency%.") ~= nil or path:match("^Statistics%.TotalValues%.Total%w+Collected$") ~= nil
end

DataManager.Changed:Connect(function(player: Player, path: string, value: any)
	if isRelevant(path) then
		remote:FireClient(player, path, value)
	end
end)

