--!strict
-- Shared presentation and swept collision math; effects are applied only by the server.
local C = {}
C.MaxSpeed = 520 -- a boost never reduces an already faster rock
C.MaxNitro = 3
local function powerScale(multiplier: number?): number
	return if multiplier==2 then 2 else 1
end
-- Multiply the boost gained, not the pebble's incoming speed. The original
-- boost bound is applied first, so a stronger trait doubles the actual gain.
function C.boostValues(speed: number,mul: number,add: number,lift: number,multiplier: number?): (number,number,number)
	local scale=powerScale(multiplier)
	local normal=math.max(speed,math.min(math.max(70,speed*mul+add),C.MaxSpeed))
	return speed+(normal-speed)*scale,lift*scale,2*scale
end
function C.nitroCapacity(multiplier: number?): number
	return C.MaxNitro*powerScale(multiplier)
end
function C.nitroRefill(charges: number,multiplier: number?): number
	return math.min(C.nitroCapacity(multiplier),charges+powerScale(multiplier))
end
C.CatchDuration = 1.12
C.PerfectStart = 0.50
C.PerfectEnd = 0.72
C.GoodStart = 0.30
C.GoodEnd = 0.91
C.CatchTiming = {
	Monkey = {perfectStart=0.41, perfectEnd=0.63, goodStart=0.24, goodEnd=0.88},
	Gorilla = {perfectStart=0.68, perfectEnd=0.92, goodStart=0.38, goodEnd=1.05},
}
C.ChainWindow = 7
C.Types = {
	Jet = {label="JET BOOST", color=Color3.fromRGB(62,221,255), radius=10, hitRadius=8, height=19, points=80},
	Nitro = {label="NITRO REFILL", color=Color3.fromRGB(255,158,38), radius=10, hitRadius=7, height=13, points=50},
	Bomb = {label="BLAST BOMB", color=Color3.fromRGB(255,116,83), radius=10, hitRadius=8, height=12, points=100},
	Monkey = {label="MONKEY KICK", color=Color3.fromRGB(255,218,99), radius=18, hitRadius=11, height=17, points=140},
	Gorilla = {label="GORILLA LAUNCH", color=Color3.fromRGB(121,245,144), radius=22, hitRadius=13, height=22, points=200},
	Log = {label="DRIFTWOOD", color=Color3.fromRGB(255,191,73), radius=13, height=5, points=0, cash=350, smashPoints=55},
	Rocks = {label="ROCK REEF", color=Color3.fromRGB(108,222,255), radius=12, height=12, points=0, cash=550, smashPoints=80},
	Whirlpool = {label="WHIRLPOOL", color=Color3.fromRGB(91,225,174), radius=19, height=7, points=160},
}
-- Segment versus upright cylinder. Includes start-inside and waterline padding.
function C.hit(from: Vector3, to: Vector3, center: Vector3, radius: number, height: number): number?
	local d=to-from
	local f=from-center
	local a=d.X*d.X+d.Z*d.Z
	local b=2*(f.X*d.X+f.Z*d.Z)
	local c=f.X*f.X+f.Z*f.Z-radius*radius
	local lo,hi=0,1
	if a<1e-8 then
		if c>0 then return nil end
	else
		local disc=b*b-4*a*c
		if disc<0 then return nil end
		lo=math.max(lo,(-b-math.sqrt(disc))/(2*a))
		hi=math.min(hi,(-b+math.sqrt(disc))/(2*a))
	end
	if math.abs(d.Y)<1e-8 then
		if f.Y < -2 or f.Y > height then return nil end
	else
		local t1,t2=(-2-f.Y)/d.Y,(height-f.Y)/d.Y
		lo=math.max(lo,math.min(t1,t2));hi=math.min(hi,math.max(t1,t2))
	end
	return if lo<=hi then lo else nil
end
return C

