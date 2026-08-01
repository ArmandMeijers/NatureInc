--!strict
--[[
	CurrencyStatsController.client.luau

	Drives the CurrencyStatsGui rows that already exist under StarterGui
	(built once by the deploy command, then yours to edit by hand in
	Studio -- move them, recolor them, resize the pill, whatever). This
	script does NOT build any UI. It finds each row by name and binds two
	properties on it via LiveBind:

		<Name>Row.AmountLabel.Text     -- formatted balance, notation-aware
		<Name>Row.Visible              -- true once lifetime total > 0

	That's it. Every other property (the row's gradient-fade background,
	the currency-branded text gradient, the icon image, position, size)
	lives on the actual GUI objects, not in this script -- so redesigning
	the look later never means touching Lua again.

	Row visibility is driven by TOTAL ever collected, not current balance,
	per how CurrencyStatsState/CurrencyStatsService report it: total only
	ever goes up (see DataManager.SetBig), so a row that's appeared never
	disappears just because you spent the currency back down to 0.

	Location: StarterPlayer/StarterPlayerScripts/CurrencyStats/CurrencyStatsController.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local CurrencyOrder = require(ReplicatedStorage.Modules.CurrencyOrder)
local CurrencyStatsState = require(ReplicatedStorage.Modules.CurrencyStatsState)
local SettingsState = require(ReplicatedStorage.Modules.SettingsState)
local LiveBind = require(ReplicatedStorage.Modules.UI.LiveBind)

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local statsGui = playerGui:WaitForChild("CurrencyStatsGui")
local panel = statsGui:WaitForChild("Panel")

local ZERO = BigNumber.new(0, 0)

for _, currencyName in CurrencyOrder do
	local row = panel:FindFirstChild(currencyName .. "Row")
	if not row then
		warn(`CurrencyStatsController: no '{currencyName}Row' under CurrencyStatsGui.Panel -- add one (copy an existing row and rename it) for this currency to show up.`)
		continue
	end

	local amountLabel = row:FindFirstChild("AmountLabel")
	if not amountLabel then
		warn(`CurrencyStatsController: '{currencyName}Row' has no AmountLabel -- skipping.`)
		continue
	end

	LiveBind.Bind(amountLabel, "Text", function()
		local balance = CurrencyStatsState.Balances[currencyName] or ZERO
		local notation = SettingsState.Get("General.NumberNotation")
		return BigNumber.Format(balance, notation)
	end, { CurrencyStatsState.Changed.Event, SettingsState.Changed })

	LiveBind.Bind(row, "Visible", function()
		local total = CurrencyStatsState.Totals[currencyName] or ZERO
		return BigNumber.GreaterThan(total, ZERO)
	end, { CurrencyStatsState.Changed.Event })
end

