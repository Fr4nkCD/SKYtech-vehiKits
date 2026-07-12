local Lift = {}

local math_sqrt = math.sqrt

function Lift.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local Env = state.EnvironmentData
	
	local mainPart = Components.MainPart
	local mainCFrame = Env.MainCFrame
	local position = Env.Position
	local globalWind = Env.GlobalWind
	
	local frameScale = dt * 45
	local _aircraftStatistics = Settings.AircraftStatistics
	
	-- Apply square root compression curve to prevent settings deadzone jumps
	local _acceleration = math_sqrt(Utils.Max(_aircraftStatistics.Acceleration, 0)) * 0.22 * Env.PhysicsScale
	local _stability = Utils.Max(_aircraftStatistics.Stability, 0.001)

	local upperCollective = Utils.Min(Utils.Max(System.Collective - 0.5, 0) / 0.5, 1)
	local lowerCollective = 1 - Utils.Min(System.Collective / 0.5, 1)

	local ascend = mainCFrame.UpVector * upperCollective * Utils.Max(upperCollective, 0.8) * Env.RateOfClimb
	local descend = Utils.V3New(0, -(lowerCollective * Utils.Max(lowerCollective, 0.8)) * Env.RateOfClimb, 0)

	local maxSpeed = Env.MaxSpeed - (Env.MaxSpeed * 0.25 * position.Y / Env.MaxAltitude)
	local turnRate = Utils.Abs(mainPart.AssemblyAngularVelocity:Dot(mainCFrame.UpVector))

	System.DynamicForwardDrag = (if System.Forward < 0 then 0.05 else -0.05) * (1 + turnRate) * Env.PhysicsScale
	local drag_Damping = Utils.Min(Utils.Abs(System.Forward / Env.PhysicsScale), 1)

	local acceleration = (-Env.PitchAngle / 10 * _acceleration) * frameScale
	System.Forward = Utils.Clamp(System.Forward + acceleration + (System.DynamicForwardDrag * drag_Damping * frameScale), -maxSpeed, maxSpeed)

	-- Apply turning speed bleed to prevent high-speed slinging
	System.Forward = System.Forward * (1 - Utils.Min(turnRate * 0.1, 0.25) * dt)

	local sidewaysMaxSpeed = maxSpeed / 4
	local sideways_Drag = Utils.Clamp(-System.SidewaysSpeed / Env.PhysicsScale, -0.1, 0.1) * Env.PhysicsScale
	local sideSlip = ((if Env.IsInverted then Env.InvertedBankAngle else Env.BankAngle) / 10 * _acceleration * -Utils.Max(1 - Env.Velocity.Magnitude / 100, 0)) * frameScale

	System.SidewaysSpeed = Utils.Clamp(System.SidewaysSpeed + sideSlip + (sideways_Drag * frameScale), -sidewaysMaxSpeed, sidewaysMaxSpeed)

	local maxAltitude = Utils.V3New(1, Utils.Clamp(Env.MaxAltitude - position.Y, 0, 1), 1)
	local altitudeDrop = Utils.V3New(0, Utils.Clamp((Env.MaxAltitude - 1) - position.Y, -Env.RateOfClimb, 0), 0)
	local crosswind = globalWind * Utils.Min(Env.Velocity.Magnitude / 25, 1)

	local speedRatio = Utils.Clamp(Utils.Abs(System.Forward) / Env.MaxSpeed, 0, 1)
	local stabilitySpeedHorizontal = Utils.Lerp(2.0, 1.65, speedRatio)

	local stabilityAlphaHorizontal = 1 - Utils.Exp(-_stability * stabilitySpeedHorizontal * dt)
	local stabilityAlphaVertical = 1 - Utils.Exp(-_stability * 2.0 * dt)
	local horizontalVector = Utils.V3New(1, 0.3, 1)

	local targetVelocity = (ascend + descend + (mainCFrame.LookVector * System.Forward * horizontalVector) + (mainCFrame.RightVector * System.SidewaysSpeed * horizontalVector)) * maxAltitude + altitudeDrop + crosswind

	local newVelocityX = Utils.Lerp(System.Velocity.X, targetVelocity.X, stabilityAlphaHorizontal)
	local newVelocityY = Utils.Lerp(System.Velocity.Y, targetVelocity.Y, stabilityAlphaVertical)
	local newVelocityZ = Utils.Lerp(System.Velocity.Z, targetVelocity.Z, stabilityAlphaHorizontal)

	System.Velocity = Utils.V3New(newVelocityX, newVelocityY, newVelocityZ)

	-- Export calculated thrust state in-place
	local thr = state.ThrustData
	thr.StabilityAlpha = stabilityAlphaHorizontal
	thr.Mass = mainPart.AssemblyMass
end

return Lift