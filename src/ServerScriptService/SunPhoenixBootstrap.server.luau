-- Regenerates the shared static mesh once per server from embedded Blender data.
-- No HTTP, inventory writes, or per-player mesh construction.
local ServerStorage=game:GetService('ServerStorage')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local HttpService=game:GetService('HttpService')
local source=ServerStorage:WaitForChild('SunPhoenixFinishedSource')
local templates=ReplicatedStorage:WaitForChild('PetModels')
local old=templates:FindFirstChild('SunPhoenix')
local oldReady=old and old:GetAttribute('PremiumReady')
if old then old:SetAttribute('PremiumReady',false) end
local function build(embeddedSource)
 local chunks={}
 for _,v in embeddedSource:GetChildren() do if v:IsA('StringValue') then table.insert(chunks,v) end end
 table.sort(chunks,function(a,b) return a.Name<b.Name end)
 local strings={};for _,v in chunks do table.insert(strings,v.Value) end
 local data=HttpService:JSONDecode(table.concat(strings))
 return require(embeddedSource.Builder).build(data)
end
local started=os.clock()
local ok,model=xpcall(function() return build(source) end,debug.traceback)
if not ok then
 source:SetAttribute('BuildStatus','Failed')
 source:SetAttribute('LastBuildError',tostring(model))
 warn('[SunPhoenix] Finished mesh build failed: '..tostring(model))
 local previousSource=ServerStorage:FindFirstChild('SunPhoenixSource')
 if previousSource then
  local previousOk,previousModel=xpcall(function() return build(previousSource) end,debug.traceback)
  if previousOk then
   ok=true;model=previousModel
   source:SetAttribute('BuildStatus','PreviousRevision')
  else
   warn('[SunPhoenix] Previous mesh build failed: '..tostring(previousModel))
  end
 end
end
if ok then
 model.Name='SunPhoenix';model:SetAttribute('BuildSeconds',os.clock()-started)
 if old then old.Parent=nil end
 model.Parent=templates
 if old then old:Destroy() end
 if source:GetAttribute('BuildStatus')~='PreviousRevision' then
  source:SetAttribute('BuildStatus','Ready')
  source:SetAttribute('LastBuildError',nil)
 end
else
 local fallback=templates:FindFirstChild('SunPhoenix_LegacyFallback')
 if fallback then
  local copy=fallback:Clone();copy.Name='SunPhoenix'
  if old then old:Destroy() end
  copy.Parent=templates
 elseif old then
  old:SetAttribute('PremiumReady',oldReady)
 end
end
