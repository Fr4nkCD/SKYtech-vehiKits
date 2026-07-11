-- Handle flight physics locally in case of no pilot seated and the aircraft's network is still owned.

local kitNames = {
	["aeroMini"] = true,
	["aeroLite"] = true,
	["aeroKit"] = true,
	["rotorLite"] = true,
	["rotorKit"] = true
}
local loadedKits = {}

---------------------

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("SKYtech Systems"):WaitForChild("Modules")
local CollectionService = game:GetService("CollectionService")

local player = game:GetService("Players").LocalPlayer

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
end)

local trackedAircraft = {}

local function initializeKit(kitName, module)
	local core = require(module)

	local tagName = "SKYtech " .. kitName

	for _, instance in CollectionService:GetTagged(tagName) do
		trackedAircraft[instance] = core
	end

	CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
		trackedAircraft[instance] = core
	end)

	CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
		trackedAircraft[instance] = nil
	end)
end

for kitName, _ in kitNames do -- Existing kit modules
	task.spawn(function()
		local module = Modules:WaitForChild(kitName, 10)

		if not module then
			return
		end

		if loadedKits[kitName] then return end
		loadedKits[kitName] = true

		initializeKit(kitName, module)
	end)
end

-- Newly added kit modules
Modules.ChildAdded:Connect(function(module)
	local kitName = module.Name
	if kitNames[kitName] then
		if loadedKits[kitName] then return end
		loadedKits[kitName] = true

		initializeKit(module.Name, module)
	end
end)

local accumulated = 0
local clockSpeed = 1 / 10 -- Hz
local cycled = false

game:GetService("RunService").Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.05)
	accumulated += dt
	cycled = accumulated >= clockSpeed

	for aircraft, core in trackedAircraft do
		if not aircraft:IsDescendantOf(workspace) then continue end
		local networkOwner = aircraft:GetAttribute("NetworkOwner")
		if networkOwner and player.UserId == networkOwner then
			if humanoid then
				local seatPart = humanoid.SeatPart
				if seatPart and seatPart:IsDescendantOf(aircraft) then
					core:Update(aircraft, dt, true)
				elseif cycled then
					core:Update(aircraft, accumulated, true)
				end
			end
		end
	end

	if cycled then
		accumulated -= clockSpeed
	end
end)