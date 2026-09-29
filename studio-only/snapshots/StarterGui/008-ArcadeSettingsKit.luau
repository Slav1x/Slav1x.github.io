local Tween=game:GetService("TweenService")
local Players=game:GetService("Players")
local K={}
local navy=Color3.fromRGB(12,27,45)
local white=Color3.fromRGB(249,253,255)
local active=setmetatable({},{__mode="k"})
function K.tween(obj,props,t,style)
 local old=active[obj] if old then old:Cancel() end
 local tw=Tween:Create(obj,TweenInfo.new(t or .13,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
 active[obj]=tw tw:Play() return tw
end
function K.worldBlur(size,t)
 local L=game:GetService("Lighting") local b=L:FindFirstChild("MenuWorldBlur")
 if not b then b=Instance.new("BlurEffect") b.Name="MenuWorldBlur" b.Size=0 b.Parent=L end
 K.tween(b,{Size=size},t or .2) return b
end
function K.paint(b,c)
 b.BackgroundColor3=c:Lerp(navy,.55)
 b.Face.BackgroundColor3=white
 b.Face.Gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c:Lerp(white,.27)),ColorSequenceKeypoint.new(.45,c),ColorSequenceKeypoint.new(1,c:Lerp(navy,.4))})
end
function K.compact(value)
 local n=math.max(0,tonumber(value) or 0)
 local units={"","K","M","B","T","Q"}
 local index=1
 while n>=1000 and index<#units do n/=1000 index+=1 end
 local decimals=(index==1 and 0) or (n<10 and 2 or 1)
 local rounded=math.floor(n*10^decimals+.5)/10^decimals
 if rounded>=1000 and index<#units then rounded/=1000 index+=1 decimals=2 end
 local text=string.format("%."..decimals.."f",rounded)
 if decimals>0 then text=text:gsub("0+$",""):gsub("%.$","") end
 return text..units[index]
end
function K.full(n)
 return tostring(math.floor(n)):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
function K.buttons(root)
 for _,b in root:GetDescendants() do
  if b:IsA("TextButton") and b:FindFirstChild("ButtonScale") then
   local base=b.Position local over=false
   local function apply(scale,dy)
    if Players.LocalPlayer:GetAttribute("ReducedMotion")==true then return end
    K.tween(b.ButtonScale,{Scale=scale},.1)
    
   end
   b.MouseEnter:Connect(function() over=true if b.Active then apply(1.035,-1) end end)
   b.MouseLeave:Connect(function() over=false apply(1,0) end)
   b.InputBegan:Connect(function(i) if b.Active and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then apply(.96,2) end end)
   b.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then apply(over and 1.035 or 1,over and -1 or 0) end end)
  end
 end
end
function K.modal(root,w,h,onOpen)
 local player=Players.LocalPlayer local token=0 local hidden={}
 local function sync()
  for _,g in player.PlayerGui:GetChildren() do
   if g.Name=="HotbarGui" and g:IsA("ScreenGui") then
    if root.Visible then if hidden[g]==nil then hidden[g]=g.Enabled end g.Enabled=false
    elseif hidden[g]~=nil then g.Enabled=hidden[g] hidden[g]=nil end
   end
  end
 end
 root:GetPropertyChangedSignal("Visible"):Connect(sync)
 player.PlayerGui.ChildAdded:Connect(function(g) if g.Name=="HotbarGui" then task.defer(sync) end end)
 local function resize()
  local v=root.Parent.AbsoluteSize
  if v.X<1 then v=workspace.CurrentCamera.ViewportSize end
  local width=v.X<700 and 540 or math.min(w,math.max(700,(v.X-64)/.82))
  local scale=math.min(.82,(v.X-32)/width,(v.Y-48)/math.min(h,580))
  local short=v.Y<500
  local height=math.min(h,(v.Y-(short and 40 or 80))/scale)
  root.ResponsiveScale.Scale=scale
  root.Size=UDim2.fromOffset(width,height)
  root.Position=UDim2.fromScale(.5,.5)
  local b=root.Surface local narrow=width<(root.Name=="upgradesui" and 930 or 780)
  local compact=short
  local headerH=compact and 60 or short and 70 or 90
  b.Header.Size=UDim2.new(1,-8,0,headerH)
    local headerDepth=b:FindFirstChild("ReferenceHeaderDepth")
    if headerDepth then headerDepth.Size=b.Header.Size;headerDepth.Position=b.Header.Position+UDim2.fromOffset(0,7) end
  local sub=b.Header:FindFirstChild("Subtitle") if sub then sub.Visible=not short end
  b.Header.Icon.Size=UDim2.fromOffset(62,compact and 40 or short and 44 or 62)
  if b.Header:FindFirstChild("Gear") then b.Header.Gear.Size=UDim2.fromOffset(62,compact and 40 or short and 44 or 62) b.Header.Gear.TextSize=compact and 36 or short and 40 or 54 end
  b.Cards.Position=UDim2.fromOffset(25,compact and 92 or short and 110 or 139)
  b.Cards.Size=UDim2.new(1,-50,1,compact and -124 or short and -144 or -180)
  b.Section.Position=UDim2.fromOffset(30,compact and 68 or short and 79 or 105)
  b.Header.Title.TextSize=narrow and 30 or 38
  if sub then sub.TextSize=narrow and 10 or 12 end
  b.Section.Size=UDim2.new(.5,-30,0,25)
  if b:FindFirstChild("Wallet") then b.Wallet.Position=UDim2.new(.5,0,0,short and 79 or 105) b.Wallet.Size=UDim2.new(.5,-30,0,25) b.Wallet.TextSize=narrow and 14 or 18 end
  if b:FindFirstChild("Session") then b.Session.Visible=not narrow and not short end
  for _,c in b.Cards:GetChildren() do if c:IsA("Frame") then
   if root.Name=="upgradesui" then
    local progressionRow=c:GetAttribute("ProgressionRow")==true
    local resetHint=progressionRow and c:FindFirstChild("ResetHint")
    local baseHeight=compact and 138 or narrow and 172 or 96
    c.Size=UDim2.new(1,-6,0,baseHeight+(resetHint and 44 or 0))
    if resetHint then
     resetHint.Position=UDim2.fromOffset(narrow and 12 or 106,baseHeight-2)
     resetHint.Size=UDim2.new(1,narrow and -24 or -130,0,36)
     resetHint.TextSize=compact and 11 or 12
    end
    c.IconBadge.Position=UDim2.fromOffset(13,10)
    c.IconBadge.Size=UDim2.fromOffset(compact and 64 or 76,compact and 64 or 76)
    c:FindFirstChild("Name").Position=UDim2.fromOffset(compact and 85 or 105,8) c:FindFirstChild("Name").Size=UDim2.new(narrow and 1 or 0,narrow and (compact and -100 or -120) or 276,0,29)
    c.Description.Position=UDim2.fromOffset(compact and 86 or 106,compact and 34 or 39) c.Description.Size=UDim2.new(narrow and 1 or 0,narrow and (compact and -100 or -120) or 280,0,30)
    c.Description.TextWrapped=true
    c.Level.Position=UDim2.fromOffset(compact and 86 or 106,compact and 60 or 74)
    c.Pips.Position=narrow and UDim2.fromOffset(13,92) or UDim2.fromOffset(252,79)
    c.Pips.Visible=not narrow and not progressionRow
    if progressionRow then c.Description.TextSize=compact and 12 or 14 end
    c.Values.Position=narrow and UDim2.fromOffset(12,compact and 76 or 103) or UDim2.new(1,-501,0,18)
    c.Values.Size=UDim2.new(narrow and .52 or 0,narrow and -20 or 243,0,compact and 52 or 57)
    c.Values.CurrentCaption.Position=UDim2.new(0,4,0,4) c.Values.CurrentCaption.Size=UDim2.new(.45,0,0,16)
    c.Values.NextCaption.Position=UDim2.new(.55,0,0,4) c.Values.NextCaption.Size=UDim2.new(.45,-4,0,16)
    c.Values.Current.Position=UDim2.new(0,4,0,25) c.Values.Current.Size=UDim2.new(.45,0,0,27)
    c.Values.Next.Position=UDim2.new(.55,0,0,25) c.Values.Next.Size=UDim2.new(.45,-4,0,27)
    c.Values.Arrow.Position=UDim2.new(.45,0,0,21) c.Values.Arrow.Size=UDim2.new(.1,0,0,30)
    c.Values.Current.TextScaled=true c.Values.Next.TextScaled=true
    c.Buy.AnchorPoint=Vector2.new(1,0) c.Buy.Position=narrow and UDim2.new(1,-12,0,compact and 76 or 103) or UDim2.new(1,-20,0,16)
    c.Buy.Size=UDim2.new(narrow and .48 or 0,narrow and -8 or 209,0,compact and 54 or narrow and 59 or 69)
    c.Buy.Face.Size=UDim2.new(1,-4,1,-6)
    c.Buy.Label.Size=UDim2.new(1,-10,0,23) c.Buy.Price.Size=UDim2.new(1,-10,0,26)
    c.Buy.Price.Position=UDim2.fromOffset(5,27)
   else
    local codes=c.Name=="Codes"
    c.Size=UDim2.new(1,-6,0,codes and 102 or compact and 86 or narrow and 112 or 68)
    if not codes then
     c:FindFirstChild("Name").Size=UDim2.new(1,-85,0,28)
     c.Description.Size=UDim2.new(narrow and 1 or 0,narrow and -85 or 358,0,19)
     c.Description.TextSize=narrow and 13 or 15
     c.Description.Visible=not compact
     if c:FindFirstChild("Toggle") then c.Toggle.AnchorPoint=Vector2.new(1,0) c.Toggle.Position=UDim2.new(1,-18,0,compact and 29 or narrow and 65 or 14) end
     if c:FindFirstChild("Track") then
      c.Track.Position=compact and UDim2.fromOffset(72,29) or narrow and UDim2.fromOffset(72,61) or UDim2.new(1,-290,0,6)
      c.Track.Size=narrow and UDim2.new(1,-167,0,46) or UDim2.fromOffset(193,54)
      c.Percent.Position=UDim2.new(1,-80,0,compact and 38 or narrow and 70 or 19)
     end
     if c.Name=="Music" then
      c.Size=UDim2.new(1,-6,0,compact and 138 or narrow and 154 or 68)
      c:FindFirstChild("Name").Size=UDim2.fromOffset(245,28)
      c.Description.Visible=true
      c.Description.Size=UDim2.fromOffset(narrow and 220 or 245,19)
      if narrow then
       c.Track.Position=UDim2.fromOffset(72,compact and 61 or 64)
       c.Track.Size=UDim2.new(1,-160,0,35)
       c.Percent.Position=UDim2.new(1,-74,0,compact and 65 or 68)
       c.Mute.Position=UDim2.fromOffset(72,compact and 100 or 109)
       c.Mute.Size=UDim2.new(.5,-78,0,34)
       c.Next.Position=UDim2.new(.5,4,0,compact and 100 or 109)
       c.Next.Size=UDim2.new(.5,-18,0,34)
      else
       c.Track.Position=UDim2.new(1,-400,0,6)
       c.Track.Size=UDim2.fromOffset(130,54)
       c.Percent.Position=UDim2.new(1,-263,0,19)
       c.Mute.Position=UDim2.new(1,-205,0,15)
       c.Mute.Size=UDim2.fromOffset(90,38)
       c.Next.Position=UDim2.new(1,-105,0,15)
       c.Next.Size=UDim2.fromOffset(90,38)
      end
     end
    else
     c.CodeBox.Size=UDim2.new(1,-235,0,43)
     c.Redeem.AnchorPoint=Vector2.new(1,0) c.Redeem.Position=UDim2.new(1,-18,0,41)
    end
   end
  end end
 end
 local conn
 local function camera()
  if conn then conn:Disconnect() end
  if workspace.CurrentCamera then conn=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) resize() end
 end
 workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(camera) camera()
 local function close()
  token+=1 local t=token
  K.tween(root.PanelScale,{Scale=.82},.16)
  K.tween(root.Surface,{GroupTransparency=1},.13)
  K.tween(root.Backdrop,{BackgroundTransparency=1},.13)
 K.worldBlur(0,.13)
  task.delay(.18,function() if token==t then root.Visible=false root.PanelScale.Scale=1 end end)
 end
 local function open()
  token+=1
  root.Visible=true root.PanelScale.Scale=.82 root.Surface.GroupTransparency=.5 root.Backdrop.BackgroundTransparency=1
  K.tween(root.PanelScale,{Scale=1},.23,Enum.EasingStyle.Back)
  K.tween(root.Surface,{GroupTransparency=0},.2)
  K.worldBlur(24,.2)
  if onOpen then onOpen() end
 end
 root.Toggle.Event:Connect(function() if root.Visible then close() else open() end end)
 root.Surface.Header.Close.Activated:Connect(close)
 game:GetService("UserInputService").InputBegan:Connect(function(i,processed) if not processed and root.Visible and i.KeyCode==Enum.KeyCode.Escape then close() end end)
 K.buttons(root)
 return {open=open,close=close,resize=resize}
end
return K


