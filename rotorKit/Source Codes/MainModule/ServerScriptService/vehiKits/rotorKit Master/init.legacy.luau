-- Server Master

local kitName = "rotorKit" -- Change here
local licenseName = kitName.."_License"

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folderName = "SKYtech Systems"
local kitCore = require(ReplicatedStorage:WaitForChild(folderName):WaitForChild("Modules"):WaitForChild(kitName))

local internalModules = script.Modules
local externalModules = script.Parent.Parent:WaitForChild("Modules")

-- Modules
local Presets = require(internalModules.Presets)
local Master = require(internalModules.Master)
local Welder = require(externalModules:WaitForChild("Welder"))
local LegacySyncing = require(externalModules:WaitForChild("LegacySyncing"))
local NetworkManager = require(externalModules:WaitForChild("NetworkManager"))
local FuelManagement = require(externalModules:WaitForChild("FuelManagement"))

--------------------------------------------------------------------------------------

local function setupAircraft(aircraft)
	local connections = {}

	local Settings, main, mainPart, Stats_, pilotSeat, kitSystem, kitGui, legacyValues
	
	-- Cached settings to avoid per-tick C++ cross-boundary attribute lookups
	local clientControlled = false
	local resetNetwork = false
	local fuelConsumptionRate = 0.025
	local physicsScaleReciprocal = 1

	local function wake()
		-- Initialize aircraft components (synchronous setup)
		Settings, main, mainPart, Stats_, pilotSeat, kitSystem, kitGui, legacyValues = Master.Initialize(
			kitName,
			aircraft,
			Presets,
			connections,
			LegacySyncing,
			Welder
		)

		-- Cache values and listen for configuration changes dynamically
		local function updateClientControlled()
			clientControlled = Settings:GetAttribute("Advanced/ClientControlled") == true
		end
		local function updateResetNetwork()
			resetNetwork = Settings:GetAttribute("Advanced/ResetNetwork") == true
		end
		local function updateFuelConsumption()
			fuelConsumptionRate = Settings:GetAttribute("AircraftStatistics/FuelConsumption") or 0.025
		end
		local function updatePhysicsScale()
			local scale = Settings:GetAttribute("Modifications/PhysicsScale") or Settings:GetAttribute("Advanced/PhysicsScale") or 1
			physicsScaleReciprocal = 1 / math.max(scale, 0.001)
		end

		updateClientControlled()
		updateResetNetwork()
		updateFuelConsumption()
		updatePhysicsScale()

		table.insert(connections, Settings:GetAttributeChangedSignal("Advanced/ClientControlled"):Connect(updateClientControlled))
		table.insert(connections, Settings:GetAttributeChangedSignal("Advanced/ResetNetwork"):Connect(updateResetNetwork))
		table.insert(connections, Settings:GetAttributeChangedSignal("AircraftStatistics/FuelConsumption"):Connect(updateFuelConsumption))
		table.insert(connections, Settings:GetAttributeChangedSignal("Modifications/PhysicsScale"):Connect(updatePhysicsScale))
		table.insert(connections, Settings:GetAttributeChangedSignal("Advanced/PhysicsScale"):Connect(updatePhysicsScale))

		-- Pilot seat interaction
		local pilotValue = kitSystem.Pilot

		if pilotSeat and kitGui then
			Master.HandlePilotSeat(
				licenseName,
				aircraft,
				kitCore,
				Settings,
				mainPart,
				pilotValue,
				pilotSeat,
				kitGui,
				kitSystem,
				connections,
				NetworkManager
			)
		end

		-- Stats update
		Master.UpdateStats(
			licenseName,
			kitSystem,
			Stats_,
			connections
		)

		-- Server update
		kitCore:Initialize(aircraft)
		local aircraftState = kitCore:GetState(aircraft)
		
		local accumulated = 0
		local clockSpeed = 1 / 10 -- Hz
		table.insert(connections, RunService.Heartbeat:Connect(function(dt)
			dt = math.min(dt, 0.05)
			accumulated += dt
			if accumulated >= clockSpeed then
				local activePilot = pilotValue.Value

				-- Client controlled identifier state sync
				if kitSystem:GetAttribute("Client_Controlled") ~= clientControlled then
					kitSystem:SetAttribute("Client_Controlled", clientControlled)
				end

				-- Network ownership
				local networkOwner = NetworkManager.GetNetworkOwner(mainPart)
				NetworkManager.UpdateNetworkOwner(activePilot, mainPart, aircraft, clientControlled, resetNetwork)

				-- Physics update (server)
				if (not activePilot or not clientControlled) and not networkOwner then
					local states = aircraftState.System
					local attributes = Stats_:GetAttributes()

					local motion = attributes.Motion or Vector3.zero
					states.Collective		= attributes.Collective or 0
					states.Roll 			= motion.X
					states.Pitch 			= motion.Y
					states.Yaw 				= motion.Z

					kitCore:Update(aircraft, accumulated, false)
				end

				-- Fuel system
				FuelManagement.ProcessBurn("Collective", fuelConsumptionRate, Stats_, accumulated, legacyValues.Fuel)
					
				local isActive = Stats_:GetAttribute("Active") == true
				-- Force shutdown if the fuel is empty.
				if Stats_:GetAttribute("Fuel") <= 0 and isActive then
					Stats_:SetAttribute("Active", false)
				end
				
				-- Rotor drag and autorotation (optimized calculations)
				local localVelocity = (mainPart.CFrame:VectorToObjectSpace(mainPart.AssemblyLinearVelocity)) * physicsScaleReciprocal
				
				local RPM = Stats_:GetAttribute("RPM") or 0
				local collective = Stats_:GetAttribute("Collective") or 0
				
				local autorotation = math.abs(100 - RPM) / 15000 * (localVelocity.Y + localVelocity.Z) * RPM / 100
				local rotorDrag = 0.0001 + collective / 10000 + RPM / 5000 + math.max(localVelocity.Y / 400, 0) + autorotation
				local dragFactor = 1 - math.exp(-accumulated * 30)
				Stats_:SetAttribute("RPM", math.clamp(RPM - rotorDrag * dragFactor, 0, 110))

				-- Modulo handles lag spikes elegantly without compounding frames
				accumulated = accumulated % clockSpeed
			end
		end))
		
		-- Legacy values syncing
		for name, value :ObjectValue in (legacyValues) do
			if name == "Fuel" then continue end

			if value then
				LegacySyncing.SyncValue(name, value, Stats_, connections)
			end
		end
	end

	local function sleep()
		for _, connection in (connections) do
			connection:Disconnect()
		end
		connections = {}

		kitCore:Cleanup(aircraft)
	end

	local cleanup
	cleanup = aircraft.AncestryChanged:Connect(function(instance, parent)
		if parent then
			if aircraft:IsDescendantOf(workspace) then
				wake()
			else
				sleep()
			end
		else
			sleep()
			aircraft = nil
			cleanup:Disconnect()
			cleanup = nil
		end
	end)

	if aircraft:IsDescendantOf(workspace) then
		wake()
	end
end

for _, aircraft in (CollectionService:GetTagged("SKYtech "..kitName)) do
	setupAircraft(aircraft)
end

CollectionService:GetInstanceAddedSignal("SKYtech "..kitName):Connect(setupAircraft)