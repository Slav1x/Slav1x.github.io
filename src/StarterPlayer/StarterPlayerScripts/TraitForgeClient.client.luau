-- Trait Forge presentation. The server picks the trait; this reel only reveals that result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rocks = require(Shared:WaitForChild("RockCatalog"))
local Traits = require(Shared:WaitForChild("TraitCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Client = script.Parent:WaitForChild("Client")
local Store = require(Client:WaitForChild("ProfileStore"))
local TraitTextStyle = require(Client:WaitForChild("TraitTextStyle"))
local function rollPriceText()
 return "REROLL TRAIT  •  "..Traits.RollCost.." SHARDS"
end
local function shardSummary()
 return tostring(Store.get().traitShards or 0).." SHARDS OWNED • "..Traits.RollCost.." PER ROLL • Rare skip drops & area rewards"
end
local TraitUI = require(Shared:WaitForChild("TraitForgeUIStyle"))
local LegendaryFX = require(Shared:WaitForChild("TraitLegendaryFX"))
local forge = workspace:WaitForChild("TraitForge")
local crystal = forge:WaitForChild("TraitCrystal")
local heart = forge:WaitForChild("CrystalHeart")
local pedestal = forge:WaitForChild("Pedestal")
local signAnchor = forge:WaitForChild("SignAnchor")
local anvilFace = forge:WaitForChild("MythicalForge"):WaitForChild("Anvil"):WaitForChild("HardenedFace")
local prompt = crystal:WaitForChild("TraitRollPrompt")
local oldSign = signAnchor:FindFirstChild("TraitSign")
if oldSign then oldSign.Enabled = false end
prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.HoldDuration = 0
prompt.RequiresLineOfSight = false

local deepStone = Color3.fromRGB(16,30,25)
local forgeGold = Color3.fromRGB(255,208,103)
local SPIN_SECONDS = 1.4
local REDUCED_SPIN_SECONDS = .75
local pale = Color3.fromRGB(255,249,230)
local muted = Color3.fromRGB(197,224,204)

local function rounded(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function makeLabel(parent, name, text, position, size, fontSize, color, bold)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = color
	label.TextSize = fontSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, position, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = pale
	button.TextSize = 18
	button.AutoButtonColor = false
	button.TextStrokeTransparency = 1
	button.Parent = parent
	rounded(button, 11)
	local border = stroke(button, color:Lerp(Color3.new(1, 1, 1), .18), 1)
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local buttonScale = Instance.new("UIScale")
	buttonScale.Name = "ButtonScale"
	buttonScale.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(buttonScale, TweenInfo.new(.12, Enum.EasingStyle.Back), {Scale = name == "Close" and 1.11 or 1.018}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(buttonScale, TweenInfo.new(.12, Enum.EasingStyle.Quad), {Scale = 1}):Play()
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			TweenService:Create(buttonScale, TweenInfo.new(.07), {Scale = .975}):Play()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			TweenService:Create(buttonScale, TweenInfo.new(.13, Enum.EasingStyle.Quad), {Scale = 1}):Play()
		end
	end)
	return button
end

-- Match SummonWorldUI: a real world-sized billboard, not a projected HUD panel.
-- Parent to PlayerGui for interactive buttons; Adornee fixes its position to the altar.
local gui = Instance.new("BillboardGui")
gui.Name = "TraitForgeGui"
gui.Adornee = anvilFace
gui.Size = UDim2.fromScale(7.3, 7.3 * 450 / 624)
-- Center the panel over the anvil itself; its lower edge clears the working face.
gui.StudsOffsetWorldSpace = Vector3.new(0, anvilFace.Size.Y / 2 + (7.3 * 450 / 624) / 2 + 1.6, 0)
gui.AlwaysOnTop = true
gui.LightInfluence = 0
gui.MaxDistance = 0 -- Proximity owns the fade; never distance-cull during the exit.
gui.Active = false
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local worldRoot = Instance.new("Frame")
worldRoot.Name = "WorldAnchor"
worldRoot.AnchorPoint = Vector2.new(.5, .5)
worldRoot.Position = UDim2.fromScale(.5, .5)
worldRoot.Size = UDim2.fromOffset(624, 450)
worldRoot.BackgroundTransparency = 1
worldRoot.BorderSizePixel = 0
worldRoot.Visible = false
worldRoot.Parent = gui

local shadow = Instance.new("Frame")
shadow.Name = "PanelShadow"
shadow.AnchorPoint = Vector2.new(.5, .5)
shadow.Position = UDim2.new(.5, 0, .5, 7)
shadow.Size = UDim2.fromOffset(608, 428)
shadow.BackgroundColor3 = Color3.fromRGB(4,12,9)
shadow.BackgroundTransparency = .28
shadow.BorderSizePixel = 0
shadow.Parent = worldRoot
rounded(shadow, 21)
-- The shadow and every panel element inherit the same worldRoot scale.

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(.5, .5)
panel.Position = UDim2.fromScale(.5, .5)
panel.Size = UDim2.fromOffset(600, 420)
panel.BackgroundColor3 = Color3.new(1, 1, 1)
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = worldRoot
rounded(panel, 18)
local panelStroke = stroke(panel, Color3.fromRGB(177,143,71), 1.2)
local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new(Color3.fromRGB(41,65,51), Color3.fromRGB(20,36,30))
panelGradient.Rotation = 90
panelGradient.Parent = panel
local scale = Instance.new("UIScale")
scale.Name = "WorldScale"
scale.Parent = worldRoot

local headerBand = Instance.new("Frame")
headerBand.Name = "HeaderBand"
headerBand.Size = UDim2.fromOffset(600, 58)
headerBand.BorderSizePixel = 0
headerBand.BackgroundColor3 = Color3.new(1, 1, 1)
headerBand.Parent = panel
rounded(headerBand, 17)
local headerGradient = Instance.new("UIGradient")
headerGradient.Color = ColorSequence.new(Color3.fromRGB(34,100,72), Color3.fromRGB(20,61,47))
headerGradient.Rotation = 0
headerGradient.Parent = headerBand

local stripe = Instance.new("Frame")
stripe.Name = "TopAccent"
stripe.Position = UDim2.fromOffset(18, 54)
stripe.Size = UDim2.fromOffset(564, 1)
stripe.BorderSizePixel = 0
stripe.BackgroundColor3 = forgeGold
stripe.Parent = panel
rounded(stripe, 2)
local stripeGradient = Instance.new("UIGradient")
stripeGradient.Color = ColorSequence.new(forgeGold, Color3.fromRGB(100,200,155))
stripe.BackgroundTransparency = .45
stripeGradient.Parent = stripe

local forgeIcon = makeLabel(panel, "ForgeIcon", "◆", UDim2.fromOffset(19, 6), UDim2.fromOffset(38, 45), 33, forgeGold, true)
forgeIcon.TextXAlignment = Enum.TextXAlignment.Center
makeLabel(panel, "Title", "TRAIT REROLLER", UDim2.fromOffset(62, 11), UDim2.fromOffset(330, 37), 23, pale, true)
local closeButton = makeButton(panel, "Close", "X", UDim2.fromOffset(545, 10), UDim2.fromOffset(39, 39), Color3.fromRGB(229,37,49))
closeButton.Font = Enum.Font.FredokaOne
closeButton.TextSize = 25
closeButton.TextStrokeColor3 = Color3.fromRGB(21,4,8)
closeButton.TextStrokeTransparency = 0
local closeShade = Instance.new("Frame")
closeShade.Name = "HoverShade"
closeShade.Size = UDim2.fromScale(1,1)
closeShade.BackgroundColor3 = Color3.fromRGB(65,0,16)
closeShade.BackgroundTransparency = 1
closeShade.BorderSizePixel = 0
closeShade.Active = false
closeShade.Parent = closeButton
rounded(closeShade, 8)
closeButton.MouseEnter:Connect(function()
 TweenService:Create(closeShade,TweenInfo.new(.13),{BackgroundTransparency=.7}):Play()
end)
closeButton.MouseLeave:Connect(function()
 TweenService:Create(closeShade,TweenInfo.new(.13),{BackgroundTransparency=1}):Play()
end)

local rockInfo = Instance.new("Frame")
rockInfo.Name = "RockInfo"
rockInfo.Position = UDim2.fromOffset(18, 65)
rockInfo.Size = UDim2.fromOffset(564, 64)
rockInfo.BackgroundColor3 = Color3.fromRGB(30,51,40)
rockInfo.BorderSizePixel = 0
rockInfo.Parent = panel
rounded(rockInfo, 11)
stroke(rockInfo, Color3.fromRGB(83,133,103), 1.4)
local rockInfoGradient = Instance.new("UIGradient")
rockInfoGradient.Color = ColorSequence.new(Color3.fromRGB(42,69,53), Color3.fromRGB(27,47,36))
rockInfoGradient.Rotation = 0
rockInfoGradient.Parent = rockInfo
local rockImage = Instance.new("ImageLabel")
rockImage.Name = "RockImage"
rockImage.Position = UDim2.fromOffset(27, 73)
rockImage.Size = UDim2.fromOffset(48, 48)
rockImage.BackgroundTransparency = 1
rockImage.ScaleType = Enum.ScaleType.Fit
rockImage.Parent = panel
local rockGlyph = makeLabel(panel, "RockGlyph", "◆", UDim2.fromOffset(28, 74), UDim2.fromOffset(46, 46), 29, Color3.fromRGB(152,255,199), true)
rockGlyph.TextXAlignment = Enum.TextXAlignment.Center
local rockLabel = makeLabel(panel, "RockName", "PICK A ROCK", UDim2.fromOffset(84, 72), UDim2.fromOffset(328, 28), 20, pale, true)
local currentLabel = makeLabel(panel, "CurrentTrait", "CURRENT TRAIT: NONE", UDim2.fromOffset(84, 101), UDim2.fromOffset(328, 22), 14, muted, false)
local selectButton = makeButton(panel, "SelectRock", "CHANGE ROCK", UDim2.fromOffset(423, 79), UDim2.fromOffset(143, 39), Color3.fromRGB(40,141,105))
selectButton.TextSize = 14
local placeButton = makeButton(panel, "PlaceRock", "PLACE SELECTED ROCK", UDim2.fromOffset(22, 135), UDim2.fromOffset(556, 40), Color3.fromRGB(39,168,112))
local reelFrame = Instance.new("Frame")
reelFrame.Name = "ReelFrame"
reelFrame.Position = UDim2.fromOffset(22, 190)
reelFrame.Size = UDim2.fromOffset(556, 94)
reelFrame.BackgroundColor3 = Color3.fromRGB(12,25,23)
reelFrame.BorderSizePixel = 0
reelFrame.Parent = panel
rounded(reelFrame, 11)
local reelStroke = stroke(reelFrame, Color3.fromRGB(173,141,73), 2)

local reel = Instance.new("Frame")
reel.Name = "SideSwipeReel"
reel.Position = UDim2.fromOffset(4, 5)
reel.Size = UDim2.fromOffset(548, 84)
reel.BackgroundTransparency = 1
reel.BorderSizePixel = 0
reel.ClipsDescendants = true
reel.Parent = reelFrame
-- Animate the strip in fixed design units, never screen pixels or CanvasPosition.
local reelTrack = Instance.new("Frame")
reelTrack.Name = "TraitStrip"
reelTrack.Size = UDim2.fromOffset(548, 84)
reelTrack.BackgroundTransparency = 1
reelTrack.BorderSizePixel = 0
reelTrack.Parent = reel
local function positionReel(x)
 reelTrack.Position = UDim2.fromOffset(-math.max(0, x), 0)
end

for _, side in {"Left", "Right"} do
	local vignette = Instance.new("Frame")
	vignette.Name = side .. "ReelFade"
	vignette.Position = UDim2.fromOffset(side == "Left" and 4 or 508, 5)
	vignette.Size = UDim2.fromOffset(44, 84)
	vignette.BackgroundColor3 = Color3.fromRGB(12,25,23)
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 7
	vignette.Parent = reelFrame
	local fade = Instance.new("UIGradient")
	fade.Rotation = 0
	fade.Transparency = if side == "Left"
		then NumberSequence.new({NumberSequenceKeypoint.new(0, .06), NumberSequenceKeypoint.new(1, 1)})
		else NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, .06)})
	fade.Parent = vignette
end

local marker = Instance.new("Frame")
marker.Name = "ResultMarker"
marker.Position = UDim2.new(.5, -2, 0, 0)
marker.Size = UDim2.fromOffset(4, 12)
marker.BackgroundColor3 = forgeGold
marker.BorderSizePixel = 0
marker.ZIndex = 8
marker.Parent = reelFrame
rounded(marker, 2)
local bottomMarker = Instance.new("Frame")
bottomMarker.Name = "BottomMarker"
bottomMarker.Position = UDim2.new(.5, -2, 1, -12)
bottomMarker.Size = UDim2.fromOffset(4, 12)
bottomMarker.BackgroundColor3 = marker.BackgroundColor3
bottomMarker.BorderSizePixel = 0
bottomMarker.ZIndex = 8
bottomMarker.Parent = reelFrame
rounded(bottomMarker, 2)
local focus = Instance.new("Frame")
focus.Name = "CenterFocus"
focus.Position = UDim2.new(.5, -74, 0, 3)
focus.Size = UDim2.fromOffset(148, 88)
focus.BackgroundTransparency = 1
focus.ZIndex = 8
focus.Parent = reelFrame
rounded(focus, 9)
local focusStroke = stroke(focus, forgeGold, 1.5)
focusStroke.Transparency = .2
local landFlash = Instance.new("Frame")
landFlash.Name = "LandFlash"
landFlash.Position = focus.Position
landFlash.Size = focus.Size
landFlash.BackgroundColor3 = Color3.new(1, 1, 1)
landFlash.BackgroundTransparency = 1
landFlash.BorderSizePixel = 0
landFlash.ZIndex = 9
landFlash.Parent = reelFrame
rounded(landFlash, 9)

local focusAura = Instance.new("Frame")
focusAura.Name = "MotionAura"
focusAura.Position = UDim2.new(.5, -81, 0, -4)
focusAura.Size = UDim2.fromOffset(162, 102)
focusAura.BackgroundTransparency = 1
focusAura.ZIndex = 7
focusAura.Parent = reelFrame
rounded(focusAura, 14)
local auraStroke = stroke(focusAura, forgeGold, 6)
auraStroke.Transparency = .94

local tapZone = Instance.new("TextButton")
tapZone.Name = "ChargeTapZone"
tapZone.Position = UDim2.fromScale(0, 0)
tapZone.Size = UDim2.fromScale(1, 1)
tapZone.BackgroundTransparency = 1
tapZone.Text = ""
tapZone.AutoButtonColor = false
tapZone.ZIndex = 10
tapZone.Parent = reelFrame

local resultBox = Instance.new("Frame")
resultBox.Name = "ResultBox"
resultBox.Position = UDim2.fromOffset(22, 287)
resultBox.Size = UDim2.fromOffset(556, 32)
resultBox.BackgroundColor3 = Color3.fromRGB(31,50,39)
resultBox.BorderSizePixel = 0
resultBox.Parent = panel
rounded(resultBox, 9)
local resultBoxStroke = stroke(resultBox, Color3.fromRGB(101,136,104), 1.4)

local resultLabel = makeLabel(panel, "Result", "PLACE YOUR ROCK TO BEGIN", UDim2.fromOffset(22, 289), UDim2.fromOffset(556, 27), 18, muted, true)
resultLabel.TextXAlignment = Enum.TextXAlignment.Center
resultLabel.AnchorPoint = Vector2.new(.5, .5)
resultLabel.Position = UDim2.fromOffset(300, 302.5)
local resultScale = Instance.new("UIScale")
resultScale.Parent = resultLabel
local rollButton = makeButton(panel, "Roll", rollPriceText(), UDim2.fromOffset(22, 325), UDim2.fromOffset(556, 52), Color3.fromRGB(223,171,65))
local footnote = makeLabel(panel, "Footnote", shardSummary(), UDim2.fromOffset(22, 379), UDim2.fromOffset(556, 17), 12, muted, false)
footnote.TextXAlignment = Enum.TextXAlignment.Center

local oddsButton = makeButton(panel, "OddsToggle", "TRAIT CHANCES", UDim2.fromOffset(405, 10), UDim2.fromOffset(128, 39), Color3.fromRGB(44,131,98))
oddsButton.TextSize = 15

local oddsPage = Instance.new("Frame")
oddsPage.Name = "OddsPage"
oddsPage.Position = UDim2.fromOffset(18, 64)
oddsPage.Size = UDim2.fromOffset(564, 329)
oddsPage.BackgroundColor3 = Color3.fromRGB(24,43,34)
oddsPage.BorderSizePixel = 0
oddsPage.Visible = false
oddsPage.Parent = panel
rounded(oddsPage, 12)
stroke(oddsPage, Color3.fromRGB(171,138,72), 1.5)
local oddsGradient = Instance.new("UIGradient")
oddsGradient.Color = ColorSequence.new(Color3.fromRGB(35,59,44), Color3.fromRGB(18,34,27))
oddsGradient.Rotation = 90
oddsGradient.Parent = oddsPage

makeLabel(oddsPage, "OddsTitle", "TRAIT ROLL ODDS", UDim2.fromOffset(16, 9), UDim2.fromOffset(530, 25), 21, pale, true)
makeLabel(oddsPage, "Summary",
	string.format("%d active outcomes  •  Text color shows rarity", #Traits.Results),
	UDim2.fromOffset(16, 37), UDim2.fromOffset(530, 20), 14, muted, false)
local oddsNote=makeLabel(oddsPage,"OddsNote","Odds rounded to 2 decimals",UDim2.fromOffset(302,9),UDim2.fromOffset(246,25),11,muted,false)
oddsNote.TextXAlignment=Enum.TextXAlignment.Right
makeLabel(oddsPage, "ResultHeading", "TRAIT RESULT", UDim2.fromOffset(24, 63), UDim2.fromOffset(350, 17), 12, muted, true)
local chanceHeading = makeLabel(oddsPage, "ChanceHeading", "CHANCE", UDim2.fromOffset(438, 63), UDim2.fromOffset(95, 17), 12, muted, true)
chanceHeading.TextXAlignment = Enum.TextXAlignment.Right

local oddsList = Instance.new("ScrollingFrame")
oddsList.Name = "OddsList"
oddsList.Position = UDim2.fromOffset(14, 84)
oddsList.Size = UDim2.fromOffset(536, 232)
oddsList.BackgroundTransparency = 1
oddsList.BorderSizePixel = 0
oddsList.ScrollBarThickness = 5
oddsList.ScrollBarImageColor3 = forgeGold
oddsList.ScrollingDirection = Enum.ScrollingDirection.Y
oddsList.CanvasSize = UDim2.fromOffset(0, 0)
oddsList.Parent = oddsPage

local oddsRowStride = 76
local rowIndex = 0
local function addOddsRow(labelText, rarity, percent, placeholder, traitId, description)
	rowIndex += 1
	local row = Instance.new("Frame")
	row.Name = "OddsRow" .. rowIndex
	row:SetAttribute("TraitRarity", rarity)
 row:SetAttribute("TraitId",traitId)
	row.Position = UDim2.fromOffset(2, (rowIndex - 1) * oddsRowStride)
	row.Size = UDim2.fromOffset(516, 72)
	row.BackgroundColor3 = placeholder and Color3.fromRGB(30,42,35) or (rowIndex % 2 == 0 and Color3.fromRGB(40,63,48) or Color3.fromRGB(32,54,42))
	row.BorderSizePixel = 0
	row.Parent = oddsList
	rounded(row, 7)
	stroke(row, placeholder and Color3.fromRGB(60,78,61) or Color3.fromRGB(67,109,78), 1)
	local name = makeLabel(row, "TraitName", labelText, UDim2.fromOffset(14, 4), UDim2.fromOffset(380, 28), 20, pale, true)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	TraitTextStyle.apply(name, labelText, rarity)
	local chance = makeLabel(row, "Chance", percent, UDim2.fromOffset(410, 4), UDim2.fromOffset(94, 28), 18, placeholder and muted or pale, true)
	chance.TextXAlignment = Enum.TextXAlignment.Right
 if description then makeLabel(row,"Description",description,UDim2.fromOffset(14,32),UDim2.fromOffset(490,34),16,muted,false) end
end

for _, result in Traits.Results do
	addOddsRow(string.upper(result.label), result.rarity, string.format("%.2f%%", Traits.chancePercent(result.id,workspace:GetAttribute("GlobalTraitLuckMultiplier"))), false, result.id, result.description)
end
for _, rarity in Traits.RarityOrder do
	if Traits.rarityChancePercent(rarity) == 0 then
		addOddsRow("NO TRAITS YET", rarity, "0%", true)
	end
end
oddsList.CanvasSize = UDim2.fromOffset(0, rowIndex * oddsRowStride)
local function refreshOdds()
 local luck=workspace:GetAttribute("GlobalTraitLuckMultiplier") or 1
 oddsPage.OddsTitle.Text=luck>1 and "TRAIT STORM ODDS" or "TRAIT ROLL ODDS"
 local rarities={} for _,rarity in ipairs(Traits.RarityOrder) do table.insert(rarities,string.format("%s %.2f%%",rarity,Traits.rarityChancePercent(rarity,luck))) end
 oddsPage.Summary.Text=table.concat(rarities," • ")
 for _,row in ipairs(oddsList:GetChildren()) do
  local id=row:GetAttribute("TraitId")
  if id then row.Chance.Text=string.format("%.2f%%",Traits.chancePercent(id,luck)) end
 end
end
workspace:GetAttributeChangedSignal("GlobalTraitLuckMultiplier"):Connect(refreshOdds)
refreshOdds()

local selectPage = Instance.new("Frame")
selectPage.Name = "SelectPage"
selectPage.Position = UDim2.fromOffset(18, 64)
selectPage.Size = UDim2.fromOffset(564, 329)
selectPage.BackgroundColor3 = Color3.fromRGB(24,43,34)
selectPage.BorderSizePixel = 0
selectPage.Visible = false
selectPage.Parent = panel
rounded(selectPage, 12)
stroke(selectPage, Color3.fromRGB(171,138,72), 1.5)
local selectGradient = Instance.new("UIGradient")
selectGradient.Color = ColorSequence.new(Color3.fromRGB(35,59,44), Color3.fromRGB(18,34,27))
selectGradient.Rotation = 90
selectGradient.Parent = selectPage
makeLabel(selectPage, "SelectTitle", "PICK A ROCK", UDim2.fromOffset(16, 9), UDim2.fromOffset(350, 25), 21, pale, true)
makeLabel(selectPage, "SelectSummary", "Choose the exact copy to receive the next trait", UDim2.fromOffset(16, 36), UDim2.fromOffset(455, 20), 13, muted, false)
local selectBack = makeButton(selectPage, "Back", "BACK", UDim2.fromOffset(472, 10), UDim2.fromOffset(75, 34), Color3.fromRGB(44,131,98))
selectBack.TextSize = 13
local selectList = Instance.new("ScrollingFrame")
selectList.Name = "RockList"
selectList.Position = UDim2.fromOffset(14, 66)
selectList.Size = UDim2.fromOffset(536, 250)
selectList.BackgroundTransparency = 1
selectList.BorderSizePixel = 0
selectList.ScrollBarThickness = 5
selectList.ScrollBarImageColor3 = forgeGold
selectList.ScrollingDirection = Enum.ScrollingDirection.Y
selectList.CanvasSize = UDim2.fromOffset(0, 0)
selectList.Parent = selectPage

TraitUI.mount(panel)
footnote.TextSize=14
footnote.Size=UDim2.fromOffset(556,18)
footnote.Position=UDim2.fromOffset(22,396)
local spinnerLighting = require(Shared:WaitForChild("TraitSpinnerLighting")).new(forge:WaitForChild("MythicalForge"))
local autoToggle,autoStart,autoBack
local autoUI=require(Shared:WaitForChild("TraitAutoRollUI")).new(panel,Traits,{
 toggle=function()if autoToggle then autoToggle()end end,
 start=function(target)if autoStart then autoStart(target)end end,
 back=function()if autoBack then autoBack()end end,
})
local confirmationUI = require(Shared:WaitForChild("TraitLegendaryConfirmation")).new(panel)
local Fade = require(Shared:WaitForChild("TraitForgeFade"))
local visualFade = Fade.new(worldRoot)
local resultFade = nil
local resultReveal = 0
local resultAnchor = nil
local defaultRollerOffset = gui.StudsOffsetWorldSpace
local targetRollerOffset = defaultRollerOffset
local sequenceProgress = 1
local sequenceDuration = .22
local function transitionTogether(duration)
 sequenceDuration = duration or .22
 sequenceProgress = 0
end

local selectedRockId = nil
local selectedCopy = "untraited"
local placedModel = nil
local placedHoverBase = nil
local placedHoverTime = 0
local placedBillboard = nil
local stageHidden = false
local state = "idle"
local autoActive=false
local autoTarget=nil
local autoGeneration=0
local autoRock,autoCopy
local autoCount=0
local autoMessage=nil
local queueAutoRoll
local function matchesTarget(trait)
 return trait and autoTarget and ((autoTarget.kind=="rarity" and trait.rarity==autoTarget.value)
  or (autoTarget.kind=="trait" and trait.id==autoTarget.value))
end
local function stopAutoRoll(message)
 autoGeneration+=1
 autoActive=false
 autoUI:setRunning(false)
 gui:SetAttribute("AutoRolling",false)
 gui:SetAttribute("AutoRollPaused",false)
 if message then autoMessage=message;footnote.Text=message end
 if state=="placed" or state=="done" then rollButton.Text=rollPriceText() end
end
local isOpen = false
local dismissedUntilExit = false
local revealProgress = 0
local closingState = nil
local inputEnabled = false
local spinConnection = nil
local charge = 0
local settledIndex = nil
local feedbackTweens = {}
local function feedbackTween(object, duration, properties)
	local tween = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	table.insert(feedbackTweens, tween)
	tween:Play()
	return tween
end
local spinAttachment = nil
local spinEmitter = nil
local spinLight = nil
local requestSerial = 0
local rollRequestedAt = 0
local confirmationPending = nil
local stopLegendaryFX = nil
local refreshSelectionPage
local sfxFolder = SoundService:WaitForChild("SFX")
local function localSfx(name, volume)
	local source = sfxFolder:WaitForChild(name)
	local sound = source:Clone()
	sound.Name = "TraitForge_" .. name
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end
local tickSfx = localSfx("UI_Hover_01", .14)
local chargeSfx = localSfx("UI_Click_01", .2)
local spinSfx = localSfx("UI_Menu_Open", .16)
local openSfx = localSfx("UI_Menu_Open", .3)
local closeSfx = localSfx("UI_Menu_Close", .25)
local rewardSfx = localSfx("SFX_Reward_Claimed", .58)
local function playSfx(sound, speed)
	sound:Stop()
	sound.TimePosition = 0
	sound.PlaybackSpeed = speed or 1
	sound:Play()
end
local function stopSpin(preservePresentation)
	spinnerLighting:reset()
	if stopLegendaryFX then stopLegendaryFX();stopLegendaryFX=nil end
	for _, tween in feedbackTweens do tween:Cancel() end
	table.clear(feedbackTweens)
	for _, item in reelFrame:GetChildren() do
		if item.Name == "SpinSpark" then item:Destroy() end
	end
	for _, sound in {tickSfx, chargeSfx, rewardSfx} do sound:Stop() end
	if not preservePresentation then
		landFlash.BackgroundTransparency = 1
		resultScale.Scale = 1
	end
	if spinConnection then spinConnection:Disconnect() spinConnection = nil end
	spinSfx:Stop()
	if spinAttachment then spinAttachment:Destroy() spinAttachment = nil end
	spinEmitter = nil
	spinLight = nil
	if not preservePresentation then
		auraStroke.Transparency = .94
		auraStroke.Thickness = 6
	end
end
local function setResultStatus(message, color)
	TraitTextStyle.clear(resultLabel)
	resultLabel.Text = message
	resultLabel.TextColor3 = color
	resultLabel.TextTransparency = 0
	resultScale.Scale = 1
end
local oddsOpen = false
local selectorOpen = false
local autoOpen=false
local forgeBody = {rockInfo, rockImage, rockGlyph, rockLabel, currentLabel, selectButton, placeButton, reelFrame, resultBox, resultLabel, rollButton, footnote}

local function showPage(page)
	local changed = oddsOpen ~= (page == "odds") or selectorOpen ~= (page == "select") or autoOpen ~= (page == "auto")
	if changed and isOpen then transitionTogether(.2) end
	autoOpen=page=="auto"
	autoUI:setVisible(autoOpen)
	oddsOpen = page == "odds"
	selectorOpen = page == "select"
	oddsPage.Visible = oddsOpen
	selectPage.Visible = selectorOpen
	for _, item in forgeBody do
		item.Visible = page == "forge" and (item ~= placeButton or state == "idle") and (item ~= rollButton or state ~= "idle") and (item ~= rockImage or rockImage.Image ~= "") and (item ~= rockGlyph or rockImage.Image == "")
	end
	oddsButton.Text = oddsOpen and "BACK" or "ODDS"
	if oddsOpen then oddsList.CanvasPosition = Vector2.new(0, 0) end
end
local function showOdds(openOdds) showPage(openOdds and "odds" or "forge") end
local function showSelector(openSelector) showPage(openSelector and "select" or "forge") end


local function setStageHidden(hidden)
	if stageHidden == hidden then return end
	stageHidden = hidden
	for _, part in {crystal, heart} do
		part.LocalTransparencyModifier = hidden and 1 or 0
	end
end

-- Measure world bounds instead of assuming every rock shares a pivot or height.
local function rockTop()
 if not placedModel then return nil end
 local low=Vector3.new(math.huge,math.huge,math.huge)
 local high=Vector3.new(-math.huge,-math.huge,-math.huge)
 local anchorPart=nil
 local parts=placedModel:IsA("BasePart") and {placedModel} or placedModel:GetDescendants()
 for _,part in parts do
  if part:IsA("BasePart") then
   anchorPart=anchorPart or part
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    local point=part.CFrame*Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2)
    low=low:Min(point);high=high:Max(point)
   end end end
  end
 end
 if not anchorPart then return nil end
 return Vector3.new((low.X+high.X)/2,high.Y,(low.Z+high.Z)/2),anchorPart
end

local function reserveResultSpace()
 local top=rockTop()
 if not top then return end
 local highestTop=top.Y
 if placedHoverBase and placedModel then
  highestTop=top.Y-placedModel:GetPivot().Position.Y+placedHoverBase.Position.Y+.12
 end
 local panelBottom=highestTop+.15+.45+.4
 targetRollerOffset=Vector3.new(0,math.max(defaultRollerOffset.Y,panelBottom-anvilFace.Position.Y+gui.Size.Y.Scale/2),0)
end

local function clearResultBillboard()
 if resultFade then resultFade:destroy();resultFade=nil end
 resultReveal=0
 if resultAnchor then resultAnchor:Destroy();resultAnchor=nil end
 if placedBillboard then placedBillboard:Destroy();placedBillboard=nil end
end

local function clearPreview()
	placedHoverBase=nil
	placedHoverTime=0
	targetRollerOffset=defaultRollerOffset
	clearResultBillboard()
	if placedModel then placedModel:Destroy() placedModel = nil end
	setStageHidden(false)
end

local function showTraitAboveRock(trait)
 if not placedModel then return end
 clearResultBillboard()
 local top,part=rockTop()
 if not top then return end
 reserveResultSpace()
 resultAnchor=Instance.new("Attachment")
 resultAnchor.Name="TraitResultAnchor"
 resultAnchor.Position=part.CFrame:PointToObjectSpace(top+Vector3.new(0,.15+.45/2,0))
 resultAnchor.Parent=part
 local billboard=Instance.new("BillboardGui")
 billboard.Name="TraitResult"
 -- Center over this rock, with a consistent gap above its highest point.
 billboard.Adornee=resultAnchor
 billboard.Size=UDim2.fromScale(3.3,.45)
 billboard.StudsOffsetWorldSpace=Vector3.zero
 billboard.AlwaysOnTop=false
 billboard.LightInfluence=0
 billboard.MaxDistance=0
 billboard.Parent=part
 local text=makeLabel(billboard,"TraitName",string.upper(trait.label),UDim2.fromScale(0,0),UDim2.fromScale(1,1),22,pale,true)
 text.TextScaled=true
 TraitTextStyle.apply(text,string.upper(trait.label),trait.rarity)
 text.TextXAlignment=Enum.TextXAlignment.Center
 text.TextStrokeColor3=Color3.new(0,0,0)
 text.TextStrokeTransparency=.15
 resultFade=Fade.new(billboard)
 resultReveal=0
 placedBillboard=billboard
end

local function placePreview(onSettled)
	clearPreview()
	local templateFolder = ReplicatedStorage:FindFirstChild("RockModels")
	local template = templateFolder and templateFolder:FindFirstChild(selectedRockId)
	local copy = (Store.get().traitedRocks or {})[selectedCopy]
	local rock = template and require(ReplicatedStorage.Shared.RockAppearance).apply(template:Clone(),selectedRockId,copy and copy.variant)
	if not rock then
		local fallback = Instance.new("Part")
		fallback.Name = "PlacedRock"
		fallback.Shape = Enum.PartType.Ball
		fallback.Size = Vector3.new(2, 2, 2)
		fallback.Material = Enum.Material.Slate
		fallback.Color = Rocks.get(selectedRockId).color
		rock = fallback
	end
	rock.Name = "PlacedTraitRock"
	for _, item in rock:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item.Disabled = true
		end
	end
	if rock:IsA("BasePart") then
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanTouch = false
		rock.CanQuery = false
	end
	if rock:IsA("Model") then
		local size = rock:GetExtentsSize()
		local longest = math.max(size.X, size.Y, size.Z)
		if longest > 0 then rock:ScaleTo(rock:GetScale() * (2.55 / longest)) end
	end
	rock.Parent = forge
	local height = rock:IsA("Model") and rock:GetExtentsSize().Y or rock.Size.Y
	local target = CFrame.new(crystal.Position.X, pedestal.Position.Y + pedestal.Size.Y / 2 + height / 2 + .4, crystal.Position.Z)
	setStageHidden(true)
	if rock:IsA("Model") then
		rock:PivotTo(target * CFrame.new(0, player:GetAttribute("ReducedMotion") and 0 or 1.2, 0))
	else
		rock.CFrame = target * CFrame.new(0, player:GetAttribute("ReducedMotion") and 0 or 1.2, 0)
	end
	placedModel = rock
	local motion = Instance.new("CFrameValue")
	motion.Value = rock:GetPivot()
	motion.Changed:Connect(function(value)
		if rock.Parent then rock:PivotTo(value) end
	end)
	local tween = TweenService:Create(motion, TweenInfo.new(.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = target})
	tween:Play()
	tween.Completed:Connect(function()
  motion:Destroy()
  if placedModel==rock and rock.Parent and isOpen and state=="placing" and onSettled then
   placedHoverBase=target
   placedHoverTime=0
   reserveResultSpace()
   onSettled()
  end
 end)
end

local reelPool={}
local function clearReel()
	settledIndex = nil
	for _, child in reelTrack:GetChildren() do
		if child:IsA("GuiObject") then
   child.Visible=false
   for _,label in child:GetChildren() do if label:IsA("TextLabel") then TraitTextStyle.clear(label) end end
  end
 end
 positionReel(0)
end

local cellWidth = 146
local function makeReelCard(index, result)
 local cached=reelPool[index]
 if cached then
  cached.Visible=true
  TraitTextStyle.apply(cached:FindFirstChild("Name"),string.upper(result.name),result.rarity)
  TraitTextStyle.apply(cached.Tier,string.upper(result.rarity),result.rarity)
  TraitUI.reelCard(cached,TraitTextStyle.color(result.rarity))
  return cached
 end
 local card = Instance.new("Frame")
	card.Name = "Result" .. index
	card.AnchorPoint = Vector2.new(.5, .5)
	card.Position = UDim2.fromOffset((index - .5) * cellWidth, 42)
	card.Size = UDim2.fromOffset(cellWidth - 7, 74)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BorderSizePixel = 0
	card.Parent = reelTrack
	rounded(card, 8)
	stroke(card, Color3.fromRGB(65,96,72), 1)
	local cardGradient = Instance.new("UIGradient")
	cardGradient.Color = ColorSequence.new(Color3.fromRGB(36,57,43), Color3.fromRGB(25,42,32))
	cardGradient.Rotation = 90
	cardGradient.Parent = card
	local title = makeLabel(card, "Name", string.upper(result.name), UDim2.fromOffset(6, 11), UDim2.fromOffset(cellWidth - 19, 27), 17, pale, true)
	TraitTextStyle.apply(title, string.upper(result.name), result.rarity)
	title.TextXAlignment = Enum.TextXAlignment.Center
 title.TextScaled=true
	local tier = makeLabel(card, "Tier", string.upper(result.rarity), UDim2.fromOffset(6, 39), UDim2.fromOffset(cellWidth - 19, 18), 13, pale, true)
	TraitTextStyle.apply(tier, string.upper(result.rarity), result.rarity)
	tier.TextXAlignment = Enum.TextXAlignment.Center
	TraitUI.reelCard(card, TraitTextStyle.color(result.rarity))
 reelPool[index]=card
	return card
end

local function selectionValid(rockId, copyId)
	if not rockId or not Rocks.exists(rockId) or not Store.ownsRock(rockId) then return false end
	if copyId == "untraited" then return Store.untraitedRockCount(rockId) > 0 end
	local copy = (Store.get().traitedRocks or {})[copyId]
	return copy ~= nil and copy.rockId == rockId
end

local function defaultSelection()
	local profile = Store.get()
	local equippedCopy = profile.rockEquippedInstance or "untraited"
	if selectionValid(profile.rockEquipped, equippedCopy) then return profile.rockEquipped, equippedCopy end
	for _, rockId in profile.rocksOwned or {} do
		if selectionValid(rockId, "untraited") then return rockId, "untraited" end
	end
	for copyId, copy in profile.traitedRocks or {} do
		if selectionValid(copy.rockId, copyId) then return copy.rockId, copyId end
	end
	return nil, "untraited"
end

local function updateRockHeader()
	TraitTextStyle.clear(currentLabel)
	if not selectedRockId then
		rockImage.Image = ""
		rockImage.Visible = false
		rockGlyph.Visible = true
		rockLabel.Text = "NO ROCK SELECTED"
		currentLabel.Text = "CHOOSE A ROCK FROM YOUR INVENTORY"
		currentLabel.TextColor3 = muted
		return
	end
 local models=ReplicatedStorage:FindFirstChild("RockModels")
 local template=models and models:FindFirstChild(selectedRockId)
 if template and not template:GetAttribute("ForgePreloadQueued") then
  template:SetAttribute("ForgePreloadQueued",true)
  task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({template}) end) end)
 end
 local rock = Rocks.get(selectedRockId)
 rockImage.Image = rock.image or ""
	rockImage.Visible = rockImage.Image ~= ""
	rockGlyph.Visible = not rockImage.Visible
	rockLabel.Text = ((Store.get().traitedRocks or {})[selectedCopy] and (Store.get().traitedRocks or {})[selectedCopy].variant == "Enchanted" and "ENCHANTED " or "") .. string.upper(rock.name)
	local copy = (Store.get().traitedRocks or {})[selectedCopy]
	local trait = copy and Traits.get(copy.traitId) or nil
	if trait then
		TraitTextStyle.apply(currentLabel, "CURRENT TRAIT: " .. string.upper(trait.label), trait.rarity)
	else
		currentLabel.Text = "CURRENT TRAIT: NONE"
		currentLabel.TextColor3 = muted
	end
end

local function setIdleReel()
	clearReel()
	local preview = {Traits.Results[2], Traits.Results[5], Traits.Results[8], Traits.Results[1], Traits.Results[6]}
	for i, result in preview do makeReelCard(i, result) end
	reelTrack.Size = UDim2.fromOffset(#preview * cellWidth, 84)
	positionReel(cellWidth * 2.5 - 548 / 2)
end

local rockRanks = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythical = 6, Exclusive = 7}
refreshSelectionPage = function()
	for _, child in selectList:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local profile = Store.get()
	local choices = {}
	for _, rock in Rocks.Rocks do
		if Store.ownsRock(rock.id) then
			local count = Store.untraitedRockCount(rock.id)
			if count > 0 then
				table.insert(choices, {rock = rock, copyId = "untraited", count = count})
			end
		end
	end
	for copyId, copy in profile.traitedRocks or {} do
		if Rocks.exists(copy.rockId) and Store.ownsRock(copy.rockId) then
			table.insert(choices, {rock = Rocks.get(copy.rockId), copyId = copyId, traitId = copy.traitId, variant = copy.variant, count = 1})
		end
	end
	table.sort(choices, function(a, b)
		local rankA, rankB = rockRanks[a.rock.rarity] or 0, rockRanks[b.rock.rarity] or 0
		if rankA ~= rankB then return rankA > rankB end
		if a.rock.name ~= b.rock.name then return a.rock.name < b.rock.name end
		if (a.traitId ~= nil) ~= (b.traitId ~= nil) then return a.traitId ~= nil end
		return a.copyId < b.copyId
	end)
	if #choices == 0 then
		local empty = makeLabel(selectList, "Empty", "NO ROCKS AVAILABLE", UDim2.fromOffset(8, 65), UDim2.fromOffset(510, 56), 20, muted, true)
		empty.TextXAlignment = Enum.TextXAlignment.Center
	end
	for index, choice in choices do
		local row = Instance.new("TextButton")
		row.Name = "RockChoice" .. index
		row:SetAttribute("RockId", choice.rock.id)
		row:SetAttribute("CopyId", choice.copyId)
		row.Text = ""
		row.AutoButtonColor = false
		row.Position = UDim2.fromOffset(2, (index - 1) * 60)
		row.Size = UDim2.fromOffset(516, 55)
		row.BackgroundColor3 = choice.rock.color:Lerp(Color3.fromRGB(29, 37, 62), .78)
		row.BorderSizePixel = 0
		row.Parent = selectList
		rounded(row, 9)
		local picked = selectedRockId == choice.rock.id and selectedCopy == choice.copyId
		stroke(row, picked and Color3.fromRGB(255,221,139) or Color3.fromRGB(71,104,80), picked and 2.4 or 1)
		local image = Instance.new("ImageLabel")
		image.Name = "RockImage"
		image.Position = UDim2.fromOffset(8, 6)
		image.Size = UDim2.fromOffset(43, 43)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = choice.rock.image or ""
		image.Parent = row
		if image.Image == "" then
			local icon = makeLabel(row, "RockIcon", "◆", UDim2.fromOffset(8, 6), UDim2.fromOffset(43, 43), 28, choice.rock.color, true)
			icon.TextXAlignment = Enum.TextXAlignment.Center
		end
		local name = makeLabel(row, "RockName", (choice.variant == "Enchanted" and "ENCHANTED " or "") .. string.upper(choice.rock.name), UDim2.fromOffset(61, 5), UDim2.fromOffset(300, 25), 16, pale, true)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local trait = choice.traitId and Traits.get(choice.traitId) or nil
		local traitText = makeLabel(row, "Trait", trait and string.upper(trait.label) or "NO TRAIT", UDim2.fromOffset(61, 29), UDim2.fromOffset(300, 20), 13, muted, true)
		if trait then TraitTextStyle.apply(traitText, string.upper(trait.label), trait.rarity) end
		local equipped = profile.rockEquipped == choice.rock.id and (profile.rockEquippedInstance or "untraited") == choice.copyId
		local tag = equipped and "EQUIPPED" or (choice.copyId == "untraited" and "×" .. choice.count or (choice.variant == "Enchanted" and "ENCHANTED" or choice.traitId and "TRAITED" or "MASTERED"))
		local status = makeLabel(row, "Status", tag, UDim2.fromOffset(384, 13), UDim2.fromOffset(120, 28), 12, equipped and Color3.fromRGB(255, 220, 121) or muted, true)
		status.TextXAlignment = Enum.TextXAlignment.Right
		TraitUI.selectionRow(row, picked, choice.rock.color)
		row.Activated:Connect(function()
			if state == "waiting" or state == "spinning" then return end
			if not selectionValid(choice.rock.id, choice.copyId) then refreshSelectionPage() return end
			clearPreview()
			selectedRockId, selectedCopy = choice.rock.id, choice.copyId
			state = "idle"
			prompt.ActionText = "PLACE ROCK"
			placeButton.Text = "PLACE SELECTED ROCK"
			TraitUI.placeReady(placeButton, true)
			rollButton.Text = "PLACE ROCK FIRST"
			rollButton.BackgroundColor3 = Color3.fromRGB(61,71,62)
			setResultStatus("PLACE YOUR ROCK TO BEGIN", muted)
			updateRockHeader()
			setIdleReel()
			showSelector(false)
		end)
	end
	selectList.CanvasSize = UDim2.fromOffset(0, math.max(250, #choices * 60))
	selectList.CanvasPosition = Vector2.new(0, 0)
end

local function close(manual)
	if not isOpen then return end
	stopAutoRoll("AUTO-ROLL STOPPED")
	confirmationPending = nil
	isOpen = false
	gui:SetAttribute("SpinState", "closed")
	gui.Active = false
	-- Invalidate a pending choice while preserving the shared exit fade.
	confirmationUI:invalidate()
	if manual then dismissedUntilExit = true playSfx(closeSfx) end
	requestSerial += 1
	-- Stop gameplay immediately, but preserve the visible page/result through the exit.
	closingState = state == "confirming" and "placed" or state
	stopSpin(true)
	state = "closing"
end

local function open()
	if isOpen then return end
	autoMessage=nil
	confirmationUI:hide()
	confirmationPending = nil
	if revealProgress > 0 and closingState and closingState ~= "waiting" and closingState ~= "spinning" and closingState ~= "placing" then
		state = closingState
		closingState = nil
		gui.Enabled = true
		isOpen = true
		return
	end
	if not Store.hasLoaded() then
		return
	end
	closingState = nil
	clearPreview()
	selectedRockId, selectedCopy = defaultSelection()
	state = "idle"
	placeButton.Visible = true
	focusStroke.Color = forgeGold
	focusStroke.Transparency = .2
	focusStroke.Thickness = 1.5
	landFlash.BackgroundTransparency = 1
	auraStroke.Transparency = .94
	auraStroke.Color = forgeGold
	marker.BackgroundColor3 = forgeGold
	bottomMarker.BackgroundColor3 = marker.BackgroundColor3
	footnote.Text = shardSummary()
	rollButton.BackgroundColor3 = Color3.fromRGB(61,71,62)
	rollButton.Text = "PLACE ROCK FIRST"
	setResultStatus("PLACE YOUR ROCK TO BEGIN", muted)
	if selectedRockId then
		placeButton.Text = "PLACE SELECTED ROCK"
		TraitUI.placeReady(placeButton, true)
		updateRockHeader()
	else
		updateRockHeader()
		placeButton.Text = "CHOOSE A ROCK FIRST"
		TraitUI.placeReady(placeButton, false)
		rollButton.Text = "CHOOSE A ROCK FIRST"
		setResultStatus("PICK A ROCK TO USE THE FORGE", muted)
	end
	setIdleReel()
	showOdds(false)
	gui.Enabled = true
	isOpen = true
	playSfx(openSfx)
end

local function stationDistance()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return math.huge end
	return (root.Position - crystal.Position).Magnitude
end

local proximityConnection = RunService.Heartbeat:Connect(function()
	local distance = stationDistance()
	local nearby = prompt.Enabled and distance <= prompt.MaxActivationDistance
	if nearby then
		if not dismissedUntilExit and not isOpen then open() end
	else
		if distance > prompt.MaxActivationDistance then dismissedUntilExit = false end
		if isOpen then close(false) end
	end
end)

local renderBinding = "TraitForgeWorldUI"
-- Run after camera updates and project one fixed canvas for every descendant.
RunService:BindToRenderStep(renderBinding, Enum.RenderPriority.Last.Value - 1, function(dt)
 spinnerLighting:update(dt, stationDistance() < 75, state, player:GetAttribute("ReducedMotion") == true)
 if placedHoverBase and placedModel and placedModel.Parent then
  local pose=placedHoverBase
  if player:GetAttribute("ReducedMotion")~=true then
   placedHoverTime+=dt
   pose=placedHoverBase*CFrame.new(0,math.sin(placedHoverTime*1.65)*.12,0)*CFrame.Angles(0,placedHoverTime*.24,0)
  end
  placedModel:PivotTo(pose)
  if resultAnchor and resultAnchor.Parent then
   local top=rockTop()
   if top then
    resultAnchor.Position=resultAnchor.Parent.CFrame:PointToObjectSpace(top+Vector3.new(0,.15+.45/2,0))
   end
  end
 end
 gui.StudsOffsetWorldSpace=gui.StudsOffsetWorldSpace:Lerp(targetRollerOffset,1-math.exp(-dt*14))
	if not isOpen and revealProgress == 0 then
		gui.Enabled = false
		gui.Active = false
		worldRoot.Visible = false
		if closingState then
			clearPreview()
			closingState = nil
			state = "idle"
			prompt.ActionText = "PLACE ROCK"
			showOdds(false)
		end
		return
	end
	gui.Enabled = true
	revealProgress = math.clamp(revealProgress + (isOpen and 1 or -1) * dt / (isOpen and .55 or .4), 0, 1)
	local opacity = revealProgress * revealProgress * (3 - 2 * revealProgress)
	local reduced = player:GetAttribute("ReducedMotion") == true
 sequenceProgress=math.min(1,sequenceProgress+dt/sequenceDuration)
 local sequenceEase=sequenceProgress*sequenceProgress*(3-2*sequenceProgress)
 local sharedOpacity=opacity*(.65+.35*sequenceEase)
 visualFade:setOpacity(sharedOpacity)
 if resultFade and placedBillboard then
  if isOpen then resultReveal=math.min(1,resultReveal+dt/.24) end
  local resultEase=resultReveal*resultReveal*(3-2*resultReveal)
  resultFade:setOpacity(sharedOpacity*resultEase)
  placedBillboard.Enabled=gui.Enabled
  placedBillboard.StudsOffsetWorldSpace=Vector3.new(0,-(reduced and 0 or (1-opacity)*.18),0)
 end
	-- The engine anchors the BillboardGui. Use this frame's camera projection
	-- only to size its ONE design canvas; AbsoluteSize can still be last frame's.
	worldRoot.Visible = true
	local camera = workspace.CurrentCamera
	if camera then
		local center = anvilFace.Position + gui.StudsOffsetWorldSpace
		local halfWidth = camera.CFrame.RightVector * (gui.Size.X.Scale / 2)
		local halfHeight = camera.CFrame.UpVector * (gui.Size.Y.Scale / 2)
		local left = camera:WorldToViewportPoint(center - halfWidth)
		local right = camera:WorldToViewportPoint(center + halfWidth)
		local bottom = camera:WorldToViewportPoint(center - halfHeight)
		local top = camera:WorldToViewportPoint(center + halfHeight)
		local fitted = math.max(.001, math.min(math.abs(right.X-left.X)/624, math.abs(bottom.Y-top.Y)/450))
		scale.Scale = fitted * (reduced and 1 or .985 + .015 * sequenceEase)
		local offset = reduced and 0 or (1-opacity)*18 + (1-sequenceEase)*5
		worldRoot.Position = UDim2.new(.5, 0, .5, offset * scale.Scale)
	end
	if state == "idle" or (state == "done" and settledIndex) then
		local center = state == "done" and (settledIndex - .5) or 2.5
		positionReel(cellWidth * center - 548 / 2)
	end
	local interactive = isOpen and revealProgress > 0
	gui.Active = interactive
	worldRoot.Active = interactive
	if inputEnabled ~= interactive then
		inputEnabled = interactive
		for _, control in panel:GetDescendants() do
			if control:IsA("GuiButton") then
				control.Active = interactive
				control.Selectable = interactive and control ~= tapZone
			end
		end
	end
end)

script.Destroying:Connect(function()
	stopAutoRoll()
	requestSerial += 1
	stopSpin()
	clearPreview()
	proximityConnection:Disconnect()
	RunService:UnbindFromRenderStep(renderBinding)
	visualFade:destroy()
	spinnerLighting:destroy()
	ContextActionService:UnbindAction("TraitForgeInteract")
	gui:Destroy()
	for _, sound in {tickSfx, chargeSfx, spinSfx, openSfx, closeSfx, rewardSfx} do sound:Destroy() end
end)

-- Integrated smoothstep velocity: starts at rest, accelerates, then brakes to rest.
-- Position and velocity stay continuous at both phase boundaries.
local function spinProgress(t)
	local acceleration, cruise, braking = .18, .12, .70
	local riseArea = acceleration * .5
	local totalArea = riseArea + cruise + braking * .5
	if t < acceleration then
		local u = math.clamp(t / acceleration, 0, 1)
		return acceleration * (u^3 - .5 * u^4) / totalArea
	elseif t < acceleration + cruise then
		return (riseArea + t - acceleration) / totalArea
	end
	local u = math.clamp((t - acceleration - cruise) / braking, 0, 1)
	return (riseArea + cruise + braking * (u - u^3 + .5 * u^4)) / totalArea
end

local function emitUiSparks(color, count, trailing)
	if trailing then return end -- No moving streak or underline beneath the reel.
	if player:GetAttribute("ReducedMotion") == true then return end
	for _ = 1, count do
		local spark = Instance.new("Frame")
		spark.Name = "SpinSpark"
		spark.AnchorPoint = Vector2.new(.5, .5)
		local y = trailing and (math.random() < .5 and 8 or 86) or 47
		spark.Position = UDim2.fromOffset(278, y)
		spark.Size = trailing and UDim2.fromOffset(math.random(12, 24), 2) or UDim2.fromOffset(3, 3)
		spark.BackgroundColor3 = color
		spark.BackgroundTransparency = .18
		spark.BorderSizePixel = 0
		spark.ZIndex = 9
		spark.Parent = reelFrame
		rounded(spark, 3)
		local angle = math.random() * math.pi * 2
		local radius = math.random(30, 65)
		TweenService:Create(spark, TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = trailing and UDim2.fromOffset(185 - math.random(0, 45), y) or UDim2.fromOffset(278 + math.cos(angle) * radius, 47 + math.sin(angle) * radius * .45),
			Size = UDim2.fromOffset(1, 1),
			BackgroundTransparency = 1,
		}):Play()
		Debris:AddItem(spark, .32)
	end
end

local function startForgeMotion()
	if not placedModel then return end
	local part = placedModel:IsA("Model") and placedModel:FindFirstChildWhichIsA("BasePart", true) or placedModel
	if not part then return end
	spinAttachment = Instance.new("Attachment")
	spinAttachment.Name = "TraitSpinEnergy"
	spinAttachment.Parent = part
	spinEmitter = Instance.new("ParticleEmitter")
	spinEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spinEmitter.Rate = 0
	spinEmitter.Lifetime = NumberRange.new(.18, .38)
	spinEmitter.Speed = NumberRange.new(1, 2.5)
	spinEmitter.SpreadAngle = Vector2.new(180, 180)
	spinEmitter.Color = ColorSequence.new(forgeGold)
	spinEmitter.LightEmission = .65
	spinEmitter.Size = NumberSequence.new(.13, 0)
	spinEmitter.Transparency = NumberSequence.new(.15, 1)
	spinEmitter.Parent = spinAttachment
	spinLight = Instance.new("PointLight")
	spinLight.Color = forgeGold
	spinLight.Range = 8
	spinLight.Brightness = .2
	spinLight.Parent = spinAttachment
end

local function finishForgeMotion(color, rarityRank)
	if not spinAttachment then return end
	local reduced = player:GetAttribute("ReducedMotion") == true
	spinEmitter.Rate = 0
	spinEmitter.Color = ColorSequence.new(color)
	if not reduced then spinEmitter:Emit(8 + rarityRank * 4) end
	spinLight.Color = color
	spinLight.Brightness = reduced and .5 or 1.6 + rarityRank * .3
	feedbackTween(spinLight, .4, {Brightness = 0})
	-- Keep the reference until the next spin/close so cancellation also clears the payoff.
	Debris:AddItem(spinAttachment, .6)
end

local function chargePulse()
	if not isOpen or oddsOpen or selectorOpen or autoOpen or autoActive or state ~= "spinning" or charge >= 1 then return end
	if player:GetAttribute("ReducedMotion") == true then return end
	charge = 1
	spinnerLighting:tap()
	rollButton.Text = "REVEALING..."
	playSfx(chargeSfx, 1.12)
	emitUiSparks(forgeGold, 5, true)
end
tapZone.Activated:Connect(chargePulse)

local function reveal(traitId)
 local setupAt=os.clock()
 debug.profilebegin("TraitForge.RevealSetup")
	local result = Traits.get(traitId)
	if not result then
		state = "placed"
		rollButton.Text = rollPriceText()
		rollButton.BackgroundColor3 = Color3.fromRGB(223,171,65)
		setResultStatus("TRY AGAIN", muted)
  debug.profileend()
		return
	end
	stopSpin()
	state = "spinning"
	charge = 0
	clearResultBillboard()
	clearReel()
	local reduced = player:GetAttribute("ReducedMotion") == true
	local count, targetIndex = 19, 15
	local targetCard
	for i = 1, count do
		local outcome = if i == targetIndex then result else Traits.Results[math.random(1, #Traits.Results)]
		local card = makeReelCard(i, outcome)
		if i == targetIndex then targetCard = card end
	end
	reelTrack.Size = UDim2.fromOffset(count * cellWidth, 84)
	positionReel(0)
	setResultStatus("FORGING YOUR TRAIT", pale)
	footnote.Text = autoActive and ("AUTO-ROLL • "..string.upper(autoTarget.label).." • "..autoCount.." ROLLS") or "Your trait is on its way"
	focusStroke.Color = forgeGold
	focusStroke.Transparency = .25
	focusStroke.Thickness = 1.5
	auraStroke.Color = forgeGold
	marker.BackgroundColor3 = forgeGold
	bottomMarker.BackgroundColor3 = forgeGold
	reelStroke.Color = Color3.fromRGB(173,141,73)
	resultBoxStroke.Color = Color3.fromRGB(101,136,104)
	landFlash.BackgroundTransparency = 1
	rollButton.Text = autoActive and "STOP AUTO" or (reduced and "REVEALING..." or "REVEAL FASTER")
	rollButton.BackgroundColor3 = Color3.fromRGB(98,91,59)
	startForgeMotion()
	playSfx(spinSfx, 1.25)
	local function destination()
		return math.max(0, (targetIndex - .5) * cellWidth - 548 / 2)
	end
	local serial = requestSerial
	local duration = reduced and REDUCED_SPIN_SECONDS or SPIN_SECONDS
	local elapsed, realElapsed, rate = 0, 0, 1
	local lastProgress, lastCentered, lastTickAt = 0, 0, -1
	local focusPulse, trailClock = 0, 0
	local started = os.clock()
 gui:SetAttribute("RevealSetupMs",(os.clock()-setupAt)*1000)
 gui:SetAttribute("ReelPoolCount",#reelPool)
 debug.profileend()
 gui:SetAttribute("SpinState", "spinning")
	spinConnection = RunService.RenderStepped:Connect(function(dt)
		if serial ~= requestSerial or not isOpen then stopSpin() return end
		realElapsed += dt
		-- One optional press speeds time up smoothly; it never changes the server result.
		rate += ((charge == 1 and 1.65 or 1) - rate) * (1 - math.exp(-dt * 12))
		elapsed = math.min(elapsed + dt * rate, duration)
		local t = elapsed / duration
		local progress = spinProgress(t)
		local motion = math.clamp((progress - lastProgress) / math.max(dt, .001) / 1.65, 0, 1)
		lastProgress = progress
		spinnerLighting:setSpeed(motion)
		local x = destination() * progress
		if not reduced then positionReel(x) end
		focusPulse = math.max(0, focusPulse - dt * 8)
		focusStroke.Transparency = reduced and .25 or .3 - motion * .12 - focusPulse * .12
		focusStroke.Thickness = reduced and 1.5 or 1.5 + motion * .5 + focusPulse * .35
		auraStroke.Transparency = reduced and .96 or .96 - motion * .2 - focusPulse * .08
		auraStroke.Thickness = 4 + motion * 2
		if spinEmitter then spinEmitter.Rate = reduced and 0 or motion * 18 end
		if spinLight then spinLight.Brightness = reduced and .2 or .25 + motion * 1.2 + focusPulse * .3 end
		if not reduced then
			local centered = math.clamp(math.floor((x + 548 / 2) / cellWidth) + 1, 1, count)
			if centered ~= lastCentered then
				lastCentered = centered
				focusPulse = 1
				if realElapsed - lastTickAt >= .065 then
					lastTickAt = realElapsed
					tickSfx.Volume = .09 + .05 * (1 - motion)
					playSfx(tickSfx, .88 + motion * .42)
				end
			end
			trailClock += dt
			if motion > .3 and trailClock >= .09 then
				trailClock = 0
				emitUiSparks(forgeGold, 1, true)
			end
		end
		if elapsed < duration then return end
		spinConnection:Disconnect()
		spinConnection = nil
		spinSfx:Stop()
		tickSfx:Stop()
		positionReel(destination())
		settledIndex = targetIndex
		state = "done"
		transitionTogether(.24)
		gui:SetAttribute("SpinState", "done")
		gui:SetAttribute("LastSpinSeconds", os.clock() - started)
		gui:SetAttribute("LastTraitId", result.id)
		local resultColor = TraitTextStyle.color(result.rarity)
		local rarityRank = table.find(Traits.RarityOrder, result.rarity) or 1
		spinnerLighting:land(resultColor, rarityRank)
		footnote.Text = result.description or shardSummary()
		local targetStroke = targetCard:FindFirstChildOfClass("UIStroke")
		targetStroke.Color = resultColor
		targetStroke.Thickness = 1.6
		reelStroke.Color = resultColor:Lerp(deepStone, .45)
		resultBoxStroke.Color = resultColor:Lerp(deepStone, .3)
		focusStroke.Color = resultColor
		focusStroke.Thickness = reduced and 1.5 or 2.5
		auraStroke.Color = resultColor
		auraStroke.Transparency = reduced and .94 or .6
		feedbackTween(auraStroke, .3, {Transparency = .9, Thickness = 4})
		feedbackTween(focusStroke, .24, {Thickness = 1.5, Transparency = .18})
		marker.BackgroundColor3 = resultColor
		bottomMarker.BackgroundColor3 = resultColor
		landFlash.BackgroundColor3 = resultColor
		landFlash.BackgroundTransparency = reduced and 1 or .7
		feedbackTween(landFlash, .24, {BackgroundTransparency = 1})
		TraitTextStyle.apply(resultLabel, string.upper(result.label) .. "  •  " .. string.upper(result.rarity), result.rarity)
		resultLabel.TextStrokeTransparency = .15
		resultLabel.TextTransparency = 0
		resultScale.Scale = 1
		rollButton.Text = rollPriceText()
		rollButton.BackgroundColor3 = Color3.fromRGB(223,171,65)
		if result.rarity == "Legendary" then
			stopLegendaryFX = LegendaryFX.play(placedModel, reelFrame, reduced)
		else
			playSfx(rewardSfx, 1.08 - rarityRank * .035)
		end
		emitUiSparks(resultColor, 5 + rarityRank * 2)
		finishForgeMotion(resultColor, rarityRank)
		updateRockHeader()
		showTraitAboveRock(result)
		if autoActive then
			rollButton.Text="STOP AUTO"
			footnote.Text="AUTO-ROLL • "..string.upper(autoTarget.label).." • "..autoCount.." ROLLS"
			queueAutoRoll(.24)
		elseif autoMessage then footnote.Text=autoMessage end
	end)
end

local function placeAction()
 if not isOpen or oddsOpen or selectorOpen or autoOpen or stationDistance()>prompt.MaxActivationDistance or state~="idle" then return end
 if not selectedRockId or not Store.ownsRock(selectedRockId) then return end
 playSfx(tickSfx,.9)
 state="placing"
 gui:SetAttribute("SpinState","placing")
 transitionTogether(.28)
 rollButton.Text="PLACING ROCK..."
 setResultStatus("PLACING YOUR ROCK",pale)
 showPage("forge")
 placePreview(function()
  state="placed"
  gui:SetAttribute("SpinState","placed")
  rollButton.Text=rollPriceText()
  setResultStatus("YOUR ROCK IS IN THE FORGE",pale)
  prompt.ActionText="REROLL TRAIT"
  if autoActive then rollButton.Text="STOP AUTO";queueAutoRoll(.08) end
 end)
end
placeButton.Activated:Connect(placeAction)

local function requestRoll(confirmationToken)
	if not isOpen or oddsOpen or selectorOpen or autoOpen or stationDistance() > prompt.MaxActivationDistance then return end
	if autoActive and (selectedRockId~=autoRock or selectedCopy~=autoCopy) then stopAutoRoll("AUTO-ROLL STOPPED • ROCK CHANGED");return end
	if state == "spinning" then chargePulse() return end
	if state ~= "placed" and state ~= "done" then return end
	if not placedModel then return end
 if (Store.get().traitShards or 0)<Traits.RollCost then
  stopAutoRoll("AUTO-ROLL STOPPED • NOT ENOUGH SHARDS")
  setResultStatus("NEED "..Traits.RollCost.." TRAIT SHARDS",Color3.fromRGB(255,178,125))
  footnote.Text=shardSummary()
  return
 end
 stopSpin()
 playSfx(chargeSfx, 1)
	state = "waiting"
	transitionTogether(.16)
	gui:SetAttribute("SpinState", "waiting")
	landFlash.BackgroundColor3 = forgeGold
	landFlash.BackgroundTransparency = .86
	feedbackTween(landFlash, .16, {BackgroundTransparency = 1})
	clearResultBillboard()
	rollButton.Text = autoActive and "STOP AUTO" or "ROLLING..."
	rollButton.BackgroundColor3 = Color3.fromRGB(61,71,62)
	setResultStatus("CHOOSING YOUR TRAIT...", pale)
	requestSerial += 1
 rollRequestedAt=os.clock()
	Remotes.TraitRollRequest:FireServer(selectedRockId, selectedCopy, requestSerial, confirmationToken)
	local serial = requestSerial
	task.delay(8, function()
		if requestSerial == serial and state == "waiting" then
			stopAutoRoll("AUTO-ROLL STOPPED • NO RESPONSE")
			state = "placed"
			rollButton.Text = rollPriceText()
			rollButton.BackgroundColor3 = Color3.fromRGB(223,171,65)
			setResultStatus("NO RESPONSE. TRY AGAIN.", Color3.fromRGB(255, 125, 125))
		end
	end)
end
queueAutoRoll=function(delay)
 local generation=autoGeneration
 task.delay(delay,function()
  if not autoActive or generation~=autoGeneration then return end
  if not isOpen or stationDistance()>prompt.MaxActivationDistance or selectedRockId~=autoRock or selectedCopy~=autoCopy then
   stopAutoRoll("AUTO-ROLL STOPPED");return
  end
  if state~="placed" and state~="done" then return end
  requestRoll(nil)
 end)
end
local function rollAction()
 if autoActive then stopAutoRoll("AUTO-ROLL STOPPED");return end
 requestRoll(nil)
end
rollButton.Activated:Connect(rollAction)

local function cancelConfirmation()
	if state ~= "confirming" then return end
	if autoActive then stopAutoRoll("AUTO-ROLL STOPPED • LEGENDARY KEPT") end
	confirmationPending = nil
	confirmationUI:hide()
	transitionTogether(.2)
	state = "placed"
	rollButton.Text = rollPriceText()
	setResultStatus("LEGENDARY KEPT", Color3.fromRGB(255,218,120))
end

local function showLegendaryConfirmation(payload)
	local trait = Traits.get(payload.traitId)
	if not trait or trait.rarity ~= "Legendary" or typeof(payload.confirmationToken) ~= "string"
		or payload.rockId ~= selectedRockId or payload.instanceId ~= selectedCopy then
		stopAutoRoll("AUTO-ROLL STOPPED • ROCK CHANGED")
		state = "placed"
		setResultStatus("ROCK CHANGED. TRY AGAIN.", muted)
		return
	end
	stopSpin()
	state = "confirming"
	transitionTogether(.2)
	gui:SetAttribute("SpinState", "confirming")
	gui:SetAttribute("AutoRollPaused",autoActive)
	local pending = {token=payload.confirmationToken, rockId=selectedRockId, copyId=selectedCopy}
	confirmationPending = pending
	confirmationUI:show(trait.label, Rocks.get(selectedRockId).name, function()
		if confirmationPending ~= pending or not isOpen or state ~= "confirming"
			or stationDistance() > prompt.MaxActivationDistance
			or selectedRockId ~= pending.rockId or selectedCopy ~= pending.copyId then return end
		confirmationPending = nil
		gui:SetAttribute("AutoRollPaused",false)
		state = "placed"
		requestRoll(pending.token)
	end, cancelConfirmation)
	panel.LegendaryConfirmation.Subtitle.Text=autoActive and "Auto-roll paused to protect your legendary." or "You've forged something special."
end

Remotes.TraitRollResult.OnClientEvent:Connect(function(payload)
	if state ~= "waiting" or not isOpen then return end
	if typeof(payload) ~= "table" or payload.requestId ~= requestSerial then return end
 gui:SetAttribute("RollResponseMs",(os.clock()-rollRequestedAt)*1000)
	if payload.requiresConfirmation then showLegendaryConfirmation(payload);return end
	if not payload.ok then
		stopAutoRoll("AUTO-ROLL STOPPED • ROLL FAILED")
		state = "placed"
		rollButton.Text = rollPriceText()
		rollButton.BackgroundColor3 = Color3.fromRGB(223,171,65)
		setResultStatus(typeof(payload) == "table" and tostring(payload.message or "ROLL FAILED") or "ROLL FAILED", Color3.fromRGB(255, 125, 125))
		return
	end
	if payload.rockId ~= selectedRockId or typeof(payload.instanceId) ~= "string" then
  stopAutoRoll("AUTO-ROLL STOPPED • ROCK CHANGED");state="placed";return
 end
 local outcome=Traits.get(payload.traitId)
 if not outcome then stopAutoRoll("AUTO-ROLL STOPPED • UNKNOWN TRAIT");state="placed";return end
 selectedCopy=payload.instanceId
 if autoActive then
  autoCopy=selectedCopy
  autoCount+=1
  gui:SetAttribute("AutoRollCount",autoCount)
  if matchesTarget(outcome) then stopAutoRoll("TARGET FOUND • "..string.upper(outcome.label)) end
 end
 reveal(payload.traitId)
end)

autoBack=function()showPage("forge")end
autoToggle=function()
 if autoActive then
  stopAutoRoll("AUTO-ROLL STOPPED")
  if state=="confirming" then confirmationUI:cancel()end
  return
 end
 if not isOpen or state=="waiting" or state=="spinning" or state=="placing" or state=="confirming" then return end
 showPage(autoOpen and "forge" or "auto")
end
autoStart=function(target)
 if not isOpen or autoActive or stationDistance()>prompt.MaxActivationDistance then return end
 if state~="idle" and state~="placed" and state~="done" then return end
 local valid=(target.kind=="rarity" and Traits.rarityChancePercent(target.value)>0)
  or (target.kind=="trait" and Traits.chancePercent(target.value)>0)
 if not valid then return end
 if not selectionValid(selectedRockId,selectedCopy) then
  showPage("forge");setResultStatus("CHOOSE A ROCK FIRST",muted);return
 end
 autoTarget=table.clone(target)
 local copy=(Store.get().traitedRocks or {})[selectedCopy]
 if copy and matchesTarget(Traits.get(copy.traitId)) then
  showPage("forge");setResultStatus("TARGET ALREADY ON THIS ROCK",forgeGold);return
 end
 autoGeneration+=1;autoActive=true;autoCount=0;autoMessage=nil
 autoRock=selectedRockId;autoCopy=selectedCopy
 gui:SetAttribute("AutoRolling",true);gui:SetAttribute("AutoRollCount",0)
 gui:SetAttribute("AutoRollTarget",target.value);autoUI:setRunning(true)
 showPage("forge")
 if state=="idle" then placeAction()else rollButton.Text="STOP AUTO";queueAutoRoll(.08)end
end

Store.onChanged(function()
 footnote.Text=shardSummary()
	if not isOpen or state == "waiting" or state == "spinning" or state == "confirming" then return end
	if not selectionValid(selectedRockId, selectedCopy) then
		stopAutoRoll("AUTO-ROLL STOPPED • ROCK CHANGED")
		clearPreview()
		selectedRockId, selectedCopy = defaultSelection()
		state = "idle"
		prompt.ActionText = "PLACE ROCK"
		setResultStatus(selectedRockId and "PLACE YOUR ROCK TO BEGIN" or "PICK A ROCK TO USE THE FORGE", muted)
		placeButton.Text = selectedRockId and "PLACE SELECTED ROCK" or "CHOOSE A ROCK FIRST"
		TraitUI.placeReady(placeButton, selectedRockId ~= nil)
		rollButton.Text = selectedRockId and "PLACE ROCK FIRST" or "CHOOSE A ROCK FIRST"
		rollButton.BackgroundColor3 = Color3.fromRGB(61,71,62)
		setIdleReel()
	end
	updateRockHeader()
	if selectorOpen then refreshSelectionPage() end
	showPage(autoOpen and "auto" or selectorOpen and "select" or oddsOpen and "odds" or "forge")
end)
local lastInteraction=-math.huge
local function interact()
 if UserInputService:GetFocusedTextBox() or game:GetService("GuiService").MenuIsOpen or stationDistance()>prompt.MaxActivationDistance then return end
 if os.clock()-lastInteraction<.12 then return end
 lastInteraction=os.clock()
 if not isOpen then
  dismissedUntilExit=false
  open()
  return
 end
 if autoActive then
  stopAutoRoll("AUTO-ROLL STOPPED")
  if state=="confirming" then confirmationUI:cancel()end
  return
 end
 if state=="confirming" or state=="waiting" or state=="placing" or state=="closing" then return end
 if oddsOpen or selectorOpen or autoOpen then showPage("forge");return end
 if state=="idle" then placeAction()
 elseif state=="placed" or state=="done" then rollAction()
 elseif state=="spinning" then chargePulse() end
end
prompt.Triggered:Connect(interact)
ContextActionService:BindActionAtPriority("TraitForgeInteract",function(_,inputState)
 if UserInputService:GetFocusedTextBox() or game:GetService("GuiService").MenuIsOpen or not prompt.Enabled or stationDistance()>prompt.MaxActivationDistance then
  return Enum.ContextActionResult.Pass
 end
 if inputState==Enum.UserInputState.Begin then interact() end
 return Enum.ContextActionResult.Sink
end,false,3000,Enum.KeyCode.E)

oddsButton.Activated:Connect(function()
	if not isOpen or state == "waiting" or state == "spinning" or state=="confirming" or state=="placing" then return end
	if autoActive then stopAutoRoll("AUTO-ROLL STOPPED")end
	playSfx(tickSfx, 1)
	showOdds(not oddsOpen)
end)
selectButton.Activated:Connect(function()
	if not isOpen or state == "waiting" or state == "spinning" or state=="confirming" or state=="placing" then return end
	if autoActive then stopAutoRoll("AUTO-ROLL STOPPED")end
	playSfx(tickSfx, 1)
	refreshSelectionPage()
	showSelector(true)
end)
selectBack.Activated:Connect(function() showSelector(false) end)
closeButton.Activated:Connect(function() close(true) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not isOpen or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if state == "confirming" then confirmationUI:cancel() else close(true) end
	end
	if input.KeyCode == Enum.KeyCode.Space and state == "spinning" then chargePulse() end
end)
setIdleReel()


-- Amortize the 19-card reel allocation across idle frames before the first roll.
task.spawn(function()
 for index=1,19 do
  if isOpen then break end
  if not reelPool[index] then
   local card=makeReelCard(index,Traits.Results[1]);card.Visible=false
   TraitTextStyle.clear(card:FindFirstChild("Name"));TraitTextStyle.clear(card.Tier)
  end
  RunService.Heartbeat:Wait()
 end
 if not isOpen then setIdleReel() end
end)
-- Preloading yields only in this background coroutine. Gameplay never waits on it.
task.spawn(function()
 local assets={tickSfx,chargeSfx,spinSfx,openSfx,closeSfx,rewardSfx,gui,forge}
 local models=ReplicatedStorage:FindFirstChild("RockModels")
 local profile=Store.get()
 local template=models and models:FindFirstChild(profile.rockEquipped or Rocks.Default)
 if template then table.insert(assets,template) end
 local failures=0
 local ok=pcall(function()
  game:GetService("ContentProvider"):PreloadAsync(assets,function(_,status)
   if status~=Enum.AssetFetchStatus.Success then failures+=1 end
  end)
 end)
 gui:SetAttribute("AssetsPreloaded",ok and failures==0)
 gui:SetAttribute("PreloadFailures",failures)
end)

