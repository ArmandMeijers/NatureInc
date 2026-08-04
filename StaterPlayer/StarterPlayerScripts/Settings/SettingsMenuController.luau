--!strict
--[[
	SettingsMenuController.client.luau

	Builds and drives the settings menu. Nothing is pre-built in Studio;
	the whole thing comes from SettingsMenuConfig.

	THREE STRUCTURAL RULES THIS FILE EXISTS AROUND, all learned by
	getting them wrong first:

	1. UIStroke.ApplyStrokeMode defaults to Contextual, and on a TEXT
	   object — TextButton included — Contextual means "outline the
	   glyphs", not "draw a border". A border stroke added to a button
	   without setting the mode ends up boxing in its letters. Hence two
	   helpers below: borderStroke() forces Border, textStroke() uses
	   Contextual. Frames are unaffected, since Contextual on a Frame
	   already resolves to Border — which is what made this look like a
	   text bug rather than a stroke bug.

	2. A UIGradient on a CanvasGroup tints the whole composited group,
	   every child included. So the panel CanvasGroup is fully
	   transparent and a plain Frame inside it carries the colour.

	3. A UIListLayout positions EVERY child it has, including one you've
	   anchored elsewhere. The close button lives on the background
	   frame, which has no layout.

	VISUAL HIERARCHY is built from opacity, not just colour: the window
	frame is frosted, the card area sits on it, and the cards sit nearly
	solid on that. Three depths, so the eye can tell what's on top of
	what.

	The row set comes from the server's schema (SettingsSchema walks
	Template.Settings), so adding a field there adds a row here with no
	client edit.

	Location: StarterPlayer/StarterPlayerScripts/Settings/SettingsMenuController.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local SettingsState = require(Modules:WaitForChild("SettingsState"))
local CurrencyArt   = require(Modules:WaitForChild("UI"):WaitForChild("CurrencyArt"))
local Config        = require(Modules:WaitForChild("Settings"):WaitForChild("SettingsMenuConfig"))

local events = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Settings")
local getBundle = events:WaitForChild("GetPlayerSettingsBundle")
local setSetting = events:WaitForChild("SetPlayerSetting")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

--== Helpers ==---------------------------------------------------------

local function corner(instance: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = instance
end

-- An outline around the SHAPE. Always use this on buttons.
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

-- An outline around the GLYPHS. Only for text that needs to hold up
-- over something busy.
local function textStroke(label: Instance, color: Color3, thickness: number): UIStroke?
	if thickness <= 0 then
		return nil
	end
	local uiStroke = Instance.new("UIStroke")
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	uiStroke.Color = color
	uiStroke.Thickness = thickness
	uiStroke.LineJoinMode = Enum.LineJoinMode.Round
	uiStroke.Parent = label
	return uiStroke
end

local function makeRule(parent: Instance, order: number, size: UDim2, color: Color3, transparency: number): Frame
	local line = Instance.new("Frame")
	line.Name                   = "Rule"
	line.LayoutOrder            = order
	line.Size                   = size
	line.BackgroundColor3       = color
	line.BackgroundTransparency = transparency
	line.BorderSizePixel        = 0
	line.Parent                 = parent
	return line
end

--== Shell ==-----------------------------------------------------------

local stale = playerGui:FindFirstChild("SettingsMenuGui")
if stale then
	stale:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name           = "SettingsMenuGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

local backdrop: TextButton? = nil
if Config.Backdrop.Enabled then
	local frame = Instance.new("TextButton")
	frame.Name                   = "Backdrop"
	frame.Size                   = UDim2.fromScale(1, 1)
	frame.BackgroundColor3       = Config.Backdrop.Color
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel        = 0
	frame.AutoButtonColor        = false
	frame.Text                   = ""
	frame.Visible                = false
	frame.ZIndex                 = 1
	frame.Parent                 = gui
	backdrop = frame
end

--== Gear button ==-----------------------------------------------------

local iconButton = Instance.new("ImageButton")
iconButton.Name                   = "IconButton"
iconButton.AnchorPoint            = Config.Icon.AnchorPoint
iconButton.Position               = Config.Icon.Position
iconButton.Size                   = UDim2.fromOffset(Config.Icon.Size, Config.Icon.Size)
iconButton.BackgroundTransparency = 1
iconButton.BorderSizePixel        = 0
iconButton.AutoButtonColor        = false
iconButton.ScaleType              = Enum.ScaleType.Fit
iconButton.Image                  = Config.Icon.Image
iconButton.ZIndex                 = 4
iconButton.Parent                 = gui

local iconScale = Instance.new("UIScale")
iconScale.Parent = iconButton

iconButton.MouseEnter:Connect(function()
	TweenService:Create(iconScale, TweenInfo.new(0.12), { Scale = Config.Icon.HoverScale }):Play()
end)
iconButton.MouseLeave:Connect(function()
	TweenService:Create(iconScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
end)
iconButton.MouseButton1Down:Connect(function()
	TweenService:Create(iconScale, TweenInfo.new(0.08), { Scale = Config.Icon.ClickScale }):Play()
end)
iconButton.MouseButton1Up:Connect(function()
	TweenService:Create(iconScale, TweenInfo.new(0.08), { Scale = Config.Icon.HoverScale }):Play()
end)

--== Holder, glow, panel ==---------------------------------------------
-- The HOLDER is what gets tweened, and everything else is sized relative
-- to it, so nothing can lag behind the slide. The glow can't live inside
-- the panel: a CanvasGroup clips its children, so a bloom in there is
-- cut off at the exact edge it's meant to spill past.

local holder = Instance.new("Frame")
holder.Name                   = "PanelHolder"
holder.AnchorPoint            = Vector2.new(0.5, 0.5)
holder.Size                   = UDim2.new(Config.Panel.WidthScale, 0, Config.Panel.HeightScale, 0)
holder.BackgroundTransparency = 1
holder.Visible                = false
holder.ZIndex                 = 2
holder.Parent                 = gui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(Config.Panel.MinWidth, Config.Panel.MinHeight)
sizeConstraint.MaxSize = Vector2.new(Config.Panel.MaxWidth, Config.Panel.MaxHeight)
sizeConstraint.Parent  = holder

local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
-- Fully below the screen, derived from the panel's own height so a
-- resize can't leave a sliver of it showing.
local CLOSED_POSITION = UDim2.new(0.5, 0, 1 + Config.Panel.HeightScale, 0)
holder.Position = CLOSED_POSITION

local glow: Frame? = nil
if Config.Panel.GlowEnabled then
	local spread = Config.Panel.GlowSpread
	local frame = Instance.new("Frame")
	frame.Name                   = "Glow"
	frame.AnchorPoint            = Vector2.new(0.5, 0.5)
	frame.Position               = UDim2.fromScale(0.5, 0.5)
	frame.Size                   = UDim2.new(1, spread * 2, 1, spread * 2)
	frame.BackgroundColor3       = Config.Panel.GlowColor
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel        = 0
	frame.ZIndex                 = 1
	frame.Parent                 = holder
	corner(frame, Config.Panel.Corner + spread)
	glow = frame
end

local panel = Instance.new("CanvasGroup")
panel.Name                   = "Panel"
panel.Size                   = UDim2.fromScale(1, 1)
-- Transparent ON PURPOSE. All colour lives on the Background frame
-- below; anything painted on the group itself tints every child.
panel.BackgroundTransparency = 1
panel.BorderSizePixel        = 0
panel.GroupTransparency      = 1
panel.ZIndex                 = 2
panel.Parent                 = holder

local background = Instance.new("Frame")
background.Name                   = "Background"
background.Size                   = UDim2.fromScale(1, 1)
background.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
background.BackgroundTransparency = Config.Panel.Transparency
background.BorderSizePixel        = 0
background.ZIndex                 = 1
background.Parent                 = panel
corner(background, Config.Panel.Corner)
borderStroke(background, Config.Panel.BorderColor, Config.Panel.BorderThickness, Config.Panel.BorderTransparency)

local backgroundGradient = Instance.new("UIGradient")
backgroundGradient.Rotation = 90
backgroundGradient.Color = ColorSequence.new(Config.Panel.GradientTop, Config.Panel.GradientBottom)
backgroundGradient.Parent = background

-- Top edge only. A UIStroke would ring the whole shape; this is a single
-- line just inside the upper border, which is what sells the frosted
-- look rather than a plain grey box.
if Config.Panel.TopHighlightEnabled then
	local topHighlight = Instance.new("Frame")
	topHighlight.Name                   = "TopHighlight"
	topHighlight.AnchorPoint            = Vector2.new(0.5, 0)
	topHighlight.Position               = UDim2.new(0.5, 0, 0, Config.Panel.BorderThickness)
	topHighlight.Size                   = UDim2.new(1, -Config.Panel.TopHighlightInset * 2, 0, Config.Panel.TopHighlightThickness)
	topHighlight.BackgroundColor3       = Config.Panel.TopHighlightColor
	topHighlight.BackgroundTransparency = Config.Panel.TopHighlightTransparency
	topHighlight.BorderSizePixel        = 0
	topHighlight.ZIndex                 = 2
	topHighlight.Parent                 = background
	corner(topHighlight, Config.Panel.TopHighlightThickness)
end

--== Content column ==--------------------------------------------------

local content = Instance.new("Frame")
content.Name                   = "Content"
content.Size                   = UDim2.fromScale(1, 1)
content.BackgroundTransparency = 1
content.ZIndex                 = 2
content.Parent                 = panel

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop    = UDim.new(0, Config.Panel.Padding)
contentPadding.PaddingBottom = UDim.new(0, Config.Panel.Padding)
contentPadding.PaddingLeft   = UDim.new(0, Config.Panel.Padding)
contentPadding.PaddingRight  = UDim.new(0, Config.Panel.Padding)
contentPadding.Parent        = content

local contentLayout = Instance.new("UIListLayout")
contentLayout.SortOrder           = Enum.SortOrder.LayoutOrder
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.Padding             = UDim.new(0, Config.Panel.Spacing)
contentLayout.Parent              = content

--== Header ==----------------------------------------------------------

local header = Instance.new("Frame")
header.Name                   = "Header"
header.LayoutOrder            = 1
header.Size                   = UDim2.new(1, 0, 0, Config.Header.Height)
header.BackgroundColor3       = Config.Header.PlateColor
header.BackgroundTransparency = Config.Header.PlateTransparency
header.BorderSizePixel        = 0
header.Parent                 = content
corner(header, Config.Header.Corner)

local headerLayout = Instance.new("UIListLayout")
headerLayout.SortOrder           = Enum.SortOrder.LayoutOrder
headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
headerLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
headerLayout.Padding             = UDim.new(0, 5)
headerLayout.Parent              = header

local ruleSize = UDim2.new(1 - Config.Header.RuleInset * 2, 0, 0, Config.Header.RuleThickness)
makeRule(header, 1, ruleSize, Config.Header.RuleColor, Config.Header.RuleTransparency)

local title = Instance.new("TextLabel")
title.Name                   = "Title"
title.LayoutOrder            = 2
title.Size                   = UDim2.new(1, 0, 0, Config.Header.TextSize + 6)
title.BackgroundTransparency = 1
title.Font                   = Config.Header.Font
title.TextSize               = Config.Header.TextSize
title.TextColor3             = Config.Header.TextColor
title.Text                   = Config.Header.Title
title.Parent                 = header
textStroke(title, Config.Header.StrokeColor, Config.Header.StrokeThickness)

makeRule(header, 3, ruleSize, Config.Header.RuleColor, Config.Header.RuleTransparency)

--== Close button ==----------------------------------------------------
-- On Background, which has no UIListLayout. Under the header, the
-- header's layout would override its position and drag it to the middle.

local closeButton = Instance.new("TextButton")
closeButton.Name                   = "CloseButton"
closeButton.AnchorPoint            = Vector2.new(1, 0)
closeButton.Position               = UDim2.new(1, -Config.Header.CloseInset, 0, Config.Header.CloseInset)
closeButton.Size                   = UDim2.fromOffset(Config.Header.CloseSize, Config.Header.CloseSize)
closeButton.BackgroundColor3       = Config.Header.CloseColor
closeButton.BackgroundTransparency = Config.Header.CloseTransparency
closeButton.BorderSizePixel        = 0
closeButton.AutoButtonColor        = false
closeButton.Font                   = Enum.Font.GothamBold
closeButton.TextSize               = Config.Header.CloseTextSize
closeButton.TextColor3             = Config.Header.CloseTextColor
closeButton.Text                   = Config.Header.CloseGlyph
closeButton.ZIndex                 = 6
closeButton.Parent                 = background
corner(closeButton, Config.Header.CloseSize)
borderStroke(closeButton, Config.Header.CloseBorderColor, 1.5)

local closeScale = Instance.new("UIScale")
closeScale.Parent = closeButton

closeButton.MouseEnter:Connect(function()
	TweenService:Create(closeButton, TweenInfo.new(0.12), {
		BackgroundColor3 = Config.Header.CloseHoverColor,
		TextColor3       = Config.Header.CloseHoverTextColor,
	}):Play()
end)
closeButton.MouseLeave:Connect(function()
	TweenService:Create(closeButton, TweenInfo.new(0.12), {
		BackgroundColor3 = Config.Header.CloseColor,
		TextColor3       = Config.Header.CloseTextColor,
	}):Play()
end)
closeButton.MouseButton1Down:Connect(function()
	TweenService:Create(closeScale, TweenInfo.new(0.08), { Scale = Config.Header.CloseClickScale }):Play()
end)
closeButton.MouseButton1Up:Connect(function()
	TweenService:Create(closeScale, TweenInfo.new(0.08), { Scale = 1 }):Play()
end)

--== Scroll ==----------------------------------------------------------

local scrollHolder = Instance.new("Frame")
scrollHolder.Name                   = "ScrollHolder"
scrollHolder.LayoutOrder            = 2
scrollHolder.Size                   = UDim2.new(1, 0, 0, 0)
scrollHolder.BackgroundTransparency = 1
scrollHolder.Parent                 = content

local holderFlex = Instance.new("UIFlexItem")
holderFlex.FlexMode = Enum.UIFlexMode.Fill
holderFlex.Parent = scrollHolder

-- The middle layer of the hierarchy: window (frosted) -> this -> cards
-- (nearly solid). Without it the cards float directly on the window and
-- the list has no bounds.
if Config.CardArea.Enabled then
	local cardArea = Instance.new("Frame")
	cardArea.Name                   = "CardArea"
	cardArea.Size                   = UDim2.fromScale(1, 1)
	cardArea.BackgroundColor3       = Config.CardArea.Color
	cardArea.BackgroundTransparency = Config.CardArea.Transparency
	cardArea.BorderSizePixel        = 0
	cardArea.ZIndex                 = 1
	cardArea.Parent                 = scrollHolder
	corner(cardArea, Config.CardArea.Corner)
end

-- Roblox exposes no styling hook for the scrollbar TRACK, only the
-- handle, so the track is a plain frame behind where the bar renders.
local scrollTrack = Instance.new("Frame")
scrollTrack.Name                   = "ScrollTrack"
scrollTrack.AnchorPoint            = Vector2.new(1, 0)
scrollTrack.Position               = UDim2.new(1, -Config.CardArea.Padding, 0, Config.CardArea.Padding)
scrollTrack.Size                   = UDim2.new(0, Config.ScrollBar.Thickness, 1, -Config.CardArea.Padding * 2)
scrollTrack.BackgroundColor3       = Config.ScrollBar.TrackColor
scrollTrack.BackgroundTransparency = Config.ScrollBar.TrackTransparency
scrollTrack.BorderSizePixel        = 0
scrollTrack.ZIndex                 = 2
scrollTrack.Parent                 = scrollHolder
corner(scrollTrack, Config.ScrollBar.Thickness)

local scroll = Instance.new("ScrollingFrame")
scroll.Name                       = "Rows"
scroll.Size                       = UDim2.fromScale(1, 1)
scroll.BackgroundTransparency     = 1
scroll.BorderSizePixel            = 0
scroll.ScrollingDirection         = Enum.ScrollingDirection.Y
scroll.ScrollBarThickness         = Config.ScrollBar.Thickness
scroll.ScrollBarImageColor3       = Config.ScrollBar.HandleColor
scroll.ScrollBarImageTransparency = 0
scroll.VerticalScrollBarInset     = Enum.ScrollBarInset.ScrollBar
scroll.CanvasSize                 = UDim2.new()
scroll.AutomaticCanvasSize        = Enum.AutomaticSize.Y
scroll.ZIndex                     = 3
scroll.Parent                     = scrollHolder

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingTop    = UDim.new(0, Config.CardArea.Padding)
scrollPadding.PaddingBottom = UDim.new(0, Config.CardArea.Padding)
scrollPadding.PaddingLeft   = UDim.new(0, Config.CardArea.Padding)
scrollPadding.PaddingRight  = UDim.new(0, Config.CardArea.Padding)
scrollPadding.Parent        = scroll

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Padding   = UDim.new(0, 8)
scrollLayout.Parent    = scroll

--== Controls ==--------------------------------------------------------

local function buildToggle(parent: Instance): (TextButton, (boolean) -> ())
	local button = Instance.new("TextButton")
	button.Name             = "Toggle"
	button.AnchorPoint      = Vector2.new(1, 0.5)
	button.Position         = UDim2.new(1, 0, 0.5, 0)
	button.Size             = UDim2.fromOffset(Config.Toggle.Width, Config.Toggle.Height)
	button.BackgroundColor3 = Config.Toggle.OffColor
	button.BorderSizePixel  = 0
	button.AutoButtonColor  = false
	button.Text             = ""
	button.ZIndex           = 4
	button.Parent           = parent
	corner(button, Config.Toggle.Height)
	borderStroke(button, Config.Toggle.BorderColor, Config.Toggle.BorderThickness)

	local knobSize = Config.Toggle.Height - Config.Toggle.KnobPadding * 2

	local label = Instance.new("TextLabel")
	label.Name                   = "StateLabel"
	label.AnchorPoint            = Vector2.new(0.5, 0.5)
	label.Size                   = UDim2.fromOffset(Config.Toggle.Width - knobSize, Config.Toggle.Height)
	label.BackgroundTransparency = 1
	label.Font                   = Config.Toggle.LabelFont
	label.TextSize               = Config.Toggle.LabelSize
	label.Text                   = "OFF"
	label.ZIndex                 = 5
	label.Parent                 = button

	local knob = Instance.new("Frame")
	knob.Name             = "Knob"
	knob.AnchorPoint      = Vector2.new(0, 0.5)
	knob.Size             = UDim2.fromOffset(knobSize, knobSize)
	knob.BackgroundColor3 = Config.Toggle.KnobColor
	knob.BorderSizePixel  = 0
	knob.ZIndex           = 6
	knob.Parent           = button
	corner(knob, knobSize)

	local function apply(value: boolean)
		local info = TweenInfo.new(Config.Toggle.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local knobX = value
			and (Config.Toggle.Width - knobSize - Config.Toggle.KnobPadding)
			or Config.Toggle.KnobPadding
		TweenService:Create(knob, info, { Position = UDim2.new(0, knobX, 0.5, 0) }):Play()
		TweenService:Create(button, info, {
			BackgroundColor3 = value and Config.Toggle.OnColor or Config.Toggle.OffColor,
		}):Play()

		-- The word sits on whichever side the knob isn't, since that's
		-- the only place it can go without being covered by it.
		label.Text = value and "ON" or "OFF"
		label.TextColor3 = value and Config.Toggle.OnLabelColor or Config.Toggle.OffLabelColor
		label.Position = value
			and UDim2.new(0, (Config.Toggle.Width - knobSize) / 2, 0.5, 0)
			or UDim2.new(1, -(Config.Toggle.Width - knobSize) / 2, 0.5, 0)
	end

	return button, apply
end

local function buildChoice(parent: Instance): (TextButton, (string) -> ())
	local button = Instance.new("TextButton")
	button.Name                   = "Choice"
	button.AnchorPoint            = Vector2.new(1, 0.5)
	button.Position               = UDim2.new(1, 0, 0.5, 0)
	button.Size                   = UDim2.fromOffset(Config.Choice.Width, Config.Choice.Height)
	button.BackgroundColor3       = Config.Choice.Color
	button.BackgroundTransparency = Config.Choice.Transparency
	button.BorderSizePixel        = 0
	button.AutoButtonColor        = false
	button.Font                   = Config.Choice.Font
	button.TextSize               = Config.Choice.TextSize
	button.TextColor3             = Config.Choice.TextColor
	button.Text                   = ""
	button.ZIndex                 = 4
	button.Parent                 = parent
	corner(button, Config.Choice.Corner)
	-- Border, not Contextual. Contextual on a TextButton draws a box
	-- around the WORD instead of an outline around the button.
	borderStroke(button, Config.Choice.BorderColor, Config.Choice.BorderThickness)

	local scaleObject = Instance.new("UIScale")
	scaleObject.Parent = button

	local hovering = false
	local info = TweenInfo.new(0.12)

	local function restore()
		TweenService:Create(button, info, {
			BackgroundColor3 = hovering and Config.Choice.HoverColor or Config.Choice.Color,
			TextColor3 = Config.Choice.TextColor,
		}):Play()
	end

	button.MouseEnter:Connect(function()
		hovering = true
		TweenService:Create(scaleObject, info, { Scale = Config.Choice.HoverScale }):Play()
		restore()
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		TweenService:Create(scaleObject, info, { Scale = 1 }):Play()
		restore()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.06), {
			BackgroundColor3 = Config.Choice.PressedColor,
			TextColor3 = Config.Choice.PressedTextColor,
		}):Play()
	end)
	button.MouseButton1Up:Connect(restore)

	return button, function(text: string)
		button.Text = text
	end
end

--== Cards ==-----------------------------------------------------------

local rows: { [string]: any } = {}

local function nextValue(def, current)
	if def.type == "toggle" then
		return not current
	end
	local index = table.find(def.options, current) or 1
	return def.options[(index % #def.options) + 1]
end

local function choiceText(def, value): string
	return string.upper((def.displayNames and def.displayNames[value]) or tostring(value))
end

local function buildCard(category, def, order)
	local isCurrency = category.name == "CurrencyView"
	local path = category.name .. "." .. def.key

	local cardHolder = Instance.new("Frame")
	cardHolder.Name                   = def.key
	cardHolder.LayoutOrder            = order
	cardHolder.Size                   = UDim2.new(1, 0, 0, Config.Card.Height + Config.Card.ShadowOffset)
	cardHolder.BackgroundTransparency = 1
	cardHolder.ZIndex                 = 3
	cardHolder.Parent                 = scroll

	local shadow = Instance.new("Frame")
	shadow.Name                   = "Shadow"
	shadow.Position               = UDim2.fromOffset(0, Config.Card.ShadowOffset)
	shadow.Size                   = UDim2.new(1, 0, 0, Config.Card.Height)
	shadow.BackgroundColor3       = Config.Card.ShadowColor
	shadow.BackgroundTransparency = Config.Card.ShadowTransparency
	shadow.BorderSizePixel        = 0
	shadow.ZIndex                 = 3
	shadow.Parent                 = cardHolder
	corner(shadow, Config.Card.Corner)

	local card = Instance.new("Frame")
	card.Name                   = "Card"
	card.Size                   = UDim2.new(1, 0, 0, Config.Card.Height)
	card.BackgroundColor3       = Config.Card.Color
	card.BackgroundTransparency = Config.Card.Transparency
	card.BorderSizePixel        = 0
	card.ZIndex                 = 4
	card.Parent                 = cardHolder
	corner(card, Config.Card.Corner)
	borderStroke(card, Config.Card.BorderColor, Config.Card.BorderThickness, Config.Card.BorderTransparency)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft  = UDim.new(0, Config.Card.PaddingLeft)
	padding.PaddingRight = UDim.new(0, Config.Card.PaddingRight)
	padding.Parent       = card

	-- Icons only on currency rows, and only the currency's own artwork.
	local iconImage: ImageLabel? = nil
	local textLeft = 0

	if isCurrency then
		local image = Instance.new("ImageLabel")
		image.Name                   = "Icon"
		image.AnchorPoint            = Vector2.new(0, 0.5)
		image.Position               = UDim2.new(0, 0, 0.5, 0)
		image.Size                   = UDim2.fromOffset(Config.Card.IconSize, Config.Card.IconSize)
		image.BackgroundTransparency = 1
		image.ScaleType              = Enum.ScaleType.Fit
		image.ZIndex                 = 5
		image.Parent                 = card
		iconImage = image
		textLeft = Config.Card.IconSize + Config.Card.IconGap
	end

	local description = Config.RowDescriptions[path]
	if isCurrency and not description then
		description = Config.CurrencyDescriptionFormat:format(def.key)
	end

	local controlWidth = def.type == "toggle" and Config.Toggle.Width or Config.Choice.Width

	local textColumn = Instance.new("Frame")
	textColumn.Name                   = "Text"
	textColumn.AnchorPoint            = Vector2.new(0, 0.5)
	textColumn.Position               = UDim2.new(0, textLeft, 0.5, 0)
	textColumn.Size                   = UDim2.new(1, -(textLeft + controlWidth + 14), 1, -10)
	textColumn.BackgroundTransparency = 1
	textColumn.ZIndex                 = 5
	textColumn.Parent                 = card

	local columnLayout = Instance.new("UIListLayout")
	columnLayout.SortOrder         = Enum.SortOrder.LayoutOrder
	columnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	columnLayout.Padding           = UDim.new(0, 1)
	columnLayout.Parent            = textColumn

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name                   = "Name"
	nameLabel.LayoutOrder            = 1
	nameLabel.Size                   = UDim2.new(1, 0, 0, Config.Card.NameSize + 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font                   = Config.Card.NameFont
	nameLabel.TextSize               = Config.Card.NameSize
	nameLabel.TextColor3             = Config.Card.NameColor
	nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
	nameLabel.TextTruncate           = Enum.TextTruncate.AtEnd
	nameLabel.Text                   = def.label
	nameLabel.ZIndex                 = 5
	nameLabel.Parent                 = textColumn

	if description then
		local descriptionLabel = Instance.new("TextLabel")
		descriptionLabel.Name                   = "Description"
		descriptionLabel.LayoutOrder            = 2
		descriptionLabel.Size                   = UDim2.new(1, 0, 0, Config.Card.DescriptionSize + 4)
		descriptionLabel.BackgroundTransparency = 1
		descriptionLabel.Font                   = Config.Card.DescriptionFont
		descriptionLabel.TextSize               = Config.Card.DescriptionSize
		descriptionLabel.TextColor3             = Config.Card.DescriptionColor
		descriptionLabel.TextXAlignment         = Enum.TextXAlignment.Left
		descriptionLabel.TextTruncate           = Enum.TextTruncate.AtEnd
		descriptionLabel.Text                   = description
		descriptionLabel.ZIndex                 = 5
		descriptionLabel.Parent                 = textColumn
	end

	if isCurrency then
		-- A gradient needs a thin dark edge to hold up against a near
		-- white card; without it the lighter currencies wash out.
		textStroke(nameLabel, Config.Card.CurrencyStrokeColor, Config.Card.CurrencyStrokeThickness)
		CurrencyArt.Bind(def.key, {
			Icons = iconImage and { iconImage } or nil,
			Labels = { nameLabel },
		})
	end

	local entry: any = { def = def, category = category.name }

	if def.type == "toggle" then
		local button, apply = buildToggle(card)
		entry.button = button
		entry.apply = apply
	else
		local button, apply = buildChoice(card)
		entry.button = button
		entry.apply = function(value)
			apply(choiceText(def, value))
		end
	end

	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12), {
			BackgroundTransparency = math.max(0, Config.Card.Transparency - Config.Card.HoverLift),
		}):Play()
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12), {
			BackgroundTransparency = Config.Card.Transparency,
		}):Play()
	end)

	return entry
end

--== Fetch schema + values ==-------------------------------------------

-- Retried. A client that asks before its profile has loaded gets nothing
-- back, and rendering an empty settings menu for the rest of the session
-- with no error is the worst possible response to that.
local function fetchBundle()
	local attempt = 0
	while attempt < 6 do
		local ok, bundle = pcall(function()
			return getBundle:InvokeServer()
		end)
		if ok and type(bundle) == "table" and type(bundle.schema) == "table" and #bundle.schema > 0 then
			return bundle
		end
		attempt += 1
		task.wait(math.min(0.5 * attempt, 4))
	end
	warn("SettingsMenuController: could not fetch the settings bundle -- the menu will be empty.")
	return { schema = {}, values = {} }
end

local bundle = fetchBundle()
local schema = bundle.schema
local values = bundle.values or {}

local layoutOrder = 0

for index, category in ipairs(schema) do
	if index > 1 then
		layoutOrder += 1
		local spacer = Instance.new("Frame")
		spacer.Name                   = "Spacer"
		spacer.LayoutOrder            = layoutOrder
		spacer.Size                   = UDim2.new(1, 0, 0, Config.Section.SpacingAbove)
		spacer.BackgroundTransparency = 1
		spacer.Parent                 = scroll
	end

	layoutOrder += 1
	local section = Instance.new("Frame")
	section.Name                   = category.name .. "Section"
	section.LayoutOrder            = layoutOrder
	section.Size                   = UDim2.new(1, 0, 0, Config.Section.Height)
	section.BackgroundTransparency = 1
	section.ZIndex                 = 3
	section.Parent                 = scroll

	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.SortOrder           = Enum.SortOrder.LayoutOrder
	sectionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sectionLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
	sectionLayout.Padding             = UDim.new(0, 4)
	sectionLayout.Parent              = section

	makeRule(section, 1, UDim2.new(1, -8, 0, Config.Section.RuleThickness),
		Config.Section.RuleColor, Config.Section.RuleTransparency)

	local caption = Instance.new("TextLabel")
	caption.Name                   = "Caption"
	caption.LayoutOrder            = 2
	caption.Size                   = UDim2.new(1, 0, 0, Config.Section.CaptionSize + 4)
	caption.BackgroundTransparency = 1
	caption.Font                   = Config.Section.CaptionFont
	caption.TextSize               = Config.Section.CaptionSize
	caption.TextColor3             = Config.Section.CaptionColor
	caption.Text                   = string.upper(category.label)
	caption.ZIndex                 = 3
	caption.Parent                 = section

	makeRule(section, 3, UDim2.new(1, -8, 0, Config.Section.RuleThickness),
		Config.Section.RuleColor, Config.Section.RuleTransparency)

	for _, def in ipairs(category.rows) do
		layoutOrder += 1
		local path = category.name .. "." .. def.key
		local entry = buildCard(category, def, layoutOrder)
		rows[path] = entry

		entry.button.MouseButton1Click:Connect(function()
			entry.value = nextValue(def, entry.value)
			entry.apply(entry.value)
			SettingsState._Set(path, entry.value)
			setSetting:FireServer(category.name, def.key, entry.value)
		end)
	end
end

for _, category in ipairs(schema) do
	for _, def in ipairs(category.rows) do
		local path = category.name .. "." .. def.key
		local entry = rows[path]
		if entry then
			local categoryValues = values[category.name]
			local value = categoryValues and categoryValues[def.key]
			if value == nil then
				value = def.default
			end
			entry.value = value
			entry.apply(value)
			SettingsState._Set(path, value)
		end
	end
end

--== Open / close ==----------------------------------------------------

local isOpen = false
local openGeneration = 0
local activeTweens: { Tween } = {}

local function cancelTweens()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

local function track(tween: Tween): Tween
	table.insert(activeTweens, tween)
	tween:Play()
	return tween
end

local function setOpen(open: boolean)
	if open == isOpen then
		return
	end
	isOpen = open
	openGeneration += 1
	local myGeneration = openGeneration

	cancelTweens()

	if open then
		holder.Visible = true
		if backdrop then backdrop.Visible = true end
	end

	local slideInfo = TweenInfo.new(
		open and Config.Animation.OpenTime or Config.Animation.CloseTime,
		open and Config.Animation.OpenEasing or Config.Animation.CloseEasing,
		Enum.EasingDirection.Out
	)
	track(TweenService:Create(holder, slideInfo, { Position = open and OPEN_POSITION or CLOSED_POSITION }))

	-- The fade is always Quad and slightly quicker than the slide. A Back
	-- curve on transparency overshoots past 0, clamps, and reads as a
	-- stutter rather than as bounce.
	local fadeInfo = TweenInfo.new(
		(open and Config.Animation.OpenTime or Config.Animation.CloseTime) * 0.75,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local fade = track(TweenService:Create(panel, fadeInfo, { GroupTransparency = open and 0 or 1 }))

	if backdrop then
		track(TweenService:Create(backdrop, fadeInfo, {
			BackgroundTransparency = open and Config.Backdrop.Transparency or 1,
		}))
	end
	if glow then
		track(TweenService:Create(glow, fadeInfo, {
			BackgroundTransparency = open and Config.Panel.GlowTransparency or 1,
		}))
	end

	if not open then
		-- Generation guard: without it, spam-clicking the gear leaves an
		-- in-flight close callback that fires later and hides a panel the
		-- player has already reopened.
		fade.Completed:Connect(function(playbackState)
			if myGeneration == openGeneration and not isOpen and playbackState == Enum.PlaybackState.Completed then
				holder.Visible = false
				if backdrop then backdrop.Visible = false end
			end
		end)
	end
end

iconButton.MouseButton1Click:Connect(function()
	setOpen(not isOpen)
end)

closeButton.MouseButton1Click:Connect(function()
	setOpen(false)
end)

if backdrop and Config.Backdrop.ClickToClose then
	backdrop.MouseButton1Click:Connect(function()
		setOpen(false)
	end)
end
