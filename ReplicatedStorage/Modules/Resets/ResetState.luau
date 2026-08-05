--!strict
--[[
	ResetState.luau  (CLIENT ONLY — never require this from server code)

	One place for the client to ask for a reset and to hear that one
	happened.

	It holds no cached payout. Payout is a pure function of the input
	currency balance, and CurrencyStatsState already tracks that live —
	caching it here would only create a second copy to go stale.

	Performed fires with (resetId, gainedAmount). Anything that needs to
	react to a reset listens to that rather than the remote directly, so
	there's exactly one place that knows the wire format.

	Location: ReplicatedStorage/Modules/Resets/ResetState.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)

local resetEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Resets")
local RequestReset = resetEvents:WaitForChild("RequestReset")
local ResetResult = resetEvents:WaitForChild("ResetResult")

local ResetState = {}

-- Fires with (resetId: string, gained: BigNum)
ResetState.Performed = Instance.new("BindableEvent")
-- Fires with (resetId: string, reason: string)
ResetState.Failed = Instance.new("BindableEvent")

function ResetState.Request(resetId: string)
	RequestReset:FireServer(resetId)
end

ResetResult.OnClientEvent:Connect(function(result)
	if type(result) ~= "table" or type(result.ResetId) ~= "string" then
		return
	end
	if result.Success then
		ResetState.Performed:Fire(result.ResetId, BigNumber.Deserialize(result.Gained))
	else
		ResetState.Failed:Fire(result.ResetId, result.Reason or "Unknown")
	end
end)

return ResetState
