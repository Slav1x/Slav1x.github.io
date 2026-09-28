-- One reusable five-part coin; no physics, textures, per-coin connections or scripts.
local A={}
function A.new(parent)
 local model=Instance.new('Model');model.Name='CurrencyCoin'
 local parts={}
 local function part(name,size,offset,color,shape,material)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Shape=shape or Enum.PartType.Block
  p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Parent=model;table.insert(parts,{part=p,offset=offset});return p
 end
 local face=Color3.fromRGB(255,221,108)
 part('MintedRim',Vector3.new(.58,3.1,3.1),CFrame.new(),Color3.fromRGB(209,148,47),Enum.PartType.Cylinder)
 for _,side in {-1,1} do
  part('EnamelFace',Vector3.new(.07,2.55,2.55),CFrame.new(side*.32,0,0),Color3.fromRGB(60,187,120),Enum.PartType.Cylinder)
  part('MintMark',Vector3.new(.085,1.03,1.03),CFrame.new(side*.37,0,0)*CFrame.Angles(math.pi/4,0,0),face)
 end
 local a=Instance.new('Attachment');a.Position=Vector3.new(0,.9,0);a.Parent=parts[1].part
 local b=Instance.new('Attachment');b.Position=Vector3.new(0,-.9,0);b.Parent=parts[1].part
 local trail=Instance.new('Trail');trail.Attachment0=a;trail.Attachment1=b;trail.Lifetime=.14;trail.MinLength=.15;trail.Color=ColorSequence.new(face);trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,1)});trail.Enabled=false;trail.Parent=parts[1].part
 model.PrimaryPart=parts[1].part;model.Parent=parent
 return {model=model,parts=parts,trail=trail}
end
function A.style(coin,gold)
 for _,e in coin.parts do
  e.part.Material=Enum.Material.SmoothPlastic
  if e.part.Name=='EnamelFace' then e.part.Color=gold and Color3.fromRGB(255,196,47) or Color3.fromRGB(60,187,120)
  elseif e.part.Name=='MintMark' then e.part.Color=gold and Color3.fromRGB(255,245,180) or Color3.fromRGB(255,221,108) end
 end
end
function A.pose(coin,cf,fade)
 for _,e in coin.parts do e.part.CFrame=cf*e.offset;e.part.Transparency=fade or 0 end
end
function A.hide(coin)
 coin.trail.Enabled=false;coin.trail:Clear()
 for _,e in coin.parts do e.part.Transparency=1 end
end
return A
