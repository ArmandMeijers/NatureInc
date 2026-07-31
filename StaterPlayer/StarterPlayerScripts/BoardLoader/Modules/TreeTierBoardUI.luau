--[[
	TreeTierBoardUI.luau

	Mounts the physical-but-local Tree Tier board: a SurfaceGui adorned to
	a world Part but parented into THIS client's PlayerGui — so the board
	looks physical and shared, but every player sees their own tier data
	on it. Mounted by BoardLoaderController for any Part with
	BoardType == "TreeTier".

	The board Part itself should be white + translucent (Glass material —
	set in the kit builder). This GUI draws NO background of its own —
	text sits directly on that glass, with a UIStroke per label for
	legibility instead of a solid panel fill.

	Currency name text (Leafs / Compost / Nuts) pulls its color from
	ReplicatedStorage.CurrencyVisuals.<key> if a UIGradient exists there —
	that's the same folder/name convention your CurrencyVisuals folder
	already uses, so once you drop gradients in there this picks them up
	automatically. Falls back to a plain forest green until then.

	Location: StarterPlayer/StarterPlayerScripts/BoardLoader/Modules/TreeTierBoardUI.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)
local TreeTierState = require(ReplicatedStorage.Modules.TreeTierState)

local LocalPlayer = Players.LocalPlayer

-- Names here match ReplicatedStorage.CurrencyVisuals.<name> exactly, so
-- lookups just index straight in.
local DISPLAY_ORDER = { "Leafs", "Compost", "Nuts" }

local COLORS = {
	Border = Color3.fromRGB(32, 58, 38), -- dark forest green frame
	Header = Color3.fromRGB(255, 255, 255),
	RowLabelFallback = Color3.fromRGB(120, 210, 135), -- used until CurrencyVisuals has a gradient for that key
	RowValue = Color3.fromRGB(255, 214, 110), -- warm gold for the numbers/arrows
	TextStroke = Color3.fromRGB(18, 28, 18), -- near-black outline so text reads on bright glass
	CannotAfford = Color3.fromRGB(178, 88, 68),
	CanAfford = Color3.fromRGB(78, 178, 102),
	Maxed = Color3.fromRGB(128, 128, 120),
}

local currencyVisualsRoot = ReplicatedStorage:FindFirstChild("CurrencyVisuals")

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

local function addStroke(label: TextLabel, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 1.25
	stroke.Color = COLORS.TextStroke
	stroke.Parent = label
end

-- Looks for ReplicatedStorage.CurrencyVisuals.<key>'s UIGradient and clones
-- it onto the label; falls back to a flat color if that currency doesn't
-- have visuals set up yet.
local function applyCurrencyTextStyle(label: TextLabel, key: string)
	local existing = label:FindFirstChild("CurrencyGradient")
	if existing then
		existing:Destroy()
	end

	local sourceFolder = currencyVisualsRoot and currencyVisualsRoot:FindFirstChild(key)
	local sourceGradient = sourceFolder and sourceFolder:FindFirstChildOfClass("UIGradient")

	if sourceGradient then
		local clone = sourceGradient:Clone()
		clone.Name = "CurrencyGradient"
		clone.Parent = label
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		label.TextColor3 = COLORS.RowLabelFallback
	end
end

local TreeTierBoardUI = {}

function TreeTierBoardUI.Mount(boardPart: BasePart)
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("SurfaceGui")
	gui.Name = "TreeTierGui"
	gui.Adornee = boardPart
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	-- No background of our own — the board Part (white, translucent glass)
	-- IS the background. This frame only exists to lay children out.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Border
	stroke.Thickness = 3
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

	-- Header ---------------------------------------------------------------
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, 44)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.FredokaOne
	header.TextColor3 = COLORS.Header
	header.TextScaled = true
	header.Text = "Tier 1"
	header.Parent = panel
	addStroke(header, 1.75)

	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 235, 170))
	headerGradient.Rotation = 90
	headerGradient.Parent = header

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.LayoutOrder = 2
	divider.Size = UDim2.new(1, 0, 0, 2)
	divider.BackgroundColor3 = COLORS.Border
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
	boostList.ScrollBarImageColor3 = COLORS.Border
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
	costLabel.Size = UDim2.new(1, 0, 0, 32)
	costLabel.BackgroundTransparency = 1
	costLabel.Font = Enum.Font.GothamMedium
	costLabel.TextColor3 = COLORS.Header
	costLabel.TextScaled = true
	costLabel.Text = ""
	costLabel.Parent = panel
	addStroke(costLabel)

	local button = Instance.new("TextButton")
	button.Name = "TierUpButton"
	button.LayoutOrder = 5
	button.Size = UDim2.new(1, 0, 0, 56)
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.AutoButtonColor = false
	button.Text = "Tier Up"
	button.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = COLORS.Border
	buttonStroke.Thickness = 2
	buttonStroke.Parent = button

	local buttonState = "CannotAfford"

	local function buildRow(name: string, current, next_)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundTransparency = 1

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextScaled = true
		nameLabel.Text = name
		nameLabel.Parent = row
		addStroke(nameLabel)
		applyCurrencyTextStyle(nameLabel, name)

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0.6, 0, 1, 0)
		valueLabel.Position = UDim2.new(0.4, 0, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.TextColor3 = COLORS.RowValue
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.TextScaled = true
		valueLabel.Text = if next_ then formatBoost(current) .. "  ->  " .. formatBoost(next_) else formatBoost(current)
		valueLabel.Parent = row
		addStroke(valueLabel)

		return row
	end

	local function refresh()
		local tier = TreeTierState.Tier
		local currentData = TreeTierConfig[tier]
		local nextData = TreeTierConfig[tier + 1]

		header.Text = "Tier " .. tier

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
			costLabel.Text = ""
			buttonState = "Maxed"
			button.Text = "Maxed"
			button.BackgroundColor3 = COLORS.Maxed
		else
			local cost = nextData.Cost
			costLabel.Text = "Cost: " .. BigNumber.Format(cost.Amount) .. " " .. cost.Currency

			if BigNumber.GreaterThanOrEqual(TreeTierState.Compost, cost.Amount) then
				buttonState = "CanAfford"
				button.Text = "Tier Up"
				button.BackgroundColor3 = COLORS.CanAfford
			else
				buttonState = "CannotAfford"
				button.Text = "Tier Up"
				button.BackgroundColor3 = COLORS.CannotAfford
			end
		end
	end

	button.MouseButton1Click:Connect(function()
		if buttonState == "CanAfford" then
			TreeTierState.RequestTierUp()
		end
	end)

	TreeTierState.TierChanged.Event:Connect(refresh)
	TreeTierState.CompostChanged.Event:Connect(refresh)
	refresh()
end

return TreeTierBoardUI