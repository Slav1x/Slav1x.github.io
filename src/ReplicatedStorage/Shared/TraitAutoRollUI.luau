local UI={}
local ink=Color3.fromRGB(12,25,23)
local gold=Color3.fromRGB(235,191,103)
local cream=Color3.fromRGB(255,248,226)
local green=Color3.fromRGB(35,151,99)
function UI.new(panel,traits,callbacks)
 local function round(p,r)local c=Instance.new("UICorner",p);c.CornerRadius=UDim.new(0,r)end
 local function outline(p,color)local s=Instance.new("UIStroke",p);s.Color=color;s.Thickness=1.5;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;return s end
 local function label(p,name,value,pos,size,fontSize,color)
  local l=Instance.new("TextLabel");l.Name=name;l.Text=value;l.Position=pos;l.Size=size
  l.BackgroundTransparency=1;l.TextColor3=color or cream;l.TextSize=fontSize;l.Font=Enum.Font.FredokaOne
  l.TextWrapped=true;l.ZIndex=p.ZIndex+1;l.Parent=p;return l
 end
 local function button(p,name,value,pos,size,color)
  local b=Instance.new("TextButton");b.Name=name;b.Text=value;b.Position=pos;b.Size=size;b.BackgroundColor3=color
  b.BorderSizePixel=0;b.AutoButtonColor=true;b.TextColor3=cream;b.TextSize=16;b.Font=Enum.Font.FredokaOne
  b.ZIndex=p.ZIndex+1;b.Parent=p;round(b,10);outline(b,Color3.fromRGB(78,140,108));return b
 end
 panel.Title.Size=UDim2.fromOffset(244,36);panel.Title.TextSize=25
 panel.OddsToggle.Position=UDim2.fromOffset(420,18);panel.OddsToggle.Size=UDim2.fromOffset(109,34)
 panel.OddsToggle.Text="ODDS"
 local toggle=button(panel,"AutoToggle","AUTO",UDim2.fromOffset(312,18),UDim2.fromOffset(96,34),Color3.fromRGB(35,114,82))
 toggle.ZIndex=9
 local page=Instance.new("TextButton");page.Name="AutoRollPage";page.Text="";page.AutoButtonColor=false
 page.Position=UDim2.fromOffset(18,78);page.Size=UDim2.fromOffset(564,329);page.BorderSizePixel=0
 page.BackgroundColor3=Color3.fromRGB(19,46,34);page.ZIndex=20;page.Visible=false;page.Parent=panel
 round(page,16);outline(page,gold)
 label(page,"Title","AUTO-ROLL TARGET",UDim2.fromOffset(18,12),UDim2.fromOffset(410,27),24,gold)
 local back=button(page,"Back","BACK",UDim2.fromOffset(464,12),UDim2.fromOffset(82,28),Color3.fromRGB(36,84,61))
 local rarityTab=button(page,"RarityMode","RARITY",UDim2.fromOffset(18,48),UDim2.fromOffset(258,32),green)
 local traitTab=button(page,"TraitMode","EXACT TRAIT",UDim2.fromOffset(288,48),UDim2.fromOffset(258,32),ink)
 local list=Instance.new("ScrollingFrame");list.Name="Targets";list.Position=UDim2.fromOffset(18,90);list.Size=UDim2.fromOffset(528,144)
 list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=4;list.ScrollBarImageColor3=gold
 list.ScrollingDirection=Enum.ScrollingDirection.Y;list.ZIndex=21;list.Parent=page
 local status=label(page,"Selection","Choose a target",UDim2.fromOffset(18,238),UDim2.fromOffset(528,20),15,cream)
 local start=button(page,"Start","START AUTO-ROLL",UDim2.fromOffset(18,267),UDim2.fromOffset(528,45),green)
 local mode="rarity";local selected=nil;local running=false;local choices={}
 local controller={}
 local function refresh()
  rarityTab.BackgroundColor3=mode=="rarity" and green or ink
  traitTab.BackgroundColor3=mode=="trait" and green or ink
  for _,row in choices do
   local picked=selected and selected.kind==mode and selected.value==row.value
   row.button.BackgroundColor3=picked and Color3.fromRGB(63,106,67) or ink
   row.border.Color=picked and gold or Color3.fromRGB(64,109,80)
  end
  status.Text=(selected and string.upper(selected.label) or "Choose a target").." • "..traits.RollCost.." shards each • stops when empty"
  start.Text=selected and "START AUTO-ROLL" or "CHOOSE A TARGET"
  start.BackgroundColor3=selected and green or Color3.fromRGB(57,74,62)
  start.Active=selected~=nil;start.Selectable=selected~=nil
 end
 local function render()
  for _,v in list:GetChildren()do if v:IsA("GuiObject")then v:Destroy()end end
  table.clear(choices)
  local options={}
  if mode=="rarity" then
   for _,rarity in traits.RarityOrder do table.insert(options,{value=rarity,label=rarity,enabled=traits.rarityChancePercent(rarity)>0})end
  else
   for _,trait in traits.Results do table.insert(options,{value=trait.id,label=trait.label,enabled=traits.chancePercent(trait.id)>0})end
  end
  for i,option in options do
   local b=button(list,"Target"..i,option.label..(option.enabled and "" or " · unavailable"),
    UDim2.fromOffset(((i-1)%2)*266,math.floor((i-1)/2)*42),UDim2.fromOffset(256,36),ink)
   b.TextSize=15;b:SetAttribute("TargetValue",option.value);b:SetAttribute("Available",option.enabled)
   b.Active=option.enabled;b.Selectable=option.enabled;b.AutoButtonColor=option.enabled
   if not option.enabled then b.TextColor3=Color3.fromRGB(131,148,134)end
   table.insert(choices,{button=b,border=b:FindFirstChildWhichIsA("UIStroke"),value=option.value})
   b.Activated:Connect(function()
    if not option.enabled then return end
    selected={kind=mode,value=option.value,label=option.label};refresh()
   end)
  end
  list.CanvasSize=UDim2.fromOffset(0,math.ceil(#options/2)*42);list.CanvasPosition=Vector2.zero
  refresh()
 end
 rarityTab.Activated:Connect(function()if mode~="rarity" then selected=nil end;mode="rarity";render()end)
 traitTab.Activated:Connect(function()if mode~="trait" then selected=nil end;mode="trait";render()end)
 back.Activated:Connect(callbacks.back)
 toggle.Activated:Connect(callbacks.toggle)
 start.Activated:Connect(function()if selected and not running then callbacks.start(table.clone(selected))end end)
 function controller:setVisible(visible)page.Visible=visible;if visible then refresh()end end
 function controller:setRunning(value)
  running=value;toggle.Text=value and "STOP" or "AUTO"
  toggle.BackgroundColor3=value and Color3.fromRGB(137,80,44) or Color3.fromRGB(35,114,82)
 end
 function controller:hide()page.Visible=false end
 render()
 return controller
end
return UI
