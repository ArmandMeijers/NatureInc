--!strict
--[[
	TreeTierBoardTheme.luau

	Visual presets for TreeTierBoardUI, kept as data instead of copies of
	the whole UI module — same board logic either way, just different
	palette and layout knobs. Pick per-board by setting a "BoardStyle"
	attribute (string: "Glass" or "Classic") on the board Part in Studio;
	unset defaults to "Glass".

	BUTTON PALETTE. Light text over a dark stroke, one pairing per state:
	    green   text #F4FFF0   stroke #2E7A38
	    red     text #FFF4F4   stroke #9A2222
	    grey    text #F8F8F5   stroke #5B6466
	The stroke colour is reused as the pill's border so each state reads
	as a single object rather than a light shape with unrelated text
	floating on it, and each gradient ends dark enough that the light text
	holds contrast across the whole fill instead of only over the bottom
	half. Button.Labels holds the wording — change RESET to TIER UP here
	and nowhere else.

	Unlock.MaxHeight caps the unlock badge area. A tier that reveals five
	things would otherwise grow that block until it squeezed the boost
	list to nothing and overflowed the panel; past the cap it scrolls.

	Location: ReplicatedStorage/Modules/UI/TreeTierBoardTheme.luau
]]

export type ButtonStateStyle = {
	Background: Color3,
	BackgroundEnd: Color3, -- vertical gradient partner
	Text: Color3,
	TextStroke: Color3,
	Border: Color3,
	Bar: Color3, -- progress bar fill for this state
}

export type BoardTheme = {
	Panel: {
		Color: Color3,
		Transparency: number,
		Corner: number,
		StrokeColor: Color3,
		StrokeTransparency: number,
		StrokeThickness: number,
		Padding: number,
		Spacing: number,
	},
	Header: {
		Height: number,
		Corner: number,
		GradientTop: Color3,
		GradientBottom: Color3,
		Transparency: number,
		StrokeColor: Color3,
		StrokeThickness: number,
		TextColor: Color3,
		TextStroke: Color3,
		TextStrokeThickness: number,
		SubTextColor: Color3,
	},
	Pips: {
		Height: number,
		Size: number,
		Gap: number,
		Done: Color3,
		Current: Color3,
		Todo: Color3,
		TodoTransparency: number,
	},
	Divider: { Color: Color3, Transparency: number },
	Boost: {
		RowHeight: number,
		IconSize: number,
		Gap: number,
		TextSize: number,
		NameFallback: Color3,
		ValueFallback: Color3,
		ArrowColor: Color3,
		StrokeColor: Color3,
		StrokeThickness: number,
		NextScale: number,
	},
	Unlock: {
		CaptionColor: Color3,
		CaptionSize: number,
		BadgeColor: Color3,
		BadgeTransparency: number,
		BadgeStroke: Color3,
		BadgeHeight: number,
		BadgeGap: number,
		MaxHeight: number, -- badge area caps here, then scrolls
		LabelColor: Color3,
		LabelSize: number,
		StrokeColor: Color3,
	},
	Cost: {
		TextColor: Color3,
		TextStroke: Color3,
		TextSize: number,
		BarHeight: number,
		BarBackground: Color3,
		BarBackgroundTransparency: number,
		UseCurrencyGradient: boolean,
	},
	Button: {
		Height: number,
		Corner: number,
		TextSize: number,
		TextStrokeThickness: number,
		StrokeThickness: number,
		HoverScale: number,
		Labels: {
			CanAfford: string,
			CannotAfford: string,
			Maxed: string,
		},
		States: {
			CanAfford: ButtonStateStyle,
			CannotAfford: ButtonStateStyle,
			Maxed: ButtonStateStyle,
		},
	},
}

local TreeTierBoardTheme: { [string]: BoardTheme } = {}

-- The one button palette both themes share, since it was picked to work
-- on its own terms rather than to match a panel.
local BUTTON_LABELS = {
	CanAfford = "RESET",
	CannotAfford = "CAN'T AFFORD",
	Maxed = "MAXED",
}

local BUTTON_STATES = {
	CanAfford = {
		Background = Color3.fromRGB(126, 214, 140),
		BackgroundEnd = Color3.fromRGB(52, 150, 74),
		Text = Color3.fromRGB(244, 255, 240),      -- #F4FFF0
		TextStroke = Color3.fromRGB(46, 122, 56),  -- #2E7A38
		Border = Color3.fromRGB(46, 122, 56),      -- #2E7A38
		Bar = Color3.fromRGB(126, 214, 140),
	},
	CannotAfford = {
		Background = Color3.fromRGB(232, 120, 110),
		BackgroundEnd = Color3.fromRGB(168, 48, 44),
		Text = Color3.fromRGB(255, 244, 244),      -- #FFF4F4
		TextStroke = Color3.fromRGB(154, 34, 34),  -- #9A2222
		Border = Color3.fromRGB(154, 34, 34),      -- #9A2222
		Bar = Color3.fromRGB(232, 120, 110),
	},
	Maxed = {
		Background = Color3.fromRGB(190, 196, 196),
		BackgroundEnd = Color3.fromRGB(128, 136, 136),
		Text = Color3.fromRGB(248, 248, 245),      -- #F8F8F5
		TextStroke = Color3.fromRGB(91, 100, 102), -- #5B6466
		Border = Color3.fromRGB(91, 100, 102),     -- #5B6466
		Bar = Color3.fromRGB(190, 196, 196),
	},
}

TreeTierBoardTheme.Glass = {
	Panel = {
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.82,
		Corner = 18,
		StrokeColor = Color3.fromRGB(255, 255, 255),
		StrokeTransparency = 0.15,
		StrokeThickness = 4,
		Padding = 14,
		Spacing = 8,
	},
	Header = {
		Height = 52,
		Corner = 12,
		GradientTop = Color3.fromRGB(255, 255, 255),
		GradientBottom = Color3.fromRGB(126, 214, 148),
		Transparency = 0.05,
		StrokeColor = Color3.fromRGB(255, 255, 255),
		StrokeThickness = 2,
		TextColor = Color3.fromRGB(22, 92, 48),
		TextStroke = Color3.fromRGB(255, 255, 255),
		TextStrokeThickness = 2,
		SubTextColor = Color3.fromRGB(38, 120, 66),
	},
	Pips = {
		Height = 12,
		Size = 10,
		Gap = 6,
		Done = Color3.fromRGB(120, 214, 145),
		Current = Color3.fromRGB(255, 232, 140),
		Todo = Color3.fromRGB(255, 255, 255),
		TodoTransparency = 0.6,
	},
	Divider = { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.5 },
	Boost = {
		RowHeight = 28,
		IconSize = 22,
		Gap = 6,
		TextSize = 19,
		NameFallback = Color3.fromRGB(255, 255, 255),
		ValueFallback = Color3.fromRGB(255, 255, 255),
		ArrowColor = Color3.fromRGB(255, 255, 255),
		StrokeColor = Color3.fromRGB(28, 46, 32),
		StrokeThickness = 2.5,
		NextScale = 1.15,
	},
	Unlock = {
		CaptionColor = Color3.fromRGB(255, 240, 180),
		CaptionSize = 14,
		BadgeColor = Color3.fromRGB(255, 226, 130),
		BadgeTransparency = 0.25,
		BadgeStroke = Color3.fromRGB(255, 255, 255),
		BadgeHeight = 26,
		BadgeGap = 4,
		MaxHeight = 92,
		LabelColor = Color3.fromRGB(255, 255, 255),
		LabelSize = 17,
		StrokeColor = Color3.fromRGB(96, 62, 12),
	},
	Cost = {
		TextColor = Color3.fromRGB(255, 255, 255),
		TextStroke = Color3.fromRGB(30, 48, 34),
		TextSize = 18,
		BarHeight = 8,
		BarBackground = Color3.fromRGB(20, 30, 22),
		BarBackgroundTransparency = 0.55,
		UseCurrencyGradient = true,
	},
	Button = {
		Height = 52,
		Corner = 14,
		TextSize = 26,
		TextStrokeThickness = 2.5,
		StrokeThickness = 3,
		HoverScale = 1.03,
		Labels = BUTTON_LABELS,
		States = BUTTON_STATES,
	},
}

-- Same structure, warmer and more opaque — for boards sitting against
-- busy backdrops where the glass version loses contrast.
TreeTierBoardTheme.Classic = {
	Panel = {
		Color = Color3.fromRGB(38, 58, 42),
		Transparency = 0.25,
		Corner = 16,
		StrokeColor = Color3.fromRGB(146, 214, 160),
		StrokeTransparency = 0.1,
		StrokeThickness = 3,
		Padding = 14,
		Spacing = 8,
	},
	Header = {
		Height = 52,
		Corner = 12,
		GradientTop = Color3.fromRGB(168, 232, 182),
		GradientBottom = Color3.fromRGB(74, 158, 96),
		Transparency = 0,
		StrokeColor = Color3.fromRGB(238, 255, 242),
		StrokeThickness = 2,
		TextColor = Color3.fromRGB(255, 255, 255),
		TextStroke = Color3.fromRGB(24, 74, 40),
		TextStrokeThickness = 2.5,
		SubTextColor = Color3.fromRGB(228, 250, 232),
	},
	Pips = {
		Height = 12,
		Size = 10,
		Gap = 6,
		Done = Color3.fromRGB(150, 232, 168),
		Current = Color3.fromRGB(255, 224, 122),
		Todo = Color3.fromRGB(220, 236, 224),
		TodoTransparency = 0.65,
	},
	Divider = { Color = Color3.fromRGB(160, 210, 172), Transparency = 0.35 },
	Boost = {
		RowHeight = 28,
		IconSize = 22,
		Gap = 6,
		TextSize = 19,
		NameFallback = Color3.fromRGB(255, 255, 255),
		ValueFallback = Color3.fromRGB(255, 236, 176),
		ArrowColor = Color3.fromRGB(214, 236, 220),
		StrokeColor = Color3.fromRGB(22, 40, 26),
		StrokeThickness = 2.5,
		NextScale = 1.15,
	},
	Unlock = {
		CaptionColor = Color3.fromRGB(255, 232, 158),
		CaptionSize = 14,
		BadgeColor = Color3.fromRGB(240, 200, 96),
		BadgeTransparency = 0.15,
		BadgeStroke = Color3.fromRGB(255, 248, 220),
		BadgeHeight = 26,
		BadgeGap = 4,
		MaxHeight = 92,
		LabelColor = Color3.fromRGB(255, 255, 255),
		LabelSize = 17,
		StrokeColor = Color3.fromRGB(88, 56, 8),
	},
	Cost = {
		TextColor = Color3.fromRGB(238, 250, 240),
		TextStroke = Color3.fromRGB(20, 38, 24),
		TextSize = 18,
		BarHeight = 8,
		BarBackground = Color3.fromRGB(16, 28, 18),
		BarBackgroundTransparency = 0.35,
		UseCurrencyGradient = true,
	},
	Button = {
		Height = 52,
		Corner = 14,
		TextSize = 26,
		TextStrokeThickness = 2.5,
		StrokeThickness = 3,
		HoverScale = 1.03,
		Labels = BUTTON_LABELS,
		States = BUTTON_STATES,
	},
}

return TreeTierBoardTheme
