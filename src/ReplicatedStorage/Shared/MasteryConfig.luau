--!strict
-- Permanent per-copy mastery. XP is awarded only by accepted server throws.
local M = {}
M.MaxLevel = 10
M.SkipShardChance = 0.003
M.MaxShardsPerThrow = 2
function M.threshold(level: number): number
 return math.floor(100 * level * level + 100 * level)
end
function M.level(xp: number?): number
 local value = math.clamp(tonumber(xp) or 0, 0, M.threshold(M.MaxLevel))
 local level = 0
 while level < M.MaxLevel and value >= M.threshold(level + 1) do level += 1 end
 return level
end
function M.progress(record: any): any
 local xp = record and record.xp or 0
 local level = M.level(xp)
 return {level=level, xp=xp, into=xp-M.threshold(level), needed=level==M.MaxLevel and 0 or M.threshold(level+1)-M.threshold(level), title=level>=10 and "Stonebound" or level>=5 and "River Adept" or level>=1 and "Apprentice" or "Untrained"}
end
function M.award(distance: number, skips: number, record: boolean, completions: number, multiplier: number?): number
 return math.floor(math.min(95, 4 + math.sqrt(math.max(0,distance))*0.8 + math.min(skips,30)*0.6 + (record and 12 or 0) + math.min(completions,5)*12) * math.clamp(multiplier or 1,1,1.35))
end
return M
