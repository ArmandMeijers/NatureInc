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

	Plays a sparkle/particle burst on every tier change after the first
	(so joining doesn't trigger it, only an actual tier-up does).

	Location: StarterPlayer/StarterPlayerScripts/BoardLoader/TreeSpawnController.client.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

local function playTierUpEffect()
	local attachment = Instance.new("Attachment")
	attachment.Parent = treeSpawn

	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(150, 255, 175)
	sparkles.Parent = treeSpawn

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(Color3.fromRGB(210, 255, 220), Color3.fromRGB(90, 200, 120))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Lifetime = NumberRange.new(1, 1.8)
	particles.Speed = NumberRange.new(6, 12)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rate = 0
	particles.Parent = attachment
	particles:Emit(70)

	task.delay(2, function()
		sparkles:Destroy()
	end)
	task.delay(2.5, function()
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
		playTierUpEffect()
	end
	hasSpawnedOnce = true
end

showTier(TreeTierState.Tier)
TreeTierState.TierChanged.Event:Connect(showTier)
