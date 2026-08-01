--!strict
--[[
	TreeTierBoardTheme.luau

	Two visual presets for TreeTierBoardUI, kept as data instead of two
	copies of the whole UI module -- same board logic (currency, button
	state, LiveBind wiring) either way, just different colors/layout
	knobs. Pick per-board by setting a "BoardStyle" attribute (string:
	"Glass" or "Classic") on the board Part in Studio; unset defaults to
	"Glass".

	ButtonStates holds one {Background, Text, Stroke?} triple per button
	state (CanAfford / CannotAfford / Maxed) -- both the pill color AND
	the text color carry the state now, with an optional black outline on
	the text for definition against a bright/glass background. Stroke is
	optional per state; omit it for a theme that doesn't want one.

	Location: ReplicatedStorage/Modules/UI/TreeTierBoardTheme.luau
]]

export type ButtonStateStyle = {
	Background: Color3,
	Text: Color3,
	Stroke: Color3?,
}

export type BoardTheme = {
	PanelBackgroundColor3: Color3,
	PanelBackgroundTransparency: number,
	BorderColor: Color3,
	BorderThickness: number,

	HeaderStyle: "banner" | "text",
	HeaderGradientStart: Color3?,
	HeaderGradientEnd: Color3?,
	HeaderTextColor: Color3,
	HeaderStrokeColor: Color3,

	DividerColor: Color3,

	BoostTextColor: Color3?, -- used for BOTH name + value if Name/Value below are omitted
	BoostNameColor: Color3?,
	BoostValueColor: Color3?,
	BoostStrokeColor: Color3,

	CostTextColor: Color3,
	CostStrokeColor: Color3,

	ButtonBorder: Color3?, -- the pill's own outer border, separate from per-state text stroke
	ButtonStates: {
		CanAfford: ButtonStateStyle,
		CannotAfford: ButtonStateStyle,
		Maxed: ButtonStateStyle,
	},
}

local TreeTierBoardTheme: { [string]: BoardTheme } = {}

TreeTierBoardTheme.Glass = {
	PanelBackgroundColor3 = Color3.fromRGB(255, 255, 255),
	PanelBackgroundTransparency = 0.88,

	BorderColor = Color3.fromRGB(255, 255, 255),
	BorderThickness = 5,

	HeaderStyle = "banner",
	HeaderGradientStart = Color3.fromRGB(255, 255, 255),
	HeaderGradientEnd = Color3.fromRGB(120, 210, 140),
	HeaderTextColor = Color3.fromRGB(20, 110, 55),
	HeaderStrokeColor = Color3.fromRGB(255, 255, 255),

	DividerColor = Color3.fromRGB(170, 220, 180),

	BoostTextColor = Color3.fromRGB(255, 255, 255),
	BoostStrokeColor = Color3.fromRGB(20, 20, 20),

	CostTextColor = Color3.fromRGB(255, 236, 190),
	CostStrokeColor = Color3.fromRGB(255, 255, 255),

	ButtonBorder = nil,
	ButtonStates = {
		CanAfford = {
			Background = Color3.fromRGB(200, 235, 205),
			Text = Color3.fromRGB(30, 110, 55),
			Stroke = Color3.fromRGB(15, 15, 15),
		},
		CannotAfford = {
			Background = Color3.fromRGB(240, 205, 200),
			Text = Color3.fromRGB(150, 45, 40),
			Stroke = Color3.fromRGB(15, 15, 15),
		},
		Maxed = {
			Background = Color3.fromRGB(225, 225, 225),
			Text = Color3.fromRGB(90, 90, 90),
			Stroke = Color3.fromRGB(15, 15, 15),
		},
	},
}

TreeTierBoardTheme.Classic = {
	PanelBackgroundColor3 = Color3.fromRGB(255, 255, 255),
	PanelBackgroundTransparency = 0.22,

	BorderColor = Color3.fromRGB(70, 120, 80),
	BorderThickness = 2,

	HeaderStyle = "text",
	HeaderTextColor = Color3.fromRGB(55, 145, 85),
	HeaderStrokeColor = Color3.fromRGB(255, 255, 255),

	DividerColor = Color3.fromRGB(210, 225, 210),

	BoostNameColor = Color3.fromRGB(90, 200, 120),
	BoostValueColor = Color3.fromRGB(235, 190, 90),
	BoostStrokeColor = Color3.fromRGB(35, 55, 35),

	CostTextColor = Color3.fromRGB(70, 90, 75),
	CostStrokeColor = Color3.fromRGB(255, 255, 255),

	ButtonBorder = nil,
	ButtonStates = {
		CanAfford = { Background = Color3.fromRGB(120, 210, 140), Text = Color3.fromRGB(35, 45, 35) },
		CannotAfford = { Background = Color3.fromRGB(225, 140, 130), Text = Color3.fromRGB(35, 45, 35) },
		Maxed = { Background = Color3.fromRGB(210, 210, 210), Text = Color3.fromRGB(35, 45, 35) },
	},
}

return TreeTierBoardTheme

