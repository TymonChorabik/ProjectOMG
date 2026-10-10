--[[
	TrainingPads.luau
	The training floors' pads (like the throwing pads at the Stone Skipping ponds): where they
	are and who is standing on one. Used by the server (TrainingService grants Strength to
	anyone on an unlocked pad) and the client (animation, hiding the other players on your pad).

	Map layout read here: Workspace.Map.TrainingZones.Zone_<Id> (ZoneId attribute) with a
	"TrainPad" part and an optional "Target" model (the item that gets chopped).
]]

local TrainingPads = {}

-- How high above the pad still counts as standing on it (jumping keeps you training).
TrainingPads.HEIGHT = 12

export type Pad = {
	ZoneId: string,
	Part: BasePart,
	Target: Model?,
	Model: Instance,
}

function TrainingPads.Collect(map: Instance): { Pad }
	local pads: { Pad } = {}
	local zones = map:FindFirstChild("TrainingZones")
	if not zones then
		return pads
	end
	for _, zoneModel in zones:GetChildren() do
		local part = zoneModel:FindFirstChild("TrainPad")
		local zoneId = zoneModel:GetAttribute("ZoneId")
		if part and part:IsA("BasePart") and type(zoneId) == "string" then
			local target = zoneModel:FindFirstChild("Target")
			table.insert(pads, {
				ZoneId = zoneId,
				Part = part,
				Target = if target and target:IsA("Model") then target else nil,
				Model = zoneModel,
			})
		end
	end
	return pads
end

function TrainingPads.Contains(part: BasePart, position: Vector3): boolean
	local point = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(point.X) <= half.X + 0.25
		and math.abs(point.Z) <= half.Z + 0.25
		and point.Y >= -1
		and point.Y <= TrainingPads.HEIGHT
end

-- The pad `position` is standing on, if any.
function TrainingPads.At(pads: { Pad }, position: Vector3): Pad?
	for _, pad in pads do
		if TrainingPads.Contains(pad.Part, position) then
			return pad
		end
	end
	return nil
end

return TrainingPads
