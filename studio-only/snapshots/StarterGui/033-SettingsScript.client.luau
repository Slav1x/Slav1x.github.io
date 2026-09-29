local root=script.Parent local body=root.Surface local rows=body.Cards local hud=root.Parent
local Players=game:GetService("Players") local player=Players.LocalPlayer
local UIS=game:GetService("UserInputService") local Sound=game:GetService("SoundService") local RS=game:GetService("ReplicatedStorage")
local K=require(hud.ArcadeSettingsKit)
local function toggle(row,read,write)
 local b=row.Toggle
 local function refresh()
  local on=read()
  b:SetAttribute("On",on)
  K.paint(b,on and Color3.fromRGB(42,205,105) or Color3.fromRGB(65,82,109))
  b.State.Text=on and "ON" or "OFF"
  b.State.Position=on and UDim2.fromOffset(4,4) or UDim2.fromOffset(51,4)
  K.tween(b.Knob,{Position=UDim2.fromOffset(on and 99 or 8,7)},.13)
 end
 local function activate()
 write(not read()) refresh()
 b.Face.BackgroundColor3=Color3.fromRGB(205,205,205)
 K.tween(b.Face,{BackgroundColor3=Color3.new(1,1,1)},.13)
end
b.Activated:Connect(activate)
if row:FindFirstChild("HitArea") then row.HitArea.Activated:Connect(activate) end

 refresh() return refresh
end
toggle(rows.ReducedMotion,function() return player:GetAttribute("ReducedMotion")==true end,function(v) player:SetAttribute("ReducedMotion",v) end)
toggle(rows.ReducedThrowFlashes,function() return player:GetAttribute("ReducedThrowFlashes")==true end,function(v) player:SetAttribute("ReducedThrowFlashes",v) end)
if player:GetAttribute("HideHud")==nil then player:SetAttribute("HideHud",false) end
toggle(rows.HideUI,function() return player:GetAttribute("HideHud")==true end,function(v)
 player:SetAttribute("HideHud",v)
end)
local function slider(row,initial,write)
 local track=row.Track local dragging=false
 local function set(v)
  v=math.clamp(v,0,1) track.Fill.Size=UDim2.new(v,0,0,13) track.Handle.Position=UDim2.fromScale(v,.5)
  row.Percent.Text=math.floor(v*100+.5).."%" write(v)
 end
 local function at(i) set((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X) end
 for _,b in {track,track.Handle} do
  b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true at(i) end end)
 end
 UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then at(i) end end)
 UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
 root:GetPropertyChangedSignal("Visible"):Connect(function() if not root.Visible then dragging=false end end)
 set(initial)
end
slider(rows.Motion,player:GetAttribute("ThrowMotionScale") or 1,function(v) player:SetAttribute("ThrowMotionScale",v); UIS.MouseDeltaSensitivity=.2+v*.8 end)
task.spawn(function()
 local group=Sound:WaitForChild("SFX")
  local row=rows.SFX
 local desired=math.clamp(group:GetAttribute('DesiredVolume') or group.Volume,0,1)
 local muted=group:GetAttribute('Muted')==true
 local function refresh()
  group:SetAttribute('DesiredVolume',desired)
  group:SetAttribute('Muted',muted)
  group.Volume=muted and 0 or desired
  row.Mute.Text=muted and 'UNMUTE' or 'MUTE'
  row.Percent.Text=muted and 'OFF' or math.floor(desired*100+.5)..'%'
 end
 slider(row,desired,function(v) desired=v;if v>0 then muted=false end;refresh() end)
 row.Mute.Activated:Connect(function() muted=not muted;if not muted and desired==0 then desired=.5 end;refresh() end)
 refresh()

end)
task.spawn(function()
 local group=Sound:WaitForChild("Music")
 local row=rows.Music
 local desired=math.clamp(group:GetAttribute("DesiredVolume") or .65,0,1)
 local muted=group:GetAttribute("Muted")==true
 local function refresh()
  group:SetAttribute("DesiredVolume",desired)
  group:SetAttribute("Muted",muted)
  group.Volume=muted and 0 or desired
  row.Mute.Text=muted and "UNMUTE" or "MUTE"
  row.Mute.TextSize=muted and 11 or 15
  row.Mute.BackgroundColor3=muted and Color3.fromRGB(88,102,128) or Color3.fromRGB(44,120,219)
  row.Percent.Text=muted and "OFF" or math.floor(desired*100+.5).."%"
 end
 slider(row,desired,function(v)
  desired=v
  if v>0 then muted=false end
  refresh()
 end)
 row.Mute.Activated:Connect(function()
  muted=not muted
  if not muted and desired==0 then desired=.65 end
  refresh()
 end)
 row.Next.Activated:Connect(function()
  group.SkipTrack:Fire()
 end)
 local now=group:WaitForChild("NowPlaying")
 local function updateTrack()
  row.Description.Text=now.Value=="Music unavailable" and "Tracks unavailable" or "Now playing: "..now.Value
 end
 now:GetPropertyChangedSignal("Value"):Connect(updateTrack)
 updateTrack()
 refresh()
end)
local pending=false
rows.Codes.Redeem.Activated:Connect(function()
 if pending then return end
 local code=rows.Codes.CodeBox.Text:match("^%s*(.-)%s*$")
 if code=="" then body.Status.Text="Enter a code first." return end
 pending=true rows.Codes.Redeem.Label.Text="..."
 local ok,result=pcall(function() return RS:WaitForChild("RedeemCode"):InvokeServer(code) end)
 pending=false rows.Codes.Redeem.Label.Text="REDEEM"
 body.Status.Text=ok and type(result)=="table" and (result.message or "") or "Something went wrong. Try again."
 if ok and type(result)=="table" and result.success then rows.Codes.CodeBox.Text="" end
end)
-- Throw shake is independent from the general camera motion setting.
if player:GetAttribute('ThrowShakeEnabled')==nil then player:SetAttribute('ThrowShakeEnabled',true) end
local shake=rows.Shake
slider(shake,player:GetAttribute('ThrowShakeScale') or .75,function(v) player:SetAttribute('ThrowShakeScale',v) end)
toggle(shake,function() return player:GetAttribute('ThrowShakeEnabled')~=false end,function(v) player:SetAttribute('ThrowShakeEnabled',v) end)

-- Presets affect engine quality and local visual effects without changing server gameplay.
local Lighting=game:GetService('Lighting')
local original=setmetatable({},{__mode='k'})
local preset=player:GetAttribute('GraphicsQualityPreset') or 'MEDIUM'
local function graphicsObject(x)
 if x:IsA('ParticleEmitter') then
  if original[x]==nil then original[x]=x.Rate end
  x.Rate=original[x]*({LOW=.4,MEDIUM=.7,HIGH=1,ULTRA=1.15})[preset]
 elseif x:IsA('PostEffect') then
  if original[x]==nil then original[x]=x.Enabled end
  x.Enabled=original[x] and preset~='LOW'
 end
end
local function refreshQuality()
 local engine={LOW=Enum.SavedQualitySetting.QualityLevel2,MEDIUM=Enum.SavedQualitySetting.QualityLevel5,HIGH=Enum.SavedQualitySetting.QualityLevel8,ULTRA=Enum.SavedQualitySetting.QualityLevel10}
 pcall(function() Lighting.GlobalShadows=preset~='LOW' end)
 for _,x in workspace:GetDescendants() do graphicsObject(x) end
 for _,x in Lighting:GetDescendants() do graphicsObject(x) end
 for _,name in {'LOW','MEDIUM','HIGH','ULTRA'} do
  local b=rows.Quality[name]
  b.BackgroundColor3=name==preset and Color3.fromRGB(0,109,252) or Color3.fromRGB(4,29,68)
  b.TextColor3=name==preset and Color3.new(1,1,1) or Color3.fromRGB(179,205,236)
 end
 player:SetAttribute('GraphicsQualityPreset',preset)
end
for _,name in {'LOW','MEDIUM','HIGH','ULTRA'} do rows.Quality[name].Activated:Connect(function() preset=name;refreshQuality() end) end
workspace.DescendantAdded:Connect(function(x) task.defer(graphicsObject,x) end)
Lighting.DescendantAdded:Connect(function(x) task.defer(graphicsObject,x) end)
refreshQuality()

K.modal(root,1100,700)

local function layout()
 local w=root.Size.X.Offset
 local narrow=w<980
 local short=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y<660
 body.Header.Position=UDim2.fromOffset(15,15)
 body.Header.Size=UDim2.new(1,-30,0,short and 78 or 100)
 local head=body.Header
 head.Icon.Size=UDim2.fromOffset(short and 63 or 82,short and 63 or 82)
 head.Title.Position=UDim2.fromOffset(short and 100 or 130,short and 6 or 12)
 head.Title.TextSize=short and 37 or 49
 head.Subtitle.Position=UDim2.fromOffset(short and 102 or 134,short and 57 or 71)
 head.Subtitle.TextSize=short and 13 or 19
 head.Close.AnchorPoint=Vector2.new(1,.5)
 head.Close.Position=UDim2.new(1,-12,.5,0)
 rows.Position=UDim2.fromOffset(24,short and 106 or 130)
 rows.Size=UDim2.new(1,-48,1,short and -142 or -168)
 body.Status.Position=UDim2.new(0,30,1,-33)
 for _,r in rows:GetChildren() do
  if r:IsA('Frame') then
   local codes=r.Name=='Codes';local sliderRow=r:FindFirstChild('Track')~=nil
   local tall=narrow and (codes and 132 or sliderRow and 132 or r.Name=='Quality' and 132 or 86) or 78
   r.Size=UDim2.new(1,-9,0,tall)
   r.IconPlate.Position=UDim2.fromOffset(12,8)
   r.IconPlate.Size=UDim2.fromOffset(62,62)
   local title=r:FindFirstChild('Name')
   title.Position=UDim2.fromOffset(93,10)
   title.Size=UDim2.new(narrow and 1 or 0,narrow and -104 or 410,0,29)
   title.TextSize=narrow and 19 or 23
   if r:FindFirstChild('Description') then
    r.Description.Position=UDim2.fromOffset(94,43)
    r.Description.Size=UDim2.new(narrow and 1 or 0,narrow and -104 or 420,0,22)
    r.Description.TextSize=narrow and 13 or 16
   end
   if r:FindFirstChild('Track') then
    local track=r.Track
    track.Position=narrow and UDim2.fromOffset(94,77) or UDim2.new(1,r.Name=='Music' and -570 or r.Name=='Shake' and -565 or r.Name=='SFX' and -465 or -440,0,12)
    track.Size=narrow and UDim2.new(1,r.Name=='Music' and -290 or r.Name=='SFX' and -225 or r.Name=='Shake' and -300 or -170,0,38) or UDim2.fromOffset(r.Name=='Music' and 285 or r.Name=='Shake' and 250 or 290,54)
    r.Percent.Position=narrow and UDim2.new(1,r.Name=='Music' and -188 or r.Name=='SFX' and -117 or r.Name=='Shake' and -207 or -78,0,79) or UDim2.new(1,r.Name=='Music' and -273 or r.Name=='Shake' and -303 or r.Name=='SFX' and -167 or -129,0,24)
    r.Percent.Size=UDim2.fromOffset(69,29)
   end
   if r:FindFirstChild('Toggle') then
    r.Toggle.AnchorPoint=Vector2.zero
    r.Toggle.Position=narrow and UDim2.new(1,-170,0,r.Name=='Shake' and 72 or 16) or UDim2.new(1,-180,0,15)
    r.Toggle.Size=UDim2.fromOffset(159,48)
   end
   if r.Name=='Music' then
    r.Mute.Position=narrow and UDim2.new(1,-178,0,76) or UDim2.new(1,-207,0,17)
    r.Mute.Size=UDim2.fromOffset(narrow and 78 or 94,42)
    r.Next.Position=narrow and UDim2.new(1,-92,0,76) or UDim2.new(1,-103,0,17)
    r.Next.Size=UDim2.fromOffset(narrow and 82 or 92,42)
   elseif r.Name=='SFX' then
    r.Mute.Position=narrow and UDim2.new(1,-102,0,76) or UDim2.new(1,-103,0,17)
    r.Mute.Size=UDim2.fromOffset(91,42)
   elseif r.Name=='Quality' then
    for i,name in {'LOW','MEDIUM','HIGH','ULTRA'} do
     local b=r[name]
     b.Position=narrow and UDim2.new((i-1)*.25,7,0,80) or UDim2.new(1,-625+(i-1)*151,0,15)
     b.Size=narrow and UDim2.new(.25,-14,0,43) or UDim2.fromOffset(143,48)
    end
   elseif codes then
    r.CodeBox.Position=narrow and UDim2.fromOffset(94,77) or UDim2.new(1,-630,0,16)
    r.CodeBox.Size=narrow and UDim2.new(1,-260,0,43) or UDim2.fromOffset(430,45)
    r.Redeem.AnchorPoint=Vector2.zero
    r.Redeem.Position=narrow and UDim2.new(1,-154,0,77) or UDim2.new(1,-181,0,16)
    r.Redeem.Size=UDim2.fromOffset(narrow and 143 or 165,45)
   end
  end
 end
end
task.defer(layout)
root:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() task.defer(layout) end)
local function bindCamera()
 local camera=workspace.CurrentCamera
 if camera then camera:GetPropertyChangedSignal('ViewportSize'):Connect(function() task.defer(layout) end) end
end
workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(bindCamera)
bindCamera()

root:GetPropertyChangedSignal("Visible"):Connect(function()
 if root.Visible then rows.CanvasPosition=Vector2.zero; task.delay(.3,function() if root.Visible then rows.CanvasPosition=Vector2.zero end end) end
end)

