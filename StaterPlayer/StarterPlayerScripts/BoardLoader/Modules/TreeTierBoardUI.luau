--[[
	TreeTierBoardUI.luau

	Mounts the physical-but-local Tree Tier board: a SurfaceGui adorned to
	a world Part but parented into THIS client's PlayerGui -- so the board
	looks physical and shared, but every player sees their own tier data
	on it. Mounted by BoardLoaderController for any Part with
	BoardType == "TreeTier".

	Visuals live in TreeTierBoardTheme (ReplicatedStorage/Modules/UI) --
	this file builds ONE board using whichever theme is passed in, so
	"Glass" and "Classic" aren't two copies of this logic drifting apart
	over time. BoardLoaderController picks the theme from the board
	Part's "BoardStyle" attribute (defaults to "Glass" if unset).

	Currency is fully dynamic -- nothing here assumes Compost. The cost
	line, the afford check, and the button state all come from
	TreeTierState.Balance / .BalanceCurrency, which track whatever
	currency TreeTierConfig says the NEXT tier actually costs.

	The Tier Up button's pill color AND text color both carry state now
	(CanAfford / CannotAfford / Maxed), each theme-defined per state, with
	an optional black text outline for definition against a bright/glass
	background. Text says exactly what's going on ("RESET" / "CAN'T
	RESET" / "MAX") instead of relying on color alone -- "RESET" because
	tiering up is literally what resets your Leafs/Compost back to zero.

	Cost text is wired through LiveBind (ReplicatedStorage/Modules/UI/
	LiveBind) so it re-formats immediately if the player changes their
	Number Notation setting mid-session, on top of updating on tier/
	balance changes -- one Bind call, no manual settings-signal wiring.

	Boost row NAME text (Leafs/Compost/Nuts) pulls its color from
	ReplicatedStorage.CurrencyVisuals.<name>.<name>GRAD when that
	UIGradient exists -- each currency renders in its own branded
	gradient instead of a flat color. Falls back to the theme's flat
	BoostNameColor for any currency without art yet.

	Location: StarterPlayer/StarterPlayerScripts/BoardLoader/Modules/TreeTierBoardUI.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)
local TreeTierState = require(ReplicatedStorage.Modules.TreeTierState)
local SettingsState = require(ReplicatedStorage.Modules.SettingsState)
local LiveBind = require(ReplicatedStorage.Modules.UI.LiveBind)
local BoardThemes = require(ReplicatedStorage.Modules.UI.TreeTierBoardTheme)

local LocalPlayer = Players.LocalPlayer

local currencyVisuals = ReplicatedStorage:WaitForChild("CurrencyVisuals")

local DISPLAY_ORDER = { "Leafs", "Compost", "Nuts" }
local DEFAULT_STYLE = "Glass"

local function formatBoost(entry)
	if not entry then
		return "—"
	elseif entry.Type == "Additive" then
		return "+" .. tostring(entry.Amount)
	elseif entry.Type == "Power" then
		return "^" .. tostring(entry.Amount)
	end
	return tostring(entry.Amount) .. "x" -- Multiplicative
end

local function addStroke(label: TextLabel, color: Color3, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 1.25
	stroke.Color = color
	stroke.Parent = label
end

-- Looks for ReplicatedStorage.CurrencyVisuals.<name>.<name>GRAD (e.g.
-- CurrencyVisuals.Leafs.LeafsGRAD) and, if it's a real UIGradient, clones
-- it onto `label` so this currency's name always renders in its own
-- branded gradient instead of a flat theme color. Falls back silently
-- (theme color stays as-is) for any currency that doesn't have art yet --
-- e.g. Nuts still growing out its visuals per your CurrencyVisuals tree.
local function applyCurrencyGradient(label: TextLabel, currencyName: string): boolean
	local currencyFolder = currencyVisuals:FindFirstChild(currencyName)
	local gradientTemplate = currencyFolder and currencyFolder:FindFirstChild(currencyName .. "GRAD")
	if gradientTemplate and gradientTemplate:IsA("UIGradient") then
		label.TextColor3 = Color3.new(1, 1, 1) -- gradient renders truest against a white base
		local gradient = gradientTemplate:Clone()
		gradient.Parent = label
		return true
	end
	return false
end

local TreeTierBoardUI = {}

function TreeTierBoardUI.Mount(boardPart: BasePart)
	local styleName = boardPart:GetAttribute("BoardStyle")
	local theme = (styleName and BoardThemes[styleName]) or BoardThemes[DEFAULT_STYLE]

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("SurfaceGui")
	gui.Name = "TreeTierGui"
	gui.Adornee = boardPart
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = theme.PanelBackgroundColor3
	panel.BackgroundTransparency = theme.PanelBackgroundTransparency
	panel.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.BorderColor
	stroke.Thickness = theme.BorderThickness
	stroke.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = panel

	-- Header -----------------------------------------------------------
	local header: TextLabel
	if theme.HeaderStyle == "banner" then
		local headerBanner = Instance.new("Frame")
		headerBanner.Name = "HeaderBanner"
		headerBanner.LayoutOrder = 1
		headerBanner.Size = UDim2.new(1, 0, 0, 46)
		headerBanner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		headerBanner.BorderSizePixel = 0
		headerBanner.Parent = panel

		local headerCorner = Instance.new("UICorner")
		headerCorner.CornerRadius = UDim.new(0, 10)
		headerCorner.Parent = headerBanner

		local headerGradient = Instance.new("UIGradient")
		headerGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.HeaderGradientStart or Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, theme.HeaderGradientEnd or Color3.fromRGB(120, 210, 140)),
		})
		headerGradient.Rotation = 90
		headerGradient.Parent = headerBanner

		header = Instance.new("TextLabel")
		header.Size = UDim2.fromScale(1, 1)
		header.BackgroundTransparency = 1
		header.Parent = headerBanner
	else
		header = Instance.new("TextLabel")
		header.LayoutOrder = 1
		header.Size = UDim2.new(1, 0, 0, 40)
		header.BackgroundTransparency = 1
		header.Parent = panel
	end
	header.Name = "Header"
	header.Font = Enum.Font.FredokaOne
	header.TextColor3 = theme.HeaderTextColor
	header.TextScaled = true
	header.Text = "Tier 1"
	addStroke(header, theme.HeaderStrokeColor, 1.25)

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.LayoutOrder = 2
	divider.Size = UDim2.new(1, 0, 0, 2)
	divider.BackgroundColor3 = theme.DividerColor
	divider.BorderSizePixel = 0
	divider.Parent = panel

	-- Boost list (scrollable so it never overflows) ------------------------
	local boostList = Instance.new("ScrollingFrame")
	boostList.Name = "BoostList"
	boostList.LayoutOrder = 3
	boostList.Size = UDim2.new(1, 0, 1, -170)
	boostList.BackgroundTransparency = 1
	boostList.BorderSizePixel = 0
	boostList.ScrollBarThickness = 6
	boostList.ScrollBarImageColor3 = theme.DividerColor
	boostList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	boostList.CanvasSize = UDim2.new(0, 0, 0, 0)
	boostList.Parent = panel

	local boostLayout = Instance.new("UIListLayout")
	boostLayout.SortOrder = Enum.SortOrder.LayoutOrder
	boostLayout.Padding = UDim.new(0, 6)
	boostLayout.Parent = boostList

	-- Cost + button ---------------------------------------------------------
	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.LayoutOrder = 4
	costLabel.Size = UDim2.new(1, 0, 0, 40)
	costLabel.BackgroundTransparency = 1
	costLabel.Font = Enum.Font.GothamMedium
	costLabel.TextColor3 = theme.CostTextColor
	costLabel.TextScaled = true
	costLabel.Text = ""
	costLabel.Parent = panel
	addStroke(costLabel, theme.CostStrokeColor)

	local button = Instance.new("TextButton")
	button.Name = "TierUpButton"
	button.LayoutOrder = 5
	button.Size = UDim2.new(1, 0, 0, 56)
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.AutoButtonColor = false
	button.Active = true
	button.Text = "RESET"
	button.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = button

	if theme.ButtonBorder then
		local buttonStroke = Instance.new("UIStroke")
		buttonStroke.Color = theme.ButtonBorder
		buttonStroke.Thickness = 2
		buttonStroke.Parent = button
	end

	local buttonTextStroke: UIStroke? = nil

	local buttonState = "CannotAfford"

	local function setButtonState(state: "CanAfford" | "CannotAfford" | "Maxed", text: string)
		buttonState = state
		button.Text = text

		local style = theme.ButtonStates[state]
		button.BackgroundColor3 = style.Background
		button.TextColor3 = style.Text

		if style.Stroke then
			if not buttonTextStroke then
				buttonTextStroke = Instance.new("UIStroke")
				buttonTextStroke.Thickness = 1.25
				buttonTextStroke.Parent = button
			end
			buttonTextStroke.Color = style.Stroke
			buttonTextStroke.Enabled = true
		elseif buttonTextStroke then
			buttonTextStroke.Enabled = false
		end
	end

	local function buildRow(name: string, current, next_)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundTransparency = 1

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextColor3 = theme.BoostNameColor or theme.BoostTextColor or Color3.fromRGB(255, 255, 255)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextScaled = true
		nameLabel.Text = name
		nameLabel.Parent = row
		addStroke(nameLabel, theme.BoostStrokeColor, 1.25)
		applyCurrencyGradient(nameLabel, name)

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0.6, 0, 1, 0)
		valueLabel.Position = UDim2.new(0.4, 0, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.TextColor3 = theme.BoostValueColor or theme.BoostTextColor or Color3.fromRGB(255, 255, 255)
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.TextScaled = true
		valueLabel.Text = if next_ then formatBoost(current) .. "  ->  " .. formatBoost(next_) else formatBoost(current)
		valueLabel.Parent = row
		addStroke(valueLabel, theme.BoostStrokeColor, 1.25)

		return row
	end

	-- Rebuilds the boost rows and sets the button's text/color/state.
	-- Header text and cost text are handled separately below via
	-- LiveBind -- those are simple property updates, not a row rebuild.
	local function refreshBoard()
		local tier = TreeTierState.Tier
		local currentData = TreeTierConfig[tier]
		local nextData = TreeTierConfig[tier + 1]

		for _, child in boostList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		for i, key in DISPLAY_ORDER do
			local currentBoost = currentData.Boosts and currentData.Boosts[key]
			local nextBoost = nextData and nextData.Boosts and nextData.Boosts[key]
			if currentBoost or nextBoost then
				local row = buildRow(key, currentBoost, nextBoost)
				row.LayoutOrder = i
				row.Parent = boostList
			end
		end

		if not nextData then
			setButtonState("Maxed", "MAX")
		elseif TreeTierState.BalanceCurrency == nextData.Cost.Currency
			and BigNumber.GreaterThanOrEqual(TreeTierState.Balance, nextData.Cost.Amount) then
			setButtonState("CanAfford", "RESET")
		else
			setButtonState("CannotAfford", "CAN'T RESET")
		end
	end

	button.MouseButton1Click:Connect(function()
		if buttonState == "CanAfford" then
			TreeTierState.RequestTierUp()
		end
	end)

	TreeTierState.TierChanged.Event:Connect(refreshBoard)
	TreeTierState.BalanceChanged.Event:Connect(refreshBoard)
	refreshBoard()

	-- Single-property bindings via LiveBind, instead of more hand-rolled
	-- refresh() wiring. Cost text also listens for SettingsState.Changed,
	-- so it reformats immediately if the player flips Number Notation
	-- mid-session -- no other file needs to know about that.
	LiveBind.Bind(header, "Text", function()
		return "Tier " .. TreeTierState.Tier
	end, { TreeTierState.TierChanged.Event })

	LiveBind.Bind(costLabel, "Text", function()
		local nextData = TreeTierConfig[TreeTierState.Tier + 1]
		if not nextData then
			return ""
		end
		local notation = SettingsState.Get("General.NumberNotation")
		return "Cost: " .. BigNumber.Format(nextData.Cost.Amount, notation) .. " " .. nextData.Cost.Currency
	end, { TreeTierState.TierChanged.Event, TreeTierState.BalanceChanged.Event, SettingsState.Changed })
end

return TreeTierBoardUI