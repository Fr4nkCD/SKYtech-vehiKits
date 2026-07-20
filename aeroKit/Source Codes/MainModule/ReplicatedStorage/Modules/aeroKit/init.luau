-- aeroKit Flight Physics
-- by SKYtech

local aeroKit = {
	States = {}
}

local VehicleUtils = require(script.Parent:WaitForChild("VehicleUtils"))
local Environment = require(script:WaitForChild("Environment"))
local Aerodynamics = require(script:WaitForChild("Aerodynamics"))
local Motion = require(script:WaitForChild("Motion"))

function aeroKit:Initialize(aircraft)
	local main = aircraft.Main
	local mainPart = main.Main

	self.States[aircraft] = {
		AircraftInstance = aircraft,
		Utils = VehicleUtils,
		System = {
			Throttle = 0,
			Brake = 0,
			Roll = 0,
			Pitch = 0,
			Yaw = 0,
			Boost = 0,
			MinSpeed = 0,
			Speed = 0,
			MotionCFrame = CFrame.new(),
			TurnCFrame = CFrame.new(),
			RestingAngle = 0,
			CurrentRoll = 0,
			CurrentPitch = 0,
			VTOLlevel = 0,
			VTOLHovering = false,
			FlightPath = Vector3.zero,
			StallSpinDirection = 0,
			LastYaw = 0,
		},
		Settings = {},
		Connections = {},
		Components = {
			StateWrapper = aircraft.System,
			StateUpdateEvent = aircraft.System.Update,
			MainPart = mainPart,
			Motion = mainPart.Motion,
			Aerodynamics = mainPart.Aerodynamics,
			Gravity = mainPart.Gravity,
			Stats_ = main.Stats,
			BoundSize = nil,
		},
		IgnoredObjects = {aircraft},
		RayFilter = nil,
		EnvironmentData = {},
		AerodynamicsData = {},
		CalculatedStateFlags = {Taxiing = false, Flying = false, Stalling = false, Hovering = false},
		Step = 0,
	}

	local state = self.States[aircraft]
	local Settings = aircraft:FindFirstChild("Settings")

	for attrName, attrValue in Settings:GetAttributes() do
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

	state.RayFilter = RaycastParams.new()
	state.RayFilter.FilterType = Enum.RaycastFilterType.Exclude

	local _, boundSize = aircraft:GetBoundingBox()
	state.Components.BoundSize = boundSize
end

function aeroKit:GetState(aircraft)
	return self.States[aircraft]
end

function aeroKit:Update(aircraft, dt, onClient)	
	local state = self.States[aircraft]
	if not state then return end

	state.Step += dt

	local mainPart = state.Components.MainPart
	local stateWrapper = state.Components.StateWrapper
	local stateUpdateEvent = state.Components.StateUpdateEvent

	local states = state.CalculatedStateFlags

	if not mainPart:IsGrounded() then
		-- Cache standard parameters & attributes for this physics step
		state.System.VTOLlevel = stateWrapper:GetAttribute("VTOL") or 0
		state.System.VTOLHovering = stateWrapper:GetAttribute("Hovering") == true

		-- Pipeline Sequence via Context Injection
		Environment.Update(dt, state)
		Aerodynamics.Update(dt, state)
		Motion.Update(dt, state)
	else
		states.Taxiing = stateWrapper:GetAttribute("Taxiing") or false
		states.Flying = stateWrapper:GetAttribute("Flying") or false
		states.Stalling = stateWrapper:GetAttribute("Stalling") or false
		states.Hovering = stateWrapper:GetAttribute("Hovering") or false
	end
	
	if state.Step >= 0.5 then
		stateWrapper:SetAttribute("Taxiing", states.Taxiing)
		stateWrapper:SetAttribute("Flying", states.Flying)
		stateWrapper:SetAttribute("Stalling", states.Stalling)
		stateWrapper:SetAttribute("Hovering", states.Hovering)

		if onClient then
			stateUpdateEvent:FireServer("States", {
				Taxiing = states.Taxiing,
				Flying = states.Flying,
				Stalling = states.Stalling,
				Hovering = states.Hovering
			})
		end

		state.Step -= 0.5
	end
end

function aeroKit:Cleanup(aircraft)
	local state = self.States[aircraft]
	if not state then return end

	for _, connection in state.Connections do
		connection:Disconnect()
	end
	state.Connections = nil
	self.States[aircraft] = nil
end

return aeroKit