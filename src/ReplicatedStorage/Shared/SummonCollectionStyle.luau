--!nonstrict
local Style={}
local UI=require(script.Parent.SummonUIStyle)
local ink=Color3.fromRGB(12,19,30)
local function label(parent,name)
 local item=parent:FindFirstChild(name)
 if not item then item=Instance.new("TextLabel");item.Name=name;item.Parent=parent end
 item.BackgroundTransparency=1;item.BorderSizePixel=0;item.ZIndex=8
 return item
end
local function buttonSkin(button)
 button.BorderSizePixel=0;button.BackgroundColor3=Color3.fromRGB(28,91,121)
 button.AutoButtonColor=true;button.ZIndex=8
 local round=button:FindFirstChildWhichIsA("UICorner") or Instance.new("UICorner",button)
 round.CornerRadius=UDim.new(0,10)
 local rim=button:FindFirstChildWhichIsA("UIStroke") or Instance.new("UIStroke",button)
 rim.Color=ink;rim.Thickness=2;rim.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 UI.stationText(button,24)
end
function Style.mount(panel)
 if panel:GetAttribute("StationCollectionStyle")==2 then return end
 panel:SetAttribute("StationCollectionStyle",2)
 panel.Size=UDim2.fromOffset(410,330);panel.AnchorPoint=Vector2.zero;panel.ClipsDescendants=false
 local constraint=panel:FindFirstChildWhichIsA("UISizeConstraint")
 if constraint then constraint.MinSize=Vector2.zero;constraint.MaxSize=Vector2.new(410,330) end
 UI.stationCard(panel,Color3.fromRGB(70,190,228))
 panel.CandySpark.Visible=false
 local eyebrow=label(panel,"Eyebrow");eyebrow.Text="AREA COLLECTIONS"
 eyebrow.Position=UDim2.fromOffset(64,9);eyebrow.Size=UDim2.new(1,-128,0,16);UI.stationText(eyebrow,11)
 local title=panel.ZoneTitle;title.Position=UDim2.fromOffset(64,28);title.Size=UDim2.new(1,-128,0,25)
 UI.stationText(title,21)
 local status=panel.ZoneStatus;status.Position=UDim2.fromOffset(12,59);status.Size=UDim2.new(1,-24,0,17)
 UI.stationText(status,12)
 for _,name in {"Previous","Next"} do
  local b=panel[name];buttonSkin(b);b.Size=UDim2.fromOffset(42,42)
  b.Position=if name=="Previous" then UDim2.fromOffset(12,17) else UDim2.new(1,-54,0,17)
 end
 local cards=panel.RockCards;cards.BackgroundTransparency=1;cards.Position=UDim2.fromOffset(12,82)
 cards.Size=UDim2.new(1,-24,0,190);cards.ZIndex=5;cards.ClipsDescendants=false
 for i=1,6 do
  local card=cards["Card"..i]
  card.Size=UDim2.new(1/3,-6,0,91)
  card.Position=UDim2.new(((i-1)%3)/3,3,0,math.floor((i-1)/3)*98)
  UI.stationCard(card,Color3.fromRGB(98,165,202))
  card.CandySpark.Visible=false;card.CandyShadow.Position=UDim2.fromOffset(0,4)
  card.RockImage.Position=UDim2.new(.5,-21,0,3);card.RockImage.Size=UDim2.fromOffset(42,42);card.RockImage.ZIndex=6
  card.RockName.Position=UDim2.new(0,5,0,46);card.RockName.Size=UDim2.new(1,-10,0,26);UI.stationText(card.RockName,13)
  card.Odds.Position=UDim2.new(0,5,0,74);card.Odds.Size=UDim2.new(1,-10,0,14);UI.stationText(card.Odds,11)
 end
 local select=panel:FindFirstChild("SelectCollection") or Instance.new("TextButton")
 select.Name="SelectCollection";select.Parent=panel
 select.Position=UDim2.fromOffset(12,280);select.Size=UDim2.new(1,-24,0,29);buttonSkin(select);UI.stationText(select,14)
 local active=label(panel,"ActiveCollection");active.Position=UDim2.fromOffset(12,311);active.Size=UDim2.new(1,-24,0,13);UI.stationText(active,10)
 local scale=panel:FindFirstChild("CollectionScale") or Instance.new("UIScale",panel);scale.Name="CollectionScale"
end
function Style.resize(panel,viewport)
 local scale=math.clamp(math.min((viewport.X-110)/410,viewport.Y/730),.55,1)
 panel.CollectionScale.Scale=scale
 panel.Position=UDim2.fromOffset(92,math.max(66,viewport.Y*.075))
end
function Style.update(panel,zone,profile,activeId)
 local Zones=require(script.Parent.ZoneConfig)
 local Catalog=require(script.Parent.RockCatalog)
 local unlocked=Zones.unlocked(profile,zone.id)
 UI.tintStationCard(panel,zone.color)
 panel.ZoneTitle.Text=zone.name;panel.ZoneTitle.TextColor3=Color3.new(1,1,1)
 panel.ZoneStatus.Text=unlocked and string.format("%s COINS PER SUMMON",zone.cost) or ("LOCKED • REACH "..zone.name)
 panel.ZoneStatus.TextColor3=unlocked and Color3.fromRGB(255,244,174) or Color3.fromRGB(255,215,204)
 local select=panel.SelectCollection
 select.Active=profile.loaded==true and unlocked and activeId~=zone.id
 select.Selectable=select.Active;select.AutoButtonColor=select.Active
 select.Text=not profile.loaded and "LOADING COLLECTIONS..." or not unlocked and ("REACH "..zone.start.." STUDS TO UNLOCK") or activeId==zone.id and "SELECTED COLLECTION" or "SELECT THIS COLLECTION"
 select.BackgroundColor3=select.Active and Color3.fromRGB(34,182,82) or Color3.fromRGB(42,72,90)
 local active=Zones.ById[activeId] or Zones.List[1]
 panel.ActiveCollection.Text="SUMMONING: "..active.name
 for i=1,6 do
  local card=panel.RockCards["Card"..i];local entry=zone.pool[i]
  card.Visible=entry~=nil
  if entry then
   local rock=Catalog.get(entry.id)
   UI.tintStationCard(card,Catalog.RarityColors[rock.rarity] or zone.color)
   card.RockName.Text=string.upper(rock.name);card.RockImage.Image=rock.image or "";card.Odds.Text=entry.weight.."%"
   card.RockImage.ImageTransparency=unlocked and 0 or .45
  end
 end
end
return Style