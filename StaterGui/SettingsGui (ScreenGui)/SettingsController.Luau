local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SettingsState = require(ReplicatedStorage.Modules:WaitForChild("SettingsState"))
local events = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Settings")
local getBundle = events:WaitForChild("GetPlayerSettingsBundle")
local setSetting = events:WaitForChild("SetPlayerSetting")

local CurrencyVisuals = ReplicatedStorage:FindFirstChild("CurrencyVisuals")

local gui = script.Parent
local iconButton = gui:WaitForChild("IconButton")
local panel = gui:WaitForChild("Panel")
local panelScale = panel:WaitForChild("UIScale")
local closeButton = panel.TitleBar:WaitForChild("CloseButton")
local scroll = panel:WaitForChild("Rows")

-- Pick your own colors here.
local COLORS = {
	on = Color3.fromRGB(39, 74, 46),
	onText = Color3.fromRGB(126, 227, 154),
	off = Color3.fromRGB(58, 42, 44),
	offText = Color3.fromRGB(224, 138, 138),
	neutral = Color3.fromRGB(44, 44, 52),
	neutralText = Color3.fromRGB(208, 208, 214),
	rowHover = Color3.fromRGB(42, 42, 50),
}

local rows = {} -- "Category.Key" -> {button, def, value, category}

local function displayText(def, value)
	if def.type == "toggle" then
		return value and "On" or "Off"
	end
	return (def.displayNames and def.displayNames[value]) or tostring(value)
end

local function positivity(def, value)
	if def.type == "toggle" then
		return value == true
	end
	return nil
end

local function paint(entry)
	local button, def, value = entry.button, entry.def, entry.value
	button.Text = displayText(def, value)
	local positive = positivity(def, value)
	if positive == true then
		button.BackgroundColor3 = COLORS.on
		button.TextColor3 = COLORS.onText
	elseif positive == false then
		button.BackgroundColor3 = COLORS.off
		button.TextColor3 = COLORS.offText
	else
		button.BackgroundColor3 = COLORS.neutral
		button.TextColor3 = COLORS.neutralText
	end
end

local function nextValue(def, current)
	if def.type == "toggle" then
		return not current
	end
	local idx = table.find(def.options, current) or 1
	local nextIdx = (idx % #def.options) + 1
	return def.options[nextIdx]
end

-- Looks up ReplicatedStorage.CurrencyVisuals.<name>.<name>PNG / <name>GRAD.
-- Falls back to a flat placeholder swatch + plain text color if either is
-- missing, so this never breaks while those folders are still empty.
local function applyCurrencyVisuals(icon, label, currencyName)
	local folder = CurrencyVisuals and CurrencyVisuals:FindFirstChild(currencyName)
	local pngSource = folder and folder:FindFirstChild(currencyName .. "PNG")
	local gradSource = folder and folder:FindFirstChild(currencyName .. "GRAD")

	if pngSource and (pngSource:IsA("ImageLabel") or pngSource:IsA("ImageButton")) then
		icon.Image = pngSource.Image
		icon.BackgroundTransparency = 1
	else
		icon.Image = ""
		icon.BackgroundTransparency = 0
		icon.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
	end

	if gradSource and gradSource:IsA("UIGradient") then
		local existingGrad = label:FindFirstChildOfClass("UIGradient")
		if existingGrad then
			existingGrad:Destroy()
		end
		gradSource:Clone().Parent = label
	end
end

local function buildRow(category, def, order)
	local isCurrency = category.name == "CurrencyView"

	local row = Instance.new("Frame")
	row.Name = def.key
	row.Size = UDim2.new(1, 0, 0, 48)
	row.BackgroundColor3 = COLORS.rowHover
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = scroll

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 4)
	rowCorner.Parent = row

	local label = Instance.new("TextLabel")
	label.Text = def.label
	label.Font = Enum.Font.Gotham
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(230, 230, 235)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.BackgroundTransparency = 1
	label.Parent = row

	if isCurrency then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.fromOffset(24, 24)
		icon.Position = UDim2.new(0, 10, 0.5, -12)
		icon.BackgroundTransparency = 1
		icon.Parent = row
		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(0, 4)
		iconCorner.Parent = icon

		label.Position = UDim2.fromOffset(44, 0)
		label.Size = UDim2.new(0.6, -52, 1, 0)

		applyCurrencyVisuals(icon, label, def.key)
	else
		label.Position = UDim2.fromOffset(10, 0)
		label.Size = UDim2.new(0.6, -18, 1, 0)
	end

	-- Bright, clearly visible divider under each individual setting.
	local underline = Instance.new("Frame")
	underline.Size = UDim2.new(1, 0, 0, 2)
	underline.Position = UDim2.new(0, 0, 1, -2)
	underline.BackgroundColor3 = Color3.fromRGB(85, 85, 95)
	underline.BorderSizePixel = 0
	underline.Parent = row

	local button = Instance.new("TextButton")
	button.Name = "StateButton"
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 13
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(90, 30)
	button.Position = UDim2.new(1, -100, 0.5, -15)
	button.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	row.MouseEnter:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
	end)

	return row, button
end

-- Fetch schema + this player's real values together, then build the menu.
local ok, bundle = pcall(function()
	return getBundle:InvokeServer()
end)

local schema = (ok and type(bundle) == "table" and bundle.schema) or {}
local values = (ok and type(bundle) == "table" and bundle.values) or {}

local layoutOrder = 0
for i, category in ipairs(schema) do
	if i > 1 then
		layoutOrder += 1
		local spacer = Instance.new("Frame")
		spacer.Size = UDim2.new(1, 0, 0, 10)
		spacer.BackgroundTransparency = 1
		spacer.LayoutOrder = layoutOrder
		spacer.Parent = scroll
	end

	layoutOrder += 1
	local sectionLabel = Instance.new("TextLabel")
	sectionLabel.Text = category.label
	sectionLabel.Font = Enum.Font.GothamMedium
	sectionLabel.TextSize = 12
	sectionLabel.TextColor3 = Color3.fromRGB(110, 110, 118)
	sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
	sectionLabel.TextYAlignment = Enum.TextYAlignment.Center
	sectionLabel.Size = UDim2.new(1, 0, 0, 26)
	sectionLabel.BackgroundTransparency = 1
	sectionLabel.LayoutOrder = layoutOrder
	sectionLabel.Parent = scroll

	for _, def in ipairs(category.rows) do
		layoutOrder += 1
		local rowFrame, button = buildRow(category, def, layoutOrder)
		local path = category.name .. "." .. def.key
		local entry = {button = button, def = def, category = category.name}
		rows[path] = entry

		button.MouseButton1Click:Connect(function()
			entry.value = nextValue(def, entry.value)
			paint(entry)
			SettingsState._Set(path, entry.value)
			setSetting:FireServer(category.name, def.key, entry.value)
		end)
	end
end

for _, category in ipairs(schema) do
	for _, def in ipairs(category.rows) do
		local path = category.name .. "." .. def.key
		local entry = rows[path]
		local categoryValues = values[category.name]
		local value = categoryValues and categoryValues[def.key]
		if value == nil then
			value = def.default
		end
		entry.value = value
		paint(entry)
		SettingsState._Set(path, value)
	end
end

-- Open / close animation. GroupTransparency fades the WHOLE panel as one
-- composited image, so nothing can visually drift out of sync mid-tween.
-- Tweens are tracked and cancelled before a new one starts, and the close
-- completion is guarded by a generation counter, so rapidly toggling the
-- menu can no longer leave a stale close-callback hiding a reopened panel.
local isOpen = false
local openGeneration = 0
local activeFadeTween, activeScaleTween

local function setOpen(open)
	if open == isOpen then
		return
	end
	isOpen = open
	openGeneration += 1
	local myGeneration = openGeneration

	if activeFadeTween then
		activeFadeTween:Cancel()
	end
	if activeScaleTween then
		activeScaleTween:Cancel()
	end

	if open then
		panel.Visible = true
	end

	activeFadeTween = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
		GroupTransparency = open and 0 or 1,
	})
	activeScaleTween = TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
		Scale = open and 1 or 0.9,
	})

	activeFadeTween:Play()
	activeScaleTween:Play()

	if not open then
		activeFadeTween.Completed:Connect(function(playbackState)
			if myGeneration == openGeneration and not isOpen and playbackState == Enum.PlaybackState.Completed then
				panel.Visible = false
			end
		end)
	end
end

iconButton.MouseButton1Click:Connect(function()
	setOpen(not isOpen)
end)

closeButton.MouseButton1Click:Connect(function()
	setOpen(false)
end)
