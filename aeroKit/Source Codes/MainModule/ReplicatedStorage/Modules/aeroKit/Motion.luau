-- Motion Module
-- Handles flight path tracking, roll/pitch/yaw input mapping, and physical constraint outputs
local Motion = {}

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

	local dive = Utils.Max((1 - Utils.Abs(if Env.NotUpsideDown then Env.BankAngle else Env.InvertedBankAngle) / 180) * (1 - Utils.Max(Utils.Abs(Env.PitchAngle) - 60, 0) / 28), 0)
	local turnScale = Utils.Max(Utils.Min(Env.ScaledWorldVelocity.Magnitude / 100, 1) - (Env.ScaledWorldVelocity.Magnitude / 600), 0.1)
	local turn = (if Env.NotUpsideDown then Env.BankAngle else Env.InvertedBankAngle) / 360 * turnScale * dive * Env.TurningRate

	local rollInput = System.Roll
	local pitchInput = System.Pitch
	
	local VTOL_Hovering = Components.StateWrapper:GetAttribute("Hovering") == true
	
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
	
	local roll = rollInput * _attitudeControls.RollSpeed / 10 * (0.8 + Env.TrueSpeed / Env.MaxSpeed / 2.5)
	local pitch = pitchInput * _attitudeControls.PitchSpeed / 10 * (1 - Env.TrueSpeed / Env.MaxSpeed / 2.5)
	local yaw = System.Yaw * _attitudeControls.YawSpeed / 10 * (1 - Env.TrueSpeed / Env.MaxSpeed / 2.5)

	local cancelWindDirection = workspace.GlobalWind - (Env.ScaledWorldVelocity.Unit * workspace.GlobalWind:Dot(Env.ScaledWorldVelocity.Unit))
	cancelWindDirection = if cancelWindDirection ~= cancelWindDirection then Utils.V3Zero else cancelWindDirection

	local mainVelocity = Env.ScaledWorldVelocity - (cancelWindDirection * Utils.Clamp((Env.TrueSpeed - Env.StallSpeed * 0.9) / (Env.StallSpeed * 0.1), 0, 1))
	local mainXZ = Utils.V3New(Env.MainCFrame.LookVector.X, 0, Env.MainCFrame.LookVector.Z).Unit
	local velocityXZ = Utils.V3New(mainVelocity.X, 0, mainVelocity.Z).Unit
	mainXZ = if mainXZ ~= mainXZ then Utils.V3Zero else mainXZ
	velocityXZ = if velocityXZ ~= velocityXZ then Utils.V3Zero else velocityXZ

	local forwardComponent = mainVelocity:Dot(Env.MainCFrame.LookVector)
	local rad = Utils.Rad(Env.BankAngle)
	local right = Env.MainCFrame.RightVector
	local up = Env.MainCFrame.UpVector
	local smoothUp = up * math.cos(rad) + right * math.sin(rad)
	local upComponent = mainVelocity:Dot(smoothUp.Unit)
	local velocityDirection = math.acos(Utils.V3New(0, 0, -1):Dot(velocityXZ)) * (if Utils.V3New(0, 0, -1):Cross(velocityXZ).Y >= 0 then 1 else -1)

	local pathYaw = math.acos(Utils.Clamp(mainXZ:Dot(velocityXZ), -2, 2)) * (if mainXZ:Cross(velocityXZ).Y >= 0 then 1 else -1) / (10 - 5 * Env.Stalling) * (1 + 0.25 * Env.Stalling)
	local pathPitch = Utils.Clamp(math.atan2(upComponent, forwardComponent), -2, 2) * 1.25 * Utils.Clamp(1 - (Env.ScaledWorldVelocity.Magnitude - Env.StallSpeed) / Env.MaxSpeed, 0.1, 1)

	pathYaw = if pathYaw ~= pathYaw then 0 else pathYaw
	pathPitch = if pathPitch ~= pathPitch then 0 else pathPitch
	local flightPath = (Utils.V3New(0, pathYaw, 0) + Utils.CFAngles(0, velocityDirection, 0):VectorToWorldSpace(Utils.V3New(pathPitch, 0, 0)) * Utils.Min(if Env.ScaledWorldVelocity.Magnitude >= 1 then Env.ScaledWorldVelocity.Magnitude / Env.StallSpeed + Env.Stalling else 0, 1)) * Utils.Max(1 - Aero.MotionStability * 4, 0)

	motion.MaxTorque = Env.Weight * Utils.Clamp(Utils.Max((Env.TrueSpeed - Env.StallSpeed * 0.3) / (Env.StallSpeed * 0.7), 0) + Env.Stalling + Aero.MotionStability, 0, 1) * 2 * _attitudeControls.TorqueResponsiveness
	local motionControl = Env.MainCFrame:VectorToWorldSpace(Utils.V3New(pitch, yaw + turn, roll + yaw / 4) * Utils.Clamp(Utils.Max(Env.TrueSpeed - Env.StallSpeed * (0.3 + 0.3 * Env.Stalling), 0) / (Env.StallSpeed * (0.7 - 0.3 * Env.Stalling)) + Aero.MotionStability, 0.15, 1))
	motion.AngularVelocity = motionControl + flightPath

	gravity.Force = Utils.V3New(0, Env.Mass * Utils.Max(workspace.Gravity - 35, 0), 0)
	local aeroForce = Aero.AeroX + Aero.AeroY + Aero.AeroZ + Aero.AeroHover + Aero.Crosswind
	aerodynamics.Force = Utils.V3New(
		Utils.Clamp(aeroForce.X, -Env.Weight, Env.Weight),
		Utils.Clamp(aeroForce.Y, -Env.Weight, Env.Weight),
		Utils.Clamp(aeroForce.Z, -Env.Weight, Env.Weight)
	)

	-- State mapping updates
	local flying = Env.TrueSpeed >= Env.StallSpeed
	local hovering = Aero.VTOLlevel > 0 and Env.ScaledWorldVelocity.Magnitude >= Env.StallSpeed * (1 - Aero.VTOLlevel) - Aero.VTOLlevel and not flying
	
	state.CalculatedStateFlags = {
		Taxiing = not flying and Env.Stalling == 0 and not hovering,
		Flying = flying and Env.Stalling == 0,
		Stalling = Env.Stalling == 1,
		Hovering = hovering
	}
end

return Motion
