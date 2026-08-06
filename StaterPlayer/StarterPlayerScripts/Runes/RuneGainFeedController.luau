--!strict
--[[
	RuneGainFeedController.client.luau

	The corner feed: one line per rune type you've gained this session,
	in that type's colours, fading out after it stops increasing.

	IT'S A LIVE TALLY, NOT A LOG. Each type keeps ONE line whose number
	grows, rather than spawning a line per gain — at thousands of rolls a
	second a log would be unreadable and would allocate a label per tick.

	Location: StarterPlayer/StarterPlayerScripts/Runes/RuneGainFeedController.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local BigNumber     = require(Modules:WaitForChild("BigNumber"))
local SettingsState = require(Modules:WaitForChild("SettingsState"))
local RuneArt       = require(Modules:WaitForChild("UI"):WaitForChild("RuneArt"))
local Theme         = require(Modules:WaitForChild("UI"):WaitForChild("RuneTheme"))

local RunesModules = Modules:WaitForChild("Runes")
local RuneConfig = require(RunesModules:WaitForChild("RuneConfig"))
local RuneScheme = require(RunesModules:WaitForChild("RuneScheme"))
local RuneState  = require(RunesModules:WaitForChild("RuneState"))

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local stale = playerGui:FindFirstChild("RuneGainGui")
if stale then
	stale:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name           = "RuneGainGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 8
gui.Parent         = playerGui

local container = Instance.new("Frame")
container.Name                   = "Container"
container.AnchorPoint            = Vector2.new(1, 1)
container.Position               = UDim2.new(1, -Theme.Gain.Margin, 1, -Theme.Gain.Margin)
container.Size                   = UDim2.fromOffset(Theme.Gain.Width, 0)
container.AutomaticSize          = Enum.AutomaticSize.Y
container.BackgroundTransparency = 1
container.Parent                 = gui

local layout = Instance.new("UIListLayout")
layout.SortOrder           = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment   = Enum.VerticalAlignment.Bottom
layout.Padding             = UDim.new(0, Theme.Gain.Spacing)
layout.Parent              = container

-- typeId -> { Label, Stroke, LastGain, Order }
local lines: { [string]: any } = {}
local nextOrder = 0

local function ensureLine(runeId: string, typeId: string)
	local existing = lines[typeId]
	if existing then
		return existing
	end

	local text = Instance.new("TextLabel")
	text.Name                   = typeId
	text.Size                   = UDim2.new(1, 0, 0, Theme.Gain.Height)
	text.BackgroundTransparency = 1
	text.Font                   = Theme.Gain.Font
	text.TextSize               = Theme.Gain.TextSize
	text.TextXAlignment         = Enum.TextXAlignment.Right
	text.TextWrapped            = false
	text.Text                   = ""
	text.Parent                 = container

	local uiStroke = Instance.new("UIStroke")
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	uiStroke.Color = Theme.Gain.StrokeColor
	uiStroke.Thickness = Theme.Gain.StrokeThickness
	uiStroke.LineJoinMode = Enum.LineJoinMode.Round
	uiStroke.Parent = text

	RuneArt.Bind(runeId, typeId, { text })

	nextOrder += 1
	local record = { Label = text, Stroke = uiStroke, LastGain = os.clock(), Order = nextOrder }
	text.LayoutOrder = nextOrder
	lines[typeId] = record
	return record
end

RuneState.Gained.Event:Connect(function(runeId: string)
	local session = RuneState.Session[runeId]
	if not session then
		return
	end

	local notation = SettingsState.Get("General.NumberNotation")
	local now = os.clock()

	for typeId, entry in session do
		local typeInfo = RuneScheme.GetType(runeId, typeId)
		if typeInfo then
			local record = ensureLine(runeId, typeId)
			record.Label.Text = ("+%s %s"):format(BigNumber.Format(entry.Amount, notation), typeInfo.Name)
			record.LastGain = entry.LastGain or now
			record.Label.TextTransparency = 0
			record.Stroke.Transparency = 0
		end
	end
end)

-- One fade check per frame across all lines, rather than a tween per
-- gain: at ten result pushes a second, per-gain tweens would stack and
-- fight each other over the same properties.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for typeId, record in lines do
		local idle = now - record.LastGain
		if idle > RuneConfig.GainFadeSeconds then
			local progress = math.clamp((idle - RuneConfig.GainFadeSeconds) / RuneConfig.GainFadeTime, 0, 1)
			record.Label.TextTransparency = progress
			record.Stroke.Transparency = progress
			if progress >= 1 then
				record.Label:Destroy()
				lines[typeId] = nil
			end
		end
	end
end)
