-- Shared budgets. Four seconds of decisions plus replication jitter at actual speed.
local W = { MaxModels=128, MaxWaterParts=160, UpdateSeconds=.15 }
function W.lead(speed)
 return math.clamp(math.max(0,speed)*4+700,1400,10000)
end
function W.notice(speed)
 return math.clamp(math.max(0,speed)*3+300,450,8000)
end
return table.freeze(W)
