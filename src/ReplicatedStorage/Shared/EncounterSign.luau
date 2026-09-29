--!nonstrict
local Tags=game:GetService("CollectionService")
local Sign={}
-- Small cards with a pixel gap above the object even when it is far away.
function Sign.layout(gui,compact)
 gui.Size=UDim2.fromOffset(compact and 108 or 124,compact and 28 or 34)
 gui.SizeOffset=Vector2.new(0,.68)
 local plate=gui:FindFirstChild("Plate")
 if not plate then return end
 plate.BackgroundTransparency=.1
 local corner=plate:FindFirstChildOfClass("UICorner")
 if corner then corner.CornerRadius=UDim.new(0,7) end
 local stroke=plate:FindFirstChildOfClass("UIStroke")
 if stroke then stroke.Thickness=1 end
 local bar=plate:FindFirstChild("Accent")
 if bar then bar.Size=UDim2.new(0,2,1,-12);bar.Position=UDim2.fromOffset(6,6) end
 local title=plate:FindFirstChild("Title")
 local detail=plate:FindFirstChild("Detail")
 if title then
  title.TextSize=compact and 9 or 10
  title.Position=UDim2.fromOffset(13,compact and 2 or 3)
  title.Size=UDim2.new(1,-19,0,compact and 13 or 14)
 end
 if detail then
  detail.TextSize=8
  detail.Position=UDim2.fromOffset(13,compact and 15 or 18)
  detail.Size=UDim2.new(1,-19,0,compact and 10 or 11)
 end
end
function Sign.positionAbove(gui,model,root,height)
 local above=height or gui.StudsOffsetWorldSpace.Y
 -- Authored pickup bounds exclude UI and match the visible asset, including
 -- large jets and tall obstacles. Preserve a higher authored placement.
 local bounds=model:GetAttribute("PickupVisualBounds")
 local size=model:GetAttribute("PickupVisualSize")
 if typeof(bounds)=="CFrame" and typeof(size)=="Vector3" then
  local half=size*.5
  local top=bounds.Position.Y+math.abs(bounds.RightVector.Y)*half.X+math.abs(bounds.UpVector.Y)*half.Y+math.abs(bounds.LookVector.Y)*half.Z
  local localRoot=root:GetAttribute("PickupLocalCFrame")
  above=math.max(above,top-(typeof(localRoot)=="CFrame" and localRoot.Position.Y or 0)+2)
 end
 gui.StudsOffsetWorldSpace=Vector3.new(0,above,0)
 gui.SizeOffset=Vector2.new(0,.68)
end
function Sign.attach(model,root,title,detail,accent,height)
 local previous=root:FindFirstChild("Sign");if previous then previous:Destroy() end
 local gui=Instance.new("BillboardGui");gui.Name="Sign";gui.Adornee=root
 gui.MaxDistance=150;gui.AlwaysOnTop=false;gui.LightInfluence=0;gui.Enabled=false
 gui:SetAttribute("EncounterLabel",true);gui.Parent=root
 local plate=Instance.new("CanvasGroup");plate.Name="Plate";plate.Size=UDim2.fromScale(1,1)
 plate.BackgroundColor3=Color3.fromRGB(243,249,240);plate.BorderSizePixel=0;plate.GroupTransparency=1;plate.Parent=gui
 local corner=Instance.new("UICorner");corner.Parent=plate
 local stroke=Instance.new("UIStroke");stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Color=accent;stroke.Transparency=.22;stroke.Parent=plate
 local bar=Instance.new("Frame");bar.Name="Accent";bar.BackgroundColor3=accent;bar.BorderSizePixel=0;bar.Parent=plate
 local bc=Instance.new("UICorner");bc.CornerRadius=UDim.new(1,0);bc.Parent=bar
 local function label(name,tint,value)
  local t=Instance.new("TextLabel");t.Name=name
  t.BackgroundTransparency=1;t.Font=if name=="Title" then Enum.Font.GothamBold else Enum.Font.GothamMedium
  t.Text=value;t.TextColor3=tint;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextTruncate=Enum.TextTruncate.AtEnd;t.Parent=plate
 end
 label("Title",Color3.fromRGB(28,57,57),title)
 label("Detail",Color3.fromRGB(71,102,94),detail)
 Sign.layout(gui,false);Sign.positionAbove(gui,model,root,height)
 Tags:AddTag(gui,"EncounterLabel")
 return gui
end
return Sign
