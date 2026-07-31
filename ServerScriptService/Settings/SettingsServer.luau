local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataStore"):WaitForChild("DataManager"))
local SettingsSchema = require(script.Parent:WaitForChild("SettingsSchema"))

local events = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Settings")
local getBundle = events:WaitForChild("GetPlayerSettingsBundle")
local setSetting = events:WaitForChild("SetPlayerSetting")

local schema = SettingsSchema.Build()

local schemaByPath = {}
for _, category in ipairs(schema) do
	for _, row in ipairs(category.rows) do
		schemaByPath[category.name .. "." .. row.key] = row
	end
end

local function isValidValue(row, value)
	if row.type == "toggle" then
		return typeof(value) == "boolean"
	end
	return table.find(row.options, value) ~= nil
end

-- ProfileStore session start is async, so a client that opens the settings
-- menu right on spawn might ask before the profile is ready. Poll briefly
-- instead of failing outright.
local function waitForProfile(player, timeoutSeconds)
	local start = os.clock()
	while player.Parent and os.clock() - start < timeoutSeconds do
		if DataManager.GetProfile(player) then
			return true
		end
		task.wait(0.1)
	end
	return DataManager.GetProfile(player) ~= nil
end

getBundle.OnServerInvoke = function(player)
	waitForProfile(player, 10)
	return {
		schema = schema,
		values = DataManager.Get(player, "Settings") or {},
	}
end

setSetting.OnServerEvent:Connect(function(player, category, key, value)
	local row = schemaByPath[category .. "." .. key]
	if not row or not isValidValue(row, value) then
		return
	end
	DataManager.Set(player, "Settings." .. category .. "." .. key, value)
end)
