-- Motion Module
-- Manages spatial vectors, aerodynamic torque adjustments, and constraint mapping
local Motion = {}

function Motion.Update(dt, state)
	local Utils = state.Utils
	
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local Env = state.EnvironmentData
	
	local globalWind = workspace.GlobalWind
	local globalGravity = workspace.Gravity

	local mainPart = Components.MainPart
	local motion = Components.Motion
	local thrust = Components.Thrust
	local gravity = Components.Gravity
	local boundSize = Components.BoundSize
	local stateWrapper = Components.StateWrapper

	local mainCFrame = mainPart.CFrame
	local position = mainPart.Position
	local altitude = position.Y
	local mass = mainPart.AssemblyMass

	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local _aircraftStatistics = Settings.AircraftStatistics
	local _attitudeControls = Settings.AttitudeControls

	local _stallSpeed = Utils.Max(_aircraftStatistics.StallSpeed * physicsScale, 0.001)
	local _maxAltitude = Utils.Max(_aircraftStatistics.MaxAltitude * physicsScale, 0.001)
	local _maxSpeed = Utils.Max(_aircraftStatistics.MaxSpeed * physicsScale, 0.001)
	local _angleOfAttack = _aircraftStatistics.AngleOfAttack
	local _flareRate = Utils.Max(_aircraftStatistics.FlareRate * physicsScale, 0.001)
	local _noseLiftFactor = Utils.Clamp(_aircraftStatistics.NoseLiftFactor, 0, 1)
	local _tailLift = _aircraftStatistics.TailLift == true

	local _advanced = _attitudeControls.Advanced
	local _turnSensitivity = _attitudeControls.TurnSensitivity

	local trueSpeed = Utils.Abs(System.Speed + mainCFrame:VectorToObjectSpace(globalWind).Z)
	local bankAngle = -Utils.Deg(Utils.GetRoll(mainCFrame)) + 360
	local invertedBankAngle = Utils.Deg(Utils.GetRoll(mainCFrame * Utils.CFAngles(0, 0, Utils.Pi))) - 360
	local pitchRad, yawAngle, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchAngle = Utils.Deg(pitchRad)

	local liftAlpha = Utils.Min(Utils.Max(trueSpeed - (_stallSpeed * 0.9), 0) / (_stallSpeed * 0.1), 1)
	local stalling = if stateWrapper:GetAttribute("Stalling") == true then 1 else 0

	stalling = if Env.HasCollision then 0 else 1 - liftAlpha
	local restingAngle = System.RestingAngle
	local totalLiftForce = Utils.Clamp(liftAlpha + stalling, 0, 1)

	local liftThreshold = if _noseLiftFactor > 0 then _stallSpeed * Utils.Clamp(1 - _noseLiftFactor - 0.1, 0, 1) else _stallSpeed * 0.95
	local totalLiftTorque = Utils.Clamp((trueSpeed - liftThreshold) / (_stallSpeed - liftThreshold) + stalling, 0, 1)
	if Env.HasCollision and trueSpeed >= liftThreshold then
		totalLiftTorque = Utils.Max(totalLiftTorque, 0.5) -- Ensure pilot can override nose attitude on runway
	end

	local maxForce = mass * 5e2
	local maxTorque = mass * 5e4

	local move = if Utils.Abs(System.Speed) >= physicsScale then 1 else 0
	local motionEnabled = motion:GetAttribute("Enabled")

	thrust.MaxAxesForce = Utils.V3New(maxForce * move, maxForce * totalLiftForce, maxForce * move)
	motion.MaxTorque = if motionEnabled == true then Utils.V3New(maxTorque * totalLiftTorque, maxTorque * move, maxTorque * totalLiftTorque) else Utils.V3Zero

	motion.P = _attitudeControls.TorqueResponsiveness
	motion.D = _attitudeControls.TorqueResponsiveness / 2

	local altitudeOvershoot = Utils.Min(Utils.Max(altitude - _maxAltitude, 0) / (_maxAltitude * 0.1), 1)
	local liftUnderMaxAlt = 1 - altitudeOvershoot
	local gravitySpeed = Utils.V3New(0, -_maxSpeed / 2 * (Utils.Max((stalling * liftUnderMaxAlt) - Utils.Min(trueSpeed / _stallSpeed, 1), 0) + altitudeOvershoot), 0) 
	local crosswind = globalWind * Utils.Min(Utils.Max(trueSpeed - _stallSpeed * 0.9, 0) / (_stallSpeed * 0.1), 1)

	local flareRate = 1 - Utils.Min(Utils.Max(trueSpeed - _stallSpeed, 0) / _flareRate, 1)
	local angleOfAttack = (Utils.CFAngles(0, yawAngle, 0) * Utils.CFAngles(Utils.Rad(_angleOfAttack * flareRate), 0, 0)).LookVector * Utils.V3New(0, 1, 0)
	local lookVector = (mainCFrame.LookVector + angleOfAttack).Unit * Utils.V3New(1, liftUnderMaxAlt, 1)
	local realSpeed = (lookVector * System.Speed) + gravitySpeed + crosswind
	thrust.VectorVelocity = realSpeed

	local dive = 1 - Utils.Max(Utils.Abs(pitchAngle) - 60, 0) / 30
	local stallSpeed95 = _stallSpeed * 0.95
	local underSpeed = trueSpeed < stallSpeed95 and stalling == 0
	local liftTransition = if _noseLiftFactor > 0 then
		Utils.Min(Utils.Max(trueSpeed - stallSpeed95 * (1 - _noseLiftFactor), 0) / (stallSpeed95 * _noseLiftFactor), 1)
		else
		if trueSpeed >= stallSpeed95 then 1 else 0
	local groundBlend = 1 - liftTransition
	local tailLiftAngle = if _tailLift then restingAngle * groundBlend else restingAngle

	System.CurrentRoll = Utils.Rad(bankAngle)
	local currentRollCF = Utils.CFAngles(0, 0, System.CurrentRoll)

	if _tailLift then
		System.CurrentPitch = 0
	elseif totalLiftForce == 1 or (System.Speed < (_maxSpeed * System.Throttle) + System.MinSpeed) then -- tracks change state
		System.CurrentPitch = pitchRad
	end

	if _advanced then
		local bankTurn = if bankAngle < 90 and bankAngle > -90 then bankAngle / 90 else invertedBankAngle / 90
		local turnDecay = Utils.Clamp(trueSpeed / (600 * physicsScale), 0, 0.7)
		local turn = bankTurn * turnDecay * dive

		local advTurnSensitivity = 1 - Utils.Exp(-_turnSensitivity / 0.0005 * dt)
		local rollOutput = Utils.Rad(System.Roll * _attitudeControls.RollSpeed / 10 * totalLiftForce) * advTurnSensitivity
		local pitchOutput = Utils.Rad(System.Pitch * _attitudeControls.PitchSpeed / 10 * totalLiftForce) * advTurnSensitivity
		local yawOutput = Utils.Rad(Utils.Clamp((System.Roll * (1 - liftAlpha)) + (System.Yaw * (1 - liftAlpha / 1.5)), -1, 1) * _attitudeControls.YawSpeed / 10 + turn) * advTurnSensitivity

		if underSpeed and Env.HasCollision then
			local _, currentYaw, _ = System.MotionCFrame:ToEulerAnglesYXZ()
			local direction = Utils.CFAngles(0, currentYaw, 0) * Utils.CFAngles(System.CurrentPitch, 0, 0) * currentRollCF
			direction = direction * Utils.CFAngles(0, yawOutput, 0)

			local directionVector = direction.LookVector
			local flatForward = Utils.V3New(directionVector.X, 0, directionVector.Z).Unit
			local yawOnlyDir = Utils.CFLookAt(position, position + flatForward)

			local groundAlignedWithYaw = yawOnlyDir * Utils.CFAngles(Utils.Rad(tailLiftAngle), 0, 0) * currentRollCF
			local blendAlpha = if _tailLift then 1 else (1 - Utils.Exp(-200 * dt))

			System.MotionCFrame = direction:Lerp(groundAlignedWithYaw, groundBlend * blendAlpha)
		else
			System.MotionCFrame *= Utils.CFAngles(pitchOutput, yawOutput, rollOutput)
		end

		System.Direction = position + (mainCFrame.LookVector * 1e6)
	else
		local nosePosition = position + (mainCFrame.LookVector * 1e6)
		local rawMousePos = System.MousePosition
		local validMouse = rawMousePos and rawMousePos ~= Vector3.zero and rawMousePos.Magnitude > 0.001

		local targetPosition = if validMouse then rawMousePos else (position + nosePosition)
		local mouseDir = (targetPosition - position).Unit
		
		local turnDecay = 2 - Utils.Clamp(trueSpeed / _maxSpeed, 0, 1)
		local turnSensitivity = _turnSensitivity * turnDecay
		local alpha = 1 - Utils.Exp(-turnSensitivity * dt)

		local yTorque = Utils.V3New(1, totalLiftForce, 1)
		local yRest = Utils.V3New(0, nosePosition.Unit.Y * (1 - totalLiftForce), 0)

		System.Direction = System.Direction:Lerp((mouseDir * yTorque) + yRest, alpha).Unit

		local targetPosition = position + (System.Direction * 1e6)
		local direction = Utils.CFLookAt(position, targetPosition)

		local flatMask = Utils.V3New(1, 0, 1)
		local start2D = nosePosition * flatMask
		local target2D = targetPosition * flatMask

		if start2D.Magnitude > 0.001 and target2D.Magnitude > 0.001 then
			local angle = math.acos(math.clamp(start2D.Unit:Dot(target2D.Unit), -1, 1))
			local sign = Utils.Sign(Vector3.yAxis:Dot(start2D:Cross(target2D)))

			local maxAngle = Utils.Pi / 2
			local rollSensitivity = 6 * (1 - Utils.Clamp(_turnSensitivity, 0, 1) / 2)
			local rollAlpha = 1 - Utils.Exp(-_turnSensitivity ^ 1.4 * 10 * dt)

			System.RollAccumulated = Utils.Lerp(System.RollAccumulated, Utils.Clamp(angle * sign * dive * rollSensitivity, -maxAngle, maxAngle) * totalLiftForce, rollAlpha)
		end

		if underSpeed and Env.HasCollision then
			local surfaceUp = Env.OnGroundNormal or Vector3.yAxis
			local flatForward = Utils.V3New(System.Direction.X, 0, System.Direction.Z).Unit
			local yawOnlyDir = Utils.CFLookAt(position, position + flatForward)

			local groundAlignedWithYaw = CFrame.fromMatrix(
				position,
				yawOnlyDir.RightVector,
				surfaceUp
			) * Utils.CFAngles(Utils.Rad(tailLiftAngle), 0, 0)

			direction = direction * currentRollCF
			System.MotionCFrame = direction:Lerp(groundAlignedWithYaw, groundBlend)
		else
			local roll = Utils.CFAngles(0, 0, System.RollAccumulated)
			System.MotionCFrame = direction * roll
		end
	end

	motion.CFrame = System.MotionCFrame
	gravity.Force = Utils.V3New(0, mass * Utils.Max(globalGravity - 35, 0), 0)

	-- Absolute bypass resets
	if not thrust.Enabled then
		realSpeed = mainPart.AssemblyLinearVelocity
		System.Speed = -mainCFrame:VectorToObjectSpace(realSpeed).Z
		thrust.VectorVelocity = realSpeed
	end
	if move == 0 or motionEnabled == false then
		System.MotionCFrame = mainCFrame
		motion.CFrame = System.MotionCFrame
		System.RollAccumulated = Utils.Rad(bankAngle)
		System.Direction = mainCFrame.LookVector * 1e6
	end
end

return Motion