--!strict
--[[
	CurrencyDisplayController.client.luau

	The currency HUD: one pill per currency, icon then amount, centre
	right of the screen.

	READS THE GAME'S REAL DATA LAYER. This used to read NumberValue
	folders written by its own CurrencyDisplayService — a second copy of
	currency data living beside the real one in DataManager. Everything
	now comes from the pipeline the tier board and progress bar already
	use: DataManager -> CurrencyNetworkBridge -> CurrencyStatsState.

	That's what makes the unlock rule correct rather than approximately
	correct. "Unlocked" means Statistics.TotalValues.Total<Name>Collected
	is above zero — the actual lifetime stat, which DataManager.AddBig is
	the only writer of and which nothing can ever lower. Spending a
	currency back to zero doesn't hide its row; never having earned it
	keeps the row hidden.

	VISIBILITY, in the order the rules are evaluated:
	  1. Lifetime total > 0. The unlock gate, and it has priority.
	  2. Settings.CurrencyView.<Name> ~= false. Defaults to true in
	     Template.Settings, so this only ever hides something the player
	     deliberately turned off.

	ORDER comes from CurrencyOrder, the shared list — not a private table
	in this system's config.

	Location: StarterPlayer/StarterPlayerScripts/CurrencyDisplay/CurrencyDisplayController.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local BigNumber          = require(Modules:WaitForChild("BigNumber"))
local CurrencyOrder      = require(Modules:WaitForChild("CurrencyOrder"))
local CurrencyStatsState = require(Modules:WaitForChild("CurrencyStatsState"))
local SettingsState      = require(Modules:WaitForChild("SettingsState"))
local LiveBind           = require(Modules:WaitForChild("UI"):WaitForChild("LiveBind"))
local CurrencyArt        = require(Modules:WaitForChild("UI"):WaitForChild("CurrencyArt"))

local DisplayModules = Modules:WaitForChild("CurrencyDisplay")
local Config   = require(DisplayModules:WaitForChild("CurrencyDisplayConfig"))
local RowClass = require(DisplayModules:WaitForChild("CurrencyDisplayRow"))

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local ZERO = BigNumber.new(0, 0)

--== Shell ==-----------------------------------------------------------

local stale = playerGui:FindFirstChild("CurrencyDisplayGui")
if stale then
	stale:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name           = "CurrencyDisplayGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.DisplayOrder   = Config.Panel.DisplayOrder
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

local panel = Instance.new("ScrollingFrame")
panel.Name                       = "Panel"
panel.AnchorPoint                = Config.Panel.AnchorPoint
panel.Position                   = Config.Panel.Position
panel.Size                       = UDim2.fromOffset(Config.Panel.Width, Config.Row.Height)
panel.BackgroundTransparency     = 1
panel.BorderSizePixel            = 0
panel.Active                     = true
panel.Selectable                 = false
panel.ScrollingDirection         = Enum.ScrollingDirection.Y
panel.CanvasSize                 = UDim2.new()
panel.AutomaticCanvasSize        = Enum.AutomaticSize.Y
panel.ScrollBarThickness         = 0
panel.ScrollBarImageColor3       = Config.ScrollBar.Color
panel.ScrollBarImageTransparency = Config.ScrollBar.Transparency
panel.VerticalScrollBarInset     = Enum.ScrollBarInset.None
panel.Parent                     = gui

-- A UIStroke draws outside its frame and a ScrollingFrame clips its
-- descendants, so without this the pill outlines get sliced off flush
-- against the panel edge.
local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingTop    = UDim.new(0, Config.Panel.EdgePadding)
panelPadding.PaddingBottom = UDim.new(0, Config.Panel.EdgePadding)
panelPadding.PaddingLeft   = UDim.new(0, Config.Panel.EdgePadding)
panelPadding.PaddingRight  = UDim.new(0, Config.Panel.EdgePadding)
panelPadding.Parent        = panel

local panelLayout = Instance.new("UIListLayout")
panelLayout.FillDirection       = Enum.FillDirection.Vertical
panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
panelLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
panelLayout.SortOrder           = Enum.SortOrder.LayoutOrder
panelLayout.Padding             = UDim.new(0, Config.Panel.RowSpacing)
panelLayout.Parent              = panel

local function resizePanel()
	local edge = Config.Panel.EdgePadding * 2
	local maxHeight = math.max(Config.Row.Height + edge, gui.AbsoluteSize.Y * Config.Panel.MaxHeightScale)
	local contentHeight = panelLayout.AbsoluteContentSize.Y + edge
	local overflowing = contentHeight > maxHeight

	panel.Size = UDim2.fromOffset(Config.Panel.Width, math.ceil(math.min(contentHeight, maxHeight)))
	panel.ScrollBarThickness = (Config.ScrollBar.AutoHide and not overflowing) and 0 or Config.ScrollBar.Thickness
end

panelLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizePanel)

--== Rows ==------------------------------------------------------------
-- CurrencyOrder decides both which rows exist and what order they sit
-- in. LayoutOrder is the index into it, so Leafs -> Compost -> Nuts here
-- means Leafs -> Compost -> Nuts everywhere.

for index, currencyName in CurrencyOrder do
	local row = RowClass.new(currencyName, panel, index)

	CurrencyArt.Bind(currencyName, {
		Icons = { row.Icon },
		Labels = { row.Amount },
	}, { MissingIconColor = Config.MissingIconColor })

	-- Amount. Watch rather than Bind so the same recompute can drive the
	-- pop, which needs the previous value to compare against.
	local previousBalance: any = nil
	LiveBind.Watch(function()
		return CurrencyStatsState.Balances[currencyName] or ZERO
	end, { CurrencyStatsState.Changed.Event, SettingsState.Changed }, function(balance)
		row:SetText(BigNumber.Format(balance, SettingsState.Get("General.NumberNotation")))
		if previousBalance and row:IsVisible() and BigNumber.GreaterThan(balance, previousBalance) then
			row:Pop()
		end
		previousBalance = balance
	end)

	-- Visibility. Lifetime total gates the settings toggle.
	LiveBind.Watch(function()
		local total = CurrencyStatsState.Totals[currencyName] or ZERO
		if not BigNumber.GreaterThan(total, ZERO) then
			return false
		end
		return SettingsState.Get("CurrencyView." .. currencyName) ~= false
	end, { CurrencyStatsState.Changed.Event, SettingsState.Changed }, function(shouldShow)
		local wasVisible = row:IsVisible()
		row:SetVisible(shouldShow)
		if shouldShow and not wasVisible then
			row:Pop()
		end
	end)
end

resizePanel()
