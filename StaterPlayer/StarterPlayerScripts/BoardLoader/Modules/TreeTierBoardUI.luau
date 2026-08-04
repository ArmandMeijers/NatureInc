--[[
	TreeTierBoardUI.luau

	Mounts the physical-but-local Tree Tier board: a SurfaceGui adorned to
	a world Part but parented into THIS client's PlayerGui — so the board
	looks physical and shared, while every player sees their own tier
	data on it. Mounted by BoardLoaderController for any Part with
	BoardType == "TreeTier".

	This file builds instances and nothing else. What the board should
	SAY is TreeTierPreview's job; what it should LOOK like is
	TreeTierBoardTheme's. Neither needs an Instance to be readable, and
	this file doesn't need an opinion on whether Nuts counts as unlocked.

	LAYOUT, top to bottom:
	    banner        TIER 3, on a gradient plate
	    pip track     one dot per tier, filled up to where you are
	    boost rows    top-aligned, each centred as ONE group:
	                  icon, name, current -> next
	    unlock block  what tiering up reveals, one badge per thing
	    cost + bar    cost line with a fill bar showing progress
	    button        RESET / CAN'T AFFORD / MAXED

	NOTHING HERE COUNTS TIERS. The pip track builds from
	TreeTierPreview.GetMaxTier(), which is #TreeTierConfig — append a
	tier to that config and this board grows a pip on its own.

	MULTIPLE UNLOCKS ON ONE TIER are fine: the block renders one badge per
	entry in that tier's Reveals, stacked. The badge area is a scrolling
	frame capped at Unlock.MaxHeight, because an uncapped auto-sizing
	block would grow until it squeezed the boost list (which absorbs the
	leftover height via UIFlexItem) down to nothing and then overflowed
	the panel entirely. Past the cap it scrolls instead.

	Boost rows are centred horizontally rather than name-left/value-right.
	Splitting a two-word row across the full board width left a canyon of
	dead space in the middle and made each row read as two unrelated
	things. Vertically they sit at the top, so the list grows downward as
	currencies unlock instead of shifting every row each time.

	Every boost row's name AND both values render in that currency's own
	GRAD gradient via CurrencyArt, which keeps them bound — re-tinting
	LeafsGRAD in Studio updates the board without a rejoin.

	Location: StarterPlayer/StarterPlayerScripts/BoardLoader/Modules/TreeTierBoardUI.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local TreeTierState = require(ReplicatedStorage.Modules.TreeTierState)
local TreeTierPreview = require(ReplicatedStorage.Modules.TreeTierPreview)
local SettingsState = require(ReplicatedStorage.Modules.SettingsState)
local LiveBind = require(ReplicatedStorage.Modules.UI.LiveBind)
local CurrencyArt = require(ReplicatedStorage.Modules.UI.CurrencyArt)
local BoardThemes = require(ReplicatedStorage.Modules.UI.TreeTierBoardTheme)

local LocalPlayer = Players.LocalPlayer

local DEFAULT_STYLE = "Glass"
local ARROW = "→"

local TreeTierBoardUI = {}

--== Small builders ==--------------------------------------------------

local function addStroke(label: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	return stroke
end

local function corner(instance: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = instance
end

-- A text label that hugs its own text on X, for use inside a centred
-- horizontal list. TextScaled can't be used here: it needs a fixed box,
-- and a fixed box is exactly what stops rows being centred.
local function autoLabel(text: string, size: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	return label
end

function TreeTierBoardUI.Mount(boardPart: BasePart)
	local styleName = boardPart:GetAttribute("BoardStyle")
	local theme = (styleName and BoardThemes[styleName]) or BoardThemes[DEFAULT_STYLE]

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("SurfaceGui")
	gui.Name = "TreeTierGui"
	gui.Adornee = boardPart
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	--== Panel ==-------------------------------------------------------
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = theme.Panel.Color
	panel.BackgroundTransparency = theme.Panel.Transparency
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, theme.Panel.Corner)

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = theme.Panel.StrokeColor
	panelStroke.Transparency = theme.Panel.StrokeTransparency
	panelStroke.Thickness = theme.Panel.StrokeThickness
	panelStroke.Parent = panel

	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingTop = UDim.new(0, theme.Panel.Padding)
	panelPadding.PaddingBottom = UDim.new(0, theme.Panel.Padding)
	panelPadding.PaddingLeft = UDim.new(0, theme.Panel.Padding)
	panelPadding.PaddingRight = UDim.new(0, theme.Panel.Padding)
	panelPadding.Parent = panel

	local panelLayout = Instance.new("UIListLayout")
	panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	panelLayout.Padding = UDim.new(0, theme.Panel.Spacing)
	panelLayout.Parent = panel

	--== Header banner ==------------------------------------------------
	local banner = Instance.new("Frame")
	banner.Name = "HeaderBanner"
	banner.LayoutOrder = 1
	banner.Size = UDim2.new(1, 0, 0, theme.Header.Height)
	banner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	banner.BackgroundTransparency = theme.Header.Transparency
	banner.BorderSizePixel = 0
	banner.Parent = panel
	corner(banner, theme.Header.Corner)

	local bannerGradient = Instance.new("UIGradient")
	bannerGradient.Rotation = 90
	bannerGradient.Color = ColorSequence.new(theme.Header.GradientTop, theme.Header.GradientBottom)
	bannerGradient.Parent = banner

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = theme.Header.StrokeColor
	bannerStroke.Thickness = theme.Header.StrokeThickness
	bannerStroke.Parent = banner

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Name = "TierLabel"
	tierLabel.Size = UDim2.fromScale(1, 1)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Font = Enum.Font.FredokaOne
	tierLabel.TextScaled = true
	tierLabel.TextColor3 = theme.Header.TextColor
	tierLabel.Text = "TIER 1"
	tierLabel.Parent = banner
	addStroke(tierLabel, theme.Header.TextStroke, theme.Header.TextStrokeThickness)

	local tierLabelPadding = Instance.new("UIPadding")
	tierLabelPadding.PaddingTop = UDim.new(0, 6)
	tierLabelPadding.PaddingBottom = UDim.new(0, 6)
	tierLabelPadding.Parent = tierLabel

	--== Pip track ==----------------------------------------------------
	-- One dot per tier, so the header answers "how far along am I" and
	-- not just "what number am I on". Built from #TreeTierConfig, so
	-- appending a tier to the config grows the track on its own.
	local pipTrack = Instance.new("Frame")
	pipTrack.Name = "PipTrack"
	pipTrack.LayoutOrder = 2
	pipTrack.Size = UDim2.new(1, 0, 0, theme.Pips.Height)
	pipTrack.BackgroundTransparency = 1
	pipTrack.Parent = panel

	local pipLayout = Instance.new("UIListLayout")
	pipLayout.FillDirection = Enum.FillDirection.Horizontal
	pipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pipLayout.Padding = UDim.new(0, theme.Pips.Gap)
	pipLayout.Parent = pipTrack

	local pips: { Frame } = {}
	for index = 1, TreeTierPreview.GetMaxTier() do
		local pip = Instance.new("Frame")
		pip.Name = "Pip" .. index
		pip.LayoutOrder = index
		pip.Size = UDim2.fromOffset(theme.Pips.Size, theme.Pips.Size)
		pip.BorderSizePixel = 0
		pip.BackgroundColor3 = theme.Pips.Todo
		pip.BackgroundTransparency = theme.Pips.TodoTransparency
		pip.Parent = pipTrack
		corner(pip, theme.Pips.Size)
		pips[index] = pip
	end

	local function paintPips(tier: number)
		for index, pip in pips do
			if index < tier then
				pip.BackgroundColor3 = theme.Pips.Done
				pip.BackgroundTransparency = 0
				pip.Size = UDim2.fromOffset(theme.Pips.Size, theme.Pips.Size)
			elseif index == tier then
				pip.BackgroundColor3 = theme.Pips.Current
				pip.BackgroundTransparency = 0
				pip.Size = UDim2.fromOffset(theme.Pips.Size + 4, theme.Pips.Size + 4)
			else
				pip.BackgroundColor3 = theme.Pips.Todo
				pip.BackgroundTransparency = theme.Pips.TodoTransparency
				pip.Size = UDim2.fromOffset(theme.Pips.Size, theme.Pips.Size)
			end
		end
	end

	--== Divider ==------------------------------------------------------
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.LayoutOrder = 3
	divider.Size = UDim2.new(1, 0, 0, 2)
	divider.BackgroundColor3 = theme.Divider.Color
	divider.BackgroundTransparency = theme.Divider.Transparency
	divider.BorderSizePixel = 0
	divider.Parent = panel

	--== Boost list ==---------------------------------------------------
	local boostList = Instance.new("ScrollingFrame")
	boostList.Name = "BoostList"
	boostList.LayoutOrder = 4
	boostList.Size = UDim2.new(1, 0, 0, 0)
	boostList.BackgroundTransparency = 1
	boostList.BorderSizePixel = 0
	boostList.ScrollBarThickness = 4
	boostList.ScrollBarImageColor3 = theme.Divider.Color
	boostList.ScrollBarImageTransparency = 0.4
	boostList.ScrollingDirection = Enum.ScrollingDirection.Y
	boostList.VerticalScrollBarInset = Enum.ScrollBarInset.None
	boostList.CanvasSize = UDim2.new()
	boostList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	boostList.Parent = panel

	-- Takes whatever vertical space is left after the fixed blocks, so
	-- the unlock section can be any height (up to its own cap) without
	-- anything overlapping.
	local boostFlex = Instance.new("UIFlexItem")
	boostFlex.FlexMode = Enum.UIFlexMode.Fill
	boostFlex.Parent = boostList

	local boostLayout = Instance.new("UIListLayout")
	boostLayout.SortOrder = Enum.SortOrder.LayoutOrder
	boostLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	boostLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	boostLayout.Padding = UDim.new(0, 4)
	boostLayout.Parent = boostList

	--== Unlock block ==-------------------------------------------------
	local unlockBlock = Instance.new("Frame")
	unlockBlock.Name = "UnlockBlock"
	unlockBlock.LayoutOrder = 5
	unlockBlock.Size = UDim2.new(1, 0, 0, 0)
	unlockBlock.AutomaticSize = Enum.AutomaticSize.Y
	unlockBlock.BackgroundTransparency = 1
	unlockBlock.Visible = false
	unlockBlock.Parent = panel

	local unlockLayout = Instance.new("UIListLayout")
	unlockLayout.SortOrder = Enum.SortOrder.LayoutOrder
	unlockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	unlockLayout.Padding = UDim.new(0, theme.Unlock.BadgeGap)
	unlockLayout.Parent = unlockBlock

	local unlockCaption = Instance.new("TextLabel")
	unlockCaption.Name = "Caption"
	unlockCaption.LayoutOrder = 1
	unlockCaption.Size = UDim2.new(1, 0, 0, theme.Unlock.CaptionSize + 4)
	unlockCaption.BackgroundTransparency = 1
	unlockCaption.Font = Enum.Font.GothamBold
	unlockCaption.TextSize = theme.Unlock.CaptionSize
	unlockCaption.TextColor3 = theme.Unlock.CaptionColor
	unlockCaption.Text = "UNLOCKS"
	unlockCaption.Parent = unlockBlock
	addStroke(unlockCaption, theme.Unlock.StrokeColor, 2)

	-- One badge per reveal, stacked. Grows with the number of unlocks up
	-- to MaxHeight, then scrolls — an uncapped block would keep eating
	-- into the flex-filled boost list until there was nothing left of it.
	local badgeList = Instance.new("ScrollingFrame")
	badgeList.Name = "BadgeList"
	badgeList.LayoutOrder = 2
	badgeList.Size = UDim2.new(1, 0, 0, 0)
	badgeList.AutomaticSize = Enum.AutomaticSize.Y
	badgeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	badgeList.CanvasSize = UDim2.new()
	badgeList.BackgroundTransparency = 1
	badgeList.BorderSizePixel = 0
	badgeList.ScrollBarThickness = 3
	badgeList.ScrollBarImageColor3 = theme.Unlock.BadgeStroke
	badgeList.ScrollBarImageTransparency = 0.4
	badgeList.ScrollingDirection = Enum.ScrollingDirection.Y
	badgeList.VerticalScrollBarInset = Enum.ScrollBarInset.None
	badgeList.Parent = unlockBlock

	local badgeConstraint = Instance.new("UISizeConstraint")
	badgeConstraint.MaxSize = Vector2.new(math.huge, theme.Unlock.MaxHeight)
	badgeConstraint.Parent = badgeList

	local badgeLayout = Instance.new("UIListLayout")
	badgeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	badgeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	badgeLayout.Padding = UDim.new(0, theme.Unlock.BadgeGap)
	badgeLayout.Parent = badgeList

	--== Cost ==---------------------------------------------------------
	local costBlock = Instance.new("Frame")
	costBlock.Name = "CostBlock"
	costBlock.LayoutOrder = 6
	costBlock.Size = UDim2.new(1, 0, 0, theme.Cost.TextSize + theme.Cost.BarHeight + 12)
	costBlock.BackgroundTransparency = 1
	costBlock.Parent = panel

	local costLayout = Instance.new("UIListLayout")
	costLayout.SortOrder = Enum.SortOrder.LayoutOrder
	costLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	costLayout.Padding = UDim.new(0, 4)
	costLayout.Parent = costBlock

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.LayoutOrder = 1
	costLabel.Size = UDim2.new(1, 0, 0, theme.Cost.TextSize + 4)
	costLabel.BackgroundTransparency = 1
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = theme.Cost.TextSize
	costLabel.TextColor3 = theme.Cost.TextColor
	costLabel.Text = ""
	costLabel.Parent = costBlock
	addStroke(costLabel, theme.Cost.TextStroke, 2)

	local costBarBack = Instance.new("Frame")
	costBarBack.Name = "CostBar"
	costBarBack.LayoutOrder = 2
	costBarBack.Size = UDim2.new(1, 0, 0, theme.Cost.BarHeight)
	costBarBack.BackgroundColor3 = theme.Cost.BarBackground
	costBarBack.BackgroundTransparency = theme.Cost.BarBackgroundTransparency
	costBarBack.BorderSizePixel = 0
	costBarBack.ClipsDescendants = true
	costBarBack.Parent = costBlock
	corner(costBarBack, theme.Cost.BarHeight)

	local costBarFill = Instance.new("Frame")
	costBarFill.Name = "Fill"
	costBarFill.Size = UDim2.fromScale(0, 1)
	costBarFill.BackgroundColor3 = theme.Button.States.CannotAfford.Bar
	costBarFill.BorderSizePixel = 0
	costBarFill.Parent = costBarBack
	corner(costBarFill, theme.Cost.BarHeight)

	--== Button ==-------------------------------------------------------
	local button = Instance.new("TextButton")
	button.Name = "TierUpButton"
	button.LayoutOrder = 7
	button.Size = UDim2.new(1, 0, 0, theme.Button.Height)
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.TextSize = theme.Button.TextSize
	button.AutoButtonColor = false
	button.Active = true
	button.Text = theme.Button.Labels.CannotAfford
	button.Parent = panel
	corner(button, theme.Button.Corner)

	local buttonGradient = Instance.new("UIGradient")
	buttonGradient.Rotation = 90
	buttonGradient.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	buttonStroke.Thickness = theme.Button.StrokeThickness
	buttonStroke.Parent = button

	local buttonTextStroke = addStroke(
		button,
		theme.Button.States.CannotAfford.TextStroke,
		theme.Button.TextStrokeThickness
	)

	local buttonScale = Instance.new("UIScale")
	buttonScale.Parent = button

	local buttonState = "CannotAfford"

	-- Label, text colour, both strokes and the bar all come from one
	-- state entry, so there's no way to end up with a green fill still
	-- wearing the red state's text colour.
	local function setButtonState(state: string)
		buttonState = state

		local style = theme.Button.States[state]
		button.Text = theme.Button.Labels[state]
		buttonGradient.Color = ColorSequence.new(style.Background, style.BackgroundEnd)
		button.TextColor3 = style.Text
		buttonTextStroke.Color = style.TextStroke
		buttonStroke.Color = style.Border
		costBarFill.BackgroundColor3 = style.Bar
	end

	button.MouseEnter:Connect(function()
		TweenService:Create(buttonScale, TweenInfo.new(0.12), { Scale = theme.Button.HoverScale }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(buttonScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Click:Connect(function()
		if buttonState == "CanAfford" then
			TreeTierState.RequestTierUp()
		end
	end)

	--== Row builders ==-------------------------------------------------

	-- One centred group per boost: icon, name, current, arrow, next.
	-- Every text part is bound to the currency's gradient, including both
	-- numbers — the values are the point of the row, so they shouldn't be
	-- the only part rendering in a flat fallback colour.
	local function buildBoostRow(row, order: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = row.Currency .. "Boost"
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, 0, 0, theme.Boost.RowHeight)
		frame.BackgroundTransparency = 1

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, theme.Boost.Gap)
		layout.Parent = frame

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.LayoutOrder = 1
		icon.Size = UDim2.fromOffset(theme.Boost.IconSize, theme.Boost.IconSize)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = frame

		local nameLabel = autoLabel(row.Currency, theme.Boost.TextSize, theme.Boost.NameFallback, Enum.Font.GothamBold)
		nameLabel.Name = "Name"
		nameLabel.LayoutOrder = 2
		nameLabel.Parent = frame
		addStroke(nameLabel, theme.Boost.StrokeColor, theme.Boost.StrokeThickness)

		local currentLabel = autoLabel(row.CurrentText, theme.Boost.TextSize, theme.Boost.ValueFallback, Enum.Font.FredokaOne)
		currentLabel.Name = "Current"
		currentLabel.LayoutOrder = 3
		currentLabel.Parent = frame
		addStroke(currentLabel, theme.Boost.StrokeColor, theme.Boost.StrokeThickness)

		local gradientTargets = { nameLabel, currentLabel }

		if row.NextText then
			local arrow = autoLabel(ARROW, theme.Boost.TextSize, theme.Boost.ArrowColor, Enum.Font.GothamBold)
			arrow.Name = "Arrow"
			arrow.LayoutOrder = 4
			arrow.Parent = frame
			addStroke(arrow, theme.Boost.StrokeColor, theme.Boost.StrokeThickness)

			local nextLabel = autoLabel(
				row.NextText,
				math.floor(theme.Boost.TextSize * theme.Boost.NextScale),
				theme.Boost.ValueFallback,
				Enum.Font.FredokaOne
			)
			nextLabel.Name = "Next"
			nextLabel.LayoutOrder = 5
			nextLabel.Parent = frame
			addStroke(nextLabel, theme.Boost.StrokeColor, theme.Boost.StrokeThickness)

			table.insert(gradientTargets, nextLabel)
		end

		CurrencyArt.Bind(row.Currency, { Icons = { icon }, Labels = gradientTargets })

		return frame
	end

	-- A pill badge: "UNLOCK NUTS", with the currency's icon when the
	-- reveal names one. One of these per entry in the tier's Reveals.
	local function buildRevealBadge(reveal, order: number): Frame
		local badge = Instance.new("Frame")
		badge.Name = "Reveal" .. order
		badge.LayoutOrder = order
		badge.Size = UDim2.new(0, 0, 0, theme.Unlock.BadgeHeight)
		badge.AutomaticSize = Enum.AutomaticSize.X
		badge.BackgroundColor3 = theme.Unlock.BadgeColor
		badge.BackgroundTransparency = theme.Unlock.BadgeTransparency
		badge.BorderSizePixel = 0
		corner(badge, theme.Unlock.BadgeHeight)

		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = theme.Unlock.BadgeStroke
		badgeStroke.Thickness = 1.5
		badgeStroke.Transparency = 0.3
		badgeStroke.Parent = badge

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 12)
		padding.Parent = badge

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = badge

		if reveal.Currency then
			local icon = Instance.new("ImageLabel")
			icon.Name = "Icon"
			icon.LayoutOrder = 1
			icon.Size = UDim2.fromOffset(theme.Unlock.BadgeHeight - 8, theme.Unlock.BadgeHeight - 8)
			icon.BackgroundTransparency = 1
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Parent = badge
			CurrencyArt.Bind(reveal.Currency, { Icons = { icon } })
		end

		local label = autoLabel(
			("UNLOCK %s"):format(string.upper(reveal.Label)),
			theme.Unlock.LabelSize,
			theme.Unlock.LabelColor,
			Enum.Font.FredokaOne
		)
		label.Name = "Label"
		label.LayoutOrder = 2
		label.Parent = badge
		addStroke(label, theme.Unlock.StrokeColor, 2.5)

		return badge
	end

	--== Refresh ==------------------------------------------------------

	local function refreshBoard()
		local preview = TreeTierPreview.Build(TreeTierState.Tier)

		paintPips(preview.Tier)

		for _, child in boostList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for order, row in preview.Boosts do
			buildBoostRow(row, order).Parent = boostList
		end

		for _, child in badgeList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		unlockBlock.Visible = #preview.Reveals > 0
		for order, reveal in preview.Reveals do
			buildRevealBadge(reveal, order).Parent = badgeList
		end

		-- Cost, progress bar and button state all answer the same
		-- question — can this player afford the next tier — so they're
		-- decided together rather than from three checks that could
		-- disagree with each other.
		costBlock.Visible = not preview.IsMaxed

		if preview.IsMaxed then
			costBarFill.Size = UDim2.fromScale(1, 1)
			setButtonState("Maxed")
			return
		end

		local cost = preview.Cost
		local balance = TreeTierState.Balance
		local matchesCurrency = TreeTierState.BalanceCurrency == cost.Currency
		local canAfford = matchesCurrency and BigNumber.GreaterThanOrEqual(balance, cost.Amount)

		local ratio = 0
		if matchesCurrency and not BigNumber.IsZero(cost.Amount) then
			-- Divide in BigNumber space first: these values routinely sit
			-- past what a double can hold, so converting each side to a
			-- plain number and dividing would saturate to inf/inf.
			ratio = TreeTierPreview.GetRatio(balance, cost.Amount)
		end
		TweenService:Create(costBarFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()

		setButtonState(canAfford and "CanAfford" or "CannotAfford")
	end

	TreeTierState.TierChanged.Event:Connect(refreshBoard)
	TreeTierState.BalanceChanged.Event:Connect(refreshBoard)
	SettingsState.Changed:Connect(refreshBoard)
	refreshBoard()

	--== Single-property bindings ==-------------------------------------
	LiveBind.Bind(tierLabel, "Text", function()
		return "TIER " .. TreeTierState.Tier
	end, { TreeTierState.TierChanged.Event })

	-- Cost text also listens for SettingsState.Changed so it reformats
	-- immediately when the player flips Number Notation mid-session.
	LiveBind.Bind(costLabel, "Text", function()
		local preview = TreeTierPreview.Build(TreeTierState.Tier)
		if preview.IsMaxed then
			return ""
		end
		local notation = SettingsState.Get("General.NumberNotation")
		return ("%s / %s %s"):format(
			BigNumber.Format(TreeTierState.Balance, notation),
			BigNumber.Format(preview.Cost.Amount, notation),
			preview.Cost.Currency
		)
	end, { TreeTierState.TierChanged.Event, TreeTierState.BalanceChanged.Event, SettingsState.Changed })

	if theme.Cost.UseCurrencyGradient then
		-- Re-bound on tier change, since a later tier can cost an
		-- entirely different currency and should read in its colours.
		local costArtHandle = nil
		local function bindCostArt()
			if costArtHandle then
				costArtHandle:Disconnect()
				costArtHandle = nil
			end
			local cost = TreeTierState.GetNextCost()
			if cost then
				costArtHandle = CurrencyArt.Bind(cost.Currency, { Labels = { costLabel } })
			end
		end
		TreeTierState.TierChanged.Event:Connect(bindCostArt)
		bindCostArt()
	end
end

return TreeTierBoardUI
