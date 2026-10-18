-- main.lua :: entry point, self-contained loader. fetches modules/*.lua from raw.githubusercontent
-- and builds them as real ModuleScripts at runtime, so this whole system runs off a single line:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/AstrodiR2/invincible-fly/main/main.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local RAW_BASE = "https://raw.githubusercontent.com/AstrodiR2/invincible-fly/main/"

local player = Players.LocalPlayer

local rootFolder = Instance.new("Folder")
rootFolder.Name = "InvincibleFlySystem"
rootFolder.Parent = game:GetService("ReplicatedStorage")

local modulesFolder = Instance.new("Folder")
modulesFolder.Name = "modules"
modulesFolder.Parent = rootFolder

local function fetchModule(name)
	local src = game:HttpGet(RAW_BASE .. "modules/" .. name .. ".lua")
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Source = src
	m.Parent = modulesFolder
	return m
end

local scriptFolder = modulesFolder

local Config = require(fetchModule("config"))
local Stages = require(fetchModule("flight_stages"))
local WallBreak = require(fetchModule("wall_break"))
local Dive = require(fetchModule("dive_sequence"))

local flying = false
local velocity = Vector3.new()
local bodyVel, bodyGyro
local rightShoulder, leftShoulder
local camera = workspace.CurrentCamera

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function setupFlight(character)
	local root = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")

	bodyVel = Instance.new("BodyVelocity")
	bodyVel.MaxForce = Config.MaxForce
	bodyVel.Velocity = Vector3.new()
	bodyVel.Parent = root

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(0, 0, 0) -- rotation handled manually in flight_stages via root.CFrame
	bodyGyro.Parent = root

	humanoid.PlatformStand = false
	rightShoulder, leftShoulder = Stages.Init(character)
	Dive.Init(character)

	return root, humanoid
end

local function teardownFlight(character)
	if bodyVel then bodyVel:Destroy() end
	if bodyGyro then bodyGyro:Destroy() end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		Stages.Reset(character, rightShoulder, leftShoulder)
	end
	velocity = Vector3.new()
	camera.FieldOfView = Config.FOVBase
end

-- Humanoid.MoveDirection already aggregates mobile touch thumbstick input, WASD and gamepad
-- thumbstick uniformly -- no need to hand-parse TouchMoved on phone.
local function getInputVector(humanoid, root)
	local moveDir = humanoid.MoveDirection -- world-space, zero if no input
	if moveDir.Magnitude < 0.05 then
		return Vector3.new()
	end
	return moveDir.Unit
end

local function onEquipped(tool, character)
	if tool.Name ~= Config.ItemName then return end
	flying = true
	setupFlight(character)
end

local function onUnequipped(tool, character)
	if tool.Name ~= Config.ItemName then return end
	flying = false
	teardownFlight(character)
end

local function bindCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Changed:Connect(function() end) -- placeholder keep-alive, not required

	-- jump = vertical thrust while flying (double-tap not needed, hold space/jump button)
	local jumpHeld = false
	UserInputService.JumpRequest:Connect(function()
		if flying then
			jumpHeld = true
			task.delay(0.15, function() jumpHeld = false end)
		end
	end)

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			child.Equipped:Connect(function() onEquipped(child, character) end)
			child.Unequipped:Connect(function() onUnequipped(child, character) end)
		end
	end)

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			child.Equipped:Connect(function() onEquipped(child, character) end)
			child.Unequipped:Connect(function() onUnequipped(child, character) end)
		end
	end

	return function() return jumpHeld end
end

local getJumpHeld

local function onCharacterAdded(character)
	getJumpHeld = bindCharacter(character)
end

onCharacterAdded(getCharacter())
player.CharacterAdded:Connect(onCharacterAdded)

RunService.RenderStepped:Connect(function(dt)
	if not flying then return end
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or not bodyVel then return end

	local inputDir = getInputVector(humanoid, root)
	local vertical = 0
	if getJumpHeld and getJumpHeld() then
		vertical = 1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		vertical = -1
	end

	local hasInput = inputDir.Magnitude > 0.05 or vertical ~= 0

	if hasInput then
		local accel = Vector3.new(inputDir.X, vertical * 0.6, inputDir.Z) * Config.Accel * dt
		velocity = velocity + accel
	else
		-- inertia: decay toward zero instead of instant stop
		velocity = velocity * Config.Damping
		if velocity.Magnitude < 0.5 then
			velocity = Vector3.new()
		end
	end

	-- dive sequence can override/boost speed when falling from height past softcap
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local adjusted = Dive.ProcessDive(root, velocity.Magnitude, dt)
	if adjusted > velocity.Magnitude then
		velocity = velocity.Unit * adjusted
	end

	bodyVel.Velocity = velocity

	local stage = Stages.Apply(character, root, rightShoulder, leftShoulder, velocity, dt, humanoid)

	if stage == 4 then
		WallBreak.Check(character, velocity)
	end

	camera.FieldOfView = Config.FOVBase + Dive.GetFOVBonus(velocity.Magnitude)
end)



