local SoundService=game:GetService("SoundService")
local Tween=game:GetService("TweenService")
local Content=game:GetService("ContentProvider")
local Run=game:GetService("RunService")
local Config=require(game.ReplicatedStorage.Shared.AwakeningConfig)
local Audio={}
local function fade(object,seconds,props)
 local t=Tween:Create(object,TweenInfo.new(seconds,Enum.EasingStyle.Sine),props);t:Play();return t
end
function Audio.preload()
 task.spawn(function()
  local list={}
  for _,id in Config.Audio do local s=Instance.new("Sound");s.SoundId=id;table.insert(list,s) end
  pcall(function() Content:PreloadAsync(list) end)
  for _,s in list do s:Destroy() end
 end)
end
function Audio.begin()
 local self={sounds={},groups={},rerouted={},alive=true,finishing=false}
 local bus=Instance.new("SoundGroup");bus.Name="AwakeningMix";bus.Parent=SoundService
 local sfx=SoundService:FindFirstChild("SFX")
 bus.Volume=sfx and sfx.Volume or .5
 local duckBus=Instance.new("SoundGroup");duckBus.Name="AwakeningWorldDuck";duckBus.Parent=SoundService
 local envelope=Instance.new("NumberValue");envelope.Value=1
 local changing=false
 local function group(g)
  if not g:IsA("SoundGroup") or g==bus or g==duckBus or self.groups[g] then return end
  local entry={volume=g.Volume,applied=g.Volume};self.groups[g]=entry
  entry.connection=g:GetPropertyChangedSignal("Volume"):Connect(function()
   -- Property signals may be deferred until after the writing flag clears.
   -- Ignore our last applied value, otherwise every frame compounds attenuation.
   if not changing and math.abs(g.Volume-entry.applied)>.00001 then entry.volume=g.Volume end
  end)
 end
 local function route(s)
  if s:IsA("SoundGroup") then group(s) end
  if not s:IsA("Sound") or s:GetAttribute("AwakeningAudio") or s.SoundGroup then return end
  if not (s:IsDescendantOf(workspace) or s:IsDescendantOf(SoundService) or s:IsDescendantOf(game.Players.LocalPlayer.PlayerGui)) then return end
  self.rerouted[s]=true;s.SoundGroup=duckBus
 end
 for _,g in SoundService:GetDescendants() do group(g) end
 for _,root in {workspace,SoundService,game.Players.LocalPlayer.PlayerGui} do for _,s in root:GetDescendants() do route(s) end end
 self.added=game.DescendantAdded:Connect(route)
 self.connection=Run.Heartbeat:Connect(function()
  changing=true
  for g,e in self.groups do if g.Parent then e.applied=e.volume*envelope.Value;g.Volume=e.applied end end
  duckBus.Volume=envelope.Value
  if sfx and self.groups[sfx] then bus.Volume=self.groups[sfx].volume end
  changing=false
 end)
 fade(envelope,1.1,{Value=.12})
 local function sound(name,id,volume,speed,loop)
  local s=Instance.new("Sound");s.Name=name;s:SetAttribute("AwakeningAudio",true)
  s.SoundId=id;s.Volume=0;s.PlaybackSpeed=speed or 1;s.Looped=loop==true;s.SoundGroup=bus
  local r=Instance.new("ReverbSoundEffect",s);r.DecayTime=2.4;r.WetLevel=-14;r.DryLevel=-1;r.Density=.7;r.Diffusion=.8
  s.Parent=SoundService;table.insert(self.sounds,s);s:Play();fade(s,.65,{Volume=volume})
  return s
 end
 self.bed=sound("Awakening_AncientAir",Config.Audio.Ambient,.3,.83,true)
 self.charge=sound("Awakening_RisingResonance",Config.Audio.Ambient,0,1.25,true)
 self.pulse=sound("Awakening_InnerPulse",Config.Audio.Ambient,0,.48,true)
 function self:cue(name)
  if not self.alive or self.finishing then return end
  if name=="contact" then sound("Awakening_Contact",Config.Audio.Chime,.19,.72,false)
  elseif name=="transfer" then
   sound("Awakening_Transfer",Config.Audio.Impact,.24,.82,false)
   fade(self.charge,2,{Volume=.15,PlaybackSpeed=1.48})
  elseif name=="inner" then fade(self.pulse,1.2,{Volume=.14})
  elseif name=="activate" then
   sound("Awakening_Activation",Config.Audio.Impact,.43,1.06,false)
   sound("Awakening_Shimmer",Config.Audio.Chime,.28,1.12,false)
   fade(self.charge,.6,{Volume=0});fade(self.pulse,.8,{Volume=0})
  end
 end
 function self:update(charge,t)
  if not self.alive or self.finishing then return end
  if charge>0 then
   self.charge.Volume=.07+charge*.16;self.charge.PlaybackSpeed=1.1+charge*.45
   self.pulse.Volume=(.06+.06*(.5+.5*math.sin(t*4.8)))*charge
  end
 end
 function self:finish(seconds)
  if self.finishing then return end;self.finishing=true
  seconds=seconds or 1.4
  fade(envelope,seconds,{Value=1})
  for _,s in self.sounds do if s.Parent then fade(s,seconds,{Volume=0}) end end
  task.delay(seconds+.05,function()
   if not self.alive then return end;self.alive=false
   self.connection:Disconnect();self.added:Disconnect()
   for g,e in self.groups do
    e.connection:Disconnect()
    if g.Parent then g.Volume=e.volume end
   end
   for s in self.rerouted do if s.Parent and s.SoundGroup==duckBus then s.SoundGroup=nil end end
   for _,s in self.sounds do s:Destroy() end
   bus:Destroy();duckBus:Destroy();envelope:Destroy()
  end)
 end
 return self
end
return Audio
