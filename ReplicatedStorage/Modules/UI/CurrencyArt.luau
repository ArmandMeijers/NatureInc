--!strict
--[[
	CurrencyArt.luau

	One shared, LIVE binding from a currency to its art in
	ReplicatedStorage.CurrencyVisuals.<Name>.<Name>PNG / <Name>GRAD.

	Three separate files used to carry their own copy of this lookup --
	SettingsController, TreeTierBoardUI, and the currency HUD -- and all
	three shared the same flaw: they cloned the gradient once at build
	time and never looked at it again, so re-tinting LeafsGRAD in Studio
	changed nothing on screen until a rejoin. Bind() re-applies on:
	  - the source PNG/GRAD's own properties changing
	  - either source being added, removed or replaced in the folder
	  - the currency's folder appearing under CurrencyVisuals later

	A UIGradient is cloned rather than reparented, since one instance can
	only live under one label and the source has to stay put as the
	template for every other consumer. A label only gets forced to white
	when a gradient actually exists -- a gradient renders truest against
	white, but a currency with no art yet should keep whatever flat
	theme color its caller gave it.

	Returns a handle with :Disconnect(), matching LiveBind's shape.

	Usage:
		CurrencyArt.Bind("Leafs", {
			Icons  = { iconLabel },
			Labels = { nameLabel, currentLabel, nextLabel },
		})

	Location: ReplicatedStorage/Modules/UI/CurrencyArt.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyArt = {}

export type Targets = {
	Icons: { ImageLabel }?,
	Labels: { TextLabel }?,
}

export type Options = {
	-- Background swatch shown when a currency has no PNG yet. nil leaves
	-- the icon fully transparent instead.
	MissingIconColor: Color3?,
}

export type Handle = { Disconnect: (Handle) -> () }

local function readImage(source: Instance?): string?
	if not source then
		return nil
	end
	if source:IsA("ImageLabel") or source:IsA("ImageButton") then
		return source.Image ~= "" and source.Image or nil
	elseif source:IsA("Decal") or source:IsA("Texture") then
		return source.Texture ~= "" and source.Texture or nil
	elseif source:IsA("StringValue") then
		return source.Value ~= "" and source.Value or nil
	end
	return nil
end

local function findSources(currencyName: string)
	local visualsFolder = ReplicatedStorage:FindFirstChild("CurrencyVisuals")
	local currencyFolder = visualsFolder and visualsFolder:FindFirstChild(currencyName)
	return visualsFolder,
		currencyFolder,
		currencyFolder and currencyFolder:FindFirstChild(currencyName .. "PNG"),
		currencyFolder and currencyFolder:FindFirstChild(currencyName .. "GRAD")
end

-- Convenience for callers that just want the asset id once and don't
-- need to stay subscribed (e.g. a one-shot unlock badge).
function CurrencyArt.GetImage(currencyName: string): string?
	local _, _, pngSource = findSources(currencyName)
	return readImage(pngSource)
end

local function applyOnce(currencyName: string, targets: Targets, options: Options, onSourceChanged: () -> ()): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}
	local visualsFolder, currencyFolder, pngSource, gradSource = findSources(currencyName)

	-- Icons -------------------------------------------------------------
	local image = readImage(pngSource)
	for _, icon in targets.Icons or {} do
		if image then
			icon.Image = image
			icon.BackgroundTransparency = 1
			if pngSource and (pngSource:IsA("ImageLabel") or pngSource:IsA("ImageButton")) then
				icon.ImageRectOffset = pngSource.ImageRectOffset
				icon.ImageRectSize = pngSource.ImageRectSize
			end
		else
			icon.Image = ""
			if options.MissingIconColor then
				icon.BackgroundTransparency = 0
				icon.BackgroundColor3 = options.MissingIconColor
			else
				icon.BackgroundTransparency = 1
			end
		end
	end
	if pngSource then
		table.insert(connections, pngSource.Changed:Connect(onSourceChanged))
	end

	-- Labels ------------------------------------------------------------
	local isRealGradient = gradSource ~= nil and gradSource:IsA("UIGradient")
	for _, label in targets.Labels or {} do
		local existing = label:FindFirstChildOfClass("UIGradient")
		if existing then
			existing:Destroy()
		end
		if isRealGradient then
			label.TextColor3 = Color3.new(1, 1, 1)
			local clone = (gradSource :: UIGradient):Clone()
			clone.Name = "CurrencyGradient"
			clone.Enabled = true
			clone.Parent = label
		end
	end
	if isRealGradient then
		table.insert(connections, (gradSource :: UIGradient).Changed:Connect(onSourceChanged))
	end

	-- Watch for art appearing / being replaced later ---------------------
	if currencyFolder then
		table.insert(connections, currencyFolder.ChildAdded:Connect(onSourceChanged))
		table.insert(connections, currencyFolder.ChildRemoved:Connect(onSourceChanged))
	elseif visualsFolder then
		table.insert(connections, visualsFolder.ChildAdded:Connect(function(child)
			if child.Name == currencyName then
				onSourceChanged()
			end
		end))
	else
		table.insert(connections, ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "CurrencyVisuals" then
				onSourceChanged()
			end
		end))
	end

	return connections
end

function CurrencyArt.Bind(currencyName: string, targets: Targets, options: Options?): Handle
	local resolvedOptions: Options = options or {}
	local connections: { RBXScriptConnection } = {}
	local alive = true
	local queued = false

	local refresh

	local function queueRefresh()
		if not alive or queued then
			return
		end
		queued = true
		-- Deferred so a burst of ChildAdded/Changed during a Studio edit
		-- collapses into one re-apply instead of one per event.
		task.defer(function()
			queued = false
			if alive then
				refresh()
			end
		end)
	end

	refresh = function()
		for _, connection in connections do
			connection:Disconnect()
		end
		connections = applyOnce(currencyName, targets, resolvedOptions, queueRefresh)
	end

	refresh()

	local handle = {}
	function handle.Disconnect()
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
	return (handle :: any) :: Handle
end

return CurrencyArt
