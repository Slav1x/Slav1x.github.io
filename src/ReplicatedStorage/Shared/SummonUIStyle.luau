local UI={}
local TS=game:GetService("TweenService")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local player=game.Players.LocalPlayer
local shellVisual=require(game.ReplicatedStorage.Shared.GeodeReveal).ShellVisual
local rarityColors=require(game.ReplicatedStorage.Shared.RockCatalog).RarityColors
local cyan=Color3.fromRGB(101,239,255)
local navy=Color3.fromRGB(13,19,35)
local function tw(o,t,p,style) TS:Create(o,TweenInfo.new(t,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),p):Play() end
local function corner(o,r)
 local c=o:FindFirstChildWhichIsA("UICorner") or Instance.new("UICorner",o);c.CornerRadius=UDim.new(0,r)
end
local function label(parent,name,text,pos,size,fontSize,color)
 local l=Instance.new("TextLabel");l.Name=name;l.BackgroundTransparency=1;l.Position=pos;l.Size=size;l.Text=text;l.TextSize=fontSize;l.Font=Enum.Font.FredokaOne;l.TextColor3=color;l.ZIndex=4;l.Parent=parent;return l
end
local function press(b)
 local sc=b:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale",b)
 b.AutoButtonColor=false
 b.MouseEnter:Connect(function() tw(sc,.15,{Scale=1.035}) end)
 b.MouseLeave:Connect(function() tw(sc,.15,{Scale=1}) end)
 b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then tw(sc,.08,{Scale=.96}) end end)
 b.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then tw(sc,.25,{Scale=1},Enum.EasingStyle.Back) end end)
end

function UI.mount(gui)
 local root=gui.PromptRoot;local b=root.ActionButton
 root.Size=UDim2.new(.84,0,0,82)
 local max=root:FindFirstChildWhichIsA("UISizeConstraint") or Instance.new("UISizeConstraint",root);max.MinSize=Vector2.zero;max.MaxSize=Vector2.new(330,82)
 for _,name in {"InnerBorder","TopHighlight","BottomShade","GlossLine","Divider"} do local o=b:FindFirstChild(name);if o then o.Visible=false end end
 root.Shadow.BackgroundColor3=Color3.new(0,0,0);root.Shadow.BackgroundTransparency=.94;corner(root.Shadow,20)
 corner(b,18);b.OuterStroke.Thickness=1.5;b.OuterStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 b.ActionText.Font=Enum.Font.FredokaOne;b.ActionText.TextSize=22;b.ActionText.TextStrokeTransparency=1
 b.CostText.Font=Enum.Font.FredokaOne;b.CostText.TextSize=14;b.CostText.TextStrokeTransparency=1
 b.KeyCap.KeyText.Font=Enum.Font.FredokaOne;b.KeyCap.KeyText.TextStrokeTransparency=1
 local ks=b.KeyCap:FindFirstChildWhichIsA("UIStroke");if ks then ks.Thickness=1;ks.Color=cyan end
 local panel=gui.SummonResult;panel.AnchorPoint=Vector2.new(.5,0)
 panel.BackgroundColor3=Color3.new(1,1,1);corner(panel,24);panel.Outline.Thickness=1.5
 if panel:FindFirstChild("TopHighlight") then panel.TopHighlight.Visible=false end
 local grad=panel:FindFirstChildWhichIsA("UIGradient") or Instance.new("UIGradient",panel);grad.Rotation=65;grad.Color=ColorSequence.new(Color3.fromRGB(31,39,65),Color3.fromRGB(10,15,28));grad.Parent=panel
 local sc=Instance.new("UIScale");sc.Name="RevealScale";sc.Parent=panel
 local limit=panel:FindFirstChildWhichIsA("UISizeConstraint") or Instance.new("UISizeConstraint",panel);limit.MinSize=Vector2.zero;limit.MaxSize=Vector2.new(350,224)
 for _,v in {panel.Heading,panel.RockName,panel.Details} do v.TextStrokeTransparency=1;v.TextScaled=false;v.ZIndex=5 end
 panel.Heading.Font=Enum.Font.FredokaOne;panel.Heading.TextSize=12
 panel.RockName.Font=Enum.Font.FredokaOne;panel.RockName.TextSize=25
 panel.Details.Font=Enum.Font.FredokaOne;panel.Details.TextSize=13
 panel.RockImage.ZIndex=5
 local halo=Instance.new("Frame");halo.Name="Halo";halo.AnchorPoint=Vector2.new(.5,.5);halo.Position=UDim2.new(.5,0,0,131);halo.Size=UDim2.fromOffset(154,154);halo.BackgroundTransparency=.94;halo.BackgroundColor3=cyan;halo.BorderSizePixel=0;halo.ZIndex=2;halo.Parent=panel;corner(halo,100)
 local st=Instance.new("UIStroke");st.Name="Ring";st.Color=cyan;st.Thickness=1.5;st.Transparency=.5;st.Parent=halo
 local orbit=Instance.new("Frame");orbit.Name="Orbit";orbit.BackgroundTransparency=1;orbit.AnchorPoint=Vector2.new(.5,.5);orbit.Position=UDim2.fromScale(.5,.5);orbit.Size=UDim2.fromScale(1.15,1.15);orbit.Parent=halo
 for i=1,8 do
  local a=i*math.pi/4
  local star=label(orbit,"Spark","+",UDim2.fromScale(.5+math.cos(a)*.5,.5+math.sin(a)*.5),UDim2.fromOffset(14,14),i%2==0 and 15 or 9,cyan);star.AnchorPoint=Vector2.new(.5,.5)
 end
 local badge=label(panel,"Discovery","NEW DISCOVERY",UDim2.fromOffset(20,16),UDim2.new(1,-40,0,18),10,cyan)
 local footer=label(panel,"Footer","ADDED TO YOUR COLLECTION",UDim2.new(0,20,1,-27),UDim2.new(1,-40,0,16),9,Color3.fromRGB(137,154,179))
 for _,btn in {panel.Equip,panel.Dismiss} do
  btn.Font=Enum.Font.FredokaOne;btn.TextSize=13;btn.TextStrokeTransparency=1;btn.ZIndex=6;corner(btn,12);press(btn)
 end
 panel.Equip.BackgroundColor3=cyan;panel.Equip.TextColor3=navy
 panel.Dismiss.BackgroundColor3=Color3.fromRGB(34,43,62);panel.Dismiss.TextColor3=Color3.fromRGB(219,230,245)
 local track=Instance.new("Frame");track.Name="StoreTrack";track.Position=UDim2.new(0,16,1,-12);track.Size=UDim2.new(1,-32,0,3);track.BackgroundTransparency=.75;track.BackgroundColor3=cyan;track.BorderSizePixel=0;track.Parent=panel
 local fill=Instance.new("Frame");fill.Name="Fill";fill.Size=UDim2.fromScale(1,1);fill.BackgroundColor3=cyan;fill.BorderSizePixel=0;fill.Parent=track
 local toast=label(gui,"StoreToast","",UDim2.fromScale(.5,.055),UDim2.new(.88,0,0,42),14,cyan);toast.AnchorPoint=Vector2.new(.5,0);toast.Visible=false
 local toastMax=Instance.new("UISizeConstraint");toastMax.MaxSize=Vector2.new(390,42);toastMax.Parent=toast
 toast.BackgroundColor3=navy;toast.BackgroundTransparency=.4;corner(toast,14)
 local connection
 connection=Run.RenderStepped:Connect(function()
  if not gui.Parent then connection:Disconnect();return end
  if panel.Visible and halo.Visible then
   local t=os.clock();local reduced=player:GetAttribute("ReducedMotion")==true
   orbit.Rotation=reduced and 0 or t*16
   panel.RockImage.Rotation=reduced and 0 or math.sin(t*1.7)*3
   st.Transparency=.45+math.sin(t*2)*.12
  end
 end)
end
local violet=Color3.fromRGB(190,150,255)
local function sigil(parent,name,color,pos)
 local holder=Instance.new("Frame");holder.Name=name;holder.BackgroundTransparency=1
 holder.Position=pos;holder.Size=UDim2.fromOffset(32,32);holder.ZIndex=4;holder.Parent=parent
 local gem=Instance.new("Frame");gem.Name="Crystal";gem.AnchorPoint=Vector2.new(.5,.5)
 gem.Position=UDim2.fromScale(.5,.5);gem.Size=UDim2.fromOffset(20,26);gem.Rotation=35
 gem.BackgroundColor3=color;gem.BackgroundTransparency=.1;gem.BorderSizePixel=0;gem.ZIndex=4;gem.Parent=holder;corner(gem,4)
 local g=Instance.new("UIGradient");g.Rotation=100;g.Color=ColorSequence.new(Color3.new(1,1,1),color:Lerp(navy,.35));g.Parent=gem
 local rim=Instance.new("UIStroke");rim.Color=color;rim.Thickness=1;rim.Transparency=.2;rim.Parent=gem
 local seam=Instance.new("Frame");seam.Name="Facet";seam.Size=UDim2.new(0,1,1,-6);seam.Position=UDim2.new(.5,0,0,3)
 seam.BackgroundColor3=Color3.new(1,1,1);seam.BackgroundTransparency=.15;seam.BorderSizePixel=0;seam.ZIndex=5;seam.Parent=gem
 return holder
end
function UI.action(root,triple)
 local b=root.ActionButton
 root:SetAttribute("Triple",triple)
 root.Shadow.Visible=false
 root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize=Vector2.new(390,96)
 b.Size=UDim2.fromScale(1,1);b.Position=UDim2.fromOffset(0,0);b.BorderSizePixel=0
 corner(b,16)
 b.KeyCap.Size=UDim2.fromOffset(42,42);b.KeyCap.Position=UDim2.fromOffset(14,29);corner(b.KeyCap,12)
 b.KeyCap.KeyText.TextSize=18
 b.ActionText.Position=UDim2.fromOffset(70,30);b.ActionText.Size=UDim2.new(1,-84,0,28)
 b.ActionText.TextXAlignment=Enum.TextXAlignment.Left;b.ActionText.TextColor3=Color3.fromRGB(244,248,255)
 b.CostText.Position=UDim2.fromOffset(70,61);b.CostText.Size=UDim2.new(1,-84,0,20)
 b.CostText.TextXAlignment=Enum.TextXAlignment.Left;b.CostText.Font=Enum.Font.FredokaOne
 local color=triple and violet or cyan
 local tag=label(b,"ActionEyebrow",triple and "TRIPLE SUMMON" or "SINGLE GEODE",UDim2.fromOffset(70,10),UDim2.new(1,-110,0,15),10,color)
 tag.TextXAlignment=Enum.TextXAlignment.Left
 tag.TextScaled=true
 local textLimit=Instance.new("UITextSizeConstraint");textLimit.MinTextSize=7;textLimit.MaxTextSize=10;textLimit.Parent=tag
 sigil(b,"CrystalSigil",color,UDim2.new(1,-35,0,2)).Size=UDim2.fromOffset(24,24)
 local line=Instance.new("Frame");line.Name="EnergyEdge";line.Position=UDim2.new(0,16,1,-5);line.Size=UDim2.new(1,-32,0,2)
 line.BackgroundColor3=color;line.BorderSizePixel=0;line.BackgroundTransparency=.15;line.Parent=b
 local fade=Instance.new("UIGradient");fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)});fade.Parent=line
 press(b)
 UI.prompt(root,false)
end
function UI.prompt(root,reward)
 local b=root.ActionButton
 local color=reward and Color3.fromRGB(255,213,112) or (root:GetAttribute("Triple") and violet or cyan)
 b.BackgroundColor3=Color3.new(1,1,1);b.BackgroundTransparency=.08
 b.MainGradient.Rotation=25
 b.MainGradient.Color=ColorSequence.new(Color3.fromRGB(31,40,68),Color3.fromRGB(10,15,29))
 b.OuterStroke.Color=color;b.OuterStroke.Transparency=.25;b.OuterStroke.Thickness=1.5
 b.KeyCap.BackgroundColor3=Color3.new(1,1,1)
 b.KeyCap.KeyGradient.Color=ColorSequence.new(color:Lerp(navy,.6),color:Lerp(navy,.85))
 b.KeyCap.KeyText.TextColor3=color
 b.CostText.TextColor3=Color3.fromRGB(207,220,237)
 b.ActionText.Text=reward and "CONTINUE" or "SUMMON 1"
end
function UI.result(panel,rock,data)
 local color=require(game.ReplicatedStorage.Shared.RockCatalog).RarityColors[rock.rarity] or cyan
 panel.Size=UDim2.new(.9,0,0,174);panel.Position=UDim2.fromScale(.5,.055);panel.BackgroundTransparency=.55
 panel.Outline.Color=color;panel.Outline.Transparency=.4
 panel.Discovery.Visible=true;panel.Discovery.Text=data.isNew and "NEW DISCOVERY" or "COLLECTION EXPANDED";panel.Discovery.TextColor3=color
 panel.Heading.Text=string.upper(rock.rarity);panel.Heading.Position=UDim2.fromOffset(124,46);panel.Heading.Size=UDim2.new(1,-140,0,18);panel.Heading.TextSize=12;panel.Heading.TextXAlignment=Enum.TextXAlignment.Left
 panel.Halo.Visible=true;panel.Halo.Position=UDim2.fromOffset(64,88);panel.Halo.Size=UDim2.fromOffset(82,82);panel.Halo.BackgroundTransparency=.98;panel.Halo.BackgroundColor3=color;panel.Halo.Ring.Color=color
 for _,v in panel.Halo.Orbit:GetChildren() do v.TextColor3=color end
 panel.RockImage.Position=UDim2.fromOffset(26,50);panel.RockImage.Size=UDim2.fromOffset(76,76)
 panel.RockName.TextSize=18;panel.RockName.TextWrapped=true;panel.RockName.TextXAlignment=Enum.TextXAlignment.Left;panel.RockName.Position=UDim2.fromOffset(124,67);panel.RockName.Size=UDim2.new(1,-140,0,43)
 panel.Details.Position=UDim2.fromOffset(124,112);panel.Details.Size=UDim2.new(1,-140,0,20);panel.Details.TextSize=11;panel.Details.TextXAlignment=Enum.TextXAlignment.Left;panel.Details.TextColor3=Color3.fromRGB(221,235,250)
 panel.Equip.BackgroundTransparency=.12;panel.Equip.Position=UDim2.new(0,16,1,-66);panel.Equip.Size=UDim2.new(.57,-22,0,40);panel.Equip.BackgroundColor3=color;panel.Equip.Text="EQUIP ROCK"
 panel.Dismiss.BackgroundTransparency=.38;panel.Dismiss.Position=UDim2.new(.57,6,1,-66);panel.Dismiss.Size=UDim2.new(.43,-22,0,40);panel.Dismiss.Text="NICE!"
 panel.Equip.Visible=false;panel.Dismiss.Visible=false
 panel.Footer.Visible=true;panel.Footer.Text="SENDING TO INVENTORY...";panel.Footer.TextColor3=color;panel.Footer.TextSize=10
 panel.StoreTrack.Visible=false;panel.StoreTrack.Fill.BackgroundColor3=color;panel.StoreTrack.Fill.Size=UDim2.fromScale(1,1)
 tw(panel.StoreTrack.Fill,2,{Size=UDim2.fromScale(0,1)})
 local viewport=workspace.CurrentCamera.ViewportSize
 local target=math.min(1,(viewport.Y*.6)/174)
 panel.RevealScale.Scale=target*.82;tw(panel.RevealScale,.45,{Scale=target},Enum.EasingStyle.Back)
end
function UI.error(panel)
 panel.StoreTrack.Visible=false
 panel.Size=UDim2.new(.9,0,0,208);panel.Position=UDim2.fromScale(.5,.055);panel.RevealScale.Scale=1;panel.BackgroundTransparency=.45
 panel.Heading.TextXAlignment=Enum.TextXAlignment.Center;panel.RockName.TextXAlignment=Enum.TextXAlignment.Center
 panel.Halo.Visible=false;panel.Discovery.Visible=false;panel.Footer.Visible=false
 panel.Heading.Position=UDim2.fromOffset(16,22);panel.Heading.Size=UDim2.new(1,-32,0,24)
 panel.RockName.Position=UDim2.fromOffset(20,62);panel.RockName.Size=UDim2.new(1,-40,0,72);panel.RockName.TextWrapped=true;panel.RockName.TextSize=18
 panel.Dismiss.Position=UDim2.new(.5, -60,1,-60);panel.Dismiss.Size=UDim2.fromOffset(120,40);panel.Dismiss.Text="GOT IT"
end
function UI.stored(gui,rock)
 local panel=gui.SummonResult
 panel.Visible=false
 local toast=gui.StoreToast;toast.Text="+1  "..rock.name.."  •  IN INVENTORY";toast.Visible=true;toast.TextTransparency=0
 toast:SetAttribute("Version",(toast:GetAttribute("Version") or 0)+1);local version=toast:GetAttribute("Version")
 toast.Position=UDim2.fromScale(.5,.065);tw(toast,.22,{Position=UDim2.fromScale(.5,.055)})
 task.delay(1.6,function()
  if toast:GetAttribute("Version")~=version then return end
  tw(toast,.25,{TextTransparency=1})
  task.delay(.25,function() if toast:GetAttribute("Version")==version then toast.Visible=false end end)
 end)
end
function UI.seal(s)
 local b=s.button
 b.Size=UDim2.new(.88,0,0,104);b.Position=UDim2.fromScale(.5,.89)
 b.UISizeConstraint.MaxSize=Vector2.new(440,104)
 b.BackgroundColor3=Color3.new(1,1,1);b.BackgroundTransparency=.06
 b.TextTransparency=1;b.BorderSizePixel=0;corner(b,18)
 s.stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.stroke.Thickness=1.6;s.stroke.Transparency=.18
 local grad=Instance.new("UIGradient");grad.Rotation=20
 grad.Color=ColorSequence.new(Color3.fromRGB(35,39,66),Color3.fromRGB(9,15,28));grad.Parent=b
 sigil(b,"CrystalSigil",s.color,UDim2.fromOffset(19,34))
 local text=label(b,"SealTitle",b.Text,UDim2.fromOffset(68,31),UDim2.new(1,-82,0,30),20,Color3.fromRGB(246,250,255))
 text.TextXAlignment=Enum.TextXAlignment.Left;text.TextScaled=true;text.TextWrapped=true
 local limit=Instance.new("UITextSizeConstraint");limit.MaxTextSize=20;limit.MinTextSize=11;limit.Parent=text
 b:GetPropertyChangedSignal("Text"):Connect(function() text.Text=b.Text end)
 local title=label(b,"Eyebrow","AWAKEN THE CRYSTAL",UDim2.fromOffset(68,12),UDim2.new(1,-82,0,16),10,cyan)
 title.TextXAlignment=Enum.TextXAlignment.Left
 s.caption.Position=UDim2.fromOffset(68,66);s.caption.Size=UDim2.new(1,-82,0,20)
 s.caption.Text="Click freely to release its energy";s.caption.TextScaled=true;s.caption.TextXAlignment=Enum.TextXAlignment.Left
 local captionLimit=Instance.new("UITextSizeConstraint");captionLimit.MinTextSize=8;captionLimit.MaxTextSize=11;captionLimit.Parent=s.caption
 local edge=Instance.new("Frame");edge.Name="EnergyEdge";edge.Position=UDim2.new(0,20,1,-7)
 edge.Size=UDim2.new(1,-40,0,2);edge.BorderSizePixel=0;edge.BackgroundColor3=s.color;edge.Parent=b
 local fade=Instance.new("UIGradient");fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)});fade.Parent=edge
 s.pips={}
 s.buttonScale=Instance.new("UIScale");s.buttonScale.Parent=b
 press(b)
end
function UI.tier(s)
 if s.button:FindFirstChild("EnergyEdge") then s.button.EnergyEdge.BackgroundColor3=s.color end
 if s.button:FindFirstChild("CrystalSigil") then
  local gem=s.button.CrystalSigil.Crystal
  gem.BackgroundColor3=s.color;gem.UIStroke.Color=s.color
  gem.UIGradient.Color=ColorSequence.new(Color3.new(1,1,1),s.color:Lerp(navy,.35))
 end
 local names={"Common","Uncommon","Rare","Epic","Legendary","Mythical"}
 local G=require(game.ReplicatedStorage.Shared.GeodeReveal)
 for i,p in s.pips do
  tw(p,.3,{BackgroundColor3=i<=s.tier and G.settings(names[i]).color or Color3.fromRGB(54,74,97),BackgroundTransparency=i<=s.tier and 0 or .65})
 end
end
function UI.strike(s,hits)
 UI.tier(s)
 s.button.Eyebrow.TextColor3=s.color
 s.buttonScale.Scale=.94;tw(s.buttonScale,.3,{Scale=1},Enum.EasingStyle.Back)
 local flash=Instance.new("Frame");flash.Name="StrikePulse";flash.AnchorPoint=Vector2.new(.5,.5);flash.Position=UDim2.fromScale(.5,.5);flash.Size=UDim2.fromScale(1,1);flash.BackgroundTransparency=1;flash.Parent=s.button;corner(flash,18)
 local stroke=Instance.new("UIStroke");stroke.Color=s.color;stroke.Thickness=2;stroke.Parent=flash
 tw(flash,.4,{Size=UDim2.fromScale(1.12,1.4)});tw(stroke,.4,{Transparency=1})
 game:GetService("Debris"):AddItem(flash,.45)
end

-- Shared toy-like card treatment for the station and crack control.
local ink=Color3.fromRGB(12,19,30)
local singleColor=Color3.fromRGB(34,210,89)
local tripleColor=Color3.fromRGB(174,66,244)
local function chunky(text,size)
 text.Font=Enum.Font.FredokaOne;text.TextColor3=Color3.new(1,1,1)
 text.TextStrokeColor3=ink;text.TextStrokeTransparency=0
 text.TextSize=size;text.TextScaled=true;text.TextWrapped=true;text.ZIndex=8
 local cap=text:FindFirstChildWhichIsA("UITextSizeConstraint") or Instance.new("UITextSizeConstraint",text)
 cap.MinTextSize=8;cap.MaxTextSize=size
end
local function frame(parent,name,pos,size,color,z,radius)
 local f=Instance.new("Frame");f.Name=name;f.Position=pos;f.Size=size
 f.BackgroundColor3=color;f.BorderSizePixel=0;f.ZIndex=z;f.Parent=parent
 corner(f,radius);return f
end
local function tintCard(b,color)
 local face=b:FindFirstChild("CandyFace");if not face then return end
 face.BackgroundColor3=Color3.new(1,1,1)
 face.Sheen.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.42),color:Lerp(ink,.23))
 b.CandyLabel.BackgroundColor3=color:Lerp(ink,.42)
 b.CandyShadow.BackgroundColor3=color:Lerp(ink,.78)
end
local function candy(b,color,triple,cardPreview,iconColor)
 b.ClipsDescendants=false;b.BackgroundTransparency=1;b.BorderSizePixel=0
 for _,v in b:GetChildren() do
  if v:IsA("UIGradient") or v:IsA("UIStroke") then v.Enabled=false end
 end
 for _,name in {"CrystalSigil","EnergyEdge","ActionEyebrow","InnerBorder","TopHighlight","BottomShade","GlossLine","Divider","GlarePrimary","GlareSecondary","CoinIcon"} do
  local v=b:FindFirstChild(name);if v and v:IsA("GuiObject") then v.Visible=false end
 end
 local shadow=frame(b,"CandyShadow",UDim2.fromOffset(0,7),UDim2.fromScale(1,1),ink,1,21)
 local outline=Instance.new("UIStroke");outline.Color=ink;outline.Thickness=3;outline.Parent=shadow
 local face=frame(b,"CandyFace",UDim2.fromScale(0,0),UDim2.fromScale(1,1),color,2,21)
 local edge=Instance.new("UIStroke");edge.Color=ink;edge.Thickness=3;edge.Parent=face
 local sheen=Instance.new("UIGradient");sheen.Name="Sheen";sheen.Rotation=90;sheen.Parent=face
 local lip=frame(b,"CandyLip",UDim2.fromOffset(4,4),UDim2.new(1,-8,1,-8),Color3.new(1,1,1),3,17)
 lip.BackgroundTransparency=1
 local rim=Instance.new("UIStroke");rim.Color=Color3.new(1,1,1);rim.Transparency=.5;rim.Thickness=2;rim.Parent=lip
 local bar=frame(b,"CandyLabel",UDim2.new(0,3,1,-49),UDim2.new(1,-6,0,46),color,4,17)
 -- The square picture area and deeper label share one silhouette and outer border.
 local gloss=frame(b,"CandyGloss",UDim2.fromOffset(9,7),UDim2.new(1,-18,0,30),Color3.new(1,1,1),3,14)
 gloss.BackgroundTransparency=.78
 local fade=Instance.new("UIGradient");fade.Rotation=90;fade.Transparency=NumberSequence.new(.1,1);fade.Parent=gloss
 if cardPreview then
  -- Full shell stays still; an orbiting camera gives it a stable, low-cost spin.
  -- Both summon prompts and the crack card use the same shell and lighting.
  local viewport=Instance.new("ViewportFrame");viewport.Name="GeodeIcon";viewport.BackgroundTransparency=1
  viewport.Position=UDim2.fromOffset(9,10);viewport.Size=UDim2.new(1,-18,1,-62);viewport.ZIndex=5
  viewport.Ambient=shellVisual.IconAmbient;viewport.LightColor=shellVisual.IconLightColor;viewport.Parent=b
  local world=Instance.new("WorldModel");world.Parent=viewport
  for _,part in game.ReplicatedStorage.GeodeShellTemplate:GetChildren() do
   if part:IsA("BasePart") then
    local shell=part:Clone()
    shell.Color=iconColor or shellVisual.IconColor
    shell.Material=shellVisual.Material
    if shell:IsA("PartOperation") then shell.UsePartColor=true end
    shell.CFrame=CFrame.new(part:GetAttribute("Direction")*.075)*part:GetAttribute("Rest")
    shell.Anchored=true;shell.CanCollide=false;shell.CanTouch=false;shell.CanQuery=false;shell.CastShadow=false
    shell.Parent=world
   end
  end
  local heart=Instance.new("Part");heart.Name="IconCrystalHeart";heart.Shape=Enum.PartType.Ball
  heart.Size=Vector3.one*2.65;heart.Position=Vector3.zero;heart.Color=color
  heart.Material=Enum.Material.Neon;heart.Anchored=true;heart.CanCollide=false;heart.CanTouch=false;heart.CanQuery=false;heart.CastShadow=false;heart.Parent=world
  local cam=Instance.new("Camera");cam.FieldOfView=32
  cam.CFrame=CFrame.lookAt(Vector3.new(0,2,7.8),Vector3.zero);cam.Parent=viewport;viewport.CurrentCamera=cam
  viewport.LightDirection=cam.CFrame.LookVector
  local spinAngle=0
  local spinElapsed=0
  local function visible()
   if viewport.ImageTransparency>.98 then return false end
   local ancestor=viewport
   while ancestor do
    if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
    if ancestor:IsA("LayerCollector") and not ancestor.Enabled then return false end
    ancestor=ancestor.Parent
   end
   return viewport:IsDescendantOf(game)
  end
  local spinConnection
  spinConnection=Run.RenderStepped:Connect(function(dt)
   if not viewport.Parent then spinConnection:Disconnect();return end
   -- Keep preloaded render targets warm, but do not redraw hidden cards.
   if player:GetAttribute("ReducedMotion")==true or not visible() then
    spinElapsed=0
    return
   end
   spinElapsed+=dt
   if spinElapsed<1/30 then return end
   spinAngle=(spinAngle+spinElapsed*math.rad(22))%(2*math.pi)
   spinElapsed=0
   cam.CFrame=CFrame.lookAt(Vector3.new(math.sin(spinAngle)*7.8,2,math.cos(spinAngle)*7.8),Vector3.zero)
   viewport.LightDirection=cam.CFrame.LookVector
  end)
  viewport.Destroying:Connect(function() spinConnection:Disconnect() end)
 end
 local star=label(b,"CandySpark","+",UDim2.new(1,-34,0,15),UDim2.fromOffset(24,30),28,Color3.fromRGB(255,249,163))
 star.TextStrokeColor3=ink;star.TextStrokeTransparency=0;star.ZIndex=6
 tintCard(b,color)
end
local oldAction=UI.action
function UI.action(root,triple)
 oldAction(root,triple)
 root.Shadow.Visible=false;root.AnchorPoint=Vector2.new(.5,0)
 root.Size=UDim2.fromOffset(144,172)
 root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize=Vector2.new(144,172)
 local b=root.ActionButton
 candy(b,triple and tripleColor or singleColor,triple,true)
 b.ActionText.Position=UDim2.new(0,7,1,-46);b.ActionText.Size=UDim2.new(1,-14,0,24)
 b.ActionText.TextXAlignment=Enum.TextXAlignment.Center;chunky(b.ActionText,22)
 b.CostText.Position=UDim2.new(0,7,1,-22);b.CostText.Size=UDim2.new(1,-14,0,17)
 b.CostText.TextXAlignment=Enum.TextXAlignment.Center;chunky(b.CostText,13)
 b.KeyCap.Position=UDim2.fromOffset(8,8);b.KeyCap.Size=UDim2.fromOffset(29,26);b.KeyCap.ZIndex=7
 b.KeyCap.BackgroundColor3=ink;b.KeyCap.KeyGradient.Enabled=false;corner(b.KeyCap,8)
 chunky(b.KeyCap.KeyText,14)
end
function UI.prompt(root,reward)
 local b=root.ActionButton
 local color=reward and Color3.fromRGB(255,167,31) or (root:GetAttribute("Triple") and tripleColor or singleColor)
 if b:FindFirstChild("CandyFace") then
  tintCard(b,color);b.BackgroundTransparency=1;b.OuterStroke.Enabled=false;b.MainGradient.Enabled=false
 end
 b.ActionText.Text=reward and "CONTINUE" or (root:GetAttribute("Triple") and "SUMMON 3" or "SUMMON 1")
 b.CostText.Position=UDim2.new(0,7,1,-22);b.CostText.Size=UDim2.new(1,-14,0,17)
 b.CostText.TextColor3=Color3.new(1,1,1)
 b.KeyCap.BackgroundColor3=ink;b.KeyCap.KeyGradient.Enabled=false;b.KeyCap.KeyText.TextColor3=Color3.new(1,1,1)
end
local oldSeal=UI.seal
function UI.seal(s)
 oldSeal(s)
 local b=s.button
 b.AnchorPoint=Vector2.new(1,1);b.Position=UDim2.fromScale(.97,.9);b.Size=UDim2.fromOffset(164,194)
 b.UISizeConstraint.MaxSize=Vector2.new(164,194)
 candy(b,rarityColors[s.rarity] or rarityColors.Common,false,true,shellVisual.SealIconColor)
 b.SealTitle.Position=UDim2.new(0,7,1,-48);b.SealTitle.Size=UDim2.new(1,-14,0,29)
 b.SealTitle.TextXAlignment=Enum.TextXAlignment.Center;chunky(b.SealTitle,19)
 b.Eyebrow.Visible=false
 s.caption.Position=UDim2.new(0,5,1,-20);s.caption.Size=UDim2.new(1,-10,0,15)
 s.caption.TextXAlignment=Enum.TextXAlignment.Center;chunky(s.caption,10)
 s.stroke.Enabled=false
 local responsive=Instance.new("UIScale");responsive.Name="ViewportScale";responsive.Parent=b
 local function resize() local v=workspace.CurrentCamera.ViewportSize;responsive.Scale=math.clamp(math.min(v.Y/650,v.X/420),.65,1) end
 resize()
 local connection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
 b.Destroying:Connect(function() connection:Disconnect() end)
end
function UI.sealRarity(s,rarity)
 s.cardRarity=rarity
 tintCard(s.button,rarityColors[rarity] or rarityColors.Common)
end
local oldTier=UI.tier
function UI.tier(s)
 oldTier(s)
 UI.sealRarity(s,s.cardRarity or s.rarity)
 local icon=s.button:FindFirstChild("GeodeIcon")
 local heart=icon and icon:FindFirstChild("WorldModel") and icon.WorldModel:FindFirstChild("IconCrystalHeart")
 if heart then heart.Color=s.color end
 s.stroke.Enabled=false
end

-- Fade the complete crack card together, then hide it after its exit motion.
function UI.dismissSeal(s)
 local button=s.button
 if s.sealDismissing or not button or not button.Parent then return end
 s.sealDismissing=true
 button.Active=false
 button.Selectable=false
 local duration=require(game.ReplicatedStorage.Shared.SummonConfig).ExitSeconds
 if player:GetAttribute("ReducedMotion")~=true then
  tw(button,duration,{Position=button.Position+UDim2.fromOffset(22,12)})
 end
 local objects=button:GetDescendants()
 table.insert(objects,button)
 for _,object in objects do
  local properties={}
  if object:IsA("GuiObject") then properties.BackgroundTransparency=1 end
  if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
   properties.TextTransparency=1
   properties.TextStrokeTransparency=1
  elseif object:IsA("ImageLabel") or object:IsA("ImageButton") or object:IsA("ViewportFrame") then
   properties.ImageTransparency=1
  elseif object:IsA("UIStroke") then
   properties.Transparency=1
  end
  if next(properties) then tw(object,duration,properties) end
 end
 task.delay(duration,function()
  if button.Parent then button.Visible=false end
 end)
end

-- Reuse the same station-card skin for related interfaces.
function UI.stationCard(button,color)
 candy(button,color,false,false)
end
function UI.tintStationCard(button,color)
 tintCard(button,color)
end
function UI.stationText(text,size)
 chunky(text,size)
end

return UI