--!strict
--[[
	SettingsMenuConfig.luau

	Every visual, layout and copy knob for the settings menu.

	PALETTE -- frosted glass with nature accents.

	    Window            #F4F5F3   at 90%
	    Window border     #D2D7D2
	    Cards             #FAFAF9   at 98%
	    Card border       #D9DDD8
	    Accent green      #6FAE72   (hover #7FC783, pressed #5E9C63)
	    Dark text         #2E342E
	    Secondary text    #7A827A
	    Disabled          #BFC5BF
	    Divider           #D8DDD8   at 50%
	    Button background #EDF6EE

	THE HIERARCHY IS THE POINT. Only the window frame is translucent; the
	cards sit nearly solid on top of it. Making everything equally
	translucent is what flattened the previous version -- with no opacity
	difference between the frame and the things inside it, nothing reads
	as being ON anything else.

	Green is reserved for things you can interact with: toggles, the
	Num. format button, section titles and the header divider. Nothing
	static is green.

	Location: ReplicatedStorage/Modules/Settings/SettingsMenuConfig.luau
]]

local Config = {}

Config.Palette = {
	Window        = Color3.fromRGB(244, 245, 243), -- #F4F5F3
	WindowBorder  = Color3.fromRGB(210, 215, 210), -- #D2D7D2
	Card          = Color3.fromRGB(250, 250, 249), -- #FAFAF9
	CardBorder    = Color3.fromRGB(217, 221, 216), -- #D9DDD8
	Accent        = Color3.fromRGB(111, 174, 114), -- #6FAE72
	AccentHover   = Color3.fromRGB(127, 199, 131), -- #7FC783
	AccentPressed = Color3.fromRGB(94, 156, 99),   -- #5E9C63
	TextDark      = Color3.fromRGB(46, 52, 46),    -- #2E342E
	TextSecondary = Color3.fromRGB(122, 130, 122), -- #7A827A
	Disabled      = Color3.fromRGB(191, 197, 191), -- #BFC5BF
	Divider       = Color3.fromRGB(216, 221, 216), -- #D8DDD8
	ButtonFill    = Color3.fromRGB(237, 246, 238), -- #EDF6EE
}

Config.Icon = {
	Image       = "rbxassetid://17368089841",
	Size        = 56,
	AnchorPoint = Vector2.new(0, 1),
	Position    = UDim2.new(0, 18, 1, -18),
	HoverScale  = 1.1,
	ClickScale  = 0.94,
}

Config.Backdrop = {
	Enabled      = true,
	Color        = Color3.fromRGB(14, 20, 16),
	Transparency = 0.55,
	ClickToClose = true,
}

Config.Panel = {
	WidthScale  = 0.4,
	MinWidth    = 340,
	MaxWidth    = 560,
	HeightScale = 0.7,
	MinHeight   = 320,
	MaxHeight   = 620,

	Corner = 22,

	-- Flat #F4F5F3 at 90%. Painted on an inner Frame, never on the
	-- CanvasGroup: a UIGradient on a CanvasGroup tints every child.
	GradientTop    = Color3.fromRGB(244, 245, 243),
	GradientBottom = Color3.fromRGB(244, 245, 243),
	Transparency   = 0.1,

	BorderColor        = Color3.fromRGB(210, 215, 210),
	BorderThickness    = 2.5,
	BorderTransparency = 0,

	-- A single white line inside the top edge. Catches light from above
	-- and is most of what separates "frosted glass" from "grey box".
	TopHighlightEnabled      = true,
	TopHighlightColor        = Color3.fromRGB(255, 255, 255),
	TopHighlightTransparency = 0.45,
	TopHighlightThickness    = 2,
	TopHighlightInset        = 18,

	-- The green bloom is off. It fought the frosted look, and the
	-- window's own border does the separation job now.
	GlowEnabled      = false,
	GlowColor        = Color3.fromRGB(111, 174, 114),
	GlowTransparency = 0.9,
	GlowSpread       = 14,

	Padding = 16,
	Spacing = 10,
}

Config.Header = {
	Title    = "SETTINGS",
	Height   = 58,
	Corner   = 14,
	Font     = Enum.Font.GothamBold,
	TextSize = 24,

	-- The plate behind the title.
	PlateColor        = Color3.fromRGB(231, 236, 231), -- #E7ECE7
	PlateTransparency = 0.15,

	TextColor       = Color3.fromRGB(47, 71, 52),      -- #2F4734
	StrokeColor     = Color3.fromRGB(255, 255, 255),
	StrokeThickness = 0,                                -- clean, no outline

	RuleThickness    = 2,
	RuleColor        = Color3.fromRGB(167, 215, 174),  -- #A7D7AE
	RuleTransparency = 0,
	RuleInset        = 0.16,

	-- "X", not "✕": Gotham has no glyph for the heavy multiplication
	-- sign and renders the missing-character box instead.
	CloseGlyph          = "X",
	CloseSize           = 30,
	CloseInset          = 10,
	CloseColor          = Color3.fromRGB(244, 245, 244), -- #F4F5F4
	CloseTransparency   = 0,
	CloseHoverColor     = Color3.fromRGB(220, 235, 221), -- #DCEBDD
	CloseBorderColor    = Color3.fromRGB(210, 215, 210),
	CloseTextColor      = Color3.fromRGB(80, 97, 80),    -- #506150
	CloseHoverTextColor = Color3.fromRGB(47, 71, 52),
	CloseTextSize       = 16,
	CloseClickScale     = 0.86,
}

Config.Section = {
	CaptionFont      = Enum.Font.GothamBold,
	CaptionSize      = 13,
	CaptionColor     = Color3.fromRGB(94, 139, 99),   -- #5E8B63
	Height           = 40,
	SpacingAbove     = 10,
	RuleThickness    = 1,
	RuleColor        = Color3.fromRGB(216, 221, 216), -- #D8DDD8
	RuleTransparency = 0.5,
}

-- The surface the cards sit on, between them and the window.
Config.CardArea = {
	Enabled      = true,
	Color        = Color3.fromRGB(238, 241, 238), -- #EEF1EE
	Transparency = 0.65,                           -- 35% opacity
	Corner       = 14,
	Padding      = 8,
}

Config.Card = {
	Height       = 56,
	Corner       = 14,
	Color        = Color3.fromRGB(250, 250, 249), -- #FAFAF9
	Transparency = 0.02,                           -- nearly solid
	HoverLift    = 0.02,

	BorderColor        = Color3.fromRGB(217, 221, 216), -- #D9DDD8
	BorderThickness    = 1.5,
	BorderTransparency = 0,

	-- rgba(0, 0, 0, .08)
	ShadowOffset       = 3,
	ShadowColor        = Color3.fromRGB(0, 0, 0),
	ShadowTransparency = 0.92,

	PaddingLeft  = 14,
	PaddingRight = 12,

	IconSize = 26,
	IconGap  = 10,

	NameFont  = Enum.Font.GothamMedium,
	NameSize  = 15,
	NameColor = Color3.fromRGB(46, 52, 46),        -- #2E342E

	DescriptionFont  = Enum.Font.Gotham,
	DescriptionSize  = 11,
	DescriptionColor = Color3.fromRGB(122, 130, 122), -- #7A827A

	CurrencyStrokeColor     = Color3.fromRGB(46, 52, 46),
	CurrencyStrokeThickness = 1,
}

Config.Toggle = {
	Width       = 54,
	Height      = 26,
	KnobPadding = 3,
	OnColor     = Color3.fromRGB(124, 198, 127), -- #7CC67F
	OffColor    = Color3.fromRGB(216, 220, 216), -- #D8DCD8
	KnobColor   = Color3.fromRGB(255, 255, 255),
	BorderColor = Color3.fromRGB(210, 215, 210),
	BorderThickness = 1.5,
	LabelFont   = Enum.Font.GothamBold,
	LabelSize   = 10,
	OnLabelColor  = Color3.fromRGB(255, 255, 255),
	OffLabelColor = Color3.fromRGB(128, 128, 128), -- #808080
	TweenTime   = 0.16,
}

Config.Choice = {
	Width        = 96,
	Height       = 28,
	Corner       = 14,
	Color        = Color3.fromRGB(237, 246, 238), -- #EDF6EE
	HoverColor   = Color3.fromRGB(221, 242, 224), -- #DDF2E0
	PressedColor = Color3.fromRGB(94, 156, 99),   -- #5E9C63
	Transparency = 0,
	BorderColor  = Color3.fromRGB(143, 200, 149), -- #8FC895
	BorderThickness = 1.5,
	Font         = Enum.Font.GothamBold,
	TextSize     = 12,
	TextColor    = Color3.fromRGB(63, 115, 68),   -- #3F7344
	PressedTextColor = Color3.fromRGB(255, 255, 255),
	HoverScale   = 1.04,
}

Config.ScrollBar = {
	Thickness         = 6,
	TrackColor        = Color3.fromRGB(216, 221, 216),
	TrackTransparency = 0.5,
	HandleColor       = Color3.fromRGB(111, 174, 114), -- #6FAE72
}

Config.Animation = {
	OpenTime    = 0.34,
	CloseTime   = 0.22,
	OpenEasing  = Enum.EasingStyle.Back,
	CloseEasing = Enum.EasingStyle.Quad,
}

Config.RowDescriptions = {
	["General.HideMaxUpgrades"] = "Hide upgrades you've already maxed out.",
	["General.HidePlayers"]     = "Make other players invisible.",
	["General.NumberNotation"]  = "How large numbers are written.",
	["Audio.Music"]             = "Background music while playing.",
	["Audio.SoundEffects"]      = "Clicks, collects and other effects.",
}
Config.CurrencyDescriptionFormat = "Show %s in the currency display."

return Config
