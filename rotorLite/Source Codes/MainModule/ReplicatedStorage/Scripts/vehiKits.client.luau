-- Handle flight physics locally in case no pilot is seated and the aircraft's network is still client-owned.

local kitNames = {
	["aeroMini"] = true,
	["aeroLite"] = true,
	["aeroKit"] = true,
	["rotorLite"] = true,
	["rotorKit"] = true,
}
local loadedKits = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("SKYtech Systems"):WaitForChild("Modules")
local player = Players.LocalPlayer
local userId = player.UserId

-- Cache the humanoid's SeatPart to eliminate per-frame property access.
local humanoid = nil
local seatPart = nil
local seatConn = nil

local function setupHumanoidCache(char)
	if seatConn then
		seatConn:Disconnect()
		seatConn = nil
	end

	humanoid = char:WaitForChild("Humanoid")
	seatPart = humanoid.SeatPart
	seatConn = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		seatPart = humanoid.SeatPart
	end)
end

local character = player.Character
if character then setupHumanoidCache(character) end
player.CharacterAdded:Connect(setupHumanoidCache)

-- Cache tracked aircraft states to eliminate per-frame C++ engine queries.
local trackedAircraft = {}

local function trackAircraft(aircraft, core)
	local data = {
		core = core,
		networkOwner = aircraft:GetAttribute("NetworkOwner"),
		inWorkspace = aircraft:IsDescendantOf(workspace),
		connections = {},
	}

	-- Update cached owner when changed rather than polling.
	table.insert(data.connections, aircraft:GetAttributeChangedSignal("NetworkOwner"):Connect(function()
		data.networkOwner = aircraft:GetAttribute("NetworkOwner")
	end))

	-- Update cached workspace ancestry when changed rather than polling.
	table.insert(data.connections, aircraft.AncestryChanged:Connect(function()
		data.inWorkspace = aircraft:IsDescendantOf(workspace)
	end))

	trackedAircraft[aircraft] = data
end

local function untrackAircraft(aircraft)
	local data = trackedAircraft[aircraft]
	if not data then return end
	for _, conn in data.connections do
		conn:Disconnect()
	end
	trackedAircraft[aircraft] = nil
end

local function initializeKit(kitName, module)
	local core = require(module)
	local tagName = "SKYtech " .. kitName

	for _, instance in CollectionService:GetTagged(tagName) do
		trackAircraft(instance, core)
	end

	CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
		trackAircraft(instance, core)
	end)

	CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
		untrackAircraft(instance)
	end)
end

-- Initialize active kit modules
for kitName in kitNames do
	task.spawn(function()
		local module = Modules:WaitForChild(kitName, 10)
		if not module then return end
		if loadedKits[kitName] then return end
		loadedKits[kitName] = true
		initializeKit(kitName, module)
	end)
end

-- Listen for runtime kit modules
Modules.ChildAdded:Connect(function(module)
	local kitName = module.Name
	if not kitNames[kitName] then return end
	if loadedKits[kitName] then return end
	loadedKits[kitName] = true
	initializeKit(kitName, module)
end)

local accumulated = 0
local clockSpeed = 1 / 10 -- 10Hz update rate for non-seated aircraft

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.05)
	accumulated += dt
	local cycled = accumulated >= clockSpeed

	for aircraft, data in trackedAircraft do
		if not data.inWorkspace then continue end
		if data.networkOwner ~= userId then continue end

		if humanoid then
			if seatPart and seatPart:IsDescendantOf(aircraft) then
				-- Player is active pilot: update physics at full frame rate
				data.core:Update(aircraft, dt, true)
			elseif cycled then
				-- Aircraft is unpiloted: throttle physics updates to 10Hz to save CPU
				data.core:Update(aircraft, accumulated, true)
			end
		end
	end

	if cycled then
		accumulated = accumulated % clockSpeed
	end
end)