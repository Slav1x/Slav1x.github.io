-- Client-owned background playlist. Sound templates stay in Workspace.backgroundmusic.
local ContentProvider=game:GetService("ContentProvider")
local SoundService=game:GetService("SoundService")
local sourceFolder=workspace:WaitForChild("backgroundmusic")
local bus=SoundService:WaitForChild("Music")
local skip=bus:WaitForChild("SkipTrack")
local nowPlaying=bus:WaitForChild("NowPlaying")
local trackIndex=bus:WaitForChild("TrackIndex")

local tracks,seen={},{}
for _,item in sourceFolder:GetChildren() do
 if item:IsA("Sound") and item.SoundId~="" and not seen[item.SoundId] then
  seen[item.SoundId]=true
  table.insert(tracks,{name=item.Name,id=item.SoundId,source=item})
 end
end
table.sort(tracks,function(a,b) return a.name:lower()<b.name:lower() end)

local sound=SoundService:FindFirstChild("BackgroundMusicPlayer") or Instance.new("Sound")
sound.Name="BackgroundMusicPlayer"
sound.SoundGroup=bus
sound.Volume=.5
sound.Looped=false
sound.Parent=SoundService
sound:Stop()

local desired=bus:GetAttribute("DesiredVolume")
if typeof(desired)~="number" then desired=.65;bus:SetAttribute("DesiredVolume",desired) end
bus.Volume=bus:GetAttribute("Muted")==true and 0 or math.clamp(desired,0,1)

local current=0
local generation=0
local alive=true
local playFrom
playFrom=function(first)
 if #tracks==0 then nowPlaying.Value="No music tracks";return end
 generation+=1
 local ticket=generation
 sound:Stop()
 nowPlaying.Value="Loading music..."
 task.spawn(function()
  for offset=0,#tracks-1 do
   if not alive or ticket~=generation then return end
   local index=(first+offset-1)%#tracks+1
   local track=tracks[index]
   local loaded=track.source.IsLoaded
   if not loaded then
    local success=false
    local ok=pcall(function()
     ContentProvider:PreloadAsync({track.source},function(_,status)
      if status==Enum.AssetFetchStatus.Success then success=true end
     end)
    end)
    loaded=ok and (success or track.source.IsLoaded)
   end
   if not alive or ticket~=generation then return end
   if loaded then
    current=index
    trackIndex.Value=index
    nowPlaying.Value=track.name
    sound.SoundId=track.id
    sound.TimePosition=0
    sound:Play()
    task.delay(8,function()
     if alive and ticket==generation and not sound.Playing then
      playFrom(index%#tracks+1)
     end
    end)
    return
   end
  end
  current=0
  trackIndex.Value=0
  nowPlaying.Value="Music unavailable"
  task.delay(30,function() if alive and ticket==generation then playFrom(1) end end)
 end)
end

sound.Ended:Connect(function()
 if alive and current>0 then playFrom(current%#tracks+1) end
end)
skip.Event:Connect(function()
 playFrom(current>0 and current%#tracks+1 or 1)
end)
script.Destroying:Connect(function()
 alive=false
 generation+=1
 sound:Stop()
 sound:Destroy()
end)
playFrom(1)
