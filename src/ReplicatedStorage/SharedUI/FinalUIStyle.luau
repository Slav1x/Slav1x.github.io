local S={}
S.navy=Color3.fromRGB(12,27,48)
S.cash="rbxassetid://127824684237342"
function S.new(c,p,n,props)
 local x=Instance.new(c) x.Name=n
 for k,v in props or {} do x[k]=v end
 x.Parent=p return x
end
function S.round(x,r) local c=x:FindFirstChildOfClass("UICorner") or S.new("UICorner",x,"Corners") c.CornerRadius=UDim.new(0,r or 12) end
function S.stroke(x,c,t)
 local st=x:FindFirstChildOfClass("UIStroke") or S.new("UIStroke",x,"Outline")
 st.Color=c or S.navy st.Thickness=t or 2
 if x:IsA("TextLabel") or x:IsA("TextButton") then st.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual end
 return st
end
function S.gradient(x,top,bottom)
 local g=x:FindFirstChildOfClass("UIGradient") or S.new("UIGradient",x,"Gradient")
 g.Rotation=90 g.Color=ColorSequence.new(top,bottom) return g
end
function S.label(p,n,text,pos,size,fs,color)
 local x=S.new("TextLabel",p,n,{BackgroundTransparency=1,Position=pos,Size=size,Text=text,Font=Enum.Font.FredokaOne,TextSize=fs or 20,TextColor3=color or Color3.new(1,1,1),ZIndex=p.ZIndex+3})
 S.stroke(x,nil,1.6) return x
end
function S.pattern(p,dark)
 local old=p:FindFirstChild("QuietPattern") if old then old:Destroy() end
 local f=S.new("Frame",p,"QuietPattern",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ClipsDescendants=true,ZIndex=p.ZIndex})
 for i=1,24 do
  local x=S.new("Frame",f,"Diamond"..i,{BorderSizePixel=0,BackgroundColor3=dark and Color3.new(1,1,1) or Color3.fromRGB(101,150,177),BackgroundTransparency=dark and .965 or .95,Size=UDim2.fromOffset(28,28),Rotation=45,Position=UDim2.fromScale(((i-1)%8)/7,(math.floor((i-1)/8)+.3)/3),ZIndex=f.ZIndex})
 end
end
function S.button(p,n,text,pos,size,c)
 local b=S.new("TextButton",p,n,{Position=pos,Size=size,Text="",AutoButtonColor=false,BorderSizePixel=0,BackgroundColor3=c:Lerp(S.navy,.55),ZIndex=p.ZIndex+3})
 S.round(b,10) S.stroke(b)
 local f=S.new("Frame",b,"Face",{Position=UDim2.fromOffset(2,2),Size=UDim2.new(1,-4,1,-7),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=b.ZIndex+1})
 S.round(f,8) S.gradient(f,c:Lerp(Color3.new(1,1,1),.3),c:Lerp(S.navy,.12))
 S.label(b,"Label",text,UDim2.fromOffset(3,0),UDim2.new(1,-6,1,-4),20)
 S.new("UIScale",b,"ButtonScale")
 return b
end
function S.calendar(p)
 local f=S.new("Frame",p,"Calendar",{Position=UDim2.fromScale(.22,.12),Size=UDim2.fromScale(.56,.59),BackgroundColor3=Color3.fromRGB(249,253,255),BorderSizePixel=0,ZIndex=p.ZIndex+4})
 S.round(f,7) S.stroke(f)
 local top=S.new("Frame",f,"RedTop",{Size=UDim2.fromScale(1,.29),BackgroundColor3=Color3.fromRGB(255,70,94),BorderSizePixel=0,ZIndex=f.ZIndex+1}) S.round(top,6)
 S.label(f,"Date","7",UDim2.fromScale(0,.26),UDim2.fromScale(1,.68),24,S.navy).Outline.Enabled=false
 for _,x in {.22,.7} do local ring=S.new("Frame",f,"Ring",{Size=UDim2.fromScale(.09,.25),Position=UDim2.fromScale(x,-.12),BackgroundColor3=S.navy,BorderSizePixel=0,ZIndex=f.ZIndex+2}) S.round(ring,3) end
end
return S
