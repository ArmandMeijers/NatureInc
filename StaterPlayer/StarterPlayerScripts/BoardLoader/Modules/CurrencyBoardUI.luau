--[[
	CurrencyBoardUI.luau

	A standalone "icon + amount" part: the currency's PNG pinned left, the
	player's balance centred on the plate in that currency's gradient.
	Mounted by BoardLoaderController for any Part with
	BoardType == "CurrencyBoard" and a Currency attribute.

	The part should be Transparency = 1 — a SurfaceGui renders regardless
	of its adornee, and the plate here is the background, not the brick.

	TEXT SIZE IS DERIVED FROM HEIGHT, NOT TextScaled. TextScaled means
	"fill your box", and this box is the plate minus icon clearance on
	both sides — most of the plate gone, so the number came out tiny with
	no knob to turn, since the box decides and the theme doesn't. Height
	is the right input: two plates of the same height should show the same
	size number whatever their width. Width is applied afterwards as a
	shrink pass, so a long balance still fits.

	THE AMOUNT IS CENTRED ON THE PLATE, not in the space beside the icon —
	those are different positions and the second reads as a mistake. Its
	padding is the icon's clearance on BOTH sides: symmetric padding keeps
	its centre on the plate's centre while guaranteeing the text can never
	slide under the icon.

	Location: StarterPlayer/StarterPlayerScripts/BoardLoader/Modules/CurrencyBoardUI.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local BigNumber          = require(Modules:WaitForChild("BigNumber"))
local CurrencyStatsState = require(Modules:WaitForChild("CurrencyStatsState"))
local SettingsState      = require(Modules:WaitForChild("SettingsState"))
local LiveBind           = require(Modules:WaitForChild("UI"):WaitForChild("LiveBind"))
local CurrencyArt        = require(Modules:WaitForChild("UI"):WaitForChild("CurrencyArt"))
local Theme              = require(Modules:WaitForChild("UI"):WaitForChild("CurrencyBoardTheme"))

local LocalPlayer = Players.LocalPlayer

local ZERO = BigNumber.new(0, 0)

local CurrencyBoardUI = {}

function CurrencyBoardUI.Mount(boardPart: BasePart)
	local currencyName = boardPart:GetAttribute("Currency")
	if type(currencyName) ~= "string" then
		warn(`CurrencyBoardUI: {boardPart:GetFullName()} has no Currency attribute — nothing to show.`)
		return
	end

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("SurfaceGui")
	gui.Name = "CurrencyBoardGui_" .. currencyName
	gui.Adornee = boardPart
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Name                   = "Background"
	background.Size                   = UDim2.fromScale(1, 1)
	background.BackgroundColor3       = Theme.Background.Color
	background.BackgroundTransparency = Theme.Background.Enabled and Theme.Background.Transparency or 1
	background.BorderSizePixel        = 0
	background.Parent                 = gui

	local corner = Instance.new("UICorner")
	corner.Parent = background

	if Theme.Background.Enabled then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Theme.Background.BorderColor
		stroke.Thickness = Theme.Background.BorderThickness
		stroke.Transparency = Theme.Background.BorderTransparency
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = background
	end

	local platePadding = Instance.new("UIPadding")
	platePadding.Parent = background

	local content = Instance.new("Frame")
	content.Name                   = "Content"
	content.Size                   = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.Parent                 = background

	local icon = Instance.new("ImageLabel")
	icon.Name                   = "Icon"
	icon.AnchorPoint            = Vector2.new(0, 0.5)
	icon.Position               = UDim2.fromScale(0, 0.5)
	icon.Size                   = UDim2.fromScale(Theme.IconWidth, Theme.IconScale)
	icon.BackgroundTransparency = 1
	icon.ScaleType              = Enum.ScaleType.Fit
	icon.ZIndex                 = 2
	icon.Parent                 = content

	local amount = Instance.new("TextLabel")
	amount.Name                   = "Amount"
	amount.AnchorPoint            = Vector2.new(0.5, 0.5)
	amount.Position               = UDim2.fromScale(0.5, 0.5)
	amount.Size                   = UDim2.fromScale(1, 1)
	amount.BackgroundTransparency = 1
	amount.Font                   = Theme.Text.Font
	amount.TextColor3             = Theme.Text.Color
	amount.TextXAlignment         = Enum.TextXAlignment.Center
	-- NOT TextScaled: the size is computed from the plate's height below.
	amount.TextScaled             = false
	amount.TextWrapped            = false
	amount.TextSize               = 24
	amount.Text                   = "0"
	amount.Parent                 = content

	-- Equal on both sides on purpose. Padding only on the icon's side
	-- would clear the icon but shift the text's centre off the plate's.
	local amountPadding = Instance.new("UIPadding")
	amountPadding.Parent = amount

	local amountStroke = Instance.new("UIStroke")
	amountStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	amountStroke.Color = Theme.Text.StrokeColor
	amountStroke.LineJoinMode = Enum.LineJoinMode.Round
	amountStroke.Thickness = Theme.Text.MinStroke
	amountStroke.Parent = amount

	-- Height sets the size, width only ever shrinks it. Called after any
	-- resize AND after the text changes, since a longer balance needs
	-- re-measuring — but never from a signal on the text itself, which
	-- would be a feedback loop.
	local function fitText()
		local contentSize = content.AbsoluteSize
		if contentSize.Y <= 0 then
			return
		end

		local baseSize = math.max(
			Theme.Text.MinTextSize,
			math.floor(contentSize.Y * Theme.Text.HeightScale)
		)
		amount.TextSize = baseSize
		amountStroke.Thickness = math.max(Theme.Text.MinStroke, contentSize.Y * Theme.Text.StrokeScale)

		local clearance = math.ceil(contentSize.X * (Theme.IconWidth + Theme.Gap))
		amountPadding.PaddingLeft = UDim.new(0, clearance)
		amountPadding.PaddingRight = UDim.new(0, clearance)

		local available = contentSize.X - clearance * 2
		local measured = amount.TextBounds.X
		if available > 0 and measured > available then
			amount.TextSize = math.max(
				Theme.Text.MinTextSize,
				math.floor(baseSize * available / measured)
			)
		end
	end

	local function resizePlate()
		local height = background.AbsoluteSize.Y
		corner.CornerRadius = UDim.new(0, math.floor(height * Theme.Background.CornerScale))

		local inset = UDim.new(0, math.floor(height * Theme.Background.PaddingScale))
		platePadding.PaddingTop = inset
		platePadding.PaddingBottom = inset
		platePadding.PaddingLeft = inset
		platePadding.PaddingRight = inset

		fitText()
	end

	background:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizePlate)
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitText)
	resizePlate()

	-- Icon and gradient both stay bound, so re-tinting the currency's
	-- GRAD updates this part without a rejoin.
	CurrencyArt.Bind(currencyName, { Icons = { icon }, Labels = { amount } })

	-- Watch rather than Bind: the text has to be refitted after it
	-- changes, and Bind would only assign the property.
	LiveBind.Watch(function()
		local balance = CurrencyStatsState.Balances[currencyName] or ZERO
		return BigNumber.Format(balance, SettingsState.Get("General.NumberNotation"))
	end, { CurrencyStatsState.Changed.Event, SettingsState.Changed }, function(text)
		amount.Text = text
		fitText()
	end)

	-- TextBounds is only meaningful once the label has been laid out, so
	-- the first fit measures zeroes. One deferred pass lands it.
	task.defer(fitText)
end

return CurrencyBoardUI
