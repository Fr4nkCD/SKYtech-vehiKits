-- Client Control --

local kitName = "rotorKit" -- Change here
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
		Collective = control_Handler.Input.Collective,
		Pitch = control_Handler.Input.Pitch,
		Roll = control_Handler.Input.Roll,
		Yaw = control_Handler.Input.Yaw,
	},

	Outputs = {
		Collective = control_Handler.Output.Collective,
		Pitch = control_Handler.Output.Pitch,
		Roll = control_Handler.Output.Roll,
		Yaw = control_Handler.Output.Yaw,
	},
}

local Control = nil
local Sensitivity = {
	Collective = 0,
	Roll = 0,
	Pitch = 0,
	Yaw = 0,
}

local Controls = {
	Inputs = {
		Collective = Stats_:GetAttribute("Collective") or 0,
		Roll = 0,
		Pitch = 0,
		Yaw = 0,
		Hover = Stats_:GetAttribute("Hover") or false
	},

	Outputs = {
		Collective = Stats_:GetAttribute("Collective") or 0,
		Roll = 0,
		Pitch = 0,
		Yaw = 0,
	},
}

script:SetAttribute("Roll", 0)
script:SetAttribute("Pitch", 0)
script:SetAttribute("Yaw", 0)
script:SetAttribute("Collective", Controls.Inputs.Collective)
script:SetAttribute("Hover", Controls.Inputs.Hover)

handlerFrames.Inputs.Collective.Size = UDim2.new(0, 20, Controls.Inputs.Collective, 0)
handlerFrames.Outputs.Collective.Size = UDim2.new(0, 20, Controls.Outputs.Collective, 0)

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

	Sensitivity.Collective = Control:GetAttribute("Collective")
	Sensitivity.Roll = Control:GetAttribute("Roll")
	Sensitivity.Pitch = Control:GetAttribute("Pitch")
	Sensitivity.Yaw = Control:GetAttribute("Yaw")
	
	-- Backward compatibility (old version used a normalized scale (0-1) while the new version uses a larger number)
	Sensitivity.Collective = if Sensitivity.Collective < 1 then (1 - Sensitivity.Collective) * 5 else Sensitivity.Collective
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
	
	local hoverFactor = if Controls.Inputs.Hover == true then 0.75 else 1
	local collective_Sensitivity = 1 - math.exp(-Sensitivity.Collective * hoverFactor * dt)
	local roll_Sensitivity = 1 - math.exp(-Sensitivity.Roll * hoverFactor * dt)
	local pitch_Sensitivity = 1 - math.exp(-Sensitivity.Pitch * hoverFactor * dt)
	local yaw_Sensitivity = 1 - math.exp(-Sensitivity.Yaw * hoverFactor * dt)

	Controls.Inputs.Collective = script:GetAttribute("Collective")
	Controls.Inputs.Roll = script:GetAttribute("Roll")
	Controls.Inputs.Pitch = script:GetAttribute("Pitch")
	Controls.Inputs.Yaw = script:GetAttribute("Yaw")
	-----------------------------------------------------------------------------------------------
	local collective_Input	= Controls.Inputs.Collective
	local roll_Input		= Controls.Inputs.Roll
	local pitch_Input 		= Controls.Inputs.Pitch
	local yaw_Input 		= Controls.Inputs.Yaw
	local hover_Input		= Controls.Inputs.Hover
	------------------------------------------------------------------------------------------------
	local deadzone = if isMobile then 0.1 else 0.005
	local effectiveRoll = getEffectiveInput(roll_Input, deadzone)
	local effectivePitch = getEffectiveInput(pitch_Input, deadzone)
	local effectiveYaw = getEffectiveInput(yaw_Input, deadzone)

	local roll_Curve		= 0.8 + (math.abs(effectiveRoll) * 0.2)
	local pitch_Curve		= 0.8 + (math.abs(effectivePitch) * 0.2)
	local yaw_Curve			= 0.8 + (math.abs(effectiveYaw) * 0.2)
	------------------------------------------------------------------------------------------------
	Controls.Outputs.Collective 	= math.lerp(Controls.Outputs.Collective, collective_Input, collective_Sensitivity)
	Controls.Outputs.Roll 			= math.lerp(Controls.Outputs.Roll, effectiveRoll * roll_Curve, roll_Sensitivity)
	Controls.Outputs.Pitch 			= math.lerp(Controls.Outputs.Pitch, effectivePitch * pitch_Curve, pitch_Sensitivity)
	Controls.Outputs.Yaw 			= math.lerp(Controls.Outputs.Yaw, effectiveYaw * yaw_Curve, yaw_Sensitivity)
	------------------------------------------------------------------------------------------------
	handlerFrames.Inputs.Collective.Size	= UDim2.new(0, 20, collective_Input, 0)
	handlerFrames.Inputs.Roll.Size			= UDim2.new(0, 20, roll_Input, 0)
	handlerFrames.Inputs.Pitch.Size			= UDim2.new(0, 20, pitch_Input, 0)
	handlerFrames.Inputs.Yaw.Size			= UDim2.new(0, 20, yaw_Input, 0)
	-----------------------------------------------------------------------------------------------
	handlerFrames.Outputs.Collective.Size	= UDim2.new(0, 20, Controls.Outputs.Collective, 0)
	handlerFrames.Outputs.Roll.Size			= UDim2.new(0, 20, Controls.Outputs.Roll, 0)
	handlerFrames.Outputs.Pitch.Size		= UDim2.new(0, 20, Controls.Outputs.Pitch, 0)
	handlerFrames.Outputs.Yaw.Size			= UDim2.new(0, 20, Controls.Outputs.Yaw, 0)
	-----------------------------------------------------------------------------------------------
	local states = aircraftState.System
	states.Collective		= Controls.Outputs.Collective
	states.Roll				= Controls.Outputs.Roll
	states.Pitch			= Controls.Outputs.Pitch
	states.Yaw				= Controls.Outputs.Yaw
	states.Hovering			= Controls.Inputs.Hover
	
	-- Disable the hover mode if the speed exceeds 100
	if mainPart.AssemblyLinearVelocity.Magnitude/physicsScale > 100 and Controls.Inputs.Hover == true then
		Controls.Inputs.Hover = false
		script:SetAttribute("Hover", Controls.Inputs.Hover)
	end

	-- Update the stats slowly if the control is client sided, 10 Hz otherwise.
	local rate = if isClientControlled then 0.5 else 1/10
	if accumulated >= rate then
		local packet = {}
		packet.Collective = Controls.Outputs.Collective
		packet.Roll = Controls.Outputs.Roll
		packet.Pitch = Controls.Outputs.Pitch
		packet.Yaw = Controls.Outputs.Yaw
		packet.Hover = Controls.Inputs.Hover
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