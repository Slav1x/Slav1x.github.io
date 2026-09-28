local Config=require(game.ReplicatedStorage.Shared.AwakeningConfig)
local M={}
local function part(parent,name,size,cf,color,transparency,shape)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
 p.Transparency=transparency or 0;p.Material=Enum.Material.Neon;p.Anchored=true
 p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 if shape then p.Shape=shape end;p.Parent=parent;return p
end
local function line(parent,a,b,color,width,alpha)
 return part(parent,"MeridianChannel",Vector3.new(width,width,(a-b).Magnitude),CFrame.lookAt((a+b)*.5,b),color,alpha)
end
function M.create(parent,character,count)
 local self={nodes={},channels={},orbit={},motes={},halos={}}
 local frame=Instance.new("Frame");frame.Name="InnerWorld";frame.Size=UDim2.fromScale(1,1)
 frame.BackgroundColor3=Color3.new(1,1,1);frame.BorderSizePixel=0;frame.ZIndex=4;frame.Visible=false;frame.Parent=parent
 local gradient=Instance.new("UIGradient",frame);gradient.Rotation=90
 gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(4,11,26)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(12,31,51)),ColorSequenceKeypoint.new(1,Color3.fromRGB(2,7,18))})
 local viewport=Instance.new("ViewportFrame");viewport.Name="MeridianBody";viewport.BackgroundTransparency=1
 viewport.Size=UDim2.fromScale(1,.55);viewport.Position=UDim2.fromScale(0,.24);viewport.ZIndex=5
 viewport.Ambient=Color3.fromRGB(200,200,200);viewport.LightColor=Color3.fromRGB(210,218,226);viewport.LightDirection=Vector3.new(-1,-.3,-1);viewport.Parent=frame
 local world=Instance.new("WorldModel",viewport);world.Name="InnerBody"
 local camera=Instance.new("Camera",viewport);camera.FieldOfView=38;viewport.CurrentCamera=camera
 local target,newNode=Config.stage(count);self.target=target
 local function text(name,words,y,size,color)
  local t=Instance.new("TextLabel");t.Name=name;t.Size=UDim2.fromScale(.88,.06);t.Position=UDim2.fromScale(.06,y)
  t.Text=words;t.TextColor3=color;t.BackgroundTransparency=1;t.TextSize=size;t.Font=Enum.Font.GothamMedium
  t.TextScaled=true;t.ZIndex=6;t.Parent=frame
  local limit=Instance.new("UITextSizeConstraint",t);limit.MaxTextSize=size;limit.MinTextSize=10
  return t
 end
 text("Chapter",count==1 and "I   /   THE FIRST AWAKENING" or "AWAKENING  /  "..count,.115,13,Color3.fromRGB(129,160,185))
 self.title=text("MeridianName",string.upper(target.name),.17,26,Config.Ice)
 self.caption=text("State","Dormant · waiting for your touch",.79,15,Color3.fromRGB(149,174,196))
 text("Hint","A beginning. The other paths are still quiet.",.84,12,Color3.fromRGB(95,119,145))
 -- A translucent anatomical echo of the player's own body meshes.
 local slots={
  Head={Vector3.new(0,2.25,0),Vector3.new(1.4,1.2,1.1)},
  Torso={Vector3.new(0,.55,.1),Vector3.new(2,2,1)},
  UpperTorso={Vector3.new(0,.85,.1),Vector3.new(2,1.4,1)},
  LowerTorso={Vector3.new(0,-.3,.1),Vector3.new(1.5,.8,.9)},
  ["Left Arm"]={Vector3.new(-1.6,.3,.1),Vector3.new(.8,2.3,.8)},
  ["Right Arm"]={Vector3.new(1.6,.3,.1),Vector3.new(.8,2.3,.8)},
  LeftUpperArm={Vector3.new(-1.5,.65,.1),Vector3.new(.75,1.15,.75)},
  RightUpperArm={Vector3.new(1.5,.65,.1),Vector3.new(.75,1.15,.75)},
  LeftLowerArm={Vector3.new(-1.65,-.35,.1),Vector3.new(.65,.95,.65)},
  RightLowerArm={Vector3.new(1.65,-.35,.1),Vector3.new(.65,.95,.65)},
  LeftHand={Vector3.new(-1.65,-1,.1),Vector3.new(.65,.45,.65)},
  RightHand={Vector3.new(1.65,-1,.1),Vector3.new(.65,.45,.65)},
  ["Left Leg"]={Vector3.new(-.55,-1.65,.1),Vector3.new(.85,2.25,.85)},
  ["Right Leg"]={Vector3.new(.55,-1.65,.1),Vector3.new(.85,2.25,.85)},
  LeftUpperLeg={Vector3.new(-.5,-1.15,.1),Vector3.new(.8,1.1,.85)},
  RightUpperLeg={Vector3.new(.5,-1.15,.1),Vector3.new(.8,1.1,.85)},
  LeftLowerLeg={Vector3.new(-.5,-2.15,.1),Vector3.new(.65,1,.7)},
  RightLowerLeg={Vector3.new(.5,-2.15,.1),Vector3.new(.65,1,.7)},
  LeftFoot={Vector3.new(-.5,-2.75,-.1),Vector3.new(.7,.4,1)},
  RightFoot={Vector3.new(.5,-2.75,-.1),Vector3.new(.7,.4,1)},
 }
 for name,slot in slots do
  local original=character:FindFirstChild(name)
  if original and original:IsA("BasePart") then
   local echo=original:Clone()
   for _,v in echo:GetDescendants() do
    if not v:IsA("DataModelMesh") then v:Destroy() elseif v:IsA("SpecialMesh") then v.TextureId="" end
   end
   if echo:IsA("MeshPart") then echo.TextureID="" end
   echo.Name="Echo_"..name;echo.Size=slot[2];echo.CFrame=CFrame.new(slot[1]);echo.Color=Color3.fromRGB(83,116,143)
   echo.Material=Enum.Material.SmoothPlastic;echo.Transparency=.76;echo.Anchored=true
   echo.CanCollide=false;echo.CanTouch=false;echo.CanQuery=false;echo.CastShadow=false;echo.Parent=world
  end
 end
 local function path(points)
  for i=1,#points-1 do
   table.insert(self.channels,line(world,Vector3.new(points[i][1],points[i][2],-.62),Vector3.new(points[i+1][1],points[i+1][2],-.62),Config.Dormant,.028,.12))
  end
 end
 path({{0,2.9},{0,2.35},{0,1.55},{0,.65},{0,-.8}})
 for _,side in {-1,1} do
  path({{0,1.25},{side*.65,1.05},{side*1.45,.82},{side*1.55,.4},{side*1.67,-.5},{side*1.65,-1}})
  path({{0,.65},{side*.65,.38},{side*.78,-.15},{0,-.8},{side*.48,-1.3},{side*.52,-2.15},{side*.52,-2.7}})
  path({{side*.48,-1.3},{side*.8,-1.75},{side*.52,-2.15}})
 end
 for _,node in Config.Nodes do
  local unlocked=node.unlock<count
  local core=part(world,node.id,Vector3.one*(node.id==target.id and .27 or .15),CFrame.new(node.at+Vector3.new(0,0,-.13)),unlocked and Config.Blue or Config.Dormant,0,Enum.PartType.Ball)
  self.nodes[node.id]=core
 end
 self.core=self.nodes[target.id]
 local center=target.at+Vector3.new(0,0,-.14)
 for i=1,3 do
  local halo=part(world,"HeartHalo",Vector3.one*(.38+i*.13),CFrame.new(center),Config.Blue,.91,Enum.PartType.Ball)
  table.insert(self.halos,halo)
 end
 for i=1,48 do
  local a=(i-1)*math.pi/24;local b=i*math.pi/24
  local p1=center+Vector3.new(math.cos(a),math.sin(a),0)*.49
  local p2=center+Vector3.new(math.cos(b),math.sin(b),0)*.49
  local p=line(world,p1,p2,Config.Dormant,.017,.3)
  table.insert(self.orbit,{part=p,angle=a})
 end
 for i=1,14 do
  local p=part(world,"InwardLight",Vector3.one*.04,CFrame.identity,Config.Ice,1,Enum.PartType.Ball)
  table.insert(self.motes,{part=p,offset=i/14})
 end
 function self:update(t,charge,activated)
  frame.Visible=true
  local pulse=.5+.5*math.sin(t*3)
  camera.CFrame=CFrame.lookAt(Vector3.new(math.sin(t*.14)*.2,.22,-10.8+charge*.3),Vector3.new(0,.1,0))
  self.core.Color=Config.Dormant:Lerp(Config.Blue,charge)
  self.core.Material=activated and Enum.Material.Neon or Enum.Material.SmoothPlastic
  self.core.Size=Vector3.one*(.27+charge*.1+pulse*.02*charge)
  for i,halo in self.halos do halo.Transparency=1-charge*(.13-i*.025);halo.Size=Vector3.one*(.35+i*.18+pulse*.06*charge) end
  for i,entry in self.orbit do
   entry.part.Color=Config.Dormant:Lerp(Config.Blue,math.clamp(charge*1.2-(i/48)*.2,0,1))
   entry.part.Transparency=.4-charge*.3
   if activated then
    self.activatedAt=self.activatedAt or t
    local progress=math.clamp((t-self.activatedAt)/1.1,0,1)
    local radius=.49+progress*1.1
    local a=entry.angle;local b=a+math.pi/24
    local p1=center+Vector3.new(math.cos(a),math.sin(a),0)*radius
    local p2=center+Vector3.new(math.cos(b),math.sin(b),0)*radius
    entry.part.CFrame=CFrame.lookAt((p1+p2)/2,p2);entry.part.Size=Vector3.new(.02,.02,(p2-p1).Magnitude)
    entry.part.Transparency=.15+progress*.85
   end
  end
  for _,mote in self.motes do
   local p=(t*.23+mote.offset)%1;local a=mote.offset*math.pi*2+t*.2
   local radius=(1-p)*(.9+charge*.25)
   mote.part.Position=center+Vector3.new(math.cos(a)*radius,math.sin(a)*radius,-.08)
   mote.part.Transparency=activated and 1 or 1-charge*math.sin(p*math.pi)*.8
  end
  self.caption.Text=activated and (newNode and "Awakened · a new path opens within" or "Resonance deepened") or "Breathe. Let the stone answer."
  self.caption.TextColor3=activated and Config.Ice or Color3.fromRGB(149,174,196)
 end
 function self:hide() frame.Visible=false end
 function self:destroy() frame:Destroy() end
 self.frame=frame
 return self
end
return M
