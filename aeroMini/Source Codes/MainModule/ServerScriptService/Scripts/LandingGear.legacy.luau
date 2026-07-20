-- Default landing gear script for all aircraft kits.
-- Handles gear toggling via RemoteEvents and checks for ground contact to prevent retraction.

local tagName = "SKYtech_LandingGear"
local CollectionService = game:GetService("CollectionService")

-- Build a fast-lookup table of parts/decals to toggle visual states without reading Attributes at runtime.
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

-- Toggles visibility and collision states of gear groups (true = extended, false = retracted).
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

-- Checks if the landing gear is currently in contact with the ground using a raycast.
local function checkGround(mainPart, boundCFrame, lowestPoint, filter)
	local raycastResult = workspace:Raycast(boundCFrame.Position, mainPart.CFrame.UpVector * lowestPoint, filter)
	if not raycastResult then return false end

	local instance = raycastResult.Instance
	local model = instance:FindFirstAncestorOfClass("Model")
	local isGround = if model then model:FindFirstChildOfClass("Humanoid") == nil else true
	return isGround and instance.CanCollide
end

local function setupLandingGear(landingGear)
	local connections = {}    -- Sleep/wake connection list.
	local permanentConns = {} -- Connections that persist across workspace transitions.
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

	local toggle = true   -- Local mirror of Toggle attribute.
	local lowestPoint = 0 -- Cached ground-detection offset distance.
	local boundSize = Vector3.zero

	local filter = RaycastParams.new()
	filter.FilterType = Enum.RaycastFilterType.Exclude
	local filterInstances = { aircraft } -- Cache instance list to avoid garbage.

	-- Prepare physics settings, part lists, and state objects.
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

		_, boundSize = aircraft:GetBoundingBox()

		-- Keep lowestPoint synced with Advanced settings attribute.
		local function updateLowestPoint()
			local lp = Settings:GetAttribute("Advanced/LowestPoint")
			lowestPoint = if lp == "Auto" or lp == nil then boundSize.Y * 0.55 else math.abs(lp)
		end
		updateLowestPoint()

		table.insert(permanentConns,
			Settings:GetAttributeChangedSignal("Advanced/LowestPoint"):Connect(updateLowestPoint))

		initialized = true
	end

	-- Connect listeners and apply current gear visual states when active in workspace.
	local function wake()
		if isAwake then return end
		if not initialized then physicalInitialize() end
		if not available then return end

		isAwake = true

		-- Remote event toggles state if the aircraft is airborne.
		table.insert(connections, remoteEvent.OnServerEvent:Connect(function()
			local boundCFrame = aircraft:GetBoundingBox()
			filter.FilterDescendantsInstances = filterInstances

			local onGround = checkGround(mainPart, boundCFrame, -lowestPoint, filter)
			if onGround then return end

			toggle = not toggle
			gearStats:SetAttribute("Toggle", toggle)
		end))

		-- Synchronize visual state with the "Toggle" attribute.
		table.insert(connections, gearStats:GetAttributeChangedSignal("Toggle"):Connect(function()
			toggle = gearStats:GetAttribute("Toggle") == true
			updateGear(extendedGroup, retractedGroup, toggle)
		end))

		updateGear(extendedGroup, retractedGroup, toggle)
	end

	-- Temporarily suspend listeners when removed from the workspace.
	local function sleep()
		isAwake = false
		for _, conn in connections do
			conn:Disconnect()
		end
		connections = {}
	end

	local cleanup

	-- Clean up all listeners and references when destroyed.
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

for _, landingGear in CollectionService:GetTagged(tagName) do
	setupLandingGear(landingGear)
end

CollectionService:GetInstanceAddedSignal(tagName):Connect(setupLandingGear)