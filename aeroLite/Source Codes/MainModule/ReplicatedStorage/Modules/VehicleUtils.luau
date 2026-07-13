-- Vehicle Utilities
-- by SKYtech

local math_pi = math.pi
local math_clamp = math.clamp
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local math_sign = math.sign
local math_rad = math.rad
local math_deg = math.deg
local math_exp = math.exp
local math_lerp = math.lerp
local math_sqrt = math.sqrt
local math_atan = math.atan
local math_atan2 = math.atan2
local math_acos = math.acos

local CFrame_new = CFrame.new
local CFrame_Angles = CFrame.Angles
local CFrame_lookAt = CFrame.lookAt
local Vector2_zero = Vector2.zero
local Vector2_new = Vector2.new
local Vector3_zero = Vector3.zero
local Vector3_new = Vector3.new

local VehicleUtils = {
	-- Global Variables
	CFNew = CFrame_new,
	CFAngles = CFrame_Angles,
	CFLookAt = CFrame_lookAt,
	V2Zero = Vector2_zero,
	V2New = Vector2_new,
	V3Zero = Vector3_zero,
	V3New = Vector3_new,
	Pi = math_pi,
	Clamp = math_clamp,
	Max = math_max,
	Min = math_min,
	Abs = math_abs,
	Sign = math_sign,
	Rad = math_rad,
	Deg = math_deg,
	Exp = math_exp,
	Lerp = math_lerp,
}

-- Utility Functions

local RunService = game:GetService("RunService")

function VehicleUtils.IsClient()
	return RunService:IsClient()
end

function VehicleUtils.GetRoll(CF)
	local CFRight = CF * CFrame_Angles(0, math_pi / 2, 0)
	local noRollRight = CFrame_new(CF.Position, CF.Position + CF.LookVector) * CFrame_Angles(0, math_pi / 2, 0)
	local CFDiff = CFRight:ToObjectSpace(noRollRight)
	return math_atan2(CFDiff.LookVector.Y, CFDiff.LookVector.Z) % (math_pi * 2) + math_pi
end

function VehicleUtils.GetPitch(CF)
	-- This function gets the pitch of the Engine. Credit to DevAdrian for this
	local LV = CF.LookVector
	local XZDist = math_sqrt(LV.X ^ 2 + LV.Z ^ 2)
	return math_atan(LV.Y / math_max(XZDist, 0.0001))
end

function VehicleUtils.GetAlignmentCFrame(part, hitNormal)
	local forwardVector = part.CFrame.LookVector
	local projectedForward = (forwardVector - hitNormal * forwardVector:Dot(hitNormal)).Unit
	projectedForward = if projectedForward ~= projectedForward then Vector3_zero else projectedForward

	local alignedCF = CFrame.fromMatrix(part.Position, projectedForward:Cross(hitNormal), hitNormal)
	local differenceCF = alignedCF:ToObjectSpace(part.CFrame)

	return differenceCF
end

function VehicleUtils.GetSurfaceBankAngle(part, hitNormal)
	local mainCF = part.CFrame

	local flatRight = Vector3_new(mainCF.RightVector.X, 0, mainCF.RightVector.Z).Unit

	if flatRight.Magnitude == 0 then
		flatRight = Vector3.xAxis
	end

	local angleFromNormal = math_acos(math_clamp(flatRight:Dot(hitNormal), -1, 1))
	local surfaceBankRad = (math_pi / 2) - angleFromNormal

	return -surfaceBankRad
end

function VehicleUtils.CheckPartCollision(part, ignoredObjects)
	if not part.CanCollide then
		table.insert(ignoredObjects, part)
	end
	return part.CanCollide
end

function VehicleUtils.UpdateSetting(attrName, attrValue, target)
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

function VehicleUtils.SyncLegacyValues(Settings, ConnectionsTable)
	for _, category in pairs(Settings:GetChildren()) do
		local categoryName = category.Name:gsub("_", "")

		for _, valueObject in pairs(category:GetChildren()) do
			if valueObject:IsA("ValueBase") then
				table.insert(ConnectionsTable, valueObject:GetPropertyChangedSignal("Value"):Connect(function()
					local newValue = valueObject.Value
					local valueName = valueObject.Name:gsub("_", "")
					local attrName = categoryName .. "/" .. valueName
					if Settings:GetAttribute(attrName) ~= newValue then
						Settings:SetAttribute(attrName, newValue)
					end
				end))
			end
		end
	end
end

return VehicleUtils
