local Presets = {
	AircraftStatistics = {
		Stability = 0.5,
		SymmetricalAirfoil = false,
		Drag = 1,
		MaxSpeed = 350,
		MaxSpeedSL = 275,
		StallSpeed = 120,
		ChangedbyAltitude = true,
		MaxAltitude = 45000,
	},

	AttitudeControls = {
		LimitAngle = false,
		MaxBank = 45,
		MaxPitch = 30,
		RollSpeed = 12,
		PitchSpeed = 4.5,
		YawSpeed = 2.4,
		TorqueResponsiveness = 0.8,
		TurningRate = 1,
	},

	Advanced = {
		PhysicsScale = 1,
		ClientControlled = true,
		ResetNetwork = true,
		LowestPoint = "Auto",
	},
}

return Presets
