local Presets = {
	AircraftStatistics = {
		RateOfClimb = 30,
		MaxSpeed = 200,
		MaxAltitude = 45000,
		FuelConsumption = 0.05,
	},

	AttitudeControls = {
		LimitAngle = false,
		MaxBank = 45,
		MaxPitch = 45,
		Hover = true,
		RollSpeed = 8,
		PitchSpeed = 8,
		YawSpeed = 8,
		TurningRate = 1,
		TorqueResponsiveness = 1,
	},

	Advanced = {
		PhysicsScale = 1,
		ClientControlled = true,
		ResetNetwork = true,
	},
}

return Presets
