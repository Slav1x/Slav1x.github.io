-- Readable shared silhouettes with biome-specific imported mesh casings.
local A={Version=4}
local C=require(script.Parent.PebbleEncounters)
local WorldArt=require(script.Parent.WorldArt)
function A.supports(k) return k=='Nitro' or k=='Jet' or k=='Bomb' or k=='Whirlpool' or k=='Log' or k=='Rocks' end
function A.upgrade(model)
 local kind=model:GetAttribute('EncounterKind')
 if kind=='Monkey' or kind=='Gorilla' then WorldArt.habitat(model);return end
 if not A.supports(kind) or not model.PrimaryPart then return end
 local area=WorldArt.zone(model.PrimaryPart.Position).id
 if model:GetAttribute('WaterArtVersion')==A.Version and model:GetAttribute('AreaId')==area then return end
 local target=model.PrimaryPart
 for _,v in model:GetChildren() do if v~=target then v:Destroy() end end
 local base=CFrame.new(target.Position)
 if kind=='Log' or kind=='Rocks' then
  require(script.Parent.WaterObstacleArt).build(model,base,kind,false)
 else
  local color=C.Types[kind].color;local cream=Color3.fromRGB(252,247,226)
  local function p(name,size,cf,tint,shape,neon)
   local x=Instance.new('Part');x.Name=name;x.Size=size;x.CFrame=base*cf;x.Color=tint;x.Shape=shape or Enum.PartType.Block
   x.Material=neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
   x.Anchored=true;x.CanCollide=false;x.CanQuery=false;x.CanTouch=false;x.CastShadow=false;x.Parent=model;return x
  end
  local function cyl(name,r,h,y,tint,neon) return p(name,Vector3.new(h,r*2,r*2),CFrame.new(0,y,0)*CFrame.Angles(0,0,math.pi/2),tint,Enum.PartType.Cylinder,neon) end
  local function ring(name,r,y,vertical,tint,width)
   local count=14
   for i=1,count do
    local a=(i-1)*math.pi*2/count;local b=i*math.pi*2/count
    local u=vertical and Vector3.new(0,y+math.sin(a)*r,math.cos(a)*r) or Vector3.new(math.cos(a)*r,y,math.sin(a)*r)
    local v=vertical and Vector3.new(0,y+math.sin(b)*r,math.cos(b)*r) or Vector3.new(math.cos(b)*r,y,math.sin(b)*r)
    p(name,Vector3.new(width,width,(v-u).Magnitude+.2),CFrame.lookAt((u+v)/2,v),tint,nil,true)
   end
  end
  if kind=='Nitro' then
   cyl('EnamelBody',2.4,5.8,4.8,color)
   cyl('PorcelainFoot',2.5,.6,2,cream);cyl('PorcelainShoulder',2.5,.6,7.6,cream);cyl('ValveCap',1.2,.7,8.2,cream)
   for _,side in {-1,1} do
    p('BoltEmblem',Vector3.new(.2,2.6,.6),CFrame.new(side*2.42,4.8,0)*CFrame.Angles(.4,0,0),cream,nil,true)
   end
  elseif kind=='Jet' then
   ring('EnergyChannel',7.1,8.1,true,color,.7)
   for _,side in {-1,1} do
    p('EnamelTurbine',Vector3.new(5,3.3,3.3),CFrame.new(0,3.5,side*7),cream,Enum.PartType.Cylinder)
    p('IntakeCore',Vector3.new(.15,2,2),CFrame.new(-2.6,3.5,side*7),color,Enum.PartType.Cylinder,true)
   end
  elseif kind=='Bomb' then
   p('EnamelBlastShell',Vector3.one*7,CFrame.new(0,4.4,0),color,Enum.PartType.Ball)
   cyl('PorcelainBelt',3.53,.7,4.4,cream);cyl('IgnitionCap',1.2,.8,8.1,cream)
   p('Fuse',Vector3.new(.4,1.2,.4),CFrame.new(0,9,0),cream)
   p('IgnitionPearl',Vector3.one,CFrame.new(0,9.8,0),Color3.fromRGB(255,225,123),Enum.PartType.Ball,true)
   for _,side in {-1,1} do
    for i=0,2 do p('BurstEmblem',Vector3.new(.2,2.7,.4),CFrame.new(side*3.51,4.4,0)*CFrame.Angles(i*math.pi/3,0,0),cream,nil,true) end
   end
  else
   ring('VortexArc',8,.35,false,color,.6)
   cyl('VortexEye',3,.2,.15,Color3.fromRGB(40,72,105))
   for i=1,3 do local a=i*math.pi*2/3;p('OrbitPearl',Vector3.one*.8,CFrame.new(math.cos(a)*6,1,math.sin(a)*6),cream,Enum.PartType.Ball,true) end
  end
  WorldArt.trimPickup(model)
 end
 model:SetAttribute('WaterArtVersion',A.Version);model:SetAttribute('AreaId',area)
end
return A
