-- Environment Module
-- Handles atmospheric metrics, altitude ceiling clamping, and helicopter weight diagnostics
local Environment = {}

function Environment.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components

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

	local RPM_ = state.RPM_
	local direction_ = state.Direction_
	local isHovering = state.IsHovering

	local mass = Components.StateWrapper:GetAttribute("Mass") or 1
	local weight = mass * 160 * Utils.Min(globalGravity / 35, 1)
	local RPM = Utils.Max((RPM_ - 70), 0) / 30

	-- Safe check to prevent division-by-zero or NaN on direction_.Unit
	local horizontalUnit = if direction_.Magnitude > 0.001 then direction_.Unit else Utils.V3Zero
	local horizontalMagnitude = Utils.V2New(horizontalUnit.X, horizontalUnit.Z).Magnitude

	-- In-place modification of EnvironmentData to prevent GC pressure
	local env = state.EnvironmentData
	env.PhysicsScale = physicsScale
	env.GlobalGravity = globalGravity
	env.MainCFrame = mainCFrame
	env.Position = position
	env.WorldVelocity = worldVelocity
	env.LocalVelocity = localVelocity
	env.SpeedMagnitude = speedMagnitude
	env.Altitude = altitude
	env.BankAngle = bankAngle
	env.IsInverted = isInverted
	env.InvertedBankAngle = invertedBankAngle
	env.PitchRad = pitchRad
	env.PitchAngle = pitchAngle
	env.RPM = RPM
	env.Weight = weight
	env.Mass = mass
	env.Direction_ = direction_
	env.IsHovering = isHovering
	env.HorizontalUnit = horizontalUnit
	env.HorizontalMagnitude = horizontalMagnitude
end

return Environment
