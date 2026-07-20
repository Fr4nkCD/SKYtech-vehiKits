-- Motion Module
-- Handles flight path tracking, roll/pitch/yaw input mapping, and physical constraint outputs
local Motion = {}

local math_cos = math.cos

function Motion.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local Env = state.EnvironmentData
	local Aero = state.AerodynamicsData

	local motion = Components.Motion
	local aerodynamics = Components.Aerodynamics
	local gravity = Components.Gravity
	
	local _attitudeControls = Settings.AttitudeControls

	local dive = Utils.Max((1 - Utils.Abs(Env.EffectiveBankAngle) / 180) * (1 - Utils.Max(Utils.Abs(Env.PitchAngle) - 60, 0) / 28), 0)
	local turnScale = Utils.Max(Utils.Min(Env.ScaledWorldVelocity.Magnitude / 100, 1) - (Env.ScaledWorldVelocity.Magnitude / 600), 0.1)
	local turn = Env.EffectiveBankAngle / 360 * turnScale * dive * Env.TurningRate

	local rollInput = System.Roll
	local pitchInput = System.Pitch
	local yawInput = System.Yaw
	
	-- Induce realistic Stall Spin (wing drop & authority loss)
	local targetStallSpinRoll = 0
	
	if Env.Stalling == 1 and not System.VTOLHovering then
		if System.StallSpinDirection == 0 then
			-- Lock in the spin direction at the start of the stall
			local rollDir = Utils.Sign(Env.BankAngle)
			if rollDir == 0 then
				rollDir = Utils.Sign(Env.LocalWindDirection.X)
			end
			if rollDir == 0 then
				rollDir = 1 -- Fallback bias
			end
			System.StallSpinDirection = rollDir
		end
		
		local severity = Utils.Clamp(1 - (Env.TrueSpeed / Env.StallSpeed), 0, 1)
		local pitchCosine = math_cos(Env.PitchRad)
		
		-- Wing drop rolling authority (up to 4.0 rad/s spin), scaled down near vertical pitch and VTOL transition level
		local vtolFactor = 1 - System.VTOLlevel
		targetStallSpinRoll = System.StallSpinDirection * severity * 4.0 * Utils.Max(pitchCosine, 0) * vtolFactor
		
		-- Decay control authority (drop to 10% responsiveness at deep stall)
		local authority = Utils.Clamp(1 - severity * 0.9, 0.1, 1)
		rollInput = rollInput * authority
		pitchInput = pitchInput * authority
		yawInput = yawInput * authority

		-- Smoothly interpolate the active stall spin roll rate to avoid instant snaps
		System.StallSpinRoll = System.StallSpinRoll or 0
		local rollFilterAlpha = 1 - math_cos(Utils.Clamp(2 * dt, 0, 1.57))
		System.StallSpinRoll = Utils.Lerp(System.StallSpinRoll, targetStallSpinRoll, rollFilterAlpha)
	else
		-- Reset stall spin direction and roll rate lock when flying normally or hovering
		System.StallSpinDirection = 0
		System.StallSpinRoll = 0
	end

	-- Calculate yaw input rate of change and save current yaw
	local yawJerkRate = if dt > 0.0001 then (yawInput - System.LastYaw) / dt else 0
	System.LastYaw = yawInput
	
	local VTOL_Hovering = System.VTOLHovering
	
	if _attitudeControls.LimitAngle or VTOL_Hovering then
		local maxB = if VTOL_Hovering then 60 else _attitudeControls.MaxBank
		local maxP = if VTOL_Hovering then 60 else _attitudeControls.MaxPitch

		local exceedingBank = if (rollInput * Env.BankAngle) > 0 then Utils.Abs(rollInput) else 0
		local exceedingPitch = if (pitchInput * Env.PitchAngle) > 0 then Utils.Abs(pitchInput) else 0

		local bankLimit = Utils.Clamp(Env.BankAngle / maxB, -1, 1) * exceedingBank
		local pitchLimit = Utils.Clamp(Env.PitchAngle / maxP, -1, 1) * exceedingPitch

		local bankLevelOut = 0
		local pitchLevelOut = 0

		if VTOL_Hovering then
			bankLevelOut = Utils.Sign(Env.BankAngle) * 0.3 * Utils.Min(Utils.Abs(Env.BankAngle) / 5, 1) * (1 - Utils.Abs(rollInput))
			pitchLevelOut = Utils.Sign(Env.PitchAngle) * 0.3 * Utils.Min(Utils.Abs(Env.PitchAngle) / 5, 1) * (1 - Utils.Abs(pitchInput))
		end

		rollInput = rollInput - bankLimit - bankLevelOut
		pitchInput = pitchInput - pitchLimit - pitchLevelOut
	end
	
	local roll = rollInput * _attitudeControls.RollSpeed / 10 * (0.8 + Env.TrueSpeed / Env.MaxSpeed / 2.5) + System.StallSpinRoll
	local pitch = pitchInput * _attitudeControls.PitchSpeed / 10 * (1 - Env.TrueSpeed / Env.MaxSpeed / 2.5)
	local yaw = yawInput * _attitudeControls.YawSpeed / 10 * (1 - Env.TrueSpeed / Env.MaxSpeed / 2.5)

	-- Safe wind calculations
	local cancelWindDirection = Utils.V3Zero
	if Env.ScaledWorldVelocity.Magnitude > 0.001 then
		local velUnit = Env.ScaledWorldVelocity.Unit
		cancelWindDirection = Env.GlobalWind - (velUnit * Env.GlobalWind:Dot(velUnit))
	end

	local mainVelocity = Env.ScaledWorldVelocity - (cancelWindDirection * Utils.Clamp((Env.TrueSpeed - Env.StallSpeed * 0.9) / (Env.StallSpeed * 0.1), 0, 1))
	
	-- Proportional Cross-Product 3D Vector Flight Path Alignment
	local targetFlightPath = Utils.V3Zero
	if mainVelocity.Magnitude > 0.1 then
		local velUnit = mainVelocity.Unit
		local look = Env.MainCFrame.LookVector
		local alignmentAxis = look:Cross(velUnit)
		
		-- Resolve dead-center backward flight by adding a nudge/torque to flip the nose
		if look:Dot(velUnit) < -0.99 then
			alignmentAxis = Env.MainCFrame.UpVector
		end
		
		targetFlightPath = alignmentAxis * 1.5 * Utils.Min(if Env.ScaledWorldVelocity.Magnitude >= 1 then Env.ScaledWorldVelocity.Magnitude / Env.StallSpeed + Env.Stalling else 0, 1) * Utils.Max(1 - Aero.MotionStability * 4, 0)
	end

	-- Scale down flight path alignment at low speed to prevent snapping (especially during VTOL transitions)
	local alignmentSpeedFactor = Utils.Clamp(Env.TrueSpeed / Env.StallSpeed, 0, 1)
	targetFlightPath = targetFlightPath * alignmentSpeedFactor

	-- Reduce path alignment torque while wheels are touching the ground to prevent overshoot (lerped based on speed)
	if Env.HasCollision then
		local speedRatio = Utils.Clamp(Env.TrueSpeed / Env.StallSpeed, 0, 1)
		targetFlightPath = targetFlightPath * (speedRatio * 0.3)
	end

	-- Low-Pass filter smoothing (8 Hz decay constant)
	local filterAlpha = 1 - math_cos(Utils.Clamp(8 * dt, 0, 1.57)) -- Safe filter blending coeff
	System.FlightPath = System.FlightPath:Lerp(targetFlightPath, filterAlpha)

	motion.MaxTorque = Env.Weight * Utils.Clamp(Utils.Max((Env.TrueSpeed - Env.StallSpeed * 0.3) / (Env.StallSpeed * 0.7), 0) + Env.Stalling + Aero.MotionStability, 0, 1) * 2 * _attitudeControls.TorqueResponsiveness
	local motionControl = Env.MainCFrame:VectorToWorldSpace(Utils.V3New(pitch, yaw + turn, roll + yaw / 4) * Utils.Clamp(Utils.Max(Env.TrueSpeed - Env.StallSpeed * (0.3 + 0.3 * Env.Stalling), 0) / (Env.StallSpeed * (0.7 - 0.3 * Env.Stalling)) + Aero.MotionStability, 0.15, 1))
	motion.AngularVelocity = motionControl + System.FlightPath

	-- Compute rudder side-force and deflection kick (pointing opposite to yaw input direction)
	local speedRatio = Utils.Clamp(Env.TrueSpeed / Env.MaxSpeed, 0, 1)
	local rudderForce = -yawInput * Env.Mass * 2.0 * speedRatio
	local rudderKick = -yawJerkRate * Env.Mass * 0.4 * speedRatio
	local totalYawJerk = Env.MainCFrame.RightVector * (rudderForce + rudderKick)

	gravity.Force = Utils.V3New(0, Env.Mass * Utils.Max(Env.GlobalGravity - 35, 0), 0)
	local aeroForce = Aero.AeroX + Aero.AeroY + Aero.AeroZ + Aero.AeroHover + Aero.Crosswind + totalYawJerk
	aerodynamics.Force = Utils.V3New(
		Utils.Clamp(aeroForce.X, -Env.Weight, Env.Weight),
		Utils.Clamp(aeroForce.Y, -Env.Weight, Env.Weight),
		Utils.Clamp(aeroForce.Z, -Env.Weight, Env.Weight)
	)

	-- Update State flags in-place to avoid GC memory churn
	local flying = Env.TrueSpeed >= Env.StallSpeed
	local hovering = System.VTOLlevel > 0 and Env.ScaledWorldVelocity.Magnitude >= Env.StallSpeed * (1 - System.VTOLlevel) - System.VTOLlevel and not flying
	
	local flags = state.CalculatedStateFlags
	flags.Taxiing = not flying and Env.Stalling == 0 and not hovering
	flags.Flying = flying and Env.Stalling == 0
	flags.Stalling = Env.Stalling == 1
	flags.Hovering = hovering
end

return Motion