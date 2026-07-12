-- Motion Module
-- Manages spatial rotation updates, auto-stabilized leveling, and sets constraint outputs
local Motion = {}

function Motion.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local Env = state.EnvironmentData
	local Lft = state.LiftData

	local motion = Components.Motion
	local lift = Components.Lift
	local gravity = Components.Gravity

	local _turningRate = Settings.AttitudeControls.TurningRate
	local _torqueResponsiveness = Settings.AttitudeControls.TorqueResponsiveness
	local _limitAngle = Settings.AttitudeControls.LimitAngle == true

	local dive = Utils.Clamp(85 - Utils.Abs(Env.PitchAngle), 0, 30) / 30
	local turnSpeed = _turningRate * Utils.Min(Env.SpeedMagnitude / 100, 1)
	local turnFactor = Utils.Max(turnSpeed - (Env.SpeedMagnitude / 600), 0.1)
	local turn = (if Env.IsInverted then Env.InvertedBankAngle else Env.BankAngle) / (180 + 45 * Env.HorizontalMagnitude) * turnFactor * dive

	local rollInput, pitchInput = 0, 0

	if _limitAngle or System.Hovering then
		local maxBank = if System.Hovering then 20 else Utils.Max(Utils.Abs(Settings.AttitudeControls.MaxBank), 1)
		local bankLimit = Utils.Clamp(Env.BankAngle / maxBank, -1, 1) * Utils.Abs(System.Roll)
		local bankLevelOut = Utils.Sign(Env.BankAngle) * 0.3 * Utils.Min(Utils.Abs(Env.BankAngle) / 5, 1) * (1 - Utils.Abs(System.Roll))
		
		local maxPitch = if System.Hovering then 20 else Utils.Max(Utils.Abs(Settings.AttitudeControls.MaxPitch), 1)
		local pitchLimit = Utils.Clamp(Env.PitchAngle / maxPitch, -1, 1) * Utils.Abs(System.Pitch)
		local pitchLevelOut = Utils.Sign(Env.PitchAngle) * 0.3 * Utils.Min(Utils.Abs(Env.PitchAngle) / 5, 1) * (1 - Utils.Abs(System.Pitch))
		
		rollInput = System.Roll - bankLimit - bankLevelOut
		pitchInput = System.Pitch - pitchLimit - pitchLevelOut
	else
		rollInput = System.Roll
		pitchInput = System.Pitch
	end

	local roll = rollInput * Settings.AttitudeControls.RollSpeed / 10
	local pitch = pitchInput * Settings.AttitudeControls.PitchSpeed / 10
	local yaw = System.Yaw * Settings.AttitudeControls.YawSpeed / 10

	motion.MaxTorque = ((Env.Weight / 20 * Utils.Min(Env.SpeedMagnitude / 10, 1)) + (Env.Weight * System.Collective)) * _torqueResponsiveness * Env.RPM
	motion.AngularVelocity = Utils.V3New(pitch, yaw + turn, roll)

	local direction = Env.Direction_ - Utils.V3New(rollInput * 0.25, 0, pitchInput * 0.25)
	lift.Force = Utils.V3New(Lft.LiftForce, Lft.LiftForce, -Lft.LiftForce) * direction * Env.RPM

	gravity.Force = Utils.V3New(0, Env.Mass * Utils.Max(Env.GlobalGravity - 35, 0), 0)
end

return Motion
