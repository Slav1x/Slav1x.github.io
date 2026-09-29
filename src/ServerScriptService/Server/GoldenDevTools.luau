-- STUDIO ONLY. Test hooks for replaying rebirths and every Golden Meridian stage.
-- Refuses to start outside Studio, and every call re-checks IsStudio, so it can never
-- run in a live server even if this module is published by accident.
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Profiles=require(script.Parent.Profiles)
local State=require(script.Parent.GoldenMeridianState)
local Golden=require(script.Parent.GoldenMeridianService)
local Progression=require(RS.Shared.ProgressionConfig)
local D={}
local function standAtStance(player,anchored)
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 local model=workspace:FindFirstChild("MagicalRock")
 local stance=model and model:FindFirstChild("Stance")
 if not root or not hum or not stance then return false,"No character or MagicalRock.Stance" end
 local height=hum.RigType==Enum.HumanoidRigType.R6 and 3 or hum.HipHeight+root.Size.Y/2
 root.AssemblyLinearVelocity=Vector3.zero
 root.Anchored=anchored
 root.CFrame=stance.CFrame+Vector3.new(0,height,0)
 hum.WalkSpeed=anchored and 0 or 16
 return true
end
local actions={}
-- Put the player at the stone exactly as the real rebirth does, for cutscene previews.
actions.stance=function(player) return standAtStance(player,true) end
actions.unstance=function(player) return standAtStance(player,false) end
actions.setRebirths=function(player,n)
 local profile=Profiles.get(player)
 profile.rebirths=math.clamp(math.floor(tonumber(n) or 0),0,Progression.MaxRebirths)
 Profiles.fireChanged(player)
 return true,"Rebirths = "..profile.rebirths
end
-- Meet every requirement for the next real rebirth (the real server flow then runs).
actions.readyRebirth=function(player)
 local profile=Profiles.get(player)
 local q=Progression.rebirthRequirements(profile.rebirths)
 profile.cycleCompletedAreas[q.areaId]=true
 profile.spinStrength=math.max(profile.spinStrength,q.strength)
 profile.upgrades.power=math.max(profile.upgrades.power or 0,q.powerLevel)
 local money=Profiles.moneyValue(player)
 if money then money.Value=math.max(money.Value,q.cost) end
 Profiles.fireChanged(player)
 return true,"Ready for rebirth "..(profile.rebirths+1)
end
-- invitationSeen=false replays the stone's speech; true skips straight to the calling.
actions.resetGolden=function(player,seen)
 local profile=Profiles.get(player)
 if profile.rebirths<Progression.NormalRebirths then profile.rebirths=Progression.NormalRebirths end
 profile.goldenPath={invitationSeen=seen==true}
 Profiles.fireChanged(player)
 return true,"Golden path reset"
end
actions.grantGolden=function(player,endingSeen)
 local profile=Profiles.get(player)
 if profile.rebirths<Progression.NormalRebirths then profile.rebirths=Progression.NormalRebirths end
 profile.goldenPath={invitationSeen=true,trialStarted=true,trialCompleted=true,unlocked=true,world2=true,endingSeen=endingSeen==true,unlockedAt=os.time()}
 Profiles.fireChanged(player)
 return true,"Golden Meridian granted"
end
-- Starts the real golden session from the stone (same checks as the prompt).
actions.beginGolden=function(player)
 if Golden.session(player) then return false,"Session already running" end
 local ok,err=standAtStance(player,false)
 if not ok then return false,err end
 task.wait(.2)
 return Golden.begin(player),"Begin requested"
end
actions.state=function(player)
 local profile=Profiles.get(player)
 local path=State.get(profile)
 local flags={}
 for _,flag in State.Flags do if path[flag] then table.insert(flags,flag) end end
 return true,string.format("rebirths=%d  stage=%s  flags=%s",profile.rebirths,State.stage(profile),#flags>0 and table.concat(flags,",") or "none")
end
function D.start()
 if not RunService:IsStudio() then return end
 local remote=RS:FindFirstChild("GoldenDevTools") or Instance.new("RemoteFunction")
 remote.Name="GoldenDevTools";remote.Parent=RS
 remote.OnServerInvoke=function(player,action,value)
  if not RunService:IsStudio() then return false,"Studio only" end
  local handler=actions[action]
  if not handler or not Profiles.has(player) or not Profiles.get(player).loaded then return false,"Not ready" end
  local ok,result,message=pcall(handler,player,value)
  if not ok then return false,tostring(result) end
  return result,message
 end
end
return D
