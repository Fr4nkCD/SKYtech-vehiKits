-- Motion Module
-- Handles flight path tracking, roll/pitch/yaw input mapping, and physical constraint outputs
local Motion = {}

local math_cos = math.cos
local math_sin = math.sin
local math_acos = math.acos

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
	local stallSpinRoll = 0
	
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
		
		-- Wing drop rolling authority (up to 2.5 rad/s spin), scaled down near vertical pitch
		stallSpinRoll = System.StallSpinDirection * severity * 2.5 * Utils.Max(pitchCosine, 0)
		
		-- Decay control authority (drop to 10% responsiveness at deep stall)
		local authority = Utils.Clamp(1 - severity * 0.9, 0.1, 1)
		rollInput = rollInput * authority
		pitchInput = pitchInput * authority
		yawInput = yawInput * authority
	else
		-- Reset stall spin direction lock when flying again
		System.StallSpinDirection = 0
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
	
	local roll = rollInput * _attitudeControls.RollSpeed / 10 * (0.8 + Env.TrueSpeed / Env.MaxSpeed / 2.5) + stallSpinRoll
	local pitch = pitchInput * _attitudeControls.PitchSpeed / 10 * (1 - Env.TrueSpeed / Env.MaxSpeed / 2.5)
	local yaw = yawInput * _attitudeControls.YawSpeed / 10 * (1 - Env.TrueSpeed / Env.MaxSpeed / 2.5)

	-- Safe wind calculations
	local cancelWindDirection = Utils.V3Zero
	if Env.ScaledWorldVelocity.Magnitude > 0.001 then
		local velUnit = Env.ScaledWorldVelocity.Unit
		cancelWindDirection = Env.GlobalWind - (velUnit * Env.GlobalWind:Dot(velUnit))
		cancelWindDirection = if cancelWindDirection == cancelWindDirection then cancelWindDirection else Utils.V3Zero
	end

	local mainVelocity = Env.ScaledWorldVelocity - (cancelWindDirection * Utils.Clamp((Env.TrueSpeed - Env.StallSpeed * 0.9) / (Env.StallSpeed * 0.1), 0, 1))
	
	-- Safe horizontal unit projection to prevent division-by-zero NaNs at near-zero vectors
	local lookXZ = Utils.V3New(Env.MainCFrame.LookVector.X, 0, Env.MainCFrame.LookVector.Z)
	local mainXZ = if lookXZ.Magnitude > 0.001 then lookXZ.Unit else Utils.V3Zero

	local velXZ = Utils.V3New(mainVelocity.X, 0, mainVelocity.Z)
	local velocityXZ = if velXZ.Magnitude > 0.001 then velXZ.Unit else Utils.V3Zero

	local forwardComponent = mainVelocity:Dot(Env.MainCFrame.LookVector)
	local rad = Utils.Rad(Env.BankAngle)
	local right = Env.MainCFrame.RightVector
	local up = Env.MainCFrame.UpVector
	local smoothUp = up * math_cos(rad) + right * math_sin(rad)
	local upComponent = mainVelocity:Dot(smoothUp.Unit)
	
	local velocityDirection = 0
	if velocityXZ.Magnitude > 0.001 then
		velocityDirection = math_acos(Utils.Clamp(Utils.V3New(0, 0, -1):Dot(velocityXZ), -1, 1)) * (if Utils.V3New(0, 0, -1):Cross(velocityXZ).Y >= 0 then 1 else -1)
	end

	-- Proportional Cross-Product Steering & Pitch Cosine Decay for pathYaw
	local pathYaw = 0
	if mainXZ.Magnitude > 0.001 and velocityXZ.Magnitude > 0.001 then
		local yawError = mainXZ:Cross(velocityXZ).Y
		local pitchCosine = math_cos(Env.PitchRad)
		pathYaw = (yawError * 1.5) / (10 - 5 * Env.Stalling) * (1 + 0.25 * Env.Stalling) * Utils.Max(pitchCosine, 0)
	end
	
	local pathPitch = Utils.Clamp(math.atan2(upComponent, forwardComponent), -2, 2) * 1.25 * Utils.Clamp(1 - (Env.ScaledWorldVelocity.Magnitude - Env.StallSpeed) / Env.MaxSpeed, 0.1, 1)

	-- Calculate the target flight path vector
	local targetFlightPath = (Utils.V3New(0, pathYaw, 0) + Utils.CFAngles(0, velocityDirection, 0):VectorToWorldSpace(Utils.V3New(pathPitch, 0, 0)) * Utils.Min(if Env.ScaledWorldVelocity.Magnitude >= 1 then Env.ScaledWorldVelocity.Magnitude / Env.StallSpeed + Env.Stalling else 0, 1)) * Utils.Max(1 - Aero.MotionStability * 4, 0)

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
