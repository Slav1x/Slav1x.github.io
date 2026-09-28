-- Trait station layout using the summon system's shared raised-card treatment.
local Style = {}
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SummonUI = require(Shared:WaitForChild("SummonUIStyle"))
local Input = game:GetService("UserInputService")
local ink = Color3.fromRGB(12,25,23)
local gold = Color3.fromRGB(232,174,62)
local green = Color3.fromRGB(104,245,179)
local jade = Color3.fromRGB(38,157,127)
local white = Color3.fromRGB(255,248,226)
local soft = Color3.fromRGB(210,234,211)

local function corner(object,radius)
	local c=object:FindFirstChildWhichIsA("UICorner") or Instance.new("UICorner",object)
	c.CornerRadius=UDim.new(0,radius)
end
local function outline(object,color,width)
	local s=object:FindFirstChildWhichIsA("UIStroke") or Instance.new("UIStroke",object)
	s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
	s.Color=color;s.Thickness=width;s.Transparency=0;s.Enabled=true
	return s
end
local function gradient(object,top,bottom)
	object.BackgroundColor3=Color3.new(1,1,1)
	local g=object:FindFirstChildWhichIsA("UIGradient") or Instance.new("UIGradient",object)
	g.Color=ColorSequence.new(top,bottom);g.Rotation=90;g.Enabled=true
end
local function label(parent,name,text,pos,size,fontSize,color)
	local l=Instance.new("TextLabel")
	l.Name=name;l.BackgroundTransparency=1;l.Position=pos;l.Size=size
	l.Text=text;l.TextColor3=color or white;l.TextSize=fontSize
	l.Font=Enum.Font.FredokaOne;l.TextStrokeColor3=ink;l.TextStrokeTransparency=.15
	l.TextXAlignment=Enum.TextXAlignment.Left;l.TextWrapped=true;l.ZIndex=8;l.Parent=parent
	return l
end
local function chunky(object,size)
	SummonUI.stationText(object,size)
end
local function secondary(button,color,size)
	gradient(button,color:Lerp(white,.12),color:Lerp(ink,.35))
	outline(button,ink,2);corner(button,11)
	chunky(button,size or 15)
	button.ZIndex=8
	-- A separate label keeps the face gradient from tinting the button lettering.
	button.TextTransparency=1
	local text=label(button,"ButtonLabel",button.Text,UDim2.fromOffset(5,0),UDim2.new(1,-10,1,0),size or 15)
	text.TextXAlignment=Enum.TextXAlignment.Center
	chunky(text,size or 15)
	text.ZIndex=9
	button:GetPropertyChangedSignal("Text"):Connect(function() text.Text=button.Text end)
end
local function inset(object)
	gradient(object,Color3.fromRGB(38,66,55),Color3.fromRGB(21,38,34))
	outline(object,ink,2);corner(object,14)
end
local function raised(button,color)
	SummonUI.stationCard(button,color)
	button.CandyShadow.Position=UDim2.fromOffset(0,4)
	button.CandyShadow.UIStroke.Thickness=2
	button.CandyFace.UIStroke.Thickness=2
	button.CandyLabel.Position=UDim2.new(0,3,.5,0)
	button.CandyLabel.Size=UDim2.new(1,-6,.5,-3)
	button.CandyLabel.BackgroundTransparency=.6
	button.CandyGloss.Size=UDim2.new(1,-18,0,18)
	button.CandySpark.Visible=false
	button.TextTransparency=1
	local text=label(button,"ActionTitle",button.Text,UDim2.fromOffset(58,9),UDim2.new(1,-116,0,30),25)
	text.TextXAlignment=Enum.TextXAlignment.Center
	chunky(text,25)
	return text
end

function Style.mount(panel)
	panel.Size=UDim2.fromOffset(600,420)
	corner(panel,24);outline(panel,Color3.fromRGB(186,143,66),2)
	gradient(panel,Color3.fromRGB(47,77,61),Color3.fromRGB(22,41,35))
	panel.HeaderBand.Size=UDim2.fromOffset(600,67)
	corner(panel.HeaderBand,23)
	gradient(panel.HeaderBand,Color3.fromRGB(38,125,88),Color3.fromRGB(21,68,52))
	panel.TopAccent.Position=UDim2.fromOffset(18,65)
	panel.TopAccent.Size=UDim2.fromOffset(564,2)
	panel.TopAccent.BackgroundTransparency=.15
	panel.TopAccent.BackgroundColor3=Color3.new(1,1,1)
	panel.TopAccent.UIGradient.Color=ColorSequence.new(Color3.fromRGB(255,206,102),Color3.fromRGB(135,255,199))
	panel.Title.Position=UDim2.fromOffset(57,15)
	panel.Title.Size=UDim2.fromOffset(325,36)
	chunky(panel.Title,29)
	panel.ForgeIcon.Position=UDim2.fromOffset(18,12)
	panel.ForgeIcon.Size=UDim2.fromOffset(30,37)
	chunky(panel.ForgeIcon,32)
	panel.ForgeIcon.TextColor3=Color3.fromRGB(255,216,126)
	panel.OddsToggle.Position=UDim2.fromOffset(395,18)
	panel.OddsToggle.Size=UDim2.fromOffset(134,34)
	secondary(panel.OddsToggle,Color3.fromRGB(55,139,114),14)
	panel.Close.Position=UDim2.fromOffset(542,17)
	panel.Close.Size=UDim2.fromOffset(38,36)
	secondary(panel.Close,Color3.fromRGB(141,76,49),26)

	local info=panel.RockInfo
	info.Position=UDim2.fromOffset(22,228);info.Size=UDim2.fromOffset(556,90)
	inset(info)
	local portrait=Instance.new("Frame");portrait.Name="PortraitWell"
	portrait.Position=UDim2.fromOffset(10,10);portrait.Size=UDim2.fromOffset(70,70)
	portrait.BorderSizePixel=0;portrait.BackgroundColor3=Color3.fromRGB(38,100,79);portrait.Parent=info
	corner(portrait,16);outline(portrait,Color3.fromRGB(149,235,185),1.5)
	local caption=label(info,"SelectedCaption","SELECTED ROCK",UDim2.fromOffset(96,8),UDim2.fromOffset(285,15),11,soft)
	caption.Font=Enum.Font.GothamBold;caption.TextStrokeTransparency=1
	panel.RockImage.Position=UDim2.fromOffset(36,242);panel.RockImage.Size=UDim2.fromOffset(62,62);panel.RockImage.ZIndex=3
	panel.RockGlyph.Position=panel.RockImage.Position;panel.RockGlyph.Size=panel.RockImage.Size;panel.RockGlyph.ZIndex=3
	panel.RockName.Position=UDim2.fromOffset(118,254);panel.RockName.Size=UDim2.fromOffset(285,28)
	chunky(panel.RockName,22);panel.RockName.TextXAlignment=Enum.TextXAlignment.Left
	panel.CurrentTrait.Position=UDim2.fromOffset(118,286);panel.CurrentTrait.Size=UDim2.fromOffset(288,19)
	panel.CurrentTrait.Font=Enum.Font.GothamBold;panel.CurrentTrait.TextSize=12
	panel.SelectRock.Position=UDim2.fromOffset(428,254);panel.SelectRock.Size=UDim2.fromOffset(135,39)
	secondary(panel.SelectRock,jade,15)
	panel.SelectRock.Text="CHANGE"

	local place=panel.PlaceRock
	place.Position=UDim2.fromOffset(22,330);place.Size=UDim2.fromOffset(556,60)
	secondary(place,Color3.fromRGB(36,177,117),23)

	panel.ReelFrame.Position=UDim2.fromOffset(22,82)
	panel.ReelFrame.BackgroundColor3=Color3.fromRGB(12,25,23)
	corner(panel.ReelFrame,14)
	outline(panel.ReelFrame,ink,2.5)

	panel.ResultBox.Position=UDim2.fromOffset(22,184)
	panel.ResultBox.Size=UDim2.fromOffset(556,34)
	inset(panel.ResultBox)
	panel.Result.Position=UDim2.fromOffset(300,201)
	panel.Result.Size=UDim2.fromOffset(530,29)
	chunky(panel.Result,21)
	panel.Result.TextXAlignment=Enum.TextXAlignment.Center

	local roll=panel.Roll
	roll.Position=UDim2.fromOffset(22,330);roll.Size=UDim2.fromOffset(556,60)
	local title=raised(roll,gold)
	title.Position=UDim2.fromOffset(58,5);title.Size=UDim2.new(1,-116,0,31)
	local caption=label(roll,"ActionCaption","CLICK OR E TO REROLL",UDim2.fromOffset(60,36),UDim2.new(1,-120,0,16),11)
	caption.TextXAlignment=Enum.TextXAlignment.Center
	local key=Instance.new("Frame");key.Name="KeyCap";key.Position=UDim2.fromOffset(15,13)
	key.Size=UDim2.fromOffset(34,32);key.BackgroundColor3=ink;key.BorderSizePixel=0;key.ZIndex=7;key.Parent=roll;corner(key,9)
	local keyText=label(key,"KeyText",Input.TouchEnabled and "TAP" or "E",UDim2.fromScale(0,0),UDim2.fromScale(1,1),16)
	keyText.TextXAlignment=Enum.TextXAlignment.Center
	local badge=label(roll,"FreeBadge","FREE",UDim2.new(1,-57,0,20),UDim2.fromOffset(48,20),12)
	badge.TextXAlignment=Enum.TextXAlignment.Center
	local function refreshAction()
		title.Text=roll.Text:gsub("  •  FREE","")
		local active=roll.Text:find("REROLL")~=nil or roll.Text:find("TRY AGAIN")~=nil
		local fast=roll.Text:find("FASTER")~=nil
		local waiting=roll.Text:find("ROLLING")~=nil or roll.Text:find("REVEALING")~=nil
		local color=active and gold or (fast and green or (waiting and jade or Color3.fromRGB(60,76,66)))
		SummonUI.tintStationCard(roll,color)
		badge.Visible=active
		key.BackgroundColor3=ink
		caption.Text=fast and "CLICK • E • SPACE" or waiting and "YOUR NEW TRAIT IS ON ITS WAY" or active and "REPLACE THIS ROCK'S CURRENT TRAIT" or "SELECT A ROCK AND PLACE IT IN THE FORGE"
	end
	roll:GetPropertyChangedSignal("Text"):Connect(refreshAction)
	refreshAction()
	panel.Footnote.Position=UDim2.fromOffset(22,400);panel.Footnote.Size=UDim2.fromOffset(556,14)
	panel.Footnote.TextSize=10;panel.Footnote.TextColor3=soft

	for _,page in {panel.OddsPage,panel.SelectPage} do
		page.Position=UDim2.fromOffset(18,78);page.Size=UDim2.fromOffset(564,329)
		inset(page)
		for _,child in page:GetChildren() do
			if child:IsA("TextLabel") then
				child.TextColor3=soft
				if child.Name:find("Title") then chunky(child,25) end
			end
		end
	end
	panel.OddsPage.OddsList.Size=UDim2.fromOffset(536,232)
	panel.SelectPage.RockList.Size=UDim2.fromOffset(536,250)
	secondary(panel.SelectPage.Back,jade,14)
	for _,row in panel.OddsPage.OddsList:GetChildren() do
		if row:IsA("Frame") then
			inset(row);corner(row,9)
			row.TraitName.Font=Enum.Font.FredokaOne
			row.Chance.Font=Enum.Font.FredokaOne
			row.Chance.TextColor3=white
		end
	end
end

function Style.reelCard(card,color)
	gradient(card,Color3.fromRGB(56,82,63),Color3.fromRGB(27,45,36))
	outline(card,ink,2)
	corner(card,11)
	card:FindFirstChild("Name").Font=Enum.Font.FredokaOne
	card:FindFirstChild("Name").TextSize=19
	card:FindFirstChild("Name").TextStrokeTransparency=.15
	card.Tier.Font=Enum.Font.FredokaOne
	card.Tier.TextSize=13
	card.Tier.TextStrokeTransparency=.25
end

function Style.selectionRow(row,picked,color)
	inset(row)
	outline(row,picked and Color3.fromRGB(255,213,121) or ink,picked and 2 or 1.5)
	row.RockName.Font=Enum.Font.FredokaOne
	row.RockName.TextSize=17
	row.RockName.TextStrokeTransparency=.2
	row.Status.Font=Enum.Font.FredokaOne
	row.Trait.Font=Enum.Font.GothamBold
end
function Style.placeReady(button,ready)
	local color=ready and Color3.fromRGB(36,177,117) or Color3.fromRGB(66,90,75)
	gradient(button,color:Lerp(white,.12),color:Lerp(ink,.35))
end
return Style
