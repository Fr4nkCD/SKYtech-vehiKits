-- rotorLite Source Module
-- by SKYtech

local module = {}

local KIT_NAME = "rotorLite" -- Change here
local TAG_NAME = "SKYtech "..KIT_NAME

do -- Load core scripts for the kit and other systems
	local FOLDER_NAME = "SKYtech Systems"

	local function installPackages(Service)
		local packages = script:FindFirstChild(Service.Name):GetChildren()

		local systemsFolder = Service:FindFirstChild(FOLDER_NAME)
		if systemsFolder then
			-- If the systems folder is found, only load the packages that don't exist.
			for _, subFolder in (packages) do
				local hasSubFolder = systemsFolder:FindFirstChild(subFolder.Name)
				if hasSubFolder then
					-- If the sub folder is found, search for the missing scripts and modules.
					for __, asset in (subFolder:GetChildren()) do
						local hasAsset = hasSubFolder:FindFirstChild(asset.Name)
						if not hasAsset then
							asset.Parent = hasSubFolder
							if asset:IsA("BaseScript") then
								asset.Enabled = true
							end
						end
					end
				else
					-- If the sub folder is not found, load it entirely.
					subFolder.Parent = systemsFolder
					for __, baseScript in (subFolder:GetChildren()) do
						if baseScript:IsA("BaseScript") then
							baseScript.Enabled = true
						end
					end
				end
			end
		else
			-- If the folder is not found, load everything.	
			systemsFolder = Instance.new("Folder")
			systemsFolder.Name = FOLDER_NAME
			systemsFolder.Parent = Service

			for _, subFolder in (packages) do
				subFolder.Parent = systemsFolder

				for __, baseScript in (subFolder:GetChildren()) do
					if baseScript:IsA("BaseScript") then
						baseScript.Enabled = true
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

function module:Load(vehicle)
	-- Legacy load function
	-- Give the old version a tag so the new module can load it.
	if not vehicle:HasTag(TAG_NAME) then
		vehicle:AddTag(TAG_NAME)
	end
end

return module