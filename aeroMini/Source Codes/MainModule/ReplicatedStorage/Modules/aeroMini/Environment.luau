-- Environment Module
-- Handles ground detection and orientation alignment
local Environment = {}

function Environment.Update(dt, state)
	local Utils = state.Utils
	
	local System = state.System
	local Settings = state.Settings
	local Components = state.Components

	local mainPart = Components.MainPart
	local boundSize = Components.BoundSize
	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)

	local mainCFrame = mainPart.CFrame
	local position = mainPart.Position
	local _, _, _ = mainCFrame:ToEulerAnglesYXZ()
	local pitchRad = Utils.GetPitch(mainCFrame)

	local _lowestPoint = Settings.Advanced.LowestPoint or "Auto"
	local _restingAngle = Settings.AircraftStatistics.RestingAngle
	local globalWind = workspace.GlobalWind
	local trueSpeed = Utils.Abs(System.Speed + mainCFrame:VectorToObjectSpace(globalWind).Z)

	local lowestPoint = 0
	local hasCollision = false

	if _lowestPoint == "Auto" then
		local projectedExtent = (boundSize.Y / 2) * math.cos(pitchRad) + (boundSize.Z / 2) * Utils.Abs(math.sin(pitchRad))
		lowestPoint = projectedExtent + physicsScale
	else
		lowestPoint = Utils.Abs(_lowestPoint)
	end

	state.RayFilter.FilterDescendantsInstances = state.IgnoredObjects
	local onGround = workspace:Raycast(position, Utils.V3New(0, -lowestPoint, 0), state.RayFilter)

	if onGround then
		local instance = onGround.Instance
		local model = instance.Parent
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid == nil then
				hasCollision = Utils.CheckPartCollision(instance, state.IgnoredObjects)
			else
				table.insert(state.IgnoredObjects, model)
			end
		else
			hasCollision = Utils.CheckPartCollision(instance, state.IgnoredObjects)
		end
	else
		if #state.IgnoredObjects > 1 then
			table.clear(state.IgnoredObjects)
			table.insert(state.IgnoredObjects, state.AircraftInstance)
		end
	end

	if hasCollision then
		local bankAngle = -Utils.Deg(Utils.GetRoll(mainCFrame)) + 360
		local surfaceBankAngle = Utils.GetSurfaceBankAngle(mainPart, onGround.Normal)
		System.CurrentRoll = Utils.Lerp(System.CurrentRoll, surfaceBankAngle, dt)

		local relativeCFrame = Utils.GetAlignmentCFrame(mainPart, onGround.Normal)
		local relativePitchAngle = Utils.Deg(Utils.GetPitch(relativeCFrame))

		if _restingAngle ~= "Auto" then
			System.RestingAngle = _restingAngle
		elseif _restingAngle == "Auto" and trueSpeed < physicsScale then
			System.RestingAngle = math.floor(relativePitchAngle * 1000) / 1000
		end
	else
		local bankAngle = -Utils.Deg(Utils.GetRoll(mainCFrame)) + 360
		System.CurrentRoll = Utils.Lerp(System.CurrentRoll, Utils.Rad(bankAngle), dt)
	end

	-- Export calculated environment state for downstream processing
	state.EnvironmentData = {
		HasCollision = hasCollision,
		OnGroundNormal = onGround and onGround.Normal or nil,
		LowestPoint = lowestPoint
	}
end

return Environment