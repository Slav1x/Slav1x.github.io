local RS=game:GetService("ReplicatedStorage")
local Chat=game:GetService("TextChatService")
local Catalog=require(RS:WaitForChild("Shared"):WaitForChild("RockCatalog"))
local queue={}
local function escape(value)
 return (tostring(value):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&apos;"))
end
local function channel()
 local channels=Chat:FindFirstChild("TextChannels")
 return channels and (channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("RBXSystem"))
end
local flushing=false
local function flush()
 if flushing then return end
 flushing=true
 task.spawn(function()
  while #queue>0 do
   local target=channel()
   if target then
    local data=queue[1]
    local rock=Catalog.get(data.id)
    local color=Catalog.RarityColors[data.rarity] or Color3.new(1,1,1)
    local message=string.format('<font color="#%s">@%s pulled %s (%s)!</font>',
     color:ToHex(),escape(data.username),escape(rock.name),escape(data.rarity))
    local ok=pcall(function() target:DisplaySystemMessage(message,"SummonAnnouncement") end)
    if ok then table.remove(queue,1) else task.wait(.5) end
   else task.wait(.25) end
  end
  flushing=false
 end)
end
RS:WaitForChild("SummonAnnouncement").OnClientEvent:Connect(function(data)
 if type(data)~="table" or type(data.username)~="string" or not Catalog.exists(data.id) then return end
 table.insert(queue,data)
 flush()
end)
