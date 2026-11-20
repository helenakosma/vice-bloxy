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

	-- Subway Line 1 service.
	Transit = {
		Headway = 90, -- target seconds between trains (the number of trains is worked out from this)
		Cars = 4, -- cars per train
		Speed = 80, -- studs per second between stations
		Accel = 9, -- studs per second squared (speeding up and braking)
		Dwell = 10, -- seconds with doors open at a station
		TerminalDwell = 24, -- seconds at Finch and Portlands

		-- Random service delays. Every CheckEvery seconds (when no delay is running)
		-- one roll decides: most of the time nothing, sometimes a delay of a kind.
		-- The whole line slows to a stop over Ramp seconds, holds, then moves off.
		Delays = {
			CheckEvery = 60,
			Ramp = 3,
			Kinds = {
				{ Name = "MINOR DELAY", Chance = 0.12, Min = 5, Max = 10 },
				{ Name = "MODERATE DELAY", Chance = 0.06, Min = 10, Max = 20 },
				{ Name = "MAJOR DELAY", Chance = 0.02, Min = 20, Max = 35 },
			},
		},

		-- Station and on-train announcements (shown as captions).
		Announcements = {
			MinGap = 4, -- seconds between captions
			ShowFor = 5.5, -- seconds each caption stays up
			ReminderEvery = 75, -- "stand behind the yellow line" when it's quiet
		},

		-- Optional sounds: paste Roblox audio asset ids (0 = off).
		Sounds = {
			Chime = 0, -- before each announcement
			StationAmbience = 0, -- looped quietly while underground
			TrainRumble = 0, -- looped on every train (fades with distance)
			DoorChime = 0, -- when a train's doors are about to close
		},
	},

	-- Transit fares: a stored-value card from the ticket machines.
	Fares = {
		CardPrice = 5, -- cash for a new card
		StartBalance = 6, -- loaded on a new card
		LoadAmount = 20, -- each top-up
		Fare = 3, -- per subway entry or bus/streetcar boarding
		TransferSeconds = 120, -- after paying, rides in this window are free
	},

	-- City advertising (billboards, station screens, train ads).
	Ads = {
		RotateEvery = 20, -- seconds before each panel moves on to the next ad
	},
}
