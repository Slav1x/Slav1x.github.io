local Z={}
Z.OriginX=-520 -- Same world origin as the area gates and biome scenery.
Z.List={
 {id="driftwood",name="DRIFTWOOD LAKE",start=0,finish=2430,cost=650,moneyPerStud=0.15,completionCash=1000,completionShards=2,surface="River",landmark="PINEWATCH FALLS",color=Color3.fromRGB(70,190,228),pool={{id="pebble",weight=30},{id="smooth_stone",weight=30},{id="moss_stone",weight=20},{id="quartz",weight=12},{id="golden_skimmer",weight=6},{id="lakeheart",weight=2}}},
 {id="blossom",name="BLOSSOM CREEK",start=2430,finish=7290,cost=2600,moneyPerStud=0.24,completionCash=4000,completionShards=4,surface="Blossom",landmark="SAKURA SPIRIT GATE",color=Color3.fromRGB(255,143,191),pool={{id="petal_stone",weight=30},{id="bamboo_pebble",weight=30},{id="koi_stone",weight=20},{id="sakura_quartz",weight=12},{id="spirit_stone",weight=6},{id="bloomheart",weight=2}}},
 {id="candy",name="CANDY LAND",start=7290,finish=13770,cost=4800,moneyPerStud=0.31,completionCash=6500,completionShards=4,surface="Candy",landmark="SUGARSPUN GARDENS",color=Color3.fromRGB(255,134,191),pool={{id="sugar_pebble",weight=30},{id="peppermint_stone",weight=30},{id="gumdrop_geode",weight=20},{id="cocoa_cluster",weight=12},{id="candy_prism",weight=6},{id="sugarheart",weight=2}}},
 {id="sunscorch",name="SUNSCORCH CANYON",start=13770,finish=23850,cost=8500,moneyPerStud=0.37,completionCash=12000,completionShards=6,surface="Oasis",landmark="SUN DISC PASS",color=Color3.fromRGB(255,174,75),pool={{id="sandstone",weight=30},{id="cactus_stone",weight=30},{id="fossil_rock",weight=20},{id="amber_shard",weight=12},{id="solar_stone",weight=6},{id="scarab_core",weight=2}}},
 {id="frozen",name="FROZEN REACH",start=23850,finish=36170,cost=12500,moneyPerStud=0.45,completionCash=18000,completionShards=7,surface="Ice",landmark="THE GLACIER CATHEDRAL",color=Color3.fromRGB(158,227,250),pool={{id="frost_pebble",weight=30},{id="snowstone",weight=30},{id="glacier_shard",weight=20},{id="aurora_quartz",weight=12},{id="frost_crown",weight=6},{id="winterheart",weight=2}}},
 {id="crystal",name="CRYSTAL CAVE",start=36170,finish=49610,cost=16000,moneyPerStud=0.48,completionCash=20500,completionShards=8,surface="Crystal",landmark="THE PRISMATIC CATHEDRAL",color=Color3.fromRGB(157,137,246),pool={{id="cavern_quartz",weight=30},{id="amethyst_geode",weight=30},{id="sapphire_cluster",weight=20},{id="ruby_matrix",weight=12},{id="emerald_crown",weight=6},{id="prismatic_heart",weight=2}}},
 {id="toxic",name="TOXIC WASTE",start=49610,finish=65210,cost=20000,moneyPerStud=0.5,completionCash=23000,completionShards=8,surface="Toxic",landmark="THE OVERFLOW WORKS",color=Color3.fromRGB(172,230,81),pool={{id="corroded_pebble",weight=30},{id="sludge_stone",weight=30},{id="waste_crystal",weight=20},{id="isotope_geode",weight=12},{id="reactor_core",weight=6},{id="fallout_heart",weight=2}}},
 {id="inferno",name="INFERNO RAPIDS",start=65210,finish=84410,cost=28000,moneyPerStud=0.56,completionCash=30000,completionShards=9,surface="Lava",landmark="CALDERA CROWN",color=Color3.fromRGB(255,93,52),pool={{id="ember_pebble",weight=30},{id="basalt_stone",weight=30},{id="cinder_rock",weight=20},{id="lava_glass",weight=12},{id="phoenix_heart",weight=6},{id="magma_core",weight=2}}},
 {id="cosmic",name="COSMIC CURRENT",start=84410,finish=109610,cost=55000,moneyPerStud=0.8,completionCash=75000,completionShards=12,surface="Cosmic",landmark="ASTRAL CONFLUENCE",color=Color3.fromRGB(163,106,255),pool={{id="moon_pebble",weight=30},{id="meteor_stone",weight=30},{id="stardust_rock",weight=20},{id="nebula_quartz",weight=12},{id="eclipse_stone",weight=6},{id="astral_core",weight=2}}},
}
Z.ById={}
for _,v in ipairs(Z.List) do
 Z.ById[v.id]=v
 local total=0
 for _,entry in ipairs(v.pool) do total+=entry.weight end
 assert(total==100,"Zone odds must total 100: "..v.id)
end
function Z.forDistance(distance)
 local found=Z.List[1]
 for _,v in ipairs(Z.List) do if distance>=v.start then found=v else break end end
 return found
end
-- Best throw distance includes sideways travel; it cannot prove area discovery.
function Z.unlocked(profile,id)
 local zone=Z.ById[id]
 if not zone then return false end
 if zone.start==0 then return true end
 local discoveries=profile and profile.discoveredZones
 if type(discoveries)~="table" then return false end
 if discoveries[id]==true then return true end
 -- Profile snapshots expose the same server-owned discoveries as a list.
 for _,value in ipairs(discoveries) do if value==id then return true end end
 return false
end
function Z.distanceAt(position)
 return math.max(0,position.X-Z.OriginX)
end
function Z.next(distance)
 for _,v in ipairs(Z.List) do if v.start>distance then return v end end
 return nil
end
return Z


