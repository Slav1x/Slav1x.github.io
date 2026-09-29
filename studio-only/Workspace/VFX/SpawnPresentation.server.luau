
-- All added behavior is local presentation or opening existing UI.
local root=script.Parent.Parent
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local PromptService=game:GetService("ProximityPromptService")
local player=Players.LocalPlayer
local rock=root:WaitForChild("Buildings"):WaitForChild("FloatingRockFountain"):WaitForChild("FloatingRock")
local rest=rock:GetAttribute("RestPivot") or rock:GetPivot()
local emitters,lights={},{}
for _,v in rock.Parent:GetDescendants() do
 if v:IsA("ParticleEmitter") then table.insert(emitters,v)
 elseif v:IsA("PointLight") then table.insert(lights,v) end
end
local elapsed,slow=0,0
local frameConnection
frameConnection=Run.Heartbeat:Connect(function(dt)
 if root ~= workspace and not root:IsDescendantOf(workspace) then frameConnection:Disconnect();return end
 elapsed+=dt;slow+=dt
 local camera=workspace.CurrentCamera
 if not camera then return end
 local reduced=player:GetAttribute("ReducedMotion")==true
 if rock.Parent and (camera.CFrame.Position-rest.Position).Magnitude<220 then
  if reduced then rock:PivotTo(rest)
  else rock:PivotTo(rest*CFrame.new(0,math.sin(elapsed*.75)*.6,0)*CFrame.Angles(0,elapsed*.10,0)) end
 end
 if slow<.3 then return end;slow=0
 local nearby={}
 for _,e in emitters do
  local p=e.Parent
  if p then
   local pos=p:IsA("Attachment") and p.WorldPosition or (p:IsA("BasePart") and p.Position)
   local distance=pos and (pos-camera.CFrame.Position).Magnitude or math.huge
   e.Enabled=false
   if distance<130 and not reduced then table.insert(nearby,{e=e,d=distance}) end
  end
 end
 table.sort(nearby,function(a,b)return a.d<b.d end)
 for i=1,math.min(18,#nearby) do nearby[i].e.Enabled=true end
 for _,l in lights do
  local p=l.Parent
  if p and p:IsA("BasePart") then l.Enabled=(p.Position-camera.CFrame.Position).Magnitude<110 end
 end
end)
local promptConnection=PromptService.PromptTriggered:Connect(function(prompt,who)
 if who and who~=player then return end
 if not prompt:IsDescendantOf(root) then return end
 local menu=prompt:GetAttribute("ExistingMenu")
 if menu~="shop" and menu~="upgrades" then return end
 local pg=player:FindFirstChildOfClass("PlayerGui");local hud=pg and pg:FindFirstChild("MainHUD")
 local open=hud and hud:FindFirstChild("OpenMenu")
 if open and open:IsA("BindableEvent") then
  local sectionName=prompt:GetAttribute("ExistingShopSection")
  if menu=="shop" and sectionName=="SpecialPetsSection" then
   local panel=hud:FindFirstChild("shopui")
   if not panel or not panel.Visible then open:Fire(menu) end
   task.delay(.25,function()
    if not panel or not panel.Parent or not panel.Visible then return end
    local shell=panel:FindFirstChild("Shell")
    local content=shell and shell:FindFirstChild("Content")
    local storefront=content and content:FindFirstChild("Storefront")
    local section=storefront and storefront:FindFirstChild(sectionName)
    if storefront and storefront:IsA("ScrollingFrame") and section then
     local y=section.AbsolutePosition.Y-storefront.AbsolutePosition.Y+storefront.CanvasPosition.Y-8
     storefront.CanvasPosition=Vector2.new(0,math.max(0,y))
    end
   end)
  else open:Fire(menu) end
 end
end)
script.Destroying:Connect(function()
 if frameConnection then frameConnection:Disconnect() end
 promptConnection:Disconnect()
end)

