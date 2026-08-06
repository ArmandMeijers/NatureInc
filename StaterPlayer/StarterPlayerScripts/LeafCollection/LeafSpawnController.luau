--!strict
--[[
	LeafSpawnController.client.luau

	Spawns and manages this player's OWN local leaves on top of
	Area1Spawner.LeafSpawnPlatform, shows a collection circle whenever
	they're standing on that platform, and collects any leaf caught
	inside it. Everything here is client-local — same trick as
	TreeSpawnController and the board GUIs: cloned and parented on this
	client only, so 500 leaves for 20 players never means 10,000 real
	server-replicated Parts.

	Currency is NEVER awarded here. Collecting a leaf destroys the local
	clone immediately (feels instant) and fires CollectLeaf:FireServer()
	— the server independently decides what that's worth and whether to
	honor it (see LeafCollectionService for why). If the server ever
	rejects a fire (rate limited), the leaf still visually vanished on
	this client already; that's an acceptable, deliberate tradeoff for
	responsiveness over strict consistency for something this low-stakes.

	Capacity/interval/radius all come from LeafStatsState (server-
	authoritative, polled) — never computed locally — so upgrades apply
	immediately without this script needing to know anything about the
	upgrade system itself.

	Location: StarterPlayer/StarterPlayerScripts/LeafCollection/LeafSpawnController.client.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LeafStatsState = require(ReplicatedStorage.Modules.LeafStatsState)
local LeafConfig = require(ReplicatedStorage.Modules.LeafConfig)
local LiveBind = require(ReplicatedStorage.Modules.UI.LiveBind)

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local area1Spawner = Workspace:WaitForChild("Area1"):WaitForChild("Area1Spawner")
local leafSpawnPlatform = area1Spawner:WaitForChild("LeafSpawnPlatform") :: BasePart

local leafTemplate = ReplicatedStorage
	:WaitForChild("Assets")
	:WaitForChild("Collectibles")
	:WaitForChild("LeafModel")

-- Falls back to the leaf model if the nut art isn't in yet, so a
-- missing asset costs you the visual and nothing else — the roll,
-- the IsNut attribute and the payout all still work.
local nutTemplate = ReplicatedStorage.Assets.Collectibles:FindFirstChild("NutModel")
	or ReplicatedStorage.Assets.Collectibles:FindFirstChild("Nut")
	or leafTemplate

local remotesFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Leaf")
local CollectLeaf = remotesFolder:WaitForChild("CollectLeaf")

local leavesFolder = Instance.new("Folder")
leavesFolder.Name = "LocalLeaves"
leavesFolder.Parent = Workspace

local activeLeaves: { Model | BasePart } = {}

-- ============================================================
-- Placement
-- ============================================================

-- Only ever hits LeafSpawnPlatform itself -- guarantees leaves land on
-- ITS actual surface, never the decorative "boarder" model or anything
-- else nearby, regardless of exactly how these parts are stacked.
local platformRaycastParams = RaycastParams.new()
platformRaycastParams.FilterType = Enum.RaycastFilterType.Include
platformRaycastParams.FilterDescendantsInstances = { leafSpawnPlatform }

-- A random point on TOP of the platform. Casts straight down from well
-- above the platform onto its own surface (see platformRaycastParams
-- above) rather than assuming Position.Y + Size.Y/2 is the walkable
-- surface -- that assumption is what was placing leaves on top of the
-- wrong geometry. Deliberately ignores the decorative "boarder" model
-- entirely either way — only LeafSpawnPlatform's own footprint is used
-- to pick X/Z, and only its own surface is ever landed on.
local function randomPlatformTopPoint(): Vector3
	local halfSize = leafSpawnPlatform.Size / 2
	local offsetX = (math.random() * 2 - 1) * halfSize.X
	local offsetZ = (math.random() * 2 - 1) * halfSize.Z

	local origin = (leafSpawnPlatform.CFrame * CFrame.new(offsetX, halfSize.Y + 10, offsetZ)).Position
	local result = Workspace:Raycast(origin, Vector3.new(0, -50, 0), platformRaycastParams)
	if result then
		return result.Position
	end

	-- Raycast shouldn't normally miss (the cast originates directly above
	-- a point on the platform's own footprint), but fall back to the
	-- geometric top just in case.
	return (leafSpawnPlatform.CFrame * CFrame.new(offsetX, halfSize.Y, offsetZ)).Position
end

-- LeafModel is authored standing upright by default (its own "flat" face
-- points sideways, not up) -- this corrects that before the random yaw
-- is applied on top. If leaves still aren't lying flat after a deploy,
-- this is the one number to adjust: try 90 instead of -90, or swap which
-- axis (X/Z) it rotates around, depending on how the model is built.
local FLAT_CORRECTION = CFrame.Angles(math.rad(-90), 0, 0)

local function setCFrame(instance: Model | BasePart, cframe: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(cframe)
	else
		(instance :: BasePart).CFrame = cframe
	end
end

local function getCFrame(instance: Model | BasePart): CFrame
	if instance:IsA("Model") then
		return instance:GetPivot()
	end
	return (instance :: BasePart).CFrame
end

-- How far BELOW the pivot this model's lowest point sits, measured in
-- the pivot's OWN local space (not world space). Computed by checking
-- every corner of every part directly, rather than trusting
-- Model:GetBoundingBox() -- that call's behavior once a model has been
-- rotated wasn't something I could verify with confidence, and two
-- placement attempts built on it both landed leaves in the wrong spot.
-- A local-space measurement is correct regardless of whatever rotation
-- gets applied afterward, by construction -- there's no ambiguity left
-- to get wrong.
local function getLocalBottomOffset(instance: Model | BasePart): number
	local pivot = getCFrame(instance)

	local parts: { BasePart } = {}
	if instance:IsA("Model") then
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	else
		table.insert(parts, instance :: BasePart)
	end

	local minLocalY = math.huge
	for _, part in parts do
		local size = part.Size
		local partCFrame = part.CFrame
		for _, signX in { -1, 1 } do
			for _, signY in { -1, 1 } do
				for _, signZ in { -1, 1 } do
					local cornerWorld = (partCFrame * CFrame.new(signX * size.X / 2, signY * size.Y / 2, signZ * size.Z / 2)).Position
					local localY = pivot:PointToObjectSpace(cornerWorld).Y
					minLocalY = math.min(minLocalY, localY)
				end
			end
		end
	end

	if minLocalY == math.huge then
		return 0
	end
	return -minLocalY
end

local function spawnLeaf()
	-- Rolled BEFORE the clone now, because it decides WHICH model to
	-- clone. Still one roll per placement, so a bulk batch of 10
	-- rolls ten times and the loop needs no changes.
	local isNut = math.random() < LeafStatsState.NutChance
	local clone = (isNut and nutTemplate or leafTemplate):Clone()
	local randomYaw = math.rad(math.random() * 360) -- random facing direction
	local rotation = CFrame.Angles(0, randomYaw, 0) * FLAT_CORRECTION

	-- Local-space measurement, so this is valid regardless of the
	-- rotation applied below -- no need to pre-rotate before measuring.
	local bottomOffset = getLocalBottomOffset(clone)
	local point = randomPlatformTopPoint()

	local cframe = CFrame.new(point) * rotation * CFrame.new(0, bottomOffset, 0)
	setCFrame(clone, cframe)

	-- Rolled at SPAWN, not at collection, so the nut is decided the
	-- moment it appears. Stored as an attribute so it survives on the
	-- instance itself. Nut art isn't in yet — until it is, a nut is just
	-- a leaf that pays out as a nut, and swapping in a different model
	-- here later changes nothing else in this file.
	clone:SetAttribute("IsNut", isNut)

	clone.Parent = leavesFolder
	table.insert(activeLeaves, clone)
end

-- ============================================================
-- Spawn loop
-- Re-reads LeafStatsState every cycle, so an upgrade purchased mid-
-- session takes effect on the very next cycle without restarting.
--
-- Two modes (see LeafConfig's BULK SPAWNING note): above the bulk
-- threshold it's one leaf per wait, exactly as before. Below it, the
-- loop stops shortening its wait and instead ticks at a fixed
-- BulkInterval, placing however many leaves the elapsed time earned --
-- same spawn rate, far fewer wakeups at 0.01s intervals.
-- ============================================================

task.spawn(function()
	local lastTick = os.clock()

	while true do
		local interval = LeafStatsState.SpawnInterval
		local capacity = LeafStatsState.Capacity

		if interval >= LeafConfig.BulkThreshold then
			if #activeLeaves < capacity then
				spawnLeaf()
			end
			task.wait(interval)
			lastTick = os.clock()
		else
			local now = os.clock()
			local elapsed = now - lastTick
			lastTick = now

			-- Derived from elapsed time rather than a fixed batch size,
			-- so the rate stays correct even if a frame hitch made this
			-- tick longer than intended.
			local earned = math.floor(elapsed / interval)
			local room = capacity - #activeLeaves
			local toSpawn = math.min(earned, room, LeafConfig.MaxBulkPerTick)

			for _ = 1, toSpawn do
				spawnLeaf()
			end

			task.wait(LeafConfig.BulkInterval)
		end
	end
end)

-- ============================================================
-- Collection circle
-- A single flat cylinder acting as a semi-transparent white disc — no
-- ring this time. "Thick" here means the disc's own physical depth
-- (0.3 studs, up from a paper-thin 0.06), not a separate border piece.
-- Anchored + manually repositioned every frame instead of welded, since
-- it needs to stay flat/level regardless of platform tilt or player
-- movement.
-- ============================================================

local circleFolder = Instance.new("Folder")
circleFolder.Name = "LeafCollectionCircle"
circleFolder.Parent = Workspace

local CIRCLE_TRANSPARENCY = 0.8
local CIRCLE_THICKNESS = 0.3

local circle = Instance.new("Part")
circle.Name = "Circle"
circle.Shape = Enum.PartType.Cylinder
circle.Anchored = true
circle.CanCollide = false
circle.CanQuery = false
circle.CanTouch = false
circle.CastShadow = false
circle.Material = Enum.Material.SmoothPlastic
circle.Color = Color3.fromRGB(255, 255, 255)
circle.Transparency = 1
circle.Parent = circleFolder

local function setCircleVisible(visible: boolean)
	circle.Transparency = visible and CIRCLE_TRANSPARENCY or 1
end
setCircleVisible(false)

local function updateCircle(center: Vector3, radius: number)
	-- Cylinder's "height" axis is X by default, so this rotates it to
	-- lie flat (facing up) before scaling: Size = (thickness, diameter, diameter).
	local flatOrientation = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	local diameter = radius * 2

	circle.Size = Vector3.new(CIRCLE_THICKNESS, diameter, diameter)
	circle.CFrame = flatOrientation
end

-- ============================================================
-- On-platform detection + collection tick
-- ============================================================

local function isOnPlatform(worldPosition: Vector3): boolean
	local relative = leafSpawnPlatform.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = leafSpawnPlatform.Size / 2
	local withinFootprint = math.abs(relative.X) <= halfSize.X and math.abs(relative.Z) <= halfSize.Z
	local withinHeight = relative.Y >= halfSize.Y - 1 and relative.Y <= halfSize.Y + 6
	return withinFootprint and withinHeight
end

-- Small "getting collected" flourish: quick scale-up-and-shrink-to-
-- nothing while drifting toward the player, then destroy. Doesn't block
-- collection of anything else while it plays.
local function playCollectAnimation(leaf: Model | BasePart, towardPosition: Vector3)
	local part: BasePart? = if leaf:IsA("BasePart") then leaf else (leaf :: Model).PrimaryPart or (leaf :: Model):FindFirstChildWhichIsA("BasePart")
	if not part then
		leaf:Destroy()
		return
	end

	local targetCFrame = CFrame.new(towardPosition + Vector3.new(0, 2, 0))
	local tween = TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = targetCFrame,
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		leaf:Destroy()
	end)
end

local function getLeafPosition(leaf: Model | BasePart): Vector3
	if leaf:IsA("Model") then
		return leaf:GetPivot().Position
	end
	return (leaf :: BasePart).Position
end

RunService.Heartbeat:Connect(function()
	local character = LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		setCircleVisible(false)
		return
	end

	local onPlatform = isOnPlatform(rootPart.Position)
	setCircleVisible(onPlatform)

	if not onPlatform then
		return
	end

	local radius = LeafStatsState.CollectionRadius
	local center = rootPart.Position
	updateCircle(Vector3.new(center.X, leafSpawnPlatform.Position.Y + leafSpawnPlatform.Size.Y / 2 + 0.05, center.Z), radius)

	for i = #activeLeaves, 1, -1 do
		local leaf = activeLeaves[i]
		if not leaf.Parent then
			table.remove(activeLeaves, i)
			continue
		end

		local leafPosition = getLeafPosition(leaf)
		local flatDistance = (Vector3.new(leafPosition.X, 0, leafPosition.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude

		if flatDistance <= radius then
			local isNut = leaf:GetAttribute("IsNut") == true
			table.remove(activeLeaves, i)
			playCollectAnimation(leaf, center)
			CollectLeaf:FireServer(isNut)
		end
	end
end)

-- ============================================================
-- Capacity display (current/capacity) — cloned local-per-player, same
-- reason as the tree board's SurfaceGui: CapacityDisplay is one shared
-- world Part, but each player's OWN leaf count differs, so the ORIGINAL
-- gui gets disabled and every client shows its own clone instead.
-- ============================================================

local capacityDisplayPart = area1Spawner:FindFirstChild("CapacityDisplay")
if capacityDisplayPart then
	local originalGui = capacityDisplayPart:FindFirstChild("gui") or capacityDisplayPart:FindFirstChildWhichIsA("BillboardGui")

	if originalGui and originalGui:IsA("BillboardGui") then
		originalGui.Enabled = false

		local guiClone = originalGui:Clone()
		guiClone.Enabled = true
		local adornTarget = if capacityDisplayPart:IsA("BasePart")
			then capacityDisplayPart
			else capacityDisplayPart:FindFirstChildWhichIsA("BasePart")
		if adornTarget then
			(guiClone :: BillboardGui).Adornee = adornTarget
		end
		guiClone.Parent = playerGui

		local nameLabel = guiClone:FindFirstChild("name")
		if nameLabel and nameLabel:IsA("TextLabel") then
			LiveBind.Bind(nameLabel, "Text", function()
				return `{#activeLeaves}/{LeafStatsState.Capacity}`
			end, { LeafStatsState.Changed.Event })

			-- activeLeaves changes every spawn/collection, not just when
			-- LeafStatsState.Changed fires -- a light poll keeps the
			-- count itself current without needing a signal for every
			-- single spawn/collect.
			task.spawn(function()
				while true do
					task.wait(0.5)
					nameLabel.Text = `{#activeLeaves}/{LeafStatsState.Capacity}`
				end
			end)
		else
			warn("LeafSpawnController: CapacityDisplay's gui has no 'name' TextLabel -- can't bind the current/capacity text.")
		end
	else
		warn("LeafSpawnController: CapacityDisplay has no BillboardGui child named 'gui' -- capacity display won't update.")
	end
else
	warn("LeafSpawnController: no 'CapacityDisplay' found under Area1.Area1Spawner -- skipping the capacity display.")
end


