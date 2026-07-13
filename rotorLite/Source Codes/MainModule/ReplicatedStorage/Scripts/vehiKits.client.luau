-- Handle flight physics locally in case of no pilot is seated and the aircraft's network is still owned.

local kitNames = {
	["aeroMini"] = true,
	["aeroLite"] = true,
	["aeroKit"] = true,
	["rotorLite"] = true,
	["rotorKit"] = true,
}
local loadedKits = {}

---------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("SKYtech Systems"):WaitForChild("Modules")
local player = Players.LocalPlayer

-- Cache the humanoid's SeatPart to eliminate per-frame property access.
local humanoid = nil
local seatPart = nil

local function setupHumanoidCache(char)
	humanoid = char:WaitForChild("Humanoid")
	seatPart = humanoid.SeatPart
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		seatPart = humanoid.SeatPart
	end)
end

local character = player.Character
if character then setupHumanoidCache(character) end
player.CharacterAdded:Connect(setupHumanoidCache)

-- Per-aircraft cached state to eliminate per-frame C++ engine queries.
-- Structure: aircraft -> { core, networkOwner, inWorkspace, connections }
local trackedAircraft = {}

local function trackAircraft(aircraft, core)
	local data = {
		core = core,
		networkOwner = aircraft:GetAttribute("NetworkOwner"),
		inWorkspace = aircraft:IsDescendantOf(workspace),
		connections = {},
	}

	-- Cache network owner changes via event instead of polling every frame.
	table.insert(data.connections, aircraft:GetAttributeChangedSignal("NetworkOwner"):Connect(function()
		data.networkOwner = aircraft:GetAttribute("NetworkOwner")
	end))

	-- Cache workspace ancestry via event instead of polling every frame.
	table.insert(data.connections, aircraft.AncestryChanged:Connect(function()
		data.inWorkspace = aircraft:IsDescendantOf(workspace)
	end))

	trackedAircraft[aircraft] = data
end

local function untrackAircraft(aircraft)
	local data = trackedAircraft[aircraft]
	if not data then return end
	for _, conn in ipairs(data.connections) do
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

for kitName in kitNames do -- Existing kit modules
	task.spawn(function()
		local module = Modules:WaitForChild(kitName, 10)
		if not module then return end
		-- Atomic guard: ChildAdded may have already processed this kit during the WaitForChild yield.
		if loadedKits[kitName] then return end
		loadedKits[kitName] = true
		initializeKit(kitName, module)
	end)
end

-- Newly added kit modules (e.g. installed at runtime by another kit's loader).
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
	local cycled = accumulated >= clockSpeed -- Per-frame local, not a persistent upvalue

	for aircraft, data in trackedAircraft do
		if not data.inWorkspace then continue end
		if data.networkOwner ~= player.UserId then continue end

		if humanoid then
			if seatPart and seatPart:IsDescendantOf(aircraft) then
				-- Player is seated in this aircraft: update every frame at full rate.
				data.core:Update(aircraft, dt, true)
			elseif cycled then
				-- No pilot present: update at the reduced 10Hz rate to save CPU.
				data.core:Update(aircraft, accumulated, true)
			end
		end
	end

	if cycled then
		-- Modulo gracefully absorbs lag spikes without compounding catch-up frames.
		accumulated = accumulated % clockSpeed
	end
end)