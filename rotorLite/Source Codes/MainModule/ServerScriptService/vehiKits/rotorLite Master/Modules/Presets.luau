local Presets = {
	AircraftStatistics = {
		Stability = 0.6,
		Sensitivity = 0.5,
		RateOfClimb = 35,
		Acceleration = 0.1,
		MaxSpeed = 200,
		MaxAltitude = 15000,
		TorqueResponsiveness = 40,
	},

	FuelSystem = {
		Enabled = true,
		Consumption = 0.0025,
	},

	FlightControls = {
		FollowCamera = true,
		CameraType = "Custom",
		CursorIcon = "rbxassetid://105110588062984",
		ToggleControl = Enum.KeyCode.C,
		Engine = Enum.KeyCode.E,
		CollectiveUp = Enum.KeyCode.W,
		CollectiveDown = Enum.KeyCode.S,
		CollectiveIncrement = 0.5,
		LandingGear = Enum.KeyCode.G,
	},

	Advanced = {
		PhysicsScale = 1,
		ClientControlled = true,
		ResetNetwork = true,
	},
}

return Presets
