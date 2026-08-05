--!strict
--[[
	CurrencyBoardTheme.luau

	Visual knobs for CurrencyBoardUI — the standalone "icon + amount"
	part. A white translucent plate with rounded corners behind the
	contents, so it reads as a HUD element rather than as text floating
	loose against the sky.

	Location: ReplicatedStorage/Modules/UI/CurrencyBoardTheme.luau
]]

local Theme = {}

Theme.Background = {
	Enabled            = true,
	Color              = Color3.fromRGB(255, 255, 255),
	Transparency       = 0.5,
	-- Corner radius as a FRACTION of the part's height, so a short plaque
	-- and a tall banner get proportionally the same curve rather than the
	-- short one looking like a pill.
	CornerScale        = 0.32,
	BorderColor        = Color3.fromRGB(14, 18, 15),
	BorderThickness    = 3,
	BorderTransparency = 0,
	-- Inset from the part's edges, also a fraction of its height.
	PaddingScale       = 0.12,
}

Theme.IconScale = 0.9   -- fraction of the content height
Theme.IconWidth = 0.3   -- fraction of the content width reserved for it
Theme.Gap       = 0.04

Theme.Text = {
	Font            = Enum.Font.GothamBold,
	MaxTextSize     = 200, -- effectively uncapped; the part's height decides
	Color           = Color3.fromRGB(255, 255, 255), -- gradient on top
	StrokeColor     = Color3.fromRGB(26, 34, 28),
	StrokeThickness = 4,
	XAlignment      = Enum.TextXAlignment.Left,
}

return Theme
