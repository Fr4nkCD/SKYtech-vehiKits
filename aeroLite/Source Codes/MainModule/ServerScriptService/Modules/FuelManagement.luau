-- Fuel Management Utility
-- by SKYtech

local math_max = math.max

local FuelManagement = {}

local function getBurnPercentages(PowerType)
	local isThrottle = PowerType == "Throttle"
	return if isThrottle then 0.1 else 0.5, if isThrottle then 0.9 else 0.5
end

function FuelManagement.ProcessBurn(
	PowerType : string,
	consumptionRate : number,
	Stats_ : Folder,
	deltaTime : number,
	legacyValue : NumberValue
)
	local currentFuel = Stats_:GetAttribute("Fuel") or 100
	local isActive = Stats_:GetAttribute("Active") == true
	
	if currentFuel > 0 and isActive then
		local idleBurnPercent, activeBurnPercent = getBurnPercentages(PowerType)
		local activeBurn = Stats_:GetAttribute(PowerType) * activeBurnPercent
		local burnPerSecond = consumptionRate * (idleBurnPercent + activeBurn) * deltaTime
		
		local newFuel = math_max(0, currentFuel - burnPerSecond)
		Stats_:SetAttribute("Fuel", newFuel)

		if legacyValue then
			legacyValue.Value = newFuel
		end
	end
end

return FuelManagement