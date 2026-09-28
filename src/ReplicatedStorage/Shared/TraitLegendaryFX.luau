-- Legendary-only prismatic reveal; entirely local and cancellable.
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local FX = {}
function FX.play(model, reelFrame, reduced)
	local folder = Instance.new("Folder")
	folder.Name = "TraitLegendaryPayoff"
	folder.Parent = workspace
	local objects, sounds, tweens = {}, {}, {}
	local elapsed, connection, stopped = 0, nil, false
	local colors = {Color3.fromRGB(255,222,117),Color3.fromRGB(124,244,255),Color3.fromRGB(232,143,255)}
	local function own(object) table.insert(objects,object);return object end
	local function tween(object,time,properties)
		local t=TweenService:Create(object,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties)
		table.insert(tweens,t);t:Play()
	end
	local function sound(name,speed,volume)
		local source=SoundService:FindFirstChild("SFX")
		source=source and source:FindFirstChild(name)
		if not source then return end
		local s=source:Clone();s.Name="TraitLegendary_"..name
		s.PlaybackSpeed=speed;s.Volume=volume;s.Parent=SoundService
		table.insert(sounds,s);s:Play()
	end
	local function stop()
		if stopped then return end
		stopped=true
		if connection then connection:Disconnect() end
		for _,t in tweens do t:Cancel() end
		for _,s in sounds do s:Destroy() end
		for _,o in objects do o:Destroy() end
		folder:Destroy()
	end
	local center=model and model:GetPivot().Position
	if center then
		local host=Instance.new("Part");host.Name="LegendaryLight"
		host.Size=Vector3.one*.1;host.Transparency=1;host.Anchored=true
		host.CanCollide=false;host.CanTouch=false;host.CanQuery=false;host.Position=center;host.Parent=folder
		local light=Instance.new("PointLight");light.Color=colors[1];light.Range=16
		light.Brightness=reduced and 1.4 or 7;light.Parent=host
		tween(light,1.1,{Brightness=0})
		local highlight=Instance.new("Highlight");highlight.Adornee=model
		highlight.DepthMode=Enum.HighlightDepthMode.Occluded
		highlight.FillColor=colors[1];highlight.OutlineColor=Color3.new(1,1,1)
		highlight.FillTransparency=reduced and .8 or .45;highlight.OutlineTransparency=.1;highlight.Parent=folder
		tween(highlight,1.2,{FillTransparency=1,OutlineTransparency=1})
		if not reduced then
			local attachment=Instance.new("Attachment",host)
			local burst=Instance.new("ParticleEmitter")
			burst.Texture="rbxasset://textures/particles/sparkles_main.dds";burst.Rate=0
			burst.Lifetime=NumberRange.new(.55,1.1);burst.Speed=NumberRange.new(4,8)
			burst.Drag=4;burst.SpreadAngle=Vector2.new(180,180)
			burst.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,colors[1]),ColorSequenceKeypoint.new(.5,colors[2]),ColorSequenceKeypoint.new(1,colors[3])})
			burst.Size=NumberSequence.new(.25,0);burst.Transparency=NumberSequence.new(.05,1)
			burst.LightEmission=1;burst.Parent=attachment;burst:Emit(64)
		end
	end
	local shards={}
	if center and not reduced then
		for i=1,12 do
			local p=Instance.new("Part");p.Name="PrismaticShard"
			p.Size=Vector3.new(.1,.34,.1);p.Material=Enum.Material.Neon;p.Color=colors[(i-1)%3+1]
			p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
			p.Position=center;p.Parent=folder
			local a=Instance.new("Attachment",p);a.Position=Vector3.new(0,.13,0)
			local b=Instance.new("Attachment",p);b.Position=Vector3.new(0,-.13,0)
			local trail=Instance.new("Trail");trail.Attachment0=a;trail.Attachment1=b;trail.Lifetime=.22
			trail.Color=ColorSequence.new(p.Color);trail.Transparency=NumberSequence.new(.15,1);trail.LightEmission=1;trail.Parent=p
			table.insert(shards,p)
		end
	end
	for i=1,(reduced and 1 or 3) do
		local ring=own(Instance.new("Frame"));ring.Name="LegendaryHalo"
		ring.AnchorPoint=Vector2.new(.5,.5);ring.Position=UDim2.fromScale(.5,.5)
		ring.Size=UDim2.fromOffset(148,88);ring.BackgroundTransparency=1;ring.ZIndex=9
		local corner=Instance.new("UICorner",ring);corner.CornerRadius=UDim.new(0,13)
		local edge=Instance.new("UIStroke");edge.Color=colors[i];edge.Thickness=reduced and 2 or 3
		edge.Transparency=.1;edge.Parent=ring;ring.Parent=reelFrame
		if not reduced then tween(ring,.45+i*.13,{Size=UDim2.fromOffset(180+i*52,92+i*13)}) end
		tween(edge,.5+i*.15,{Transparency=1})
	end
	-- A lower impact plus two ascending chimes distinguishes this from the normal reward.
	sound("SFX_Reward_Claimed",.72,.68)
	sound("UI_Menu_Open",.82,.28)
	local chime1,chime2,audioFading=false,false,false
	connection=RunService.RenderStepped:Connect(function(dt)
		elapsed+=dt
		if not model or not model.Parent or not reelFrame.Parent then stop();return end
		if elapsed>=.18 and not chime1 then chime1=true;sound("SFX_Reward_Claimed",1.18,.34) end
		if elapsed>=.36 and not chime2 then chime2=true;sound("SFX_Reward_Claimed",1.48,.26) end
		for i,p in shards do
			local u=math.min(elapsed/1.15,1)
			local angle=i/12*math.pi*2+u*2.5
			local radius=.8+math.sin(u*math.pi*.7)*2.1
			p.CFrame=CFrame.new(center+Vector3.new(math.cos(angle)*radius,u*3.7,math.sin(angle)*radius))*CFrame.Angles(u*2,angle,.4)
			p.Transparency=math.clamp((u-.4)/.6,0,1)
		end
		if elapsed>=1.25 and not audioFading then
			audioFading=true
			for _,s in sounds do tween(s,.3,{Volume=0}) end
		end
		if elapsed>=1.6 then stop() end
	end)
	return stop
end
return FX