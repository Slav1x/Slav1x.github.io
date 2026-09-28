
-- Pooled, art-only VFX. No instances/tweens are created inside the animation loop.
local RunService=game:GetService("RunService")
local shop=script.Parent
local page=shop.Shell.Content.SpecialPetsPage
local scroll=page.GridScroll
local entries={}
for _,card in scroll:GetChildren() do
 if card:IsA("Frame") and card:FindFirstChild("Artwork") then
  local effects={}
  for _,v in card.Artwork:GetDescendants() do
   if v:GetAttribute("FXKind") then table.insert(effects,v) end
  end
  table.insert(entries,{card=card,effects=effects,hover=false})
  local entry=entries[#entries]
  card.MouseEnter:Connect(function() entry.hover=true end)
  card.MouseLeave:Connect(function() entry.hover=false end)
 end
end
local time=0 local elapsed=0
local connection
connection=RunService.RenderStepped:Connect(function(dt)
 if not shop.Visible or not page.Visible or page.GroupTransparency>.95 then return end
 elapsed+=dt
 if elapsed<1/30 then return end
 time+=elapsed elapsed=0
 local top=scroll.AbsolutePosition.Y local bottom=top+scroll.AbsoluteSize.Y
 for _,entry in entries do
  local card=entry.card
  if card.AbsolutePosition.Y+card.AbsoluteSize.Y>=top and card.AbsolutePosition.Y<=bottom then
   local speed=card:GetAttribute("VFXSpeed") or 1
   local strength=entry.hover and 1.25 or 1
   for _,v in entry.effects do
    local i=v:GetAttribute("FXIndex") local kind=v:GetAttribute("FXKind")
    local phase=(time*speed/(v:GetAttribute("Lifetime") or 3)+i*.137)%1
    local wave=math.sin(time*speed*2+i*1.8)
    if kind=="Flame" then
     local x=v:GetAttribute("HomeX") local y=v:GetAttribute("HomeY")
     v.Position=UDim2.fromScale(x+math.sin(time*2.8+i)*.012,y+.30-phase*.50)
     v.Size=UDim2.fromScale((.16+.09*(1-phase))*strength,(.24+.14*(1-phase))*strength)
     v.Rotation=math.sin(time*2+i)*8
     v.GroupTransparency=1-math.sin(phase*math.pi)*(.65+(entry.hover and .12 or 0))
    elseif kind=="Ember" then
     local x=.15+((i*37)%70)/100
     v.Position=UDim2.fromScale(x+math.sin(phase*5+i)*.07,.93-phase*.89)
     v.BackgroundTransparency=1-math.sin(phase*math.pi)*.85
     v.Rotation=45+phase*110
    elseif kind=="Leaf" then
     v.Position=UDim2.fromScale(.13+((i*29)%74)/100+math.sin(phase*6+i)*.065,.92-phase*.82)
     v.Rotation=phase*120+i*41
     v.BackgroundTransparency=1-math.sin(phase*math.pi)*.72
    elseif kind=="Rune" then
     local angle=time*speed*.48+i*math.pi/4
     v.Position=UDim2.fromScale(.5+math.cos(angle)*.37,.52+math.sin(angle)*.33)
     v.Rotation=45+time*12
     v.BackgroundTransparency=.26+.25*(1+math.sin(angle))
    elseif kind=="Wisp" then
     local angle=-time*speed*.32+i*math.pi
     v.Position=UDim2.fromScale(.5+math.cos(angle)*.30,.54+math.sin(angle)*.30)
     v.ImageTransparency=.72+.10*wave
     v.Rotation=time*15+i*90
    elseif kind=="Bubble" then
     v.Position=UDim2.fromScale(.12+((i*31)%76)/100+math.sin(phase*5+i)*.04,.97-phase*.94)
     v.Outline.Transparency=1-math.sin(phase*math.pi)*.65
    elseif kind=="Ripple" then
     v.Size=UDim2.fromScale(.25+phase*.62,.07+phase*.15)
     v.Outline.Transparency=.50+phase*.50
    end
   end
  end
 end
end)
script.Destroying:Connect(function() if connection then connection:Disconnect() end end)

