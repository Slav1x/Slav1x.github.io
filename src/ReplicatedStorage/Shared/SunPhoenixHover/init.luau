-- Exact 30 fps baked Blender action; decoded once per client, shared by followers.
local HttpService=game:GetService('HttpService')
local rows={}
for _,item in script:GetChildren() do if item:IsA('StringValue') then table.insert(rows,item) end end
table.sort(rows,function(a,b) return a.Name<b.Name end)
local chunks={};for _,row in rows do table.insert(chunks,row.Value) end
local data=HttpService:JSONDecode(table.concat(chunks))
local frames={}
for i,row in data.frames do
 local frame={};for j,components in row do frame[j]=CFrame.new(unpack(components)) end
 frames[i]=frame
end
local Hover={Duration=data.duration,Names=data.names,Frames=frames,FPS=data.fps}
function Hover.apply(bones,time)
 local position=(time%data.duration)*data.fps
 local index=math.floor(position)+1;local alpha=position-math.floor(position)
 local first,second=frames[index],frames[index+1]
 for i,name in data.names do
  local list=bones[name]
  if list then local transform=first[i]:Lerp(second[i],alpha);for _,bone in list do bone.Transform=transform end end
 end
end
return Hover