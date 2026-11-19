-- Tunable game settings shared by server and client.
return {
	StartingCash = 500,
	JobPayout = 150,
	JobCooldown = 10, -- seconds before a job pad can be used again by the same player

	Car = {
		MaxSpeed = 90, -- studs/second at full throttle
		Torque = 8000, -- motor torque per driven wheel (chassis is heavy, see Cars.lua)
		MaxSteerAngle = 30, -- degrees
		SteerSpeed = 3, -- how fast the wheels turn
		WheelRadius = 1.5,
		Color = Color3.fromRGB(255, 61, 154),
	},
}
