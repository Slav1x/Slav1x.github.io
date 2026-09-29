-- The existing two verified ambience assets, smoothly remixed by biome.
-- No extra music layers or downloaded audio are introduced.
local ContentProvider=game:GetService('ContentProvider')
local RunService=game:GetService('RunService')
local SoundService=game:GetService('SoundService')
local Water=require(game.ReplicatedStorage.Shared.WaterSurface)
local Biomes=require(game.ReplicatedStorage.Shared.BiomePresentation)
local Players=game:GetService('Players')
local player=Players.LocalPlayer
local bus=Instance.new('SoundGroup');bus.Name='LakeAmbient';bus.Volume=.6;bus.Parent=SoundService
local function loop(name,id)
 local sound=Instance.new('Sound');sound.Name=name;sound.SoundId=id;sound.Looped=true;sound.Volume=0;sound.SoundGroup=bus;sound.Parent=SoundService
 return sound
end
local lake=loop('LakeBed','rbxassetid://9112877174')
local shore=loop('ShoreWash','rbxassetid://9126195224')
local eq=Instance.new('EqualizerSoundEffect',shore);eq.Name='BiomeTone'
local reverb=Instance.new('ReverbSoundEffect',shore);reverb.Name='BiomeSpace';reverb.WetLevel=-80;reverb.DryLevel=0;reverb.Density=.45;reverb.Diffusion=.6
local alive=true
task.spawn(function()
 local ok=pcall(function() ContentProvider:PreloadAsync({lake,shore}) end)
 if not ok or not alive then return end
 if lake.IsLoaded then lake:Play() end
 if shore.IsLoaded then shore:Play() end
end)
local elapsed=0
local connection=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.15 then return end
 local step=elapsed;elapsed=0
 local camera=workspace.CurrentCamera;if not camera then return end
 local position=camera.CFrame.Position
 local profile=Biomes.at(position).audio
 local near=Water.at(position)~=nil or Water.at(position+camera.CFrame.LookVector*60)~=nil
 local a=1-math.exp(-1.3*step)
 local duck=player:GetAttribute('RockInFlight') and .76 or 1
 lake.Volume+=(profile.lake*duck-lake.Volume)*a
 shore.Volume+=(profile.shore*(near and 1 or .25)*duck-shore.Volume)*a
 shore.PlaybackSpeed+=(profile.speed-shore.PlaybackSpeed)*a
 eq.LowGain+=(profile.low-eq.LowGain)*a;eq.MidGain+=(profile.mid-eq.MidGain)*a;eq.HighGain+=(profile.high-eq.HighGain)*a
 reverb.WetLevel+=(profile.wet-reverb.WetLevel)*a;reverb.DecayTime+=(profile.decay-reverb.DecayTime)*a
end)
script.Destroying:Connect(function() alive=false;connection:Disconnect();lake:Destroy();shore:Destroy();bus:Destroy() end)
