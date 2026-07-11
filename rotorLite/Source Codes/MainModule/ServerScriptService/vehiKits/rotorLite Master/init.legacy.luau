-- Server Master

local kitName = "rotorLite" -- Change here
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

function setupAircraft(aircraft)
	local connections = {}
	local runTask = nil

	local Settings, main, mainPart, Stats_, pilotSeat, kitSystem, kitGui, legacyValues

	local function wake()
		runTask = task.spawn(function()
			-- Initialize aircraft
			Settings, main, mainPart, Stats_, pilotSeat, kitSystem, kitGui, legacyValues
				= Master.Initialize(
					kitName,
					aircraft,
					Presets,
					connections,
					LegacySyncing,
					Welder
				)

			-- Pilot seat interaction
			local handler = kitSystem.Handler
			local pilotValue = handler.Pilot

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
					handler,
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

					-- Client controlled identifier
					local ClientControlled = Settings:GetAttribute("Advanced/ClientControlled") == true
					if kitSystem:GetAttribute("Client_Controlled") ~= ClientControlled then
						kitSystem:SetAttribute("Client_Controlled", ClientControlled)
						kitCore:Reset(aircraft)
					end

					-- Network ownership
					local networkOwner = NetworkManager.GetNetworkOwner(mainPart)
					local canResetNetwork = Settings:GetAttribute("Advanced/ResetNetwork") == true
					NetworkManager.UpdateNetworkOwner(activePilot, mainPart, aircraft, ClientControlled, canResetNetwork)

					-- Physics update (server)
					if (not activePilot or not ClientControlled) and not networkOwner then
						local states = aircraftState.System
						local attributes = Stats_:GetAttributes()

						local motion = attributes.Motion or Vector3.zero
						states.Collective		= attributes.Collective or 0
						states.MousePosition	= attributes.TargetPosition
						states.Roll 			= motion.X
						states.Pitch 			= motion.Y
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

					-- Fuel system
					if Settings:GetAttribute("FuelSystem/Enabled") == true then
						local consumptionRate = Settings:GetAttribute("FuelSystem/Consumption") or 0.025
						FuelManagement.ProcessBurn("Collective", consumptionRate, Stats_, accumulated, legacyValues.Fuel)
					end
					
					local isActive = Stats_:GetAttribute("Active") == true
					-- Force shutdown if the fuel is empty.
					if Stats_:GetAttribute("Fuel") <= 0 and isActive then
						Stats_:SetAttribute("Active", false)
						Stats_:SetAttribute("Collective", 0)
					end
					-- Force the collective at 0 if the aircraft is inactive.
					if not isActive and Stats_:GetAttribute("Collective") > 0 then
						Stats_:SetAttribute("Collective", 0)
					end

					accumulated -= clockSpeed
				end
			end))
			
			-- Legacy values
			for name, value :ObjectValue in (legacyValues) do
				if name == "Fuel" then continue end

				if value then
					LegacySyncing.SyncValue(name, value, Stats_, connections)
				end
			end
		end)
	end

	local function sleep()
		for _, connection in (connections) do
			connection:Disconnect()
		end
		connections = {}

		if runTask then task.cancel(runTask) end
		runTask = nil

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