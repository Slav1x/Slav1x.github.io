--!nonstrict
-- One distance-culled update for every streamed encounter rig. No per-animal loops.
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Player=game:GetService('Players').LocalPlayer
local Motion=require(RS.Shared.PrimateMotion)
local rigs={}
local function add(item)
 if item:IsA('Model') and item:GetAttribute('PrimateArtVersion')==1 then rigs[item]=true end
end
for _,item in workspace:GetDescendants() do add(item) end
workspace.DescendantAdded:Connect(add)
Run.PreSimulation:Connect(function()
 local camera=workspace.CurrentCamera;if not camera then return end
 local now=workspace:GetServerTimeNow();local reduced=Player:GetAttribute('ReducedMotion')==true
 for model in rigs do
  if not model:IsDescendantOf(workspace) then rigs[model]=nil
  elseif model.PrimaryPart and (model.PrimaryPart.Position-camera.CFrame.Position).Magnitude<360 then
   Motion.apply(model,Motion.poseAt(model,now,reduced))
  end
 end
end)
