-- services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- modules
local SoundController = require(ReplicatedStorage:FindFirstChild("SoundController", true))

-- variables
local tagged = CollectionService:GetTagged(script.Name)

-- values
local hoverAnimSpeed = 0.1
local sizeDifference = 0.9

local guiCache = {}
local activeHovering = {}
local latestHover = nil

-- loop through all instances with tagid
local function DeselectAll()
	for _, child in pairs(activeHovering) do			
		child:TweenSize(guiCache[child].defaultSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, hoverAnimSpeed/2, true)	
		local hoverShadowImage = child:FindFirstChild("HoverShadowImage")
		if hoverShadowImage then
			hoverShadowImage.Visible = false
		end	
	end
end

local function Expand(child)
	child:TweenSize(guiCache[child].hoveredSize, Enum.EasingDirection.In, Enum.EasingStyle.Quad, hoverAnimSpeed, true)
	local hoverShadowImage = child:FindFirstChild("HoverShadowImage")
	if hoverShadowImage then
		hoverShadowImage.Visible = true
	end
end

local function OnMouseEnter(child)
	DeselectAll()
	
	Expand(child)
	if table.find(activeHovering, child) == nil then
		table.insert(activeHovering, child)
	end
	latestHover = child
end

local function OnMouseLeave(child)	
	DeselectAll()
	
	table.remove(activeHovering, table.find(activeHovering, child)) 
	latestHover = activeHovering[#activeHovering]
	
	if latestHover then
		Expand(latestHover)
	end
end

local function TagAdded(child)
	if guiCache[child] ~= nil or not child:IsA("GuiObject") then 
		warn(child.Name .. " Cannot be tagged with '".. script.Name .. "'")
		return 
	end
	
	local defaultSize, hoveredSize = UDim2.new(child.Size.X.Scale*sizeDifference,0,child.Size.Y.Scale*sizeDifference,0), child.Size
	guiCache[child] = {defaultSize=defaultSize,hoveredSize=hoveredSize}
	child.Size = defaultSize

	child.MouseLeave:Connect(function()
		OnMouseLeave(child)
	end)
	child.MouseEnter:Connect(function()	
		SoundController.Play("SFX", "UI_Hover_01")
		OnMouseEnter(child)
	end)
end

CollectionService:GetInstanceAddedSignal(script.Name):Connect(function(child)
	TagAdded(child)
end)
