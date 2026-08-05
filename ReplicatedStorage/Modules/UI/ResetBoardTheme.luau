--!strict
--[[
	ResetBoardTheme.luau

	Visual knobs for ResetBoardUI. Same language as the upgrade board:
	pale green glass panel, thick black borders, white text with a dark
	stroke. The button palette is the shared green/red one so "you can
	afford this" looks identical everywhere in the game.

	Location: ReplicatedStorage/Modules/UI/ResetBoardTheme.luau
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
	Padding            = 16,
	Spacing            = 10,
}

Theme.Title = {
	Height           = 54,
	Font             = Enum.Font.GothamBold,
	TextSize         = 38,
	Color            = TEXT_WHITE, -- gradient is cloned on top
	StrokeColor      = STROKE_DARK,
	StrokeThickness  = 3,
	RuleColor        = BORDER_BLACK,
	RuleTransparency = 0.15,
	RuleThickness    = 3,
	RuleWidthScale   = 0.5,
}

Theme.Icon = {
	-- Fraction of the flex area the icon fills. It's the centrepiece of
	-- this board, so it gets more of it than an upgrade card's does.
	Scale = 0.82,
}

Theme.Payout = {
	Height          = 46,
	Font            = Enum.Font.GothamBold,
	MaxTextSize     = 40,
	Color           = TEXT_WHITE, -- output currency's gradient on top
	StrokeColor     = STROKE_DARK,
	StrokeThickness = 3,
}

Theme.Status = {
	Height          = 26,
	Font            = Enum.Font.GothamBold,
	MaxTextSize     = 20,
	Color           = TEXT_WHITE,
	StrokeColor     = STROKE_DARK,
	StrokeThickness = 2.5,
	CannotAffordText = "CAN'T AFFORD",
}

Theme.Button = {
	Height              = 56,
	Corner              = 8,
	Font                = Enum.Font.GothamBold,
	MaxTextSize         = 26,
	StrokeThickness     = 3,
	TextStrokeThickness = 2,

	AffordLabel      = "RESET",
	CannotAffordLabel = "CAN'T AFFORD",

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
	},
}

return Theme
