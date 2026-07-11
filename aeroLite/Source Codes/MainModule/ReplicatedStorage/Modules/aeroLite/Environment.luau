-- Environment Module
-- Handles terrain profiling, surface tracking, and stall dynamics
local Environment = {}

function Environment.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local stateWrapper = Components.StateWrapper

	local mainPart = Components.MainPart
	local boundSize = Components.BoundSize
	local mainCFrame = mainPart.CFrame
	local position = mainPart.Position
	local altitude = position.Y

	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local _aircraftStatistics = Settings.AircraftStatistics

	local _maxSpeed = _aircraftStatistics.MaxSpeed * physicsScale
	local _maxSpeedSL = _aircraftStatistics.MaxSpeedSL * physicsScale
	local _stallSpeed = Utils.Max(_aircraftStatistics.StallSpeed * physicsScale, 0.001)
	local _changedbyAltitude = _aircraftStatistics.ChangedbyAltitude
	local _maxAltitude = Utils.Max(_aircraftStatistics.MaxAltitude * physicsScale, 0.001)
	local _lowestPoint = Settings.Advanced.LowestPoint or "Auto"
	local _restingAngle = _aircraftStatistics.RestingAngle

	local pitchRad, _, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchAngle = Utils.Deg(pitchRad)
	local bankAngle = -Utils.Deg(Utils.GetRoll(mainCFrame)) + 360
	local invertedBankAngle = Utils.Deg(Utils.GetRoll(mainCFrame * Utils.CFAngles(0, 0, Utils.Pi))) - 360

	local trueSpeed = Utils.Abs(System.Speed + mainCFrame:VectorToObjectSpace(workspace.GlobalWind).Z)

	local stallSpeedChangedbyAltitude = if _changedbyAltitude then (_maxSpeed - _stallSpeed) * Utils.Clamp((altitude/_maxAltitude) + Utils.Clamp((altitude - _maxAltitude)/10, 0, 10), 0, 10) else 0
	local stallSpeed = Utils.Max(_stallSpeed + (Utils.Abs(bankAngle/180) * (_stallSpeed/3)) + stallSpeedChangedbyAltitude, 0.001)
	local maxSpeed = _maxSpeedSL + (_maxSpeed - _maxSpeedSL) * (altitude/_maxAltitude + Utils.Max(-pitchAngle, 0)/180)

	local lowestPoint = 0
	if _lowestPoint == "Auto" then
		local projectedExtent = (boundSize.Y/2) * math.cos(pitchRad) + (boundSize.Z/2) * Utils.Abs(math.sin(pitchRad))
		lowestPoint = projectedExtent + physicsScale
	else
		lowestPoint = Utils.Abs(_lowestPoint)
	end

	local stalling, stallDrop, stallForce, stallBank = 0, 0, 0, 0
	local hasCollision = false

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
			local inverted = if bankAngle%360 >= 90 and bankAngle%360 <= 270 then -1 else 1
			local AoA = Utils.Clamp(-pitchAngle/90, 0, 1)
			if bankAngle > -90 and bankAngle < 90 then
				stallBank = Utils.Abs(bankAngle)/135
			else
				stallBank = Utils.Abs(invertedBankAngle)/135
			end
			stallDrop = Utils.Clamp((trueSpeed - stallSpeed)/(stallSpeed/10), -1, 0)
			stallForce = stallDrop * (1 - AoA) * (1 - stallBank) * inverted
		end
	end

	if hasCollision then
		stalling, stallDrop, stallForce, stallBank = 0, 0, 0, 0
		local surfaceBankAngle = Utils.GetSurfaceBankAngle(mainPart, onGround.Normal)
		System.CurrentRoll = Utils.Lerp(System.CurrentRoll, surfaceBankAngle, dt)

		local relativeCFrame = Utils.GetAlignmentCFrame(mainPart, onGround.Normal)
		local relativePitchAngle = Utils.Deg(Utils.GetPitch(relativeCFrame))

		if _restingAngle ~= "Auto" then
			System.RestingAngle = _restingAngle
		elseif _restingAngle == "Auto" and trueSpeed < physicsScale then
			System.RestingAngle = math.floor(relativePitchAngle * 1000)/1000
		end
	else
		System.CurrentRoll = Utils.Lerp(System.CurrentRoll, Utils.Rad(bankAngle), dt)
	end

	-- Export calculations down the context pipeline
	state.EnvironmentData = {
		HasCollision = hasCollision,
		OnGroundNormal = onGround and onGround.Normal or nil,
		Stalling = stalling,
		StallDrop = stallDrop,
		StallForce = stallForce,
		StallBank = stallBank,
		StallSpeed = stallSpeed,
		MaxSpeedCalculated = maxSpeed
	}
end

return Environment