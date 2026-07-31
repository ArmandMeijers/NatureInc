--[[
	TreeSpawnController.client.luau

	Clones the tree model matching this player's current tier and pivots
	it onto TOP of the TreeSpawn part (TreeSpawn's Position is its center,
	so we push up by half its height). The clone is parented into
	workspace from a LocalScript, so — same trick as the board GUI — it
	only exists on this client. That's what makes a per-player tree tier
	work without giving every player their own physical tree in the world.

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

local function getSpawnCFrame(): CFrame
	return treeSpawn.CFrame + Vector3.new(0, treeSpawn.Size.Y / 2, 0)
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
	clone:PivotTo(getSpawnCFrame())
	clone.Parent = Workspace
	currentClone = clone

	if hasSpawnedOnce then
		playTierUpEffect()
	end
	hasSpawnedOnce = true
end

showTier(TreeTierState.Tier)
TreeTierState.TierChanged.Event:Connect(showTier)
