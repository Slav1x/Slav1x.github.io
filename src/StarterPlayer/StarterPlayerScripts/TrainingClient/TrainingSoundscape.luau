-- One local mix, driven by existing state and confirmed reward messages.
local Run=game:GetService("RunService")
local SoundService=game:GetService("SoundService")
local Content=game:GetService("ContentProvider")
local Soundscape={}
function Soundscape.new(player,remotes,isHeld)
 local self={count=0,pulse=0,weight=0,afk=0,alive=true,lastAccent=-math.huge}
 local folder=Instance.new("Folder");folder.Name="TrainingAudio";folder.Parent=SoundService
 local sfx=SoundService:FindFirstChild("SFX")
 local function sound(name,id,volume,loop,speed)
  local o=Instance.new("Sound");o.Name=name;o.SoundId=id;o.Volume=volume;o.Looped=loop or false;o.PlaybackSpeed=speed or 1;o.SoundGroup=sfx;o.Parent=folder;return o
 end
 local air=sound("VortexAir","rbxasset://sounds/action_falling.ogg",0,true,.95)
 local hum=sound("ResonantCore","rbxassetid://9125674129",0,true,.92)
 local chime=sound("TrainingGain","rbxassetid://9116395089",.12,false,1.5)
 local sweep=sound("ChargeSweep","rbxassetid://9125647922",.13,false,.85)
 local start=sound("FocusIgnition","rbxassetid://9116384485",.16,false,.72)
 for _,s in {air,hum} do
  local eq=Instance.new("EqualizerSoundEffect");eq.LowGain=s==air and -12 or -3;eq.MidGain=-4;eq.HighGain=-9;eq.Parent=s
 end
 for _,s in {hum,chime,sweep,start} do
  local reverb=Instance.new("ReverbSoundEffect");reverb.DecayTime=1.3;reverb.WetLevel=-19;reverb.DryLevel=0;reverb.Parent=s
 end
 local wasActive=false
 self.reward=remotes.ShopResult.OnClientEvent:Connect(function(id,ok)
  if id~="spin" or ok~=true then return end
  self.count+=1;self.pulse=1
  -- Keep long AFK sessions comfortable: a soft chord every other reward.
  if self.count%2==1 then
   chime.PlaybackSpeed=({1.25,1.4,1.575,1.667})[(math.floor(self.count/2)%4)+1]
   chime.Volume=player:GetAttribute("TrainingAFK")==true and .105 or .085
   chime.TimePosition=0;chime:Play()
  end
  if os.clock()-self.lastAccent>4.5 then
   self.lastAccent=os.clock();sweep.TimePosition=0;sweep:Play()
  end
 end)
 self.loop=Run.Heartbeat:Connect(function(dt)
  local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
  local active=player:GetAttribute("TrainingSpinning")==true and isHeld(c)~=nil and h~=nil and h.Health>0 and player:GetAttribute("RebirthCinematic")~=true
  local afk=active and player:GetAttribute("TrainingAFK")==true
  if active and not wasActive then
   air:Play();hum:Play();start:Play()
  end
  wasActive=active
  self.weight+=((active and 1 or 0)-self.weight)*(1-math.exp(-dt*(active and 2.7 or 6)))
  self.afk+=((afk and 1 or 0)-self.afk)*(1-math.exp(-dt*3))
  self.pulse*=math.exp(-dt*4.5)
  local breath=.93+.07*math.sin(os.clock()*2.2)
  air.Volume=self.weight*(.12+self.afk*.055)*breath
  air.PlaybackSpeed=.82+self.weight*.3+self.pulse*.065
  hum.Volume=self.weight*(.08+self.afk*.095)*breath
  hum.PlaybackSpeed=.8+self.weight*.16+self.pulse*.035
  if not active and self.weight<.003 then air:Stop();hum:Stop() end
 end)
 task.spawn(function() pcall(function() Content:PreloadAsync({air,hum,chime,sweep,start}) end) end)
 function self:destroy()
  if not self.alive then return end;self.alive=false
  self.reward:Disconnect();self.loop:Disconnect();folder:Destroy()
 end
 return self
end
return Soundscape