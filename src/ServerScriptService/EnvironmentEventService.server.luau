-- One server scheduler, replicated attributes; clients present the atmosphere.
local Config=require(game.ReplicatedStorage.Shared.EnvironmentEventConfig)
local rng=Random.new()
local function apply(event,endsAt)
 workspace:SetAttribute("GlobalMoneyMultiplier",event and event.money or 1)
 workspace:SetAttribute("GlobalEnchantedMultiplier",event and event.enchanted or 1)
 workspace:SetAttribute("GlobalTraitLuckMultiplier",event and event.traitLuck or 1)
 workspace:SetAttribute("GlobalEventName",event and event.name or "")
 workspace:SetAttribute("GlobalEventDescription",event and event.description or "")
 workspace:SetAttribute("GlobalEventEndsAt",endsAt or 0)
 workspace:SetAttribute("GlobalEventId",event and event.id or "")
end
apply(nil)
local previous
while true do
 task.wait(rng:NextInteger(Config.QuietMinimum,Config.QuietMaximum))
 local choices={} for _,event in ipairs(Config.List) do if event.id~=previous then table.insert(choices,event) end end
 local event=choices[rng:NextInteger(1,#choices)]
 previous=event.id
 apply(event,workspace:GetServerTimeNow()+Config.Duration)
 task.wait(Config.Duration)
 apply(nil)
end
