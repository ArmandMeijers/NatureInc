--[[
	TreeSpawnController.client.luau

	Clones the tree model matching this player's current tier and pivots
	it onto TOP of the TreeSpawn part. The clone is parented into
	workspace from a LocalScript, so — same trick as the board GUI — it
	only exists on this client. That's what makes a per-player tree tier
	work without giving every player their own physical tree in the world.

	IMPORTANT: PivotTo moves a model's PIVOT to a CFrame, not its base —
	and a model's pivot usually sits wherever it happened to land when it
	was grouped (often near its geometric center), not at its bottom. So
	finding the top of TreeSpawn isn't enough on its own; we also have to
	measure how far each tree model's actual bottom sits below its own
	pivot (via GetBoundingBox) and add that back in. This works correctly
	for any tree model — any height, any pivot placement — without
	needing every tree to have a manually-set "pivot at base" in Studio.

	Tier-up effect: previously this spawned from an Attachment parented to
	TreeSpawn itself — i.e. from the flat spawn part's CENTER, which sits
	near ground level (see getSpawnCFrame below: the actual top of the
	part is TreeSpawn.Position + half its height above that). That's low
	enough, and close enough behind the board, that it read as late/weak
	and could get visually swallowed by the board's opaque UI elements
	(button, boost rows) sitting in front of it from the camera's angle.

	Fixed by anchoring the effect to the NEW tree's own bounding box —
	roughly canopy height, not ground level — so it reads as coming from
	the tree itself and sits above the board's silhouette instead of
	behind it. Anchored to Workspace.Terrain via WorldPosition rather than
	parented to the clone, so a fast second tier-up destroying the old
	clone can't cut the effect off mid-play.

	Location: StarterPlayer/StarterPlayerScripts/BoardLoader/TreeSpawnController.client.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local TreeTierState = require(ReplicatedStorage.Modules.TreeTierState)
local TreeTierConfig = require(ReplicatedStorage.Modules.TreeTierConfig)

local treeModels = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("TreeModels")
local treeSpawn = Workspace:WaitForChild("Area1"):WaitForChild("TreeSpawn")

local currentClone: Model? = nil
local hasSpawnedOnce = false

-- How far this model's own pivot sits ABOVE its actual lowest point.
-- (If the pivot happened to be exactly at the base already, this is 0.)
local function getPivotHeightAboveBase(model: Model): number
	local boundingBoxCFrame, size = model:GetBoundingBox()
	local bottomY = boundingBoxCFrame.Position.Y - size.Y / 2
	local pivotY = model:GetPivot().Position.Y
	return pivotY - bottomY
end

local function getSpawnCFrame(model: Model): CFrame
	local topY = treeSpawn.Position.Y + treeSpawn.Size.Y / 2
	local pivotHeight = getPivotHeightAboveBase(model)
	return CFrame.new(treeSpawn.Position.X, topY + pivotHeight, treeSpawn.Position.Z)
end

-- `model` must already be positioned (PivotTo'd) before calling this, so
-- the bounding box reflects where it actually ended up in the world.
local function playTierUpEffect(model: Model)
	local boundingBoxCFrame, size = model:GetBoundingBox()
	-- Roughly canopy height: most of the way up the tree, not dead center.
	local canopyPosition = boundingBoxCFrame.Position + Vector3.new(0, size.Y * 0.3, 0)

	-- Anchored to Terrain via WorldPosition instead of parented to the
	-- tree clone, so destroying the clone (e.g. a fast second tier-up)
	-- can't cut this effect off mid-play.
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = canopyPosition
	attachment.Parent = Workspace.Terrain

	-- Main burst: brighter, bigger, and drifts upward like new growth
	-- instead of just falling away.
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 210)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 255, 175)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 190, 110)),
	})
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.3, 1.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Lifetime = NumberRange.new(1.3, 2.1)
	burst.Speed = NumberRange.new(8, 16)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Acceleration = Vector3.new(0, 14, 0)
	burst.Rate = 0
	burst.Parent = attachment
	burst:Emit(100)

	-- Soft expanding ring at the base of the burst, scaled to the tree's
	-- own width — a Tier 3 tree gets a bigger ring than Tier 2, for free.
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxasset://textures/particles/smoke_main.dds"
	ring.Color = ColorSequence.new(Color3.fromRGB(235, 255, 235))
	ring.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size.X * 0.15),
		NumberSequenceKeypoint.new(1, size.X * 1.1),
	})
	ring.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	ring.Lifetime = NumberRange.new(0.7, 0.7)
	ring.Speed = NumberRange.new(0, 0)
	ring.Rate = 0
	ring.Parent = attachment
	ring:Emit(1)

	-- Quick warm flash so the moment reads even before the particles
	-- finish traveling.
	local flash = Instance.new("PointLight")
	flash.Color = Color3.fromRGB(190, 255, 200)
	flash.Range = math.max(size.Y * 2, 16)
	flash.Brightness = 5
	flash.Parent = attachment
	TweenService:Create(flash, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()

	task.delay(2.3, function()
		attachment:Destroy()
	end)
end

local function showTier(tier: number)
	local tierData = TreeTierConfig[tier]
	if not tierData or not tierData.Model then
		return
	end

	local template = treeModels:FindFirstChild(tierData.Model)
	if not template then
		warn(`TreeSpawnController: no model named '{tierData.Model}' in ReplicatedStorage.Assets.TreeModels`)
		return
	end

	if currentClone then
		currentClone:Destroy()
	end

	local clone = template:Clone()
	clone:PivotTo(getSpawnCFrame(clone))
	clone.Parent = Workspace
	currentClone = clone

	if hasSpawnedOnce then
		playTierUpEffect(clone)
	end
	hasSpawnedOnce = true
end

showTier(TreeTierState.Tier)
TreeTierState.TierChanged.Event:Connect(showTier)

