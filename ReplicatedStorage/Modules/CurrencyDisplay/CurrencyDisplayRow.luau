--!strict
--[[
	CurrencyDisplayRow.luau

	Builds one HUD row -- icon first, amount second -- entirely from
	CurrencyDisplayConfig. Knows nothing about currency values, settings
	or visibility rules; CurrencyDisplayController owns all of that and
	just calls SetText / SetVisible / Pop.

	The frame auto-sizes on X so the pill hugs its text: "20" gets a
	short pill, "1.24e18" gets a long one, and both stay flush to the
	right edge of the panel.

	NOTE ON THE ICON: no UICorner, no ClipsDescendants, nothing that
	masks it. UICorner clips an ImageLabel's IMAGE, not just its
	background, and the source art runs corner to corner -- a circular
	corner radius shaved the tips clean off the leaf. If an icon needs to
	sit differently against the others, size it via
	Config.IconSizeOverrides rather than reaching for a mask.

	Location: ReplicatedStorage/Modules/CurrencyDisplay/CurrencyDisplayRow.luau
]]

local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("CurrencyDisplayConfig"))

local Row = {}
Row.__index = Row

export type Row = typeof(setmetatable({} :: any, Row))

function Row.new(currencyName: string, parent: Instance, layoutOrder: number): Row
	local self = setmetatable({}, Row)
	self.CurrencyName = currencyName

	local rowConfig = Config.Row
	local iconSize = Config.IconSizeOverrides[currencyName] or rowConfig.IconSize

	local frame = Instance.new("Frame")
	frame.Name                   = currencyName .. "Row"
	frame.LayoutOrder            = layoutOrder
	frame.Size                   = UDim2.new(0, 0, 0, rowConfig.Height)
	frame.AutomaticSize          = Enum.AutomaticSize.X
	frame.BackgroundColor3       = rowConfig.BackgroundColor
	frame.BackgroundTransparency = rowConfig.BackgroundTransparency
	frame.BorderSizePixel        = 0
	frame.ClipsDescendants       = false
	frame.Visible                = false
	frame.Parent                 = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, rowConfig.CornerRadius)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color        = rowConfig.StrokeColor
	stroke.Transparency = rowConfig.StrokeTransparency
	stroke.Thickness    = rowConfig.StrokeThickness
	stroke.Parent       = frame

	if rowConfig.Gloss.Enabled then
		local gloss = Instance.new("UIGradient")
		gloss.Name = "Gloss"
		gloss.Rotation = 90
		gloss.Color = ColorSequence.new(rowConfig.Gloss.TopColor, rowConfig.Gloss.BottomColor)
		gloss.Transparency = rowConfig.Gloss.Transparency
		gloss.Parent = frame
	end

	local scale = Instance.new("UIScale")
	scale.Parent = frame
	self.Scale = scale

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft  = UDim.new(0, rowConfig.PaddingLeft)
	padding.PaddingRight = UDim.new(0, rowConfig.PaddingRight)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection       = Enum.FillDirection.Horizontal
	layout.VerticalAlignment   = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder           = Enum.SortOrder.LayoutOrder
	layout.Padding             = UDim.new(0, rowConfig.IconGap)
	layout.Parent = frame

	-- 1. ICON
	local icon = Instance.new("ImageLabel")
	icon.Name                   = "Icon"
	icon.LayoutOrder            = 1
	icon.Size                   = UDim2.fromOffset(iconSize, iconSize)
	icon.BackgroundTransparency = 1
	icon.ClipsDescendants       = false
	icon.ScaleType              = Enum.ScaleType.Fit
	icon.Parent                 = frame

	-- 2. AMOUNT
	local amount = Instance.new("TextLabel")
	amount.Name                   = "AmountLabel"
	amount.LayoutOrder            = 2
	amount.Size                   = UDim2.new(0, 0, 1, 0)
	amount.AutomaticSize          = Enum.AutomaticSize.X
	amount.BackgroundTransparency = 1
	amount.Font                   = Config.Text.Font
	amount.TextSize               = Config.Text.TextSize
	amount.TextColor3             = Config.Text.Color
	amount.TextXAlignment         = Enum.TextXAlignment.Left
	amount.TextYAlignment         = Enum.TextYAlignment.Center
	amount.Text                   = "0"
	amount.Parent                 = frame

	local textStroke = Instance.new("UIStroke")
	textStroke.Name            = "AmountStroke"
	textStroke.Color           = Config.Text.StrokeColor
	textStroke.Thickness       = Config.Text.StrokeThickness
	textStroke.Transparency    = Config.Text.StrokeTransparency
	textStroke.LineJoinMode    = Enum.LineJoinMode.Round
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent          = amount

	self.Frame  = frame
	self.Icon   = icon
	self.Amount = amount

	return self
end

function Row:SetText(text: string)
	self.Amount.Text = text
end

function Row:SetVisible(visible: boolean)
	self.Frame.Visible = visible
end

function Row:IsVisible(): boolean
	return self.Frame.Visible
end

function Row:Pop()
	if not Config.Pop.Enabled then
		return
	end
	self.Scale.Scale = Config.Pop.Scale
	TweenService:Create(
		self.Scale,
		TweenInfo.new(Config.Pop.Time, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

function Row:Destroy()
	self.Frame:Destroy()
end

return Row
