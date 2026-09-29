-- Server-local rare events. Normal progression never depends on an event.
local C={}
C.QuietMinimum=15*60
C.QuietMaximum=23*60
C.Duration=180
C.List={
 {id="enchanted_surge",name="ENCHANTED SURGE",description="Enchanted summon chance: 1% → 2%",money=1,enchanted=2,traitLuck=1,color=Color3.fromRGB(133,255,217),tint=Color3.fromRGB(210,255,239)},
 {id="golden_tide",name="GOLDEN TIDE",description="2x money earned from throws",money=2,enchanted=1,traitLuck=1,color=Color3.fromRGB(255,213,98),tint=Color3.fromRGB(255,238,202)},
 {id="trait_storm",name="TRAIT STORM",description="Better forge odds • Legendary remains rare",money=1,enchanted=1,traitLuck=1.65,color=Color3.fromRGB(190,147,255),tint=Color3.fromRGB(229,216,255)},
}
C.ById={} for _,event in ipairs(C.List) do C.ById[event.id]=event end
return C
