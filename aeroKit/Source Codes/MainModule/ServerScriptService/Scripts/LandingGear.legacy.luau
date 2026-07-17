-- Default landing gear script for all aircraft kits.

local tagName = "SKYtech_LandingGear"
local CollectionService = game:GetService("CollectionService")

-- Pre-build a Lua-side part data table so updateGear reads from fast local tables
-- instead of calling :GetAttribute() per part per toggle.
local function buildPartData(group, dataTable)
	for _, v in group:GetDescendants() do
		if v:IsA("BasePart") then
			table.insert(dataTable, {
				part = v,
				transparency = v.Transparency,
				canCollide = v.CanCollide,
			})
		elseif v:IsA("Decal") or v:IsA("Texture") then
			table.insert(dataTable, {
				part = v,
				transparency = v.Transparency,
			})
		end
	end
end

-- toggle: true = extended (gear down), false = retracted (gear up).
-- Reads from pre-built Lua tables — zero attribute queries per call.
local function updateGear(extendedGroup, retractedGroup, toggle)
	for _, data in extendedGroup do
		data.part.Transparency = if toggle then data.transparency else 1
		if data.canCollide ~= nil then
			data.part.CanCollide = if toggle then data.canCollide else false
		end
	end
	for _, data in retractedGroup do
		data.part.Transparency = if toggle then 1 else data.transparency
		if data.canCollide ~= nil then
			data.part.CanCollide = if toggle then false else data.canCollide
		end
	end
end

local function checkGround(mainPart, boundCFrame, lowestPoint, filter)
	local raycastResult = workspace:Raycast(boundCFrame.Position, mainPart.CFrame.UpVector * lowestPoint, filter)
	if not raycastResult then return false end

	local instance = raycastResult.Instance
	local model = instance:FindFirstAncestorOfClass("Model")
	if model == nil then
		return instance.CanCollide
	else
		-- Only count as ground if there is no humanoid (excludes players/NPCs).
		return model:FindFirstChildOfClass("Humanoid") == nil and instance.CanCollide
	end
end

local function setupLandingGear(landingGear)
	local connections = {}    -- Wake/sleep-managed connections.
	local permanentConns = {} -- Connections that persist across wake/sleep cycles.
	local initialized = false
	local available = false
	local isAwake = false

	local aircraft = landingGear.Parent.Parent
	local Settings
	local mainPart = landingGear.Parent.Main
	local mods = landingGear.Parent.Mods

	local gearStats
	local remoteEvent

	local extendedGroup = {}
	local retractedGroup = {}

	local toggle = true         -- Local mirror of the "Toggle" attribute.
	local lowestPoint = 0       -- Cached from settings; rarely changes at runtime.
	local boundSize = Vector3.zero  -- Cached bounding size; geometry is fixed.
	local boundCFrame               -- Updated per toggle request (aircraft moves).
	local onGround = true

	local filter = RaycastParams.new()
	filter.FilterType = Enum.RaycastFilterType.Exclude
	local filterInstances = { aircraft } -- Cached to avoid per-toggle table allocation.

	local function physicalInitialize()
		Settings = aircraft:WaitForChild("Settings")
		gearStats = mods:FindFirstChild("Landing_Gear") or mods:FindFirstChild("LandingGear")

		if gearStats then
			remoteEvent = gearStats:FindFirstChild("Remote")
			toggle = gearStats:GetAttribute("Toggle") == true
		else
			gearStats = Instance.new("Folder")
			gearStats.Name = "LandingGear"
			gearStats:SetAttribute("Available", false)
			gearStats:SetAttribute("Toggle", true)

			remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = "Remote"
			remoteEvent.Parent = gearStats
			gearStats.Parent = mods
		end

		buildPartData(landingGear.Extended, extendedGroup)
		buildPartData(landingGear.Retracted, retractedGroup)

		available = #extendedGroup > 0 or #retractedGroup > 0
		gearStats:SetAttribute("Available", available)

		-- Cache bounding size once — aircraft geometry is fixed at runtime.
		_, boundSize = aircraft:GetBoundingBox()

		-- Cache lowestPoint and keep it synced if the setting changes.
		local function updateLowestPoint()
			local lp = Settings:GetAttribute("Advanced/LowestPoint")
			lowestPoint = if lp == "Auto" or lp == nil then boundSize.Y * 0.55 else math.abs(lp)
		end
		updateLowestPoint()

		-- Permanent: this listener must survive wake/sleep cycles.
		table.insert(permanentConns,
			Settings:GetAttributeChangedSignal("Advanced/LowestPoint"):Connect(updateLowestPoint))

		initialized = true
	end

	local function wake()
		if isAwake then return end
		if not initialized then physicalInitialize() end
		if not available then return end

		isAwake = true

		table.insert(connections, remoteEvent.OnServerEvent:Connect(function()
			-- Only refresh CFrame per toggle — boundSize is already cached.
			boundCFrame = aircraft:GetBoundingBox()
			filter.FilterDescendantsInstances = filterInstances
			onGround = checkGround(mainPart, boundCFrame, -lowestPoint, filter)

			if onGround then return end
			-- Flip the local mirror first, then write to the attribute once.
			toggle = not toggle
			gearStats:SetAttribute("Toggle", toggle)
		end))

		table.insert(connections, gearStats:GetAttributeChangedSignal("Toggle"):Connect(function()
			-- Sync local mirror in case of external attribute changes.
			toggle = gearStats:GetAttribute("Toggle") == true
			updateGear(extendedGroup, retractedGroup, toggle)
		end))

		updateGear(extendedGroup, retractedGroup, toggle)
	end

	local function sleep()
		isAwake = false
		for _, conn in connections do
			conn:Disconnect()
		end
		connections = {}
	end

	local cleanup

	local function terminate()
		sleep()
		for _, conn in permanentConns do
			conn:Disconnect()
		end
		permanentConns = {}
		connections = nil
		landingGear = nil
		if cleanup then
			cleanup:Disconnect()
			cleanup = nil
		end
	end

	cleanup = landingGear.AncestryChanged:Connect(function(_, parent)
		if parent then
			task.defer(function()
				if landingGear and landingGear:IsDescendantOf(workspace) then
					wake()
				else
					sleep()
				end
			end)
		else
			terminate()
		end
	end)

	if landingGear:IsDescendantOf(workspace) then
		wake()
	end
end

for _, landingGear in (CollectionService:GetTagged(tagName)) do
	setupLandingGear(landingGear)
end

CollectionService:GetInstanceAddedSignal(tagName):Connect(setupLandingGear)