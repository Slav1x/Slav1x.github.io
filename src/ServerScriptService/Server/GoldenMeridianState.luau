-- Golden Meridian progress inside the existing player profile (profile.goldenPath).
-- Persistence calls serialise/deserialise, so this rides in the same save document,
-- the same UpdateAsync and the same autosave as everything else the player owns.
local RS=game:GetService("ReplicatedStorage")
local Progression=require(RS.Shared.ProgressionConfig)
local S={}
-- invitationSeen  the stone spoke after the tenth awakening
-- trialStarted    the player has stood before the Pebble God at least once
-- trialCompleted  the divine skip reached the light
-- unlocked        the Golden Meridian is awakened (granted with trialCompleted)
-- world2          World 2 eligibility (granted with the Golden Meridian)
-- endingSeen      the blessing and "To Be Continued" played through
S.Flags={"invitationSeen","trialStarted","trialCompleted","unlocked","world2","endingSeen"}
function S.get(profile)
 local path=profile.goldenPath
 if type(path)~="table" then path={};profile.goldenPath=path end
 return path
end
-- Dormant: fewer than ten awakenings. Invited: the stone is calling. Awakened: gold.
function S.stage(profile)
 local path=S.get(profile)
 if path.unlocked==true then return "Awakened" end
 if (tonumber(profile.rebirths) or 0)>=Progression.NormalRebirths then return "Invited" end
 return "Dormant"
end
function S.serialise(profile)
 local path=profile.goldenPath
 if type(path)~="table" then return nil end
 local out={v=1}
 for _,flag in S.Flags do if path[flag]==true then out[flag]=true end end
 if Progression.isFinite(path.unlockedAt) then out.unlockedAt=math.floor(path.unlockedAt) end
 return out
end
function S.deserialise(profile,data)
 local path={}
 if type(data)=="table" then
  for _,flag in S.Flags do if data[flag]==true then path[flag]=true end end
  if Progression.isFinite(data.unlockedAt) then path.unlockedAt=math.floor(data.unlockedAt) end
  -- The grant is atomic; repair any half-written combination defensively.
  if path.unlocked or path.trialCompleted then path.unlocked=true;path.trialCompleted=true;path.world2=true;path.trialStarted=true end
 end
 profile.goldenPath=path
end
return S
