-- Environment Module
-- Handles atmospheric metrics, altitude ceiling clamping, and helicopter weight diagnostics
local Environment = {}

function Environment.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components

	local Stats_ = Components.Stats_
	local mainPart = Components.MainPart

	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local globalGravity = workspace.Gravity
	local mainCFrame = mainPart.CFrame
	local position = mainPart.Position
	local worldVelocity = mainPart.AssemblyLinearVelocity / physicsScale
	local localVelocity = mainCFrame:VectorToObjectSpace(worldVelocity)
	local speedMagnitude = worldVelocity.Magnitude
	local altitude = position.Y / physicsScale
	local bankAngle = -Utils.Deg(Utils.GetRoll(mainCFrame)) + 360
	local isInverted = bankAngle % 360 >= 90 and bankAngle % 360 <= 270
	local invertedBankAngle = Utils.Deg(Utils.GetRoll(mainCFrame * Utils.CFAngles(0, 0, Utils.Pi))) - 360
	local pitchRad, _, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchAngle = Utils.Deg(pitchRad)

	local RPM_ = Stats_:GetAttribute("RPM")
	local direction_ = Stats_:GetAttribute("Direction")
	local isHovering = Stats_:GetAttribute("Hover")

	local mass = Components.StateWrapper:GetAttribute("Mass") or 1
	local weight = mass * 160 * Utils.Min(globalGravity / 35, 1)
	local RPM = Utils.Max((RPM_ - 70), 0) / 30

	local horizontalUnit = if direction_.Unit then direction_.Unit else Utils.V3Zero
	local horizontalMagnitude = Utils.V2New(horizontalUnit.X, horizontalUnit.Z).Magnitude

	state.EnvironmentData = {
		PhysicsScale = physicsScale,
		GlobalGravity = globalGravity,
		MainCFrame = mainCFrame,
		Position = position,
		WorldVelocity = worldVelocity,
		LocalVelocity = localVelocity,
		SpeedMagnitude = speedMagnitude,
		Altitude = altitude,
		BankAngle = bankAngle,
		IsInverted = isInverted,
		InvertedBankAngle = invertedBankAngle,
		PitchRad = pitchRad,
		PitchAngle = pitchAngle,
		RPM = RPM,
		Weight = weight,
		Mass = mass,
		Direction_ = direction_,
		IsHovering = isHovering,
		HorizontalUnit = horizontalUnit,
		HorizontalMagnitude = horizontalMagnitude,
	}
end

return Environment
