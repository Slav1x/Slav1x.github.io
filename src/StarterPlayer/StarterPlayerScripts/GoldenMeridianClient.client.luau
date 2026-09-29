-- Golden Meridian (client): the Golden Rock, its one-time speech after the tenth
-- awakening, its calling, and the whole true-rebirth sequence:
--   Golden Rock -> the light -> Spirit Realm -> the Pebble God -> the Divine Skip Trial
--   -> the blessing -> the Golden Meridian -> sent onward -> To Be Continued -> home.
-- GoldenMeridianService on the server owns every decision; this script presents them and
-- always lands the player safely back at the stone, however the sequence ends.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
local Golden=require(RS.Shared.GoldenMeridianConfig)
local Director=require(script.Parent.GoldenDirector)
local Audio=require(script.Parent.GoldenAudio)
local Dialogue=require(script.Parent.GoldenDialogue)
local GoldenRock=require(script.Parent.GoldenRock)
local RockCinematic=require(script.Parent.GoldenRockCinematic)
local SpiritRealm=require(script.Parent.SpiritRealm)
local PebbleGod=require(script.Parent.PebbleGod)
local Trial=require(script.Parent.DivineTrial)
local Blessing=require(script.Parent.GoldenBlessing)
local Ending=require(script.Parent.GoldenEnding)
local player=Players.LocalPlayer
local event=RS:WaitForChild("GoldenMeridianEvent")
local rock=GoldenRock.new()
local session=nil
local speaking=false
local function stage() return player:GetAttribute("GoldenPath") or "Dormant" end
local function seen() return player:GetAttribute("GoldenInvitationSeen")==true end
local function refresh() rock:setStage(stage(),seen()) end
for _,name in {"GoldenPath","GoldenInvitationSeen"} do player:GetAttributeChangedSignal(name):Connect(refresh) end
refresh()
rock.onPrompt=function()
 if session or speaking then return end
 event:FireServer("Begin")
end
local function busy()
 return player:GetAttribute("RockInFlight")==true or player:GetAttribute("RebirthCinematic")==true or player:GetAttribute("RebirthCutscene")==true
  or player:GetAttribute("NoobDialogueOpen")==true or player:GetAttribute("GoldenCutscene")==true
end
local function watchCharacter(D)
 local character=player.Character
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then D:abort("died");return end
 D:connect(hum.Died,function() D:abort("died") end)
 D:connect(player.CharacterRemoving,function() D:abort("died") end)
end
---------------------------------------------------------------- the stone speaks, once
local function speak()
 speaking=true
 local D=Director.new("speech")
 D:takeScene();D:setPrompts(false)
 watchCharacter(D)
 local audio=Audio.begin();D:add(audio)
 local dlg=Dialogue.new(D,audio)
 D:add(function() rock.quiet=false;rock.override=nil;rock.flare=0 end)
 local ok,result=pcall(rock.speak,rock,D,dlg,audio)
 if not ok then warn("[Golden] speech: "..tostring(result)) end
 local finished=ok and result==true and D.alive
 D:close()
 if finished then rock.seen=true;event:FireServer("InvitationSeen") end
 speaking=false
end
local pendingSince=nil
local accumulator=0
Run.Heartbeat:Connect(function(dt)
 accumulator+=dt
 if accumulator<.4 then return end
 accumulator=0
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 local ready=not session and not speaking and stage()=="Invited" and not seen() and not rock.seen and not busy()
  and rock.v~=nil and root~=nil and hum~=nil and hum.Health>0 and (root.Position-rock.v.cf.Position).Magnitude<60
 if not ready then pendingSince=nil;return end
 -- A moment after the tenth awakening's cutscene ends, the stone speaks.
 pendingSince=pendingSince or os.clock()
 if os.clock()-pendingSince>1.2 then pendingSince=nil;task.spawn(speak) end
end)
---------------------------------------------------------------- the true rebirth
local function send(s,action,value) event:FireServer(action,s.token,value) end
-- Every stage announces itself in Output, so a failure always says where it happened.
local function stage(s,name) s.stage=name;print("[Golden] "..name) end
local function await(s,kind,timeout)
 s.D:waitUntil(function() return s.inbox[kind]~=nil end,timeout)
 local data=s.inbox[kind]
 s.inbox[kind]=nil
 return data
end
local function characterParts()
 local list={}
 if player.Character then for _,d in player.Character:GetDescendants() do if d:IsA("BasePart") then table.insert(list,d) end end end
 return list
end
local function sayLines(ctx,lines,speaker,cues)
 for _,line in lines do
  local cue=line.cue and cues[line.cue]
  if not ctx.dlg:say(speaker(),line[1],{onShow=cue}) then return false end
 end
 return true
end
local function run(s)
 local D=s.D
 local audio=Audio.begin();D:add(audio)
 local dlg=Dialogue.new(D,audio)
 local ctx={D=D,audio=audio,dlg=dlg,rock=rock,mode=s.mode,
  send=function(action,value) send(s,action,value) end,
  await=function(kind,timeout) return await(s,kind,timeout) end}
 ---------------------------------------------------------------- 1. the Golden Rock
 stage(s,"1/6 golden rock cutscene")
 local engulf=RockCinematic.play(ctx,s.mode)
 if not D.alive then return end
 ---------------------------------------------------------------- 2. the realm is built inside the light
 stage(s,"2/6 building the spirit realm")
 local realm=SpiritRealm.build(D,s.basis,audio)
 local godPos=realm:point(Golden.Realm.God)
 local spawnPoint=realm:point(Vector3.zero)
 local god=PebbleGod.new(realm,CFrame.lookAt(godPos,spawnPoint))
 realm:reflect(god:parts())
 D:every(function(dt) god:update(dt) end)
 ctx.realm=realm;ctx.god=god
 ---------------------------------------------------------------- 3. crossing over
 stage(s,"3/6 crossing into the realm")
 ctx.send("EnterRealm")
 if not ctx.await("Arrived",10) then D:abort("the way did not open");return end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not root then D:abort("no character");return end
 D:waitUntil(function() return (root.Position-spawnPoint).Magnitude<15 end,6)
 engulf:settle()
 realm:reflect(characterParts())
 realm:start();realm:startSound()
 -- First sight of the realm: low over the water, the god a shape far away in the mist.
 local toGod=((godPos-spawnPoint)*Vector3.new(1,0,1)).Unit
 local side=toGod:Cross(Vector3.yAxis)
 local reveal0=CFrame.lookAt(spawnPoint-toGod*6+Vector3.new(0,1.1,0)+side*1.5,godPos+Vector3.new(0,6,0))
 local reveal1=CFrame.lookAt(spawnPoint-toGod*8.5+Vector3.new(0,4.4,0)+side*2.2,godPos+Vector3.new(0,5,0))
 D:shoot(reveal0,50)
 D:setBars(1)
 D:spawn(function() engulf:dissolve(3.4) end)
 audio:set("tail",0,4);audio:set("drone",0,5)
 D:animate(5.6,function(a) D:shoot(reveal0:Lerp(reveal1,D.inOut(a)),50) end)
 if not D.alive then return end
 ---------------------------------------------------------------- 4. the player walks to him
 stage(s,"4/6 walking to the Pebble God")
 ctx.send("Walk")
 D:spawn(function() D:bars(0,1.4) end)
 D:freeCamera();D:lockControls(false);D:setPrompts(true)
 local known=s.mode~="trial"
 local anchor=Instance.new("Part")
 anchor.Name="GodPresence";anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Transparency=1
 anchor.Size=Vector3.one;anchor.CFrame=CFrame.new(godPos-toGod*4+Vector3.new(0,3,0));anchor.Parent=realm.folder
 local listen=Instance.new("ProximityPrompt")
 listen.ActionText="Listen";listen.ObjectText=known and "The Pebble God" or "· · ·";listen.HoldDuration=0;listen.MaxActivationDistance=20
 listen.RequiresLineOfSight=false;listen.KeyboardKeyCode=Enum.KeyCode.E;listen.GamepadKeyCode=Enum.KeyCode.ButtonY;listen.Parent=anchor
 local listened=false
 D:connect(listen.Triggered,function() listened=true end)
 local near=0
 local function flatDistance() return ((root.Position-godPos)*Vector3.new(1,0,1)).Magnitude end
 local stopApproach=D:every(function(dt)
  local d=flatDistance()
  local k=math.clamp(1-(d-24)/200,0,1)
  realm:proximityTo(k)
  audio:set("choir",.02+.16*k,.3)
  realm:setPath(math.clamp((d-30)/40,0,1))
  if d<130 then god:setLook(root.Position) end
  god:setGlow(.35+.45*k)
  if d<30 then near+=dt else near=0 end
 end)
 D:waitUntil(function() return listened or near>7 or flatDistance()<14 end)
 stopApproach()
 listen:Destroy()
 if not D.alive then return end
 ---------------------------------------------------------------- 5. he speaks
 stage(s,"5/6 the Pebble God speaks")
 D:lockControls(true);D:setPrompts(false)
 local function talkShot()
  local stand=root.Position
  local flat=((godPos-stand)*Vector3.new(1,0,1)).Unit
  local s2=flat:Cross(Vector3.yAxis)
  return CFrame.lookAt(stand-flat*6.5+s2*4+Vector3.new(0,3,0),god.root.Position+Vector3.new(0,7,0)),flat
 end
 local talk,flat=talkShot()
 root.CFrame=CFrame.lookAt(root.Position,root.Position+flat)
 local from=workspace.CurrentCamera.CFrame
 D:animate(1.3,function(a) D:shoot(from:Lerp(talk,D.inOut(a)),52);D:setBars(D.smooth(a)) end)
 local function speaker() return known and Golden.Speaker.God or Golden.Speaker.Unknown end
 local cues={
  lift=function() god:setPose("lift",.8) end,
  stonesStir=function()
   god:riseStones(.35);realm:liftMonoliths(8)
   task.delay(3.5,function() god:riseStones(0);realm:liftMonoliths(0) end)
  end,
  reveal=function() known=true;god:setGlow(1);realm.mistLevel=.85 end,
  mist=function()
   -- He only glances at the horizon; the mist withdraws.
   god:setLook(godPos+realm.basis.LookVector*400)
   task.delay(2.2,function() god:setLook(root.Position) end)
   D:spawn(function() D:animate(2.5,function(a) realm.mistLevel=.85-.3*D.smooth(a) end) end)
   realm:flash(Golden.WhiteGold,.25)
  end,
  stonesFreeze=function()
   god:freezeStones(true);realm.mist.TimeScale=.1
   task.delay(3,function() god:freezeStones(false);if realm.mist.Parent then realm.mist.TimeScale=1 end end)
  end,
  send=function() god:setPose("send",1) end,
 }
 if s.mode=="trial" then
  if not sayLines(ctx,Golden.Script.Arrival,speaker,cues) then return end
  -- The server opens the trial only when the player really stands before him.
  local opened=false
  for _=1,6 do
   ctx.send("TrialReady")
   D:waitUntil(function() return s.inbox.TrialOpen~=nil or s.inbox.TrialHold~=nil end,4)
   if s.inbox.TrialOpen then s.inbox.TrialOpen=nil;opened=true;break end
   s.inbox.TrialHold=nil
   if not D:wait(1) then return end
  end
  if not opened then D:abort("the trial did not open");return end
  if not Trial.run(ctx) then return end
  -- He is not impressed. He is satisfied: a small nod, and his eyes open a little.
  talk=talkShot()
  D:shoot(talk,52)
  god:setLook(root.Position)
  god:setEyes(.35)
  god.target.headPitch=-.18
  task.delay(1,function() god.target.headPitch=0 end)
  if not D:wait(1.2) then return end
  if not sayLines(ctx,Golden.Script.Success,speaker,cues) then return end
  dlg:close()
  if not Blessing.run(ctx) then return end
  if not sayLines(ctx,Golden.Script.AfterBlessing,speaker,cues) then return end
 elseif s.mode=="unfinished" then
  if not sayLines(ctx,Golden.Script.Unfinished,speaker,cues) then return end
  dlg:close()
  if not Blessing.run(ctx) then return end
  if not sayLines(ctx,Golden.Script.AfterBlessing,speaker,cues) then return end
 else
  if not sayLines(ctx,Golden.Script.Memory,speaker,cues) then return end
 end
 dlg:close()
 ---------------------------------------------------------------- 6. sent onward
 stage(s,"6/6 sent onward")
 if not Ending.sendOff(ctx) then return end
 local card=Ending.card(ctx)
 s.card=card
 s.expectingReturn=true
 card:hold()
 ctx.send("Finish")
end
-- However the sequence ended, bring the player home behind a black card.
local function land(s)
 local D=s.D
 local character=player.Character
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 local alive=hum~=nil and hum.Health>0 and D.reason~="died"
 local card=s.card
 if not card then
  local gui=Instance.new("ScreenGui");gui.Name="GoldenLanding";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=1002
  local cover=Instance.new("Frame");cover.Size=UDim2.fromScale(1,1);cover.BackgroundColor3=Color3.new(0,0,0);cover.BorderSizePixel=0;cover.Parent=gui
  gui.Parent=player.PlayerGui
  card={}
  function card:dismiss(seconds)
   local start=os.clock()
   while os.clock()-start<seconds do cover.BackgroundTransparency=(os.clock()-start)/seconds;task.wait() end
   gui:Destroy()
  end
 end
 D:close()
 if alive then
  if not s.returned then
   -- After "Finish" the server is already bringing us home; otherwise ask it to.
   if not s.expectingReturn then send(s,"Cancel") end
   local deadline=os.clock()+6
   while not s.returned and os.clock()<deadline do task.wait() end
  end
  local root=character:FindFirstChild("HumanoidRootPart")
  task.wait(.15)
  if root then pcall(function() player:RequestStreamAroundAsync(root.Position,4) end) end
  send(s,"Landed")
  task.wait(.3)
 end
 local reason=s.failure and ("The golden sequence stopped at "..s.failure) or s.returnReason
 if type(reason)=="string" and #reason>12 then
  pcall(function() StarterGui:SetCore("SendNotification",{Title="The Magical Rock",Text=reason,Duration=12}) end)
 end
 card:dismiss(1.2)
 if session==s then session=nil end
 refresh()
end
local function startSession(data)
 if session or speaking then event:FireServer("Cancel",data.token);return end
 local s={token=data.token,mode=data.mode,basis=data.basis,inbox={},returned=false,expectingReturn=false}
 session=s
 local D=Director.new("golden")
 s.D=D
 D:takeScene();D:setPrompts(false)
 watchCharacter(D)
 rock:setQuiet(true)
 D:add(function() rock:setQuiet(false) end)
 task.spawn(function()
  local ok,err=xpcall(run,debug.traceback,s)
  if not ok then
   warn("[Golden] stopped during '"..tostring(s.stage).."': "..tostring(err))
   s.failure=tostring(s.stage)..": "..string.sub(tostring(err),1,160)
  elseif not D.alive and D.reason and D.reason~="returned" then
   warn("[Golden] ended during '"..tostring(s.stage).."': "..tostring(D.reason))
  end
  local landed,landError=xpcall(land,debug.traceback,s)
  if not landed then
   warn("[Golden] landing failed: "..tostring(landError))
   -- Never leave the screen covered: remove any landing card and release the scene.
   pcall(function() D:close() end)
   local card=player.PlayerGui:FindFirstChild("GoldenLanding")
   if card then card:Destroy() end
   if session==s then session=nil end
   pcall(function() send(s,"Landed") end)
   pcall(refresh)
  end
 end)
end
event.OnClientEvent:Connect(function(action,data)
 if type(data)~="table" then return end
 if action=="Begin" then startSession(data);return end
 local s=session
 if not s or data.token~=s.token then return end
 s.inbox[action]=data
 if action=="Returned" then
  s.returned=true;s.returnReason=data.reason
  if not s.expectingReturn and s.D then s.D:abort("returned") end
 end
end)
