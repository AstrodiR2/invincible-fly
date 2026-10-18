-- config.lua :: shared tunables, one block, edit here not in logic
local Config = {}

Config.ItemName = "Invincible Visor" -- Tool name in Backpack/Character that triggers the flight ability when equipped

-- speed thresholds (studs/s). roblox ~ 1 stud ~= 0.28m, km/h->studs/s roughly *1
Config.Stage1Max = 0   -- hover only
Config.Stage2Max = 50
Config.Stage3Max = 250
Config.Stage4Max = 700 -- soft-cap after this, see dive_sequence

Config.MaxForce = Vector3.new(1e6, 1e6, 1e6)
Config.Accel = 120       -- studs/s^2 while input held
Config.Damping = 0.92    -- per-frame velocity decay when input released (inertia)
Config.TiltMaxStage2 = 25 -- degrees, lean while flying 0-50
Config.TiltStage3 = 90    -- degrees, full forward tilt 50-250
Config.TiltStage4 = 90

Config.FOVBase = 70
Config.FOVPerSpeed = 0.04 -- fov += speed * this
Config.FOVMax = 120

-- dive sequence
Config.SpawnTrackHeight = 2000 -- studs above spawn that counts as "launch point" for dive accumulation
Config.DiveSoftCapBase = 750
Config.DiveParticleHigh = 700 -- studs above spawn: blue particles start
Config.DiveParticleComet = 400 -- studs above spawn: comet trail
Config.ReturnRadius = 50 -- studs from spawn
Config.FlashInTime = 0.5
Config.FlashOutTime = 0.4
Config.WorldHideDuration = 60

Config.WallBreakEnabled = true
Config.DebrisCount = 10

return Config
