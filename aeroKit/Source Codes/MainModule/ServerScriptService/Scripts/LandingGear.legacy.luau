-- Default landing gear script for all aircraft kits.

local tagName = "SKYtech_LandingGear"

local CollectionService = game:GetService("CollectionService")

local function getParts(group, groupTable)
	for _, v in (group:GetDescendants()) do
		if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
			table.insert(groupTable, v)
		end
	end
end

local function createValues(parts)
	for _, p in (parts) do
		p:SetAttribute("DefaultTransparency", p.Transparency)
		if p:IsA("BasePart") then
			p:SetAttribute("DefaultCanCollide", p.CanCollide)
		end
	end
end

local function updateGear(gearStats, extendedGroup, retractedGroup)
	local toggle = gearStats:GetAttribute("Toggle") == true

	for _, part in (extendedGroup) do
		part.Transparency = if toggle then part:GetAttribute("DefaultTransparency") else 1
		if part:IsA("BasePart") then
			part.CanCollide = if toggle then part:GetAttribute("DefaultCanCollide") else false
		end
	end

	for _, part in (retractedGroup) do
		part.Transparency = if toggle then 1 else part:GetAttribute("DefaultTransparency")
		if part:IsA("BasePart") then
			part.CanCollide = if toggle then false else part:GetAttribute("DefaultCanCollide")
		end
	end
end

local function checkGround(aircraft, mainPart, boundCFrame, lowestPoint, filter)
	local onGround = false

	local raycastResult = workspace:Raycast(boundCFrame.Position, mainPart.CFrame.UpVector * lowestPoint, filter)

	if raycastResult then
		local instance = raycastResult.Instance
		local model = instance:FindFirstAncestorOfClass("Model") -- Check for possible ancestor model
		if model == nil then -- Part
			onGround = instance.CanCollide
		else -- Model
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid == nil then
				onGround = instance.CanCollide
			end
		end
	else
		onGround = false
	end

	return onGround
end

local function setupLandingGear(landingGear)
	local connections = {}
	local initialized = false
	local available = false
	local runTask = nil

	local aircraft = landingGear.Parent.Parent
	local Settings
	local mainPart = landingGear.Parent.Main

	local mods = landingGear.Parent.Mods
	local gearStats
	local remoteEvent

	local extendedGroup = {}
	local retractedGroup = {}

	local boundCFrame, boundSize
	local lowestPoint

	local onGround = true
	local filter = RaycastParams.new()
	filter.FilterType = Enum.RaycastFilterType.Exclude

	local function physicalInitialize()
		Settings = aircraft:WaitForChild("Settings")
		gearStats = mods:FindFirstChild("Landing_Gear") or mods:FindFirstChild("LandingGear")

		if gearStats then
			remoteEvent = gearStats:FindFirstChild("Remote")
		else
			gearStats = Instance.new("Folder")
			gearStats.Name = "LandingGear"

			gearStats:SetAttribute("Available", false)
			gearStats:SetAttribute("Toggle", gearStats:GetAttribute("Toggle") or true)

			remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = "Remote"
			remoteEvent.Parent = gearStats

			gearStats.Parent = mods
		end

		getParts(landingGear.Extended, extendedGroup)
		getParts(landingGear.Retracted, retractedGroup)

		if #extendedGroup > 0 then -- Check for extended group
			createValues(extendedGroup)
		end
		if #retractedGroup > 0 then -- Check for retracted group
			createValues(retractedGroup)
		end

		available = #extendedGroup > 0 or #retractedGroup > 0
		gearStats:SetAttribute("Available", available)

		initialized = true
	end

	local function wake()
		if runTask or #connections > 0 then return end

		if not initialized then
			physicalInitialize()
		end

		if not available then
			return
		end

		runTask = task.spawn(function()
			table.insert(connections, remoteEvent.OnServerEvent:Connect(function()
				boundCFrame, boundSize = aircraft:GetBoundingBox()
				local _lowestPoint = Settings:GetAttribute("Advanced/LowestPoint")
				lowestPoint = if _lowestPoint == "Auto" then boundSize.Y * 0.55 else math.abs(_lowestPoint)

				filter.FilterDescendantsInstances = {aircraft}
				onGround = checkGround(aircraft, mainPart, boundCFrame, -lowestPoint, filter)

				if onGround == true then return end
				gearStats:SetAttribute("Toggle", gearStats:GetAttribute("Toggle") ~= true)
			end))
			
			updateGear(gearStats, extendedGroup, retractedGroup)

			table.insert(connections, gearStats:GetAttributeChangedSignal("Toggle"):Connect(function()
				updateGear(gearStats, extendedGroup, retractedGroup)
			end))
		end)
	end

	local function sleep()
		for _, connection in (connections) do
			connection:Disconnect()
		end
		connections = {}

		if runTask then task.cancel(runTask) end
		runTask = nil
	end

	local cleanup

	local function terminate()
		sleep()

		connections = nil
		landingGear = nil

		if cleanup then
			cleanup:Disconnect()
			cleanup = nil
		end
	end

	cleanup = landingGear.AncestryChanged:Connect(function(instance, parent)
		if parent then
			task.defer(function()
				if landingGear:IsDescendantOf(workspace) then
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
