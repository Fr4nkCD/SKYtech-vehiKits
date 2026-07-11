-- Client Control --

local kitName = "aeroMini" -- Change here
local kitCore = require(game:GetService("ReplicatedStorage"):WaitForChild("SKYtech Systems"):WaitForChild("Modules"):WaitForChild(kitName))

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

kitCore:Initialize(aircraft)
local aircraftState = kitCore:GetState(aircraft)

local stateWrapper = aircraft.System
local updateEvent = stateWrapper.Update

local control_Handler = gui.Control_Handler
local handlerFrames = {
	Linear = {
		Throttle = control_Handler.Linear_Inputs.Throttle,
		Pitch = control_Handler.Linear_Inputs.Pitch,
		Roll = control_Handler.Linear_Inputs.Roll,
		Yaw = control_Handler.Linear_Inputs.Yaw,
	};

	Nonlinear = {
		Throttle = control_Handler.Throttle,
		Pitch = control_Handler.Pitch,
		Roll = control_Handler.Roll,
		Yaw = control_Handler.Yaw,
	};
}

local onControl, isMobile, isGamepad = false, false, false
local throttleChange = 0

local Controls = {
	Inputs = {
		Throttle = Stats_:GetAttribute("Throttle") or 0,
		Roll = 0,
		Pitch = 0,
		Yaw = 0,
		MousePosition = nil
	};

	Outputs = {
		Throttle = Stats_:GetAttribute("Throttle") or 0,
		Roll = 0,
		Pitch = 0,
		Yaw = 0,
		MousePosition = nil
	};
}

script:SetAttribute("MousePosition", nil)
script:SetAttribute("Roll", 0)
script:SetAttribute("Pitch", 0)
script:SetAttribute("Yaw", 0)
script:SetAttribute("Throttle", Controls.Inputs.Throttle)

handlerFrames.Linear.Throttle.Size = UDim2.new(0, 20, Controls.Inputs.Throttle, 0)
handlerFrames.Nonlinear.Throttle.Size = UDim2.new(0, 20, Controls.Outputs.Throttle, 0)

------------------------------------------------------------------------------------

local Keybinds = {
	ToggleControl = Settings:GetAttribute("FlightControls/ToggleControl"),
	Engine = Settings:GetAttribute("FlightControls/Engine"),
	ThrottleUp = Settings:GetAttribute("FlightControls/ThrottleUp"),
	ThrottleDown = Settings:GetAttribute("FlightControls/ThrottleDown"),
	LandingGear = Settings:GetAttribute("FlightControls/LandingGear"),
}

local useCustomControl = script:GetAttribute("Custom_Control") == true
local isClientControlled = stateWrapper:GetAttribute("Client_Controlled") == true

local UserInputService = game:GetService("UserInputService")
UserInputService.MouseIcon = ""

if UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 then
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	humanoid:UnequipTools()
end

if Keybinds.ToggleControl == "nil" then
	-- Force control
	onControl = true
	control_Handler.Modal.Visible = true
	UserInputService.MouseIcon = Settings:GetAttribute("FlightControls/CursorIcon")
	camera.CameraType = Enum.CameraType[Settings:GetAttribute("FlightControls/CameraType")]
end

UserInputService.InputBegan:Connect(function(input, processed) -- Keys pressed
	if processed or isMobile or useCustomControl then return end

	local advancedMode = Settings:GetAttribute("AttitudeControls/Advanced") == true
	if Keybinds.ToggleControl ~= "nil" and input.KeyCode == Enum.KeyCode[Keybinds.ToggleControl] then
		if not onControl then
			onControl = true
			control_Handler.Modal.Visible = true
			UserInputService.MouseIcon = Settings:GetAttribute("FlightControls/CursorIcon")
			camera.CameraType = Enum.CameraType[Settings:GetAttribute("FlightControls/CameraType")]
		else
			onControl = false
			control_Handler.Modal.Visible = false
			UserInputService.MouseIcon = ""
			camera.CameraType = Enum.CameraType.Custom
		end


	elseif Keybinds.Engine ~= "nil" and input.KeyCode == Enum.KeyCode[Keybinds.Engine] then
		updateEvent:FireServer("Active")


	elseif input.KeyCode == Enum.KeyCode[Keybinds.ThrottleUp] then
		throttleChange = 1
	elseif input.KeyCode == Enum.KeyCode[Keybinds.ThrottleDown] then
		throttleChange = -1


	elseif input.KeyCode == Enum.KeyCode.A and advancedMode then
		Controls.Inputs.Yaw = 1
	elseif input.KeyCode == Enum.KeyCode.D and advancedMode then
		Controls.Inputs.Yaw = -1


	elseif Settings:GetAttribute("FlightControls/LandingGear") ~= "nil" and gearRemote and input.KeyCode == Enum.KeyCode[Settings:GetAttribute("FlightControls/LandingGear")] then
		gearRemote:FireServer()
	end
end)

UserInputService.InputEnded:Connect(function(input, processed) -- Keys released
	if processed or isMobile or useCustomControl then return end

	if input.KeyCode == Enum.KeyCode[Keybinds.ThrottleUp] or input.KeyCode == Enum.KeyCode[Keybinds.ThrottleDown] then
		throttleChange = 0


	elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then
		Controls.Inputs.Yaw = 0
	end
end)

local function getEffectiveInput(input, deadzone)
	return math.max(0, math.abs(input) - deadzone) / (1 - deadzone)
end

local accumulated = 0
local connection
connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.05)
	accumulated += dt
	local sensitivity = 1 - math.exp(-10 * dt)
	
	local isActive = Stats_:GetAttribute("Active") == true
	if not isMobile and not useCustomControl then
		Controls.Inputs.Throttle = if isActive then math.clamp(Controls.Inputs.Throttle + (throttleChange * Settings:GetAttribute("FlightControls/ThrottleIncrement") * dt), 0, 1) else 0

		if onControl then
			local mousePos = UserInputService:GetMouseLocation()
			if Settings:GetAttribute("AttitudeControls/Advanced") == true then
				Controls.Inputs.Roll = ((mousePos.X - (camera.ViewportSize.X/2))/camera.ViewportSize.X) * -2
				Controls.Inputs.Pitch = ((mousePos.Y - (camera.ViewportSize.Y/2))/camera.ViewportSize.Y) * -2
			else
				local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
				Controls.Inputs.MousePosition = ray.Origin + (ray.Direction * 1e6)
			end
		else
			Controls.Inputs.MousePosition = nil
			Controls.Inputs.Roll = 0
			Controls.Inputs.Pitch = 0
		end
	else
		if not isActive and script:GetAttribute("Throttle") > 0 then
			-- Force reset the throttle if the aircraft is inactive.
			script:SetAttribute("Throttle", 0)
		end
		
		Controls.Inputs.Throttle = if isActive then script:GetAttribute("Throttle") else 0
		Controls.Inputs.MousePosition = script:GetAttribute("MousePosition")
		Controls.Inputs.Roll = script:GetAttribute("Roll")
		Controls.Inputs.Pitch = script:GetAttribute("Pitch")
		Controls.Inputs.Yaw = script:GetAttribute("Yaw")
	end
	-----------------------------------------------------------------------------------------------
	local throttle_Input	= Controls.Inputs.Throttle
	local roll_Input		= Controls.Inputs.Roll
	local pitch_Input 		= Controls.Inputs.Pitch
	local yaw_Input 		= Controls.Inputs.Yaw
	------------------------------------------------------------------------------------------------
	local deadzone = if isMobile or isGamepad then 0.1 else 0.005
	local roll_Curve		= 0.8 + (getEffectiveInput(roll_Input, deadzone) * 0.2)
	local pitch_Curve		= 0.8 + (getEffectiveInput(pitch_Input, deadzone) * 0.2)
	local yaw_Curve			= 0.8 + (getEffectiveInput(yaw_Input, deadzone) * 0.2)
	------------------------------------------------------------------------------------------------
	Controls.Outputs.Throttle = math.lerp(Controls.Outputs.Throttle, throttle_Input, sensitivity)
	Controls.Outputs.MousePosition = if Controls.Inputs.MousePosition then
		(Controls.Outputs.MousePosition or mainPart.Position + (mainPart.CFrame.LookVector * 1e6)):Lerp(Controls.Inputs.MousePosition, sensitivity)
		else nil
	Controls.Outputs.Roll = math.lerp(Controls.Outputs.Roll, roll_Input * roll_Curve, sensitivity)
	Controls.Outputs.Pitch = math.lerp(Controls.Outputs.Pitch, pitch_Input * pitch_Curve, sensitivity)
	Controls.Outputs.Yaw = math.lerp(Controls.Outputs.Yaw, yaw_Input * yaw_Curve, sensitivity)
	------------------------------------------------------------------------------------------------
	handlerFrames.Linear.Throttle.Size	= UDim2.new(0, 20, throttle_Input, 0)
	handlerFrames.Linear.Roll.Size		= UDim2.new(0, 20, roll_Input, 0)
	handlerFrames.Linear.Pitch.Size		= UDim2.new(0, 20, pitch_Input, 0)
	handlerFrames.Linear.Yaw.Size		= UDim2.new(0, 20, yaw_Input, 0)
	-----------------------------------------------------------------------------------------------
	handlerFrames.Nonlinear.Throttle.Size	= UDim2.new(0, 20, Controls.Outputs.Throttle, 0)
	handlerFrames.Nonlinear.Roll.Size		= UDim2.new(0, 20, Controls.Outputs.Roll, 0)
	handlerFrames.Nonlinear.Pitch.Size		= UDim2.new(0, 20, Controls.Outputs.Pitch, 0)
	handlerFrames.Nonlinear.Yaw.Size		= UDim2.new(0, 20, Controls.Outputs.Yaw, 0)
	-----------------------------------------------------------------------------------------------
	local states = aircraftState.System
	states.Throttle			= Controls.Outputs.Throttle
	states.MousePosition	= Controls.Outputs.MousePosition
	states.Roll				= Controls.Outputs.Roll
	states.Pitch			= Controls.Outputs.Pitch
	states.Yaw				= Controls.Outputs.Yaw

	states.Boost 			= Stats_:GetAttribute("Boost") or states.Boost
	states.MinSpeed 		= Stats_:GetAttribute("MinSpeed") or states.MinSpeed

	local speedChange = Stats_:GetAttribute("Speed")
	if speedChange then
		states.Speed = speedChange
		Stats_:SetAttribute("Speed", nil)
	end

	local motionCFrameChange = Stats_:GetAttribute("MotionCFrame")
	if motionCFrameChange then
		states.MotionCFrame = motionCFrameChange
		Stats_:SetAttribute("MotionCFrame", nil)
	end

	-- Update the stats slowly if the control is client sided, 10 Hz otherwise.
	local rate = if isClientControlled then 0.5 else 1/10
	if accumulated >= rate then
		local packet = {}
		packet.Throttle = Controls.Outputs.Throttle
		packet.MousePosition = Controls.Outputs.MousePosition
		packet.Roll = Controls.Outputs.Roll
		packet.Pitch = Controls.Outputs.Pitch
		packet.Yaw = Controls.Outputs.Yaw
		updateEvent:FireServer("Stats", packet)
		accumulated -= rate
	end
end)

function disconnect()
	connection:Disconnect()
	kitCore:Cleanup(aircraft)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, defaultBackpackEnabled)
	UserInputService.MouseIcon = "" -- Return to Roblox default cursor
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

if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
	-- Mobile indentifier
	isMobile = true
	onControl = false
elseif UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 then
	-- Gamepad indentifier
	isGamepad = true
	onControl = false
end

function resetControl()
	useCustomControl = script:GetAttribute("Custom_Control") == true
	if useCustomControl then
		onControl = false
		UserInputService.MouseIcon = ""
		camera.CameraType = Enum.CameraType.Custom
	end
end resetControl()

script:GetAttributeChangedSignal("Custom_Control"):Connect(resetControl) -- Reset if custom control is enabled

script:SetAttribute("Custom_Control", #script:GetChildren() > 0) -- Check if there is a custom control script

stateWrapper:GetAttributeChangedSignal("Client_Controlled"):Connect(function()
	isClientControlled = stateWrapper:GetAttribute("Client_Controlled") == true
	kitCore:Reset(aircraft)
end)