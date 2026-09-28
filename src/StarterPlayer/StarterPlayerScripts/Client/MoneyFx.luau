-- Server messages confirm rewards. One client scheduler owns pooled coins and attraction.
local Run=game:GetService('RunService')
local Tags=game:GetService('CollectionService')
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Sound=game:GetService('SoundService')
local Config=require(RS.Shared.MoneyConfig)
local Art=require(RS.Shared.CurrencyVisual)
local player=Players.LocalPlayer
local Fx={}
local tracked={}
local free={}
local flights={}
local created=0
local MAX_COINS=112
local MAX_FLIGHTS=24
local started=false
local folder=Instance.new('Folder');folder.Name='LocalCurrency';folder.Parent=workspace
local chime=Instance.new('Sound');chime.Name='CurrencyChime';chime.SoundId='rbxassetid://607665037';chime.Volume=.16;chime.PlaybackSpeed=1.2;chime.SoundGroup=Sound:FindFirstChild('SFX');chime.Parent=Sound
-- Warm the one shared sound outside any pickup event.
task.spawn(function() pcall(function() game:GetService('ContentProvider'):PreloadAsync({chime}) end) end)
local lastSound=-math.huge
local function release(coin)
 Art.hide(coin);table.insert(free,coin)
end
local function acquire(gold)
 local coin=table.remove(free)
 if not coin and created<MAX_COINS then coin=Art.new(folder);created+=1 end
 if coin then Art.style(coin,gold) end
 return coin
end
local function track(part)
 if not part:IsA('BasePart') or tracked[part] then return end
 tracked[part]={base=part:GetAttribute('BasePos') or part.Position,phase=part:GetAttribute('Phase') or 0,gold=part:GetAttribute('IsGold')==true}
end
local function untrack(part)
 local entry=tracked[part]
 if entry and entry.coin then release(entry.coin) end
 tracked[part]=nil
end
local function targetPosition(flight)
 if flight.target and flight.target.Parent then return flight.target:GetPivot().Position end
 return flight.finish
end
function Fx.startHovering()
 if started then return end;started=true
 for _,p in Tags:GetTagged(Config.Tag) do track(p) end
 Tags:GetInstanceAddedSignal(Config.Tag):Connect(track)
 Tags:GetInstanceRemovedSignal(Config.Tag):Connect(untrack)
 local visibilityClock=0
 Run.RenderStepped:Connect(function(dt)
  local camera=workspace.CurrentCamera;if not camera then return end
  local now=os.clock()
  local reduced=player:GetAttribute('ReducedMotion')==true
  visibilityClock+=dt
  if visibilityClock>=.12 then
   visibilityClock=0
   folder:SetAttribute('ActiveFlights',#flights)
   folder:SetAttribute('PooledCoins',created)
   local candidates={}
   for part,e in tracked do
    if not part:IsDescendantOf(workspace) then untrack(part)
    else
     local d=(e.base-camera.CFrame.Position).Magnitude
     if d<Config.AnimateRadius then table.insert(candidates,{entry=e,distance=d})
     elseif e.coin then release(e.coin);e.coin=nil end
    end
   end
   table.sort(candidates,function(a,b) return a.distance<b.distance end)
   for i,c in candidates do
    local e=c.entry
    if i<=MAX_COINS-MAX_FLIGHTS then if not e.coin then e.coin=acquire(e.gold) end
    elseif e.coin then release(e.coin);e.coin=nil end
   end
  end
  for _,e in tracked do
   if e.coin then
    local bob=reduced and 0 or math.sin(now*Config.BobSpeed+e.phase)*Config.BobAmplitude
    local turn=reduced and e.phase or now*Config.SpinSpeed+e.phase
    Art.pose(e.coin,CFrame.new(e.base+Vector3.new(0,bob,0))*CFrame.Angles(0,turn,0),0)
   end
  end
  for i=#flights,1,-1 do
   local f=flights[i]
   local t=math.clamp((now-f.started)/f.duration,0,1)
   local destination=targetPosition(f)
   if t<1 then
    -- Slow first instant, then accelerate into the moving rock's current position.
    local a=t*t
    local p=f.start:Lerp(destination,a)+Vector3.new(0,reduced and 0 or math.sin(t*math.pi)*2.8,0)
    Art.pose(f.coin,CFrame.new(p)*CFrame.Angles(0,now*8,0),0)
   else
    -- Short radial pop at arrival; same pooled geometry, no emitter allocation.
    local pop=(now-f.started-f.duration)/.13
    if pop>=1 then release(f.coin);table.remove(flights,i)
    else Art.pose(f.coin,CFrame.new(destination+Vector3.new(0,pop*.7,0))*CFrame.Angles(0,now*8,0),pop) end
   end
  end
 end)
end
function Fx.playClaim(collected,total,isMine,target,collectorUserId)
 local now=os.clock()
 local reduced=player:GetAttribute('ReducedMotion')==true
 local made=false
 for _,entry in collected do
  -- Distance/obstacle awards are not water coins and must not fabricate pickups.
  if entry.source=='distance' or entry.source=='obstacle' then continue end
  if typeof(entry.p)~='Vector3' then continue end
  local camera=workspace.CurrentCamera
  if not camera or (entry.p-camera.CFrame.Position).Magnitude>Config.AnimateRadius then continue end
  if #flights>=MAX_FLIGHTS then break end
  local coin=acquire(entry.g==true)
  if not coin then break end
  local finish=typeof(entry.target)=='Vector3' and entry.target or entry.p+Vector3.new(0,2,0)
  local duration=reduced and .16 or math.clamp((entry.p-finish).Magnitude/110,.24,.58)
  Art.pose(coin,CFrame.new(entry.p),0);coin.trail.Enabled=not reduced
  table.insert(flights,{coin=coin,start=entry.p,finish=finish,target=target,started=now,duration=duration})
  made=true
 end
 if made and isMine and total>0 and now-lastSound>.22 then
  lastSound=now;chime.TimePosition=0;chime:Play()
 end
end
return Fx
