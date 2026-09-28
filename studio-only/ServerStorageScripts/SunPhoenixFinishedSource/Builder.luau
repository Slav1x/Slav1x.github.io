-- Exact transfer of Sun_Phoenix.blend geometry, skin weights and palette.
-- Uses the project's existing DataModel-content bootstrap, once per server.
local AssetService=game:GetService('AssetService')
local Builder={}
function Builder.build(data)
 assert(data.schema=='SunPhoenixFinishedMeshV1','Unexpected Sun Phoenix source schema')
 local model=Instance.new('Model'); model.Name='SunPhoenix_ImportCandidate'
 local root=Instance.new('Part'); root.Name='PetRoot'; root.Size=Vector3.new(.2,.2,.2)
 root.Transparency=1; root.Anchored=true; root.CanCollide=false; root.CanTouch=false; root.CanQuery=false; root.Parent=model; model.PrimaryPart=root
 local em=assert(AssetService:CreateEditableMesh(),'EditableMesh allocation failed')
 local mn=Vector3.new(math.huge,math.huge,math.huge);local mx=-mn
 for _,v in data.vertices do local p=Vector3.new(unpack(v));mn=mn:Min(p);mx=mx:Max(p) end
 local center=(mn+mx)/2
 local boneIds={}
 for _,b in data.bones do
  boneIds[b.name]=em:AddBone({Name=b.name,ParentId=b.parent and boneIds[b.parent] or nil,CFrame=CFrame.new(-center)*CFrame.new(unpack(b.global)),Virtual=false})
 end
 local vertexIds={}
 for i,v in data.vertices do
  local id=em:AddVertex(Vector3.new(unpack(v))-center); vertexIds[i]=id
  local ids,weights={},{}
  for name,weight in data.weights[i] do table.insert(ids,boneIds[name]); table.insert(weights,weight) end
  em:SetVertexBones(id,ids); em:SetVertexBoneWeights(id,weights)
 end
 local palette={}
 for i,f in data.faces do
  local id=em:AddTriangle(vertexIds[f[1]+1],vertexIds[f[2]+1],vertexIds[f[3]+1])
  local c=data.colors[i]; local key=table.concat(c,','); local color=palette[key]
  if not color then color=em:AddColor(Color3.new(unpack(c)),1); palette[key]=color end
  em:SetFaceColors(id,{color,color,color})
  local n=em:AddNormal(Vector3.new(unpack(data.normals[i]))); em:SetFaceNormals(id,{n,n,n})
  local u={};for _,uv in data.uvs[i] do table.insert(u,em:AddUV(Vector2.new(unpack(uv)))) end
  em:SetFaceUVs(id,u)
 end
 local result,content=AssetService:CreateDataModelContentAsync(Content.fromObject(em))
 assert(result==Enum.CreateContentResult.Success,'Mesh content failed: '..tostring(result))
 local mesh=AssetService:CreateMeshPartAsync(content,{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise})
 mesh.Name='Plumage';mesh.CFrame=CFrame.new(center);mesh.Color=Color3.new(1,1,1);mesh.Material=Enum.Material.SmoothPlastic
 mesh.Anchored=true;mesh.Massless=true;mesh.CanCollide=false;mesh.CanTouch=false;mesh.CanQuery=false;mesh.CastShadow=true;mesh.DoubleSided=false;mesh.Parent=model
 local bones={}
 for _,b in data.bones do
  local bone=Instance.new('Bone');bone.Name=b.name;bone.CFrame=CFrame.new(unpack(b['local']))
  if not b.parent then bone.CFrame=CFrame.new(-center)*bone.CFrame end
  bone.Parent=b.parent and bones[b.parent] or mesh; bones[b.name]=bone
 end
 local controller=Instance.new('AnimationController');controller.Name='AnimationController';controller.Parent=model
 local animator=Instance.new('Animator');animator.Parent=controller
 model:SetAttribute('PetId','sun_phoenix');model:SetAttribute('VisualRevision',4)
 model:SetAttribute('ArticulatedPhoenix',true);model:SetAttribute('PremiumReady',true)
 model:SetAttribute('TriangleCount',data.triangles);model:SetAttribute('BoneCount',#data.bones)
 model:SetAttribute('HoverClip','SunPhoenix_Hover_48f');model:SetAttribute('HoverDuration',1.6)
 model:SetAttribute('SourceFile',data.source);model:SetAttribute('ImportScale',data.scale)
 model:SetAttribute('PaletteMode','Original palette baked to face colors; original UVs retained')
 model:SetAttribute('ForwardAxis','-Z');model:SetAttribute('SculptedElements',0)
 require(game.ReplicatedStorage.Shared.PhoenixVFX).add(model)
 em:Destroy()
 return model
end
return Builder
