-- Golden sequence sound: ducks the world (same approach as AwakeningAudio, so music and
-- ambience glide down instead of cutting), then layers looping beds and one-shots on a
-- private bus. vacuum() pulls the bus toward silence for the held-breath moments.
local SoundService=game:GetService("SoundService")
local Tween=game:GetService("TweenService")
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Golden=require(game:GetService("ReplicatedStorage").Shared.GoldenMeridianConfig)
local A={}
local function tween(object,seconds,props)
 local t=Tween:Create(object,TweenInfo.new(math.max(seconds,.01),Enum.EasingStyle.Sine),props);t:Play();return t
end
local function effects(s,opts)
 if opts.reverb~=false then
  local r=Instance.new("ReverbSoundEffect");r.DecayTime=opts.decay or 2.6;r.WetLevel=opts.wet or -10;r.DryLevel=opts.dry or -1;r.Density=.8;r.Diffusion=.85;r.Parent=s
 end
 if opts.eq then
  local e=Instance.new("EqualizerSoundEffect");e.LowGain=opts.eq[1];e.MidGain=opts.eq[2];e.HighGain=opts.eq[3];e.Parent=s
 end
 if opts.chorus then
  local c=Instance.new("ChorusSoundEffect");c.Depth=.45;c.Mix=.6;c.Rate=.35;c.Parent=s
 end
end
function A.begin()
 local self={layers={},shots={},groups={},rerouted={},alive=true,finishing=false}
 local player=Players.LocalPlayer
 local sfx=SoundService:FindFirstChild("SFX")
 local base=sfx and sfx:IsA("SoundGroup") and sfx.Volume or .5
 local bus=Instance.new("SoundGroup");bus.Name="GoldenMix";bus.Volume=base;bus.Parent=SoundService
 local duck=Instance.new("SoundGroup");duck.Name="GoldenWorldDuck";duck.Parent=SoundService
 local envelope=Instance.new("NumberValue");envelope.Value=1
 local busScale=Instance.new("NumberValue");busScale.Value=1
 local writing=false
 local function group(g)
  if not g:IsA("SoundGroup") or g==bus or g==duck or self.groups[g] then return end
  local entry={volume=g.Volume,applied=g.Volume};self.groups[g]=entry
  entry.connection=g:GetPropertyChangedSignal("Volume"):Connect(function()
   if not writing and math.abs(g.Volume-entry.applied)>.00001 then entry.volume=g.Volume end
  end)
 end
 local function route(s)
  if s:IsA("SoundGroup") then group(s) end
  if not s:IsA("Sound") or s:GetAttribute("GoldenAudio") or s:GetAttribute("AwakeningAudio") or s.SoundGroup then return end
  if not (s:IsDescendantOf(workspace) or s:IsDescendantOf(SoundService) or s:IsDescendantOf(player.PlayerGui)) then return end
  self.rerouted[s]=true;s.SoundGroup=duck
 end
 for _,g in SoundService:GetDescendants() do group(g) end
 for _,root in {workspace,SoundService,player.PlayerGui} do for _,s in root:GetDescendants() do route(s) end end
 self.added=game.DescendantAdded:Connect(route)
 self.connection=Run.Heartbeat:Connect(function()
  writing=true
  for g,e in self.groups do if g.Parent then e.applied=e.volume*envelope.Value;g.Volume=e.applied end end
  duck.Volume=envelope.Value
  bus.Volume=(sfx and self.groups[sfx] and self.groups[sfx].volume or base)*busScale.Value
  writing=false
 end)
 local function sound(name,id,volume,speed,looped,opts)
  local s=Instance.new("Sound");s.Name=name;s:SetAttribute("GoldenAudio",true)
  s.SoundId=id;s.Volume=volume;s.PlaybackSpeed=speed or 1;s.Looped=looped==true;s.SoundGroup=bus
  effects(s,opts or {})
  s.Parent=SoundService
  return s
 end
 -- World level: 1 = normal, 0 = silent.
 function self:world(level,seconds) if self.alive then tween(envelope,seconds or 1,{Value=level}) end end
 -- Bus level for held-breath silence and the hit that follows it.
 function self:vacuum(level,seconds) if self.alive then tween(busScale,seconds or .15,{Value=level}) end end
 -- A looping bed. Starts silent; set() moves it.
 function self:layer(name,id,speed,opts)
  if not self.alive or self.layers[name] then return self.layers[name] end
  local s=sound("Golden_"..name,id,0,speed,true,opts);s:Play()
  self.layers[name]=s
  return s
 end
 function self:set(name,volume,seconds,speed)
  local s=self.layers[name]
  if not s or not self.alive or self.finishing then return end
  local props={Volume=volume}
  if speed then props.PlaybackSpeed=speed end
  tween(s,seconds or 1,props)
 end
 function self:shot(id,speed,volume,opts)
  if not self.alive or self.finishing then return end
  local s=sound("Golden_Shot",id,volume,speed,false,opts)
  s:Play()
  table.insert(self.shots,s)
  s.Ended:Once(function() task.delay(3,function() if s.Parent then s:Destroy() end end) end)
  task.delay(20,function() if s.Parent then s:Destroy() end end)
  return s
 end
 -- Common voices of the sequence.
 function self:impact(speed,volume) return self:shot(Golden.Audio.Impact,speed or .7,volume or .45,{decay=3.4,wet=-6}) end
 function self:chime(speed,volume) return self:shot(Golden.Audio.Chime,speed or .7,volume or .2,{decay=3,wet=-7}) end
 function self:splash(speed,volume) return self:shot(Golden.Audio.Splash,speed or 1,volume or .4,{decay=1.8,wet=-12}) end
 function self:finish(seconds)
  if self.finishing then return end
  self.finishing=true
  seconds=seconds or 1.5
  tween(envelope,seconds,{Value=1})
  tween(busScale,seconds,{Value=0})
  task.delay(seconds+.1,function()
   if not self.alive then return end
   self.alive=false
   self.connection:Disconnect();self.added:Disconnect()
   for g,e in self.groups do e.connection:Disconnect();if g.Parent then g.Volume=e.volume end end
   for s in self.rerouted do if s.Parent and s.SoundGroup==duck then s.SoundGroup=nil end end
   for _,s in self.layers do s:Destroy() end
   for _,s in self.shots do if s.Parent then s:Destroy() end end
   bus:Destroy();duck:Destroy();envelope:Destroy();busScale:Destroy()
  end)
 end
 function self:destroy() self:finish(.8) end
 return self
end
return A
