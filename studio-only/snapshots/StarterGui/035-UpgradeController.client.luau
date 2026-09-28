local root=script.Parent local body=root.Surface
local Players=game:GetService("Players") local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local K=require(root.Parent.UIPolishKit)
local Catalog=require(RS.Shared.UpgradeCatalog)
local ProgressionConfig=require(RS.Shared.ProgressionConfig)
local Remotes=require(RS.Shared.Remotes)
local UISounds=require(RS.SharedUI.UISounds)
local Store=require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("ProfileStore"))
local money local pending={} local levels={}
local trainingPending=false
local trainingReadyAt=0
local rebirthPending=false
local confirmRebirthUntil=0
local knownRebirths=nil
local refresh

-- Reuse the existing upgrade-card artwork and scrolling list.
local function progressionRow(name,title,order,accent)
 local card=body.Cards:FindFirstChild(name)
 if not card then
  card=body.Cards.power:Clone()
  card.Name=name
  card.LayoutOrder=order
  card.Parent=body.Cards
 end
 card:SetAttribute("AccentColor",accent)
 card:SetAttribute("ProgressionRow",true)
 card:FindFirstChild("Name").Text=title
 card.Pips.Visible=false
 card.Level.Size=UDim2.fromOffset(280,18)
 card.Level.TextWrapped=false
 card.Level.TextScaled=true
 card.Buy.Position=UDim2.new(1,-234,0,13)
 card.Buy.Label.TextScaled=true
 card.Buy.Price.TextScaled=true
 card.Values.Arrow.Visible=false
 return card
end
local trainingCard=progressionRow("SpinTraining","Spin Training",100,Color3.fromRGB(53,219,193))
local rebirthCard=progressionRow("SpinRebirth","Rebirth",101,Color3.fromRGB(185,133,255))
trainingCard.Description.Text="Practice between throws. Rebirth lifts your strength ceiling."
trainingCard.Description.TextWrapped=true
trainingCard.Values.CurrentCaption.Text="SPIN STRENGTH"
trainingCard.Values.NextCaption.Text="GAIN"
rebirthCard.Size=UDim2.new(1,-6,0,140)
rebirthCard.Accent.Size=UDim2.new(0,5,1,-14)
rebirthCard.Values.CurrentCaption.Text="CURRENT CEILING"
rebirthCard.Values.NextCaption.Text="NEXT CEILING"
local resetHint=rebirthCard:FindFirstChild("ResetHint")
if not resetHint then
 resetHint=rebirthCard.Description:Clone()
 resetHint.Name="ResetHint"
 resetHint.Parent=rebirthCard
end
resetHint.Position=UDim2.fromOffset(106,94)
resetHint.Size=UDim2.new(1,-130,0,36)
resetHint.TextSize=12
resetHint.TextWrapped=true
resetHint.Text="Keeps rocks, Enchanted, traits, mastery, pets and shards.\nResets cash, upgrades, strength and this journey's milestones."

local feedback=body.Status
feedback.Visible=false
feedback.AnchorPoint=Vector2.new(.5,1)
feedback.Position=UDim2.new(.5,0,1,-8)
feedback.Size=UDim2.new(1,-70,0,26)
feedback.BackgroundColor3=Color3.fromRGB(15,50,75)
feedback.BackgroundTransparency=.04
feedback.TextColor3=Color3.fromRGB(247,252,255)
feedback.TextSize=15
feedback.ZIndex=100
local feedbackCorner=feedback:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
feedbackCorner.CornerRadius=UDim.new(0,8)
feedbackCorner.Parent=feedback
local feedbackToken=0
local function showFeedback(message,ok)
 feedbackToken+=1
 local token=feedbackToken
 feedback.Text=tostring(message)
 feedback.BackgroundColor3=ok and Color3.fromRGB(19,94,75) or Color3.fromRGB(122,49,66)
 feedback.Visible=true
 task.delay(2.8,function() if token==feedbackToken and feedback.Parent then feedback.Visible=false end end)
end
local function strengthText(value)
 return ProgressionConfig.formatStrength(tonumber(value) or 0)
end
local function multiplierText(value)
 return string.format("%.2fx",tonumber(value) or 1)
end
local function effect(u,l)
 if u.id=="power" then return multiplierText(1+l*u.perLevel).." strength" end
 return u.id=="magnet" and ("+"..l*u.perLevel.." studs") or ("+"..string.format("%g",l*u.perLevel*100).."%")
end
refresh=function()
 local cash=money and money.Value or 0
 body.Wallet.Text=money and ("CASH  $"..K.compact(cash)) or "LOADING CASH..."
 for _,u in Catalog.Upgrades do
  local c=body.Cards[u.id] local l=Store.upgradeLevel(u.id)
  local cap=Catalog.capAt(u,tonumber(Store.get().rebirths) or 0)
  local maxed=Catalog.isMaxed(u,l,tonumber(Store.get().rebirths) or 0) local cost=Catalog.costAt(u,l)
  c:FindFirstChild("Name").Text=u.name
  c.Description.Text=u.description
  local accent=c:GetAttribute("AccentColor") local before=levels[u.id] levels[u.id]=l
  if before and l>before then
   pending[u.id]=nil
   c.Outline.Color=Color3.fromRGB(172,255,185) K.tween(c.Outline,{Color=Color3.fromRGB(86,121,149)},.55)
   showFeedback(u.name.." upgraded to level "..l.."!",true)
   UISounds.play("Success")
  end
  c.Level.Text="LEVEL "..l.." / "..cap
  c.Values.Current.Text=effect(u,l)
  c.Values.Next.Text=maxed and "MAX" or effect(u,l+1)
  c.Values.NextCaption.Text=maxed and "CEILING" or "NEXT"
  local progress=math.clamp(l/cap,0,1)*10
  for i=1,10 do
   local pip=c.Pips["Pip"..i]
   local amount=math.clamp(progress-(i-1),0,1)
   pip.BackgroundColor3=Color3.fromRGB(22,40,60):Lerp(accent,amount)
   pip.Outline.Color=amount>0 and accent or Color3.fromRGB(96,119,142)
  end
  local can=Store.hasLoaded() and cash>=cost and not maxed and not pending[u.id]
  c.Buy.Active=can c.Buy.Selectable=can
  K.paint(c.Buy,maxed and Color3.fromRGB(205,152,35) or can and Color3.fromRGB(43,219,81) or Color3.fromRGB(71,91,111))
  c.Buy.Label.Text=not Store.hasLoaded() and "LOADING..." or pending[u.id] and "UPGRADING..." or maxed and (cap<u.maxLevel and "REBIRTH FOR MORE" or "MAX POTENTIAL") or can and "UPGRADE" or "NEED CASH"
  c.Buy.Price.Text=maxed and (cap<u.maxLevel and "JOURNEY CAP" or "FULLY MASTERED") or "$"..K.full(cost)
 end
 local state=Store.get()
 local loaded=Store.hasLoaded() and state.loaded~=false
 local inFlight=player:GetAttribute("RockInFlight")==true
 local cooldown=ProgressionConfig.TrainingCooldown
 local trainingGain=tonumber(state.trainingGain) or 0
 local canTrain=loaded and not inFlight and not trainingPending and os.clock()>=trainingReadyAt and trainingGain>0
 trainingCard.Values.Current.Text=strengthText(state.spinStrength)
 trainingCard.Values.Next.Text="+"..strengthText(trainingGain)
 trainingCard.Level.Text="CEILING "..strengthText(state.strengthCap).." • FREE TRAINING"
 trainingCard.Buy.Active=canTrain
 trainingCard.Buy.Selectable=canTrain
 trainingCard.Buy.Label.Text=not loaded and "LOADING..." or inFlight and "FINISH THROW" or trainingPending and "TRAINING..." or os.clock()<trainingReadyAt and "RECOVERING" or trainingGain<=0 and "REBIRTH FOR MORE" or "TRAIN"
 trainingCard.Buy.Price.Text="+"..strengthText(trainingGain).." SPIN"
 K.paint(trainingCard.Buy,canTrain and Color3.fromRGB(43,219,150) or Color3.fromRGB(71,91,111))
 local rebirths=tonumber(state.rebirths) or 0
 if knownRebirths~=nil and rebirths~=knownRebirths then
  rebirthPending=false
  confirmRebirthUntil=0
  showFeedback("Rebirth complete — a higher power ceiling is unlocked!",true)
 end
 knownRebirths=rebirths
 local requirement=state.rebirthRequirement or ProgressionConfig.rebirthRequirements(rebirths)
 local cost=tonumber(requirement.cost) or 0
 local ready=state.rebirthReady==true or (tostring(state.rebirthReason or ""):find("^Save %$")~=nil and cash>=cost)
 local canRebirth=loaded and ready and not inFlight and not rebirthPending and not state.hasPendingSummon
 if not canRebirth then confirmRebirthUntil=0 end
 rebirthCard.Values.Current.Text=strengthText(state.strengthCap or ProgressionConfig.strengthCap(rebirths))
 rebirthCard.Values.Next.Text=strengthText(state.nextStrengthCap or requirement.nextStrengthCap)
 rebirthCard.Level.Text=string.format("POWER %d/%d • STRENGTH %s/%s",Store.upgradeLevel("power"),requirement.powerLevel,strengthText(state.spinStrength),strengthText(requirement.strength))
 rebirthCard.Description.Text="Complete "..requirement.areaName.." this journey"
 rebirthCard.Description.TextWrapped=true
 rebirthCard.Buy.Active=canRebirth
 rebirthCard.Buy.Selectable=canRebirth
 local reason=tostring(state.rebirthReason or "Complete this journey")
 local short=reason:find("Complete") and "COMPLETE AREA" or reason:find("Spin Strength") and "BUILD STRENGTH" or reason:find("Throw Power") and "UPGRADE POWER" or reason:find("Maximum") and "MAX POTENTIAL" or "NEED CASH"
 rebirthCard.Buy.Label.Text=not loaded and "LOADING..." or rebirthPending and "REBIRTHING..." or inFlight and "FINISH THROW" or not ready and short or confirmRebirthUntil>os.clock() and "CONFIRM REBIRTH" or "REBIRTH"
 rebirthCard.Buy.Price.Text=rebirths>=ProgressionConfig.MaxRebirths and "FINAL POTENTIAL UNLOCKED" or "R"..rebirths.." → "..(rebirths+1).." • $"..strengthText(cost)
 rebirthCard.Buy.Label.Text="TALK TO NOOB"
 rebirthCard.Buy.Active=loaded;rebirthCard.Buy.Selectable=loaded
 K.paint(rebirthCard.Buy,canRebirth and (confirmRebirthUntil>os.clock() and Color3.fromRGB(255,174,63) or Color3.fromRGB(175,117,244)) or Color3.fromRGB(71,91,111))
end
trainingCard.Buy.Activated:Connect(function()
 if not trainingCard.Buy.Active then return end
 local request={}
 trainingPending=request
 local cooldown=ProgressionConfig.TrainingCooldown
 trainingReadyAt=os.clock()+cooldown
 refresh()
 Remotes.RequestPurchase:FireServer("training","spin")
 task.delay(cooldown,refresh)
 task.delay(6,function()
  if trainingPending==request then
   trainingPending=false
   showFeedback("No reply yet. Please try again.",false)
   refresh()
  end
 end)
end)
rebirthCard.Buy.Activated:Connect(function()
 showFeedback("Noob is fishing at the Rebirth shrine up the stairs. Talk to him to review and confirm Rebirth.",true)
end)
player:GetAttributeChangedSignal("RockInFlight"):Connect(refresh)
for _,u in Catalog.Upgrades do
 local c=body.Cards[u.id]
 c.Buy.Activated:Connect(function()
  local l=Store.upgradeLevel(u.id)
  if not Store.hasLoaded() or pending[u.id] or Catalog.isMaxed(u,l,tonumber(Store.get().rebirths) or 0) or not money or money.Value<Catalog.costAt(u,l) then return end
  local token={} pending[u.id]=token refresh()
  Remotes.RequestPurchase:FireServer("upgrade",u.id)
  task.delay(6,function() if pending[u.id]==token then pending[u.id]=nil showFeedback("No reply yet. Please try again.",false) refresh() end end)
 end)
 c.MouseEnter:Connect(function() K.tween(c.Outline,{Color=c:GetAttribute("AccentColor")},.12) end)
 c.MouseLeave:Connect(function() K.tween(c.Outline,{Color=Color3.fromRGB(86,121,149)},.15) end)
end
Remotes.ShopResult.OnClientEvent:Connect(function(id,ok,message)
 if id=="spin" and trainingPending then
  trainingPending=false
  showFeedback(message,ok)
  if ok then UISounds.play("Success") end
  refresh()
 end
 if pending[id] then pending[id]=nil showFeedback(message,ok) if ok then UISounds.play("Success") end refresh() end
end)
Store.onChanged(refresh)
Remotes.Toast.OnClientEvent:Connect(function(message,kind)
 if rebirthPending and kind=="bad" then rebirthPending=false;showFeedback(message,false);refresh() end
end)
task.spawn(function() money=player:WaitForChild("leaderstats"):WaitForChild("Money") money.Changed:Connect(refresh) refresh() end)
local modal=K.modal(root,960,720,function() Remotes.RequestShopState:FireServer() refresh() end)
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt,who)
 if who~=player then return end
 local shrine=workspace:FindFirstChild("RebirthShrine")
 if shrine and prompt:IsDescendantOf(shrine) then
  modal.open()
  task.defer(function()
   body.Cards.CanvasPosition=Vector2.new(0,math.max(0,rebirthCard.AbsolutePosition.Y-body.Cards.AbsolutePosition.Y+body.Cards.CanvasPosition.Y-8))
  end)
 end
end)
refresh()



