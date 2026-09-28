-- Pooled per-card decorations. One 30 Hz update; no per-frame instances or tweens.
local Run=game:GetService("RunService")
local shop=script.Parent
local player=game.Players.LocalPlayer
local entries={}
-- Falling/background icons are an intentional Gamepasses-only visual.
-- Other Shop pages use static weld/checker texture layers instead.
local gamepasses=shop.Shell.Content.GamepassesPage
for _,layer in gamepasses:GetDescendants() do
 if layer.Name=="CardAtmosphere" then
  local icons={}
  for _,im in layer:GetChildren() do if im:IsA("ImageLabel") then table.insert(icons,im) end end
  table.insert(entries,{layer=layer,icons=icons,time=0})
 end
end
local elapsed=0
local connection=Run.Heartbeat:Connect(function(dt)
 if not shop.Visible then return end
 elapsed+=dt if elapsed<1/30 then return end
 local step=elapsed elapsed=0
 for _,entry in entries do
  local visible=true local p=entry.layer
  while p and p~=shop do
   if p:IsA("GuiObject") and not p.Visible then visible=false break end
   if p:IsA("ScrollingFrame") then
    local a=entry.layer.AbsolutePosition local b=entry.layer.AbsoluteSize
    if a.Y+b.Y<p.AbsolutePosition.Y or a.Y>p.AbsolutePosition.Y+p.AbsoluteSize.Y then visible=false break end
   end
   p=p.Parent
  end
  if visible then
   if not player:GetAttribute("ReducedMotion") then entry.time+=step end
   for i,im in entry.icons do
    local phase=(entry.time/im:GetAttribute("Duration")+im:GetAttribute("Phase"))%1
    im.Position=UDim2.fromScale(im:GetAttribute("Lane")+math.sin(phase*math.pi*2+i)*.045,-.18+phase*1.36)
    im.ImageTransparency=1-.22*math.sin(math.pi*phase)^.7
    im.Rotation=-18+phase*36
   end
  end
 end
end)
script.Destroying:Connect(function() connection:Disconnect() end)

