-- Integration helper for RockAppearance. Requires each target template to have
-- AuthoredVariantMesh=true and one centered Body MeshPart as PrimaryPart.
-- RS.BlenderRockVariants[id].Normal / .Enchanted are source MeshParts.
-- Call immediately after variant normalization, before the legacy recolor path.
local RS=game:GetService('ReplicatedStorage')
return function(model,id,variant)
 if model:GetAttribute('AuthoredVariantMesh')~=true then return false end
 local library=RS:FindFirstChild('BlenderRockVariants')
 local family=library and library:FindFirstChild(id)
 local source=family and family:FindFirstChild(variant)
 local body=model.PrimaryPart
 assert(source and source:IsA('MeshPart') and body and body:IsA('MeshPart'),'Missing authored variant mesh: '..id..'/'..variant)
 -- Same body instance retains held/thrown/ability welds and attachments.
 -- Full authored geometry changes, including silhouette, details and palette.
 local size=source.Size*model:GetScale()
 if body:GetAttribute('AppliedAuthoredVariant')~=variant then
  body:ApplyMesh(source);body.Size=size;body.Color=Color3.new(1,1,1);body.Material=source.Material;body.Reflectance=source.Reflectance
  body:SetAttribute('AppliedAuthoredVariant',variant)
 end
 model:SetAttribute('Variant',variant);model:SetAttribute('Enchanted',variant=='Enchanted');model:SetAttribute('RockId',id)
 local aura=body:FindFirstChild('AuthoredEnchantedAura')
 if aura then aura:Destroy() end
 if variant=='Enchanted' then
  aura=Instance.new('Attachment');aura.Name='AuthoredEnchantedAura';aura.Parent=body
  local spark=Instance.new('ParticleEmitter');spark.Name='AuthoredSparkles';spark.Texture='rbxasset://textures/particles/sparkles_main.dds';spark.Rate=3;spark.Lifetime=NumberRange.new(.5,.9);spark.Speed=NumberRange.new(.1,.3);spark.SpreadAngle=Vector2.new(180,180);spark.LightEmission=.65;spark.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.3,.07),NumberSequenceKeypoint.new(1,0)});spark.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.25,.25),NumberSequenceKeypoint.new(1,1)});spark.Color=ColorSequence.new(Color3.fromRGB(204,245,255));spark.Parent=aura
 end
 return true
end
