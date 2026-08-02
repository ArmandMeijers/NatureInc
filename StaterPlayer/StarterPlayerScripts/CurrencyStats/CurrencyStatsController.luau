--!strict
--[[
	CurrencyStatsController.client.luau

	Drives the CurrencyStatsGui rows that already exist under StarterGui
	(built once by the deploy command, then yours to edit by hand in
	Studio -- move them, recolor them, resize the pill, whatever). This
	script does NOT build any UI. It finds each row by name and binds
	properties on it via LiveBind:

		<Name>Row.AmountLabel.Text     -- formatted balance, notation-aware
		<Name>Row.Visible              -- see below

	A row is visible when BOTH of these are true:
	  1. Lifetime total collected > 0 (see DataManager.SetBig) -- so a row
	     that's appeared never disappears just because you spent the
	     currency back down to 0.
	  2. Settings.CurrencyView.<Name> isn't explicitly false -- this is
	     the actual wiring for what SettingState.luau's own doc comment
	     already promised ("show/hide a currency display when
	     CurrencyView.Leafs is flipped") but nothing ever implemented.
	     Turning a currency off in the settings menu now actually hides
	     its row here, instead of the toggle changing color with no
	     effect on the display.

	This script also keeps the ScrollingFrame pinned to the BOTTOM of its
	canvas whenever the canvas is resized (a row appearing/disappearing
	changes the total content height) -- Panel is anchored bottom-left and
	grows upward, so "pinned to bottom" means whatever's near the anchor
	corner stays in view by default, and overflow at the top is what
	needs a scroll up to reach, matching how the rows are ordered.

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
local panel = statsGui:WaitForChild("Panel") :: ScrollingFrame

local ZERO = BigNumber.new(0, 0)

-- Keeps the anchor corner (bottom-left) in view whenever the canvas
-- height changes -- i.e. whenever a row's Visible toggles and the
-- UIListLayout recomputes AbsoluteContentSize. Native Roblox signal, not
-- app data, so it doesn't go through LiveBind.
local function pinScrollToBottom()
	local overflow = panel.AbsoluteCanvasSize.Y - panel.AbsoluteWindowSize.Y
	panel.CanvasPosition = Vector2.new(0, math.max(0, overflow))
end
panel:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(pinScrollToBottom)
pinScrollToBottom()

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
		local hasCollectedAny = BigNumber.GreaterThan(total, ZERO)
		local viewEnabled = SettingsState.Get("CurrencyView." .. currencyName) ~= false
		return hasCollectedAny and viewEnabled
	end, { CurrencyStatsState.Changed.Event, SettingsState.Changed })
end