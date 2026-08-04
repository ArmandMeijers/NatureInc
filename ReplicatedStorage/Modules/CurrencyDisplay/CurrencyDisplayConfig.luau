--!strict
--[[
	CurrencyDisplayConfig.luau

	Every visual and layout knob for the currency HUD.

	WHAT ISN'T HERE ANY MORE: an Order table and a currency list. Both
	were private copies of things the game already had. Order comes from
	CurrencyOrder, and which currencies exist comes from the same place,
	so the HUD can't disagree with the tier board about either.

	Location: ReplicatedStorage/Modules/CurrencyDisplay/CurrencyDisplayConfig.luau
]]

local Config = {}

Config.Panel = {
	AnchorPoint    = Vector2.new(1, 0.5),
	Position       = UDim2.new(1, -18, 0.5, 0),
	Width          = 240,
	MaxHeightScale = 0.55,
	DisplayOrder   = 5,
	RowSpacing     = 8,
	EdgePadding    = 6,
}

Config.ScrollBar = {
	Thickness    = 4,
	Color        = Color3.fromRGB(255, 255, 255),
	Transparency = 0.4,
	AutoHide     = true,
}

Config.Row = {
	Height       = 46,
	CornerRadius = 23,

	BackgroundColor        = Color3.fromRGB(36, 52, 40),
	BackgroundTransparency = 0.2,

	StrokeColor        = Color3.fromRGB(255, 255, 255),
	StrokeTransparency = 0.35,
	StrokeThickness    = 2.5,

	Gloss = {
		Enabled     = true,
		TopColor    = Color3.fromRGB(255, 255, 255),
		BottomColor = Color3.fromRGB(150, 190, 160),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
	},

	PaddingLeft  = 8,
	PaddingRight = 16,
	IconGap      = 8,
	IconSize     = 34,
}

Config.IconSizeOverrides = {
	-- Leafs = 36,
}

Config.Text = {
	Font               = Enum.Font.FredokaOne,
	TextSize           = 24,
	Color              = Color3.fromRGB(255, 255, 255),
	StrokeColor        = Color3.fromRGB(120, 120, 128),
	StrokeThickness    = 3.5,
	StrokeTransparency = 0,
}

Config.Pop = {
	Enabled = true,
	Scale   = 1.12,
	Time    = 0.25,
}

Config.MissingIconColor = Color3.fromRGB(70, 78, 72)

return Config
