-- Former master script, now a mass manager.

local aircraft = script.Parent
local mainPart = aircraft.Main.Main

local parts = {}
for i, part in ipairs(aircraft:GetDescendants()) do
	if i % 100 == 0 then task.wait() end

	if part:IsA("BasePart") then
		table.insert(parts, part)
	end
end

local function calculateMass()
	local totalMass = 0
	for i, part in pairs(parts) do
		if i % 100 == 0 then task.wait() end

		totalMass += if not part.Massless then part:GetMass() else 0
		part:SetAttribute("CurrentMass", part:GetMass())
	end
	script:SetAttribute("Mass", totalMass)
end calculateMass()

for _, part in (parts) do
	local physicsChanged, masslessChanged, destroyed

	physicsChanged = part:GetPropertyChangedSignal("CustomPhysicalProperties"):Connect(function()
		local change = part:GetMass() - part:GetAttribute("CurrentMass")
		script:SetAttribute("Mass", if not part.Massless then script:GetAttribute("Mass") + change else 0)
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