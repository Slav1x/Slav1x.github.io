--!nonstrict
-- Blue inventory-style flight card and short-lived encounter feedback.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local C=require(RS.Shared.PebbleEncounters)
local ThrowConfig=require(RS.Shared.ThrowConfig)
local Water=require(RS.Shared.WaterSurface)
local PickupMotion=require(RS.Shared.WaterPickupMotion)
local PickupPresentation=require(script:WaitForChild("WaterPickupPresentation"))
local Remotes=require(RS.Shared.Remotes)
local Theme=require(RS:WaitForChild("SharedUI"):WaitForChild("SkipstoneTheme"))
local player=Players.LocalPlayer
local F={}
local active=nil
local steerInput=nil
local previewSteer=0
local seen={}
local bound=false
local lastSend=0
local messageUntil=0
local routeAt=0
local exhaust=nil
local exhaustAttachment=nil
local effects=nil

local landingMarker=nil
local FLIGHT_ARC_SEGMENTS=14
local landingArcPoints={}
local landingArcBeams={}
local ink=Theme.Ink
local mint=Color3.fromRGB(26,188,99)
local lime=Color3.fromRGB(109,241,132)
local blue=Color3.fromRGB(15,113,231)
local deepBlue=Color3.fromRGB(5,62,177)
local pale=Color3.fromRGB(239,247,255)
local orange=Color3.fromRGB(248,193,96)
local coral=Color3.fromRGB(239,46,59)
local white=Color3.fromRGB(255,255,255)
local function corner(parent,radius)
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,radius);c.Parent=parent
end
local function outline(parent,width)
 local s=Instance.new("UIStroke");s.Name="BlackOutline";s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Color=ink;s.Thickness=width;s.Parent=parent
end
local function gradient(parent,a,b)
 local g=parent:FindFirstChild("BrightGradient")
 if not g then g=Instance.new("UIGradient");g.Name="BrightGradient";g.Rotation=90;g.Parent=parent end
 g.Color=ColorSequence.new(a,b)
end
local function text(parent,name,position,size,fontSize)
 local l=Instance.new("TextLabel");l.Name=name;l.BackgroundTransparency=1;l.Position=position;l.Size=size
 l.Font=Enum.Font.GothamBlack;l.TextSize=fontSize;l.TextScaled=false;l.TextColor3=white
 l.TextStrokeColor3=ink;l.TextStrokeTransparency=0;l.TextXAlignment=Enum.TextXAlignment.Center
 l.Text="";l.Parent=parent;return l
end

-- Skipstone flight card: white sticker, colored header band, overhanging medallion.
local gui=Instance.new("ScreenGui");gui.Name="PebbleAdventureHUD";gui.ResetOnSpawn=false;gui.DisplayOrder=55;gui.IgnoreGuiInset=false;gui.Enabled=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui:SetAttribute("Skipstone",true);gui.Parent=player:WaitForChild("PlayerGui")
-- Kept for the layout code below; the sticker's own lip is the shadow now.
local shadow=Instance.new("Frame");shadow.Name="SoftShadow";shadow.Visible=false;shadow.BackgroundTransparency=1;shadow.AnchorPoint=Vector2.new(.5,1);shadow.Size=UDim2.fromOffset(444,154);shadow.Parent=gui
local card=Instance.new("Frame");card.Name="AdventureCard";card.AnchorPoint=Vector2.new(.5,1);card.Position=UDim2.new(.5,0,1,-18);card.Size=UDim2.fromOffset(444,154);card.BackgroundTransparency=1;card.Parent=gui
local scale=Instance.new("UIScale");scale.Parent=card
local shadowScale=Instance.new("UIScale");shadowScale.Parent=shadow
local sticker,body=Theme.sticker(card,22,6,"Sticker");sticker.Size=UDim2.fromScale(1,1)
local header=Instance.new("Frame");header.Name="Header";header.Position=UDim2.fromOffset(4,4);header.Size=UDim2.new(1,-8,0,46);header.BackgroundColor3=white;header.BorderSizePixel=0;header.ZIndex=3;header.Parent=body;corner(header,18);gradient(header,blue,deepBlue)
local headerFoot=Instance.new("Frame");headerFoot.Name="SquareBottom";headerFoot.Position=UDim2.new(0,0,1,-16);headerFoot.Size=UDim2.new(1,0,0,16);headerFoot.BackgroundColor3=deepBlue;headerFoot.BorderSizePixel=0;headerFoot.ZIndex=3;headerFoot.Parent=header
local headerGloss=Instance.new("Frame");headerGloss.Name="HeaderGloss";headerGloss.Position=UDim2.new(0,70,0,6);headerGloss.Size=UDim2.new(1,-230,0,9);headerGloss.BackgroundColor3=white;headerGloss.BackgroundTransparency=.72;headerGloss.BorderSizePixel=0;headerGloss.ZIndex=4;headerGloss.Parent=header;corner(headerGloss,5)
local rule=Instance.new("Frame");rule.Name="HeaderRule";rule.Position=UDim2.fromOffset(0,50);rule.Size=UDim2.new(1,0,0,3);rule.BackgroundColor3=ink;rule.BorderSizePixel=0;rule.ZIndex=4;rule.Parent=body
local medallion=Theme.medallion(card,62,8);medallion.root.Position=UDim2.fromOffset(8,27);medallion.setIcon("throw")
local heading=text(header,"Heading",UDim2.fromOffset(44,6),UDim2.new(1,-190,0,34),21);heading.Text="PEBBLE SKIPPING";heading.FontFace=Theme.Display;heading.TextXAlignment=Enum.TextXAlignment.Left;heading.TextScaled=true;heading.TextStrokeTransparency=1;heading.ZIndex=5;Theme.textStroke(ink,2.4).Parent=heading
local headingLimit=Instance.new("UITextSizeConstraint");headingLimit.MinTextSize=14;headingLimit.MaxTextSize=21;headingLimit.Parent=heading
local badge=Instance.new("Frame");badge.Name="ModeBadge";badge.AnchorPoint=Vector2.new(1,.5);badge.Position=UDim2.new(1,-10,.5,0);badge.Size=UDim2.fromOffset(132,28);badge.BackgroundColor3=ink;badge.BorderSizePixel=0;badge.ZIndex=5;badge.Parent=header;corner(badge,14)
local badgeText=text(badge,"Mode",UDim2.fromScale(0,0),UDim2.fromScale(1,1),14);badgeText.Text="ON THE WATER";badgeText.FontFace=Theme.Display;badgeText.TextStrokeTransparency=1;badgeText.ZIndex=6
local accent=Instance.new("Frame");accent.Name="EventAccent";accent.Visible=false;accent.Size=UDim2.fromOffset(0,0);accent.Parent=card
local title=text(body,"Event",UDim2.fromOffset(26,60),UDim2.new(1,-196,0,36),24);title.FontFace=Theme.Display;title.TextColor3=ink;title.TextStrokeTransparency=1;title.TextXAlignment=Enum.TextXAlignment.Left;title.TextScaled=true;title.ZIndex=5
local limit=Instance.new("UITextSizeConstraint");limit.MinTextSize=13;limit.MaxTextSize=24;limit.Parent=title
local nitroLip=Instance.new("Frame");nitroLip.Name="NitroLip";nitroLip.Position=UDim2.new(1,-160,0,64);nitroLip.Size=UDim2.fromOffset(144,48);nitroLip.BackgroundColor3=ink;nitroLip.BorderSizePixel=0;nitroLip.ZIndex=5;nitroLip.Parent=body;corner(nitroLip,13)
local nitroFace=Instance.new("Frame");nitroFace.Name="NitroFace";nitroFace.Position=UDim2.new(1,-160,0,60);nitroFace.Size=UDim2.fromOffset(144,48);nitroFace.BackgroundColor3=white;nitroFace.BorderSizePixel=0;nitroFace.ZIndex=6;nitroFace.Parent=body;corner(nitroFace,13);outline(nitroFace,3);gradient(nitroFace,Theme.Swatches.sun.top,Theme.Swatches.sun.bottom)
local nitroGloss=Instance.new("Frame");nitroGloss.Name="NitroGloss";nitroGloss.Position=UDim2.new(0,8,0,4);nitroGloss.Size=UDim2.new(1,-16,0,12);nitroGloss.BackgroundColor3=white;nitroGloss.BackgroundTransparency=.6;nitroGloss.BorderSizePixel=0;nitroGloss.ZIndex=7;nitroGloss.Parent=nitroFace;corner(nitroGloss,6)
local nitro=Instance.new("TextButton");nitro.Name="NitroButton";nitro.Position=nitroFace.Position;nitro.Size=nitroFace.Size;nitro.BackgroundTransparency=1;nitro.FontFace=Theme.Display;nitro.TextScaled=true;nitro.TextColor3=white;nitro.TextStrokeTransparency=1;nitro.Text="NITRO  [Q]";nitro.AutoButtonColor=false;nitro.ZIndex=8;nitro.Parent=body;Theme.textStroke(ink,2).Parent=nitro
local nitroLimit=Instance.new("UITextSizeConstraint");nitroLimit.MinTextSize=11;nitroLimit.MaxTextSize=19;nitroLimit.Parent=nitro
local nitroPad=Instance.new("UIPadding");nitroPad.PaddingLeft=UDim.new(0,8);nitroPad.PaddingRight=UDim.new(0,8);nitroPad.PaddingTop=UDim.new(0,6);nitroPad.PaddingBottom=UDim.new(0,6);nitroPad.Parent=nitro
local chainMeter=Instance.new("Frame");chainMeter.Name="ChainMeter";chainMeter.Position=UDim2.fromOffset(26,100);chainMeter.Size=UDim2.new(1,-204,0,12);chainMeter.BackgroundColor3=Theme.Mist;chainMeter.BorderSizePixel=0;chainMeter.ZIndex=5;chainMeter.Parent=body;corner(chainMeter,6);outline(chainMeter,2.5)
local chainFill=Instance.new("Frame");chainFill.Name="Remaining";chainFill.Size=UDim2.fromScale(0,1);chainFill.BackgroundColor3=Color3.fromRGB(39,186,255);chainFill.BorderSizePixel=0;chainFill.ZIndex=6;chainFill.Parent=chainMeter;corner(chainFill,6)
local hint=Instance.new("TextLabel");hint.Name="Route";hint.BackgroundTransparency=1;hint.Position=UDim2.fromOffset(26,118);hint.Size=UDim2.new(1,-52,0,22);hint.FontFace=Theme.Body;hint.TextScaled=true;hint.TextXAlignment=Enum.TextXAlignment.Left;hint.TextColor3=Theme.InkSoft;hint.TextStrokeTransparency=1;hint.Text="";hint.ZIndex=5;hint.Parent=body
local hintLimit=Instance.new("UITextSizeConstraint");hintLimit.MinTextSize=10;hintLimit.MaxTextSize=15;hintLimit.Parent=hint
local track=Instance.new("Frame");track.Name="KickTiming";track.Position=UDim2.fromOffset(26,146);track.Size=UDim2.new(1,-52,0,14);track.BorderSizePixel=0;track.BackgroundColor3=Theme.Mist;track.Visible=false;track.ZIndex=5;track.Parent=body;corner(track,7);outline(track,2.5)
local sweet=Instance.new("Frame");sweet.Name="PerfectWindow";sweet.Position=UDim2.fromScale(C.PerfectStart/C.CatchDuration,0);sweet.Size=UDim2.fromScale((C.PerfectEnd-C.PerfectStart)/C.CatchDuration,1);sweet.BackgroundColor3=white;sweet.BorderSizePixel=0;sweet.ZIndex=6;sweet.Parent=track;corner(sweet,7);outline(sweet,2);gradient(sweet,Theme.Swatches.lime.top,Theme.Swatches.lime.bottom)
local needle=Instance.new("Frame");needle.Name="TimingNeedle";needle.Size=UDim2.fromOffset(8,24);needle.AnchorPoint=Vector2.new(.5,.5);needle.BackgroundColor3=white;needle.BorderSizePixel=0;needle.ZIndex=7;needle.Parent=track;corner(needle,4);outline(needle,2.5)
local buttonLip=Instance.new("Frame");buttonLip.Name="ActionLip";buttonLip.Position=UDim2.fromOffset(22,176);buttonLip.Size=UDim2.new(1,-44,0,40);buttonLip.BackgroundColor3=ink;buttonLip.BorderSizePixel=0;buttonLip.ZIndex=5;buttonLip.Parent=body;corner(buttonLip,13)
local buttonFace=Instance.new("Frame");buttonFace.Name="ActionPlate";buttonFace.Position=UDim2.fromOffset(22,172);buttonFace.Size=UDim2.new(1,-44,0,40);buttonFace.BorderSizePixel=0;buttonFace.BackgroundColor3=white;buttonFace.ZIndex=6;buttonFace.Parent=body;corner(buttonFace,13);outline(buttonFace,3);gradient(buttonFace,blue,deepBlue)
local button=Instance.new("TextButton");button.Name="CatchKickButton";button.Position=buttonFace.Position;button.Size=buttonFace.Size;button.BackgroundTransparency=1;button.ZIndex=8;button.FontFace=Theme.Display;button.TextScaled=true;button.TextColor3=white;button.TextStrokeTransparency=1;button.Selectable=true;button.Text="KICK";button.Parent=body;Theme.textStroke(ink,2).Parent=button
local buttonLimit=Instance.new("UITextSizeConstraint");buttonLimit.MinTextSize=12;buttonLimit.MaxTextSize=19;buttonLimit.Parent=button
local buttonPad=Instance.new("UIPadding");buttonPad.PaddingTop=UDim.new(0,7);buttonPad.PaddingBottom=UDim.new(0,7);buttonPad.Parent=button
local function paint(a,b,buttonA,buttonB)
 gradient(header,a,b);headerFoot.BackgroundColor3=b;gradient(buttonFace,buttonA,buttonB);accent.BackgroundColor3=a;chainFill.BackgroundColor3=a
 medallion.discGradient.Color=ColorSequence.new(a:Lerp(white,.25),b)
end
buttonLip.Visible=false;buttonFace:GetPropertyChangedSignal("Visible"):Connect(function() buttonLip.Visible=buttonFace.Visible end)
local function action(mode)
 if not active or not active.Parent or UIS:GetFocusedTextBox() then return end
 if mode==nil and typeof(active:GetAttribute("CatchStart"))~="number" then return end
 if os.clock()-lastSend<.2 then return end
 lastSend=os.clock()
 Remotes.FlightAction:FireServer(active:GetAttribute("ThrowId"),mode)
end
button.Activated:Connect(function() action(nil) end)
nitro.Activated:Connect(function() action("nitro") end)
function F.attach(pebble, currentSteer)
 if exhaustAttachment then exhaustAttachment:Destroy() end
 local main=pebble.PrimaryPart or pebble:FindFirstChildWhichIsA("BasePart",true)
 if main then
  exhaustAttachment=Instance.new("Attachment");exhaustAttachment.Name="AdventureExhaust";exhaustAttachment.Parent=main
  exhaust=Instance.new("ParticleEmitter");exhaust.Name="BoostSpark";exhaust.Texture="rbxasset://textures/particles/sparkles_main.dds"
  exhaust.Rate=28;exhaust.Lifetime=NumberRange.new(.1,.22);exhaust.Speed=NumberRange.new(1,3);exhaust.SpreadAngle=Vector2.new(14,14)
  exhaust.LightEmission=.7;exhaust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(1,0)})
  exhaust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(1,1)})
  exhaust.Enabled=false;exhaust.Parent=exhaustAttachment
 end
 active=pebble;PickupPresentation.setFocus(pebble);steerInput=currentSteer;previewSteer=0;seen={};gui.Enabled=true;messageUntil=0
 card.Size=UDim2.fromOffset(444,154);shadow.Size=card.Size;buttonFace.Visible=false;button.Visible=false
 if landingMarker then landingMarker:Destroy() end
 landingArcPoints={};landingArcBeams={}
 landingMarker=Instance.new("Part");landingMarker.Name="LocalLandingArc";landingMarker.Anchored=true;landingMarker.Transparency=1;landingMarker.Size=Vector3.one;landingMarker.CanCollide=false;landingMarker.CanTouch=false;landingMarker.CanQuery=false;landingMarker.Parent=workspace
 for i=0,FLIGHT_ARC_SEGMENTS do
  local point=Instance.new("Attachment");point.Name="FlightArcPoint"..i;point.Parent=landingMarker
  landingArcPoints[i+1]=point
 end
 for i=1,FLIGHT_ARC_SEGMENTS do
  local fade=(i-1)/FLIGHT_ARC_SEGMENTS
  local nextFade=i/FLIGHT_ARC_SEGMENTS
  local outline=Instance.new("Beam");outline.Name="FlightArcDarkEdge";outline.Attachment0=landingArcPoints[i];outline.Attachment1=landingArcPoints[i+1]
  outline.Width0=.74-.14*fade;outline.Width1=.74-.14*nextFade;outline.Transparency=NumberSequence.new(.11+.08*fade)
  outline.Color=ColorSequence.new(Color3.fromRGB(11,31,58));outline.FaceCamera=true;outline.ZOffset=.02;outline.LightEmission=0;outline.Parent=landingMarker
  local halo=Instance.new("Beam");halo.Name="FlightArcSoftGlow";halo.Attachment0=landingArcPoints[i];halo.Attachment1=landingArcPoints[i+1]
  halo.Width0=1.35-.3*fade;halo.Width1=1.35-.3*nextFade;halo.Transparency=NumberSequence.new(.8+.06*fade)
  halo.Color=ColorSequence.new(Color3.fromRGB(255,230,91));halo.FaceCamera=true;halo.ZOffset=0;halo.LightEmission=1;halo.Parent=landingMarker
  local core=Instance.new("Beam");core.Name="FlightArcBrightCore";core.Attachment0=landingArcPoints[i];core.Attachment1=landingArcPoints[i+1]
  core.Width0=.36-.07*fade;core.Width1=.36-.07*nextFade;core.Transparency=NumberSequence.new(.07+.11*fade)
  core.Color=ColorSequence.new(Color3.fromRGB(255,190,0));core.FaceCamera=true;core.ZOffset=.04;core.LightEmission=.25;core.LightInfluence=0;core.Parent=landingMarker
  landingArcBeams[i]={outline=outline,halo=halo,core=core}
 end
 title.Text="Choose your next landing";hint.Text="Aim for surfaced pickups  •  Save your nitro"
 badgeText.Text="ON THE WATER"
 paint(blue,deepBlue,blue,deepBlue)
 if not bound then
  bound=true
  CAS:BindActionAtPriority("PebbleAdventureAction",function(_,state,input)
   -- Flight controls only take E, Space, or A while a catch can be kicked.
   if typeof(active and active:GetAttribute("CatchStart"))~="number" then return Enum.ContextActionResult.Pass end
   if state==Enum.UserInputState.Begin then action() end
   return Enum.ContextActionResult.Sink
  end,false,Enum.ContextActionPriority.High.Value+100,Enum.KeyCode.E,Enum.KeyCode.Space,Enum.KeyCode.ButtonA)
  CAS:BindActionAtPriority("PebbleNitroAction",function(_,state)
   if state==Enum.UserInputState.Begin then action("nitro") end
   return Enum.ContextActionResult.Sink
  end,false,Enum.ContextActionPriority.High.Value+100,Enum.KeyCode.Q,Enum.KeyCode.ButtonX)
 end
end
function F.finish()
 if exhaustAttachment then exhaustAttachment:Destroy();exhaustAttachment=nil;exhaust=nil end
 if effects then effects:Destroy();effects=nil end
 if landingMarker then landingMarker:Destroy();landingMarker=nil end
 landingArcPoints={};landingArcBeams={}
 active=nil;PickupPresentation.setFocus(nil);steerInput=nil;previewSteer=0;gui.Enabled=false;track.Visible=false
 if bound then CAS:UnbindAction("PebbleAdventureAction");CAS:UnbindAction("PebbleNitroAction");bound=false end
end
local function fxFolder()
 if effects and effects.Parent then return effects end
 effects=Instance.new("Folder");effects.Name="LocalAdventureEffects";effects.Parent=workspace
 return effects
end
local function portal(position,velocity)
 if player:GetAttribute("ReducedThrowFlashes")==true or player:GetAttribute("ReducedMotion")==true then return end
 local camera=workspace.CurrentCamera
 if not camera or (camera.CFrame.Position-position).Magnitude>340 then return end
 local horizontal=Vector3.new(velocity and velocity.X or 1,0,velocity and velocity.Z or 0)
 local forward=if horizontal.Magnitude>1 then horizontal.Unit else Vector3.xAxis
 local right=forward:Cross(Vector3.yAxis)
 local folder=fxFolder()
 for layer=1,2 do
  local radius=if layer==1 then 4.4 else 6.2
  local color=if layer==1 then Color3.fromRGB(195,248,255) else Color3.fromRGB(71,207,239)
  for i=1,18 do
   local a=(i-1)/18*math.pi*2;local b=i/18*math.pi*2
   local va=right*math.cos(a)+Vector3.yAxis*math.sin(a)
   local vb=right*math.cos(b)+Vector3.yAxis*math.sin(b)
   local from=position+va*radius;local to=position+vb*radius
   local outA=position+va*(radius+2.8);local outB=position+vb*(radius+2.8)
   local segment=Instance.new("Part")
   segment.Name="WormholeArc";segment.Anchored=true;segment.CanCollide=false;segment.CanTouch=false;segment.CanQuery=false
   segment.CastShadow=false;segment.Material=Enum.Material.Neon;segment.Color=color;segment.Transparency=if layer==1 then .08 else .28
   segment.Size=Vector3.new(.22,.22,(to-from).Magnitude)
   segment.CFrame=CFrame.lookAt((from+to)*.5,to);segment.Parent=folder
   Tween:Create(segment,TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
    Position=(outA+outB)*.5,Size=Vector3.new(.08,.08,(outB-outA).Magnitude),Transparency=1
   }):Play()
   Debris:AddItem(segment,.6)
  end
 end
end
local function burst(data)
 if player:GetAttribute("ReducedThrowFlashes")==true or player:GetAttribute("ReducedMotion")==true then return end
 local camera=workspace.CurrentCamera
 if not camera or (camera.CFrame.Position-data.position).Magnitude>300 then return end
 local def=C.Types[data.kind]
 local color=if data.kind=="Miss" then coral elseif def then def.color else lime
 local folder=fxFolder()
 -- Thin, expanding neon rim, matching the card outlines without covering the pebble.
 local count=10;local radius=if data.kind=="Bomb" then 12 elseif data.kind=="Nitro" then 5 else 8
 for i=1,count do
  local a=(i-1)/count*math.pi*2;local b=i/count*math.pi*2
  local unitA=Vector3.new(math.cos(a),0,math.sin(a));local unitB=Vector3.new(math.cos(b),0,math.sin(b))
  local inner=2;local outA=data.position+unitA*radius;local outB=data.position+unitB*radius
  local initialA=data.position+unitA*inner;local initialB=data.position+unitB*inner
  local seg=Instance.new("Part");seg.Name="EncounterRim";seg.Anchored=true;seg.CanCollide=false;seg.CanTouch=false;seg.CanQuery=false
  seg.CastShadow=false;seg.Material=Enum.Material.Neon;seg.Color=color;seg.Size=Vector3.new(.28,.28,(initialB-initialA).Magnitude)
  seg.CFrame=CFrame.lookAt((initialA+initialB)*.5,initialB);seg.Parent=folder
  Tween:Create(seg,TweenInfo.new(.40,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=(outA+outB)*.5,Size=Vector3.new(.12,.12,(outB-outA).Magnitude),Transparency=1}):Play()
  Debris:AddItem(seg,.44)
 end
 local anchor=Instance.new("Part");anchor.Name="EncounterCallout";anchor.Anchored=true;anchor.Transparency=1;anchor.Size=Vector3.one;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Position=data.position+Vector3.new(0,7,0);anchor.Parent=folder
 local pop=Instance.new("BillboardGui");pop.Size=UDim2.fromOffset(210,45);pop.StudsOffsetWorldSpace=Vector3.new(0,1,0);pop.MaxDistance=200;pop.Adornee=anchor;pop.Parent=anchor
 local plate=Instance.new("Frame");plate.Size=UDim2.fromScale(1,1);plate.BackgroundColor3=color;plate.Parent=pop;corner(plate,16);outline(plate,3)
 plate.BackgroundColor3=white;gradient(plate,color:Lerp(white,.3),color)
 local words=text(plate,"Callout",UDim2.fromScale(0,0),UDim2.fromScale(1,1),18);words.TextScaled=true;words.Text=(data.label or "BOOST!");words.FontFace=Theme.Display;words.TextStrokeTransparency=1;Theme.textStroke(ink,2.2).Parent=words
 local wordPad=Instance.new("UIPadding");wordPad.PaddingLeft=UDim.new(0,10);wordPad.PaddingRight=UDim.new(0,10);wordPad.PaddingTop=UDim.new(0,6);wordPad.PaddingBottom=UDim.new(0,6);wordPad.Parent=words
 local wordLimit=Instance.new("UITextSizeConstraint");wordLimit.MinTextSize=12;wordLimit.MaxTextSize=18;wordLimit.Parent=words
 Tween:Create(anchor,TweenInfo.new(.7),{Position=anchor.Position+Vector3.new(0,5,0)}):Play()
 Debris:AddItem(anchor,.75)
end
Remotes.Encounter.OnClientEvent:Connect(function(data)
 if typeof(data)~="table" or typeof(data.position)~="Vector3" then return end

 if data.kind=="Whirlpool" and data.phase=="enter" then
  portal(data.position,data.velocity)
  if typeof(data.exitPosition)=="Vector3" then
   task.delay(.12,function() portal(data.exitPosition,data.velocity) end)
  end
 end
 burst(data)
 if data.kind~="Catch" then
  local camera=workspace.CurrentCamera
  if camera and (camera.CFrame.Position-data.position).Magnitude<240 then
   local palette={
    Jet={"rbxassetid://9113586144",1.45,.26},
    Nitro={"rbxassetid://9113586144",1.85,.2},
    Bomb={"rbxassetid://9125577419",.78,.30},
    Monkey={"rbxassetid://94689014718800",.7,.24},
    Gorilla={"rbxassetid://9125577419",.55,.31},
    Miss={"rbxassetid://119214808310856",.6,.18},
    Log={"rbxassetid://9125577419",1.18,.28},
    Rocks={"rbxassetid://9125577419",.90,.32},
    Whirlpool={"rbxassetid://9113586144",1.35,.30},
    Obstacle={"rbxassetid://9125577419",1.04,.27},
   }
   local voice=palette[data.kind]
   if voice then
    local anchor=Instance.new("Part");anchor.Name="EncounterSound";anchor.Anchored=true;anchor.Transparency=1;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Size=Vector3.one;anchor.Position=data.position;anchor.Parent=fxFolder()
    local sound=Instance.new("Sound");sound.SoundId=voice[1];sound.PlaybackSpeed=voice[2];sound.Volume=voice[3];sound.RollOffMaxDistance=220;sound.Parent=anchor;sound:Play();Debris:AddItem(anchor,3)
   end
  end
 end
 if not active or data.userId~=player.UserId or data.throwId~=active:GetAttribute("ThrowId") then return end
 if data.stationId then seen[data.stationId]=true end
 title.Text=data.label or "BOOST!";messageUntil=os.clock()+1.55
 if data.cash then
  paint(Color3.fromRGB(49,213,105),Color3.fromRGB(20,151,76),Color3.fromRGB(43,190,94),Color3.fromRGB(16,112,61))
 elseif data.kind=="Miss" then
  paint(Color3.fromRGB(255,100,91),coral,Color3.fromRGB(255,135,65),Color3.fromRGB(200,72,34))
 elseif data.kind=="Catch" then paint(blue,deepBlue,Color3.fromRGB(44,184,90),Color3.fromRGB(22,117,63))
 elseif data.kind=="Nitro" then paint(Color3.fromRGB(255,174,56),orange,orange,Color3.fromRGB(192,94,5))
 else paint(blue,deepBlue,blue,deepBlue) end
end)
Run.RenderStepped:Connect(function(dt)
 if not active then return end
 if not active.Parent or not active.PrimaryPart then F.finish();return end
 local camera=workspace.CurrentCamera
 local v=camera and camera.ViewportSize or Vector2.new(1000,800)
 local responsive=math.min(1,(v.X-180)/444,(v.Y-120)/220)
 responsive=math.max(.55,responsive)
 card.Position=UDim2.new(.5,0,1,-18)
 shadow.Position=UDim2.new(.5,0,1,-12)
 scale.Scale=responsive;shadowScale.Scale=responsive
 local now=workspace:GetServerTimeNow()
 if exhaust then
  local untilAt=active:GetAttribute("BoostUntil") or 0
  exhaust.Enabled=now<untilAt and player:GetAttribute("ReducedThrowFlashes")~=true and player:GetAttribute("ReducedMotion")~=true
  local def=C.Types[active:GetAttribute("BoostKind") or "Jet"]
  exhaust.Color=ColorSequence.new(if def then def.color else mint)
 end
 previewSteer=ThrowConfig.smoothSteering(previewSteer,if steerInput then steerInput() else 0,dt)
 local main=active.PrimaryPart
 local pos=main.Position;local velocity=main.AssemblyLinearVelocity
 local waterY=Water.at(pos)
 local g=math.max(workspace.Gravity,1)
 local height=if waterY then math.max(0,pos.Y-waterY) else 0
 local timeToWater=if waterY then (velocity.Y+math.sqrt(velocity.Y*velocity.Y+2*g*height))/g else 5
 if landingMarker then
  local landing=pos+Vector3.new(velocity.X,0,velocity.Z)*math.clamp(timeToWater,0,2.6)
  -- Forecast a short section of the same heading turn used by the server.
  -- The local input ramps in, so tapping the button nudges the guide instead of snapping it sideways.
  local horizon=math.clamp(timeToWater,0,.55)
  local bank=active:GetAttribute("SteerBank")
  if typeof(bank)~="number" then bank=previewSteer end
  local _,_,steeredDisplacement=ThrowConfig.steerVelocity(velocity,bank,previewSteer,horizon)
  landing+=steeredDisplacement-Vector3.new(velocity.X,0,velocity.Z)*horizon
  local landingWater=Water.at(landing)
  local arcVisible=landingWater~=nil and timeToWater>.04 and timeToWater<2.6
  landingMarker.Position=pos
  if arcVisible then
   local horizontal=Vector3.new(velocity.X,0,velocity.Z)
   local sideways=landing-(pos+horizontal*timeToWater)
   for i=0,FLIGHT_ARC_SEGMENTS do
    local fraction=i/FLIGHT_ARC_SEGMENTS
    local t=timeToWater*fraction
    local point=pos+velocity*t-Vector3.yAxis*(.5*g*t*t)+sideways*(fraction*fraction)
    if i==FLIGHT_ARC_SEGMENTS then point=Vector3.new(landing.X,landingWater+.22,landing.Z) end
    landingArcPoints[i+1].Position=point-pos
   end
  end
  for _,segment in landingArcBeams do
   segment.outline.Enabled=arcVisible
   segment.halo.Enabled=arcVisible
   segment.core.Enabled=arcVisible
  end
 end
 local charges=active:GetAttribute("NitroCharges") or 0
 local key=if UIS.TouchEnabled and not UIS.KeyboardEnabled then "TAP" elseif UIS:GetLastInputType()==Enum.UserInputType.Gamepad1 then "X" else "Q"
 local ready=active:GetAttribute("NitroReadyAt") or 0
 nitro.Text=if charges<=0 then "NITRO EMPTY" elseif ready>now then "NITRO "..string.format("%.1f",ready-now).."s" else "NITRO "..charges.."/"..(active:GetAttribute("NitroMaxCharges") or C.MaxNitro).."  ["..key.."]"
 if charges>0 and ready<=now then gradient(nitroFace,Theme.Swatches.sun.top,Theme.Swatches.sun.bottom) else gradient(nitroFace,Theme.Swatches.stone.top,Theme.Swatches.stone.deep) end
 local caught=active:GetAttribute("CatchStart")
 local catching=typeof(caught)=="number"
 track.Visible=catching;buttonFace.Visible=catching;button.Visible=catching;chainMeter.Visible=not catching
 card.Size=UDim2.fromOffset(444,if catching then 226 else 154);shadow.Size=card.Size
 local chain=active:GetAttribute("EncounterChain") or 0
 local expires=active:GetAttribute("ChainExpires") or 0
 chainFill.Size=UDim2.fromScale(if chain>0 then math.clamp((expires-now)/C.ChainWindow,0,1) else 0,1)
 if catching then
  local kind=active:GetAttribute("CatchKind") or "Monkey"
  local verb=if kind=="Gorilla" then "THROW" else "KICK"
  badgeText.Text=verb.." TIMING"
  if os.clock()>messageUntil then title.Text="TIME YOUR "..verb end
  local timing=C.CatchTiming[kind] or C.CatchTiming.Monkey
  sweet.Position=UDim2.fromScale(timing.perfectStart/C.CatchDuration,0)
  sweet.Size=UDim2.fromScale((timing.perfectEnd-timing.perfectStart)/C.CatchDuration,1)
  local elapsed=active:GetAttribute("CatchInputTime") or (now-caught);local perfect=elapsed>=timing.perfectStart and elapsed<=timing.perfectEnd
  needle.Position=UDim2.fromScale(math.clamp(elapsed/C.CatchDuration,0,1),.5)
  button.Text=if active:GetAttribute("CatchReleasing") then verb.."!" elseif perfect then verb.." NOW!  [E / SPACE / A]" else "WAIT FOR GREEN - THEN "..verb
  hint.Text=if kind=="Monkey" then "STEER LEFT / RIGHT TO CURVE" else "LATE GREEN = BIG SKY LAUNCH"
  nitro.Text=verb.." FIRST"
  if perfect then paint(Color3.fromRGB(46,214,113),mint,Color3.fromRGB(44,184,90),Color3.fromRGB(22,117,63)) end
 else
  badgeText.Text="ON THE WATER"
  if os.clock()>routeAt then
   routeAt=os.clock()+.12
   local folder=workspace:FindFirstChild("PebbleAdventure")
   local pos=active.PrimaryPart.Position;local velocity=active.PrimaryPart.AssemblyLinearVelocity
   local dir=Vector3.new(velocity.X,0,velocity.Z)
   local best=nil;local bestDistance=700
   if folder and dir.Magnitude>1 then
    for _,m in folder:GetChildren() do
     if not m:IsA("Model") or not m.PrimaryPart or seen[m:GetAttribute("EncounterId")] then continue end
     local cycle=PickupMotion.decode(m:GetAttribute("PickupTimeline"))
     if cycle and not PickupMotion.availableForModel(m,now) then continue end
     local d=m.PrimaryPart.Position-pos;local flat=Vector3.new(d.X,0,d.Z)
     local forward=flat:Dot(dir.Unit)
     if forward<=10 or forward>=bestDistance then continue end
     local t=forward/math.max(dir.Magnitude,1)
     local atHeight=pos.Y+velocity.Y*t-.5*g*t*t
     local def=C.Types[m:GetAttribute("EncounterKind")]
     if not def or atHeight-m.PrimaryPart.Position.Y>def.height+20 then continue end
     local lateral=math.abs(flat:Dot(dir.Unit:Cross(Vector3.yAxis)))
     if lateral>16+ThrowConfig.BankMaxLateralSpeed*t then continue end
     best=m;bestDistance=forward
    end
   end
   if best then
    local def=C.Types[best:GetAttribute("EncounterKind")]
    local right=dir.Unit:Cross(Vector3.yAxis)
    local side=(best.PrimaryPart.Position-pos):Dot(right)
    local partner=nil
    if folder then
     for _,m in folder:GetChildren() do
      if m==best or not m:IsA("Model") or not m.PrimaryPart or seen[m:GetAttribute("EncounterId")] then continue end
      local cycle=PickupMotion.decode(m:GetAttribute("PickupTimeline"))
      if cycle and not PickupMotion.availableForModel(m,now) then continue end
      local offset=m.PrimaryPart.Position-pos
      local forward=Vector3.new(offset.X,0,offset.Z):Dot(dir.Unit)
      if math.abs(forward-bestDistance)>35 then continue end
      local otherSide=offset:Dot(right)
      if side*otherSide>=0 or math.abs(otherSide)>16+ThrowConfig.BankMaxLateralSpeed*forward/math.max(dir.Magnitude,1) then continue end
      partner=m;break
     end
    end
    if partner then
     local other=C.Types[partner:GetAttribute("EncounterKind")]
     local left=if side<0 then def else other
     local rightChoice=if side>0 then def else other
     hint.Text="< "..left.label.."  |  "..rightChoice.label.." >"
    else
     hint.Text=(if side>10 then "RIGHT >  " elseif side < -10 then "< LEFT  " else "AHEAD  ")..(if def.cash then "COLLECT " else "AIM FOR ")..def.label.."  /  "..math.floor(bestDistance).." STUDS"
    end
   else hint.Text="Aim for surfaced pickups  •  Save your nitro" end
  end
  if os.clock()>messageUntil then
   local chain=active:GetAttribute("EncounterChain") or 0
   local expires=active:GetAttribute("ChainExpires") or 0
   title.Text=if chain>0 and expires>now then "CHAIN x"..chain.."  /  "..string.format("%.1fs",expires-now) else "Choose your next landing"
   paint(blue,deepBlue,blue,deepBlue)
  end
 end
end)
player.CharacterRemoving:Connect(F.finish)
return F


