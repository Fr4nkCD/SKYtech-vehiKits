-- Welder Module
-- by SKYtech

local Welder = {}

local os_clock = os.clock
local Instance_new = Instance.new

local function getParts(object, partsTable)
	if object:FindFirstChild("IgnoreWeld") then return end

	if object:IsA("BasePart") then
		table.insert(partsTable, object)
	end

	for _, child in object:GetChildren() do
		getParts(child, partsTable)
	end
end

function Welder.Weld(model, primaryPart)
	if not primaryPart then return end

	local weldFolder = primaryPart:FindFirstChild("Welds")
	if not weldFolder then
		weldFolder = Instance_new("Folder")
		weldFolder.Name = "Welds"
		weldFolder.Parent = primaryPart
	end

	local parts = {}
	getParts(model, parts)

	primaryPart.RootPriority = 10

	for _, part in parts do
		part.Anchored = true
	end

	local startTime = os_clock()
	for _, part in parts do
		if os_clock() - startTime > 0.002 then
			task.wait()
			startTime = os_clock()
		end

		if part ~= primaryPart then
			local weld = Instance_new("Weld")
			weld.Part0 = primaryPart
			weld.Part1 = part
			weld.C0 = primaryPart.CFrame:ToObjectSpace(part.CFrame)
			weld.Parent = weldFolder
		end
	end

	for _, part in parts do
		part.Anchored = false
	end
end

return Welder