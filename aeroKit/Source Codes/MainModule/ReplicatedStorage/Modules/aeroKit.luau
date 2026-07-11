-- aeroKit Flight Physics
-- by SKYtech

local aeroKit = {
	States = {}
}

-- Utilies (math, physics, global variables)
local Utils = require(script.Parent:WaitForChild("VehicleUtils"))

function aeroKit:Initialize(aircraft)
	local main = aircraft.Main
	local mainPart = main.Main

	self.States[aircraft] = {
		System = {
			Throttle = 0,
			Brake = 0,
			Roll = 0,
			Pitch = 0,
			Yaw = 0,
			-----------------------
			Boost = 0,
			MinSpeed = 0,
			Speed = 0,
			MotionCFrame = CFrame.new(),
			TurnCFrame = CFrame.new(),
			RestingAngle = 0,
			CurrentRoll = 0,
			CurrentPitch = 0,
		},
		Settings = {},
		Connections = {},
		Components = {
			StateWrapper = aircraft.System,
			StateUpdateEvent = aircraft.System.Update,
			MainPart = mainPart,
			Motion = mainPart.Motion,
			Aerodynamics = mainPart.Aerodynamics,
			Gravity = mainPart.Gravity,
			BoundSize = nil,
		},
		IgnoredObjects = {aircraft},
		RayFilter = nil,
		Step = 0,
	}

	local state = self.States[aircraft]

	local Settings = aircraft:FindFirstChild("Settings")

	-- Initialize settings.
	for attrName, attrValue in pairs(Settings:GetAttributes()) do
		Utils.UpdateSetting(attrName, attrValue, state.Settings)
	end	

	-- Update legacy value objects on the client side.
	if Utils.IsClient() then
		Utils.SyncLegacyValues(Settings, state.Connections)
	end

	-- Update settings on attribute changed.
	table.insert(state.Connections, Settings.AttributeChanged:Connect(function(attrName)
		local attrValue = Settings:GetAttribute(attrName)
		if attrValue == nil then return end
		Utils.UpdateSetting(attrName, attrValue, state.Settings)
	end))

	state.RayFilter = RaycastParams.new()
	state.RayFilter.FilterType = Enum.RaycastFilterType.Exclude

	local _, boundSize = aircraft:GetBoundingBox()
	state.Components.BoundSize = boundSize
end

function aeroKit:GetState(aircraft)
	return self.States[aircraft]
end

function aeroKit:Update(aircraft, dt, onClient)	
	local state = self.States[aircraft]

	if not state then return end

	state.Step += dt

	local System = state.System
	local Settings = state.Settings
	local Components = state.Components

	local stateWrapper = Components.StateWrapper
	local stateUpdateEvent = Components.StateUpdateEvent

	local mainPart = Components.MainPart
	local motion = Components.Motion
	local aerodynamics = Components.Aerodynamics
	local gravity = Components.Gravity
	local boundSize = Components.BoundSize

	-- Variables that need to be updated every frame.
	local physicsScale = Utils.Max(Settings.Modifications.PhysicsScale or Settings.Advanced.PhysicsScale, 0.001)
	local globalWind = workspace.GlobalWind
	local globalGravity = workspace.Gravity
	local mainCFrame = mainPart.CFrame
	local trueSpeed = Utils.Abs(System.Speed + mainCFrame:VectorToObjectSpace(globalWind).Z)
	local position = mainPart.Position
	local altitude = position.Y

	local states = {
		Taxiing = stateWrapper:GetAttribute("Taxiing"),
		Flying = stateWrapper:GetAttribute("Flying"),
		Stalling = stateWrapper:GetAttribute("Stalling"),
		Hovering = stateWrapper:GetAttribute("Hovering")
	} -- Get the current states if the aircraft is anchored.

	-- Only run physics if the aircraft is unanchored.
	if not mainPart:IsGrounded() then
		--------------------------- Variables ---------------------------
		local system = aircraft.System
		
		local _aircraftStatistics = Settings.AircraftStatistics
		local _attitudeControls = Settings.AttitudeControls
		
		local _stability = _aircraftStatistics.Stability^2
		local _symmetricalAirfoil = _aircraftStatistics.SymmetricalAirfoil == true
		local _drag = _aircraftStatistics.Drag
		local _maxSpeed = _aircraftStatistics.MaxSpeed
		local _maxSpeedSL = _aircraftStatistics.MaxSpeedSL
		local _stallSpeed = _aircraftStatistics.StallSpeed
		local _changedbyAltitude = _aircraftStatistics.ChangedbyAltitude
		local _maxAltitude = _aircraftStatistics.MaxAltitude
		local _turningRate = _attitudeControls.TurningRate
		local _lowestPoint = Settings.Advanced.LowestPoint or "Auto"
		------------------------------------------------------------------
		local mainDirection = mainPart.CFrame
		local worldVelocity = mainPart.AssemblyLinearVelocity/physicsScale

		local bankAngle = -Utils.Deg(Utils.GetRoll(mainPart.CFrame)) + 360
		local notUpsideDown = bankAngle >= -90 and bankAngle <= 90
		local invertedBankAngle = Utils.Deg(Utils.GetRoll(mainPart.CFrame * Utils.CFAngles(0, 0, Utils.Rad(180)))) - 360
		local pitchRad, yawAngle, _ = mainCFrame:ToEulerAnglesYXZ()
		local pitchAngle = Utils.Deg(pitchRad)
		local velocity = mainPart.CFrame:VectorToObjectSpace(mainPart.AssemblyLinearVelocity)/physicsScale
		local trueSpeed = Utils.Abs(-velocity.Z + mainPart.CFrame:VectorToObjectSpace(workspace.GlobalWind).Z)
		local altitude = mainPart.Position.Y/physicsScale
		------------------------------------------------------------------
		local mass = system:GetAttribute("Mass")
		local weight = mass * 196.2 * Utils.Min(workspace.Gravity/35, 1)
		------------------------------------------------------------------
		local yawInput = System.Yaw
		local yawDriftAngle = yawInput * _attitudeControls.YawSpeed/200 * (1 - trueSpeed/_maxSpeed/2.5)
		local sideWindMagnitude = trueSpeed * yawDriftAngle
		local driftDirection = mainPart.CFrame.RightVector * sideWindMagnitude * Utils.Min(Utils.Max(trueSpeed - _stallSpeed, 0)/_stallSpeed/(10 * physicsScale), 1)
		local globalWind = workspace.GlobalWind
		local localWindDirection = if (globalWind + driftDirection).Magnitude > 0 then mainPart.CFrame:VectorToObjectSpace(globalWind + driftDirection).Unit else Utils.V3Zero

		local stallSpeedChangedbyAltitude = if _changedbyAltitude then (_maxSpeed - _stallSpeed) * Utils.Clamp((altitude/_maxAltitude) + Utils.Clamp((altitude - _maxAltitude)/10, 0, 10), 0, 10) else 0
		local stallSpeed = _stallSpeed + ((if _symmetricalAirfoil then Utils.Abs(if notUpsideDown then bankAngle else invertedBankAngle)/180 else Utils.Abs(bankAngle/180)) * (_stallSpeed/2.5)) + stallSpeedChangedbyAltitude + (_maxSpeed * math.max(altitude - _maxAltitude, 0)/100)
		local maxSpeed = _maxSpeedSL + (_maxSpeed - _maxSpeedSL) * (altitude/_maxAltitude + Utils.Max(-pitchAngle, 0)/180)

		local forwardDrag = trueSpeed/maxSpeed/(3000 + (1000 * velocity.Magnitude/maxSpeed)) * Utils.Max(1 - altitude/_maxAltitude, 0.25) * _drag
		local maxSpeedDrag = Utils.Max((velocity.Magnitude - maxSpeed)/(5000 + 5000 * (1 - _stability)), 0) or 1 - Utils.Abs(bankAngle/270)

		local liftLoss = if _symmetricalAirfoil then 1 - Utils.Abs(if notUpsideDown then bankAngle else invertedBankAngle)/270 else 1 - Utils.Abs(bankAngle)/270
		local lift_Force = Utils.Clamp((trueSpeed - stallSpeed)/(60 + 40 * (1 - _stability)), 0, Utils.Max(_stability, 0.001))/10 * liftLoss
		local stall_Force = trueSpeed/stallSpeed * velocity.Magnitude/stallSpeed/400

		local aeroX = mainDirection.RightVector * weight * (lift_Force + maxSpeedDrag + stall_Force) * -velocity.X * (1 - Utils.Abs(localWindDirection.X)/(1.5 - _stability/2.5))
		local aeroY = mainDirection.UpVector * weight * (lift_Force + maxSpeedDrag + stall_Force) * -velocity.Y * (1 - Utils.Abs(localWindDirection.Y)/(1.5 - _stability/2.5))
		local aeroZ = mainDirection.LookVector * weight * (forwardDrag + maxSpeedDrag) * velocity.Z

		local motionStability = system:GetAttribute("Stability") * System.Throttle
		local VTOLlevel = system:GetAttribute("VTOL")
		local VTOL = if VTOLlevel then VTOLlevel * System.Throttle * (if trueSpeed < stallSpeed then 1 else 0) else 0 -- Secret feature
		local aeroHover = Utils.V3New(0, weight * -velocity.Y/(200 * (1 + Utils.Abs(worldVelocity.Y)/20)) * (VTOL or 0), 0)

		-- Crosswind
		local windFactor = 1 - Utils.Abs(worldVelocity.Unit:Dot(globalWind.Unit))
		windFactor = if windFactor ~= windFactor then 0 else windFactor
		local windForce = globalWind * windFactor
		local windForwardComponent = mainDirection.LookVector * windForce:Dot(mainDirection.LookVector)
		local windLimit = Utils.Min(trueSpeed / 10, 1)
		local crosswindForce = (windForce - windForwardComponent + driftDirection) * windLimit
		local crosswind = mass * 1.5 * crosswindForce * Utils.Clamp((trueSpeed - stallSpeed*0.9)/(stallSpeed*0.1), 0, 1)

		------------------------------------------------------------------
		local stalling = 0
		
		local lowestPoint = 0
		local hasCollision = false

		if _lowestPoint == "Auto" then
			-- Automatic lowest point calculation based on aircraft's size
			local halfY, halfZ = boundSize.Y/2, boundSize.Z/2
			local projectedExtent = halfY * math.cos(pitchRad) + halfZ * Utils.Abs(math.sin(pitchRad))
			lowestPoint = projectedExtent + physicsScale
		else
			-- Manual lowest point overwrite
			lowestPoint = Utils.Abs(_lowestPoint)
		end
		
		state.RayFilter.FilterDescendantsInstances = state.IgnoredObjects
		local onGround = workspace:Raycast(position, Utils.V3New(0, -lowestPoint, 0), state.RayFilter)
		if onGround then
			local instance = onGround.Instance
			local model = instance.Parent -- Check for possible ancestor model
			if model:IsA("Model") then -- Model
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid == nil then
					hasCollision = Utils.CheckPartCollision(instance, state.IgnoredObjects)
				else -- Exclude player/NPC character if humanoid is detected
					table.insert(state.IgnoredObjects, model)
				end
			else -- Part
				hasCollision = Utils.CheckPartCollision(instance, state.IgnoredObjects)
			end
		else
			-- Reset filter
			if #state.IgnoredObjects > 1 then
				table.clear(state.IgnoredObjects)
				table.insert(state.IgnoredObjects, aircraft)
			end
			
			if trueSpeed < stallSpeed then
				stalling = 1
			else
				stalling = 0
			end
		end

		if hasCollision then
			stalling = 0
		end
		------------------------------------------------------------------

		local dive = Utils.Max((1 - Utils.Abs(if notUpsideDown then bankAngle else invertedBankAngle)/180) * (1 - Utils.Max(Utils.Abs(pitchAngle) - 60, 0)/28), 0) -- Reduce shakiness when nose diving
		local turnScale = Utils.Max(Utils.Min(worldVelocity.Magnitude/100, 1) - (worldVelocity.Magnitude/600), 0.1)
		local turn = (if notUpsideDown then bankAngle else invertedBankAngle)/360 * turnScale * dive * _turningRate

		local rollInput = System.Roll
		local pitchInput = System.Pitch
		
		local VTOL_Hovering = system:GetAttribute("Hovering") == true
		
		if _attitudeControls.LimitAngle or VTOL_Hovering then
			local maxB = if VTOL_Hovering then 60 else _attitudeControls.MaxBank
			local maxP = if VTOL_Hovering then 60 else _attitudeControls.MaxPitch

			local exceedingBank = if (rollInput * bankAngle) > 0 then Utils.Abs(rollInput) else 0
			local exceedingPitch = if (pitchInput * pitchAngle) > 0 then Utils.Abs(pitchInput) else 0

			local bankLimit = Utils.Clamp(bankAngle / maxB, -1, 1) * exceedingBank
			local pitchLimit = Utils.Clamp(pitchAngle / maxP, -1, 1) * exceedingPitch

			local bankLevelOut = 0
			local pitchLevelOut = 0

			if VTOL_Hovering then
				bankLevelOut = Utils.Sign(bankAngle) * 0.3 * Utils.Min(Utils.Abs(bankAngle) / 5, 1) * (1 - Utils.Abs(rollInput))
				pitchLevelOut = Utils.Sign(pitchAngle) * 0.3 * Utils.Min(Utils.Abs(pitchAngle) / 5, 1) * (1 - Utils.Abs(pitchInput))
			end

			rollInput = rollInput - bankLimit - bankLevelOut
			pitchInput = pitchInput - pitchLimit - pitchLevelOut
		end
		
		local roll = rollInput * _attitudeControls.RollSpeed/10 * (0.8 + trueSpeed/maxSpeed/2.5)
		local pitch = pitchInput * _attitudeControls.PitchSpeed/10 * (1 - trueSpeed/maxSpeed/2.5)
		local yaw = yawInput * _attitudeControls.YawSpeed/10 * (1 - trueSpeed/maxSpeed/2.5)

		local cancelWindDirection = globalWind - (worldVelocity.Unit * globalWind:Dot(worldVelocity.Unit))
		cancelWindDirection = if cancelWindDirection ~= cancelWindDirection then Utils.V3Zero else cancelWindDirection

		local mainVelocity = worldVelocity - (cancelWindDirection * Utils.Clamp((trueSpeed - stallSpeed*0.9)/(stallSpeed*0.1), 0, 1))
		local mainXZ = Utils.V3New(mainDirection.LookVector.X, 0, mainDirection.LookVector.Z).Unit
		local velocityXZ = Utils.V3New(mainVelocity.X, 0, mainVelocity.Z).Unit
		mainXZ = if mainXZ ~= mainXZ then Utils.V3Zero else mainXZ
		velocityXZ = if velocityXZ ~= velocityXZ then Utils.V3Zero else velocityXZ

		local forwardComponent = mainVelocity:Dot(mainDirection.LookVector)
		local rad = Utils.Rad(bankAngle)
		local right = mainDirection.RightVector
		local up = mainDirection.UpVector
		local smoothUp = up * math.cos(rad) + right * math.sin(rad)
		local upComponent = mainVelocity:Dot(smoothUp.Unit)
		local velocityDirection = math.acos(Utils.V3New(0, 0, -1):Dot(velocityXZ)) * (if Utils.V3New(0, 0, -1):Cross(velocityXZ).Y >= 0 then 1 else -1)

		-- Follow the flight path
		local pathYaw = math.acos(Utils.Clamp(mainXZ:Dot(velocityXZ), -2, 2)) * (if mainXZ:Cross(velocityXZ).Y >= 0 then 1 else -1)/(10 - 5*stalling) * (1 + 0.25*stalling)
		local pathPitch = Utils.Clamp(math.atan2(upComponent, forwardComponent), -2, 2) * 1.25 * Utils.Clamp(1 - (worldVelocity.Magnitude - stallSpeed)/maxSpeed, 0.1, 1)

		pathYaw = if pathYaw ~= pathYaw then 0 else pathYaw
		pathPitch = if pathPitch ~= pathPitch then 0 else pathPitch
		local flightPath = (Utils.V3New(0, pathYaw, 0) + Utils.CFAngles(0, velocityDirection, 0):VectorToWorldSpace(Utils.V3New(pathPitch, 0, 0)) * Utils.Min(if worldVelocity.Magnitude >= 1 then worldVelocity.Magnitude/stallSpeed + stalling else 0, 1)) * Utils.Max(1 - motionStability*4, 0)

		motion.MaxTorque = weight * Utils.Clamp(Utils.Max((trueSpeed - stallSpeed*0.3)/(stallSpeed*0.7), 0) + stalling + motionStability, 0, 1) * 2 * _attitudeControls.TorqueResponsiveness
		local motionControl = mainDirection:VectorToWorldSpace(Utils.V3New(pitch, yaw + turn, roll + yaw/4) * Utils.Clamp(Utils.Max(trueSpeed - stallSpeed*(0.3 + 0.3*stalling), 0)/(stallSpeed*(0.7 - 0.3*stalling)) + motionStability, 0.15, 1))
		motion.AngularVelocity = motionControl + flightPath
		-----------------------------------------------------------------

		gravity.Force = Utils.V3New(0, mass * Utils.Max(workspace.Gravity - 35, 0), 0)
		local aeroForce = aeroX + aeroY + aeroZ + aeroHover + crosswind
		aerodynamics.Force = Utils.V3New(Utils.Clamp(aeroForce.X, -weight, weight), Utils.Clamp(aeroForce.Y, -weight, weight), Utils.Clamp(aeroForce.Z, -weight, weight))
		
		-- State update
		local flying = trueSpeed >= stallSpeed
		local hovering = VTOLlevel > 0 and worldVelocity.Magnitude >= stallSpeed * (1 - VTOLlevel) - VTOLlevel and not flying
		
		states.Taxiing = not flying and stalling == 0 and not hovering
		states.Flying = flying and stalling == 0
		states.Stalling = stalling == 1
		states.Hovering = hovering
	end
	
	--- Classic CM32 booleans ---
	if state.Step >= 0.5 then
		stateWrapper:SetAttribute("Taxiing", states.Taxiing)
		stateWrapper:SetAttribute("Flying", states.Flying)
		stateWrapper:SetAttribute("Stalling", states.Stalling)
		stateWrapper:SetAttribute("Hovering", states.Hovering)

		if onClient then
			local attributes = stateWrapper:GetAttributes()
			local packet = {}
			packet.Taxiing = attributes.Taxiing
			packet.Flying = attributes.Flying
			packet.Stalling = attributes.Stalling
			packet.Hovering = attributes.Hovering

			stateUpdateEvent:FireServer("States", packet)
		end

		state.Step -= 0.5
	end
end

function aeroKit:Cleanup(aircraft)
	local state = self.States[aircraft]

	for i, connection in pairs(state.Connections) do
		connection:Disconnect()
	end
	state.Connections = nil

	self.States[aircraft] = nil
end

return aeroKit