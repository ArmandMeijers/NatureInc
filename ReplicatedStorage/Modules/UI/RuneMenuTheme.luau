--!strict
--[[
	RuneMenuTheme.luau

	Styling for the runes menu. Dark, because the content is coloured
	rarity names and gradient boost lines and they need something dark to
	read against — the same reason the world-space rune panels are dark.

	TEXT SIZES ARE FILL FRACTIONS, not pixel sizes. Boxes are a constant
	size and the number of lines inside varies with how many stats a rune
	boosts, so a fixed size would either overflow the six-boost types or
	waste the one-boost ones. The controller measures each row and sizes
	text to a fraction of it.

	Location: ReplicatedStorage/Modules/UI/RuneMenuTheme.luau
]]

local Theme = {}

local WHITE = Color3.fromRGB(240, 245, 240)
local MUTED = Color3.fromRGB(150, 162, 152)
local STROKE = Color3.fromRGB(8, 11, 9)

Theme.Icon = {
	Size        = 56,
	AnchorPoint = Vector2.new(0, 1),
	-- Above the settings gear, which sits at (18, -18).
	Position    = UDim2.new(0, 18, 1, -86),
	Glyph       = "◆",
	GlyphColor  = WHITE,
	HoverScale  = 1.1,
	ClickScale  = 0.94,
}

Theme.Backdrop = {
	Color        = Color3.fromRGB(6, 10, 7),
	Transparency = 0.45,
}

Theme.Panel = {
	WidthScale   = 0.62,
	HeightScale  = 0.66,
	MinWidth     = 520,
	MinHeight    = 340,
	MaxWidth     = 980,
	MaxHeight    = 660,

	Color              = Color3.fromRGB(14, 18, 15),
	Transparency       = 0.06,
	Corner             = 16,
	BorderColor        = Color3.fromRGB(96, 190, 112),
	BorderThickness    = 3,
	BorderTransparency = 0.35,
	Padding            = 16,
}

Theme.Header = {
	Height          = 52,
	Title           = "RUNES",
	Font            = Enum.Font.GothamBold,
	FillFactor      = 0.72,
	Color           = WHITE,
	StrokeColor     = STROKE,
	StrokeThickness = 2,

	CloseSize        = 32,
	CloseGlyph       = "X",
	CloseColor       = Color3.fromRGB(26, 32, 27),
	CloseHoverColor  = Color3.fromRGB(58, 78, 62),
	CloseTextColor   = MUTED,
	CloseHoverText   = WHITE,
	CloseBorderColor = Color3.fromRGB(70, 92, 74),
	CloseClickScale  = 0.86,
}

Theme.List = {
	WidthScale      = 0.26,
	Gap             = 14,
	DividerColor    = Color3.fromRGB(70, 92, 74),
	DividerWidth    = 2,
	DividerTransparency = 0.4,

	ButtonHeight    = 46,
	ButtonSpacing   = 8,
	ButtonCorner    = 8,
	ButtonColor     = Color3.fromRGB(22, 28, 23),
	ButtonSelected  = Color3.fromRGB(34, 52, 38),
	ButtonBorder    = Color3.fromRGB(70, 92, 74),
	ButtonBorderSelected = Color3.fromRGB(120, 220, 132),
	ButtonBorderThickness = 2,
	Font            = Enum.Font.GothamBold,
	FillFactor      = 0.42,
	TextColor       = WHITE,
	StrokeColor     = STROKE,
	StrokeThickness = 2,
}

Theme.Grid = {
	Columns      = 2,
	-- How many rows fit in the visible area. 1.5 leaves the next row
	-- half-showing, which is what tells a player the grid scrolls.
	VisibleRows  = 2,
	Gap          = 12,

	-- Room inside the scroll areas for the boxes' borders to draw
	-- into. A UIStroke renders outside its frame and a
	-- ScrollingFrame clips descendants, so without this the
	-- outlines get sliced off at the edges. Keep it >=
	-- BorderThickness.
	EdgePadding  = 6,

	Color              = Color3.fromRGB(20, 26, 21),
	Transparency       = 0.05,
	Corner             = 10,
	BorderColor        = Color3.fromRGB(70, 92, 74),
	BorderThickness    = 2,
	BorderTransparency = 0,
	Padding            = 10,
	Spacing            = 2,

	EmptyText  = "ROLL THIS RUNE TO SEE ITS BOOSTS HERE",
	EmptyColor = MUTED,
}

-- Relative row weights inside a box. More boosts means more rows, which
-- means every row gets thinner and the text with it.
Theme.Box = {
	NameWeight   = 1.35,
	AmountWeight = 0.9,
	BoostWeight  = 1.0,

	FillFactor   = 0.74,
	MinTextSize  = 6,

	NameFont     = Enum.Font.GothamBold,
	NameColor    = WHITE, -- the type's gradient goes on top

	AmountFont   = Enum.Font.GothamBold,
	AmountColor  = MUTED,

	BoostFont    = Enum.Font.GothamBold,
	BoostColor   = WHITE, -- the tag's gradient goes on top

	StrokeColor     = STROKE,
	StrokeThickness = 2,

	MaxSuffix       = "  [MAX]",
	MaxColor        = Color3.fromRGB(255, 226, 130),
}

Theme.Scroll = {
	Thickness   = 5,
	HandleColor = Color3.fromRGB(96, 190, 112),
	Transparency = 0.2,
}

Theme.Animation = {
	OpenTime    = 0.3,
	CloseTime   = 0.2,
	OpenEasing  = Enum.EasingStyle.Back,
	CloseEasing = Enum.EasingStyle.Quad,
}

return Theme
