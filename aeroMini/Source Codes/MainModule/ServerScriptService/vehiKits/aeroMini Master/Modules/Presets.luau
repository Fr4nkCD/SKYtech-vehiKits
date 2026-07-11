local Presets = {
	AircraftStatistics = {
		Acceleration = 0.25,
		MaxSpeed = 300,
		StallSpeed = 100,
		AngleOfAttack = -5,
		FlareRate = 90,
		NoseLiftFactor = 0.2,
		TailLift = false,
		RestingAngle = "Auto",
		MaxAltitude = 100000,
	},

	AttitudeControls = {
		Advanced = false,
		RollSpeed = 10,
		PitchSpeed = 5,
		YawSpeed = 5,
		TurnSensitivity = 0.5,
		TorqueResponsiveness = 100,
	},

	FlightControls = {
		CameraType = "Attach",
		CursorIcon = "rbxassetid://105110588062984",
		ToggleControl = Enum.KeyCode.C,
		Engine = Enum.KeyCode.E,
		ThrottleUp = Enum.KeyCode.W,
		ThrottleDown = Enum.KeyCode.S,
		ThrottleIncrement = 0.5,
		ThrottleExponential = true,
		LandingGear = Enum.KeyCode.G,
	},

	Advanced = {
		PhysicsScale = 1,
		ClientControlled = true,
		ResetNetwork = true,
		LowestPoint = "Auto",
	}
}

return Presets