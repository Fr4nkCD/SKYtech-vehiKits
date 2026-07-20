-- Legacy Syncing Module
-- by SKYtech

local LegacySyncing = {}

function LegacySyncing.FindMissingSettings(Settings, Presets)
	-- Find missing settings
	for category, values in Presets do
		for name, value in values do
			local attrName = category .. "/" .. name
			if Settings:GetAttribute(attrName) == nil then
				local attrValue = if typeof(value) == "EnumItem" then value.Name else value
				Settings:SetAttribute(attrName, attrValue)
			end
		end
	end
end

function LegacySyncing.SyncValue(AttrName, Value, Folder, ConnectionsTable)
	-- Sync the legacy value with an attribute.

	-- Value Changed
	table.insert(ConnectionsTable, Value:GetPropertyChangedSignal("Value"):Connect(function()
		local newValue = Value.Value
		if newValue ~= Folder:GetAttribute(AttrName) then
			Folder:SetAttribute(AttrName, newValue)
		end
	end))

	-- Attribute Changed
	table.insert(ConnectionsTable, Folder:GetAttributeChangedSignal(AttrName):Connect(function()
		local newValue = Folder:GetAttribute(AttrName)
		if newValue ~= nil and newValue ~= Value.Value then
			Value.Value = newValue
		end
	end))
end

function LegacySyncing.SyncSettings(Settings, ConnectionsTable)
	-- Sync attributes with legacy values if found.
	for _, category in Settings:GetChildren() do
		local categoryName = category.Name:gsub("_", "")

		for _, value in category:GetChildren() do
			local valueName = value.Name:gsub("_", "")
			local attrName = categoryName .. "/" .. valueName
			
			-- Overwrite the attribute if the legacy value is found.
			Settings:SetAttribute(attrName, value.Value)

			-- Sync attributes and value objects.
			LegacySyncing.SyncValue(attrName, value, Settings, ConnectionsTable)
		end
	end
end

return LegacySyncing