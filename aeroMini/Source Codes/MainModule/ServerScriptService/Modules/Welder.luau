local Welder = {}

local function getParts(object, partsTable)
	-- If this folder/part has the ignore signal, STOP searching this entire branch
	if object:FindFirstChild("IgnoreWeld") then 
		return 
	end

	if object:IsA("BasePart") then
		table.insert(partsTable, object)
	end

	-- Recurse into children
	for _, child in ipairs(object:GetChildren()) do
		getParts(child, partsTable)
	end
end

function Welder.Weld(model, primaryPart)
	if not primaryPart then return end

	local weldFolder = primaryPart:FindFirstChild("Welds") or Instance.new("Folder")
	weldFolder.Name = "Welds"
	weldFolder.Parent = primaryPart

	local parts = {}
	getParts(model, parts)

	primaryPart.RootPriority = 10

	-- Anchor to prevent parts falling during welding
	for _, part in (parts) do
		part.Anchored = true
	end

	-- Time-Budgeted Loop (The "Anti-Timeout" Logic)
	local startTime = os.clock()
	local TIME_BUDGET = 0.002 -- 2ms per frame

	for _, part in (parts) do
		-- Safety check to prevent the script from hanging on massive models
		if os.clock() - startTime > TIME_BUDGET then
			task.wait()
			startTime = os.clock()
		end

		if part == primaryPart then continue end

		local weld = Instance.new("Weld")
		weld.Part0 = primaryPart
		weld.Part1 = part
		weld.C0 = primaryPart.CFrame:ToObjectSpace(part.CFrame)
		weld.Parent = weldFolder
	end

	for _, part in ipairs(parts) do
		part.Anchored = false
	end

	parts = nil
end

return Welder