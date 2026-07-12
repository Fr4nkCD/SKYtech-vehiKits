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
		EnvironmentData = {
			PhysicsScale = 0.001,
			GlobalGravity = 196.2,
			MainCFrame = CFrame.new(),
			Position = Vector3.zero,
			WorldVelocity = Vector3.zero,
			LocalVelocity = Vector3.zero,
			SpeedMagnitude = 0,
			Altitude = 0,
			BankAngle = 0,
			IsInverted = false,
			InvertedBankAngle = 0,
			PitchRad = 0,
			PitchAngle = 0,
			RPM = 0,
			Weight = 0,
			Mass = 1,
			Direction_ = Vector3.zero,
			IsHovering = false,
			HorizontalUnit = Vector3.zero,
			HorizontalMagnitude = 0,
		},
		LiftData = {
			LiftForce = 0,
			RateOfClimb = 0,
		},
		RPM_ = 0,
		Direction_ = Vector3.zero,
		IsHovering = false,
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
	local stats = state.Components.Stats_

	if not mainPart:IsGrounded() then
		-- Cache attributes once per frame
		state.RPM_ = stats:GetAttribute("RPM") or 0
		state.Direction_ = stats:GetAttribute("Direction") or Vector3.zero
		state.IsHovering = stats:GetAttribute("Hover") == true

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
