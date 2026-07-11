-- Environment Module
-- Handles atmospheric metrics, altitude ceiling clamping, and collective scaling
local Environment = {}

function Environment.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components

	local Stats_ = Components.Stats_
	local mainPart = Components.MainPart
	local mainCFrame = mainPart.CFrame
	local position = mainPart.Position
	local altitude = position.Y

	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local _aircraftStatistics = Settings.AircraftStatistics

	local _sensitivity = Utils.Max(_aircraftStatistics.Sensitivity, 0.001)
	local _maxSpeed = Utils.Max(_aircraftStatistics.MaxSpeed * physicsScale, 0.001)
	local _maxAltitude = Utils.Max(_aircraftStatistics.MaxAltitude * physicsScale, 0.001)
	local _rateOfClimb = _aircraftStatistics.RateOfClimb * physicsScale

	local velocity = mainPart.AssemblyLinearVelocity / physicsScale
	local bankAngle = -Utils.Deg(Utils.GetRoll(mainCFrame)) + 360
	local isInverted = bankAngle % 360 >= 90 and bankAngle % 360 <= 270
	local invertedBankAngle = Utils.Deg(Utils.GetRoll(mainCFrame * Utils.CFAngles(0, 0, Utils.Pi))) - 360
	local pitchRad, yawAngle, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchAngle = Utils.Deg(pitchRad)

	local collective = Utils.Clamp(System.Collective / 0.1 + velocity.Magnitude / 20, 0, 1) * (if Stats_:GetAttribute("Active") == true then 1 else 0)
	local forceAlpha = 1 - Utils.Exp(-10 * (0.5 + _sensitivity / 2) * dt)
	System.MaxForce = Utils.Lerp(System.MaxForce, collective, forceAlpha)

	state.EnvironmentData = {
		PhysicsScale = physicsScale,
		Velocity = velocity,
		BankAngle = bankAngle,
		IsInverted = isInverted,
		InvertedBankAngle = invertedBankAngle,
		PitchRad = pitchRad,
		PitchAngle = pitchAngle,
		YawAngle = yawAngle,
		MaxSpeed = _maxSpeed,
		MaxAltitude = _maxAltitude,
		RateOfClimb = _rateOfClimb,
		Sensitivity = _sensitivity
	}
end

return Environment