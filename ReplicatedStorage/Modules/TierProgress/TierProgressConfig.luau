--!strict
--[[
	TierProgressConfig.luau

	Every knob for the top-of-screen tier progress bar. The controller
	hardcodes no colour, size or wording — change it here and the bar
	follows.

	The bar is full-bleed: it spans the entire screen width, sits flush
	against the very top, and has square corners. That means
	IgnoreGuiInset is on and the Roblox topbar chrome (menu button, chat)
	renders over the left end of it. That's intended — it's what makes
	the bar read as part of the screen furniture rather than as another
	floating HUD panel. If you'd rather it started below the chrome, set
	Layout.IgnoreGuiInset false; the bar stays full-width either way.

	Location: ReplicatedStorage/Modules/TierProgress/TierProgressConfig.luau
]]

local Config = {}

Config.Layout = {
	IgnoreGuiInset = true, -- sit at the literal top of the screen
	DisplayOrder   = 4,

	BarHeight     = 30,
	CaptionHeight = 20,
	CaptionGap    = 2,
}

Config.Track = {
	-- The unfilled remainder of the bar.
	Color        = Color3.fromRGB(24, 32, 28),
	Transparency = 0.25,

	-- A hairline along the bottom edge, so the bar has a defined base
	-- against the world instead of fading straight into it. Set
	-- Thickness 0 to drop it.
	EdgeThickness    = 2,
	EdgeColor        = Color3.fromRGB(255, 255, 255),
	EdgeTransparency = 0.55,
}

Config.Fill = {
	-- Working toward the next tier.
	ProgressStart = Color3.fromRGB(255, 214, 112),
	ProgressEnd   = Color3.fromRGB(226, 152, 44),
	-- Affordable: the whole bar goes green.
	ReadyStart    = Color3.fromRGB(150, 238, 156),
	ReadyEnd      = Color3.fromRGB(56, 168, 82),
	TweenTime     = 0.3,
}

Config.Text = {
	Font             = Enum.Font.FredokaOne,
	Size             = 18,
	Color            = Color3.fromRGB(255, 255, 255),
	StrokeColor      = Color3.fromRGB(24, 34, 28),
	StrokeThickness  = 2.5,
	IconSize         = 20,
	Gap              = 6,
	ShowCurrencyName = true,
	ShowIcon         = true,
	-- Shown inside the bar once the next tier is affordable, in place of
	-- the have/need numbers.
	ReadyText        = "TIER UP READY",
}

Config.Caption = {
	Font            = Enum.Font.FredokaOne,
	Size            = 15,
	Color           = Color3.fromRGB(255, 255, 255),
	StrokeColor     = Color3.fromRGB(24, 34, 28),
	StrokeThickness = 2.5,
	ReadyColor      = Color3.fromRGB(180, 255, 188),

	ProgressFormat  = "Progress to Tier %d",
	ReadyText       = "YOU CAN TIER UP",
	MaxedText       = "MAX TIER REACHED",
}

-- Hide the whole bar at max tier. Set false to keep it on screen showing
-- Caption.MaxedText over a full grey bar instead.
Config.HideWhenMaxed = true

Config.Maxed = {
	FillStart = Color3.fromRGB(206, 210, 210),
	FillEnd   = Color3.fromRGB(146, 152, 152),
}

-- A highlight sweeping left to right along the fill while a tier-up is
-- affordable, so it reads as "act on this" rather than as one more
-- static HUD element. Deliberately not a scale pulse: the bar already
-- touches both screen edges, so scaling it just clips.
Config.Shine = {
	Enabled = true,
	Time    = 1.4,
	Color   = Color3.fromRGB(255, 255, 255),
	Peak    = 0.5, -- transparency at the brightest point of the band
	Width   = 0.12, -- band half-width, as a fraction of the bar
}

return Config
