-- Studio Edit mode only. Paste one of these into View > Command Bar:
-- require(game.ServerStorage.StudioUIPreview).show("Daily")
-- require(game.ServerStorage.StudioUIPreview).show("Playtime")
-- require(game.ServerStorage.StudioUIPreview).show("Quests")
-- require(game.ServerStorage.StudioUIPreview).show("Shop", "SpecialPets")
-- require(game.ServerStorage.StudioUIPreview).hide()
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Preview = {}

local names = {
    featured = "FeaturedPage",
    gamepasses = "GamepassesPage",
    specialpets = "SpecialPetsPage",
    specialrocks = "SpecialRocksPage",
    cashpacks = "CashPacksPage",
}

local function editOnly()
    assert(not RunService:IsRunning(), "StudioUIPreview is for Edit mode. Stop Play first.")
end

local function styleTabs(shop, activePage)
    for _, tab in shop.Shell.Navigation:GetChildren() do
        if tab:IsA("GuiButton") then
            local selected = tab:GetAttribute("Page") == activePage
            local outline = tab:FindFirstChild("Outline")
            if outline then
                outline.Color = selected and Color3.fromRGB(203, 255, 161) or Color3.fromRGB(88, 117, 158)
                outline.Thickness = selected and 2 or 1
                outline.Transparency = selected and 0 or .08
            end
            local gradient = tab:FindFirstChild("TabGradient")
            if gradient then
                gradient.Color = selected
                    and ColorSequence.new(Color3.fromRGB(143, 241, 86), Color3.fromRGB(26, 160, 78))
                    or ColorSequence.new(Color3.fromRGB(58, 86, 131), Color3.fromRGB(30, 47, 81))
            end
            local label = tab:FindFirstChild("Label")
            if label then label.TextColor3 = selected and Color3.fromRGB(245, 250, 255) or Color3.fromRGB(212, 227, 245) end
            local icon = tab:FindFirstChild("AssetIcon")
            if icon then icon.ImageTransparency = selected and 0 or .12 end
        end
    end
end

function Preview.hide()
    editOnly()
    local hud = StarterGui.MainHUD
    StarterGui.DailyRewardsUI.Enabled = false
    StarterGui.PlaytimeGiftsUI.Enabled = false
    StarterGui.QuestsUI.Enabled = false
    for _, name in {"shopui", "inventoryui", "upgradesui", "settingsui", "IndexPanel", "MultiplierBreakdown"} do
        hud[name].Visible = false
    end
    hud.SummonGroveQuickButton.Visible = true
    return "UI preview hidden"
end

function Preview.show(menu, tab)
    editOnly()
    local key = tostring(menu or ""):lower():gsub("[%s_%-]", "")
    local shopPage
    if key == "shop" then
        local tabKey = tostring(tab or "Featured"):lower():gsub("[%s_%-]", "")
        shopPage = names[tabKey]
        assert(shopPage, "Shop tab must be Featured, Gamepasses, SpecialPets, SpecialRocks, or CashPacks")
    else
        assert(key == "daily" or key == "dailyrewards" or key == "playtime" or key == "playtimegifts" or key == "quests", "Menu must be Daily, Playtime, Quests, or Shop")
    end
    Preview.hide()
    StarterGui.MainHUD.Enabled = true
    StarterGui.MainHUD.SummonGroveQuickButton.Visible = false
    if key == "daily" or key == "dailyrewards" then
        StarterGui.DailyRewardsUI.Enabled = true
        return "Showing Daily Rewards. Edit StarterGui > DailyRewardsUI > Background."
    elseif key == "playtime" or key == "playtimegifts" then
        StarterGui.PlaytimeGiftsUI.Enabled = true
        return "Showing Playtime Gifts. Edit StarterGui > PlaytimeGiftsUI > Background."
    elseif key == "quests" then
        StarterGui.QuestsUI.QuestPanel.Visible = true
        StarterGui.QuestsUI.Enabled = true
        return "Showing Quests. Edit StarterGui > QuestsUI > QuestPanel."
    end
    local shop = StarterGui.MainHUD.shopui
    shop.Visible = true
    shop.Shell.Visible = true
    for _, page in shop.Shell.Content:GetChildren() do
        if page:IsA("CanvasGroup") then
            page.Visible = page.Name == shopPage
            page.GroupTransparency = page.Name == shopPage and 0 or 1
        end
    end
    styleTabs(shop, shopPage)
    return "Showing Shop > " .. shopPage .. ". Edit StarterGui > MainHUD > shopui > Shell > Content > " .. shopPage .. "."
end

return Preview


