--!strict
--[[
	PlayerSpeedController.client.luau

	Sets the local player's walk speed to their configured base plus every
	upgrade tagged "WalkSpeed".

	    speed = Settings.Misc.PlayerSpeed + sum(upgrades tagged WalkSpeed)

	THE BASE COMES FROM SETTINGS, not a constant. It's saved player data,
	so whatever changes it later — a menu, a gamepass, an admin command —
	writes one field and this follows, with no second place to update.

	UPGRADES ARE SUMMED BY TAG, not by id. CompostWalkspeed is the only
	one today; a future nut sprint or rune bonus needs no code here, just
	Tag = "WalkSpeed" in its schema entry. Same mechanism that lets
	compost upgrades feed leaf stats.

	Re-applies on four triggers: upgrade levels changing, the setting
	changing, the character respawning (a fresh Humanoid arrives at
	Roblox's default), and the Humanoid's WalkSpeed being written by
	anything else.

	Location: StarterPlayer/StarterPlayerScripts/PlayerSpeed/PlayerSpeedController.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SettingsState = require(Modules:WaitForChild("SettingsState"))

local UpgradesModules = Modules:WaitForChild("Upgrades")
local UpgradeSchema = require(UpgradesModules:WaitForChild("UpgradeSchema"))
local UpgradeState = require(UpgradesModules:WaitForChild("UpgradeState"))

-- Only used if the setting hasn't loaded yet. Not the source of truth.
local FALLBACK_BASE_SPEED = 16
local SPEED_SETTING = "Misc.PlayerSpeed"
local SPEED_TAG = "WalkSpeed"

local LocalPlayer = Players.LocalPlayer

local function computeWalkSpeed(): number
	local base = SettingsState.Get(SPEED_SETTING)
	if type(base) ~= "number" then
		base = FALLBACK_BASE_SPEED
	end

	local total = base
	for _, upgradeId in UpgradeSchema.ByTag[SPEED_TAG] or {} do
		total += UpgradeSchema.GetBoostValue(upgradeId, UpgradeState.GetLevel(upgradeId))
	end
	return math.max(total, 0)
end

local applying = false

local function apply(humanoid: Humanoid?)
	local character = LocalPlayer.Character
	humanoid = humanoid or (character and character:FindFirstChildOfClass("Humanoid"))
	if not humanoid then
		return
	end

	local target = computeWalkSpeed()
	if humanoid.WalkSpeed == target then
		return
	end

	-- Guarded, since writing WalkSpeed fires the very signal this is
	-- connected to and would otherwise recurse.
	applying = true
	humanoid.WalkSpeed = target
	applying = false
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	apply(humanoid)

	-- Anything else writing WalkSpeed (a tool, a default respawn) gets
	-- corrected rather than silently winning.
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if not applying then
			apply(humanoid)
		end
	end)
end

if LocalPlayer.Character then
	bindCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(bindCharacter)

UpgradeState.Changed.Event:Connect(function()
	apply(nil)
end)
SettingsState.Changed:Connect(function()
	apply(nil)
end)
