-- Server Master

local kitName = "aeroKit" -- Change here
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

--------------------------------------------------------------------------------------

local function setupAircraft(aircraft)
	local connections = {}
	
	local Settings, main, mainPart, Stats_, pilotSeat, kitSystem, kitGui, legacyValues
	
	-- Cached settings to avoid per-tick C++ cross-boundary attribute lookups
	local clientControlled = false
	local resetNetwork = false

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

		updateClientControlled()
		updateResetNetwork()

		table.insert(connections, Settings:GetAttributeChangedSignal("Advanced/ClientControlled"):Connect(updateClientControlled))
		table.insert(connections, Settings:GetAttributeChangedSignal("Advanced/ResetNetwork"):Connect(updateResetNetwork))

		-- Pilot seat interaction
		local pilotValue = kitSystem.Pilot

		if pilotSeat and kitGui then
			Master.HandlePilotSeat(
				licenseName,
				aircraft,
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
					states.Throttle			= attributes.Throttle or 0
					states.Brake 			= attributes.Brake or 0
					states.Roll 			= motion.X
					states.Pitch 			= motion.Y + (attributes.Trim or 0)
					states.Yaw 				= motion.Z

					states.Boost 			= attributes.Boost or states.Boost
					states.MinSpeed 		= attributes.MinSpeed or states.MinSpeed

					local speedChange = attributes.Speed
					if speedChange then
						states.Speed = speedChange
						Stats_:SetAttribute("Speed", nil)
					end

					local motionCFrameChange = attributes.MotionCFrame
					if motionCFrameChange then
						states.MotionCFrame = motionCFrameChange
						Stats_:SetAttribute("MotionCFrame", nil)
					end

					kitCore:Update(aircraft, accumulated, false)
				end
				
				local isActive = Stats_:GetAttribute("Active") == true
				local fuel = Stats_:GetAttribute("Fuel")
				-- Force shutdown if the fuel is empty.
				if fuel and fuel <= 0 and isActive then
					Stats_:SetAttribute("Active", false)
					Stats_:SetAttribute("Throttle", 0)
				end
				-- Force the throttle at 0 if the aircraft is inactive.
				if not isActive and Stats_:GetAttribute("Throttle") > 0 then
					Stats_:SetAttribute("Throttle", 0)
				end

				-- Modulo handles lag spikes elegantly without compounding frames
				accumulated = accumulated % clockSpeed
			end
		end))
		
		-- Legacy values syncing
		for name, value :ObjectValue in legacyValues do
			if value then
				LegacySyncing.SyncValue(name, value, Stats_, connections)
			end
		end
	end

	local function sleep()
		for _, connection in connections do
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

for _, aircraft in CollectionService:GetTagged("SKYtech "..kitName) do
	setupAircraft(aircraft)
end

CollectionService:GetInstanceAddedSignal("SKYtech "..kitName):Connect(setupAircraft)