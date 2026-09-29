-- Presentation data only. It never changes throws, rewards, discovery, or collision.
local Zones=require(script.Parent.ZoneConfig)
local B={}
local rgb=Color3.fromRGB
local function mood(id,clock,tint,fog,decay,ambient,outdoor,water,mote,rate,mist,sun,audio)
 return {id=id,clock=clock,tint=tint,fog=fog,decay=decay,ambient=ambient,outdoor=outdoor,water=water,mote=mote,moteRate=rate,mistRate=mist,sun=sun,audio=audio,
  brightness=2.2,exposure=.08,density=.16,haze=.35,saturation=.025,contrast=.045,stars=1200}
end
B.ById={
 driftwood=mood('driftwood',12.3,rgb(255,253,245),rgb(207,231,239),rgb(163,193,208),rgb(147,163,179),rgb(191,209,220),rgb(190,239,244),rgb(255,230,171),5,.75,1,{lake=.15,shore=.11,speed=1,low=0,mid=0,high=-1,wet=-80,decay=1.5}),
 blossom=mood('blossom',14.1,rgb(255,248,253),rgb(242,218,234),rgb(197,179,210),rgb(171,161,184),rgb(219,206,223),rgb(255,209,227),rgb(255,191,216),5,.5,.7,{lake=.09,shore=.085,speed=.95,low=0,mid=-2,high=-3,wet=-30,decay=1.8}),
 sunscorch=mood('sunscorch',13.2,rgb(255,249,230),rgb(242,217,176),rgb(214,179,140),rgb(178,157,136),rgb(226,207,174),rgb(158,234,211),rgb(242,209,159),2,.15,.9,{lake=.022,shore=.055,speed=.86,low=-1,mid=-4,high=-8,wet=-80,decay=1.5}),
 inferno=mood('inferno',16.55,rgb(255,244,228),rgb(242,201,169),rgb(192,151,139),rgb(181,151,145),rgb(220,180,159),rgb(255,180,72),rgb(255,191,100),3,.12,.22,{lake=0,shore=.052,speed=.72,low=3,mid=-8,high=-14,wet=-27,decay=2}),
 cosmic=mood('cosmic',17.3,rgb(249,246,255),rgb(209,205,246),rgb(162,167,222),rgb(174,168,207),rgb(207,201,235),rgb(189,192,255),rgb(200,215,255),3,.3,.15,{lake=0,shore=.05,speed=.78,low=1,mid=-7,high=-12,wet=-16,decay=3.1}),
}
B.ById.candy=mood('candy',13.8,rgb(255,247,252),rgb(246,215,234),rgb(196,164,199),rgb(153,132,161),rgb(208,183,211),rgb(129,215,218),rgb(255,205,230),7,.5,.6,{lake=.08,shore=.06,speed=1.05,low=0,mid=-1,high=-2,wet=-26,decay=1.8})
B.ById.frozen=mood('frozen',11.6,rgb(234,247,255),rgb(211,238,246),rgb(141,180,208),rgb(132,156,184),rgb(188,219,235),rgb(162,225,244),rgb(238,251,255),12,.9,.5,{lake=.04,shore=.07,speed=.85,low=-2,mid=-3,high=-6,wet=-22,decay=2.6})
B.ById.toxic=mood('toxic',15.6,rgb(242,252,225),rgb(195,212,158),rgb(137,159,117),rgb(132,152,133),rgb(182,203,165),rgb(132,195,74),rgb(195,243,99),6,.7,.2,{lake=.02,shore=.06,speed=.75,low=2,mid=-5,high=-10,wet=-20,decay=2.2})
B.ById.crystal=mood('crystal',14.2,rgb(235,231,255),rgb(116,110,162),rgb(68,74,115),rgb(102,103,149),rgb(109,117,154),rgb(137,207,249),rgb(186,164,250),4,.45,0,{lake=.035,shore=.045,speed=.8,low=0,mid=-4,high=-8,wet=-18,decay=3.6})
B.ById.crystal.brightness=2.2
B.ById.crystal.exposure=.12
B.ById.crystal.density=.12
B.ById.crystal.ambient=rgb(139,134,166)
B.ById.crystal.outdoor=rgb(157,161,189)
B.ById.sunscorch.density=.12
B.ById.inferno.density=.13
B.ById.inferno.exposure=.12
B.ById.cosmic.exposure=.16
B.ById.cosmic.density=.18
B.ById.cosmic.stars=3800
B.ById.cosmic.clock=20.1
B.ById.inferno.clock=18.2
B.ById.frozen.haze=.65
B.ById.toxic.haze=.8
B.ById.crystal.haze=.55
-- Preserve shadow shape and saturated materials; the sky supplies the daylight.
for _,profile in pairs(B.ById) do
 profile.ambient=profile.ambient:Lerp(rgb(115,128,145),.28)
 profile.outdoor=profile.outdoor:Lerp(rgb(155,174,192),.36)
end
-- Cohesive daylight: controlled chroma, lower fill and less haze preserve form.
for id,p in pairs(B.ById) do
 p.saturation=(id=='candy' or id=='frozen') and .085 or .12
 p.contrast=id=='crystal' and .10 or .12
 p.density=math.min(p.density,.115)
 p.haze=math.min(p.haze,.28)
 p.ambient=p.ambient:Lerp(rgb(84,103,128),.36)
 p.outdoor=p.outdoor:Lerp(rgb(140,160,181),.28)
 p.brightness=2.5
end
B.ById.driftwood.ambient=rgb(96,112,130)
B.ById.driftwood.outdoor=rgb(145,163,183)
B.ById.driftwood.tint=rgb(255,254,248)
B.ById.crystal.ambient=rgb(126,116,169)
B.ById.crystal.outdoor=rgb(143,153,199)
B.ById.crystal.saturation=.14
B.ById.inferno.ambient=rgb(142,104,109)
B.ById.cosmic.ambient=rgb(128,112,179)
B.ById.cosmic.outdoor=rgb(150,156,205)
local function blend(a,b,t)
 local result={}
 for key,value in pairs(a) do
  local other=b[key]
  if typeof(value)=='Color3' then result[key]=value:Lerp(other,t)
  elseif type(value)=='number' then result[key]=value+(other-value)*t
  elseif type(value)=='table' then result[key]=blend(value,other,t)
  else result[key]=t<.5 and value or other end
 end
 return result
end
function B.sample(distance)
 distance=math.max(0,distance)
 for i=2,#Zones.List do
  local boundary=Zones.List[i].start
  local previousLength=Zones.List[i-1].finish-Zones.List[i-1].start
  local nextLength=Zones.List[i].finish-Zones.List[i].start
  local width=math.min(300,previousLength*.18,nextLength*.18)
  if distance>=boundary-width and distance<=boundary+width then
   local t=math.clamp((distance-boundary+width)/(2*width),0,1)
   t=t*t*(3-2*t)
   return blend(B.ById[Zones.List[i-1].id],B.ById[Zones.List[i].id],t)
  end
 end
 return B.ById[Zones.forDistance(distance).id]
end
function B.at(position) return B.sample(Zones.distanceAt(position)) end
function B.event()
 local id=workspace:GetAttribute('GlobalEventId')
 if type(id)~='string' or id=='' or (workspace:GetAttribute('GlobalEventEndsAt') or 0)<=workspace:GetServerTimeNow() then return nil end
 return require(script.Parent.EnvironmentEventConfig).ById[id]
end
return B



