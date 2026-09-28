-- Legendary protection presented as part of the forge, with a single-use choice.
local Confirmation={}
local TweenService=game:GetService("TweenService")
local Players=game:GetService("Players")
local ink=Color3.fromRGB(12,25,23)
local gold=Color3.fromRGB(235,191,103)
local mint=Color3.fromRGB(143,244,191)
local cream=Color3.fromRGB(255,248,226)
local function corner(object,radius)
 local c=Instance.new("UICorner",object);c.CornerRadius=UDim.new(0,radius)
end
local function stroke(object,color,width)
 local s=Instance.new("UIStroke",object);s.Color=color;s.Thickness=width;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 return s
end
function Confirmation.new(panel)
 local page=Instance.new("TextButton")
 page.Name="LegendaryConfirmation";page.Text="";page.AutoButtonColor=false
 page.AnchorPoint=Vector2.new(.5,.5)
 local resting=UDim2.fromOffset(300,242.5)
 page.Position=resting;page.Size=UDim2.fromOffset(564,329)
 page.BackgroundColor3=Color3.new(1,1,1);page.BorderSizePixel=0
 page.ZIndex=30;page.Visible=false;page.Parent=panel
 corner(page,18);stroke(page,gold,1.5)
 local fill=Instance.new("UIGradient",page)
 fill.Color=ColorSequence.new(Color3.fromRGB(28,65,47),Color3.fromRGB(13,32,26));fill.Rotation=90
 local scale=Instance.new("UIScale",page)
 local function text(parent,name,value,pos,size,fontSize,color,font)
  local l=Instance.new("TextLabel");l.Name=name;l.Text=value
  l.Font=font or Enum.Font.FredokaOne;l.TextSize=fontSize;l.TextColor3=color or cream
  l.TextWrapped=true;l.BackgroundTransparency=1;l.Position=pos;l.Size=size
  l.TextStrokeColor3=ink;l.TextStrokeTransparency=.4;l.ZIndex=parent.ZIndex+1;l.Parent=parent
  return l
 end
 text(page,"Heading","Reroll this legendary?",UDim2.fromOffset(22,18),UDim2.fromOffset(520,32),26,cream)
 text(page,"Subtitle","You've forged something special.",UDim2.fromOffset(22,53),UDim2.fromOffset(520,20),14,mint,Enum.Font.GothamMedium)
 local card=Instance.new("Frame");card.Name="ProtectedTraitCard"
 card.Position=UDim2.fromOffset(22,84);card.Size=UDim2.fromOffset(520,82)
 card.BackgroundColor3=Color3.fromRGB(18,43,33);card.BorderSizePixel=0;card.ZIndex=31;card.Parent=page
 corner(card,13);stroke(card,Color3.fromRGB(113,145,85),1)
 text(card,"Rarity","◆  LEGENDARY",UDim2.fromOffset(14,8),UDim2.fromOffset(492,15),11,gold,Enum.Font.GothamBold)
 local trait=text(card,"ProtectedTrait","The One",UDim2.fromOffset(14,25),UDim2.fromOffset(492,30),27,cream)
 local rock=text(card,"RockName","",UDim2.fromOffset(14,58),UDim2.fromOffset(492,17),12,Color3.fromRGB(186,219,193),Enum.Font.GothamMedium)
 rock.TextWrapped=false;rock.TextTruncate=Enum.TextTruncate.AtEnd
 text(page,"Warning","A new roll will replace this trait.",UDim2.fromOffset(22,175),UDim2.fromOffset(520,20),15,cream,Enum.Font.GothamMedium)
 local function button(name,value,x,color,borderColor,textColor)
  local b=Instance.new("TextButton");b.Name=name;b.Text=value;b.Font=Enum.Font.FredokaOne;b.TextSize=21
  b.TextColor3=textColor;b.TextStrokeColor3=ink;b.TextStrokeTransparency=.4
  b.Position=UDim2.fromOffset(x,204);b.Size=UDim2.fromOffset(250,48)
  b.BackgroundColor3=color;b.BorderSizePixel=0;b.AutoButtonColor=false;b.ZIndex=32;b.Parent=page
  corner(b,12);stroke(b,borderColor,1.5)
  local hover
  local function tint(target)
   if hover then hover:Cancel() end
   hover=TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=target});hover:Play()
  end
  b.MouseEnter:Connect(function() tint(color:Lerp(mint,.12)) end)
  b.MouseLeave:Connect(function() tint(color) end)
  return b
 end
 local keep=button("KeepLegendary","Keep trait",22,Color3.fromRGB(35,158,101),Color3.fromRGB(104,225,158),cream)
 local confirm=button("ConfirmReroll","Reroll trait",292,Color3.fromRGB(36,61,43),gold,gold)
 text(page,"Tip","Your legendary is safe until you choose to reroll.",UDim2.fromOffset(22,269),UDim2.fromOffset(520,20),13,Color3.fromRGB(193,221,199),Enum.Font.GothamMedium)
 text(page,"Shortcut","Esc to keep",UDim2.fromOffset(22,295),UDim2.fromOffset(520,16),11,Color3.fromRGB(156,186,164),Enum.Font.GothamMedium)
 local version=0
 local accept,cancel,armedAt
 local busy=false
 local freshPress=false
 local motion={}
 local controller={}
 local function reduced()
  local player=Players.LocalPlayer
  return player and player:GetAttribute("ReducedMotion")==true
 end
 local function stopMotion()
  for _,t in motion do t:Cancel() end;table.clear(motion)
 end
 local function animate(object,duration,props)
  local tween=TweenService:Create(object,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
  table.insert(motion,tween);tween:Play()
 end
 function controller:invalidate()
  version+=1;accept=nil;cancel=nil;armedAt=nil;busy=true;freshPress=false
  stopMotion()
 end
 function controller:hide()
  version+=1;accept=nil;cancel=nil;armedAt=nil;busy=false;freshPress=false
  stopMotion();page.Visible=false;page.Position=resting;scale.Scale=1
 end
 local function choose(callback)
  if busy or not page.Visible or not callback then return false end
  busy=true;accept=nil;cancel=nil;armedAt=nil;freshPress=false
  version+=1;local current=version
  stopMotion()
  local duration=reduced() and .08 or .14
  if not reduced() then
   animate(page,duration,{Position=resting+UDim2.fromOffset(0,7)})
   animate(scale,duration,{Scale=.985})
  end
  task.delay(duration,function()
   if current~=version or not page.Parent then return end
   controller:hide()
   callback()
  end)
  return true
 end
 function controller:show(traitName,rockName,onAccept,onCancel)
  controller:hide()
  trait.Text=traitName;rock.Text=rockName
  accept=onAccept;cancel=onCancel;armedAt=os.clock()+.32
  page.Visible=true
  page.Position=resting+UDim2.fromOffset(0,reduced() and 0 or 9)
  scale.Scale=reduced() and 1 or .975
  animate(page,.22,{Position=resting});animate(scale,.22,{Scale=1})
 end
 function controller:confirm()
  if not armedAt or os.clock()<armedAt then return false end
  return choose(accept)
 end
 function controller:cancel()
  return choose(cancel)
 end
 -- Releasing the click that opened the dialogue cannot confirm it.
 confirm.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch
   or input.KeyCode==Enum.KeyCode.ButtonA or input.KeyCode==Enum.KeyCode.Return then
   freshPress=not busy and armedAt~=nil and os.clock()>=armedAt
  end
 end)
 confirm.Activated:Connect(function()
  if freshPress then controller:confirm() end
  freshPress=false
 end)
 keep.Activated:Connect(function() controller:cancel() end)
 page.Destroying:Connect(function() version+=1;stopMotion();accept=nil;cancel=nil end)
 return controller
end
return Confirmation
