-- flight_stages.lua :: pose + tilt + arm position per speed stage
local Config = require(script.Parent:WaitForChild("config"))

local Stages = {}

-- cache original Motor6D C0 so we can lerp back to idle pose when speed drops to 0
local originalC0 = {}

local function getMotor(character, name)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then return nil end
	for _, child in ipairs(torso:GetChildren()) do
		if child:IsA("Motor6D") and child.Name == name then
			return child
		end
	end
	return nil
end

function Stages.Init(character)
	local rightShoulder = getMotor(character, "RightShoulder") or getMotor(character, "Right Shoulder")
	local leftShoulder = getMotor(character, "LeftShoulder") or getMotor(character, "Left Shoulder")
	if rightShoulder then originalC0[rightShoulder] = rightShoulder.C0 end
	if leftShoulder then originalC0[leftShoulder] = leftShoulder.C0 end
	return rightShoulder, leftShoulder
end

-- returns stage number 1-4 for a given horizontal speed
function Stages.GetStage(speed)
	if speed <= Config.Stage1Max then
		return 1
	elseif speed <= Config.Stage2Max then
		return 2
	elseif speed <= Config.Stage3Max then
		return 3
	else
		return 4
	end
end

-- applies tilt (root CFrame orientation) and arm pose (Motor6D C0) for current stage/speed
function Stages.Apply(character, root, rightShoulder, leftShoulder, velocity, dt, humanoid)
	local speed = velocity.Magnitude
	local stage = Stages.GetStage(speed)
	local flatDir = Vector3.new(velocity.X, 0, velocity.Z)
	local hasHorizontal = flatDir.Magnitude > 1

	local targetTilt = 0 -- degrees, pitch forward around root's right axis
	local armAngle = 0   -- degrees, shoulder raise

	if stage == 1 then
		targetTilt = 0
		armAngle = 0
	elseif stage == 2 then
		local t = math.clamp(speed / Config.Stage2Max, 0, 1)
		targetTilt = t * Config.TiltMaxStage2
		armAngle = 0
	elseif stage == 3 then
		targetTilt = Config.TiltStage3
		armAngle = 180 -- right arm only
		humanoid.AutoRotate = false -- "шифтлок" auto-enabled: character locks facing flight dir manually below
	elseif stage == 4 then
		targetTilt = Config.TiltStage4
		armAngle = 180 -- both arms
		humanoid.AutoRotate = false
	end

	if stage < 3 then
		humanoid.AutoRotate = true
	end

	-- orient root: face flight direction, pitch by targetTilt
	if hasHorizontal and stage > 1 then
		local lookCFrame = CFrame.lookAt(root.Position, root.Position + flatDir.Unit)
		local pitch = CFrame.Angles(math.rad(-targetTilt), 0, 0)
		local goal = lookCFrame * pitch
		root.CFrame = root.CFrame:Lerp(goal, math.clamp(dt * 8, 0, 1))
	elseif stage == 1 then
		-- stage 1: upright hover, zero out any residual tilt
		local upright = CFrame.new(root.Position) * CFrame.Angles(0, root.CFrame:ToEulerAnglesXYZ(), 0)
		-- simpler: lerp orientation back to flat (keep current Y rotation, zero X/Z)
		local _, yRot, _ = root.CFrame:ToEulerAnglesYXZ()
		local goal = CFrame.new(root.Position) * CFrame.Angles(0, yRot, 0)
		root.CFrame = root.CFrame:Lerp(goal, math.clamp(dt * 6, 0, 1))
	end

	-- arms
	local rightGoal = originalC0[rightShoulder]
	local leftGoal = originalC0[leftShoulder]

	if rightShoulder and originalC0[rightShoulder] then
		if stage >= 3 then
			rightGoal = originalC0[rightShoulder] * CFrame.Angles(0, 0, math.rad(-armAngle))
		end
		rightShoulder.C0 = rightShoulder.C0:Lerp(rightGoal, math.clamp(dt * 6, 0, 1))
	end

	if leftShoulder and originalC0[leftShoulder] then
		if stage == 4 then
			leftGoal = originalC0[leftShoulder] * CFrame.Angles(0, 0, math.rad(armAngle))
		end
		leftShoulder.C0 = leftShoulder.C0:Lerp(leftGoal, math.clamp(dt * 6, 0, 1))
	end

	return stage
end

function Stages.Reset(character, rightShoulder, leftShoulder)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.AutoRotate = true end
	if rightShoulder and originalC0[rightShoulder] then
		rightShoulder.C0 = originalC0[rightShoulder]
	end
	if leftShoulder and originalC0[leftShoulder] then
		leftShoulder.C0 = originalC0[leftShoulder]
	end
end

return Stages
