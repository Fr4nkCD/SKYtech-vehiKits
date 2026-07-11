-- Protect SKYtech vehiKits from being hidden by SteamingEnabled which breaks the systems.

if not workspace.StreamingEnabled then return end -- Don't run if it's disabled

local tagName = "SKYtech_System"

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Initialize
for _, instance in (CollectionService:GetTagged(tagName)) do
	if instance:IsA("BasePart") then
		for _, player in (Players:GetPlayers()) do
			player:AddReplicationFocus(instance)
		end
	end
end

-- Tagged instance added
CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
	if instance:IsA("BasePart") then
		for _, player in (Players:GetPlayers()) do
			player:AddReplicationFocus(instance)
		end
	end
end)

-- Tagged instance removed
CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
	if instance:IsA("BasePart") then
		for _, player in (Players:GetPlayers()) do
			player:RemoveReplicationFocus(instance)
		end
	end
end)

-- Add tagged instances to new players
Players.PlayerAdded:Connect(function(player)
	for _, instance in (CollectionService:GetTagged(tagName)) do
		if instance:IsA("BasePart") then
			player:AddReplicationFocus(instance)
		end
	end
end)
