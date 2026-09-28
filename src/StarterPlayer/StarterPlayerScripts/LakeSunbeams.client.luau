-- Existing six-shaft pool follows authored light direction with biome strength.
local Run=game:GetService('RunService')
local Lighting=game:GetService('Lighting')
local Water=require(game.ReplicatedStorage.Shared.WaterSurface)
local Biomes=require(game.ReplicatedStorage.Shared.BiomePresentation)
local player=game.Players.LocalPlayer
local folder=Instance.new('Folder');folder.Name='LocalSunbeams';folder.Parent=workspace
local shafts={}
for i=1,6 do
 local anchor=Instance.new('Part');anchor.Name='Sunshaft'..i;anchor.Anchored=true;anchor.Transparency=1;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Size=Vector3.one;anchor.Parent=folder
 local top=Instance.new('Attachment',anchor);local bottom=Instance.new('Attachment',anchor)
 local beam=Instance.new('Beam',anchor);beam.Name='SoftSunlight';beam.Attachment0=top;beam.Attachment1=bottom;beam.FaceCamera=true;beam.Width0=8;beam.Width1=23;beam.Segments=6
 beam.Texture='rbxasset://textures/particles/smoke_main.dds';beam.TextureMode=Enum.TextureMode.Stretch;beam.TextureSpeed=0;beam.LightEmission=.65;beam.LightInfluence=0;beam.Enabled=false
 table.insert(shafts,{part=anchor,top=top,beam=beam,strength=0})
end
local elapsed=0
local connection=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.2 then return end
 local step=elapsed;elapsed=0
 local cam=workspace.CurrentCamera;if not cam then return end
 local pos=cam.CFrame.Position;local sun=Lighting:GetSunDirection();local origin=math.floor(pos.X/240)*240
 local reduced=player:GetAttribute('ReducedMotion')==true
 for i,s in shafts do
  local x=origin+(i-3)*240;local z=-40.5+math.sin(x*.017)*95
  local y=Water.at(Vector3.new(x,0,z));local profile=Biomes.at(Vector3.new(x,0,z))
  local target=(y and sun.Y>.08 and not reduced) and profile.sun or 0
  s.strength+=(target-s.strength)*(1-math.exp(-1.8*step))
  s.beam.Enabled=s.strength>.015
  s.beam.Color=ColorSequence.new(profile.tint,profile.mote)
  s.beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.22,1-.10*s.strength),NumberSequenceKeypoint.new(.65,1-.055*s.strength),NumberSequenceKeypoint.new(1,1)})
  if y then s.part.Position=Vector3.new(x,y+.5,z);s.top.Position=sun*(90/math.max(sun.Y,.2)) end
 end
end)
script.Destroying:Connect(function() connection:Disconnect();folder:Destroy() end)
