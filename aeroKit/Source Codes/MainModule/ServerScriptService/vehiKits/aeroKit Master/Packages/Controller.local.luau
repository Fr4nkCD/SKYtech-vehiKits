-- Client Control --

local kitName = "aeroKit" -- Change here
local core = require(game:GetService("ReplicatedStorage"):WaitForChild("SKYtech Systems"):WaitForChild("Modules"):WaitForChild(kitName))

local StarterGui	= game:GetService("StarterGui")
local StarterPlayer	= game:GetService("StarterPlayer")
local player		= game:GetService("Players").LocalPlayer

local humanoid	= player.Character:WaitForChild("Humanoid")
local rootPart	= player.Character:WaitForChild("HumanoidRootPart")
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

	local timer = 1
	repeat
		timer -= RS.Heartbeat:Wait()
		Control = script.Module.Value
	until script.Module.Value ~= nil or timer <= 0

	if script.Module.Value == nil then return end

	Sensitivity.Throttle = Control:GetAttribute("Throttle")
	Sensitivity.Roll = Control:GetAttribute("Roll")
	Sensitivity.Pitch = Control:GetAttribute("Pitch")
	Sensitivity.Yaw = Control:GetAttribute("Yaw")
	
	-- Backward compatibility (old version used a normalized scale (0-1) while the new version uses a larger number)
	Sensitivity.Throttle = if Sensitivity.Throttle < 1 then (1 - Sensitivity.Throttle) * 5 else Sensitivity.Throttle
	Sensitivity.Roll = if Sensitivity.Roll < 1 then (1 - Sensitivity.Roll) * 5 else Sensitivity.Roll
	Sensitivity.Pitch = if Sensitivity.Pitch < 1 then (1 - Sensitivity.Pitch) * 5 else Sensitivity.Pitch
	Sensitivity.Yaw = if Sensitivity.Yaw < 1 then (1 - Sensitivity.Yaw) * 5 else Sensitivity.Yaw

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



local function getEffectiveInput(input, deadzone)
	return math.max(0, math.abs(input) - deadzone) / (1 - deadzone)
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

	Controls.Inputs.Throttle = script:GetAttribute("Throttle")
	Controls.Inputs.Roll = script:GetAttribute("Roll")
	Controls.Inputs.Pitch = script:GetAttribute("Pitch")
	Controls.Inputs.Trim = script:GetAttribute("Trim")
	Controls.Inputs.Yaw = script:GetAttribute("Yaw")
	-----------------------------------------------------------------------------------------------
	local throttle_Input	= Controls.Inputs.Throttle
	local roll_Input		= Controls.Inputs.Roll
	local pitch_Input 		= Controls.Inputs.Pitch
	local trim_Input 		= Controls.Inputs.Trim
	local yaw_Input 		= Controls.Inputs.Yaw
	------------------------------------------------------------------------------------------------
	local deadzone = if isMobile then 0.1 else 0.005
	local roll_Curve		= 0.8 + (getEffectiveInput(roll_Input, deadzone) * 0.2)
	local pitch_Curve		= 0.8 + (getEffectiveInput(pitch_Input, deadzone) * 0.2)
	local yaw_Curve			= 0.8 + (getEffectiveInput(yaw_Input, deadzone) * 0.2)
	------------------------------------------------------------------------------------------------
	Controls.Outputs.Throttle 		= math.lerp(Controls.Outputs.Throttle, throttle_Input, throttle_Sensitivity)
	Controls.Outputs.Roll 			= math.lerp(Controls.Outputs.Roll, roll_Input * roll_Curve, roll_Sensitivity)
	Controls.Outputs.Pitch 			= math.lerp(Controls.Outputs.Pitch, pitch_Input * pitch_Curve, pitch_Sensitivity)
	Controls.Outputs.Trim 			= math.lerp(Controls.Outputs.Trim, trim_Input, trim_Sensitivity)
	Controls.Outputs.Yaw 			= math.lerp(Controls.Outputs.Yaw, yaw_Input * yaw_Curve, yaw_Sensitivity)
	------------------------------------------------------------------------------------------------
	handlerFrames.Inputs.Throttle.Size	= UDim2.new(0, 20, throttle_Input, 0)
	handlerFrames.Inputs.Roll.Size			= UDim2.new(0, 20, roll_Input, 0)
	handlerFrames.Inputs.Pitch.Size			= UDim2.new(0, 20, pitch_Input, 0)
	handlerFrames.Inputs.Trim.Size			= UDim2.new(0, 20, trim_Input, 0)
	handlerFrames.Inputs.Yaw.Size			= UDim2.new(0, 20, yaw_Input, 0)
	-----------------------------------------------------------------------------------------------
	handlerFrames.Outputs.Throttle.Size	= UDim2.new(0, 20, Controls.Outputs.Throttle, 0)
	handlerFrames.Outputs.Roll.Size			= UDim2.new(0, 20, Controls.Outputs.Roll, 0)
	handlerFrames.Outputs.Pitch.Size		= UDim2.new(0, 20, Controls.Outputs.Pitch, 0)
	handlerFrames.Outputs.Trim.Size			= UDim2.new(0, 20, Controls.Outputs.Trim, 0)
	handlerFrames.Outputs.Yaw.Size			= UDim2.new(0, 20, Controls.Outputs.Yaw, 0)
	-----------------------------------------------------------------------------------------------
	local states = aircraftState.System
	states.Throttle			= Controls.Outputs.Throttle
	states.Roll				= Controls.Outputs.Roll
	states.Pitch			= Controls.Outputs.Pitch + Controls.Outputs.Trim
	states.Yaw				= Controls.Outputs.Yaw

	-- Update the stats slowly if the control is client sided, 10 Hz otherwise.
	local rate = if isClientControlled then 0.5 else 1/10
	if accumulated >= rate then
		local packet = {}
		packet.Throttle = Controls.Outputs.Throttle
		packet.Roll = Controls.Outputs.Roll
		packet.Pitch = Controls.Outputs.Pitch
		packet.Trim = Controls.Outputs.Trim
		packet.Yaw = Controls.Outputs.Yaw
		updateEvent:FireServer("Stats", packet)
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