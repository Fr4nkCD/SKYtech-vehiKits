-- Vehicle Utilities

local module = {
	-- Global Variables
	CFNew = CFrame.new,
	CFAngles = CFrame.Angles,
	CFLookAt = CFrame.lookAt,
	V2Zero = Vector2.zero,
	V2New = Vector2.new,
	V3Zero = Vector3.zero,
	V3New = Vector3.new,
	Pi = math.pi,
	Clamp = math.clamp,
	Max = math.max,
	Min = math.min,
	Abs = math.abs,
	Sign = math.sign,
	Rad = math.rad,
	Deg = math.deg,
	Exp = math.exp,
	Lerp = math.lerp
}

-- Utility Functions

local RunService = game:GetService("RunService")

function module.IsClient()
	return RunService:IsClient()
end

function module.GetRoll(CF)
	local CFRight = CF * CFrame.Angles(0, math.pi/2, 0)
	local noRollRight = CFrame.new(CF.Position, (CF.Position + CF.LookVector)) * CFrame.Angles(0, math.pi/2, 0)
	local CFDiff = CFRight:ToObjectSpace(noRollRight)
	return math.atan2(CFDiff.LookVector.Y, CFDiff.LookVector.Z) % (math.pi * 2) + math.pi
end

function module.GetPitch(CF)
	-- This function gets the pitch of the Engine. Credit to DevAdrian for this
	local LV = CF.LookVector
	local XZDist = math.sqrt(LV.X ^ 2 + LV.Z ^ 2)
	return math.atan(LV.Y / math.max(XZDist, 0.0001))
end

function module.GetAlignmentCFrame(part, hitNormal)
	local forwardVector = part.CFrame.LookVector
	local projectedForward = (forwardVector - hitNormal * forwardVector:Dot(hitNormal)).Unit
	projectedForward = if projectedForward ~= projectedForward then Vector3.zero else projectedForward

	local alignedCF = CFrame.fromMatrix(part.Position, projectedForward:Cross(hitNormal), hitNormal)
	local differenceCF = alignedCF:ToObjectSpace(part.CFrame)

	return differenceCF
end

function module.GetSurfaceBankAngle(part, hitNormal)
	local mainCF = part.CFrame

	local flatRight = Vector3.new(mainCF.RightVector.X, 0, mainCF.RightVector.Z).Unit

	if flatRight.Magnitude == 0 then
		flatRight = Vector3.xAxis
	end

	local angleFromNormal = math.acos(math.clamp(flatRight:Dot(hitNormal), -1, 1))
	local surfaceBankRad = (math.pi / 2) - angleFromNormal

	return -surfaceBankRad
end

function module.CheckPartCollision(part, ignoredObjects)
	if not part.CanCollide then
		table.insert(ignoredObjects, part)
	end
	return part.CanCollide
end

function module.UpdateSetting(attrName, attrValue, target)
	local split = attrName:split("/")

	for i = 1, #split - 1 do
		local folderName = split[i]
		if not target[folderName] then
			target[folderName] = {}
		end
		target = target[folderName]
	end

	local finalKey = split[#split]
	target[finalKey] = attrValue
end

function module.SyncLegacyValues(Settings, ConnectionsTable)
	for _, category in pairs(Settings:GetChildren()) do
		local categoryName = category.Name:gsub("_", "")

		for _, valueObject in pairs(category:GetChildren()) do
			if valueObject:IsA("ValueBase") then
				table.insert(ConnectionsTable, valueObject:GetPropertyChangedSignal("Value"):Connect(function()
					local newValue = valueObject.Value
					local valueName = valueObject.Name:gsub("_", "")
					local attrName = categoryName.."/"..valueName
					if Settings:GetAttribute(attrName) ~= newValue then
						Settings:SetAttribute(attrName, newValue)
					end
				end))
			end
		end
	end
end

return module
