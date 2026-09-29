--!strict
-- Shared by held rocks, in-flight rocks, predictions, and optional viewports.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityVisuals = {}
function AbilityVisuals.clear(rock: Model)
	local old = rock:FindFirstChild("EquippedAbilityVisual")
	if old then old:Destroy() end
	rock:SetAttribute("AttachedAbility", nil)
end
function AbilityVisuals.attach(rock: Model, abilityId: string?): Model?
	local old = rock:FindFirstChild("EquippedAbilityVisual")
	if old and old:IsA("Model") and old:GetAttribute("AbilityId") == abilityId then return old end
	AbilityVisuals.clear(rock)
	if not abilityId or abilityId == "" then return nil end
	local library = ReplicatedStorage:FindFirstChild("AbilityModels")
	local template = library and library:FindFirstChild(abilityId)
	local root = rock.PrimaryPart or rock:FindFirstChildWhichIsA("BasePart", true)
	if not template or not template:IsA("Model") or not root then return nil end
	local _, bounds = rock:GetBoundingBox()
	local sizeScale = math.clamp(math.max(bounds.X / 1.35, bounds.Z / 1.65), 0.35, 8)
	local model = template:Clone()
	model.Name = "EquippedAbilityVisual"
	model:SetAttribute("AbilityId", abilityId)
	model:ScaleTo(template:GetScale() * sizeScale)
	model:PivotTo(rock:GetPivot())
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = root.Anchored
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part.CollisionGroup = root.CollisionGroup
			local weld = Instance.new("WeldConstraint")
			weld.Name = "AbilityMountWeld"
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		elseif part:IsA("ParticleEmitter") or part:IsA("Light") then
			part.Enabled = false
		elseif part:IsA("LuaSourceContainer") then
			part:Destroy()
		end
	end
	model.Parent = rock
	rock:SetAttribute("AttachedAbility", abilityId)
	return model
end
function AbilityVisuals.setActive(rock: Model, active: boolean)
	rock:SetAttribute("JetpackActive", active)
	local model = rock:FindFirstChild("EquippedAbilityVisual")
	if not model then return end
	for _, item in model:GetDescendants() do
		if item:IsA("ParticleEmitter") or item:IsA("Light") then
			item.Enabled = active and model:GetAttribute("AbilityId") == "jetpack_rock"
		end
	end
end
return AbilityVisuals
