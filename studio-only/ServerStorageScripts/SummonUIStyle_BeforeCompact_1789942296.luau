local UI={}
local TS=game:GetService("TweenService")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local player=game.Players.LocalPlayer
local cyan=Color3.fromRGB(101,239,255)
local navy=Color3.fromRGB(13,19,35)
local function tw(o,t,p,style) TS:Create(o,TweenInfo.new(t,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),p):Play() end
local function corner(o,r)
 local c=o:FindFirstChildWhichIsA("UICorner") or Instance.new("UICorner",o);c.CornerRadius=UDim.new(0,r)
end
local function label(parent,name,text,pos,size,fontSize,color)
 local l=Instance.new("TextLabel");l.Name=name;l.BackgroundTransparency=1;l.Position=pos;l.Size=size;l.Text=text;l.TextSize=fontSize;l.Font=Enum.Font.GothamBold;l.TextColor3=color;l.ZIndex=4;l.Parent=parent;return l
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
 local max=root:FindFirstChildWhichIsA("UISizeConstraint") or Instance.new("UISizeConstraint",root);max.MinSize=Vector2.zero;max.MaxSize=Vector2.new(360,82)
 for _,name in {"InnerBorder","TopHighlight","BottomShade","GlossLine","Divider"} do local o=b:FindFirstChild(name);if o then o.Visible=false end end
 root.Shadow.BackgroundColor3=Color3.new(0,0,0);root.Shadow.BackgroundTransparency=.65;corner(root.Shadow,20)
 corner(b,18);b.OuterStroke.Thickness=1.5;b.OuterStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 b.ActionText.Font=Enum.Font.GothamBlack;b.ActionText.TextSize=22;b.ActionText.TextStrokeTransparency=1
 b.CostText.Font=Enum.Font.GothamMedium;b.CostText.TextSize=14;b.CostText.TextStrokeTransparency=1
 b.KeyCap.KeyText.Font=Enum.Font.GothamBold;b.KeyCap.KeyText.TextStrokeTransparency=1
 local ks=b.KeyCap:FindFirstChildWhichIsA("UIStroke");if ks then ks.Thickness=1;ks.Color=cyan end
 local panel=gui.SummonResult;panel.AnchorPoint=Vector2.new(.5,0)
 panel.BackgroundColor3=Color3.new(1,1,1);corner(panel,24);panel.Outline.Thickness=1.5
 if panel:FindFirstChild("TopHighlight") then panel.TopHighlight.Visible=false end
 local grad=panel:FindFirstChildWhichIsA("UIGradient") or Instance.new("UIGradient",panel);grad.Rotation=65;grad.Color=ColorSequence.new(Color3.fromRGB(31,39,65),Color3.fromRGB(10,15,28));grad.Parent=panel
 local sc=Instance.new("UIScale");sc.Name="RevealScale";sc.Parent=panel
 local limit=panel:FindFirstChildWhichIsA("UISizeConstraint") or Instance.new("UISizeConstraint",panel);limit.MinSize=Vector2.zero;limit.MaxSize=Vector2.new(390,390)
 for _,v in {panel.Heading,panel.RockName,panel.Details} do v.TextStrokeTransparency=1;v.TextScaled=false;v.ZIndex=5 end
 panel.Heading.Font=Enum.Font.GothamBold;panel.Heading.TextSize=12
 panel.RockName.Font=Enum.Font.GothamBlack;panel.RockName.TextSize=25
 panel.Details.Font=Enum.Font.GothamMedium;panel.Details.TextSize=13
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
  btn.Font=Enum.Font.GothamBold;btn.TextSize=13;btn.TextStrokeTransparency=1;btn.ZIndex=6;corner(btn,12);press(btn)
 end
 panel.Equip.BackgroundColor3=cyan;panel.Equip.TextColor3=navy
 panel.Dismiss.BackgroundColor3=Color3.fromRGB(34,43,62);panel.Dismiss.TextColor3=Color3.fromRGB(219,230,245)
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
function UI.prompt(root,reward)
 local b=root.ActionButton
 b.BackgroundColor3=Color3.new(1,1,1)
 b.MainGradient.Color=ColorSequence.new(Color3.fromRGB(31,44,65),Color3.fromRGB(12,21,37))
 local color=reward and Color3.fromRGB(255,213,112) or cyan
 b.OuterStroke.Color=color
 b.KeyCap.BackgroundColor3=Color3.new(1,1,1)
 b.KeyCap.KeyGradient.Color=ColorSequence.new(color,color:Lerp(Color3.fromRGB(26,74,100),.4))
 b.KeyCap.KeyText.TextColor3=navy;b.CostText.TextColor3=Color3.fromRGB(194,215,232)
 b.ActionText.Text=reward and "CONTINUE" or "SUMMON A ROCK"
end
function UI.result(panel,rock,data)
 local color=require(game.ReplicatedStorage.Shared.RockCatalog).RarityColors[rock.rarity] or cyan
 panel.Size=UDim2.new(.86,0,0,368);panel.Position=UDim2.fromScale(.5,.08);panel.BackgroundTransparency=.03
 panel.Outline.Color=color;panel.Outline.Transparency=.12
 panel.Discovery.Visible=true;panel.Discovery.Text=data.isNew and "NEW DISCOVERY" or "COLLECTION EXPANDED";panel.Discovery.TextColor3=color
 panel.Heading.Text=string.upper(rock.rarity);panel.Heading.Position=UDim2.fromOffset(20,39);panel.Heading.Size=UDim2.new(1,-40,0,21);panel.Heading.TextSize=15
 panel.Halo.Visible=true;panel.Halo.BackgroundColor3=color;panel.Halo.Ring.Color=color
 for _,v in panel.Halo.Orbit:GetChildren() do v.TextColor3=color end
 panel.RockImage.Position=UDim2.new(.5,-59,0,72);panel.RockImage.Size=UDim2.fromOffset(118,118)
 panel.RockName.TextSize=25;panel.RockName.TextWrapped=false;panel.RockName.Position=UDim2.fromOffset(16,215);panel.RockName.Size=UDim2.new(1,-32,0,31)
 panel.Details.Position=UDim2.fromOffset(16,252);panel.Details.Size=UDim2.new(1,-32,0,22);panel.Details.TextColor3=Color3.fromRGB(174,195,216)
 panel.Equip.Position=UDim2.new(0,20,1,-78);panel.Equip.Size=UDim2.new(.57,-26,0,43);panel.Equip.BackgroundColor3=color;panel.Equip.Text="EQUIP ROCK"
 panel.Dismiss.Position=UDim2.new(.57,6,1,-78);panel.Dismiss.Size=UDim2.new(.43,-26,0,43);panel.Dismiss.Text="NICE!"
 panel.Footer.Visible=true
 local viewport=workspace.CurrentCamera.ViewportSize
 local target=math.min(1,(viewport.Y*.82)/368)
 panel.RevealScale.Scale=target*.82;tw(panel.RevealScale,.45,{Scale=target},Enum.EasingStyle.Back)
end
function UI.error(panel)
 panel.Size=UDim2.new(.86,0,0,224);panel.Position=UDim2.fromScale(.5,.12);panel.RevealScale.Scale=1
 panel.Halo.Visible=false;panel.Discovery.Visible=false;panel.Footer.Visible=false
 panel.Heading.Position=UDim2.fromOffset(16,22);panel.Heading.Size=UDim2.new(1,-32,0,24)
 panel.RockName.Position=UDim2.fromOffset(20,62);panel.RockName.Size=UDim2.new(1,-40,0,72);panel.RockName.TextWrapped=true;panel.RockName.TextSize=18
 panel.Dismiss.Position=UDim2.new(.5, -60,1,-60);panel.Dismiss.Size=UDim2.fromOffset(120,40);panel.Dismiss.Text="GOT IT"
end
function UI.seal(s)
 local b=s.button;b.Size=UDim2.new(.84,0,0,108);b.UISizeConstraint.MaxSize=Vector2.new(420,108)
 b.BackgroundColor3=Color3.new(1,1,1);b.BackgroundTransparency=.02;b.TextSize=18;b.TextTransparency=1
 s.stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 local text=label(b,"SealTitle",b.Text,UDim2.new(0,12,0,12),UDim2.new(1,-24,0,42),18,Color3.fromRGB(238,250,255));text.TextWrapped=true
 b:GetPropertyChangedSignal("Text"):Connect(function() text.Text=b.Text end)
 local p=Instance.new("UIPadding");p.PaddingBottom=UDim.new(0,24);p.Parent=b
 local grad=Instance.new("UIGradient");grad.Color=ColorSequence.new(Color3.fromRGB(34,47,72),navy);grad.Rotation=25;grad.Parent=b
 local title=label(b,"Eyebrow","A W A K E N I N G",UDim2.new(0,0,0,-30),UDim2.new(1,0,0,20),11,cyan);title.TextStrokeTransparency=.6
 s.pips={}
 for i=1,3 do
  local pip=Instance.new("Frame");pip.Name="Seal"..i;pip.Size=UDim2.new(1/3,-20,0,5);pip.Position=UDim2.new((i-1)/3,10,1,-31);pip.BorderSizePixel=0;pip.BackgroundColor3=Color3.fromRGB(54,74,97);pip.Parent=b;corner(pip,4);s.pips[i]=pip
 end
 s.caption.Text="Tap to channel energy • opens automatically"
 s.caption.TextScaled=false;s.caption.TextSize=11
 s.buttonScale=Instance.new("UIScale");s.buttonScale.Parent=b
 press(b)
end
function UI.strike(s,hits)
 for i,p in s.pips do if i<=hits then tw(p,.12,{BackgroundColor3=cyan}) end end
 s.buttonScale.Scale=.94;tw(s.buttonScale,.3,{Scale=1},Enum.EasingStyle.Back)
 local flash=Instance.new("Frame");flash.Name="StrikePulse";flash.AnchorPoint=Vector2.new(.5,.5);flash.Position=UDim2.fromScale(.5,.5);flash.Size=UDim2.fromScale(1,1);flash.BackgroundTransparency=1;flash.Parent=s.button;corner(flash,18)
 local stroke=Instance.new("UIStroke");stroke.Color=cyan;stroke.Thickness=2;stroke.Parent=flash
 tw(flash,.4,{Size=UDim2.fromScale(1.12,1.4)});tw(stroke,.4,{Transparency=1})
 game:GetService("Debris"):AddItem(flash,.45)
end
return UI
