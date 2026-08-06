--[[
	UpgradeBoardUI.luau

	Mounts a physical-but-local upgrade board: a SurfaceGui adorned to a
	world Part but parented into THIS client's PlayerGui, so the board
	looks shared while every player sees their own levels, costs and
	affordability. Mounted by BoardLoaderController for any Part with
	BoardType == "UpgradeBoard".

	PART ATTRIBUTES:
	    UpgradeCategory   "LeafUpgrades"   (required)
	    BoardTitle        "Leaf Upgrades"  (optional, derived if absent)
	    BoardCurrency     "Leafs"          (optional, taken from the
	                                        category's first upgrade;
	                                        only tints the title)
	The part should be Transparency = 1 — a SurfaceGui renders regardless
	of its adornee, and an opaque brick behind a translucent panel just
	makes the panel look solid.

	ONE TEXT SIZING MECHANISM FOR EVERY LABEL. Each one hugs its own text
	at the size the theme names, and a row shrinks its labels in a single
	pass only if they wouldn't fit its width.

	The alternative — TextScaled — means "fill your box", which sounds
	equivalent and isn't: the box wins. Short fixed-height rows produced
	small text no matter what the theme said, and mixing the two
	mechanisms is why one row rendered large and the rest didn't. It also
	gets centring for free, since the engine positions hug-sized labels
	in a centred layout correctly whatever their lengths.

	The fitting pass runs from the painter, never from a resize signal:
	TextSize drives TextBounds drives the calculation drives TextSize,
	which is fine one-shot and oscillates if it's event-driven.

	CARDS ARE LEFT ALIGNED, and not only as a preference: inside a
	ScrollingFrame with AutomaticCanvasSize, HorizontalAlignment.Center
	splits overflow across both sides, and the half left of canvas origin
	is unreachable by scrolling.

	Rebuilds only when the SET of visible upgrades changes; buying
	repaints in place, so the card under the cursor survives the click.

	Location: StarterPlayer/StarterPlayerScripts/BoardLoader/Modules/UpgradeBoardUI.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local BigNumber          = require(Modules:WaitForChild("BigNumber"))
local CurrencyStatsState = require(Modules:WaitForChild("CurrencyStatsState"))
local SettingsState      = require(Modules:WaitForChild("SettingsState"))
local CurrencyArt        = require(Modules:WaitForChild("UI"):WaitForChild("CurrencyArt"))
local Theme              = require(Modules:WaitForChild("UI"):WaitForChild("UpgradeBoardTheme"))

local UpgradesModules = Modules:WaitForChild("Upgrades")
local UpgradeSchema   = require(UpgradesModules:WaitForChild("UpgradeSchema"))
local UpgradeDisplay  = require(UpgradesModules:WaitForChild("UpgradeDisplay"))
local UpgradePurchase = require(UpgradesModules:WaitForChild("UpgradePurchase"))
local UpgradeState    = require(UpgradesModules:WaitForChild("UpgradeState"))

local LocalPlayer = Players.LocalPlayer

local ZERO = BigNumber.new(0, 0)
local ARROW = "→"
local MIN_TEXT_SIZE = 8

local UpgradeBoardUI = {}

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

-- Every card label is built this way: a real TextSize, a box that hugs
-- the text. Never TextScaled — see the module header.
local function hugLabel(textSize: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.AutomaticSize          = Enum.AutomaticSize.X
	label.Size                   = UDim2.new(0, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font                   = font
	label.TextSize               = textSize
	label.TextColor3             = color
	label.TextWrapped            = false
	label.Text                   = ""
	return label
end

-- A row of hug-sized labels, centred, with a gap between them.
local function makeRow(parent: Instance, layoutOrder: number, height: number, gap: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder            = layoutOrder
	row.Size                   = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.ZIndex                 = 3
	row.Parent                 = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection       = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment   = Enum.VerticalAlignment.Center
	layout.SortOrder           = Enum.SortOrder.LayoutOrder
	layout.Padding             = UDim.new(0, gap)
	layout.Parent              = row

	return row
end

-- Shrinks a group of labels until they fit their row. Only shrinks:
-- a row with room to spare keeps the theme's size rather than growing
-- into the gap, so sizes stay consistent across cards.
local function fitLabels(rowWidth: number, labels: { TextLabel }, gap: number, baseSize: number)
	local visible = {}
	for _, label in labels do
		if label.Visible then
			table.insert(visible, label)
		end
	end
	for _, label in visible do
		label.TextSize = baseSize
	end
	if rowWidth <= 0 or #visible == 0 then
		return
	end

	local total = gap * math.max(#visible - 1, 0)
	for _, label in visible do
		total += label.TextBounds.X
	end

	if total > rowWidth and total > 0 then
		local scaled = math.max(MIN_TEXT_SIZE, math.floor(baseSize * rowWidth / total))
		for _, label in visible do
			label.TextSize = scaled
		end
	end
end

-- ReplicatedStorage.UpgradeIcons.<Category>.<UpgradeId>. Accepts a Decal,
-- an ImageLabel or a StringValue holding the id.
local function findIcon(entry, upgradeId: string): string?
	local root = ReplicatedStorage:FindFirstChild("UpgradeIcons")
	local categoryFolder = root and root:FindFirstChild(entry.Category)
	local source = categoryFolder and categoryFolder:FindFirstChild(upgradeId)
	if not source then
		return nil
	end
	if source:IsA("Decal") or source:IsA("Texture") then
		return source.Texture ~= "" and source.Texture or nil
	elseif source:IsA("ImageLabel") or source:IsA("ImageButton") then
		return source.Image ~= "" and source.Image or nil
	elseif source:IsA("StringValue") then
		return source.Value ~= "" and source.Value or nil
	end
	return nil
end

--== Mount ==-----------------------------------------------------------

function UpgradeBoardUI.Mount(boardPart: BasePart)
	local category = boardPart:GetAttribute("UpgradeCategory")
	if type(category) ~= "string" then
		warn(`UpgradeBoardUI: {boardPart:GetFullName()} has no UpgradeCategory attribute — nothing to show.`)
		return
	end

	local titleText = boardPart:GetAttribute("BoardTitle")
	if type(titleText) ~= "string" then
		titleText = (category:gsub("(%l)(%u)", "%1 %2"))
	end

	local boardCurrency = boardPart:GetAttribute("BoardCurrency")
	if type(boardCurrency) ~= "string" then
		local firstId = UpgradeSchema.GetCategoryOrder(category)[1]
		local firstEntry = firstId and UpgradeSchema.Get(firstId)
		boardCurrency = firstEntry and firstEntry.Currency or nil
	end

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("SurfaceGui")
	gui.Name = "UpgradeBoardGui_" .. category
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
	borderStroke(panel, Theme.Panel.BorderColor, Theme.Panel.BorderThickness, Theme.Panel.BorderTransparency)

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

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name                   = "TitleLabel"
	titleLabel.Size                   = UDim2.fromScale(1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font                   = Theme.Title.Font
	titleLabel.TextSize               = Theme.Title.TextSize
	titleLabel.TextColor3             = Theme.Title.Color
	titleLabel.TextWrapped            = false
	titleLabel.Text                   = string.upper(titleText)
	titleLabel.Parent                 = titleHolder
	textStroke(titleLabel, Theme.Title.StrokeColor, Theme.Title.StrokeThickness)

	if boardCurrency then
		CurrencyArt.Bind(boardCurrency, { Labels = { titleLabel } })
	end

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

	--== Card strip ==--------------------------------------------------
	local strip = Instance.new("ScrollingFrame")
	strip.Name                       = "Cards"
	strip.LayoutOrder                = 2
	strip.Size                       = UDim2.new(1, 0, 0, 0)
	strip.BackgroundTransparency     = 1
	strip.BorderSizePixel            = 0
	strip.ScrollingDirection         = Enum.ScrollingDirection.X
	strip.ScrollBarThickness         = Theme.ScrollBar.Thickness
	strip.ScrollBarImageColor3       = Theme.ScrollBar.HandleColor
	strip.ScrollBarImageTransparency = Theme.ScrollBar.Transparency
	strip.CanvasSize                 = UDim2.new()
	strip.AutomaticCanvasSize        = Enum.AutomaticSize.X
	strip.Parent                     = panel

	local stripFlex = Instance.new("UIFlexItem")
	stripFlex.FlexMode = Enum.UIFlexMode.Fill
	stripFlex.Parent = strip

	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection       = Enum.FillDirection.Horizontal
	stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	stripLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
	stripLayout.SortOrder           = Enum.SortOrder.LayoutOrder
	stripLayout.Padding             = UDim.new(0, Theme.Card.Gap)
	stripLayout.Parent              = strip

	-- A UIStroke draws OUTSIDE its frame and a ScrollingFrame clips
	-- descendants, so without this the cards' black borders get sliced
	-- off flush against the strip's edges.
	local stripPadding = Instance.new("UIPadding")
	stripPadding.PaddingTop    = UDim.new(0, Theme.Card.EdgePadding)
	stripPadding.PaddingBottom = UDim.new(0, Theme.Card.EdgePadding)
	stripPadding.PaddingLeft   = UDim.new(0, Theme.Card.EdgePadding)
	stripPadding.PaddingRight  = UDim.new(0, Theme.Card.EdgePadding)
	stripPadding.Parent        = strip

	--== Card construction ==-------------------------------------------

	local cards: { [string]: any } = {}

	local function cardWidth(): number
		local height = strip.AbsoluteSize.Y - Theme.Card.ShadowOffset - Theme.Card.EdgePadding * 2
		if height <= 0 then
			return Theme.Card.MinWidth
		end
		return math.clamp(
			math.floor(height * Theme.Card.AspectRatio),
			Theme.Card.MinWidth,
			Theme.Card.MaxWidth
		)
	end

	local function buildButton(parent: Instance, label: string, order: number): (TextButton, (string) -> ())
		local button = Instance.new("TextButton")
		button.Name             = label
		button.LayoutOrder      = order
		button.Size             = UDim2.new(0.5, -Theme.Button.Gap / 2, 1, 0)
		button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		button.BorderSizePixel  = 0
		button.AutoButtonColor  = false
		button.Font             = Theme.Button.Font
		button.TextSize         = Theme.Button.TextSize
		button.TextWrapped      = false
		button.Text             = label
		button.ZIndex           = 4
		button.Parent           = parent
		corner(button, Theme.Button.Corner)

		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Parent = button

		local border = borderStroke(button, Theme.Button.States.Maxed.Border, Theme.Button.StrokeThickness)
		local stroke = textStroke(button, Theme.Button.States.Maxed.TextStroke, Theme.Button.TextStrokeThickness)

		return button, function(state: string)
			local style = Theme.Button.States[state]
			gradient.Color = ColorSequence.new(style.Background, style.BackgroundEnd)
			button.TextColor3 = style.Text
			stroke.Color = style.TextStroke
			border.Color = style.Border
		end
	end

	local function buildCard(upgradeId: string, order: number)
		local entry = UpgradeSchema.Get(upgradeId)
		if not entry then
			return nil
		end

		local holder = Instance.new("Frame")
		holder.Name                   = upgradeId
		holder.LayoutOrder            = order
		holder.Size                   = UDim2.new(0, cardWidth(), 1, -Theme.Card.ShadowOffset)
		holder.BackgroundTransparency = 1
		holder.Parent                 = strip

		local shadow = Instance.new("Frame")
		shadow.Name                   = "Shadow"
		shadow.Position               = UDim2.fromOffset(0, Theme.Card.ShadowOffset)
		shadow.Size                   = UDim2.fromScale(1, 1)
		shadow.BackgroundColor3       = Theme.Card.ShadowColor
		shadow.BackgroundTransparency = Theme.Card.ShadowTransparency
		shadow.BorderSizePixel        = 0
		shadow.Parent                 = holder
		corner(shadow, Theme.Card.Corner)

		local card = Instance.new("Frame")
		card.Name                   = "Card"
		card.Size                   = UDim2.fromScale(1, 1)
		card.BackgroundColor3       = Theme.Card.Color
		card.BackgroundTransparency = Theme.Card.Transparency
		card.BorderSizePixel        = 0
		card.ZIndex                 = 2
		card.Parent                 = holder
		corner(card, Theme.Card.Corner)
		borderStroke(card, Theme.Card.BorderColor, Theme.Card.BorderThickness, Theme.Card.BorderTransparency)

		local cardPadding = Instance.new("UIPadding")
		cardPadding.PaddingTop    = UDim.new(0, Theme.Card.Padding)
		cardPadding.PaddingBottom = UDim.new(0, Theme.Card.Padding)
		cardPadding.PaddingLeft   = UDim.new(0, Theme.Card.Padding)
		cardPadding.PaddingRight  = UDim.new(0, Theme.Card.Padding)
		cardPadding.Parent        = card

		local cardLayout = Instance.new("UIListLayout")
		cardLayout.SortOrder           = Enum.SortOrder.LayoutOrder
		cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		cardLayout.Padding             = UDim.new(0, Theme.Card.Spacing)
		cardLayout.Parent              = card

		-- 1. Name
		local nameRow = makeRow(card, 1, Theme.Name.Height, 0)
		nameRow.Name = "NameRow"
		local nameLabel = hugLabel(Theme.Name.TextSize, Theme.Name.Color, Theme.Name.Font)
		nameLabel.Name = "Name"
		nameLabel.Text = entry.Name
		nameLabel.ZIndex = 3
		nameLabel.Parent = nameRow
		textStroke(nameLabel, Theme.Name.StrokeColor, Theme.Name.StrokeThickness)

		-- 2. Level
		local levelRow = makeRow(card, 2, Theme.Level.Height, 0)
		levelRow.Name = "LevelRow"
		local levelLabel = hugLabel(Theme.Level.TextSize, Theme.Level.Color, Theme.Level.Font)
		levelLabel.Name = "Level"
		levelLabel.ZIndex = 3
		levelLabel.Parent = levelRow
		textStroke(levelLabel, Theme.Level.StrokeColor, Theme.Level.StrokeThickness)

		-- 3. Icon: flex-fills the leftover height and stays square, so a
		-- taller card gets a bigger icon rather than more whitespace.
		local iconHolder = Instance.new("Frame")
		iconHolder.Name                   = "IconHolder"
		iconHolder.LayoutOrder            = 3
		iconHolder.Size                   = UDim2.new(1, 0, 0, 0)
		iconHolder.BackgroundTransparency = 1
		iconHolder.ZIndex                 = 3
		iconHolder.Parent                 = card

		local iconFlex = Instance.new("UIFlexItem")
		iconFlex.FlexMode = Enum.UIFlexMode.Fill
		iconFlex.Parent = iconHolder

		local iconFrame = Instance.new("Frame")
		iconFrame.Name                   = "IconFrame"
		iconFrame.AnchorPoint            = Vector2.new(0.5, 0.5)
		iconFrame.Position               = UDim2.fromScale(0.5, 0.5)
		iconFrame.Size                   = UDim2.fromScale(Theme.Icon.Scale, Theme.Icon.Scale)
		iconFrame.BackgroundTransparency = 1
		iconFrame.ZIndex                 = 3
		iconFrame.Parent                 = iconHolder

		local iconRatio = Instance.new("UIAspectRatioConstraint")
		iconRatio.AspectRatio = 1
		iconRatio.DominantAxis = Enum.DominantAxis.Height
		iconRatio.Parent = iconFrame

		local iconImage = findIcon(entry, upgradeId)
		if iconImage then
			local icon = Instance.new("ImageLabel")
			icon.Name                   = "Icon"
			icon.Size                   = UDim2.fromScale(1, 1)
			icon.BackgroundTransparency = 1
			icon.ScaleType              = Enum.ScaleType.Fit
			icon.Image                  = iconImage
			icon.ZIndex                 = 3
			icon.Parent                 = iconFrame
		else
			local placeholder = Instance.new("Frame")
			placeholder.Name                   = "Placeholder"
			placeholder.Size                   = UDim2.fromScale(1, 1)
			placeholder.BackgroundColor3       = Theme.Icon.PlaceholderColor
			placeholder.BackgroundTransparency = Theme.Icon.PlaceholderTransparency
			placeholder.BorderSizePixel        = 0
			placeholder.ZIndex                 = 3
			placeholder.Parent                 = iconFrame
			corner(placeholder, Theme.Icon.PlaceholderCorner)

			local glyph = Instance.new("TextLabel")
			glyph.Size                   = UDim2.fromScale(0.7, 0.7)
			glyph.AnchorPoint            = Vector2.new(0.5, 0.5)
			glyph.Position               = UDim2.fromScale(0.5, 0.5)
			glyph.BackgroundTransparency = 1
			glyph.Font                   = Enum.Font.GothamBold
			glyph.TextScaled             = true
			glyph.TextWrapped            = false
			glyph.TextColor3             = Theme.Icon.PlaceholderTextColor
			glyph.Text                   = Theme.Icon.PlaceholderGlyph
			glyph.ZIndex                 = 4
			glyph.Parent                 = placeholder
			textStroke(glyph, Theme.Name.StrokeColor, 2)
		end

		-- 4. Boost transition
		local valueRow = makeRow(card, 4, Theme.Value.Height, Theme.Value.Gap)
		valueRow.Name = "Value"

		local currentValue = hugLabel(Theme.Value.TextSize, Theme.Value.Color, Theme.Value.Font)
		currentValue.Name = "Current"
		currentValue.LayoutOrder = 1
		currentValue.ZIndex = 3
		currentValue.Parent = valueRow
		textStroke(currentValue, Theme.Value.StrokeColor, Theme.Value.StrokeThickness)

		local arrow = hugLabel(Theme.Value.TextSize, Theme.Value.ArrowColor, Enum.Font.GothamBold)
		arrow.Name = "Arrow"
		arrow.LayoutOrder = 2
		arrow.Text = ARROW
		arrow.TextTransparency = Theme.Value.ArrowTransparency
		arrow.ZIndex = 3
		arrow.Parent = valueRow
		textStroke(arrow, Theme.Value.StrokeColor, Theme.Value.StrokeThickness)

		local nextValue = hugLabel(Theme.Value.TextSize, Theme.Value.Color, Theme.Value.Font)
		nextValue.Name = "Next"
		nextValue.LayoutOrder = 3
		nextValue.ZIndex = 3
		nextValue.Parent = valueRow
		textStroke(nextValue, Theme.Value.StrokeColor, Theme.Value.StrokeThickness)

		-- 5. Cost
		local costRow = makeRow(card, 5, Theme.Cost.Height, Theme.Cost.Gap)
		costRow.Name = "Cost"

		local costAmount = hugLabel(Theme.Cost.TextSize, Theme.Cost.AmountColor, Theme.Cost.Font)
		costAmount.Name = "Amount"
		costAmount.LayoutOrder = 1
		costAmount.ZIndex = 3
		costAmount.Parent = costRow
		textStroke(costAmount, Theme.Cost.StrokeColor, Theme.Cost.StrokeThickness)

		local costCurrency = hugLabel(Theme.Cost.TextSize, Theme.Cost.CurrencyColor, Theme.Cost.Font)
		costCurrency.Name = "Currency"
		costCurrency.LayoutOrder = 2
		costCurrency.ZIndex = 3
		costCurrency.Parent = costRow
		textStroke(costCurrency, Theme.Cost.StrokeColor, Theme.Cost.StrokeThickness)
		CurrencyArt.Bind(entry.Currency, { Labels = { costCurrency } })

		-- 6. Buttons
		local buttonRow = Instance.new("Frame")
		buttonRow.Name                   = "Buttons"
		buttonRow.LayoutOrder            = 6
		buttonRow.Size                   = UDim2.new(1, 0, 0, Theme.Button.Height)
		buttonRow.BackgroundTransparency = 1
		buttonRow.ZIndex                 = 3
		buttonRow.Parent                 = card

		local buttonLayout = Instance.new("UIListLayout")
		buttonLayout.FillDirection       = Enum.FillDirection.Horizontal
		buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		buttonLayout.SortOrder           = Enum.SortOrder.LayoutOrder
		buttonLayout.Padding             = UDim.new(0, Theme.Button.Gap)
		buttonLayout.Parent              = buttonRow

		local buyButton, paintBuy = buildButton(buttonRow, Theme.Button.BuyLabel, 1)
		local maxButton, paintMax = buildButton(buttonRow, Theme.Button.MaxLabel, 2)

		local record = {
			UpgradeId    = upgradeId,
			Entry        = entry,
			Holder       = holder,
			Card         = card,
			NameRow      = nameRow,
			NameLabel    = nameLabel,
			LevelRow     = levelRow,
			LevelLabel   = levelLabel,
			ValueRow     = valueRow,
			CurrentValue = currentValue,
			Arrow        = arrow,
			NextValue    = nextValue,
			CostRow      = costRow,
			CostAmount   = costAmount,
			CostCurrency = costCurrency,
			BuyButton    = buyButton,
			MaxButton    = maxButton,
			PaintBuy     = paintBuy,
			PaintMax     = paintMax,
			HoveringMax  = false,
		}

		buyButton.MouseButton1Click:Connect(function()
			UpgradeState.RequestPurchase(upgradeId)
		end)
		maxButton.MouseButton1Click:Connect(function()
			UpgradeState.RequestMaxPurchase(upgradeId)
		end)

		-- The "20x" preview exists only while hovering, so the button
		-- reads MAX at rest and tells you what MAX means when you're
		-- about to press it.
		maxButton.MouseEnter:Connect(function()
			record.HoveringMax = true
			UpgradeBoardUI._paintCard(record)
		end)
		maxButton.MouseLeave:Connect(function()
			record.HoveringMax = false
			UpgradeBoardUI._paintCard(record)
		end)

		return record
	end

	--== Fitting ==-----------------------------------------------------

	function UpgradeBoardUI._fitCard(record)
		fitLabels(record.NameRow.AbsoluteSize.X, { record.NameLabel }, 0, Theme.Name.TextSize)
		fitLabels(record.LevelRow.AbsoluteSize.X, { record.LevelLabel }, 0, Theme.Level.TextSize)
		fitLabels(
			record.ValueRow.AbsoluteSize.X,
			{ record.CurrentValue, record.Arrow, record.NextValue },
			Theme.Value.Gap,
			Theme.Value.TextSize
		)
		fitLabels(
			record.CostRow.AbsoluteSize.X,
			{ record.CostAmount, record.CostCurrency },
			Theme.Cost.Gap,
			Theme.Cost.TextSize
		)
	end

	local function resizeCards()
		local width = cardWidth()
		for _, record in cards do
			record.Holder.Size = UDim2.new(0, width, 1, -Theme.Card.ShadowOffset)
			-- Text size depends on row width, so it has to be refitted
			-- whenever the card changes size.
			UpgradeBoardUI._fitCard(record)
		end
	end

	strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCards)

	--== Painting ==----------------------------------------------------

	function UpgradeBoardUI._paintCard(record)
		local upgradeId = record.UpgradeId
		local entry = record.Entry
		local level = UpgradeState.GetLevel(upgradeId)
		local notation = SettingsState.Get("General.NumberNotation")
		local maxed = UpgradeDisplay.IsMaxed(upgradeId, level)

		record.LevelLabel.Text = UpgradeDisplay.LevelText(upgradeId, level)

		local currentText, nextText = UpgradeDisplay.Transition(upgradeId, level, notation)
		record.CurrentValue.Text = currentText
		record.Arrow.Visible = nextText ~= nil
		record.NextValue.Visible = nextText ~= nil
		record.NextValue.Text = nextText or ""

		if maxed then
			record.CostAmount.Text = Theme.Cost.MaxedText
			record.CostAmount.TextTransparency = Theme.Cost.MaxedTransparency
			record.CostCurrency.Visible = false
			record.Card.BackgroundTransparency = Theme.Card.MaxedTransparency
			record.PaintBuy("Maxed")
			record.PaintMax("Maxed")
			record.MaxButton.Text = Theme.Button.MaxLabel
			UpgradeBoardUI._fitCard(record)
			return
		end

		record.Card.BackgroundTransparency = Theme.Card.Transparency
		record.CostAmount.TextTransparency = 0
		record.CostCurrency.Visible = true

		local amountText, currencyName = UpgradeDisplay.CostParts(upgradeId, level, notation)
		record.CostAmount.Text = amountText or ""
		record.CostCurrency.Text = currencyName or ""
		UpgradeBoardUI._fitCard(record)

		local balance = CurrencyStatsState.Balances[entry.Currency] or ZERO
		local canAfford = UpgradePurchase.CanAffordNext(upgradeId, level, balance)
		local state = canAfford and "CanAfford" or "CannotAfford"

		record.PaintBuy(state)
		record.PaintMax(state)

		if record.HoveringMax and canAfford then
			local plan = UpgradePurchase.Plan(upgradeId, level, balance)
			record.MaxButton.Text = plan.Levels > 0 and (plan.Levels .. "x") or Theme.Button.MaxLabel
		else
			record.MaxButton.Text = Theme.Button.MaxLabel
		end
	end

	--== Which cards, in what order ==-----------------------------------

	local function computeVisible(): ({ string }, string)
		local hideMaxed = SettingsState.Get("General.HideMaxUpgrades") == true
		local active, maxed = {}, {}

		for _, upgradeId in UpgradeSchema.GetCategoryOrder(category) do
			local level = UpgradeState.GetLevel(upgradeId)
			if UpgradeDisplay.IsMaxed(upgradeId, level) then
				if not hideMaxed then
					table.insert(maxed, upgradeId)
				end
			else
				table.insert(active, upgradeId)
			end
		end

		local ordered = {}
		for _, upgradeId in active do
			table.insert(ordered, upgradeId)
		end
		for _, upgradeId in maxed do
			table.insert(ordered, upgradeId)
		end

		return ordered, table.concat(ordered, "|")
	end

	local currentSignature = ""

	local function rebuild()
		local ordered, signature = computeVisible()
		currentSignature = signature

		for _, record in cards do
			record.Holder:Destroy()
		end
		table.clear(cards)

		for order, upgradeId in ordered do
			local record = buildCard(upgradeId, order)
			if record then
				cards[upgradeId] = record
				UpgradeBoardUI._paintCard(record)
			end
		end

		resizeCards()

		-- TextBounds is only meaningful once a label has been laid out,
		-- so the fit right after building measures zeroes. One deferred
		-- pass catches every card with real numbers.
		task.defer(function()
			for _, record in cards do
				UpgradeBoardUI._fitCard(record)
			end
		end)
	end

	local function refresh()
		local _, signature = computeVisible()
		if signature ~= currentSignature then
			rebuild()
			return
		end
		for _, record in cards do
			UpgradeBoardUI._paintCard(record)
		end
	end

	UpgradeState.Changed.Event:Connect(refresh)
	CurrencyStatsState.Changed.Event:Connect(refresh)
	SettingsState.Changed:Connect(refresh)

	rebuild()
end

return UpgradeBoardUI
