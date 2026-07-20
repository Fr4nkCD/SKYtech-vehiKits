-- aeroKit Source Module
-- by SKYtech

local aeroKit = {}

local KIT_NAME = "aeroKit" -- Change here
local TAG_NAME = "SKYtech "..KIT_NAME

do -- Load core scripts for the kit and other systems
	local FOLDER_NAME = "SKYtech Systems"

	local function installPackages(Service)
		local sourceFolder = script:FindFirstChild(Service.Name)
		if not sourceFolder then return end

		local systemsFolder = Service:FindFirstChild(FOLDER_NAME)
		if not systemsFolder then
			systemsFolder = Instance.new("Folder")
			systemsFolder.Name = FOLDER_NAME
			systemsFolder.Parent = Service
		end

		for _, subFolder in sourceFolder:GetChildren() do
			local targetSubFolder = systemsFolder:FindFirstChild(subFolder.Name)
			if not targetSubFolder then
				subFolder.Parent = systemsFolder
				for _, child in subFolder:GetChildren() do
					if child:IsA("BaseScript") then
						child.Enabled = true
					end
				end
			else
				for _, asset in subFolder:GetChildren() do
					if not targetSubFolder:FindFirstChild(asset.Name) then
						asset.Parent = targetSubFolder
						if asset:IsA("BaseScript") then
							asset.Enabled = true
						end
					end
				end
			end
		end
	end

	warn("Installing SKYtech "..KIT_NAME)

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	installPackages(ReplicatedStorage)
	installPackages(ServerScriptService)

	warn(KIT_NAME.." has been successfully installed.\nCurrent Version: "..script:GetAttribute("Version"))
end

function aeroKit:Load(vehicle)
	-- Legacy load function
	-- Give the old version a tag so the new module can load it.
	if not vehicle:HasTag(TAG_NAME) then
		vehicle:AddTag(TAG_NAME)
	end
end

return aeroKit