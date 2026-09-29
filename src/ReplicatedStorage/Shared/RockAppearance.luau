-- One geometry template per rock; all display paths use the same reversible treatment.
local RS = game:GetService("ReplicatedStorage")
local Catalog = require(script.Parent.RockCatalog)
local Appearance = {}
local applyAuthoredVariant=require(script.Parent:WaitForChild("AuthoredRockVariant"))
Appearance.EnchantedChance = 0.01
local palettes = {
 sugar_pebble={0x233D52,0x7BFFE1,0xFFF0AA,"Pearl"},
 peppermint_stone={0x233D52,0x7BFFE1,0xFFF0AA,"Metal"},
 gumdrop_geode={0x233D52,0x7BFFE1,0xFFF0AA,"Inverse"},
 cocoa_cluster={0x233D52,0x7BFFE1,0xFFF0AA,"Crystal"},
 candy_prism={0x233D52,0x7BFFE1,0xFFF0AA,"Cosmic"},
 sugarheart={0x233D52,0x7BFFE1,0xFFF0AA,"Crystal"},
 frost_pebble={0x422657,0xFFB8EA,0xFFEFC1,"Pearl"},
 snowstone={0x422657,0xFFB8EA,0xFFEFC1,"Metal"},
 glacier_shard={0x422657,0xFFB8EA,0xFFEFC1,"Inverse"},
 aurora_quartz={0x422657,0xFFB8EA,0xFFEFC1,"Crystal"},
 frost_crown={0x422657,0xFFB8EA,0xFFEFC1,"Cosmic"},
 winterheart={0x422657,0xFFB8EA,0xFFEFC1,"Crystal"},
 corroded_pebble={0x342347,0xC696FF,0x78F9FF,"Pearl"},
 sludge_stone={0x342347,0xC696FF,0x78F9FF,"Metal"},
 waste_crystal={0x342347,0xC696FF,0x78F9FF,"Inverse"},
 isotope_geode={0x342347,0xC696FF,0x78F9FF,"Crystal"},
 reactor_core={0x342347,0xC696FF,0x78F9FF,"Cosmic"},
 fallout_heart={0x342347,0xC696FF,0x78F9FF,"Crystal"},

 pebble={0x133B48,0x77FFE5,0xD4FFF4,"Metal"},
 smooth_stone={0x332742,0xFFB9E2,0xFFFFFF,"Pearl"},
 quartz={0x392458,0xFFCF74,0xFF71E5,"Crystal"},
 obsidian={0xECECF8,0x734BFF,0x47FFD7,"Inverse"},
 golden_skimmer={0x18294E,0x8CCFFF,0xEEF9FF,"Metal"},
 astral_core={0x092822,0x78FFC1,0xFFDE7F,"Cosmic"},
 treasure_stone={0x4D215E,0xFF86DC,0xB8FFEE,"Metal"},
 magma_skimmer={0x173954,0x60DAFF,0xDBFDFF,"Inverse"},
 celestial_shard={0x492838,0xFFD293,0xFFF0D6,"Cosmic"},
 moss_stone={0x21394B,0x8CB4FF,0xE4C4FF,"Pearl"},
 lakeheart={0x411A62,0xF981FF,0xFFF0FC,"Crystal"},
 petal_stone={0x174634,0xA8FFD0,0xF9FFF1,"Pearl"},
 bamboo_pebble={0x462A56,0xD0A1FF,0xFFF0A5,"Metal"},
 koi_stone={0x182541,0x7FEAFF,0xEAFBFF,"Inverse"},
 sakura_quartz={0x163B48,0x7AFFF2,0xDEFFF9,"Crystal"},
 spirit_stone={0x332116,0xFFC567,0xFFFFFF,"Cosmic"},
 bloomheart={0x283955,0xA4D4FF,0xF2F8FF,"Pearl"},
 sandstone={0x293B5B,0xB8DBFF,0xF5E5FF,"Metal"},
 cactus_stone={0x542B44,0xFF95BE,0xFFE5BC,"Pearl"},
 fossil_rock={0x252041,0xAFFFDA,0xC8FFF3,"Inverse"},
 amber_shard={0x27305B,0xA58AFF,0xE1FDFF,"Crystal"},
 solar_stone={0x111F3E,0x5CBAFF,0xDEFCFF,"Cosmic"},
 scarab_core={0x5C2344,0xF7ACFF,0xFFD795,"Metal"},
 magma_core={0x112B43,0x58E6FF,0xEBFEFF,"Inverse"},
 ember_pebble={0x1E3741,0x88FFAA,0xDBFFED,"Pearl"},
 basalt_stone={0xDDD8EF,0x8960FF,0xE0B7FF,"Inverse"},
 cinder_rock={0x392A56,0xD195FF,0xA9FAFF,"Cosmic"},
 lava_glass={0x18372C,0xA1FFAC,0xFCFFE7,"Crystal"},
 phoenix_heart={0x2B1B53,0xB186FF,0xFFA0EC,"Metal"},
 moon_pebble={0x443A28,0xFFE7A0,0xFFFFFF,"Pearl"},
 meteor_stone={0x463B68,0xFFABCE,0xFFEFBA,"Metal"},
 stardust_rock={0x24413E,0x8BFFD9,0xFFDD8D,"Cosmic"},
 nebula_quartz={0x523A2C,0xFFD089,0xFFABAE,"Crystal"},
 eclipse_stone={0xDCEAF2,0x27356C,0x9AB8FF,"Inverse"},
}
-- These originals carry their rock identity in authored color/emissive maps.
-- Tint those maps in place so veins, strata, and core markings remain visible.
local authoredMapTints={pebble=0x77FFE5,smooth_stone=0xFFA6DE,quartz=0xFF72DF,obsidian=0x88FFD5,golden_skimmer=0x76C8FF,astral_core=0xFFD086}
local states=setmetatable({}, {__mode="k"})
palettes.cavern_quartz={0x433657,0xE9BEF9,0xFCF0FF,"Pearl"}
palettes.amethyst_geode={0x261B3E,0xE6A850,0xE4C6FF,"Crystal"}
palettes.sapphire_cluster={0x152541,0x6BD4E8,0xCCDFFF,"Crystal"}
palettes.ruby_matrix={0x451D37,0xFFC181,0xFFBFDD,"Metal"}
palettes.emerald_crown={0x153E39,0xEBCD69,0xAEFFE3,"Pearl"}
palettes.prismatic_heart={0x362556,0xBDA8FF,0xE1FFF9,"Cosmic"}
local function rgb(hex)
 return Color3.fromRGB(bit32.band(bit32.rshift(hex,16),255),bit32.band(bit32.rshift(hex,8),255),bit32.band(hex,255))
end
function Appearance.normalize(variant)
 return (variant==true or type(variant)=="string" and string.lower(variant)=="enchanted") and "Enchanted" or "Normal"
end
function Appearance.palette(id)
 local p=palettes[id]
 if p then return rgb(p[1]),rgb(p[2]),rgb(p[3]),p[4] end
 -- Stable individual palette for future catalog additions, without extra registration.
 local hash=0
 for i=1,#id do hash=(hash*31+string.byte(id,i))%360 end
 return Color3.fromHSV(hash/360,.65,.24),Color3.fromHSV((hash/360+.38)%1,.6,1),Color3.fromHSV((hash/360+.56)%1,.22,1),"Crystal"
end
function Appearance.apply(model,id,variant)
 variant=Appearance.normalize(variant)
 if applyAuthoredVariant(model,id,variant) then return model end
 local state=states[model]
 if state then
  for part,original in pairs(state.parts) do
   if part.Parent then
    part.Color=original.color;part.Material=original.material;part.Reflectance=original.reflectance
    if part:IsA("MeshPart") then part.TextureID=original.texture end
   end
  end
  for surface,parent in pairs(state.surfaces) do if parent.Parent then surface.Parent=parent end end
  for surface,original in pairs(state.tints) do
   if surface.Parent then surface.Color=original.color;surface.EmissiveTint=original.emissiveTint;surface.EmissiveStrength=original.emissiveStrength end
  end
  for light,original in pairs(state.lights) do
   if light.Parent then light.Color=original.color;light.Brightness=original.brightness end
  end
  for _,effect in ipairs(state.effects) do effect:Destroy() end
  state.effects={};state.tints={};state.lights={}
 end
 model:SetAttribute("Variant",variant)
 model:SetAttribute("RockId",id)
 model:SetAttribute("Enchanted",variant=="Enchanted")
 if variant=="Normal" then return model end
 if not state then state={parts={},surfaces={},tints={},lights={},effects={}};states[model]=state end
 local body,accent,glow,mode=Appearance.palette(id)
 local semanticBlender=model:GetAttribute("BlenderAuthored")==true and model:GetAttribute("CustomRockAppearance")==true
 local preserveMaps=(not semanticBlender and authoredMapTints[id]~=nil) or model:GetAttribute("PreserveSurfaceMaps")==true
 local mapTint=authoredMapTints[id] and rgb(authoredMapTints[id]) or accent
 local stash=Instance.new("Folder");stash.Name="NormalSurfaceMaps";stash.Parent=model;table.insert(state.effects,stash)
 local primary=model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") and not part:FindFirstAncestor("EquippedAbilityVisual") then
   if not state.parts[part] then state.parts[part]={color=part.Color,material=part.Material,reflectance=part.Reflectance,texture=part:IsA("MeshPart") and part.TextureID or ""} end
   -- Legacy TextureID maps need a SurfaceAppearance to accept a runtime tint.
   -- These preauthored clones use the exact original image; Normal removes them.
   if preserveMaps and part:IsA("MeshPart") and part.TextureID~="" and not part:FindFirstChildWhichIsA("SurfaceAppearance") then
    local mapFolder=RS:FindFirstChild("AuthoredRockSurfaceMaps")
    local mapTemplate=mapFolder and mapFolder:FindFirstChild(id)
    if mapTemplate then local surface=mapTemplate:Clone();surface.Name="EnchantedAuthoredSurface";surface.Parent=part;table.insert(state.effects,surface) end
   end
   for _,surface in ipairs(part:GetChildren()) do
    if surface:IsA("SurfaceAppearance") then
     if preserveMaps then
      if not state.tints[surface] then state.tints[surface]={color=surface.Color,emissiveTint=surface.EmissiveTint,emissiveStrength=surface.EmissiveStrength} end
      surface.Color=mapTint;surface.EmissiveTint=glow;surface.EmissiveStrength=math.max(.4,math.min(state.tints[surface].emissiveStrength*1.5,.8))
     else state.surfaces[surface]=part;surface.Parent=stash end
    end
   end
   if part:IsA("MeshPart") and not preserveMaps then part.TextureID="" end
   local role=part:GetAttribute("AppearanceRole") or "Body"
   if preserveMaps then
    -- SurfaceAppearance owns its tint; legacy TextureID is tinted by the part.
    part.Color=part:FindFirstChildWhichIsA("SurfaceAppearance") and Color3.new(1,1,1) or mapTint
    part.Material=(mode=="Metal" or mode=="Inverse") and Enum.Material.Metal or Enum.Material.SmoothPlastic
    part.Reflectance=mode=="Pearl" and .22 or .08
   elseif role=="Crystal" or role=="Inlay" then
    part.Color=glow;part.Material=Enum.Material.Neon;part.Reflectance=0
   elseif role=="Accent" then
    part.Color=accent;part.Material=(mode=="Inverse" or mode=="Cosmic") and Enum.Material.Neon or Enum.Material.Glass;part.Reflectance=.1
   elseif role=="Metal" then part.Color=accent;part.Material=Enum.Material.Metal;part.Reflectance=.3
   else
    part.Color=body;part.Material=(mode=="Metal" or mode=="Inverse") and Enum.Material.Metal or Enum.Material.SmoothPlastic
    part.Reflectance=mode=="Pearl" and .28 or .12
   end
  end
 end
 if preserveMaps then
  for _,light in ipairs(model:GetDescendants()) do
   if light:IsA("PointLight") and light.Name=="IconGlow" then
    if not state.lights[light] then state.lights[light]={color=light.Color,brightness=light.Brightness} end
    light.Color=accent;light.Brightness=math.min(state.lights[light].brightness,.65)
   end
  end
 end
 if primary then
  local attachment=Instance.new("Attachment");attachment.Name="EnchantedAura";attachment.Parent=primary;table.insert(state.effects,attachment)
  local sparks=Instance.new("ParticleEmitter");sparks.Name="EnchantedSparkles"
  sparks.Texture="rbxasset://textures/particles/sparkles_main.dds"
  sparks.Color=ColorSequence.new(accent,glow);sparks.LightEmission=.8
  sparks.Lifetime=NumberRange.new(.65,1.2);sparks.Rate=mode=="Cosmic" and 7 or 4
  sparks.Speed=NumberRange.new(.15,.4);sparks.SpreadAngle=Vector2.new(180,180)
  sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.3,.1),NumberSequenceKeypoint.new(1,0)})
  sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.15),NumberSequenceKeypoint.new(1,1)})
  sparks.Parent=attachment
  local light=Instance.new("PointLight");light.Name="EnchantedLight";light.Color=accent;light.Brightness=.45;light.Range=4;light.Shadows=false;light.Parent=attachment
 end
 return model
end
function Appearance.clone(id,variant)
 local models=RS:WaitForChild("RockModels")
 local template=models:FindFirstChild(id) or models:FindFirstChild(Catalog.Default)
 assert(template and template:IsA("Model"),"Missing rock template: "..tostring(id))
 return Appearance.apply(template:Clone(),id,variant)
end
-- Shared camera fitting keeps thumbnails faithful to the held and thrown model.
function Appearance.populateViewport(viewport,id,variant)
 local old=viewport:FindFirstChild("RockPreviewWorld")
 if old then old:Destroy() end
 local oldCamera=viewport:FindFirstChild("RockPreviewCamera")
 if oldCamera then oldCamera:Destroy() end
 local world=Instance.new("WorldModel");world.Name="RockPreviewWorld";world.Parent=viewport
 local model=Appearance.clone(id,variant);model.Parent=world
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end
 end
 model:PivotTo(CFrame.Angles(0,math.rad(-22),0))
 local cf,size=model:GetBoundingBox()
 local camera=Instance.new("Camera");camera.Name="RockPreviewCamera";camera.FieldOfView=32
 local radius=math.max(size.X,size.Y,size.Z)*.5
 local distance=radius/math.tan(math.rad(camera.FieldOfView*.5))*1.28
 camera.CFrame=CFrame.lookAt(cf.Position+Vector3.new(.65,.8,1).Unit*distance,cf.Position)
 camera.Parent=viewport;viewport.CurrentCamera=camera
 viewport.Ambient=Color3.fromRGB(190,190,205);viewport.LightColor=Color3.fromRGB(255,244,225);viewport.LightDirection=Vector3.new(-1,-2,-2)
 return model
end
return Appearance


