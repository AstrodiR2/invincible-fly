-- dive_sequence.lua :: launch-and-dive mechanic: accumulate speed past softcap diving from height,
-- comet particles, whiteout + temporary world hide on return to spawn at high speed
local Config = require(script.Parent:WaitForChild("config"))
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Dive = {}

local player = Players.LocalPlayer
local spawnPosition = nil -- set on first Init call (character spawn point)

local particlesHigh, particlesComet = nil, nil
local flashGui = nil

local worldHidden = false

function Dive.Init(character)
	local root = character:WaitForChild("HumanoidRootPart")
	if not spawnPosition then
		spawnPosition = root.Position
	end

	-- particle emitters, parented to root, disabled by default
	particlesHigh = Instance.new("ParticleEmitter")
	particlesHigh.Name = "DiveParticlesHigh"
	particlesHigh.Color = ColorSequence.new(Color3.fromRGB(60, 140, 255))
	particlesHigh.Size = NumberSequence.new(0.6)
	particlesHigh.Lifetime = NumberRange.new(0.4, 0.8)
	particlesHigh.Rate = 0
	particlesHigh.Speed = NumberRange.new(2, 6)
	particlesHigh.Parent = root

	particlesComet = Instance.new("ParticleEmitter")
	particlesComet.Name = "DiveParticlesComet"
	particlesComet.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
	particlesComet.Size = NumberSequence.new(1.4, 0.2)
	particlesComet.Lifetime = NumberRange.new(0.6, 1.0)
	particlesComet.Rate = 0
	particlesComet.Speed = NumberRange.new(4, 10)
	particlesComet.Parent = root

	-- screen flash gui
	local pg = player:WaitForChild("PlayerGui")
	flashGui = pg:FindFirstChild("DiveFlashGui")
	if not flashGui then
		flashGui = Instance.new("ScreenGui")
		flashGui.Name = "DiveFlashGui"
		flashGui.IgnoreGuiInset = true
		flashGui.DisplayOrder = 1000
		flashGui.Parent = pg

		local frame = Instance.new("Frame")
		frame.Name = "Flash"
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Parent = flashGui
	end
end

-- heightAboveSpawn: root.Position.Y - spawnPosition.Y
-- returns adjusted speed (soft-capped accumulation when diving from height)
function Dive.ProcessDive(root, currentSpeed, dt)
	if not spawnPosition then
		return currentSpeed
	end

	local height = root.Position.Y - spawnPosition.Y
	local falling = root.AssemblyLinearVelocity.Y < -5

	local adjustedSpeed = currentSpeed

	if falling and height > 0 and currentSpeed >= Config.DiveSoftCapBase then
		-- soft asymptotic growth past the cap: approaches infinity slowly, never hard-caps
		-- formula: extra = base * ln(1 + height/spawnTrackHeight) tempered by dt-based accumulation
		local gainFactor = math.min(height / Config.SpawnTrackHeight, 3)
		local target = Config.DiveSoftCapBase + (Config.DiveSoftCapBase * math.log(1 + gainFactor) * 1.5)
		adjustedSpeed = currentSpeed + (target - currentSpeed) * math.clamp(dt * 0.5, 0, 1)
	end

	-- particle thresholds (height above spawn while diving)
	if particlesHigh then
		particlesHigh.Rate = (height > Config.DiveParticleHigh and falling) and 40 or 0
	end
	if particlesComet then
		particlesComet.Rate = (height > Config.DiveParticleComet and falling and currentSpeed > Config.DiveSoftCapBase) and 80 or 0
	end

	-- return-to-spawn check: close to spawn horizontally+vertically, high speed, still falling
	local distFromSpawn = (root.Position - spawnPosition).Magnitude
	if falling and distFromSpawn <= Config.ReturnRadius and currentSpeed > Config.DiveSoftCapBase and not worldHidden then
		Dive.TriggerWorldHide()
	end

	return adjustedSpeed
end

function Dive.TriggerWorldHide()
	if worldHidden then return end
	worldHidden = true

	local frame = flashGui.Flash
	local tweenIn = TweenService:Create(frame, TweenInfo.new(Config.FlashInTime, Enum.EasingStyle.Sine), {BackgroundTransparency = 0})
	tweenIn:Play()

	tweenIn.Completed:Wait()

	-- hide all players + their characters
	local hidden = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(hidden, {part, part.Transparency, part.CanCollide})
					part.Transparency = 1
					part.CanCollide = false
				elseif part:IsA("Decal") then
					table.insert(hidden, {part, part.Transparency})
					part.Transparency = 1
				end
			end
		end
	end

	local tweenOut = TweenService:Create(frame, TweenInfo.new(Config.FlashOutTime, Enum.EasingStyle.Sine), {BackgroundTransparency = 1})
	tweenOut:Play()

	task.delay(Config.WorldHideDuration, function()
		for _, entry in ipairs(hidden) do
			local inst = entry[1]
			if inst and inst.Parent then
				inst.Transparency = entry[2]
				if entry[3] ~= nil then
					inst.CanCollide = entry[3]
				end
			end
		end
		worldHidden = false
	end)
end

function Dive.GetFOVBonus(speed)
	return math.clamp(speed * Config.FOVPerSpeed, 0, Config.FOVMax - Config.FOVBase)
end

return Dive
