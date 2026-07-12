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

	local sidewaysMaxSpeed = maxSpeed / 4
	local sideways_Drag = Utils.Clamp(-System.SidewaysSpeed / Env.PhysicsScale, -0.1, 0.1) * Env.PhysicsScale
	local sideSlip = ((if Env.IsInverted then Env.InvertedBankAngle else Env.BankAngle) / 10 * _acceleration * -Utils.Max(1 - Env.Velocity.Magnitude / 100, 0)) * frameScale

	System.SidewaysSpeed = Utils.Clamp(System.SidewaysSpeed + sideSlip + (sideways_Drag * frameScale), -sidewaysMaxSpeed, sidewaysMaxSpeed)

	local maxAltitude = Utils.V3New(1, Utils.Clamp(Env.MaxAltitude - position.Y, 0, 1), 1)
	local altitudeDrop = Utils.V3New(0, Utils.Clamp((Env.MaxAltitude - 1) - position.Y, -Env.RateOfClimb, 0), 0)
	local crosswind = globalWind * Utils.Min(Env.Velocity.Magnitude / 25, 1)

	local stabilitySpeed = 1 + 0.2 ^ (Utils.Abs(System.Forward) / Env.MaxSpeed)
	local stabilityAlpha = 1 - Utils.Exp(-_stability * stabilitySpeed * dt)
	local horizontalVector = Utils.V3New(1, 0.3, 1)

	System.Velocity = System.Velocity:Lerp((ascend + descend + (mainCFrame.LookVector * System.Forward * horizontalVector) + (mainCFrame.RightVector * System.SidewaysSpeed * horizontalVector)) * maxAltitude + altitudeDrop + crosswind, stabilityAlpha)

	-- Export calculated thrust state in-place
	local thr = state.ThrustData
	thr.StabilityAlpha = stabilityAlpha
	thr.Mass = mainPart.AssemblyMass
end

return Lift