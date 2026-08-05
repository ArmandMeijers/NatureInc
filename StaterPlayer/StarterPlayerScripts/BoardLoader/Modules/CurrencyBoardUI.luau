--[[
	CurrencyBoardUI.luau

	A standalone "icon + amount" part: the currency's PNG on the left, the
	player's balance on the right in that currency's gradient, on a white
	translucent plate. Mounted by BoardLoaderController for any Part with
	BoardType == "CurrencyBoard" and a Currency attribute.

	The part itself should be Transparency = 1 — a SurfaceGui renders
	regardless, and the plate here is the background, not the brick.

	Everything is proportional to the part, INCLUDING the corner radius
	and padding. A fixed pixel radius makes a short plaque look like a
	pill and a tall banner look square; scaling it off the height keeps
	one module usable at any size without a per-board setting.

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

	local padding = Instance.new("UIPadding")
	padding.Parent = background

	-- Radius and padding both track the part's real height, so the plate
	-- keeps its proportions whatever size you make the board.
	local function resize()
		local height = background.AbsoluteSize.Y
		corner.CornerRadius = UDim.new(0, math.floor(height * Theme.Background.CornerScale))
		local inset = UDim.new(0, math.floor(height * Theme.Background.PaddingScale))
		padding.PaddingTop = inset
		padding.PaddingBottom = inset
		padding.PaddingLeft = inset
		padding.PaddingRight = inset
	end
	background:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

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
	icon.Parent                 = content

	local amount = Instance.new("TextLabel")
	amount.Name                   = "Amount"
	amount.AnchorPoint            = Vector2.new(1, 0.5)
	amount.Position               = UDim2.fromScale(1, 0.5)
	amount.Size                   = UDim2.fromScale(1 - Theme.IconWidth - Theme.Gap, 1)
	amount.BackgroundTransparency = 1
	amount.Font                   = Theme.Text.Font
	amount.TextScaled             = true
	amount.TextColor3             = Theme.Text.Color
	amount.TextXAlignment         = Theme.Text.XAlignment
	amount.Text                   = "0"
	amount.Parent                 = content

	local amountConstraint = Instance.new("UITextSizeConstraint")
	amountConstraint.MaxTextSize = Theme.Text.MaxTextSize
	amountConstraint.MinTextSize = 8
	amountConstraint.Parent = amount

	local amountStroke = Instance.new("UIStroke")
	amountStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	amountStroke.Color = Theme.Text.StrokeColor
	amountStroke.Thickness = Theme.Text.StrokeThickness
	amountStroke.LineJoinMode = Enum.LineJoinMode.Round
	amountStroke.Parent = amount

	-- Icon and gradient both stay bound, so re-tinting the currency's
	-- GRAD updates this part without a rejoin.
	CurrencyArt.Bind(currencyName, { Icons = { icon }, Labels = { amount } })

	LiveBind.Bind(amount, "Text", function()
		local balance = CurrencyStatsState.Balances[currencyName] or ZERO
		return BigNumber.Format(balance, SettingsState.Get("General.NumberNotation"))
	end, { CurrencyStatsState.Changed.Event, SettingsState.Changed })
end

return CurrencyBoardUI
