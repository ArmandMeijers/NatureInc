--!strict
--[[
	RuneArt.luau

	Binds a label to a rune type's gradient in
	ReplicatedStorage.RuneVisuals.<RuneId>.<TypeId>GRAD, and keeps it
	bound — same contract and same live re-sync as CurrencyArt, which it
	delegates the watching to.

	Falls back to the type's Color from the schema when no gradient
	exists, so a rune reads correctly before any art is made.

	Location: ReplicatedStorage/Modules/UI/RuneArt.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuneScheme = require(ReplicatedStorage.Modules.Runes.RuneScheme)

local RuneArt = {}

local function findGradient(runeId: string, typeId: string): UIGradient?
	local root = ReplicatedStorage:FindFirstChild("RuneVisuals")
	local runeFolder = root and root:FindFirstChild(runeId)
	local source = runeFolder and runeFolder:FindFirstChild(typeId .. "GRAD")
	if source and source:IsA("UIGradient") then
		return source
	end
	return nil
end

-- Applies once and re-applies whenever the source gradient is edited,
-- added or removed.
function RuneArt.Bind(runeId: string, typeId: string, labels: { TextLabel })
	local connections: { RBXScriptConnection } = {}
	local alive = true
	local refresh

	local function queue()
		if not alive then
			return
		end
		task.defer(function()
			if alive then
				refresh()
			end
		end)
	end

	refresh = function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)

		local source = findGradient(runeId, typeId)
		local entry = RuneScheme.GetType(runeId, typeId)

		for _, label in labels do
			local existing = label:FindFirstChildOfClass("UIGradient")
			if existing then
				existing:Destroy()
			end
			if source then
				label.TextColor3 = Color3.new(1, 1, 1)
				local clone = source:Clone()
				clone.Name = "RuneGradient"
				clone.Enabled = true
				clone.Parent = label
			elseif entry and entry.Color then
				label.TextColor3 = entry.Color
			end
		end

		if source then
			table.insert(connections, source.Changed:Connect(queue))
		end

		local root = ReplicatedStorage:FindFirstChild("RuneVisuals")
		local runeFolder = root and root:FindFirstChild(runeId)
		if runeFolder then
			table.insert(connections, runeFolder.ChildAdded:Connect(queue))
			table.insert(connections, runeFolder.ChildRemoved:Connect(queue))
		end
	end

	refresh()

	return {
		Disconnect = function()
			alive = false
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
		end,
	}
end

return RuneArt
