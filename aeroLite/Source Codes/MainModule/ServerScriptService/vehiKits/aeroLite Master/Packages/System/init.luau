-- State Wrapper
-- This was an old module of the kit and it should've been deleted already.
-- However, some mods manipulate states here so it's just a wrapper now.

local System = {}

-- 1. Internal Signal Class (Mimics Roblox Signals)
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _listeners = {} }, Signal)
end

function Signal:Connect(callback)
	local connection
	connection = {
		_callback = callback,
		Connected = true,
		Disconnect = function()
			if not connection.Connected then return end
			connection.Connected = false
			local index = table.find(self._listeners, connection)
			if index then
				table.remove(self._listeners, index)
			end
		end
	}
	table.insert(self._listeners, connection)
	return connection
end

function Signal:Fire(...)
	-- Iterate backwards so we can safely remove disconnected listeners
	for i = #self._listeners, 1, -1 do
		local listener = self._listeners[i]
		if listener.Connected then
			task.spawn(listener._callback, ...) -- Use task.spawn so one mod's crash doesn't kill the whole system
		else
			table.remove(self._listeners, i)
		end
	end
end

-- 2. Core Data & Signal Instance
local _aircraft = script.Parent
local _stats = _aircraft:WaitForChild("Main"):WaitForChild("Stats")
local _changedSignal = Signal.new()

local _data = {
	Throttle = 0,
	Brake = 0,
	Roll = 0,
	Pitch = 0,
	Yaw = 0,
	--------------------
	Boost = 0,
	MinSpeed = 0,
	Speed = 0,
	MotionCFrame = CFrame.new(),
}

-- 3. The Public API
local SystemProxy = {
	Changed = _changedSignal, -- This is the object with :Connect()
	
	Reset = function()
		-- Nothing here, just added it to avoid breaking mods.
	end,
}

local _isSyncing = false

setmetatable(SystemProxy, {
	__index = function(_, key)
		return _data[key]
	end,

	__newindex = function(_, key, value)
		if _data[key] ~= value then
			local oldValue = _data[key]
			_data[key] = value

			-- Sync Attribute for HUD/Client (Optional but recommended)
			if not _isSyncing then
				_isSyncing = true
				_stats:SetAttribute(key, value)
				_changedSignal:Fire(key, value, oldValue)
				_isSyncing = false
			end
		end
	end
})

return SystemProxy