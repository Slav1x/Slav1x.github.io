local CameraMotion={}
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local Config=require(game.ReplicatedStorage.Shared:WaitForChild("SummonConfig"))
local active
local binding="SummonCameraDolly"
local function ease(t) t=math.clamp(t,0,1);return t*t*t*(t*(t*6-15)+10) end
local function restore(s)
 Run:UnbindFromRenderStep(binding)
 if workspace.CurrentCamera==s.camera then
  s.camera.CFrame=s.original
  s.camera.Focus=s.focus
  s.camera.FieldOfView=s.fov
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  s.camera.CameraSubject=humanoid or s.subject
  s.camera.CameraType=s.kind
 end
 if active==s then active=nil end
end
function CameraMotion.stop(immediate,hold)
 local s=active
 if not s then return end
 if hold and workspace.CurrentCamera==s.camera then s.returning=false;return end
 if immediate or workspace.CurrentCamera~=s.camera then restore(s);return end
 if s.returning then return end
 s.returning=true
 s.returnStart=os.clock()
 s.returnFrame=s.camera.CFrame
 s.returnFov=s.camera.FieldOfView
 s.returnFocus=s.camera.Focus
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if root and s.rootPosition then
  local delta=root.Position-s.rootPosition
  s.original=s.original+delta
  s.focus=s.focus+delta
 end
end
function CameraMotion.begin(position,count,skipIntro)
 local continuing=skipIntro and active and workspace.CurrentCamera==active.camera
 if not continuing then CameraMotion.stop(true) end
 if player:GetAttribute("ReducedMotion")==true then CameraMotion.stop(true);return end
 local camera=workspace.CurrentCamera
 if not camera then return end
 local s
 if continuing then
  -- Keep the same shot and original camera state between automatic rolls.
  s=active;s.returning=false;s.started=os.clock()-Config.CameraEnterSeconds
  s.position=position;s.shotFrame=nil
 else
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  s={camera=camera,original=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView,
   subject=camera.CameraSubject,kind=camera.CameraType,rootPosition=root and root.Position,
   started=skipIntro and os.clock()-Config.CameraEnterSeconds or os.clock(),position=position}
  active=s
 end
 -- Consistent composition independent of player position and facing.
 s.shotOffset=Config.CameraOffset
 if (count or 1)>1 then
  local aspect=camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y)
  s.shotOffset=Config.batchCameraOffset(count,aspect)
 end
 s.focusPoint=position+Vector3.new(0,.9,0)
 camera.CameraType=Enum.CameraType.Scriptable
 if continuing then return end
 -- Keep the current frame on first entry; repeated auto-rolls start at the shot.
 Run:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value,function(dt)
  if workspace.CurrentCamera~=camera then restore(s);return end
  if s.returning then
   local t=ease((os.clock()-s.returnStart)/Config.CameraReturnSeconds)
   camera.CFrame=s.returnFrame:Lerp(s.original,t)
   camera.FieldOfView=s.returnFov+(s.fov-s.returnFov)*t
   camera.Focus=s.returnFocus:Lerp(s.focus,t)
   if t>=1 then restore(s) end
   return
  end
  if player:GetAttribute("ReducedMotion")==true then restore(s);return end
  local age=os.clock()-s.started
  local t=ease(age/Config.CameraEnterSeconds)
  local focus=s.focusPoint
  local desired=focus+s.shotOffset
  local params=RaycastParams.new()
  params.FilterType=Enum.RaycastFilterType.Exclude
  local excluded={}
  if player.Character then table.insert(excluded,player.Character) end
  local effects=workspace:FindFirstChild("SummonPresentation")
  if effects then table.insert(excluded,effects) end
  params.FilterDescendantsInstances=excluded
  local ray=desired-focus
  local hit=workspace:Raycast(focus,ray,params)
  if hit then desired=focus+ray.Unit*math.max(.8,hit.Distance-.6) end
  local target=CFrame.lookAt(desired,focus)
  -- Smooth collision-driven corrections without moving the entry destination.
  s.shotFrame=s.shotFrame and s.shotFrame:Lerp(target,1-math.exp(-dt*18)) or target
  camera.CFrame=s.original:Lerp(s.shotFrame,t)
  camera.Focus=s.focus:Lerp(CFrame.new(focus),t)
  camera.FieldOfView=s.fov+(58-s.fov)*t
 end)
end
player.CharacterRemoving:Connect(function() CameraMotion.stop(true) end)
return CameraMotion
