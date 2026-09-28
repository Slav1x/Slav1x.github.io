-- One upcoming marker and a brief arrival card; neither awards progression.
local player=game.Players.LocalPlayer
local Zones=require(game.ReplicatedStorage.Shared.ZoneConfig)
local Run=game:GetService('RunService')
local markers=workspace:WaitForChild('ZoneMarkers')
local host=player:WaitForChild('PlayerGui'):WaitForChild('ProgressionFeedback',30)
local arrival,title,subtitle,stroke
if host then
 arrival=Instance.new('CanvasGroup');arrival.Name='AreaArrival';arrival.AnchorPoint=Vector2.new(1,0);arrival.Position=UDim2.new(1,-14,0,64);arrival.Size=UDim2.fromOffset(260,54);arrival.BackgroundColor3=Color3.fromRGB(21,43,58);arrival.BackgroundTransparency=.14;arrival.BorderSizePixel=0;arrival.GroupTransparency=1;arrival.Visible=false;arrival.Parent=host
 local corner=Instance.new('UICorner',arrival);corner.CornerRadius=UDim.new(0,9)
 stroke=Instance.new('UIStroke',arrival);stroke.Thickness=1;stroke.Transparency=.35
 title=Instance.new('TextLabel',arrival);title.Name='AreaName';title.Size=UDim2.new(1,-24,0,24);title.Position=UDim2.fromOffset(12,5);title.BackgroundTransparency=1;title.Font=Enum.Font.GothamSemibold;title.TextSize=17;title.TextXAlignment=Enum.TextXAlignment.Left
 subtitle=Instance.new('TextLabel',arrival);subtitle.Name='AreaDetail';subtitle.Size=UDim2.new(1,-24,0,16);subtitle.Position=UDim2.fromOffset(12,29);subtitle.BackgroundTransparency=1;subtitle.Font=Enum.Font.Gotham;subtitle.TextSize=11;subtitle.TextColor3=Color3.fromRGB(226,235,242);subtitle.TextXAlignment=Enum.TextXAlignment.Left
end
local descriptions={candy='Frosted islands · sugarspun gardens',frozen='Glacial arches · drifting ice',toxic='Corroded towers · glowing runoff',driftwood='Bright shallows · woodland banks',blossom='Petal gardens · a calm current',sunscorch='Sunlit mesas · an oasis passage',inferno='Warm caldera · flowing magma',cosmic='Celestial banks · an astral current'}
local openedAt=-math.huge
local visited={}
local wasFlying=false
for _,anchor in markers:GetChildren() do
 local gui=anchor:FindFirstChild('ZoneName')
 if gui then gui.Size=UDim2.fromOffset(266,47);gui.AlwaysOnTop=false;gui.MaxDistance=480;gui.Enabled=false end
end
local elapsed=0
local connection=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.1 then return end;elapsed=0
 local cam=workspace.CurrentCamera;if not cam then return end
 local distance=Zones.distanceAt(cam.CFrame.Position)
 local flying=player:GetAttribute('RockInFlight')==true
 if flying and not wasFlying then visited={driftwood=true} end
 if not flying and wasFlying then openedAt=-math.huge end
 wasFlying=flying
 local zone=Zones.forDistance(distance)
 if flying and not visited[zone.id] and distance>zone.start+12 then
  visited[zone.id]=true
  if arrival then
   openedAt=os.clock();arrival:SetAttribute("ShownUntil",openedAt+3);title.Text=zone.name;title.TextColor3=zone.color;stroke.Color=zone.color
   subtitle.Text=descriptions[zone.id] or zone.landmark;arrival.Visible=true
  end
 end
 if arrival then
  local age=os.clock()-openedAt
  local visibility=math.min(math.clamp(age/.32,0,1),math.clamp((3.0-age)/.4,0,1))
  arrival.GroupTransparency=1-visibility;arrival.Visible=visibility>0
  local event=host:FindFirstChild("EnvironmentalEvent");if arrival.Visible and event then event.Visible=false end
  -- Keep the central skip counter, distance and water clear. On narrow
  -- screens use a smaller side card below the flight HUD's top block.
  local narrow=cam.ViewportSize.X<900
  arrival.Position=UDim2.new(1,-14,0,narrow and 174 or 64)
  arrival.Size=UDim2.fromOffset(math.min(narrow and 220 or 260,cam.ViewportSize.X-28),54)
  if host:GetAttribute('ArrivalDiscoveryName')==zone.name and os.clock()-(host:GetAttribute('ArrivalDiscoveryAt') or -math.huge)<8 then
   subtitle.Text='New rock collection unlocked'
  end
 end
 local nextZone=Zones.next(distance)
 for i=2,#Zones.List do
  local entry=Zones.List[i]
  local anchor=markers:FindFirstChild(entry.id)
  local preview=markers:FindFirstChild(entry.id..'Preview')
  local vista=markers:FindFirstChild('StartVista_'..entry.id)
  if anchor then
   local gui=anchor:FindFirstChild('ZoneName')
   if gui then
    local remaining=entry.start-distance
    gui.Enabled=nextZone==entry and remaining>95 and remaining<420 and math.abs(cam.CFrame.Position.Z+40.5)<340
    local label=gui:FindFirstChild('NextDistance',true)
    if label then label.Text='AHEAD  ·  '..(math.ceil(math.max(0,remaining)/5)*5)..' STUDS' end
   end
  end
  for _,old in {preview,vista} do if old then local gui=old:FindFirstChild('ZoneName');if gui then gui.Enabled=false end end end
 end
end)
script.Destroying:Connect(function() connection:Disconnect();if arrival then arrival:Destroy() end end)

