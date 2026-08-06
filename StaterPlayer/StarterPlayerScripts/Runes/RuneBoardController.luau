--!strict
--[[
	RuneBoardController.client.luau

	Two billboards either side of a rune: rarity odds and totals on the
	left, affordability on the right.

	MOUNTS ON A "RunePanels" ATTRIBUTE, not on RuneId. Both the anchor and
	the pad carry RuneId — the pad needs it so the server knows which rune
	it rolls — so keying panels off RuneId built two overlapping sets.
	There's a per-rune guard on top, since a model with several tagged
	parts should still get one set.

	SIZED IN SCALE, i.e. studs, so the frame is world-locked.

	TEXT IS SIZED MANUALLY, and that's the subtle part. A scale-sized
	billboard's AbsoluteSize in pixels CHANGES with camera distance —
	that's exactly how it holds its size in the world. TextScaled derives
	from that pixel box, so it tracks distance correctly right up until a
	UITextSizeConstraint clamps it, at which point the frame holds still
	and the text doesn't. Measuring each row and sizing text to a fraction
	of it has no cap to hit, so the proportion is constant at every
	distance.

	The fit runs on the panel's AbsoluteSize signal (which fires as you
	move) and after any text change. It can't feed back: rows are sized in
	scale, so changing a TextSize never changes the box it was measured
	from.

	LOCKED RUNES HIDE THEIR PANELS. These live in PlayerGui rather than on
	the rune, so the visibility controller reparenting the anchor out of
	Workspace doesn't take them along — they check UnlockState themselves.

	Location: StarterPlayer/StarterPlayerScripts/Runes/RuneBoardController.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local BigNumber          = require(Modules:WaitForChild("BigNumber"))
local CurrencyStatsState = require(Modules:WaitForChild("CurrencyStatsState"))
local SettingsState      = require(Modules:WaitForChild("SettingsState"))
local RuneArt            = require(Modules:WaitForChild("UI"):WaitForChild("RuneArt"))
local Theme              = require(Modules:WaitForChild("UI"):WaitForChild("RuneTheme"))
local UnlockState        = require(Modules:WaitForChild("Unlocks"):WaitForChild("UnlockState"))

local RunesModules = Modules:WaitForChild("Runes")
local RuneConfig = require(RunesModules:WaitForChild("RuneConfig"))
local RuneScheme = require(RunesModules:WaitForChild("RuneScheme"))
local RuneMath   = require(RunesModules:WaitForChild("RuneMath"))
local RuneState  = require(RunesModules:WaitForChild("RuneState"))

local LocalPlayer = Players.LocalPlayer
local ZERO = BigNumber.new(0, 0)

--== Builders ==--------------------------------------------------------

local function stroke(label: Instance, color: Color3, thickness: number)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	uiStroke.Color = color
	uiStroke.Thickness = thickness
	uiStroke.LineJoinMode = Enum.LineJoinMode.Round
	uiStroke.Parent = label
end

-- Height is a FRACTION of the panel; the text size is decided later by
-- fitPanel. NOT TextScaled — see the module header.
local function row(parent: Instance, order: number, heightScale: number, style: any, color: Color3?): TextLabel
	local text = Instance.new("TextLabel")
	text.LayoutOrder            = order
	text.Size                   = UDim2.new(1, 0, heightScale, 0)
	text.BackgroundTransparency = 1
	text.Font                   = style.Font
	text.TextScaled             = false
	text.TextWrapped            = false
	text.TextSize               = 20 -- placeholder; fitPanel decides
	text.TextColor3             = color or style.Color
	text.Text                   = ""
	text.Parent                 = parent

	stroke(text, style.StrokeColor, style.StrokeThickness)
	return text
end

-- Sizes every label to a fraction of its own measured row, then shrinks
-- any that would overrun the panel's width. One pass, no cap.
local function fitPanel(panel: Frame, labels: { TextLabel })
	local available = panel.AbsoluteSize.X
	if available <= 0 then
		return
	end

	for _, label in labels do
		local height = label.AbsoluteSize.Y
		if height > 0 then
			local base = math.max(Theme.Text.MinSize, math.floor(height * Theme.Text.FillFactor))
			label.TextSize = base

			local measured = label.TextBounds.X
			if measured > available and measured > 0 then
				label.TextSize = math.max(
					Theme.Text.MinSize,
					math.floor(base * available / measured)
				)
			end
		end
	end
end

local function makePanel(adornee: BasePart, name: string, widthStuds: number, heightStuds: number, xOffset: number): (BillboardGui, Frame)
	local billboard = Instance.new("BillboardGui")
	billboard.Name           = name
	billboard.Adornee        = adornee
	billboard.AlwaysOnTop    = false
	billboard.LightInfluence = 0
	billboard.Size           = UDim2.fromScale(widthStuds, heightStuds)
	billboard.StudsOffset    = Vector3.new(xOffset, Theme.Panel.HeightOffset, 0)
	-- Doubles as the proximity rule: past this it simply isn't drawn, so
	-- there's no distance check to write or to run every frame.
	billboard.MaxDistance    = RuneConfig.PanelDistance
	billboard.ResetOnSpawn   = false
	billboard.Parent         = LocalPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name                   = "Panel"
	panel.Size                   = UDim2.fromScale(1, 1)
	panel.BackgroundColor3       = Theme.Panel.Color
	panel.BackgroundTransparency = Theme.Panel.Transparency
	panel.BorderSizePixel        = 0
	panel.Parent                 = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(Theme.Panel.Corner, 0)
	corner.Parent = panel

	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = Theme.Panel.BorderColor
	border.Thickness = Theme.Panel.BorderThickness
	border.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop    = UDim.new(Theme.Panel.Padding, 0)
	padding.PaddingBottom = UDim.new(Theme.Panel.Padding, 0)
	padding.PaddingLeft   = UDim.new(Theme.Panel.Padding, 0)
	padding.PaddingRight  = UDim.new(Theme.Panel.Padding, 0)
	padding.Parent        = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder           = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding             = UDim.new(Theme.Panel.Spacing, 0)
	layout.Parent              = panel

	return billboard, panel
end

--== Mount ==-----------------------------------------------------------

-- One set of panels per RUNE, not per part.
local mountedRunes: { [string]: boolean } = {}

local function mount(host: Instance)
	if not host:IsA("BasePart") or host:GetAttribute("RunePanels") ~= true then
		return
	end
	local runeId = host:GetAttribute("RuneId")
	if type(runeId) ~= "string" or mountedRunes[runeId] then
		return
	end
	local rune = RuneScheme.Get(runeId)
	if not rune then
		return
	end
	mountedRunes[runeId] = true

	local typeCount = #rune.Types
	local weights = Theme.Weights

	local totalUnits = weights.Title + weights.Opened + weights.Rps + weights.Caption
		+ weights.Type * typeCount
	local infoHeight = Theme.Panel.InfoRowHeight * totalUnits
	local unit = 1 / totalUnits

	--== Left: odds and totals ==---------------------------------------
	local infoBillboard, infoPanel = makePanel(
		host, "RuneInfo_" .. runeId,
		Theme.Panel.InfoWidth, infoHeight, -Theme.Panel.StudsOffset
	)

	local infoLabels: { TextLabel } = {}

	local title = row(infoPanel, 1, unit * weights.Title, Theme.Title)
	title.Text = string.upper(rune.Name)
	table.insert(infoLabels, title)

	local opened = row(infoPanel, 2, unit * weights.Opened, Theme.Subtitle)
	table.insert(infoLabels, opened)

	local rows = {}
	for index, entry in rune.Types do
		local typeRow = row(infoPanel, 2 + index, unit * weights.Type, Theme.Row)
		RuneArt.Bind(runeId, entry.Id, { typeRow })
		rows[entry.Id] = typeRow
		table.insert(infoLabels, typeRow)
	end

	local rps = row(infoPanel, 100, unit * weights.Rps, Theme.Rps)
	table.insert(infoLabels, rps)

	local rpsCaption = row(infoPanel, 101, unit * weights.Caption, Theme.Subtitle)
	rpsCaption.Text = Theme.Rps.Caption
	table.insert(infoLabels, rpsCaption)

	--== Right: affordability ==----------------------------------------
	local affordBillboard, affordPanel = makePanel(
		host, "RuneAfford_" .. runeId,
		Theme.Panel.AffordWidth, Theme.Panel.AffordHeight, Theme.Panel.StudsOffset
	)

	local affordUnit = 1 / 6
	local affordLabels: { TextLabel } = {}

	local affordCaption = row(affordPanel, 1, affordUnit * 0.8, Theme.Afford, Theme.Afford.LabelColor)
	affordCaption.Text = "YOU CAN AFFORD"
	local affordValue = row(affordPanel, 2, affordUnit * 1.2, Theme.Afford)
	local durationCaption = row(affordPanel, 3, affordUnit * 0.8, Theme.Afford, Theme.Afford.LabelColor)
	durationCaption.Text = "YOU CAN OPEN FOR"
	local durationValue = row(affordPanel, 4, affordUnit * 1.2, Theme.Afford)
	local costCaption = row(affordPanel, 5, affordUnit * 0.8, Theme.Afford, Theme.Afford.LabelColor)
	costCaption.Text = "COST PER ROLL"
	local costValue = row(affordPanel, 6, affordUnit * 1.2, Theme.Afford)

	for _, label in { affordCaption, affordValue, durationCaption, durationValue, costCaption, costValue } do
		table.insert(affordLabels, label)
	end

	--== Fitting ==-----------------------------------------------------

	local function fitAll()
		fitPanel(infoPanel, infoLabels)
		fitPanel(affordPanel, affordLabels)
	end

	-- Fires as the camera moves, which is exactly when a scale-sized
	-- billboard's pixel dimensions change. Safe to drive from: rows are
	-- sized in scale, so a TextSize change never alters the box it was
	-- measured from.
	infoPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitAll)
	affordPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitAll)

	--== Visibility ==--------------------------------------------------

	local function applyUnlock()
		local unlocked = rune.UnlockPath == nil or UnlockState.IsUnlocked(rune.UnlockPath)
		infoBillboard.Enabled = unlocked
		affordBillboard.Enabled = unlocked
	end

	--== Refresh ==-----------------------------------------------------

	local function formatDuration(seconds: number): string
		if seconds >= 60 * 60 * 24 * 365 then
			return Theme.Afford.Forever
		elseif seconds >= 86400 then
			return ("%dd %dh"):format(seconds // 86400, (seconds % 86400) // 3600)
		elseif seconds >= 3600 then
			return ("%dh %dm"):format(seconds // 3600, (seconds % 3600) // 60)
		elseif seconds >= 60 then
			return ("%dm %ds"):format(seconds // 60, seconds % 60)
		end
		return ("%ds"):format(math.max(seconds, 0))
	end

	local function refresh()
		local notation = SettingsState.Get("General.NumberNotation")
		local stats = RuneState.GetStats(runeId)

		local luck = stats and stats.Luck or 1
		local luckEnabled = stats and stats.LuckEnabled ~= false
		local chances = RuneMath.GetChances(runeId, luck, luckEnabled)

		opened.Text = ("%s OPENED"):format(BigNumber.Format(stats and stats.Opened or ZERO, notation))

		for _, entry in chances do
			local typeRow = rows[entry.Id]
			if typeRow then
				if entry.Obtainable then
					typeRow.Text = ("%s  --  1/%s"):format(
						string.upper(entry.Name),
						BigNumber.Format(BigNumber.FromNumber(entry.OneIn), notation))
					typeRow.TextTransparency = 0
				else
					-- Squeezed out by luck rather than switched off; saying
					-- so is clearer than "1 in infinity".
					typeRow.Text = ("%s  --  %s"):format(string.upper(entry.Name), Theme.Row.UnobtainableText)
					typeRow.TextTransparency = Theme.Row.UnobtainableFade
				end
			end
		end

		rps.Text = ("%s RPS"):format(BigNumber.Format(stats and stats.Rps or ZERO, notation))

		local balance = CurrencyStatsState.Balances[rune.Currency] or ZERO
		local affordableRolls = BigNumber.Div(balance, rune.CostPerRoll)
		local bulk = stats and stats.Bulk or BigNumber.FromNumber(1)
		affordValue.Text = ("%s RUNES"):format(
			BigNumber.Format(BigNumber.Mul(affordableRolls, bulk), notation))

		local speed = stats and stats.Speed or BigNumber.FromNumber(1)
		if BigNumber.IsZero(speed) then
			durationValue.Text = Theme.Afford.Forever
		else
			local seconds = BigNumber.Div(affordableRolls, speed)
			durationValue.Text = seconds.exponent > 8
				and Theme.Afford.Forever
				or formatDuration(BigNumber.ToNumber(seconds))
		end

		costValue.Text = ("%s %s"):format(BigNumber.Format(rune.CostPerRoll, notation), rune.Currency)

		-- Text changed, so widths changed with it.
		fitAll()
	end

	RuneState.Changed.Event:Connect(refresh)
	CurrencyStatsState.Changed.Event:Connect(refresh)
	SettingsState.Changed:Connect(refresh)
	UnlockState.Changed.Event:Connect(applyUnlock)

	applyUnlock()
	refresh()

	-- AbsoluteSize is meaningless until the panels have been laid out, so
	-- the first fit measures zeroes. One deferred pass lands it.
	task.defer(fitAll)
end

local runesRoot = Workspace:WaitForChild("Runes")
for _, descendant in runesRoot:GetDescendants() do
	mount(descendant)
end
runesRoot.DescendantAdded:Connect(mount)
