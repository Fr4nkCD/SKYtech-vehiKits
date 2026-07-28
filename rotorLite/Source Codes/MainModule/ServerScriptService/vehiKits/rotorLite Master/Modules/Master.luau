local Master = {}

local Players = game:GetService("Players")

local KitMaster = script.Parent.Parent
local Packages = KitMaster.Packages
local Constraints = Packages.Constraints



function Master.Initialize(
	kitName,
	aircraft,
	Presets,
	connections,
	LegacySyncing,
	Welder
)
	local Settings = aircraft:WaitForChild("Settings")
	local main = aircraft:WaitForChild("Main")
	local mainPart = main:WaitForChild("Main")
	local Stats_ = main:WaitForChild("Stats")
	local pilotSeat = main:FindFirstChild("PilotSeat")

	local legacyValues = {
		["Active"] = Stats_:FindFirstChild("Active"),
		["Collective"] = Stats_:FindFirstChild("Collective"),
		["Motion"] = Stats_:FindFirstChild("Motion"),
		["Fuel"] = Stats_:FindFirstChild("Fuel")
	}

	-- Check for missing stats attributes and overwrite them with legacy values if found.
	Stats_:SetAttribute("Active", if legacyValues.Active then
		legacyValues.Active.Value
		else
		Stats_:GetAttribute("Active") or false)
	Stats_:SetAttribute("Collective", if legacyValues.Collective then
		legacyValues.Collective.Value
		else
		Stats_:GetAttribute("Collective") or 0)
	Stats_:SetAttribute("Motion", if legacyValues.Motion then
		legacyValues.Motion.Value
		else
		Stats_:GetAttribute("Motion") or Vector3.zero)
	Stats_:SetAttribute("Fuel", if legacyValues.Fuel then
		legacyValues.Fuel.Value
		else
		Stats_:GetAttribute("Fuel") or 100
	)

	LegacySyncing.FindMissingSettings(Settings, Presets)
	LegacySyncing.SyncSettings(Settings, connections)

	aircraft.PrimaryPart = mainPart
	
	if not mainPart:HasTag("SKYtech_System") then
		mainPart:AddTag("SKYtech_System")
	end

	-------------------------------------

	-- Clone the attachment and constraints if they don't exist.
	local main_Attachment = mainPart:FindFirstChild("Main_Attachment")
	if not main_Attachment then
		main_Attachment = Packages.Main_Attachment:Clone()
		main_Attachment.Parent = mainPart
	end

	for _, constraint in Constraints:GetChildren() do		
		local existingConstraint = mainPart:FindFirstChild(constraint.Name)
		if not existingConstraint then
			existingConstraint = constraint:Clone()
			if existingConstraint:IsA("Constraint") then
				existingConstraint.Attachment0 = main_Attachment
			end
			existingConstraint.Parent = mainPart
		else
			-- Reconnect the attachment for safety
			if existingConstraint:IsA("Constraint") and not existingConstraint.Attachment0 then
				existingConstraint.Attachment0 = main_Attachment
			end
		end
	end

	local weldFolder = mainPart:FindFirstChild("Welds")
	if not weldFolder then
		-- Weld only once
		Welder.Weld(aircraft, mainPart)
	end

	---------------------------------------------------------------------------------

	local kitSystem = aircraft:FindFirstChild("System")
	if not kitSystem then
		kitSystem = Packages.System:Clone()
		kitSystem.Parent = aircraft
	end

	if legacyValues.Active then
		local activate = legacyValues.Active:FindFirstChild("Activate")
		if not activate then
			activate = Packages.Activate:Clone()
			activate.Parent = legacyValues.Active
			activate.Function.Enabled = true
		end
	end

	local handler = kitSystem.Handler
	local kitGui = if pilotSeat then
		pilotSeat:FindFirstChild(kitName.."_System") or handler:FindFirstChild(kitName.."_System")
		else nil

	local controller = if kitGui then kitGui:FindFirstChild("Controller") else nil

	if kitGui then
		if not controller then
			controller = Packages.Controller:Clone()
			controller.Enabled = true
			controller.Parent = kitGui
		end

		local controlHandler = kitGui:FindFirstChild("Control_Handler")
		if not controlHandler then
			controlHandler = Packages.Control_Handler:Clone()
			controlHandler.Parent = kitGui
		end

		local aircraftOrigin = kitGui:FindFirstChild("Aircraft")
		if not aircraftOrigin then
			aircraftOrigin = Packages.Aircraft:Clone()
			aircraftOrigin.Value = aircraft
			aircraftOrigin.Parent = kitGui
		end

		if kitGui.Parent ~= handler then
			kitGui.Parent = handler
		end
	end

	local loader = aircraft:FindFirstChild("Settings/Loader")
	if loader then
		local hasCustomControls = loader:GetChildren()
		if hasCustomControls and controller then
			for _, module in hasCustomControls do
				if module.Name ~= kitName.." Source" then
					module.Parent = controller
				end
			end
			hasCustomControls = nil
		end
		loader:Destroy()
	end

	local defaultLandingGear = main:FindFirstChild("LandingGear")
	local modsFolder = main:FindFirstChild("Mods")
	local oldGearScript = if modsFolder then modsFolder:FindFirstChild("Landing_Gear") else nil
	if (defaultLandingGear and defaultLandingGear:FindFirstChild("Extended") and defaultLandingGear:FindFirstChild("Retracted"))
		and (not oldGearScript or (oldGearScript and not oldGearScript:IsA("Script"))) then
		defaultLandingGear:AddTag("SKYtech_LandingGear")
	end

	table.insert(connections, mainPart.AncestryChanged:Connect(function(instance, parent)
		if not parent then
			aircraft:Destroy()
		end
	end))

	return Settings, main, mainPart, Stats_, pilotSeat, kitSystem, kitGui, legacyValues
end

function Master.HandlePilotSeat(
	licenseName,
	aircraft,
	kitCore,
	Settings,
	mainPart,
	pilotValue,
	pilotSeat,
	kitGui,
	handler,
	connections,
	NetworkManager
)
	local pilotGui
	local license = handler.License
	local kitLicense = handler:FindFirstChild(licenseName)

	table.insert(connections, pilotSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local player = Players:GetPlayerFromCharacter(if pilotSeat.Occupant then pilotSeat.Occupant.Parent else nil)

		if player then
			-- Pilot enter
			pilotValue.Value = player

			local existingPilotGui = player.PlayerGui:FindFirstChild(kitGui.Name)
			pilotGui = if existingPilotGui then existingPilotGui else kitGui:Clone()
			pilotGui.Parent = player.PlayerGui

			license.Value = if license.Value then license.Value else kitLicense:Clone()
			license.Value.Parent = player.PlayerGui
			

		else
			-- Pilot leave (localize values first to prevent race condition during wait)
			local targetPilot = pilotValue.Value
			local targetGui = pilotGui
			local targetLicenseVal = license.Value

			if targetPilot then 
				pilotValue.Value = nil 
			end
			
			task.wait(0.1)
			
			if targetGui then targetGui:Destroy() end
			if targetLicenseVal then targetLicenseVal:Destroy() end
			
			pilotGui = nil
			license.Value = nil
			kitCore:Reset(aircraft)
		end

		if player and Settings:GetAttribute("Advanced/ClientControlled") == true then
			NetworkManager.SetNetworkOwner(player, mainPart, aircraft)
		elseif not player and Settings:GetAttribute("Advanced/ResetNetwork") == true then
			NetworkManager.SetNetworkOwner(nil, mainPart, aircraft)
		end
	end))
	
	table.insert(connections, pilotValue:GetPropertyChangedSignal("Value"):Connect(function()
		if pilotValue.Value then
			kitCore:Reset(aircraft)
		end
	end))
end

function Master.UpdateStats(
	licenseName,
	kitSystem,
	Stats_,
	connections
)
	local updateEvent = kitSystem.Update

	table.insert(connections, updateEvent.OnServerEvent:Connect(function(player, event, packet)
		if not player.PlayerGui:FindFirstChild(licenseName) then return end

		local hasFuel = Stats_:GetAttribute("Fuel") > 0

		if event == "Active" then
			Stats_:SetAttribute("Active", Stats_:GetAttribute("Active") ~= true and hasFuel)
			Stats_:SetAttribute("Collective", 0)

		elseif event == "Stats" then
			local collective = if hasFuel then packet.Collective else 0
			local roll = packet.Roll
			local pitch = packet.Pitch
			local yaw = packet.Yaw
			local mousePosition = packet.MousePosition
			local motion = Vector3.new(roll, pitch, yaw)

			Stats_:SetAttribute("Collective", collective)
			Stats_:SetAttribute("TargetPosition", mousePosition)
			Stats_:SetAttribute("Motion", motion)

		elseif event == "States" then
			local taxiing = packet.Taxiing
			local flying = packet.Flying
			local stalling = packet.Stalling

			kitSystem:SetAttribute("Taxiing", taxiing)
			kitSystem:SetAttribute("Flying", flying)
			kitSystem:SetAttribute("Stalling", stalling)
		end
	end))
end

return Master