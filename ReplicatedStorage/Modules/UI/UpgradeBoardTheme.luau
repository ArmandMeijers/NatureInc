--!strict
--[[
	UpgradeBoardTheme.luau

	Visual knobs for UpgradeBoardUI.

	BORDERS ARE BLACK, the panel is pale green glass, the cards are a
	darker grey glass on top of it, and text is white with a dark stroke.
	The card being darker than the panel is what gives white text
	something to sit against — on a near-white card the stroke was doing
	all the work.

	Card.EdgePadding EXISTS FOR THE BORDER. A UIStroke renders outside
	its frame's bounds and a ScrollingFrame clips descendants, so without
	padding inside the strip the black outline gets sliced off at the top
	and bottom edges. Keep this >= Card.BorderThickness.

	TEXT SIZES ARE CEILINGS, not fixed values. Cards are narrow columns
	and the longest string ("5 studs -> 5.5 studs") is several times the
	width of the shortest ("x1 -> x1.18"). Everything variable is
	TextScaled with a UITextSizeConstraint capped at these numbers.

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
	Transparency       = 0.45,
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
	-- White base on purpose: the board currency's GRAD is cloned on top,
	-- and a gradient only renders true against white.
	Color            = TEXT_WHITE,
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
	-- Darker grey than the panel behind it. Two translucent surfaces the
	-- same brightness read as one surface.
	Color              = Color3.fromRGB(104, 112, 106),
	Transparency       = 0.32,
	BorderColor        = BORDER_BLACK,
	BorderThickness    = 4,
	BorderTransparency = 0,
	Padding            = 8,
	Spacing            = 6,
	Gap                = 15,

	-- Room inside the strip for the border to draw into. See the header.
	EdgePadding        = 8,

	ShadowOffset       = 4,
	ShadowColor        = Color3.fromRGB(0, 0, 0),
	ShadowTransparency = 0.82,

	MaxedTransparency  = 0.6,
}

Theme.Name = {
	Font            = Enum.Font.GothamBold,
	TextSize        = 22,
	Color           = TEXT_WHITE,
	StrokeColor     = STROKE_DARK,
	StrokeThickness = 3,
	Height          = 30,
}

Theme.Level = {
	Font            = Enum.Font.GothamMedium,
	TextSize        = 17,
	Color           = TEXT_WHITE,
	StrokeColor     = STROKE_DARK,
	StrokeThickness = 2.5,
	Height          = 22,
}

Theme.Icon = {
	-- Fills the card's leftover height as a centred square. No fixed
	-- size: a taller card should get a bigger icon, not more whitespace.
	Padding = 6,

	-- Fraction of the flex area the icon square fills. A scale rather
	-- than a pixel inset, so the icon reads the same size relative to
	-- its card whether the board is 8 studs tall or 16.
	Scale = 0.48,

	-- No fill and no outline. Icon art is mostly transparent, so a boxed
	-- frame around it would read as a separate object sitting on the
	-- card rather than as part of it — and the placeholder should occupy
	-- the same visual space the real art will.
	PlaceholderColor        = Color3.fromRGB(255, 255, 255),
	PlaceholderTransparency = 1,
	PlaceholderGlyph        = "?",
	PlaceholderTextColor    = TEXT_WHITE,
	PlaceholderCorner       = 14,
}

Theme.Value = {
	Font              = Enum.Font.GothamBold,
	MaxTextSize       = 22,
	Color             = TEXT_WHITE,
	ArrowColor        = TEXT_WHITE,
	ArrowTransparency = 0.3,
	StrokeColor       = STROKE_DARK,
	StrokeThickness   = 2.5,
	Height            = 26,
	SideScale         = 0.42,
	ArrowScale        = 0.16,
}

Theme.Cost = {
	Font              = Enum.Font.GothamBold,
	MaxTextSize       = 21,
	AmountColor       = TEXT_WHITE,
	-- Currency renders in that currency's own GRAD; this is the fallback
	-- for one with no art yet.
	CurrencyColor     = TEXT_WHITE,
	StrokeColor       = STROKE_DARK,
	StrokeThickness   = 2.5,
	MaxedTransparency = 0.35,
	MaxedText         = "MAXED",
	Height            = 26,
	AmountScale       = 0.5,
	CurrencyScale     = 0.5,
	Gap               = 4,
}

Theme.Button = {
	Height              = 46,
	Corner              = 6,
	Font                = Enum.Font.GothamBold,
	MaxTextSize         = 22,
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
