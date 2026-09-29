-- Local, distance-gated forge atmosphere. No server heartbeat or gameplay changes.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local forge=workspace:WaitForChild("TraitForge")
local decor=forge:WaitForChild("MythicalForge")
local energy=decor:WaitForChild("ForgeEnergy")
local light=energy:WaitForChild("ForgeLight")
local emitter=energy:WaitForChild("EmberOrigin"):WaitForChild("ForgeEmbers")
local shards={}
for _,p in decor:GetChildren() do
 if p:IsA("BasePart") and p:GetAttribute("ForgeFloat") then
  local veins={}
  for _,v in decor:GetChildren() do
   if v:IsA("BasePart") and v:GetAttribute("FloatOwner")==p.Name then
    table.insert(veins,{part=v,offset=p.CFrame:ToObjectSpace(v.CFrame)})
   end
  end
  table.insert(shards,{part=p,base=p.CFrame,veins=veins,phase=#shards*1.1})
 end
end
local elapsed,accumulator=0,0
local connection
connection=RunService.Heartbeat:Connect(function(dt)
 accumulator+=dt
 if accumulator<1/30 then return end
 local step=accumulator;accumulator=0
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local nearby=root and (root.Position-energy.Position).Magnitude<75
 local reduced=player:GetAttribute("ReducedMotion")==true
 emitter.Enabled=nearby==true and not reduced
 light.Enabled=nearby==true
 if not nearby then return end
 elapsed+=step
 light.Brightness=reduced and 1 or 1.1+math.sin(elapsed*1.6)*.15
 for _,s in shards do
  if s.part.Parent then
   local cf=s.base
   if not reduced then cf=CFrame.new(0,math.sin(elapsed*.9+s.phase)*.16,0)*s.base*CFrame.Angles(0,math.sin(elapsed*.32+s.phase)*.12,math.sin(elapsed*.5+s.phase)*.045) end
   s.part.CFrame=cf
   for _,v in s.veins do if v.part.Parent then v.part.CFrame=cf*v.offset end end
  end
 end
end)
script.Destroying:Connect(function() connection:Disconnect() end)

