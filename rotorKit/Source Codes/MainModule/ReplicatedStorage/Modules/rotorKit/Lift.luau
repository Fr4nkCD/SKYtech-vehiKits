-- Lift Module
-- Processes multi-axial aerodynamics, wind forces, and collective thrust vectoring
local Lift = {}

function Lift.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local Env = state.EnvironmentData

	local lift = Components.Lift
	local aerodynamics = Components.Aerodynamics
	local globalWind = workspace.GlobalWind

	local _maxSpeed = Utils.Max(Settings.AircraftStatistics.MaxSpeed, 0.001)
	local _maxAltitude = Settings.AircraftStatistics.MaxAltitude
	local _rateOfClimb = Settings.AircraftStatistics.RateOfClimb

	local maxSpeedBit = Env.Altitude / Utils.Max(_maxAltitude * 0.25, 0.001)
	local verticalMaxSpeedDrag = maxSpeedBit * Utils.Abs(Env.HorizontalUnit.Y)
	local horizontalMaxSpeedDrag = maxSpeedBit * Env.HorizontalMagnitude

	local maxSpeed = _maxSpeed * Utils.Max((0.75 + Utils.Abs(Env.HorizontalUnit.Y) / 4) - verticalMaxSpeedDrag + horizontalMaxSpeedDrag, 0.75)
	local maxSpeedDrag = Utils.Max(Env.SpeedMagnitude - maxSpeed, 0) / 1000
	local speedDrag = 0.005 * Env.SpeedMagnitude / maxSpeed
	
	local XYForce = Env.Weight * (speedDrag * (1 + Env.HorizontalMagnitude) + maxSpeedDrag)
	local collectiveDrag = 1 - System.Collective
	local verticalFactor = 1 - Env.HorizontalMagnitude
	local forwardDrag = Utils.Max(100 + (1900 * verticalFactor * collectiveDrag), 100)
	local ZForce = Env.Weight * (speedDrag / forwardDrag + maxSpeedDrag)
	
	local aeroX = Env.MainCFrame.RightVector * XYForce * -Env.LocalVelocity.X
	local aeroY = Env.MainCFrame.UpVector * XYForce * -Env.LocalVelocity.Y * 1.5
	local aeroZ = Env.MainCFrame.LookVector * ZForce * Env.LocalVelocity.Z
	
	local aerodynamicsForce = aeroX + aeroY + aeroZ
	local aeroHover = Utils.V3New(0, if Env.IsHovering then Env.Weight * -Env.LocalVelocity.Y / 140 else 0, 0)
	local crosswind = globalWind * Env.Weight * Env.SpeedMagnitude / 25000
	
	aerodynamics.Force = (aerodynamicsForce + aeroHover + crosswind) * Env.RPM

	local rateOfClimb = _rateOfClimb + (_maxSpeed - _rateOfClimb) * Env.HorizontalMagnitude
	local liftDrag = 1 - Utils.Max((Env.WorldVelocity.Y - rateOfClimb) / 5, 0)
	local pressureLoss = Utils.Min(Utils.Max(Env.Altitude - _maxAltitude, 0) / 100, 1)
	local liftForce = Env.Weight / 2 * Utils.Max(System.Collective - 0.1, 0) * liftDrag * (1 - pressureLoss)

	state.LiftData = {
		LiftForce = liftForce,
		RateOfClimb = rateOfClimb,
	}
end

return Lift
