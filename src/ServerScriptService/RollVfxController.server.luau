local prompt = workspace:WaitForChild("terrain"):WaitForChild("SpinButton"):WaitForChild("ProximityPrompt")
local RS, RunService = game:GetService("ReplicatedStorage"), game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Profiles = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Profiles"))
local Models = RS:WaitForChild("RockModels")
local Catalog = require(RS.Shared:WaitForChild("RockCatalog"))
local RockAppearance = require(RS.Shared:WaitForChild("RockAppearance"))
local Config = require(RS.Shared:WaitForChild("SummonConfig"))
local Zones = require(RS.Shared:WaitForChild("ZoneConfig"))
local Transaction = require(script.Parent:WaitForChild("SummonTransaction"))
local random = Random.new()
local interact = RS:FindFirstChild("SummonInteract") or Instance.new("RemoteEvent")
interact.Name="SummonInteract";interact.Parent=RS
local rarityTiming={Common=.65,Uncommon=.75,Rare=.85,Epic=1.0,Legendary=1.2,Mythical=1.4}
local function smooth(t) return t*t*t*(t*(t*6-15)+10) end
local Geode=require(RS.Shared:WaitForChild("GeodeReveal"))
local Progression=require(script.Parent:WaitForChild("GeodeProgression"))
local feedback = RS:FindFirstChild("SummonFeedback") or Instance.new("RemoteEvent")
feedback.Name="SummonFeedback";feedback.Parent=RS
local autoRoll = RS:FindFirstChild("SummonAutoRoll") or Instance.new("RemoteEvent")
autoRoll.Name="SummonAutoRoll";autoRoll.Parent=RS

local vfx = {
 Common={Color3.fromRGB(210,230,255),8,18,1.2,2,1},Uncommon={Color3.fromRGB(110,255,145),13,28,1.5,3,1},
 Rare={Color3.fromRGB(75,195,255),20,42,1.9,5,1},Epic={Color3.fromRGB(190,100,255),30,65,2.4,7,2},
 Legendary={Color3.fromRGB(255,205,55),45,95,3.1,10,3},Mythical={Color3.fromRGB(255,75,220),65,140,4,14,4},
}
-- A session owns only its player's input, models, timers, and cleanup.
local sessions = {}
local autoModes = {}
local function setAutoMode(player,count,reason)
 autoModes[player]=count
 if player.Parent then feedback:FireClient(player,"AutoRollState",{mode=count or 0,reason=reason}) end
end
local scenes = RS:FindFirstChild("SummonScenes") or Instance.new("Folder")
scenes.Name="SummonScenes";scenes.Parent=RS
local Announcements=require(script.Parent:WaitForChild("SummonAnnouncements"))
prompt.Style = Enum.ProximityPromptStyle.Custom
prompt:SetAttribute("SummonPrompt", true)
prompt:SetAttribute("SummonCost", Config.Cost)
prompt.ActionText="Summon"
prompt:SetAttribute("SummonState","Ready")
local function weightFor(id)
 for _,entry in ipairs(Config.Pool) do if entry.id==id then return entry.weight end end
 return 0
end
local function placeCentered(model,cf)
 -- Recalculate after ScaleTo: imported pivots and scaled PivotOffsets can differ.
 model:PivotTo(cf)
 local bounds=model:GetBoundingBox()
 model:PivotTo(model:GetPivot()+(cf.Position-bounds.Position))
end
local function make(id,cf,masked,parent,variant)
 local m=RockAppearance.clone(id,variant)
 for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false if masked then p.Color=Color3.new() end end end
 if masked then local h=Instance.new("Highlight");h.FillTransparency=1;h.OutlineColor=Color3.new(1,1,1);h.Parent=m end
 placeCentered(m,cf);m.Parent=parent;return m
end
local function aura(pos,rarity)
 local e=vfx[rarity] or vfx.Common
 local a=Instance.new("Part");a.Anchored=true;a.CanCollide=false;a.CanQuery=false;a.Transparency=1;a.Size=Vector3.one;a.Position=pos;a.Parent=workspace
 local at=Instance.new("Attachment");at.Parent=a
 local p=Instance.new("ParticleEmitter");p.Texture="rbxasset://textures/particles/sparkles_main.dds";p.Color=ColorSequence.new(e[1]);p.Rate=e[2];p.Lifetime=NumberRange.new(.5,1.1);p.Speed=NumberRange.new(2,7);p.SpreadAngle=Vector2.new(360,360);p.LightEmission=.9;p.Parent=at
 local l=Instance.new("PointLight");l.Color=e[1];l.Brightness=e[5];l.Range=10+e[4]*5;l.Parent=a
 return function() p.Enabled=false;l.Enabled=false;task.delay(1.2,function() if a.Parent then a:Destroy() end end) end
end
local function reveal(m,rarity)
 local tier=table.find(Progression.Order,rarity) or 1
 local e=vfx[rarity] or (tier>=6 and vfx.Mythical or vfx.Common)
 local impact=tier>=5 and math.min(3,1.8+(tier-5)*.6) or 1
 local part=m:FindFirstChildWhichIsA("BasePart",true);if not part then return end
 local at=Instance.new("Attachment");at.Parent=part
 local p=Instance.new("ParticleEmitter");p.Texture="rbxasset://textures/particles/sparkles_main.dds";p.Color=ColorSequence.new(e[1]);p.Rate=0;p.Lifetime=NumberRange.new(.6,1.4);p.Speed=NumberRange.new(8*impact,(15+e[4]*4)*impact);p.SpreadAngle=Vector2.new(360,360);p.LightEmission=1;p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(.15,(.18+e[4]*.07)*math.sqrt(impact)),NumberSequenceKeypoint.new(1,0)});p.Transparency=NumberSequence.new(.15,1);p.Drag=5;p.Parent=at;p:Emit(math.ceil(e[3]*.3*impact))
 local l=Instance.new("PointLight");l.Color=e[1];l.Brightness=e[5]*.35*impact;l.Range=(12+e[4]*2)*impact;l.Parent=part
 TweenService:Create(l,TweenInfo.new(.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Brightness=0}):Play()
 task.delay(1.6,function() if at.Parent then at:Destroy() end if l.Parent then l:Destroy() end end)
end
local function rewardSpinAngle(lane)
 -- One clock from shell break through display, including skipped reveal frames.
 return -math.pi*.65+(time()-lane.spinStarted)*math.rad(125)
end
local function startSpin(lane)
 if lane.spin then lane.spin:Disconnect() end
 local activeModel, basePivot, phaseStart
 lane.spin = RunService.Heartbeat:Connect(function()
  if not lane.current or not lane.current.Parent then lane.spin:Disconnect();lane.spin=nil return end

  -- A new preview keeps its own neutral centre, so tilt never accumulates.
  if lane.current ~= activeModel then
   activeModel, phaseStart = lane.current, time()
   local bounds=lane.current:GetBoundingBox()
   basePivot=CFrame.new(bounds.Position)*lane.revealOrigin.Rotation
  end
  local t = time() - phaseStart
  local settle=smooth(math.clamp(t/.4,0,1))
  local hover = (math.sin(t * 2.05) * 0.24 + math.sin(t * 4.1) * 0.02)*settle
  local spinAngle = rewardSpinAngle(lane)

  placeCentered(lane.current,
   CFrame.new(basePivot.Position + Vector3.new(0, hover, 0))
   * (basePivot - basePivot.Position)
   * CFrame.Angles(0, spinAngle, 0)
  )

 end)
end
local function showRarityLabel(rock, rarity)
 local colors = {
  Common = Color3.new(1, 1, 1),
  Uncommon = Color3.fromRGB(94, 201, 98),
  Rare = Color3.fromRGB(66, 148, 255),
  Epic = Color3.fromRGB(171, 104, 255),
  Legendary = Color3.fromRGB(255, 189, 62),
  Mythical = Color3.fromRGB(255, 75, 220),
 }
 local part = rock:FindFirstChildWhichIsA("BasePart", true)
 if not part then return end
 local board = Instance.new("BillboardGui")
 board.Name = "RarityReveal"
 board.Adornee = part
 board.Size = UDim2.fromOffset(360, 92)
 board.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
 board.AlwaysOnTop = true
 board.MaxDistance = 100
 board.Parent = part
 local text = Instance.new("TextLabel")
 text.Size = UDim2.fromScale(1, 1)
 text.BackgroundTransparency = 1
 text.Text = string.upper(rarity) .. "!"
 text.Font = Enum.Font.FredokaOne
 local rarityColor = colors[rarity] or Color3.new(1, 1, 1)
 text.TextColor3 = Color3.new(1, 1, 1)
 text.TextStrokeColor3 = rarityColor
 text.TextStrokeTransparency = 0
 text.TextScaled = true
 text.TextTransparency = 1
 text.TextStrokeTransparency = 1
 text.Parent = board
 TweenService:Create(text, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
 -- A looping rarity-color outline makes the reward text feel alive.
 TweenService:Create(text, TweenInfo.new(0.32, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {TextStrokeTransparency = 0.42}):Play()
 TweenService:Create(board, TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {StudsOffsetWorldSpace = Vector3.new(0, 4.35, 0)}):Play()
 task.delay(1.05, function()
  if not text.Parent then return end
  TweenService:Create(text, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
  task.delay(0.35, function() if board.Parent then board:Destroy() end end)
 end)
end

local function createOddsBoard()
 local host=prompt.Parent
 local old=host:FindFirstChild("RollOddsBoard");if old then old:Destroy() end
 local board=Instance.new("BillboardGui");board.Name="RollOddsBoard";board.Adornee=host
 board.Size=UDim2.fromOffset(468,238);board.StudsOffsetWorldSpace=Vector3.new(0,9.5,0)
 board.MaxDistance=42;board.AlwaysOnTop=true;board.LightInfluence=0;board.Enabled=false;board.Parent=host -- Client displays the probability panel near the station.
 local function round(parent,r)
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r);c.Parent=parent
 end
 local function label(parent,name,text,x,y,w,h,size,color)
  local t=Instance.new("TextLabel");t.Name=name;t.BackgroundTransparency=1
  t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);t.Font=Enum.Font.GothamBold
  t.Text=text;t.TextSize=size;t.TextColor3=color;t.Parent=parent;return t
 end
 local white=Color3.fromRGB(237,245,255)
 local bg=Instance.new("Frame");bg.Name="Panel";bg.Size=UDim2.fromScale(1,1)
 bg.BackgroundColor3=Color3.fromRGB(12,20,34);bg.BackgroundTransparency=.24;bg.BorderSizePixel=0;bg.Parent=board;round(bg,18)
 local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(130,218,245);stroke.Transparency=.55;stroke.Parent=bg
 local title=label(bg,"Title","SUMMON CHANCES",16,9,285,26,19,white);title.TextXAlignment=Enum.TextXAlignment.Left
 local price=label(bg,"Price",tostring(Config.Cost).." COINS",324,13,128,20,12,Color3.fromRGB(255,222,132));price.TextXAlignment=Enum.TextXAlignment.Right
 local sub=label(bg,"Subtitle","Every geode holds a discovery",16,35,436,18,11,Color3.fromRGB(168,192,213));sub.TextXAlignment=Enum.TextXAlignment.Left
 local total=Config.totalWeight()
 for i,entry in ipairs(Config.Pool) do
  local rock=Catalog.get(entry.id)
  local color=Catalog.RarityColors[rock.rarity] or white
  local card=Instance.new("Frame");card.Name=entry.id;card.Size=UDim2.fromOffset(140,72)
  card.Position=UDim2.fromOffset(16+((i-1)%3)*148,61+math.floor((i-1)/3)*79)
  card.BackgroundColor3=Color3.fromRGB(28,39,56);card.BackgroundTransparency=.2;card.BorderSizePixel=0;card.Parent=bg;round(card,10)
  local rim=Instance.new("UIStroke");rim.Color=color;rim.Transparency=.65;rim.Parent=card
  local icon=Instance.new("ImageLabel");icon.Name="RockImage";icon.BackgroundTransparency=1
  icon.Position=UDim2.fromOffset(5,4);icon.Size=UDim2.fromOffset(51,42);icon.Image=rock.image or "";icon.ScaleType=Enum.ScaleType.Fit;icon.Parent=card
  local odds=label(card,"Probability",string.format("%.2f%%",entry.weight/total*100),56,7,79,23,19,color)
  label(card,"Rarity",string.upper(rock.rarity),56,29,79,14,9,color)
  local name=label(card,"RockName",rock.name,6,49,128,17,11,white)
  name.TextTruncate=Enum.TextTruncate.AtEnd
 end
 label(bg,"Footer","ITEM DROP CHANCES  •  REWARDS STORE AUTOMATICALLY",16,220,436,12,9,Color3.fromRGB(168,192,213))
end

createOddsBoard()


-- Prompts stay available to everyone; each player can own one batch.
local triplePrompt=prompt.Parent:FindFirstChild("SummonThreePrompt") or Instance.new("ProximityPrompt")
triplePrompt.Name="SummonThreePrompt"
triplePrompt.ActionText="Summon 3"
triplePrompt.ObjectText="Three geodes"
triplePrompt.Style=Enum.ProximityPromptStyle.Custom
triplePrompt.KeyboardKeyCode=Enum.KeyCode.R
triplePrompt.GamepadKeyCode=Enum.KeyCode.ButtonY
triplePrompt.HoldDuration=prompt.HoldDuration
triplePrompt.MaxActivationDistance=prompt.MaxActivationDistance
triplePrompt.RequiresLineOfSight=prompt.RequiresLineOfSight
triplePrompt.Exclusivity=Enum.ProximityPromptExclusivity.AlwaysShow
prompt.Exclusivity=Enum.ProximityPromptExclusivity.AlwaysShow
triplePrompt:SetAttribute("SummonTriplePrompt",true)
triplePrompt:SetAttribute("SummonCost",Config.Cost*3)
triplePrompt.Parent=prompt.Parent
local generation=0
local lastRequest={}
local function notify(player,message)
 if player.Parent then feedback:FireClient(player,"Error",{message=message}) end
end
local function inRange(player,part,distance)
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildWhichIsA("Humanoid")
 return root and humanoid and humanoid.Health>0 and (root.Position-part.Position).Magnitude<=distance+3
end
local function closeDisplay(player,token,keepAuto)
 local batch=sessions[player]
 if not batch or token~=batch.token then return end
 sessions[player]=nil
 if not keepAuto and autoModes[player] then setAutoMode(player,nil,"Auto-roll stopped") end
 if batch.removing then batch.removing:Disconnect() end
 if batch.died then batch.died:Disconnect() end
 if batch.root.Parent then batch.root.Anchored=batch.wasAnchored end
 for _,lane in batch.lanes do
  if lane.spin then lane.spin:Disconnect() end
  if lane.current then lane.current:Destroy() end
 end
 if batch.player.Parent then feedback:FireClient(batch.player,"Closed",{token=token}) end
 batch.scene:Destroy()
end
local function emit(batch,lane,kind,data)
 data.token=batch.token;data.slot=lane.index;data.batchSize=#batch.lanes
 -- Forward the actual reward rank so lens effects also scale with future rarity tiers.
 if data.rarity then data.rarityTier=table.find(Progression.Order,data.rarity) end
 feedback:FireClient(batch.player,kind,data)
end

local function runBatch(batch)
 local player,profile,money=batch.player,batch.profile,batch.money
 local function valid()
  if sessions[player]~=batch or not player.Parent then return false end
  if not inRange(player,prompt.Parent,prompt.MaxActivationDistance) then closeDisplay(player,batch.token);return false end
  return true
 end
 local function animate(seconds,step,skippable)
  local began=os.clock()
  while valid() do
   local t=math.clamp((os.clock()-began)/seconds,0,1)
   step(t)
   if t>=1 then break end
   if skippable and batch.queued>0 then step(1);break end
   RunService.Heartbeat:Wait()
  end
  return valid()
 end
 local function sealAll()
  for _,lane in batch.lanes do
   local state=lane.state
   emit(batch,lane,"Seal",{hits=state.hits,total=state.total,
    required=Progression.Cracks[state.tier],rarity=Progression.Order[state.tier]})
  end
 end
 for _,lane in batch.lanes do
  local cf=Config.slotCFrame(lane.index,#batch.lanes)
  lane.target=cf*CFrame.new(0,Config.RiseHeight,0)
  lane.base=cf
  lane.current=Geode.create(cf,Progression.Order[lane.state.tier],batch.scene)
  lane.current:SetAttribute("SummonToken",batch.token)
  lane.current:SetAttribute("SummonSlot",lane.index)
  lane.scale=lane.current:GetScale()
 end
 if not animate(.65,function(t)
  for _,lane in batch.lanes do lane.current:PivotTo(lane.base:Lerp(lane.target,smooth(t))) end
 end,true) then return end
 for _,lane in batch.lanes do
  lane.current:PivotTo(lane.target)
  Geode.crack(lane.current,lane.state.total,Geode.TotalCracks)
 end
 sealAll()
 local unresolved=#batch.lanes
 while valid() and unresolved>0 do
  while valid() and batch.queued==0 and not batch.auto do RunService.Heartbeat:Wait() end
  if not valid() then return end
  if batch.queued>0 then batch.queued-=1 end
  -- One input and one animation clock drive the entire row, including ready shells.
  for _,lane in batch.lanes do
   local state=lane.state
   if not lane.result then Progression.strike(state) end
   Geode.crack(lane.current,state.total,Geode.TotalCracks)
   emit(batch,lane,"Strike",{hits=state.hits,total=state.total})
   emit(batch,lane,"Checkpoint",{})
  end
  if not animate(Config.CrackBeatSeconds,function(t)
   local kick=math.sin(t*math.pi)^2
   for _,lane in batch.lanes do
    lane.current:PivotTo(lane.target*CFrame.new(0,kick*.32,0)*CFrame.Angles(0,0,math.sin(t*math.pi*2)*kick*.08))
   end
  end,true) then return end
  local upgraded=false
  for _,lane in batch.lanes do
   local state=lane.state
   lane.current:PivotTo(lane.target)
   if not lane.result and state.hits>=Progression.Cracks[state.tier] then
    local win=Progression.resolve(state,random)
    if win then
     local index=table.find(batch.pending.entries,state)
     assert(index,"Missing pending geode")
     local wasFirst=not next(profile.rocksOwned)
     local ok,isNew,count,variant,instanceId=Transaction.commit(profile,money,win,0)
     if wasFirst then profile.starterRockClaimed=true;Profiles.selectRock(profile,win,instanceId) end
     if not ok then error(isNew) end
     table.remove(batch.pending.entries,index)
     if #batch.pending.entries==0 then profile.pendingSummon=nil end
     lane.result={id=win,isNew=isNew,count=count,token=batch.token,variant=variant,instanceId=instanceId}
     lane.info=Catalog.get(win)
     unresolved-=1
     Profiles.fireChanged(player)
    else
     upgraded=true
     local rarity=Progression.Order[state.tier]
     Geode.recolor(lane.current,rarity,Config.TierTransitionSeconds)
     emit(batch,lane,"Upgrade",{rarity=rarity,required=Progression.Cracks[state.tier],total=state.total})
    end
   end
  end
  if unresolved>0 then
   if upgraded and not animate(Config.TierPauseSeconds,function() end,true) then return end
   sealAll()
  end
 end
 if not valid() then return end
 batch.opening=true -- Keep buffered clicks so they can also skip the reveal animation.
 -- All rarities share the longest anticipation and the same shatter frame.
 local duration=0
 for _,lane in batch.lanes do duration=math.max(duration,rarityTiming[lane.info.rarity] or 1.4) end
 for _,lane in batch.lanes do
  emit(batch,lane,"Anticipation",{rarity=lane.info.rarity,duration=duration,variant=lane.result.variant})
 end
 if not animate(duration,function(t)
  local charge=smooth(math.min(t/.85,1))
  local shake=math.sin(t*duration*35)*.035*math.sin(t*math.pi)^2
  for _,lane in batch.lanes do
   lane.current:ScaleTo(lane.scale*(1+.16*charge))
   lane.current:PivotTo(lane.target*CFrame.new(shake,-.16*charge,0)*CFrame.Angles(0,0,shake*.8))
  end
 end,true) then return end
 local spinStarted=time()
 for _,lane in batch.lanes do
  lane.spinStarted=spinStarted
  -- Anticipation lowers the shell; capture its actual center before shattering it.
  lane.revealOrigin=CFrame.new(lane.current.CrystalHeart.Position)*lane.target.Rotation
  local final=make(lane.result.id,lane.revealOrigin*CFrame.Angles(0,-math.pi*.65,0),false,batch.scene,lane.result.variant)
  Geode.shatter(lane.current,lane.info.rarity,table.find(Progression.Order,lane.info.rarity))
  lane.current=final;lane.rewardScale=final:GetScale()
  final:ScaleTo(lane.rewardScale*.55)
  placeCentered(final,lane.revealOrigin*CFrame.Angles(0,rewardSpinAngle(lane),0))
  final:SetAttribute("SummonResultToken",batch.token)
  final:SetAttribute("SummonResultSlot",lane.index)
  emit(batch,lane,"Open",{model=final,rarity=lane.info.rarity,position=lane.revealOrigin.Position,variant=lane.result.variant,id=lane.result.id})
  -- Announce only when this geode opens, after its reward is safely committed.
  Announcements.announce(player,lane.result.id)
  reveal(final,lane.info.rarity)
 end
 if not animate(Config.RevealSeconds,function(t)
  local eased=smooth(t)
  local height=.65*eased+math.sin(t*math.pi)^2*.8
  for _,lane in batch.lanes do
   lane.current:ScaleTo(lane.rewardScale*(.55+.45*eased))
   placeCentered(lane.current,lane.revealOrigin*CFrame.new(0,height,0)*CFrame.Angles(0,rewardSpinAngle(lane),0))
  end
 end,true) then return end
 batch.finished=true;batch.queued=0
 for _,lane in batch.lanes do
  lane.current:ScaleTo(lane.rewardScale)
  placeCentered(lane.current,lane.revealOrigin*CFrame.new(0,.65,0)*CFrame.Angles(0,rewardSpinAngle(lane),0))
  lane.current:SetAttribute("SummonResultToken",batch.token)
  lane.current:SetAttribute("SummonResultSlot",lane.index)
  lane.result.model=lane.current;lane.finished=true
  startSpin(lane)
  emit(batch,lane,"Result",lane.result)
 end
end

interact.OnServerEvent:Connect(function(player,token)
 local batch=sessions[player]
 if not batch or batch.token~=token or player~=batch.player or batch.finished then return end
 if not inRange(player,prompt.Parent,prompt.MaxActivationDistance) then return end
 -- No click cooldown: buffer a complete tier climb plus reveal skips.
 -- Extra inputs cannot start another purchase or award extra rocks.
 batch.queued=math.min(batch.queued+1,Geode.TotalCracks+2)
end)
local function beginSummon(player,requestedCount,automatic,skipCameraIntro)
 local now=os.clock()
 if not automatic and now-(lastRequest[player] or -math.huge)<.5 then return end
 lastRequest[player]=now
 if not inRange(player,prompt.Parent,prompt.MaxActivationDistance) then
  if automatic then setAutoMode(player,nil,"Move closer to the summon station") end
  return
 end
 if sessions[player] then return end
 local selected=player:GetAttribute("SelectedSummonCollection") or "driftwood"
 local zone=Zones.ById[selected] or Zones.List[1]
 local profile=Profiles.get(player)
 if not Zones.unlocked(profile,zone.id) and not profile.pendingSummon then
  if autoModes[player] then setAutoMode(player,nil,"Reach "..zone.name.." to summon these rocks") end
  notify(player,"Reach "..zone.name.." to summon these rocks.");return
 end
 for _,entry in ipairs(zone.pool) do
  local model=Models:FindFirstChild(entry.id)
  if not model or not model:IsA("Model") or not model:FindFirstChildWhichIsA("BasePart",true) then
   if autoModes[player] then setAutoMode(player,nil,"Summoning is temporarily unavailable") end
   notify(player,"Summoning is temporarily unavailable.");return
  end
 end
 local money=Profiles.moneyValue(player)
 if not profile or not profile.loaded then
  if autoModes[player] then setAutoMode(player,nil,"Inventory is not ready") end
  notify(player,"Your inventory is still loading.");return
 end
 if not money or type(profile.rocksOwned)~="table" or type(profile.rockCounts)~="table" then
  if autoModes[player] then setAutoMode(player,nil,"Inventory is not ready") end
  notify(player,"Your inventory is not ready.");return
 end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then
  if autoModes[player] then setAutoMode(player,nil,"Auto-roll stopped") end
  return
 end
 local pending=profile.pendingSummon
 if pending and pending.version~=4 then pending={version=4,entries={pending}} end
 if pending and profile.freeSummonUsed ~= true then profile.freeSummonUsed=true end
 if not pending then
  local introFree = requestedCount == 1 and not next(profile.rocksOwned) and profile.freeSummonUsed ~= true and zone.id=="driftwood"
  local cost = if introFree then 0 else zone.cost * requestedCount
  if money.Value<cost then
   if autoModes[player] then setAutoMode(player,nil,"Not enough coins — auto-roll stopped")
   else notify(player,"You need "..cost.." coins to summon "..requestedCount..".") end
   return
  end
  local entries={}
  for i=1,requestedCount do entries[i]=Progression.new(zone.id,introFree,Profiles.dailyBoostActive(profile,"summon") and 2 or 1) end
  pending={version=4,entries=entries}
  if introFree then profile.freeSummonUsed=true end
  if cost > 0 then money.Value-=cost end
 end
 profile.pendingSummon=pending
 generation+=1
 local batch={token=generation,player=player,profile=profile,money=money,pending=pending,
  root=root,wasAnchored=root.Anchored,lanes={},queued=0,auto=autoModes[player]~=nil}
 for i,state in pending.entries do
  batch.lanes[i]={index=i,state=state}
 end
 local scene=Instance.new("Folder")
 scene.Name=tostring(player.UserId).."_"..tostring(batch.token)
 scene:SetAttribute("OwnerUserId",player.UserId)
 scene:SetAttribute("SummonToken",batch.token)
 -- Only the owning client mounts this folder in Workspace.
 scene.Parent=scenes;batch.scene=scene
 sessions[player]=batch
 root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero;root.Anchored=true
 batch.removing=player.CharacterRemoving:Connect(function() closeDisplay(player,batch.token) end)
 local humanoid=player.Character:FindFirstChildWhichIsA("Humanoid")
 if humanoid then batch.died=humanoid.Died:Connect(function() closeDisplay(player,batch.token) end) end
 Profiles.fireChanged(player)
 local geodes={}
 for i,lane in batch.lanes do
  local state=lane.state
  geodes[i]={slot=i,token=batch.token,batchSize=#batch.lanes,
   position=(Config.slotCFrame(i,#batch.lanes)*CFrame.new(0,Config.RiseHeight,0)).Position,
   rarity=Progression.Order[state.tier],required=Progression.Cracks[state.tier],hits=state.hits,total=state.total}
 end
 feedback:FireClient(player,"Rolling",{token=batch.token,batchSize=#geodes,
  position=(Config.SpawnCFrame*CFrame.new(0,Config.RiseHeight,0)).Position,geodes=geodes,
  skipCameraIntro=skipCameraIntro==true})
 task.spawn(function()
   if sessions[player]~=batch then return end
   local ok,err=xpcall(function() runBatch(batch) end,debug.traceback)
   if not ok then
    warn("[Summon] Display failed: "..tostring(err))
    closeDisplay(player,batch.token)
    return
   end
   if sessions[player]~=batch then return end
   -- Completion and delayed cleanup belong to this session only.
   task.delay(Config.DisplaySeconds,function()
    if sessions[player]~=batch then return end
    for _,entry in batch.lanes do
     emit(batch,entry,"FadeOut",entry.result)
    end
    -- Client fades the full scene on one clock; server reclaims it afterward.
    task.wait(Config.ExitSeconds+.1)
    if sessions[player]~=batch then return end
    feedback:FireClient(player,"Stored",{token=batch.token})
    closeDisplay(player,batch.token,true)
    -- Start the next paid batch on the next scheduler step; recheck funds every time.
    task.defer(function()
     local mode=autoModes[player]
     if mode and not sessions[player] then beginSummon(player,mode,true,true) end
    end)
   end)
  end)
end
autoRoll.OnServerEvent:Connect(function(player,requestedCount)
 if requestedCount~=1 and requestedCount~=3 then return end
 if autoModes[player]==requestedCount then
  setAutoMode(player,nil)
  return
 end
 if not inRange(player,prompt.Parent,prompt.MaxActivationDistance) then
  setAutoMode(player,nil,"Move closer to the summon station")
  return
 end
 setAutoMode(player,requestedCount)
 local batch=sessions[player]
 if batch then batch.auto=true else beginSummon(player,requestedCount,true) end
end)
local collectionRemote=RS:FindFirstChild("SummonCollection") or Instance.new("RemoteEvent")
collectionRemote.Name="SummonCollection";collectionRemote.Parent=RS
local switchedAt={}
collectionRemote.OnServerEvent:Connect(function(player,zoneId,requestId)
 if type(requestId)~="number" or requestId~=requestId or math.abs(requestId)>9e15 then requestId=nil end
 if type(zoneId)~="string" or not Zones.ById[zoneId] then return end
 local zone=Zones.ById[zoneId]
 local function respond(accepted,reason,retryAfter)
  feedback:FireClient(player,"CollectionSelected",{id=zoneId,requestId=requestId,accepted=accepted,
   locked=not Zones.unlocked(Profiles.get(player),zoneId),required=zone.start,cost=zone.cost,
   reason=reason,retryAfter=retryAfter})
 end
 local elapsed=os.clock()-(switchedAt[player] or -math.huge)
 if elapsed<.15 then respond(false,"throttled",.15-elapsed);return end
 switchedAt[player]=os.clock()
 if not inRange(player,prompt.Parent,32) or sessions[player] then respond(false,"busy");return end
 local p=Profiles.get(player)
 if not p.loaded or p.pendingSummon then respond(false,"busy");return end
 -- Selection is a preview choice, never permission to purchase.
 if autoModes[player] then setAutoMode(player,nil,"Auto-roll stopped while browsing") end
 player:SetAttribute("SelectedSummonCollection",zoneId)
 respond(true)
end)
game:GetService("Players").PlayerRemoving:Connect(function(player) switchedAt[player]=nil end)
prompt.Triggered:Connect(function(player) beginSummon(player,1) end)
triplePrompt.Triggered:Connect(function(player) beginSummon(player,3) end)
game:GetService("Players").PlayerRemoving:Connect(function(player)
 autoModes[player]=nil
 lastRequest[player]=nil
 local batch=sessions[player]
 if batch then closeDisplay(player,batch.token) end
end)

