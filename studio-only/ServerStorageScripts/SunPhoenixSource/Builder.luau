local A=game:GetService('AssetService')
local Builder={}
function Builder.build(data)
local model=Instance.new('Model');model.Name='SunPhoenix_PremiumCandidate';model.Parent=nil
local root=Instance.new('Part');root.Name='PetRoot';root.Size=Vector3.new(.2,.2,.2);root.Transparency=1;root.Anchored=true;root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;root.Parent=model;model.PrimaryPart=root
model:SetAttribute('PetId','sun_phoenix');model:SetAttribute('VisualRevision',3);model:SetAttribute('ArticulatedPhoenix',true)
model:SetAttribute('TriangleCount',data.triangles);model:SetAttribute('BoneCount',#data.bones);model:SetAttribute('SculptedElements',data.features)
local summary={}
for material=0,2 do
 local used={};local faceList={}
 for i,f in data.faces do if data.materials[i]==material then table.insert(faceList,f);for _,v in f do used[v+1]=true end end end
 local mn=Vector3.new(math.huge,math.huge,math.huge);local mx=-mn
 for i in used do local p=Vector3.new(unpack(data.vertices[i]));mn=mn:Min(p);mx=mx:Max(p) end
 local center=(mn+mx)/2
 local em=A:CreateEditableMesh();local bs={};local bc={}
 for _,b in data.bones do
  local pos=Vector3.new(unpack(b.position));bc[b.name]=pos
  bs[b.name]=em:AddBone({Name=b.name,ParentId=b.parent and bs[b.parent] or nil,CFrame=CFrame.new(pos-center),Virtual=false})
 end
 local vs={};local colors={};local normals={}
 for i in used do
  vs[i]=em:AddVertex(Vector3.new(unpack(data.vertices[i]))-center)
  colors[i]=em:AddColor(Color3.new(unpack(data.colors[i])),1)
  normals[i]=em:AddNormal(Vector3.new(unpack(data.normals[i])))
  local ids={};local weights={};local total=0
  for bone,w in data.weights[i] do if w>0 then table.insert(ids,bs[bone]);table.insert(weights,w);total+=w end end
  for j,w in weights do weights[j]=w/total end
  em:SetVertexBones(vs[i],ids);em:SetVertexBoneWeights(vs[i],weights)
 end
 for _,f in faceList do
  local a,b,c=f[1]+1,f[2]+1,f[3]+1
  local id=em:AddTriangle(vs[a],vs[b],vs[c]);em:SetFaceColors(id,{colors[a],colors[b],colors[c]});em:SetFaceNormals(id,{normals[a],normals[b],normals[c]})
 end
 local result,content=A:CreateDataModelContentAsync(Content.fromObject(em))
 assert(result==Enum.CreateContentResult.Success,tostring(result))
 local part=A:CreateMeshPartAsync(content,{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise})
 part.Name=({'Plumage','FeatherFiligree','SolarGlow'})[material+1]
 part.CFrame=CFrame.new(center);part.Color=Color3.new(1,1,1);part.Material=if material==2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
 part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=material==0;part.DoubleSided=true;part.Parent=model
 part:SetAttribute('TriangleCount',#faceList)
 local instances={}
 for _,b in data.bones do
  local bone=Instance.new('Bone');bone.Name=b.name
  bone.CFrame=CFrame.new(bc[b.name]-(b.parent and bc[b.parent] or center))
  bone.Parent=b.parent and instances[b.parent] or part;instances[b.name]=bone
 end
 table.insert(summary,{name=part.Name,triangles=#faceList,bones=#data.bones})
 em:Destroy()
end

model:SetAttribute('PremiumReady',true)
require(game.ReplicatedStorage.Shared.PhoenixVFX).add(model)
return model
end
return Builder

