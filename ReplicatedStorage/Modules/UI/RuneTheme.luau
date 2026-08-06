--!strict
--[[
	RuneTheme.luau

	Styling for the rune panels.

	SIZES ARE IN STUDS. A BillboardGui sized in offset is a constant
	number of PIXELS: it holds its size on screen while the world shrinks
	behind it, so backing away makes it appear to swell. Sized in scale
	it's a fixed size in the WORLD, like the sign it's pretending to be.

	TEXT HAS NO SIZE HERE, only a FillFactor. A scale-sized billboard's
	pixel dimensions change with camera distance — that's how it stays
	world-locked — so any fixed TextSize or MaxTextSize is right at
	exactly one distance and wrong everywhere else. The controller
	measures each row and sizes its text to a fraction of it instead, so
	text stays a constant proportion of the panel at every distance.

	Rows are relative weights, not heights. A rune with four types and one
	with twelve both fill their panel with no per-rune number anywhere.

	Location: ReplicatedStorage/Modules/UI/RuneTheme.luau
]]

local Theme = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local STROKE = Color3.fromRGB(10, 14, 11)

Theme.Panel = {
	Color              = Color3.fromRGB(16, 20, 17),
	Transparency       = 0.2,
	Corner             = 0.05,  -- fraction of panel height
	BorderColor        = Color3.fromRGB(12, 16, 13),
	BorderThickness    = 3,
	Padding            = 0.035, -- fraction of panel height
	Spacing            = 0.006,

	-- Studs. The info panel's height grows with the number of rune types
	-- so rows keep a constant stud height rather than squashing.
	InfoWidth          = 7,
	InfoRowHeight      = 0.6,
	AffordWidth        = 6.5,
	AffordHeight       = 5,

	StudsOffset        = 6.5,
	-- Raised well clear of the ground; the rune model sits below this.
	HeightOffset       = 7,
}

-- Fraction of a row's height the text fills. The single knob for "make
-- everything bigger or smaller"; it applies to every label on both
-- panels, so they can't drift out of proportion with each other.
Theme.Text = {
	FillFactor = 0.78,
	MinSize    = 6,
}

-- Relative row weights inside the info panel.
Theme.Weights = {
	Title   = 1.5,
	Opened  = 1.0,
	Type    = 1.0,
	Rps     = 1.4,
	Caption = 0.7,
}

Theme.Title = {
	Font            = Enum.Font.GothamBold,
	Color           = WHITE,
	StrokeColor     = STROKE,
	StrokeThickness = 2.5,
}

Theme.Subtitle = {
	Font            = Enum.Font.GothamBold,
	Color           = Color3.fromRGB(190, 200, 190),
	StrokeColor     = STROKE,
	StrokeThickness = 2,
}

Theme.Row = {
	Font             = Enum.Font.GothamBold,
	Color            = WHITE, -- the type's gradient goes on top
	StrokeColor      = STROKE,
	StrokeThickness  = 2,
	UnobtainableText = "LOCKED OUT",
	UnobtainableFade = 0.45,
}

Theme.Rps = {
	Font            = Enum.Font.GothamBold,
	Color           = Color3.fromRGB(150, 235, 160),
	StrokeColor     = STROKE,
	StrokeThickness = 2.5,
	Caption         = "(RUNES PER SECOND)",
}

Theme.Afford = {
	Font            = Enum.Font.GothamBold,
	Color           = Color3.fromRGB(150, 235, 160),
	LabelColor      = Color3.fromRGB(190, 200, 190),
	StrokeColor     = STROKE,
	StrokeThickness = 2,
	Forever         = "FOREVER",
}

Theme.Gain = {
	Font            = Enum.Font.GothamBold,
	TextSize        = 26,
	Height          = 32,
	Spacing         = 2,
	StrokeColor     = STROKE,
	StrokeThickness = 3,
	Width           = 420,
	Margin          = 16,
}

return Theme
