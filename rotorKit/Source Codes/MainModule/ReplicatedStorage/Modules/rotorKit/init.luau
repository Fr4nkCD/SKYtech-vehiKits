-- rotorKit Flight Physics
-- by SKYtech

local rotorKit = {
	States = {}
}

local VehicleUtils = require(script.Parent:WaitForChild("VehicleUtils"))
local Environment = require(script:WaitForChild("Environment"))
local Lift = require(script:WaitForChild("Lift"))
local Motion = require(script:WaitForChild("Motion"))

function rotorKit:Initialize(aircraft)
	local main = aircraft.Main
	local mainPart = main.Main

	self.States[aircraft] = {
		AircraftInstance = aircraft,
		Utils = VehicleUtils,
		System = {
			Collective = 0,
			Roll = 0,
			Pitch = 0,
			Yaw = 0,
			Hovering = false,
		},
		Settings = {},
		Connections = {},
		Components = {
			MainPart = mainPart,
			Stats_ = main.Stats,
			Motion = mainPart.Motion,
			Lift = mainPart.Lift,
			Aerodynamics = mainPart.Aerodynamics,
			Gravity = mainPart.Gravity,
			StateWrapper = aircraft.System,
		},
		EnvironmentData = {},
		LiftData = {},
	}

	local state = self.States[aircraft]
	local Settings = aircraft:FindFirstChild("Settings")

	for attrName, attrValue in pairs(Settings:GetAttributes()) do
		VehicleUtils.UpdateSetting(attrName, attrValue, state.Settings)
	end	

	if VehicleUtils.IsClient() then
		VehicleUtils.SyncLegacyValues(Settings, state.Connections)
	end

	table.insert(state.Connections, Settings.AttributeChanged:Connect(function(attrName)
		local attrValue = Settings:GetAttribute(attrName)
		if attrValue == nil then return end
		VehicleUtils.UpdateSetting(attrName, attrValue, state.Settings)
	end))
end

function rotorKit:GetState(aircraft)
	return self.States[aircraft]
end

function rotorKit:Update(aircraft, dt, onClient)
	local state = self.States[aircraft]
	if not state then return end

	local mainPart = state.Components.MainPart

	if not mainPart:IsGrounded() then
		-- Pipeline Sequence via Context Injection
		Environment.Update(dt, state)
		Lift.Update(dt, state)
		Motion.Update(dt, state)
	end
end

function rotorKit:Cleanup(aircraft)
	local state = self.States[aircraft]
	if not state then return end

	for _, connection in pairs(state.Connections) do
		connection:Disconnect()
	end
	state.Connections = nil
	self.States[aircraft] = nil
end

return rotorKit
