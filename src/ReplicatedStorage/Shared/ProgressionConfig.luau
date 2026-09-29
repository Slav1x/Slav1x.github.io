--!strict
-- Shared progression ceilings and pacing. Collection, traits and mastery are permanent.
local P = {}
P.MaxLevel=100
P.XpPerStud=.10
P.XpPerSkip=4
P.XpPerfectBonus=20
P.LevelMoneyBonus=.003
P.RebirthMoneyBonus=.07
P.StartingSpinStrength=10
P.MaxSpinStrength=9e8
P.MaxEffectiveStrength=1e12
P.MaxRebirths=24
-- Normal rebirths end at the tenth meridian; the Golden Meridian follows (GoldenMeridianService).
-- Derived from the meridian map so the rebirth count and the cutscene always agree.
P.NormalRebirths=#require(script.Parent.AwakeningConfig).Nodes
P.MaxRebirthCost=9e12
local Zones=require(script.Parent.ZoneConfig)
P.MaxRebirthDistance=Zones.List[#Zones.List].finish
P.RebirthBaseCost=12000
P.RebirthCostGrowth=2.1
P.RebirthBaseDistance=1800
P.RebirthDistanceGrowth=1.8
P.RebirthGainPerLevel=.16
P.RebirthGainExponent=.9
P.SpinGainGrowthExponent=.40
P.SpinSkipRewardWeight=.8
P.SpinDistanceRewardWeight=1
P.SpinDistanceRewardUnit=60
P.SpinPerfectRewardBonus=.08
P.MaxBaseThrowSpinGain=16
P.MaxRewardSkips=1000
P.MaxRewardDistance=Zones.List[#Zones.List].finish
P.TrainingBaseGain=.8
P.TrainingCooldown=3
function P.isFinite(v: any): boolean
 return type(v)=="number" and v==v and v>-math.huge and v<math.huge
end
local function rebirthCount(r: any): number
 return P.isFinite(r) and math.clamp(math.floor(r),0,P.MaxRebirths) or 0
end
function P.strengthCap(rebirths: number): number
 local r=rebirthCount(rebirths)
 -- Controlled ceilings: early Rebirths expand the same journey before unlocking another biome.
 return math.min(P.MaxSpinStrength,math.floor(1000*1.8^r))
end
function P.normalizeSpinStrength(value: any, rebirths: number?): number
 if not P.isFinite(value) then return P.StartingSpinStrength end
 return math.clamp(value,P.StartingSpinStrength,if rebirths~=nil then P.strengthCap(rebirths) else P.MaxSpinStrength)
end
function P.safeProduct(a: number,b: number,ceiling: number?): number
 local cap=ceiling or P.MaxEffectiveStrength
 if not P.isFinite(a) or not P.isFinite(b) or a<0 or b<0 then return 0 end
 if b==0 or a==0 then return 0 end
 return if a>=cap/b then cap else math.min(a*b,cap)
end
function P.xpForLevel(level: number): number
 return math.floor(120+level^1.55*55)
end
function P.rebirthCost(rebirths: number): number
 local r=rebirthCount(rebirths)
 return math.min(P.MaxRebirthCost,math.floor(P.RebirthBaseCost*(1+.45*r+.065*r*r)))
end
local function rebirthArea(rebirths: number)
 local r=rebirthCount(rebirths)
 local index=if r<5 then 1 elseif r<8 then 2 elseif r<10 then 3 elseif r<12 then 4
  elseif r==12 then 5 elseif r==13 then 6 elseif r==14 then 7 elseif r==15 then 8 else 9
 return Zones.List[math.min(index,#Zones.List)]
end
function P.rebirthDistance(rebirths: number): number
 return rebirthArea(rebirths).finish
end
function P.rebirthGainMultiplier(rebirths: number): number
 local r=rebirthCount(rebirths)
 if r<=5 then return 1+P.RebirthGainPerLevel*r+.01*r*r end
 -- Offset the integral cost of strength^0.4 gains after five deliberate rebuilds.
 -- Ceiling growth still outpaces gain growth; this avoids multi-hour late rebuilds.
 local baseline=1+P.RebirthGainPerLevel*5+.01*25
 return baseline*(P.strengthCap(r)/P.strengthCap(5))^(1-P.SpinGainGrowthExponent)*(1+.015*(r-5))
end
function P.spinGainMultiplier(strength: number,rebirths: number): number
 return (P.normalizeSpinStrength(strength)/P.StartingSpinStrength)^P.SpinGainGrowthExponent*P.rebirthGainMultiplier(rebirths)
end
function P.throwSpinGain(strength: number,rebirths: number,distance: number,skips: number,isPerfect: boolean): number
 if not P.isFinite(distance) or not P.isFinite(skips) or skips<1 or distance<0 then return 0 end
 local base=P.SpinSkipRewardWeight*math.log(1+math.clamp(math.floor(skips),0,P.MaxRewardSkips),2)
  +P.SpinDistanceRewardWeight*math.log(1+math.clamp(distance,0,P.MaxRewardDistance)/P.SpinDistanceRewardUnit,2)
 base=math.min(P.MaxBaseThrowSpinGain,base*(isPerfect and 1+P.SpinPerfectRewardBonus or 1))
 return math.min(math.max(0,P.strengthCap(rebirths)-strength),base*P.spinGainMultiplier(strength,rebirths))
end
function P.trainingGain(strength: number,rebirths: number): number
 return math.min(math.max(0,P.strengthCap(rebirths)-strength),P.TrainingBaseGain*P.spinGainMultiplier(strength,rebirths))
end
function P.rebirthRequirements(rebirths: number): {[string]: any}
 local r=rebirthCount(rebirths)
 local area=rebirthArea(r)
 return {cost=P.rebirthCost(r),distance=area.finish,areaId=area.id,areaName=area.name,
  strength=math.floor(P.strengthCap(r)*.85),
  powerLevel=math.min(60,10+3*r),nextStrengthCap=P.strengthCap(math.min(r+1,P.MaxRebirths))}
end
function P.canRebirth(profile: any,money: number): (boolean,string)
 if not profile or profile.loaded~=true then return false,"Your save is loading" end
 local r=rebirthCount(profile.rebirths)
 if r>=P.MaxRebirths then return false,"Maximum rebirth potential reached" end
 if r>=P.NormalRebirths then
  local golden=type(profile.goldenPath)=="table" and profile.goldenPath.unlocked==true
  return false,golden and "The Golden Meridian has awakened" or "Ten paths awakened · return to the Magical Rock"
 end
 local q=P.rebirthRequirements(r)
 if not profile.cycleCompletedAreas or profile.cycleCompletedAreas[q.areaId]~=true then return false,"Complete "..q.areaName.." this journey" end
 if (profile.spinStrength or 0)<q.strength then return false,"Reach "..P.formatStrength(q.strength).." Spin Strength" end
 if ((profile.upgrades or {}).power or 0)<q.powerLevel then return false,"Reach Throw Power level "..q.powerLevel end
 if not P.isFinite(money) or money<q.cost then return false,"Save $"..P.formatStrength(q.cost).." for rebirth" end
 return true,"Ready to increase your maximum potential"
end
function P.rebirthTitle(rebirths: number): string
 local titles={"Skipper","River Hand","Coastal Pro","Lakebreaker","Stormcaller","Tidemaster","Deepwater","Legend","Starfarer","Worldbreaker","Celestial","Eternal"}
 return rebirths<=0 and "Rookie" or titles[math.min(rebirthCount(rebirths),#titles)]
end
function P.formatStrength(value: number): string
 if not P.isFinite(value) then return "0" end
 local n=math.max(0,value)
 if n>=1e15 then return string.format("%.2e",n) end
 for _,entry in {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}} do
  if n>=entry[1] then return string.format("%.2f%s",n/entry[1],entry[2]) end
 end
 return n>=100 and string.format("%.0f",n) or string.format("%.1f",n)
end
return P

