--!strict
--[[
	SettingsEffects.client.luau

	Makes the Settings menu's toggles actually DO something on this
	client, beyond just being saved. Two things wired here on purpose --
	General.HideMaxUpgrades is intentionally left alone:

	- General.HidePlayers: locally hides every OTHER player's character
	  (never your own). Purely a client-side transparency trick -- this
	  doesn't tell the server or any other client anything, so nobody
	  else is affected by your choice, and yours isn't affected by theirs.

	- Audio.Music / Audio.SoundEffects: two SoundGroups under SoundService
	  ("Music", "SFX") get muted/unmuted. Route any Sound you add through
	  one of these two (set its .SoundGroup property in Studio) and this
	  automatically respects both settings for it -- no per-sound wiring
	  needed anywhere else, including for sounds added later.

	Both use LiveBind (ReplicatedStorage/Modules/UI/LiveBind) to react to
	SettingsState.Changed -- the same tool the board UI's cost text uses,
	just applied to gameplay effects instead of a GUI property.

	Location: StarterPlayer/StarterPlayerScripts/Settings/SettingsEffects.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SettingsState = require(ReplicatedStorage.Modules.SettingsState)
local LiveBind = require(ReplicatedStorage.Modules.UI.LiveBind)

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- Audio: Music / SoundEffects -> SoundGroups
-- ============================================================

local function getOrCreateSoundGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

local musicGroup = getOrCreateSoundGroup("Music")
local sfxGroup = getOrCreateSoundGroup("SFX")

-- Settings default to true until the real value loads in (see
-- SettingsController), so "not false" reads as on rather than muted
-- during that brief window.
LiveBind.Bind(musicGroup, "Volume", function()
	return SettingsState.Get("Audio.Music") ~= false and 1 or 0
end, { SettingsState.Changed })

LiveBind.Bind(sfxGroup, "Volume", function()
	return SettingsState.Get("Audio.SoundEffects") ~= false and 1 or 0
end, { SettingsState.Changed })

-- ============================================================
-- General.HidePlayers -> hide every other player's character locally
-- ============================================================

local function isHidePlayersOn(): boolean
	return SettingsState.Get("General.HidePlayers") == true
end

local function setCharacterHidden(character: Model, hidden: boolean)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function watchPlayer(player: Player)
	if player == LocalPlayer then
		return
	end

	local function onCharacterAdded(character: Model)
		-- Applies whatever the CURRENT setting is, so a character that
		-- spawns after the setting was already turned on comes in hidden
		-- instead of flashing visible first.
		setCharacterHidden(character, isHidePlayersOn())
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Newly-added parts on an existing character (equipped accessories,
	-- a limb replaced on respawn, etc.) need the current state applied
	-- too, or they'd pop back in at full visibility while hidden.
	player.CharacterAdded:Connect(function(character)
		character.DescendantAdded:Connect(function(descendant)
			if isHidePlayersOn() and (descendant:IsA("BasePart") or descendant:IsA("Decal")) then
				(descendant :: BasePart).LocalTransparencyModifier = 1
			end
		end)
	end)
end

for _, player in Players:GetPlayers() do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

-- Re-applies to every currently-present character the moment the setting
-- itself changes, not just on spawn/despawn.
LiveBind.Watch(isHidePlayersOn, { SettingsState.Changed }, function(hidden)
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer and player.Character then
			setCharacterHidden(player.Character, hidden)
		end
	end
end)

