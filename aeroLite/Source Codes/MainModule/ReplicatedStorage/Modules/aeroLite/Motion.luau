-- Motion Module
-- Manages aerospace transforms, control surfaces, and orientation interpolation
local Motion = {}

function Motion.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local Env = state.EnvironmentData
	local Thr = state.ThrustData

	local mainPart = Components.MainPart
	local motion = Components.Motion
	local turn = Components.Turn
	local thrust = Components.Thrust
	local lift = Components.Lift
	local gravity = Components.Gravity

	local mainCFrame = mainPart.CFrame
	local position = mainPart.Position
	local mass = mainPart.AssemblyMass
	local globalGravity = workspace.Gravity

	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local _aircraftStatistics = Settings.AircraftStatistics
	local _attitudeControls = Settings.AttitudeControls

	local _turningRate = _attitudeControls.TurningRate
	local _angleOfAttack = _aircraftStatistics.AngleOfAttack
	local _flareRate = Utils.Max(_aircraftStatistics.FlareRate * physicsScale, 0.001)
	local _tailLift = _aircraftStatistics.TailLift == true
	local _advanced = _attitudeControls.Advanced
	local _AoA = _aircraftStatistics.AoA

	local pitchRad, yawAngle, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchAngle = Utils.Deg(pitchRad)
	local bankAngle = -Utils.Deg(Utils.GetRoll(mainCFrame)) + 360
	local invertedBankAngle = Utils.Deg(Utils.GetRoll(mainCFrame * Utils.CFAngles(0, 0, Utils.Pi))) - 360
	local trueSpeed = Utils.Abs(System.Speed + mainCFrame:VectorToObjectSpace(workspace.GlobalWind).Z)

	local initialSpeed = Utils.Min(Utils.Abs(System.Speed)/(3 * physicsScale), 1)
	local thrust_Force = Utils.Clamp(initialSpeed + Env.Stalling, 0, 1)
	local turn_Torque = initialSpeed - (Thr.LiftTorque * (1 - Env.Stalling))

	local bankTurn = if bankAngle < 90 and bankAngle > -90 then bankAngle/90 else invertedBankAngle/90
	local crosswind = workspace.GlobalWind * Thr.LiftForce
	local speedGain = Utils.Min(Utils.Max(trueSpeed - Thr.StallSpeed95, 0)/(Env.StallSpeed * 0.05) + Env.Stalling, 1)
	local flareRate = Utils.Min(Utils.Max(trueSpeed - Env.StallSpeed, 0)/_flareRate, 1)
	local flaring = speedGain - flareRate
	local turnSlip = mainCFrame.RightVector * (bankTurn * _turningRate * (if _AoA then _AoA * 0.8 else _angleOfAttack) * flaring * physicsScale)
	local stallFlare = Utils.V3New(0, -30 * physicsScale * Utils.Clamp((System.Speed - Env.StallSpeed)/(Env.StallSpeed * 0.1), -1, 0) * Env.StallDrop, 0)

	local realSpeed = Utils.V3Zero
	if _AoA then
		local flare = Utils.V3New(0, _AoA * flaring, 0)
		realSpeed = (mainCFrame.LookVector * System.Speed) + turnSlip + flare + stallFlare + crosswind
	else
		local angleOfAttack = (Utils.CFAngles(0, yawAngle, 0) * Utils.CFAngles(Utils.Rad(_angleOfAttack * flaring), 0, 0)).LookVector * Vector3.new(0, 1, 0)
		realSpeed = ((mainCFrame.LookVector + angleOfAttack).Unit * System.Speed) + turnSlip + stallFlare + crosswind
	end

	local weight = mass * (globalGravity + 1)
	thrust.MaxForce = thrust_Force * weight * 10
	lift.MaxForce = Thr.LiftForce * weight * 10
	turn.MaxTorque = turn_Torque * weight * 500
	motion.MaxTorque = Thr.LiftTorque * weight * 500

	local torqueResponsiveness = 25 + (75 * Utils.Min(trueSpeed/(Env.StallSpeed/2), 1))
	turn.Responsiveness = torqueResponsiveness
	motion.Responsiveness = torqueResponsiveness

	thrust.PlaneVelocity = Utils.V2New(realSpeed.X, realSpeed.Z)
	lift.LineVelocity = realSpeed.Y

	local initialSpeedGlobal = Utils.Min(trueSpeed/(3 * physicsScale), 1)
	local controlStability = Utils.Min(initialSpeedGlobal - trueSpeed/Env.MaxSpeedCalculated/4, 1)

	local rollOutput, pitchOutput, yawOutput = 0, 0, 0
	local dive = Utils.Clamp(90 - Utils.Abs(pitchAngle), 0, 30)/30
	local turnDecay = Utils.Clamp(trueSpeed/(600 * physicsScale), 0, 0.7)
	local bankYaw = bankTurn * _turningRate * dive * (1 + Env.StallBank - turnDecay) * speedGain

	if _advanced then
		rollOutput = (System.Roll + System.Yaw/20) * (1 - Env.StallForce/2) * Thr.LiftTorque * _attitudeControls.RollSpeed * (controlStability + trueSpeed/(Env.MaxSpeedCalculated/2))
		pitchOutput = ((System.Pitch * Utils.Sign(_attitudeControls.PitchSpeed) * Utils.Clamp(1 - Utils.Abs(Env.StallForce), 0, 1)) + Env.StallForce/1.5) * Thr.LiftTorque * Utils.Abs(_attitudeControls.PitchSpeed) * controlStability
		yawOutput = (System.Roll * Utils.Clamp(1 - Thr.LiftTorque - Utils.Abs(System.Yaw), 0, 1) + System.Yaw) * (1 - Thr.LiftTorque/1.6) * _attitudeControls.YawSpeed * controlStability * initialSpeedGlobal + bankYaw
	else
		local bankLimitPct = math.clamp(bankAngle / _attitudeControls.MaxBank, -1, 1)
		local pitchLimitPct = math.clamp(pitchAngle / _attitudeControls.MaxPitch, -1, 1)

		local rollLevelOut = bankLimitPct * 0.45
		local rollDirectionMatch = System.Roll * (if bankAngle > 0 then 1 else -1)
		local rollAuthority = 1.0
		if rollDirectionMatch > 0 then
			rollAuthority = 1.0 - (math.abs(bankLimitPct) * 0.7)
		else
			rollAuthority = 1.0 + (math.abs(bankLimitPct) * 0.3)
		end
		local modifiedRoll = (System.Roll * rollAuthority * (1 - Env.StallForce / 2)) - rollLevelOut

		local isExceedingPitch = (System.Pitch * pitchAngle) > 0
		local pitchAuthority = if isExceedingPitch then (1 - math.abs(pitchLimitPct)) else 1.0

		local stallPitchOffset = Env.StallForce / 1.5
		local cleanPitchInput = System.Pitch * pitchAuthority * math.clamp(1 - math.abs(Env.StallForce), 0, 1)
		local modifiedPitch = (cleanPitchInput * math.sign(_attitudeControls.PitchSpeed)) + stallPitchOffset

		rollOutput = modifiedRoll * Thr.LiftTorque * _attitudeControls.RollSpeed * (controlStability + trueSpeed / (Env.MaxSpeedCalculated / 2))
		pitchOutput = modifiedPitch * Thr.LiftTorque * math.abs(_attitudeControls.PitchSpeed) * controlStability
		yawOutput = ((System.Roll * (1 - Thr.LiftTorque)) * (1 - Thr.LiftTorque / 1.6) * _attitudeControls.YawSpeed * controlStability * initialSpeedGlobal) + bankYaw
	end

	if _tailLift then
		System.CurrentPitch = 0
	elseif trueSpeed >= Thr.StallSpeed95 or Env.Stalling == 1 or Thr.SpeedChange > 0 then
		System.CurrentPitch = pitchRad
	end

	local controlDelta = 1 - Utils.Exp(-4 * dt)
	if (Utils.Abs(System.Speed) + Env.Stalling) > 0.1 then
		if Thr.LiftTorque > 0 then
			local underSpeed = trueSpeed < Thr.StallSpeed95 and Env.Stalling == 0

			if underSpeed and Env.HasCollision then
				local _, currentYaw, _ = System.MotionCFrame:ToEulerAnglesYXZ()
				local currentRollCF = Utils.CFAngles(0, 0, System.CurrentRoll)
				local direction = Utils.CFAngles(0, currentYaw, 0) * Utils.CFAngles(System.CurrentPitch, 0, 0) * currentRollCF
				direction = direction * Utils.CFAngles(0, Utils.Rad(yawOutput) * controlDelta, 0)

				local liftTransition = if Utils.Clamp(_aircraftStatistics.NoseLiftFactor, 0, 1) > 0 then
					Utils.Min(Utils.Max(trueSpeed - Thr.StallSpeed95*(1 - Utils.Clamp(_aircraftStatistics.NoseLiftFactor, 0, 1)), 0)/(Thr.StallSpeed95*Utils.Clamp(_aircraftStatistics.NoseLiftFactor, 0, 1)), 1)
					else
					if trueSpeed >= Thr.StallSpeed95 then 1 else 0
				local groundBlend = 1 - liftTransition

				local tailLiftAngle = if _tailLift then System.RestingAngle * groundBlend else System.RestingAngle
				local yawOnlyDir = Utils.CFLookAt(position, position + Utils.V3New(direction.LookVector.X, 0, direction.LookVector.Z).Unit)

				-- Perfect -200 Hard Clamp for Ground Alignment
				local blendAlpha = if _tailLift then 1 else (1 - Utils.Exp(-250 * dt))
				System.MotionCFrame = direction:Lerp(yawOnlyDir * Utils.CFAngles(Utils.Rad(tailLiftAngle), 0, 0) * currentRollCF, groundBlend * blendAlpha)
			else
				System.MotionCFrame *= Utils.CFAngles(
					Utils.Rad(pitchOutput * controlDelta),
					Utils.Rad(yawOutput * controlDelta),
					Utils.Rad(rollOutput * controlDelta)
				)
			end
			System.TurnCFrame = System.MotionCFrame * Utils.CFAngles(0, Utils.Pi/2, 0)
		else
			System.MotionCFrame = mainCFrame
			System.TurnCFrame *= Utils.CFAngles(0, Utils.Rad(yawOutput * controlDelta), 0)
		end
	else
		System.MotionCFrame = mainCFrame
		System.TurnCFrame = System.MotionCFrame * Utils.CFAngles(0, Utils.Pi/2, 0)
	end

	local responsiveness = Utils.Clamp(_attitudeControls.TorqueResponsiveness/4 * dt, 0, 1) 
	motion.CFrame = motion.CFrame:Lerp(System.MotionCFrame, responsiveness)
	turn.CFrame = turn.CFrame:Lerp(System.TurnCFrame, responsiveness)

	gravity.Force = Utils.V3New(0, mass * Utils.Max(globalGravity - 35, 0) * initialSpeedGlobal, 0)

	-- Overwrite/bypass logic handling
	if not thrust.Enabled and not lift.Enabled then
		realSpeed = mainPart.AssemblyLinearVelocity
		System.Speed = -mainCFrame:VectorToObjectSpace(realSpeed).Z
		thrust.PlaneVelocity = Utils.V2New(realSpeed.X, realSpeed.Z)
		lift.LineVelocity = realSpeed.Y
	end
	if not motion.Enabled and not turn.Enabled then
		System.MotionCFrame = mainCFrame
		System.TurnCFrame = Utils.CFAngles(0, yawAngle + Utils.Pi/2, 0)
		motion.CFrame = mainCFrame
		turn.CFrame = System.TurnCFrame
	end

	state.CalculatedStateFlags = {
		Taxiing = Thr.LiftForce == 0 and Env.Stalling == 0,
		Flying = Thr.LiftForce > 0 and Env.Stalling == 0,
		Stalling = Env.Stalling == 1
	}
end

return Motion