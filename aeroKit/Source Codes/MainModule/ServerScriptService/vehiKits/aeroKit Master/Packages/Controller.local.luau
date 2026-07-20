-- Client Control --

local kitName = "aeroKit" -- Change here
local core = require(game:GetService("ReplicatedStorage"):WaitForChild("SKYtech Systems"):WaitForChild("Modules"):WaitForChild(kitName))

local StarterGui	= game:GetService("StarterGui")
local StarterPlayer	= game:GetService("StarterPlayer")
local player		= game:GetService("Players").LocalPlayer

local character = player.Character or player.CharacterAdded:Wait()
local humanoid	= character:WaitForChild("Humanoid")
local rootPart	= character:WaitForChild("HumanoidRootPart")
local camera	= workspace.CurrentCamera

local defaultMaxZoomDistance = StarterPlayer.CameraMaxZoomDistance
local defaultMinZoomDistance = StarterPlayer.CameraMinZoomDistance
local defaultBackpackEnabled = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)

camera.CameraSubject = rootPart
camera.CameraSubject = humanoid
player.CameraMaxZoomDistance = 500

------------------------------------

local gui = script.Parent
local aircraft = gui.Aircraft.Value
local main = aircraft.Main
local mainPart = main.Main

local Settings = aircraft.Settings
local Stats_ = main.Stats
local Mods = main.Mods

local landingGear = Mods:FindFirstChild("LandingGear")
local gearRemote = if landingGear then landingGear:FindFirstChild("Remote") else nil

core:Initialize(aircraft)
local aircraftState = core:GetState(aircraft)

local stateWrapper = aircraft.System
local updateEvent = stateWrapper.Update

local control_Handler = gui.Control_Handler
local handlerFrames = {
	Inputs = {
		Throttle = control_Handler.Input.Throttle,
		Pitch = control_Handler.Input.Pitch,
		Trim = control_Handler.Input.Trim,
		Roll = control_Handler.Input.Roll,
		Yaw = control_Handler.Input.Yaw,
	},

	Outputs = {
		Throttle = control_Handler.Output.Throttle,
		Pitch = control_Handler.Output.Pitch,
		Roll = control_Handler.Output.Roll,
		Trim = control_Handler.Output.Trim,
		Yaw = control_Handler.Output.Yaw,
	},
}

local Control = nil
local Sensitivity = {
	Throttle = 0,
	Roll = 0,
	Pitch = 0,
	Yaw = 0,
}

local Controls = {
	Inputs = {
		Throttle = Stats_:GetAttribute("Throttle") or 0,
		Roll = 0,
		Pitch = 0,
		Trim = 0,
		Yaw = 0,
	},

	Outputs = {
		Throttle = Stats_:GetAttribute("Throttle") or 0,
		Roll = 0,
		Pitch = 0,
		Trim = 0,
		Yaw = 0,
	},
}

script:SetAttribute("Roll", 0)
script:SetAttribute("Pitch", 0)
script:SetAttribute("Yaw", 0)
script:SetAttribute("Throttle", Controls.Inputs.Throttle)

handlerFrames.Inputs.Throttle.Size = UDim2.new(0, 20, Controls.Inputs.Throttle, 0)
handlerFrames.Outputs.Throttle.Size = UDim2.new(0, 20, Controls.Outputs.Throttle, 0)

------------------------------------------------------------------------------------

local isClientControlled = stateWrapper:GetAttribute("Client_Controlled") == true

local UIS = game:GetService("UserInputService")
local isMobile = UIS:GetLastInputType() == Enum.UserInputType.Touch

if UIS:GetLastInputType() == Enum.UserInputType.Gamepad1 then
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	humanoid:UnequipTools()
end

------------------------------------------------------------------------------------

local physicsScale = math.max(Settings:GetAttribute("Advanced/PhysicsScale"), 0.001)

local RS = game:GetService("RunService")
local controllerEvent = script.Event

function changeControl()
	controllerEvent:Fire("Stop")
	controllerEvent:Fire("ChangeControl")

	local controlVal = script.Module.Value
	if not controlVal then
		local thread = coroutine.running()
		local delayTask = task.delay(1, task.spawn, thread)
		local conn = script.Module:GetPropertyChangedSignal("Value"):Connect(function()
			task.cancel(delayTask)
			task.spawn(thread)
		end)
		coroutine.yield()
		conn:Disconnect()
		controlVal = script.Module.Value
	end

	if not controlVal then return end
	Control = controlVal

	local isNewSens = Control:GetAttribute("NewSensitivity") == true
	local throttleRaw = Control:GetAttribute("Throttle") or 1
	local rollRaw = Control:GetAttribute("Roll") or 1
	local pitchRaw = Control:GetAttribute("Pitch") or 1
	local yawRaw = Control:GetAttribute("Yaw") or 1

	if isNewSens then
		Sensitivity.Throttle = throttleRaw
		Sensitivity.Roll = rollRaw
		Sensitivity.Pitch = pitchRaw
		Sensitivity.Yaw = yawRaw
	else
		-- Convert legacy duration (seconds) to responsiveness multiplier
		Sensitivity.Throttle = 4.6 / math.max(throttleRaw, 0.01)
		Sensitivity.Roll = 4.6 / math.max(rollRaw, 0.01)
		Sensitivity.Pitch = 4.6 / math.max(pitchRaw, 0.01)
		Sensitivity.Yaw = 4.6 / math.max(yawRaw, 0.01)
	end

	controllerEvent:Fire("Start")
end

local changeControl_function = nil
script:GetAttributeChangedSignal("ControlMode"):Connect(function()
	if changeControl_function then
		task.cancel(changeControl_function)
		changeControl_function = nil
	end
	changeControl_function = task.spawn(changeControl)
end)

controllerEvent.Event:Connect(function(event)
	if event == "Hover" then
		if Settings:GetAttribute("AttitudeControls/Hover") == false or mainPart.AssemblyLinearVelocity.Magnitude/physicsScale > 100 then return end
		Controls.Inputs.Hover = not Controls.Inputs.Hover
		script:SetAttribute("Hover", Controls.Inputs.Hover)
	end
end)

-- For copilot system
if script:GetAttribute("ControlMode") == nil or script:GetAttribute("ControlMode") == 0 then
	-- Set default if no control mode selected
	script:SetAttribute("ControlMode", 1)
else
	-- Reactivate the control
	local currentMode = script:GetAttribute("ControlMode")
	script:SetAttribute("ControlMode", -1)
	script:SetAttribute("ControlMode", currentMode)
end

------------------------------------------------------------------------------------



local function getEffectiveInput(input: number, deadzone: number): number
	if math.abs(input) <= deadzone then
		return 0
	end
	return math.sign(input) * (math.abs(input) - deadzone) / (1 - deadzone)
end

local accumulated = 0
local connection
connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
	accumulated += dt
	
	local throttle_Sensitivity = 1 - math.exp(-Sensitivity.Throttle * dt)
	local roll_Sensitivity = 1 - math.exp(-Sensitivity.Roll * dt)
	local pitch_Sensitivity = 1 - math.exp(-Sensitivity.Pitch * dt)
	local trim_Sensitivity = 1 - math.exp(-script:GetAttribute("TrimSensitivity") * dt)
	local yaw_Sensitivity = 1 - math.exp(-Sensitivity.Yaw * dt)

	local throttle_Input = script:GetAttribute("Throttle") or 0
	local roll_Input = script:GetAttribute("Roll") or 0
	local pitch_Input = script:GetAttribute("Pitch") or 0
	local trim_Input = script:GetAttribute("Trim") or 0
	local yaw_Input = script:GetAttribute("Yaw") or 0

	local deadzone = if isMobile then 0.1 else 0.005
	local effectiveRoll = getEffectiveInput(roll_Input, deadzone)
	local effectivePitch = getEffectiveInput(pitch_Input, deadzone)
	local effectiveYaw = getEffectiveInput(yaw_Input, deadzone)

	local roll_Curve = 0.8 + (math.abs(effectiveRoll) * 0.2)
	local pitch_Curve = 0.8 + (math.abs(effectivePitch) * 0.2)
	local yaw_Curve = 0.8 + (math.abs(effectiveYaw) * 0.2)

	Controls.Outputs.Throttle = math.lerp(Controls.Outputs.Throttle, throttle_Input, throttle_Sensitivity)
	Controls.Outputs.Roll = math.lerp(Controls.Outputs.Roll, effectiveRoll * roll_Curve, roll_Sensitivity)
	Controls.Outputs.Pitch = math.lerp(Controls.Outputs.Pitch, effectivePitch * pitch_Curve, pitch_Sensitivity)
	Controls.Outputs.Trim = math.lerp(Controls.Outputs.Trim, trim_Input, trim_Sensitivity)
	Controls.Outputs.Yaw = math.lerp(Controls.Outputs.Yaw, effectiveYaw * yaw_Curve, yaw_Sensitivity)

	handlerFrames.Inputs.Throttle.Size = UDim2.new(0, 20, throttle_Input, 0)
	handlerFrames.Inputs.Roll.Size = UDim2.new(0, 20, roll_Input, 0)
	handlerFrames.Inputs.Pitch.Size = UDim2.new(0, 20, pitch_Input, 0)
	handlerFrames.Inputs.Trim.Size = UDim2.new(0, 20, trim_Input, 0)
	handlerFrames.Inputs.Yaw.Size = UDim2.new(0, 20, yaw_Input, 0)

	handlerFrames.Outputs.Throttle.Size = UDim2.new(0, 20, Controls.Outputs.Throttle, 0)
	handlerFrames.Outputs.Roll.Size = UDim2.new(0, 20, Controls.Outputs.Roll, 0)
	handlerFrames.Outputs.Pitch.Size = UDim2.new(0, 20, Controls.Outputs.Pitch, 0)
	handlerFrames.Outputs.Trim.Size = UDim2.new(0, 20, Controls.Outputs.Trim, 0)
	handlerFrames.Outputs.Yaw.Size = UDim2.new(0, 20, Controls.Outputs.Yaw, 0)

	local states = aircraftState.System
	states.Throttle = Controls.Outputs.Throttle
	states.Roll = Controls.Outputs.Roll
	states.Pitch = Controls.Outputs.Pitch + Controls.Outputs.Trim
	states.Yaw = Controls.Outputs.Yaw

	local rate = if isClientControlled then 0.5 else 0.1
	if accumulated >= rate then
		updateEvent:FireServer("Stats", {
			Throttle = Controls.Outputs.Throttle,
			Roll = Controls.Outputs.Roll,
			Pitch = Controls.Outputs.Pitch,
			Trim = Controls.Outputs.Trim,
			Yaw = Controls.Outputs.Yaw,
		})
		accumulated -= rate
	end
end)

function disconnect()
	connection:Disconnect()
	core:Cleanup(aircraft)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, defaultBackpackEnabled)
	UIS.MouseIcon = "" -- Return to Roblox default cursor
	camera.CameraType = Enum.CameraType.Custom
	player.CameraMaxZoomDistance = defaultMaxZoomDistance
	player.CameraMinZoomDistance = defaultMinZoomDistance
	gui.Enabled = false
end

humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
	if not humanoid.SeatPart then
		disconnect()
	end
end)

stateWrapper:GetAttributeChangedSignal("Client_Controlled"):Connect(function()
	isClientControlled = stateWrapper:GetAttribute("Client_Controlled") == true
end)