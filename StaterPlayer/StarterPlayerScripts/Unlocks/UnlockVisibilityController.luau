--!strict
--[[
	UnlockVisibilityController.client.luau

	Hides every Workspace instance carrying an "UnlockPath" attribute
	until that path is unlocked, and reveals it the moment it is — on
	join, and again after any tier-up or reset.

	ONE ATTRIBUTE IS THE WHOLE INTEGRATION. Nothing here knows what a
	board or a rune or an area is; it moves instances. Gating a new
	feature is a Studio edit, not a code change.

	HIDING IS A REPARENT, not a transparency change, for three reasons:
	  * It hides descendants for free — a Model's parts, decals, lights,
	    ProximityPrompts, the lot — instead of needing a rule per class.
	  * A SurfaceGui whose Adornee isn't in Workspace stops rendering, so
	    board UI disappears with its part. Setting Transparency = 1 on the
	    part would leave the board's interface floating in mid-air.
	  * It's exactly reversible. Restoring a stored parent can't lose the
	    original transparency, collision or material the way writing over
	    properties can.

	Local-only, which is correct: unlocks are per player, so the server
	must keep its copy where it is. This is the same reasoning that makes
	the boards local.

	Location: StarterPlayer/StarterPlayerScripts/Unlocks/UnlockVisibilityController.client.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UnlocksModules = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Unlocks")
local UnlockScheme = require(UnlocksModules:WaitForChild("UnlockScheme"))
local UnlockState = require(UnlocksModules:WaitForChild("UnlockState"))

-- Where hidden instances live. Out of Workspace on purpose: that's what
-- makes SurfaceGuis adorned to them stop rendering.
local holding = Instance.new("Folder")
holding.Name = "LockedContent"
holding.Parent = ReplicatedStorage

-- instance -> { Path = string, HomeParent = Instance }
local tracked: { [Instance]: { Path: string, HomeParent: Instance } } = {}

local function track(instance: Instance)
	if tracked[instance] then
		return
	end
	local path = instance:GetAttribute(UnlockScheme.AttributeName)
	if type(path) ~= "string" or path == "" then
		return
	end
	if not instance.Parent then
		return
	end

	tracked[instance] = {
		Path = UnlockScheme.Resolve(path),
		-- Captured BEFORE anything is hidden, which is why tracking has
		-- to happen while the instance is still in its real home.
		HomeParent = instance.Parent,
	}
end

local function applyOne(instance: Instance, record: { Path: string, HomeParent: Instance })
	local unlocked = UnlockState.IsUnlocked(record.Path)
	local wantedParent = unlocked and record.HomeParent or holding
	if instance.Parent ~= wantedParent then
		instance.Parent = wantedParent
	end
end

local function applyAll()
	for instance, record in tracked do
		if instance.Parent == nil and instance ~= nil then
			-- Destroyed by something else; stop tracking it.
			tracked[instance] = nil
		else
			applyOne(instance, record)
		end
	end
end

-- Initial sweep. Everything gated starts HIDDEN and is revealed by the
-- first apply, rather than starting visible and being hidden a frame
-- later — a locked area flashing on screen at spawn reads as a bug and
-- tells the player what's coming.
for _, instance in Workspace:GetDescendants() do
	track(instance)
end
for instance, record in tracked do
	instance.Parent = holding
end

-- Anything streamed in or built later.
Workspace.DescendantAdded:Connect(function(instance)
	if instance:IsDescendantOf(holding) then
		return
	end
	local path = instance:GetAttribute(UnlockScheme.AttributeName)
	if type(path) ~= "string" or path == "" then
		return
	end
	track(instance)
	local record = tracked[instance]
	if record then
		-- Deferred: the instance may still be having children added to
		-- it, and reparenting mid-build is a good way to lose them.
		task.defer(function()
			if tracked[instance] then
				applyOne(instance, record)
			end
		end)
	end
end)

UnlockState.Changed.Event:Connect(applyAll)
applyAll()
