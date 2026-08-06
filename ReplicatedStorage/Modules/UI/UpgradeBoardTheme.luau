--!strict
--[[
	UpgradeBoardTheme.luau

	Visual knobs for UpgradeBoardUI.

	TEXT SIZES HERE ARE REAL SIZES. Every card label renders at exactly
	the number below and only shrinks if its row is too narrow to fit it.
	They were previously ceilings on TextScaled labels — "fill your box,
	but no larger than this" — and since the boxes are short fixed-height
	rows, the ceilings were never reached and the numbers had no effect.

	Rows are sized to fit their text with a little headroom. A row
	shorter than its TextSize will clip; keep Height >= TextSize + 6.

	BORDERS ARE BLACK, the panel is pale green glass, the cards a darker
	grey glass on top, text white with a dark stroke. The card being
	darker than the panel is what gives white text something to sit
	against.

	Card.EdgePadding EXISTS FOR THE BORDER: a UIStroke renders outside its
	frame and a ScrollingFrame clips descendants, so without padding
	inside the strip the black outline gets sliced off. Keep it >=
	Card.BorderThickness.

	CARD WIDTH IS DERIVED: padded strip height x AspectRatio. Board height
	is the constant in this game, so a wider board fits MORE cards rather
	than stretching the ones it has.

	Location: ReplicatedStorage/Modules/UI/UpgradeBoardTheme.luau
]]

local Theme = {}

local TEXT_WHITE = Color3.fromRGB(255, 255, 255)
local STROKE_DARK = Color3.fromRGB(26, 34, 28)
local BORDER_BLACK = Color3.fromRGB(14, 18, 15)

Theme.Panel = {
	Color              = Color3.fromRGB(238, 250, 238),
	Transparency       = 1,
	Corner             = 18,
	BorderColor        = BORDER_BLACK,
	BorderThickness    = 5,
	BorderTransparency = 0,
	Padding            = 14,
	Spacing            = 8,
}

Theme.Title = {
	Height           = 48,
	Font             = Enum.Font.GothamBold,
	TextSize         = 34,
	Color            = TEXT_WHITE, -- the board currency's GRAD goes on top
	StrokeColor      = STROKE_DARK,
	StrokeThickness  = 3,
	RuleColor        = BORDER_BLACK,
	RuleTransparency = 0.15,
	RuleThickness    = 3,
	RuleWidthScale   = 0.45,
}

Theme.Card = {
	AspectRatio        = 0.68,
	MinWidth           = 140,
	MaxWidth           = 300,

	Corner             = 14,
	Color              = Color3.fromRGB(104, 112, 106),
	Transparency       = 0.32,
	BorderColor        = BORDER_BLACK,
	BorderThickness    = 4,
	BorderTransparency = 0,
	Padding            = 8,
	Spacing            = 6,
	Gap                = 15,
	EdgePadding        = 8,

	ShadowOffset       = 4,
	ShadowColor        = Color3.fromRGB(0, 0, 0),
	ShadowTransparency = 0.82,

	MaxedTransparency  = 0.6,
}

Theme.Name = {
	Font            = Enum.Font.GothamBold,
	TextSize        = 26,
	Height          = 34,
	Color           = TEXT_WHITE,
	StrokeColor     = STROKE_DARK,
	StrokeThickness = 3,
}

Theme.Level = {
	Font            = Enum.Font.GothamBold,
	TextSize        = 21,
	Height          = 28,
	Color           = TEXT_WHITE,
	StrokeColor     = STROKE_DARK,
	StrokeThickness = 2.5,
}

Theme.Icon = {
	-- Fraction of the flex area the icon square fills. A scale rather
	-- than a pixel inset, so the icon reads the same size relative to its
	-- card whether the board is 8 studs tall or 16.
	Scale = 0.48,

	-- No fill and no outline. Icon art is mostly transparent, so a boxed
	-- frame would read as a separate object sitting on the card.
	PlaceholderColor        = Color3.fromRGB(255, 255, 255),
	PlaceholderTransparency = 1,
	PlaceholderGlyph        = "?",
	PlaceholderTextColor    = TEXT_WHITE,
	PlaceholderCorner       = 14,
}

Theme.Value = {
	Font              = Enum.Font.GothamBold,
	TextSize          = 24,
	Height            = 32,
	Gap               = 6,
	Color             = TEXT_WHITE,
	ArrowColor        = TEXT_WHITE,
	ArrowTransparency = 0.3,
	StrokeColor       = STROKE_DARK,
	StrokeThickness   = 2.5,
}

Theme.Cost = {
	Font              = Enum.Font.GothamBold,
	TextSize          = 24,
	Height            = 32,
	Gap               = 6,
	AmountColor       = TEXT_WHITE,
	-- The currency name renders in that currency's own GRAD; this is the
	-- fallback for one with no art yet.
	CurrencyColor     = TEXT_WHITE,
	StrokeColor       = STROKE_DARK,
	StrokeThickness   = 2.5,
	MaxedTransparency = 0.35,
	MaxedText         = "MAXED",
}

Theme.Button = {
	Height              = 46,
	Corner              = 6,
	Font                = Enum.Font.GothamBold,
	TextSize            = 22,
	StrokeThickness     = 3,
	TextStrokeThickness = 2,
	Gap                 = 5,

	BuyLabel = "BUY",
	MaxLabel = "MAX",

	States = {
		CanAfford = {
			Background    = Color3.fromRGB(126, 214, 140),
			BackgroundEnd = Color3.fromRGB(52, 150, 74),
			Text          = Color3.fromRGB(244, 255, 240), -- #F4FFF0
			TextStroke    = Color3.fromRGB(46, 122, 56),   -- #2E7A38
			Border        = BORDER_BLACK,
		},
		CannotAfford = {
			Background    = Color3.fromRGB(232, 120, 110),
			BackgroundEnd = Color3.fromRGB(168, 48, 44),
			Text          = Color3.fromRGB(255, 244, 244), -- #FFF4F4
			TextStroke    = Color3.fromRGB(154, 34, 34),   -- #9A2222
			Border        = BORDER_BLACK,
		},
		Maxed = {
			Background    = Color3.fromRGB(190, 196, 196),
			BackgroundEnd = Color3.fromRGB(128, 136, 136),
			Text          = Color3.fromRGB(248, 248, 245), -- #F8F8F5
			TextStroke    = Color3.fromRGB(91, 100, 102),  -- #5B6466
			Border        = BORDER_BLACK,
		},
	},
}

Theme.ScrollBar = {
	Thickness    = 6,
	HandleColor  = BORDER_BLACK,
	Transparency = 0.3,
}

return Theme
