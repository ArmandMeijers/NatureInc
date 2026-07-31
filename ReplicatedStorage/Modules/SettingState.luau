--[[
	SettingsState.luau
	Client-side cache + change signal for the local player's settings.
	Any other LocalScript (currency boards, etc.) can require this to read
	the current value of a setting, or subscribe to be notified the moment
	it changes -- e.g. to reformat a BigNumber display when NumberNotation
	is toggled, or to show/hide a currency display when CurrencyView.Leafs
	is flipped. Keys are namespaced as "Category.Key", e.g. "Audio.Music"
	or "CurrencyView.Leafs". SettingsController is the only script that
	should call _Set.
]]
local SettingsState = {}

local cache = {}
local changedEvent = Instance.new("BindableEvent")
SettingsState.Changed = changedEvent.Event -- :Connect(function(path, value) ... end)

function SettingsState.Get(path)
	return cache[path]
end

function SettingsState.GetAll()
	local copy = {}
	for path, value in pairs(cache) do
		copy[path] = value
	end
	return copy
end

function SettingsState._Set(path, value)
	cache[path] = value
	changedEvent:Fire(path, value)
end

return SettingsState
