-- Native Roblox model preview for inventory, index and hatch results.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local library=ReplicatedStorage:WaitForChild("BGCPetPreviewModels")
local PetViewport={}

function PetViewport.populate(viewport,modelName)
 for _,child in ipairs(viewport:GetChildren()) do
  if child:IsA("Camera") or child:IsA("WorldModel") then child:Destroy() end
 end
 local source=library:FindFirstChild(modelName)
 if not source or not source:IsA("Model") then return false end
 local world=Instance.new("WorldModel")
 world.Name="PetWorld"
 world.Parent=viewport
 local model=source:Clone()
 model:PivotTo(CFrame.identity)
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Anchored=true
   part.CanCollide=false
   part.CanTouch=false
   part.CanQuery=false
  end
 end
 model.Parent=world
 local bounds,size=model:GetBoundingBox()
 local radius=math.max(size.X,size.Y,size.Z)
 local camera=Instance.new("Camera")
 camera.Name="PetCamera"
 camera.FieldOfView=35
 camera.CFrame=CFrame.lookAt(bounds.Position+Vector3.new(0,size.Y*.08,-radius*1.85),bounds.Position)
 camera.Parent=viewport
 viewport.CurrentCamera=camera
 return true
end
return PetViewport

