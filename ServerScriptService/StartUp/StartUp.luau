require(script.Parent.Parent.DataStore.DataManager)

-- ServerScriptService/TestCurrency.server.luau

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(game.ServerScriptService.DataStore.DataManager)
local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
