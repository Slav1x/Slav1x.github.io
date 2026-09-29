-- Explicit descendant fading for the altar BillboardGui.
-- Preserve each element's own opacity (including hidden button text and VFX).
local Fade = {}
function Fade.new(root)
	local opacity = 0
	local entries = {}
	local stopped = false
	local controller = {}
	local function apply(entry)
		local value = 1 - (1 - entry.base) * opacity
		entry.writing = true
		entry.object[entry.property] = value
		-- Roblox stores these properties as floats; compare against the stored value.
		entry.applied = entry.object[entry.property]
		entry.writing = false
	end
	local function track(object)
		if entries[object] then return end
		local properties = {}
		if object:IsA("GuiObject") then table.insert(properties, "BackgroundTransparency") end
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			table.insert(properties, "TextTransparency")
			table.insert(properties, "TextStrokeTransparency")
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") or object:IsA("ViewportFrame") then
			table.insert(properties, "ImageTransparency")
		elseif object:IsA("UIStroke") then
			table.insert(properties, "Transparency")
		end
		if #properties == 0 then return end
		local tracked = {}
		entries[object] = tracked
		for _, property in properties do
			local entry = {object=object, property=property, base=object[property]}
			table.insert(tracked, entry)
			entry.connection = object:GetPropertyChangedSignal(property):Connect(function()
				local current = object[property]
				-- Ignore our writes under immediate and deferred signal behavior.
				if stopped or entry.writing or current == entry.applied then return end
				entry.base = current
				apply(entry)
			end)
			apply(entry)
		end
	end
	local function untrack(object)
		local tracked = entries[object]
		if not tracked then return end
		for _, entry in tracked do entry.connection:Disconnect() end
		entries[object] = nil
	end
	for _, object in root:GetDescendants() do track(object) end
	track(root)
	local added = root.DescendantAdded:Connect(track)
	local removing = root.DescendantRemoving:Connect(untrack)
	function controller:setOpacity(value)
		if stopped then return end
		opacity = math.clamp(value, 0, 1)
		for _, tracked in entries do
			for _, entry in tracked do
				-- Capture changes made earlier this frame before deferred signals run.
				local current = entry.object[entry.property]
				if current ~= entry.applied then entry.base = current end
				apply(entry)
			end
		end
	end
	function controller:destroy()
		if stopped then return end
		stopped = true
		added:Disconnect()
		removing:Disconnect()
		for object in entries do untrack(object) end
	end
	return controller
end
return Fade