-- Former master script, now a mass manager.

local aircraft = script.Parent
local mainPart = aircraft.Main.Main

local parts = {}
local scanStart = os.clock()
for _, part in aircraft:GetDescendants() do
	if os.clock() - scanStart > 0.005 then
		task.wait()
		scanStart = os.clock()
	end

	if part:IsA("BasePart") then
		table.insert(parts, part)
	end
end

local function calculateMass()
	local totalMass = 0
	local calcStart = os.clock()
	for _, part in parts do
		if os.clock() - calcStart > 0.005 then
			task.wait()
			calcStart = os.clock()
		end

		totalMass += if not part.Massless then part:GetMass() else 0
		part:SetAttribute("CurrentMass", part:GetMass())
	end
	script:SetAttribute("Mass", totalMass)
end
calculateMass()

for _, part in parts do
	local physicsChanged, masslessChanged, destroyed

	physicsChanged = part:GetPropertyChangedSignal("CustomPhysicalProperties"):Connect(function()
		local change = part:GetMass() - part:GetAttribute("CurrentMass")
		if not part.Massless then
			script:SetAttribute("Mass", script:GetAttribute("Mass") + change)
		end
		part:SetAttribute("CurrentMass", part:GetMass())
	end)

	masslessChanged = part:GetPropertyChangedSignal("Massless"):Connect(function()
		script:SetAttribute("Mass", script:GetAttribute("Mass") + (if part.Massless then -1 else 1) * part:GetAttribute("CurrentMass"))
	end)

	destroyed = part:GetPropertyChangedSignal("Parent"):Connect(function()
		if not part.Parent then
			if not part.Massless then
				script:SetAttribute("Mass", script:GetAttribute("Mass") - part:GetAttribute("CurrentMass"))
			end

			table.remove(parts, table.find(parts, part))

			physicsChanged:Disconnect()
			masslessChanged:Disconnect()
			destroyed:Disconnect()

			physicsChanged = nil
			masslessChanged = nil
			destroyed = nil
		end
	end)
end

mainPart:GetPropertyChangedSignal("Parent"):Connect(function()
	if not mainPart.Parent then
		-- Destroy the plane to prevent the scripts from continuing.

		table.clear(parts)
		parts = nil

		aircraft:Destroy()
	end
end)

-- Attribute mapping and synchronization wrapper for VTOLLevel & MotionStability
local Stats_ = aircraft:WaitForChild("Main"):WaitForChild("Stats")

local attributeMap = {
	["MotionStability"] = "Stability",
	["VTOLLevel"]        = "VTOL",
}

-- Initialize fallback values on startup
for statsName, systemName in attributeMap do
	local statsValue = Stats_:GetAttribute(statsName)
	local systemValue = script:GetAttribute(systemName)
	
	if statsValue ~= nil and systemValue == nil then
		script:SetAttribute(systemName, statsValue)
	elseif systemValue ~= nil and statsValue == nil then
		Stats_:SetAttribute(statsName, systemValue)
	end
end

-- Sync Stats (New Names) -> System (Legacy Names)
Stats_.AttributeChanged:Connect(function(statsAttr)
	local systemAttr = attributeMap[statsAttr]
	if systemAttr then
		local newValue = Stats_:GetAttribute(statsAttr)
		if script:GetAttribute(systemAttr) ~= newValue then
			script:SetAttribute(systemAttr, newValue)
		end
	end
end)

-- Sync System (Legacy Names) -> Stats (New Names)
script.AttributeChanged:Connect(function(systemAttr)
	local statsAttr = nil
	for newName, legacyName in attributeMap do
		if legacyName == systemAttr then
			statsAttr = newName
			break
		end
	end
	
	if statsAttr then
		local newValue = script:GetAttribute(systemAttr)
		if Stats_:GetAttribute(statsAttr) ~= newValue then
			Stats_:SetAttribute(statsAttr, newValue)
		end
	end
end)