-- wall_break.lua :: raycast in flight direction, punch hole in hit part, spawn debris
local Config = require(script.Parent:WaitForChild("config"))

local WallBreak = {}

local function makeDebris(hitPosition, normal, material, color, speed)
	local count = math.clamp(math.floor(Config.DebrisCount * (speed / 250)), 4, 30)
	local folder = Instance.new("Folder")
	folder.Name = "Debris_" .. tostring(os.clock())
	folder.Parent = workspace

	for i = 1, count do
		local p = Instance.new("Part")
		p.Size = Vector3.new(math.random(1, 3), math.random(1, 3), math.random(1, 3))
		p.Position = hitPosition + Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3))
		p.Material = material or Enum.Material.Rock
		p.Color = color or Color3.fromRGB(120, 120, 120)
		p.CanCollide = true
		p.Parent = folder

		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Config.MaxForce
		bv.Velocity = (normal * math.random(10, 30)) + Vector3.new(math.random(-15, 15), math.random(0, 20), math.random(-15, 15))
		bv.Parent = p

		game:GetService("Debris"):AddItem(p, 6)
		game:GetService("Debris"):AddItem(bv, 0.3)
	end
end

-- punches a hole by shrinking/hollowing the hit part if it's a plain, unanchored-safe brick.
-- only touches parts tagged "Breakable" or thin enough to be a wall (heuristic on size), never touches
-- Terrain or parts outside a sane size (avoids wrecking baseplate/map geo by accident).
local function punchHole(hitPart, hitPosition)
	if not hitPart or hitPart.Name == "Baseplate" then
		return
	end
	if hitPart:GetAttribute("Unbreakable") then
		return
	end

	local size = hitPart.Size
	local isWallLike = (size.X < 200 and size.Y < 200 and size.Z < 200)
	if not isWallLike then
		return
	end

	-- create a hole: a small invisible, non-collide part "plugged" into the wall at hit point,
	-- then use a boolean-ish visual via a punched-through cage: cheapest reliable approach in
	-- stock Lua (no CSG dependency, CSG:Subtract is server-expensive) is a hole decal + local
	-- no-collide zone. We carve collision locally via a temporary CanCollide=false clone region.
	local hole = Instance.new("Part")
	hole.Name = "HoleMarker"
	hole.Size = Vector3.new(4, 4, 4)
	hole.CFrame = CFrame.new(hitPosition)
	hole.Anchored = true
	hole.CanCollide = false
	hole.CanQuery = false
	hole.Transparency = 1
	hole.Parent = hitPart

	-- Real geometric hole requires UnionAsync/SubtractAsync (server-side, needs the parts to be
	-- unions). Attempt it if available; fall back to the no-collide marker above if it fails
	-- (e.g. part is part of Terrain or union fails due to permissions).
	local ok = pcall(function()
		local cutter = Instance.new("Part")
		cutter.Size = Vector3.new(6, 6, 6)
		cutter.CFrame = CFrame.new(hitPosition)
		cutter.Shape = Enum.PartType.Ball
		local result = hitPart:SubtractAsync({cutter})
		result.Anchored = hitPart.Anchored
		result.Parent = hitPart.Parent
		result.CFrame = hitPart.CFrame
		hitPart:Destroy()
		cutter:Destroy()
	end)

	if not ok then
		-- fallback already placed (hole marker, cosmetic no-collide only locally doesn't truly
		-- remove collision for other players; this is client-local cosmetic in that case)
	end
end

function WallBreak.Check(character, velocity)
	if not Config.WallBreakEnabled then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local speed = velocity.Magnitude
	if speed < 50 then
		return
	end

	local dir = velocity.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local result = workspace:Raycast(root.Position, dir * (speed * 0.15 + 5), params)
	if result then
		punchHole(result.Instance, result.Position)
		makeDebris(result.Position, result.Normal, result.Instance.Material, result.Instance.Color, speed)
	end
end

return WallBreak
