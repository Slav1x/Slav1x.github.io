local cash=script.Parent
local K=require(cash.Parent.UIPolishKit)
local player=game:GetService("Players").LocalPlayer
local money=player:WaitForChild("leaderstats"):WaitForChild("Money")
local function compactCash(value)
 local n=math.max(0,tonumber(value) or 0)
 local units={"","K","M","B","T","Q"}
 local index=1
 while n>=1000 and index<#units do n/=1000 index+=1 end
 if index==1 then return string.format("%."..(n<10 and 2 or 1).."f",n) end
 local decimals=n<10 and 2 or 1
 local rounded=math.floor(n*10^decimals+.5)/10^decimals
 if rounded>=1000 and index<#units then rounded/=1000 index+=1 decimals=2 end
 return string.format("%."..decimals.."f",rounded)..units[index]
end
local plus=cash:WaitForChild("CashPacksPlus")
local function refresh()
 if cash.Parent:GetAttribute("BankingThrowRewards") == true or player:GetAttribute("RockInFlight") == true then return end
 cash.Value.Text="$"..compactCash(money.Value)
 
end
money.Changed:Connect(refresh)
cash.Parent:GetAttributeChangedSignal("BankingThrowRewards"):Connect(refresh)
player:GetAttributeChangedSignal("RockInFlight"):Connect(refresh)
refresh()

