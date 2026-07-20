-- Keep systems replicated under StreamingEnabled by forcing replication focus.
if not workspace.StreamingEnabled then return end

local tagName = "SKYtech_System"
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Focuses or unfocuses a BasePart for a single player.
local function setFocusForPlayer(player, instance, isAdding)
	if instance:IsA("BasePart") then
		if isAdding then
			player:AddReplicationFocus(instance)
		else
			player:RemoveReplicationFocus(instance)
		end
	end
end

-- Focuses or unfocuses a BasePart for all active players.
local function setFocusForGlobal(instance, isAdding)
	for _, player in Players:GetPlayers() do
		setFocusForPlayer(player, instance, isAdding)
	end
end

-- Register existing and spawned systems.
for _, instance in CollectionService:GetTagged(tagName) do
	setFocusForGlobal(instance, true)
end

CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
	setFocusForGlobal(instance, true)
end)

CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
	setFocusForGlobal(instance, false)
end)

-- Handle players joining mid-session.
Players.PlayerAdded:Connect(function(player)
	for _, instance in CollectionService:GetTagged(tagName) do
		setFocusForPlayer(player, instance, true)
	end
end)