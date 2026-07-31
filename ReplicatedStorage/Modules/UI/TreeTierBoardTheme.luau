--!strict
--[[
	TreeTierBoardTheme.luau

	Two visual presets for TreeTierBoardUI, kept as data instead of two
	copies of the whole UI module — same board logic (currency, button
	state, LiveBind wiring) either way, just different colors/layout
	knobs. Pick per-board by setting a "BoardStyle" attribute (string:
	"Glass" or "Classic") on the board Part in Studio; unset defaults to
	"Glass". No code change needed to preview both — just tag two
	different board Parts with different attributes.

	Glass: fully see-through panel (the board's own translucent Part IS
	the background), thick white border, a green/white gradient banner
	behind "Tier X", white boost text with a black outline, and a button
	that's always white with the state carried by its TEXT color
	("Tier Up" green / "Can't Tier Up" red / "Maxed Out" grey).

	Classic: a lightly frosted white card (still translucent, just less
	so — closer to the reference screenshot), a thin green border, plain
	green header text, green/gold boost rows, and a button whose PILL
	color carries the state instead (green/red/grey), with the text
	staying a fixed dark color.

	Location: ReplicatedStorage/Modules/UI/TreeTierBoardTheme.luau
]]

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

	-- Button: either the background stays fixed and TEXT color carries
	-- state (Glass), or the background itself carries state and text
	-- stays fixed (Classic). Only the relevant fields need to be set.
	ButtonUsesTextColorForState: boolean,
	ButtonBackground: Color3?,
	ButtonBorder: Color3?,
	ButtonTextCanAfford: Color3?,
	ButtonTextCannotAfford: Color3?,
	ButtonTextMaxed: Color3?,
	ButtonBackgroundCanAfford: Color3?,
	ButtonBackgroundCannotAfford: Color3?,
	ButtonBackgroundMaxed: Color3?,
	ButtonTextColor: Color3?,
}

local TreeTierBoardTheme: { [string]: BoardTheme } = {}

TreeTierBoardTheme.Glass = {
	PanelBackgroundColor3 = Color3.fromRGB(255, 255, 255),
	PanelBackgroundTransparency = 1,

	BorderColor = Color3.fromRGB(255, 255, 255),
	BorderThickness = 5,

	HeaderStyle = "banner",
	HeaderGradientStart = Color3.fromRGB(255, 255, 255),
	HeaderGradientEnd = Color3.fromRGB(120, 210, 140),
	HeaderTextColor = Color3.fromRGB(26, 54, 32),
	HeaderStrokeColor = Color3.fromRGB(255, 255, 255),

	DividerColor = Color3.fromRGB(170, 220, 180),

	BoostTextColor = Color3.fromRGB(255, 255, 255),
	BoostStrokeColor = Color3.fromRGB(20, 20, 20),

	CostTextColor = Color3.fromRGB(255, 236, 190),
	CostStrokeColor = Color3.fromRGB(255, 255, 255),

	ButtonUsesTextColorForState = true,
	ButtonBackground = Color3.fromRGB(255, 255, 255),
	ButtonBorder = Color3.fromRGB(70, 150, 95),
	ButtonTextCanAfford = Color3.fromRGB(46, 150, 75),
	ButtonTextCannotAfford = Color3.fromRGB(190, 75, 60),
	ButtonTextMaxed = Color3.fromRGB(130, 130, 130),
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

	ButtonUsesTextColorForState = false,
	ButtonBackgroundCanAfford = Color3.fromRGB(120, 210, 140),
	ButtonBackgroundCannotAfford = Color3.fromRGB(225, 140, 130),
	ButtonBackgroundMaxed = Color3.fromRGB(210, 210, 210),
	ButtonTextColor = Color3.fromRGB(35, 45, 35),
}

return TreeTierBoardTheme

