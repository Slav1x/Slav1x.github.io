-- World forge lighting only. Driven by the reel's actual velocity and confirmed landing.
local Lighting = {}
local TAU = math.pi * 2
local GOLD = Color3.fromRGB(255, 208, 103)
local WHITE = Color3.fromRGB(255, 249, 230)

function Lighting.new(decor)
 local self = {clock=0, phase=0, speed=0, targetSpeed=0, kick=0, resultAge=10, resultRank=1, resultColor=GOLD, accumulator=0}
 local saved, runes, beams = {}, {}, {}
 local function remember(object, properties)
  local values = {}
  for _,property in properties do values[property] = object[property] end
  table.insert(saved, {object=object, values=values})
 end
 local energy = decor:WaitForChild("ForgeEnergy")
 local light = energy:WaitForChild("ForgeLight")
 remember(light, {"Color", "Brightness"})
 for _,object in decor:GetDescendants() do
  if object:IsA("BasePart") and (object.Name=="HaloRune" or object.Name=="HaloHeart" or object.Name=="AltarRune" or object.Name=="ShardVein") then
   remember(object, {"Color", "Transparency"})
   local offset = object.Position-energy.Position
   table.insert(runes, {part=object, color=object.Color, transparency=object.Transparency,
    phase=(math.atan2(offset.Z,offset.X)/TAU)%1})
  elseif object:IsA("Beam") and object.Name=="ForgeLightShaft" then
   remember(object, {"Color", "Brightness", "Width0", "Width1", "Transparency", "Enabled"})
   table.insert(beams, {beam=object, color=object.Color, width0=object.Width0, width1=object.Width1})
  end
 end
 local baseLightColor = light.Color
 function self:setSpeed(value)
  self.targetSpeed = math.clamp(value,0,1)
 end
 function self:tap()
  self.kick = 1
 end
 function self:land(color, rank)
  self.resultColor = color
  self.resultRank = math.clamp(rank,1,6)
  self.resultAge = 0
  self.targetSpeed = 0
 end
 function self:reset()
  self.targetSpeed = 0
  self.speed = 0
  self.kick = 0
  self.resultAge = 10
 end
 local function chase(position, phase)
  local distance = (phase-position)%1
  return math.exp(-distance*18)
 end
 function self:update(dt, nearby, state, reduced)
  if self.destroyed then return end
  self.accumulator += dt
  if self.accumulator<1/30 then return end
  local step = self.accumulator
  self.accumulator = 0
  self.resultAge += step
  self.kick *= math.exp(-step*7)
  if not nearby then return end
  step = math.min(step,.1)
  self.clock += step
  local spinning = state=="spinning"
  local waiting = state=="waiting" or state=="placing"
  local target = spinning and self.targetSpeed or 0
  self.speed += (target-self.speed)*(1-math.exp(-step*16))
  if not reduced then
   self.phase = (self.phase+step*(.12+self.speed*1.7+(waiting and .3 or 0)))%1
  end
  local breath = reduced and .5 or .5+.5*math.sin(self.clock*1.7)
  local payoff = state=="done" and math.exp(-self.resultAge/1.25) or 0
  local burst = reduced and 0 or payoff*(.35+self.resultRank*.08)
  local kick = reduced and 0 or self.kick
  local strength = reduced and .15 or self.speed
  for _,entry in runes do
   if entry.part.Parent then
    local wave = reduced and 0 or chase(entry.phase,self.phase)
    local level = math.clamp(.42+breath*.15+wave*.35+strength*.16+burst*.4+kick*.2,0,1)
    local color = entry.color:Lerp(GOLD,strength*.45):Lerp(self.resultColor,payoff)
    entry.part.Color = color:Lerp(WHITE,math.max(0,level-.65)*.65)
    entry.part.Transparency = math.clamp(entry.transparency+(1-level)*.32,0,1)
   end
  end
  light.Color = baseLightColor:Lerp(GOLD,strength*.45):Lerp(self.resultColor,payoff)
  light.Brightness = (reduced and 1.1 or .85+breath*.35+strength*1.5+burst*1.2+kick*.45) * (decor:GetAttribute("AmbientLightScale") or 1)
  for index,entry in beams do
   local beam = entry.beam
   if beam.Parent then
    -- Smooth independent shimmer and a traveling bright band bring untextured shafts to life.
    local shimmer = reduced and .5 or .5+.5*math.noise(self.clock*3,index*7)
    local power = math.clamp(.22+breath*.12+strength*.38+burst*.3+kick*.15,0,1)
    beam.Color = ColorSequence.new(light.Color)
    beam.Brightness = .7+power*1.7+shimmer*.2
    beam.Width0 = entry.width0*(.8+power*.85)
    beam.Width1 = entry.width1*(.9+power*.6)
    if reduced then
     beam.Transparency = NumberSequence.new(.72,1)
    else
     local band = .12+((self.phase+(index-1)*.5)%1)*.76
     local low = math.clamp(.77-power*.25,0,1)
     beam.Transparency = NumberSequence.new({
      NumberSequenceKeypoint.new(0,.8),
      NumberSequenceKeypoint.new(band-.08,.87),
      NumberSequenceKeypoint.new(band,low),
      NumberSequenceKeypoint.new(band+.08,.87),
      NumberSequenceKeypoint.new(1,1),
     })
    end
   end
  end
 end
 function self:destroy()
  if self.destroyed then return end
  self.destroyed = true
  for _,entry in saved do
   if entry.object.Parent then
    for property,value in entry.values do entry.object[property]=value end
   end
  end
 end
 return self
end
return Lighting
