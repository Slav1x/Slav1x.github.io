-- Custom Blender river props use the existing server-owned breakable lifecycle.
local A={}
function A.build(model,base,kind,query)
 local WorldArt=require(script.Parent.WorldArt)
 local zone=WorldArt.zone(base.Position)
 local role=(kind=='Log' or kind=='Driftwood') and 'RiverRelic_B' or 'RiverRelic_A'
 local p=WorldArt.mesh(model,WorldArt.riverName(zone.id,role),base*CFrame.new(0,-1.8,0)*CFrame.Angles(0,.35,0),.65)
 p.Name='BiomeWaterObstacle';p.CanQuery=query==true;p.CastShadow=false
 model:SetAttribute('AreaId',zone.id)
 model:SetAttribute('BreakableArtVersion',3)
 model:SetAttribute('WaterBreakable',true)
end
-- Normalize existing authored and generated breakables without changing their art.
-- They are hit only by WaterPickupService's swept, animated visual geometry.
function A.configure(model)
 local kind=model:GetAttribute("EncounterKind")
 if model:GetAttribute("WaterBreakable")~=true and model:GetAttribute("SkipObstacle")~=true
  and kind~="Log" and kind~="Rocks" then return false end
 model:SetAttribute("WaterBreakable",true)
 model:SetAttribute("PickupWaterlineOffset",model:GetAttribute("PickupWaterlineOffset") or 0)
 for _,p in model:GetDescendants() do
  if p:IsA("BasePart") then
   p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
  end
 end
 return true
end
return A