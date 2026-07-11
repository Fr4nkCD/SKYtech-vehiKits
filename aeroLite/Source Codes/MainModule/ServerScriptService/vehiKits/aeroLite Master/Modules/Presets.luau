local Presets = {
	AircraftStatistics = {
		Acceleration = 0.3,
		Deceleration = 0.2,
		BrakeRatio = 0.25,
		Airbrake = false,
		MaxSpeed = 300,
		MaxSpeedSL = 250,
		StallSpeed = 100,
		ChangedbyAltitude = true,
		GravitySpeed = 50,
		AngleOfAttack = 0,
		FlareRate = 90,
		NoseLiftFactor = 0.2,
		TailLift = false,
		RestingAngle = "Auto",
		MaxAltitude = 10000,
	},

	FuelSystem = {
		Enabled = true,
		Consumption = 0.0025,
	},

	AttitudeControls = {
		Advanced = false,
		MaxBank = 60,
		MaxPitch = 45,
		RollSpeed = 10,
		PitchSpeed = 5,
		YawSpeed = 5,
		TurningRate = 6,
		TurningBleed = 0.1,
		TorqueResponsiveness = 25,
	},

	FlightControls = {
		CameraType = "Attach",
		CursorIcon = "rbxassetid://105110588062984",
		ToggleControl = Enum.KeyCode.C,
		Engine = Enum.KeyCode.E,
		ThrottleUp = Enum.KeyCode.W,
		ThrottleDown = Enum.KeyCode.S,
		ThrottleIncrement = 0.5,
		Brake = Enum.KeyCode.B,
		LandingGear = Enum.KeyCode.G
	},

	Advanced = {
		PhysicsScale = 1,
		ClientControlled = true,
		ResetNetwork = true,
		LowestPoint = "Auto",
	},
}

return Presets
