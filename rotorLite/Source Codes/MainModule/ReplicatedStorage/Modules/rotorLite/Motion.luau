-- Motion Module
-- Manages spatial orientation matrices, auto-coordinated bank target curves, and constraints
local Motion = {}

function Motion.Update(dt, state)
	local Utils = state.Utils
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components
	local Env = state.EnvironmentData
	local Thr = state.ThrustData

	local mainPart = Components.MainPart
	local motion = Components.Motion
	local lift = Components.Lift
	local gravity = Components.Gravity

	local mainCFrame = mainPart.CFrame
	local position = mainPart.Position
	local globalGravity = workspace.Gravity

	lift.MaxForce = Thr.Mass * 100 * System.MaxForce
	motion.MaxTorque = Thr.Mass * 2000 * System.MaxForce
	lift.VectorVelocity = System.Velocity

	motion.MaxAngularVelocity = Utils.Clamp(Env.Sensitivity * 3, 1, 3)

	if System.MaxForce > 0.01 then
		local alpha = 1 - Utils.Exp(-Env.Sensitivity / 0.5 * dt)
		local nosePosition = mainCFrame.LookVector * 1e6
		
		local rawMousePos = System.MousePosition
		local validMouse = rawMousePos and rawMousePos ~= Vector3.zero and rawMousePos.Magnitude > 0.001
		
		local targetPosition = if validMouse then rawMousePos else (position + nosePosition)
		local targetDir = (targetPosition - position).Unit
		
		System.Direction = System.Direction:Lerp(targetDir, alpha).Unit

		local targetPosition = position + (System.Direction * 1e6)
		local flatMask = Utils.V3New(1, 0, 1)
		local start2D = nosePosition * flatMask
		local target2D = targetPosition * flatMask

		local maxAngle = Utils.Pi / 4 + Utils.Pi / 8 * Env.Sensitivity

		if start2D.Magnitude > 0.001 and target2D.Magnitude > 0.001 then
			local turnAngle = math.acos(Utils.Clamp(start2D.Unit:Dot(target2D.Unit), -1, 1))
			local turnSign = Utils.Sign(Vector3.yAxis:Dot(start2D:Cross(target2D)))

			local cleanForwardSpeed = Utils.Abs(System.Forward)
			local speedFactor = Utils.Min(cleanForwardSpeed / 30, 1.5)

			local manualRollTarget = System.Roll * maxAngle
			
			local rollSensitivity = Env.Sensitivity * 2.5 * (if System.OnClient then 5 else 1)
			local autoRollTarget = (turnAngle ^ (1 + Env.Sensitivity) * turnSign) * rollSensitivity * speedFactor
			local manualRollOverride = 1 - Utils.Abs(System.Roll)
			autoRollTarget = Utils.Clamp(autoRollTarget * manualRollOverride + manualRollTarget, -maxAngle, maxAngle)

			local dive = 1 - Utils.Max(Utils.Abs(Env.PitchAngle) - 60, 0) / 30
			System.RollAccumulated = Utils.Lerp(System.RollAccumulated * dive, autoRollTarget, alpha)
		end

		local finalRollAngle = Utils.Clamp(System.RollAccumulated, -maxAngle, maxAngle)
		System.MotionCFrame = CFrame.lookAt(position, targetPosition) * Utils.CFAngles(0, 0, finalRollAngle)
	else
		System.Forward = -mainCFrame:VectorToObjectSpace(Env.Velocity).Z
		System.SidewaysSpeed = mainCFrame:VectorToObjectSpace(Env.Velocity).X
		System.Velocity = Utils.V3Zero
		System.Direction = mainCFrame.LookVector * 1e6
		System.MotionCFrame = mainCFrame
	end

	gravity.Force = Utils.V3New(0, Thr.Mass * Utils.Max(globalGravity - 35, 0), 0)

	local responsiveness = Utils.Clamp((10 + Utils.Max(Settings.AircraftStatistics.TorqueResponsiveness, 0.001)) * Thr.StabilityAlpha, 0, 0.25) 
	motion.CFrame = motion.CFrame:Lerp(System.MotionCFrame, responsiveness)

	-- Overwrite/bypass debug safety logic
	if not lift.Enabled then
		System.Forward = -mainCFrame:VectorToObjectSpace(Env.Velocity).Z
		System.SidewaysSpeed = mainCFrame:VectorToObjectSpace(Env.Velocity).X
		System.Velocity = Env.Velocity * Env.PhysicsScale
	end
	if not motion.Enabled then
		System.RollAccumulated = Utils.Rad(Env.BankAngle)
		System.Direction = mainCFrame.LookVector * 1e6
		System.MotionCFrame = mainCFrame
	end
end

return Motion