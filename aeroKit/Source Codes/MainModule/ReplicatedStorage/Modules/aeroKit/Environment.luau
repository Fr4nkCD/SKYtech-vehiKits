-- Environment Module
-- Handles terrain profiling, surface tracking, collision exceptions, and stall speed calculations
local Environment = {}

local math_cos = math.cos
local math_sin = math.sin

function Environment.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components

	local mainPart = Components.MainPart
	local boundSize = Components.BoundSize

	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local globalWind = workspace.GlobalWind
	local globalGravity = workspace.Gravity
	local mainCFrame = mainPart.CFrame
	local position = mainPart.Position

	local _aircraftStatistics = Settings.AircraftStatistics
	local _attitudeControls = Settings.AttitudeControls
	
	local _stability = _aircraftStatistics.Stability^2
	local _symmetricalAirfoil = _aircraftStatistics.SymmetricalAirfoil == true
	local _drag = _aircraftStatistics.Drag
	local _maxSpeed = _aircraftStatistics.MaxSpeed
	local _maxSpeedSL = _aircraftStatistics.MaxSpeedSL
	local _stallSpeed = _aircraftStatistics.StallSpeed
	local _changedbyAltitude = _aircraftStatistics.ChangedbyAltitude
	local _maxAltitude = _aircraftStatistics.MaxAltitude
	local _turningRate = _attitudeControls.TurningRate
	local _lowestPoint = Settings.Advanced.LowestPoint or "Auto"

	local mainDirection = mainPart.CFrame
	local worldVelocity = mainPart.AssemblyLinearVelocity / physicsScale

	local bankAngle = -Utils.Deg(Utils.GetRoll(mainPart.CFrame)) + 360
	local notUpsideDown = bankAngle >= -90 and bankAngle <= 90
	local invertedBankAngle = Utils.Deg(Utils.GetRoll(mainPart.CFrame * Utils.CFAngles(0, 0, Utils.Pi))) - 360
	local pitchRad, yawAngle, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchAngle = Utils.Deg(pitchRad)
	local velocity = mainPart.CFrame:VectorToObjectSpace(mainPart.AssemblyLinearVelocity) / physicsScale
	local trueSpeed = Utils.Abs(-velocity.Z + mainPart.CFrame:VectorToObjectSpace(globalWind).Z)
	local altitude = mainPart.Position.Y / physicsScale
	
	local mass = Components.StateWrapper:GetAttribute("Mass") or 1
	local weight = mass * 196.2 * Utils.Min(globalGravity / 35, 1)

	local yawInput = System.Yaw
	local yawDriftAngle = yawInput * _attitudeControls.YawSpeed / 200 * (1 - trueSpeed / _maxSpeed / 2.5)
	local sideWindMagnitude = trueSpeed * yawDriftAngle
	local driftDirection = mainPart.CFrame.RightVector * sideWindMagnitude * Utils.Min(Utils.Max(trueSpeed - _stallSpeed, 0) / _stallSpeed / (10 * physicsScale), 1)
	local localWindDirection = if (globalWind + driftDirection).Magnitude > 0 then mainPart.CFrame:VectorToObjectSpace(globalWind + driftDirection).Unit else Utils.V3Zero

	local effectiveBankAngle = if notUpsideDown then bankAngle else invertedBankAngle

	local stallSpeedChangedbyAltitude = if _changedbyAltitude then (_maxSpeed - _stallSpeed) * Utils.Clamp((altitude / _maxAltitude) + Utils.Clamp((altitude - _maxAltitude) / 10, 0, 10), 0, 10) else 0
	local stallSpeed = _stallSpeed + ((if _symmetricalAirfoil then Utils.Abs(effectiveBankAngle) / 180 else Utils.Abs(bankAngle / 180)) * (_stallSpeed / 2.5)) + stallSpeedChangedbyAltitude + (_maxSpeed * math.max(altitude - _maxAltitude, 0) / 100)
	local maxSpeed = _maxSpeedSL + (_maxSpeed - _maxSpeedSL) * (altitude / _maxAltitude + Utils.Max(-pitchAngle, 0) / 180)

	local stalling = 0
	local lowestPoint = 0
	local hasCollision = false

	if _lowestPoint == "Auto" then
		local halfY, halfZ = boundSize.Y / 2, boundSize.Z / 2
		local projectedExtent = halfY * math_cos(pitchRad) + halfZ * Utils.Abs(math_sin(pitchRad))
		lowestPoint = projectedExtent + physicsScale
	else
		lowestPoint = Utils.Abs(_lowestPoint)
	end
	
	state.RayFilter.FilterDescendantsInstances = state.IgnoredObjects
	local onGround = workspace:Raycast(position, Utils.V3New(0, -lowestPoint, 0), state.RayFilter)
	if onGround then
		local instance = onGround.Instance
		local model = instance.Parent
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid == nil then
				hasCollision = Utils.CheckPartCollision(instance, state.IgnoredObjects)
			else
				table.insert(state.IgnoredObjects, model)
			end
		else
			hasCollision = Utils.CheckPartCollision(instance, state.IgnoredObjects)
		end
	else
		if #state.IgnoredObjects > 1 then
			table.clear(state.IgnoredObjects)
			table.insert(state.IgnoredObjects, state.AircraftInstance)
		end
		
		if trueSpeed < stallSpeed then
			stalling = 1
		else
			stalling = 0
		end
	end

	if hasCollision then
		stalling = 0
	end

	state.EnvironmentData = {
		PhysicsScale = physicsScale,
		GlobalGravity = globalGravity,
		GlobalWind = globalWind,
		MainCFrame = mainCFrame,
		Position = position,
		WorldVelocity = mainPart.AssemblyLinearVelocity, -- non-scaled world velocity for hover math
		ScaledWorldVelocity = worldVelocity,
		Velocity = velocity,
		TrueSpeed = trueSpeed,
		Altitude = altitude,
		BankAngle = bankAngle,
		NotUpsideDown = notUpsideDown,
		InvertedBankAngle = invertedBankAngle,
		EffectiveBankAngle = effectiveBankAngle,
		PitchRad = pitchRad,
		PitchAngle = pitchAngle,
		YawAngle = yawAngle,
		Mass = mass,
		Weight = weight,
		DriftDirection = driftDirection,
		LocalWindDirection = localWindDirection,
		StallSpeed = stallSpeed,
		MaxSpeed = maxSpeed,
		Stalling = stalling,
		StabilityCoeff = _stability,
		SymmetricalAirfoil = _symmetricalAirfoil,
		DragCoeff = _drag,
		TurningRate = _turningRate,
	}
end

return Environment
