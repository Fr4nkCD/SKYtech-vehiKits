-- Aerodynamics Module
-- Handles aerodynamic drag forces, lift force curves, VTOL hover, and wind effects
local Aerodynamics = {}

function Aerodynamics.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Components = state.Components
	local Env = state.EnvironmentData
	local globalWind = Env.GlobalWind

	local forwardDrag = Env.TrueSpeed / Env.MaxSpeed / (3000 + (1000 * Env.Velocity.Magnitude / Env.MaxSpeed)) * Utils.Max(1 - Env.Altitude / state.Settings.AircraftStatistics.MaxAltitude, 0.25) * Env.DragCoeff
	local maxSpeedDrag = Utils.Max((Env.Velocity.Magnitude - Env.MaxSpeed) / (5000 + 5000 * (1 - Env.StabilityCoeff)), 0)

	-- Calculate desired speed based on exponential throttle curve
	local throttleExponential = Utils.Max(System.Throttle, 0.25)
	local desiredSpeed = Env.MaxSpeed * System.Throttle * throttleExponential
	
	-- Calculate speed-limiting drag (active only when overspeeding relative to throttle)
	local speedError = Env.TrueSpeed - desiredSpeed
	local targetSpeedDrag = 0
	if speedError > 0 then
		targetSpeedDrag = (speedError / Env.MaxSpeed) * Env.DragCoeff * 0.001
	end

	local liftLoss = if Env.SymmetricalAirfoil then 1 - Utils.Abs(Env.EffectiveBankAngle) / 270 else 1 - Utils.Abs(Env.BankAngle) / 270
	local lift_Force = Utils.Clamp((Env.TrueSpeed - Env.StallSpeed) / (60 + 40 * (1 - Env.StabilityCoeff)), 0, Utils.Max(Env.StabilityCoeff, 0.001)) / 10 * liftLoss
	local stall_Force = Env.TrueSpeed / Env.StallSpeed * Env.Velocity.Magnitude / Env.StallSpeed / 400

	local aeroX = Env.MainCFrame.RightVector * Env.Weight * (lift_Force + maxSpeedDrag + stall_Force) * -Env.Velocity.X * (1 - Utils.Abs(Env.LocalWindDirection.X) / (1.5 - Env.StabilityCoeff / 2.5))
	local aeroY = Env.MainCFrame.UpVector * Env.Weight * (lift_Force + maxSpeedDrag + stall_Force) * -Env.Velocity.Y * (1 - Utils.Abs(Env.LocalWindDirection.Y) / (1.5 - Env.StabilityCoeff / 2.5))
	local aeroZ = Env.MainCFrame.LookVector * Env.Weight * (forwardDrag + maxSpeedDrag + targetSpeedDrag) * Env.Velocity.Z

	local stats = Components.Stats_
	local stabilityVal = (stats and stats:GetAttribute("MotionStability")) or Components.StateWrapper:GetAttribute("Stability") or 0
	local motionStability = stabilityVal * System.Throttle
	local VTOLlevel = System.VTOLlevel
	local VTOL = VTOLlevel * System.Throttle * (if Env.TrueSpeed < Env.StallSpeed then 1 else 0)
	local aeroHover = Utils.V3New(0, Env.Weight * -Env.Velocity.Y / (200 * (1 + Utils.Abs(Env.WorldVelocity.Y) / 20)) * VTOL, 0)

	local windFactor = 0
	if Env.ScaledWorldVelocity.Magnitude > 0.001 and globalWind.Magnitude > 0.001 then
		windFactor = 1 - Utils.Abs(Env.ScaledWorldVelocity.Unit:Dot(globalWind.Unit))
	end
	
	local windForce = globalWind * windFactor
	local windForwardComponent = Env.MainCFrame.LookVector * windForce:Dot(Env.MainCFrame.LookVector)
	local windLimit = Utils.Min(Env.TrueSpeed / 10, 1)
	local crosswindForce = (windForce - windForwardComponent + Env.DriftDirection) * windLimit
	local crosswind = Env.Mass * 1.5 * crosswindForce * Utils.Clamp((Env.TrueSpeed - Env.StallSpeed * 0.9) / (Env.StallSpeed * 0.1), 0, 1)

	state.AerodynamicsData = {
		AeroX = aeroX,
		AeroY = aeroY,
		AeroZ = aeroZ,
		AeroHover = aeroHover,
		Crosswind = crosswind,
		MotionStability = motionStability,
		VTOLlevel = VTOLlevel,
	}
end

return Aerodynamics