-- Bounded client reveal accent; driven by the presenter's existing render connection.
local Reveal={}
Reveal.__index=Reveal
local Curves=require(script.Parent.SummonBezierVFX)
function Reveal.new(parent,position,color,tier,reduced,seed)
 local folder=Instance.new("Folder");folder.Name="ItemRevealPayoff";folder.Parent=parent
 local host=Instance.new("Part");host.Name="RevealOrigin";host.Anchored=true
 host.CanCollide=false;host.CanTouch=false;host.CanQuery=false;host.Transparency=1;host.Size=Vector3.one
 host.Position=position;host.Parent=folder
 local blast=tier>=5 and math.min(3.2,2+(tier-5)*.6) or 1
 local self=setmetatable({folder=folder,host=host,position=position,color=color,tier=tier,
  reduced=reduced,blast=blast,age=0,rings={},wave=0},Reveal)
 self.curves=Curves.new(folder,position,color,seed)
 local light=Instance.new("PointLight");light.Name="RevealFlare";light.Color=color
 light.Range=(10+tier)*blast;light.Shadows=false;light.Brightness=0;light.Parent=host;self.light=light
 local flare=Instance.new("ParticleEmitter");flare.Name="EmergenceFlare";flare.Rate=0
 flare.Texture="rbxasset://textures/particles/sparkles_main.dds";flare.Speed=NumberRange.new(0)
 flare.Lifetime=NumberRange.new(reduced and .45 or .65);flare.LightEmission=1;flare.LightInfluence=0
 flare.Color=ColorSequence.new(Color3.new(1,1,1),color)
 local size=reduced and 1.4 or (2+tier*.38)*blast
 flare.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(.12,size),NumberSequenceKeypoint.new(1,0)})
 flare.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(.12,.08),NumberSequenceKeypoint.new(1,1)})
 flare.Rotation=NumberRange.new(0,180);flare.Parent=host;flare:Emit(1)
 if not reduced then
  self.curves:emit("burst",math.min(32,math.ceil((8+tier*2)*blast)),math.min(4.8,(2.3+tier*.12)*blast),.8)
  for ringIndex=1,(tier>=5 and math.min(4,tier-2) or 1) do
   local ring={attachments={},beams={},delay=(ringIndex-1)*(tier>=5 and .13 or .18)}
   for i=1,32 do
    local a=Instance.new("Attachment");a.Parent=host;ring.attachments[i]=a
   end
   for i=1,32 do
    local beam=Instance.new("Beam");beam.Name="RevealShockwave"
    beam.Attachment0=ring.attachments[i];beam.Attachment1=ring.attachments[i%32+1]
    beam.FaceCamera=true;beam.LightEmission=1;beam.LightInfluence=0
    beam.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.45),color)
    beam.Width0=.08;beam.Width1=.08;beam.Transparency=NumberSequence.new(1)
    beam.Parent=host;ring.beams[i]=beam
   end
   table.insert(self.rings,ring)
  end
 end
 return self
end
function Reveal:attach(model)
 if self.destroyed or not model or not model:IsA("Model") or not model.Parent then return end
 self.model=model
 if not self.highlight then
  local h=Instance.new("Highlight");h.Name="RewardRimGlow";h.DepthMode=Enum.HighlightDepthMode.Occluded
  h.FillColor=self.color;h.OutlineColor=self.color:Lerp(Color3.new(1,1,1),.55)
  h.FillTransparency=1;h.OutlineTransparency=1;h.Parent=self.folder;self.highlight=h
 end
 self.highlight.Adornee=model
end
function Reveal:step(dt)
 if self.destroyed then return end
 self.age+=dt
 local t=self.age
 if t>=2 then self:destroy();return end
 local center=self.position
 if self.model and self.model.Parent then local bounds=self.model:GetBoundingBox();center=bounds.Position end
 self.host.Position=center;self.curves.center=center
 if not self.reduced then
  -- Staggered accents survive an instant Open -> Result when clicks skip the rise.
  local wave=t>=.38 and 2 or (t>=.16 and 1 or 0)
  if wave>self.wave then
   self.wave=wave
   self.curves:emit("ribbon",math.min(32,math.ceil((4+self.tier)*self.blast)),math.min(4.8,(2.4+self.tier*.1)*self.blast),1.05)
  end
 end
 self.curves:step(dt)
 local envelope=math.min(t/.06,1)*math.exp(-t*3)
 self.light.Brightness=(self.reduced and 1.5 or (3+self.tier*.65)*self.blast)*envelope
 if self.highlight then
  local glow=math.min(t/.09,1)*math.clamp((1.8-t)/1.35,0,1)
  self.highlight.FillTransparency=1-glow*.12
  self.highlight.OutlineTransparency=1-glow*(self.reduced and .35 or .8)
 end
 for _,ring in self.rings do
  local u=math.clamp((t-ring.delay)/.7,0,1)
  local radius=.35+(2.2+self.tier*.1)*self.blast*(1-(1-u)^3)
  for i,a in ring.attachments do
   local angle=(i-1)*math.pi*2/32
   a.Position=Vector3.new(math.cos(angle)*radius,self.position.Y-center.Y-.9,math.sin(angle)*radius)
  end
  local opacity=(t>=ring.delay and u<1) and math.sin(math.pi*u)^.65*.85 or 0
  for _,beam in ring.beams do
   beam.Transparency=NumberSequence.new(1-opacity)
   beam.Width0=(.07+self.tier*.012)*self.blast*(1-u*.65);beam.Width1=beam.Width0
  end
 end
end
function Reveal:destroy()
 if self.destroyed then return end
 self.destroyed=true;self.curves:destroy();self.folder:Destroy()
end
return Reveal
