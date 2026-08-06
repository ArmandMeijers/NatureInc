--!strict
--[[
	RuneMenuController.client.luau

	The runes menu: a list of runes down the left, a grid of the rune
	types you own on the right with their live boosts.

	ONLY OWNED TYPES APPEAR. A box for a type you've never rolled would be
	a list of 1x boosts — technically accurate and completely uninformative
	— and it would bury the ones that matter under everything that doesn't.

	BOXES ARE A CONSTANT SIZE; the LABELS shrink. A type with six boosts
	and one with a single boost need the same footprint or the grid jumps
	around as you roll new types. Rows inside are relative weights, so
	more boosts automatically means thinner rows and smaller text, with
	no per-type numbers anywhere.

	Text is sized from each row's MEASURED height rather than set in
	pixels, for the same reason the world panels are: the box's real size
	depends on the viewport, so any fixed size is right at one resolution.

	THE SELECTED RUNE PERSISTS FOR THE SESSION but not beyond it. Reopening
	the menu returns you to the rune you were looking at; rejoining starts
	you at the first one. Saving it would mean a profile write for a UI
	preference, and the first rune is the right default for someone coming
	back later anyway.

	Location: StarterPlayer/StarterPlayerScripts/Runes/RuneMenuController.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local BigNumber     = require(Modules:WaitForChild("BigNumber"))
local SettingsState = require(Modules:WaitForChild("SettingsState"))
local CurrencyArt   = require(Modules:WaitForChild("UI"):WaitForChild("CurrencyArt"))
local RuneArt       = require(Modules:WaitForChild("UI"):WaitForChild("RuneArt"))
local Theme         = require(Modules:WaitForChild("UI"):WaitForChild("RuneMenuTheme"))

local RunesModules = Modules:WaitForChild("Runes")
local RuneScheme = require(RunesModules:WaitForChild("RuneScheme"))
local RuneMath   = require(RunesModules:WaitForChild("RuneMath"))
local RuneState  = require(RunesModules:WaitForChild("RuneState"))
local RuneTags   = require(RunesModules:WaitForChild("RuneTags"))

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local ZERO = BigNumber.new(0, 0)
local ONE = BigNumber.FromNumber(1)

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

local function textStroke(label: Instance, color: Color3, thickness: number)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	uiStroke.Color = color
	uiStroke.Thickness = thickness
	uiStroke.LineJoinMode = Enum.LineJoinMode.Round
	uiStroke.Parent = label
end

-- Sizes text to a fraction of the label's own measured height, then
-- shrinks it if the line would overrun the width. One pass, called after
-- layout and after any text change — never from a size signal on the
-- text itself, which would feed back.
local function fit(label: TextLabel, fillFactor: number)
	local height = label.AbsoluteSize.Y
	local width = label.AbsoluteSize.X
	if height <= 0 then
		return
	end

	local base = math.max(Theme.Box.MinTextSize, math.floor(height * fillFactor))
	label.TextSize = base

	local measured = label.TextBounds.X
	if width > 0 and measured > width and measured > 0 then
		label.TextSize = math.max(Theme.Box.MinTextSize, math.floor(base * width / measured))
	end
end

local function makeLabel(parent: Instance, order: number, heightScale: number, font: Enum.Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder            = order
	label.Size                   = UDim2.new(1, 0, heightScale, 0)
	label.BackgroundTransparency = 1
	label.Font                   = font
	label.TextColor3             = color
	label.TextScaled             = false
	label.TextWrapped            = false
	label.TextSize               = 16
	label.Text                   = ""
	label.Parent                 = parent
	textStroke(label, Theme.Box.StrokeColor, Theme.Box.StrokeThickness)
	return label
end

--== Shell ==-----------------------------------------------------------

local stale = playerGui:FindFirstChild("RuneMenuGui")
if stale then
	stale:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name           = "RuneMenuGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 11
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

local backdrop = Instance.new("TextButton")
backdrop.Name                   = "Backdrop"
backdrop.Size                   = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3       = Theme.Backdrop.Color
backdrop.BackgroundTransparency = 1
backdrop.BorderSizePixel        = 0
backdrop.AutoButtonColor        = false
backdrop.Text                   = ""
backdrop.Visible                = false
backdrop.ZIndex                 = 1
backdrop.Parent                 = gui

--== Open button ==-----------------------------------------------------

local iconValue = ReplicatedStorage:FindFirstChild("Assets")
iconValue = iconValue and iconValue:FindFirstChild("UIIcons")
iconValue = iconValue and iconValue:FindFirstChild("RunesIcon")
local iconImage = (iconValue and iconValue:IsA("StringValue") and iconValue.Value) or ""

local iconButton = Instance.new("ImageButton")
iconButton.Name                   = "RunesButton"
iconButton.AnchorPoint            = Theme.Icon.AnchorPoint
iconButton.Position               = Theme.Icon.Position
iconButton.Size                   = UDim2.fromOffset(Theme.Icon.Size, Theme.Icon.Size)
iconButton.BackgroundTransparency = 1
iconButton.BorderSizePixel        = 0
iconButton.AutoButtonColor        = false
iconButton.ScaleType              = Enum.ScaleType.Fit
iconButton.Image                  = iconImage
iconButton.ZIndex                 = 4
iconButton.Parent                 = gui

if iconImage == "" then
	-- Placeholder until the art exists. Deliberately the same shape and
	-- position the real icon will occupy, so nothing moves when it lands.
	local glyph = Instance.new("TextLabel")
	glyph.Size                   = UDim2.fromScale(1, 1)
	glyph.BackgroundTransparency = 1
	glyph.Font                   = Enum.Font.GothamBold
	glyph.TextScaled             = true
	glyph.TextWrapped            = false
	glyph.TextColor3             = Theme.Icon.GlyphColor
	glyph.Text                   = Theme.Icon.Glyph
	glyph.Parent                 = iconButton
	textStroke(glyph, Theme.Box.StrokeColor, 3)
end

local iconScale = Instance.new("UIScale")
iconScale.Parent = iconButton

iconButton.MouseEnter:Connect(function()
	TweenService:Create(iconScale, TweenInfo.new(0.12), { Scale = Theme.Icon.HoverScale }):Play()
end)
iconButton.MouseLeave:Connect(function()
	TweenService:Create(iconScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
end)
iconButton.MouseButton1Down:Connect(function()
	TweenService:Create(iconScale, TweenInfo.new(0.08), { Scale = Theme.Icon.ClickScale }):Play()
end)
iconButton.MouseButton1Up:Connect(function()
	TweenService:Create(iconScale, TweenInfo.new(0.08), { Scale = Theme.Icon.HoverScale }):Play()
end)

--== Panel ==-----------------------------------------------------------

local holder = Instance.new("Frame")
holder.Name                   = "PanelHolder"
holder.AnchorPoint            = Vector2.new(0.5, 0.5)
holder.Size                   = UDim2.new(Theme.Panel.WidthScale, 0, Theme.Panel.HeightScale, 0)
holder.BackgroundTransparency = 1
holder.Visible                = false
holder.ZIndex                 = 2
holder.Parent                 = gui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(Theme.Panel.MinWidth, Theme.Panel.MinHeight)
sizeConstraint.MaxSize = Vector2.new(Theme.Panel.MaxWidth, Theme.Panel.MaxHeight)
sizeConstraint.Parent  = holder

local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
local CLOSED_POSITION = UDim2.new(0.5, 0, 1 + Theme.Panel.HeightScale, 0)
holder.Position = CLOSED_POSITION

local panel = Instance.new("CanvasGroup")
panel.Name                   = "Panel"
panel.Size                   = UDim2.fromScale(1, 1)
-- Transparent on purpose: a UIGradient or colour on a CanvasGroup tints
-- every child. The Background frame below carries the colour.
panel.BackgroundTransparency = 1
panel.BorderSizePixel        = 0
panel.GroupTransparency      = 1
panel.Parent                 = holder

local background = Instance.new("Frame")
background.Name                   = "Background"
background.Size                   = UDim2.fromScale(1, 1)
background.BackgroundColor3       = Theme.Panel.Color
background.BackgroundTransparency = Theme.Panel.Transparency
background.BorderSizePixel        = 0
background.Parent                 = panel
corner(background, Theme.Panel.Corner)
borderStroke(background, Theme.Panel.BorderColor, Theme.Panel.BorderThickness, Theme.Panel.BorderTransparency)

local content = Instance.new("Frame")
content.Name                   = "Content"
content.Size                   = UDim2.fromScale(1, 1)
content.BackgroundTransparency = 1
content.Parent                 = panel

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop    = UDim.new(0, Theme.Panel.Padding)
contentPadding.PaddingBottom = UDim.new(0, Theme.Panel.Padding)
contentPadding.PaddingLeft   = UDim.new(0, Theme.Panel.Padding)
contentPadding.PaddingRight  = UDim.new(0, Theme.Panel.Padding)
contentPadding.Parent        = content

--== Header ==----------------------------------------------------------

local header = Instance.new("Frame")
header.Name                   = "Header"
header.Size                   = UDim2.new(1, 0, 0, Theme.Header.Height)
header.BackgroundTransparency = 1
header.Parent                 = content

local title = Instance.new("TextLabel")
title.Name                   = "Title"
title.Size                   = UDim2.new(1, -Theme.Header.CloseSize - 12, 1, 0)
title.BackgroundTransparency = 1
title.Font                   = Theme.Header.Font
title.TextColor3             = Theme.Header.Color
title.TextXAlignment         = Enum.TextXAlignment.Left
title.TextScaled             = false
title.TextWrapped            = false
title.Text                   = Theme.Header.Title
title.Parent                 = header
textStroke(title, Theme.Header.StrokeColor, Theme.Header.StrokeThickness)

local closeButton = Instance.new("TextButton")
closeButton.Name             = "Close"
closeButton.AnchorPoint      = Vector2.new(1, 0.5)
closeButton.Position         = UDim2.new(1, 0, 0.5, 0)
closeButton.Size             = UDim2.fromOffset(Theme.Header.CloseSize, Theme.Header.CloseSize)
closeButton.BackgroundColor3 = Theme.Header.CloseColor
closeButton.BorderSizePixel  = 0
closeButton.AutoButtonColor  = false
closeButton.Font             = Enum.Font.GothamBold
closeButton.TextSize         = 16
closeButton.TextColor3       = Theme.Header.CloseTextColor
closeButton.Text             = Theme.Header.CloseGlyph
closeButton.Parent           = header
corner(closeButton, Theme.Header.CloseSize)
borderStroke(closeButton, Theme.Header.CloseBorderColor, 2)

local closeScale = Instance.new("UIScale")
closeScale.Parent = closeButton

closeButton.MouseEnter:Connect(function()
	TweenService:Create(closeButton, TweenInfo.new(0.12), {
		BackgroundColor3 = Theme.Header.CloseHoverColor,
		TextColor3 = Theme.Header.CloseHoverText,
	}):Play()
end)
closeButton.MouseLeave:Connect(function()
	TweenService:Create(closeButton, TweenInfo.new(0.12), {
		BackgroundColor3 = Theme.Header.CloseColor,
		TextColor3 = Theme.Header.CloseTextColor,
	}):Play()
end)
closeButton.MouseButton1Down:Connect(function()
	TweenService:Create(closeScale, TweenInfo.new(0.08), { Scale = Theme.Header.CloseClickScale }):Play()
end)
closeButton.MouseButton1Up:Connect(function()
	TweenService:Create(closeScale, TweenInfo.new(0.08), { Scale = 1 }):Play()
end)

--== Body: list | divider | grid ==-------------------------------------

local body = Instance.new("Frame")
body.Name                   = "Body"
body.Position               = UDim2.new(0, 0, 0, Theme.Header.Height + 8)
body.Size                   = UDim2.new(1, 0, 1, -(Theme.Header.Height + 8))
body.BackgroundTransparency = 1
body.Parent                 = content

local list = Instance.new("ScrollingFrame")
list.Name                       = "RuneList"
list.Size                       = UDim2.new(Theme.List.WidthScale, -Theme.List.Gap, 1, 0)
list.BackgroundTransparency     = 1
list.BorderSizePixel            = 0
list.ScrollingDirection         = Enum.ScrollingDirection.Y
list.ScrollBarThickness         = Theme.Scroll.Thickness
list.ScrollBarImageColor3       = Theme.Scroll.HandleColor
list.ScrollBarImageTransparency = Theme.Scroll.Transparency
list.CanvasSize                 = UDim2.new()
list.AutomaticCanvasSize        = Enum.AutomaticSize.Y
list.Parent                     = body

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0, Theme.List.ButtonSpacing)
listLayout.Parent    = list

-- A UIStroke draws OUTSIDE its frame and a ScrollingFrame clips
-- descendants, so without this the buttons' borders get sliced off
-- against the list's edges.
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop    = UDim.new(0, Theme.Grid.EdgePadding)
listPadding.PaddingBottom = UDim.new(0, Theme.Grid.EdgePadding)
listPadding.PaddingLeft   = UDim.new(0, Theme.Grid.EdgePadding)
listPadding.PaddingRight  = UDim.new(0, Theme.Grid.EdgePadding)
listPadding.Parent        = list

local divider = Instance.new("Frame")
divider.Name                   = "Divider"
divider.AnchorPoint            = Vector2.new(0.5, 0)
divider.Position               = UDim2.new(Theme.List.WidthScale, 0, 0, 0)
divider.Size                   = UDim2.new(0, Theme.List.DividerWidth, 1, 0)
divider.BackgroundColor3       = Theme.List.DividerColor
divider.BackgroundTransparency = Theme.List.DividerTransparency
divider.BorderSizePixel        = 0
divider.Parent                 = body

local grid = Instance.new("ScrollingFrame")
grid.Name                       = "RuneGrid"
grid.AnchorPoint                = Vector2.new(1, 0)
grid.Position                   = UDim2.fromScale(1, 0)
grid.Size                       = UDim2.new(1 - Theme.List.WidthScale, -Theme.List.Gap, 1, 0)
grid.BackgroundTransparency     = 1
grid.BorderSizePixel            = 0
grid.ScrollingDirection         = Enum.ScrollingDirection.Y
grid.ScrollBarThickness         = Theme.Scroll.Thickness
grid.ScrollBarImageColor3       = Theme.Scroll.HandleColor
grid.ScrollBarImageTransparency = Theme.Scroll.Transparency
grid.CanvasSize                 = UDim2.new()
grid.AutomaticCanvasSize        = Enum.AutomaticSize.Y
grid.Parent                     = body

local gridLayout = Instance.new("UIGridLayout")
gridLayout.SortOrder    = Enum.SortOrder.LayoutOrder
gridLayout.CellPadding  = UDim2.fromOffset(Theme.Grid.Gap, Theme.Grid.Gap)
gridLayout.FillDirectionMaxCells = Theme.Grid.Columns
gridLayout.Parent       = grid

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop    = UDim.new(0, Theme.Grid.EdgePadding)
gridPadding.PaddingBottom = UDim.new(0, Theme.Grid.EdgePadding)
gridPadding.PaddingLeft   = UDim.new(0, Theme.Grid.EdgePadding)
gridPadding.PaddingRight  = UDim.new(0, Theme.Grid.EdgePadding)
gridPadding.Parent        = grid

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name                   = "Empty"
emptyLabel.Size                   = UDim2.fromScale(1, 0.3)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Font                   = Enum.Font.GothamBold
emptyLabel.TextScaled             = false
emptyLabel.TextWrapped            = true
emptyLabel.TextSize               = 16
emptyLabel.TextColor3             = Theme.Grid.EmptyColor
emptyLabel.Text                   = Theme.Grid.EmptyText
emptyLabel.Visible                = false
emptyLabel.Parent                 = body

--== State ==-----------------------------------------------------------

-- Session-scoped, deliberately not saved. See the module header.
local selectedRuneId: string? = nil
local runeButtons: { [string]: any } = {}
local boxes: { [string]: any } = {}
local boxSignature = ""

local function cellSize(): UDim2
	local width = grid.AbsoluteSize.X
	local height = grid.AbsoluteSize.Y
	if width <= 0 or height <= 0 then
		return UDim2.fromOffset(180, 140)
	end

	local columns = Theme.Grid.Columns
	local inset = Theme.Grid.EdgePadding * 2
	local usableWidth = width - inset - Theme.Scroll.Thickness
	local usableHeight = height - inset
	local cellWidth = (usableWidth - Theme.Grid.Gap * (columns - 1)) / columns
	-- Height so VisibleRows fit: the half-row is what shows the grid
	-- scrolls without needing a scrollbar to be noticed.
	local cellHeight = (usableHeight - Theme.Grid.Gap * (Theme.Grid.VisibleRows - 1)) / Theme.Grid.VisibleRows

	return UDim2.fromOffset(math.max(math.floor(cellWidth), 60), math.max(math.floor(cellHeight), 60))
end

--== Boxes ==-----------------------------------------------------------

local function buildBox(runeId: string, entry: any, order: number)
	local sorted = RuneTags.SortedBoosts(entry.Boosts or {})

	local box = Instance.new("Frame")
	box.Name                   = entry.Id
	box.LayoutOrder            = order
	box.BackgroundColor3       = Theme.Grid.Color
	box.BackgroundTransparency = Theme.Grid.Transparency
	box.BorderSizePixel        = 0
	box.Parent                 = grid
	corner(box, Theme.Grid.Corner)
	borderStroke(box, Theme.Grid.BorderColor, Theme.Grid.BorderThickness, Theme.Grid.BorderTransparency)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop    = UDim.new(0, Theme.Grid.Padding)
	padding.PaddingBottom = UDim.new(0, Theme.Grid.Padding)
	padding.PaddingLeft   = UDim.new(0, Theme.Grid.Padding)
	padding.PaddingRight  = UDim.new(0, Theme.Grid.Padding)
	padding.Parent        = box

	local layout = Instance.new("UIListLayout")
	layout.SortOrder           = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding             = UDim.new(0, Theme.Grid.Spacing)
	layout.Parent              = box

	-- Weights, not heights: more boosts means thinner rows and smaller
	-- text, with the box itself never moving.
	local totalUnits = Theme.Box.NameWeight + Theme.Box.AmountWeight
		+ Theme.Box.BoostWeight * #sorted
	local unit = 1 / totalUnits

	local nameLabel = makeLabel(box, 1, unit * Theme.Box.NameWeight, Theme.Box.NameFont, Theme.Box.NameColor)
	nameLabel.Text = string.upper(entry.Name)
	RuneArt.Bind(runeId, entry.Id, { nameLabel })

	local amountLabel = makeLabel(box, 2, unit * Theme.Box.AmountWeight, Theme.Box.AmountFont, Theme.Box.AmountColor)

	local boostLabels = {}
	for index, item in sorted do
		local info = RuneTags.Get(item.Tag)
		local label = makeLabel(box, 2 + index, unit * Theme.Box.BoostWeight, Theme.Box.BoostFont, info.Color)
		-- Currency and rune-stat gradients both live under
		-- CurrencyVisuals, so one binder covers both.
		CurrencyArt.Bind(info.Art, { Labels = { label } })
		boostLabels[item.Tag] = { Label = label, Boost = item.Boost, Info = info }
	end

	return {
		Frame = box,
		TypeId = entry.Id,
		NameLabel = nameLabel,
		AmountLabel = amountLabel,
		BoostLabels = boostLabels,
		AllLabels = (function()
			local all = { nameLabel, amountLabel }
			for _, record in boostLabels do
				table.insert(all, record.Label)
			end
			return all
		end)(),
	}
end

local function paintBox(runeId: string, box: any)
	local notation = SettingsState.Get("General.NumberNotation")
	local count = RuneState.GetCount(runeId, box.TypeId)

	box.AmountLabel.Text = ("x%s"):format(BigNumber.Format(count, notation))

	for _, record in box.BoostLabels do
		local value, capped = RuneMath.GetTypeBoost(count, record.Boost)
		local text = ("%s: %.2fx"):format(record.Info.Label, value)
		text = (text:gsub("%.00x$", "x"))
		if capped then
			text ..= Theme.Box.MaxSuffix
		end
		record.Label.Text = text
	end

	for _, label in box.AllLabels do
		fit(label, Theme.Box.FillFactor)
	end
end

-- Owned types, in schema order. The signature lets the caller tell "a
-- count changed" from "a new type appeared" without diffing.
local function ownedTypes(runeId: string): ({ any }, string)
	local rune = RuneScheme.Get(runeId)
	if not rune then
		return {}, ""
	end

	local owned = {}
	for _, entry in rune.Types do
		if BigNumber.GreaterThanOrEqual(RuneState.GetCount(runeId, entry.Id), ONE) then
			table.insert(owned, entry)
		end
	end

	local ids = {}
	for _, entry in owned do
		table.insert(ids, entry.Id)
	end
	return owned, runeId .. "|" .. table.concat(ids, ",")
end

local function rebuildBoxes()
	local runeId = selectedRuneId
	if not runeId then
		return
	end

	local owned, signature = ownedTypes(runeId)
	boxSignature = signature

	for _, box in boxes do
		box.Frame:Destroy()
	end
	table.clear(boxes)

	gridLayout.CellSize = cellSize()

	for order, entry in owned do
		local box = buildBox(runeId, entry, order)
		boxes[entry.Id] = box
		paintBox(runeId, box)
	end

	emptyLabel.Visible = #owned == 0
	grid.Visible = #owned > 0

	-- AbsoluteSize is meaningless until laid out, so the first fit
	-- measures zeroes. One deferred pass lands every box.
	task.defer(function()
		for _, box in boxes do
			for _, label in box.AllLabels do
				fit(label, Theme.Box.FillFactor)
			end
		end
	end)
end

local function refreshBoxes()
	local runeId = selectedRuneId
	if not runeId then
		return
	end
	local _, signature = ownedTypes(runeId)
	if signature ~= boxSignature then
		rebuildBoxes()
		return
	end
	for _, box in boxes do
		paintBox(runeId, box)
	end
end

--== Rune list ==-------------------------------------------------------

local function paintRuneButtons()
	for runeId, button in runeButtons do
		local selected = runeId == selectedRuneId
		button.Frame.BackgroundColor3 = selected and Theme.List.ButtonSelected or Theme.List.ButtonColor
		button.Border.Color = selected and Theme.List.ButtonBorderSelected or Theme.List.ButtonBorder
		fit(button.Label, Theme.List.FillFactor)
	end
end

local function selectRune(runeId: string)
	if selectedRuneId == runeId then
		return
	end
	selectedRuneId = runeId
	paintRuneButtons()
	rebuildBoxes()
end

for order, runeId in RuneScheme.GetOrder() do
	local rune = RuneScheme.Get(runeId)

	local button = Instance.new("TextButton")
	button.Name             = runeId
	button.LayoutOrder      = order
	button.Size             = UDim2.new(1, -Theme.Scroll.Thickness, 0, Theme.List.ButtonHeight)
	button.BackgroundColor3 = Theme.List.ButtonColor
	button.BorderSizePixel  = 0
	button.AutoButtonColor  = false
	button.Text             = ""
	button.Parent           = list
	corner(button, Theme.List.ButtonCorner)
	local border = borderStroke(button, Theme.List.ButtonBorder, Theme.List.ButtonBorderThickness)

	local label = Instance.new("TextLabel")
	label.Size                   = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font                   = Theme.List.Font
	label.TextColor3             = Theme.List.TextColor
	label.TextScaled             = false
	label.TextWrapped            = false
	label.TextSize               = 16
	label.Text                   = string.upper(rune.Name)
	label.Parent                 = button
	textStroke(label, Theme.List.StrokeColor, Theme.List.StrokeThickness)

	button.MouseButton1Click:Connect(function()
		selectRune(runeId)
	end)

	runeButtons[runeId] = { Frame = button, Label = label, Border = border }
end

selectedRuneId = RuneScheme.GetOrder()[1]

--== Resize ==----------------------------------------------------------

local function resize()
	gridLayout.CellSize = cellSize()
	fit(title, Theme.Header.FillFactor)
	paintRuneButtons()
	for _, box in boxes do
		for _, label in box.AllLabels do
			fit(label, Theme.Box.FillFactor)
		end
	end
end

grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
header:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)

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
		backdrop.Visible = true
		rebuildBoxes()
		task.defer(resize)
	end

	local slideInfo = TweenInfo.new(
		open and Theme.Animation.OpenTime or Theme.Animation.CloseTime,
		open and Theme.Animation.OpenEasing or Theme.Animation.CloseEasing,
		Enum.EasingDirection.Out
	)
	track(TweenService:Create(holder, slideInfo, { Position = open and OPEN_POSITION or CLOSED_POSITION }))

	-- The fade is always Quad: a Back curve on transparency overshoots
	-- past 0, clamps, and reads as a stutter rather than as bounce.
	local fadeInfo = TweenInfo.new(
		(open and Theme.Animation.OpenTime or Theme.Animation.CloseTime) * 0.75,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local fade = track(TweenService:Create(panel, fadeInfo, { GroupTransparency = open and 0 or 1 }))
	track(TweenService:Create(backdrop, fadeInfo, {
		BackgroundTransparency = open and Theme.Backdrop.Transparency or 1,
	}))

	if not open then
		-- Generation guard: without it, spam-clicking the button leaves an
		-- in-flight close callback that fires later and hides a panel the
		-- player has already reopened.
		fade.Completed:Connect(function(state)
			if myGeneration == openGeneration and not isOpen and state == Enum.PlaybackState.Completed then
				holder.Visible = false
				backdrop.Visible = false
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
backdrop.MouseButton1Click:Connect(function()
	setOpen(false)
end)

--== Live data ==-------------------------------------------------------

RuneState.Changed.Event:Connect(function()
	if isOpen then
		refreshBoxes()
	end
end)
SettingsState.Changed:Connect(function()
	if isOpen then
		refreshBoxes()
	end
end)

paintRuneButtons()
