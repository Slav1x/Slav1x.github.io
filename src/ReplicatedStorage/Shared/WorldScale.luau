-- Authored longitudinal map; launch inlet and all object silhouettes retain their shape.
local M={OriginalEnds={1800,5400,10200,17400,26200,35800,46200,59000,75800},Ends={2430,7290,13770,23850,36170,49610,65210,84410,109610},Origin=-520,InletEnd=-103}
function M.expandedX(x)
 if x<=M.InletEnd then return x end
 local a,b=M.InletEnd,M.InletEnd
 for i,finish in M.OriginalEnds do
  local e,n=finish+M.Origin,M.Ends[i]+M.Origin
  if x<=e then return b+(x-a)*(n-b)/(e-a) end
  a,b=e,n
 end
 return b+(x-a)*1.5
end
function M.originalX(x)
 if x<=M.InletEnd then return x end
 local a,b=M.InletEnd,M.InletEnd
 for i,finish in M.Ends do
  local e,n=finish+M.Origin,M.OriginalEnds[i]+M.Origin
  if x<=e then return b+(x-a)*(n-b)/(e-a) end
  a,b=e,n
 end
 return b+(x-a)/1.5
end
function M.position(p) return Vector3.new(M.expandedX(p.X),p.Y,p.Z) end
return M
