--!nonstrict
-- Swept rock volume against each moving visual part, including start-inside hits.
local H={}
function H.box(from,to,cf,size,radius)
 local a=cf:PointToObjectSpace(from)
 local d=cf:VectorToObjectSpace(to-from)
 local half=size*.5+Vector3.one*radius
 local lo,hi=0,1
 for _,axis in {"X","Y","Z"} do
  if math.abs(d[axis])<1e-8 then
   if math.abs(a[axis])>half[axis] then return nil end
  else
   local t1=(-half[axis]-a[axis])/d[axis]
   local t2=(half[axis]-a[axis])/d[axis]
   lo=math.max(lo,math.min(t1,t2));hi=math.min(hi,math.max(t1,t2))
   if lo>hi then return nil end
  end
 end
 return lo
end
return H