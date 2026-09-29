-- Dialogue for the Golden Meridian: no panels or portraits, just a soft band of shadow,
-- a spaced speaker name and a serif line that writes itself in. Tap, click, E, Space,
-- Enter or gamepad A advances; tapping while a line is still writing completes it.
local UIS=game:GetService("UserInputService")
local Golden=require(game:GetService("ReplicatedStorage").Shared.GoldenMeridianConfig)
local Dlg={}
Dlg.__index=Dlg
local ADVANCE={[Enum.KeyCode.E]=true,[Enum.KeyCode.Space]=true,[Enum.KeyCode.Return]=true,[Enum.KeyCode.ButtonA]=true,[Enum.KeyCode.ButtonX]=true}
local function smooth(a) a=math.clamp(a,0,1);return a*a*(3-2*a) end
local function spaced(text) return (string.gsub(text,"(%S)","%1 ")) end
function Dlg.new(director,audio)
 local D=director
 local self=setmetatable({D=D,audio=audio,open=false,pressed=false},Dlg)
 local make=D.make
 local root=make("Frame",D.gui,{Name="Dialogue",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=48,Visible=false})
 self.root=root
 -- A band of shadow behind the words, darkest at the bottom.
 local band=make("Frame",root,{Name="Shade",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.fromScale(1,.34),BackgroundColor3=Color3.fromRGB(6,5,4),BackgroundTransparency=0,BorderSizePixel=0,ZIndex=48})
 make("UIGradient",band,{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.55,.55),NumberSequenceKeypoint.new(1,.35)})})
 self.band=band
 self.name=make("TextLabel",root,{Name="Speaker",AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,.8),Size=UDim2.fromScale(.7,.03),BackgroundTransparency=1,
  Text="",TextScaled=true,Font=Enum.Font.GothamMedium,TextColor3=Golden.Gold,TextTransparency=1,ZIndex=49})
 make("UITextSizeConstraint",self.name,{MaxTextSize=13,MinTextSize=9})
 self.line=make("TextLabel",root,{Name="Line",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,.81),Size=UDim2.fromScale(.72,.1),BackgroundTransparency=1,
  Text="",TextWrapped=true,TextScaled=true,Font=Enum.Font.Garamond,TextColor3=Golden.WhiteGold,TextTransparency=1,TextStrokeColor3=Color3.fromRGB(20,14,6),TextStrokeTransparency=.7,
  TextYAlignment=Enum.TextYAlignment.Top,ZIndex=49})
 make("UITextSizeConstraint",self.line,{MaxTextSize=27,MinTextSize=14})
 self.next=make("TextLabel",root,{Name="Continue",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,.915),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,
  Text="◆",TextSize=12,Font=Enum.Font.GothamMedium,TextColor3=Golden.Gold,TextTransparency=1,ZIndex=49})
 -- Centred whisper text, for the Magical Rock's voice.
 self.whisperLabel=make("TextLabel",D.gui,{Name="Whisper",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.3),Size=UDim2.fromScale(.8,.07),BackgroundTransparency=1,
  Text="",TextScaled=true,Font=Enum.Font.Garamond,TextColor3=Golden.WhiteGold,TextTransparency=1,TextStrokeColor3=Golden.Blue,TextStrokeTransparency=.75,ZIndex=47})
 make("UITextSizeConstraint",self.whisperLabel,{MaxTextSize=34,MinTextSize=16})
 -- Input: a full-screen tap target while a line is shown, plus keys and gamepad.
 local tap=make("TextButton",root,{Name="Advance",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,Selectable=false,ZIndex=47})
 D:connect(tap.Activated,function() self.pressed=true end)
 D:connect(UIS.InputBegan,function(input)
  if self.open and ADVANCE[input.KeyCode] then self.pressed=true end
 end)
 D:add(root);D:add(self.whisperLabel)
 return self
end
function Dlg:show(visible)
 local D=self.D
 if visible then self.root.Visible=true end
 self.open=visible
 local fromBand=self.band.BackgroundTransparency
 D:animate(.35,function(a)
  local k=smooth(a)
  self.band.BackgroundTransparency=visible and fromBand+(0-fromBand)*k or fromBand+(1-fromBand)*k
  if not visible then self.line.TextTransparency=k;self.name.TextTransparency=k;self.next.TextTransparency=1 end
 end)
 if not visible then self.root.Visible=false end
end
-- Writes one line and waits for the player (or `auto` seconds). Returns false if aborted.
-- opts: auto, speed (characters per second), onShow(), voice (false to silence)
function Dlg:say(speaker,text,opts)
 opts=opts or {}
 local D=self.D
 if not D.alive then return false end
 if not self.open then self.root.Visible=true;self.band.BackgroundTransparency=1;self:show(true) end
 local line=self.line
 self.name.Text=spaced(speaker)
 line.Text=text
 line.MaxVisibleGraphemes=0
 line.TextTransparency=0
 self.name.TextTransparency=0
 self.next.TextTransparency=1
 self.pressed=false
 if opts.onShow then D:spawn(opts.onShow) end
 if opts.voice~=false and self.audio then self.audio:chime(.42+math.random()*.04,.05) end
 -- Reveal times, with a breath after punctuation.
 local reveal={}
 local clock=0
 local speed=opts.speed or 30
 for _,code in utf8.codes(text) do
  local ch=utf8.char(code)
  clock+=1/speed
  table.insert(reveal,clock)
  if ch=="." or ch=="…" or ch=="?" or ch=="!" then clock+=.28 elseif ch=="," or ch==";" or ch==":" then clock+=.12 end
 end
 local total=#reveal
 local start=os.clock()
 while D.alive do
  local elapsed=os.clock()-start
  local shown=0
  while shown<total and reveal[shown+1]<=elapsed do shown+=1 end
  if self.pressed then self.pressed=false;shown=total;start=os.clock()-(reveal[total] or 0)-1 end
  line.MaxVisibleGraphemes=shown
  if shown>=total then break end
  task.wait()
 end
 line.MaxVisibleGraphemes=-1
 local waitStart=os.clock()
 local auto=opts.auto
 local fast=game:GetService("RunService"):IsStudio() and game:GetService("Players").LocalPlayer:GetAttribute("GoldenDevFast")==true
 if fast then auto=math.min(auto or .7,.7) end
 while D.alive do
  local waited=os.clock()-waitStart
  self.next.TextTransparency=.35+.35*math.sin(waited*4)
  if self.pressed then break end
  if auto and waited>=auto then break end
  -- Never strand the player: long silence moves the scene on.
  if waited>=14+#text*.04 then break end
  task.wait()
 end
 self.pressed=false
 self.next.TextTransparency=1
 return D.alive
end
function Dlg:close() if self.open then self:show(false) end end
-- The Magical Rock's voice: a centred line that breathes in, holds, and fades.
function Dlg:whisper(text,hold,color)
 local D=self.D
 local label=self.whisperLabel
 label.Text=text
 label.TextColor3=color or Golden.WhiteGold
 if self.audio then self.audio:chime(.58+math.random()*.06,.09) end
 D:animate(.9,function(a) label.TextTransparency=1-smooth(a);label.Position=UDim2.fromScale(.5,.3+.012*(1-smooth(a))) end)
 D:wait(hold or 2.2)
 return D:animate(.9,function(a) label.TextTransparency=smooth(a) end)
end
return Dlg
