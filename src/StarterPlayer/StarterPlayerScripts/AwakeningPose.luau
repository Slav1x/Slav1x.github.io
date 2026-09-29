-- Procedural reach supports R6 and R15 without an unpublished animation asset.
local Run=game:GetService("RunService")
local Pose={}
function Pose.begin(character,folder,contact)
 local self={motors={},scripts={},faces={},eyes=0,weight=0}
 local hum=character:FindFirstChildOfClass("Humanoid")
 local root=character:FindFirstChild("HumanoidRootPart")
 local head=character:FindFirstChild("Head")
 for _,v in character:GetDescendants() do
  if v:IsA("LocalScript") and (v.Name=="Animate" or v.Name=="AmbientIdle") then
   self.scripts[v]=v.Enabled;v.Enabled=false
  elseif v:IsA("Motor6D") or v:IsA("AnimationConstraint") then
   table.insert(self.motors,{joint=v,base=v.Transform,key=v.Name:gsub(" ","")})
  elseif v:IsA("Decal") and v.Parent==head and v.Face==Enum.NormalId.Front then self.faces[v]=v.Transparency end
 end
 local animator=hum and hum:FindFirstChildOfClass("Animator")
 if animator then for _,track in animator:GetPlayingAnimationTracks() do track:Stop(.18) end end
 local face=head and head:FindFirstChildOfClass("FaceControls")
 if face then
  pcall(function() self.left=face.LeftEyeClosed;self.right=face.RightEyeClosed end)
 end
 local eyeGui
 if head and not face then
  eyeGui=Instance.new("SurfaceGui");eyeGui.Name="AwakeningClosedEyes";eyeGui.Adornee=head
  eyeGui.Face=Enum.NormalId.Front;eyeGui.CanvasSize=Vector2.new(200,100);eyeGui.LightInfluence=.2;eyeGui.Parent=folder
  eyeGui.Enabled=false
  for _,x in {.32,.68} do
   for i=-2,2 do
    local line=Instance.new("Frame");line.BorderSizePixel=0;line.BackgroundColor3=Color3.fromRGB(32,30,40)
    line.AnchorPoint=Vector2.new(.5,.5);line.Size=UDim2.fromOffset(6,2.5)
    line.Position=UDim2.fromScale(x+i*.023,.47+(.04-i*i*.007));line.Rotation=-i*9;line.Parent=eyeGui
   end
  end
 end
 local target=Instance.new("Part");target.Name="PalmTarget";target.Size=Vector3.one*.1;target.Transparency=1
 target.Anchored=true;target.CanCollide=false;target.CanTouch=false;target.CanQuery=false
 target.CFrame=contact;target.Parent=folder
 local ik
 if hum and character:FindFirstChild("RightHand") and character:FindFirstChild("RightUpperArm") then
  local attachment=Instance.new("Attachment",target)
  ik=Instance.new("IKControl");ik.Name="AwakeningReach";ik.Type=Enum.IKControlType.Position
  ik.ChainRoot=character.RightUpperArm;ik.EndEffector=character.RightHand;ik.Target=attachment
  ik.SmoothTime=.12;ik.Weight=0;ik.Priority=100;ik.Parent=hum
 end
 local connection=Run.PreSimulation:Connect(function()
  for _,e in self.motors do
   if not e.joint.Parent then continue end
   local pose=CFrame.identity
   if e.key=="RightShoulder" and not ik then pose=CFrame.Angles(math.rad(88*self.weight),0,math.rad(6*self.weight))
   elseif e.key=="Neck" then pose=CFrame.Angles(math.rad(-8*self.weight),0,0)
   elseif e.key=="Waist" or e.key=="RootJoint" then pose=CFrame.Angles(math.rad(-3*self.weight),0,0) end
   local basis=e.joint.C0.Rotation
   e.joint.Transform=basis:Inverse()*pose*basis*e.base
  end
  if ik then ik.Weight=self.weight end
  if face then pcall(function() face.LeftEyeClosed=self.eyes;face.RightEyeClosed=self.eyes end) end
  if eyeGui then eyeGui.Enabled=self.eyes>.7 end
  for decal,transparency in self.faces do if decal.Parent then decal.Transparency=self.eyes>.7 and 1 or transparency end end
 end)
 function self:update(weight,eyes) self.weight=weight;self.eyes=eyes end
 function self:destroy()
  connection:Disconnect()
  if ik then ik:Destroy() end
  if face and self.left~=nil then pcall(function() face.LeftEyeClosed=self.left;face.RightEyeClosed=self.right end) end
  for decal,t in self.faces do if decal.Parent then decal.Transparency=t end end
  for _,e in self.motors do if e.joint.Parent then e.joint.Transform=e.base end end
  for s,enabled in self.scripts do if s.Parent then s.Enabled=enabled end end
  if eyeGui then eyeGui:Destroy() end
  target:Destroy()
 end
 return self
end
return Pose
