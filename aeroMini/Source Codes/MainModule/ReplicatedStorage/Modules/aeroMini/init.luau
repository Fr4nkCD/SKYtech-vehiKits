-- aeroMini Flight Physics
-- by SKYtech

local aeroMini = {
	States = {}
}

-- Processors
local VehicleUtils = require(script.Parent:WaitForChild("VehicleUtils"))
local Environment = require(script:WaitForChild("Environment"))
local Thrust = require(script:WaitForChild("Thrust"))
local Motion = require(script:WaitForChild("Motion"))

function aeroMini:Initialize(aircraft)
	local main = aircraft.Main
	local mainPart = main.Main

	self.States[aircraft] = {
		AircraftInstance = aircraft,
		Utils = VehicleUtils,
		System = {
			Throttle = 0,
			Roll = 0,
			Pitch = 0,
			SubModulesReady = true,
			Yaw = 0,
			MousePosition = nil,
			Boost = 0,
			MinSpeed = 0,
			Speed = 0,
			MotionCFrame = CFrame.new(),
			Direction = mainPart.CFrame.LookVector * 1e6,
			RollAccumulated = 0,
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
			Thrust = mainPart.Thrust,
			Gravity = mainPart.Gravity,
			BoundSize = nil,
		},
		IgnoredObjects = {aircraft},
		RayFilter = nil,
		EnvironmentData = {
			HasCollision = false,
			OnGroundNormal = Vector3.yAxis,
			LowestPoint = 0,
			GlobalWind = Vector3.zero,
			GlobalGravity = 196.2,
		},
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

function aeroMini:GetState(aircraft)
	return self.States[aircraft]
end

function aeroMini:Reset(aircraft)
	local state = self.States[aircraft]
	local System = state.System
	local Components = state.Components
	local mainPart = Components.MainPart
	local mainCFrame = mainPart.CFrame

	System.Speed = -mainCFrame:VectorToObjectSpace(mainPart.AssemblyLinearVelocity).Z
	System.MotionCFrame = mainCFrame
	System.Direction = mainCFrame.LookVector * 1e6
	
	Components.Motion.CFrame = System.MotionCFrame
end

function aeroMini:Update(aircraft, dt, onClient)	
	local state = self.States[aircraft]
	if not state then return end

	state.Step += dt
	
	local Utils = state.Utils

	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local mainPart = Components.MainPart

	if not mainPart:IsGrounded() then
		-- Pipeline Execution Sequence via Context Injection
		Environment.Update(dt, state)
		Thrust.Update(dt, state)
		Motion.Update(dt, state)
	else
		-- Grounded Safety Anchoring fallback
		local mainCFrame = mainPart.CFrame
		local realSpeed = mainPart.AssemblyLinearVelocity
		System.Speed = -mainCFrame:VectorToObjectSpace(realSpeed).Z
		Components.Thrust.VectorVelocity = realSpeed
		System.MotionCFrame = mainCFrame
		Components.Motion.CFrame = System.MotionCFrame
		local bankAngle = -Utils.Deg(Utils.GetRoll(mainCFrame)) + 360
		System.RollAccumulated = Utils.Rad(bankAngle)
		System.Direction = mainCFrame.LookVector * 1e6
	end

	-- Global State Network Synchronization Handling (CM32 Legacy)
	if state.Step >= 0.5 then
		local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
		local _stallSpeed = Utils.Max(Settings.AircraftStatistics.StallSpeed * physicsScale, 0.001)
		local _maxAltitude = Utils.Max(Settings.AircraftStatistics.MaxAltitude * physicsScale, 0.001)

		local trueSpeed = Utils.Abs(System.Speed + mainPart.CFrame:VectorToObjectSpace(state.EnvironmentData.GlobalWind).Z)
		local lift = if trueSpeed >= _stallSpeed then 1 else 0
		local stalling = if state.EnvironmentData.HasCollision then 0 else 1 - lift

		local belowMaxAlt = mainPart.Position.Y <= _maxAltitude

		Components.StateWrapper:SetAttribute("Taxiing", lift == 0 and stalling == 0)
		Components.StateWrapper:SetAttribute("Flying", lift > 0 and stalling == 0 and belowMaxAlt)
		Components.StateWrapper:SetAttribute("Stalling", stalling == 1 or not belowMaxAlt)

		if onClient then
			local attributes = Components.StateWrapper:GetAttributes()
			local packet = {
				Taxiing = attributes.Taxiing,
				Flying = attributes.Flying,
				Stalling = attributes.Stalling
			}
			Components.StateUpdateEvent:FireServer("States", packet)
		end
		state.Step -= 0.5
	end
end

function aeroMini:Cleanup(aircraft)
	local state = self.States[aircraft]
	if not state then return end

	for _, connection in pairs(state.Connections) do
		connection:Disconnect()
	end
	state.Connections = nil
	self.States[aircraft] = nil
end

return aeroMini