-- Protect SKYtech vehiKits from being hidden by StreamingEnabled, which breaks the systems.

if not workspace.StreamingEnabled then return end -- Don't run if it's disabled.

local tagName = "SKYtech_System"
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Helpers to avoid repeating the BasePart check + player loop in each handler.
local function addFocus(instance)
	if not instance:IsA("BasePart") then return end
	for _, player in Players:GetPlayers() do
		player:AddReplicationFocus(instance)
	end
end

local function removeFocus(instance)
	if not instance:IsA("BasePart") then return end
	for _, player in Players:GetPlayers() do
		player:RemoveReplicationFocus(instance)
	end
end

-- Initialize existing tagged instances.
for _, instance in CollectionService:GetTagged(tagName) do
	addFocus(instance)
end

-- Tagged instance added (e.g. aircraft spawns into the world).
CollectionService:GetInstanceAddedSignal(tagName):Connect(addFocus)

-- Tagged instance removed (e.g. aircraft is destroyed).
CollectionService:GetInstanceRemovedSignal(tagName):Connect(removeFocus)

-- Add replication focus for new players who join mid-session.
-- Note: addFocus cannot be reused here — it adds for ALL players, not just the new one.
Players.PlayerAdded:Connect(function(player)
	for _, instance in CollectionService:GetTagged(tagName) do
		if instance:IsA("BasePart") then
			player:AddReplicationFocus(instance)
		end
	end
end)