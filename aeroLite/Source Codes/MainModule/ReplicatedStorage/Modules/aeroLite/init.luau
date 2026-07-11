-- aeroLite Flight Physics
-- by SKYtech

local aeroLite = {
	States = {}
}

local VehicleUtils = require(script.Parent:WaitForChild("VehicleUtils"))
local Environment = require(script:WaitForChild("Environment"))
local Thrust = require(script:WaitForChild("Thrust"))
local Motion = require(script:WaitForChild("Motion"))

function aeroLite:Initialize(aircraft)
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
		},
		Settings = {},
		Connections = {},
		Components = {
			StateWrapper = aircraft.System,
			StateUpdateEvent = aircraft.System.Update,
			MainPart = mainPart,
			Motion = mainPart.Motion,
			Turn = mainPart.Turn,
			Thrust = mainPart.Thrust,
			Lift = mainPart.Lift,
			Gravity = mainPart.Gravity,
			BoundSize = nil,
		},
		IgnoredObjects = {aircraft},
		RayFilter = nil,
		EnvironmentData = {},
		ThrustData = {},
		CalculatedStateFlags = {Taxiing = false, Flying = false, Stalling = false},
		Step = 0,
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

	state.RayFilter = RaycastParams.new()
	state.RayFilter.FilterType = Enum.RaycastFilterType.Exclude

	local _, boundSize = aircraft:GetBoundingBox()
	state.Components.BoundSize = boundSize

	self:Reset(aircraft)
end

function aeroLite:GetState(aircraft)
	return self.States[aircraft]
end

function aeroLite:Reset(aircraft)
	local state = self.States[aircraft]
	local System = state.System
	local Components = state.Components
	local mainPart = Components.MainPart

	local currentCFrame = mainPart.CFrame
	local _, yawAngle, _ = currentCFrame:ToEulerAnglesYXZ()

	System.Speed = -currentCFrame:VectorToObjectSpace(mainPart.AssemblyLinearVelocity).Z
	System.MotionCFrame = currentCFrame
	System.TurnCFrame = VehicleUtils.CFAngles(0, yawAngle + VehicleUtils.Pi/2, 0)

	Components.Motion.CFrame = System.MotionCFrame
	Components.Turn.CFrame = System.TurnCFrame
end

function aeroLite:Update(aircraft, dt, onClient)	
	local state = self.States[aircraft]
	if not state then return end

	state.Step += dt

	local System = state.System
	local Components = state.Components
	local mainPart = Components.MainPart

	if not mainPart:IsGrounded() then
		-- Pipeline Sequence via Context Injection
		Environment.Update(dt, state)
		Thrust.Update(dt, state)
		Motion.Update(dt, state)
	else
		-- Grounded Safety Anchoring
		local mainCFrame = mainPart.CFrame
		local _, yawAngle, _ = mainCFrame:ToEulerAnglesYXZ()
		local realSpeed = mainPart.AssemblyLinearVelocity

		System.Speed = -mainCFrame:VectorToObjectSpace(realSpeed).Z
		Components.Thrust.PlaneVelocity = VehicleUtils.V2New(realSpeed.X, realSpeed.Z)
		Components.Lift.LineVelocity = realSpeed.Y
		System.MotionCFrame = mainCFrame
		System.TurnCFrame = VehicleUtils.CFAngles(0, yawAngle + VehicleUtils.Pi/2, 0)
		Components.Motion.CFrame = System.MotionCFrame
		Components.Turn.CFrame = System.TurnCFrame

		state.CalculatedStateFlags.Taxiing = true
		state.CalculatedStateFlags.Flying = false
		state.CalculatedStateFlags.Stalling = false
	end

	-- Network State Synchronization Loop
	if state.Step >= 0.5 then
		Components.StateWrapper:SetAttribute("Taxiing", state.CalculatedStateFlags.Taxiing)
		Components.StateWrapper:SetAttribute("Flying", state.CalculatedStateFlags.Flying)
		Components.StateWrapper:SetAttribute("Stalling", state.CalculatedStateFlags.Stalling)

		if onClient then
			local attributes = Components.StateWrapper:GetAttributes()
			Components.StateWrapper.Update:FireServer("States", {
				Taxiing = attributes.Taxiing,
				Flying = attributes.Flying,
				Stalling = attributes.Stalling
			})
		end
		state.Step -= 0.5
	end
end

function aeroLite:Cleanup(aircraft)
	local state = self.States[aircraft]
	if not state then return end

	for _, connection in pairs(state.Connections) do
		connection:Disconnect()
	end
	state.Connections = nil
	self.States[aircraft] = nil
end

return aeroLite