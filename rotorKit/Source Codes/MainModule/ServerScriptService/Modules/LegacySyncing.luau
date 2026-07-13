-- Legacy Syncing Module
-- by SKYtech

local LegacySyncing = {}

function LegacySyncing.FindMissingSettings(Settings, Presets)
	-- Find missing settings
	for category, values in pairs(Presets) do
		for name, value in pairs(values) do
			local atrrName = category.."/"..name
			if Settings:GetAttribute(atrrName) == nil then
				value = if typeof(value) == "EnumItem" then value.Name else value
				Settings:SetAttribute(atrrName, value)
			end
		end
	end
end

function LegacySyncing.SyncValue(AtrrName, Value, Folder, ConnectionsTable)
	-- Sync the legacy value with an attribute.

	-- Value Changed
	table.insert(ConnectionsTable, Value:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = Value.Value
		if newValue ~= Folder:GetAttribute(AtrrName) then
			Folder:SetAttribute(AtrrName, newValue)
		end
	end))

	-- Attribute Changed
	table.insert(ConnectionsTable, Folder:GetAttributeChangedSignal(AtrrName):Connect(function()
		local newValue = Folder:GetAttribute(AtrrName)
		if newValue ~= nil and newValue ~= Value.Value then
			Value.Value = newValue
		end
	end))
end

function LegacySyncing.SyncSettings(Settings, ConnectionsTable)
	-- Sync attributes with legacy values if found.
	for _, category in (Settings:GetChildren()) do
		local categoryName = category.Name:gsub("_", "")

		for _, value in (category:GetChildren()) do
			local valueName = value.Name:gsub("_", "")
			local attrName = categoryName.."/"..valueName
			
			-- Overwrite the attribute if the legacy value is found.
			Settings:SetAttribute(categoryName.."/"..valueName, value.Value)

			-- Sync attributes and value objects.
			LegacySyncing.SyncValue(attrName, value, Settings, ConnectionsTable)
		end
	end
end

return LegacySyncing
