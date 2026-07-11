-- rotorLite Flight Physics
-- by SKYtech

local rotorLite = {
	States = {}
}

local VehicleUtils = require(script.Parent:WaitForChild("VehicleUtils"))
local Environment = require(script:WaitForChild("Environment"))
local Lift = require(script:WaitForChild("Lift"))
local Motion = require(script:WaitForChild("Motion"))

function rotorLite:Initialize(aircraft)
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
			Forward = 0,
			DynamicForwardDrag = 0,
			SidewaysSpeed = 0,
			Velocity = Vector3.zero,
			Direction = Vector3.zero,
			RollAccumulated = 0,
			MotionCFrame = CFrame.new(),
			MaxForce = 0,
			OnClient = false,
		},
		Settings = {},
		Connections = {},
		Components = {
			MainPart = mainPart,
			Motion = mainPart.Motion,
			Lift = mainPart.Lift,
			Gravity = mainPart.Gravity,
			Stats_ = main.Stats,
		},
		IgnoredObjects = {aircraft},
		EnvironmentData = {},
		ThrustData = {}
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

	self:Reset(aircraft)
end

function rotorLite:GetState(aircraft)
	return self.States[aircraft]
end

function rotorLite:Reset(aircraft)
	local state = self.States[aircraft]
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local mainPart = Components.MainPart

	local physicsScale = VehicleUtils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local mainCFrame = mainPart.CFrame
	local velocity = mainPart.AssemblyLinearVelocity / physicsScale
	local bankAngle = -VehicleUtils.Deg(VehicleUtils.GetRoll(mainCFrame)) + 360

	System.MaxForce = VehicleUtils.Clamp(System.Collective / 0.1 + velocity.Magnitude / 20, 0, 1) * (if Components.Stats_:GetAttribute("Active") == true then 1 else 0)
	System.Forward = -mainCFrame:VectorToObjectSpace(velocity).Z
	System.SidewaysSpeed = mainCFrame:VectorToObjectSpace(velocity).X
	System.Velocity = velocity * physicsScale
	System.RollAccumulated = VehicleUtils.Rad(bankAngle)
	System.Direction = mainCFrame.LookVector * 1e6
	System.MotionCFrame = mainCFrame
	
	Components.Motion.CFrame = System.MotionCFrame
end

function rotorLite:Update(aircraft, dt, onClient)	
	local state = self.States[aircraft]
	if not state then return end
	
	local System = state.System
	local Components = state.Components
	local mainPart = Components.MainPart
	
	System.OnClient = onClient

	if not mainPart:IsGrounded() then
		-- Ordered calculation pipeline execution
		Environment.Update(dt, state)
		Lift.Update(dt, state)
		Motion.Update(dt, state)
	else
		local mainCFrame = mainPart.CFrame
		local physicsScale = VehicleUtils.Max(state.Settings.Modifications.PhysicsScale or state.Settings.Advanced.PhysicsScale, 0.001)
		local velocity = mainPart.AssemblyLinearVelocity / physicsScale
		local bankAngle = -VehicleUtils.Deg(VehicleUtils.GetRoll(mainCFrame)) + 360
		
		System.MaxForce = VehicleUtils.Clamp(System.Collective / 0.1 + velocity.Magnitude / 20, 0, 1) * (if Components.Stats_:GetAttribute("Active") == true then 1 else 0)
		System.Forward = -mainCFrame:VectorToObjectSpace(velocity).Z
		System.SidewaysSpeed = mainCFrame:VectorToObjectSpace(velocity).X
		System.Velocity = velocity * physicsScale
		System.RollAccumulated = VehicleUtils.Rad(bankAngle)
		System.Direction = mainCFrame.LookVector * 1e6
		System.MotionCFrame = mainCFrame
		
		Components.Motion.CFrame = System.MotionCFrame
	end
end

function rotorLite:Cleanup(aircraft)
	local state = self.States[aircraft]
	if not state then return end

	for _, connection in pairs(state.Connections) do
		connection:Disconnect()
	end
	state.Connections = nil
	self.States[aircraft] = nil
end

return rotorLite