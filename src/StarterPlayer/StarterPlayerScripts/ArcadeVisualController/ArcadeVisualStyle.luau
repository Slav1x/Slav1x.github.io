-- Visual-only skin. No remotes, input handlers, visibility or gameplay state.
local Style = {}
local ink = Color3.fromRGB(8, 11, 17)
local white = Color3.fromRGB(255, 253, 246)
local blue = Color3.fromRGB(12, 170, 241)
local orange = Color3.fromRGB(255, 145, 24)
local eligibleScreens = {
 DailyRewardsUI=true, PlaytimeGiftsUI=true, QuestsUI=true, CoreTutorialUI=true,
 ThrowHud=true, TouchControls=true, Notify=true, SpinTrainingGui=true,
 ProgressionFeedback=true, NoobConversation=true, HotbarGui=true, SivaCashFlight=true,
 PebbleAdventureHUD=true, InspectNameplate=true, StoneCamReplay=true,
}
local protected = {
 inventoryui=true, Inventory=true, shopui=true, upgradesui=true,
 IndexPanel=true, IndexBackdrop=true, SummonGroveQuickButton=true,
 SummonPromptUI=true, SummonAutoUI=true, TraitForgeUI=true,
}
local hudRoots = {
 LeftNav=true, StatsBar=true, Money=true, FriendBoostHUD=true, CashMultiplierHUD=true, SpinMultiplierHUD=true, SpinMultiplierBreakdown=true,
 MultiplierBreakdown=true, LevelHolder=true, settingsui=true, settingsopenframe=true,
 dailyrewardsopenFrame=true, playtimerewardsopenFrame=true, questsopenFrame=true,
}
function Style.eligible(x)
 local cursor=x
 while cursor do
  -- Skipstone surfaces (tutorial, throw HUD) own their styling.
  if protected[cursor.Name] or cursor:GetAttribute("Skipstone") then return false end
  if cursor:IsA("ScreenGui") then
   if cursor.Name=="MainHUD" then
    local branch=x
    while branch.Parent and branch.Parent~=cursor do branch=branch.Parent end
    return hudRoots[branch.Name]==true
   end
   return eligibleScreens[cursor.Name]==true
  end
  cursor=cursor.Parent
 end
 return false
end
local function corner(x,r)
 local c=x:FindFirstChildOfClass("UICorner")
 if not c then c=Instance.new("UICorner");c.Name="ArcadeCorner";c.Parent=x end
 -- Preserve circular controls, icons, and progress capsules.
 if c.CornerRadius.Scale<.4 then c.CornerRadius=UDim.new(0,r) end
end
local function stroke(x,thickness)
 local st
 for _,v in x:GetChildren() do
  if v:IsA("UIStroke") and v.ApplyStrokeMode==Enum.ApplyStrokeMode.Border then st=v;break end
  if v:IsA("UIStroke") and not x:IsA("TextLabel") and not x:IsA("TextButton") then st=v;break end
 end
 if not st then st=Instance.new("UIStroke");st.Name="ArcadeBorder";st.Parent=x end
 st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Color=ink
 st.Thickness=thickness or 2.5;st.Transparency=0;st.Enabled=true
 st.LineJoinMode=Enum.LineJoinMode.Round
end
local function gradient(x,top,bottom)
 local g=x:FindFirstChildOfClass("UIGradient")
 if not g then g=Instance.new("UIGradient");g.Name="ArcadeGradient";g.Parent=x end
 g.Enabled=true;g.Rotation=90;g.Color=ColorSequence.new(top,bottom)
 x.BackgroundColor3=Color3.new(1,1,1)
end
local function plate(x,top,bottom,r)
 x.BorderSizePixel=0;x.BackgroundTransparency=0
 corner(x,r or 16);stroke(x,3);gradient(x,top,bottom)
end
local function textStyle(x)
 -- Fonts only; preserve semantic colors, rich text, values, wrapping and sizes.
 x.Font=Enum.Font.FredokaOne
 x.TextStrokeColor3=ink
 local contextual
 for _,v in x:GetChildren() do
  if v:IsA("UIStroke") and v.ApplyStrokeMode==Enum.ApplyStrokeMode.Contextual then
   contextual=v;v.Color=ink;v.Thickness=x.TextSize>=24 and 2.4 or 1.4;v.Transparency=0;v.Enabled=true
  end
 end
 if contextual then x.TextStrokeTransparency=1
 else x.TextStrokeTransparency=x.TextSize<15 and .3 or 0 end
end
local surfaceNames={Background=true,QuestPanel=true,Shell=true,Dialogue=true,
 MultiplierBreakdown=true,JetpackFuel=true,ResultPanel=true,ChargePanel=true,Panel=true,Card=true}
local decoration={"shadow","glare","gloss","bevel","sunray","glow","diamond","spark","needle","divider","hand"}
local function decorative(x)
 local n=x.Name:lower()
 for _,word in decoration do if n:find(word,1,true) then return true end end
 local p=x.Parent
 while p and not p:IsA("ScreenGui") do
  if p.Name=="QuietPattern" or p.Name=="ClockArt" or p.Name=="FlameArt" or p.Name=="ClockIcon" or p.Name=="Calendar" then return true end
  p=p.Parent
 end
 return false
end
local function applyStyle(x)
 if not Style.eligible(x) or not x:IsA("GuiObject") or x:GetAttribute("ArcadeDecoration") then return end
 local n=x.Name
 if x:IsA("TextLabel") or x:IsA("TextButton") or x:IsA("TextBox") then textStyle(x) end
 if n=="Backdrop" then x.BackgroundTransparency=.88;return end
 if x:IsA("ImageLabel") and (n:find("Stud") or n=="SivaBodyTexture" or n=="HeaderTexture") then
  local screen=x:FindFirstAncestorWhichIsA("ScreenGui")
  if screen and screen.Name=="CoreTutorialUI" and n=="StudTexture" then
   x.ImageTransparency=.78
  elseif screen and (screen.Name=="DailyRewardsUI" or screen.Name=="PlaytimeGiftsUI" or screen.Name=="QuestsUI") then
   x.ImageTransparency=(x.Parent.Name=="Header") and .60 or (n=="SivaBodyTexture") and .74 or .65
  else
   x.ImageTransparency=(x.Parent.Name=="Header" or x.Parent.Name=="AccentHeader") and .83 or .96
  end
  return
 end
 if decorative(x) then return end
 if x:IsA("ScrollingFrame") then
  x.BorderSizePixel=0;corner(x,12)
  x.ScrollBarImageColor3=blue
  if x.ScrollBarThickness>0 then x.ScrollBarThickness=5 end
  if x.BackgroundTransparency<.8 then
   x.BackgroundColor3=Color3.fromRGB(20,28,40);x.BackgroundTransparency=.3
  end
  return
 end
 if n=="Header" or n=="AccentHeader" or n=="BlueStudHeader" or n=="StuddedPanel" then
  plate(x,Color3.fromRGB(31,193,250),Color3.fromRGB(4,103,189),14)
 elseif n:match("^Quest%d+$") or n:match("^Reward%d+$") then
  plate(x,Color3.fromRGB(54,63,80),Color3.fromRGB(28,34,46),13)
 elseif n=="SpinMultiplierBreakdown" then
  plate(x,Color3.fromRGB(8,36,76),Color3.fromRGB(4,20,47),18)
 elseif n=="ObjectiveCard" then
  plate(x,Color3.fromRGB(31,145,238),Color3.fromRGB(8,62,157),14)
  local border=x:FindFirstChildOfClass("UIStroke")
  if border then border.Color=Color3.fromRGB(0,222,255);border.Thickness=2.5 end
 elseif surfaceNames[n] or (x.Parent and x.Parent:IsA("ScreenGui") and x:IsA("Frame") and x.BackgroundTransparency<.6) then
  plate(x,Color3.fromRGB(47,59,76),Color3.fromRGB(22,30,43),18)
 elseif x.Parent and x.Parent.Name=="Cards" and x:IsA("Frame") then
  plate(x,Color3.fromRGB(51,64,82),Color3.fromRGB(31,40,55),14)
 elseif n=="ExitReplay" then
  plate(x,Color3.fromRGB(255,184,61),Color3.fromRGB(241,111,15),14)
  x.TextColor3=white
 elseif n=="Close" or n=="CloseButton" then
  plate(x,Color3.fromRGB(255,94,89),Color3.fromRGB(210,30,48),12)
 elseif x:IsA("GuiButton") and x.BackgroundTransparency<.6 then
  -- Keep state-driven button colors and gradients owned by their controllers.
  corner(x,12);stroke(x,2.5);x.BorderSizePixel=0
 elseif n=="Track" or n=="ProgressTrack" or n=="MasteryTrack" then
  corner(x,8);stroke(x,2);x.BorderSizePixel=0
 elseif n=="Fill" or n=="Progress" then
  corner(x,8)
 elseif x.BackgroundTransparency<.6 and x:FindFirstChildOfClass("UICorner") then
  corner(x,12)
  local st=x:FindFirstChildOfClass("UIStroke")
  if st then st.Color=ink;st.Transparency=0;st.Thickness=2 end
 end
 if n=="DailyProgress" then
  plate(x,Color3.fromRGB(255,173,45),Color3.fromRGB(239,111,14),12)
 end
 if (n=="QuestPanel" or n=="Background" or n=="Shell") and not x:FindFirstChild("ArcadeShadow")
  and not x:FindFirstChild("PremiumShadow") and not x:FindFirstChildOfClass("UIListLayout") then
  local shadow=Instance.new("Frame")
  shadow.Name="ArcadeShadow";shadow:SetAttribute("ArcadeDecoration",true)
  shadow.Size=UDim2.new(1,0,1,0);shadow.Position=UDim2.fromOffset(0,5)
  shadow.BackgroundColor3=ink;shadow.BackgroundTransparency=.55;shadow.BorderSizePixel=0
  shadow.ZIndex=math.max(1,x.ZIndex-1);shadow.Active=false
  corner(shadow,18);shadow.Parent=x
 end
end

-- Background-only translucency: captions, artwork and interaction remain intact.
function Style.translucency(x)
 if not x:IsA("GuiObject") or not Style.eligible(x) then return end
 local n=x.Name
 if n=="ObjectiveCard" then x.BackgroundTransparency=.08;return end
 if n=="SpinMultiplierBreakdown" then x.BackgroundTransparency=.08;return end
 local lower=n:lower()
 local screen=x:FindFirstAncestorWhichIsA("ScreenGui")
 if screen and (screen.Name=="DailyRewardsUI" or screen.Name=="PlaytimeGiftsUI" or screen.Name=="QuestsUI") then
  if n=="Background" or n=="QuestPanel" then x.BackgroundTransparency=.10;return end
  if n=="Header" then x.BackgroundTransparency=.12;return end
  if n:match("^Reward%d+$") or n:match("^Quest%d+$") then x.BackgroundTransparency=.12;return end
  if n=="Face" and x.Parent and x.Parent.Name:match("^Reward%d+$") then x.BackgroundTransparency=.12;return end
 end
 if lower:find("shadow",1,true) then
  if x.BackgroundTransparency<1 then x.BackgroundTransparency=math.max(.95,x.BackgroundTransparency) end
  if x:IsA("ImageLabel") then x.ImageTransparency=math.max(.95,x.ImageTransparency) end
  return
 end
 if x:GetAttribute("ArcadeDecoration") or decorative(x) then return end
 if n=="Backdrop" then x.BackgroundTransparency=.96;return end
 if x:IsA("ScrollingFrame") then x.BackgroundTransparency=1;return end
 -- Do not fade meter fills, slider handles or icon artwork.
 if n=="Fill" or n=="Progress" or lower:find("knob",1,true) or lower:find("thumb",1,true)
  or lower:find("handle",1,true) or x:IsA("ViewportFrame") then return end
 if x:IsA("ImageLabel") or x:IsA("ImageButton") then
  if x.BackgroundTransparency<1 then x.BackgroundTransparency=math.max(.3,x.BackgroundTransparency) end
  return
 end
 if x.BackgroundTransparency>=1 then return end
 local opacity=.45
 if surfaceNames[n] or n=="AdventureCard" or n=="ResultHolder"
  or (x.Parent and x.Parent:IsA("ScreenGui") and x:IsA("Frame")) then
  opacity=.55
 elseif n=="Header" or n=="AccentHeader" or n=="BlueStudHeader" or n=="StuddedPanel" then
  opacity=.3
 elseif n:match("^Quest%d+$") or n:match("^Reward%d+$") or (x.Parent and x.Parent.Name=="Cards") then
  opacity=.5
 elseif x:IsA("GuiButton") or n=="Face" or n=="State" then
  opacity=.25
 end
 x.BackgroundTransparency=math.max(opacity,x.BackgroundTransparency)
end
function Style.apply(x)
 applyStyle(x)
 Style.translucency(x)
end

function Style.tree(root)
 Style.apply(root)
 for _,x in root:GetDescendants() do Style.apply(x) end
end
function Style.watch(root)
 Style.tree(root)
 -- Deferred once per new instance, so builders can finish assigning properties.
 return root.DescendantAdded:Connect(function(x)
  if x:IsA("GuiObject") then task.defer(function()
   if x.Parent then Style.apply(x) end
  end) end
 end)
end
return Style

