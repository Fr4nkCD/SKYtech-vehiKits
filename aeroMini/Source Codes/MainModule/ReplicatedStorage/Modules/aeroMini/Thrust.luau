-- Thrust Module
-- Handles engine curves, updates target velocities, and controls acceleration state
local Thrust = {}

function Thrust.Update(dt, state)
	local Utils = state.Utils
	
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components

	local mainPart = Components.MainPart
	local mainCFrame = mainPart.CFrame

	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local _aircraftStatistics = Settings.AircraftStatistics

	local _acceleration = _aircraftStatistics.Acceleration * physicsScale
	local _minSpeed = System.MinSpeed * physicsScale
	local _maxSpeed = Utils.Max(_aircraftStatistics.MaxSpeed * physicsScale, 0.001)

	local pitchRad, _, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchAngle = Utils.Deg(pitchRad)

	local throttleExponential = if Settings.FlightControls.ThrottleExponential then Utils.Max(System.Throttle, 0.5) else 1
	local desiredSpeed = _maxSpeed * System.Throttle * throttleExponential
	local change = if System.Speed < desiredSpeed + System.MinSpeed then 1 else -1
	local damping = Utils.Clamp(Utils.Abs(System.Speed - desiredSpeed), 0, 1)

	System.Speed = Utils.Clamp(
		System.Speed + (change * damping * _acceleration * dt * 30) - pitchAngle / 1000 + System.Boost * physicsScale,
		if System.Speed < 0 then
			(if _minSpeed ~= 0 then _minSpeed else -_maxSpeed)
			else
			(if System.Speed < _minSpeed then 0 else _minSpeed),
		_maxSpeed
	)
end

return Thrust