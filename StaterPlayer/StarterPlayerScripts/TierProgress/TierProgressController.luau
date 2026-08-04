--!strict
--[[
	TierProgressController.client.luau

	A thin, full-width bar flush against the top of the screen: currency
	icon and "have / need" centred inside it, a fill tracking the ratio,
	and a caption reading "Progress to Tier 3" directly beneath. Once the
	next tier is affordable the fill goes green and full, the caption
	switches to "YOU CAN TIER UP", and a highlight sweeps along the bar.

	FULL-BLEED, so a few things that would be normal for a floating HUD
	panel are deliberately absent: no corner radius, no outer stroke, no
	width clamp, no anchor offset. The bar runs edge to edge at y = 0 and
	the Roblox topbar renders over its left end.

	READS THE SAME TWO MODULES THE BOARD DOES — TreeTierState for the
	live tier and balance, TreeTierPreview for what the next tier costs
	and whether there is one. That's deliberate: a top bar saying you can
	afford a tier-up while the board's button still says CAN'T AFFORD is
	worse than having no bar at all, and the only reliable way to prevent
	that is for both to ask the same question of the same source rather
	than each deriving its own answer.

	No new remotes and no polling. TreeTierState already gets its balance
	from CurrencyStatsState, which CurrencyNetworkBridge pushes into the
	instant DataManager writes a currency — so this bar moves on the same
	frame the currency does.

	Location: StarterPlayer/StarterPlayerScripts/TierProgress/TierProgressController.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local BigNumber       = require(Modules:WaitForChild("BigNumber"))
local TreeTierState   = require(Modules:WaitForChild("TreeTierState"))
local TreeTierPreview = require(Modules:WaitForChild("TreeTierPreview"))
local SettingsState   = require(Modules:WaitForChild("SettingsState"))
local CurrencyArt     = require(Modules:WaitForChild("UI"):WaitForChild("CurrencyArt"))
local Config          = require(Modules:WaitForChild("TierProgress"):WaitForChild("TierProgressConfig"))

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

--== Shell ==-----------------------------------------------------------

local stale = playerGui:FindFirstChild("TierProgressGui")
if stale then
	stale:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name           = "TierProgressGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = Config.Layout.IgnoreGuiInset
gui.DisplayOrder   = Config.Layout.DisplayOrder
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

--== Track ==-----------------------------------------------------------
-- Full width, square, pinned to y = 0. No UICorner and no UIStroke on
-- purpose: rounding a bar that runs off both edges of the screen only
-- makes the ends look broken.

local track = Instance.new("Frame")
track.Name                   = "Track"
track.AnchorPoint            = Vector2.new(0, 0)
track.Position               = UDim2.new(0, 0, 0, 0)
track.Size                   = UDim2.new(1, 0, 0, Config.Layout.BarHeight)
track.BackgroundColor3       = Config.Track.Color
track.BackgroundTransparency = Config.Track.Transparency
track.BorderSizePixel        = 0
track.ClipsDescendants       = true
track.Parent                 = gui

local fill = Instance.new("Frame")
fill.Name             = "Fill"
fill.Size             = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fill.BorderSizePixel  = 0
fill.Parent           = track

local fillGradient = Instance.new("UIGradient")
fillGradient.Rotation = 90
fillGradient.Color = ColorSequence.new(Config.Fill.ProgressStart, Config.Fill.ProgressEnd)
fillGradient.Parent = fill

-- Sweeping highlight, parented to the fill so it's clipped to the filled
-- portion rather than sliding across empty track.
local shine = Instance.new("Frame")
shine.Name                   = "Shine"
shine.Size                   = UDim2.fromScale(1, 1)
shine.BackgroundColor3       = Config.Shine.Color
shine.BackgroundTransparency = 1
shine.BorderSizePixel        = 0
shine.Visible                = false
shine.Parent                 = fill

local shineGradient = Instance.new("UIGradient")
shineGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(math.clamp(0.5 - Config.Shine.Width, 0.01, 0.49), 1),
	NumberSequenceKeypoint.new(0.5, Config.Shine.Peak),
	NumberSequenceKeypoint.new(math.clamp(0.5 + Config.Shine.Width, 0.51, 0.99), 1),
	NumberSequenceKeypoint.new(1, 1),
})
shineGradient.Parent = shine

-- Hairline base, so the bar has a defined edge against the world.
if Config.Track.EdgeThickness > 0 then
	local edge = Instance.new("Frame")
	edge.Name                   = "Edge"
	edge.AnchorPoint            = Vector2.new(0, 1)
	edge.Position               = UDim2.fromScale(0, 1)
	edge.Size                   = UDim2.new(1, 0, 0, Config.Track.EdgeThickness)
	edge.BackgroundColor3       = Config.Track.EdgeColor
	edge.BackgroundTransparency = Config.Track.EdgeTransparency
	edge.BorderSizePixel        = 0
	edge.ZIndex                 = 3
	edge.Parent                 = track
end

--== Label group (above the fill, centred in the bar) ==----------------

local labelGroup = Instance.new("Frame")
labelGroup.Name                   = "LabelGroup"
labelGroup.Size                   = UDim2.fromScale(1, 1)
labelGroup.BackgroundTransparency = 1
labelGroup.ZIndex                 = 2
labelGroup.Parent                 = track

local labelLayout = Instance.new("UIListLayout")
labelLayout.FillDirection       = Enum.FillDirection.Horizontal
labelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
labelLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
labelLayout.SortOrder           = Enum.SortOrder.LayoutOrder
labelLayout.Padding             = UDim.new(0, Config.Text.Gap)
labelLayout.Parent              = labelGroup

local icon = Instance.new("ImageLabel")
icon.Name                   = "Icon"
icon.LayoutOrder            = 1
icon.Size                   = UDim2.fromOffset(Config.Text.IconSize, Config.Text.IconSize)
icon.BackgroundTransparency = 1
icon.ScaleType              = Enum.ScaleType.Fit
icon.ZIndex                 = 2
icon.Visible                = Config.Text.ShowIcon
icon.Parent                 = labelGroup

local amountLabel = Instance.new("TextLabel")
amountLabel.Name                   = "AmountLabel"
amountLabel.LayoutOrder            = 2
amountLabel.Size                   = UDim2.new(0, 0, 1, 0)
amountLabel.AutomaticSize          = Enum.AutomaticSize.X
amountLabel.BackgroundTransparency = 1
amountLabel.Font                   = Config.Text.Font
amountLabel.TextSize               = Config.Text.Size
amountLabel.TextColor3             = Config.Text.Color
amountLabel.ZIndex                 = 2
amountLabel.Text                   = ""
amountLabel.Parent                 = labelGroup

local amountStroke = Instance.new("UIStroke")
amountStroke.Color           = Config.Text.StrokeColor
amountStroke.Thickness       = Config.Text.StrokeThickness
amountStroke.LineJoinMode    = Enum.LineJoinMode.Round
amountStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
amountStroke.Parent          = amountLabel

--== Caption (below the bar, on the world) ==---------------------------

local caption = Instance.new("TextLabel")
caption.Name                   = "Caption"
caption.AnchorPoint            = Vector2.new(0.5, 0)
caption.Position               = UDim2.new(0.5, 0, 0, Config.Layout.BarHeight + Config.Layout.CaptionGap)
caption.Size                   = UDim2.new(1, 0, 0, Config.Layout.CaptionHeight)
caption.BackgroundTransparency = 1
caption.Font                   = Config.Caption.Font
caption.TextSize               = Config.Caption.Size
caption.TextColor3             = Config.Caption.Color
caption.Text                   = ""
caption.Parent                 = gui

local captionStroke = Instance.new("UIStroke")
captionStroke.Color           = Config.Caption.StrokeColor
captionStroke.Thickness       = Config.Caption.StrokeThickness
captionStroke.LineJoinMode    = Enum.LineJoinMode.Round
captionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
captionStroke.Parent          = caption

--== Shine ==-----------------------------------------------------------

local shineTween: Tween? = nil

local function setShining(active: boolean)
	if not Config.Shine.Enabled then
		return
	end

	if active and not shineTween then
		shine.Visible = true
		shine.BackgroundTransparency = 0
		shineGradient.Offset = Vector2.new(-1, 0)
		shineTween = TweenService:Create(
			shineGradient,
			TweenInfo.new(Config.Shine.Time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false),
			{ Offset = Vector2.new(1, 0) }
		)
		;(shineTween :: Tween):Play()
	elseif not active and shineTween then
		shineTween:Cancel()
		shineTween = nil
		shine.Visible = false
	end
end

--== Currency art ==----------------------------------------------------

-- Re-bound whenever the tier changes, since a later tier can cost an
-- entirely different currency and should show that one's icon.
local artHandle: any = nil
local boundCurrency: string? = nil

local function bindArt(currencyName: string?)
	if artHandle then
		artHandle:Disconnect()
		artHandle = nil
	end
	if currencyName and Config.Text.ShowIcon then
		artHandle = CurrencyArt.Bind(currencyName, { Icons = { icon } })
		icon.Visible = true
	else
		icon.Visible = false
	end
end

--== Refresh ==---------------------------------------------------------

local function setVisible(visible: boolean)
	track.Visible = visible
	caption.Visible = visible
end

local function refresh()
	local preview = TreeTierPreview.Build(TreeTierState.Tier)

	if preview.IsMaxed then
		if Config.HideWhenMaxed then
			setVisible(false)
			setShining(false)
			return
		end

		setVisible(true)
		setShining(false)
		bindArt(nil)
		boundCurrency = nil
		fillGradient.Color = ColorSequence.new(Config.Maxed.FillStart, Config.Maxed.FillEnd)
		fill.Size = UDim2.fromScale(1, 1)
		amountLabel.Text = ""
		caption.Text = Config.Caption.MaxedText
		caption.TextColor3 = Config.Caption.Color
		return
	end

	setVisible(true)

	local cost = preview.Cost
	if boundCurrency ~= cost.Currency then
		boundCurrency = cost.Currency
		bindArt(cost.Currency)
	end

	-- One source for "can they afford it": the same balance/currency pair
	-- the board's button reads, compared the same way.
	local balance = TreeTierState.Balance
	local matchesCurrency = TreeTierState.BalanceCurrency == cost.Currency
	local canAfford = matchesCurrency and BigNumber.GreaterThanOrEqual(balance, cost.Amount)
	local ratio = matchesCurrency and TreeTierPreview.GetRatio(balance, cost.Amount) or 0

	if canAfford then
		fillGradient.Color = ColorSequence.new(Config.Fill.ReadyStart, Config.Fill.ReadyEnd)
		amountLabel.Text = Config.Text.ReadyText
		caption.Text = Config.Caption.ReadyText
		caption.TextColor3 = Config.Caption.ReadyColor
	else
		local notation = SettingsState.Get("General.NumberNotation")
		local text = ("%s / %s"):format(
			BigNumber.Format(balance, notation),
			BigNumber.Format(cost.Amount, notation)
		)
		if Config.Text.ShowCurrencyName then
			text ..= " " .. cost.Currency
		end

		fillGradient.Color = ColorSequence.new(Config.Fill.ProgressStart, Config.Fill.ProgressEnd)
		amountLabel.Text = text
		caption.Text = Config.Caption.ProgressFormat:format(preview.NextTier)
		caption.TextColor3 = Config.Caption.Color
	end

	setShining(canAfford)

	TweenService:Create(
		fill,
		TweenInfo.new(Config.Fill.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(canAfford and 1 or ratio, 1) }
	):Play()
end

TreeTierState.TierChanged.Event:Connect(refresh)
TreeTierState.BalanceChanged.Event:Connect(refresh)
SettingsState.Changed:Connect(refresh)
refresh()
