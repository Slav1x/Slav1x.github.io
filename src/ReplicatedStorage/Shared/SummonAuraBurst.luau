-- Legendary-or-higher geodes throw 3D shell chunks into a transparent screen layer.
-- Higher tiers add stronger shockwaves, rays, and more foreground debris.
-- Driven by SummonAnticipationFX; no independent connections or camera ownership.
local Burst={}
Burst.__index=Burst
local GOLD=Color3.fromRGB(255,203,65)
local PINK=Color3.fromRGB(255,100,223)
local CYAN=Color3.fromRGB(90,250,255)
local WHITE=Color3.fromRGB(255,250,235)
local function frame(parent,name,color)
 local f=Instance.new("Frame")
 f.Name=name;f.BorderSizePixel=0;f.BackgroundColor3=color
 f.BackgroundTransparency=1;f.AnchorPoint=Vector2.new(.5,.5)
 f.Active=false;f.Parent=parent
 return f
end
function Burst.new(parent,position,tier,seed)
 if type(tier)~="number" or tier~=tier or tier==math.huge or tier<5 then return nil end
 tier=math.floor(tier)
 local escalation=tier-5
 local intensity=math.min(4.1,2.1+.7*escalation)
 local rockCount=math.min(34,18+8*escalation)
 local camera=workspace.CurrentCamera
 if not camera then return nil end
 local point,visible=camera:WorldToViewportPoint(position)
 if not visible then return nil end
 local myth=tier>=6
 local color=myth and PINK or GOLD
 local random=Random.new(seed)
 local gui=Instance.new("ScreenGui")
 gui.Name="SummonAuraBurst";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=45
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local canvas=frame(gui,"TransparentCanvas",color)
 canvas.AnchorPoint=Vector2.zero;canvas.Size=UDim2.fromScale(1,1)
 local viewport=camera.ViewportSize
 local origin=Vector2.new(point.X/math.max(1,viewport.X),point.Y/math.max(1,viewport.Y))
 local self=setmetatable({gui=gui,canvas=canvas,tier=tier,myth=myth,color=color,
  origin=origin,age=0,intensity=intensity,duration=1+intensity*.2,rocks={},rays={},rings={}},Burst)
 local flash=Instance.new("ImageLabel")
 flash.Name="AuraCoreFlare";flash.BackgroundTransparency=1;flash.Active=false
 flash.AnchorPoint=Vector2.new(.5,.5);flash.Image="rbxasset://textures/particles/sparkles_main.dds"
 flash.ImageColor3=WHITE;flash.ImageTransparency=1;flash.ZIndex=3;flash.Parent=canvas
 self.flash=flash
 -- Hollow shockwaves expand away from the item; no opaque screen cover.
 for i=1,math.min(5,3+escalation) do
  local circle=frame(canvas,"AuraShockwave"..i,i==2 and CYAN or color)
  circle.ZIndex=2
  local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=circle
  local stroke=Instance.new("UIStroke");stroke.Color=i==2 and CYAN or color
  stroke.Thickness=myth and 4.5 or 3;stroke.Transparency=1;stroke.Parent=circle
  self.rings[i]={frame=circle,stroke=stroke,delay=(i-1)*.13}
 end
 -- Thin, tapered energy rays provide speed and parallax instead of debris coverage.
 local count=math.min(44,24+8*escalation)
 for i=1,count do
  local angle=(i-1)/count*math.pi*2+random:NextNumber(-.09,.09)
  local ray=frame(canvas,"AuraRay"..i,myth and (i%2==0 and CYAN or PINK) or GOLD)
  ray.ZIndex=2;ray.Rotation=math.deg(angle)
  local gradient=Instance.new("UIGradient")
  gradient.Transparency=NumberSequence.new({
   NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.65,.15),
   NumberSequenceKeypoint.new(.9,0),NumberSequenceKeypoint.new(1,1)})
  gradient.Parent=ray
  local glow=ray:Clone();glow.Name="AuraRayGlow"..i;glow.ZIndex=1;glow.Parent=canvas
  ray.BackgroundColor3=ray.BackgroundColor3:Lerp(WHITE,.3)
  self.rays[i]={frame=ray,glow=glow,angle=angle,delay=myth and i%2*.13 or random:NextNumber(0,.035),
   speed=random:NextNumber(.9,1.2),width=random:NextNumber(2.2,4.2)*math.min(1.8,intensity/1.5)}
 end
 local view=Instance.new("ViewportFrame")
 view.Name="ScreenShellDebris";view.BackgroundTransparency=1;view.Size=UDim2.fromScale(1,1)
 view.Active=false;view.Ambient=Color3.fromRGB(180,174,190)
 view.LightColor=color;view.LightDirection=Vector3.new(-1,-1,-1);view.ZIndex=4;view.Parent=canvas
 local world=Instance.new("WorldModel");world.Parent=view
 local lens=Instance.new("Camera");lens.CFrame=CFrame.new();lens.FieldOfView=70
 lens.Parent=view;view.CurrentCamera=lens
 -- Readable, substantial shell chunks rush at the lens, then separate and fall away.
 for i=1,rockCount do
  local angle=(i-1)/rockCount*math.pi*2+random:NextNumber(-.2,.2)
  local p=Instance.new(i%2==0 and "WedgePart" or "Part")
  p.Name="AuraShellFragment";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
  p.CastShadow=false;p.Material=Enum.Material.Slate
  p.Color=Color3.fromRGB(87,80,102):Lerp(Color3.new(1,1,1),.25)
  p.Transparency=1;p.Parent=world
  local foreground=i%3==1
  local scale=foreground and (.75+intensity*.15) or intensity
  self.rocks[i]={part=p,angle=angle,spin=random:NextNumber(-9,9),foreground=foreground,
   size=Vector3.new(random:NextNumber(.55,.95),random:NextNumber(.4,.75),random:NextNumber(.3,.55))*scale,
   spread=random:NextNumber(.72,1.15),landing=random:NextNumber(.14,.43),
   drift=random:NextNumber(-.4,.4),flight=random:NextNumber(.15,.22),
   delay=random:NextNumber(0,.05)}
 end
 return self
end
function Burst:step(dt)
 if self.destroyed then return 0 end
 self.age+=dt
 local t=self.age
 if t>=self.duration then self:destroy();return 0 end
 local size=self.canvas.AbsoluteSize
 local w,h=math.max(1,size.X),math.max(1,size.Y)
 local unit=math.min(w,h)
 local origin=Vector2.new(self.origin.X*w,self.origin.Y*h)
 local function place(f,p) f.Position=UDim2.fromOffset(p.X,p.Y) end
 -- Localized flare only: brief bright core with a quick, smooth falloff.
 local pulse=math.min(t/.035,1)*math.exp(-t*13)
 if self.myth then
  local after=math.max(0,t-.16)
  pulse+=.5*math.min(after/.035,1)*math.exp(-after*15)
 end
 place(self.flash,origin)
 local diameter=unit*(.08+.32*self.intensity*(1-math.exp(-t*18)))
 self.flash.Size=UDim2.fromOffset(diameter,diameter)
 self.flash.ImageTransparency=1-math.min(.72,pulse*.72)
 self.flash.Rotation=t*(self.myth and 85 or 35)
 for _,ring in self.rings do
  local age=t-ring.delay
  local u=math.clamp(age/.62,0,1)
  local radius=unit*(.035+(.72+.12*math.min(self.tier-5,3))*self.intensity/2.1*(1-(1-u)^3))
  place(ring.frame,origin);ring.frame.Size=UDim2.fromOffset(radius*2,radius*2)
  local opacity=age>=0 and math.min(age/.035,1)*(1-u)^2*.8 or 0
  ring.stroke.Transparency=1-opacity
  ring.stroke.Thickness=3*self.intensity*(1-u*.6)
 end
 for _,ray in self.rays do
  local age=t-ray.delay
  local u=math.clamp(age/.55,0,1)
  local radius=unit*(.045+.95*self.intensity/1.7*u^.7*ray.speed)
  local length=unit*(.025+(self.myth and .19 or .12)*self.intensity/1.7*math.sin(math.pi*u))
  local a=ray.angle+(self.myth and .11*math.sin(math.pi*u) or 0)
  place(ray.frame,origin+Vector2.new(math.cos(a),math.sin(a))*radius)
  ray.frame.Rotation=math.deg(a)
  ray.frame.Size=UDim2.fromOffset(length,ray.width*(1-u*.65))
  local opacity=age>=0 and math.sin(math.pi*u)^.6 or 0
  ray.frame.BackgroundTransparency=1-opacity*.9
  ray.glow.Position=ray.frame.Position;ray.glow.Rotation=ray.frame.Rotation
  ray.glow.Size=UDim2.fromOffset(length*1.05,ray.width*4*(1-u*.65))
  ray.glow.BackgroundTransparency=1-opacity*.16
 end
 local halfY=math.tan(math.rad(35))
 local aspect=w/h
 for _,rock in self.rocks do
  local age=t-rock.delay
  local u=math.clamp(age/.75,0,1)
  local arrival=math.clamp(age/rock.flight,0,1)
  local rush=1-(1-arrival)^3
  local clearing=math.max(0,age-rock.flight)
  local direction=Vector2.new(math.cos(rock.angle),math.sin(rock.angle))
  local tangent=Vector2.new(-direction.Y,direction.X)
  local radius=rock.foreground and unit*(.015+rock.landing*rush)
   or unit*(.015+.28*self.intensity/1.5*rush*rock.spread+clearing*.9)
  local pixel=origin+direction*radius
   +tangent*unit*rock.drift*clearing
   +Vector2.new(0,unit*clearing*clearing*(rock.foreground and 1.5 or 1.8))
  local depth=22-(rock.foreground and 20 or 18)*rush
  local position=Vector3.new((pixel.X/w*2-1)*depth*halfY*aspect,
   (1-pixel.Y/h*2)*depth*halfY,-depth)
  rock.part.CFrame=CFrame.new(position)*CFrame.Angles(u*rock.spin,u*rock.spin*.7,rock.angle+u*rock.spin)
  rock.part.Size=rock.size*(.08+.92*rush)
  rock.part.Transparency=age<0 and 1 or math.clamp((age-(rock.foreground and .42 or .24))/(rock.foreground and .5 or .42),0,1)
 end
 -- A small, decaying backward impulse; the summon shot and angle stay unchanged.
 local kick=math.sin(math.min(t/.13,1)*math.pi*.5)*math.exp(-t*11)*.16*self.intensity
 if self.myth and t>.16 then
  local after=t-.16
  kick+=math.sin(math.min(after/.1,1)*math.pi*.5)*math.exp(-after*14)*.1*self.intensity
 end
 return kick
end
function Burst:destroy()
 if self.destroyed then return end
 self.destroyed=true;self.gui:Destroy()
end
return Burst
