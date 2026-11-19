-- Tunable game settings shared by server and client.
return {
	StartingCash = 500,
	JobPayout = 150,
	JobCooldown = 10, -- seconds before the job marker can be used again by the same player

	DayNight = {
		Enabled = true,
		StartTime = 17.0, -- golden hour
		DayLengthMinutes = 24, -- a full day/night cycle in real minutes
	},

	Car = {
		-- Engine and brakes (studs/s and studs/s^2). 1 stud/s is roughly 0.63 mph.
		MaxSpeed = 140,
		Acceleration = 46,
		ReverseMaxSpeed = 32,
		ReverseAcceleration = 30,
		BrakeDecel = 110,
		HandbrakeDecel = 70,
		CoastDecel = 7,
		AirDrag = 0.0003,

		-- Steering (degrees). The angle shrinks as speed rises, like a real car.
		MaxSteerAngle = 34,
		HighSpeedSteerAngle = 7,
		SteerRate = 110, -- degrees per second while steering
		SteerReturnRate = 160, -- degrees per second back to centre

		-- Tyres
		TireFriction = 1.25, -- limits total grip (friction circle)
		FrontGrip = 0.9,
		RearGrip = 0.85,
		HandbrakeGrip = 0.18, -- rear grip with the handbrake on, for drifts
		RollInfluence = 0.25, -- 0 = no body roll from cornering forces, 1 = full

		-- Suspension
		WheelRadius = 1.35,
		SuspensionRest = 2.0,
		SpringFrequency = 2.0, -- Hz; higher is stiffer
		DampingRatio = 0.55,

		MphPerStud = 0.63,
	},
}
