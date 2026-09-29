-- Responsive scaling only. All button sizes, artwork, shadows, and labels are editable in Studio.
local nav=script.Parent
local scale=nav:FindFirstChild("ResponsiveScale") or Instance.new("UIScale")
scale.Name="ResponsiveScale"
scale.Parent=nav
local function resize()
 local camera=workspace.CurrentCamera
 if not camera then return end
 local v=camera.ViewportSize
 scale.Scale=math.min(1,(v.Y-85)/410,(v.X-24)/78)
end
local connection
local function bind()
 if connection then connection:Disconnect() end
 if workspace.CurrentCamera then
  connection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
 end
 resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
bind()
