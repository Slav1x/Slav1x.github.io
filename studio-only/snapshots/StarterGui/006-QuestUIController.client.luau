-- Quest presentation. Currency and spin rewards are granted by QuestService on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local hud = script.Parent
local gui = player:WaitForChild("PlayerGui"):WaitForChild("QuestsUI")
local panel = gui:WaitForChild("QuestPanel")
local remotes = require(ReplicatedStorage.Shared.Remotes)
local sounds = require(ReplicatedStorage.SharedUI.UISounds)
local state
local scale = 1
local transition = 0
local scaleTween

local function short(value)
    local n = tonumber(value) or 0
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end
local function clock(seconds)
    local s = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end
local function detail(q)
    local id = tostring(q.id or "")
    if id:find("far_", 1, true) then return "Land one throw of at least " .. short(q.target) .. " studs." end
    if id:find("skips_", 1, true) then return "Get " .. short(q.target) .. " skips in a single throw." end
    if id:find("throw_", 1, true) then return "Skip " .. short(q.target) .. " stones across your throws." end
    if id:find("money_", 1, true) then return "Collect $" .. short(q.target) .. " from your throws." end
    if id:find("gold_", 1, true) then return "Pick up " .. short(q.target) .. " gold bars." end
    if id:find("perfect_", 1, true) then return "Time " .. short(q.target) .. " perfect releases." end
    if id:find("boom_", 1, true) then return "Break the sound barrier " .. short(q.target) .. " times." end
    return "Finish this challenge before the daily reset."
end
local function refresh(data)
    if typeof(data) ~= "table" or typeof(data.quests) ~= "table" then return end
    state = data
    local ready, claimed = 0, 0
    for i = 1, 3 do
        local row = panel["Quest" .. i]
        local q = data.quests[i]
        row.Visible = q ~= nil
        if q then
            local progress = tonumber(q.progress) or 0
            local target = math.max(1, tonumber(q.target) or 1)
            local done = q.claimed == true
            local canClaim = progress >= target and not done
            if done then claimed += 1 elseif canClaim then ready += 1 end
            local artKey = tostring(q.icon or "Rock")
            if tostring(q.id or ""):find("throw_", 1, true) then artKey = "Stones" end
            local art = panel.IconLibrary:FindFirstChild(artKey) or panel.IconLibrary.Rock
            row.Icon.QuestArt.Image = art.Image
            row.Icon.QuestArt.Visible = true
            row.Description.Text = tostring(q.text or "Daily quest")
            row.Subtitle.Text = detail(q)
            row.ProgressText.Text = short(math.min(progress, target)) .. " / " .. short(target)
            row.Track.Fill.Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1)
            row.RewardBox.CashValue.Text = "$" .. short(q.rewardMoney)
            row.RewardBox.SpinValue.Text = "+" .. short(q.rewardSpinStrength) .. " SPIN"
            row.Claim.Text = done and "CLAIMED ✓" or canClaim and "CLAIM!" or "TRACKING"
            row.Claim.Active = canClaim
            row.Claim.AutoButtonColor = canClaim
            row.Claim.BackgroundColor3 = canClaim and Color3.fromRGB(32, 213, 67) or done and Color3.fromRGB(28, 118, 109) or Color3.fromRGB(29, 62, 101)
            row.CompletionMarker.Visible = done or canClaim
            row.CompletionMarker.Text = done and "✓" or "!"
            row.CompletionMarker.BackgroundColor3 = done and Color3.fromRGB(31, 189, 112) or Color3.fromRGB(255, 179, 28)
            row:SetAttribute("QuestReady", canClaim)
        end
    end
    panel.DailyProgress.Count.Text = claimed .. " / 3 CLAIMED"
    panel.DailyProgress.Track.Fill.Size = UDim2.fromScale(claimed / 3, 1)
    local bonus = panel.DailyBonus
    local complete = claimed == 3
    local bonusDone = data.bonusClaimed == true
    bonus.Reward.Text = "+$" .. short(data.bonusMoney) .. "  •  +" .. short(data.bonusSpinStrength) .. " SPIN"
    bonus.Claim.Text = bonusDone and "CLAIMED ✓" or complete and "CLAIM BONUS!" or "COMPLETE ALL 3"
    bonus.Claim.Active = complete and not bonusDone
    bonus.Claim.AutoButtonColor = bonus.Claim.Active
    bonus.Claim.BackgroundColor3 = bonusDone and Color3.fromRGB(59, 104, 126) or complete and Color3.fromRGB(19, 205, 60) or Color3.fromRGB(17, 66, 106)
    bonus:SetAttribute("QuestReady", complete and not bonusDone)
    hud:SetAttribute("QuestReadyCount", ready + (complete and not bonusDone and 1 or 0))
    local badge = hud.questsopenFrame.questsopenbutton:FindFirstChild("NotificationBadge")
    if badge then
        badge.Visible = ready > 0 or (complete and not bonusDone)
        local number = ready + (complete and not bonusDone and 1 or 0)
        if badge:FindFirstChild("Label") then badge.Label.Text = tostring(number) end
        if badge:FindFirstChild("Shadow") then badge.Shadow.Text = tostring(number) end
    end
end
remotes.QuestState.OnClientEvent:Connect(refresh)
for i = 1, 3 do
    local row = panel["Quest" .. i]
    row.Claim.Activated:Connect(function()
        local q = state and state.quests[i]
        if not q or q.claimed or (q.progress or 0) < (q.target or math.huge) then return end
        sounds.play("Click")
        remotes.RequestClaimQuest:FireServer(q.id)
    end)
    row.MouseEnter:Connect(function()
        if player:GetAttribute("ReducedMotion") then return end
        local stroke = row:FindFirstChild("Outline")
        if stroke then TweenService:Create(stroke, TweenInfo.new(.14), {Thickness = 5}):Play() end
    end)
    row.MouseLeave:Connect(function()
        local stroke = row:FindFirstChild("Outline")
        if stroke then TweenService:Create(stroke, TweenInfo.new(.14), {Thickness = 3}):Play() end
    end)
end
panel.DailyBonus.Claim.Activated:Connect(function()
    if not state or state.bonusClaimed then return end
    for _, q in state.quests do if not q.claimed then return end end
    sounds.play("Click")
    remotes.RequestClaimQuestBonus:FireServer()
end)
panel.QuestToolbar.AchievementsTab.Activated:Connect(function()
    sounds.play("Click")
    panel.QuestToolbar.AchievementsTab.Label.Text = "COMING SOON"
    task.delay(1.6, function()
        if panel.Parent then panel.QuestToolbar.AchievementsTab.Label.Text = "ACHIEVEMENTS" end
    end)
end)

local function close()
    if not gui.Enabled then return end
    transition += 1
    local token = transition
    if scaleTween then scaleTween:Cancel() end
    sounds.play("Close")
    hud:SetAttribute("CurrentMenu", "")
    if player:GetAttribute("ReducedMotion") then
        gui.Enabled = false
        panel.PanelScale.Scale = scale
        return
    end
    scaleTween = TweenService:Create(panel.PanelScale, TweenInfo.new(.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = scale * .82})
    scaleTween:Play()
    scaleTween.Completed:Once(function(state)
        if state == Enum.PlaybackState.Completed and transition == token and gui.Parent then
            gui.Enabled = false
            panel.PanelScale.Scale = scale
        end
    end)
end
panel.Header.Close.Activated:Connect(close)
panel.CloseRequest.Event:Connect(close)

local function resize()
    local v = workspace.CurrentCamera.ViewportSize
    local portrait = v.X < 600 and v.Y > v.X
    local toolbar = panel.QuestToolbar
    if portrait then
        panel.Size = UDim2.fromOffset(390, 826)
        panel.Header.Size = UDim2.new(1, -12, 0, 69)
        panel.Header.Title.Position = UDim2.fromOffset(72, 4)
        panel.Header.Title.Size = UDim2.fromOffset(255, 38)
        panel.Header.Title.TextSize = 34
        panel.Header.QuestEmblem.Position = UDim2.fromOffset(8, 2)
        panel.Header.QuestEmblem.Size = UDim2.fromOffset(59, 59)
        panel.Header.Subtitle.Position = UDim2.fromOffset(73, 39)
        panel.Header.Subtitle.Size = UDim2.fromOffset(242, 21)
        panel.Header.Subtitle.TextSize = 12
        panel.Header.Close.Position = UDim2.new(1, -7, 0, 12)
        panel.Header.Close.Size = UDim2.fromOffset(42, 42)
        toolbar.Position = UDim2.fromOffset(9, 80)
        toolbar.Size = UDim2.fromOffset(372, 67)
        toolbar.DailyTab.Position = UDim2.fromOffset(5, 6)
        toolbar.DailyTab.Size = UDim2.fromOffset(118, 55)
        toolbar.DailyTab.Icon.Size = UDim2.fromOffset(37, 37)
        toolbar.DailyTab.Label.Position = UDim2.fromOffset(46, 8)
        toolbar.DailyTab.Label.Size = UDim2.fromOffset(68, 42)
        toolbar.DailyTab.Label.TextSize = 13
        toolbar.AchievementsTab.Position = UDim2.fromOffset(128, 6)
        toolbar.AchievementsTab.Size = UDim2.fromOffset(111, 55)
        toolbar.AchievementsTab.Icon.Size = UDim2.fromOffset(32, 32)
        toolbar.AchievementsTab.Label.Position = UDim2.fromOffset(42, 8)
        toolbar.AchievementsTab.Label.Size = UDim2.fromOffset(66, 42)
        toolbar.AchievementsTab.Label.TextSize = 11
        toolbar.ResetTimer.Position = UDim2.fromOffset(244, 6)
        toolbar.ResetTimer.Size = UDim2.fromOffset(123, 55)
        toolbar.ResetTimer.Clock.Position = UDim2.fromOffset(3, 10)
        toolbar.ResetTimer.Clock.Size = UDim2.fromOffset(31, 31)
        toolbar.ResetTimer.Label.Position = UDim2.fromOffset(37, 7)
        toolbar.ResetTimer.Label.Size = UDim2.fromOffset(82, 16)
        toolbar.ResetTimer.Label.TextSize = 11
        toolbar.ResetTimer.Value.Position = UDim2.fromOffset(37, 25)
        toolbar.ResetTimer.Value.Size = UDim2.fromOffset(84, 25)
        toolbar.ResetTimer.Value.TextSize = 14
        for i = 1, 3 do
            local row = panel["Quest" .. i]
            row.Position = UDim2.fromOffset(9, 157 + (i - 1) * 143)
            row.Size = UDim2.fromOffset(372, 136)
            row.Icon.Position = UDim2.fromOffset(10, 12)
            row.Icon.Size = UDim2.fromOffset(55, 55)
            row.Description.Position = UDim2.fromOffset(72, 10)
            row.Description.Size = UDim2.fromOffset(283, 25)
            row.Description.TextSize = 17
            row.Subtitle.Position = UDim2.fromOffset(73, 34)
            row.Subtitle.Size = UDim2.fromOffset(281, 20)
            row.Subtitle.TextSize = 11
            row.RewardBox.Position = UDim2.fromOffset(73, 60)
            row.RewardBox.Size = UDim2.fromOffset(176, 35)
            row.RewardBox.CashIcon.Position = UDim2.fromOffset(4, 1)
            row.RewardBox.CashIcon.Size = UDim2.fromOffset(34, 30)
            row.RewardBox.CashValue.Position = UDim2.fromOffset(38, 4)
            row.RewardBox.CashValue.Size = UDim2.fromOffset(47, 26)
            row.RewardBox.CashValue.TextSize = 12
            row.RewardBox.SpinIcon.Position = UDim2.fromOffset(91, 2)
            row.RewardBox.SpinIcon.Size = UDim2.fromOffset(28, 28)
            row.RewardBox.SpinValue.Position = UDim2.fromOffset(119, 4)
            row.RewardBox.SpinValue.Size = UDim2.fromOffset(55, 26)
            row.RewardBox.SpinValue.TextSize = 10
            row.Track.Position = UDim2.fromOffset(13, 105)
            row.Track.Size = UDim2.fromOffset(346, 21)
            row.ProgressText.Position = row.Track.Position
            row.ProgressText.Size = row.Track.Size
            row.ProgressText.TextSize = 15
            row.Claim.Position = UDim2.fromOffset(258, 63)
            row.Claim.Size = UDim2.fromOffset(101, 34)
            row.Claim.TextSize = 14
            row.CompletionMarker.Position = UDim2.fromOffset(49, 11)
        end
        panel.DailyProgress.Position = UDim2.fromOffset(9, 589)
        panel.DailyProgress.Size = UDim2.fromOffset(372, 104)
        panel.DailyProgress.GiftIcon.Size = UDim2.fromOffset(69, 69)
        panel.DailyProgress.Label.Position = UDim2.fromOffset(84, 8)
        panel.DailyProgress.Label.Size = UDim2.fromOffset(260, 27)
        panel.DailyProgress.Label.TextSize = 21
        panel.DailyProgress.Subtitle.Position = UDim2.fromOffset(85, 35)
        panel.DailyProgress.Subtitle.Size = UDim2.fromOffset(272, 20)
        panel.DailyProgress.Subtitle.TextSize = 11
        panel.DailyProgress.Track.Position = UDim2.fromOffset(84, 70)
        panel.DailyProgress.Track.Size = UDim2.fromOffset(272, 20)
        panel.DailyProgress.Count.Position = UDim2.fromOffset(220, 54)
        panel.DailyProgress.Count.Size = UDim2.fromOffset(136, 18)
        panel.DailyBonus.Position = UDim2.fromOffset(9, 704)
        panel.DailyBonus.Size = UDim2.fromOffset(372, 112)
        scale = math.min(.96, (v.X - 14) / 390, (gui.AbsoluteSize.Y - 14) / 826)
    else
        panel.Size = UDim2.fromOffset(1080, 720)
        panel.Header.Size = UDim2.new(1, -16, 0, 96)
        panel.Header.Title.Position = UDim2.fromOffset(113, 10)
        panel.Header.Title.Size = UDim2.fromOffset(700, 54)
        panel.Header.Title.TextSize = 52
        panel.Header.QuestEmblem.Position = UDim2.fromOffset(17, 4)
        panel.Header.QuestEmblem.Size = UDim2.fromOffset(88, 88)
        panel.Header.Subtitle.Position = UDim2.fromOffset(117, 65)
        panel.Header.Subtitle.Size = UDim2.fromOffset(690, 24)
        panel.Header.Subtitle.TextSize = 19
        panel.Header.Close.Position = UDim2.new(1, -14, 0, 18)
        panel.Header.Close.Size = UDim2.fromOffset(58, 58)
        toolbar.Position = UDim2.fromOffset(20, 112)
        toolbar.Size = UDim2.new(1, -40, 0, 70)
        toolbar.DailyTab.Position = UDim2.fromOffset(6, 6)
        toolbar.DailyTab.Size = UDim2.fromOffset(296, 58)
        toolbar.DailyTab.Icon.Size = UDim2.fromOffset(48, 48)
        toolbar.DailyTab.Label.Position = UDim2.fromOffset(70, 8)
        toolbar.DailyTab.Label.Size = UDim2.new(1, -78, 0, 44)
        toolbar.DailyTab.Label.TextSize = 25
        toolbar.AchievementsTab.Position = UDim2.fromOffset(312, 6)
        toolbar.AchievementsTab.Size = UDim2.fromOffset(300, 58)
        toolbar.AchievementsTab.Icon.Size = UDim2.fromOffset(48, 48)
        toolbar.AchievementsTab.Label.Position = UDim2.fromOffset(70, 8)
        toolbar.AchievementsTab.Label.Size = UDim2.new(1, -78, 0, 44)
        toolbar.AchievementsTab.Label.TextSize = 25
        toolbar.ResetTimer.Position = UDim2.new(1, -314, 0, 6)
        toolbar.ResetTimer.Size = UDim2.fromOffset(308, 58)
        toolbar.ResetTimer.Clock.Position = UDim2.fromOffset(8, 3)
        toolbar.ResetTimer.Clock.Size = UDim2.fromOffset(52, 52)
        toolbar.ResetTimer.Label.Position = UDim2.fromOffset(69, 4)
        toolbar.ResetTimer.Label.Size = UDim2.fromOffset(220, 19)
        toolbar.ResetTimer.Label.TextSize = 15
        toolbar.ResetTimer.Value.Position = UDim2.fromOffset(69, 22)
        toolbar.ResetTimer.Value.Size = UDim2.fromOffset(228, 32)
        toolbar.ResetTimer.Value.TextSize = 26
        for i = 1, 3 do
            local row = panel["Quest" .. i]
            row.Position = UDim2.fromOffset(20, 192 + (i - 1) * 130)
            row.Size = UDim2.new(1, -40, 0, 122)
            row.Icon.Position = UDim2.fromOffset(15, 22)
            row.Icon.Size = UDim2.fromOffset(78, 78)
            row.Description.Position = UDim2.fromOffset(109, 11)
            row.Description.Size = UDim2.fromOffset(465, 35)
            row.Description.TextSize = 25
            row.Subtitle.Position = UDim2.fromOffset(110, 45)
            row.Subtitle.Size = UDim2.fromOffset(455, 24)
            row.Subtitle.TextSize = 16
            row.Track.Position = UDim2.fromOffset(109, 82)
            row.Track.Size = UDim2.fromOffset(455, 26)
            row.ProgressText.Position = row.Track.Position
            row.ProgressText.Size = row.Track.Size
            row.ProgressText.TextSize = 20
            row.RewardBox.Position = UDim2.fromOffset(580, 17)
            row.RewardBox.Size = UDim2.fromOffset(260, 94)
            row.RewardBox.CashIcon.Position = UDim2.fromOffset(11, 9)
            row.RewardBox.CashIcon.Size = UDim2.fromOffset(56, 47)
            row.RewardBox.CashValue.Position = UDim2.fromOffset(8, 57)
            row.RewardBox.CashValue.Size = UDim2.fromOffset(100, 29)
            row.RewardBox.CashValue.TextSize = 20
            row.RewardBox.SpinIcon.Position = UDim2.fromOffset(151, 9)
            row.RewardBox.SpinIcon.Size = UDim2.fromOffset(48, 47)
            row.RewardBox.SpinValue.Position = UDim2.fromOffset(128, 57)
            row.RewardBox.SpinValue.Size = UDim2.fromOffset(120, 29)
            row.RewardBox.SpinValue.TextSize = 18
            row.Claim.Position = UDim2.fromOffset(857, 38)
            row.Claim.Size = UDim2.fromOffset(164, 50)
            row.Claim.TextSize = 25
            row.CompletionMarker.Position = UDim2.fromOffset(75, 15)
        end
        panel.DailyProgress.Position = UDim2.fromOffset(20, 594)
        panel.DailyProgress.Size = UDim2.fromOffset(650, 112)
        panel.DailyProgress.GiftIcon.Size = UDim2.fromOffset(88, 88)
        panel.DailyProgress.Label.Position = UDim2.fromOffset(111, 10)
        panel.DailyProgress.Label.Size = UDim2.fromOffset(510, 32)
        panel.DailyProgress.Label.TextSize = 28
        panel.DailyProgress.Subtitle.Position = UDim2.fromOffset(112, 42)
        panel.DailyProgress.Subtitle.Size = UDim2.fromOffset(505, 22)
        panel.DailyProgress.Subtitle.TextSize = 16
        panel.DailyProgress.Track.Position = UDim2.fromOffset(112, 75)
        panel.DailyProgress.Track.Size = UDim2.fromOffset(501, 22)
        panel.DailyProgress.Count.Position = UDim2.fromOffset(475, 51)
        panel.DailyProgress.Count.Size = UDim2.fromOffset(138, 20)
        panel.DailyBonus.Position = UDim2.fromOffset(682, 594)
        panel.DailyBonus.Size = UDim2.fromOffset(376, 112)
        scale = math.min(.94, (v.X - 24) / 1080, (gui.AbsoluteSize.Y - 20) / 720)
    end
    panel.PanelScale.Scale = scale
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
resize()
task.defer(resize)

task.spawn(function()
    while gui.Parent do
        if state and state.resetAt then
            local remaining = state.resetAt - os.time()
            panel.QuestToolbar.ResetTimer.Value.Text = clock(remaining)
            if remaining <= 0 then remotes.RequestQuestState:FireServer() end
        end
        task.wait(1)
    end
end)
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if gui.Enabled then
        transition += 1
        if scaleTween then scaleTween:Cancel() end
        if player:GetAttribute("ReducedMotion") then
            panel.PanelScale.Scale = scale
        else
            panel.PanelScale.Scale = scale * .82
            scaleTween = TweenService:Create(panel.PanelScale, TweenInfo.new(.23, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = scale})
            scaleTween:Play()
        end
        remotes.RequestQuestState:FireServer()
    end
end)
remotes.RequestQuestState:FireServer()


