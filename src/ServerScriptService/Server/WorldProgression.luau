--!nonstrict
-- Server-owned milestones extend the existing profile and authoritative throw.
local RS=game:GetService("ReplicatedStorage")
local Profiles=require(script.Parent.Profiles)
local Remotes=require(RS.Shared.Remotes)
local Zones=require(RS.Shared.ZoneConfig)
local Water=require(RS.Shared.WaterSurface)
local Mastery=require(RS.Shared.MasteryConfig)
local P={}
local rng=Random.new()
function P.begin(throw)
 local profile=Profiles.get(throw.player)
 throw.rockId=profile.rockEquipped
 throw.rockInstanceId=Profiles.ensureMasteryCopy(profile)
 throw.masteryMultiplier=(Profiles.modifiers(throw.player).rockStats or {}).masteryMultiplier or 1
 throw.firstCompletions=0
 throw.shardsFound=0
 throw.lastShardX=throw.launchPos.X
 throw.lastMilestoneX=throw.launchPos.X
 Profiles.fireChanged(throw.player)
end
-- A physics step can jump beyond the last water rectangle. Validate the
-- swept finish crossing against water just inside the endpoint instead of
-- requiring a sample at its zero-width, floating-point-sensitive outer edge.
local function crossesCourseFinish(throw, position)
 local from=throw.lastPos
 local finalZone=Zones.List[#Zones.List]
 local finishX=Zones.OriginX+finalZone.finish
 if typeof(from)~="Vector3" or from.X>=finishX or position.X<finishX then return false end
 local dx=position.X-from.X
 if dx<=0 or from.X<Zones.OriginX+finalZone.start then return false end
 local step=position-from
 if Vector3.new(step.X,0,step.Z).Magnitude>2048 then return false end
 local alpha=(finishX-from.X)/dx
 if alpha<0 or alpha>1 then return false end
 local crossing=from:Lerp(position,alpha)
 local inside=Vector3.new(finishX-0.25,crossing.Y,crossing.Z)
 if not Water.at(from) or not Water.at(inside) then return false end
 local travel=inside-from
 local horizontal=Vector3.new(travel.X,0,travel.Z).Magnitude
 -- Reject discontinuous jumps; this comfortably covers a stalled physics
 -- frame while bounding the work and preserving the valid-channel check.
 if horizontal>2048 then return false end
 local count=math.max(1,math.ceil(horizontal/16))
 for i=1,count-1 do
  if not Water.at(from:Lerp(inside,i/count)) then return false end
 end
 return true
end
function P.observe(throw,position)
 local profile=Profiles.get(throw.player)
 if not profile.loaded or not throw.rockInstanceId then return false end
 if position.X<=throw.lastMilestoneX then return false end
 local distance=Zones.distanceAt(position)
 local finalFinish=Zones.List[#Zones.List].finish
 local completedCourse=distance>=finalFinish and crossesCourseFinish(throw,position)
 if distance>=finalFinish and not completedCourse then return false end
 if not completedCourse and not Water.at(position) then return false end
 throw.lastMilestoneX=position.X
 local changed=false
 for index,zone in ipairs(Zones.List) do
  if distance>=zone.finish then
   if not profile.cycleCompletedAreas[zone.id] then
    profile.cycleCompletedAreas[zone.id]=true
    changed=true
   end
   if not profile.completedAreas[zone.id] then
    -- Receipt precedes reward, without yielding. Both save in the same profile.
    profile.completedAreas[zone.id]=true
    local eventMoney=workspace:GetAttribute("GlobalMoneyMultiplier")
    local cash=math.floor((zone.completionCash or 0)*(type(eventMoney)=="number" and math.clamp(eventMoney,1,2) or 1))
    local shards=zone.completionShards or 0
    Profiles.addMoney(throw.player,cash)
    profile.traitShards+=shards
    profile.permanentTitles[zone.id.."_voyager"]=true
    throw.firstCompletions+=1
    Remotes.AreaCompleted:FireClient(throw.player,{id=zone.id,name=zone.name,cash=cash,shards=shards,color=zone.color,title=zone.name.." VOYAGER"})
    changed=true
    task.defer(function()
     if throw.player.Parent then require(script.Parent.Persistence).saveNow(throw.player) end
    end)
   end
  end
 end
 if changed then Profiles.fireChanged(throw.player) end
 return distance>=Zones.List[#Zones.List].finish
end
function P.skip(throw,position)
 if throw.shardsFound>=Mastery.MaxShardsPerThrow or position.X<throw.lastShardX+20 then return end
 throw.lastShardX=position.X
 if os.clock()-throw.startedAt<1 or not Water.at(position) then return end
 local profile=Profiles.get(throw.player)
 if not profile.loaded then return end
 if rng:NextNumber()<Mastery.SkipShardChance then
  throw.shardsFound+=1
  profile.traitShards+=1
  Remotes.TraitShardFound:FireClient(throw.player,position,profile.traitShards)
  Profiles.fireChanged(throw.player)
 end
end
function P.finish(throw,reason)
 if throw.masteryAwarded then return end
 throw.masteryAwarded=true
 if reason=="interrupted" or not throw.player.Parent or throw.skips<1 or throw.maxDistance<40 or os.clock()-throw.startedAt<1 then return end
 local profile=Profiles.get(throw.player)
 local id=throw.rockInstanceId
 local record=id and profile.rockMastery[id]
 if not profile.loaded or not record then return end
 local before=Mastery.level(record.xp)
 local isRecord=throw.maxDistance>(record.best or 0)+5
 local gain=Mastery.award(throw.maxDistance,throw.skips,isRecord,throw.firstCompletions,throw.masteryMultiplier)
 record.xp=math.min(Mastery.threshold(Mastery.MaxLevel),record.xp+gain)
 record.best=math.max(record.best or 0,math.floor(throw.maxDistance))
 record.throws=(record.throws or 0)+1
 local after=Mastery.level(record.xp)
 if after>before then
  local progress=Mastery.progress(record)
  if after>=5 then profile.permanentTitles[progress.title]=true end
  Remotes.MasteryUp:FireClient(throw.player,throw.rockId,progress)
 end
 Profiles.fireChanged(throw.player)
end
return P
