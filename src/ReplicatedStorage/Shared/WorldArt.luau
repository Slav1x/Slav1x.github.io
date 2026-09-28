-- Shared biome mesh presentation; no reward or collection decisions.
local A={}
local RS=game:GetService('ReplicatedStorage')
local Zones=require(RS.Shared.ZoneConfig)
local Lib=RS:WaitForChild('WorldAssetLibrary')
A.Families={
 driftwood={small='Driftwood_MossCrag',medium='Driftwood_Pine',large='Driftwood_PinewatchFalls',border='Driftwood_StoneArch',ground=Color3.fromRGB(103,148,108),soil=Color3.fromRGB(92,118,112),water=Color3.fromRGB(65,170,186)},
 blossom={small='Blossom_RoseQuartz',medium='Blossom_Sakura',large='Blossom_PetalIsland',border='Blossom_SpiritGate',ground=Color3.fromRGB(143,174,136),soil=Color3.fromRGB(139,133,151),water=Color3.fromRGB(99,179,196)},
 candy={small='Candy_Gumdrops',medium='Candy_PeppermintCane',alternate='Candy_SwirlPop',large='Candy_FrostingArch',border='Candy_FrostingArch',ground=Color3.fromRGB(255,212,226),soil=Color3.fromRGB(137,84,93),water=Color3.fromRGB(98,201,204)},
 sunscorch={small='Sunscorch_AmberFossil',medium='Sunscorch_Saguaro',large='Sunscorch_Mesa',border='Sunscorch_WindArch',ground=Color3.fromRGB(228,181,116),soil=Color3.fromRGB(172,107,78),water=Color3.fromRGB(72,168,170)},
 frozen={small='Frozen_CrystalCluster',medium='Frozen_SnowPine',large='Frozen_Glacier',border='Frozen_IcicleArch',ground=Color3.fromRGB(224,241,241),soil=Color3.fromRGB(115,177,203),water=Color3.fromRGB(101,182,213)},
 crystal={small='Crystal_Geode',medium='Crystal_LeaningNeedle',large='Crystal_PrismaticOrgan',border='Crystal_Entrance',ground=Color3.fromRGB(92,85,121),soil=Color3.fromRGB(50,46,73),water=Color3.fromRGB(83,127,173)},
 toxic={small='Toxic_BarrelCluster',medium='Toxic_RunoffPipe',large='Toxic_CoolingTowers',border='Toxic_IndustrialGate',ground=Color3.fromRGB(105,125,89),soil=Color3.fromRGB(63,82,78),water=Color3.fromRGB(119,160,62)},
 inferno={small='Inferno_Obsidian',medium='Inferno_BasaltSpire',large='Inferno_Caldera',border='Inferno_CinderArch',ground=Color3.fromRGB(89,74,83),soil=Color3.fromRGB(48,48,63),water=Color3.fromRGB(178,91,47)},
 cosmic={small='Cosmic_StarCluster',medium='Cosmic_MoonMonolith',large='Cosmic_AstralIsland',border='Cosmic_OrbitGate',ground=Color3.fromRGB(129,124,167),soil=Color3.fromRGB(74,69,113),water=Color3.fromRGB(93,111,166)},
}
function A.mesh(parent,name,base,scale)
 local source=Lib:FindFirstChild(name);assert(source,'Missing imported mesh '..name)
 local p=source:Clone();p.Size=source.Size*scale
 p.CFrame=base*CFrame.new(0,(source:GetAttribute('GroundOffset') or source.Size.Y/2)*scale,0)
 p.Parent=parent;return p
end
function A.zone(position) return Zones.forDistance(Zones.distanceAt(position)) end
function A.trimPickup(model)
 local base=CFrame.new(model.PrimaryPart.Position)
 local zone=A.zone(base.Position);local theme=A.Families[zone.id]
 model:SetAttribute('AreaId',zone.id)
 if not theme then return end
 local p=A.mesh(model,A.riverName(zone.id,'PickupCradle'),base*CFrame.new(0,-1.5,0),1)
 p.Name='BiomeCasing';p.CastShadow=false
end

function A.riverName(area,role)
 local family=area=='driftwood' and 'Forest' or area:sub(1,1):upper()..area:sub(2)
 local name=role
 if area=='driftwood' then
  name=({RiverRelic_A='RootIslet',RiverRelic_B='FallenNurseLog',PickupCradle='RootCradle',Growth_A='AncientCedar'})[role] or role
 end
 return 'RL_'..family..'_'..name
end
function A.habitat(model)
 if not model.PrimaryPart then return end
 local area=A.zone(model.PrimaryPart.Position).id
 if model:GetAttribute('HabitatArtVersion')==2 and model:GetAttribute('AreaId')==area then return end
 for _,p in model:GetChildren() do
  if p.Name=='Island' or p.Name=='SandIsland' or p.Name=='Grass' or p.Name=='PalmTrunk' or p.Name=='PalmLeaf' or p.Name=='BiomeHabitat' or p.Name=='BiomeGrowth' then p:Destroy() end
 end
 local base=CFrame.new(model.PrimaryPart.Position)
 local island=A.mesh(model,A.riverName(area,'RiverRelic_A'),base,1)
 island.Name='BiomeHabitat';island.Size=Vector3.new(26,3,23);island.CFrame=base*CFrame.new(0,-.8,0)
 local growth=A.mesh(model,A.riverName(area,'Growth_A'),base*CFrame.new(9,0,-9),.27);growth.Name='BiomeGrowth'
 model:SetAttribute('HabitatArtVersion',2);model:SetAttribute('AreaId',area)
end

return A

