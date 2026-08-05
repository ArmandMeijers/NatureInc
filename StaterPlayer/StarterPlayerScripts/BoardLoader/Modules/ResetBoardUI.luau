--[[
	ResetBoardUI.luau

	The reset board: title, output-currency icon, a live progress line, a
	live payout figure, and the button. Mounted by BoardLoaderController
	for any Part with BoardType == "ResetBoard" and a ResetId attribute.

	THE PROGRESS LINE reads "32.4K / 10K" in the INPUT currency's colours
	and stays visible past the requirement — a bare CAN'T AFFORD tells you
	that you can't, but not how close you are, and once you can afford it
	the number still answers "how far past am I". The requirement comes
	from ResetMath.GetRequiredInput, which inverts whatever curve the
	scheme names, so retuning Threshold or Exponent moves this label with
	it.

	EVERYTHING IS COMPUTED LOCALLY, not fetched. Payout is a pure function
	of the input balance, which CurrencyStatsState already tracks and
	CurrencyNetworkBridge already pushes the instant it changes — so the
	labels update on the same frame the currency does, with no polling and
	no remote of their own. ResetMath is the same module the server uses
	to decide the real payout, so the preview can't drift from it.

	Location: StarterPlayer/StarterPlayerScripts/BoardLoader/Modules/ResetBoardUI.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local BigNumber          = require(Modules:WaitForChild("BigNumber"))
local CurrencyStatsState = require(Modules:WaitForChild("CurrencyStatsState"))
local SettingsState      = require(Modules:WaitForChild("SettingsState"))
local CurrencyArt        = require(Modules:WaitForChild("UI"):WaitForChild("CurrencyArt"))
local Theme              = require(Modules:WaitForChild("UI"):WaitForChild("ResetBoardTheme"))

local ResetsModules = Modules:WaitForChild("Resets")
local ResetScheme = require(ResetsModules:WaitForChild("ResetScheme"))
local ResetMath   = require(ResetsModules:WaitForChild("ResetMath"))
local ResetState  = require(ResetsModules:WaitForChild("ResetState"))

local LocalPlayer = Players.LocalPlayer

local ZERO = BigNumber.new(0, 0)

local ResetBoardUI = {}

--== Helpers ==---------------------------------------------------------

local function corner(instance: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = instance
end

-- Border, not Contextual. On a TextButton, Contextual outlines the
-- LETTERS rather than the shape.
local function borderStroke(instance: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local uiStroke = Instance.new("UIStroke")
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Color = color
	uiStroke.Thickness = thickness
	uiStroke.Transparency = transparency or 0
	uiStroke.LineJoinMode = Enum.LineJoinMode.Round
	uiStroke.Parent = instance
	return uiStroke
end

local function textStroke(label: Instance, color: Color3, thickness: number): UIStroke
	local uiStroke = Instance.new("UIStroke")
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	uiStroke.Color = color
	uiStroke.Thickness = thickness
	uiStroke.LineJoinMode = Enum.LineJoinMode.Round
	uiStroke.Parent = label
	return uiStroke
end

local function scaledLabel(size: UDim2, maxSize: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Size                   = size
	label.BackgroundTransparency = 1
	label.Font                   = font
	label.TextColor3             = color
	label.TextScaled             = true
	label.Text                   = ""

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.MinTextSize = 8
	constraint.Parent = label

	return label
end

--== Mount ==-----------------------------------------------------------

function ResetBoardUI.Mount(boardPart: BasePart)
	local resetId = boardPart:GetAttribute("ResetId")
	if type(resetId) ~= "string" then
		warn(`ResetBoardUI: {boardPart:GetFullName()} has no ResetId attribute — nothing to show.`)
		return
	end

	local entry = ResetScheme.Get(resetId)
	if not entry then
		warn(`ResetBoardUI: ResetScheme has no entry '{resetId}'.`)
		return
	end

	-- Fixed for the life of the board: the curve doesn't change at
	-- runtime, so this is computed once rather than every refresh.
	local requiredInput = ResetMath.GetRequiredInput(resetId)

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("SurfaceGui")
	gui.Name = "ResetBoardGui_" .. resetId
	gui.Adornee = boardPart
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	--== Panel ==-------------------------------------------------------
	local panel = Instance.new("Frame")
	panel.Name                   = "Panel"
	panel.Size                   = UDim2.fromScale(1, 1)
	panel.BackgroundColor3       = Theme.Panel.Color
	panel.BackgroundTransparency = Theme.Panel.Transparency
	panel.BorderSizePixel        = 0
	panel.Parent                 = gui
	corner(panel, Theme.Panel.Corner)
	borderStroke(panel, Theme.Panel.BorderColor, Theme.Panel.BorderThickness)

	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingTop    = UDim.new(0, Theme.Panel.Padding)
	panelPadding.PaddingBottom = UDim.new(0, Theme.Panel.Padding)
	panelPadding.PaddingLeft   = UDim.new(0, Theme.Panel.Padding)
	panelPadding.PaddingRight  = UDim.new(0, Theme.Panel.Padding)
	panelPadding.Parent        = panel

	local panelLayout = Instance.new("UIListLayout")
	panelLayout.SortOrder           = Enum.SortOrder.LayoutOrder
	panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	panelLayout.Padding             = UDim.new(0, Theme.Panel.Spacing)
	panelLayout.Parent              = panel

	--== Title ==-------------------------------------------------------
	local titleHolder = Instance.new("Frame")
	titleHolder.Name                   = "Title"
	titleHolder.LayoutOrder            = 1
	titleHolder.Size                   = UDim2.new(1, 0, 0, Theme.Title.Height)
	titleHolder.BackgroundTransparency = 1
	titleHolder.Parent                 = panel

	local titleLabel = scaledLabel(UDim2.fromScale(1, 1), Theme.Title.TextSize, Theme.Title.Color, Theme.Title.Font)
	titleLabel.Name = "TitleLabel"
	titleLabel.Text = string.upper(entry.BoardTitle or entry.Name)
	titleLabel.Parent = titleHolder
	textStroke(titleLabel, Theme.Title.StrokeColor, Theme.Title.StrokeThickness)
	CurrencyArt.Bind(entry.OutputCurrency, { Labels = { titleLabel } })

	local titleRule = Instance.new("Frame")
	titleRule.Name                   = "Rule"
	titleRule.AnchorPoint            = Vector2.new(0.5, 1)
	titleRule.Position               = UDim2.fromScale(0.5, 1)
	titleRule.Size                   = UDim2.new(Theme.Title.RuleWidthScale, 0, 0, Theme.Title.RuleThickness)
	titleRule.BackgroundColor3       = Theme.Title.RuleColor
	titleRule.BackgroundTransparency = Theme.Title.RuleTransparency
	titleRule.BorderSizePixel        = 0
	titleRule.Parent                 = titleHolder
	corner(titleRule, Theme.Title.RuleThickness)

	--== Icon ==--------------------------------------------------------
	local iconHolder = Instance.new("Frame")
	iconHolder.Name                   = "IconHolder"
	iconHolder.LayoutOrder            = 2
	iconHolder.Size                   = UDim2.new(1, 0, 0, 0)
	iconHolder.BackgroundTransparency = 1
	iconHolder.Parent                 = panel

	local iconFlex = Instance.new("UIFlexItem")
	iconFlex.FlexMode = Enum.UIFlexMode.Fill
	iconFlex.Parent = iconHolder

	local icon = Instance.new("ImageLabel")
	icon.Name                   = "Icon"
	icon.AnchorPoint            = Vector2.new(0.5, 0.5)
	icon.Position               = UDim2.fromScale(0.5, 0.5)
	icon.Size                   = UDim2.fromScale(Theme.Icon.Scale, Theme.Icon.Scale)
	icon.BackgroundTransparency = 1
	icon.ScaleType              = Enum.ScaleType.Fit
	icon.Parent                 = iconHolder

	local iconRatio = Instance.new("UIAspectRatioConstraint")
	iconRatio.AspectRatio = 1
	iconRatio.DominantAxis = Enum.DominantAxis.Height
	iconRatio.Parent = icon

	CurrencyArt.Bind(entry.OutputCurrency, { Icons = { icon } })

	--== Progress ==----------------------------------------------------
	-- Input currency's colours, because it's counting the thing you're
	-- spending, not the thing you're getting.
	local progressLabel = scaledLabel(
		UDim2.new(1, 0, 0, Theme.Status.Height),
		Theme.Status.MaxTextSize, Theme.Status.Color, Theme.Status.Font
	)
	progressLabel.Name = "Progress"
	progressLabel.LayoutOrder = 3
	progressLabel.Parent = panel
	textStroke(progressLabel, Theme.Status.StrokeColor, Theme.Status.StrokeThickness)
	CurrencyArt.Bind(entry.InputCurrency, { Labels = { progressLabel } })

	--== Payout ==------------------------------------------------------
	local payoutLabel = scaledLabel(
		UDim2.new(1, 0, 0, Theme.Payout.Height),
		Theme.Payout.MaxTextSize, Theme.Payout.Color, Theme.Payout.Font
	)
	payoutLabel.Name = "Payout"
	payoutLabel.LayoutOrder = 4
	payoutLabel.Parent = panel
	textStroke(payoutLabel, Theme.Payout.StrokeColor, Theme.Payout.StrokeThickness)
	-- Always the OUTPUT currency's colours, affordable or not — it's what
	-- you'd get, and that reads clearer than recolouring it and making
	-- the player work out which number changed.
	CurrencyArt.Bind(entry.OutputCurrency, { Labels = { payoutLabel } })

	--== Button ==------------------------------------------------------
	local button = Instance.new("TextButton")
	button.Name             = "ResetButton"
	button.LayoutOrder      = 5
	button.Size             = UDim2.new(1, 0, 0, Theme.Button.Height)
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.BorderSizePixel  = 0
	button.AutoButtonColor  = false
	button.Font             = Theme.Button.Font
	button.TextScaled       = true
	button.Text             = Theme.Button.CannotAffordLabel
	button.Parent           = panel
	corner(button, Theme.Button.Corner)

	local buttonTextConstraint = Instance.new("UITextSizeConstraint")
	buttonTextConstraint.MaxTextSize = Theme.Button.MaxTextSize
	buttonTextConstraint.MinTextSize = 8
	buttonTextConstraint.Parent = button

	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingTop    = UDim.new(0, 8)
	buttonPadding.PaddingBottom = UDim.new(0, 8)
	buttonPadding.PaddingLeft   = UDim.new(0, 10)
	buttonPadding.PaddingRight  = UDim.new(0, 10)
	buttonPadding.Parent        = button

	local buttonGradient = Instance.new("UIGradient")
	buttonGradient.Rotation = 90
	buttonGradient.Parent = button

	local buttonBorder = borderStroke(button, Theme.Button.States.CannotAfford.Border, Theme.Button.StrokeThickness)
	local buttonTextStroke = textStroke(button, Theme.Button.States.CannotAfford.TextStroke, Theme.Button.TextStrokeThickness)

	local canAfford = false

	--== Refresh ==-----------------------------------------------------

	local function refresh()
		local balance = CurrencyStatsState.Balances[entry.InputCurrency] or ZERO
		local payout = ResetMath.GetPayout(resetId, balance)
		canAfford = ResetMath.CanReset(resetId, balance)

		local notation = SettingsState.Get("General.NumberNotation")

		progressLabel.Text = ("%s / %s"):format(
			BigNumber.Format(balance, notation),
			BigNumber.Format(requiredInput, notation)
		)
		payoutLabel.Text = ("+%s %s"):format(BigNumber.Format(payout, notation), entry.OutputCurrency)

		local style = canAfford and Theme.Button.States.CanAfford or Theme.Button.States.CannotAfford
		button.Text = canAfford and Theme.Button.AffordLabel or Theme.Button.CannotAffordLabel
		buttonGradient.Color = ColorSequence.new(style.Background, style.BackgroundEnd)
		button.TextColor3 = style.Text
		buttonTextStroke.Color = style.TextStroke
		buttonBorder.Color = style.Border
	end

	button.MouseButton1Click:Connect(function()
		if canAfford then
			ResetState.Request(resetId)
		end
	end)

	CurrencyStatsState.Changed.Event:Connect(refresh)
	SettingsState.Changed:Connect(refresh)
	refresh()
end

return ResetBoardUI
