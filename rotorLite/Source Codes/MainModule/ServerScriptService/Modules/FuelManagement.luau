-- Fuel Management Utility
-- by SKYtech

local math_max = math.max

local FuelManagement = {}

local function getBurnPercentages(PowerType)
	-- Get burn percentages based on the aircraft type (fixed wing = throttle, helicopter = collective)
	local isThrottle = PowerType == "Throttle" -- Throttle or Collective
	local idleBurnPercent = if isThrottle then 0.1 else 0.5
	local activeBurnPercent = if isThrottle then 0.9 else 0.5

	return idleBurnPercent, activeBurnPercent
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
	
	local idleBurnPercent, activeBurnPercent = getBurnPercentages(PowerType)
	
	if currentFuel > 0 and isActive then
		local idleBurn = if isActive then idleBurnPercent else 0
		local activeBurn = Stats_:GetAttribute(PowerType) * activeBurnPercent
		local burnPerSecond = consumptionRate * (idleBurn + activeBurn) * deltaTime
		
		local newFuel = math_max(0, currentFuel - burnPerSecond)
		Stats_:SetAttribute("Fuel", newFuel)

		if legacyValue then
			-- Sync the legacy value if found.
			legacyValue.Value = newFuel
		end
	end
end

return FuelManagement
