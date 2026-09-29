-- Server-driven models stay off-world except on their owner's client.
local Registry={}
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local storage=game:GetService("ReplicatedStorage"):WaitForChild("SummonScenes")
local root=Instance.new("Folder")
root.Name="LocalSummonScenes";root.Parent=workspace
local prefix=tostring(player.UserId).."_"
local function mount(scene)
 if scene:IsA("Folder") and scene.Name:sub(1,#prefix)==prefix then
  scene.Parent=root
 end
end
storage.ChildAdded:Connect(mount)
for _,scene in storage:GetChildren() do mount(scene) end
function Registry.get(token)
 return root:FindFirstChild(prefix..tostring(token))
end
function Registry.find(token,slot,result)
 local scene=Registry.get(token)
 if not scene then return nil end
 for _,model in scene:GetChildren() do
  if model:IsA("Model")
   and model:GetAttribute(result and "SummonResultToken" or "SummonToken")==token
   and model:GetAttribute(result and "SummonResultSlot" or "SummonSlot")==slot then
   return model
  end
 end
 return nil
end
function Registry.fadeOut(token,duration)
 local scene=Registry.get(token)
 if not scene then return end
 local Tween=game:GetService("TweenService")
 for _,object in scene:GetDescendants() do
  if object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture") then
   Tween:Create(object,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency=1}):Play()
  elseif object:IsA("ParticleEmitter") then
   object.Enabled=false
   object:Clear()
  elseif object:IsA("Trail") then
   object.Enabled=false
   object:Clear()
  elseif object:IsA("Beam") then
   object.Enabled=false
  elseif object:IsA("Light") then
   Tween:Create(object,TweenInfo.new(duration),{Brightness=0}):Play()
  end
 end
 task.delay(duration,function() scene:Destroy() end)
end
return Registry