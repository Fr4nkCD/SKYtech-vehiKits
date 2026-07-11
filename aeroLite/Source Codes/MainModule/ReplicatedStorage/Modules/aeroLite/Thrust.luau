-- Thrust Module
-- Handles engine curves, throttle management, and braking coefficients
local Thrust = {}

function Thrust.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local Env = state.EnvironmentData

	local mainPart = Components.MainPart
	local mainCFrame = mainPart.CFrame

	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local _aircraftStatistics = Settings.AircraftStatistics
	local _attitudeControls = Settings.AttitudeControls

	local _acceleration = _aircraftStatistics.Acceleration * physicsScale
	local _deceleration = _aircraftStatistics.Deceleration * physicsScale
	local _airbrake = if _aircraftStatistics.Airbrake == true then 0 else 1
	local _brakeRatio = _aircraftStatistics.BrakeRatio
	local _gravitySpeed = _aircraftStatistics.GravitySpeed * physicsScale
	local _turningBleed = _attitudeControls.TurningBleed

	local pitchRad, _, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchAngle = Utils.Deg(pitchRad)
	local trueSpeed = Utils.Abs(System.Speed + mainCFrame:VectorToObjectSpace(workspace.GlobalWind).Z)

	local lift_Force = Utils.Min(Utils.Max(trueSpeed - Env.StallSpeed, 0)/(Env.StallSpeed * 0.1) + Env.Stalling, 1)
	local stallSpeed95 = Env.StallSpeed * 0.95
	local lift_Torque = Utils.Min(Utils.Max(trueSpeed - stallSpeed95 * (1 - Utils.Clamp(_aircraftStatistics.NoseLiftFactor, 0, 1)), 0)/(if Utils.Clamp(_aircraftStatistics.NoseLiftFactor, 0, 1) > 0 then stallSpeed95 * Utils.Clamp(_aircraftStatistics.NoseLiftFactor, 0, 1) else 1) + Env.Stalling, 1)

	local gravitySpeed = (_gravitySpeed + (Env.StallSpeed * Env.Stalling * 2)) * math.sin(pitchRad) * lift_Force
	local minSpeed = System.MinSpeed * physicsScale
	local throttleExponential = Utils.Max(System.Throttle, 0.25)
	local desiredSpeed = (Env.MaxSpeedCalculated * System.Throttle * throttleExponential) - gravitySpeed + minSpeed

	local changeSign = if System.Speed < desiredSpeed then 1 * (0.5 + System.Throttle/2) else -1 * (1 - System.Throttle/2)
	local speedDamping = Utils.Clamp(Utils.Abs(System.Speed - desiredSpeed)/(15 * physicsScale), if System.Brake > 0 then 1 else 0.5, 1)

	local targetChange = (changeSign * speedDamping) - pitchAngle/360
	local timeScale = dt * 30

	local acceleration = (_acceleration * (1 - pitchAngle/180)) * targetChange * timeScale
	local deceleration = (_deceleration * (1 + pitchAngle/180)) * targetChange * timeScale

	local brake = System.Brake * (_deceleration * _brakeRatio) * (1 - (lift_Force + Env.Stalling) * _airbrake) * Utils.Sign(System.Speed) * timeScale
	local speedDrop = gravitySpeed * 0.0001 * timeScale
	local pitchRate = Utils.Abs(mainPart.AssemblyAngularVelocity:Dot(mainCFrame.RightVector))
	local turningBleed = if lift_Torque > 0 then pitchRate * _turningBleed * trueSpeed * 0.005 * timeScale else 0

	local speedChange = if targetChange > 0 then acceleration else deceleration

	System.Speed = Utils.Clamp(
		System.Speed + speedChange + ((System.Boost * physicsScale) * timeScale) - brake - speedDrop - turningBleed,
		if System.Speed < 0 then
			(if minSpeed ~= 0 then minSpeed else -Env.MaxSpeedCalculated)
			else
			(if System.Speed < minSpeed then 0 else minSpeed),
		Env.MaxSpeedCalculated
	)

	-- Save tracking state variables for kinematics calculations
	state.ThrustData = {
		LiftForce = lift_Force,
		LiftTorque = lift_Torque,
		SpeedChange = speedChange,
		StallSpeed95 = stallSpeed95
	}
end

return Thrust