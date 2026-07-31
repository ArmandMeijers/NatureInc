--[[
	SettingsSchema.luau
	Server-only (requires Template directly). Builds the settings menu
	structure by looping over Template.Settings -- add a field there and it
	shows up in the menu automatically. A category with no keys (Misc = {})
	is skipped until you add something to it.
	Location: ServerScriptService/Settings/SettingsSchema.luau
]]
local ServerScriptService = game:GetService("ServerScriptService")
local Template = require(ServerScriptService:WaitForChild("DataStore"):WaitForChild("Template"))

local SettingsSchema = {}

-- Metadata ONLY for settings that aren't plain true/false toggles. Every
-- boolean field in Template.Settings gets a row automatically -- no entry
-- needed here for those, including future CurrencyView additions.
local OVERRIDES = {
	NumberNotation = {
		label = "Num. format",
		type = "choice",
		options = {"abbreviation", "scientific"},
		displayNames = {abbreviation = "Suffix", scientific = "Scientific"},
	},
}

-- Controls category display order; anything not listed here sorts
-- alphabetically after the ones that are.
local CATEGORY_ORDER = {"General", "Audio", "CurrencyView", "Misc"}

local function prettify(key)
	return (key:gsub("(%l)(%u)", "%1 %2"))
end

local function categoryRank(name)
	for i, orderedName in ipairs(CATEGORY_ORDER) do
		if orderedName == name then
			return i
		end
	end
	return math.huge
end

function SettingsSchema.Build()
	local categories = {}

	for categoryName, categoryTable in pairs(Template.Settings) do
		if next(categoryTable) ~= nil then
			local rows = {}
			for key, defaultValue in pairs(categoryTable) do
				local override = OVERRIDES[key]
				local row = {key = key, default = defaultValue}
				if override then
					row.label = override.label
					row.type = override.type
					row.options = override.options
					row.displayNames = override.displayNames
				elseif type(defaultValue) == "boolean" then
					row.label = prettify(key)
					row.type = "toggle"
				else
					warn(("SettingsSchema: '%s' in Template.Settings.%s isn't a boolean and has no OVERRIDES entry -- skipping."):format(key, categoryName))
					row = nil
				end
				if row then
					table.insert(rows, row)
				end
			end
			table.sort(rows, function(a, b)
				return a.key < b.key
			end)
			table.insert(categories, {name = categoryName, label = prettify(categoryName), rows = rows})
		end
	end

	table.sort(categories, function(a, b)
		local rankA, rankB = categoryRank(a.name), categoryRank(b.name)
		if rankA == rankB then
			return a.name < b.name
		end
		return rankA < rankB
	end)

	return categories
end

return SettingsSchema
