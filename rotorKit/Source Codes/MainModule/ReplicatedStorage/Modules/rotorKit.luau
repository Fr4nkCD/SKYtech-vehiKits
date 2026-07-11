-- rotorKit Flight Physics
-- by SKYtech

local rotorKit = {
	States = {}
}

-- Utilies (math, physics, global variables)
local Utils = require(script.Parent:WaitForChild("VehicleUtils"))

function rotorKit:Initialize(aircraft)
	local main = aircraft.Main
	local mainPart = main.Main

	self.States[aircraft] = {
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
		},
	}

	local state = self.States[aircraft]

	local Settings = aircraft:FindFirstChild("Settings")

	-- Initialize settings.
	for attrName, attrValue in pairs(Settings:GetAttributes()) do
		Utils.UpdateSetting(attrName, attrValue, state.Settings)
	end	

	-- Update legacy value objects on the client side.
	if Utils.IsClient() then
		Utils.SyncLegacyValues(Settings, state.Connections)
	end

	-- Update settings on attribute changed.
	table.insert(state.Connections, Settings.AttributeChanged:Connect(function(attrName)
		local attrValue = Settings:GetAttribute(attrName)
		if attrValue == nil then return end
		Utils.UpdateSetting(attrName, attrValue, state.Settings)
	end))
end

function rotorKit:GetState(aircraft)
	return self.States[aircraft]
end

function rotorKit:Update(aircraft, dt, onClient)
	local state = self.States[aircraft]

	if not state then return end

	local System = state.System
	local Settings = state.Settings
	local Components = state.Components

	local Stats_ = Components.Stats_
	local mainPart = Components.MainPart
	
	local motion = Components.Motion
	local lift = Components.Lift
	local aerodynamics = Components.Aerodynamics
	local gravity = Components.Gravity

	-- Variables that need to be updated every frame.
	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local globalWind = workspace.GlobalWind
	local globalGravity = workspace.Gravity
	local mainCFrame = mainPart.CFrame
	local position = mainPart.Position
	local worldVelocity = mainPart.AssemblyLinearVelocity/physicsScale
	local localVelocity = mainCFrame:VectorToObjectSpace(worldVelocity)
	local speedMagnitude = worldVelocity.Magnitude
	local altitude = position.Y/physicsScale
	local bankAngle = -Utils.Deg(Utils.GetRoll(mainCFrame)) + 360
	local isInverted = bankAngle%360 >= 90 and bankAngle%360 <= 270
	local invertedBankAngle = Utils.Deg(Utils.GetRoll(mainCFrame * Utils.CFAngles(0, 0, Utils.Pi))) - 360
	local pitchRad, _, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchAngle = Utils.Deg(pitchRad)

	-- Only run physics if the aircraft is unanchored.
	if not mainPart:IsGrounded() then
		--------------------------- Variables ---------------------------
		local _rateOfClimb = Settings.AircraftStatistics.RateOfClimb
		local _maxSpeed = Utils.Max(Settings.AircraftStatistics.MaxSpeed, 0.001)
		local _maxAltitude = Settings.AircraftStatistics.MaxAltitude
		local _limitAngle = Settings.AttitudeControls.LimitAngle == true
		local _turningRate = Settings.AttitudeControls.TurningRate
		local _torqueResponsiveness = Settings.AttitudeControls.TorqueResponsiveness
		------------------------------------------------------------------
		local RPM_ = Stats_:GetAttribute("RPM")
		local direction_ = Stats_:GetAttribute("Direction")
		local isHovering = Stats_:GetAttribute("Hover")

		local mass = aircraft.System:GetAttribute("Mass")
		local weight = mass * 160 * Utils.Min(globalGravity/35, 1)
		local RPM = Utils.Max((RPM_ - 70), 0)/30

		local horizontalUnit = if direction_.Unit then direction_.Unit else Utils.V3Zero
		local horizontalMagnitude = Utils.V2New(horizontalUnit.X, horizontalUnit.Z).Magnitude
		local maxSpeedBit = altitude/Utils.Max(_maxAltitude * 0.25, 0.001)
		local verticalMaxSpeedDrag = maxSpeedBit * Utils.Abs(horizontalUnit.Y)
		local horizontalMaxSpeedDrag = maxSpeedBit * horizontalMagnitude

		local maxSpeed = _maxSpeed * Utils.Max((0.75 + Utils.Abs(horizontalUnit.Y)/4) - verticalMaxSpeedDrag + horizontalMaxSpeedDrag, 0.75)
		local maxSpeedDrag = Utils.Max(speedMagnitude - maxSpeed, 0)/1000
		local speedDrag = 0.005 * speedMagnitude/maxSpeed
		
		local XYForce = weight * (speedDrag * (1 + horizontalMagnitude) + maxSpeedDrag)
		local collectiveDrag = 1 - System.Collective
		local verticalFactor = 1 - horizontalMagnitude
		local forwardDrag = Utils.Max(100 + (1900 * verticalFactor * collectiveDrag), 100)
		local ZForce = weight * (speedDrag/forwardDrag + maxSpeedDrag)
		
		local aeroX = mainCFrame.RightVector * XYForce * -localVelocity.X
		local aeroY = mainCFrame.UpVector * XYForce * -localVelocity.Y * 1.5
		local aeroZ = mainCFrame.LookVector * ZForce * localVelocity.Z
		
		local aerodynamicsForce = aeroX + aeroY + aeroZ
		local aeroHover = Utils.V3New(0, if isHovering then weight * -localVelocity.Y/140 else 0, 0)
		local crosswind = globalWind * weight * speedMagnitude/25000
		
		aerodynamics.Force = (aerodynamicsForce + aeroHover + crosswind) * RPM

		local dive = Utils.Clamp(85 - Utils.Abs(pitchAngle), 0, 30)/30 -- Reduce shakiness when nose diving
		local turnSpeed = _turningRate * Utils.Min(speedMagnitude/100, 1)
		local turnFactor = Utils.Max(turnSpeed - (speedMagnitude/600), 0.1)
		local turn = (if isInverted then invertedBankAngle else bankAngle)/(180 + 45 * horizontalMagnitude) * turnFactor * dive

		-----------------------------------------------------
		local rollInput, pitchInput = 0, 0

		if _limitAngle or System.Hovering then
			local maxBank = if System.Hovering then 20 else Utils.Max(Utils.Abs(Settings.AttitudeControls.MaxBank), 1)
			local bankLimit = Utils.Clamp(bankAngle/maxBank, -1, 1) * Utils.Abs(System.Roll)
			local bankLevelOut = (bankAngle > 0 and 0.3 or -0.3) * Utils.Min(Utils.Abs(bankAngle)/5, 1) * (1 - Utils.Abs(System.Roll))
			
			local maxPitch = if System.Hovering then 20 else Utils.Max(Utils.Abs(Settings.AttitudeControls.MaxPitch), 1)
			local pitchLimit = Utils.Clamp(pitchAngle/maxPitch, -1, 1) * Utils.Abs(System.Pitch)
			local pitchLevelOut = (pitchAngle > 0 and 0.3 or -0.3) * Utils.Min(Utils.Abs(pitchAngle)/5, 1) * (1 - Utils.Abs(System.Pitch))
			
			rollInput = System.Roll - bankLimit - bankLevelOut
			pitchInput = System.Pitch - pitchLimit - pitchLevelOut
		else
			rollInput = System.Roll
			pitchInput = System.Pitch
		end

		local roll = rollInput * Settings.AttitudeControls.RollSpeed/10
		local pitch = pitchInput * Settings.AttitudeControls.PitchSpeed/10
		local yaw = System.Yaw * Settings.AttitudeControls.YawSpeed/10

		motion.MaxTorque = ((weight/20 * Utils.Min(speedMagnitude/10, 1)) + (weight * System.Collective)) * _torqueResponsiveness * RPM
		motion.AngularVelocity = Utils.V3New(pitch, yaw + turn, roll)
		-----------------------------------------------------------------

		local rateOfClimb = _rateOfClimb + (_maxSpeed - _rateOfClimb) * horizontalMagnitude
		local liftDrag = 1 - Utils.Max((worldVelocity.Y - rateOfClimb)/5, 0)
		local pressureLoss = Utils.Min(Utils.Max(altitude - _maxAltitude, 0)/100, 1)
		local liftForce = weight/2 * Utils.Max(System.Collective - 0.1, 0) * liftDrag * (1 - pressureLoss)
		local direction = direction_ - Utils.V3New(rollInput * 0.25, 0, pitchInput * 0.25)
		lift.Force = Utils.V3New(liftForce, liftForce, -liftForce) * direction * RPM

		gravity.Force = Utils.V3New(0, mass * Utils.Max(globalGravity - 35, 0), 0)
	end
end

function rotorKit:Cleanup(aircraft)
	local state = self.States[aircraft]

	for i, connection in pairs(state.Connections) do
		connection:Disconnect()
	end
	state.Connections = nil

	self.States[aircraft] = nil
end

return rotorKit