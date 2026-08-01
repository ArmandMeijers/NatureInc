require(script.Parent.DataStore.DataManager)

-- ServerScriptService/TestCurrency.server.luau

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(game.ServerScriptService.DataStore.DataManager)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

Players.PlayerAdded:Connect(function(player)
	-- Wait for profile to load
	while not DataManager.GetProfile(player) do
		task.wait(0.1)
	end

	while player.Parent do
		task.wait(5)

		local newAmount = DataManager.AddCurrency(
			player,
			"Compost",
			BigNumber.new(200000, 0)
		)
	
		local displayTYPE = DataManager.Get(player, "Settings.General.NumberNotation")

		print(player.Name .. " now has " .. BigNumber.Format(newAmount, displayTYPE) .. " compost")
		-- Or use "abbreviation" instead of "scientific"
	end
end)