local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=player:WaitForChild("PlayerGui"):WaitForChild("SummonPromptUI")
local root=player.PlayerGui:WaitForChild("SummonWorldUI"):WaitForChild("SummonActions"):WaitForChild("PromptRoot")
local station=workspace:WaitForChild("terrain"):WaitForChild("SpinButton")
local Zones=require(ReplicatedStorage.Shared:WaitForChild("ZoneConfig"))
local Catalog=require(ReplicatedStorage.Shared:WaitForChild("RockCatalog"))
local models=ReplicatedStorage:WaitForChild("RockModels")
local display=Instance.new("Folder")
display.Name="FloatingSummonRocks"
local entries={}
local connections={}
local visible=false
local animationTime=0
local revealProgress=0
local FADE_IN_SECONDS=.55
local FADE_OUT_SECONDS=.4
local fadeProperties={}
local function rememberFade(instance,property)
 table.insert(fadeProperties,{instance=instance,property=property,base=instance[property]})
 instance[property]=1
end
local selectedId=nil
local total=100
local ORBIT_SECONDS=18
local ORBIT_RADIUS=10
local ORBIT_HEIGHT=7.2

local function label(parent,name,text,y,height,color,size)
 local textLabel=Instance.new("TextLabel")
 textLabel.Name=name
 textLabel.BackgroundTransparency=1
 textLabel.Position=UDim2.fromScale(0,y)
 textLabel.Size=UDim2.fromScale(1,height)
 textLabel.Font=Enum.Font.FredokaOne
 textLabel.Text=text
 textLabel.TextColor3=color
 textLabel.TextSize=size
 textLabel.TextStrokeColor3=Color3.fromRGB(10,15,25)
 textLabel.TextStrokeTransparency=.15
 textLabel.Parent=parent
 return textLabel
end

local function rebuild()
 local id=player:GetAttribute("SelectedSummonCollection") or "driftwood"
 local zone=Zones.ById[id] or Zones.List[1]
 if selectedId==zone.id then return end
 selectedId=zone.id
 -- Swap one complete ring. No outgoing models or delayed build tasks can stack.
 local old=display
 display=Instance.new("Folder");display.Name="FloatingSummonRocks"
 display:SetAttribute("AreaId",zone.id)
 entries={};fadeProperties={}
 total=0
 for _,entry in ipairs(zone.pool) do total+=entry.weight end
 ORBIT_RADIUS=math.max(10,#zone.pool*5.6/(2*math.pi))
 for i,entry in ipairs(zone.pool) do

 local source=models:FindFirstChild(entry.id)
 if not source then warn("Missing summon preview model: "..entry.id);continue end
 local rock=Catalog.get(entry.id)
 local color=Catalog.RarityColors[rock.rarity] or Color3.new(1,1,1)
 local model=source:Clone()
 model.Name=entry.id
 -- Previews are cosmetic and cannot collide with players or run cloned scripts.
 for _,item in model:GetDescendants() do
  if item:IsA("BaseScript") or item:IsA("ModuleScript") then
   item:Destroy()
  elseif item:IsA("BasePart") then
   item.Anchored=true
   item.CanCollide=false
   item.CanTouch=false
   item.CanQuery=false
   item.CastShadow=false
  end
 end
 local extent=model:GetExtentsSize()
 model:ScaleTo(model:GetScale()*2.5/math.max(extent.X,extent.Y,extent.Z,.01))
 local bounds=model:GetBoundingBox()
 local center=model:GetPivot():ToObjectSpace(bounds)
 model.Parent=display
 local glow=Instance.new("Highlight")
 glow.Name="RarityGlow"
 glow.Adornee=model
 glow.DepthMode=Enum.HighlightDepthMode.Occluded
 glow.FillColor=color
 glow.FillTransparency=.9
 glow.OutlineColor=color
 glow.OutlineTransparency=.35
 glow.Parent=model

 local anchor=Instance.new("Part")
 anchor.Name=entry.id.."OddsAnchor"
 anchor.Size=Vector3.new(.1,.1,.1)
 anchor.Transparency=1
 anchor.Anchored=true
 anchor.CanCollide=false
 anchor.CanTouch=false
 anchor.CanQuery=false
 anchor.Parent=display
 local board=Instance.new("BillboardGui")
 board.Name="RockOdds"
 board.Adornee=anchor
 board.Size=UDim2.fromScale(4.8,1.8)
 board.AlwaysOnTop=true
 board.MaxDistance=65
 board.LightInfluence=0
 board.Parent=anchor
 label(board,"Probability",string.format("%.2f%%",entry.weight/total*100),0,.42,color,24)
 label(board,"RockName",rock.name,.43,.31,Color3.fromRGB(240,247,255),14)
 label(board,"Rarity",string.upper(rock.rarity),.75,.23,color,10)
 table.insert(entries,{model=model,anchor=anchor,center=center,index=i})
end

-- Cache the original look so transparent materials retain their finish.
for _,item in display:GetDescendants() do
 if item:IsA("BasePart") or item:IsA("Decal") or item:IsA("Texture") then
  rememberFade(item,"Transparency")
 elseif item:IsA("Highlight") then
  rememberFade(item,"FillTransparency")
  rememberFade(item,"OutlineTransparency")
 elseif item:IsA("TextLabel") then
  rememberFade(item,"TextTransparency")
  rememberFade(item,"TextStrokeTransparency")
 end
end

 old:Destroy()
end

local function refresh()
 local nextVisible=root:GetAttribute("PromptActive")==true
 if visible==nextVisible then return end
 visible=nextVisible
 -- RenderStepped finishes the fade before removing the display.
 -- Keeping the current progress also makes quick direction changes smooth.
end

table.insert(connections,root:GetAttributeChangedSignal("PromptActive"):Connect(refresh))
table.insert(connections,player:GetAttributeChangedSignal("SelectedSummonCollection"):Connect(rebuild))
table.insert(connections,RunService.RenderStepped:Connect(function(dt)
 if not visible and revealProgress==0 then return end
 local reduced=player:GetAttribute("ReducedMotion")==true
 local duration=visible and FADE_IN_SECONDS or FADE_OUT_SECONDS
 revealProgress=math.clamp(revealProgress+(visible and 1 or -1)*dt/duration,0,1)
 local opacity=root:GetAttribute("PromptOpacity") or revealProgress*revealProgress*(3-2*revealProgress)
 for _,fade in fadeProperties do
  fade.instance[fade.property]=1-(1-fade.base)*opacity
 end
 if not reduced then animationTime+=dt end
 local age=animationTime
 local enter=reduced and 1 or opacity
 -- Every summon reward shares a world-space ring, independent of the camera.
 local orbit=reduced and 0 or age*(2*math.pi/ORBIT_SECONDS)
 for _,entry in entries do
  local i=entry.index
  local angle=(i-1)*(2*math.pi/#entries)+orbit
  local hover=reduced and 0 or math.sin(age*1.7+i*.8)*.22
  local position=station.Position+Vector3.new(
   math.cos(angle)*ORBIT_RADIUS,
   ORBIT_HEIGHT+hover-(1-enter)*.6,
   math.sin(angle)*ORBIT_RADIUS
  )
  local spin=reduced and .35 or age*.4+i*.6
  entry.model:PivotTo(CFrame.new(position)*CFrame.Angles(math.rad(25),spin,math.rad(12))*entry.center:Inverse())
  entry.anchor.Position=position+Vector3.new(0,2,0)
 end
 -- Position and fade everything before parenting to avoid a one-frame flash.
 display.Parent=revealProgress>0 and workspace or nil
end))
local cleaned=false
local function cleanup()
 if cleaned then return end
 cleaned=true
 for _,connection in connections do connection:Disconnect() end
 display:Destroy()
end
gui.Destroying:Connect(cleanup)
script.Destroying:Connect(cleanup)
rebuild()
refresh()
