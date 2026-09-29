-- Presentation only: one fixed-design text run scales with the pedestal billboard.
local S={}
local TextService=game:GetService("TextService")
local states=setmetatable({},{__mode="k"})
local ink=Color3.fromRGB(18,29,43)
local function textOutline(label)
 label.TextStrokeTransparency=1
 local stroke=Instance.new("UIStroke")
 stroke.Name="TextOutline";stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
 stroke.Color=ink;stroke.Thickness=1;stroke.LineJoinMode=Enum.LineJoinMode.Round
 stroke.Parent=label
 return stroke
end
local function themeGradient(parent,zone)
 local gradient=parent:FindFirstChild("ZoneGradient") or Instance.new("UIGradient")
 gradient.Name="ZoneGradient";gradient.Rotation=90
 local color=zone.color or Color3.fromRGB(70,190,228)
 gradient.Color=ColorSequence.new({
  ColorSequenceKeypoint.new(0,color:Lerp(Color3.new(1,1,1),.55)),
  ColorSequenceKeypoint.new(.5,color:Lerp(Color3.new(1,1,1),.12)),
  ColorSequenceKeypoint.new(1,color:Lerp(ink,.12)),
 })
 gradient.Parent=parent
end
function S.mount(root)
 local old=root:FindFirstChild("AreaSelector")
 if old then return old end
 local holder=Instance.new("Frame")
 holder.Name="AreaSelector";holder.AnchorPoint=Vector2.new(.5,1)
 holder.Position=UDim2.new(.5,0,0,-12);holder.Size=UDim2.fromOffset(252,42)
 holder.BackgroundTransparency=1;holder.BorderSizePixel=0
 holder.ZIndex=10;holder.ClipsDescendants=false;holder.Parent=root
 local title=Instance.new("Frame");title.Name="AreaName"
 title.BackgroundTransparency=1;title.BorderSizePixel=0
 title.Position=UDim2.fromOffset(42,4);title.Size=UDim2.fromOffset(168,34)
 title.ClipsDescendants=false;title.ZIndex=11;title.Parent=holder
 for _,entry in {{"Previous","‹",4},{"Next","›",212}} do
  local b=Instance.new("TextButton");b.Name=entry[1];b.Text=entry[2]
  b.Size=UDim2.fromOffset(36,34);b.Position=UDim2.fromOffset(entry[3],4)
  b.BackgroundColor3=Color3.new(1,1,1);b.AutoButtonColor=true
  b.Active=false;b.Selectable=false;b.Font=Enum.Font.FredokaOne;b.TextColor3=Color3.new(1,1,1)
  b.TextScaled=false;b.TextSize=30;b.ZIndex=11;b.BorderSizePixel=0;b.Parent=holder
  textOutline(b)
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,10);c.Parent=b
 end
 return holder
end
function S.setArea(selector,zone)
 local state=states[selector]
 if state and state.id==zone.id then return end
 for _,child in selector.AreaName:GetChildren() do child:Destroy() end
 for _,name in {"Previous","Next"} do themeGradient(selector[name],zone) end
 local letters={}
 local widths,total={},0
 for i=1,#zone.name do
  local width=TextService:GetTextSize(zone.name:sub(i,i),18,Enum.Font.FredokaOne,Vector2.new(1000,100)).X
  widths[i]=width;total+=width
 end
 local fit=math.min(1,164/math.max(total,1))
 -- Offsets and TextSize use the same design units. No per-glyph size constraints:
 -- those clamp rendered fonts independently of billboard/camera scaling.
 local run=Instance.new("Frame");run.Name="TextRun";run.BackgroundTransparency=1;run.BorderSizePixel=0
 run.AnchorPoint=Vector2.new(.5,.5);run.Position=UDim2.fromScale(.5,.5)
 run.Size=UDim2.fromOffset(total*fit,34);run.ZIndex=12;run.Parent=selector.AreaName
 local x=0
 local step=math.min(.026,.32/math.max(1,#zone.name-1))
 for i=1,#zone.name do
  local char=zone.name:sub(i,i);local width=widths[i]*fit
  if char~=" " then
   local letter=Instance.new("TextLabel");letter.Name="Letter_"..i;letter.Text=char
   letter.BackgroundTransparency=1;letter.BorderSizePixel=0
   letter.AnchorPoint=Vector2.new(.5,.5);letter.Size=UDim2.fromOffset(width+4,34)
   letter.Position=UDim2.new(0,x+width*.5,.5,0)
   letter.Font=Enum.Font.FredokaOne;letter.TextColor3=Color3.new(1,1,1)
   letter.TextTransparency=1;letter.TextScaled=false;letter.TextSize=18*fit
   letter.TextWrapped=false;letter.ZIndex=12;letter.Parent=run
   local stroke=textOutline(letter);stroke.Transparency=1
   themeGradient(letter,zone)
   table.insert(letters,{label=letter,stroke=stroke,x=x+width*.5,delay=(i-1)*step})
  end
  x+=width
 end
 selector:SetAttribute("AreaId",zone.id);selector:SetAttribute("AreaName",zone.name)
 states[selector]={id=zone.id,letters=letters,age=0,wasActive=false}
end
function S.step(selector,dt,opacity,active,reduced)
 local state=states[selector];if not state then return end
 if active and not state.wasActive then state.age=0 end
 state.wasActive=active
 if active or opacity>0 then state.age+=dt end
 for _,entry in state.letters do
  local t=state.age-entry.delay
  local reveal=if reduced then 1 else math.clamp(t/.075,0,1)
  local bounce=if reduced or t<0 or t>.24 then 0 else math.sin(t/.24*math.pi)*4.5
  entry.label.Position=UDim2.new(0,entry.x,.5,-bounce)
  entry.label.TextTransparency=1-opacity*reveal
  entry.stroke.Transparency=1-opacity*reveal
 end
end
function S.cleanup(selector) states[selector]=nil end
return S